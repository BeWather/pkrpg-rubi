extends RefCounted
class_name BattleSubstitutePresentation
## Native reconciliation of an accepted barrier, independent of HP/PP authority.

static func owned_state(slot: BattleSlot) -> Dictionary:
	if not is_instance_valid(slot) or not is_instance_valid(slot.sprite_pokemon):return {}
	var sprite: Sprite2D=slot.sprite_pokemon
	var state: Dictionary=sprite.get_meta("source_presentation_state",{})
	if state.get("texture")!=sprite.texture or int(state.get("generation",-1))!=slot.animation_generation or state.get("token")!=sprite.get_meta("source_appearance_owner","") or state.get("species")!=sprite.get_meta("animation_species",""):return {}
	for property: String in state.get("frame_properties",{}):
		if sprite.get(property)!=state.frame_properties[property]:return {}
	return state

static func capture(slot: BattleSlot) -> BattleOwnedAppearanceLease:
	if not is_instance_valid(slot) or not is_instance_valid(slot.sprite_pokemon) or slot.sprite_pokemon.texture==null:return null
	return BattleOwnedAppearanceLease.capture(BattleAnimationActor.new(int(slot.posicion_batalla),0 if slot.es_jugador else 1,slot.sprite_pokemon,slot))

static func restore_bound(lease: BattleOwnedAppearanceLease, state: Dictionary, detached: bool=false) -> void:
	if lease==null or not lease.still_bound(detached):return
	var chosen: Dictionary={}
	if str(state.get("kind",""))=="substitute":chosen=state.previous.duplicate(true)
	elif str(state.get("kind",""))=="substitute_mon":chosen=state.substitute_state.previous.duplicate(true)
	if chosen.is_empty():return
	var underlying: Dictionary=chosen.get("presentation_state",{}).duplicate(true)
	if underlying.is_empty():underlying={"kind":"form"}
	lease.replacement={"texture":chosen.texture,"species":str(chosen.get("species","")),"kind":str(underlying.kind),"frame_properties":BattleSubstituteLifecycle._frame_properties(chosen),"presentation_state":underlying}
	lease.ready=true;lease.finalize(true,detached)

static func ensure_doll(lease: BattleOwnedAppearanceLease) -> void:
	if lease==null or not lease.still_bound():return
	# The same source assets as Move164; fallback is not a second gameplay command.
	var view: String="back" if lease.actor.side==0 else "front"
	var texture: Texture2D=load("res://graficos/batalla/animaciones/substitute_%s.png"%view)
	if texture==null:return
	lease.replacement={"texture":texture,"species":str(lease.before.species),"kind":"substitute","flip_h":lease.before.flip_h}
	lease.ready=true;lease.finalize(true)

static func _animation_for(slot: BattleSlot) -> BattleSequenceAnimation:
	var node: Node=slot.get_parent()
	while is_instance_valid(node):
		var reference: Variant=node.get_meta("active_move_animation") if node.has_meta("active_move_animation") else null
		if reference is WeakRef:
			var animation: BattleSequenceAnimation=reference.get_ref()
			if is_instance_valid(animation) and animation.state=="running" and is_instance_valid(animation.runner):
				var context: BattleAnimationContext=animation.runner.context
				var selected: Array[int]=context.target_ids.duplicate();selected.append(context.attacker_id)
				for id: int in selected:
					if context.actors.has(id) and context.actors[id].slot==slot:return animation
				for track: Dictionary in animation.runner._tracks:
					var actor: Variant=track.get("bound_actor")
					if actor is BattleAnimationActor and actor.slot==slot:return animation
		node=node.get_parent()
	return null

static func retire(slot: BattleSlot) -> void:
	if not is_instance_valid(slot) or not is_instance_valid(slot.sprite_pokemon):return
	var sprite: Sprite2D=slot.sprite_pokemon
	var record: Dictionary=sprite.get_meta("source_presentation_state",{})
	var animation: BattleSequenceAnimation=_animation_for(slot)
	var substitute_record: bool=str(record.get("kind","")) in ["substitute","substitute_mon"]
	var pending_substitute: bool=animation!=null and (animation.definition.key in ["ruby:move/164","ruby:general/2","ruby:general/3","ruby:special/5","ruby:special/6"] or animation.runner.has_meta("source_substitute_guard"))
	if not substitute_record and not pending_substitute:return
	var state: Dictionary=owned_state(slot) if substitute_record else {}
	# Release only the retiring original's transient writes before texture commit.
	# An external tag/frame/texture is not a lease this cleanup can acquire.
	if animation!=null:
		var guard: BattleOwnedAppearanceLease=animation.runner.get_meta("source_substitute_guard") if animation.runner.has_meta("source_substitute_guard") else null
		for actor: BattleAnimationActor in animation.runner.context.actors.values():
			if actor.slot==slot and (not state.is_empty() or (guard!=null and guard.still_bound())):actor.release()
	if not state.is_empty():restore_bound(capture(slot),state,true)
	# Remove stale records we authored, never an external provider's owner/species.
	var current: Dictionary=sprite.get_meta("source_presentation_state",{})
	if substitute_record and current.has("token") and current.get("kind")!="transform":
		if sprite.get_meta("source_appearance_owner","")==current.token:
			sprite.remove_meta("source_appearance_owner")
			if sprite.get_meta("animation_species","")==current.get("species"):sprite.remove_meta("animation_species")
		sprite.remove_meta("source_presentation_state")
	# Mark aborted BEFORE waking waiters: cancellation cannot launch a new primary
	# or let a pending finalizer reacquire the new slot occupant.
	if animation!=null:
		animation.runner.lifecycle_aborted=true;animation.cancel()

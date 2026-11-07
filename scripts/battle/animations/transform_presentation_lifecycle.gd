extends RefCounted
class_name BattleTransformPresentation
## Accepted native Transform presentation snapshot and explicit own-doll handoff.
static func capture(battle: BattleSceneController, actor: BasePokemon, target: BasePokemon, action: BattleMoveAction) -> Dictionary:
	var slot: BattleSlot=battle.hud._obtener_slot_de_pokemon(actor)
	var other: BattleSlot=battle.hud._obtener_slot_de_pokemon(target)
	var guard: BattleOwnedAppearanceLease=BattleSubstitutePresentation.capture(slot)
	if guard==null or other==null:return {"original_guard":guard}
	var context: BattleAnimationContext=BattleAnimationContext.from_legacy(MoveAnimationContext.nueva(battle,slot,other))
	var actors: Array[BattleAnimationActor]=context.resolve("attacker")
	var targets: Array[BattleAnimationActor]=context.resolve("target")
	if actors.is_empty() or targets.is_empty():return {"original_guard":guard}
	return {"original_guard":guard,"buffer":BattleSourceTransform.buffer(context,actors[0],targets[0]),"action_id":action.action_id}

static func bind(snapshot: Dictionary, coordinator: BattleSubstituteActionCoordinator) -> BattleOwnedAppearanceLease:
	var original: BattleOwnedAppearanceLease=snapshot.get("original_guard")
	if original==null:return null
	if coordinator!=null and coordinator.opened:
		# Only the approved original doll's Special5 can change this guard.
		var state: Dictionary=BattleSubstitutePresentation.owned_state(coordinator.slot)
		if coordinator.aborted or state.get("kind")!="substitute_mon" or state.get("substitute_state",{}).get("token")!=original.before.tag:return null
		return coordinator.expected
	return original

static func transform_state(lease: BattleOwnedAppearanceLease, action_id: int) -> Dictionary:
	var previous: Dictionary=lease.before.duplicate(true)
	previous.species=previous.get("species","")
	previous.presentation_state=lease.actor.sprite.get_meta("source_presentation_state",{}).duplicate(true)
	# A Transform changes the underlying mon, not its own authoritative doll.
	if previous.presentation_state.get("kind")=="substitute_mon":previous=previous.presentation_state.substitute_state.previous.duplicate(true)
	var state: Dictionary={"kind":"transform","previous":previous,"transform_action_id":action_id}
	if lease.replacement.has("shadow") and is_instance_valid(lease.actor.slot) and lease.actor.slot._sombra_activa==lease.before.get("shadow"):
		state.shadow_before=lease.before.shadow;state.shadow_after=lease.replacement.shadow
	return state

static func reconcile(presenter: BattleMoveActionPresenter) -> void:
	var snapshot: Dictionary=presenter.action.transform_presentation
	var guard: BattleOwnedAppearanceLease=snapshot.get("guard")
	var battle: BattleSceneController=presenter.battle
	if guard==null or not snapshot.has("buffer") or not is_instance_valid(battle) or not battle.is_inside_tree() or battle.fase==battle.FIN_BATALLA:return
	if presenter.action.attacker.estad_ps_actual<=0:return
	if battle.hud._obtener_slot_de_pokemon(presenter.action.attacker)!=guard.actor.slot:return
	if presenter.animation is BattleSequenceAnimation and presenter.animation.lifecycle_aborted:return
	var current: Dictionary=BattleSubstitutePresentation.owned_state(guard.actor.slot)
	if int(current.get("transform_action_id",-1))!=presenter.action.action_id:
		# Failed/cancelled/missing visuals keep accepted domain authority. Commit
		# the frozen party buffer only to the original expected-value guard.
		if not guard.still_bound():return
		guard.replacement=snapshot.buffer.duplicate(true)
		guard.replacement.presentation_state=transform_state(guard,presenter.action.action_id)
		guard.ready=true;guard.finalize(true)
		current=BattleSubstitutePresentation.owned_state(guard.actor.slot)
	if int(current.get("transform_action_id",-1))==presenter.action.action_id and presenter.action.substitute_coordinator!=null:
		presenter.action.substitute_coordinator.accept_transform_handoff(presenter.action.action_id,current)

static func retire(slot: BattleSlot) -> void:
	if not is_instance_valid(slot) or not is_instance_valid(slot.sprite_pokemon):return
	# Only retire this actor's pending native Transform; a target leaving must
	# not cancel somebody else's action or adopt its new slot occupant.
	var animation: BattleSequenceAnimation=BattleSubstitutePresentation._animation_for(slot)
	if animation!=null and animation.runner.has_meta("source_transform_guard"):
		var guard: BattleOwnedAppearanceLease=animation.runner.get_meta("source_transform_guard")
		if guard!=null and guard.actor.slot==slot:
			animation.runner.lifecycle_aborted=true;animation.cancel()
	var state: Dictionary=BattleSubstitutePresentation.owned_state(slot)
	if state.get("kind")!="transform":return
	var chosen: Dictionary={}
	var shadow: Dictionary={}
	for depth in 16:
		if state.get("kind")!="transform":break
		if state.has("shadow_after"):shadow={"before":state.shadow_before,"after":state.shadow_after}
		chosen=state.previous.duplicate(true);state=chosen.get("presentation_state",{})
	if chosen.is_empty():return
	var lease: BattleOwnedAppearanceLease=BattleSubstitutePresentation.capture(slot)
	if lease==null:return
	lease.replacement={"texture":chosen.texture,"species":str(chosen.get("species","")),"kind":"form","frame_properties":BattleSubstituteLifecycle._frame_properties(chosen)}
	if not shadow.is_empty() and slot._sombra_activa==shadow.after:lease.replacement.shadow=shadow.before
	lease.ready=true;lease.finalize(true,true)
	var sprite: Sprite2D=slot.sprite_pokemon
	var owned: Dictionary=sprite.get_meta("source_presentation_state",{})
	if sprite.get_meta("source_appearance_owner","")==owned.get("token"):
		if str(chosen.get("tag","")).is_empty():sprite.remove_meta("source_appearance_owner")
		else:sprite.set_meta("source_appearance_owner",chosen.tag)
		if str(chosen.get("species","")).is_empty():sprite.remove_meta("animation_species")
		else:sprite.set_meta("animation_species",chosen.species)
		if state.is_empty():sprite.remove_meta("source_presentation_state")
		else:sprite.set_meta("source_presentation_state",state)

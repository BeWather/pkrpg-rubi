extends RefCounted
class_name BattleSubstituteLifecycle
## Compartida: _frame_properties() lo usan BattleSubstituteActionCoordinator, BattleSubstitutePresentation y
## BattleTransformPresentation en producción; la pista de la VM legada (create()/update()/update_palette()) está
## obsoleta. Ver scripts/battle/animations/sequence/README.md.

## Qualified visual lifecycle; domain HP/barrier authority remains separate.
## @deprecated: camino de la VM legada; las animaciones nativas no lo usan. Se conserva como referencia y fallback de configuración. Ver scripts/battle/animations/sequence/README.md.
static func create(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Array[Dictionary]:
	var resolved: Array[BattleAnimationActor]=context.resolve("attacker")
	if resolved.is_empty():return []
	var actor: BattleAnimationActor=resolved[0]
	var mode: String=str(step.mode)
	# General2's fade and later restore are one execution-bound identity.
	# Do not acquire an external owner's tag/frame at the delayed swap callback.
	var guard: BattleOwnedAppearanceLease=owner.get_meta("source_substitute_guard") if owner.has_meta("source_substitute_guard") else null
	if guard!=null and not guard.still_bound():return []
	if guard==null:
		guard=BattleOwnedAppearanceLease.capture(actor)
		owner.set_meta("source_substitute_guard",guard)
	if mode=="substitute_palette":
		return [{"kind":"substitute_palette","age":0,"ticks":int(step.ticks),"owner":owner,"bound_actor":actor,"settings":step,"update":update_palette}]
	var node: Sprite2D=BattleIdentityCopy.clone_sprite(actor,owner)
	node.z_index=BattleSourcePriority.relative_layer(actor,1,context,owner) if mode=="substitute_fade" else BattleSourcePriority.actor_layer(actor,owner)
	owner.add_child(node);actor.apply_source_state("hidden",true)
	var track: Dictionary={"kind":"substitute_lifecycle","age":0,"ticks":int(step.ticks),"bound_actor":actor,"node":node,"owner":owner,"guard":guard,"settings":step.duplicate(true),"phase":0,"count":0,"swap_offset":0,"eva":16,"evb":0,"update":update}
	if mode=="substitute_swap":
		track.lease=BattleOwnedAppearanceLease.capture(actor);owner._appearance_leases.append(track.lease)
	else:
		var material:=ShaderMaterial.new();material.shader=load("res://scripts/battle/animations/sequence/source_substitute_fade.gdshader")
		node.material=material;track.material=material
	return [track]

## @deprecated: camino de la VM legada; las animaciones nativas no lo usan. Se conserva como referencia y fallback de configuración. Ver scripts/battle/animations/sequence/README.md.
static func update_palette(track: Dictionary, _context: BattleAnimationContext) -> void:
	if not track.bound_actor.is_present():track.ticks=int(track.age);return
	var s: Dictionary=track.settings
	var amount: int=mini(absi(int(s.blend_end)-int(s.blend_start)),maxi(0,int(track.age)-1)/maxi(1,int(s.blend_delay)))
	track.owner.set_meta("source_substitute_palette",(int(s.blend_start)+signi(int(s.blend_end)-int(s.blend_start))*amount)/16.0)

## @deprecated: camino de la VM legada; las animaciones nativas no lo usan. Se conserva como referencia y fallback de configuración. Ver scripts/battle/animations/sequence/README.md.
static func update(track: Dictionary, context: BattleAnimationContext) -> void:
	var actor: BattleAnimationActor=track.bound_actor
	if not actor.is_present() or not track.guard.still_bound() or (track.has("lease") and not track.lease.still_bound()):
		track.node.visible=false;track.ticks=int(track.age);return
	if str(track.settings.mode)=="substitute_fade":_fade(track)
	else:_swap(track,context)
	track.node.position=track.owner.to_local(actor.sprite.to_global(Vector2(0,actor.sprite.get_rect().end.y-track.node.get_rect().end.y)))+Vector2(track.swap_offset,0)

static func _fade(track: Dictionary) -> void:
	match int(track.phase):
		0:track.phase=1
		1:
			track.count+=1
			if int(track.count)==3:
				track.count=0;track.eva-=1;track.evb+=1
				if int(track.eva)==0:track.phase=2
		2:
			track.node.visible=false;track.owner.set_meta("source_substitute_remove",true);track.ticks=int(track.age)
	if track.node.material==track.material:
		track.material.set_shader_parameter("eva",float(track.eva)/16)
		track.material.set_shader_parameter("evb",float(track.evb)/16)
		track.material.set_shader_parameter("palette_amount",float(track.owner.get_meta("source_substitute_palette",0.0)))

static func _swap(track: Dictionary, context: BattleAnimationContext) -> void:
	var actor: BattleAnimationActor=track.bound_actor
	var direction: int=-1 if actor.side==0 else 1
	match int(track.phase):
		0:
			track.swap_offset+=5*direction
			var x: float=actor.anchor(context.field,"origin").x+float(track.swap_offset)+32
			# Ruby u32 wraps negative x; preserve both unsigned exits without actor-ID assumptions.
			if x<0 or x>context.field_size.x+64:track.phase=1
		1:
			_capture_swap(track,context);track.phase=2
		2:
			track.swap_offset-=5*direction
			if int(track.swap_offset)*direction<=0:
				track.swap_offset=0;track.lease.ready=true;track.ticks=int(track.age)

static func _frame_properties(state: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for property: String in ["hframes","vframes","frame","region_enabled","region_rect","flip_h","flip_v"]:
		if state.has(property):result[property]=state[property]
	return result

static func _capture_swap(track: Dictionary, context: BattleAnimationContext) -> void:
	var actor: BattleAnimationActor=track.bound_actor
	var current: Dictionary=actor.sprite.get_meta("source_presentation_state",{})
	var to_mon: bool=int(track.settings.source_args[0])==1
	var state: Dictionary={}
	var chosen: Dictionary={}
	if to_mon and str(current.get("kind",""))=="substitute":
		chosen=current.previous.duplicate(true)
		state=chosen.get("presentation_state",{}).duplicate(true)
		if not bool(track.owner.get_meta("source_substitute_remove",false)):
			state={"kind":"substitute_mon","underlying_presentation":state,"substitute_state":current.duplicate(true)}
	elif not to_mon and str(current.get("kind",""))=="substitute_mon":
		state=current.substitute_state.duplicate(true);chosen=state.duplicate(true)
	else:
		var view: String="back" if actor.side==0 or context.contest else "front"
		if not to_mon:
			chosen.texture=load(str(track.settings.back_texture if view=="back" else track.settings.front_texture))
			chosen.species=str(actor.sprite.get_meta("animation_species",context.source_appearance_species.get(actor.id,"")))
			state={"kind":"substitute","previous":_snapshot(actor.sprite)}
		else:
			# Direct laboratory mon phase without a committed doll uses the bound
			# appearance, preserving custom art/Transform instead of guessing species.
			chosen=_snapshot(actor.sprite);state=current.duplicate(true)
	var node: Sprite2D=track.node
	node.texture=chosen.texture;node.hframes=1;node.vframes=1;node.frame=0;node.region_enabled=false
	for property: String in _frame_properties(chosen):node.set(property,chosen[property])
	if state.is_empty():state={"kind":"form"}
	track.lease.replacement={"texture":node.texture,"species":str(chosen.get("species",context.source_appearance_species.get(actor.id,""))),"kind":str(state.kind),"frame_properties":_frame_properties(_snapshot(node)),"presentation_state":state}

static func _snapshot(sprite: Sprite2D) -> Dictionary:
	return {"texture":sprite.texture,"hframes":sprite.hframes,"vframes":sprite.vframes,"frame":sprite.frame,"region_enabled":sprite.region_enabled,"region_rect":sprite.region_rect,"flip_h":sprite.flip_h,"flip_v":sprite.flip_v,"species":sprite.get_meta("animation_species",""),"presentation_state":sprite.get_meta("source_presentation_state",{}).duplicate(true)}

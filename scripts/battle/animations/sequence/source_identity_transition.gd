extends RefCounted
class_name BattleIdentityTransition
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Native local BG scanline ownership; presentation never writes domain identity.
static func create(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Array[Dictionary]:
	if str(step.mode)=="transform":return BattleSourceTransform.create(step,context,owner)
	if str(step.mode)=="substitute":return BattleSourceSubstitute.create(step,context,owner)
	if str(step.mode) in ["substitute_swap","substitute_fade","substitute_palette"]:return BattleSubstituteLifecycle.create(step,context,owner)
	var resolved: Array[BattleAnimationActor]=context.resolve(str(step.get("selector","attacker")))
	if resolved.is_empty():return []
	var actor: BattleAnimationActor=resolved[0]
	var node: Sprite2D=BattleIdentityCopy.clone_sprite(actor,owner)
	node.z_index=BattleSourcePriority.actor_layer(actor,owner)
	owner.add_child(node)
	var material:=ShaderMaterial.new()
	material.shader=load("res://scripts/battle/animations/sequence/source_acid_armor.gdshader")
	material.set_shader_parameter("stretch",1.0)
	material.set_shader_parameter("scanline_band",66.0)
	# monBG copies the selected source frame, not adjacent atlas cells.
	var texture_size: Vector2=actor.sprite.texture.get_size()
	var region: Rect2=actor.sprite.region_rect if actor.sprite.region_enabled else Rect2(Vector2.ZERO,texture_size)
	var frame_size: Vector2=region.size/Vector2(actor.sprite.hframes,actor.sprite.vframes)
	material.set_shader_parameter("frame_uv_origin",(region.position+Vector2(actor.sprite.frame_coords)*frame_size)/texture_size)
	material.set_shader_parameter("frame_uv_size",frame_size/texture_size)
	node.material=material
	actor.apply_source_state("hidden",true)
	return [{"kind":"source_identity_transition","age":0,"ticks":int(step.ticks),"bound_actor":actor,"node":node,"owned_material":material,"settings":step.duplicate(true),"phase":0,"count":0,"stretch":32,"horizontal":0,"angle":0,"eva":16,"evb":0,"update":update}]

static func update(track: Dictionary, _context: BattleAnimationContext) -> void:
	var actor: BattleAnimationActor=track.bound_actor
	if not actor.is_present():
		track.node.visible=false;track.ticks=int(track.age);return
	track.node.position=actor.anchor(track.node.get_parent(),"origin")
	match int(track.phase):
		0:
			track.angle=(int(track.angle)+2)&255
			track.stretch=min(64,int(track.stretch)+1)
			if int(track.stretch)==64:
				track.count+=1
				if int(track.count)&1:track.eva-=1
				else:track.evb+=1
				if int(track.eva)==0 and int(track.evb)==16:track.phase=1;track.count=0
			else:track.horizontal+=24 if actor.side==0 else -24
		1:
			track.count+=1
			if int(track.count)>12:track.phase=2;track.count=0
		2:
			track.count+=1
			if int(track.count)&1:track.eva+=1
			else:track.evb-=1
			if int(track.eva)==16 and int(track.evb)==0:track.phase=3
		3:
			actor.apply_source_state("hidden",false)
			track.ticks=int(track.age)
	# Never reclaim a clone's material if an external owner replaced it.
	if track.node.material!=track.owned_material:return
	var material: ShaderMaterial=track.owned_material
	material.set_shader_parameter("stretch",float(track.stretch)/32.0)
	material.set_shader_parameter("horizontal",float(track.horizontal)/32.0)
	material.set_shader_parameter("phase_angle",float(track.angle))
	material.set_shader_parameter("eva",float(track.eva)/16.0)
	material.set_shader_parameter("evb",float(track.evb)/16.0)
	material.set_shader_parameter("wave_enabled",int(track.phase)<2)

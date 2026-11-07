extends RefCounted
class_name BattlePostPsychic
## Concrete Ruby private continuations and counted/uncounted child ownership.
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

static func initialize_particle(track: Dictionary, context: BattleAnimationContext, owner: Node2D) -> void:
	# Ruby sub_80DB74C overrides createsprite defaults before its first pose.
	var settings: Dictionary = track.settings
	if str(settings.get("mode",""))!="palette_wall" or str(settings.get("source_callback",""))!="sub_80DB74C":return
	var attackers: Array[BattleAnimationActor] = context.resolve("attacker")
	if not attackers.is_empty() and (attackers[0].side==0 or context.contest):
		track.source_oam_priority=2
		track.source_oam_subpriority=200
		if not settings.has("source_z_index"):
			track.node.z_index=BattleSourcePriority.relative_layer(attackers[0],200-BattleElectricContract.source_subpriority(attackers[0],context),context,owner)

static func prepare_particle(original: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Dictionary:
	var step := original.duplicate(true)
	var side: int = context.actors[context.attacker_id].side
	var a: Array = step.get("source_args",[]).duplicate()
	step.source_contest = context.contest
	if step.has("source_clamped_arg"):
		owner._source_args[int(step.source_clamped_arg.index)] = int(step.source_clamped_arg.value)
	if bool(step.get("source_stinger",false)):
		if context.contest:a[2] = -int(a[2])
		elif side!=0:
			a[1] = -int(a[1]);a[2] = -int(a[2]);a[3] = -int(a[3])
		if not context.contest and context.resolve("target")[0].side==side and context.target_ids[0]%2==0:
			a[0] = -int(a[0]);a[2] = -int(a[2])
		step.offset = [int(a[0])*(1 if side==0 else -1),a[1]]
		step.end_offset = [int(a[2])*(1 if side==0 else -1),a[3]]
		for index in a.size():owner._source_args[index] = int(a[index])&65535
	if bool(step.get("source_partner_flip",false)) and context.resolve("target")[0].side==side and context.target_ids[0]%2==0:
		step.offset[0] = -int(step.offset[0])
		step.end_offset[0] = int(step.offset[0])+int(a[2])
		owner._source_args[0] = int(step.offset[0])&65535
	if bool(step.get("mirror_vertical_by_attacker",false)) and side!=0 and not context.contest:
		step.offset[1] = -int(step.offset[1])
		owner._source_args[1] = int(step.offset[1])&65535
	if bool(step.get("opponent_x_arg1",false)) and side!=0:step.offset[0] = a[1]
	if str(step.get("mode",""))=="fog_orbit":
		step.radius = 64 if bool(step.partner_average) and context.resolve("attacker_partner" if str(step.selector)=="attacker" else "target_partner").size()>0 else 32
		step.layer_actor_z = BattleSourcePriority.actor_layer(context.resolve(str(step.selector))[0],owner)
		step.layer_field_floor = BattleSourcePriority.effective_layer(context.field)-BattleSourcePriority.effective_layer(owner)
	return step

static func particle_pose(track: Dictionary) -> void:
	var s: Dictionary = track.settings
	var age := maxi(0,int(track.age))
	var node: Sprite2D = track.node
	var direction := 1 if track.source_side==0 else -1
	match str(s.get("mode","")):
		"horn_approach":
			var duration := int(s.travel_ticks)
			var start := Vector2(40,20) if bool(s.get("source_contest",false)) else Vector2(-40*direction,20*direction)
			# Source seven-bit accumulators snap at remaining1, then delete.
			node.position = track.origin+start*(1.0-float(age)/duration) if age<duration-1 else track.origin
			node.rotation = 0.0
			node.flip_h = direction!=1 or bool(s.get("source_contest",false))
			node.flip_v = direction!=1 and not bool(s.get("source_contest",false))
		"foot_sine":
			var t := clampf(float(age)/int(s.travel_ticks),0,1)
			node.position = track.origin.lerp(track.destination,t)+Vector2(0,sin(((age*int(s.phase_advance))>>8)*TAU/256.0)*float(s.amplitude))
		"fog_orbit":
			var phase := (64+age*3)&255
			node.position = track.origin+Vector2(sin(phase*TAU/256.0)*float(s.radius),float(s.drift)*mini(age+1,int(s.travel_ticks))/int(s.travel_ticks)-cos(phase*TAU/256.0)*6)
			node.z_index = maxi(int(s.get("layer_field_floor",-4096)),int(s.layer_actor_z)+(1 if ((phase-64)&65535)<=127 else -1))
		"leaf_scatter":
			var first := mini(age,int(s.scatter_ticks))
			var tail := maxi(0,age-int(s.scatter_ticks)-1)
			var odd := int(s.scatter_velocity[1])&1
			var phase := (128 if odd else 0)+tail*2
			node.position = track.origin+Vector2(float(s.scatter_velocity[0])*first+sin(phase*TAU/256.0)*25*direction,float(s.scatter_velocity[1])*first+floorf(tail/2.0))
		"homing_needle":
			var delta: Vector2 = track.destination-track.origin
			var count := mini(age,int(s.travel_ticks))
			node.position = track.origin+Vector2(int(delta.x*16/int(s.travel_ticks))*count/16.0,int(delta.y*16/int(s.travel_ticks))*count/16.0)
			node.rotation = delta.angle()
		"splash_scatter":
			node.position = track.origin+Vector2(floorf(float(s.scatter_velocity[0])*age/256.0),floorf(float(s.scatter_velocity[1])*age/256.0))
	if bool(s.get("tangent_rotation",false)) and str(s.get("mode",""))=="linear":
		node.rotation = (track.destination-track.origin).angle()+PI/2
	if s.has("palette_cycle_count") and str(s.get("mode",""))!="palette_wall":
		var cycle := int(track.get("palette_cycle",0))%int(s.palette_cycle_count)
		node.region_rect.position.y += cycle*int(s.palette_cycle_height)

static func update_owned(track: Dictionary, owner: Node2D) -> void:
	var s: Dictionary = track.settings
	if s.has("termination_arg") and int(owner._source_args.get(int(s.termination_arg),0))==(int(s.termination_value)&65535):
		track.ticks = track.age
		if track.kind=="source_scroll" and is_instance_valid(owner._source_background):
			owner._source_background.position = Vector2.ZERO
			owner._source_background.region_rect.position = Vector2.ZERO
		return
	if track.kind=="source_scroll":
		var sign_value := -1 if bool(s.mirror_scroll) and owner.context.actors[owner.context.attacker_id].side!=0 else 1
		if is_instance_valid(owner._source_background):
			# Native tiling replaces BG3 registers; actors remain stationary.
			owner._source_background.region_rect.position.x = int(int(track.age)*int(s.scroll_velocity[0])*sign_value/256)&255
			# BG registers address the tilemap's actual row period. Legacy maps
			# have128 rows; Aeroblast BG18/19 have256 distinct rows, not repeats.
			var texture: Texture2D=owner._source_background.texture
			var row_period: int=maxi(1,texture.get_height()) if texture!=null else 128
			owner._source_background.region_rect.position.y = posmod(int(int(track.age)*int(s.scroll_velocity[1])*sign_value/256),row_period)
	else:
		for particle in owner._tracks:
			if particle.kind!="source_particle":continue
			var tag := str(particle.settings.get("source_palette_tag",""))
			if bool(s.get("palette_cycle",false)) and tag==str(s.palette_tag):particle.palette_cycle = int(track.age)/int(s.interval)
			elif tag in s.get("palette_tags",[]):
				var material: ShaderMaterial = particle.node.material as ShaderMaterial
				if material==null:
					material = ShaderMaterial.new();material.shader = load("res://scripts/battle/animations/sequence/palette_blend.gdshader");particle.node.material = material
				var phase := maxi(0,int(track.age)-1)
				material.set_shader_parameter("blend_color",Color(str(s.palette_colors[(phase/17)%s.palette_colors.size()])))
				material.set_shader_parameter("blend_amount",float(phase%17)/16.0)

static func create_owned(step: Dictionary, context: BattleAnimationContext, owner: Node2D, kind: String) -> Array[Dictionary]:
	var tracks: Array[Dictionary] = []
	for actor in context.resolve(str(step.selector)):
		if kind=="source_shadow":
			tracks.append({"kind":"actor_motion","age":0,"ticks":9,"actor":actor,"initial":Vector2.ZERO,"settings":{"motion":"shadow_dash"}})
		for index in (9 if kind=="source_shadow" else 1):
			var clone := Sprite2D.new()
			clone.texture = actor.sprite.texture;clone.hframes = actor.sprite.hframes;clone.vframes = actor.sprite.vframes;clone.frame = actor.sprite.frame
			clone.flip_h = actor.sprite.flip_h;clone.position = actor.anchor(context.field);clone.scale = actor.sprite.global_scale/context.field.global_scale
			clone.z_index = actor.sprite.z_index+1
			owner.add_child(clone)
			var material := ShaderMaterial.new()
			if kind=="source_shadow":
				material.shader = load("res://scripts/battle/animations/sequence/palette_blend.gdshader")
				material.set_shader_parameter("blend_color",Color.BLACK);material.set_shader_parameter("blend_amount",float(step.source_args[1])/16.0)
			else:
				material.shader = load("res://scripts/battle/animations/sequence/source_refresh.gdshader")
				material.set_shader_parameter("mask_texture",load(str(step.texture)))
			clone.material = material;clone.visible = false
			tracks.append({"kind":"source_shadow_clone" if kind=="source_shadow" else "source_refresh","age":-index-1 if kind=="source_shadow" else 0,"ticks":8 if kind=="source_shadow" else int(step.ticks),"node":clone,"actor_snapshot":actor,"owner":owner,"settings":step.duplicate(true),"snapshot_pending":kind=="source_shadow","child_index":index})
	return tracks

static func update_clone(track: Dictionary) -> void:
	var node: Sprite2D = track.node
	if int(track.age)<0:return
	if track.kind=="source_shadow_clone":
		if bool(track.snapshot_pending):
			var actor: BattleAnimationActor = track.actor_snapshot
			# Source snapshots current x2 before this tick's dash; anchor already owns it.
			node.position = actor.anchor(track.owner.context.field)
			track.snapshot_pending = false
		node.visible = true;node.modulate.a = 0.5
	else:
		var age := int(track.age)
		var coefficient := mini(10,age/3) if age<=30 else 10 if age<=60 else maxi(0,10-(age-60)/3)
		node.visible = true
		node.material.set_shader_parameter("amount",coefficient/16.0)
		node.material.set_shader_parameter("scroll",float(age)*416/256.0/64.0)

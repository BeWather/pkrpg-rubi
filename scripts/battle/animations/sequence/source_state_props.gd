extends RefCounted
class_name BattleStateProps
## Concrete source props and palette/alpha buffers, owned by one execution.
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

static func initialize(track: Dictionary, context: BattleAnimationContext, owner: Node2D) -> void:
	if str(track.settings.get("source_module",""))!="state_props":return
	track.prop_owner=owner
	track.prop_context=context
	track.prop_attacker=context.resolve("attacker")[0]
	if str(track.settings.mode)=="conversion_tile" and context.contest:
		track.origin.y+=10
		track.destination=track.origin
	if str(track.settings.mode)=="recycle_arrow":
		track.origin.y=maxf(float(track.settings.source_top_min),track.origin.y)
		track.destination=track.origin
		var material:=ShaderMaterial.new()
		material.shader=load("res://scripts/battle/animations/sequence/source_local_ab.gdshader")
		track.node.material=material
		track.prop_blend_material=material
	track.node.position=track.origin

static func bound_identity_present(track: Dictionary) -> bool:
	if str(track.settings.get("mode",""))!="conversion2_tile":return true
	var actor: BattleAnimationActor=track.get("prop_attacker")
	if actor!=null and actor.is_present():return true
	track.node.visible=false
	track.ticks=int(track.age)
	return false

static func frame_pose(track: Dictionary, selected: Dictionary) -> Dictionary:
	if str(track.settings.get("mode",""))=="conversion2_tile":
		return BattleSourceCommandProgram.evaluate(track.settings.frame_program,maxi(0,int(track.age)-int(track.settings.frame_pause_ticks))).frame
	return selected

static func create_control(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Array[Dictionary]:
	var track: Dictionary={"kind":"source_state_props_task","age":0,"ticks":int(step.ticks),"settings":step.duplicate(true),"update":update_control.bind(owner)}
	update_control(track,context,owner)
	return [track]

static func update_control(track: Dictionary, _context: BattleAnimationContext, owner: Node2D) -> void:
	var s: Dictionary=track.settings
	var tag:=str(s.source_palette_tag)
	var age:=int(track.age)
	if str(s.task_mode)=="conversion_alpha":
		var count:=mini(16,age/int(s.interval))
		var alpha:=int(s.alpha_start)+count*(1 if int(s.alpha_end)>int(s.alpha_start) else -1)
		var states: Dictionary=owner.get_meta("source_prop_alpha",{})
		states[tag]=alpha
		owner.set_meta("source_prop_alpha",states)
		if int(s.release_arg)>=0 and age>=65:owner._source_args[int(s.release_arg)]=int(s.release_value)
	else:
		var count:=mini(int(s.switch_count),age/int(s.interval))
		var pair: Array=s.palette_states[count%2]
		if age>=int(track.ticks)-1:pair=[0,0]
		var states: Dictionary=owner.get_meta("source_prop_palette",{})
		states[tag]={"color":int(pair[0]),"amount":int(pair[1])}
		owner.set_meta("source_prop_palette",states)
	for particle: Dictionary in owner._tracks:
		if particle.kind=="source_particle" and str(particle.settings.get("source_palette_tag",""))==tag:apply_buffers(particle,owner)

static func apply_buffers(track: Dictionary, owner: Node2D) -> void:
	var tag:=str(track.settings.get("source_palette_tag",""))
	var alphas: Dictionary=owner.get_meta("source_prop_alpha",{})
	if alphas.has(tag):track.node.modulate.a=float(alphas[tag])/16.0
	var palettes: Dictionary=owner.get_meta("source_prop_palette",{})
	if not palettes.has(tag):return
	var state: Dictionary=palettes[tag]
	var material: ShaderMaterial=track.node.material as ShaderMaterial
	if material==null:
		material=ShaderMaterial.new()
		material.shader=load("res://scripts/battle/animations/sequence/palette_blend.gdshader")
		track.node.material=material
	var value:=int(state.color)
	material.set_shader_parameter("blend_color",Color(float(value&31)/31.0,float((value>>5)&31)/31.0,float((value>>10)&31)/31.0))
	material.set_shader_parameter("blend_amount",float(state.amount)/16.0)

static func sharpen_state(age: int) -> Dictionary:
	var counter:=0
	var interval:=2
	var toggles:=0
	var visible:=true
	var visible_count:=0
	var cues: Array[int]=[]
	for tick in range(1,age+1):
		counter+=1
		if counter>=interval:
			counter=0
			visible=not visible
			if visible:
				visible_count+=1
				if visible_count%2==0:cues.append(tick)
			toggles+=1
			if toggles>1:toggles=0;interval+=1
	return {"visible":visible,"interval":interval,"cues":cues}

static func recycle_pair(age: int) -> Vector2i:
	# AnimRecycleStep alternates independent coefficients every second callback.
	if age<=64:
		var changes:=maxi(0,age/2)
		return Vector2i(mini(16,(changes+1)/2),maxi(0,16-changes/2))
	if age<=74:return Vector2i(16,0)
	var changes:=maxi(0,(age-74)/2)
	return Vector2i(maxi(0,16-(changes+1)/2),mini(16,changes/2))

static func particle_pose(track: Dictionary) -> void:
	var s: Dictionary=track.settings
	if str(s.get("source_module",""))!="state_props":return
	var owner: Node2D=track.prop_owner
	var age:=maxi(0,int(track.age))
	var node: Sprite2D=track.node
	match str(s.mode):
		"conversion_tile":
			if int(owner._source_args.get(7,0))==65535:
				node.visible=false
				track.ticks=age
		"sword_rise":
			var phase:=clampf(float(age-int(s.affine_hold_ticks))/int(s.travel_ticks),0.0,1.0)
			node.position=track.origin+Vector2(0,-float(s.rise)*phase)
		"sharpen_cube":
			var state: Dictionary=sharpen_state(age)
			node.visible=state.visible
			var emitted:=int(track.get("prop_cues",0))
			while emitted<state.cues.size():
				owner._play_sound(str(s.callback_cue_path),"SOUND_PAN_ATTACKER")
				emitted+=1
			track.prop_cues=emitted
			if bool(BattleSourceCommandProgram.evaluate(s.frame_program,age).ended) and int(state.interval)>16 and not node.visible:track.ticks=age
		"conversion2_tile":
			var phase:=maxi(0,age-int(s.travel_delay))
			if age>=int(s.travel_delay) and not track.get("prop_travel_started",false):
				track.destination=track.prop_attacker.anchor(track.prop_context.field)
				track.prop_travel_started=true
			node.position=track.origin.lerp(track.destination,clampf(float(phase)/int(s.travel_ticks),0.0,1.0))
			node.modulate.a=0.0
		"recycle_arrow":
			var pair:=recycle_pair(age)
			var material: ShaderMaterial=track.prop_blend_material
			# Never reclaim an external replacement or mutate its parameters.
			if node.material==material:
				node.modulate.a=1.0
				material.set_shader_parameter("eva",float(pair.x)/16.0)
				material.set_shader_parameter("evb",float(pair.y)/16.0)
	apply_buffers(track,owner)

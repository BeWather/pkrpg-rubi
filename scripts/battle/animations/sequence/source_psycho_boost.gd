extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Source psychic.c state machine; shared normal-fade clock selects only BG1/2/3.
const NormalFade=preload("res://scripts/battle/animations/sequence/source_tail_glow.gd")
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if s.behavior=="source_boost_monbg":return BattleCounterSelected.create(s,c,owner)
	var t: Dictionary={"kind":str(s.behavior),"settings":s,"owner":owner,"age":0,"ticks":int(s.ticks),"update":advance}
	if s.behavior=="source_boost_palette":t.phase=0;t.elapsed=0;_fade(t,0,10);return [t]
	var actors: Array[BattleAnimationActor]=c.resolve("attacker")
	if actors.is_empty():return []
	var node:=Sprite2D.new();node.texture=load(str(s.texture));owner.add_child(node);BattleCounterSelected._blend_node(node,owner);node.material.shader=load("res://scripts/battle/animations/sequence/source_boost_light.gdshader")
	t.node=node;t.original_actor=actors[0];t.origin=Geometry._anchor(actors[0],c,owner,"origin")+Vector2(0,12 if c.contest else 0);node.position=t.origin;t.eva=8;t.accumulator=0;t.y_offset=0;BattleSourcePriority.initialize(t,c,owner);_pose(t,Vector2(32,32));_alpha(t,c,8);return [t]
static func _fade(t: Dictionary,from: int,to: int) -> void:
	t.amount=from;t.destination=to;t.obj_half=true;t.delay_counter=0;t.finishing=-1;NormalFade._paint(t)
static func _pose(t: Dictionary,matrix: Vector2) -> void:t.node.material.set_shader_parameter("source_scale",matrix/256.0)
static func _alpha(t: Dictionary,_c: BattleAnimationContext,eva: int) -> void:
	# BLDCNT0x3F40 has no BG first target: semi-transparent light OBJ only.
	# Ordinary CounterSelected monbg clones have no material and stay opaque.
	t.node.material.set_shader_parameter("eva",float(eva)/16.0)
	t.node.material.set_shader_parameter("evb",float(16-eva)/16.0)
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	var age: int=int(t.age)
	if t.kind=="source_boost_palette":
		t.elapsed=int(t.elapsed)+1
		if int(t.elapsed)==27:
			t.phase=int(t.phase)+1;t.elapsed=0
			if int(t.phase)<8:_fade(t,10 if int(t.phase)%2 else 0,0 if int(t.phase)%2 else 10)
		else:NormalFade.advance(t,c)
		return
	if age<=198:
		var pose: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.affine_program,mini(age,197),true);_pose(t,pose.matrix)
	elif age<224:
		if age==199:t.owner._play_sound(str(t.settings.source_callback_sound_assets.SE_M_TELEPORT),"SOUND_PAN_ATTACKER")
		# ChangeSpriteAffineAnim retains304/304, unlike StartSpriteAffineAnim.
		var elapsed: int=mini(age-198,15);_pose(t,Vector2(304-20*elapsed,304+24*elapsed))
		if age>=200:
			t.accumulator=int(t.accumulator)+896;t.y_offset=int(t.y_offset)-(int(t.accumulator)>>8);t.accumulator=int(t.accumulator)&255;t.node.position=t.origin+Vector2(0,int(t.y_offset))
			if (age-199)%3==0:t.eva=int(t.eva)-1;_alpha(t,c,int(t.eva))
			if int(t.eva)==0:t.node.visible=false
	else:BattleCounterSelected.create({"mode":"blend_off"},c,t.owner)

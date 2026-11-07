extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Actual angel_kiss.c (despite its comment) and devil.c source continuations.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var actors: Array[BattleAnimationActor]=c.resolve("attacker");var targets: Array[BattleAnimationActor]=c.resolve("target")
	if actors.is_empty() or targets.is_empty():return []
	var origin: Vector2=Geometry._anchor(targets[0],c,owner,"center")
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;owner.add_child(node)
	var t: Dictionary={"kind":str(step.behavior),"settings":step.duplicate(true),"owner":owner,"original_actor":actors[0],"original_target":targets[0],"node":node,"origin":origin,"initial_origin":origin,"age":0,"ticks":4096,"qx":0,"phase":0,"stage":"fountain","fall_origin":origin,"fall_phase":0,"fall_count":0,"counter":0,"orbit":0,"direction":1,"update":advance}
	if t.kind=="source_lovely_devil":
		t.origin+=Vector2(step.source_args[0],step.source_args[1]);_devil(t)
	else:node.position=origin # Constructor consumes init-only fountain callback.
	BattleSourcePriority.initialize(t,c,owner)
	if t.kind=="source_lovely_devil":
		t.source_oam_subpriority=BattleElectricContract.source_subpriority(targets[0],c)-1;node.z_index=BattleSourcePriority.relative_layer(targets[0],-1,c,owner)
	_pose(t)
	return [t]
static func _pose(t: Dictionary) -> void:
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.frame_program,int(t.age)).frame
	var rect: Array=t.settings.frame_rects[str(int(frame.tile))];t.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3])
static func _random(t: Dictionary,c: BattleAnimationContext) -> int:
	# One source-LCG visual stream per execution, shared by the four children.
	# This is not synchronization with Ruby's world/global battle RNG state.
	var state: int=int(t.owner.get_meta("source_lovely_rng",c.seed_value&4294967295))
	state=(1103515245*state+24691)&4294967295;t.owner.set_meta("source_lovely_rng",state)
	return state>>16
static func _pink(t: Dictionary,c: BattleAnimationContext) -> void:
	if str(t.stage)=="fountain":
		t.qx=((int(t.qx)+int(t.settings.source_args[0])+32768)&65535)-32768
		t.node.position=t.origin+Vector2(int(t.qx)>>8,BattleSourceTrig.sine(int(t.phase),int(t.settings.source_args[1])))
		t.phase=(int(t.phase)+3)&255
		if int(t.phase)>70:
			t.stage="fall";t.fall_origin=t.node.position;t.phase=_random(t,c)%180;t.fall_phase=int(t.phase)
	else:
		t.fall_count=int(t.fall_count)+1
		t.node.position=t.fall_origin+Vector2(BattleSourceTrig.sine(int(t.phase),5),int(int(t.fall_count)/2));t.phase=(int(t.phase)+3)&255
		if int(t.fall_count)>20:t.node.visible=int(t.fall_count)%2==0
		if int(t.fall_count)>30:t.ticks=int(t.age)
static func _devil(t: Dictionary) -> void:
	t.orbit=int(t.orbit)+int(t.direction);var phase: int=maxi(0,(int(t.orbit)*4)%256)
	t.node.position=t.origin+Vector2(BattleSourceTrig.cosine(phase,30-int(int(t.orbit)/4)),BattleSourceTrig.sine(phase,10-int(int(t.orbit)/8)))
	if phase>128 and int(t.direction)>0:t.direction=-1
	if phase==0 and int(t.direction)<0:t.direction=1
	t.counter=int(t.counter)+1;t.node.visible=int(t.orbit)%2==0 if int(t.counter)<10 or int(t.counter)>80 else true
	if int(t.counter)>90:t.ticks=int(t.age)
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if c.actors.get(t.original_actor.id)!=t.original_actor or c.actors.get(t.original_target.id)!=t.original_target or not t.original_actor.is_present() or not t.original_target.is_present():t.ticks=int(t.age);return
	if t.kind=="source_lovely_devil":_devil(t)
	else:_pink(t,c)
	_pose(t)

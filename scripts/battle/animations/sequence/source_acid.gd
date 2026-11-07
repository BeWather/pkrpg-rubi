extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## poison.c:218–241 and273–289, including source splash duration-as-y-delta.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
const PackedMotion=preload("res://scripts/battle/animations/sequence/source_sports.gd")
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var attackers: Array[BattleAnimationActor]=c.resolve("attacker");var targets: Array[BattleAnimationActor]=c.resolve("target");var a: Array=step.get("source_args",[])
	var arc: bool=str(step.get("mode",""))=="arc"
	if attackers.is_empty() or targets.is_empty() or a.size()!=(6 if arc else 5):return []
	if str(step.get("source_callback",""))!=("sub_80D9DF0" if arc else "sub_80D9F14"):return []
	var actor: BattleAnimationActor=attackers[0];var target: BattleAnimationActor=targets[0];var direction: int=1 if actor.side==0 else -1
	var average: Vector2=Geometry._average(target,c,owner,"center","air_wave")
	var origin: Vector2=(Geometry._anchor(actor,c,owner,"center") if arc else average)+Vector2(int(a[0])*direction,int(a[1]))
	var duration: int=int(a[2] if arc else a[4])
	# sub_80D9F14 uses data[0] (duration) for destinationY, not argument3.
	var destination: Vector2=average+Vector2(int(a[4])*direction,int(a[5])) if arc else origin+Vector2(int(a[2]),duration)
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;owner.add_child(node)
	var t: Dictionary={"kind":"source_acid","mode":"arc" if arc else "splash","settings":step.duplicate(true),"owner":owner,"node":node,"original_actor":actor,"original_target":target,"args":a.duplicate(),"origin":origin,"destination":destination,"age":0,"ticks":4096,"stage":0,"remaining":duration,"acc_x":0,"acc_y":0,"offset":Vector2.ZERO,"update":advance}
	if arc:PackedMotion._arc(t,destination,duration,-30)
	else:t.vx=PackedMotion._delta(int(destination.x-origin.x),duration);t.vy=PackedMotion._delta(int(destination.y-origin.y),duration)
	node.position=origin;BattleSourcePriority.initialize(t,c,owner);_pose(t)
	return [t]
static func _pose(t: Dictionary) -> void:
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.frame_program,int(t.age)).frame
	var rect: Array=t.settings.frame_rects[str(int(frame.tile))]
	t.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);t.node.flip_h=bool(frame.get("flip_h",false));t.node.flip_v=bool(frame.get("flip_v",false))
	var pose: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.affine_program,int(t.age),true)
	t.node.scale=Vector2(256.0/float(pose.matrix.x),256.0/float(pose.matrix.y))
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if c.actors.get(t.original_actor.id)!=t.original_actor or c.actors.get(t.original_target.id)!=t.original_target or not t.original_actor.is_present() or not t.original_target.is_present():t.ticks=int(t.age);return
	if t.mode=="arc":
		if PackedMotion._translate(t):t.ticks=int(t.age);return
		t.node.position=t.origin+t.offset
	else:
		if int(t.stage)==1:t.ticks=int(t.age);return
		if int(t.remaining)==0:t.stage=1;return # Stored destroy on following callback.
		t.acc_x=(int(t.acc_x)+int(t.vx))&65535;t.acc_y=(int(t.acc_y)+int(t.vy))&65535;t.remaining=int(t.remaining)-1
		t.node.position=t.origin+Vector2((int(t.acc_x)>>8)*(-1 if int(t.vx)&1 else 1),(int(t.acc_y)>>8)*(-1 if int(t.vy)&1 else 1))
	_pose(t)

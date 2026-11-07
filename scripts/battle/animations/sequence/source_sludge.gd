extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## poison.c:195–216 selected arcs;245–271 decelerating fragments;298–326 bubbles.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
const PackedMotion=preload("res://scripts/battle/animations/sequence/source_sports.gd")
static func _signed(value: int) -> int:return ((value+32768)&65535)-32768
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var attackers: Array[BattleAnimationActor]=c.resolve("attacker");var targets: Array[BattleAnimationActor]=c.resolve("target");var a: Array=step.get("source_args",[])
	var mode: String=str(step.get("mode",""));var expected: String={"arc":"sub_80D9D70","fragment":"sub_80D9E94","bubble":"AnimBubbleEffect"}.get(mode,"")
	if attackers.is_empty() or targets.is_empty() or expected.is_empty() or str(step.get("source_callback",""))!=expected or a.size()!=(4 if mode=="arc" else 3):return []
	var actor: BattleAnimationActor=attackers[0];var target: BattleAnimationActor=targets[0];var direction: int=1 if actor.side==0 else -1
	var origin: Vector2=Geometry._anchor(actor if mode=="arc" else target,c,owner,"center")
	if mode!="fragment":origin+=Vector2(int(a[0])*direction,int(a[1]))
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;node.position=origin;owner.add_child(node)
	var t: Dictionary={"kind":"source_sludge","mode":mode,"settings":step.duplicate(true),"owner":owner,"node":node,"original_actor":actor,"original_target":target,"args":a.duplicate(),"origin":origin,"age":0,"ticks":4096,"acc_x":0,"acc_y":0,"update":advance}
	if mode=="arc":PackedMotion._arc(t,Geometry._anchor(target,c,owner,"center"),int(a[2]),-30)
	elif mode=="fragment":
		t.remaining=int(a[2]);t.vx=int(_signed(int(a[0])<<8)/int(a[2]));t.vy=int(_signed(int(a[1])<<8)/int(a[2]))
		t.initial_vx=t.vx;t.initial_vy=t.vy;t.deceleration_x=int(int(t.vx)/int(a[2]));t.deceleration_y=int(int(t.vy)/int(a[2]))
	else:t.ticks=int(step.source_affine_ticks)+1
	BattleSourcePriority.initialize(t,c,owner);_pose(t)
	return [t]
static func _pose(t: Dictionary) -> void:
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.frame_program,int(t.age)).frame
	var rect: Array=t.settings.frame_rects[str(int(frame.tile))]
	t.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);t.node.flip_h=bool(frame.get("flip_h",false));t.node.flip_v=bool(frame.get("flip_v",false))
	var pose: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.affine_program,int(t.age),true)
	t.node.scale=Vector2(256.0/float(pose.matrix.x),256.0/float(pose.matrix.y))
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if c.actors.get(t.original_actor.id)!=t.original_actor or c.actors.get(t.original_target.id)!=t.original_target or not t.original_actor.is_present() or not t.original_target.is_present():t.ticks=int(t.age);return
	match t.mode:
		"arc":
			if PackedMotion._translate(t):t.ticks=int(t.age);return
			t.node.position=t.origin+t.offset
		"fragment":
			t.remaining=int(t.remaining)-1;t.acc_x=_signed(int(t.acc_x)+int(t.vx));t.acc_y=_signed(int(t.acc_y)+int(t.vy))
			t.node.position=t.origin+Vector2(int(t.acc_x)>>8,int(t.acc_y)>>8)
			t.vx=_signed(int(t.vx)-int(t.deceleration_x));t.vy=_signed(int(t.vy)-int(t.deceleration_y))
			if int(t.remaining)==0:t.ticks=int(t.age)
		"bubble":t.node.position=t.origin+Vector2(BattleSourceTrig.sine((int(t.age)*11)&255,4),-((int(t.age)*48)>>8))
	_pose(t)

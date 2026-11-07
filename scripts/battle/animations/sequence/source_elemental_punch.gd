extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Actual fist wait, shared fire/ice shrinking spiral, and signed Q8 ember drift.
const ROOTS={"fist":["AnimBasicFistOrFoot"],"spiral":["sub_80D4ED8","AnimIcePunchSwirlingParticle"],"ember":["sub_80D4F18"]}
static func s16(value: int) -> int:return ((value+32768)&65535)-32768
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var attackers: Array[BattleAnimationActor]=c.resolve("attacker");var targets: Array[BattleAnimationActor]=c.resolve("target")
	if attackers.is_empty() or targets.is_empty():return []
	var a: Array=step.source_args.duplicate();var mode: String=str(step.mode)
	if not ROOTS.has(mode) or str(step.get("source_callback","")) not in ROOTS[mode] or a.size()!=(1 if mode=="spiral" else 5):return []
	var attacker: BattleAnimationActor=attackers[0];var target: BattleAnimationActor=targets[0]
	var origin: Vector2=BattleElectricContract.source_anchor(target,c,"center")
	var direction: int=BattleElectricContract.source_offset_direction(c,attacker,target)
	if mode=="fist":
		if int(a[3])==0:origin=BattleElectricContract.source_anchor(attacker,c,"center")
		origin+=Vector2(int(a[0])*direction,int(a[1]))
	elif mode=="ember":origin+=Vector2(int(a[0])*direction,int(a[1]))
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;node.position=origin;owner.add_child(node)
	var t: Dictionary={"kind":"source_elemental_punch","settings":step.duplicate(true),"owner":owner,"node":node,"age":0,"ticks":4096,"update":advance,"args":a,"origin":origin,"attacker":attacker,"target":target,"remaining":30 if mode=="spiral" else int(a[2] if mode=="fist" else a[4]),"angle":int(a[0]) if mode=="spiral" else 0,"qx":0,"qy":0,"terminal":false}
	BattleSourcePriority.initialize(t,c,owner)
	if mode=="spiral":_spiral(t) # Initializer calls the shared helper immediately.
	_pose(t)
	return [t]
static func _spiral(t: Dictionary) -> void:
	var radius: int=(int(t.qx)>>8)+60
	t.node.position=t.origin+Vector2(BattleSourceTrig.sine(int(t.angle),radius),BattleSourceTrig.cosine(int(t.angle),radius))
	t.angle=s16(int(t.angle)+9)
	if int(t.angle)>=256:t.angle=int(t.angle)-256
	elif int(t.angle)<0:t.angle=int(t.angle)+256
	t.qx=s16(int(t.qx)-512);t.remaining=int(t.remaining)-1
static func _pose(t: Dictionary) -> void:
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.frame_program,int(t.age)).frame
	var rect: Array=t.settings.frame_rects[str(int(frame.tile))]
	t.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);t.node.flip_h=bool(frame.get("flip_h",false));t.node.flip_v=bool(frame.get("flip_v",false))
	var pose: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.affine_program,int(t.age),true)
	t.node.scale=Vector2(256.0/maxf(1,float(pose.matrix.x)),256.0/maxf(1,float(pose.matrix.y)))
	t.node.rotation=-float(pose.rotation)*TAU/256.0
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if not t.attacker.is_present() or not t.target.is_present():t.ticks=int(t.age);return
	if int(t.remaining)>0:
		match str(t.settings.mode):
			"spiral":_spiral(t)
			"ember":
				t.qx=s16(int(t.qx)+int(t.args[2]));t.qy=s16(int(t.qy)+int(t.args[3]));t.node.position=t.origin+Vector2(int(t.qx)>>8,int(t.qy)>>8);t.remaining=int(t.remaining)-1
			"fist":t.remaining=int(t.remaining)-1
	elif not bool(t.terminal):t.terminal=true # SetCallbackToStoredInData.
	else:t.ticks=int(t.age) # DestroyAnimSprite on the following callback.
	_pose(t)

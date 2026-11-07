extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Ruby sleep.c:73–102: actor-centered Z, signed drift, accelerating rise,61 callbacks.
static func s16(value: int) -> int:return ((value+32768)&65535)-32768
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var actors: Array[BattleAnimationActor]=c.resolve("attacker")
	if actors.is_empty() or str(step.get("source_callback",""))!="sub_80CD328" or step.get("source_args",[]).size()!=5:return []
	var actor: BattleAnimationActor=actors[0];var a: Array=step.source_args
	var side: int=0 if actor.side==0 else 1
	var origin: Vector2=BattleElectricContract.source_anchor(actor,c,"center")+Vector2(int(a[0])*(1 if side==0 else -1),int(a[1]))
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;node.position=origin;owner.add_child(node)
	var t: Dictionary={"kind":"source_sleep_z","settings":step.duplicate(true),"owner":owner,"node":node,"original_actor":actor,"origin":origin,"direction":1 if side==0 else -1,"age":0,"ticks":61,"count":0,"rise":0,"drift":0,"affine":step.source_affine_variants[str(side)],"update":advance}
	BattleSourcePriority.initialize(t,c,owner);_pose(t)
	return [t]
static func _pose(t: Dictionary) -> void:
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.frame_program,int(t.age)).frame
	var rect: Array=t.settings.frame_rects[str(int(frame.tile))]
	t.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3])
	var pose: Dictionary=BattleSourceCommandProgram.evaluate(t.affine,int(t.age),true)
	t.node.scale=Vector2(256.0/maxf(1,float(pose.matrix.x)),256.0/maxf(1,float(pose.matrix.y)))
	t.node.rotation=-float(pose.rotation)*TAU/256.0
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if c.actors.get(t.original_actor.id)!=t.original_actor or not t.original_actor.is_present():t.node.visible=false;t.ticks=int(t.age);return
	# C signed division truncates toward zero, not arithmetic shift/floor.
	t.node.position=t.origin+Vector2(int(int(t.drift)/10),-int(int(t.rise)/40))
	t.drift=s16(int(t.drift)+int(t.direction)*2)
	t.rise=s16(int(t.rise)+int(t.count));t.count=int(t.count)+1
	if int(t.count)>60:t.ticks=int(t.age)
	_pose(t)

extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## guard.c:45–70, then StartAnimLinearTranslation's packed-Q8 continuation.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var actors: Array[BattleAnimationActor]=c.resolve("attacker")
	if actors.is_empty() or str(step.get("source_callback",""))!="sub_80D3014":return []
	var original: BattleAnimationActor=actors[0]
	var origin: Vector2=BattleElectricContract.source_anchor(original,c,"origin")
	var partner: BattleAnimationActor=Geometry._partner(original,c) if Geometry._is_double(c) else null
	var double_ring: bool=partner!=null
	if double_ring:
		var other: Vector2=BattleElectricContract.source_anchor(partner,c,"origin")
		origin=Vector2(int((origin.x+other.x)/2),int((origin.y+other.y)/2))
	origin.y+=40
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;node.position=origin;owner.add_child(node)
	var t: Dictionary={"kind":"source_guard_ring","settings":step.duplicate(true),"owner":owner,"original_actor":original,"origin":origin,"node":node,"age":0,"ticks":4096,"remaining":13,"acc_y":0,"vy":(int((72<<8)/13)|1),"stage":0,"double_ring":double_ring,"update":advance}
	BattleSourcePriority.initialize(t,c,owner);BattleCounterSelected._blend_node(node,owner);_pose(t)
	return [t]
static func _pose(t: Dictionary) -> void:
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.frame_program,int(t.age)).frame
	var rect: Array=t.settings.frame_rects[str(int(frame.tile))]
	t.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);t.node.flip_h=bool(frame.get("flip_h",false));t.node.flip_v=bool(frame.get("flip_v",false))
	var program: Array=t.settings.source_affine_variants["1" if t.double_ring else "0"]
	var pose: Dictionary=BattleSourceCommandProgram.evaluate(program,int(t.age),true)
	t.node.scale=Vector2(256.0/float(pose.matrix.x),256.0/float(pose.matrix.y))
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if c.actors.get(t.original_actor.id)!=t.original_actor or not t.original_actor.is_present():t.ticks=int(t.age);return
	if int(t.stage)==1:t.ticks=int(t.age);return # Stored DestroyAnimSprite on next callback.
	if int(t.remaining)==0:t.stage=1;return # TranslateAnimLinearUntil switches callback.
	t.acc_y=(int(t.acc_y)+int(t.vy))&65535;t.remaining=int(t.remaining)-1
	t.node.position=t.origin+Vector2(0,-(int(t.acc_y)>>8));_pose(t)

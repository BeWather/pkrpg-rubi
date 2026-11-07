extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## heart_1.c:27: initialize on first callback, then sine8 / signed Q8 rise /60.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var actors: Array[BattleAnimationActor]=c.resolve("attacker");var targets: Array[BattleAnimationActor]=c.resolve("target")
	if actors.is_empty() or targets.is_empty():return []
	var actor: BattleAnimationActor=actors[0];var a: Array=step.source_args
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;owner.add_child(node)
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(step.frame_program,0).frame
	var rect: Array=step.frame_rects[str(int(frame.tile))];node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3])
	var origin: Vector2=Geometry._anchor(actor,c,owner,"center")+Vector2(int(a[0])*BattleElectricContract.source_offset_direction(c,actor,targets[0]),int(a[1]))
	var t: Dictionary={"kind":"source_magenta_heart","settings":step.duplicate(true),"owner":owner,"original_actor":actor,"node":node,"origin":origin,"age":0,"ticks":60,"update":advance}
	# createsprite initially places the uninitialized sprite at the target center.
	node.position=Geometry._anchor(targets[0],c,owner,"center");BattleSourcePriority.initialize(t,c,owner)
	return [t]
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if c.actors.get(t.original_actor.id)!=t.original_actor or not t.original_actor.is_present():t.ticks=int(t.age);return
	var callback: int=int(t.age)-1
	t.node.position=t.origin+Vector2(BattleSourceTrig.sine((callback*7)&255,8),(-callback*128)>>8)

extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Source paw callback uses absolute screen coordinates, never actor-facing mirroring.
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var a: Array=s.source_args;var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;var rect: Array=s.frame_rects["0"];node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);owner.add_child(node)
	var t: Dictionary={"kind":"source_assist_paw","settings":s,"owner":owner,"node":node,"age":0,"ticks":38,"update":advance,"origin":Vector2(a[0],a[1]),"destination":Vector2(a[2],a[3]),"qx":0,"qy":0,"vx":_velocity(int(a[2])-int(a[0])),"vy":_velocity(int(a[3])-int(a[1]))}
	node.position=t.origin;BattleSourcePriority.initialize(t,c,owner);return [t]
static func _velocity(distance: int) -> int:
	var value: int=(absi(distance)<<4)/36
	return value|1 if distance<0 else value&~1
static func advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	# First subsequent callback initializes Q4 and calls the mover synchronously.
	# The zero-duration transfer and stored Destroy callback each keep one frame.
	if int(t.age)>36:return
	t.qx=(int(t.qx)+int(t.vx))&65535;t.qy=(int(t.qy)+int(t.vy))&65535;t.node.position=t.origin+Vector2((int(t.qx)>>4)*(-1 if int(t.vx)&1 else 1),(int(t.qy)>>4)*(-1 if int(t.vy)&1 else 1))

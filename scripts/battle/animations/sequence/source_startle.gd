extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Source curtain window and fixed-point sweat callbacks; presentation only.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if str(step.behavior)=="source_fake_curtain":
		var node:=Node2D.new();node.z_index=0;owner.add_child(node)
		for i: int in 2:
			var polygon:=Polygon2D.new();polygon.color=Color.BLACK;node.add_child(polygon)
		return [{"kind":"source_fake_curtain","settings":step.duplicate(true),"owner":owner,"node":node,"age":0,"ticks":4096,"left":0,"right":152 if c.contest else 240,"closed":false,"hold":0,"update":advance}]
	var targets: Array[BattleAnimationActor]=c.resolve("target" if int(step.source_args[1]) else "attacker")
	if targets.is_empty():return []
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;owner.add_child(node)
	var state: int=int(owner.get_meta("source_startle_rng",c.seed_value&4294967295))
	state=(1103515245*state+24691)&4294967295;var x: int=(state>>16)&511
	state=(1103515245*state+24691)&4294967295;var y: int=(state>>16)&127;owner.set_meta("source_startle_rng",state)
	var vx: int=736+x if x&1 else 736-x;var vy: int=896+y if y&1 else 896-y
	var origin: Vector2=Geometry._anchor(targets[0],c,owner,"origin")+Vector2(0,32)
	var t: Dictionary={"kind":"source_astonish_sweat","settings":step.duplicate(true),"owner":owner,"node":node,"origin":origin,"age":0,"ticks":31,"side":int(step.source_args[0]),"vx":vx,"vy":vy,"initial_vy":vy,"x":0,"y":0,"update":advance}
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(step.frame_program,0).frame
	var rect: Array=step.frame_rects[str(int(frame.tile))];node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);node.flip_h=int(t.side)!=0;node.position=origin
	BattleSourcePriority.initialize(t,c,owner)
	return [t]
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if t.kind=="source_astonish_sweat":
		t.x=int(t.x)+(int(t.vx)>>8)*(-1 if int(t.side) else 1);t.y=int(t.y)-(int(t.vy)>>8);t.vy=int(t.vy)-32
		t.node.position=t.origin+Vector2(t.x,t.y)
		return
	if not t.closed:
		t.left=int(t.left)+13;t.right=int(t.right)-13
		if int(t.left)>=int(t.right):t.closed=true
		var size: Vector2=c.field_size;var left: float=size.x*(int(t.left)/240.0);var right: float=size.x*(int(t.right)/240.0)
		var a: Polygon2D=t.node.get_child(0);var b: Polygon2D=t.node.get_child(1)
		a.polygon=PackedVector2Array([Vector2.ZERO,Vector2(left,0),Vector2(left,size.y),Vector2(0,size.y)])
		b.polygon=PackedVector2Array([Vector2(right,0),Vector2(size.x,0),size,Vector2(right,size.y)])
	else:
		t.hold=int(t.hold)+1
		if int(t.hold)==5:t.owner._source_palette({"age":0,"settings":{"blend_start":16,"blend_end":16,"blend_delay":1,"color":"ffffff"}})
		elif int(t.hold)>5:t.ticks=int(t.age)

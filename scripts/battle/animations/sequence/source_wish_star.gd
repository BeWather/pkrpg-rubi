extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Source main AnimSprite and plain child Sprite lifetimes remain independent.
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var actors: Array[BattleAnimationActor]=c.resolve("attacker")
	if actors.is_empty():return []
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;owner.add_child(node)
	var t: Dictionary={"kind":"source_wish_star","settings":step,"owner":owner,"node":node,"original_actor":actors[0],"age":0,"ticks":4096,"created":0,"qx":0,"qy":0,"dy":0,"direction":-1 if actors[0].side==0 else 1,"update":advance}
	node.position=Vector2(256 if actors[0].side==0 else -16,0);t.origin=node.position
	BattleSourcePriority.initialize(t,c,owner);_frame(t,0);return [t]
static func _frame(t: Dictionary,tile: int) -> void:
	var rect: Array=t.settings.frame_rects[str(tile)];t.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3])
static func _random(t: Dictionary,c: BattleAnimationContext) -> int:
	var value: int=int(t.owner.get_meta("source_wish_rng",c.seed_value&4294967295))
	value=(1103515245*value+24691)&4294967295;t.owner.set_meta("source_wish_rng",value);return value>>16
static func _trail(parent: Dictionary,c: BattleAnimationContext) -> void:
	var settings: Dictionary=parent.settings.child;var node:=Sprite2D.new();node.texture=load(str(settings.texture));node.region_enabled=true;parent.owner.add_child(node)
	var tile: int=4 if (_random(parent,c)&3)==0 else 5;var y: int=_random(parent,c)&7
	node.position=parent.node.position+Vector2(0,-y if y>3 else y);node.z_index=BattleSourcePriority.relative_layer(parent.original_actor,0,c,parent.owner)
	# Child source subpriority is parent+1 (lower visual OBJ order).
	node.z_index=int(parent.node.z_index)-1
	var t: Dictionary={"kind":"source_wish_trail","domain":"maintenance","settings":settings,"owner":parent.owner,"node":node,"age":1,"ticks":61,"tile":tile,"counter":0,"update":advance,"source_oam_subpriority":int(parent.get("source_oam_subpriority",0))+1}
	_frame(t,tile);_blink(t);parent.owner._tracks.append(t)
static func _blink(t: Dictionary) -> void:
	if int(t.age)<30:
		t.counter=int(t.counter)+1
		if int(t.counter)==2:t.node.visible=not t.node.visible;t.counter=0
	else:
		if int(t.counter)==2:t.node.visible=true
		if int(t.counter)==3:t.node.visible=false;t.counter=-1
		t.counter=int(t.counter)+1
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if t.kind=="source_wish_trail":_blink(t);return
	if not t.original_actor.is_present():t.ticks=int(t.age);return
	t.qx=int(t.qx)+72;t.qy=int(t.qy)+16;t.dy=int(t.dy)+(int(t.qy)>>8)
	t.node.position=t.origin+Vector2(int(t.direction)*(int(t.qx)>>4),int(t.dy))
	if int(t.age)%3==0:t.created=int(t.created)+1;_trail(t,c)
	var x: int=int(t.node.position.x)+32
	if x<0 or x>304:t.ticks=int(t.age)

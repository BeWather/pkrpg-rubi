extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Source rain task spawns plain sprites; Sun keeps its distinct packed affine path.
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if str(step.behavior)=="source_rain_task":
		var task: Dictionary={"kind":"source_rain_task","settings":step,"owner":owner,"age":0,"ticks":4096,"counter":0,"created":0,"update":advance}
		_rain(task,c);return [task]
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;owner.add_child(node);BattleCounterSelected._blend_node(node,owner)
	var t: Dictionary={"kind":"source_sun_orb","settings":step,"owner":owner,"node":node,"age":0,"ticks":62,"update":advance}
	BattleSourcePriority.initialize(t,c,owner);_sun(t);return [t]
static func _random(t: Dictionary,c: BattleAnimationContext) -> int:
	var value: int=int(t.owner.get_meta("source_rain_rng",c.seed_value&4294967295));value=(1103515245*value+24691)&4294967295;t.owner.set_meta("source_rain_rng",value);return value>>16
static func _frame(t: Dictionary,age: int) -> void:
	var program: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.frame_program,age)
	var rect: Array=t.settings.frame_rects[str(int(program.frame.tile))];t.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3])
static func _rain(t: Dictionary,c: BattleAnimationContext) -> void:
	t.counter=int(t.counter)+1
	if int(t.counter)%int(t.settings.source_args[1])==1:
		var step: Dictionary=t.settings.child;var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;t.owner.add_child(node)
		node.position=Vector2(_random(t,c)%240,_random(t,c)%80)
		var actors: Array[BattleAnimationActor]=c.resolve("attacker")
		if not actors.is_empty():node.z_index=BattleSourcePriority.relative_layer(actors[0],4-BattleElectricContract.source_subpriority(actors[0],c),c,t.owner)
		var child: Dictionary={"kind":"source_rain_drop","domain":"maintenance","settings":step,"owner":t.owner,"node":node,"origin":node.position,"age":0,"ticks":19,"source_oam_subpriority":4,"update":advance}
		_frame(child,0);t.owner._tracks.append(child);t.created=int(t.created)+1
	if int(t.counter)==int(t.settings.source_args[2]):t.ticks=int(t.age)
static func _sun(t: Dictionary) -> void:
	var n: int=mini(int(t.age),60);t.node.position=Vector2((596*n)>>8,(340*n)>>8)
	var affine: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.affine_program,int(t.age),true)
	t.node.scale=Vector2(256.0/affine.matrix.x,256.0/affine.matrix.y);t.node.rotation=-float(affine.rotation)*TAU/256.0;_frame(t,0)
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if t.kind=="source_rain_task":_rain(t,c)
	elif t.kind=="source_rain_drop":t.node.position=t.origin+Vector2(mini(int(t.age),13),4*mini(int(t.age),13));_frame(t,int(t.age))
	else:_sun(t)

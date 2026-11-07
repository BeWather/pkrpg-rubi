extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Normal fade alternates BG/OBJ halves; only BG1/2/3 are selected here.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if s.behavior=="source_tail_monbg":return BattleCounterSelected.create(s,c,owner)
	var t: Dictionary={"kind":str(s.behavior),"settings":s,"owner":owner,"age":0,"ticks":int(s.ticks),"update":advance}
	if s.behavior=="source_tail_palette":
		t.amount=int(s.source_args[2]);t.destination=int(s.source_args[3]);t.obj_half=true;t.delay_counter=0;t.finishing=-1;_paint(t);return [t]
	var actors: Array[BattleAnimationActor]=c.resolve("attacker")
	if actors.is_empty():return []
	var node:=Sprite2D.new();node.texture=load(str(s.texture));owner.add_child(node);BattleCounterSelected._blend_node(node,owner)
	t.node=node;t.original_actor=actors[0];t.origin=Geometry._anchor(actors[0],c,owner,"center");node.position=t.origin+Vector2(0,18);BattleSourcePriority.initialize(t,c,owner);_light(t,0);return [t]
static func _paint(t: Dictionary) -> void:
	var owner: Node2D=t.owner
	if not is_instance_valid(owner._background_blend):
		owner._background_blend=Polygon2D.new();owner._background_blend.polygon=PackedVector2Array([Vector2.ZERO,Vector2(240,0),Vector2(240,160),Vector2(0,160)]);owner.add_child(owner._background_blend)
	owner._background_blend.color=Color(0,0,0,float(t.amount)/16.0)
static func _light(t: Dictionary,age: int) -> void:
	# ConvertScaleParam computes reciprocal OAM texture coordinates; visible size
	# is the source affine state /256, not its reciprocal. Normal64px OAM bounds
	# are never exceeded by this program (maximum state160).
	var pose: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.affine_program,mini(age,114),true)
	t.node.scale=pose.matrix/256.0
static func advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	if t.kind=="source_tail_light":_light(t,int(t.age));return
	if int(t.finishing)>=0:
		t.finishing=int(t.finishing)+1;return
	if not bool(t.obj_half):
		if int(t.delay_counter)<int(t.settings.source_args[1]):t.delay_counter=int(t.delay_counter)+1;return
		t.delay_counter=0;_paint(t)
	t.obj_half=not bool(t.obj_half)
	if not bool(t.obj_half):
		if int(t.amount)==int(t.destination):t.finishing=0
		else:t.amount=int(t.amount)+2*signi(int(t.destination)-int(t.amount))

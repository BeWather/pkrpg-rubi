extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Source shape changes are non-affine frame VM; no alpha/monBG/OBJ palette task.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if s.behavior=="source_kinesis_cycle":return [{"kind":"source_kinesis_cycle","settings":s,"owner":owner,"domain":"maintenance","age":0,"ticks":int(s.ticks),"counter":0,"cycles":0,"bank":1 if c.contest else 2,"update":advance}]
	var actors: Array[BattleAnimationActor]=c.resolve("attacker");var targets: Array[BattleAnimationActor]=c.resolve("target")
	if actors.is_empty() or targets.is_empty():return []
	var actor: BattleAnimationActor=actors[0];var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;owner.add_child(node)
	var t: Dictionary={"kind":str(s.behavior),"settings":s,"node":node,"original_actor":actor,"age":0,"ticks":int(s.ticks),"program":s.source_frame_variants[0 if actor.side==0 else 1] if s.behavior=="source_kinesis_spoon" else s.frame_program,"side_flip":actor.side!=0 and s.behavior=="source_kinesis_alert","v_flip":s.behavior=="source_kinesis_alert" and int(s.source_args[2])!=0,"update":advance}
	var origin: Vector2=Geometry._anchor(actor,c,owner,"center")
	if s.behavior=="source_kinesis_spoon":node.position=origin+Vector2(40,-10)*(1 if actor.side==0 else -1)
	else:node.position=origin+Vector2(int(s.source_args[0])*BattleElectricContract.source_offset_direction(c,actor,targets[0]),int(s.source_args[1]))
	BattleSourcePriority.initialize(t,c,owner);_frame(t,0);return [t]
static func _frame(t: Dictionary,age: int) -> void:
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(t.program,age).frame;var rect: Array=t.settings.frame_rects[str(int(frame.tile))];t.tile=int(frame.tile);t.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);t.node.flip_h=bool(frame.get("flip_h",false))!=bool(t.side_flip);t.node.flip_v=bool(frame.get("flip_v",false))!=bool(t.v_flip)
static func advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	if t.kind=="source_kinesis_cycle":
		t.counter=int(t.counter)+1
		if int(t.counter)==4:
			t.counter=0;t.cycles=int(t.cycles)+1
			if is_instance_valid(t.owner._source_background):t.owner._source_background.region_rect.position.y=(int(t.cycles)%11)*160
		# Source rotates FADED first, then checks shared ARG7 and DestroyTask.
		if (int(t.owner._source_args.get(7,0))&65535)==65535:t.ticks=int(t.age)
		return
	if not t.original_actor.is_present():t.ticks=int(t.age);return
	_frame(t,int(t.age))

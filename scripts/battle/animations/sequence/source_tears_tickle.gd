extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## dark.c fixed-point arcs / source picture corners, perceive.c finite eye frames.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
const Arc=preload("res://scripts/battle/animations/sequence/source_sports.gd")
static func create_tint(step: Dictionary,_c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	# Source start==end and delay0: Step1 calls Step2 immediately and destroys.
	# Keep only this execution's selected OBJ palette state for later children.
	var states: Dictionary=owner.get_meta("source_tag_palette_states",{})
	states[str(step.source_tag)]={"amount":int(step.amount),"color":step.source_color.duplicate()};owner.set_meta("source_tag_palette_states",states)
	return []
static func _node(step: Dictionary,owner: Node2D,texture: String) -> Sprite2D:
	var node:=Sprite2D.new();node.texture=load(texture);node.region_enabled=true;owner.add_child(node)
	return node
static func _pose(t: Dictionary) -> void:
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.frame_program,int(t.age)).frame
	var rect: Array=t.settings.frame_rects[str(int(frame.tile))];t.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3])
	if t.kind=="source_fake_tear":
		var program: Array=t.settings.source_affine_variants["0" if int(t.case)<2 else "1"]
		var pose: Dictionary=BattleSourceCommandProgram.evaluate(program,int(t.age),true)
		t.node.scale=Vector2(256.0/pose.matrix.x,256.0/pose.matrix.y);t.node.rotation=-float(pose.rotation)*TAU/256.0
static func create_tear(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var actors: Array[BattleAnimationActor]=c.resolve("attacker" if int(step.source_args[0])==0 else "target")
	if actors.is_empty():return []
	var actor: BattleAnimationActor=actors[0]
	var states: Dictionary=owner.get_meta("source_tag_palette_states",{})
	var selected: Dictionary=states.get("10155",{})
	if int(selected.get("amount",-1))!=int(step.source_required_palette.amount) or selected.get("color",[])!=step.source_required_palette.color:owner.error_message="Missing actual source bubble palette10155 tint";owner.finish("failed");return []
	var bounds: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(step.source_bounds)))
	var species: String=str(c.source_appearance_species.get(actor.id,c.source_party_species.get(actor.id,""))).to_upper()
	var side: String="back" if c.contest or actor.side==0 else "front";var sizes: Dictionary=bounds.by_species.get(species,{})
	if not sizes.has(side):owner.error_message="Missing source tear picture dimensions: "+species;owner.finish("failed");return []
	var picture: Vector2=Vector2(sizes[side][0],sizes[side][1]);var center: Vector2=Geometry._anchor(actor,c,owner,"center");var half: Vector2=picture/2;var case: int=int(step.source_args[1])
	var origin: Vector2=center+Vector2(half.x-8 if case==0 else half.x-14 if case==1 else -half.x+8 if case==2 else -half.x+14,-half.y+(8 if case in [0,2] else 16))
	var node: Sprite2D=_node(step,owner,str(step.source_tinted_texture))
	var t: Dictionary={"kind":"source_fake_tear","settings":step.duplicate(true),"owner":owner,"original_actor":actor,"node":node,"case":case,"center":center,"picture_size":picture,"origin":origin,"offset":Vector2.ZERO,"age":0,"ticks":33,"update":advance}
	Arc._arc(t,origin+Vector2(20 if case<2 else -20,12),32,-12);node.position=origin;BattleSourcePriority.initialize(t,c,owner);_pose(t)
	return [t]
static func create_sparkle(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var actors: Array[BattleAnimationActor]=c.resolve("attacker");var targets: Array[BattleAnimationActor]=c.resolve("target")
	if actors.is_empty() or targets.is_empty():return []
	var actor: BattleAnimationActor=actors[0];var a: Array=step.source_args
	var origin: Vector2=Geometry._anchor(actor,c,owner,"center")+Vector2(int(a[0])*BattleElectricContract.source_offset_direction(c,actor,targets[0]),int(a[1]))
	var node: Sprite2D=_node(step,owner,str(step.texture));node.position=origin
	var t: Dictionary={"kind":"source_tickle_sparkle","settings":step.duplicate(true),"owner":owner,"original_actor":actor,"node":node,"origin":origin,"age":0,"ticks":int(step.ticks),"update":advance}
	BattleSourcePriority.initialize(t,c,owner);_pose(t)
	return [t]
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if c.actors.get(t.original_actor.id)!=t.original_actor or not t.original_actor.is_present():t.ticks=int(t.age);return
	if t.kind=="source_fake_tear":
		if Arc._translate(t):t.ticks=int(t.age);return
		t.node.position=t.origin+t.offset
	_pose(t)

extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Independent source palette domains; owned clone shader combines BG alpha/palette.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if s.behavior=="source_luster_monbg":
		var tracks: Array[Dictionary]=BattleCounterSelected.create(s,c,owner)
		if s.mode=="monbg":
			for track: Dictionary in tracks:
				for clone: Dictionary in track.clones:
					var material:=ShaderMaterial.new();material.shader=load("res://scripts/battle/animations/sequence/source_luster_clone.gdshader");clone.node.material=material
					var nodes: Array=owner.get_meta("source_counter_blend_nodes",[]);nodes.append({"node":clone.node,"material":material});owner.set_meta("source_counter_blend_nodes",nodes)
		return tracks
	if s.behavior=="source_luster_impact":
		if not bool(owner.get_meta("source_luster_impact_blue12",false)):owner.error_message="Missing source impact palette admission";owner.finish("failed");return []
		return BattleFieldOwned.create(s,c,owner)
	var t: Dictionary={"kind":str(s.behavior),"settings":s,"owner":owner,"age":0,"ticks":int(s.ticks),"update":advance}
	if s.behavior=="source_luster_cycle":t.domain="maintenance";return [t]
	if s.behavior=="source_luster_palette":
		if s.mode=="impact":owner.set_meta("source_luster_impact_blue12",true);return []
		t.members=c.resolve("all") if s.mode=="excluded" else [];t.counter=1;t.amount=int(s.source_args[2]);t.applied=int(s.source_args[2]);return [t]
	var actors: Array[BattleAnimationActor]=c.resolve("attacker")
	if actors.is_empty():return []
	var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;owner.add_child(node);BattleCounterSelected._blend_node(node,owner)
	t.node=node;t.original_actor=actors[0];t.origin=Geometry._anchor(actors[0],c,owner,"center");t.palette_amount=0;BattleSourcePriority.initialize(t,c,owner);_circle(t,0);return [t]
static func _circle(t: Dictionary,age: int) -> void:
	var s: Dictionary=t.settings;var pose: Dictionary=BattleSourceCommandProgram.evaluate(s.affine_program,age,true)
	t.node.position=t.origin;t.node.scale=Vector2(256.0/pose.matrix.x,256.0/pose.matrix.y);t.palette_amount=int(t.owner.get_meta("source_luster_circle_amount",0));t.node.region_rect=Rect2(0,int(t.palette_amount)*int(s.source_palette_height),64,64)
static func _paint(t: Dictionary,c: BattleAnimationContext) -> void:
	var owner: Node2D=t.owner
	if t.settings.mode=="circle":
		owner.set_meta("source_luster_circle_amount",int(t.applied))
		for circle: Dictionary in owner._tracks:
			if circle.kind=="source_luster_circle":_circle(circle,int(circle.age))
		return
	for actor: BattleAnimationActor in t.members:
		if c.actors.get(actor.id)==actor and actor.is_present():owner._held_blends[actor.id]={"color":Color.WHITE,"amount":float(t.applied)/16.0,"source_actor":actor}
	if not is_instance_valid(owner._background_blend):
		owner._background_blend=Polygon2D.new();owner._background_blend.polygon=PackedVector2Array([Vector2.ZERO,Vector2(240,0),Vector2(240,160),Vector2(0,160)]);owner.add_child(owner._background_blend)
	owner._background_blend.color=Color(1,1,1,float(t.applied)/16.0)
	for entry: Dictionary in owner.get_meta("source_counter_blend_nodes",[]):
		if is_instance_valid(entry.node) and entry.node.material==entry.material and entry.material.shader.resource_path.ends_with("source_luster_clone.gdshader"):entry.material.set_shader_parameter("palette_amount",float(t.applied)/16.0)
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if t.kind=="source_luster_circle":_circle(t,int(t.age));return
	if t.kind=="source_luster_cycle":
		if (int(t.owner._source_args.get(7,0))&65535)==65535:
			t.ticks=int(t.age)
			if is_instance_valid(t.owner._source_background):t.owner._source_background.region_rect.position=Vector2.ZERO
		elif is_instance_valid(t.owner._source_background):t.owner._source_background.region_rect.position.y=(int(t.age)/4%11)*160
		return
	var s: Dictionary=t.settings
	if int(t.counter)==int(s.source_args[1]):
		t.counter=0;t.applied=int(t.amount);_paint(t,c)
		if int(t.amount)==int(s.source_args[3]):t.ticks=int(t.age)
		else:t.amount=int(t.amount)+signi(int(s.source_args[3])-int(t.amount))
	else:t.counter=int(t.counter)+1

extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Source five static hollow orbs/32-callback alpha and separate X-sign blink.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
const OFFSETS=[Vector2(1,-1),Vector2(-1,1),Vector2(1,1),Vector2(-1,-1),Vector2.ZERO]
static func _node(settings: Dictionary,owner: Node2D) -> Sprite2D:
	var node:=Sprite2D.new();node.texture=load(str(settings.texture));node.region_enabled=true;owner.add_child(node)
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(settings.frame_program,0).frame
	var rect: Array=settings.frame_rects[str(int(frame.tile))];node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);return node
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var actors: Array[BattleAnimationActor]=c.resolve("target" if str(step.behavior)=="source_imprison_sign" and int(step.source_args[0])!=0 else "attacker")
	if actors.is_empty():return []
	var actor: BattleAnimationActor=actors[0];var origin: Vector2=Geometry._anchor(actor,c,owner,"center")
	if str(step.behavior)=="source_imprison_sign":
		var node: Sprite2D=_node(step,owner);node.position=origin
		var sign: Dictionary={"kind":"source_imprison_sign","settings":step.duplicate(true),"owner":owner,"node":node,"origin":origin,"age":0,"ticks":4096,"counter":0,"update":advance}
		BattleSourcePriority.initialize(sign,c,owner);return [sign]
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(step.source_bounds)))
	var species: String=str(c.source_appearance_species.get(actor.id,c.source_party_species.get(actor.id,""))).to_upper();var side: String="back" if c.contest or actor.side==0 else "front"
	var sizes: Dictionary=data.by_species.get(species,{})
	if not sizes.has(side):owner.error_message="Missing source Imprison picture dimensions: "+species;owner.finish("failed");return []
	var size: Array=sizes[side];var radius: int=maxi(int(size[0])/3,int(size[1])/3)
	var t: Dictionary={"kind":"source_imprison_orbs","settings":step.duplicate(true),"owner":owner,"original_actor":actor,"origin":origin,"radius":radius,"age":0,"ticks":4096,"counter":0,"created":0,"fade_age":0,"stage":0,"eva":16,"evb":0,"children":[],"update":advance}
	_alpha(t);return [t]
static func _alpha(t: Dictionary) -> void:
	t.owner.set_meta("source_counter_alpha",[int(t.eva),int(t.evb)])
	for child: Dictionary in t.children:
		child.node.material.set_shader_parameter("eva",float(t.eva)/16.0);child.node.material.set_shader_parameter("evb",float(t.evb)/16.0)
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if t.kind=="source_imprison_sign":
		if int(t.counter)>int(t.settings.source_args[1])-10:t.node.visible=int(t.counter)%2==0
		if int(t.counter)==int(t.settings.source_args[1]):t.ticks=int(t.age)
		t.counter=int(t.counter)+1;return
	match int(t.stage):
		0:
			t.counter=int(t.counter)+1
			if int(t.counter)>8:
				t.counter=0
				var node: Sprite2D=_node(t.settings,t.owner);node.position=t.origin+OFFSETS[int(t.created)]*int(t.radius)
				node.z_index=BattleSourcePriority.relative_layer(t.original_actor,-BattleElectricContract.source_subpriority(t.original_actor,c),c,t.owner)
				BattleCounterSelected._blend_node(node,t.owner)
				t.children.append({"node":node,"serial":int(t.created),"source_oam_subpriority":0});t.created=int(t.created)+1
				if int(t.created)==5:t.stage=1
		1:
			if int(t.fade_age)&1:t.eva=int(t.eva)-1
			else:t.evb=int(t.evb)+1
			t.fade_age=int(t.fade_age)+1;_alpha(t)
			if int(t.fade_age)==32:
				for child: Dictionary in t.children:child.node.queue_free()
				t.children.clear();t.stage=2
		2:t.stage=3
		3:t.eva=0;t.evb=0;_alpha(t);t.ticks=int(t.age)

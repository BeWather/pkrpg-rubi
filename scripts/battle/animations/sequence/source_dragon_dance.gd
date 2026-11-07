extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Separate source scanline, tag palette and accelerating-circle continuations.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if str(step.behavior)=="source_dragon_palette":
		owner.set_meta("source_dragon_palette_amount",0)
		return [{"kind":"source_dragon_palette","settings":step,"owner":owner,"age":0,"ticks":84,"amount":0,"direction":1,"cycles":3,"update":advance}]
	var actors: Array[BattleAnimationActor]=c.resolve("attacker")
	if actors.is_empty():return []
	var actor: BattleAnimationActor=actors[0]
	if str(step.behavior)=="source_dragon_wave":return _wave(step,c,owner,actor)
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(step.source_bounds)));var species: String=str(c.source_appearance_species.get(actor.id,c.source_party_species.get(actor.id,""))).to_upper();var side: String="back" if c.contest or actor.side==0 else "front"
	if not data.by_species.has(species):owner.error_message="Missing source Dragon Dance picture bounds: "+species;owner.finish("failed");return []
	var size: Array=data.by_species[species][side]
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;owner.add_child(node)
	var t: Dictionary={"kind":"source_dragon_orb","settings":step,"owner":owner,"original_actor":actor,"node":node,"origin":Geometry._anchor(actor,c,owner,"center"),"phase":int(step.source_args[0]),"radius":maxi(int(size[0]),int(size[1]))/2,"speed":1,"counter":0,"stage":"orbit","stage_age":0,"age":0,"ticks":82,"update":advance}
	BattleSourcePriority.initialize(t,c,owner);_orb(t);return [t]
static func _orb(t: Dictionary) -> void:
	t.node.position=t.origin+Vector2(BattleSourceTrig.cosine(int(t.phase),int(t.radius)),BattleSourceTrig.sine(int(t.phase),int(t.radius)))
	t.palette_amount=int(t.owner.get_meta("source_dragon_palette_amount",0));t.node.region_rect=Rect2(0,int(t.palette_amount)*16,16,16)
static func _wave(step: Dictionary,c: BattleAnimationContext,owner: Node2D,actor: BattleAnimationActor) -> Array[Dictionary]:
	var center: int=int(Geometry._anchor(actor,c,owner,"origin").y)
	if actor.side!=0 and not c.contest:
		var species: String=str(c.source_appearance_species.get(actor.id,c.source_party_species.get(actor.id,""))).to_upper();var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(step.source_elevations)))
		center-=int(data.castform_forms[clampi(int(c.get_meta("source_castform_form",0)),0,3)]) if species=="CASTFORM" else int(data.by_species.get(species,0))
	var t: Dictionary={"kind":"source_dragon_wave","settings":step,"owner":owner,"original_actor":actor,"source_top":maxi(0,center-32),"source_bottom":center+32,"rows":[],"nodes":[],"amplitude":0,"phase":0,"counter":0,"stage":"rise","age":0,"ticks":4096,"update":advance}
	for index: int in 65:t.rows.append(0)
	for bg: Dictionary in owner.get_meta("source_counter_monbg",[]):
		for clone: Dictionary in bg.clones:
			if clone.actor!=actor:continue
			var material:=ShaderMaterial.new();material.shader=load("res://scripts/battle/animations/sequence/source_dragon_wave.gdshader")
			t.nodes.append({"node":clone.node,"material":material,"previous":clone.node.material});clone.node.material=material
	t.cleanup=_cleanup.bind(t);_project(t);return [t]
static func _project(t: Dictionary) -> void:
	for entry: Dictionary in t.nodes:
		if not is_instance_valid(entry.node) or entry.node.material!=entry.material:continue
		var node: Sprite2D=entry.node;var rect: Rect2=node.get_rect();var pixels: Rect2=node.region_rect if node.region_enabled else Rect2(Vector2(node.frame_coords)*node.texture.get_size()/Vector2(node.hframes,node.vframes),node.texture.get_size()/Vector2(node.hframes,node.vframes))
		entry.material.set_shader_parameter("frame_uv_origin",pixels.position/node.texture.get_size());entry.material.set_shader_parameter("frame_uv_size",pixels.size/node.texture.get_size())
		entry.material.set_shader_parameter("native_top",node.position.y+rect.position.y*node.scale.y);entry.material.set_shader_parameter("native_height",rect.size.y*node.scale.y);entry.material.set_shader_parameter("native_width",rect.size.x*absf(node.scale.x));entry.material.set_shader_parameter("uv_direction",-1.0 if node.flip_h else 1.0)
		entry.material.set_shader_parameter("source_top",float(t.source_top));entry.material.set_shader_parameter("source_bottom",float(t.source_bottom));entry.material.set_shader_parameter("source_rows",PackedFloat32Array(t.rows))
static func _cleanup(t: Dictionary) -> void:
	t.erase("cleanup")
	for entry: Dictionary in t.nodes:
		if is_instance_valid(entry.node) and entry.node.material==entry.material:entry.node.material=entry.previous
static func _rows(t: Dictionary) -> void:
	var phase: int=int(t.phase)
	for index: int in 65:t.rows[index]=BattleSourceTrig.sine(phase,int(t.amplitude)*2);phase=(phase+8)&255
	t.phase=(int(t.phase)+9)&255;_project(t)
static func advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	if t.kind=="source_dragon_palette":
		t.amount=int(t.amount)+int(t.direction)
		if int(t.amount)==14:t.direction=-1
		elif int(t.amount)==0:t.cycles=int(t.cycles)-1;t.direction=1
		t.owner.set_meta("source_dragon_palette_amount",int(t.amount));return
	if not t.original_actor.is_present():t.ticks=int(t.age);return
	if t.kind=="source_dragon_orb":
		t.phase=(int(t.phase)-int(t.speed))&255
		if t.stage=="expand":t.radius=mini(150,int(t.radius)+8)
		t.counter=int(t.counter)+1
		if int(t.counter)>5:t.counter=0;t.speed=mini(16,int(t.speed)+1)
		t.stage_age=int(t.stage_age)+1
		if t.stage=="orbit" and int(t.stage_age)>60:t.stage="expand";t.stage_age=0
		_orb(t);return
	match str(t.stage):
		"rise","fall":
			t.counter=int(t.counter)+1
			if int(t.counter)>1:
				t.counter=0;t.amplitude=int(t.amplitude)+(1 if t.stage=="rise" else -1)
				if int(t.amplitude)==3 and t.stage=="rise":t.stage="hold"
				elif int(t.amplitude)==0 and t.stage=="fall":t.stage="stop"
			_rows(t)
		"hold":
			t.counter=int(t.counter)+1
			if int(t.counter)>60:t.counter=0;t.stage="fall"
			_rows(t)
		"stop":t.stage="cleanup"
		"cleanup":t.ticks=int(t.age)

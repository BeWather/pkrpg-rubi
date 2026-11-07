extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## ground.c517/583/728: separate actor offset, BG3 registers, and packed plume.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
const Packed=preload("res://scripts/battle/animations/sequence/source_sports.gd")
static func _draw_field_nodes(c: BattleAnimationContext) -> Array[Dictionary]:
	# Render-only BG3 scroll: terrain may parent BattleSlots, so moving its
	# Node2D transform would incorrectly add the field quake to every OBJ.
	var nodes: Array[Dictionary]=[];var actor_z: int=2147483647
	for actor: BattleAnimationActor in c.resolve("all"):actor_z=mini(actor_z,BattleSourcePriority.effective_layer(actor.sprite))
	for node: Node in c.field.get_children():
		if not (node is Sprite2D or node is Polygon2D):continue
		var is_actor: bool=false
		for actor: BattleAnimationActor in c.resolve("all"):
			if node==actor.sprite:is_actor=true;break
		if not is_actor and (bool(node.get_meta("animation_background",false)) or BattleSourcePriority.effective_layer(node as CanvasItem)<actor_z):
			nodes.append({"node":node,"property":"offset","base":node.get("offset"),"expected":node.get("offset"),"field":c.field})
	return nodes
static func _field(t: Dictionary,x: int,y: int=0) -> void:
	# LoadMoveBg creates the BG3 image after the quake cached native field nodes.
	# Enroll that late runner child into the SAME absolute register authority.
	var background: Sprite2D=t.owner._source_background
	if is_instance_valid(background):
		var enrolled: bool=false
		for item: Dictionary in t.nodes:
			if item.node==background:enrolled=true;break
		if not enrolled:
			var property: String=str(t.get("field_property","position"));var base: Vector2=background.get(property)
			var receipt: Dictionary={"node":background,"property":property,"base":base,"expected":base}
			if property=="offset":receipt.field=t.field
			t.nodes.append(receipt)
	t.register_x=x;t.register_y=y
	var offset:=Vector2(-x,-y)
	if t.kind=="source_fissure_align":offset=Vector2(-(x-512 if x>255 else x),-(y-256 if y>127 else y))
	for item: Dictionary in t.nodes:
		if not is_instance_valid(item.node):continue
		var property: String=str(item.get("property","position"));var projected: Vector2=offset
		if property=="offset":projected=item.node.to_local(item.field.to_global(offset))-item.node.to_local(item.field.to_global(Vector2.ZERO))
		item.base+=Vector2(item.node.get(property))-item.expected
		item.node.set(property,item.base+projected);item.expected=item.node.get(property)
static func _restore(t: Dictionary) -> void:
	if t.has("nodes"):_field(t,0)
	elif t.owner._held_offsets.get(t.original_actor.id,Vector2.ZERO)==t.offset:t.owner._held_offsets[t.original_actor.id]=Vector2.ZERO
	t.erase("cleanup")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var actor: BattleAnimationActor=c.resolve("attacker" if s.behavior=="source_fissure_plume" and int(s.source_args[0])==0 else "target")[0]
	var t: Dictionary={"kind":s.behavior,"settings":s,"owner":owner,"original_actor":actor,"age":0,"ticks":int(s.ticks),"offset":Vector2.ZERO,"counter":0,"toggles":0,"stage":0,"magnitude":13,"register_x":0,"update":advance}
	if s.behavior=="source_fissure_plume":
		var a: Array=s.source_args;var side: int=1 if int(a[1])==0 else -1;var base: Vector2=Geometry._anchor(actor,c,owner,"origin");var elevation: int=0
		if actor.side!=0 and not c.contest:
			var species: String=str(c.source_appearance_species.get(actor.id,c.source_party_species.get(actor.id,""))).to_upper();var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(s.source_elevations)))
			elevation=int(data.castform_forms[clampi(int(c.get_meta("source_castform_form",0)),0,3)]) if species=="CASTFORM" else int(data.by_species.get(species,0))
		t.origin=Vector2(Geometry._anchor(actor,c,owner,"center").x+24*side,base.y-elevation+30);t.destination=t.origin+Vector2(int(a[2])*side,int(a[3]));Packed._arc(t,t.destination,int(a[5]),int(a[4]));var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;var rect: Array=s.frame_rects["0"];node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);node.position=t.origin;owner.add_child(node);t.node=node;BattleSourcePriority.initialize(t,c,owner);return [t]
	if s.behavior=="source_fissure_align" or int(s.source_args[0])==5:
		if s.get("source_field_projection","")=="draw_offset":
			t.field_property="offset";t.field=c.field;t.nodes=_draw_field_nodes(c)
		else:
			if not owner.has_meta("source_fissure_bg3_nodes"):
				var field: Dictionary=BattleSoundOwnership.create_field_offset({"source_args":[0,0,0,0],"ticks":4096,"register_mode":"toggle_set"},c)[0];owner.set_meta("source_fissure_bg3_nodes",field.nodes)
			t.nodes=owner.get_meta("source_fissure_bg3_nodes")
	if s.behavior=="source_fissure_align":
		t.domain="maintenance";var center: Vector2=Geometry._anchor(actor,c,owner,"center");_field(t,(32-int(center.x))&511,(64-int(center.y))&255)
	t.cleanup=_restore.bind(t);return [t]
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if t.kind=="source_fissure_align":
		if int(t.owner._source_args.get(7,0))==65535:_restore(t);t.ticks=int(t.age)
		else:_field(t,int(t.register_x),int(t.register_y))
		return
	if not t.original_actor.is_present():t.ticks=int(t.age);return
	if t.kind=="source_fissure_plume":
		if int(t.age)==1:return
		if Packed._translate(t):t.ticks=int(t.age);return
		t.node.position=t.origin+t.offset
		var frame: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.frame_program,int(t.age)).frame;var rect: Array=t.settings.frame_rects[str(int(frame.tile))];t.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);return
	if int(t.age)==1:return
	if int(t.stage)==2:_restore(t);t.ticks=int(t.age);return
	t.counter=int(t.counter)+1
	if int(t.counter)<=1:return
	t.counter=0
	var x: int=int(t.magnitude)*(1 if int(t.toggles)%2==0 else -1) if t.has("nodes") else (int(t.magnitude)/2+(int(t.magnitude)&1) if int(t.toggles)%2==0 else -(int(t.magnitude)/2))
	if t.has("nodes"):_field(t,x)
	else:t.offset=Vector2(x,0);t.owner._held_offsets[t.original_actor.id]=t.offset
	t.toggles=int(t.toggles)+1
	if int(t.toggles)==(50 if int(t.stage)==0 else 4):
		t.toggles=0;t.magnitude=int(t.magnitude)-1
		if int(t.stage)==0:t.stage=1
		elif int(t.magnitude)==0:t.stage=2

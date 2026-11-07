extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## dark.c415–825: visible original OBJ plus independent selected black BG/window/VOFS.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func _plane(a: BattleAnimationActor,c: BattleAnimationContext) -> int:return 1 if c.contest or c.source_position(a.id) in [1,2] else 2
static func _clear(t: Dictionary) -> void:
	t.erase("cleanup")
	for item: Dictionary in t.members:
		if is_instance_valid(item.node):item.node.queue_free()
	t.members.clear()
static func _copy(actor: BattleAnimationActor,c: BattleAnimationContext,owner: Node2D) -> Dictionary:
	var t: Dictionary={"kind":"source_memento_copy","owner":owner,"members":[],"age":0,"ticks":2147483647,"domain":"maintenance","mode":"attacker" if actor.id==c.attacker_id else "target"}
	for member: BattleAnimationActor in [actor,Geometry._partner(actor,c)]:
		if member==null or not member.is_present() or not member.sprite.visible:continue
		var clone: Sprite2D=BattleIdentityCopy.clone_sprite(member,owner);owner.add_child(clone);clone.z_index=BattleSourcePriority.relative_layer(member,1,c,owner);t.members.append({"actor":member,"node":clone,"bg_plane":_plane(member,c)})
	t.cleanup=_clear.bind(t);return t
static func _black_copy(t: Dictionary) -> void:
	# FillPalette replaces the selected BG art; the original OBJ stays visible.
	# The opposite copied plane is displaced offscreen by the same source task.
	var copy: Dictionary=t.owner.get_meta("source_memento_"+str(t.settings.mode),{})
	for item: Dictionary in copy.get("members",[]):
		if is_instance_valid(item.node):item.node.hide()
static func _geometry(t: Dictionary,c: BattleAnimationContext) -> void:
	var actor: BattleAnimationActor=t.original_actor;var origin: Vector2=Geometry._anchor(actor,c,t.owner,"origin");var center: Vector2=Geometry._anchor(actor,c,t.owner,"center");var species: String=str(c.source_appearance_species.get(actor.id,""));species=(str(c.source_party_species.get(actor.id,"")) if species.is_empty() else species).to_upper();var bounds: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(t.settings.source_bounds)));var side: String="back" if c.contest or actor.side==0 else "front"
	# Source attr2 deliberately uses coords low nibble (width), not height.
	t.original_top=int(center.y)-int(bounds.by_species[species][side][0])/2-7;t.original_bottom=int(origin.y)+31;t.height_q=(int(t.original_bottom)-int(t.original_top))*256;t.limit=-12 if actor.side==0 else -64;t.center_x=int(origin.x);t.top=t.original_top;t.bottom=t.original_bottom;t.left=int(origin.x)-32;t.right=int(origin.x)+32
static func _polygon(t: Dictionary,c: BattleAnimationContext) -> void:
	var actor: BattleAnimationActor=t.original_actor;var source: Sprite2D=actor.sprite;var clone: Sprite2D=BattleIdentityCopy.clone_sprite(actor,t.owner);var rect: Rect2=clone.get_rect();var native_origin: Vector2=clone.position+rect.position*clone.scale;var native_size: Vector2=rect.size*clone.scale.abs();var pixels: Rect2=clone.region_rect if clone.region_enabled else Rect2(Vector2(clone.frame_coords)*clone.texture.get_size()/Vector2(clone.hframes,clone.vframes),clone.texture.get_size()/Vector2(clone.hframes,clone.vframes));clone.free()
	var node:=Polygon2D.new();node.polygon=PackedVector2Array([Vector2.ZERO,Vector2(c.field_size.x,0),c.field_size,Vector2(0,c.field_size.y)]);node.texture=source.texture;node.uv=node.polygon;node.z_index=BattleSourcePriority.relative_layer(actor,-1,c,t.owner);t.owner.add_child(node);var m:=ShaderMaterial.new();m.shader=load("res://scripts/battle/animations/sequence/source_memento.gdshader");node.material=m;m.set_shader_parameter("frame_uv_origin",pixels.position/source.texture.get_size());m.set_shader_parameter("frame_uv_size",pixels.size/source.texture.get_size());m.set_shader_parameter("native_origin",native_origin);m.set_shader_parameter("native_size",native_size);m.set_shader_parameter("flip_h",source.flip_h);m.set_shader_parameter("flip_v",source.flip_v);t.node=node;t.material=m
	for member: BattleAnimationActor in c.actors.values():
		if member.is_present():
			var layers: Dictionary=t.owner.get_meta("source_memento_layers",{})
			if not layers.has(member.id):layers[member.id]=member.sprite.z_index;t.owner.set_meta("source_memento_layers",layers)
			member.apply_source_layer(maxi(0,int(layers[member.id])-1))
static func _project(t: Dictionary) -> void:
	t.material.set_shader_parameter("source_rows",PackedFloat32Array(t.rows));t.material.set_shader_parameter("window_left",float(t.left));t.material.set_shader_parameter("window_right",float(t.right));t.material.set_shader_parameter("eva",float(t.eva)/16);t.material.set_shader_parameter("evb",float(t.evb)/16)
static func _rows(t: Dictionary) -> void:
	var top: int=t.top;var bottom: int=t.bottom
	if bottom==top:
		for row: int in 112:t.rows[row]=159-row
	else:
		var step: int=int(t.height_q)/(bottom-top);var value: int=int(t.original_top)*256
		for row: int in maxi(0,top):
			if row<160:t.rows[row]=159-row
		for row: int in range(top,bottom+1):
			if row>=0 and row<160:t.rows[row]=(value>>8)-row
			value+=step
		var sample: int=159-(bottom+1)
		for row: int in range(bottom+1,int(t.original_bottom)):
			if row>=0 and row<160:t.rows[row]=sample
			sample-=1
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if s.behavior=="source_memento_command":
		if s.mode=="target_clear":
			var copy: Dictionary=owner.get_meta("source_memento_target",{})
			if not copy.is_empty():_clear(copy);copy.ticks=int(copy.age)
		elif s.mode=="target_copy":
			var copy: Dictionary=_copy(c.resolve("target")[0],c,owner);owner.set_meta("source_memento_target",copy);return [copy]
		else:owner.set_meta("source_memento_alpha",s.source_args if s.mode=="alpha" else [16,0])
		return []
	if s.mode=="clear":
		var copy: Dictionary=owner.get_meta("source_memento_attacker",{})
		if not copy.is_empty():_clear(copy);copy.ticks=int(copy.age)
		return []
	if s.mode=="copy":
		var copy: Dictionary=_copy(c.resolve("attacker")[0],c,owner);owner.set_meta("source_memento_attacker",copy);return [copy]
	if s.mode=="target" and c.contest:return []
	var actor: BattleAnimationActor=c.resolve(s.mode)[0];var t: Dictionary={"kind":"source_memento_fade","settings":s,"owner":owner,"original_actor":actor,"age":0,"ticks":4096,"phase":0,"counter":0,"toggles":0,"eva":0,"evb":16,"setup":1 if s.mode=="target" else 0,"rows":[],"bg_plane":_plane(actor,c),"update":advance};t.palette_bank=14 if c.contest and int(t.bg_plane)==1 else 8 if int(t.bg_plane)==1 else 9
	for row: int in 160:t.rows.append(0)
	_geometry(t,c);_polygon(t,c)
	if s.mode=="attacker":_black_copy(t)
	if s.mode=="target":t.top=t.limit;t.bottom=t.limit;t.left=int(t.center_x)-4;t.right=int(t.center_x)+4
	_project(t);return [t]
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if int(t.setup)>0:
		if int(t.setup)==1:_black_copy(t)
		# createvisualtask already ran state0; callbacks1..4 run states1..4.
		if int(t.setup)==3:
			for row: int in 112:t.rows[row]=159-row
		t.setup=int(t.setup)+1
		if int(t.setup)>4:t.setup=0;t.eva=12;t.evb=8
		_project(t);return
	var reverse: bool=t.settings.mode=="target"
	match int(t.phase):
		0:
			if reverse:
				t.bottom=mini(int(t.original_bottom),int(t.bottom)+8);_rows(t)
				if int(t.bottom)==int(t.original_bottom):t.phase=1
			else:
				t.counter=int(t.counter)+1
				if int(t.counter)>1:
					t.counter=0;t.toggles=int(t.toggles)+1
					if int(t.toggles)%2:t.eva=mini(12,int(t.eva)+1)
					else:t.evb=maxi(8,int(t.evb)-1)
					if int(t.eva)==12 and int(t.evb)==8:t.phase=1
		1:
			if reverse:
				if int(t.right)-int(t.left)<64:t.left=int(t.left)-4;t.right=int(t.right)+4
				else:t.counter=1
				t.top=mini(int(t.original_top),int(t.top)+8);_rows(t)
				if int(t.top)==int(t.original_top) and int(t.counter)==1:t.counter=0;t.phase=2
			else:
				t.top=int(t.top)-8;_rows(t)
				if int(t.top)<int(t.limit):t.phase=2
		2:
			if reverse:
				t.counter=int(t.counter)+1
				if int(t.counter)>1:
					t.counter=0;t.toggles=int(t.toggles)+1
					if int(t.toggles)%2:t.eva=maxi(0,int(t.eva)-1)
					else:t.evb=mini(16,int(t.evb)+1)
					if int(t.eva)==0 and int(t.evb)==16:t.phase=3
			else:
				t.top=int(t.top)-8;_rows(t);t.left=mini(int(t.right),int(t.left)+4);t.right=maxi(int(t.left),int(t.right)-4)
				if int(t.left)==int(t.right):t.phase=3
		3:t.phase=4
		4:
			if reverse:t.left=0;t.right=0
			t.ticks=int(t.age)
	_project(t)

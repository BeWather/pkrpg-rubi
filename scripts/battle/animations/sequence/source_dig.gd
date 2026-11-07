extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Exact task clocks; an owned clone clip projects BG scanline+240 hiding below ground.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func _ground(actor: BattleAnimationActor,c: BattleAnimationContext,owner: Node2D,s: Dictionary) -> int:
	var y: int=int(Geometry._anchor(actor,c,owner,"origin").y)
	if actor.side!=0 and not c.contest:
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(s.source_elevations)));var species: String=str(c.source_appearance_species.get(actor.id,c.source_party_species.get(actor.id,""))).to_upper()
		y-=int(data.castform_forms[clampi(int(c.get_meta("source_castform_form",0)),0,3)]) if species=="CASTFORM" else int(data.by_species.get(species,0))
	return y
static func _clip(t: Dictionary,node: Sprite2D) -> void:
	var material:=ShaderMaterial.new();material.shader=load("res://scripts/battle/animations/sequence/source_dig.gdshader");t.materials.append({"node":node,"material":material,"previous":node.material});node.material=material;_paint(t)
static func _paint(t: Dictionary) -> void:
	for item: Dictionary in t.materials:
		if not is_instance_valid(item.node) or item.node.material!=item.material:continue
		var node: Sprite2D=item.node;var rect: Rect2=node.get_rect();var pixels: Rect2=node.region_rect if node.region_enabled else Rect2(Vector2(node.frame_coords)*node.texture.get_size()/Vector2(node.hframes,node.vframes),node.texture.get_size()/Vector2(node.hframes,node.vframes))
		item.material.set_shader_parameter("frame_uv_origin",pixels.position/node.texture.get_size());item.material.set_shader_parameter("frame_uv_size",pixels.size/node.texture.get_size());item.material.set_shader_parameter("native_top",node.position.y+rect.position.y*node.scale.y);item.material.set_shader_parameter("native_height",rect.size.y*node.scale.y);item.material.set_shader_parameter("floor_y",float(t.ground+32))
static func _cleanup(t: Dictionary) -> void:
	for item: Dictionary in t.get("materials",[]):
		if is_instance_valid(item.node) and item.node.material==item.material:item.node.material=item.previous
	t.erase("cleanup")
static func _copy_cleanup(t: Dictionary) -> void:
	for item: Dictionary in t.clones:
		if is_instance_valid(item.node):item.node.queue_free()
	t.erase("cleanup")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var actor: BattleAnimationActor=c.resolve("attacker")[0]
	if s.behavior=="source_dig_command":
		if s.mode in ["monbg","clear_monbg"]:return BattleCounterSelected.create(s,c,owner)
		if s.mode=="clear":
			var bg: Dictionary=owner.get_meta("source_dig_copy",{});actor.apply_source_state("hidden",false)
			if not bg.is_empty():bg.ticks=int(bg.age)+2
			return []
		var bg: Dictionary={"kind":"source_dig_copy","domain":"maintenance","age":0,"ticks":2147483647,"clones":[],"update":copy_update}
		for member: BattleAnimationActor in [actor,Geometry._partner(actor,c)]:
			if member==null or not member.is_present() or not member.sprite.is_visible_in_tree():continue
			var node: Sprite2D=BattleIdentityCopy.clone_sprite(member,owner);owner.add_child(node);node.z_index=BattleSourcePriority.relative_layer(member,1,c,owner);bg.clones.append({"actor":member,"node":node,"base":node.position})
		bg.cleanup=_copy_cleanup.bind(bg);owner.set_meta("source_dig_copy",bg);return [bg]
	var t: Dictionary={"kind":s.behavior,"settings":s,"owner":owner,"original_actor":actor,"age":0,"ticks":int(s.ticks),"stage":0,"phase_angle":0,"counter":0,"linear":0,"down":0,"offset":Vector2.ZERO,"materials":[],"update":advance,"ground":_ground(actor,c,owner,s)}
	if s.behavior=="source_dig_mound":
		var a: Array=s.source_args;var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;var rect: Array=s.frame_rects[str(int(a[1])*8)];node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);node.position=Vector2(Geometry._anchor(actor,c,owner,"origin").x-16+int(a[1])*32,int(t.ground)+32);owner.add_child(node);t.node=node;BattleSourcePriority.initialize(t,c,owner);return [t]
	t.cleanup=_cleanup.bind(t);advance(t,c)
	if s.source_callback=="sub_80E1244" and int(s.source_args[0])==1:_cleanup(t);return []
	return [t]
static func copy_update(_t: Dictionary,_c: BattleAnimationContext) -> void:pass
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if t.kind=="source_dig_mound":return
	var actor: BattleAnimationActor=t.original_actor;var mode: int=int(t.settings.source_args[0])
	if t.settings.source_callback=="sub_80E1244":
		if mode==1:
			actor.apply_source_state("hidden",true);t.owner._held_offsets[actor.id]=Vector2.ZERO;t.ticks=maxi(1,int(t.age));return
		match int(t.stage):
			0:
				t.top=maxi(0,int(t.ground)-32);var bg: Dictionary=t.owner.get_meta("source_dig_copy",{})
				for item: Dictionary in bg.get("clones",[]):
					if item.actor==actor:t.clone=item.node;t.base=item.base
				actor.apply_source_state("hidden",true);t.stage=1
			1:_clip(t,t.clone);t.stage=2
			2:
				t.phase_angle=(int(t.phase_angle)+6)&127;t.counter=int(t.counter)+1
				if int(t.counter)>2:t.counter=0;t.linear=int(t.linear)+1
				t.down=int(t.linear)+(BattleSourceTrig.sine(int(t.phase_angle),256)>>4)
				if int(t.down)>63:t.down=120-int(t.top);t.owner._held_offsets[actor.id]=Vector2(272-Geometry._anchor(actor,c,t.owner,"origin").x,0);t.stage=3
				t.clone.position=t.base+Vector2(0,int(t.down));_paint(t)
			3:t.stage=4
			4:actor.apply_source_state("hidden",true);t.ticks=int(t.age)
	else:
		if mode==0:
			if int(t.stage)==0:actor.apply_source_state("hidden",false);t.owner._held_offsets[actor.id]=Vector2(0,160-int(Geometry._anchor(actor,c,t.owner,"origin").y));t.stage=1
			else:t.ticks=int(t.age)
			return
		match int(t.stage):
			0:t.stage=1
			1:
				for bg: Dictionary in t.owner.get_meta("source_counter_monbg",[]):
					for item: Dictionary in bg.clones:
						if item.actor==actor:_clip(t,item.node)
				t.stage=2
			2:
				t.offset=Vector2(0,96);t.owner._held_offsets[actor.id]=t.offset
				for item: Dictionary in t.materials:item.node.position=Geometry._anchor(actor,c,t.owner,"origin")+t.offset
				_paint(t);t.stage=3
			3:
				t.offset.y-=8;t.owner._held_offsets[actor.id]=t.offset
				for item: Dictionary in t.materials:item.node.position=Geometry._anchor(actor,c,t.owner,"origin")+t.offset
				_paint(t)
				if t.offset.y==0:t.stage=4
			4:t.ticks=int(t.age)

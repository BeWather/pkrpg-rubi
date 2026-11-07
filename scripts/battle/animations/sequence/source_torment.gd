extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Task-owned bubbles and raw actor affine are distinct from logical anger sprite affine.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
const SpriteAffine=preload("res://scripts/battle/animations/sequence/source_self_heal.gd")
static func _restore_actor(t: Dictionary) -> void:
	if t.original_actor.is_present():
		# Restore an owned baseline exactly: repeated floating ratios otherwise drift.
		if t.original_actor._base_scale==t.owned_base_scale:
			t.original_actor._base_scale=t.base_scale;t.original_actor._expected_scale=t.base_scale*t.original_actor._scale_factor;t.original_actor.sprite.scale=t.original_actor._expected_scale
		else:t.original_actor.multiply_layout_scale(Vector2.ONE/t.factor)
		t.owned_base_scale=t.original_actor._base_scale
	t.factor=Vector2.ONE;t.owner._held_offsets[t.original_actor.id]=Vector2.ZERO
static func _cleanup(t: Dictionary) -> void:
	t.erase("cleanup");_restore_actor(t)
	for child: Dictionary in t.children:
		if is_instance_valid(child.node):child.node.queue_free()
	t.children.clear()
static func _palette_cleanup(t: Dictionary) -> void:t.erase("cleanup");t.material_lease.release()
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var actor: BattleAnimationActor=c.resolve("attacker" if s.behavior=="source_torment_thought" else "target")[0]
	var t: Dictionary={"kind":str(s.behavior),"settings":s,"owner":owner,"original_actor":actor,"age":0,"ticks":int(s.ticks),"phase":0,"counter":0,"update":advance}
	if s.behavior=="source_torment_palette":
		var material:=ShaderMaterial.new();material.shader=load("res://scripts/battle/animations/sequence/source_celestial_heal.gdshader");material.set_shader_parameter("color5",Vector3(31,0,0));material.set_shader_parameter("amount",0.0);material.set_shader_parameter("eva",1.0);material.set_shader_parameter("evb",0.0);t.material_lease=BattleOwnedMaterialLease.attach(actor,material);t.material=material;t.amount=0;t.cleanup=_palette_cleanup.bind(t);return [t]
	if s.behavior=="source_torment_thought":
		var species: String=str(c.source_appearance_species.get(actor.id,c.source_party_species.get(actor.id,""))).to_upper();var side: String="back" if c.contest or actor.side==0 else "front";var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(s.source_offsets)));var row: Dictionary=data.by_species.get(species,{})
		if not row.has(side):owner.error_message="Missing source Torment picture offset: "+species;owner.finish("failed");return []
		t.picture_height=64-2*int(row[side]);t.center=Geometry._anchor(actor,c,owner,"center");t.children=[];t.created=0;t.raw_matrix=Vector2(256,256);t.factor=Vector2.ONE;t.base_scale=actor._base_scale;t.owned_base_scale=actor._base_scale;t.affine_tick=0;t.cleanup=_cleanup.bind(t);return [t]
	var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;var rect: Array=s.frame_rects["0"];node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);owner.add_child(node)
	var x: int=int(s.source_args[1])*(-1 if actor.side==1 else 1);owner._source_args[1]=x&65535;var center: Vector2=Geometry._anchor(actor,c,owner,"center");node.position=Vector2(center.x+x,maxf(8,center.y+int(s.source_args[2])));t.node=node
	var material:=ShaderMaterial.new();material.shader=load("res://scripts/battle/animations/sequence/source_torment_anger.gdshader");node.material=material;SpriteAffine._start_affine(t,0);material.set_shader_parameter("source_scale",node.scale);BattleSourcePriority.initialize(t,c,owner);return [t]
static func _child_frame(child: Dictionary,s: Dictionary) -> void:
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(child.program,int(child.age)).frame;child.tile=int(frame.tile);var rect: Array=s.frame_rects[str(child.tile)];child.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);child.node.flip_h=bool(frame.get("flip_h",false))!=bool(child.base_flip)
static func _spawn(t: Dictionary,c: BattleAnimationContext) -> void:
	var n: int=t.created;var pair: int=n/2;var offset:=Vector2((32-6*pair)*(1 if n%2==0 else -1),-20-6*pair);var node:=Sprite2D.new();node.texture=load(str(t.settings.child.texture));node.region_enabled=true;node.position=t.center+offset;t.owner.add_child(node);node.z_index=BattleSourcePriority.relative_layer(t.original_actor,6-n,c,t.owner)
	var child: Dictionary={"node":node,"age":0,"program":t.settings.child.frame_program,"base_flip":n%2==1,"source_subpriority":6-n,"finished":false,"released":false,"created_age":int(t.age)};_child_frame(child,t.settings.child);t.children.append(child);t.created=n+1;t.affine_tick=0;t.raw_matrix=Vector2(256,256);t.phase=1;t.owner._play_sound(str(t.settings.source_sound_path),"SOUND_PAN_ATTACKER")
static func _pose_actor(t: Dictionary) -> void:
	var factor:=Vector2(256.0/t.raw_matrix.x,256.0/t.raw_matrix.y);t.original_actor.multiply_layout_scale(factor/t.factor);t.factor=factor;t.owned_base_scale=t.original_actor._base_scale
	var height: int=t.picture_height;var projected: int=mini(128,int(height*256)/int(t.raw_matrix.y));t.owner._held_offsets[t.original_actor.id]=Vector2(0,(height-projected)/2)
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if not t.original_actor.is_present():t.ticks=int(t.age);return
	if t.kind=="source_torment_palette":t.amount=int(t.age) if int(t.age)<=10 else 20-int(t.age);t.material.set_shader_parameter("amount",float(t.amount));return
	if t.kind=="source_torment_anger":
		if t.affine.ended:t.ticks=int(t.age);return
		SpriteAffine._affine(t);t.node.material.set_shader_parameter("source_scale",t.node.scale);return
	match int(t.phase):
		0:_spawn(t,c)
		1:
			if int(t.affine_tick)==12:
				_restore_actor(t)
				if int(t.created)==6:t.counter=8;t.phase=3
				else:t.counter=10 if int(t.created)<=2 else 0;t.phase=2
			else:
				t.affine_tick=int(t.affine_tick)+1;t.raw_matrix=BattleSourceCommandProgram.evaluate(t.settings.source_affine_program,int(t.affine_tick),true).matrix;_pose_actor(t)
		2,3:
			if int(t.counter)>0:t.counter=int(t.counter)-1
			else:t.phase=0 if int(t.phase)==2 else 4
		4:
			for child: Dictionary in t.children:child.program=t.settings.child.source_contract_program;child.age=0;child.finished=false;child.created_age=int(t.age)
			t.phase=5
		5:
			if t.children.all(func(child: Dictionary)->bool:return bool(child.released)):t.ticks=int(t.age)
	for child: Dictionary in t.children:
		if child.released:continue
		if int(t.phase)==5 and child.finished:child.node.queue_free();child.released=true;continue
		if int(child.created_age)!=int(t.age):child.age=int(child.age)+1
		_child_frame(child,t.settings.child)
		if int(t.phase)==5:child.finished=bool(BattleSourceCommandProgram.evaluate(child.program,int(child.age)).ended)

extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Source fight.c816–952. Actor BG copies/rocks/meteor stay opaque; auraOBJ alone blends.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
const Affine=preload("res://scripts/battle/animations/sequence/source_self_heal.gd")
const Packed=preload("res://scripts/battle/animations/sequence/source_sports.gd")
static func _center(actor: BattleAnimationActor,c: BattleAnimationContext,owner: Node2D) -> Vector2:
	var v: Vector2=Geometry._anchor(actor,c,owner,"center");return Vector2(int(v.x),int(v.y))
static func _field(t: Dictionary,y: int) -> void:
	t.register_y=y
	for item: Dictionary in t.nodes:
		if not is_instance_valid(item.node):continue
		item.base+=item.node.position-item.expected;item.node.position=item.base-Vector2(0,y);item.expected=item.node.position
static func _release_field(t: Dictionary) -> void:t.erase("cleanup");_field(t,0)
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if s.behavior=="source_superpower_command":
		# ScriptCmd_setalpha contains no BG first-target bit.
		if s.mode in ["alpha","blend_off"]:owner.set_meta("source_superpower_alpha",s.get("blend_pair",[16,0]));return []
		return BattleCounterSelected.create(s,c,owner)
	var t: Dictionary={"kind":s.behavior,"settings":s,"owner":owner,"age":0,"ticks":int(s.ticks),"phase":0,"update":advance}
	if s.behavior=="source_superpower_quake":
		t.nodes=BattleSoundOwnership.create_field_offset({"ticks":181,"source_args":[0,0,0,0],"register_mode":"toggle_add"},c)[0].nodes;t.register_y=0;t.cleanup=_release_field.bind(t);return [t]
	var actor: BattleAnimationActor=c.resolve("attacker")[0];var target: BattleAnimationActor=c.resolve("target")[0];t.original_actor=actor;t.target_actor=target;t.origin=_center(actor,c,owner);t.destination=_center(target,c,owner);var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;owner.add_child(node);t.node=node;t.tile=int(s.source_args[2])*4 if s.behavior=="source_superpower_rock" else 0;var rect: Array=s.frame_rects[str(t.tile)];node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);BattleSourcePriority.initialize(t,c,owner)
	if s.behavior=="source_superpower_rock":t.yq=120*256;node.position=Vector2(int(s.source_args[0]),120)
	else:
		node.position=t.origin;t.source_oam_priority=2 if c.contest or c.source_position(actor.id) in [0,3] else 1
		if s.behavior=="source_superpower_aura":
			Affine._start_affine(t,0);node.material=BattleIdentityCopy.blend_material(false);var pair: Array=owner.get_meta("source_superpower_alpha",[16,0]);node.material.set_shader_parameter("eva",float(pair[0])/16);node.material.set_shader_parameter("evb",float(pair[1])/16)
		else:node.flip_h=not c.contest and target.side==0;node.flip_v=c.contest or target.side==0;Packed._arc(t,t.destination,16,0)
	return [t]
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if t.kind=="source_superpower_quake":_field(t,-4 if int(t.age)<181 and (int(t.age)/2)%2 else 0);return
	if t.kind=="source_superpower_aura":
		Affine._affine(t)
		if int(t.age)==180:
			# sub_80D986C disables BLDCNT at transition, not just sprite visibility.
			t.node.material=null;t.owner.set_meta("source_superpower_alpha",[16,0]);t.destination=_center(t.target_actor,c,t.owner);Packed._arc(t,t.destination,16,0)
		elif int(t.age)>180:
			if Packed._translate(t):t.ticks=int(t.age)
			else:t.node.position=t.origin+t.offset
		return
	if t.kind=="source_superpower_meteor":
		if Packed._translate(t):t.ticks=int(t.age)
		else:t.node.position=t.origin+t.offset
		return
	var a: Array=t.settings.source_args
	if int(t.age)<=int(a[3]):
		t.yq=int(t.yq)-int(a[1]);t.node.position.y=int(t.yq)>>8
		if t.node.position.y< -8:t.ticks=int(t.age)
	elif int(t.age)==int(a[3])+1:t.position_q=t.node.position*16;t.velocity=_center(t.target_actor,c,t.owner)-_center(t.original_actor,c,t.owner)
	else:
		t.position_q+=t.velocity;t.node.position=Vector2(int(t.position_q.x)>>4,int(t.position_q.y)>>4)
		if ((int(t.node.position.x)+8)&65535)>256 or t.node.position.y< -8 or t.node.position.y>120:t.ticks=int(t.age)

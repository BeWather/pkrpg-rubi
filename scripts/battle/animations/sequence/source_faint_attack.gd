extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Dark fades target the attacker's primary BG plane, not BG3 or all OBJ.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func _plane(a: BattleAnimationActor,c: BattleAnimationContext) -> int:return 1 if c.contest or c.source_position(a.id) in [1,2] else 2
static func _blend(owner: Node2D,mask: int,eva: int,evb: int) -> void:
	owner.set_meta("source_faint_mask",mask);owner.set_meta("source_faint_pair",[eva,evb])
	for bg: Dictionary in owner.get_meta("source_faint_backgrounds",[]):
		for item: Dictionary in bg.clones:
			if not is_instance_valid(item.node):continue
			if (mask&(1<<int(item.plane)))!=0:
				if item.material==null:item.material=BattleIdentityCopy.blend_material(false);item.node.material=item.material
				if item.node.material==item.material:item.material.set_shader_parameter("eva",float(eva)/16);item.material.set_shader_parameter("evb",float(evb)/16)
			elif item.material!=null and item.node.material==item.material:item.node.material=null;item.material=null
static func _copy_cleanup(t: Dictionary) -> void:
	for item: Dictionary in t.clones:
		if is_instance_valid(item.node):item.node.queue_free()
	t.clones.clear();t.erase("cleanup")
static func _info_cleanup(t: Dictionary) -> void:t.owner.set_meta("source_faint_info",t.previous);t.erase("cleanup")
static func _ellipse_cleanup(t: Dictionary) -> void:
	if t.owner._held_offsets.get(t.original_actor.id,Vector2.ZERO)==t.offset:t.owner._held_offsets[t.original_actor.id]=Vector2.ZERO
	t.erase("cleanup")
static func copy_update(t: Dictionary,c: BattleAnimationContext) -> void:
	for item: Dictionary in t.clones:
		if not item.actor.is_present():continue
		item.node.position=Geometry._anchor(item.actor,c,t.owner,"origin")+t.owner._held_offsets.get(item.actor.id,Vector2.ZERO)
static func _command(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var actor: BattleAnimationActor=c.resolve("attacker")[0];var role: int=int(s.source_args[0]) if not s.source_args.is_empty() else 0
	if s.mode=="invisible":actor.apply_source_state("hidden",true);return []
	if s.mode in ["alpha","off"]:_blend(owner,0,int(s.source_args[0]) if s.mode=="alpha" else 0,int(s.source_args[1]) if s.mode=="alpha" else 0);return []
	if s.mode=="clear":
		for bg: Dictionary in owner.get_meta("source_faint_backgrounds",[]):
			if int(bg.role)!=role:continue
			for item: Dictionary in bg.clones:item.actor.apply_source_state("hidden",false)
			bg.ticks=int(bg.age)+2
		return []
	var selected: BattleAnimationActor=c.resolve("attacker" if role==0 else "target")[0]
	var t: Dictionary={"kind":"source_faint_bg","domain":"maintenance","role":role,"owner":owner,"age":0,"ticks":2147483647,"clones":[],"update":copy_update}
	for member: BattleAnimationActor in [selected,Geometry._partner(selected,c)]:
		if member==null or not member.is_present() or (c.contest and member!=actor):continue
		# IsAnimBankSpriteVisible consults saved battle info OR current OBJ.
		if member==actor and bool(owner.get_meta("source_faint_info",false)) and not member.sprite.visible:continue
		var node: Sprite2D=BattleIdentityCopy.clone_sprite(member,owner);owner.add_child(node);node.z_index=BattleSourcePriority.relative_layer(member,1,c,owner);t.clones.append({"actor":member,"node":node,"plane":_plane(member,c),"material":null});member.apply_source_state("hidden",true)
	t.cleanup=_copy_cleanup.bind(t);var bgs: Array=owner.get_meta("source_faint_backgrounds",[]);bgs.append(t);owner.set_meta("source_faint_backgrounds",bgs);var pair: Array=owner.get_meta("source_faint_pair",[0,0]);_blend(owner,int(owner.get_meta("source_faint_mask",0)),int(pair[0]),int(pair[1]));return [t]
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if s.behavior=="source_faint_command":return _command(s,c,owner)
	if s.behavior=="source_faint_hit":
		var tracks: Array[Dictionary]=BattleFieldOwned.create(s,c,owner);var pair: Array=owner.get_meta("source_faint_pair",[0,0])
		for t: Dictionary in tracks:
			t.node.material=BattleIdentityCopy.blend_material(false);t.node.material.set_shader_parameter("eva",float(pair[0])/16);t.node.material.set_shader_parameter("evb",float(pair[1])/16)
		return tracks
	var actor: BattleAnimationActor=c.resolve("attacker")[0];var mode: String=str(s.mode);var mask: int=1<<_plane(actor,c)
	if mode=="restore":_blend(owner,mask,0,16);return []
	var t: Dictionary={"kind":"source_faint_task","settings":s,"mode":mode,"owner":owner,"original_actor":actor,"age":0,"ticks":int(s.ticks),"counter":0,"mask":mask,"clones":[],"offset":Vector2.ZERO,"update":advance}
	if mode=="ellipse":t.ticks=31;t.cleanup=_ellipse_cleanup.bind(t);owner._held_offsets[actor.id]=Vector2.ZERO;return [t]
	if mode=="info":
		if c.contest:return []
		t.previous=bool(owner.get_meta("source_faint_info",false));owner.set_meta("source_faint_info",true);t.domain="maintenance";t.cleanup=_info_cleanup.bind(t);return [t]
	t.eva=16 if mode=="hide" else 0;t.evb=0 if mode=="hide" else 16;_blend(owner,mask,int(t.eva),int(t.evb))
	for bg: Dictionary in owner.get_meta("source_faint_backgrounds",[]):
		for item: Dictionary in bg.clones:
			if int(item.plane)==_plane(actor,c):t.clones.append(item)
	return [t]
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if t.mode=="info":
		if int(t.owner._source_args.get(7,0))==4096:_info_cleanup(t);t.ticks=int(t.age)
		return
	if t.mode=="ellipse":
		var phase: int=(int(t.age)*8)&255;t.offset=Vector2(BattleSourceTrig.sine(phase,18 if t.original_actor.side==0 else -18),6-BattleSourceTrig.cosine(phase,6)) if int(t.age)<31 else Vector2.ZERO;t.owner._held_offsets[t.original_actor.id]=t.offset
		for bg: Dictionary in t.owner.get_meta("source_faint_backgrounds",[]):copy_update(bg,c)
		return
	t.counter=int(t.counter)+1
	if int(t.counter)<=1:return
	t.counter=0;t.eva=int(t.eva)+(-1 if t.mode=="hide" else 1);t.evb=16-int(t.eva);_blend(t.owner,int(t.mask),int(t.eva),int(t.evb))
	if int(t.eva)==(0 if t.mode=="hide" else 16):
		if t.mode=="hide":t.original_actor.apply_source_state("hidden",true)
		else:_blend(t.owner,0,0,0)
		t.ticks=int(t.age)

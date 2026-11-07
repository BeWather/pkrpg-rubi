extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Target OBJ enlargement/blend plus opaque unscaled monBG copies, not global BG gray.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func _material(gray: bool=false,eva: float=1.0,evb: float=0.0) -> ShaderMaterial:
	var m:=ShaderMaterial.new();m.shader=load("res://scripts/battle/animations/sequence/source_disable.gdshader");m.set_shader_parameter("gray",gray);m.set_shader_parameter("eva",eva);m.set_shader_parameter("evb",evb);return m
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if s.behavior=="source_disable_command":return _command(s,c,owner)
	var actors: Array[BattleAnimationActor]=c.resolve("attacker");var targets: Array[BattleAnimationActor]=c.resolve("target")
	if actors.is_empty() or targets.is_empty():return []
	var actor: BattleAnimationActor=actors[0];var target: BattleAnimationActor=targets[0]
	if s.behavior=="source_disable_sparkle":
		var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;owner.add_child(node)
		var t: Dictionary={"kind":"source_disable_sparkle","settings":s,"node":node,"original_actor":actor,"age":0,"ticks":int(s.ticks),"update":advance}
		node.position=Geometry._anchor(actor,c,owner,"center")+Vector2(24 if actor.side==0 else -24,-16);BattleSourcePriority.initialize(t,c,owner);_sparkle(t,0);return [t]
	var pair: Array=owner.get_meta("source_disable_alpha",[16,0]);var material: ShaderMaterial=_material(true,float(pair[0])/16,float(pair[1])/16);var lease:=BattleOwnedMaterialLease.attach(target,material)
	var t: Dictionary={"kind":"source_disable_shadow","settings":s,"owner":owner,"original_actor":target,"base_scale":target.sprite.scale,"material_lease":lease,"age":0,"ticks":81,"remaining":80,"update":advance}
	t.cleanup=_restore.bind(t);target.apply_source_state("hidden",false);target.sprite.scale=t.base_scale*256.0/208.0;_gray_bg(owner,target,true);return [t]
static func _sparkle(t: Dictionary,age: int) -> void:
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.frame_program,age).frame;var rect: Array=t.settings.frame_rects[str(int(frame.tile))];t.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3])
static func _gray_bg(owner: Node2D,actor: BattleAnimationActor,gray: bool) -> void:
	var bg: Dictionary=owner.get_meta("source_disable_bg",{})
	for entry: Dictionary in bg.get("clones",[]):
		if entry.actor==actor and is_instance_valid(entry.node):entry.node.material.set_shader_parameter("gray",gray)
static func _restore(t: Dictionary) -> void:
	t.erase("cleanup")
	if t.original_actor.is_present():t.original_actor.sprite.scale=t.base_scale
	t.material_lease.release();_gray_bg(t.owner,t.original_actor,false)
static func _bg_cleanup(t: Dictionary) -> void:
	t.erase("cleanup")
	for entry: Dictionary in t.clones:
		entry.actor.apply_source_state("hidden",false)
		if is_instance_valid(entry.node):entry.node.queue_free()
	t.clones.clear()
static func _command(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var mode: String=str(s.mode);var bg: Dictionary=owner.get_meta("source_disable_bg",{})
	if mode=="alpha":owner.set_meta("source_disable_alpha",s.source_args.duplicate());return []
	if mode=="off":owner.set_meta("source_disable_alpha",[16,0]);return []
	if mode=="clear":
		if not bg.is_empty():
			for entry: Dictionary in bg.clones:entry.actor.apply_source_state("hidden",false)
			bg.ticks=int(bg.age)+2
		return []
	var targets: Array[BattleAnimationActor]=c.resolve("target")
	if targets.is_empty():return []
	if mode=="priority":
		if not c.contest and c.source_position(targets[0].id) in [0,3]:
			for entry: Dictionary in bg.get("clones",[]):
				if entry.bg_plane==1:entry.node.z_index=int(entry.base_z)+1
		return []
	var selected: Array[BattleAnimationActor]=[targets[0]];var partner: BattleAnimationActor=Geometry._partner(targets[0],c)
	if partner!=null:selected.append(partner)
	var t: Dictionary={"kind":"source_disable_bg","domain":"maintenance","owner":owner,"clones":[],"age":0,"ticks":2147483647,"update":advance}
	for actor: BattleAnimationActor in selected:
		if not actor.is_present() or not actor.sprite.visible or (c.contest and actor.id!=c.attacker_id):continue
		var node: Sprite2D=BattleIdentityCopy.clone_sprite(actor,owner);owner.add_child(node);node.z_index=BattleSourcePriority.relative_layer(actor,1,c,owner);node.material=_material()
		t.clones.append({"actor":actor,"node":node,"base_scale":node.scale,"base_z":node.z_index,"bg_plane":1 if c.contest or c.source_position(actor.id) in [1,2] else 2});actor.apply_source_state("hidden",true)
	t.cleanup=_bg_cleanup.bind(t);owner.set_meta("source_disable_bg",t);return [t]
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if t.kind=="source_disable_bg":
		for entry: Dictionary in t.clones:
			if entry.actor.is_present():entry.node.position=Geometry._anchor(entry.actor,c,t.owner,"origin")
			else:entry.node.hide()
		return
	if not t.original_actor.is_present():t.ticks=int(t.age);return
	if t.kind=="source_disable_sparkle":_sparkle(t,int(t.age));return
	t.remaining=int(t.remaining)-1
	if int(t.remaining)==-1:t.ticks=int(t.age)

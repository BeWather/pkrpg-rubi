extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Aromatherapy-local source normal fade, flowers and BG1 masked cure stream.
const Wind=preload("res://scripts/battle/animations/sequence/source_wind_feather_particles.gd")
const Heal=preload("res://scripts/battle/animations/sequence/source_self_heal.gd")
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if s.behavior=="source_aroma_monbg":return BattleCounterSelected.create(s,c,owner)
	if s.behavior=="source_aroma_flower":
		var result: Array[Dictionary]=Wind.create(s,c,owner)
		for t: Dictionary in result:
			t.kind="source_aroma_flower";t.update=advance;t.source_oam_priority=(2 if c.contest or c.source_position(t.selected.id) in [0,3] else 1)+(1 if bool(t.behind) else 0)
			if not s.affine_program.is_empty():Heal._start_affine(t,0)
		return result
	var t: Dictionary={"kind":str(s.behavior),"settings":s,"owner":owner,"age":0,"ticks":int(s.ticks),"update":advance,"members":[]}
	if s.behavior=="source_aroma_mask":
		t.coefficient=0;t.scroll=0
		for actor: BattleAnimationActor in c.resolve("attacker_side"):
			if not actor.is_present() or not actor.sprite.visible or (c.contest and actor.id!=c.attacker_id):continue
			var node: Sprite2D=BattleIdentityCopy.clone_sprite(actor,owner);owner.add_child(node);node.z_index=BattleSourcePriority.relative_layer(actor,1,c,owner)
			var m:=ShaderMaterial.new();m.shader=load("res://scripts/battle/animations/sequence/source_aromatherapy.gdshader");m.set_shader_parameter("mask_texture",load(str(s.texture)));m.set_shader_parameter("field_origin",BattleElectricContract.source_anchor(actor,c,"origin"));m.set_shader_parameter("actor_size",actor.sprite.texture.get_size()/Vector2(actor.sprite.hframes,actor.sprite.vframes));node.material=m;t.members.append({"actor":actor,"node":node,"material":m})
		t.cleanup=_mask_cleanup.bind(t);return [t]
	t.amount=int(s.source_args[2]);t.bg_amount=t.amount;t.obj_amount=0;t.toggle=1;t.delay=0;t.finishing=-1
	var rect:=ColorRect.new();rect.size=c.field_size;rect.mouse_filter=Control.MOUSE_FILTER_IGNORE;owner.add_child(rect);t.node=rect
	for actor: BattleAnimationActor in c.actors.values():
		if actor.is_present():rect.z_index=mini(rect.z_index,BattleSourcePriority.actor_layer(actor,owner)-1)
	if int(s.source_args[0])==43:
		for actor: BattleAnimationActor in c.resolve("attacker_side"):
			if not actor.is_present() or (c.contest and actor.id!=c.attacker_id):continue
			var m:=ShaderMaterial.new();m.shader=load("res://scripts/battle/animations/sequence/palette_blend.gdshader");m.set_shader_parameter("blend_color",Color(13.0/31,1,12.0/31));t.members.append({"lease":BattleOwnedMaterialLease.attach(actor,m),"material":m})
	# A BG-only hold survives its fade task until the following explicit restore.
	if owner.has_meta("source_aroma_bg"):
		if is_instance_valid(owner.get_meta("source_aroma_bg")):owner.get_meta("source_aroma_bg").queue_free()
	owner.set_meta("source_aroma_bg",rect);_palette(t);t.cleanup=_palette_cleanup.bind(t);return [t]
static func _palette(t: Dictionary) -> void:
	t.node.color=Color(13.0/31,1,12.0/31,float(t.bg_amount)/16)
	for member: Dictionary in t.members:member.material.set_shader_parameter("blend_amount",float(t.obj_amount)/16)
static func _palette_cleanup(t: Dictionary) -> void:
	t.erase("cleanup")
	for member: Dictionary in t.members:member.lease.release()
	if int(t.settings.source_args[3])!=0:
		# The runner ordinarily frees expired track.node; retain only this owned hold.
		t.erase("node")
static func _mask_cleanup(t: Dictionary) -> void:
	t.erase("cleanup")
	for member: Dictionary in t.members:
		if is_instance_valid(member.node):member.node.queue_free()
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if t.kind=="source_aroma_flower":
		Wind.advance(t,c)
		if t.has("affine"):
			Heal._affine(t);t.source_scale=t.affine.matrix/256.0;t.source_rotation=-float(t.affine.rotation)*TAU/256;Wind._paint(t,c)
		return
	if t.kind=="source_aroma_mask":
		var age: int=t.age;t.coefficient=mini(10,age/3) if age<=30 else 10 if age<=60 else maxi(0,10-(age-60)/3);t.scroll=(age*416)>>8
		for member: Dictionary in t.members:
			member.node.position=Geometry._anchor(member.actor,c,t.owner,"origin");member.material.set_shader_parameter("coefficient",float(t.coefficient)/16);member.material.set_shader_parameter("scroll",float(t.scroll))
		return
	if int(t.finishing)>=0:t.finishing=int(t.finishing)+1;return
	if int(t.toggle)==0 and int(t.delay)<int(t.settings.source_args[1]):t.delay=int(t.delay)+1;return
	t.delay=0
	if int(t.toggle)==0:t.bg_amount=int(t.amount)
	else:t.obj_amount=int(t.amount)
	t.toggle=1-int(t.toggle)
	if int(t.toggle)==0:
		var destination: int=t.settings.source_args[3]
		if int(t.amount)==destination:t.finishing=0
		else:t.amount=int(t.amount)+signi(destination-int(t.amount))*mini(2,absi(destination-int(t.amount)))
	_palette(t)

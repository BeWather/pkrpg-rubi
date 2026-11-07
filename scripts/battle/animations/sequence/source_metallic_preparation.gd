extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Finite source task transaction. Private materials never adopt custom writers.
const Same=preload("res://scripts/battle/animations/sequence/source_cutting_slice.gd")
const PATH := "res://scripts/battle/animations/sequence/source_metallic_preparation.gdshader"
const META := "source_metallic_lease"
# script, line, sweep PC, restore policy, palette mode, label source PC, restore PC
const SITES := {
	"ruby:move/106":["Move_HARDEN",4572,1,0,0,-1,-1],
	"ruby:move/211":["Move_STEEL_WING",7204,10,0,0,6103,-1],
	"ruby:move/231":["Move_IRON_TAIL",7230,8,1,0,6127,38],
	"ruby:move/232":["Move_METAL_CLAW",7270,1,0,0,-1,-1],
	"ruby:move/334":["Move_IRON_DEFENSE",4360,1,0,0,-1,-1],
	"ruby:move/342":["Move_POISON_TAIL",7250,10,1,1,6145,40],
}
const ROWS := [48,47,46,46,45,44,43,43,42,41,40,40,39,38,37,37,36,35,34,34,33,32,31,30,30,29,28,27,27,26,25,24,24,23,22,21,21,20,19,18,18,17,16,15,14,14,13,12,11,11,10,9,8,8,7,6,5,5,4,3,2,2,1,0]
static var _palettes: Dictionary={}
static var _mask: Image
static var _mask_texture: ImageTexture

static func _shapes(a: Array) -> Dictionary:
	var args: Array=[a[3],a[4],23768 if a[4]==1 else 0]
	var sweep: Dictionary={"op":"effect","behavior":"metallic_sweep","ticks":56,"selector":"attacker","source_task":"sub_80E0A4C","source_line":a[1]}
	var shapes: Dictionary={}
	if a[5]>=0:
		sweep.ticks=64;sweep.source_args=args;sweep.native_substitution="owned shader sweep substitutes source64-tick double BG sweep; source grayscale/tint and explicit later restore retained"
		shapes[a[2]-2]={"op":"source_label","source_pc":a[5],"source_line":a[1],"source_command":"createvisualtask sub_80E0A4C, 5, "+", ".join(args.map(func(v):return str(v))),"source_args":args}
		shapes[a[2]-1]={"op":"source_actor_state","selector":"attacker","property":"grayscale","value":true,"source_task":"sub_80E0A4C","source_line":a[1]} if a[4]==0 else {"op":"effect","behavior":"source_palette","selector":"attacker","ticks":1,"blend_start":11,"blend_end":11,"blend_delay":1,"color":"c531bd","source_task":"sub_80E0A4C","source_line":a[1]}
	shapes[a[2]]=sweep
	if a[6]>=0:
		var line: int=7240 if a[4]==0 else 7260
		shapes[a[6]]={"op":"source_actor_state","selector":"attacker","property":"grayscale","value":false,"source_task":"sub_80E0E24","source_line":line}
		shapes[a[6]-1]={"op":"source_label","source_pc":6137 if a[4]==0 else 6155,"source_line":line,"source_command":"createvisualtask sub_80E0E24, 5, 0, 1","source_args":[0,1]}
	return shapes

static func _provider(c: BattleAnimationContext,owner: Node2D) -> bool:
	if not is_instance_valid(c.field) or not c.field.is_inside_tree():return false
	for node: Node2D in [c.field,owner]:
		if not node.global_transform.is_finite() or is_zero_approx(node.global_transform.determinant()):return false
	var root: Node=c.field
	while root!=null:
		if root.scene_file_path=="res://herramientas/laboratorio_animaciones/laboratorio_animaciones.tscn":return root.field==c.field
		if root.scene_file_path=="res://escenas/batalla/batalla.tscn":return root.get_node_or_null("Campo")==c.field and c.field.get_node_or_null("btlFondo") is Sprite2D
		root=root.get_parent()
	return false

static func _eligible(owner: Node2D,a: Array) -> bool:
	if not BattleAnimationSequenceRegistry.is_builtin_source_definition(owner.definition) or owner.definition.source_script!=a[0]:return false
	var shapes:=_shapes(a)
	for pc: int in shapes:
		if pc>=owner._steps.size() or pc>=owner.definition.steps.size():return false
		if not Same._same(owner._steps[pc],shapes[pc]) or not Same._same(owner.definition.steps[pc],shapes[pc]):return false
	return true

static func _native_available(owner: Node2D) -> bool:
	var c: BattleAnimationContext=owner.context
	if not _provider(c,owner) or not c.actors.has(c.attacker_id):return false
	var actor: BattleAnimationActor=c.actors[c.attacker_id]
	if not actor.is_present() or c.source_position(actor.id) not in [0,1,2,3] or not c.source_positions.has(actor.id):return false
	if (c.source_position(actor.id)&1)!=actor.side:return false
	if not actor.sprite.global_transform.is_finite() or is_zero_approx(actor.sprite.global_transform.determinant()):return false
	# Transaction declines BEFORE generic companion writes; matching shader path is not authority.
	return actor.sprite.material==null and not actor.sprite.use_parent_material and actor._blend_material==null and not actor._owned_grayscale and not actor._owned_invert and load(PATH).code==FileAccess.get_file_as_string(PATH)

static func consume(step: Dictionary,owner: Node2D) -> bool:
	var a: Array=SITES.get(owner.definition.key,[])
	if a.is_empty():return false
	var first: int=a[2]-1 if a[5]>=0 else a[2]
	if owner._pc not in [first,a[2],a[6]]:return false
	if not owner.has_meta("source_metallic_decision"):
		if owner._pc!=first:return false
		owner.set_meta("source_metallic_decision","native" if _eligible(owner,a) and _native_available(owner) else "opt_out" if _eligible(owner,a) else "literal")
	if owner.get_meta("source_metallic_decision")=="literal":return false
	var shapes:=_shapes(a)
	if not shapes.has(owner._pc) or not Same._same(step,shapes[owner._pc]):return false
	if owner.get_meta("source_metallic_decision")=="opt_out":
		# Canonical custom material/invalid provider: consume THIS whole group,
		# never just its first companion then fall through to a generic writer.
		if owner._pc==a[2]:owner._tracks.append({"kind":"source_metallic_opt_out","age":0,"ticks":int(step.ticks),"settings":step.duplicate(true)})
		return true
	if owner._pc==a[6]:release(owner);return true
	if owner._pc==first:_acquire(owner,a)
	if owner._pc==a[2]:
		var lease: Dictionary=owner.get_meta(META,{})
		if not lease.is_empty():owner._tracks.append(_track(owner,a,step,lease))
	return true

static func _palette(mode: int) -> Dictionary:
	if _palettes.has(mode):return _palettes[mode]
	var values:=PackedInt32Array();values.resize(32768)
	var image:=Image.create(256,128,false,Image.FORMAT_RGBA8)
	for c: int in 32768:
		var out: int=0
		if mode==0:
			var mean: int=((c&31)+((c>>5)&31)+((c>>10)&31))/3;out=mean|(mean<<5)|(mean<<10)
		else:
			for channel: int in 3:
				var v: int=(c>>(channel*5))&31
				out|=(v+((([24,6,23][channel]-v)*11)>>4))<<(channel*5)
		values[c]=out;image.set_pixel(c%256,c/256,Color(float(out&31)/31,float((out>>5)&31)/31,float((out>>10)&31)/31,1))
	_palettes[mode]={"values":values,"image":image,"texture":ImageTexture.create_from_image(image)}
	return _palettes[mode]

static func _mask_data() -> void:
	if _mask!=null:return
	_mask=Image.create(256,256,false,Image.FORMAT_RGBA8)
	for y: int in 64:
		for x: int in 64:
			var delta: int=x-ROWS[y]
			if delta>=0 and (delta<11 or (delta>=14 and delta<16)):_mask.set_pixel(x,y,Color.WHITE)
	_mask_texture=ImageTexture.create_from_image(_mask)

static func _material(mode: int,band: bool,params: Dictionary) -> ShaderMaterial:
	var m:=ShaderMaterial.new();m.shader=load(PATH)
	m.set_shader_parameter("palette_mode",mode);m.set_shader_parameter("band_only",band)
	m.set_shader_parameter("palette_lut_texture",_palette(mode).texture)
	for key: String in params:m.set_shader_parameter(key,params[key])
	return m

static func _expected(m: ShaderMaterial) -> Dictionary:
	var result: Dictionary={}
	for name: String in ["palette_mode","band_only","palette_lut_texture","source_mask","sweep_shift","bg_origin","field_origin","field_x","field_y"]:result[name]=m.get_shader_parameter(name)
	return result

static func _matches(m: ShaderMaterial,shader: Shader,code: String,expected: Dictionary) -> bool:
	if m.shader!=shader or shader.code!=code:return false
	for key: String in expected:
		if m.get_shader_parameter(key)!=expected[key]:return false
	return true

static func _acquire(owner: Node2D,a: Array) -> void:
	var actor: BattleAnimationActor=owner.context.actors[owner.context.attacker_id]
	var m:=_material(a[4],false,{})
	actor.sprite.material=m
	owner.set_meta(META,{"subject":actor,"parent":actor.sprite.get_parent(),"material":m,"shader":m.shader,"code":m.shader.code,"expected":_expected(m),"owned":true})

static func _track(owner: Node2D,a: Array,step: Dictionary,lease: Dictionary) -> Dictionary:
	_mask_data()
	var actor: BattleAnimationActor=lease.subject;var c: BattleAnimationContext=owner.context
	var node:=Sprite2D.new();var source: Sprite2D=actor.sprite
	for key: String in ["texture","hframes","vframes","frame","flip_h","flip_v","region_enabled","region_rect","centered","offset","texture_filter"]:node.set(key,source.get(key))
	node.modulate=source.modulate;owner.add_child(node);node.global_transform=source.global_transform
	# Private native plane projection, NOT raw OAM priority/framebuffer parity.
	node.z_index=BattleSourcePriority.actor_layer(actor,owner)+1
	var position: int=c.source_position(actor.id);var priority: int=0
	for other: BattleAnimationActor in c.actors.values():
		if not c.contest and position in [0,3] and c.source_position(other.id)==(position^2) and other.is_present() and other.sprite.is_visible_in_tree():priority=1
	var tf: Transform2D=c.field.global_transform.affine_inverse()*source.global_transform
	var bg: Vector2=c.field.to_local(source.get_parent().to_global(actor._base_position))
	var m:=_material(a[4],true,{"source_mask":_mask_texture,"sweep_shift":0,"bg_origin":bg,"field_origin":tf.origin,"field_x":tf.x,"field_y":tf.y});node.material=m
	var t: Dictionary={"kind":"source_metallic_preparation","age":0,"ticks":64,"subject":actor,"restore_policy":a[3],"mode":a[4],"bg_origin":bg,"bg_priority":priority,"pass_count":0,"node":node,"material":m,"shader":m.shader,"code":m.shader.code,"expected":_expected(m),"band_owned":true,"palette_material":lease.material,"palette_lut":_palette(a[4]).values,"palette_image":_palette(a[4]).image,"mask_image":_mask,"settings":step.duplicate(true),"update":advance}
	lease.track=t;t.cleanup=retire.bind(owner,t);return t

static func observe(owner: Node2D) -> void:
	var lease: Dictionary=owner.get_meta(META,{})
	if lease.is_empty():return
	var actor: BattleAnimationActor=lease.subject
	if owner.context.actors.get(actor.id)!=actor or not actor.is_present() or actor.sprite.get_parent()!=lease.parent or not _provider(owner.context,owner):lease.owned=false
	elif actor.sprite.material!=lease.material or not _matches(lease.material,lease.shader,lease.code,lease.expected):lease.owned=false
	if not lease.owned and lease.has("track") and is_instance_valid(lease.track.node):lease.track.node.visible=false

static func advance(t: Dictionary,_context: BattleAnimationContext) -> void:
	t.pass_count=int(t.age)/32
	if not t.band_owned or not is_instance_valid(t.node):return
	if t.node.material!=t.material or not _matches(t.material,t.shader,t.code,t.expected):t.band_owned=false;return
	var shift: int=(int(t.age)%32)*4
	t.material.set_shader_parameter("sweep_shift",shift);t.expected.sweep_shift=shift

static func retire(owner: Node2D,t: Dictionary) -> void:
	t.erase("cleanup")
	var lease: Dictionary=owner.get_meta(META,{})
	lease.erase("track")
	if int(t.restore_policy)==0:release(owner)

static func release(owner: Node2D) -> void:
	observe(owner)
	var lease: Dictionary=owner.get_meta(META,{})
	if lease.is_empty():return
	if lease.owned:lease.subject.sprite.material=null
	lease.erase("track");owner.remove_meta(META)

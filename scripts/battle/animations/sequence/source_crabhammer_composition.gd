extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Finite Crabhammer152: source clocks, input-palette transport and local pose channels.
## Generic literals retain their existing behavior; no other family supplies authority.
const Data=preload("res://scripts/battle/animations/sequence/source_crabhammer_data.gd")
const Same=preload("res://scripts/battle/animations/sequence/source_cutting_slice.gd")
const Owned=preload("res://scripts/battle/animations/sequence/source_owned_composition.gd")
const Trig=preload("res://scripts/battle/animations/sequence/source_trig.gd")
const Electric=preload("res://scripts/battle/animations/sequence/source_electric_contract.gd")
const Fast=preload("res://scripts/battle/animations/sequence/source_program_proof.gd")
const AB=preload("res://scripts/battle/animations/sequence/source_agility_aerial_palette_ab.gdshader")
const PALETTE=preload("res://scripts/battle/animations/sequence/palette_blend.gdshader")
const KEY="ruby:move/152"
const STATE="i173_crabhammer_session"
const ART=["texture","frame_rects","scale_factor","color","recolor","flip_h","flip_v"]
const SCENES=["btlFondo","btlSueloArriba","btlSueloAbajo"]
static var _calls: Dictionary={}
static var _scans: Dictionary={}
class Invocation extends RefCounted:
	var raw: Dictionary
	var packet: Dictionary
	var definition: BattleAnimationDefinition
	var context: BattleAnimationContext
	var field: Node2D
	var roles: Array
	var program: Array
	var header: Array
	var pc: int
	var claimed: bool=false
	var validating: bool=false
class Record extends RefCounted:
	var group_ref: WeakRef
	var track: Dictionary={}
	var raw: Dictionary={}
	var recipe: Dictionary={}
	var kind: String
	var actor_id: int=-1
	var age: int=0
	var duration: int=1
	var point: Vector2
	var start_x: float=0.0
	var serial: int=0
	var subpriority: int=0
	var node: Sprite2D
	var parent: Node2D
	var copy: BackBufferCopy
	var item: Dictionary={}
	var screen: bool=false
	var screen_lost: bool=false
	var screen_receipt: Dictionary={}
	var created_material: bool=false
	var retired: bool=false
	var published: bool=false
class Session extends RefCounted:
	var owner: Node2D
	var definition: BattleAnimationDefinition
	var context: BattleAnimationContext
	var field: Node2D
	var roles: Array
	var program: Array
	var header: Array
	var capturing: bool=true
	var bindings: Dictionary={}
	var palette_members: Dictionary={}
	var scenes: Array[Dictionary]=[]
	var records: Array[Record]=[]
	var inputs: Dictionary={}
	var derivatives: Dictionary={}
	var valid: bool=true
	var checking: bool=false
	var pulse_started: bool=false
	var coefficient: int=0
	var alpha: Vector2i=Vector2i(16,0)
	var serial: int=0
	var offset: Vector2=Vector2.ZERO
	var applied: Vector2=Vector2.ZERO
	var offset_lost: bool=false
	var terminating: bool=false
class Sweep extends RefCounted:
	# Native signal queue owns this weak-only terminal receipt, never a Session/track.
	var owner_ref: WeakRef
	var definition_ref: WeakRef
	var context_ref: WeakRef
	var owned: Array[WeakRef]=[]
	var state: String
	var parents: Dictionary={}
	var inputs_dropped: bool=false
	var null_context: bool=false
	var pending: bool=false
	func changed(_child: Node=null) -> void:
		if pending:return
		pending=true;finish.call_deferred()
	func finish() -> void:
		pending=false
		# Old, empty source-created leaves may be reclaimed even after runner reuse.
		for ref: WeakRef in owned:
			var node: Variant=ref.get_ref()
			if not is_instance_valid(node) or not node is Node or node.is_queued_for_deletion():continue
			var id: int=node.get_instance_id()
			if not parents.has(id):continue
			var parent: Variant=parents[id].get_ref()
			if is_instance_valid(parent) and node.get_parent()==parent and node.get_child_count()==0:node.queue_free()
		var owner: Variant=owner_ref.get_ref()
		if not owner_allowed(owner):return
		if not inputs_dropped:
			owner.definition=null;owner.context=null;owner._factories={};owner._steps.clear();owner._sounds.clear();inputs_dropped=true
		if owner.get_child_count()==0:owner.queue_free()
	func owner_allowed(owner: Variant) -> bool:
		if not is_instance_valid(owner) or not owner is Node2D or not is_same(owner_ref.get_ref(),owner):return false
		if not owner.has_meta("i173_crab_terminal") or not is_same(owner.get_meta("i173_crab_terminal"),self) or owner.has_meta(STATE):return false
		if owner.state!=state:return false
		if inputs_dropped:return owner.definition==null and owner.context==null
		var prior_definition: Variant=definition_ref.get_ref();var prior_context: Variant=context_ref.get_ref()
		if not is_instance_valid(prior_definition) or owner.definition!=prior_definition:return false
		if null_context:return owner.context==null
		return is_instance_valid(prior_context) and owner.context==prior_context

static func _object(v: Variant) -> bool:return typeof(v)==TYPE_OBJECT and is_instance_valid(v)
# Native equality is a strict fast success; Same keeps its asymmetric numeric compatibility.
static func _equal(a: Variant,b: Variant) -> bool:return a==b or Same._same(a,b)
static func _actor(v: Variant) -> bool:return _object(v) and v is BattleAnimationActor
static func _number(v: Variant,integer: bool=false) -> bool:return typeof(v) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(v)) and (not integer or float(v)==floorf(float(v)))
static func _group(owner: Node2D) -> Session:
	if not _object(owner) or not owner.has_meta(STATE):return null
	var value: Variant=owner.get_meta(STATE)
	return value as Session if _object(value) and value is Session else null
static func _canonical(d: Variant) -> bool:return _object(d) and d is BattleAnimationDefinition and is_same(d,BattleAnimationSequenceRegistry._builtin_source_definitions.get(KEY)) and BattleAnimationSequenceRegistry.is_builtin_source_definition(d)
static func matches(owner: Variant) -> bool:return _object(owner) and owner is BattleAnimationSequenceRunner and _canonical(owner.definition)
static func _roles(c: BattleAnimationContext) -> Array:return [c.attacker_id,c.target_ids.duplicate(),c.source_positions.duplicate(),c.contest]
static func _position(c: BattleAnimationContext,id: int) -> int:
	var value: Variant=c.source_positions.get(id,BattleAnimationContext.source_position_for_slot(id))
	return int(value) if _number(value,true) and int(value) in [0,1,2,3] else -1
static func _normal(raw: Dictionary) -> Dictionary:
	var out: Dictionary={}
	for key: Variant in raw:
		if typeof(key)!=TYPE_STRING and not (typeof(key)==TYPE_STRING_NAME and str(key) in ART):return {}
		if out.has(str(key)):return {}
		out[str(key)]=raw[key]
	return out
static func _without_priority(raw: Dictionary,expected: Dictionary) -> Dictionary:
	# Validate only the runtime decoration; source/ART key normalization stays strict.
	var recipe: Dictionary=raw.duplicate(true);var keys: Array=[]
	for key: Variant in recipe:
		if typeof(key)==TYPE_STRING and key=="source_command_priority" or typeof(key)==TYPE_STRING_NAME and key==&"source_command_priority":keys.append(key)
	if expected.is_empty():return recipe if keys.is_empty() else {}
	if keys.size()!=1:return {}
	var actual: Variant=recipe[keys[0]]
	if not actual is Dictionary or actual.size()!=expected.size():return {}
	for key: Variant in actual:
		if typeof(key)!=TYPE_STRING or not expected.has(key) or typeof(actual[key])!=typeof(expected[key]) or not Same._same(actual[key],expected[key]):return {}
	recipe.erase(keys[0]) # Only the fully validated decoration on our duplicate.
	return recipe
static func _texture(s: Dictionary) -> Texture2D:
	var raw: Variant=s.get("texture")
	if _object(raw) and raw is Texture2D:return raw
	if raw is String:return Fast.texture(raw)
	return null
static func _rects(s: Dictionary,e: Dictionary) -> Dictionary:
	var texture: Texture2D=_texture(s)
	if texture==null:return {}
	var width: int=texture.get_width();var height: int=texture.get_height()
	if width<=0 or height<=0 or not _number(s.get("scale_factor",1.0)) or float(s.get("scale_factor",1.0))<=0:return {}
	for key: String in ["flip_h","flip_v","recolor"]:
		if s.has(key) and typeof(s[key])!=TYPE_BOOL:return {}
	if s.has("color") and (not s.color is String or not Color.html_is_valid(s.color)):return {}
	var raw: Variant=s.get("frame_rects",e.get("frame_rects",{}));var out: Dictionary={}
	if not raw is Dictionary:return out
	var allowed: Array=[0] if int(e.source_line)==6268 else [12,13]
	for key: Variant in raw:
		var tile: int=-1
		if key is String and key.is_valid_int():tile=int(key)
		elif _number(key,true):tile=int(key)
		else:return {}
		if tile not in allowed or out.has(str(tile)):return {}
		var rect: Variant=raw[key]
		if not rect is Array or rect.size()!=4:return {}
		for value: Variant in rect:
			if not _number(value,true):return {}
		if rect[0]<0 or rect[1]<0 or rect[2]<=0 or rect[3]<=0 or rect[0]+rect[2]>width or rect[1]+rect[3]>height:return {}
		out[str(tile)]=rect.duplicate()
	for tile: int in allowed:
		if not out.has(str(tile)):return {}
	return out
static func _shape(raw: Variant,e: Dictionary) -> bool:
	if not raw is Dictionary:return false
	var s: Dictionary=_normal(raw)
	if s.is_empty():return false
	var art: bool=e.get("behavior")=="source_particle"
	for key: String in e:
		if art and key in ART:continue
		if not s.has(key) or not Same._same(s[key],e[key]):return false
	for key: String in s:
		if not e.has(key) and (not art or key not in ART):return false
	return not art or not _rects(s,e).is_empty()
static func _definition(d: BattleAnimationDefinition) -> bool:
	if not _canonical(d) or d.key!=KEY or d.source_script!=Data.PROGRAM.source_script or d.coverage!=Data.PROGRAM.coverage or d.schema_version!=1 or d.steps.size()!=110:return false
	var id: int=d.get_instance_id()
	if _scans.has(id):return false
	_scans[id]=true
	var before: Array=d.steps.duplicate(true);var good: bool=true
	for pc: int in 110:
		if not _shape(d.steps[pc],Data.PROGRAM.steps[pc]):good=false;break
	good=good and _canonical(d) and Same._same(before,d.steps)
	_scans.erase(id);return good
static func accepts_texture_dependency(d: BattleAnimationDefinition,s: Dictionary) -> bool:
	if not _definition(d):return false
	for pc: int in 110:
		if is_same(s,d.steps[pc]):return Data.PROGRAM.steps[pc].get("behavior")=="source_particle"
	return false
static func open_dispatch(owner: Node2D,s: Dictionary) -> Invocation:
	if not matches(owner) or owner.context==null or not _object(owner.context.field) or _calls.has(owner.get_instance_id()):return null
	var call:=Invocation.new();call.raw=s;call.packet=s.duplicate(true);call.definition=owner.definition;call.context=owner.context;call.field=owner.context.field;call.roles=_roles(owner.context);call.program=owner._steps.duplicate(true);call.header=[owner.definition.key,owner.definition.source_script,owner.definition.coverage,owner.definition.schema_version];call.pc=owner._pc
	_calls[owner.get_instance_id()]=call;return call
static func close_dispatch(owner: Node2D,call: Invocation) -> void:
	if call!=null and is_same(_calls.get(owner.get_instance_id()),call):_calls.erase(owner.get_instance_id())
static func _stable(call: Invocation,owner: Node2D,c: BattleAnimationContext,s: Dictionary) -> bool:
	return _object(owner) and owner.state=="running" and is_same(_calls.get(owner.get_instance_id()),call) and is_same(call.raw,s) and is_same(owner.context,c) and is_same(call.context,c) and _object(call.field) and call.field.is_inside_tree() and is_same(c.field,call.field) and matches(owner) and is_same(call.definition,owner.definition) and Same._same(_roles(c),call.roles) and owner._pc==call.pc and owner._source_returns.is_empty() and owner._i159_dispatch_live and Same._same(call.packet,s) and _equal(call.program,owner._steps) and _equal(call.program,owner.definition.steps) and Same._same(call.header,[owner.definition.key,owner.definition.source_script,owner.definition.coverage,owner.definition.schema_version])
static func effect(raw: Dictionary,c: BattleAnimationContext,owner: Node2D,kind: String) -> Variant:
	if not matches(owner) and _group(owner)==null:
		return null
	var call: Invocation=_calls.get(owner.get_instance_id()) as Invocation
	if call==null:
		return []
	if call.claimed:
		return []
	if call.validating:
		return []
	call.validating=true # Reservation precedes ALL image/Texture virtual reads.
	var output: Array[Dictionary]=[]
	var good: bool=_stable(call,owner,c,raw)
	if good:good=is_same(owner._effect_dispatch_step,raw)
	if good:good=owner._effect_dispatch_pc==call.pc
	if good:good=_definition(owner.definition)
	if good:
		var e: Dictionary=Data.PROGRAM.steps[call.pc]
		var priority: Dictionary=BattleSourcePriority.command_metadata(Data.PROGRAM.steps[call.pc-1])
		var recipe: Dictionary=_without_priority(raw,priority)
		var priority_ok: bool=not recipe.is_empty()
		var s: Dictionary=_normal(recipe) if priority_ok else {}
		good=priority_ok
		if good:good=e.get("behavior")==kind
		if good:good=_shape(s,e)
		if good:good=Same._same(s,owner._steps[call.pc])
		if good:good=_stable(call,owner,c,raw)
		if good:good=owner.claim_effect_dispatch(raw)
		if good:
			call.claimed=true
			var g: Session=_group(owner)
			if g==null:g=_capture(owner,c)
			good=g!=null
			if good:good=_valid(g)
			if good:good=_stable(call,owner,c,raw)
			if good:
				output=_create(g,raw,s,call.pc)
	call.validating=false
	return output
static func _frame(n: Sprite2D) -> Array:return [n.centered,n.offset,n.hframes,n.vframes,n.frame,n.region_enabled,n.region_rect,n.flip_h,n.flip_v]
static func _input(texture: Texture2D) -> Dictionary:
	var chain: Array=[];var leaf: Texture2D=texture;var ids: Dictionary={}
	for depth: int in 5:
		if leaf==null:return {}
		if not leaf is AtlasTexture:break
		if ids.has(leaf.get_instance_id()):return {}
		ids[leaf.get_instance_id()]=true;chain.append({"original":leaf,"atlas":leaf.atlas,"region":leaf.region,"margin":leaf.margin,"filter_clip":leaf.filter_clip});leaf=leaf.atlas
	if leaf==null or leaf is AtlasTexture:return {}
	var image: Image=leaf.get_image()
	if image==null or image.is_empty():return {}
	return {"texture":texture,"leaf":leaf,"image":image.duplicate(),"bytes":image.get_data(),"format":image.get_format(),"size":image.get_size(),"chain":chain}
static func _input_valid(input: Dictionary) -> bool:
	if input.is_empty() or not _object(input.texture) or not _object(input.leaf):return false
	for view: Dictionary in input.chain:
		if not _object(view.original) or not is_same(view.original.atlas,view.atlas) or view.original.region!=view.region or view.original.margin!=view.margin or view.original.filter_clip!=view.filter_clip:return false
	var image: Image=input.leaf.get_image()
	# Atlas metadata can change inside the leaf getter as well as the recipient.
	for view: Dictionary in input.chain:
		if not _object(view.original) or not is_same(view.original.atlas,view.atlas) or view.original.region!=view.region or view.original.margin!=view.margin or view.original.filter_clip!=view.filter_clip:return false
	return image!=null and image.get_size()==input.size and image.get_format()==input.format and image.get_data()==input.bytes
static func _derive(g: Session,input: Dictionary,coefficient: int) -> Texture2D:
	if coefficient==0:return input.texture
	var key: String=str(input.texture.get_instance_id())+":"+str(coefficient)
	if g.derivatives.has(key):return g.derivatives[key]
	var image: Image=input.image.duplicate();var target: Array=[13,21,31]
	if image.get_format() in [Image.FORMAT_RGB8,Image.FORMAT_RGBA8]:
		var data: PackedByteArray=image.get_data();var stride: int=4 if image.get_format()==Image.FORMAT_RGBA8 else 3
		for pixel: int in floori(float(data.size())/stride):
			for channel: int in 3:
				var raw: int=floori(float(int(input.bytes[pixel*stride+channel])*31+127)/255.0)
				var blended: int=raw+floori(float((target[channel]-raw)*coefficient)/16.0)
				data[pixel*stride+channel]=floori(float(blended*255)/31.0)
		image=Image.create_from_data(image.get_width(),image.get_height(),false,image.get_format(),data)
	elif image.get_format() in [Image.FORMAT_RGBF,Image.FORMAT_RGBAF,Image.FORMAT_RGBH,Image.FORMAT_RGBAH]:
		for y: int in image.get_height():
			for x: int in image.get_width():
				var color: Color=image.get_pixel(x,y)
				if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b) or not is_finite(color.a):return null
				var amount: float=float(coefficient)/16.0
				image.set_pixel(x,y,Color(lerpf(color.r,13.0/31.0,amount),lerpf(color.g,21.0/31.0,amount),lerpf(color.b,1.0,amount),color.a))
	else:return null
	var result: Texture2D=ImageTexture.create_from_image(image)
	for index: int in range(input.chain.size()-1,-1,-1):
		var view: Dictionary=input.chain[index];var wrapper:=AtlasTexture.new();wrapper.atlas=result;wrapper.region=view.region;wrapper.margin=view.margin;wrapper.filter_clip=view.filter_clip;result=wrapper
	g.derivatives[key]=result;return result
static func _material_recipe(material: Material) -> Dictionary:
	var result: Dictionary={"valid":true,"pointer":material,"shader":null,"code":"","properties":{},"uniforms":{}}
	if material==null:return result # Trusted typed Sprite getter, not arbitrary exposed Object-null.
	if not _object(material) or material.get_script()!=null or material.get_class() not in ["CanvasItemMaterial","ShaderMaterial"]:return {"valid":false}
	for property: Dictionary in material.get_property_list():
		if (int(property.usage)&PROPERTY_USAGE_STORAGE)!=0:result.properties[str(property.name)]=material.get(property.name)
	if material is ShaderMaterial:
		if not _object(material.shader) or material.shader.get_script()!=null:return {"valid":false}
		result.shader=material.shader;result.code=material.shader.code
		for uniform: Dictionary in material.shader.get_shader_uniform_list():
			result.uniforms[str(uniform.name)]=material.get_shader_parameter(uniform.name)
	return result
static func _material_same(material: Material,receipt: Dictionary) -> bool:
	return receipt.get("valid",false) and Same._same(_material_recipe(material),receipt)
static func _screen_kind(receipt: Dictionary) -> int:
	if not receipt.get("valid",false):return -1
	if receipt.pointer==null:return 0
	if receipt.shader==AB:
		# Exact known shader: unset overrides have only its declared defaults.
		var defaults: Dictionary={"eva":0.75,"evb":0.5,"source_recolor":false,"source_recolor_tint":Color.WHITE,"blend_color":Color.WHITE,"grayscale":false,"invert":false,"blend_amount":0.0,"wave_amplitude":0.0,"wave_phase":0.0,"wave_height":64.0,"wave_start":-32.0,"wave_end":32.0,"wave_scale_x":1.0,"wave_scale_y":1.0}
		for name: String in defaults:
			var value: Variant=receipt.uniforms.get(name)
			if value==null:continue
			if typeof(defaults[name])==TYPE_BOOL and typeof(value)!=TYPE_BOOL:return -1
			if typeof(defaults[name])==TYPE_FLOAT and not _number(value):return -1
			if typeof(defaults[name])==TYPE_COLOR and (typeof(value)!=TYPE_COLOR or not is_finite(value.r) or not is_finite(value.g) or not is_finite(value.b) or not is_finite(value.a)):return -1
		return 1
	return -1 if str(receipt.code).contains("hint_screen_texture") else 0
static func _sampling(n: CanvasItem) -> Array:
	var rows: Array=[];var current: Node=n
	while current!=null:
		if current is CanvasLayer:return []
		if current is CanvasItem:
			if current.top_level:return []
			if current is Node2D and current.y_sort_enabled:return []
			rows.append([current.get_instance_id(),current.get_index(),current.texture_filter,current.texture_repeat,current.z_index,current.z_as_relative,current.show_behind_parent,current.top_level,current.visibility_layer,current.light_mask,current.visible])
		current=current.get_parent()
	return rows
static func _geometry(n: Sprite2D) -> Array:
	return [n.transform,n.centered,n.offset,n.hframes,n.vframes,n.frame,n.region_enabled,n.region_rect,n.flip_h,n.flip_v,n.modulate,n.self_modulate,n.texture_filter,n.texture_repeat]
static func _scene_recipe(n: Sprite2D) -> Array:
	return [str(n.name),n.get_parent(),n.get_index(),_geometry(n),n.z_index,n.z_as_relative,n.show_behind_parent,n.top_level,n.visibility_layer,n.light_mask,n.visible,n.is_visible_in_tree(),n.y_sort_enabled,_sampling(n)]
static func _scene_eligible(g: Session,n: Sprite2D,material: Dictionary) -> bool:
	return n.get_parent()==g.field and str(n.name) in SCENES and n.get_script()==null and n.visible and n.is_visible_in_tree() and n.transform.is_finite() and not n.y_sort_enabled and not _sampling(n).is_empty() and _screen_kind(material)==0
static func _scene_observe(g: Session,entry: Dictionary,read_content: bool=false) -> bool:
	if entry.lost:return false
	var node: Variant=entry.node
	if not _object(node) or not node is Sprite2D:entry.lost=true;return false
	if node.texture!=entry.written:entry.texture_lost=true;entry.lost=true;return false
	if not _identity(g) or not _scene_eligible(g,node,entry.material_recipe) or not Same._same(_scene_recipe(node),entry.recipe) or not _material_same(node.material,entry.material_recipe):entry.lost=true;return false
	if read_content:
		var good: bool=_input_valid(entry.input) # May invoke external Texture.get_image.
		if not _object(node) or not node is Sprite2D:entry.lost=true;return false
		# Last check is native receipt/session, AFTER the final virtual read.
		if not good or not _identity(g) or node.texture!=entry.written or not Same._same(_scene_recipe(node),entry.recipe) or not _material_same(node.material,entry.material_recipe):
			if node.texture!=entry.written:entry.texture_lost=true
			entry.lost=true;return false
	return true
static func _capture_palette_members(c: BattleAnimationContext) -> Dictionary:
	# normal.c397 mask31 -> rom_8077ABC.c1268-1303: primary bits are unconditional.
	# Snapshot partner visibility BEFORE monbg hides originals or any virtual input read.
	var members: Dictionary={c.attacker_id:true}
	var primaries: Array=[c.attacker_id]
	if not c.target_ids.is_empty():members[c.target_ids[0]]=true;primaries.append(c.target_ids[0])
	for value: Variant in c.actors.values():
		if not _actor(value) or not value.is_present() or value.side not in [0,1] or not value.sprite.is_visible_in_tree():continue
		# battle_anim.c1902: Contest visibility limits PARTNERS, never primary bits.
		if c.contest and value.id!=c.attacker_id:continue
		var position: int=_position(c,value.id)
		if position<0:continue
		for primary: int in primaries:
			var source: int=_position(c,primary)
			if source>=0 and position==(source^2):members[value.id]=true
	return members
static func _capture(owner: Node2D,c: BattleAnimationContext) -> Session:
	var g:=Session.new();g.owner=owner;g.definition=owner.definition;g.context=c;g.field=c.field;g.roles=_roles(c);g.program=owner._steps.duplicate(true);g.header=[owner.definition.key,owner.definition.source_script,owner.definition.coverage,owner.definition.schema_version]
	g.palette_members=_capture_palette_members(c) # Native actor keys are NOT source-bank indices.
	# Snapshot raw recipients BEFORE any potentially virtual image getter.
	for value: Variant in c.actors.values():
		if not _actor(value) or not value.is_present() or value.side not in [0,1] or _position(c,value.id)<0:continue
		var actor: BattleAnimationActor=value;var n: Sprite2D=actor.sprite
		g.bindings[actor.id]={"actor":actor,"sprite":n,"parent":n.get_parent(),"texture":n.texture,"material":n.material,"material_recipe":_material_recipe(n.material),"frame":_frame(n),"generation":actor._generation,"slot":actor.slot,"has_slot":is_instance_valid(actor.slot),"position":_position(c,actor.id),"side":actor.side,"input":{},"visible":n.visible,"hidden":false,"hide_lost":false,"lost":false,"palette_lost":false,"screen_lost":false}
	for name: String in SCENES:
		var node: Node=c.field.get_node_or_null(name)
		if not _object(node) or not node is Sprite2D:continue
		var receipt: Dictionary=_material_recipe(node.material)
		if not _scene_eligible(g,node,receipt):continue
		g.scenes.append({"node":node,"parent":c.field,"texture":node.texture,"material_recipe":receipt,"recipe":_scene_recipe(node),"input":{},"written":node.texture,"lost":false,"texture_lost":false})
	for id: int in g.bindings:
		var b: Dictionary=g.bindings[id];b.input=_input(b.texture)
		if not _identity(g) or _binding(g,id).is_empty() or not _material_same(b.sprite.material,b.material_recipe):b.lost=true
	for entry: Dictionary in g.scenes:
		entry.input=_input(entry.texture)
		if entry.input.is_empty() or not _scene_observe(g,entry):entry.lost=true
	if not _identity(g) or owner.has_meta(STATE):return null
	owner.set_meta(STATE,g);g.capturing=false;return g
static func _identity(g: Session) -> bool:
	if not _object(g.owner) or g.owner.state!="running" or g.terminating or not matches(g.owner):return false
	if not is_same(g.owner.definition,g.definition) or not is_same(g.owner.context,g.context) or g.context==null:return false
	if not is_same(g.context.field,g.field) or not _object(g.field) or not g.field.is_inside_tree():return false
	if not g.field.global_transform.is_finite() or g.field.global_transform.determinant()==0.0 or not g.owner.global_transform.is_finite() or g.owner.global_transform.determinant()==0.0:return false
	if not Same._same(_roles(g.context),g.roles) or not _equal(g.program,g.owner._steps) or not _equal(g.program,g.definition.steps):return false
	if not Same._same(g.header,[g.definition.key,g.definition.source_script,g.definition.coverage,g.definition.schema_version]):return false
	if g.capturing:return not g.owner.has_meta(STATE)
	return g.owner.has_meta(STATE) and is_same(g.owner.get_meta(STATE),g)
static func _valid(g: Session) -> bool:
	if not g.valid or g.checking or g.terminating:return false
	g.checking=true;var good: bool=_identity(g);g.checking=false
	if not good:g.valid=false;_release_inputs(g);for_record_retire(g)
	return good
static func _cleanup_binding(g: Session,id: int) -> Dictionary:
	if not g.bindings.has(id):return {}
	var b: Dictionary=g.bindings[id]
	if not _actor(b.actor) or not _object(b.sprite) or not b.sprite is Sprite2D or b.actor.sprite!=b.sprite:return {}
	var contexts: Array=[g.context]
	if _object(g.owner) and g.owner.context!=null and not is_same(g.owner.context,g.context):contexts.append(g.owner.context)
	for context: BattleAnimationContext in contexts:
		for other: Variant in context.actors.values():
			if _actor(other) and other!=b.actor and other.sprite==b.sprite:return {}
	return b
static func _binding(g: Session,id: int,cleanup: bool=false) -> Dictionary:
	if cleanup:return _cleanup_binding(g,id)
	if not g.bindings.has(id):return {}
	var b: Dictionary=g.bindings[id]
	if b.lost:return {}
	if _cleanup_binding(g,id).is_empty() or not _object(b.parent) or not b.parent is Node2D or not b.parent.global_transform.is_finite() or b.parent.global_transform.determinant()==0.0 or b.has_slot and not _object(b.slot) or b.sprite.get_parent()!=b.parent or not b.actor.is_present() or b.actor._generation!=b.generation or b.actor.slot!=b.slot or b.sprite.texture!=b.texture:
		b.lost=true;return {}
	if not is_same(g.context.actors.get(id),b.actor) or _position(g.context,id)!=b.position or b.actor.side!=b.side or not Same._same(_frame(b.sprite),b.frame):b.lost=true;return {}
	return b
static func _hide(g: Session,b: Dictionary,hide: bool) -> void:
	if _cleanup_binding(g,b.actor.id).is_empty():b.hide_lost=true;return
	if b.hidden and b.sprite.visible!=false:
		b.actor._release_source_visibility();b.hidden=false;b.hide_lost=true
	if hide:
		if b.lost or b.hide_lost or not b.visible or _binding(g,b.actor.id).is_empty():return
		b.actor.apply_source_state("hidden",true);b.hidden=true
	elif b.hidden:
		# Actor's conditional visibility release tombstones bookkeeping when presentation
		# texture/generation is lost, without overwriting a foreign replacement value.
		b.actor._release_source_visibility();b.hidden=false
static func _scene_write(g: Session,entry: Dictionary,coefficient: int) -> void:
	if not _scene_observe(g,entry,true):return
	var texture: Texture2D=_derive(g,entry.input,coefficient)
	if texture==null:return
	if not _scene_observe(g,entry):return # Exact last-owned recipient immediately before the setter.
	entry.node.texture=texture
	if not _object(entry.node) or not entry.node is Sprite2D:entry.lost=true;return
	if not is_same(entry.node.texture,texture):entry.texture_lost=true;entry.lost=true;return
	entry.written=texture
	_scene_observe(g,entry) # Setter signals cannot silently change source authority.
static func _seed(item: Dictionary,key: String,value: Variant) -> void:item.node.set(key,value);item.writes[key]=item.node.get(key)
static func _record(g: Session,kind: String,raw: Dictionary,s: Dictionary,duration: int) -> Record:
	var r:=Record.new();r.group_ref=weakref(g);r.kind=kind;r.duration=duration;r.raw=raw.duplicate(true);r.recipe=s.duplicate(true);r.serial=g.serial;g.serial+=1
	r.track={"kind":"source_crab_"+kind,"domain":"maintenance" if kind=="BG" else "visual","age":0,"ticks":duration,"owner":g.owner,"settings":raw.duplicate(true),"update":advance,"record_ref":weakref(r)}
	g.records.append(r);return r
static func _visual(g: Session,r: Record,screen: bool=false) -> bool:
	var pair:=Node2D.new();var n:=Sprite2D.new();r.parent=pair;r.node=n;r.screen=screen
	r.item={"node":n,"parent":pair,"writes":{},"lost":{}}
	if screen:
		r.copy=BackBufferCopy.new();r.copy.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT;pair.add_child(r.copy)
	pair.add_child(n);r.track.node=n
	return true
static func _render_guard(r: Record) -> bool:
	return _object(r.node) and _object(r.parent) and r.node.get_parent()==r.parent and not r.node.is_queued_for_deletion() and r.item.get("node")==r.node and r.item.get("parent")==r.parent and r.item.get("writes") is Dictionary and r.item.get("lost") is Dictionary
static func _lose_borrowed_screen(r: Record) -> void:
	if not r.screen or r.created_material or r.kind not in ["BG","OBJ"]:return
	var g: Variant=r.group_ref.get_ref()
	if not _object(g) or not g is Session:return
	var b: Dictionary=_cleanup_binding(g,r.actor_id)
	if not b.is_empty():
		b.screen_lost=true # Sticky presentation-only loss, before retirement/re-admission.
		_hide(g,b,false)
static func _screen_guard(r: Record) -> void:
	if not r.screen or r.screen_lost or not r.published or not _render_guard(r):return
	var receipt: Dictionary=r.screen_receipt
	var material_good: bool=not receipt.is_empty() and _material_same(r.node.material,receipt.material)
	var order_good: bool=not receipt.is_empty() and _object(r.copy) and r.copy.get_parent()==r.parent and r.copy.copy_mode==BackBufferCopy.COPY_MODE_VIEWPORT and r.copy.z_index==r.node.z_index and r.node.get_index()==r.copy.get_index()+1 and Same._same(r.parent.get_children(),receipt.children) and r.parent.get_parent()==receipt.owner and r.parent.get_index()==receipt.index and r.parent.z_index==r.item.get("parent_z")
	if material_good and order_good:return
	r.screen_lost=true
	_lose_borrowed_screen(r)
	if _object(r.copy) and r.copy.get_parent()==r.parent and r.copy.get_child_count()==0:r.copy.queue_free()
	if not material_good:
		# Pointer/Shader/uniform foreign intent wins; never replace its material.
		r.item.lost.material=true;return
	if r.created_material and not r.item.lost.has("material") and r.node.material==r.item.writes.get("material"):
		# Drop only our AB screen pass; keep genuine particle and recolor/palette intent.
		var fallback:=ShaderMaterial.new();fallback.shader=PALETTE
		for key: String in receipt.material.uniforms:
			if key not in ["eva","evb","screen_texture"] and receipt.material.uniforms[key]!=null:fallback.set_shader_parameter(key,receipt.material.uniforms[key])
		Owned.write(r.item,"material",fallback)
	elif r.kind in ["BG","OBJ"]:
		var group: Variant=r.group_ref.get_ref()
		if _object(group) and group is Session:
			var b: Dictionary=_cleanup_binding(group,r.actor_id)
			if not b.is_empty():_hide(group,b,false)
		_retire(r) # Borrowed screen material remains literal on its original Sprite.
static func _prepared_input(g: Session,b: Dictionary) -> Dictionary:
	if b.palette_lost or b.input.is_empty() or not _identity(g):return {}
	var snapshot: Dictionary={"geometry":_geometry(b.sprite),"world":b.sprite.global_transform,"field":g.field.global_transform,"owner":g.owner.global_transform,"values":{}}
	for key: String in Owned.FOLLOW:
		if key not in ["texture","material"]:snapshot.values[key]=b.sprite.get(key)
	var valid_input: bool=_input_valid(b.input) # Last external Texture read.
	if not valid_input or not _source_stable(g,b,snapshot):b.palette_lost=true;return {}
	snapshot.texture=_derive(g,b.input,g.coefficient if g.palette_members.has(b.actor.id) else 0)
	if snapshot.texture==null or not _source_stable(g,b,snapshot):b.palette_lost=true;return {}
	return snapshot
static func _source_stable(g: Session,b: Dictionary,snapshot: Dictionary) -> bool:
	if not _identity(g) or not is_same(_binding(g,b.actor.id),b):return false
	if not _material_same(b.sprite.material,b.material_recipe):b.palette_lost=true;return false
	if not Same._same(_geometry(b.sprite),snapshot.geometry) or b.sprite.global_transform!=snapshot.world or g.field.global_transform!=snapshot.field or g.owner.global_transform!=snapshot.owner:
		b.lost=true;return false
	return true
static func _retire(r: Record) -> void:
	if r.retired:return
	r.retired=true;r.track.ticks=int(r.track.get("age",0))
	if _render_guard(r):
		Owned.write(r.item,"visible",false)
		# Only leaves this source created can be deleted. Preserve foreign descendants.
		if r.node.get_child_count()==0:r.node.queue_free()
	if _object(r.copy) and r.copy.get_parent()==r.parent and r.copy.get_child_count()==0:r.copy.queue_free()
	if _object(r.parent) and (r.parent.get_parent()==null or r.parent.get_parent()==r.track.get("owner")):
		var only_owned_leaves: bool=true
		for child: Node in r.parent.get_children():
			if child not in [r.node,r.copy] or child.get_child_count()!=0:only_owned_leaves=false;break
		if only_owned_leaves:r.parent.queue_free()
static func _project(g: Session,r: Record) -> void:
	if not _render_guard(r):_lose_borrowed_screen(r);_retire(r);return
	_screen_guard(r)
	var n: Sprite2D=r.node
	if r.retired or not _identity(g):return
	if r.kind in ["BG","OBJ"]:
		var b: Dictionary=_binding(g,r.actor_id)
		if b.is_empty() or b.palette_lost or b.screen_lost:
			var original: Dictionary=_cleanup_binding(g,r.actor_id)
			if not original.is_empty():_hide(g,original,false)
			_retire(r);return
		var prepared: Dictionary=_prepared_input(g,b)
		if prepared.is_empty():
			var original: Dictionary=_cleanup_binding(g,r.actor_id)
			if not original.is_empty():_hide(g,original,false)
			_retire(r);return
		for key: String in prepared.values:
			if not _source_stable(g,b,prepared):_retire(r);return
			Owned.write(r.item,key,prepared.values[key])
		if not _source_stable(g,b,prepared):_retire(r);return
		Owned.write(r.item,"transform",r.parent.global_transform.affine_inverse()*prepared.world)
		if not _source_stable(g,b,prepared):_retire(r);return
		Owned.write(r.item,"texture",prepared.texture)
		if not _render_guard(r):_retire(r);return
		if not is_same(r.node.texture,prepared.texture):r.item.lost.texture=true
		if not _source_stable(g,b,prepared):_retire(r);return
		Owned.write(r.item,"visible",b.visible and not b.hide_lost)
	else:
		var point: Vector2=r.point;var tile: int=0
		if r.kind=="ice":
			var phase: int=(r.age*11)&255
			point+=Vector2(Trig.sine(phase,4),-floori(float((r.age*48)&65535)/256.0));tile=12 if (r.age%12)<6 else 13
		var rect: Array=r.item.rects[str(tile)]
		Owned.write(r.item,"region_enabled",true);Owned.write(r.item,"region_rect",Rect2(rect[0],rect[1],rect[2],rect[3]))
		var factor: float=float(r.recipe.get("scale_factor",1.0))
		var field_pose:=Transform2D(Vector2(factor,0),Vector2(0,factor),point)
		var inverse: Transform2D=g.owner.global_transform.affine_inverse() if not r.published else r.parent.global_transform.affine_inverse()
		Owned.write(r.item,"transform",inverse*g.field.global_transform*field_pose)
		Owned.write(r.item,"visible",true)
static func _z(node: CanvasItem) -> int:
	var value: int=0;var current: Node=node
	while current!=null:
		if current is CanvasItem:
			value+=current.z_index
			if not current.z_as_relative:break
		current=current.get_parent()
	return value
static func _oam_y(r: Record) -> int:
	var dy: int=-floori(float((r.age*48)&65535)/256.0) if r.kind=="ice" else 0
	var encoded: int=(int(r.point.y)+dy-(4 if r.kind=="ice" else 16))&255
	return encoded-256 if encoded>=160 else encoded
static func _depth(g: Session) -> bool:
	if not _identity(g):return false
	var members: Array[Record]=[];var target: Dictionary={}
	if not g.context.target_ids.is_empty():target=_binding(g,g.context.target_ids[0])
	var anchor: int=0;var anchor_found: bool=false
	if not target.is_empty():anchor=_z(target.sprite);anchor_found=true
	for r: Record in g.records:
		if r.retired or r.parent==null:continue
		if r.kind=="OBJ":continue
		members.append(r)
		if not anchor_found and r.kind=="BG":
			var b: Dictionary=_binding(g,r.actor_id)
			if not b.is_empty():anchor=_z(b.sprite);anchor_found=true
	if members.is_empty():return true
	if not anchor_found:return false
	members.sort_custom(func(a: Record,b: Record)->bool:
		var ga: Session=a.group_ref.get_ref();var gb: Session=b.group_ref.get_ref()
		var ka: Array=[0,1 if ga.bindings[a.actor_id].position in [1,2] else 0,0] if a.kind=="BG" else [1,-a.subpriority,_oam_y(a)]
		var kb: Array=[0,1 if gb.bindings[b.actor_id].position in [1,2] else 0,0] if b.kind=="BG" else [1,-b.subpriority,_oam_y(b)]
		for index: int in 3:
			if ka[index]!=kb[index]:return ka[index]<kb[index]
		return a.serial<b.serial)
	var floor: int=_z(g.field);var max_start: int=4095-members.size()
	if floor>max_start:return false
	var base: int=clampi(anchor-2,floor,max_start)
	for index: int in members.size():
		var r: Record=members[index]
		if r.published and r.item.lost.has("z_index"):continue
		var local: int=base+index-_z(g.owner)
		if r.published and r.parent.z_index!=r.item.get("parent_z"):r.item.lost.z_index=true;continue
		r.parent.z_index=local;r.item.parent_z=r.parent.z_index
	return true
static func _publish(g: Session,r: Record) -> bool:
	if not _identity(g):_retire(r);return false
	if not _object(r.parent):_retire(r);return false
	if r.parent.get_parent()!=null:_retire(r);return false
	if not _depth(g):_retire(r);return false
	if r.screen:
		r.screen_receipt={"material":_material_recipe(r.node.material),"copy":r.copy,"children":r.parent.get_children().duplicate(),"index":g.owner.get_child_count(),"owner":g.owner}
	if not _identity(g):_retire(r);return false
	r.published=true
	g.owner.add_child(r.parent)
	if not _identity(g) or r.parent.get_parent()!=g.owner:_retire(r);return false
	_screen_guard(r)
	return not r.retired
static func _mirror(g: Session,b: Dictionary,raw: Dictionary,s: Dictionary,kind: String) -> Record:
	var r: Record=_record(g,kind,raw,s,4096);r.actor_id=b.actor.id
	if b.screen_lost:_retire(r);return r
	var screen_kind: int=_screen_kind(b.material_recipe)
	if screen_kind<0:_retire(r);return r
	var prepared: Dictionary=_prepared_input(g,b)
	if prepared.is_empty():_retire(r);return r
	_visual(g,r,screen_kind==1)
	for key: String in Owned.FOLLOW:
		if key=="texture":_seed(r.item,key,prepared.texture)
		elif key=="material":_seed(r.item,key,b.material)
		else:_seed(r.item,key,prepared.values[key])
	_seed(r.item,"transform",prepared.owner.affine_inverse()*prepared.world);_seed(r.item,"visible",b.visible)
	r.track.clones=[{"actor":b.actor,"node":r.node}]
	if kind=="OBJ":r.parent.z_index=_z(b.sprite)-_z(g.owner);r.item.parent_z=r.parent.z_index
	if not _source_stable(g,b,prepared) or not _publish(g,r):_retire(r);return r
	if not _source_stable(g,b,prepared):_retire(r);return r
	_hide(g,b,true);return r
static func _palette(g: Session,coefficient: int,raw: Dictionary={},s: Dictionary={}) -> void:
	g.coefficient=coefficient
	for scene: Dictionary in g.scenes:_scene_write(g,scene,coefficient)
	for id: int in g.bindings:
		var b: Dictionary=_binding(g,id)
		if b.is_empty() or b.palette_lost or b.screen_lost or b.input.is_empty():continue
		if not _material_same(b.sprite.material,b.material_recipe):b.palette_lost=true;continue
		var bg: bool=false;var obj: Record
		for r: Record in g.records:
			if not r.retired and r.actor_id==id:
				if r.kind=="BG":bg=true
				if r.kind=="OBJ":obj=r
		var effective: int=coefficient if g.palette_members.has(id) else 0
		if effective>0 and not bg and obj==null and b.visible:obj=_mirror(g,b,raw,s,"OBJ")
		if effective==0 and obj!=null:_retire(obj);_hide(g,b,false)
		elif obj!=null:_project(g,obj)
	for r: Record in g.records:
		if not r.retired and r.kind=="BG":_project(g,r)
static func _create(g: Session,raw: Dictionary,s: Dictionary,pc: int) -> Array[Dictionary]:
	var line: int=int(s.source_line)
	if s.behavior=="source_legacy_impact_command":
		match str(s.mode):
			"setalpha":g.alpha=Vector2i(12,8)
			"blendoff":g.alpha=Vector2i(16,0)
			"clearmonbg":
				for r: Record in g.records:
					if r.kind=="BG":
						var b: Dictionary=_binding(g,r.actor_id,true)
						if not b.is_empty():_hide(g,b,false)
						_retire(r)
			"monbg":
				var tracks: Array[Dictionary]=[]
				for a: BattleAnimationActor in Owned.source_bg_members(g.context,3):
					var b: Dictionary=_binding(g,a.id)
					if b.is_empty() or b.input.is_empty():continue
					var r: Record=_mirror(g,b,raw,s,"BG")
					if not r.retired:tracks.append(r.track)
				return tracks
		return []
	if line==6271:
		if g.pulse_started:return []
		g.pulse_started=true;var r: Record=_record(g,"palette",raw,s,9);_palette(g,10,raw,s);return [r.track]
	var target_id: int=g.context.target_ids[0] if not g.context.target_ids.is_empty() else -1
	var target: Dictionary=_binding(g,target_id)
	if target.is_empty():return []
	if line in [6272,6276,6279]:
		var kind: String="slide" if line==6272 else "return" if line==6276 else "shake"
		var r: Record=_record(g,kind,raw,s,6 if kind=="slide" else 5 if kind=="return" else 15);r.actor_id=target_id;r.start_x=g.offset.x
		if kind=="shake":
			g.offset.y=4
			_publish_offset(g,target)
		return [r.track]
	var r: Record=_record(g,"hit" if line==6268 else "ice",raw,s,11 if line==6268 else 21);r.actor_id=target_id
	var center: Vector2=g.field.to_local(target.sprite.to_global(target.sprite.get_rect().get_center()))
	# Only the contribution actually applied in the preceding pose is removed.
	# A just-created shake may already publish its register but not yet its native pose.
	var applied_field: Vector2=g.field.global_transform.affine_inverse().basis_xform(target.parent.global_transform.basis_xform(g.applied))
	center-=applied_field
	r.point=center
	var attacker: Dictionary=_binding(g,g.context.attacker_id)
	if attacker.is_empty():_retire(r);return []
	if r.kind=="ice":
		var attacker_x: float=g.field.to_local(attacker.sprite.global_position).x
		var direction: int=1 if attacker_x<center.x else -1 if attacker_x>center.x else 1 if attacker.side==0 else -1
		r.point+=Vector2(int(s.source_args[0])*direction,int(s.source_args[1]))
	r.subpriority=maxi(3,Electric.source_subpriority(attacker.actor,g.context)-(4 if r.kind=="hit" else 2))
	_visual(g,r,r.kind=="hit")
	r.item.rects=_rects(s,Data.PROGRAM.steps[pc]);_seed(r.item,"texture",_texture(s));_seed(r.item,"centered",true);_seed(r.item,"flip_h",bool(s.get("flip_h",false)));_seed(r.item,"flip_v",bool(s.get("flip_v",false)))
	if r.kind=="hit" or bool(s.get("recolor",false)):
		var material:=ShaderMaterial.new();material.shader=AB if r.kind=="hit" else PALETTE
		if r.kind=="hit":material.set_shader_parameter("eva",float(g.alpha.x)/16.0);material.set_shader_parameter("evb",float(g.alpha.y)/16.0)
		if bool(s.get("recolor",false)):material.set_shader_parameter("source_recolor",true);material.set_shader_parameter("source_recolor_tint",Color(str(s.get("color","ffffff"))))
		_seed(r.item,"material",material);r.created_material=true
	r.track.source_priority_actor_id=attacker.actor.id;r.track.source_oam_subpriority=r.subpriority;r.track.source_oam_priority=2
	_project(g,r)
	if not _publish(g,r):return []
	return [r.track]
static func _record_from(t: Dictionary) -> Record:
	var ref: Variant=t.get("record_ref")
	if not _object(ref) or not ref is WeakRef:return null
	var r: Variant=ref.get_ref()
	return r as Record if _object(r) and r is Record and is_same(r.track,t) else null
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	var r: Record=_record_from(t)
	if r==null or r.retired:return
	var g: Session=r.group_ref.get_ref() as Session
	if g==null or not _valid(g) or not is_same(c,g.context) or not is_same(g.owner._i161_control_callback_track,t) or not g.owner._tracks.any(func(v: Variant)->bool:return is_same(v,t)):return
	if not _number(t.get("age"),true) or int(t.age)!=r.age+1 or not Same._same(t.get("settings"),r.raw):_retire(r);return
	r.age=int(t.age)
	match r.kind:
		"palette":
			if r.age==4:_palette(g,0)
			if r.age==9:_palette(g,0);_retire(r)
		"slide":
			if not _binding(g,r.actor_id).is_empty() and not g.offset_lost:g.offset.x=(6 if g.bindings[r.actor_id].side==1 else -6)*mini(r.age,4)
			if r.age>=6:_retire(r)
		"return":
			if not _binding(g,r.actor_id).is_empty() and not g.offset_lost:g.offset.x=r.start_x*float(4-mini(r.age,4))/4.0
			if r.age>=5:g.offset.x=0;_retire(r)
		"shake":
			if not _binding(g,r.actor_id).is_empty() and not g.offset_lost:g.offset.y=4 if r.age<15 and r.age%4 in [0,3] else 0
			if r.age>=15:_retire(r)
		"BG","OBJ":_project(g,r)
		_:
			if r.age>=r.duration:_retire(r)
			else:_project(g,r)
	_depth(g)
static func tracks_for_tick(owner: Node2D,tracks: Array) -> Array:
	if _group(owner)==null:return tracks.duplicate()
	var sprites: Array=[];var maintenance: Array=[]
	for t: Variant in tracks:
		var r: Record=_record_from(t) if t is Dictionary else null
		if r!=null and r.kind=="BG":maintenance.append(t)
		else:sprites.append(t)
	# AnimateSprites/source task5 publications precede task10 palette transport.
	sprites.append_array(maintenance);return sprites
static func before_track(owner: Node2D,t: Variant) -> bool:
	var g: Session=_group(owner)
	if g==null:return true
	if not _valid(g):return false
	if not t is Dictionary:return false
	var r: Record=_record_from(t)
	if r==null:return not str(t.get("kind","")).begins_with("source_crab_")
	if r.retired:owner._tracks.erase(t);return false
	if not _number(t.get("age"),true) or not _number(t.get("ticks"),true) or t.age!=r.age or t.ticks!=r.duration or not Same._same(t.get("settings"),r.raw):_retire(r);owner._tracks.erase(t);return false
	if r.node!=null:
		if not _render_guard(r):_lose_borrowed_screen(r);_retire(r);owner._tracks.erase(t);return false
		_screen_guard(r)
	return true
static func _publish_offset(g: Session,b: Dictionary) -> void:
	# Replace only this producer's last applied displacement, not the mixed pose.
	if g.offset_lost or not _identity(g) or not is_same(_binding(g,b.actor.id),b):return
	var next: Vector2=resolve_offset(g.owner,b.actor)
	if not next.is_finite() or g.offset_lost or not _identity(g) or not is_same(_binding(g,b.actor.id),b):return
	var mixed: Vector2=b.actor._offset-g.applied+next
	b.actor.apply(mixed,b.actor._tint)
	if _identity(g) and not g.offset_lost and is_same(_binding(g,b.actor.id),b) and b.actor._offset==mixed:g.applied=next
static func resolve_offset(owner: Node2D,a: BattleAnimationActor) -> Vector2:
	var g: Session=_group(owner)
	if g==null or not _valid(g) or g.offset_lost:return Vector2.ZERO
	var b: Dictionary=_binding(g,a.id)
	if b.is_empty() or g.context.target_ids.is_empty() or a.id!=g.context.target_ids[0]:return Vector2.ZERO
	var parent: Transform2D=b.parent.global_transform
	if not parent.is_finite() or parent.determinant()==0.0 or not g.field.global_transform.is_finite():return Vector2.ZERO
	return parent.affine_inverse().basis_xform(g.field.global_transform.basis_xform(g.offset))
static func actor_allowed(owner: Node2D,value: Variant) -> bool:
	var g: Session=_group(owner)
	return true if g==null else _actor(value) and not _binding(g,value.id).is_empty()
static func note_application(owner: Node2D,a: BattleAnimationActor) -> void:
	var g: Session=_group(owner)
	if g!=null and not g.context.target_ids.is_empty() and a.id==g.context.target_ids[0]:g.applied=resolve_offset(owner,a)
static func note_held_write(owner: Node2D,t: Dictionary,_value: Vector2) -> void:
	var g: Session=_group(owner)
	if g!=null and _actor(t.get("actor")) and not g.context.target_ids.is_empty() and t.actor.id==g.context.target_ids[0] and is_same(owner._i159_actor_callback_track,t):g.offset_lost=true;g.offset=Vector2.ZERO
static func after_pose(owner: Node2D,c: BattleAnimationContext) -> void:
	var g: Session=_group(owner)
	if g==null or not _valid(g) or not is_same(c,g.context):return
	for scene: Dictionary in g.scenes:_scene_observe(g,scene,true)
	if not _identity(g):return
	for id: int in g.bindings:
		var b: Dictionary=_binding(g,id,true)
		if b.is_empty():continue
		if b.hidden and b.sprite.visible!=false:_hide(g,b,false)
		if not _material_same(b.sprite.material,b.material_recipe):b.palette_lost=true
		if _binding(g,id).is_empty():
			if not g.context.target_ids.is_empty() and id==g.context.target_ids[0]:_remove_offset(g)
			_hide(g,b,false)
	for r: Record in g.records:
		if not r.retired and r.kind in ["BG","OBJ"]:_project(g,r)
	_depth(g)
static func _remove_offset(g: Session) -> void:
	if g.context.target_ids.is_empty():return
	var b: Dictionary=_binding(g,g.context.target_ids[0],true)
	if not b.is_empty():b.actor.apply(b.actor._offset-g.applied,b.actor._tint)
	g.offset=Vector2.ZERO;g.applied=Vector2.ZERO
static func _release_inputs(g: Session) -> void:
	_remove_offset(g)
	for entry: Dictionary in g.scenes:
		var node: Variant=entry.node
		# Work admission and still-owned texture restoration are separate receipts.
		if not entry.texture_lost and _object(node) and node is Sprite2D and node.get_parent()==entry.parent and node.texture==entry.written and _object(g.field) and g.field.get_node_or_null(str(entry.recipe[0]))==node:
			if _object(g.owner) and (is_same(g.owner.context,g.context) or g.owner.context==null):node.texture=entry.texture;entry.written=node.texture
	for id: int in g.bindings:
		var b: Dictionary=_cleanup_binding(g,id)
		if not b.is_empty():_hide(g,b,false)
static func for_record_retire(g: Session) -> void:
	for r: Record in g.records:_retire(r)
static func _owns_session_slot(g: Session) -> bool:
	return _object(g.owner) and g.owner.has_meta(STATE) and is_same(g.owner.get_meta(STATE),g)
static func _terminal_owner(g: Session,allow_null: bool=false) -> bool:
	return _object(g.owner) and is_same(g.owner.definition,g.definition) and Same._same(g.owner._steps,g.program) and (is_same(g.owner.context,g.context) or allow_null and g.owner.context==null)
static func _detach_session(g: Session,allow_owner: bool,allow_null: bool=false) -> Sweep:
	# This function only consumes the captured old Session, never a fresh meta lookup.
	g.terminating=true;g.valid=false
	_release_inputs(g);for_record_retire(g)
	var owner: Node2D=g.owner
	var sweep:=Sweep.new();sweep.owner_ref=weakref(owner);sweep.definition_ref=weakref(g.definition);sweep.context_ref=weakref(g.context);sweep.state=owner.state;sweep.null_context=allow_null
	for r: Record in g.records:
		for candidate: Variant in [r.node,r.copy,r.parent]:
			if not _object(candidate) or not candidate is Node or candidate.get_parent()==null:continue
			sweep.owned.append(weakref(candidate));sweep.parents[candidate.get_instance_id()]=weakref(candidate.get_parent())
			candidate.child_exiting_tree.connect(sweep.changed)
	# Only exact old members can be removed; synchronous cleanup observers may install a successor.
	for r: Record in g.records:
		if _object(owner):
			for t: Variant in owner._tracks.duplicate():
				if is_same(t,r.track):owner._tracks.erase(t)
	if _owns_session_slot(g):
		owner.remove_meta(STATE)
		if allow_owner and _terminal_owner(g,allow_null) and not owner.has_meta(STATE):
			owner.child_exiting_tree.connect(sweep.changed);owner.set_meta("i173_crab_terminal",sweep)
	g.records=[];g.derivatives={};g.bindings={};g.palette_members={};g.scenes=[];g.inputs={}
	sweep.changed();return sweep
static func finish_context_loss(owner: Node2D,terminal_state: String="cancelled") -> bool:
	var old: Session=_group(owner)
	if old==null or is_same(owner.context,old.context):return false
	var intentional_null: bool=owner.context==null and _owns_session_slot(old) and _terminal_owner(old,true) and owner.state=="running"
	if intentional_null:owner.state=terminal_state
	var sweep: Sweep=_detach_session(old,intentional_null,intentional_null)
	# Everything old is detached BEFORE callbacks; no release(owner) or owner mutation afterwards.
	if intentional_null and _object(owner) and owner.state==terminal_state and is_same(owner.definition,sweep.definition_ref.get_ref()) and owner.context==null and not owner.has_meta(STATE):owner.terminated.emit(terminal_state)
	return true
static func begin_terminal(owner: Node2D) -> void:
	var old: Session=_group(owner)
	if old!=null:old.terminating=true;_release_inputs(old)
static func release_actor(owner: Node2D,value: Variant) -> bool:
	var old: Session=_group(owner)
	if old==null:return false
	if not _actor(value):return true
	return _cleanup_binding(old,value.id).is_empty()
static func release(owner: Node2D) -> void:
	var old: Session=_group(owner)
	if old!=null:_detach_session(old,_terminal_owner(old))
static func release_child_allowed(owner: Node2D,child: Node) -> bool:
	if not owner.has_meta("i173_crab_terminal"):return true
	var receipt: Variant=owner.get_meta("i173_crab_terminal")
	if not _object(receipt) or not receipt is Sweep:return true
	return (child is AudioStreamPlayer2D and owner._sounds.has(child)) or (receipt.owned.any(func(ref: WeakRef)->bool:return ref.get_ref()==child) and child.get_child_count()==0)
static func release_owner_allowed(owner: Node2D) -> bool:
	if not owner.has_meta("i173_crab_terminal"):return true
	var receipt: Variant=owner.get_meta("i173_crab_terminal")
	return true if not _object(receipt) or not receipt is Sweep else receipt.owner_allowed(owner) and owner.get_child_count()==0

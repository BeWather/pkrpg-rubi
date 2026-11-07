extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Finite308 owns source-local clocks/recipes; generic Electric and VM remain literal.
const Data=preload("res://scripts/battle/animations/sequence/source_hydro_cannon_data.gd")
const Same=preload("res://scripts/battle/animations/sequence/source_cutting_slice.gd")
const Owned=preload("res://scripts/battle/animations/sequence/source_owned_composition.gd")
const Electric=preload("res://scripts/battle/animations/sequence/source_electric_contract.gd")
const Fast=preload("res://scripts/battle/animations/sequence/source_program_proof.gd")
const PALETTE=preload("res://scripts/battle/animations/sequence/palette_blend.gdshader")
const AB=preload("res://scripts/battle/animations/sequence/source_agility_aerial_palette_ab.gdshader")
const INVERT=preload("res://scripts/battle/animations/sequence/field_invert.gdshader")
const KEY="ruby:move/308"
const STATE="i172_hydro_session"
const ART=["texture","frame_rects","scale_factor","color","recolor","flip_h","flip_v"]
const RETURNS=[8035,8038,8040,8042,8044,8046]
static var _calls: Dictionary={}
static var _definition_scans: Dictionary={}
# Proof memo: bumped whenever control can leave this module (dispatch, tick/pose boundaries).
static var _stamp: int=0
class Invocation extends RefCounted:
	var incoming: Dictionary
	var context: BattleAnimationContext
	var definition: BattleAnimationDefinition
	var pc: int
	var field: Node2D
	var program: Array
	var runner_program: Array
	var packet: Dictionary
	var header: Array
	var roles: Array
	var returns: Array
	var claimed: bool=false
	var validating: bool=false
	var recipe: Dictionary={}
	var initial: Dictionary={}
class Record extends RefCounted:
	var track: Dictionary={}
	var raw: Dictionary={}
	var recipe: Dictionary={}
	var item: Dictionary={}
	var kind: String
	var node: Node2D
	var owner: Node2D
	var pair: Node2D
	var copy: BackBufferCopy
	var point: Vector2
	var end: Vector2
	var callback: int=-1
	var serial: int
	var sub: int=0
	var actor_id: int=-1
	var retired: bool=false
	var published: bool=false
	var screen_required: bool=false
	var screen_lost: bool=false
	var pair_z: int=0
	var publication: Dictionary={}
	var root_order: Array=[]
	var session_ref: WeakRef
	var defer_disposal: bool=false
class Session extends RefCounted:
	var owner: Node2D
	var context: BattleAnimationContext
	var field: Node2D
	var field_size: Vector2
	var definition: BattleAnimationDefinition
	var roles: Array
	var program: Array
	var proof: Fast.Proof
	var proof_stamp: int=-1
	var program_stamp: int=-1
	var bindings: Dictionary={}
	var bodies: Array[WeakRef]=[]
	var lost: Dictionary={}
	var records: Array[Record]=[]
	var serial: int=0
	var anchor: Variant=null
	var alpha: Vector2i=Vector2i(16,0)
	var inverted: bool=false
	var palettes: Dictionary={}
	var scene: Record
	var scene_inputs: Dictionary={}
	var scene_lost: bool=false
	var valid: bool=true
	var checking: bool=false
	var invalidated: bool=false
	var domain: Dictionary={}
	var exclusions: Dictionary={}
	var root_order: Array=[]
	var owned_sounds: Array[Dictionary]=[]
	var offset_record: WeakRef
	var applied_total: Vector2=Vector2.ZERO
	var applied_position: Vector2=Vector2.ZERO
	var null_context_terminal: bool=false
	var terminating: bool=false
	var offset: Vector2=Vector2.ZERO
	var applied: Vector2=Vector2.ZERO
	var offset_lost: bool=false
class TerminalReceipt extends RefCounted:
	# The signal/deferred queue owns this receipt; it owns only weak Nodes, never a Session/callable/resource.
	var owner_ref: WeakRef
	var definition_ref: WeakRef
	var context_ref: WeakRef
	var null_context_terminal: bool=false
	var lifecycle_aborted: bool=false
	var inputs_dropped: bool=false
	var terminal_state: String
	var may_free_owner: bool=true
	var entries: Array[Dictionary]=[]
	var pending: bool=false
	var ready: bool=false
	var done: bool=false
static func _object(v: Variant) -> bool:return typeof(v)==TYPE_OBJECT and is_instance_valid(v)
static func _actor(v: Variant) -> bool:return _object(v) and v is BattleAnimationActor
static func _sprite(v: Variant) -> bool:return _object(v) and v is Sprite2D
static func _number(v: Variant,integral: bool=false) -> bool:return typeof(v) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(v)) and(not integral or float(v)==floorf(float(v)))
static func _canonical(d: Variant) -> bool:
	return _object(d) and d is BattleAnimationDefinition and is_same(d,BattleAnimationSequenceRegistry._builtin_source_definitions.get(KEY)) and BattleAnimationSequenceRegistry.is_builtin_source_definition(d)
static func matches(owner: Variant) -> bool:return _object(owner) and owner is BattleAnimationSequenceRunner and _canonical(owner.definition)
static func _group(owner: Node2D) -> Session:return owner.get_meta(STATE) as Session if owner.has_meta(STATE) else null
static func _roles(c: BattleAnimationContext) -> Array:return [c.attacker_id,c.target_ids.duplicate(),c.contest,c.source_positions.duplicate()]
static func _position(c: BattleAnimationContext,id: int) -> int:
	var v: Variant=c.source_positions[id] if c.source_positions.has(id) else BattleAnimationContext.source_position_for_slot(id)
	return int(v) if _number(v,true) and int(v) in [0,1,2,3] else -1
static func _normal(raw: Dictionary) -> Dictionary:
	var out: Dictionary={}
	for key: Variant in raw:
		if typeof(key)!=TYPE_STRING and not(typeof(key)==TYPE_STRING_NAME and str(key) in ART):return {}
		if out.has(str(key)):return {}
		out[str(key)]=raw[key]
	return out
static func _texture(s: Dictionary) -> Texture2D:
	var raw: Variant=s.get("texture")
	if _object(raw) and raw is Texture2D:return raw
	if raw is String:return Fast.texture(raw)
	return null
static func _rects(s: Dictionary,e: Dictionary) -> Dictionary:
	var texture: Texture2D=_texture(s)
	if texture==null or texture.get_width()<=0 or texture.get_height()<=0:return {}
	if not _number(s.get("scale_factor",1.0)) or float(s.get("scale_factor",1.0))<=0:return {}
	for key: String in ["flip_h","flip_v","recolor"]:
		if s.has(key) and typeof(s[key])!=TYPE_BOOL:return {}
	if s.has("color") and(not s.color is String or not Color.html_is_valid(s.color)):return {}
	var raw: Variant=s.get("frame_rects",e.get("frame_rects",{}))
	if not raw is Dictionary:return {}
	var allowed: Array=[0] if e.get("source_callback")=="sub_80E27A0" else [0,4,8,12]
	var out: Dictionary={}
	for key: Variant in raw:
		var tile: int=-1
		if key is String and key.is_valid_int():tile=int(key)
		elif _number(key,true):tile=int(key)
		else:return {}
		if tile not in allowed or out.has(str(tile)):return {}
		var r: Variant=raw[key]
		if not r is Array or r.size()!=4:return {}
		for v: Variant in r:
			if not _number(v,true):return {}
		if r[0]<0 or r[1]<0 or r[2]<=0 or r[3]<=0 or r[0]+r[2]>texture.get_width() or r[1]+r[3]>texture.get_height():return {}
		out[str(tile)]=r.duplicate()
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
		if not e.has(key) and(not art or key not in ART):return false
	return not art or not _rects(s,e).is_empty()
static func _definition(d: BattleAnimationDefinition) -> bool:
	if not _canonical(d) or d.key!=KEY or d.source_script!=Data.PROGRAM.source_script or d.coverage!=Data.PROGRAM.coverage or d.schema_version!=1 or d.steps.size()!=111:return false
	var id: int=d.get_instance_id()
	if _definition_scans.has(id):return false
	_definition_scans[id]=true
	var valid: bool=true
	for pc: int in 111:
		if not _shape(d.steps[pc],Data.PROGRAM.steps[pc]):valid=false;break
	_definition_scans.erase(id);return valid
static func accepts_texture_dependency(d: BattleAnimationDefinition,s: Dictionary) -> bool:
	if not _definition(d):return false
	for pc: int in 111:
		if is_same(d.steps[pc],s):return Data.PROGRAM.steps[pc].get("behavior")=="source_particle"
	return false
static func _whole(owner: Node2D) -> bool:return matches(owner) and _definition(owner.definition) and Same._same(owner._steps,owner.definition.steps)
## Cheap proof that the live program still equals the one this session admitted.
static func _fast(owner: Node2D,g: Session) -> bool:
	if g==null or g.proof==null or not matches(owner):return false
	var d: BattleAnimationDefinition=owner.definition
	if d.key!=KEY or d.source_script!=Data.PROGRAM.source_script or d.coverage!=Data.PROGRAM.coverage or d.schema_version!=1 or d.steps.size()!=111 or owner._steps.size()!=111:return false
	return Fast.holds(owner._steps,d.steps,g.program,g.proof,func(pc: int,step: Variant) -> bool:return _shape(step,Data.PROGRAM.steps[pc]))
static func _whole_for(owner: Node2D,g: Session) -> bool:return _fast(owner,g) or _whole(owner)
static func open_dispatch(owner: Node2D,s: Dictionary) -> Invocation:
	if not matches(owner) or owner.context==null or not _object(owner.context.field) or _calls.has(owner.get_instance_id()):return null
	_stamp+=1
	var call:=Invocation.new();call.incoming=s;call.context=owner.context;call.definition=owner.definition;call.pc=owner._pc;call.roles=_roles(owner.context);call.returns=owner._source_returns.duplicate()
	call.field=owner.context.field;call.program=owner.definition.steps.duplicate(true);call.runner_program=owner._steps.duplicate(true);call.packet=s.duplicate(true);call.header=[owner.definition.key,owner.definition.source_script,owner.definition.coverage,owner.definition.schema_version]
	_calls[owner.get_instance_id()]=call;return call
static func _stable_call(call: Invocation,owner: Node2D,c: BattleAnimationContext,raw: Dictionary,consumed: bool=false) -> bool:
	if not _object(owner) or c==null or not is_same(_calls.get(owner.get_instance_id()),call) or not is_same(call.incoming,raw) or not is_same(owner.context,c) or not is_same(call.context,c) or not is_same(c.field,call.field) or not _object(call.field) or not call.field.is_inside_tree():return false
	if not owner._i159_dispatch_live or owner._pc!=call.pc or not is_same(owner.definition,call.definition) or not _canonical(call.definition) or not Same._same(call.roles,_roles(c)) or not Same._same(call.returns,owner._source_returns):return false
	if not Same._same(call.packet,raw) or not Same._same(call.program,call.definition.steps) or not Same._same(call.runner_program,owner._steps) or not Same._same(call.header,[call.definition.key,call.definition.source_script,call.definition.coverage,call.definition.schema_version]):return false
	return call.claimed if consumed else not call.claimed and is_same(owner._effect_dispatch_step,raw) and owner._effect_dispatch_pc==call.pc
static func close_dispatch(owner: Node2D,call: Invocation) -> void:
	_stamp+=1
	if call!=null and is_same(_calls.get(owner.get_instance_id()),call):_calls.erase(owner.get_instance_id())
static func _session_identity(g: Session) -> bool:
	return _object(g.owner) and _object(g.definition) and g.definition.key==KEY and g.definition.source_script==Data.PROGRAM.source_script and g.definition.coverage==Data.PROGRAM.coverage and g.definition.schema_version==1 and g.context!=null and _object(g.field) and g.field.is_inside_tree() and is_same(g.owner.context,g.context) and is_same(g.context.field,g.field) and is_same(g.owner.definition,g.definition) and Same._same(_roles(g.context),g.roles) and _program_same(g)
# Native equality is a strict fast success; Same keeps its asymmetric numeric compatibility.
static func _program_same(g: Session) -> bool:
	# Two deep program compares cost ~0.2 ms and ran per record per tick; re-prove once per stamp.
	if g.program_stamp==_stamp:return true
	var same: bool=(g.program==g.owner._steps or Same._same(g.program,g.owner._steps)) and (g.program==g.definition.steps or Same._same(g.program,g.definition.steps))
	if same:g.program_stamp=_stamp
	return same
static func _valid(g: Session,memo: bool=false) -> bool:
	if not g.valid or g.checking or g.terminating:return false
	g.checking=true
	var proven: bool=memo and g.proof_stamp==_stamp
	var good: bool=_session_identity(g) and (proven or _whole_for(g.owner,g))
	# Virtual getters above cannot redefine roles/program/FIELD after their initial check.
	if not proven:g.program_stamp=-1
	good=good and _session_identity(g)
	g.checking=false
	if good:g.proof_stamp=_stamp
	else:_invalidate(g)
	return g.valid
static func effect(s: Dictionary,c: BattleAnimationContext,owner: Node2D,kind: String) -> Variant:
	if not matches(owner) and _group(owner)==null:return null
	var call: Invocation=_calls.get(owner.get_instance_id()) as Invocation
	if call==null or call.claimed or call.validating or not is_same(call.incoming,s) or not is_same(call.context,c) or call.pc!=owner._pc or not owner._i159_dispatch_live:return []
	call.validating=true # BEFORE any Texture virtual getter/whole-program shape scan.
	var out: Array[Dictionary]=[]
	if _admit(s,c,owner,kind,call):
		var g: Session=_session(owner,c)
		out=_create(s,call.recipe,g,call)
	call.validating=false;return out
static func _admit(s: Dictionary,c: BattleAnimationContext,owner: Node2D,kind: String,call: Invocation) -> bool:
	var g: Session=_group(owner)
	if not _stable_call(call,owner,c,s) or not _whole_for(owner,g):return false
	if g!=null and not _valid(g):return false
	if call.pc<0 or call.pc>=111 or Data.PROGRAM.steps[call.pc].get("behavior")!=kind:return false
	if int(s.source_line)>=9356 and(call.returns.size()!=1 or call.returns[0] not in RETURNS):return false
	var recipe: Dictionary=s.duplicate(true)
	var priority: Dictionary=BattleSourcePriority.command_metadata(Data.PROGRAM.steps[call.pc-1]) if call.pc>0 else {}
	if not priority.is_empty():
		if not Same._same(recipe.get("source_command_priority"),priority):return false
		recipe.erase("source_command_priority")
	elif recipe.has("source_command_priority"):return false
	if not _shape(recipe,Data.PROGRAM.steps[call.pc]) or not Same._same(recipe,owner._steps[call.pc]):return false
	if not _stable_call(call,owner,c,s) or not owner.claim_effect_dispatch(s):return false
	call.recipe=_normal(recipe);call.claimed=true;return true
static func _frame(n: Sprite2D) -> Array:return [n.centered,n.offset,n.hframes,n.vframes,n.frame,n.region_enabled,n.region_rect,n.flip_h,n.flip_v]
static func _binding(g: Session,id: int) -> Dictionary:
	if g.lost.has(id):return {}
	var b: Dictionary=g.bindings.get(id,{})
	if b.is_empty():return {}
	var good: bool=_actor(b.get("actor")) and _sprite(b.get("sprite")) and _object(b.get("parent")) and b.actor.sprite==b.sprite and b.actor.is_present() and b.sprite.get_parent()==b.parent and b.sprite.texture==b.texture and b.actor._generation==b.generation and b.actor.side==b.side and _position(g.context,id)==b.position and Same._same(_frame(b.sprite),b.frame) and is_same(g.context.actors.get(id),b.actor)
	if good:
		var live: Variant=g.owner.context
		if live is BattleAnimationContext:
			for occupant: Variant in live.actors.values():
				if _actor(occupant) and not is_same(occupant,b.actor) and occupant.sprite==b.sprite:good=false
	if not good:g.lost[id]=true;return {}
	return b
static func _birth_binding(g: Session,id: int) -> Dictionary:
	var original: Dictionary=_binding(g,id)
	if original.is_empty():return {}
	var b: Dictionary=original.duplicate()
	b.origin=Electric.source_anchor(b.actor,g.context,"origin");b.center=Electric.source_anchor(b.actor,g.context,"center")
	return b
static func _session(owner: Node2D,c: BattleAnimationContext) -> Session:
	var g: Session=_group(owner)
	if g!=null:return g
	g=Session.new();g.owner=owner;g.context=c;g.field=c.field;g.field_size=c.field_size;g.definition=owner.definition;g.roles=_roles(c);g.program=owner._steps.duplicate(true);g.proof=Fast.capture(g.program)
	for id: Variant in c.actors:
		var a: Variant=c.actors[id]
		if _actor(a) and _sprite(a.sprite):
			g.bodies.append(weakref(a.sprite))
			if not g.exclusions.has(a.sprite.get_instance_id()):g.exclusions[a.sprite.get_instance_id()]={"node":weakref(a.sprite),"order":_order_path(a.sprite,false),"visible":a.sprite.visible}
		if typeof(id)!=TYPE_INT or not _actor(a) or not a.is_present() or not _sprite(a.sprite) or not a.sprite.get_parent() is Node2D or a.side not in [0,1] or _position(c,id)<0:continue
		var n: Sprite2D=a.sprite
		g.bindings[id]={"actor":a,"sprite":n,"parent":n.get_parent(),"texture":n.texture,"generation":a._generation,"side":a.side,"position":_position(c,id),"frame":_frame(n),"hidden":false,"origin":Electric.source_anchor(a,c,"origin"),"center":Electric.source_anchor(a,c,"center")}
	var target: Dictionary=g.bindings.get(c.target_ids[0],{}) if not c.target_ids.is_empty() else {}
	if not target.is_empty():g.anchor=_z(target.sprite)
	elif g.bindings.has(c.attacker_id):g.anchor=_z(g.bindings[c.attacker_id].sprite)
	else:
		var members: Array[BattleAnimationActor]=Owned.source_bg_members(c,3)
		if not members.is_empty():g.anchor=_z(members[0].sprite)
	g.root_order=[_order_path(g.field),_order_path(owner)];owner.set_meta(STATE,g);_capture_scene(g,g.field);return g
static func _order_path(node: CanvasItem,leaf_visibility: bool=true) -> Array:
	var out: Array=[];var cursor: Node=node
	while _object(cursor):
		if cursor is CanvasLayer:return []
		if cursor is CanvasItem:
			if cursor.top_level or cursor.show_behind_parent or (cursor is Node2D and cursor.y_sort_enabled):return []
			out.append([cursor.get_instance_id(),cursor.get_parent().get_instance_id() if cursor.get_parent()!=null else 0,cursor.get_index(),cursor.z_index,cursor.z_as_relative,cursor.visibility_layer,cursor.visible if cursor!=node or leaf_visibility else true])
		cursor=cursor.get_parent()
	return out
static func _root_order_valid(g: Session) -> bool:
	return not g.root_order[0].is_empty() and not g.root_order[1].is_empty() and Same._same([_order_path(g.field),_order_path(g.owner)],g.root_order)
static func _exclusions_valid(g: Session) -> bool:
	for receipt: Dictionary in g.exclusions.values():
		var node: Variant=receipt.node.get_ref()
		if not _object(node) or not node is Sprite2D or receipt.order.is_empty() or not Same._same(_order_path(node,false),receipt.order) or node.visible!=receipt.visible:return false
	return true
static func _observe_hide(g: Session,id: int) -> void:
	var b: Dictionary=_cleanup_binding(g,id)
	if b.is_empty() or not b.get("hide_owned",false) or b.get("hide_lost",false):return
	if b.sprite.visible==false:return
	# Relinquish generic Actor bookkeeping WHILE the foreign value differs.
	# Equal return later cannot reacquire this finite binding's visibility lease.
	b.actor.apply_source_state("hidden",false)
	b.hide_owned=false;b.hidden=false;b.hide_lost=true
static func _hide(g: Session,b: Dictionary,hidden: bool) -> void:
	_observe_hide(g,b.actor.id)
	if b.get("hide_lost",false):return
	var receipt: Dictionary=g.exclusions.get(b.sprite.get_instance_id(),{})
	var before: bool=not receipt.is_empty() and b.sprite.visible==receipt.visible
	b.actor.apply_source_state("hidden",hidden);b.hide_owned=hidden
	if before:receipt.visible=b.sprite.visible # Actual authorized hide/release result, not a foreign baseline.
	else:g.scene_lost=true
static func _z(n: CanvasItem) -> int:
	var z: int=n.z_index
	while n.z_as_relative and n.get_parent() is CanvasItem:
		n=n.get_parent();z+=n.z_index
	return clampi(z,-4096,4096)
static func _material_recipe(material: Material) -> Dictionary:
	var out: Dictionary={}
	if material==null:return out
	if material is ShaderMaterial and _object(material.shader):out["__shader_code"]=material.shader.code
	for property: Dictionary in material.get_property_list():
		if (int(property.usage)&PROPERTY_USAGE_STORAGE)==0:continue
		var value: Variant=material.get(property.name)
		if typeof(value) in [TYPE_NIL,TYPE_BOOL,TYPE_INT,TYPE_FLOAT,TYPE_STRING,TYPE_STRING_NAME,TYPE_COLOR]:out[str(property.name)]=value
	return out
static func _scene_recipe(n: CanvasItem) -> Array:
	var material: Material=n.material
	var shader: Shader=material.shader if material is ShaderMaterial else null
	var parameters: Dictionary=_uniforms(material) if material is ShaderMaterial and _object(shader) else {}
	var recipe: Array=[n.get_global_transform(),n.visible,material,shader,parameters,_material_recipe(material),n.modulate,n.self_modulate,n.show_behind_parent,n.top_level,(n is Node2D and n.y_sort_enabled),n.z_index,n.z_as_relative,n.get_index(),n.texture_filter,n.texture_repeat,n.visibility_layer]
	if n is Sprite2D:recipe.append_array([n.texture,_frame(n)])
	elif n is Polygon2D:recipe.append_array([n.polygon,n.color,n.texture])
	elif n is ColorRect:recipe.append_array([n.color,n.size])
	return recipe
static func _safe_owned_audio(g: Session,node: Node) -> bool:
	if node.get_class()!="AudioStreamPlayer2D" or not node is AudioStreamPlayer2D or node.get_script()!=null or node.get_child_count()!=0:return false
	if not _object(g.owner) or not g.owner is BattleAnimationSequenceRunner or not is_same(node.get_parent(),g.owner) or not g.owner._sounds.has(node):return false
	for receipt: Dictionary in g.owned_sounds:
		var ref: Variant=receipt.get("node")
		if _object(ref) and ref is WeakRef and is_same(ref.get_ref(),node):return true
	return false
static func _domain(g: Session,n: Node,out: Dictionary,capture: bool) -> bool:
	for child: Node in n.get_children():
		# Only our exact active pairs are excluded. Unknown additions beneath them are checked separately.
		var controlled: bool=false
		for r: Record in g.records:
			if not r.retired and _object(r.pair) and is_same(child,r.pair):controlled=true;break
		if controlled:
			for r: Record in g.records:
				if not r.retired and is_same(child,r.pair) and not _owned(r):return false
			continue
		var original: bool=false
		for body: WeakRef in g.bodies:
			if is_same(child,body.get_ref()):original=true;break
		if original:
			if child.get_child_count()!=0:return false
			out[child.get_instance_id()]={"node":weakref(child),"parent":child.get_parent(),"index":child.get_index(),"original":true}
			continue
		if child is CanvasLayer or child is CanvasGroup:return false
		if child is CanvasItem:
			if child.top_level or child.show_behind_parent or (child is Node2D and child.y_sort_enabled):return false
			if _safe_owned_audio(g,child):continue
			if child is Sprite2D or child is Polygon2D or child is ColorRect:
				if child.get_script()!=null or child.get_child_count()!=0:return false
				out[child.get_instance_id()]={"node":weakref(child),"parent":child.get_parent(),"index":child.get_index(),"original":false}
				if capture:g.scene_inputs[child.get_instance_id()]={"node":weakref(child),"parent":child.get_parent(),"z":_z(child),"recipe":_scene_recipe(child)}
			elif child.get_class()!="Node2D":return false # Includes unknown scriptless Line2D/draw domains.
			elif child!=g.owner and child.get_script()!=null:return false
		if not _domain(g,child,out,capture):return false
	return true
static func _capture_scene(g: Session,n: Node) -> void:
	g.scene_lost=not _root_order_valid(g) or not _exclusions_valid(g) or not _domain(g,n,g.domain,true) or g.scene_inputs.is_empty()
static func _scene_valid(g: Session) -> bool:
	if g.scene_lost or not _object(g.field):return false
	if not _root_order_valid(g) or not _exclusions_valid(g):g.scene_lost=true;return false
	var current: Dictionary={}
	if not _domain(g,g.field,current,false) or current.size()!=g.domain.size():g.scene_lost=true;return false
	for id: int in g.domain:
		var before: Dictionary=g.domain[id]
		if not current.has(id) or current[id].node.get_ref()!=before.node.get_ref() or current[id].parent!=before.parent or current[id].index!=before.index:g.scene_lost=true;return false
	for state: Dictionary in g.scene_inputs.values():
		var node: Variant=state.node.get_ref()
		if not _object(node) or node.get_parent()!=state.parent or _z(node)!=state.z or not Same._same(_scene_recipe(node),state.recipe):g.scene_lost=true;return false
	return true
static func _seed(item: Dictionary,key: String,value: Variant) -> void:
	item.node.set(key,value);item.writes[key]=item.node.get(key)
	if key=="material" and value is ShaderMaterial:
		item.screen_material=value;item.screen_shader=value.shader;item.screen_code=value.shader.code if _object(value.shader) else ""
static func _pair(r: Record,_g: Session,n: Node2D,screen: bool) -> void:
	r.owner=_g.owner;r.root_order=_order_path(_g.owner);r.node=n;r.pair=Node2D.new();r.pair.y_sort_enabled=false;r.screen_required=screen
	if screen:
		r.copy=BackBufferCopy.new();r.copy.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT;r.pair.add_child(r.copy)
	r.pair.add_child(n)
	r.item={"node":n,"parent":r.pair,"writes":{},"lost":{}}
static func _remember_record(g: Session,r: Record) -> void:
	r.session_ref=weakref(g);r.owner=g.owner;g.records.append(r)
static func _clear_source_offset(g: Session) -> void:
	var owned: bool=not g.offset_lost
	g.offset=Vector2.ZERO;g.offset_lost=true;g.offset_record=null
	if owned and not g.roles[1].is_empty():
		var b: Dictionary=_cleanup_binding(g,int(g.roles[1][0]))
		if not b.is_empty() and g.applied!=Vector2.ZERO and b.actor._offset==g.applied_total and b.sprite.position==g.applied_position:b.actor.apply(b.actor._offset-g.applied,b.actor._tint)
	g.applied=Vector2.ZERO;g.applied_total=Vector2.ZERO;g.applied_position=Vector2.ZERO
static func _release_shake(r: Record) -> void:
	var group: Variant=r.session_ref.get_ref() if r.session_ref!=null else null
	if not _object(group) or not group is Session:return
	if group.offset_record!=null and is_same(group.offset_record.get_ref(),r):_clear_source_offset(group)
static func _record(g: Session,t: Dictionary) -> Record:
	for r: Record in g.records:
		if is_same(r.track,t):return r
	return null
static func _flags(n: CanvasItem) -> Array:
	return [n.z_as_relative,n.show_behind_parent,n.top_level,n.y_sort_enabled,n.visibility_layer,n.modulate,n.self_modulate]
static func _owned(r: Record) -> bool:
	if not _object(r.node) or not _object(r.pair) or not _object(r.owner) or r.node.is_queued_for_deletion() or r.pair.is_queued_for_deletion() or r.node.get_parent()!=r.pair or r.node.get_child_count()!=0:return false
	if r.pair.get_parent()!=(r.owner if r.published else null) or r.pair.transform!=Transform2D.IDENTITY or not r.pair.visible or _flags(r.pair)!=[true,false,false,false,1,Color.WHITE,Color.WHITE]:return false
	if r.node.z_index!=0 or not r.node.z_as_relative or r.node.show_behind_parent or r.node.top_level or r.node.y_sort_enabled or r.node.visibility_layer!=1:return false
	if r.item.has("pair_z") and r.pair.z_index!=r.pair_z:return false
	if r.screen_required:
		if r.root_order.is_empty() or not Same._same(_order_path(r.owner),r.root_order):return false
		if r.screen_lost or not _object(r.copy) or r.copy.is_queued_for_deletion() or r.copy.get_parent()!=r.pair or r.pair.get_child_count()!=2 or r.copy.get_index()!=0 or r.node.get_index()!=1:return false
		if not r.copy.visible or r.copy.transform!=Transform2D.IDENTITY or _flags(r.copy)!=[true,false,false,false,1,Color.WHITE,Color.WHITE] or r.copy.copy_mode!=BackBufferCopy.COPY_MODE_VIEWPORT or r.copy.z_index!=0:return false
	elif r.pair.get_child_count()!=1 or r.node.get_index()!=0:return false
	return true
static func _observe_properties(r: Record) -> void:
	if not _object(r.node):return
	for key: String in r.item.writes:
		if not Same._same(r.node.get(key),r.item.writes[key]):r.item.lost[key]=true
static func _render_receipt(r: Record) -> Array:
	var material: Material=r.node.material
	var shader: Shader=material.shader if material is ShaderMaterial else null
	return [r.node.transform,_flags(r.node),r.node.visible,r.node.z_index,material,shader,_material_recipe(material),_uniforms(material) if material is ShaderMaterial and _object(shader) else {},r.item.writes.duplicate(true)]
static func _publish(r: Record,g: Session) -> bool:
	if not _owned(r):_retire(r);return false
	r.publication={"recipe":_render_receipt(r),"pair_z":r.pair_z,"node":r.node,"pair":r.pair,"copy":r.copy}
	var call: Invocation=_calls.get(g.owner.get_instance_id()) as Invocation
	if call==null or not _valid(g) or not _stable_call(call,g.owner,g.context,call.incoming,true):_retire(r);return false
	r.published=true;g.owner.add_child(r.pair)
	return _published(r,g)
static func _published(r: Record,g: Session) -> bool:
	var call: Invocation=_calls.get(g.owner.get_instance_id()) as Invocation
	if not _valid(g) or call==null or not _stable_call(call,g.owner,g.context,call.incoming,true) or not _owned(r):_retire(r);return false
	_observe_properties(r)
	if not r.item.lost.is_empty() or not Same._same(_render_receipt(r),r.publication.recipe):_retire(r);return false
	if not _scene_valid(g):
		if g.scene!=null:_retire(g.scene)
		if r.kind=="scene":_retire(r);return false
	if not _session_identity(g) or not _stable_call(call,g.owner,g.context,call.incoming,true):_invalidate(g);_retire(r);return false
	return true
static func _dispose_component(node: Node,expected_parent: Node) -> void:
	if not _object(node) or node.get_parent()!=expected_parent:return
	# Foreign descendants retain their actual parent; never free an arbitrary subtree.
	if node.get_child_count()!=0:return
	if node.is_inside_tree():node.queue_free()
	else:node.free()
static func _retire(r: Record) -> void:
	if r.retired:return
	if r.kind=="shake":_release_shake(r)
	r.retired=true;r.track.ticks=maxi(0,r.callback)
	if _object(r.node) and _object(r.pair) and r.node.get_parent()==r.pair:Owned.write(r.item,"visible",false)
	if r.defer_disposal:
		if _object(r.copy) and _object(r.pair) and r.copy.get_parent()==r.pair:r.copy.copy_mode=BackBufferCopy.COPY_MODE_DISABLED
		return # Exact disposal identities survive synchronous terminated observers.
	if _object(r.copy) and _object(r.pair) and r.copy.get_parent()==r.pair:
		r.copy.copy_mode=BackBufferCopy.COPY_MODE_DISABLED;_dispose_component(r.copy,r.pair)
	if _object(r.node) and _object(r.pair):_dispose_component(r.node,r.pair)
	if _object(r.pair) and(r.pair.get_parent()==null or r.pair.get_parent()==r.owner):
		var safe: bool=true
		for child: Node in r.pair.get_children():
			if (not is_same(child,r.node) and not is_same(child,r.copy)) or child.get_child_count()!=0:safe=false
		if safe:
			if r.pair.is_inside_tree():r.pair.queue_free()
			else:r.pair.free()
static func _depth(g: Session) -> bool:
	var members: Array[Record]=[];var excluded_min: int=4097
	if not _root_order_valid(g):
		g.scene_lost=true
		if g.scene!=null:_retire(g.scene)
		return true # Never reproject ranks under an unproved root order; independent input/numerics continue.
	for receipt: Dictionary in g.exclusions.values():
		var original: Variant=receipt.node.get_ref()
		if _sprite(original) and original.is_visible_in_tree():excluded_min=mini(excluded_min,_z(original))
	for r: Record in g.records:
		if not r.retired and _owned(r) and r.kind in ["charge","stream","hit","BG","scene"] and not r.item.lost.has("z_index"):members.append(r)
	if members.is_empty():return true
	if g.anchor==null:return false
	members.sort_custom(func(a: Record,b: Record)->bool:
		var ka: Array=_rank(a,g);var kb: Array=_rank(b,g)
		for i: int in ka.size():
			if ka[i]!=kb[i]:return ka[i]>kb[i]
		return false)
	var floor_z: int=maxi(-4096,_z(g.field));var owner_z: int=_z(g.owner)
	var high: int=mini(4096,owner_z+4096)-members.size()+1
	var low: int=maxi(floor_z,owner_z-4096)
	if low>high:return false
	var band: int=clampi(int(g.anchor)-2,low,high)
	for r: Record in members:
		if r.kind=="scene":
			var scene_top: int=-4097
			for state: Dictionary in g.scene_inputs.values():scene_top=maxi(scene_top,int(state.z))
			band=maxi(band,scene_top+1)
			if band>high or band>=excluded_min:
				_retire(r);return _depth(g) # Decline only the invalid SCREEN component.
	for index: int in members.size():
		var r: Record=members[index]
		if r.item.has("pair_z") and r.pair.z_index!=r.item.pair_z:r.item.lost.z_index=true;continue
		r.pair.z_index=band+index-owner_z;r.pair_z=r.pair.z_index;r.item.pair_z=r.pair_z
	return true
static func _rank(r: Record,g: Session) -> Array:
	if r.kind=="scene":return [3,0,0,0]
	if r.kind=="BG":return [2,1 if g.context.contest or g.bindings[r.actor_id].position in [1,2] else 2,0,r.serial]
	var point: Vector2=_point(r)
	var y: int=(int(point.y)-16)&255
	if y>=160:y-=256
	return [1,r.sub,-y,r.serial]
static func _point(r: Record) -> Vector2:
	if r.kind!="stream" or r.callback<=0:return r.point
	var delta: Vector2=r.end-r.point;var n: int=mini(r.callback,15);var move: Vector2=Vector2.ZERO
	for axis: int in 2:
		var d: int=int(delta[axis]);var q: int=int(float((absi(d)<<8)&65535)/15.0)
		q=(q|1) if d<0 else (q&65534)
		move[axis]=float(((q*n)&65535)>>8)*(-1 if d<0 else 1)
	return r.point+move
static func _observe_screen(r: Record) -> void:
	if not r.screen_required or r.retired:return
	var m: Variant=r.item.get("screen_material")
	var good: bool=_object(m) and m is ShaderMaterial and _object(r.node) and r.node.material==m and m.shader==r.item.get("screen_shader") and _object(m.shader) and m.shader.code==r.item.get("screen_code") and _owned(r)
	if good:return
	r.screen_lost=true
	if r.kind=="scene":_retire(r);return # Never leave INVERT screen-reading without a valid copy.
	if _object(r.node) and _object(m) and m is ShaderMaterial and r.node.material==m and m.shader==AB and m.shader.code==r.item.get("screen_code"):m.shader=PALETTE;r.item.screen_shader=PALETTE;r.item.screen_code=PALETTE.code
	if _object(r.copy) and _object(r.pair) and r.copy.get_parent()==r.pair:
		r.copy.copy_mode=BackBufferCopy.COPY_MODE_DISABLED;_dispose_component(r.copy,r.pair)
	# Copy remains part of the immutable failed boundary until actual removal; no stale sampling.
	r.screen_required=false
	if _object(r.copy) and r.copy.is_queued_for_deletion():r.copy.get_parent().remove_child(r.copy)
	r.copy=null
static func _project(r: Record,g: Session) -> void:
	_observe_screen(r)
	if not _owned(r):_retire(r);return
	var age: int=maxi(0,r.callback);var logical: float=1.0;var angle: float=0.0
	if r.kind=="charge":
		var matrix: int=256+3*mini(age+1,50)-20*clampi(age-59,0,20)
		logical=float(matrix)/256.0;angle=float((10*mini(age+1,50)-10*clampi(age-59,0,20))&255)*TAU/256.0
	elif r.kind=="stream":logical=336.0/256.0
	var factor: float=float(r.recipe.get("scale_factor",1.0))
	var shape: Transform2D=Transform2D(angle,_point(r)).scaled_local(Vector2.ONE*logical*factor)
	Owned.write(r.item,"transform",g.owner.global_transform.affine_inverse()*g.field.global_transform*shape)
	var tile: int=0 if r.kind=="hit" else [0,4,8,12][age%4]
	var rect: Array=r.item.rects[str(tile)]
	Owned.write(r.item,"region_rect",Rect2(float(rect[0]),float(rect[1]),float(rect[2]),float(rect[3])))
	Owned.write(r.item,"flip_h",bool(r.recipe.get("flip_h",false)));Owned.write(r.item,"flip_v",bool(r.recipe.get("flip_v",false)))
static func _create(raw: Dictionary,s: Dictionary,g: Session,call: Invocation) -> Array[Dictionary]:
	var line: int=int(s.source_line)
	if s.behavior=="source_legacy_impact_command":
		match str(s.mode):
			"setalpha":g.alpha=Vector2i(12,8)
			"blendoff":g.alpha=Vector2i(16,0)
			"monbg":return _bg(raw,s,g,call)
			"clearmonbg":
				for r: Record in g.records:
					if r.kind=="BG":_restore_hide(g,r.actor_id);_retire(r)
		return []
	if s.behavior=="source_electric_task":_invert(g);return []
	var attacker: Dictionary=_birth_binding(g,g.context.attacker_id)
	var target: Dictionary=_birth_binding(g,g.context.target_ids[0]) if not g.context.target_ids.is_empty() else {}
	if line==9337:
		if target.is_empty():return []
		var shake_record:=Record.new();shake_record.kind="shake";shake_record.actor_id=target.actor.id;shake_record.raw=raw.duplicate(true);shake_record.recipe=s.duplicate(true);shake_record.track={"kind":"source_hydro_actor","age":0,"ticks":79,"actor":target.actor,"owner":g.owner,"settings":raw.duplicate(true),"update":advance};_remember_record(g,shake_record);call.initial=shake_record.track;advance(shake_record.track,g.context);call.initial={};return [shake_record.track]
	if line==9331 and attacker.is_empty():return []
	if line!=9331 and target.is_empty():return []
	if line>=9356 and attacker.is_empty():return []
	var n:=Sprite2D.new();n.texture=_texture(s);n.region_enabled=true
	var r:=Record.new();r.kind="charge" if line==9331 else "stream" if line>=9356 else "hit";r.raw=raw.duplicate(true);r.recipe=s.duplicate(true);r.serial=g.serial;g.serial+=1
	if r.kind=="hit":r.point=target.center;r.sub=maxi(3,Electric.source_subpriority(target.actor,g.context)-2)
	elif r.kind=="charge":r.point=attacker.origin+Vector2(-10 if g.context.contest or attacker.side==1 else 10,-10);r.sub=(Electric.source_subpriority(attacker.actor,g.context)+(2 if g.context.contest or attacker.side==0 else -2))&255
	else:
		var args: Array=s.source_args.duplicate();var x: int=int(args[0])
		if attacker.side==target.side and attacker.position not in [0,1]:x=-x
		var direction: int=1 if attacker.origin.x<target.origin.x else -1 if attacker.origin.x>target.origin.x else 1 if attacker.side==0 else -1
		r.point=attacker.origin+Vector2(x*direction,int(args[1]));r.end=Vector2(target.center.x+(int(args[2]) if attacker.side==0 else -int(args[2])),target.origin.y+int(args[3]));r.sub=maxi(3,Electric.source_subpriority(target.actor,g.context)-2)
	_pair(r,g,n,true);r.item.rects=_rects(s,Data.PROGRAM.steps[call.pc]);r.track={"kind":"source_hydro_particle","age":0,"ticks":81 if r.kind=="charge" else 17 if r.kind=="stream" else 10,"node":n,"owner":g.owner,"settings":raw.duplicate(true),"update":advance};_remember_record(g,r)
	var tint:=Color(str(s.get("color","ffffff")));var m:=ShaderMaterial.new();m.shader=AB;m.set_shader_parameter("eva",float(g.alpha.x)/16.0);m.set_shader_parameter("evb",float(g.alpha.y)/16.0);m.set_shader_parameter("source_recolor",bool(s.get("recolor",false)));m.set_shader_parameter("source_recolor_tint",tint)
	_seed(r.item,"material",m);_seed(r.item,"texture",n.texture);_seed(r.item,"modulate",Color.WHITE if bool(s.get("recolor",false)) else tint);_seed(r.item,"self_modulate",Color.WHITE);_seed(r.item,"visible",true);_seed(r.item,"region_enabled",true)
	r.callback=0;_project(r,g)
	if not _depth(g):_retire(r);return []
	if not _publish(r,g):return []
	r.callback=-1;call.initial=r.track;advance(r.track,g.context);call.initial={};return [r.track]
static func _bg(raw: Dictionary,s: Dictionary,g: Session,call: Invocation) -> Array[Dictionary]:
	var members: Array[Record]=[]
	for a: BattleAnimationActor in Owned.source_bg_members(g.context,3):
		var b: Dictionary=_binding(g,a.id)
		if b.is_empty():continue
		var prior: Material=b.sprite.material
		var known: bool=prior==null or prior is ShaderMaterial and prior.shader in [PALETTE,AB]
		var uniforms: Dictionary=_known_uniform_recipe(prior) if known else {}
		if known and uniforms.is_empty():continue
		var r:=Record.new();r.kind="BG";r.actor_id=a.id;r.serial=g.serial;g.serial+=1;r.raw=raw.duplicate(true);r.recipe=s.duplicate(true)
		var n:=Sprite2D.new();_pair(r,g,n,false)
		for key: String in Owned.FOLLOW+ ["texture_filter","texture_repeat"]:_seed(r.item,key,b.sprite.get(key))
		_seed(r.item,"transform",g.owner.global_transform.affine_inverse()*b.sprite.global_transform);_seed(r.item,"visible",true)
		if known:
			var m:=ShaderMaterial.new();m.shader=PALETTE
			for name: String in uniforms:
				if name not in ["eva","evb"]:m.set_shader_parameter(name,uniforms[name])
			_seed(r.item,"material",m);r.item.base_invert=uniforms.invert
		else:r.item.base_invert=false;r.item.input=_input_recipe(n.texture)
		r.item.base_material=n.material
		if n.material is ShaderMaterial and n.material.shader==PALETTE:r.item.palette={"node":n,"parent":r.pair,"material":n.material,"shader":PALETTE,"uniforms":{},"revoked":{},"lost_material":false}
		r.track={"kind":"source_hydro_BG","domain":"maintenance","age":0,"ticks":4096,"owner":g.owner,"settings":raw.duplicate(true),"clones":[{"actor":a,"node":n}],"update":advance};_remember_record(g,r);members.append(r)
	if not _depth(g):
		for r: Record in members:_retire(r)
		return []
	var output: Array[Dictionary]=[]
	for r: Record in members:
		if not _publish(r,g):continue
		var b: Dictionary=_binding(g,r.actor_id)
		if b.is_empty():_retire(r);continue
		_hide(g,b,true);b.hidden=true;call.initial=r.track;advance(r.track,g.context);call.initial={};output.append(r.track)
	return output
static func _restore_hide(g: Session,id: int) -> void:
	_observe_hide(g,id)
	var b: Dictionary=g.bindings.get(id,{})
	if b.is_empty() or not b.hidden or not _actor(b.get("actor")) or not _sprite(b.get("sprite")) or not _object(b.get("parent")):return
	if not is_same(b.actor.sprite,b.sprite) or not b.actor.is_present() or b.sprite.get_parent()!=b.parent or b.sprite.texture!=b.texture or b.actor._generation!=b.generation:return
	var live: Variant=g.owner.context
	if live is BattleAnimationContext:
		for value: Variant in live.actors.values():
			if _actor(value) and not is_same(value,b.actor) and is_same(value.sprite,b.sprite):return
	_hide(g,b,false);b.hidden=false
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	var owner: Variant=t.get("owner")
	if not _object(owner) or not owner is BattleAnimationSequenceRunner:return
	var g: Session=_group(owner)
	if g==null:return
	var r: Record=_record(g,t)
	if r==null or r.retired or not _valid(g,true) or c!=g.context or not Same._same(t.get("settings"),r.raw) or not _number(t.get("age"),true):return
	var call: Invocation=_calls.get(owner.get_instance_id()) as Invocation
	var immediate: bool=call!=null and call.claimed and is_same(call.initial,t) and owner._i159_dispatch_live
	var scheduled: bool=is_same(owner._i159_actor_callback_track if r.kind=="shake" else owner._i161_control_callback_track,t) and owner._tracks.any(func(v):return is_same(v,t))
	if not immediate and not scheduled:return
	if int(t.age)!=r.callback+1:return
	r.callback=int(t.age)
	if r.kind=="shake":
		var b: Dictionary=_binding(g,r.actor_id)
		if b.is_empty():_retire(r);return
		g.offset_record=weakref(r)
		g.offset=Vector2(10 if r.callback<79 and ((r.callback+1)/2)%2==0 else 0,0)
		var local: Vector2=resolve_offset(owner,b.actor)
		# Exact source channel alongside the actually applied independent channels, never a held mixed-pose snapshot.
		b.actor.apply(b.actor._offset-g.applied+local,b.actor._tint);g.applied=local;g.applied_total=b.actor._offset;g.applied_position=b.sprite.position
		if r.callback>=79:_retire(r)
	elif r.kind=="BG":
		var b: Dictionary=_binding(g,r.actor_id)
		if b.is_empty():_restore_hide(g,r.actor_id);_retire(r);return
		for key: String in Owned.FOLLOW:
			if key not in ["material","texture"]:Owned.write(r.item,key,b.sprite.get(key))
		Owned.write(r.item,"transform",g.owner.global_transform.affine_inverse()*b.sprite.global_transform);Owned.write(r.item,"visible",true)
	elif int(t.age)>=int(t.ticks):_retire(r)
	else:_project(r,g)
	# Ranking sorts every live record (O(n log n) per call); scheduled ticks defer to after_pose's single pass.
	if immediate:_depth(g)
static func _known_uniform_recipe(prior: Material) -> Dictionary:
	# Only these exact shaders have this finite default/type contract. Never coerce foreign overrides.
	if prior!=null and not(prior is ShaderMaterial and prior.shader in [PALETTE,AB]):return {}
	var values: Dictionary={"source_recolor":false,"source_recolor_tint":Color.WHITE,"blend_color":Color.WHITE,"grayscale":false,"invert":false,"blend_amount":0.0,"wave_amplitude":0.0,"wave_phase":0.0,"wave_height":64.0,"wave_start":-32.0,"wave_end":32.0,"wave_scale_x":1.0,"wave_scale_y":1.0}
	if prior is ShaderMaterial and prior.shader==AB:values.merge({"eva":0.75,"evb":0.5})
	if prior==null:return values
	var material: ShaderMaterial=prior as ShaderMaterial
	for name: String in values:
		var value: Variant=material.get_shader_parameter(name)
		if value==null:continue # Unset override uses only the exact shader declaration default above.
		match typeof(values[name]):
			TYPE_BOOL:
				if typeof(value)!=TYPE_BOOL:return {}
			TYPE_FLOAT:
				if not _number(value):return {}
			TYPE_COLOR:
				if typeof(value)!=TYPE_COLOR:return {}
				if not(is_finite(value.r) and is_finite(value.g) and is_finite(value.b) and is_finite(value.a)):return {}
			_:return {}
		values[name]=value
	return values
static func _uniforms(m: ShaderMaterial) -> Dictionary:
	var values: Dictionary={}
	for u: Dictionary in m.shader.get_shader_uniform_list():
		if str(u.name)!="screen_texture":values[str(u.name)]=m.get_shader_parameter(u.name)
	return values
static func _input_recipe(texture: Texture2D) -> Dictionary:
	if not _object(texture):return {}
	var wrappers: Array=[];var seen: Dictionary={};var leaf: Texture2D=texture
	while leaf is AtlasTexture:
		if seen.has(leaf.get_instance_id()) or wrappers.size()>=8:return {}
		seen[leaf.get_instance_id()]=true
		wrappers.append({"source":leaf,"region":leaf.region,"margin":leaf.margin,"filter_clip":leaf.filter_clip,"size":Vector2i(leaf.get_width(),leaf.get_height())})
		leaf=leaf.atlas
		if not _object(leaf):return {}
	var image: Image=leaf.get_image()
	if image==null or image.is_empty() or image.get_format() not in [Image.FORMAT_RGBA8,Image.FORMAT_RGB8,Image.FORMAT_RGBAF,Image.FORMAT_RGBF,Image.FORMAT_RGBAH,Image.FORMAT_RGBH]:return {}
	return {"source":texture,"leaf":leaf,"wrappers":wrappers,"size":image.get_size(),"format":image.get_format(),"bytes":image.get_data(),"raw":image.duplicate()}
static func _input_valid(input: Dictionary) -> bool:
	if input.is_empty() or not _object(input.get("source")) or not _object(input.get("leaf")):return false
	# get_image()+full byte compare is the costliest check here; re-run it once per stamp.
	if input.get("proof_stamp",-1)==_stamp:return true
	var cursor: Texture2D=input.source
	for wrapper: Dictionary in input.wrappers:
		if not _object(wrapper.source) or not is_same(cursor,wrapper.source) or not cursor is AtlasTexture:return false
		if cursor.region!=wrapper.region or cursor.margin!=wrapper.margin or cursor.filter_clip!=wrapper.filter_clip or Vector2i(cursor.get_width(),cursor.get_height())!=wrapper.size:return false
		cursor=cursor.atlas
	if not is_same(cursor,input.leaf):return false
	var current: Image=cursor.get_image()
	if current==null or current.is_empty() or current.get_size()!=input.size or current.get_format()!=input.format or current.get_data()!=input.bytes:return false
	input.proof_stamp=_stamp
	return true
static func _invert_input(input: Dictionary) -> Texture2D:
	if not _input_valid(input):return null
	var image: Image=input.raw.duplicate()
	if image.get_format() in [Image.FORMAT_RGB8,Image.FORMAT_RGBA8]:
		# Packed data includes every mip level; integer complement preserves alpha and transparent RGB.
		var bytes: PackedByteArray=image.get_data().duplicate()
		var stride: int=4 if image.get_format()==Image.FORMAT_RGBA8 else 3
		for offset: int in range(0,bytes.size(),stride):
			for channel: int in 3:bytes[offset+channel]=255-bytes[offset+channel]
		image.set_data(image.get_width(),image.get_height(),image.has_mipmaps(),image.get_format(),bytes)
	else:
		for y: int in image.get_height():
			for x: int in image.get_width():
				var pixel: Color=image.get_pixel(x,y);image.set_pixel(x,y,Color(1.0-pixel.r,1.0-pixel.g,1.0-pixel.b,pixel.a))
	var output: Texture2D=ImageTexture.create_from_image(image)
	for index: int in range(input.wrappers.size()-1,-1,-1):
		var original: Dictionary=input.wrappers[index]
		var atlas:=AtlasTexture.new();atlas.atlas=output;atlas.region=original.region;atlas.margin=original.margin;atlas.filter_clip=original.filter_clip;output=atlas
	return output
static func _input_output(r: Record,g: Session,inverted: bool) -> void:
	if not r.item.has("input") or r.item.lost.has("texture"):return
	if not _input_valid(r.item.input):r.item.lost.texture=true;return
	if inverted and not r.item.has("inverted_texture"):
		var derived: Texture2D=_invert_input(r.item.input)
		if derived==null or not _session_identity(g):return
		r.item.inverted_texture=derived
	if not _valid(g) or not _input_valid(r.item.input) or not _session_identity(g):return
	var call: Invocation=_calls.get(g.owner.get_instance_id()) as Invocation
	if call==null or not _stable_call(call,g.owner,g.context,call.incoming,true):_invalidate(g);return
	Owned.write(r.item,"texture",r.item.inverted_texture if inverted else r.item.input.source)
static func _invert(g: Session) -> void:
	g.inverted=not g.inverted
	var seen: Dictionary={}
	for id: int in [g.context.attacker_id]+g.context.target_ids.slice(0,1):
		var b: Dictionary=_binding(g,id)
		if b.is_empty() or seen.has(b.sprite.get_instance_id()):continue
		seen[b.sprite.get_instance_id()]=true
		var lease: Dictionary=g.palettes.get(id,{})
		if lease.is_empty():
			var prior: Material=b.sprite.material
			var m: ShaderMaterial=null
			if prior is ShaderMaterial and prior.shader==AB:
				g.palettes[id]={"declined":true};continue # Explicit BODY screen component decline; never assign an unsafe new reader.
			if prior==null or prior is ShaderMaterial and prior.shader==PALETTE:
				var uniforms: Dictionary=_known_uniform_recipe(prior)
				if uniforms.is_empty():g.palettes[id]={"declined":true};continue
				m=ShaderMaterial.new();m.shader=PALETTE
				for key: String in uniforms:m.set_shader_parameter(key,uniforms[key])
				lease={"node":b.sprite,"parent":b.parent,"material":m,"shader":m.shader,"uniforms":{},"revoked":{},"lost_material":false,"previous":prior,"base":uniforms.invert,"all":_uniforms(m)};b.sprite.material=m
			else:
				var source_input: Dictionary=_input_recipe(b.sprite.texture)
				if source_input.is_empty():continue
				var derived: Texture2D=_invert_input(source_input)
				if derived==null or not _valid(g) or _binding(g,id).is_empty():continue
				var proxy:=Record.new();proxy.kind="proxy";proxy.actor_id=id
				var image:=Sprite2D.new();_pair(proxy,g,image,false)
				for key: String in Owned.FOLLOW:_seed(proxy.item,key,b.sprite.get(key))
				_seed(proxy.item,"texture",derived);_seed(proxy.item,"transform",g.owner.global_transform.affine_inverse()*b.sprite.global_transform);_seed(proxy.item,"visible",b.sprite.visible)
				proxy.pair.z_index=_z(b.sprite)-_z(g.owner);proxy.pair_z=proxy.pair.z_index;proxy.item.pair_z=proxy.pair_z;proxy.item.input=source_input;_remember_record(g,proxy)
				lease={"literal":true,"proxy":proxy,"hide":b.sprite.visible,"lost":false}
				if not _publish(proxy,g):continue
				if lease.hide:_hide(g,b,true)
			g.palettes[id]=lease
		if lease.get("declined",false):continue
		if lease.get("literal",false):
			if not g.inverted:
				if lease.hide:_hide(g,b,false)
				_retire(lease.proxy)
		else:Owned.uniform(lease,"invert",not bool(lease.base) if g.inverted else bool(lease.base))
	for r: Record in g.records:
		if r.kind!="BG" or r.retired or not _owned(r):continue
		if r.item.has("palette"):Owned.uniform(r.item.palette,"invert",not bool(r.item.base_invert) if g.inverted else bool(r.item.base_invert))
		else:_input_output(r,g,g.inverted)
	if not g.inverted:
		if g.scene!=null:_retire(g.scene)
		return
	if not _scene_valid(g):return
	var scene_record:=Record.new();scene_record.kind="scene";scene_record.serial=g.serial;g.serial+=1
	var scene_node:=Polygon2D.new();scene_node.polygon=PackedVector2Array([Vector2.ZERO,Vector2(g.field_size.x,0),g.field_size,Vector2(0,g.field_size.y)])
	var scene_material:=ShaderMaterial.new();scene_material.shader=INVERT;scene_node.material=scene_material
	_pair(scene_record,g,scene_node,true);_seed(scene_record.item,"material",scene_material);_seed(scene_record.item,"transform",g.owner.global_transform.affine_inverse()*g.field.global_transform);_seed(scene_record.item,"visible",true);_remember_record(g,scene_record)
	if not _depth(g):_retire(scene_record);return
	if not _publish(scene_record,g):return
	g.scene=scene_record
static func _cleanup_binding(g: Session,id: int) -> Dictionary:
	var b: Dictionary=g.bindings.get(id,{})
	if b.is_empty() or not _actor(b.get("actor")) or not _sprite(b.get("sprite")) or not _object(b.get("parent")):return {}
	if not is_same(b.actor.sprite,b.sprite) or not b.actor.is_present() or b.sprite.get_parent()!=b.parent or b.sprite.texture!=b.texture or b.actor._generation!=b.generation:return {}
	var live: Variant=g.owner.context if _object(g.owner) else null
	if live is BattleAnimationContext:
		for occupant: Variant in live.actors.values():
			if _actor(occupant) and not is_same(occupant,b.actor) and is_same(occupant.sprite,b.sprite):return {}
	return b
static func _release_palette(g: Session,id: int) -> void:
	var b: Dictionary=_cleanup_binding(g,id)
	var lease: Dictionary=g.palettes.get(id,{})
	if b.is_empty() or lease.is_empty() or lease.get("declined",false):return
	if lease.get("literal",false):
		if lease.hide:_hide(g,b,false)
		_retire(lease.proxy);return
	if not Owned.observe_material(lease):return
	var foreign: bool=false
	for key: String in lease.all:
		if key!="invert" and not Same._same(lease.material.get_shader_parameter(key),lease.all[key]):foreign=true
	if not lease.revoked.has("invert"):lease.material.set_shader_parameter("invert",lease.base)
	if not foreign and lease.revoked.is_empty():b.sprite.material=lease.previous
static func _invalidate(g: Session) -> void:
	if g.invalidated:return
	g.invalidated=true;g.valid=false;_clear_source_offset(g)
	for id: int in g.bindings:
		_release_palette(g,id);_restore_hide(g,id)
	for r: Record in g.records:_retire(r)
static func after_pose(owner: Node2D,_context: BattleAnimationContext) -> void:
	var g: Session=_group(owner)
	if g==null:return
	_stamp+=1
	if not _valid(g):return
	for id: int in g.bindings:_observe_hide(g,id)
	# Observe admitted original BODY leases every real pose boundary, without publishing.
	# Pointer/Shader loss and per-uniform revocation remain sticky after equal return.
	for id: int in g.palettes:
		var lease: Dictionary=g.palettes[id]
		if lease.get("literal",false) or lease.get("declined",false) or _binding(g,id).is_empty():continue
		Owned.observe_material(lease)
	for r: Record in g.records:
		if r.retired or r.kind=="shake":continue
		_observe_screen(r)
		if r.retired:continue
		if not _owned(r):
			if r.kind=="BG":_restore_hide(g,r.actor_id)
			_retire(r);continue
		_observe_properties(r)
		if r.item.has("input") and not _input_valid(r.item.input):r.item.lost.texture=true
		if not _session_identity(g):_invalidate(g);return
		if r.kind in ["BG","proxy"]:
			var b: Dictionary=_binding(g,r.actor_id)
			if b.is_empty():_restore_hide(g,r.actor_id);_retire(r)
			else:
				Owned.write(r.item,"transform",owner.global_transform.affine_inverse()*b.sprite.global_transform)
				if r.kind=="proxy":
					for key: String in Owned.FOLLOW:
						if key not in ["texture","material"]:Owned.write(r.item,key,b.sprite.get(key))
					Owned.write(r.item,"visible",bool(g.palettes.get(r.actor_id,{}).get("hide",false)))
	if not _scene_valid(g) and g.scene!=null:_retire(g.scene)
	_depth(g)
static func resolve_offset(owner: Node2D,a: BattleAnimationActor) -> Vector2:
	var g: Session=_group(owner)
	if g!=null and not _session_identity(g):_invalidate(g)
	if g==null or not g.valid or g.offset_lost or g.offset_record==null or g.context.target_ids.is_empty() or a.id!=g.context.target_ids[0] or _binding(g,a.id).is_empty():return Vector2.ZERO
	var producer: Variant=g.offset_record.get_ref()
	if not _object(producer) or not producer is Record or producer.retired or producer.kind!="shake" or producer.session_ref==null or not is_same(producer.session_ref.get_ref(),g):return Vector2.ZERO
	var b: Dictionary=g.bindings[a.id]
	var parent: Transform2D=b.parent.global_transform
	var field: Transform2D=g.field.global_transform
	var determinant: float=parent.determinant()
	if not parent.is_finite() or not field.is_finite() or not is_finite(determinant) or determinant==0.0:return Vector2.ZERO
	# Actor.apply consumes parent-local POSITION deltas, not an orthonormal basis projection.
	var local: Vector2=parent.affine_inverse().basis_xform(field.basis_xform(g.offset))
	return local if local.is_finite() else Vector2.ZERO
static func note_application(owner: Node2D,a: BattleAnimationActor) -> void:
	var g: Session=_group(owner)
	if g!=null and not g.context.target_ids.is_empty() and a.id==g.context.target_ids[0] and is_same(owner._i159_actor_apply_actor,a):
		g.applied=resolve_offset(owner,a);g.applied_total=a._offset;g.applied_position=a.sprite.position
static func actor_allowed(owner: Node2D,value: Variant) -> bool:
	var g: Session=_group(owner)
	if g==null:return true
	return _actor(value) and not _binding(g,value.id).is_empty()
static func note_held_write(owner: Node2D,t: Dictionary,_value: Vector2) -> void:
	var g: Session=_group(owner)
	if g==null or not _actor(t.get("actor")) or t.get("kind")=="source_hydro_actor" or not is_same(owner._i159_actor_callback_track,t):return
	var b: Dictionary=_binding(g,t.actor.id)
	if not b.is_empty() and not g.context.target_ids.is_empty() and t.actor.id==g.context.target_ids[0]:g.offset_lost=true;g.offset=Vector2.ZERO
static func before_track(owner: Node2D,t: Variant) -> bool:
	var g: Session=_group(owner)
	if g==null:return true
	if not t is Dictionary:return false
	var r: Record=_record(g,t)
	if r==null:return true
	var good: bool=_valid(g,true) and _number(t.get("age"),true) and _number(t.get("ticks"),true) and Same._same(t.get("settings"),r.raw) and _object(t.get("owner")) and is_same(t.owner,owner)
	if r.kind=="shake":good=good and _actor(t.get("actor")) and is_same(t.actor,g.bindings[r.actor_id].actor)
	else:
		good=good and(r.kind=="BG" or _object(t.get("node")) and is_same(t.node,r.node))
		if good:
			# Downgrade only a failed screen receipt before residual whole-node ownership checks.
			_observe_screen(r)
			good=not r.retired and _owned(r)
	if not good:_retire(r);owner._tracks.erase(t);return false
	return true
static func note_sound(owner: Node2D,player: AudioStreamPlayer2D) -> void:
	var g: Session=_group(owner)
	if g!=null and not g.terminating and _session_identity(g) and _object(player) and player.get_parent()==null:g.owned_sounds.append({"node":weakref(player),"stream":weakref(player.stream) if _object(player.stream) else null})
static func begin_terminal(owner: Node2D) -> void:
	var g: Session=_group(owner)
	if g==null or g.terminating:return
	g.terminating=true
	for r: Record in g.records:r.defer_disposal=true
static func finish_context_loss(owner: Node2D,terminal_state: String="cancelled") -> bool:
	var g: Session=_group(owner)
	if g==null:return false
	_stamp+=1 # The runner calls this first every tick: a new tick re-proves the program.
	var live: Variant=owner.context
	if live is BattleAnimationContext and is_same(live,g.context) and is_same(live.field,g.field) and _object(g.field) and g.field.is_inside_tree():return false
	# Capture intentional null detachment before any synchronous terminal callbacks.
	g.null_context_terminal=live==null and is_same(owner.definition,g.definition)
	owner.state=terminal_state;owner.lifecycle_aborted=true;begin_terminal(owner)
	for b: Dictionary in g.bindings.values():
		if _actor(b.get("actor")):release_actor(owner,b.actor)
	release(owner)
	owner._tracks.clear();owner._source_palette_banks.clear();owner.terminated.emit(terminal_state)
	for child: Node in owner.get_children():
		if release_child_allowed(owner,child):child.queue_free()
	if release_owner_allowed(owner):owner.queue_free()
	return true
static func release_actor(owner: Node2D,a: Variant) -> bool:
	var g: Session=_group(owner)
	if g==null or not _actor(a) or not g.bindings.has(a.id):return false
	var b: Dictionary=_cleanup_binding(g,a.id)
	if b.is_empty():return true
	_observe_hide(g,a.id)
	_release_palette(g,a.id)
	a.release();return true
static func release(owner: Node2D) -> void:
	var g: Session=_group(owner)
	if g==null:return
	begin_terminal(owner)
	var terminal:=TerminalReceipt.new();terminal.owner_ref=weakref(owner);terminal.definition_ref=weakref(g.definition);terminal.context_ref=weakref(g.context);terminal.terminal_state=owner.state
	terminal.null_context_terminal=g.null_context_terminal and owner.context==null and owner.lifecycle_aborted and is_same(owner.definition,g.definition)
	terminal.lifecycle_aborted=owner.lifecycle_aborted
	for r: Record in g.records:
		_terminal_add(terminal,r.pair,owner)
		_terminal_add(terminal,r.node,r.pair)
		_terminal_add(terminal,r.copy,r.pair)
		if r.kind=="BG":_restore_hide(g,r.actor_id)
		_retire(r)
	for sound_receipt: Dictionary in g.owned_sounds:
		var sound: Variant=sound_receipt.node.get_ref()
		if _object(sound):_terminal_add(terminal,sound,owner,sound_receipt.stream)
	owner.set_meta(STATE+"_terminal",terminal)
	_terminal_watch(terminal,owner)
	for entry: Dictionary in terminal.entries:
		var node: Variant=entry.node.get_ref()
		if _object(node):_terminal_watch(terminal,node)
	g.offset=Vector2.ZERO;g.applied=Vector2.ZERO;g.offset_record=null;g.records.clear();g.palettes.clear();g.bindings.clear();g.bodies.clear();g.exclusions.clear();g.scene_inputs.clear();g.domain.clear();g.owned_sounds.clear();g.scene=null;g.program.clear();owner.remove_meta(STATE)
static func release_child_allowed(owner: Node2D,_child: Node) -> bool:
	return not owner.has_meta(STATE+"_terminal")
static func release_owner_allowed(owner: Node2D) -> bool:
	if not owner.has_meta(STATE+"_terminal"):return true
	var terminal: TerminalReceipt=owner.get_meta(STATE+"_terminal") as TerminalReceipt
	if terminal==null:return false
	terminal.ready=true
	terminal.may_free_owner=_terminal_owner_matches(owner,terminal)
	if terminal.may_free_owner:_drop_terminal_inputs(owner);terminal.inputs_dropped=true
	_terminal_changed(terminal)
	return false # Local deferred sweep rechecks current children AFTER every synchronous terminal observer.
static func _terminal_owner_matches(owner: Node2D,terminal: TerminalReceipt) -> bool:
	if not owner.has_meta(STATE+"_terminal") or not is_same(owner.get_meta(STATE+"_terminal"),terminal) or owner.has_meta(STATE) or owner.state!=terminal.terminal_state or owner.lifecycle_aborted!=terminal.lifecycle_aborted:return false
	if terminal.inputs_dropped:return owner.definition==null and owner.context==null
	var captured_definition: Variant=terminal.definition_ref.get_ref()
	if not _object(captured_definition) or not captured_definition is BattleAnimationDefinition or not is_same(owner.definition,captured_definition):return false
	if terminal.null_context_terminal:return owner.context==null and owner.lifecycle_aborted
	var captured_context: Variant=terminal.context_ref.get_ref()
	return _object(captured_context) and captured_context is BattleAnimationContext and is_same(owner.context,captured_context)
static func _terminal_add(terminal: TerminalReceipt,node: Variant,parent: Variant,stream_ref: WeakRef=null) -> void:
	if not _object(node) or not node is Node or not _object(parent) or not parent is Node or node.get_parent()!=parent:return
	for existing: Dictionary in terminal.entries:
		if is_same(existing.node.get_ref(),node):return
	var entry: Dictionary={"node":weakref(node),"parent":weakref(parent)}
	if node is AudioStreamPlayer2D:entry.stream=stream_ref
	terminal.entries.append(entry)
static func _terminal_watch(terminal: TerminalReceipt,node: Node) -> void:
	var callback: Callable=_terminal_changed.bind(terminal)
	if not node.child_order_changed.is_connected(callback):node.child_order_changed.connect(callback)
	if not node.tree_exited.is_connected(callback):node.tree_exited.connect(callback)
static func _terminal_changed(terminal: TerminalReceipt) -> void:
	if terminal.done or terminal.pending or not terminal.ready:return
	terminal.pending=true
	_terminal_sweep.call_deferred(terminal)
static func _terminal_entry(terminal: TerminalReceipt,node: Node) -> Dictionary:
	for entry: Dictionary in terminal.entries:
		if is_same(entry.node.get_ref(),node):return entry
	return {}
static func _terminal_prune(terminal: TerminalReceipt,node: Node,depth: int=0) -> bool:
	if depth>256:return false # Constructor-bounded owned tree; never recurse through unknown descendants.
	var entry: Dictionary=_terminal_entry(terminal,node)
	if entry.is_empty() or not _object(node) or node.get_parent()!=entry.parent.get_ref():return false
	if node.is_queued_for_deletion():return true
	var empty: bool=true
	for child: Node in node.get_children():
		if not _terminal_prune(terminal,child,depth+1):empty=false
	if node is AudioStreamPlayer2D:
		if entry.get("stream")!=null and is_same(node.stream,entry.stream.get_ref()):node.stop();node.stream=null
	if empty:node.queue_free()
	return empty
static func _terminal_disconnect(terminal: TerminalReceipt) -> void:
	var nodes: Array[WeakRef]=[terminal.owner_ref]
	for entry: Dictionary in terminal.entries:nodes.append(entry.node)
	var callback: Callable=_terminal_changed.bind(terminal)
	for ref: WeakRef in nodes:
		var node: Variant=ref.get_ref()
		if not _object(node) or not node is Node:continue
		if node.child_order_changed.is_connected(callback):node.child_order_changed.disconnect(callback)
		if node.tree_exited.is_connected(callback):node.tree_exited.disconnect(callback)
	terminal.done=true;terminal.entries.clear()
static func _terminal_sweep(terminal: TerminalReceipt) -> void:
	terminal.pending=false
	if terminal.done or not terminal.ready:return
	var owner: Variant=terminal.owner_ref.get_ref()
	if not _object(owner) or not owner is Node2D:_terminal_disconnect(terminal);return
	if not _terminal_owner_matches(owner,terminal):terminal.may_free_owner=false
	for entry: Dictionary in terminal.entries:
		var node: Variant=entry.node.get_ref()
		if _object(node) and node is Node:_terminal_prune(terminal,node)
	# Pruning may trigger synchronous observers; never dispose a replacement execution.
	if not _terminal_owner_matches(owner,terminal):terminal.may_free_owner=false
	# Queued children are NOT already absent: wait for actual removal and all synchronous exit/order callbacks.
	if terminal.may_free_owner and owner.get_child_count()==0:
		_terminal_disconnect(terminal)
		if owner.has_meta(STATE+"_terminal") and is_same(owner.get_meta(STATE+"_terminal"),terminal):owner.remove_meta(STATE+"_terminal")
		owner.queue_free()
	elif not terminal.may_free_owner:
		var remaining: bool=false
		for entry: Dictionary in terminal.entries:
			var node: Variant=entry.node.get_ref()
			if _object(node) and node is Node and node.get_parent()==entry.parent.get_ref():remaining=true
		if not remaining:
			_terminal_disconnect(terminal)
			if owner.has_meta(STATE+"_terminal") and is_same(owner.get_meta(STATE+"_terminal"),terminal):owner.remove_meta(STATE+"_terminal")
static func _drop_terminal_inputs(owner: Node2D) -> void:
	# This terminal anchor is no longer an execution; keep no strong gameplay/ART/factory graph.
	owner.set_process(false);owner.definition=null;owner.context=null
	owner._steps.clear();owner._tracks.clear();owner._sounds.clear();owner._factories.clear();owner._appearance_leases.clear()
	owner._held_offsets.clear();owner._held_blends.clear();owner._held_rotations.clear();owner._held_approach_corrections.clear();owner._source_palette_banks.clear()
	owner._effect_dispatch_step={};owner._i159_actor_callback_track={};owner._i159_palette_callback_track={};owner._i161_control_callback_track={};owner._i171_palette_callback={}
	owner._i159_actor_apply_actor=null;owner._source_spinning_invocation=null;owner._source_background=null;owner._source_blackout=null;owner._background_blend=null
	owner._source_returns.clear();owner._source_args.clear();owner._pending_sprite_priority.clear()

extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Finite146 composition. Authority, callback state and ownership stay local;
## generic particles/Actor anchors/scheduling/audio90 are not reinterpreted.
const Data = preload("res://scripts/battle/animations/sequence/source_dizzy_punch_data.gd")
const Same = preload("res://scripts/battle/animations/sequence/source_cutting_slice.gd")
const Coordinates = preload("res://scripts/battle/animations/sequence/source_coordinate_contract.gd")
const Owned = preload("res://scripts/battle/animations/sequence/source_owned_composition.gd")
const Trig = preload("res://scripts/battle/animations/sequence/source_trig.gd")
const AB = preload("res://scripts/battle/animations/sequence/source_local_ab.gdshader")
const Recolor = preload("res://scripts/battle/animations/sequence/particle_recolor.gdshader")
const KEY = "ruby:move/146"
const STATE = "source_dizzy_punch_session"
static var _calls: Dictionary = {}
static var _validating: Dictionary = {}

class Session extends RefCounted:
	var owner_ref: WeakRef
	var parent_ref: WeakRef
	var call_counts: Dictionary = {}
	var definition: BattleAnimationDefinition
	var context: BattleAnimationContext
	var field: Node2D
	var roles: Array
	var program: Array
	var bindings: Dictionary = {}
	var records: Array = []
	var slots: Array = []
	var permutation: Array[int] = []
	var channels: Dictionary = {}
	var sounds: Array = []
	var alpha := Vector2i(16,0)
	var terminal := false
	var execution_lost := false

class Record extends RefCounted:
	var session_ref: WeakRef
	var track: Dictionary = {}
	var actor_id := -1
	var kind := ""
	var age := 0
	var duration := 0
	var slot := -1
	var point := Vector2.ZERO
	var subpriority := 0
	var recipe: Dictionary = {}
	var args: Array = []
	var item: Dictionary = {}
	var node: Sprite2D
	var copy: BackBufferCopy
	var copy_receipt: Dictionary = {}
	var copy_lost := false
	var retired := false

class Sweep extends RefCounted:
	## Weak-only terminal observer: no Dictionary/Callable/session ownership cycle.
	var owner_ref: WeakRef
	var leaves: Array[WeakRef] = []
	var parents: Dictionary = {}
	var pending := false
	func changed(_child: Node=null) -> void:
		if pending:return
		pending = true;finish.call_deferred()
	func children_changed() -> void:
		changed() # child_order_changed has no Node argument, including detached removal.
	func finish() -> void:
		pending = false
		var owner: Variant = owner_ref.get_ref()
		if not is_instance_valid(owner) or owner.has_meta(STATE) or owner.get_meta("source_dizzy_terminal",null)!=self:return
		for reference: WeakRef in leaves:
			var node: Variant = reference.get_ref()
			if is_instance_valid(node) and not node.is_queued_for_deletion() and node.get_parent()==owner and node.get_child_count()==0:node.queue_free()
		if not owner.is_queued_for_deletion() and owner.get_child_count()==0:owner.queue_free()

static func _number(value: Variant,integer: bool=false) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and (not integer or float(value)==floorf(float(value)))
static func matches(owner: Variant) -> bool:
	return is_instance_valid(owner) and owner is BattleAnimationSequenceRunner and owner.definition!=null and owner.definition.key==KEY and BattleAnimationSequenceRegistry.is_builtin_source_definition(owner.definition)
static func _group(owner: Node2D) -> Session:
	return owner.get_meta(STATE) as Session if is_instance_valid(owner) and owner.has_meta(STATE) else null
static func _roles(c: BattleAnimationContext) -> Array:
	return [c.attacker_id,c.target_ids.duplicate(),c.source_positions.duplicate(),c.contest]
static func _normal(raw: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in raw:
		if typeof(key)!=TYPE_STRING and not (typeof(key)==TYPE_STRING_NAME and str(key) in Data.ART):return {}
		if result.has(str(key)):return {}
		result[str(key)] = raw[key]
	return result
static func _art(expected: Dictionary) -> bool:
	var line: int = int(expected.get("source_line",-1))
	return expected.get("op")=="effect" and (line in Data.DUCK_LINES or line in Data.FIST_LINES or line in Data.HIT_LINES)
static func _shape(raw: Dictionary,expected: Dictionary) -> bool:
	var s: Dictionary = _normal(raw)
	if s.is_empty():return false
	var art: bool = _art(expected)
	for key: String in expected:
		if art and key in Data.ART:continue
		if not s.has(key) or not Same._same(s[key],expected[key]):return false
	for key: String in s:
		if not expected.has(key) and (not art or key not in Data.ART):return false
	return true
static func _body(d: BattleAnimationDefinition) -> bool:
	if d==null or d.key!=KEY or not BattleAnimationSequenceRegistry.is_builtin_source_definition(d):return false
	if d.schema_version!=1 or d.coverage!=Data.PROGRAM.coverage or d.source_script!=Data.PROGRAM.source_script or d.steps.size()!=Data.PROGRAM.steps.size():return false
	for pc: int in d.steps.size():
		if not _shape(d.steps[pc],Data.PROGRAM.steps[pc]):return false
	return true
static func _texture(s: Dictionary) -> Texture2D:
	var value: Variant = s.get("texture")
	if value is Texture2D:return value
	return load(value) as Texture2D if value is String and ResourceLoader.exists(value) else null
static func _rects(s: Dictionary,e: Dictionary) -> Dictionary:
	var texture: Texture2D = _texture(s)
	if texture==null:return {}
	var chain: Array = [];var leaf: Texture2D = texture;var seen: Dictionary = {}
	for depth: int in 5:
		if not leaf is AtlasTexture:break
		if leaf.get_script()!=null or seen.has(leaf.get_instance_id()):return {}
		seen[leaf.get_instance_id()] = true
		chain.append([leaf,leaf.atlas,leaf.region,leaf.margin,leaf.filter_clip]);leaf = leaf.atlas
		if leaf==null:return {}
	if leaf is AtlasTexture:return {}
	var width: int = texture.get_width();var height: int = texture.get_height()
	for link: Array in chain:
		if link[0].atlas!=link[1] or link[0].region!=link[2] or link[0].margin!=link[3] or link[0].filter_clip!=link[4]:return {}
	if width<=0 or height<=0 or not _number(s.get("scale_factor",1.0)) or float(s.get("scale_factor",1.0))<=0:return {}
	for name: String in ["recolor","flip_h","flip_v"]:
		if s.has(name) and typeof(s[name])!=TYPE_BOOL:return {}
	if s.has("color") and (not s.color is String or not Color.html_is_valid(s.color)):return {}
	var expected_rects: Dictionary = e.frame_rects if e.has("frame_rects") else {"0":[0,0,int(e.frame_size[0]),int(e.frame_size[1])]}
	var raw: Variant = s.get("frame_rects",expected_rects)
	if not raw is Dictionary:return {}
	var result: Dictionary = {}
	for key: Variant in raw:
		var tile: String = str(key)
		if not tile.is_valid_int() or not expected_rects.has(tile) or result.has(tile):return {}
		var rect: Variant = raw[key]
		if not rect is Array or rect.size()!=4:return {}
		for number: Variant in rect:
			if not _number(number,true):return {}
		if rect[0]<0 or rect[1]<0 or rect[2]<=0 or rect[3]<=0 or rect[0]+rect[2]>width or rect[1]+rect[3]>height:return {}
		result[tile] = rect.duplicate()
	return result if result.size()==expected_rects.size() else {}
static func _definition(d: BattleAnimationDefinition) -> bool:
	if not _body(d) or _validating.has(d.get_instance_id()):return false
	_validating[d.get_instance_id()] = true
	var snapshot: Array = d.steps.duplicate(true);var good := true
	for pc: int in d.steps.size():
		if _art(Data.PROGRAM.steps[pc]) and _rects(d.steps[pc],Data.PROGRAM.steps[pc]).is_empty():good = false;break
	good = good and _body(d) and Same._same(snapshot,d.steps)
	_validating.erase(d.get_instance_id());return good
static func accepts_texture_dependency(d: BattleAnimationDefinition,s: Dictionary) -> bool:
	if not _definition(d):return false
	for pc: int in d.steps.size():
		if is_same(s,d.steps[pc]):return _art(Data.PROGRAM.steps[pc])
	return false

static func _capture(owner: Node2D,c: BattleAnimationContext) -> Session:
	# Missing optional providers keep legacy generic behavior without certification.
	for actor: BattleAnimationActor in c.actors.values():
		if Coordinates.visual(actor,c).state=="missing" or Coordinates.nominal(actor,c).state=="missing":return null
	var g := Session.new();g.owner_ref = weakref(owner);g.parent_ref = weakref(owner.get_parent());g.definition = owner.definition;g.context = c;g.field = c.field;g.roles = _roles(c);g.program = owner.definition.steps.duplicate(true)
	for actor: BattleAnimationActor in c.actors.values():
		var provider: Variant = c.source_visual.get(actor.id)
		var nominal: Variant = c.source_nominal.get(actor.id)
		var visual_snapshot: Variant = provider.duplicate(true) if provider is Dictionary else provider
		var nominal_snapshot: Variant = nominal.duplicate(true) if nominal is Dictionary else nominal
		g.bindings[actor.id] = {"actor":actor,"provider":provider,"provider_snapshot":visual_snapshot,"nominal_provider":nominal,"nominal_snapshot":nominal_snapshot,"sprite":weakref(actor.sprite),"parent":weakref(actor.sprite.get_parent()),"base":actor.sprite.position,"visible":actor.sprite.visible,"hide_expected":actor.sprite.visible,"hide_owned":false,"hide_lost":false,"invalid":false}
		g.channels[actor.id] = Vector2.ZERO
	for index: int in 64:g.permutation.append(index);g.slots.append(null)
	owner.set_meta(STATE,g);return g
static func _identity(g: Session) -> bool:
	var owner: Variant = g.owner_ref.get_ref()
	if g.execution_lost:return false
	var valid: bool = not g.terminal and is_instance_valid(owner) and owner.state=="running" and matches(owner) and owner.get_parent()==g.parent_ref.get_ref() and owner.global_transform.is_finite() and not is_zero_approx(owner.global_transform.determinant()) and owner.definition==g.definition and owner.definition.schema_version==1 and owner.definition.coverage==Data.PROGRAM.coverage and owner.definition.source_script==Data.PROGRAM.source_script and owner.context==g.context and is_instance_valid(g.field) and g.field==g.context.field and g.field.is_inside_tree() and g.field.global_transform.is_finite() and not is_zero_approx(g.field.global_transform.determinant()) and Same._same(g.roles,_roles(g.context)) and Same._same(g.program,owner._steps) and Same._same(g.program,g.definition.steps)
	if not valid and not g.terminal:
		g.execution_lost = true
		for id: int in g.bindings:_revoke_binding(g,id)
	return valid
static func _cleanup_subject(g: Session,b: Dictionary) -> bool:
	# Captured receipts authorize cleanup only while the original Actor remains
	# the current occupant. Provider restoration never authorizes a successor.
	# Texture/generation identity loss conservatively denies cleanup writes.
	var actor: BattleAnimationActor = b.actor
	if g.context.actors.get(actor.id)!=actor:return false
	var sprite: Variant = b.sprite.get_ref()
	if not is_instance_valid(sprite) or actor.sprite!=sprite or sprite.get_parent()!=b.parent.get_ref() or not actor.is_present():return false
	var receipt: Variant = b.provider_snapshot
	if not receipt is Dictionary:return false
	if receipt.get("had_slot",false):
		var reference: Variant = receipt.get("slot")
		if not reference is WeakRef:return false
		var slot: Variant = reference.get_ref()
		return is_instance_valid(slot) and actor.slot==slot and slot.sprite_pokemon==sprite and slot.animation_generation==receipt.generation
	return actor.slot==null and int(sprite.get_meta("animation_generation",0))==int(receipt.get("generation",-1))
static func _revoke_binding(g: Session,id: int) -> void:
	var b: Dictionary = g.bindings.get(id,{})
	if b.is_empty() or b.invalid:return
	b.invalid = true
	# Clear only our last applied local positional contribution, and only while
	# the actual full position still equals its postwrite receipt. Other Actor
	# fields and any later foreign literal position remain untouched.
	if b.has("channel_position") and _cleanup_subject(g,b):
		var sprite: Sprite2D = b.sprite.get_ref()
		if sprite.position==b.channel_position:sprite.position -= b.channel_local
	b.erase("channel_position");b.erase("channel_local")
	g.channels[id] = Vector2.ZERO
static func _binding(g: Session,id: int,cleanup: bool=false) -> Dictionary:
	var b: Dictionary = g.bindings.get(id,{})
	if b.is_empty():return {}
	if cleanup:return b if _cleanup_subject(g,b) else {}
	if b.invalid or g.execution_lost:return {}
	var actor: BattleAnimationActor = b.actor;var sprite: Variant = b.sprite.get_ref()
	var valid: bool = b.provider is Dictionary and b.nominal_provider is Dictionary
	valid = valid and is_instance_valid(sprite) and g.context.actors.get(id)==actor and actor.sprite==sprite and sprite.get_parent()==b.parent.get_ref()
	valid = valid and is_same(g.context.source_visual.get(id),b.provider) and Same._same(b.provider,b.provider_snapshot)
	valid = valid and is_same(g.context.source_nominal.get(id),b.nominal_provider) and Same._same(b.nominal_provider,b.nominal_snapshot)
	var parent: CanvasItem = b.parent.get_ref() as CanvasItem
	valid = valid and parent!=null and parent.get_global_transform().is_finite() and not is_zero_approx(parent.get_global_transform().determinant())
	valid = valid and Coordinates.visual(actor,g.context).state=="valid" and Coordinates.nominal(actor,g.context).state=="valid"
	if not valid:_revoke_binding(g,id);return {}
	return b
static func open_dispatch(owner: Node2D,s: Dictionary) -> Dictionary:
	if not matches(owner) or not _body(owner.definition) or owner.context==null or _calls.has(owner.get_instance_id()):return {}
	var g: Session = _group(owner)
	if g==null:g = _capture(owner,owner.context)
	if g==null:return {}
	var call: Dictionary = {"raw":s,"packet":s.duplicate(true),"pc":owner._pc,"returns":owner._source_returns.duplicate(),"args":owner._source_args.duplicate(),"claimed":false}
	_calls[owner.get_instance_id()] = call;return call
static func close_dispatch(owner: Node2D,call: Dictionary) -> void:
	if not call.is_empty() and is_same(_calls.get(owner.get_instance_id()),call):_calls.erase(owner.get_instance_id())
static func _call_valid(g: Session,owner: Node2D,call: Dictionary,s: Dictionary) -> bool:
	return _identity(g) and is_same(_calls.get(owner.get_instance_id()),call) and is_same(call.raw,s) and owner._pc==call.pc and owner._i159_dispatch_live and Same._same(call.packet,s) and Same._same(call.returns,owner._source_returns) and Same._same(call.args,owner._source_args)
static func effect(raw: Dictionary,c: BattleAnimationContext,owner: Node2D,kind: String) -> Variant:
	var g: Session = _group(owner)
	if g==null:return null
	var call: Dictionary = _calls.get(owner.get_instance_id(),{})
	if call.is_empty() or call.claimed or not _call_valid(g,owner,call,raw):return []
	var e: Dictionary = Data.PROGRAM.steps[call.pc]
	if e.get("op")!="effect" or e.get("behavior")!=kind:return []
	var recipe: Dictionary = raw.duplicate(true)
	var priority: Dictionary = BattleSourcePriority.command_metadata(Data.PROGRAM.steps[call.pc-1])
	if not priority.is_empty():
		if not Same._same(recipe.get("source_command_priority"),priority):return []
		recipe.erase("source_command_priority")
	elif recipe.has("source_command_priority"):return []
	if not _shape(recipe,e) or not Same._same(recipe,owner._steps[call.pc]):return []
	var source_label: Dictionary = Data.PROGRAM.steps[call.pc-1]
	var args: Array = source_label.get("source_args",[])
	for index: int in args.size():
		if int(owner._source_args.get(index,-1))!=(int(args[index])&65535):return []
	var line: int = int(recipe.source_line)
	var ordinal: int = int(g.call_counts.get(line,0))
	if line in [1391,1393]:
		if ordinal>=2 or not Same._same(owner._source_returns,[836 if ordinal==0 else 847]):return []
	elif not owner._source_returns.is_empty():return []
	# Consume real physical packet BEFORE custom Texture/resource getters.
	if not owner.claim_effect_dispatch(raw):return []
	call.claimed = true;g.call_counts[line] = ordinal+1
	if not _definition(owner.definition) or not _call_valid(g,owner,call,raw):return []
	if kind=="source_legacy_impact_command":return _command(g,recipe)
	var id: int = c.attacker_id if line==1391 else (c.target_ids[0] if not c.target_ids.is_empty() else -1)
	var b: Dictionary = _binding(g,id)
	if b.is_empty():return []
	if line in [1391,1393]:return _actor(g,b,recipe)
	var rects: Dictionary = _rects(recipe,e)
	if rects.is_empty() or not _call_valid(g,owner,call,raw) or _binding(g,id).is_empty():return []
	return _particle(g,b,recipe,rects)

static func _record(g: Session,kind: String,s: Dictionary,duration: int) -> Record:
	var r := Record.new();r.session_ref = weakref(g);r.kind = kind;r.recipe = s.duplicate(true);r.duration = duration
	r.track = {"kind":"source_particle" if kind in ["duck","fist","hit"] else "source_dizzy_actor" if kind in ["lunge","shake"] else "source_dizzy_bg","settings":s.duplicate(true),"age":0,"ticks":duration,"update":advance,"dizzy_record":weakref(r)}
	r.track.cleanup = _retire_ref.bind(weakref(r));g.records.append(r);return r
static func _hide(g: Session,b: Dictionary,hidden: bool) -> void:
	if _binding(g,b.actor.id,true).is_empty():return
	var sprite: Sprite2D = b.actor.sprite
	if b.hide_owned and sprite.visible!=b.hide_expected:b.hide_lost = true
	if b.hide_lost:return
	if hidden:
		b.hide_owned = true;sprite.visible = false;b.hide_expected = sprite.visible
	elif b.hide_owned:
		sprite.visible = bool(b.visible);b.hide_expected = sprite.visible;b.hide_owned = false
static func _item(node: Sprite2D,owner: Node2D) -> Dictionary:
	var item: Dictionary = {"node":node,"parent":owner,"writes":{},"lost":{},"material":null,"shader":null,"uniforms":{},"revoked":{},"lost_material":false,"active":false,"previous":null}
	for key: String in ["position","rotation","scale","skew","visible","z_index","texture","centered","offset","hframes","vframes","frame","region_enabled","region_rect","flip_h","flip_v","modulate","self_modulate","material"]:item.writes[key] = node.get(key)
	return item
static func _pose(item: Dictionary,pose: Transform2D) -> void:
	if not pose.is_finite() or is_zero_approx(pose.determinant()):return
	var orientation: float = 1.0 if pose.determinant()>0 else -1.0
	var y: Vector2 = pose.y*orientation
	Owned.write(item,"position",pose.origin);Owned.write(item,"rotation",pose.x.angle())
	Owned.write(item,"scale",Vector2(pose.x.length(),pose.y.length()*orientation))
	# Godot skew is the negative basis dot/cross angle after reflection removal.
	# Zero/singular bases were rejected above; signed Y scale retains reflections.
	Owned.write(item,"skew",-atan2(pose.x.dot(y),pose.x.cross(y)))
static func _safe_leaf(r: Record) -> bool:
	var g: Session = r.session_ref.get_ref() as Session
	return g!=null and is_instance_valid(r.node) and not r.node.is_queued_for_deletion() and r.node.get_parent()==g.owner_ref.get_ref()
static func _retire_ref(reference: WeakRef) -> void:
	var r: Record = reference.get_ref() as Record
	if r!=null:_retire(r)
static func _retire(r: Record) -> void:
	if r.retired:return
	r.retired = true;r.track.ticks = int(r.track.age)
	var g: Session = r.session_ref.get_ref() as Session
	if g==null:return
	if r.kind=="BG":
		var b: Dictionary = g.bindings.get(r.actor_id,{})
		if not b.is_empty():_hide(g,b,false)
	if r.slot>=0:g.slots[r.slot] = null
	if not r.item.is_empty() and r.item.active:
		if Owned.observe_material(r.item) and r.item.revoked.is_empty() and not r.item.lost_material:r.node.material = r.item.previous
		r.item.active = false
	if _safe_leaf(r) and r.node.get_child_count()==0:r.node.queue_free()
	if is_instance_valid(r.copy) and r.copy.get_parent()==g.owner_ref.get_ref() and r.copy.get_child_count()==0:r.copy.queue_free()
static func _alpha_guard(r: Record) -> void:
	if r.item.is_empty() or not r.item.active:return
	var owned: bool = Owned.observe_material(r.item)
	if not r.copy_receipt.is_empty():
		var receipt: Dictionary = r.copy_receipt
		if not is_instance_valid(r.copy) or r.copy.get_parent()!=receipt.parent or r.copy.z_index!=receipt.z or r.copy.copy_mode!=receipt.mode or r.copy.rect!=receipt.rect:r.copy_lost = true
	if r.copy_lost:
		if owned and r.item.revoked.is_empty() and not r.item.lost_material:r.node.material = r.item.previous
		r.item.active = false
static func _safe_screen(b: Dictionary) -> bool:
	if b.get("screen_lost",false):return false
	var material: Material = b.actor.sprite.material
	if material is ShaderMaterial and material.shader!=null and material.shader.code.contains("hint_screen_texture"):
		b.screen_lost = true;return false
	return true
static func _follow(g: Session,r: Record) -> void:
	if not _safe_leaf(r):_retire(r);return
	var b: Dictionary = _binding(g,r.actor_id)
	if b.is_empty() or b.hide_lost or not _safe_screen(b):_retire(r);return
	var source: Sprite2D = b.actor.sprite
	for key: String in Owned.FOLLOW:Owned.write(r.item,key,source.get(key))
	var owner: Node2D = g.owner_ref.get_ref() as Node2D
	_pose(r.item,owner.global_transform.affine_inverse()*source.global_transform)
	Owned.write(r.item,"visible",bool(b.visible) and source.get_parent().is_visible_in_tree())
static func _headroom(g: Session) -> bool:
	var owner: Node2D = g.owner_ref.get_ref() as Node2D
	if not _identity(g):return false
	var relative: int = BattleSourcePriority.effective_layer(g.field)-BattleSourcePriority.effective_layer(owner)
	return relative+95>= -4096 and relative+192<=4096
static func _command(g: Session,s: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	match str(s.mode):
		"setalpha":g.alpha = Vector2i(12,8)
		"blendoff":g.alpha = Vector2i(16,0)
		"clearmonbg":
			for value: Record in g.records:
				if value.kind=="BG" and not value.retired:
					_hide(g,g.bindings[value.actor_id],false)
					value.duration = value.age+2;value.track.ticks = value.duration
		"monbg":
			if not _headroom(g):return []
			for actor: BattleAnimationActor in Owned.source_bg_members(g.context,1):
				var b: Dictionary = _binding(g,actor.id)
				if b.is_empty() or not _safe_screen(b):continue
				var r: Record = _record(g,"BG",s,4096);r.actor_id = actor.id
				r.track.domain = "maintenance"
				r.node = BattleIdentityCopy.clone_sprite(actor,g.owner_ref.get_ref())
				var owner: Node2D = g.owner_ref.get_ref() as Node2D
				owner.add_child(r.node);r.item = _item(r.node,owner)
				if not _identity(g) or _binding(g,actor.id).is_empty():_retire(r);continue
				var plane: int = 1 if g.context.contest or g.context.source_position(actor.id) in [1,2] else 2
				r.track.clones = [{"actor":actor,"node":r.node,"bg_plane":plane}]
				_hide(g,b,true);_follow(g,r)
				Owned.write(r.item,"z_index",BattleSourcePriority.effective_layer(g.field)-BattleSourcePriority.effective_layer(owner)+(96 if plane==1 else 95))
				if not r.retired:result.append(r.track)
	return result
static func _actor(g: Session,b: Dictionary,s: Dictionary) -> Array[Dictionary]:
	var lunge: bool = int(s.source_line)==1391
	var r: Record = _record(g,"lunge" if lunge else "shake",s,16 if lunge else 13)
	r.actor_id = b.actor.id;r.track.actor = b.actor
	if not lunge:
		var channel: Vector2 = g.channels[r.actor_id];channel.x = 3;g.channels[r.actor_id] = channel
		var owner: Node2D = g.owner_ref.get_ref() as Node2D
		b.actor.apply(owner.get_actor_offset(r.actor_id)+owner.get_actor_approach_correction(r.actor_id)+resolve_offset(owner,b.actor),Color.WHITE);note_application(owner,b.actor)
	var result: Array[Dictionary] = [];result.append(r.track);return result
static func _current_x(g: Session,b: Dictionary) -> float:
	var parent: CanvasItem = b.parent.get_ref() as CanvasItem
	return (g.field.to_local(b.actor.sprite.global_position)-g.field.to_local(parent.get_global_transform()*b.base)).x
static func _comparison_norm(value: Transform2D) -> float:
	return maxf(absf(value.x.x)+absf(value.y.x),absf(value.x.y)+absf(value.y.y))
static func _comparison_point(value: Vector2) -> bool:
	return value.is_finite() and absf(value.x)<=256.0 and absf(value.y)<=256.0
static func _comparison_geometry(g: Session,b: Dictionary) -> bool:
	var sprite: Variant = b.sprite.get_ref();var parent: Variant = b.parent.get_ref()
	if not is_instance_valid(sprite) or not is_instance_valid(parent) or not parent is CanvasItem or not is_instance_valid(g.field):return false
	var field_pose: Transform2D = g.field.global_transform
	var parent_pose: Transform2D = parent.get_global_transform()
	for pose: Transform2D in [field_pose,parent_pose]:
		var determinant: float = pose.determinant()
		if not pose.is_finite() or not is_finite(determinant) or determinant==0.0:return false
		var inverse: Transform2D = pose.affine_inverse()
		if not inverse.is_finite():return false
		var forward_norm: float = _comparison_norm(pose)
		var inverse_norm: float = _comparison_norm(inverse)
		if forward_norm>4.0 or inverse_norm>4.0 or forward_norm*inverse_norm>4.0:return false
		if not _comparison_point(pose.origin):return false
	var actual_global: Vector2 = sprite.global_position
	var baseline_global: Vector2 = parent_pose*b.base
	var field_inverse: Transform2D = field_pose.affine_inverse()
	for point: Vector2 in [b.base,sprite.position,actual_global,baseline_global,field_inverse*actual_global,field_inverse*baseline_global]:
		if not _comparison_point(point):return false
	return true
static func _source_three(g: Session,b: Dictionary,current: float) -> bool:
	# Deliberate finite native integer-comparison resolution, NOT a universal
	# floating-error theorem. Foreign values inside this bin are indistinguishable.
	if not is_finite(current):return false
	if current==3.0:return true
	return absf(current-3.0)<=1.0/1024.0 and _comparison_geometry(g,b)
static func actor_step(t: Dictionary,c: BattleAnimationContext) -> void:
	var r: Record = t.dizzy_record.get_ref() as Record
	if r==null or r.retired:return
	var g: Session = r.session_ref.get_ref() as Session
	if g==null or not _identity(g) or g.context!=c:_retire(r);return
	var b: Dictionary = _binding(g,r.actor_id)
	if b.is_empty():g.channels[r.actor_id] = Vector2.ZERO;_retire(r);return
	r.age = int(t.age)
	var channel: Vector2 = g.channels[r.actor_id]
	if r.kind=="lunge":
		var direction: int = 1 if b.actor.side==0 else -1
		if r.age>=1 and r.age<=6:channel.x += 4*direction
		elif r.age>=9 and r.age<=14:channel.x -= 4*direction
	elif r.age%2==1:
		# C AnimTask_ShakeMon2Step compares ACTUAL current x2, not a triangle.
		var current: float = _current_x(g,b)
		var desired: float = 0.0 if r.age>=13 else -3.0 if _source_three(g,b,current) else 3.0
		channel.x += desired-current
	g.channels[r.actor_id] = channel
	if r.age>=r.duration:_retire(r)
static func resolve_offset(owner: Node2D,actor: BattleAnimationActor) -> Vector2:
	var g: Session = _group(owner)
	if g==null or not _identity(g) or _binding(g,actor.id).is_empty():return Vector2.ZERO
	var parent: CanvasItem = actor.sprite.get_parent() as CanvasItem
	var value: Vector2 = g.channels.get(actor.id,Vector2.ZERO)
	var projection: Transform2D = parent.get_global_transform().affine_inverse()*g.field.global_transform
	return projection*value-projection*Vector2.ZERO
static func _particle(g: Session,b: Dictionary,s: Dictionary,rects: Dictionary) -> Array[Dictionary]:
	if not _headroom(g):return []
	var line: int = int(s.source_line)
	var kind: String = "duck" if line in Data.DUCK_LINES else "fist" if line in Data.FIST_LINES else "hit"
	var r: Record = _record(g,kind,s,41 if kind=="duck" else 22 if kind=="fist" else 11);r.actor_id = b.actor.id
	var owner: Node2D = g.owner_ref.get_ref() as Node2D
	var attackers: Dictionary = _binding(g,g.context.attacker_id)
	if attackers.is_empty():_retire(r);return []
	var start: Dictionary = Coordinates.visual(attackers.actor,g.context);var target: Dictionary = Coordinates.visual(b.actor,g.context)
	var facing_start: Dictionary = Coordinates.nominal(attackers.actor,g.context);var facing_end: Dictionary = Coordinates.nominal(b.actor,g.context)
	if start.state!="valid" or target.state!="valid":_retire(r);return []
	var direction: int = 1 if facing_start.point.x<facing_end.point.x else -1 if facing_start.point.x>facing_end.point.x else 1 if attackers.actor.side==0 else -1
	var args: Array = Data.PROGRAM.steps[_site_pc(line)-1].source_args
	r.args = args.duplicate()
	r.point = target.point+Vector2(int(args[0])*direction,int(args[1]))
	r.subpriority = maxi(3,BattleElectricContract.source_subpriority(b.actor,g.context)-(3 if kind=="duck" else 5 if kind=="fist" else 4))
	r.node = Sprite2D.new();r.node.texture = _texture(s)
	r.node.modulate = Color(str(s.get("color","ffffff")))
	r.node.flip_h = bool(s.get("flip_h",false));r.node.flip_v = bool(s.get("flip_v",false))
	r.node.region_enabled = true;var rect: Array = rects["0"];r.node.region_rect = Rect2(rect[0],rect[1],rect[2],rect[3])
	var alpha: bool = kind=="hit" and not bool(s.get("recolor",false))
	if alpha:
		r.copy = BackBufferCopy.new();r.copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT;owner.add_child(r.copy)
		var material := ShaderMaterial.new();material.shader = AB
		material.set_shader_parameter("eva",float(g.alpha.x)/16.0);material.set_shader_parameter("evb",float(g.alpha.y)/16.0);material.set_shader_parameter("first_tint",r.node.modulate)
		r.node.material = material;r.node.modulate = Color.WHITE
	elif bool(s.get("recolor",false)):
		var material := ShaderMaterial.new();material.shader = Recolor;material.set_shader_parameter("tint",r.node.modulate);r.node.material = material
		r.track.source_local_alpha_override = true
	owner.add_child(r.node);r.item = _item(r.node,owner)
	if not _identity(g) or _binding(g,r.actor_id).is_empty():_retire(r);return []
	if alpha:
		r.item.active = true;r.item.material = r.node.material;r.item.shader = AB
		for key: String in ["eva","evb","first_tint"]:r.item.uniforms[key] = r.item.material.get_shader_parameter(key)
	for index: int in range(4,64):
		if g.slots[index]==null:g.slots[index] = r;r.slot = index;break
	if r.slot<0:_retire(r);return []
	r.track.node = r.node;r.track.source_oam_priority = 2;r.track.source_oam_subpriority = r.subpriority
	r.item.rects = rects
	_project(g,r);_order(g)
	if not _identity(g) or _binding(g,r.actor_id).is_empty():_retire(r)
	var result: Array[Dictionary] = []
	if not r.retired:result.append(r.track)
	return result
static func _project(g: Session,r: Record) -> void:
	if not _safe_leaf(r):_retire(r);return
	if _binding(g,r.actor_id).is_empty():_retire(r);return
	var point: Vector2 = r.point
	if r.kind=="duck" and r.age>0:
		point += Vector2((r.age*int(r.args[2]))>>8,Trig.sine(((r.age-1)*3)&255,int(r.args[3])))
	var factor: float = float(r.recipe.get("scale_factor",1.0))
	if r.kind=="hit" and factor==float(Data.PROGRAM.steps[_site_pc(int(r.recipe.source_line))].get("scale_factor",1.0)):factor = 216.0/256.0
	var owner: Node2D = g.owner_ref.get_ref() as Node2D
	_pose(r.item,owner.global_transform.affine_inverse()*g.field.global_transform*Transform2D(Vector2(factor,0),Vector2(0,factor),point))
	Owned.write(r.item,"visible",r.kind!="duck" or r.age*3<=100 or (r.age*3)%2==0)
static func _site_pc(line: int) -> int:
	for pc: int in Data.PROGRAM.steps.size():
		if Data.PROGRAM.steps[pc].get("op")=="effect" and int(Data.PROGRAM.steps[pc].get("source_line",-1))==line:return pc
	return -1
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	var r: Record = t.dizzy_record.get_ref() as Record
	if r==null or r.retired:return
	var g: Session = r.session_ref.get_ref() as Session
	if g==null or not _identity(g) or c!=g.context:_retire(r);return
	var owner: Node2D = g.owner_ref.get_ref() as Node2D
	if not owner._tracks.any(func(candidate: Dictionary) -> bool:return is_same(candidate,t)):return
	if int(t.age)!=r.age+1 or not Same._same(t.settings,r.recipe):_retire(r);return
	r.age = int(t.age)
	if r.age>=r.duration:_retire(r)
	elif r.kind=="BG":_follow(g,r)
	else:_project(g,r)

static func _oam(r: Record) -> Array:
	if r==null or r.retired:return [1023,-96]
	var y: float = r.point.y
	if r.kind=="duck" and r.age>0:y += Trig.sine(((r.age-1)*3)&255,int(r.args[3]))
	var encoded: int = int(y-(8 if r.kind=="duck" else 16))&255
	return [512+r.subpriority,encoded-256 if encoded>=160 else encoded]
static func _order(g: Session) -> void:
	var owner: Node2D = g.owner_ref.get_ref() as Node2D
	if not is_instance_valid(owner) or not is_instance_valid(g.field):return
	# A native owned-presentation projection: update even on blink-off ticks.
	# Equal keys preserve the LAST permutation, including first-free slot reuse.
	for index: int in range(1,64):
		var cursor: int = index
		while cursor>0:
			var left: Array = _oam(g.slots[g.permutation[cursor-1]])
			var right: Array = _oam(g.slots[g.permutation[cursor]])
			if not (int(left[0])>int(right[0]) or (left[0]==right[0] and int(left[1])<int(right[1]))):break
			var previous: int = g.permutation[cursor-1];g.permutation[cursor-1] = g.permutation[cursor];g.permutation[cursor] = previous;cursor -= 1
	var field_z: int = BattleSourcePriority.effective_layer(g.field)
	var owner_z: int = BattleSourcePriority.effective_layer(owner)
	var base: int = field_z+128
	for index: int in 64:
		var r: Record = g.slots[g.permutation[index]] as Record
		if r==null or r.retired:continue
		var z: int = base+64-index-owner_z
		if z< -4096 or z>4096:_retire(r);continue
		Owned.write(r.item,"z_index",z)
		if is_instance_valid(r.copy) and r.copy.get_parent()==owner:
			_alpha_guard(r)
			if not r.copy_lost:
				r.copy.z_index = int(r.node.z_index)
				r.copy_receipt = {"parent":owner,"z":r.copy.z_index,"mode":r.copy.copy_mode,"rect":r.copy.rect}
static func before_track(owner: Node2D,t: Dictionary) -> bool:
	if not t.has("dizzy_record"):return true
	var r: Record = t.dizzy_record.get_ref() as Record if t.dizzy_record is WeakRef else null
	if r==null or not is_same(r.track,t):owner._tracks.erase(t);return false
	var g: Session = r.session_ref.get_ref() as Session
	var kind: String = "source_particle" if r.kind in ["duck","fist","hit"] else "source_dizzy_actor" if r.kind in ["lunge","shake"] else "source_dizzy_bg"
	if r.retired or g==null or not _identity(g) or t.get("kind")!=kind or int(t.get("age",-1))!=r.age or int(t.get("ticks",-1))!=r.duration or not Same._same(t.get("settings"),r.recipe):
		_retire(r);owner._tracks.erase(t);return false
	return true
static func begin_tick(owner: Node2D,c: BattleAnimationContext) -> void:
	var g: Session = _group(owner)
	if g==null or c!=g.context:return
	for r: Record in g.records:
		if r.retired:continue
		if not _identity(g):_retire(r);continue
		if r.actor_id>=0 and _binding(g,r.actor_id).is_empty():_retire(r);continue
		if not r.item.is_empty() and r.item.active:_alpha_guard(r)
		if r.kind=="BG":
			var b: Dictionary = g.bindings[r.actor_id]
			if b.hide_owned and b.actor.sprite.visible!=b.hide_expected:b.hide_lost = true
	# Revoke original sound ownership before generic paused/pitch/drain writes.
	for entry: Dictionary in g.sounds:_sound_owned(g,entry)
static func after_pose(owner: Node2D,c: BattleAnimationContext) -> void:
	var g: Session = _group(owner)
	if g==null or not _identity(g) or c!=g.context:return
	for r: Record in g.records:
		if r.kind=="BG" and not r.retired:_follow(g,r)
	_order(g)
static func actor_allowed(owner: Node2D,actor: BattleAnimationActor) -> bool:
	var g: Session = _group(owner)
	return g==null or (_identity(g) and not _binding(g,actor.id).is_empty())
static func _sound_entry(g: Session,player: AudioStreamPlayer2D) -> Dictionary:
	for entry: Dictionary in g.sounds:
		if entry.player.get_ref()==player:return entry
	return {}
static func note_sound(owner: Node2D,player: AudioStreamPlayer2D) -> void:
	var g: Session = _group(owner)
	if g==null or not _sound_entry(g,player).is_empty():return
	g.sounds.append({"player":weakref(player),"stream":weakref(player.stream),"lost":false,"properties":_audio_properties(player),"exit_receipt":{}})
	# Both callbacks bind only weak references, never Session/Node ownership.
	player.tree_exiting.connect(_voice_tree_exiting.bind(weakref(g),weakref(player)))
	player.tree_entered.connect(_voice_tree_entered.bind(weakref(g),weakref(player)))
static func _voice_tree_entered(group_ref: WeakRef,player_ref: WeakRef) -> void:
	var g: Session = group_ref.get_ref() as Session
	var player: Variant = player_ref.get_ref()
	if g==null or not is_instance_valid(player):return
	var entry: Dictionary = _sound_entry(g,player)
	if not entry.is_empty():entry.exit_receipt = {} # Never reset sticky loss.
static func _voice_tree_exiting(group_ref: WeakRef,player_ref: WeakRef) -> void:
	var g: Session = group_ref.get_ref() as Session
	var player: Variant = player_ref.get_ref()
	if g==null or g.terminal or not is_instance_valid(player):return
	var owner: Variant = g.owner_ref.get_ref()
	if not is_instance_valid(owner) or _group(owner)!=g or owner.state!="running":return
	var entry: Dictionary = _sound_entry(g,player)
	if entry.is_empty():return
	entry.exit_receipt = {}
	# This voice signal precedes its native EXIT_TREE auto-pause.
	if not player.is_inside_tree() or not _sound_owned(g,entry):return
	var playback: Variant = player.get_stream_playback() if player.has_stream_playback() else null
	entry.exit_receipt = {"frame":Engine.get_process_frames(),"owner":owner.get_instance_id(),"player":player.get_instance_id(),"stream":player.stream.get_instance_id(),"properties":entry.properties.duplicate(),"playback":weakref(playback) if is_instance_valid(playback) else null,"used":false}
static func _native_exit_pause_owned(g: Session,entry: Dictionary,player: AudioStreamPlayer2D) -> bool:
	var receipt: Dictionary = entry.get("exit_receipt",{})
	var owner: Variant = g.owner_ref.get_ref()
	if entry.lost or receipt.is_empty() or receipt.get("used",true) or not is_instance_valid(owner):return false
	if _group(owner)!=g or not g.terminal or owner.state!="cancelled" or not owner.lifecycle_aborted or not owner.is_inside_tree() or player.is_inside_tree() or owner.get_parent()!=g.parent_ref.get_ref():return false
	if receipt.frame!=Engine.get_process_frames() or receipt.owner!=owner.get_instance_id() or receipt.player!=player.get_instance_id() or receipt.stream!=player.stream.get_instance_id():return false
	if not Same._same(receipt.properties,entry.properties) or entry.properties[0]!=false or player.stream_paused!=true or player.pitch_scale!=entry.properties[1] or player.volume_db!=entry.properties[2]:return false
	var playback_ref: Variant = receipt.get("playback")
	if not playback_ref is WeakRef or not player.has_stream_playback():return false
	var playback: Variant = playback_ref.get_ref()
	if not is_instance_valid(playback) or player.get_stream_playback()!=playback:return false
	receipt.used = true # One terminal grant, not a new last-owned pause tuple.
	return true
static func _sound_owned(g: Session,entry: Dictionary,native_exit: bool=false) -> bool:
	if entry.lost:return false
	var player: Variant = entry.player.get_ref();var stream: Variant = entry.stream.get_ref()
	if not is_instance_valid(player) or not is_instance_valid(stream) or player.get_parent()!=g.owner_ref.get_ref() or player.stream!=stream or player.is_queued_for_deletion():entry.lost = true
	if not entry.lost and not Same._same(entry.properties,_audio_properties(player)):
		if not native_exit or not _native_exit_pause_owned(g,entry,player):entry.lost = true
	return not entry.lost
static func audio_allowed(owner: Node2D,player: AudioStreamPlayer2D) -> bool:
	var g: Session = _group(owner)
	if g==null:return true
	for entry: Dictionary in g.sounds:
		if entry.player.get_ref()==player:return _sound_owned(g,entry)
	return false
static func audio_playing(owner: Node2D) -> bool:
	var g: Session = _group(owner)
	if g==null:return owner._sounds.any(func(player: AudioStreamPlayer2D) -> bool:return is_instance_valid(player) and player.playing)
	for entry: Dictionary in g.sounds:
		if _sound_owned(g,entry) and entry.player.get_ref().playing:return true
	return false
static func finish_context_loss(owner: Node2D) -> bool:
	var g: Session = _group(owner)
	return finish(owner,"cancelled") if g!=null and (owner.context==null or not is_instance_valid(owner.context.field) or not owner.context.field.is_inside_tree()) else false
static func finish(owner: Node2D,state: String) -> bool:
	var g: Session = _group(owner)
	if g==null:return false
	if g.terminal:return true
	g.terminal = true;owner.state = state
	var sweep := Sweep.new();sweep.owner_ref = weakref(owner)
	for r: Record in g.records:
		_retire(r)
		for node: Variant in [r.node,r.copy]:
			if not is_instance_valid(node) or node.get_parent()!=owner:continue
			sweep.leaves.append(weakref(node))
			if not node.child_exiting_tree.is_connected(sweep.changed):node.child_exiting_tree.connect(sweep.changed)
			if not node.child_order_changed.is_connected(sweep.children_changed):node.child_order_changed.connect(sweep.children_changed)
	for id: int in g.bindings:
		var b: Dictionary = _binding(g,id,true)
		if b.is_empty():continue
		_hide(g,b,false)
		if b.get("actor_written",false) and b.actor.is_present():b.actor.release()
	for entry: Dictionary in g.sounds:
		if not _sound_owned(g,entry,state=="cancelled" and owner.lifecycle_aborted):continue
		var player: AudioStreamPlayer2D = entry.player.get_ref()
		# Playback ownership and descendant lifetime are independent.
		player.stop()
		if player.get_child_count()==0:player.queue_free()
		else:
			sweep.leaves.append(weakref(player))
			if not player.child_exiting_tree.is_connected(sweep.changed):player.child_exiting_tree.connect(sweep.changed)
			if not player.child_order_changed.is_connected(sweep.children_changed):player.child_order_changed.connect(sweep.children_changed)
	owner._tracks.clear();owner._sounds.clear()
	owner.remove_meta(STATE);owner.set_meta("source_dizzy_terminal",sweep)
	if not owner.child_exiting_tree.is_connected(sweep.changed):owner.child_exiting_tree.connect(sweep.changed)
	if not owner.child_order_changed.is_connected(sweep.children_changed):owner.child_order_changed.connect(sweep.children_changed)
	owner.terminated.emit(state)
	# Drop only our captured execution input references; no foreign node is freed.
	owner.definition = null;owner.context = null;owner._steps.clear();owner._factories = {}
	sweep.changed();return true

static func release_track_node_allowed(_owner: Node2D,t: Dictionary) -> bool:
	# Our Record owns retirement; generic queue_free must not kill foreign children.
	return not t.has("dizzy_record")
static func literal_art(raw: Dictionary,c: BattleAnimationContext,owner: Node2D,kind: String) -> Dictionary:
	# Contexts without optional coordinate providers retain literal semantics, even
	# for an admitted Texture dependency. No finite geometry/lifetime claim here.
	if not raw.get("texture") is Texture2D or not matches(owner) or kind not in ["sheet","source_particle"]:return {}
	if not _body(owner.definition):return {"handled":true,"valid":false}
	var pc: int = owner._pc
	if pc<0 or pc>=Data.PROGRAM.steps.size() or not _art(Data.PROGRAM.steps[pc]):return {"handled":true,"valid":false}
	if owner._effect_dispatch_pc!=pc or not is_same(owner._effect_dispatch_step,raw) or not owner._i159_dispatch_live:return {"handled":true,"valid":false}
	var snapshot: Dictionary = raw.duplicate(true);var definition: BattleAnimationDefinition = owner.definition
	var roles: Array = _roles(c)
	if not owner.claim_effect_dispatch(raw):return {"handled":true,"valid":false}
	var rects: Dictionary = _rects(raw,Data.PROGRAM.steps[pc])
	var valid: bool = not rects.is_empty() and _definition(definition) and owner.state=="running" and owner.definition==definition and owner.context==c and Same._same(roles,_roles(c)) and Same._same(snapshot,raw)
	return {"handled":true,"valid":valid,"texture":raw.texture} if valid else {"handled":true,"valid":false}

static func note_application(owner: Node2D,actor: BattleAnimationActor) -> void:
	var g: Session = _group(owner)
	if g==null or not _identity(g) or _binding(g,actor.id).is_empty():return
	var b: Dictionary = g.bindings[actor.id]
	b.actor_written = true
	b.channel_position = actor.sprite.position
	b.channel_local = resolve_offset(owner,actor)
static func _audio_properties(player: AudioStreamPlayer2D) -> Array:
	return [player.stream_paused,player.pitch_scale,player.volume_db]
static func note_audio_write(owner: Node2D,player: AudioStreamPlayer2D) -> void:
	var g: Session = _group(owner)
	if g==null:return
	for entry: Dictionary in g.sounds:
		if not entry.lost and entry.player.get_ref()==player and player.get_parent()==owner and entry.stream.get_ref()==player.stream:
			entry.properties = _audio_properties(player)
			entry.exit_receipt = {} # A later owned write invalidates an earlier exit witness.

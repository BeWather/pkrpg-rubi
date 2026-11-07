extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Finite canonical101 adapter. Source workers are not native cached-OAM emulation.
const State = preload("res://scripts/battle/animations/sequence/source_night_shade_state.gd")
const Owned = preload("res://scripts/battle/animations/sequence/source_owned_composition.gd")
const Coordinates = preload("res://scripts/battle/animations/sequence/source_coordinate_contract.gd")
const Encoding = preload("res://scripts/battle/animations/sequence/source_confuse_ray_state.gd")
const Same = preload("res://scripts/battle/animations/sequence/source_cutting_slice.gd")
const AB = preload("res://scripts/battle/animations/sequence/source_local_ab.gdshader")
const Palette = preload("res://scripts/battle/animations/sequence/source_night_shade_palette.gdshader")
const STATE := "source_night_shade_session"
const FINGERPRINT := "c3f9df04f70e522f6d03cd1ce442caaba420b4ada2ad7fee2fcc24fcce3338a8"
static var _validating: Dictionary = {}

class Session extends RefCounted:
	var owner_ref: WeakRef
	var parent_ref: WeakRef
	var field_ref: WeakRef
	var definition: BattleAnimationDefinition
	var context: BattleAnimationContext
	var program: Array
	var roles: Array
	var bindings: Dictionary = {}
	var records: Array = []
	var calls: Dictionary = {}
	var leaves: Array[WeakRef] = []
	var voices: Array = []
	var declines: Array = []
	var background: Dictionary = {}
	var blackout: Dictionary = {}
	var band := 0 # Effective canvas rank, never an original Sprite local z.
	var planes: Dictionary = {}
	var promoted := false
	var terminal := false
	var constructing := false

class Record extends RefCounted:
	var session_ref: WeakRef
	var track: Dictionary
	var kind := ""
	var actor_id := -1
	var item: Dictionary = {}
	var pair: Dictionary = {}
	var state: Dictionary = {}
	var input: Dictionary = {}
	var image: Image
	var prepared_image: Image
	var texture: ImageTexture
	var coefficient := -1
	var indexed := false
	var bytes: PackedByteArray = []
	var clock_live := false # Invalid background publication retires without shortening its task.
	var retired := false
	var pending := true
	var published_age := -1

static func group(owner: Node2D) -> Session:
	return owner.get_meta(STATE) as Session if is_instance_valid(owner) and owner.has_meta(STATE) else null
static func _body(d: BattleAnimationDefinition,diagnostic: Dictionary={}) -> bool:
	if d==null or d.key!="ruby:move/101" or not BattleAnimationSequenceRegistry.is_builtin_source_definition(d):diagnostic.body_gate="original_resource_identity_or_key";return false
	var steps: Array = []
	for raw: Dictionary in d.steps:
		var s: Dictionary = Encoding.normalized(raw)
		if s.is_empty():diagnostic.body_gate="malformed_step_keys";return false
		if s.get("op")=="effect" and int(s.get("source_line",-1)) in [7292,7303]:s.erase("texture")
		steps.append(s)
	var digest: String = Encoding.stable([d.key,d.coverage,d.source_script,d.schema_version,steps]).sha256_text()
	diagnostic.structure_sha256=digest;diagnostic.expected_sha256=FINGERPRINT;diagnostic.body_gate="accepted" if digest==FINGERPRINT else "whole_non_ART_fingerprint"
	return digest==FINGERPRINT
static func _texture(s: Dictionary,diagnostic: Dictionary={}) -> Texture2D:
	var value: Variant = s.get("texture")
	diagnostic.raw_type=typeof(value)
	diagnostic.raw_class=value.get_class() if value is Object and is_instance_valid(value) else ""
	diagnostic.raw_id=value.get_instance_id() if value is Object and is_instance_valid(value) else 0
	if value is Texture2D:
		diagnostic.branch="typed_Texture2D";diagnostic.returned_id=value.get_instance_id();diagnostic.same_raw_object=true
		return value as Texture2D
	if value is String and ResourceLoader.exists(value):
		var texture: Texture2D = load(value) as Texture2D
		diagnostic.branch="existing_resource_path";diagnostic.returned_id=texture.get_instance_id() if texture!=null else 0;diagnostic.same_raw_object=false
		return texture
	diagnostic.branch="unsupported_or_missing";diagnostic.returned_id=0;diagnostic.same_raw_object=false
	return null
static func _definition(d: BattleAnimationDefinition,diagnostic: Dictionary={}) -> bool:
	var body: bool = _body(d,diagnostic);diagnostic.body_before=body
	if not body:diagnostic.gate="whole_original_program";return false
	if _validating.has(d.get_instance_id()):diagnostic.gate="validation_reentry";return false
	_validating[d.get_instance_id()]=true
	var before: Array = d.steps.duplicate(true);var valid := true
	diagnostic.sites=[]
	for s: Dictionary in d.steps:
		if s.get("op")=="effect" and int(s.get("source_line",-1)) in [7292,7303]:
			var resolution: Dictionary = {}
			var texture: Texture2D = _texture(s,resolution)
			var input: Dictionary = Owned.image_input(texture)
			diagnostic.sites.append({"line":s.source_line,"class":texture.get_class() if texture!=null else "null","image_input_valid":not input.is_empty(),"resolver":resolution})
			if input.is_empty():valid=false;diagnostic.gate="image_input_line_"+str(s.source_line)
	var after: bool = _body(d);var same: bool = Same._same(before,d.steps)
	diagnostic.body_after=after;diagnostic.program_unchanged=same
	if not after:diagnostic.gate="whole_program_changed_during_validation"
	elif not same:diagnostic.gate="step_identity_or_value_changed_during_validation"
	valid = valid and after and same
	_validating.erase(d.get_instance_id());return valid
static func accepts_texture_dependency(d: BattleAnimationDefinition,s: Dictionary) -> bool:
	var diagnostic: Dictionary = {"key":d.key,"line":s.get("source_line",-1),"definition_id":d.get_instance_id(),"builtin":BattleAnimationSequenceRegistry.is_builtin_source_definition(d)}
	var valid: bool = _definition(d,diagnostic)
	var alias: bool = d.steps.any(func(entry: Dictionary)->bool:return is_same(entry,s) and entry.get("op")=="effect" and int(entry.get("source_line",-1)) in [7292,7303])
	diagnostic.step_alias=alias;diagnostic.accepted=valid and alias
	if valid and not alias:diagnostic.gate="actual_step_identity_or_ART_site"
	if diagnostic.accepted:diagnostic.gate="accepted"
	# Truthful actual public gate evidence, never a bypass or test authority token.
	print("I176_TYPED_BG_ADMISSION "+JSON.stringify(diagnostic))
	return valid and alias
static func tick_allowed(owner: Node2D) -> bool:
	var g: Session = group(owner)
	return (g==null or not g.constructing) and (owner.definition==null or not _validating.has(owner.definition.get_instance_id()))
static func _capture(owner: Node2D,c: BattleAnimationContext) -> Session:
	var g := Session.new();g.owner_ref=weakref(owner);g.parent_ref=weakref(owner.get_parent());g.field_ref=weakref(c.field);g.definition=owner.definition;g.context=c;g.program=owner._steps.duplicate(true)
	g.roles=[c.attacker_id,c.target_ids.duplicate(),c.source_positions.duplicate(),c.contest]
	for actor: BattleAnimationActor in c.actors.values():
		var source: Sprite2D = actor.sprite
		var provider: Variant = c.source_visual.get(actor.id);var nominal: Variant = c.source_nominal.get(actor.id)
		var receipt: Dictionary = Owned.item(source,source.get_parent());receipt.plane_relative=source.z_as_relative
		g.bindings[actor.id]={"actor":actor,"id":actor.id,"side":actor.side,"sprite":weakref(source),"parent":weakref(source.get_parent()),"slot":weakref(actor.slot) if is_instance_valid(actor.slot) else null,"generation":actor._generation,"texture":source.texture,"input":Owned.image_input(source.texture),"art_lost":false,"entry":receipt.writes.duplicate(),"item":receipt,"provider":provider,"nominal":nominal,"provider_copy":provider.duplicate(true) if provider is Dictionary else provider,"nominal_copy":nominal.duplicate(true) if nominal is Dictionary else nominal,"uniforms":{},"shader":source.material.shader if source.material is ShaderMaterial else null,"lost":false,"position":source.position,"art":source.transform}
	for b: Dictionary in g.bindings.values():
		if b.entry.material is ShaderMaterial and b.shader!=null:
			for property: Dictionary in b.shader.get_shader_uniform_list():b.uniforms[str(property.name)]=b.entry.material.get_shader_parameter(str(property.name))
	g.planes=_plane_capture(g);g.band=int(g.planes.get("band",0))
	if bool(g.planes.get("lost",false)):g.declines.append({"plane_policy":"publication_declined","reason":g.planes.reason})
	owner.set_meta(STATE,g);return g
static func _identity(g: Session) -> bool:
	var owner: Variant = g.owner_ref.get_ref()
	return not g.terminal and is_instance_valid(owner) and owner.state=="running" and owner.context==g.context and owner.definition==g.definition and owner.get_parent()==g.parent_ref.get_ref() and owner.is_inside_tree() and g.context.field==g.field_ref.get_ref() and is_instance_valid(g.context.field) and g.context.field.is_inside_tree() and _body(g.definition) and Same._same(g.program,g.definition.steps) and Same._same(g.program,owner._steps) and g.roles==[g.context.attacker_id,g.context.target_ids,g.context.source_positions,g.context.contest]
static func _subject(g: Session,b: Dictionary) -> bool:
	var sprite: Variant = b.sprite.get_ref();var actor: BattleAnimationActor = b.actor
	return actor.id==b.id and actor.side==b.side and g.context.actors.get(b.id)==actor and is_instance_valid(sprite) and actor.sprite==sprite and sprite.get_parent()==b.parent.get_ref() and actor.is_present() and actor._generation==b.generation and (actor.slot==b.slot.get_ref() and is_instance_valid(actor.slot) and actor.slot.sprite_pokemon==sprite if b.slot is WeakRef else actor.slot==null) and not g.context.actors.values().any(func(other: BattleAnimationActor)->bool:return other!=actor and other.sprite==sprite)
# Inverse-domain safety is exact and separate from allocation/layer headroom.
# Finite reflections, skew and small nonzero determinants retain their policy.
static func _invertible(transform: Transform2D) -> bool:
	var determinant: float=transform.determinant()
	return transform.is_finite() and is_finite(determinant) and determinant!=0.0
static func _world_invertible(owner: Node2D,field: Node2D) -> bool:
	return is_instance_valid(owner) and is_instance_valid(field) and _invertible(owner.global_transform) and _invertible(field.global_transform)
static func _inverse_authority(g: Session,parent: Node2D=null) -> bool:
	if g.terminal:return false
	var owner: Node2D=g.owner_ref.get_ref() as Node2D
	if _world_invertible(owner,g.field_ref.get_ref() as Node2D) and (parent==null or _invertible(parent.global_transform)):return true
	# Observation permanently revokes every subject BEFORE ordinary retirement:
	# neither geometry nor material cleanup may restore an adopted appearance.
	for binding: Dictionary in g.bindings.values():binding.lost=true
	finish(owner,"cancelled");return false
static func _binding(g: Session,id: int) -> Dictionary:
	var b: Dictionary = g.bindings.get(id,{})
	if g.terminal or b.is_empty() or b.lost:return {}
	if not _subject(g,b) or not is_same(g.context.source_visual.get(id),b.provider) or not is_same(g.context.source_nominal.get(id),b.nominal) or not Same._same(b.provider,b.provider_copy) or not Same._same(b.nominal,b.nominal_copy):
		b.lost=true;_restore(g,b,["visible","position","rotation","scale","skew","z_index"]);return {}
	if not _inverse_authority(g,b.parent.get_ref() as Node2D):return {}
	if Coordinates.visual(b.actor,g.context).state=="invalid" or Coordinates.nominal(b.actor,g.context).state=="invalid":
		b.lost=true;_restore(g,b,["visible","position","rotation","scale","skew","z_index"]);return {}
	return b
static func _actor_art(g: Session,b: Dictionary) -> void:
	# ART loss is not subject/provider authority loss: keep source callbacks alive.
	if not b.art_lost and Owned.image_input_valid(b.input):return
	b.art_lost=true
	for record: Record in g.records:
		if record.actor_id!=b.id:continue
		if record.kind=="actor_BG":_retire(record)
		elif record.kind in ["ghost","palette"] and not record.item.is_empty():
			_release_actor_material(record);record.item={}
			if not record.pair.is_empty() and Owned.node(record.pair):
				Owned.write(record.pair,"copy_mode",BackBufferCopy.COPY_MODE_DISABLED)
				if record.pair.node.get_child_count(true)==0:record.pair.node.queue_free()
			record.pair={}
static func _restore(g: Session,b: Dictionary,keys: Array) -> void:
	# Whole-binding revocation stays final when identity inputs are restored.
	if b.lost or not _subject(g,b):return
	for key: String in keys:
		if b.item.writes.get(key)!=b.entry.get(key):Owned.write(b.item,key,b.entry[key])
static func _projection(g: Session) -> Variant:
	if not _inverse_authority(g):return null
	var owner: Node2D = g.owner_ref.get_ref()
	return owner.global_transform.affine_inverse()*g.context.field.global_transform
# One Session owns frozen canvas planes; no global battle layout or canvas state changes.
static func _canvas_parent(node: CanvasItem) -> CanvasItem:
	return null if node.is_set_as_top_level() else node.get_parent() as CanvasItem
static func _canvas_z(node: CanvasItem) -> int:
	var chain: Array[CanvasItem]=[];var current: CanvasItem=node
	while current!=null:chain.push_front(current);current=_canvas_parent(current)
	var rank:=0
	for item: CanvasItem in chain:rank=clampi(rank+item.z_index,-4096,4096) if item.z_as_relative else item.z_index
	return rank
static func _plane_stamp(node: CanvasItem,own_z: bool=true) -> Array:
	if not is_instance_valid(node) or not node.is_inside_tree():return []
	var result: Array=[];var current: CanvasItem=node
	while current!=null:
		result.append([current.get_instance_id(),current.get_canvas().get_id(),current.get_viewport().get_instance_id(),current.z_index if own_z or current!=node else "leased",current.z_as_relative,current.is_set_as_top_level(),(current as Node2D).y_sort_enabled if current is Node2D else false])
		current=_canvas_parent(current)
	return result
static func _local_z(node: CanvasItem,rank: int) -> int:
	var parent: CanvasItem=_canvas_parent(node)
	return rank-_canvas_z(parent) if node.z_as_relative and parent!=null else rank
static func _entry_before_owner(entry: CanvasItem,owner: CanvasItem) -> bool:
	# Equal-rank ties are supported only for ordinary unambiguous tree ordering.
	var left: Array[Node]=[];var right: Array[Node]=[]
	for start: Node in [entry,owner]:
		var path: Array[Node]=[];var current: Node=start
		while current!=null:
			if current is CanvasItem and ((current as CanvasItem).is_set_as_top_level() or (current as CanvasItem).show_behind_parent or current is Node2D and (current as Node2D).y_sort_enabled):return false
			path.append(current);current=current.get_parent()
		if start==entry:left=path
		else:right=path
	while not left.is_empty() and not right.is_empty() and left[-1]==right[-1]:left.pop_back();right.pop_back()
	return not left.is_empty() and not right.is_empty() and left[-1].get_index()<right[-1].get_index()
static func _plane_capture(g: Session) -> Dictionary:
	var owner: Node2D=g.owner_ref.get_ref();var field: Node2D=g.context.field
	if not owner.is_inside_tree() or not field.is_inside_tree():return {"lost":true,"reason":"canvas_subject_outside_tree"}
	var canvas: int=owner.get_canvas().get_id();var low:=4097;var high: int=_canvas_z(field)+5
	var actors: Dictionary={}
	if canvas==0 or field.get_canvas().get_id()!=canvas or field.get_viewport()!=owner.get_viewport():return {"lost":true,"reason":"different_owner_FIELD_canvas"}
	for b: Dictionary in g.bindings.values():
		var sprite: Sprite2D=b.sprite.get_ref()
		if not _subject(g,b):continue
		if sprite.get_canvas().get_id()!=canvas or sprite.get_viewport()!=owner.get_viewport():return {"lost":true,"reason":"interleaved_actor_canvas"}
		var rank: int=_canvas_z(sprite);low=mini(low,rank);high=maxi(high,rank)
		actors[b.id]=_plane_stamp(sprite,false)
	if actors.is_empty():return {"lost":true,"reason":"no_bound_normal_OBJ"}
	var background: int=low-1;var entry: Array[Dictionary]=[]
	for name: String in ["btlFondo","btlSueloArriba","btlSueloAbajo"]:
		var node: CanvasItem=field.get_node_or_null(name) as CanvasItem
		if node==null:continue
		var rank: int=_canvas_z(node)
		if node.get_canvas().get_id()!=canvas or rank>background or rank==background and not _entry_before_owner(node,owner):return {"lost":true,"reason":"entry_BG_not_below_or_earlier_tie"}
		entry.append({"ref":weakref(node),"stamp":_plane_stamp(node)})
	for rank: int in [background,high,high+1,high+2,high+3]:
		if rank< -4096 or rank>4096 or rank-_canvas_z(owner)< -4096 or rank-_canvas_z(owner)>4096:return {"lost":true,"reason":"unrepresentable_owner_relative_plane"}
	for b: Dictionary in g.bindings.values():
		if not _subject(g,b):continue
		var local: int=_local_z(b.sprite.get_ref(),high+2)
		if local< -4096 or local>4096:return {"lost":true,"reason":"unrepresentable_actor_parent_relative_plane"}
	return {"lost":false,"canvas":canvas,"background":background,"band":high,"owner":_plane_stamp(owner),"field":_plane_stamp(field),"actors":actors,"entry":entry}
static func _decline_planes(g: Session,reason: String) -> void:
	if bool(g.planes.get("lost",false)):return
	g.planes.lost=true;g.declines.append({"plane_policy":"publication_declined","reason":reason})
	# Retire owned publication, not the finite source callback/barrier lifetime.
	for r: Record in g.records:
		if r.retired:continue
		var ticks: int=int(r.track.ticks);var pending: bool=r.pending
		_retire(r)
		if g.terminal or group(g.owner_ref.get_ref())!=g:return
		if r.kind!="actor_BG":r.track.ticks=ticks;r.clock_live=true;r.pending=pending
	for item: Dictionary in [g.background,g.blackout]:
		if not item.is_empty() and Owned.node(item):
			Owned.write(item,"visible",false)
			if g.terminal or group(g.owner_ref.get_ref())!=g:return
static func _planes_ready(g: Session) -> bool:
	if bool(g.planes.get("lost",false)):return false
	var owner: Node2D=g.owner_ref.get_ref();var valid: bool=_plane_stamp(owner)==g.planes.owner and _plane_stamp(g.context.field)==g.planes.field
	for b: Dictionary in g.bindings.values():
		# A retired/replaced actor cannot revoke the unaffected actors' frozen planes.
		if not b.lost and _subject(g,b):
			var sprite: Sprite2D=b.sprite.get_ref()
			if sprite.z_as_relative!=bool(b.item.plane_relative):b.item.lost.z_index=true
			valid=valid and g.planes.actors.get(b.id,[])==_plane_stamp(sprite,false)
	for entry: Dictionary in g.planes.entry:
		var node: CanvasItem=entry.ref.get_ref() as CanvasItem
		if node==null:continue
		if not node.is_inside_tree():valid=false;continue
		valid=valid and _plane_stamp(node)==entry.stamp and (_canvas_z(node)<int(g.planes.background) or _entry_before_owner(node,owner))
	if not g.background.is_empty() and not g.blackout.is_empty() and Owned.node(g.background) and Owned.node(g.blackout):valid=valid and g.background.node.get_index()<g.blackout.node.get_index()
	if not valid:_decline_planes(g,"frozen_canvas_plane_authority_lost")
	return valid
static func _write_plane(g: Session,item: Dictionary,rank: int) -> void:
	if not Owned.node(item):return
	var node: CanvasItem=item.node
	if not node.is_inside_tree():_decline_planes(g,"plane_node_outside_tree");return
	if item.has("plane_relative") and node.z_as_relative!=bool(item.plane_relative):item.lost.z_index=true;return
	var local: int=_local_z(node,rank)
	if local< -4096 or local>4096 or node.get_canvas().get_id()!=int(g.planes.canvas):
		_decline_planes(g,"unrepresentable_parent_at_Z_publication");return
	Owned.write(item,"z_index",local)
static func _headroom(g: Session) -> bool:
	var owner: Node2D = g.owner_ref.get_ref();var field: Node2D = g.context.field
	return owner.global_transform.is_finite() and field.global_transform.is_finite() and not is_zero_approx(owner.global_transform.determinant()) and not is_zero_approx(field.global_transform.determinant()) and _planes_ready(g)
static func _leaf(g: Session,n: Node2D) -> Dictionary:
	var owner: Node2D = g.owner_ref.get_ref();owner.add_child(n);g.leaves.append(weakref(n));var item: Dictionary=Owned.item(n,owner);item.plane_relative=n.z_as_relative;return item
static func _record(g: Session,kind: String,s: Dictionary,domain: String="visual") -> Record:
	var r := Record.new();r.session_ref=weakref(g);r.kind=kind
	r.track={"kind":"source_night_shade_control","settings":s.duplicate(true),"age":0,"ticks":4096,"domain":domain,"update":advance,"night_shade_record":weakref(r),"cleanup":_cleanup_record.bind(weakref(r))};g.records.append(r);return r
static func _packet(owner: Node2D,c: BattleAnimationContext,raw: Dictionary,pc: int,s: Dictionary) -> bool:
	if owner.state!="running" or owner.context!=c or owner._pc!=pc or pc<1 or pc>=owner._steps.size() or not Same._same(s,owner._steps[pc]):return false
	var label: Dictionary = owner._steps[pc-1]
	if label.get("op")!="source_label" or label.get("source_line")!=s.get("source_line"):return false
	var priority: Dictionary = BattleSourcePriority.command_metadata(label)
	if not priority.is_empty() and not Same._same(raw.get("source_command_priority"),priority):return false
	for index: int in label.get("source_args",[]).size():
		var value: Variant = owner._source_args.get(index,-1)
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value)!=floor(float(value)) or int(value)!=(int(label.source_args[index])&65535):return false
	return true
static func effect(raw: Dictionary,c: BattleAnimationContext,owner: Node2D,kind: String) -> Variant:
	if not owner is BattleAnimationSequenceRunner:return null
	var g: Session = group(owner)
	if g==null and not _body(owner.definition):return null
	if g!=null and not _identity(g):return []
	var pc: int = owner._pc
	if pc<0 or pc>=owner._steps.size() or owner._effect_dispatch_pc!=pc or not is_same(owner._effect_dispatch_step,raw):return []
	var s: Dictionary = Encoding.normalized(raw);s.erase("source_command_priority")
	if s.get("behavior")!=kind or not _packet(owner,c,raw,pc,s) or not owner.claim_effect_dispatch(raw):return []
	if g==null:
		g=_capture(owner,c)
		if not _inverse_authority(g):return []
		g.constructing=true
		var admitted: bool = _definition(owner.definition)
		g.constructing=false
		if not admitted or not _identity(g):finish(owner,"cancelled");return []
		if not _inverse_authority(g):return []
	if g.calls.has(pc):return []
	g.calls[pc]=true;g.constructing=true
	var result: Array[Dictionary] = _dispatch(g,s)
	g.constructing=false
	if not _identity(g) or not _inverse_authority(g):
		for r: Record in g.records:_retire(r)
		if group(owner)==g:finish(owner,"cancelled")
		return []
	return result
static func _dispatch(g: Session,s: Dictionary) -> Array[Dictionary]:
	var owner: Node2D = g.owner_ref.get_ref();var line: int = int(s.source_line)
	if line in [7289,7290,7301]:
		var commands: Array = owner.get_meta("source_legacy_impact_commands",[]);commands.append(line);owner.set_meta("source_legacy_impact_commands",commands)
		if line==7290:g.promoted=not g.context.contest and g.context.source_position(g.roles[0]) in [0,3]
		elif line==7301:
			for r: Record in g.records:
				if r.kind=="actor_BG" and not r.retired:_restore(g,g.bindings[r.actor_id],["visible"]);r.state.clear=2;r.pending=true
		else:return _map(g,s)
		return []
	if line in [7292,7303]:return _background(g,s)
	var r: Record = _record(g,"ghost" if line==7296 else "shake" if line==7298 else "palette",s)
	r.actor_id=g.roles[0] if line==7296 else g.roles[1][0] if not g.roles[1].is_empty() else -1
	var b: Dictionary = _binding(g,r.actor_id)
	if line==7296:r.state=State.ghost_new()
	elif line==7298:r.state=State.shake_new()
	else:r.state=State.target_palette_new(g.context.source_position(r.actor_id)) if not b.is_empty() else {"live":false}
	if not b.is_empty() and _headroom(g):
		_actor_art(g,b)
		if r.kind=="ghost" and b.entry.visible:
			Owned.write(b.item,"visible",true);_write_plane(g,b.item,g.band+2)
			if not b.art_lost and _compatible(b):
				r.item=b.item;Owned.attach_material(r.item,AB)
				var copy := BackBufferCopy.new();copy.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT;r.pair=_leaf(g,copy)
				_write_plane(g,r.pair,g.band+1)
				_publish_alpha(r,b)
			else:g.declines.append({"line":line,"reason":"ART_input_lost" if b.art_lost else "foreign_material_AB_declined"})
		elif r.kind=="palette" and not b.art_lost and _compatible(b):
			r.input=Owned.image_input(b.texture)
			if not r.input.is_empty():
				# Sprite Atlas/region/frame UVs address the original leaf, not a cropped view.
				r.image=r.input.leaf.get_image().duplicate();r.image.convert(Image.FORMAT_RGBA8)
				r.indexed=b.texture is CompressedTexture2D and b.texture.resource_path.begins_with("res://graficos/pokemon/") and ResourceLoader.load(b.texture.resource_path)==b.texture
				r.item=b.item;Owned.attach_material(r.item,Palette)
		_publish(r)
	return [r.track]
static func _compatible(b: Dictionary) -> bool:
	var material: Material = b.entry.material
	if b.actor.sprite.material!=material:return false
	if material is ShaderMaterial:
		if material.shader!=b.shader:return false
		for key: String in b.uniforms:
			if material.get_shader_parameter(key)!=b.uniforms[key]:return false
	if material==null:return true
	# Known ordinary palette material only; unknown effects retain their own pixels.
	if not material is ShaderMaterial or material.shader==null:return false
	if material.shader.resource_path=="res://escenas/batalla/pokemon_battle.gdshader":
		for key: String in ["efecto_silueta","efecto_parpadeo","efecto_brillo","efecto_desvanecimiento","efecto_contorno","efecto_monocromo"]:
			if material.get_shader_parameter(key)!=false:return false
		return true
	if material.shader.resource_path!="res://scripts/battle/animations/sequence/palette_blend.gdshader":return false
	for key: String in ["source_recolor","grayscale","invert"]:
		if material.get_shader_parameter(key)==true:return false
	return is_zero_approx(float(material.get_shader_parameter("blend_amount"))) and is_zero_approx(float(material.get_shader_parameter("wave_amplitude")))
static func _map(g: Session,s: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for actor: BattleAnimationActor in Owned.source_bg_members(g.context,0):
		var b: Dictionary = _binding(g,actor.id)
		if b.is_empty() or not _headroom(g):continue
		var r: Record = _record(g,"actor_BG",s,"maintenance");r.pending=false;r.actor_id=actor.id;r.item=_leaf(g,Sprite2D.new());r.state={"clear":0}
		r.track.clones=[{"actor":actor,"node":r.item.node,"bg_plane":1 if g.context.contest or g.context.source_position(actor.id) in [1,2] else 2}]
		if not _identity(g) or _binding(g,actor.id).is_empty():_retire(r);continue
		Owned.write(b.item,"visible",false);_publish(r);result.append(r.track)
	return result
static func _background(g: Session,s: Dictionary) -> Array[Dictionary]:
	var r: Record = _record(g,"restore" if int(s.source_line)==7303 else "background",s,"background");r.state=State.background_new();r.input=Owned.image_input(_texture(s))
	if g.background.is_empty() and _headroom(g):
		var n := Sprite2D.new();n.centered=false;n.region_enabled=true;n.region_rect=Rect2(0,0,240,160);n.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED;n.visible=false
		g.background=_leaf(g,n)
		var black := Polygon2D.new();black.polygon=PackedVector2Array([Vector2.ZERO,Vector2(240,0),Vector2(240,160),Vector2(0,160)]);black.color=Color(0,0,0,0);g.blackout=_leaf(g,black)
		g.declines.append({"background_policy":"entry_scene_untouched_overlay_restore","fallback":"transparent_entry_when_no_scene_background"})
	if r.kind=="background" and not g.background.is_empty():Owned.write(g.background,"texture",_texture(s))
	return [r.track]

# Native E/P: begin advances old tasks once; after_pose advances only new pending
# constructors once. Generic track updates never advance source clocks a second time.
static func begin_tick(owner: Node2D,_c: BattleAnimationContext) -> void:
	var g: Session = group(owner)
	if g==null:return
	if not _identity(g):finish(owner,"cancelled");return
	for v: Owned.Voice in g.voices:v.owns()
	for r: Record in g.records:
		if (not r.retired or r.clock_live) and not r.pending:_pulse(r)
static func after_pose(owner: Node2D,c: BattleAnimationContext) -> void:
	var g: Session = group(owner)
	if g==null or not _identity(g) or c!=g.context:return
	for r: Record in g.records:
		if r.retired and not r.clock_live:continue
		if r.pending:r.pending=false;_pulse(r)
		_publish(r)
	# Session.records is live ownership, not a history of removed runner tracks.
	g.records=g.records.filter(func(r: Record)->bool:return not r.retired or r.clock_live)
static func advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	var reference: Variant = t.get("night_shade_record")
	var r: Record = reference.get_ref() as Record if reference is WeakRef else null
	if r==null:return
	var g: Session = r.session_ref.get_ref() as Session
	var owner: Variant = g.owner_ref.get_ref() if g!=null else null
	if not is_instance_valid(owner) or not _identity(g) or not is_same(t,r.track) or not is_same(owner._i161_control_callback_track,t) or not owner._tracks.any(func(current: Dictionary)->bool:return is_same(t,current)):return
	r.published_age=int(t.age);_publish(r)
static func _pulse(r: Record) -> void:
	if r.retired and not r.clock_live:return
	match r.kind:
		"ghost":State.ghost_callback(r.state)
		"shake":State.shake_callback(r.state)
		"palette":State.target_palette_update(r.state);State.target_palette_callback(r.state)
		"background","restore":State.background_palette_update(r.state);State.background_callback(r.state);State.background_vblank(r.state)
		"actor_BG":
			if r.state.clear>0:
				r.state.clear-=1
				if r.state.clear==0:_retire(r)
	_publish(r)
	if r.state.get("done",false) or not r.state.get("live",true):
		if r.clock_live:r.clock_live=false;r.track.ticks=int(r.track.age)
		_retire(r)
static func _body_point(g: Session,b: Dictionary) -> Vector2:
	if not _inverse_authority(g,b.parent.get_ref() as Node2D):return Vector2.INF
	var value: Dictionary = Coordinates.visual(b.actor,g.context)
	if value.state=="valid":return value.point
	if value.state=="invalid":return Vector2.INF
	g.declines.append({"actor":b.actor.id,"reason":"missing_BODY_anchor_fallback"})
	return b.actor.anchor(g.context.field)
static func _pose(g: Session,b: Dictionary,factor: float,offset: Vector2=Vector2.ZERO) -> void:
	if not _inverse_authority(g,b.parent.get_ref() as Node2D) or not _headroom(g):return
	var body: Vector2 = _body_point(g,b)
	if not body.is_finite() or not _inverse_authority(g,b.parent.get_ref() as Node2D):return
	var base: Transform2D = g.context.field.global_transform.affine_inverse()*b.parent.get_ref().global_transform*b.art
	# Layout motion is additive in the source parent's coordinates; intrinsic ART
	# basis is frozen independently from our affine write and provider BODY.
	var parent: Node2D = b.parent.get_ref()
	base.origin=g.context.field.to_local(parent.to_global(b.position))
	var magnify := Transform2D(Vector2(factor,0),Vector2(0,factor),body*(1.0-factor)+offset)
	var local: Transform2D = parent.global_transform.affine_inverse()*g.context.field.global_transform*magnify*base
	Owned.pose(b.item,local)
static func _publish_alpha(r: Record,b: Dictionary) -> void:
	if r.item.is_empty() or not r.item.active:return
	var g: Session = r.session_ref.get_ref() as Session
	if g==null or not _subject(g,b):_release_actor_material(r);return
	if not Owned.node(r.pair):_release_actor_material(r);return
	for key: String in ["copy_mode","rect","z_index"]:Owned.write(r.pair,key,r.pair.writes[key])
	if not r.pair.lost.is_empty():_release_actor_material(r);return
	var sprite: Sprite2D = b.sprite.get_ref()
	var tint: Color = sprite.modulate*sprite.self_modulate;var parent: CanvasItem = sprite.get_parent() as CanvasItem
	while parent!=null:
		tint*=parent.modulate;parent=parent.get_parent() as CanvasItem
	Owned.uniform(r.item,"eva",float(r.state.eva)/16.0);Owned.uniform(r.item,"evb",float(r.state.evb)/16.0);Owned.uniform(r.item,"first_tint",Vector3(tint.r,tint.g,tint.b))
static func _publish(r: Record) -> void:
	if r.retired:return
	var g: Session = r.session_ref.get_ref() as Session
	if g==null or not _identity(g) or not _inverse_authority(g) or not _planes_ready(g):return
	if r.kind in ["background","restore"]:
		if not Owned.image_input_valid(r.input):
			# Retire only publication. Source task/barrier and unrelated audio keep running.
			r.retired=true;r.clock_live=true
			if not g.background.is_empty():
				Owned.write(g.background,"visible",false);Owned.write(g.background,"texture",null)
			if not g.blackout.is_empty():Owned.write(g.blackout,"color",Color(0,0,0,0))
			return
		if g.background.is_empty() or not _headroom(g):return
		var background_pose: Variant=_projection(g)
		if not background_pose is Transform2D:return
		Owned.pose(g.background,background_pose)
		var blackout_pose: Variant=_projection(g)
		if not blackout_pose is Transform2D:return
		Owned.pose(g.blackout,blackout_pose)
		Owned.write(g.background,"visible",not r.state.swapped if r.kind=="restore" else r.state.swapped)
		_write_plane(g,g.background,int(g.planes.background));_write_plane(g,g.blackout,int(g.planes.background));Owned.write(g.blackout,"color",Color(0,0,0,float(r.state.bldy)/16.0));return
	var b: Dictionary = _binding(g,r.actor_id)
	if b.is_empty():_retire(r);return
	_actor_art(g,b)
	if r.retired:return
	if r.kind=="actor_BG":
		for key: String in Owned.FOLLOW:Owned.write(r.item,key,b.entry.material if key=="material" else b.actor.sprite.get(key))
		if not _inverse_authority(g,b.parent.get_ref() as Node2D):return
		var transform: Transform2D = g.context.field.global_transform.affine_inverse()*b.parent.get_ref().global_transform*b.art
		var projection: Variant=_projection(g)
		if not projection is Transform2D:return
		Owned.pose(r.item,projection*transform);Owned.write(r.item,"visible",bool(b.entry.visible) and b.actor.sprite.get_parent().is_visible_in_tree())
		var plane: int = r.track.clones[0].bg_plane
		_write_plane(g,r.item,g.band+(3 if plane==1 and g.promoted else 1 if plane==1 else 0));return
	if r.kind=="ghost":
		if b.entry.visible and r.state.live:_pose(g,b,256.0/float(r.state.matrix));_publish_alpha(r,b)
	elif r.kind=="shake":_pose(g,b,1.0,Vector2(r.state.x2,0))
	elif r.kind=="palette" and not r.item.is_empty():
		if not Owned.image_input_valid(r.input) or not Owned.observe_material(r.item) or not r.item.revoked.is_empty():_release_actor_material(r);r.item={};return
		if r.texture!=null and r.texture.get_image().get_data()!=r.bytes:_release_actor_material(r);r.item={};return
		if r.coefficient!=int(r.state.amount):
			r.coefficient=int(r.state.amount);r.prepared_image=r.image.duplicate()
			for y: int in r.image.get_height():
				for x: int in r.image.get_width():
					var pixel: Color = r.image.get_pixel(x,y)
					if r.indexed:pixel=Color8(State.black_rgb5(pixel.r8>>3,r.coefficient)*255/31,State.black_rgb5(pixel.g8>>3,r.coefficient)*255/31,State.black_rgb5(pixel.b8>>3,r.coefficient)*255/31,pixel.a8)
					else:pixel=Color8(roundi(pixel.r8*(1.0-r.coefficient/16.0)),roundi(pixel.g8*(1.0-r.coefficient/16.0)),roundi(pixel.b8*(1.0-r.coefficient/16.0)),pixel.a8)
					r.prepared_image.set_pixel(x,y,pixel)
			if r.texture==null:r.texture=ImageTexture.create_from_image(r.prepared_image)
			else:r.texture.update(r.prepared_image)
			r.bytes=r.texture.get_image().get_data();Owned.uniform(r.item,"palette_texture",r.texture)
static func _release_actor_material(r: Record) -> void:
	if r.item.is_empty():return
	var g: Session = r.session_ref.get_ref() as Session
	var b: Dictionary = g.bindings.get(r.actor_id,{}) if g!=null else {}
	# A surviving Node/material is not proof of the original visual occupant.
	# Abandon permanently on generation/slot/wrapper/successor loss: no writes.
	if b.is_empty() or b.lost or not _subject(g,b):
		r.item.active=false;r.item.lost_material=true;return
	Owned.release_material(r.item)
static func _retire(r: Record) -> void:
	if r.retired:return
	r.retired=true;r.pending=false;r.track.ticks=int(r.track.age)
	var g: Session = r.session_ref.get_ref() as Session
	if g==null:return
	var b: Dictionary = g.bindings.get(r.actor_id,{})
	if not b.is_empty():
		if r.kind=="actor_BG":_restore(g,b,["visible"])
		elif r.kind in ["ghost","shake"]:_restore(g,b,["position","rotation","scale","skew","z_index"])
	if r.kind in ["ghost","palette"] and not r.item.is_empty():_release_actor_material(r)
	if r.kind=="restore" and not g.blackout.is_empty():Owned.write(g.blackout,"color",Color(0,0,0,0))
	for item: Dictionary in [r.item if r.kind=="actor_BG" else {},r.pair]:
		if not item.is_empty() and Owned.node(item):
			if item.node is Sprite2D:Owned.write(item,"texture",null)
			elif item.node is BackBufferCopy:Owned.write(item,"copy_mode",BackBufferCopy.COPY_MODE_DISABLED)
			if item.node.get_child_count(true)==0:item.node.queue_free()
static func _cleanup_record(reference: WeakRef) -> void:
	var r: Record = reference.get_ref() as Record
	if r!=null:_retire(r)
static func actor_allowed(owner: Node2D,_actor: BattleAnimationActor) -> bool:return group(owner)==null
static func finish_context_loss(owner: Node2D) -> bool:
	var g: Session = group(owner)
	if g!=null:
		if not _identity(g):return finish(owner,"cancelled")
		return not _inverse_authority(g)
	# Runner calls this before its first effect OR sound. Capture only safe
	# inverse-free receipts so entry loss uses the same sticky terminal drain.
	if owner.definition!=null and _body(owner.definition) and owner.context!=null and is_instance_valid(owner.context.field) and not _world_invertible(owner,owner.context.field):
		g=_capture(owner,owner.context)
		return not _inverse_authority(g)
	return false
static func note_sound(owner: Node2D,player: AudioStreamPlayer2D) -> void:
	var g: Session = group(owner)
	if g!=null:g.voices.append(Owned.voice(owner,player))
static func audio_allowed(owner: Node2D,player: AudioStreamPlayer2D) -> bool:
	var g: Session = group(owner)
	if g==null:return true
	for voice: Owned.Voice in g.voices:
		if voice.player_ref.get_ref()==player:return voice.owns()
	return false
static func note_audio_write(owner: Node2D,player: AudioStreamPlayer2D) -> void:
	var g: Session = group(owner)
	if g!=null:
		for voice: Owned.Voice in g.voices:
			if voice.player_ref.get_ref()==player:voice.note_write()
static func audio_playing(owner: Node2D) -> bool:
	var g: Session = group(owner)
	if g!=null:
		for voice: Owned.Voice in g.voices:
			if voice.owns() and voice.player_ref.get_ref().playing:return true
	return false
static func finish(owner: Node2D,state: String) -> bool:
	var g: Session = group(owner)
	if g==null:return false
	if g.terminal:return true
	g.terminal=true;owner.state=state;owner.set_process(false)
	var sweep: Owned.LeafSweep = Owned.leaf_sweep(owner)
	for r: Record in g.records:_retire(r)
	for b: Dictionary in g.bindings.values():_restore(g,b,["visible","position","rotation","scale","skew","z_index"])
	for item: Dictionary in [g.background,g.blackout]:
		if not item.is_empty() and Owned.node(item):
			if item.node is Sprite2D:Owned.write(item,"texture",null)
			elif item.node is Polygon2D:Owned.write(item,"polygon",PackedVector2Array())
	for reference: WeakRef in g.leaves:
		var candidate: Variant = reference.get_ref()
		if is_instance_valid(candidate):sweep.enroll(candidate)
	for voice: Owned.Voice in g.voices:
		if voice.owns(state=="cancelled" and owner.lifecycle_aborted):
			var player: AudioStreamPlayer2D = voice.player_ref.get_ref();player.stop();sweep.enroll(player)
	owner._tracks.clear();owner._sounds.clear();owner.remove_meta(STATE);owner.set_meta("source_night_shade_terminal",sweep)
	owner.terminated.emit(state)
	owner.definition=null;owner.context=null;owner._steps.clear();owner._factories={};g.records.clear();g.bindings.clear();g.voices.clear();sweep.changed();return true

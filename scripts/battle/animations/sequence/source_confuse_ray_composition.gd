extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Finite109 glue: source state is pure; leases/transforms/audio are shared mechanics.
const State = preload("res://scripts/battle/animations/sequence/source_confuse_ray_state.gd")
const Owned = preload("res://scripts/battle/animations/sequence/source_owned_composition.gd")
const Coordinates = preload("res://scripts/battle/animations/sequence/source_coordinate_contract.gd")
const Same = preload("res://scripts/battle/animations/sequence/source_cutting_slice.gd")
const AB = preload("res://scripts/battle/animations/sequence/source_local_ab.gdshader")
const Commands = preload("res://scripts/battle/animations/sequence/source_command_program.gd")
const STATE := "source_confuse_ray_session"
static var _validating: Dictionary = {}

class Session extends RefCounted:
	var owner_ref: WeakRef
	var parent_ref: WeakRef
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
	var coefficient := 0
	var pan := -64
	var pan_start := -64
	var pan_end := 63
	var background_lost := false
	var fade: Dictionary = {"mode":"idle","toggle":0,"active":false}
	var background: Dictionary = {}
	var blackout: Dictionary = {}
	var alpha := Vector2i(16,0)
	var terminal := false
	var constructing := false

class Record extends RefCounted:
	var session_ref: WeakRef
	var track: Dictionary
	var kind := ""
	var age := 0
	var actor_id := -1
	var node: Sprite2D
	var item: Dictionary = {}
	var pair: Dictionary = {}
	var state: Dictionary = {}
	var input: Dictionary = {}
	var image: Image
	var prepared_image: Image # Actual CPU argument retained for bounded publication measurement.
	var texture: ImageTexture
	var coefficient := -1
	var color := Color.WHITE
	var default_art := false
	var presentation_lost := false
	var palette_lost := false
	var output_bytes: PackedByteArray = []
	var retired := false
	var published_age := 0

static func group(owner: Node2D) -> Session:return owner.get_meta(STATE) as Session if is_instance_valid(owner) and owner.has_meta(STATE) else null
static func _texture(s: Dictionary) -> Texture2D:
	var value: Variant = s.get("texture")
	if value is Texture2D:return value
	return load(value) as Texture2D if value is String and ResourceLoader.exists(value) else null
static func _art(s: Dictionary) -> Dictionary:
	var input: Dictionary = Owned.image_input(_texture(s))
	if input.is_empty():return {}
	var factor: Variant = s.get("scale_factor",1.0)
	if typeof(factor) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(factor)) or float(factor)<=0 or not (Vector2.ONE*float(factor)).is_finite() or (Vector2.ONE*float(factor)).is_zero_approx():return {}
	for name: String in ["flip_h","flip_v","recolor"]:
		if s.has(name) and typeof(s[name])!=TYPE_BOOL:return {}
	if s.has("color") and (not s.color is String or not Color.html_is_valid(s.color)):return {}
	if int(s.source_line) in [2053,2066]:return input
	var frames: Variant = s.get("frame_rects",{"0":[0,0,16,16]})
	if not frames is Dictionary or frames.size()!=1 or not frames.has("0") or not frames["0"] is Array or frames["0"].size()!=4:return {}
	var rect: Array = frames["0"]
	for value: Variant in rect:
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value)!=floor(float(value)):return {}
	if rect[0]<0 or rect[1]<0 or rect[2]<=0 or rect[3]<=0 or rect[0]+rect[2]>input.image.get_width() or rect[1]+rect[3]>input.image.get_height():return {}
	input.frame = input.image.get_region(Rect2i(rect[0],rect[1],rect[2],rect[3]));return input
static func _definition(d: BattleAnimationDefinition) -> bool:
	if not State.body(d) or _validating.has(d.get_instance_id()):return false
	_validating[d.get_instance_id()]=true
	var before: Array = d.steps.duplicate(true);var valid := true
	for s: Dictionary in d.steps:
		if s.get("op")=="effect" and int(s.get("source_line",-1)) in [2053,2057,2061,2066] and _art(s).is_empty():valid=false;break
	valid = valid and State.body(d) and Same._same(before,d.steps)
	_validating.erase(d.get_instance_id());return valid
static func accepts_texture_dependency(d: BattleAnimationDefinition,s: Dictionary) -> bool:
	if not _definition(d):return false
	for entry: Dictionary in d.steps:
		if is_same(entry,s):return entry.get("op")=="effect" and int(entry.get("source_line",-1)) in [2053,2057,2061,2066]
	return false

static func _capture(owner: Node2D,c: BattleAnimationContext) -> Session:
	var g := Session.new();g.owner_ref=weakref(owner);g.parent_ref=weakref(owner.get_parent());g.context=c;g.definition=owner.definition;g.program=owner._steps.duplicate(true);g.roles=[c.attacker_id,c.target_ids.duplicate(),c.source_positions.duplicate(),c.contest]
	for actor: BattleAnimationActor in c.actors.values():
		var provider: Variant = c.source_visual.get(actor.id);var nominal: Variant = c.source_nominal.get(actor.id)
		var source: Sprite2D = actor.sprite
		g.bindings[actor.id] = {"actor":actor,"sprite":weakref(source),"parent":weakref(source.get_parent()),"provider":provider,"nominal":nominal,"provider_copy":provider.duplicate(true) if provider is Dictionary else provider,"nominal_copy":nominal.duplicate(true) if nominal is Dictionary else nominal,"material":source.material,"shader":source.material.shader if source.material is ShaderMaterial else null,"uniforms":{},"visible":source.visible,"hide_owned":false,"hide_expected":source.visible,"hide_lost":false,"lost":false}
		if source.material is ShaderMaterial and source.material.shader!=null:
			for key: String in ["blend_color","blend_amount","grayscale","invert"]:
				if source.material.shader.get_shader_uniform_list().any(func(p: Dictionary)->bool:return str(p.name)==key):g.bindings[actor.id].uniforms[key]=source.material.get_shader_parameter(key)
	if c.actors.has(c.attacker_id) and not c.resolve("target").is_empty():
		g.pan_start=BattleCounterSelected.adjust_panning(-64,c);g.pan_end=BattleCounterSelected.adjust_panning(63,c)
	owner.set_meta(STATE,g);return g
static func _identity(g: Session) -> bool:
	var owner: Variant = g.owner_ref.get_ref()
	return not g.terminal and is_instance_valid(owner) and owner.state=="running" and owner.context==g.context and owner.definition==g.definition and owner.get_parent()==g.parent_ref.get_ref() and BattleAnimationSequenceRegistry.is_builtin_source_definition(g.definition) and Same._same(g.program,g.definition.steps) and Same._same(g.program,owner._steps) and is_instance_valid(g.context.field) and g.context.field.is_inside_tree()
static func _subject(g: Session,b: Dictionary) -> bool:
	var sprite: Variant = b.sprite.get_ref()
	return g.context.actors.get(b.actor.id)==b.actor and is_instance_valid(sprite) and b.actor.sprite==sprite and sprite.get_parent()==b.parent.get_ref() and b.actor.is_present() and not g.context.actors.values().any(func(a: BattleAnimationActor)->bool:return a!=b.actor and a.sprite==sprite)
static func _hide(g: Session,b: Dictionary,hidden: bool) -> void:
	if not _subject(g,b):return
	var source: Sprite2D = b.sprite.get_ref()
	if b.hide_owned and source.visible!=b.hide_expected:b.hide_lost=true
	if b.hide_lost:return
	if hidden:b.hide_owned=true;source.visible=false;b.hide_expected=source.visible
	elif b.hide_owned:source.visible=b.visible;b.hide_expected=source.visible;b.hide_owned=false
static func _binding(g: Session,id: int) -> Dictionary:
	var b: Dictionary = g.bindings.get(id,{})
	if b.is_empty() or b.lost:return {}
	var c: BattleAnimationContext = g.context
	var valid: bool = _subject(g,b) and is_same(c.source_visual.get(id),b.provider) and is_same(c.source_nominal.get(id),b.nominal) and Same._same(b.provider,b.provider_copy) and Same._same(b.nominal,b.nominal_copy)
	valid = valid and c.source_positions.get(id)==g.roles[2].get(id) and c.contest==g.roles[3]
	if id==int(g.roles[0]):valid = valid and c.attacker_id==id
	if id in g.roles[1]:valid = valid and c.target_ids==g.roles[1]
	valid = valid and Coordinates.visual(b.actor,c).state!="invalid" and Coordinates.nominal(b.actor,c).state!="invalid"
	if not valid:b.lost=true;_hide(g,b,false);return {}
	return b
static func _point(g: Session,id: int,nominal: bool=false) -> Vector2:
	var b: Dictionary = _binding(g,id)
	if b.is_empty():return Vector2.INF
	var value: Dictionary = Coordinates.nominal(b.actor,g.context) if nominal else Coordinates.visual(b.actor,g.context)
	if value.state=="valid":return value.point
	g.declines.append({"actor":id,"state":"legacy_missing","domain":"nominal" if nominal else "BODY"})
	return b.actor.anchor(g.context.field)
static func _projection(g: Session) -> Transform2D:
	var owner: Node2D = g.owner_ref.get_ref()
	if not owner.global_transform.is_finite() or is_zero_approx(owner.global_transform.determinant()):return Transform2D(Vector2.ZERO,Vector2.ZERO,Vector2.ZERO)
	return owner.global_transform.affine_inverse()*g.context.field.global_transform
static func _layer(g: Session,offset: int) -> int:
	return BattleSourcePriority.effective_layer(g.context.field)-BattleSourcePriority.effective_layer(g.owner_ref.get_ref())+offset
static func _headroom(g: Session) -> bool:
	var projection: Transform2D = _projection(g)
	return projection.is_finite() and not is_zero_approx(projection.determinant()) and _layer(g,1)>=-4096 and _layer(g,97)<=4096
static func _record(g: Session,kind: String,s: Dictionary,duration: int,domain: String="visual") -> Record:
	var r := Record.new();r.session_ref=weakref(g);r.kind=kind
	r.track={"kind":"source_confuse_control","settings":s.duplicate(true),"age":0,"ticks":duration,"domain":domain,"update":advance,"confuse_record":weakref(r),"cleanup":_cleanup_record.bind(weakref(r))};g.records.append(r);return r
static func _leaf(g: Session,node: Node2D) -> Dictionary:
	var owner: Node2D = g.owner_ref.get_ref();owner.add_child(node);g.leaves.append(weakref(node));return Owned.item(node,owner)

static func tick_allowed(owner: Node2D) -> bool:
	var g: Session = group(owner)
	return (g==null or not g.constructing) and (owner.definition==null or not _validating.has(owner.definition.get_instance_id()))
static func _packet(owner: Node2D,c: BattleAnimationContext,raw: Dictionary,pc: int,snapshot: Dictionary) -> bool:
	if owner.state!="running" or owner.context!=c or owner._pc!=pc or pc>=owner._steps.size():return false
	var current: Dictionary = State.normalized(raw);current.erase("source_command_priority")
	if not Same._same(current,snapshot) or not Same._same(snapshot,owner._steps[pc]):return false
	var label: Dictionary = owner._steps[pc-1] if pc>0 else {}
	var expected_priority: Dictionary = BattleSourcePriority.command_metadata(label)
	if not expected_priority.is_empty() and not Same._same(raw.get("source_command_priority"),expected_priority):return false
	var args: Array = label.get("source_args",[])
	for index: int in args.size():
		var actual: Variant = owner._source_args.get(index,-1)
		if typeof(actual) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(actual)) or float(actual)!=floor(float(actual)) or int(actual)!=(int(args[index])&65535):return false
	return true
static func effect(raw: Dictionary,c: BattleAnimationContext,owner: Node2D,kind: String) -> Variant:
	if not owner is BattleAnimationSequenceRunner:return null
	var g: Session = group(owner)
	if g==null and not State.body(owner.definition):return null
	if g!=null and not _identity(g):return []
	var pc: int = owner._pc
	if pc<0 or pc>=owner._steps.size() or owner._effect_dispatch_pc!=pc or not is_same(owner._effect_dispatch_step,raw):return []
	var s: Dictionary = State.normalized(raw);var priority: Variant = s.get("source_command_priority")
	if priority!=null:
		if pc<1 or not Same._same(priority,BattleSourcePriority.command_metadata(owner._steps[pc-1])):return []
		s.erase("source_command_priority")
	if not Same._same(s,owner._steps[pc]) or str(s.get("behavior",""))!=kind:return []
	if not _packet(owner,c,raw,pc,s) or not owner.claim_effect_dispatch(raw):return [] # Consume BEFORE getters/reentry.
	var first: bool = g==null
	if first:g=_capture(owner,c)
	if g.calls.has(pc):return []
	g.calls[pc]=true;g.constructing=true
	var eligible: bool = not first or _definition(owner.definition)
	g.constructing=false
	if not _identity(g) or not _packet(owner,c,raw,pc,s):return []
	if not eligible:
		var literal: bool = not owner.definition.steps.any(func(entry: Dictionary)->bool:return entry.get("texture") is Texture2D)
		for id: int in g.bindings:
			if _binding(g,id).is_empty():literal=false
		owner.remove_meta(STATE)
		return null if literal else []
	g.constructing=true
	var result: Array[Dictionary] = _dispatch(g,s)
	g.constructing=false
	return result
static func _dispatch(g: Session,s: Dictionary) -> Array[Dictionary]:
	var line: int = int(s.source_line)
	if line in [2052,2059,2064,2065]:return _command(g,s)
	if line in [2053,2066]:return _background(g,s)
	if line in [2055,2056]:
		var r: Record = _record(g,"pan" if line==2055 else "palette",s,maxi(0,ceili(absf(float(g.pan_end-g.pan_start))/2.0)-1) if line==2055 else 120)
		if line==2055:g.pan=clampi(g.pan_start+signi(g.pan_end-g.pan_start)*2,mini(g.pan_start,g.pan_end),maxi(g.pan_start,g.pan_end))
		else:g.coefficient=0;g.fade={"mode":"normal","toggle":1,"active":true,"coefficient":0}
		return [r.track]
	return _particle(g,s) if line in [2057,2061] else []

static func _command(g: Session,s: Dictionary) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	match str(s.mode):
		"setalpha":g.alpha=Vector2i(8,8)
		"blendoff":g.alpha=Vector2i(16,0)
		"clearmonbg":
			for r: Record in g.records:
				if r.kind=="actor_BG" and not r.retired:_hide(g,g.bindings[r.actor_id],false);r.track.ticks=int(r.track.age)+2
		"monbg":
			for actor: BattleAnimationActor in Owned.source_bg_members(g.context,3):
				var b: Dictionary = _binding(g,actor.id)
				if b.is_empty() or not _borrowed_material(b) or not _headroom(g):continue
				var r: Record = _record(g,"actor_BG",s,4096,"maintenance");r.actor_id=actor.id;r.node=Sprite2D.new();r.item=_leaf(g,r.node);r.track.node=r.node
				r.track.clones=[{"node":r.node,"actor":actor,"bg_plane":1 if actor.side==1 else 2}]
				if not _identity(g) or _binding(g,actor.id).is_empty():_retire(r);continue
				_hide(g,b,true);_publish(r);output.append(r.track)
	return output
static func _borrowed_material(b: Dictionary) -> bool:
	var source: Sprite2D = b.sprite.get_ref()
	if source.material!=b.material:return false
	if source.material is ShaderMaterial:
		if source.material.shader!=b.shader or (b.shader!=null and b.shader.code.contains("hint_screen_texture")):return false
		for key: String in b.uniforms:
			if source.material.get_shader_parameter(key)!=b.uniforms[key]:return false
	return true
static func _background(g: Session,s: Dictionary) -> Array[Dictionary]:
	var restore: bool = int(s.source_line)==2066
	var r: Record = _record(g,"restore" if restore else "background",s,36,"background")
	if g.background.is_empty() and _headroom(g):
		var node := Sprite2D.new();node.centered=false;node.texture=_texture(s);node.region_enabled=true;node.region_rect=Rect2(0,0,240,160);node.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
		g.background=_leaf(g,node)
		var black := Polygon2D.new();black.polygon=PackedVector2Array([Vector2.ZERO,Vector2(240,0),Vector2(240,160),Vector2(0,160)]);black.color=Color(0,0,0,0);g.blackout=_leaf(g,black)
	r.node=g.background.get("node");_publish(r);return [r.track]
static func _virtual(g: Session,s: Dictionary,ball: bool) -> Array[Dictionary]:
	return [{"kind":"source_confuse_virtual","owner_ref":g.owner_ref,"settings":s.duplicate(true),"age":0,"ticks":576 if ball else 60,"clock":State.translation(Vector2.ZERO,Vector2.ZERO) if ball else {},"update":_advance_virtual}]
static func _advance_virtual(t: Dictionary,_c: BattleAnimationContext) -> void:
	var owner: Variant = t.owner_ref.get_ref()
	if not is_instance_valid(owner) or not is_same(owner._i161_control_callback_track,t) or not owner._tracks.any(func(current: Dictionary)->bool:return is_same(current,t)):return
	if t.clock.is_empty():return
	State.ball(t.clock)
	if t.clock.phase=="dead":t.ticks=t.age
static func _particle(g: Session,s: Dictionary) -> Array[Dictionary]:
	var ball: bool = int(s.source_line)==2057;var a: int = g.roles[0];var target: int = g.roles[1][0] if not g.roles[1].is_empty() else -1
	var start: Vector2 = _point(g,a);var finish: Vector2 = _point(g,target)
	var nominal_a: Vector2 = _point(g,a,true);var nominal_b: Vector2 = _point(g,target,true)
	var source_actor: BattleAnimationActor = g.bindings.get(a,{}).get("actor") as BattleAnimationActor
	var direction: int = 1 if nominal_a.x<nominal_b.x else -1 if nominal_a.x>nominal_b.x else (1 if is_instance_valid(source_actor) and source_actor.side==0 else -1)
	var state: Dictionary = State.translation(start+Vector2(28*direction,0),finish) if ball else {"valid":finish.is_finite() and maxf(absf(finish.x),absf(finish.y-16))<=1048576.0,"base":finish+Vector2(0,-16)}
	if not state.valid or not nominal_a.is_finite() or not nominal_b.is_finite() or not _headroom(g):
		g.declines.append({"line":s.source_line,"reason":state.get("reason","invalid_binding_or_range")});return _virtual(g,s,ball)
	var input: Dictionary = _art(s)
	if input.is_empty() or not _identity(g) or _binding(g,target).is_empty() or _binding(g,a).is_empty():return _virtual(g,s,ball)
	var r: Record = _record(g,"ball" if ball else "orbit",s,576 if ball else 60);r.actor_id=target;r.state=state;r.input=input;r.image=input.frame
	r.color=Color(str(s.get("color","ffffff")));r.default_art=s.get("texture") is String and s.get("texture")=="res://graficos/batalla/animaciones/yellow_ball_pal_13_16x16_0.png" and not s.has("color") and not bool(s.get("recolor",false))
	r.node=Sprite2D.new();r.node.flip_h=bool(s.get("flip_h",false));r.node.flip_v=bool(s.get("flip_v",false));r.item=_leaf(g,r.node);r.track.node=r.node
	var copy := BackBufferCopy.new();copy.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT;r.pair=_leaf(g,copy)
	var owner: Node2D = g.owner_ref.get_ref();owner.move_child(copy,r.node.get_index())
	Owned.attach_material(r.item,AB)
	r.track.source_oam_priority=2 if ball else 1;r.track.source_oam_subpriority=maxi(3,BattleElectricContract.source_subpriority(g.bindings[a].actor,g.context)-2)
	_publish(r);return [r.track]

static func begin_tick(owner: Node2D,_c: BattleAnimationContext) -> void:
	var g: Session = group(owner)
	if g==null:return
	if not _identity(g):finish(owner,"cancelled");return
	for voice: Owned.Voice in g.voices:voice.owns() # Observe foreign loss on genuine steps even with manual stepping.
	# Existing sprites first, one local fade/transfer pulse, then source tasks.
	for r: Record in g.records:
		if r.retired:continue
		r.age+=1
		if r.kind=="ball":State.ball(r.state)
	for r: Record in g.records:
		if r.retired:continue
		if r.kind=="palette":
			g.coefficient=State.normal(r.age);g.fade={"mode":"normal","toggle":(r.age+1)%2,"active":r.age<120,"coefficient":g.coefficient}
		elif r.kind in ["background","restore"]:
			g.fade=State.hardware(r.age);g.fade.mode="hardware"
		elif r.kind=="pan":g.pan=clampi(g.pan_start+signi(g.pan_end-g.pan_start)*2*(r.age+1),mini(g.pan_start,g.pan_end),maxi(g.pan_start,g.pan_end))
static func advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	var r: Record = t.confuse_record.get_ref() as Record
	if r==null:return
	var g: Session = r.session_ref.get_ref() as Session
	var owner: Variant = g.owner_ref.get_ref() if g!=null else null
	if not is_instance_valid(owner) or not _identity(g) or not is_same(t,r.track) or not is_same(owner._i161_control_callback_track,t) or not owner._tracks.any(func(current: Dictionary)->bool:return is_same(current,t)) or r.published_age==int(t.age):return
	r.published_age=int(t.age) # Consume scheduled callback before any publication/getter reentry.
	_publish(r)
	if r.kind=="ball" and r.state.phase=="dead":t.ticks=t.age
static func _publish(r: Record) -> void:
	if r.retired:return
	var g: Session = r.session_ref.get_ref() as Session
	if g==null:return
	if r.kind in ["background","restore"]:
		var phase: Dictionary = State.hardware(r.age)
		if g.background.is_empty() or g.background_lost:return
		if not Owned.node(g.background) or not Owned.node(g.blackout):g.background_lost=true;return
		Owned.write(g.background,"texture",g.background.writes.texture);Owned.write(g.background,"material",g.background.writes.material)
		if not g.background.lost.is_empty() or not Owned.pose(g.background,_projection(g)) or not Owned.pose(g.blackout,_projection(g)):
			Owned.write(g.background,"visible",false);Owned.write(g.blackout,"visible",false);g.background_lost=true;return
		Owned.write(g.background,"visible",not phase.swapped if r.kind=="restore" else phase.swapped)
		Owned.write(g.background,"z_index",_layer(g,0));Owned.write(g.blackout,"z_index",_layer(g,0));Owned.write(g.blackout,"color",Color(0,0,0,float(phase.y)/16.0))
		return
	if r.kind in ["palette","pan"]:return
	var b: Dictionary = _binding(g,r.actor_id)
	if r.kind=="actor_BG":
		if not b.is_empty() and b.hide_owned and b.actor.sprite.visible!=b.hide_expected:b.hide_lost=true
		if b.is_empty() or b.hide_lost or not _borrowed_material(b) or not Owned.node(r.item):_retire(r);return
		for key: String in Owned.FOLLOW:Owned.write(r.item,key,b.actor.sprite.get(key))
		if not Owned.pose(r.item,_projection(g)*(g.context.field.global_transform.affine_inverse()*b.actor.sprite.global_transform)):_retire(r);return
		Owned.write(r.item,"visible",(bool(b.visible) if b.hide_owned else b.actor.sprite.visible) and b.actor.sprite.get_parent().is_visible_in_tree());Owned.write(r.item,"z_index",_layer(g,96));return
	if b.is_empty() or _binding(g,int(g.roles[0])).is_empty() or not Owned.image_input_valid(r.input) or not _identity(g):r.presentation_lost=true
	if r.presentation_lost or not Owned.node(r.item):_drop_visual(r);return
	var pose: Dictionary = r.state if r.kind=="ball" else State.orbit(r.state.base,r.age+1)
	var transform := Transform2D(0,pose.point)
	if r.kind=="ball":
		var affine: Dictionary = Commands.evaluate(r.track.settings.affine_program,r.age,true)
		transform=Transform2D(float(affine.rotation)*TAU/256.0,pose.point);transform=transform.scaled_local(Vector2.ONE*256.0/float(affine.matrix.x))
	transform=transform.scaled_local(Vector2.ONE*float(r.track.settings.get("scale_factor",1.0)))
	if not Owned.pose(r.item,_projection(g)*transform):r.presentation_lost=true;_drop_visual(r);return
	Owned.write(r.item,"visible",bool(pose.get("live",true)))
	var priority: int = 2 if r.kind=="ball" else int(pose.priority);var z: int = _layer(g,97 if priority==1 else 95)
	Owned.write(r.item,"z_index",z);Owned.write(r.pair,"z_index",z)
	for key: String in ["texture","modulate","self_modulate","hframes","vframes","frame","region_enabled","region_rect","flip_h","flip_v"]:
		if r.node.get(key)!=r.item.writes.get(key):r.palette_lost=true
	if r.texture!=null:
		var current_image: Image = r.texture.get_image()
		if current_image==null or current_image.get_data()!=r.output_bytes:r.palette_lost=true
	if r.palette_lost:Owned.release_material(r.item)
	if not r.palette_lost and r.coefficient!=g.coefficient:
		r.prepared_image = State.palette(r.image,g.coefficient,r.default_art,r.color,bool(r.track.settings.get("recolor",false)))
		if r.texture==null:r.texture=ImageTexture.create_from_image(r.prepared_image)
		else:r.texture.update(r.prepared_image)
		Owned.write(r.item,"texture",r.texture);r.output_bytes=r.texture.get_image().get_data();r.coefficient=g.coefficient
	if Owned.node(r.pair):
		for key: String in ["copy_mode","rect","z_index"]:
			if r.pair.node.get(key)!=r.pair.writes.get(key):r.pair.lost[key]=true
		if r.pair.node.get_index()+1!=r.node.get_index():r.pair.lost.order=true
	if not Owned.node(r.pair) or not r.pair.lost.is_empty():Owned.release_material(r.item);r.item.lost_material=true
	var alpha: Vector2i = Vector2i(int(r.state.get("alpha",16)),16-int(r.state.get("alpha",16))) if r.kind=="ball" else g.alpha
	Owned.uniform(r.item,"eva",float(alpha.x)/16.0);Owned.uniform(r.item,"evb",float(alpha.y)/16.0);Owned.uniform(r.item,"first_tint",Vector3.ONE)
	if r.kind=="orbit" and r.age>=60:r.track.ticks=int(r.track.age)
	if r.kind=="ball" and r.state.get("cue",false):
		var owner: Node2D = g.owner_ref.get_ref()
		if r.state.panned:owner._play_sound(str(r.track.settings.callback_cue_path),"0",float(g.pan)/64.0,true)
		else:owner._play_sound(str(r.track.settings.callback_cue_path))

static func _drop_visual(r: Record) -> void:
	if not r.item.is_empty():
		Owned.release_material(r.item)
		if Owned.node(r.item) and r.node.get_child_count(true)>0:Owned.write(r.item,"texture",null) # Retire only our pixels, not foreign descendants.
	var g: Session = r.session_ref.get_ref() as Session
	if g==null:return
	for candidate: Variant in [r.node,r.pair.get("node")]:
		if is_instance_valid(candidate) and candidate.get_parent()==g.owner_ref.get_ref() and candidate.get_child_count(true)==0 and not candidate.is_queued_for_deletion():candidate.queue_free()
static func _retire(r: Record) -> void:
	if r.retired:return
	r.retired=true
	var g: Session = r.session_ref.get_ref() as Session
	if g!=null and r.kind=="actor_BG":_hide(g,g.bindings[r.actor_id],false)
	if r.kind not in ["background","restore","palette","pan"]:
		_drop_visual(r)
		r.track.ticks=mini(int(r.track.ticks),int(r.track.age)+1) # A retired owner must not keep the animation (and its text) alive for its full budget.
static func _cleanup_record(reference: WeakRef) -> void:
	var r: Record = reference.get_ref() as Record
	if r!=null:_retire(r)
static func release_track_node_allowed(owner: Node2D,t: Dictionary) -> bool:
	var g: Session = group(owner);var reference: Variant = t.get("confuse_record")
	var r: Record = reference.get_ref() as Record if reference is WeakRef else null
	return g==null or r==null or r.session_ref.get_ref()!=g or not is_same(r.track,t)
static func finish_context_loss(owner: Node2D) -> bool:
	var g: Session = group(owner)
	return finish(owner,"cancelled") if g!=null and (owner.context==null or not is_instance_valid(owner.context.field) or not owner.context.field.is_inside_tree()) else false
static func note_sound(owner: Node2D,player: AudioStreamPlayer2D) -> void:
	var g: Session = group(owner)
	if g!=null:g.voices.append(Owned.voice(owner,player))
static func audio_allowed(owner: Node2D,player: AudioStreamPlayer2D) -> bool:
	var g: Session = group(owner)
	if g==null:return true
	for v: Owned.Voice in g.voices:
		if v.player_ref.get_ref()==player:return v.owns()
	return false
static func note_audio_write(owner: Node2D,player: AudioStreamPlayer2D) -> void:
	var g: Session = group(owner)
	if g==null:return
	for v: Owned.Voice in g.voices:
		if v.player_ref.get_ref()==player:v.note_write()
static func audio_playing(owner: Node2D) -> bool:
	var g: Session = group(owner)
	if g==null:return false
	for v: Owned.Voice in g.voices:
		if v.owns() and v.player_ref.get_ref().playing:return true
	return false
static func finish(owner: Node2D,state: String) -> bool:
	var g: Session = group(owner)
	if g==null:return false
	if g.terminal:return true
	g.terminal=true;owner.state=state;owner.set_process(false)
	var sweep: Owned.LeafSweep = Owned.leaf_sweep(owner)
	for r: Record in g.records:_retire(r)
	for b: Dictionary in g.bindings.values():_hide(g,b,false)
	for reference: WeakRef in g.leaves:
		var candidate: Variant = reference.get_ref()
		if is_instance_valid(candidate):sweep.enroll(candidate)
	for v: Owned.Voice in g.voices:
		if v.owns(state=="cancelled" and owner.lifecycle_aborted):
			var player: AudioStreamPlayer2D = v.player_ref.get_ref();player.stop();sweep.enroll(player)
	owner._tracks.clear();owner._sounds.clear();owner.remove_meta(STATE);owner.set_meta("source_confuse_terminal",sweep)
	owner.terminated.emit(state)
	owner.definition=null;owner.context=null;owner._steps.clear();owner._factories={};g.records.clear();g.bindings.clear();g.voices.clear()
	sweep.changed();return true

extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Solar Beam's finite source-event coordinator. Generic workers remain literal.
const Data=preload("res://scripts/battle/animations/sequence/source_solar_beam_data.gd")
const Same=preload("res://scripts/battle/animations/sequence/source_cutting_slice.gd")
const Owned=preload("res://scripts/battle/animations/sequence/source_owned_composition.gd")
const Pair=preload("res://scripts/battle/animations/sequence/source_charge_owned.gd")
const Fast=preload("res://scripts/battle/animations/sequence/source_program_proof.gd")
const COMBINED=preload("res://scripts/battle/animations/sequence/source_agility_aerial_palette_ab.gdshader")
const PALETTE=preload("res://scripts/battle/animations/sequence/palette_blend.gdshader")
const RECOLOR=preload("res://scripts/battle/animations/sequence/particle_recolor.gdshader")
const STATE="i161_solar_session"
const ART=["texture","frame_rects","color","recolor","scale_factor","flip_h","flip_v"]
static var _invocations: Dictionary={}
static var _controls: Dictionary={}
static var _children: Dictionary={}

class Invocation extends RefCounted:
	var incoming: Dictionary
	var context: BattleAnimationContext
	var definition: BattleAnimationDefinition
	var pc: int
	var claimed: bool=false
	var building: bool=false

class ControlCall extends RefCounted:
	var track: Dictionary
	var record: Dictionary
	var context: BattleAnimationContext
	var executing: bool=false

class Session extends RefCounted:
	var owner: Node2D
	var context: BattleAnimationContext
	var definition: BattleAnimationDefinition
	var program: Array=[]
	var proof: Fast.Proof
	var bindings: Dictionary={}
	var objects: Array[Dictionary]=[]
	var controls: Array[Dictionary]=[]
	var palettes: Array[Dictionary]=[]
	var actors: Array[Dictionary]=[]
	var palette_leases: Dictionary={}
	var foreign: Dictionary={}
	var backgrounds: Array[Dictionary]=[]
	var global_bg: Dictionary={}
	var attacker_id: int
	var target_ids: Array=[]
	var variant: String
	var valid: bool=true

static func matches(owner: Node2D) -> bool:
	return owner is BattleAnimationSequenceRunner and owner.definition!=null and is_same(owner.definition,BattleAnimationSequenceRegistry._builtin_source_definitions.get("ruby:move/76"))

static func _number(v: Variant,integral: bool=false) -> bool:
	return typeof(v) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(v)) and (not integral or float(v)==floorf(float(v)))

static func _rects(s: Dictionary) -> Dictionary:
	if not s.get("texture") is String or not ResourceLoader.exists(s.texture):return {}
	var texture: Resource=Fast.texture(s.texture)
	if not texture is Texture2D:return {}
	if s.has("scale_factor") and (not _number(s.scale_factor) or float(s.scale_factor)<=0):return {}
	for key: String in ["recolor","flip_h","flip_v"]:
		if s.has(key) and typeof(s[key])!=TYPE_BOOL:return {}
	if s.has("color") and (not s.color is String or not Color.html_is_valid(s.color)):return {}
	var out: Dictionary={}
	if s.has("frame_rects"):
		if not s.frame_rects is Dictionary:return {}
		for key: Variant in s.frame_rects:
			if not key is String or not key.is_valid_int() or int(key)<0 or int(key)>8:return {}
			var r: Variant=s.frame_rects[key]
			if not r is Array or r.size()!=4:return {}
			for n: Variant in r:
				if not _number(n,true):return {}
			if r[0]<0 or r[1]<0 or r[2]<=0 or r[3]<=0 or r[0]+r[2]>texture.get_width() or r[1]+r[3]>texture.get_height():return {}
			out[key]=r.duplicate()
	else:
		var size: Array=s.get("frame_size",[])
		if size.size()!=2:return {}
		for frame: Dictionary in s.get("frame_commands",[]):
			var tile: int=int(frame.tile);var columns: int=texture.get_width()/8
			if columns<1:return {}
			out[str(tile)]=[0,0,size[0],size[1]] if texture.get_size()==Vector2(size[0],size[1]) else [(tile%columns)*8,(tile/columns)*8,size[0],size[1]]
	for frame: Dictionary in s.get("frame_commands",[]):
		if not out.has(str(int(frame.tile))):return {}
	for rect: Array in out.values():
		if rect[0]<0 or rect[1]<0 or rect[2]<=0 or rect[3]<=0 or rect[0]+rect[2]>texture.get_width() or rect[1]+rect[3]>texture.get_height():return {}
	return out

static func _shape(actual: Variant,expected: Dictionary) -> bool:
	if not actual is Dictionary:return false
	var art: bool=expected.get("source_callback") in ["sub_80CA7B0","sub_80CA800","sub_80CA858"]
	for key: String in expected:
		if art and key in ART:continue
		if not actual.has(key):return false
		if key=="child_binding":
			if not _shape(actual[key],expected[key]):return false
		elif not Same._same(actual[key],expected[key]):return false
	for key: Variant in actual:
		if typeof(key)!=TYPE_STRING and not (typeof(key)==TYPE_STRING_NAME and art and str(key) in ART):return false
		if not expected.has(str(key)) and (not art or str(key) not in ART):return false
	return not art or not _rects(actual).is_empty()

static func _whole(owner: Node2D) -> bool:
	if not matches(owner) or owner.definition.key!=Data.PROGRAM.key or owner.definition.coverage!=Data.PROGRAM.coverage or owner.definition.source_script!=Data.PROGRAM.source_script:return false
	if owner._steps.size()!=Data.PROGRAM.steps.size() or not Same._same(owner._steps,owner.definition.steps):return false
	for pc: int in Data.PROGRAM.steps.size():
		if not _shape(owner._steps[pc],Data.PROGRAM.steps[pc]):return false
	return true

## Cheap proof that the live program still equals the one this session admitted.
static func _fast(owner: Node2D,group: Session) -> bool:
	if group==null or group.proof==null or not matches(owner) or owner.definition.key!=Data.PROGRAM.key or owner.definition.coverage!=Data.PROGRAM.coverage or owner.definition.source_script!=Data.PROGRAM.source_script or owner._steps.size()!=Data.PROGRAM.steps.size():return false
	return Fast.holds(owner._steps,owner.definition.steps,group.program,group.proof,func(pc: int,step: Variant) -> bool:return _shape(step,Data.PROGRAM.steps[pc]))

static func open_dispatch(owner: Node2D,s: Dictionary) -> Invocation:
	if not matches(owner) or _invocations.has(owner.get_instance_id()):return null
	var invocation:=Invocation.new();invocation.incoming=s;invocation.context=owner.context;invocation.definition=owner.definition;invocation.pc=owner._pc
	_invocations[owner.get_instance_id()]=invocation;return invocation

static func close_dispatch(owner: Node2D,scope: Invocation) -> void:
	if scope!=null and is_same(_invocations.get(owner.get_instance_id()),scope):_invocations.erase(owner.get_instance_id())

static func _live(owner: Node2D,c: BattleAnimationContext,s: Dictionary) -> Invocation:
	var scope: Invocation=_invocations.get(owner.get_instance_id()) as Invocation
	return scope if scope!=null and is_same(scope.incoming,s) and is_same(scope.context,c) and is_same(owner.context,c) and is_same(scope.definition,owner.definition) and scope.pc==owner._pc else null

static func _admit(owner: Node2D,c: BattleAnimationContext,s: Dictionary,kind: String) -> bool:
	var scope: Invocation=_live(owner,c,s);var group: Session=_group(owner)
	if scope==null or scope.claimed or not (_fast(owner,group) or _whole(owner)) or (group!=null and not group.valid):return false
	var pc: int=scope.pc
	if pc<=0 or pc>=Data.PROGRAM.steps.size() or Data.PROGRAM.steps[pc].get("behavior")!=kind:return false
	var original: Dictionary=s.duplicate(true);var canonical: Dictionary=Data.PROGRAM.steps[pc]
	if not canonical.has("source_command_priority"):
		var priority: Dictionary=BattleSourcePriority.command_metadata(Data.PROGRAM.steps[pc-1])
		if not priority.is_empty():
			if not Same._same(original.get("source_command_priority"),priority):return false
			original.erase("source_command_priority")
		elif original.has("source_command_priority"):return false
	if not _shape(original,canonical) or not Same._same(original,owner._steps[pc]) or not owner.claim_effect_dispatch(s):return false
	scope.claimed=true;return true

static func _group(owner: Node2D) -> Session:
	return owner.get_meta(STATE) as Session if owner.has_meta(STATE) else null

static func _capture(actor: BattleAnimationActor,c: BattleAnimationContext) -> Dictionary:
	var sprite: Sprite2D=actor.sprite
	return {"actor":actor,"sprite":sprite,"sprite_parent":sprite.get_parent(),"texture":sprite.texture,"generation":actor._generation,"slot":actor.slot,"position":c.source_position(actor.id),"contest":c.contest}

static func _bound(binding: Dictionary,c: BattleAnimationContext) -> bool:
	return not binding.is_empty() and c.actors.get(binding.actor.id)==binding.actor and binding.actor.sprite==binding.sprite and binding.actor.is_present() and Pair._visual(binding) and c.source_position(binding.actor.id)==binding.position and c.contest==binding.contest

static func _session(owner: Node2D,c: BattleAnimationContext) -> Session:
	var group: Session=_group(owner)
	if group!=null:return group
	group=Session.new();group.owner=owner;group.context=c;group.definition=owner.definition;group.program=owner._steps.duplicate(true);group.proof=Fast.capture(group.program)
	group.attacker_id=c.attacker_id;group.target_ids=c.target_ids.duplicate();group.variant=c.presentation_variant()
	for actor: BattleAnimationActor in c.actors.values():group.bindings[actor.id]=_capture(actor,c)
	owner.set_meta(STATE,group);return group

static func _coordinate(actor: BattleAnimationActor,c: BattleAnimationContext) -> Vector2:
	var p: Vector2=BattleElectricContract.source_anchor(actor,c)
	# Quantization belongs only to this finite integer source-screen boundary,
	# never generic transforms or the compositor's independent native channels.
	return Vector2(roundi(p.x)&255,roundi(p.y)&255)

static func effect(s: Dictionary,c: BattleAnimationContext,owner: Node2D,kind: String) -> Variant:
	var captured: Session=_group(owner)
	if captured!=null:
		# A parked foreign Resource is not a new literal runner. Reject without
		# revoking the genuine session, which may resume after the rejected call.
		if captured.context.attacker_id!=captured.attacker_id or captured.context.target_ids!=captured.target_ids:return []
		if c==null or not captured.valid or not is_same(owner.definition,captured.definition) or not is_same(owner.context,captured.context) or not _whole(owner) or not Same._same(owner._steps,captured.program) or c.attacker_id!=captured.attacker_id or c.target_ids!=captured.target_ids or captured.context.presentation_variant()!=captured.variant:return []
		var child_call: Variant=_children.get(owner.get_instance_id())
		var child_lane: bool=kind=="source_particle" and child_call is Dictionary and is_same(child_call.get("incoming"),s) and is_same(child_call.get("context"),c)
		if not is_same(c,captured.context) and not child_lane:return []
	if not matches(owner):return null
	if kind=="source_particle" and _children.has(owner.get_instance_id()):return _child(s,c,owner)
	if not _admit(owner,c,s,kind):return []
	var group: Session=_session(owner,c)
	if kind=="source_particle":return _particle(s,c,owner,group,false)
	if kind=="source_charge_task":
		var scope: Invocation=_live(owner,c,s);scope.building=true
		var tracks: Array[Dictionary]=BattleChargeContract.create_control(s,c,owner,initialize_control)
		scope.building=false;return tracks
	if kind=="source_palette":return _palette(s,c,owner,group)
	if kind=="source_actor":return _actor(s,c,owner,group)
	if kind=="source_background":return [{"kind":"source_background","age":0,"ticks":int(s.ticks),"domain":"background","settings":s.duplicate(true)}]
	return []

static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if not _admit(owner,c,s,"source_legacy_impact_command"):return []
	var group: Session=_session(owner,c)
	match str(s.mode):
		"alpha","setalpha":owner.set_meta("source_legacy_impact_alpha",[12,8]);return []
		"blendoff":owner.set_meta("source_legacy_impact_alpha",[16,0]);return []
		"clearmonbg":
			for background: Dictionary in group.backgrounds:Pair._clear_pair(background)
			return []
	# Ordinary source operands0/2 both select the attacker bank pair; the shared
	# pair worker's primary-role receipt uses normalized0, not the source label2.
	var backgrounds: Array[Dictionary]=Pair._create_pair_bg(c,owner,0,"source_legacy_impact_bg","source_legacy_impact_backgrounds")
	for t: Dictionary in backgrounds:t.update=_background;group.backgrounds.append(t)
	return backgrounds

static func _particle(s: Dictionary,c: BattleAnimationContext,owner: Node2D,group: Session,child: bool) -> Array[Dictionary]:
	var live: BattleAnimationContext=group.context
	var attacker: Dictionary=group.bindings.get(live.attacker_id,{})
	var target_id: int=live.target_ids[0] if not live.target_ids.is_empty() else -1
	var target: Dictionary=group.bindings.get(target_id,{})
	var charge: bool=s.get("mode")=="solar_charge_orb"
	if not _bound(attacker,live) or (not charge and not _bound(target,live)):return []
	var normalized: Dictionary=s.duplicate(true);normalized.source_contest=c.contest;normalized.frame_rects=_rects(s)
	if normalized.frame_rects.is_empty():return []
	var a: Array=s.source_args;var origin: Vector2=_coordinate(attacker.actor,live)
	var endpoint: Vector2=origin if charge else _coordinate(target.actor,live)
	var direction: int=1 if attacker.actor.side==0 else -1
	if _bound(target,live):
		var tx: float=_coordinate(target.actor,live).x
		direction=1 if origin.x<tx else -1 if origin.x>tx else direction
	origin+=Vector2(int(a[0])*direction,int(a[1]))
	var node:=Sprite2D.new();owner.add_child(node);node.texture=load(s.texture);node.region_enabled=true
	var tint:=Color(str(s.get("color","ffffff")));node.modulate=tint
	var material: ShaderMaterial=null
	if charge:
		material=ShaderMaterial.new();material.shader=COMBINED;material.set_shader_parameter("eva",0.75);material.set_shader_parameter("evb",0.5);material.set_shader_parameter("blend_amount",0.0)
		material.set_shader_parameter("source_recolor",bool(s.get("recolor",false)));material.set_shader_parameter("source_recolor_tint",tint if bool(s.get("recolor",false)) else Color.WHITE)
	elif bool(s.get("recolor",false)):
		material=ShaderMaterial.new();material.shader=RECOLOR;material.set_shader_parameter("tint",tint)
	node.material=material
	var t: Dictionary={"kind":"source_particle","age":0,"ticks":80 if child else 18 if charge else 22,"node":node,"origin":origin,"destination":endpoint,"settings":normalized,"source_side":attacker.actor.side,"source_owner":owner,"update":_advance}
	BattleSourcePriority.initialize(t,c,owner);BattleChargeContract.initialize_particle(t,c,owner)
	var item: Dictionary={"node":node,"parent":owner,"track":t,"group":group,"binding":attacker,"target":target,"child":child,"charge":charge,"origin":origin,"endpoint":endpoint,"settings":normalized.duplicate(true),"output_texture":node.texture,"factor":float(s.get("scale_factor",1.0)),"writes":{},"lost":{},"retired":false,"active":true,"material":material,"previous":null,"shader":material.shader if material!=null else null,"uniforms":{},"revoked":{},"lost_material":false}
	if material!=null:
		for p: Dictionary in material.shader.get_shader_uniform_list():item.uniforms[str(p.name)]=material.get_shader_parameter(str(p.name))
	t.solar_item=item;t.cleanup=_particle_cleanup.bind(t);group.objects.append(item)
	for key: String in ["texture","modulate","material","region_enabled","hframes","vframes","frame"]:item.writes[key]=node.get(key)
	_advance(t,c);return [t]

static func _linear(start: Vector2,end: Vector2,duration: int,count: int) -> Vector2:
	var delta: Vector2=end-start
	var vx: int=((absi(int(delta.x))<<8)&65535)/duration;var vy: int=((absi(int(delta.y))<<8)&65535)/duration
	vx=(vx|1) if delta.x<0 else (vx&~1);vy=(vy|1) if delta.y<0 else (vy&~1)
	return start+Vector2((((vx*count)&65535)>>8)*(-1 if vx&1 else 1),(((vy*count)&65535)>>8)*(-1 if vy&1 else 1))

static func _advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	var item: Dictionary=t.solar_item;var group: Session=item.group;var c: BattleAnimationContext=group.context
	if item.retired:return
	if not group.valid or not _bound(item.binding,c) or (item.child and not _bound(item.target,c)) or not Owned.node(item) or item.node.texture!=item.output_texture or not Same._same(t.settings,item.settings):_retire(item);return
	var age: int=int(t.age)
	if age>=int(t.ticks):_retire(item);return
	var count: int=mini(age,16 if item.charge else 20)
	if item.child:count=age+1
	var point: Vector2=_linear(item.origin,item.endpoint,80 if item.child else 16 if item.charge else 20,count)
	if item.child:
		var phase: int=(int(t.settings.source_args[3])+age*15)&255
		point+=Vector2(BattleSourceTrig.sine(phase,5),BattleSourceTrig.cosine(phase,14))
		t.source_oam_subpriority=BattleElectricContract.source_subpriority(item.target.actor,c)+(6 if phase<=127 else 1)
		Owned.write(item,"z_index",BattleElectricContract.behind_actor_plane(t.source_oam_subpriority,item.target.actor,c,item.parent))
	var scale_value: float=(256.0-5.0*(age+1))/256.0 if item.charge else 1.0
	var pose: Transform2D=item.parent.global_transform.affine_inverse()*c.field.global_transform*Transform2D(0,Vector2.ONE*scale_value*float(item.factor),0,point)
	Owned.write(item,"transform",pose)
	var tile: int=7 if item.child else 8 if item.charge else int(t.settings.source_args[3]);var rect: Array=t.settings.frame_rects[str(tile)]
	Owned.write(item,"region_rect",Rect2(rect[0],rect[1],rect[2],rect[3]));Owned.write(item,"flip_h",bool(t.settings.get("flip_h",false)));Owned.write(item,"flip_v",bool(t.settings.get("flip_v",false)))
	Owned.write(item,"hframes",1);Owned.write(item,"vframes",1);Owned.write(item,"frame",0);Owned.write(item,"visible",true)

static func _retire(item: Dictionary) -> void:
	if item.retired:return
	item.retired=true;item.track.ticks=int(item.track.age)
	if Owned.node(item):
		Owned.write(item,"visible",false)
		item.node.queue_free()

static func _particle_cleanup(t: Dictionary) -> void:
	if t.has("solar_item"):t.solar_item.erase("track")
	t.erase("solar_item");t.erase("cleanup");t.erase("update")

# The only preappend parent registration is inside the already admitted original
# generator invocation. Scheduled calls use a different runner-opened scope.
static func initialize_control(t: Dictionary,s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> bool:
	if not matches(owner):return false
	var scope: Invocation=_live(owner,c,s);var group: Session=_group(owner)
	if scope==null or not scope.claimed or not scope.building or group==null or not group.valid or t.get("kind")!="source_charge_task" or not Same._same(t.settings,s):t.ticks=0;return true
	t.settings.source_contest=c.contest
	var record: Dictionary={"track":t,"settings":t.settings.duplicate(true),"group":group,"initial":true,"next_birth":0,"retired":false}
	t.solar_control=record;t.update=_control_update;t.cleanup=_control_cleanup.bind(t);group.controls.append(record)
	t.solar_child_open=open_child;t.solar_child_close=close_child
	var initial:=ControlCall.new();initial.track=t;initial.record=record;initial.context=c
	_controls[owner.get_instance_id()]=initial;_control_update(t,c);_controls.erase(owner.get_instance_id());record.initial=false
	return true

static func open_control(owner: Node2D,t: Dictionary) -> bool:
	if not is_same(owner._i161_control_callback_track,t) or not t.has("solar_control") or not owner._tracks.any(func(actual):return is_same(actual,t)):return false
	var record: Dictionary=t.solar_control
	if record.group!=_group(owner) or not is_same(record.get("track"),t) or not record.group.controls.any(func(actual):return is_same(actual,record)) or record.initial or record.retired or _controls.has(owner.get_instance_id()):return false
	var call:=ControlCall.new();call.track=t;call.record=record;call.context=owner.context
	_controls[owner.get_instance_id()]=call;return true

static func close_control(owner: Node2D,t: Dictionary) -> void:
	var call: Variant=_controls.get(owner.get_instance_id())
	if call is ControlCall and is_same(call.track,t):_controls.erase(owner.get_instance_id())

static func _control_update(t: Dictionary,c: BattleAnimationContext) -> void:
	var record: Dictionary=t.solar_control;var group: Session=record.group;var owner: Node2D=group.owner
	var call: Variant=_controls.get(owner.get_instance_id())
	if not call is ControlCall or not is_same(call.track,t) or not is_same(call.record,record) or not is_same(record.get("track"),t) or not is_same(call.context,c) or not is_same(c,group.context):return
	if record.initial:
		var original: Invocation=_invocations.get(owner.get_instance_id()) as Invocation
		if original==null or not original.claimed or not original.building or _live(owner,c,original.incoming)!=original:return
	elif not is_same(owner._i161_control_callback_track,t) or not owner._tracks.any(func(actual):return is_same(actual,t)):return
	if not group.valid or not _bound(group.bindings.get(t.attacker.id,{}),group.context) or not _bound(group.bindings.get(t.target.id,{}),group.context) or not Same._same(t.settings,record.settings):record.retired=true;t.ticks=int(t.age);return
	call.executing=true
	BattleChargeContract.update_control(t,c)
	call.executing=false
	if int(t.spawned)==15:t.ticks=int(t.age)

static func open_child(owner: Node2D,c: BattleAnimationContext,step: Dictionary) -> bool:
	var call: Variant=_controls.get(owner.get_instance_id())
	if not call is ControlCall or not call.executing or _children.has(owner.get_instance_id()):return false
	var t: Dictionary=call.track;var record: Dictionary=call.record;var group: Session=record.group
	if not is_same(record.get("track"),t) or not is_same(t.get("solar_control"),record) or not is_same(group,_group(owner)) or not group.controls.any(func(actual):return is_same(actual,record)) or not is_same(call.context,group.context):return false
	if record.initial:
		var original: Invocation=_invocations.get(owner.get_instance_id()) as Invocation
		if original==null or not original.claimed or not original.building or _live(owner,group.context,original.incoming)!=original:return false
	elif not is_same(owner._i161_control_callback_track,t) or not owner._tracks.any(func(actual):return is_same(actual,t)):return false
	if not group.valid or record.retired or not is_same(c,t.source_context) or not Same._same(step,t.settings.child_binding) or int(t.age)!=int(record.next_birth)*7 or int(t.spawned)!=int(record.next_birth) or int(record.next_birth)>=15:return false
	record.next_birth+=1;_children[owner.get_instance_id()]={"incoming":step,"context":c,"record":record,"call":call,"claimed":false};return true

static func close_child(owner: Node2D) -> void:_children.erase(owner.get_instance_id())

static func _child(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var call: Dictionary=_children[owner.get_instance_id()];var record: Dictionary=call.record
	if call.claimed or not call.call is ControlCall or not call.call.executing or not is_same(_controls.get(owner.get_instance_id()),call.call) or not is_same(call.call.track,record.get("track")) or not is_same(call.incoming,s) or not is_same(call.context,c) or not record.group.valid or not _whole(owner):return []
	if record.initial:
		var original: Invocation=_invocations.get(owner.get_instance_id()) as Invocation
		if original==null or not original.claimed or not original.building or _live(owner,record.group.context,original.incoming)!=original:return []
	elif not is_same(owner._i161_control_callback_track,call.call.track) or not owner._tracks.any(func(actual):return is_same(actual,call.call.track)):return []
	call.claimed=true;return _particle(s,c,owner,record.group,true)

static func _control_cleanup(t: Dictionary) -> void:
	if t.has("solar_control"):t.solar_control.erase("track")
	t.erase("solar_control");t.erase("cleanup");t.erase("update")
	t.erase("solar_child_open");t.erase("solar_child_close")

static func _palette(s: Dictionary,c: BattleAnimationContext,owner: Node2D,group: Session) -> Array[Dictionary]:
	var id: int=c.attacker_id if int(s.source_line)==5446 else (c.target_ids[0] if not c.target_ids.is_empty() else -1)
	var binding: Dictionary=group.bindings.get(id,{})
	if not _bound(binding,c):return []
	if not group.palette_leases.has(id):
		group.palette_leases[id]={"node":binding.sprite,"parent":binding.sprite_parent,"binding":binding,"material":null,"previous":binding.sprite.material,"shader":null,"uniforms":{},"revoked":{},"lost_material":false,"lost":false}
	var charge: bool=int(s.source_line)==5446
	var normalized: Dictionary=s.duplicate(true);normalized.source_contest=c.contest
	var t: Dictionary={"kind":"source_solar_palette","age":0,"ticks":100 if charge else 21,"settings":normalized,"owner":owner,"binding":binding,"charge":charge,"lost":false,"update":_palette_update}
	t.cleanup=_palette_cleanup.bind(t);group.palettes.append(t);_palette_update(t,c);return [t]

static func _palette_update(t: Dictionary,_c: BattleAnimationContext) -> void:
	var owner: Node2D=t.owner;var group: Session=_group(owner)
	if group==null or not group.valid or not _bound(t.binding,group.context):t.ticks=int(t.age);return
	if t.lost:return
	var age: int=int(t.age);var amount: int=0;var color:=Color8(25*255/31,255,0)
	if t.charge:
		if age>=100:return
		var leg: int=age/25;var local: int=age%25
		if local<1 or local>19 or local%3!=1:return
		var index: int=(local-1)/3
		amount=mini(11,index*2) if leg%2==0 else maxi(0,11-index*2);color=Color8(255,255,11*255/31)
	else:
		if age<1 or age%2!=1:return
		amount=(age-1)/2 if int(t.settings.source_line)==5491 else 10-(age-1)/2
	owner._held_blends[t.binding.actor.id]={"color":color,"amount":float(amount)/16.0}

static func _palette_cleanup(t: Dictionary) -> void:t.erase("cleanup");t.erase("update");t.erase("owner")

static func before_palette_writer(owner: Node2D,t: Dictionary) -> void:
	var group: Session=_group(owner)
	if group==null or not group.valid or not is_same(owner._i159_actor_callback_track,t) or not owner._tracks.any(func(actual):return is_same(actual,t)) or t.get("kind")!="source_palette" or not t.has("actor"):return
	var id: int=t.actor.id
	if not group.palette_leases.has(id) or not _bound(group.bindings.get(id,{}),group.context) or t.actor!=group.bindings[id].actor:return
	for palette: Dictionary in group.palettes:
		if palette.binding.actor==t.actor:palette.lost=true
	group.foreign[id]={"track":t,"receipt":null}

static func after_palette_writer(owner: Node2D,t: Dictionary) -> void:
	var group: Session=_group(owner)
	if group!=null and t.has("actor") and group.foreign.has(t.actor.id) and is_same(group.foreign[t.actor.id].track,t):group.foreign[t.actor.id].receipt=owner._held_blends.get(t.actor.id)

static func handle_palette(owner: Node2D,c: BattleAnimationContext,actor: BattleAnimationActor,blend: Dictionary) -> bool:
	var group: Session=_group(owner)
	if group==null or not group.palette_leases.has(actor.id):return false
	var lease: Dictionary=group.palette_leases[actor.id]
	if lease.binding.actor!=actor:return false
	if not group.valid or not _bound(lease.binding,c) or lease.lost:return true
	if lease.material!=null:
		if not Owned.observe_material(lease) or not lease.revoked.is_empty():lease.lost=true;return true
	elif actor.sprite.material!=lease.previous:lease.lost=true;return true
	var amount: float=float(blend.get("amount",0.0))
	if amount<=0:
		if lease.material!=null:actor.sprite.material=lease.previous;lease.material=null;lease.shader=null;lease.uniforms.clear()
		return true
	if lease.material==null:
		var material:=ShaderMaterial.new();material.shader=PALETTE;lease.material=material;lease.shader=material.shader;actor.sprite.material=material
		for p: Dictionary in material.shader.get_shader_uniform_list():lease.uniforms[str(p.name)]=material.get_shader_parameter(str(p.name))
	Owned.uniform(lease,"blend_color",blend.get("color",Color.WHITE));Owned.uniform(lease,"blend_amount",amount);return true

static func _actor(s: Dictionary,c: BattleAnimationContext,owner: Node2D,group: Session) -> Array[Dictionary]:
	var id: int=c.target_ids[0] if not c.target_ids.is_empty() else -1;var binding: Dictionary=group.bindings.get(id,{})
	if not _bound(binding,c):return []
	var t: Dictionary={"kind":"source_solar_actor","age":0,"ticks":129,"actor":binding.actor,"settings":s.duplicate(true),"binding":binding,"owner":owner}
	group.actors.append(t)
	var offset: Vector2=actor_offset(t,c)
	# The source register is one contribution. Preserve separate native additive
	# channels already published by the real compositor, rather than baking them.
	binding.actor.apply(binding.actor._offset+offset,binding.actor._tint)
	return [t]

static func actor_offset(t: Dictionary,c: BattleAnimationContext) -> Vector2:
	var group: Session=_group(t.owner)
	if group==null or not group.valid or not _bound(t.binding,c):t.ticks=int(t.age);return Vector2.ZERO
	var age: int=int(t.age);var x: int=0 if age>=129 else 2 if age==0 or ((age+1)/2)%2==0 else -2
	var parent: Node2D=t.binding.sprite_parent
	return parent.global_transform.affine_inverse().basis_xform(c.field.global_transform.basis_xform(Vector2(x,0)))

static func actor_allowed(owner: Node2D,actor: BattleAnimationActor) -> bool:
	var group: Session=_group(owner)
	if group==null or not group.bindings.has(actor.id) or group.bindings[actor.id].actor!=actor:return true
	return _bound(group.bindings[actor.id],group.context)

static func _background(t: Dictionary,c: BattleAnimationContext) -> void:
	var group: Session=_group(t.owner)
	if group==null or not group.valid:
		if not t.cleared:Pair._clear_pair(t)
	Pair._advance_pair(t,c)

static func _mirror_palette(item: Dictionary,owner: Node2D) -> void:
	if item.retired or not Owned.node(item) or item.lost.has("material"):return
	var source: Material=item.actor.sprite.material
	if source==null and not item.has("palette_copy"):return
	if not item.has("palette_copy"):
		var material:=ShaderMaterial.new();material.shader=PALETTE
		var made_copy: Dictionary={"node":item.node,"parent":owner,"material":material,"shader":material.shader,"uniforms":{},"revoked":{},"lost_material":false}
		for p: Dictionary in material.shader.get_shader_uniform_list():made_copy.uniforms[str(p.name)]=material.get_shader_parameter(str(p.name))
		item.palette_copy=made_copy
	var copy: Dictionary=item.palette_copy
	Owned.write(item,"material",copy.material)
	Owned.uniform(copy,"blend_color",source.get_shader_parameter("blend_color") if source is ShaderMaterial else Color.WHITE)
	Owned.uniform(copy,"blend_amount",source.get_shader_parameter("blend_amount") if source is ShaderMaterial else 0.0)

static func begin_tick(owner: Node2D,c: BattleAnimationContext) -> void:
	var group: Session=_group(owner)
	if group==null:return
	if not (_fast(owner,group) or (_whole(owner) and Same._same(owner._steps,group.program))) or not is_same(group.context,c) or not is_same(group.definition,owner.definition) or c.attacker_id!=group.attacker_id or c.target_ids!=group.target_ids or c.presentation_variant()!=group.variant:group.valid=false
	for item: Dictionary in group.objects:
		if not item.has("track"):continue
		if Owned.node(item):
			for key: String in item.writes:
				if item.node.get(key)!=item.writes[key]:item.lost[key]=true
			if item.material!=null and (not Owned.observe_material(item) or not item.revoked.is_empty()):item.lost_material=true
		if not group.valid or not _bound(item.binding,c) or (item.child and not _bound(item.target,c)):_retire(item)
	for t: Dictionary in group.actors:
		if group.valid and _bound(t.binding,c):continue
		t.ticks=int(t.age);owner._tracks.erase(t)
	for background: Dictionary in group.backgrounds:
		for item: Dictionary in background.clones:
			if Owned.node(item):
				for key: String in item.writes:
					if item.node.get(key)!=item.writes[key]:item.lost[key]=true
				if item.has("palette_copy") and (not Owned.observe_material(item.palette_copy) or not item.palette_copy.revoked.is_empty()):item.lost.material=true
		if not group.valid and not background.cleared:Pair._clear_pair(background)
	for id: Variant in group.palette_leases:
		var lease: Dictionary=group.palette_leases[id]
		if lease.material!=null and (not Owned.observe_material(lease) or not lease.revoked.is_empty()):
			lease.lost=true
			for palette: Dictionary in group.palettes:
				if palette.binding.actor.id==id:palette.lost=true
		if not group.valid or not _bound(lease.binding,c):
			for palette: Dictionary in group.palettes:
				if palette.binding.actor.id==id:palette.lost=true;palette.ticks=int(palette.age)
			if not group.foreign.has(id) and lease.material!=null and Owned.observe_material(lease) and lease.revoked.is_empty() and Pair._visual(lease.binding):lease.node.material=lease.previous
			lease.lost=true

static func after_pose(owner: Node2D,c: BattleAnimationContext) -> void:
	var group: Session=_group(owner)
	if group==null:return
	for t: Dictionary in group.backgrounds:
		Pair._after_pair_pose(t)
		for item: Dictionary in t.clones:_mirror_palette(item,owner)
	for item: Dictionary in group.objects:
		if item.has("track"):_advance(item.track,c)
	if group.valid and is_instance_valid(owner._source_background):
		var node: Sprite2D=owner._source_background
		if group.global_bg.is_empty():group.global_bg={"node":node,"parent":owner,"writes":{},"lost":{}}
		Owned.write(group.global_bg,"transform",owner.global_transform.affine_inverse()*c.field.global_transform)

static func background_write(owner: Node2D,key: String,value: Variant) -> void:
	var group: Session=_group(owner)
	if group==null:
		owner._source_background.set(key,value);return
	if group.global_bg.is_empty():
		group.global_bg={"node":owner._source_background,"parent":owner,"writes":{},"lost":{}}
		for field: String in ["transform","texture","region_rect","modulate"]:group.global_bg.writes[field]=owner._source_background.get(field)
	Owned.write(group.global_bg,key,value)

static func terminal(owner: Node2D) -> Dictionary:
	var group: Session=_group(owner);var keep: Dictionary={};var invalid: Array=[]
	if group==null:return {"foreign":keep,"invalid":invalid}
	for binding: Dictionary in group.bindings.values():
		if not _bound(binding,group.context):invalid.append(binding.actor)
	for id: Variant in group.foreign:
		var f: Dictionary=group.foreign[id]
		if f.receipt!=null and is_same(owner._held_blends.get(id),f.receipt):keep[id]={"receipt":f.receipt,"actor":group.bindings[id].actor,"material":group.bindings[id].sprite.material}
	return {"foreign":keep,"invalid":invalid}

static func release(owner: Node2D) -> void:
	var group: Session=_group(owner)
	if group==null:return
	for id: Variant in group.palette_leases:
		var lease: Dictionary=group.palette_leases[id]
		if group.foreign.has(id):continue
		if _bound(lease.binding,group.context) and lease.material!=null and Owned.observe_material(lease) and lease.revoked.is_empty():lease.node.material=lease.previous
	group.objects.clear();group.controls.clear();group.palettes.clear();group.actors.clear();group.palette_leases.clear();group.backgrounds.clear();group.foreign.clear();group.bindings.clear()
	owner.remove_meta(STATE);_children.erase(owner.get_instance_id());_controls.erase(owner.get_instance_id());_invocations.erase(owner.get_instance_id())

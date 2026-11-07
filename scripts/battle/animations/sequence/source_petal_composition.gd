extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Finite Petal Dance. Source registers and native compositor channels stay separate.
const Data=preload("res://scripts/battle/animations/sequence/source_petal_data.gd")
const Same=preload("res://scripts/battle/animations/sequence/source_cutting_slice.gd")
const Solar=preload("res://scripts/battle/animations/sequence/source_solar_beam_composition.gd")
const Capture=preload("res://scripts/battle/animations/sequence/source_stockpile_composition.gd")
const Owned=preload("res://scripts/battle/animations/sequence/source_owned_composition.gd")
const Pair=preload("res://scripts/battle/animations/sequence/source_charge_owned.gd")
const Fast=preload("res://scripts/battle/animations/sequence/source_program_proof.gd")
const COMBINED=preload("res://scripts/battle/animations/sequence/source_agility_aerial_palette_ab.gdshader")
const STATE="i168_petal_session"
static var _calls: Dictionary={}
# Proof memo: bumped whenever control can leave this module (dispatch, births, tick/pose boundaries).
static var _stamp: int=0
class Invocation extends RefCounted:
	var incoming: Dictionary
	var context: BattleAnimationContext
	var definition: BattleAnimationDefinition
	var pc: int
	var claimed: bool=false
	var physical: Dictionary={}
	var roles: Array=[]
	var initial: Dictionary={}
class Session extends RefCounted:
	var owner: Node2D
	var context: BattleAnimationContext
	var definition: BattleAnimationDefinition
	var roles: Array=[]
	var program: Array=[]
	var proof: Fast.Proof
	var proof_stamp: int=-1
	var bindings: Dictionary={}
	var lost: Dictionary={}
	var offsets: Dictionary={}
	var writers: Dictionary={}
	var motion_lost: Dictionary={}
	var palettes: Dictionary={}
	var objects: Array=[]
	var actors: Array=[]
	var valid: bool=true
	var released: Dictionary={}
static func matches(owner: Node2D) -> bool:
	if not owner is BattleAnimationSequenceRunner or owner.definition==null:return false
	var original: Variant=BattleAnimationSequenceRegistry._builtin_source_definitions.get("ruby:move/80")
	return original is BattleAnimationDefinition and is_same(owner.definition,original)

static func _group(owner: Node2D) -> Session:return owner.get_meta(STATE) as Session if owner.has_meta(STATE) else null
static func _roles(c: BattleAnimationContext) -> Array:return [c.attacker_id,c.target_ids.duplicate(),c.contest]
static func _shape(s: Variant,e: Dictionary) -> bool:
	if not s is Dictionary:return false
	var art: bool=e.get("source_callback") in ["sub_80CAD54","sub_80CAE20","sub_80E27A0"]
	for key: String in e:
		if art and key in Solar.ART:continue
		if not s.has(key) or not Same._same(s[key],e[key]):return false
	for key: Variant in s:
		if typeof(key)!=TYPE_STRING and not (typeof(key)==TYPE_STRING_NAME and art and str(key) in Solar.ART):return false
		if not e.has(str(key)) and (not art or str(key) not in Solar.ART):return false
	return not art or not Solar._rects(s).is_empty()
static func _whole(owner: Node2D) -> bool:
	if not matches(owner) or owner.definition.key!=Data.PROGRAM.key or owner.definition.coverage!=Data.PROGRAM.coverage or owner.definition.source_script!=Data.PROGRAM.source_script or owner._steps.size()!=109 or not Same._same(owner._steps,owner.definition.steps):return false
	for pc: int in 109:
		if not _shape(owner._steps[pc],Data.PROGRAM.steps[pc]):return false
	return true
## Cheap proof that the live program still equals the one this session admitted.
static func _fast(owner: Node2D,g: Session) -> bool:
	if g==null or g.proof==null or not matches(owner) or owner.definition.key!=Data.PROGRAM.key or owner.definition.coverage!=Data.PROGRAM.coverage or owner.definition.source_script!=Data.PROGRAM.source_script or owner._steps.size()!=109:return false
	return Fast.holds(owner._steps,owner.definition.steps,g.program,g.proof,func(pc: int,step: Dictionary) -> bool:return _shape(step,Data.PROGRAM.steps[pc]))
static func _whole_for(owner: Node2D,g: Session) -> bool:return _fast(owner,g) or _whole(owner)
static func _program_ok(owner: Node2D,g: Session,memo: bool) -> bool:
	if memo and g.proof_stamp==_stamp:return true
	var good: bool=_fast(owner,g) or (_whole(owner) and Same._same(owner._steps,g.program))
	if good:g.proof_stamp=_stamp
	return good
static func open_dispatch(owner: Node2D,s: Dictionary) -> Invocation:
	if not matches(owner) or _calls.has(owner.get_instance_id()):return null
	_stamp+=1
	var call:=Invocation.new();call.incoming=s;call.context=owner.context;call.definition=owner.definition;call.pc=owner._pc;call.roles=_roles(owner.context);_calls[owner.get_instance_id()]=call;return call
static func close_dispatch(owner: Node2D,call: Invocation) -> void:
	_stamp+=1
	if call!=null and is_same(_calls.get(owner.get_instance_id()),call):_calls.erase(owner.get_instance_id())
static func _valid(owner: Node2D,g: Session,memo: bool=false) -> bool:
	if not g.valid:return false
	if owner.context!=g.context or owner.definition!=g.definition or not Same._same(_roles(g.context),g.roles) or not _program_ok(owner,g,memo):g.valid=false
	return g.valid
static func _binding(g: Session,id: int) -> Dictionary:
	if g.lost.has(id):return {}
	var b: Dictionary=g.bindings.get(id,{})
	if b.is_empty():return {}
	var current: Variant=g.context.actors.get(id)
	if not current is BattleAnimationActor or not is_same(current,b.actor) or not _original_bound(b,g) or not _live_clear(b,g):g.lost[id]=true;return {}
	return b
static func _original_bound(b: Dictionary,g: Session) -> bool:
	if not b.get("actor") is BattleAnimationActor or not is_instance_valid(b.get("sprite")):return false
	var current: Variant=g.context.actors.get(b.actor.id)
	if not current is BattleAnimationActor or not is_same(current,b.actor):return false
	return Capture._bound(b,g.context) and b.actor.side==b.side and Same._same(_frame(b.sprite),b.frame)
static func _live_clear(b: Dictionary,g: Session) -> bool:
	# Captured context cannot disprove a same-Sprite successor in the live map.
	if g.owner.context==null:return true
	for value: Variant in g.owner.context.actors.values():
		if not value is BattleAnimationActor:return false
		if not is_same(value,b.actor) and is_instance_valid(value.sprite) and value.sprite==b.sprite:return false
	return true
static func _capture(c: BattleAnimationContext,id: int) -> Dictionary:
	var value: Variant=c.actors.get(id)
	if not value is BattleAnimationActor or value.id!=id or not is_instance_valid(value.sprite):return {}
	var b: Dictionary=Capture._capture(c,id)
	if not b.is_empty():
		b.frame=_frame(b.sprite)
		# Center-minus-origin is a displacement: compose local bases, not two
		# translated FIELD/global roundtrips. Preserve genuine fractional ART.
		var delta: Vector2=b.rect.get_center()
		var ancestor: Node=b.sprite
		while ancestor!=c.field and ancestor is Node2D:
			var local: Node2D=ancestor as Node2D
			if local.is_set_as_top_level():break
			delta=local.transform.basis_xform(delta)
			ancestor=local.get_parent()
		b.center_delta=delta if ancestor==c.field else (c.field.global_transform.affine_inverse()*b.sprite.global_transform).basis_xform(b.rect.get_center())
	return b

static func _frame(n: Sprite2D) -> Array:return [n.hframes,n.vframes,n.frame,n.region_enabled,n.region_rect,n.centered,n.offset,n.flip_h,n.flip_v,n.get_rect()]

static func _session(owner: Node2D,c: BattleAnimationContext) -> Session:
	var g: Session=_group(owner)
	if g!=null:return g
	g=Session.new();g.owner=owner;g.context=c;g.definition=owner.definition;g.roles=_roles(c);g.program=owner._steps.duplicate(true);g.proof=Fast.capture(g.program)
	for key: Variant in c.actors:
		if typeof(key)!=TYPE_INT:continue
		var id: int=int(key)
		var b: Dictionary=_capture(c,id)
		if not b.is_empty():g.bindings[id]=b
	owner.set_meta(STATE,g);return g
static func _admit(s: Dictionary,c: BattleAnimationContext,owner: Node2D,kind: String) -> bool:
	var call: Invocation=_calls.get(owner.get_instance_id()) as Invocation;var g: Session=_group(owner)
	if call==null or call.claimed or not is_same(call.incoming,s) or call.context!=c or owner.context!=c or call.definition!=owner.definition or call.pc!=owner._pc or not owner._i159_dispatch_live or not Same._same(call.roles,_roles(c)) or not _whole_for(owner,g) or (g!=null and not _valid(owner,g)):return false
	if call.pc<=0 or call.pc>=109:return false
	var expected: Dictionary=Data.PROGRAM.steps[call.pc]
	if expected.get("behavior")!=kind:return false
	var plain: Dictionary=s.duplicate(true);var priority: Dictionary=BattleSourcePriority.command_metadata(Data.PROGRAM.steps[call.pc-1])
	if not priority.is_empty():
		if not Same._same(plain.get("source_command_priority"),priority):return false
		plain.erase("source_command_priority")
	elif plain.has("source_command_priority"):return false
	if not _shape(plain,expected) or not Same._same(plain,owner._steps[call.pc]) or not owner.claim_effect_dispatch(s):return false
	call.claimed=true;return true
static func effect(s: Dictionary,c: BattleAnimationContext,owner: Node2D,kind: String) -> Variant:
	var call: Invocation=_calls.get(owner.get_instance_id()) as Invocation
	if call!=null and not call.physical.is_empty() and is_same(call.physical,s) and call.context==c:return null
	var g: Session=_group(owner)
	if g!=null and not _valid(owner,g):return []
	if not matches(owner):return null
	if kind not in ["source_particle","sheet","actor_motion","source_actor","source_legacy_impact_command"] or not _admit(s,c,owner,kind):return []
	g=_session(owner,c)
	if kind=="source_legacy_impact_command":return _command(s,c,owner,g)
	var target: bool=int(s.source_line) in [6804,6805]
	var id: int=c.target_ids[0] if target and not c.target_ids.is_empty() else -1 if target else c.attacker_id
	var b: Dictionary=_binding(g,id)
	if b.is_empty():return []
	if kind in ["source_particle","sheet"]:return _particle(s,c,owner,g,b,call,target)
	var t: Dictionary={"kind":"source_petal_actor","age":0,"ticks":192 if int(s.source_line)==6782 else 7 if int(s.source_line)==6801 else 8 if int(s.source_line)==6808 else 16,"actor":b.actor,"owner":owner,"settings":s.duplicate(true),"petal_id":id,"start":g.offsets.get(id,Vector2.ZERO),"callback_age":0}
	g.actors.append(t)
	if int(s.source_line) in [6782,6805]:
		var previous_source: Vector2=g.offsets.get(id,Vector2.ZERO)
		t.callback_age=-1;call.initial=t
		actor_step(t,c)
		call.initial={}
		# Replace only this source register; never add a self-target lunge twice.
		if not g.writers.has(id) and not g.motion_lost.has(id):b.actor.apply(b.actor._offset+_parent_offset(g,id,g.offsets.get(id,Vector2.ZERO)-previous_source),b.actor._tint)
	return [t]
static func _command(s: Dictionary,c: BattleAnimationContext,owner: Node2D,g: Session) -> Array[Dictionary]:
	var trace: Array=owner.get_meta("source_legacy_impact_commands",[]);trace.append(int(s.source_line));owner.set_meta("source_legacy_impact_commands",trace)
	match str(s.mode):
		"setalpha","blendoff":owner.set_meta("source_legacy_impact_alpha",[12,8] if s.mode=="setalpha" else [16,0]);return []
		"clearmonbg":
			for t: Dictionary in owner.get_meta("source_legacy_impact_backgrounds",[]):Pair._clear_pair(t)
			return []
	var result: Array[Dictionary]=Pair._create_pair_bg(c,owner,1,"source_legacy_impact_bg","source_legacy_impact_backgrounds")
	for t: Dictionary in result:t.update=_bg
	return result
static func _bg(t: Dictionary,c: BattleAnimationContext) -> void:
	if not t.get("owner") is BattleAnimationSequenceRunner or not is_same(t.owner._i161_control_callback_track,t) or not t.owner._tracks.any(func(actual):return is_same(actual,t)):return
	var g: Session=_group(t.owner)
	if g==null or c!=g.context or t.owner.context!=c:return
	_guard_bg(t,g)
	if not _valid(t.owner,g,true):Pair._clear_pair(t)
	Pair._advance_pair(t,c)
static func _direction(g: Session,b: Dictionary) -> int:
	var other: Dictionary=g.bindings.get(g.context.target_ids[0],{}) if not g.context.target_ids.is_empty() else {}
	if not other.is_empty():
		if b.origin.x<other.origin.x:return 1
		if b.origin.x>other.origin.x:return -1
	return 1 if int(b.side)==0 else -1
static func _particle(s: Dictionary,c: BattleAnimationContext,owner: Node2D,g: Session,b: Dictionary,call: Invocation,impact: bool) -> Array[Dictionary]:
	var physical: Dictionary=s.duplicate(true);physical.mode="static";physical.behavior="source_particle";physical.source_module="";physical.offset=[0,0];physical.offset_direction="";physical.mirror_offset=false;physical.selector="target" if impact else "attacker";physical.affine_program=[];physical.frame_rects=Solar._rects(s)
	physical.erase("from_selector");physical.erase("to_selector");physical.erase("end_offset")
	call.physical=physical
	_stamp+=1
	var result: Array[Dictionary]=BattleEffectBehaviorRegistry._create(physical,c,owner,"source_particle")
	_stamp+=1
	call.physical={}
	for t: Dictionary in result:
		var large: bool=s.get("source_callback")=="sub_80CAD54"
		var origin: Vector2=b.center if impact or not large else b.origin
		var args: Array=s.get("source_args",[0,0,1,0]);var direction: int=_direction(g,b)
		if not impact:origin+=Vector2(int(args[0])*direction,int(args[1]))
		var settings: Dictionary=s.duplicate(true);settings.source_contest=c.contest;settings.frame_rects=physical.frame_rects
		t.settings=settings;t.age=0;t.ticks=11 if impact else int(args[3]);t.update=_advance;t.petal_owner=owner
		var material: Material=t.node.material
		if impact:
			var combined:=ShaderMaterial.new();combined.shader=COMBINED;combined.set_shader_parameter("eva",0.75);combined.set_shader_parameter("evb",0.5);combined.set_shader_parameter("blend_amount",0.0);combined.set_shader_parameter("source_recolor",bool(s.get("recolor",false)));combined.set_shader_parameter("source_recolor_tint",Color(str(s.get("color","ffffff"))));t.node.material=combined;material=combined
		var item: Dictionary={"node":t.node,"parent":owner,"id":b.actor.id,"origin":origin,"duration":int(args[3]) if not impact else 8,"dy":int((b.center_delta.y if large else 0.0)+int(args[2])-int(args[1])) if not impact else 0,"large":large,"impact":impact,"settings":settings.duplicate(true),"texture":t.node.texture,"factor":float(s.get("scale_factor",1.0)),"track":t,"writes":{},"lost":{},"material":material,"shader":material.shader if material is ShaderMaterial else null,"uniforms":{},"revoked":{},"lost_material":false,"retired":false,"affine_remaining":8,"affine_age":0,"affine_end":false,"delegate":false}
		if material is ShaderMaterial:
			for parameter: Dictionary in material.shader.get_shader_uniform_list():item.uniforms[str(parameter.name)]=material.get_shader_parameter(str(parameter.name))
		item.callback_age=-1;item.point=origin;item.phase=64;item.flip=bool(settings.get("flip_h",false));item.writes.texture=t.node.texture
		t.petal_item=item;t.cleanup=_cleanup.bind(item);g.objects.append(item);call.initial=t;_advance(t,c);call.initial={}
	return result
static func _sin(phase: int,amplitude: int) -> int:return BattleSourceTrig.sine(phase,amplitude)
static func _axis(delta: int,duration: int,count: int) -> int:
	var velocity: int=((absi(delta)<<8)&65535)/duration;velocity=(velocity|1) if delta<0 else velocity&~1
	var magnitude: int=((velocity*count)&65535)>>8
	return -magnitude if velocity&1 else magnitude
static func _controller(t: Dictionary,c: BattleAnimationContext,particle: bool) -> bool:
	var owner: Variant=t.get("petal_owner") if particle else t.get("owner")
	if not owner is BattleAnimationSequenceRunner:return false
	var g: Session=_group(owner)
	if g==null or c!=g.context or owner.context!=c or not _valid(owner,g,true):return false
	var registered: bool=false
	if particle:
		for item: Dictionary in g.objects:
			if item.has("track") and is_same(item.track,t) and is_same(t.get("petal_item"),item):registered=true;break
	else:registered=g.actors.any(func(actual):return is_same(actual,t))
	if not registered:return false
	var call: Invocation=_calls.get(owner.get_instance_id()) as Invocation
	if call!=null and call.claimed and is_same(call.initial,t) and call.context==c and call.definition==owner.definition and call.pc==owner._pc and owner._i159_dispatch_live and Same._same(call.roles,_roles(c)):return true
	var boundary: Dictionary=owner._i161_control_callback_track if particle else owner._i159_actor_callback_track
	return is_same(boundary,t) and owner._tracks.any(func(actual):return is_same(actual,t))
static func _advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if not _controller(t,c,true):return
	var item: Dictionary=t.petal_item;var g: Session=_group(t.petal_owner)
	if item.retired or int(t.age)!=int(item.callback_age)+1:return
	if _binding(g,int(item.id)).is_empty() or not Owned.node(item) or not Same._same(t.settings,item.settings):_retire(item);return
	item.callback_age=int(t.age)
	var age: int=int(t.age)
	if not item.impact and age>=int(item.duration):_retire(item);return
	if item.impact:
		# Sprite callback precedes affine advancement: delay8 is loaded at birth.
		# Passes1..8 consume it; pass9 publishes END, callback10 assigns stored
		# Destroy, and only the following genuine callback11 invokes Destroy.
		if item.delegate:_retire(item);return
		if item.affine_end:item.delegate=true
		elif age>0:
			if int(item.affine_remaining)>0:item.affine_remaining-=1
			else:item.affine_end=true;item.affine_age=age
	item.point=item.origin;item.phase=(64+age*5)&255
	if not item.impact:
		item.point+=Vector2(_sin(item.phase,32 if item.large else 8),_axis(int(item.dy),int(item.duration),age+1)+(_sin(item.phase+64,-5) if item.large else 0))
		if not item.large and (((int(item.phase)-59)&65535)<5 or ((int(item.phase)-187)&65535)<5):item.flip=not item.flip
	_project(item,g)
static func _project(item: Dictionary,g: Session) -> void:
	# Presentation reapplication never advances phase, affine continuation or lifetime.
	if item.retired or not item.has("track") or not g.objects.any(func(actual):return is_same(actual,item)):return
	var t: Dictionary=item.track
	if not is_same(t.get("petal_item"),item) or not _valid(t.petal_owner,g,true) or _binding(g,int(item.id)).is_empty() or not Owned.node(item):return
	Owned.write(item,"texture",item.texture)
	var matrix: Transform2D=t.petal_owner.global_transform.affine_inverse()*g.context.field.global_transform*Transform2D(0.0,Vector2.ONE*float(item.factor),0.0,item.point)
	Owned.write(item,"transform",matrix)
	var tile: int=0 if item.large or item.impact else 4
	var r: Array=item.settings.frame_rects[str(tile)];Owned.write(item,"region_enabled",true);Owned.write(item,"region_rect",Rect2(r[0],r[1],r[2],r[3]));Owned.write(item,"hframes",1);Owned.write(item,"vframes",1);Owned.write(item,"frame",0)
	Owned.write(item,"flip_h",item.flip);Owned.write(item,"flip_v",bool(item.settings.get("flip_v",false)));Owned.write(item,"visible",true)
	if item.large:
		var b: Dictionary=g.bindings[item.id];var source: int=BattleElectricContract.source_subpriority(b.actor,g.context)+(-1 if ((int(item.phase)-64)&65535)<128 else 1)
		t.source_oam_priority=2;t.source_oam_subpriority=source;t.source_priority_actor_id=b.actor.id;Owned.write(item,"z_index",BattleSourcePriority.actor_layer(b.actor,t.petal_owner)+(1 if ((int(item.phase)-64)&65535)<128 else -1))
	if item.material is ShaderMaterial:Owned.observe_material(item)
	if not item.lost_material:Owned.write(item,"material",item.material)

static func _parent_offset(g: Session,id: int,value: Vector2) -> Vector2:return g.bindings[id].parent.global_transform.affine_inverse().basis_xform(g.context.field.global_transform.basis_xform(value))
static func actor_step(t: Dictionary,c: BattleAnimationContext) -> void:
	if not _controller(t,c,false):return
	if int(t.age)!=int(t.callback_age)+1:return
	t.callback_age=int(t.age)
	var g: Session=_group(t.owner);var id: int=int(t.petal_id)
	if g==null or not _valid(t.owner,g,true) or _binding(g,id).is_empty():t.ticks=int(t.age);return
	var age: int=int(t.age);var line: int=int(t.settings.source_line);var value: Vector2=g.offsets.get(id,Vector2.ZERO)
	match line:
		6782:
			var phase: int=(age*8)&255;value=Vector2(_sin(phase,12 if int(g.bindings[id].side)==0 else -12),6-_sin(phase+64,6))
			if age>=191:value=Vector2.ZERO;t.ticks=age
		6801:
			if age>=1 and age<=5:
				var numerator: int=24*256*(1 if int(g.bindings[id].side)==0 else -1);var velocity: int=numerator/5;value=Vector2(floori(float(_s16(velocity*age))/256.0),0)
			if age>=7:t.ticks=age
		6808:
			if age>=8:value=Vector2.ZERO;t.ticks=age
			elif age>=1:
				var start: Vector2=t.start;var vx: int=int(-start.x*256)/7;var vy: int=int(-start.y*256)/7
				value=start+Vector2(_s8(floori(float(_s16(vx*age))/256.0)),_s8(floori(float(_s16(vy*age))/256.0)))
		6805:
			value=Vector2(6 if ((age+1)/2)%2==0 else 0,0)
			if age>=15:value=Vector2.ZERO;t.ticks=age
	g.offsets[id]=value
static func _s16(n: int) -> int:return ((n+32768)&65535)-32768
static func _s8(n: int) -> int:return ((n+128)&255)-128
static func resolve_offset(owner: Node2D,a: BattleAnimationActor) -> Vector2:
	var g: Session=_group(owner)
	if g==null or not _valid(owner,g,true) or (g.writers.has(a.id) or g.motion_lost.has(a.id)) or _binding(g,a.id).is_empty():return Vector2.ZERO
	return _parent_offset(g,a.id,g.offsets.get(a.id,Vector2.ZERO))
static func note_held_write(owner: Node2D,t: Dictionary,value: Vector2) -> void:
	var g: Session=_group(owner);var candidate: Variant=t.get("actor")
	if g==null or not candidate is BattleAnimationActor or t.get("kind")=="source_petal_actor" or not value.is_finite() or not is_same(owner._i159_actor_callback_track,t) or not owner._tracks.any(func(actual):return is_same(actual,t)):return
	var b: Dictionary=_binding(g,candidate.id)
	if b.is_empty():return
	if not is_same(candidate,b.actor):
		if g.writers.has(candidate.id):g.writers[candidate.id].superseded=true;g.writers[candidate.id].applied=false
		return
	# A genuine publication revokes only our register. No strong track receipt.
	g.writers[candidate.id]={"value":value,"applied":false}
static func note_application(owner: Node2D,candidate: Variant,held: Vector2,approach: Vector2,offset: Vector2) -> void:
	var g: Session=_group(owner)
	if g==null or not candidate is BattleAnimationActor or not is_same(owner._i159_actor_apply_actor,candidate) or not g.writers.has(candidate.id):return
	var b: Dictionary=_binding(g,candidate.id);var receipt: Dictionary=g.writers[candidate.id]
	if b.is_empty() or not is_same(candidate,b.actor) or receipt.get("superseded",false):return
	var composed: Vector2=held+approach+offset
	if held!=receipt.value or candidate._offset!=composed or b.sprite.position!=candidate._expected_position:receipt.applied=false;return
	receipt.applied=true;receipt.composed=composed;receipt.position=candidate._expected_position

static func after_palette_writer(owner: Node2D,t: Dictionary) -> void:
	var g: Session=_group(owner);var candidate: Variant=t.get("actor")
	if g==null or not candidate is BattleAnimationActor or not is_same(owner._i159_actor_callback_track,t) or not owner._tracks.any(func(actual):return is_same(actual,t)):return
	var b: Dictionary=_binding(g,candidate.id)
	if b.is_empty() or not is_same(candidate,b.actor):return
	var receipt: Variant=owner._held_blends.get(candidate.id)
	if receipt is Dictionary:g.palettes[candidate.id]={"receipt":receipt,"material":null,"lost":false}
static func observe_palette_application(owner: Node2D) -> void:
	var g: Session=_group(owner)
	if g==null:return
	for id: int in g.palettes:
		var lease: Dictionary=g.palettes[id]
		if lease.lost:continue
		var b: Dictionary=_binding(g,id)
		if b.is_empty() or not is_same(owner._held_blends.get(id),lease.receipt):lease.lost=true;continue
		var material: ShaderMaterial=b.actor._blend_material
		if lease.material==null:
			if material!=null and is_same(b.sprite.material,material) and material.get_shader_parameter("blend_color")==lease.receipt.color and material.get_shader_parameter("blend_amount")==lease.receipt.amount:
				lease.material=weakref(material)
		elif not is_same(lease.material.get_ref(),b.sprite.material):lease.lost=true

static func before_track(owner: Node2D,t: Dictionary) -> bool:
	var g: Session=_group(owner)
	if g==null:return true
	_valid(owner,g,true)
	for id: int in g.bindings:_binding(g,id)
	if t.get("kind")!="source_petal_actor":return true
	if not g.actors.any(func(actual):return is_same(actual,t)):owner._tracks.erase(t);return false
	if not g.valid or _binding(g,int(t.petal_id)).is_empty():owner._tracks.erase(t);return false
	return true
static func begin_tick(owner: Node2D,c: BattleAnimationContext) -> void:
	var g: Session=_group(owner)
	if g==null:return
	_stamp+=1
	_valid(owner,g)
	for id: int in g.bindings:
		var b: Dictionary=_binding(g,id)
		if not b.is_empty() and (b.sprite.position!=b.actor._expected_position or b.sprite.scale!=b.actor._expected_scale or b.sprite.rotation!=b.actor._expected_rotation):g.motion_lost[id]=true
	for item: Dictionary in g.objects:
		if not g.valid or _binding(g,int(item.id)).is_empty():_retire(item)
static func after_pose(owner: Node2D,c: BattleAnimationContext) -> void:
	var g: Session=_group(owner)
	if g==null or c!=g.context or owner.context!=c:return
	_stamp+=1
	for item: Dictionary in g.objects:
		if not item.retired:_project(item,g)
	for t: Dictionary in owner.get_meta("source_legacy_impact_backgrounds",[]):
		_guard_bg(t,g)
		if not g.valid:Pair._clear_pair(t)
		Pair._after_pair_pose(t)
static func _retire(item: Dictionary) -> void:
	if item.retired:return
	item.retired=true
	if item.has("track"):item.track.ticks=int(item.track.age)
	if Owned.node(item):Owned.write(item,"visible",false);item.node.queue_free()
static func _cleanup(item: Dictionary) -> void:
	var t: Dictionary=item.get("track",{})
	t.erase("cleanup");t.erase("update");t.erase("petal_item");item.erase("track")
static func _cleanup_bound(b: Dictionary,g: Session) -> bool:
	return not g.lost.has(b.actor.id) and _original_bound(b,g) and _live_clear(b,g)
static func _hide_bound(item: Dictionary,b: Dictionary,g: Session) -> bool:
	# Source frame/side/slot membership is stricter than restoration of this
	# original appearance's own hide. Neither grants a successor restore lease.
	if b.is_empty() or not b.get("actor") is BattleAnimationActor or not is_instance_valid(b.get("sprite")):return false
	var current: Variant=g.context.actors.get(b.actor.id)
	if not current is BattleAnimationActor or not is_same(current,b.actor) or not is_same(item.actor,b.actor) or item.sprite!=b.sprite or b.actor.sprite!=b.sprite:return false
	if not b.actor.is_present() or not Pair._visual(item) or not _live_clear(b,g):return false
	# Pair's typed loop is safe only after checking every captured-map claimant.
	for value: Variant in g.context.actors.values():
		if not value is BattleAnimationActor:return false
		if not is_same(value,b.actor) and is_instance_valid(value.sprite) and value.sprite==b.sprite:return false
	return true
static func _guard_bg(t: Dictionary,g: Session) -> void:
	for item: Dictionary in t.clones:
		if item.retired:continue
		var b: Dictionary=g.bindings.get(item.actor.id,{})
		if b.is_empty() or not _cleanup_bound(b,g):
			# A frame-only source loss still releases the independent hide lease.
			# Pair preserves foreign visibility and touches no frame/pose/material.
			if _hide_bound(item,b,g):Pair._restore_pair(item,g.context)
			else:item.restored=true
			if Owned.node(item):Owned.write(item,"visible",false);item.node.queue_free()
			item.retired=true
static func terminal(owner: Node2D) -> Array:
	var g: Session=_group(owner);var invalid: Array=[]
	if g==null:return invalid
	for b: Dictionary in g.bindings.values():
		if not _cleanup_bound(b,g):invalid.append(b.actor)
	for item: Dictionary in g.objects:_retire(item)
	for t: Dictionary in owner.get_meta("source_legacy_impact_backgrounds",[]):_guard_bg(t,g)
	return invalid
static func release_actor(owner: Node2D,candidate: Variant) -> bool:
	var g: Session=_group(owner)
	if g==null:return false
	if not candidate is BattleAnimationActor:return true
	if not g.bindings.has(candidate.id):
		for b: Dictionary in g.bindings.values():
			if is_instance_valid(candidate.sprite) and candidate.sprite==b.sprite:return true
		return false
	var b: Dictionary=g.bindings[candidate.id]
	if not is_same(candidate,b.actor) or g.released.has(candidate.id) or not _cleanup_bound(b,g):return true
	var held: Dictionary=g.writers.get(candidate.id,{})
	var winning: Variant=owner._held_offsets.get(candidate.id)
	var keep_offset: bool=not held.is_empty() and held.get("applied",false) and winning is Vector2 and winning==held.value and b.sprite.position==candidate._expected_position and b.sprite.position==held.position and candidate._offset==held.composed
	var palette: Dictionary=g.palettes.get(candidate.id,{})
	var keep_material: bool=not palette.is_empty() and not palette.lost and palette.material is WeakRef and is_same(owner._held_blends.get(candidate.id),palette.receipt) and is_same(palette.material.get_ref(),b.sprite.material)
	var material: Material=b.sprite.material if keep_material else null
	# First release ALL transient additive/approach/matrix/source contributions.
	# Retain only the proven winning held vector, never a mixed visual snapshot.
	candidate.release()
	if keep_offset and _cleanup_bound(b,g):candidate.add_layout_offset(held.value)
	if keep_material and _cleanup_bound(b,g):b.sprite.material=material
	g.released[candidate.id]=true
	return true
static func release_missing_actors(owner: Node2D) -> void:
	var g: Session=_group(owner)
	if g==null:return
	for b: Dictionary in g.bindings.values():
		var current: Variant=owner.context.actors.get(b.actor.id) if owner.context!=null else null
		if not current is BattleAnimationActor or not is_same(current,b.actor):release_actor(owner,b.actor)
static func terminal_shape_allowed(owner: Node2D,candidate: Variant) -> bool:return _group(owner)==null or candidate is BattleAnimationActor

static func release(owner: Node2D) -> void:
	var g: Session=_group(owner)
	if g==null:return
	for item: Dictionary in g.objects:
		if item.has("track"):_cleanup(item)
	g.objects.clear();g.actors.clear();g.bindings.clear();g.offsets.clear();g.writers.clear();g.palettes.clear();g.released.clear();owner.remove_meta(STATE);_calls.erase(owner.get_instance_id())

static func actor_allowed(owner: Node2D,a: BattleAnimationActor) -> bool:
	var g: Session=_group(owner)
	return g==null or not g.bindings.has(a.id) or not _binding(g,a.id).is_empty()

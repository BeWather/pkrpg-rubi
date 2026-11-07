extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Exact Stockpile254 / Spit Up255 / Swallow256 share rendering and owned lifecycle.
const Data=preload("res://scripts/battle/animations/sequence/source_stockpile_data.gd")
const Spit=preload("res://scripts/battle/animations/sequence/source_spit_up_data.gd")
const Swallow=preload("res://scripts/battle/animations/sequence/source_swallow_data.gd")
const INHALE={"kinds":["source_orb_state","source_palette","actor_motion"],"particles":{"sub_80CA7B0":"inhale"},"body_end":75,"body":"inhale","palette":true,"power":false,"shakes":false,"owned_offset":false}
const BURST={"kinds":["source_orb_state","source_particle","source_actor","actor_motion"],"particles":{"sub_80D28AC":"spray","sub_80E29C0":"impact"},"body_end":78,"body":"burst","palette":false,"power":true,"shakes":true,"owned_offset":true}
const RECOVERY={"kinds":["source_orb_state","source_particle","source_actor","actor_motion"],"particles":{"sub_812D724":"bounce","sub_80793C4":"star"},"body_end":87,"body":"recovery","palette":false,"power":false,"shakes":true,"owned_offset":true}
const Solar=preload("res://scripts/battle/animations/sequence/source_solar_beam_composition.gd")
const Same=preload("res://scripts/battle/animations/sequence/source_cutting_slice.gd")
const Owned=preload("res://scripts/battle/animations/sequence/source_owned_composition.gd")
const Fast=preload("res://scripts/battle/animations/sequence/source_program_proof.gd")
const PALETTE=preload("res://scripts/battle/animations/sequence/palette_blend.gdshader")
const STATE="i162_stockpile_session"
static var _calls: Dictionary={}
class Invocation extends RefCounted:
	var incoming: Dictionary
	var context: BattleAnimationContext
	var definition: BattleAnimationDefinition
	var pc: int
	var claimed: bool=false
	var physical: Dictionary={}
	var attacker_id: int
	var target_ids: Array=[]
	var descriptor: Dictionary={}
class Session extends RefCounted:
	var context: BattleAnimationContext
	var definition: BattleAnimationDefinition
	var descriptor: Dictionary={}
	var target_binding: Dictionary={}
	var target_lost: bool=false
	var offset_lost: bool=false
	var held_writer: Dictionary={}
	var shake: Dictionary={}
	var shakes: Array=[]
	var power: Dictionary={}
	var binding: Dictionary={}
	var program: Array=[]
	var proof: Fast.Proof
	var attacker_id: int
	var target_ids: Array=[]
	var center: Vector2
	var direction: int
	var valid: bool=true
	var objects: Array=[]
	var palettes: Array=[]
	var body: Dictionary={}
	var motion_lost: bool=false
	var palette_lost: bool=false
	var lease: Dictionary={}
	var foreign: Dictionary={}
static func matches(owner: Node2D) -> bool:
	return not _descriptor(owner).is_empty()
static func _descriptor(owner: Node2D) -> Dictionary:
	if not owner is BattleAnimationSequenceRunner or owner.definition==null:return {}
	for program: Dictionary in [Data.PROGRAM,Spit.PROGRAM,Swallow.PROGRAM]:
		if is_same(owner.definition,BattleAnimationSequenceRegistry._builtin_source_definitions.get(program.key)):return program
	return {}
static func _profile(program: Dictionary) -> Dictionary:
	if is_same(program,Data.PROGRAM):return INHALE
	if is_same(program,Spit.PROGRAM):return BURST
	if is_same(program,Swallow.PROGRAM):return RECOVERY
	return {}
static func _shape(actual: Variant,expected: Dictionary,program: Dictionary) -> bool:
	if not actual is Dictionary:return false
	var profile: Dictionary=_profile(program)
	var art: bool=not profile.is_empty() and profile.particles.has(str(expected.get("source_callback","")))
	for key: String in expected:
		if art and key in Solar.ART:continue
		if not actual.has(key) or not Same._same(actual[key],expected[key]):return false
	for key: Variant in actual:
		if typeof(key)!=TYPE_STRING and not (typeof(key)==TYPE_STRING_NAME and art and str(key) in Solar.ART):return false
		if not expected.has(str(key)) and (not art or str(key) not in Solar.ART):return false
	return not art or not _rects(actual,program).is_empty()

static func _rects(s: Dictionary,program: Dictionary) -> Dictionary:
	# Only this descriptor/callback has tile IDs outside Solar's local 0..8.
	if not is_same(program,Swallow.PROGRAM) or s.get("source_callback")!="sub_80793C4":return Solar._rects(s)
	if not s.get("texture") is String:return {}
	var texture: Resource=Fast.texture(s.texture)
	if not texture is Texture2D or texture.get_width()<=0 or texture.get_height()<=0:return {}
	if s.has("scale_factor") and (not Solar._number(s.scale_factor) or float(s.scale_factor)<=0):return {}
	for key: String in ["recolor","flip_h","flip_v"]:
		if s.has(key) and typeof(s[key])!=TYPE_BOOL:return {}
	if s.has("color") and (not s.color is String or not Color.html_is_valid(s.color)):return {}
	var allowed: Array=[0,16,32,48,64,80,96];var out: Dictionary={}
	if s.has("frame_rects"):
		if not s.frame_rects is Dictionary:return {}
		for key: Variant in s.frame_rects:
			var tile: int=-1
			if key is String:
				if not key.is_valid_int():return {}
				tile=int(key)
			elif Solar._number(key,true):tile=int(key)
			else:return {}
			if not allowed.has(tile) or out.has(str(tile)):return {}
			var r: Variant=s.frame_rects[key]
			if not r is Array or r.size()!=4:return {}
			for n: Variant in r:
				if not Solar._number(n,true):return {}
			out[str(tile)]=r.duplicate()
	else:
		var raw_size: Variant=s.get("frame_size",[])
		if not raw_size is Array or raw_size.size()!=2:return {}
		for n: Variant in raw_size:
			if not Solar._number(n,true) or n<=0:return {}
		var columns: int=texture.get_width()/8
		if columns<1:return {}
		for tile: int in allowed:
			out[str(tile)]=[0,0,raw_size[0],raw_size[1]] if texture.get_size()==Vector2(raw_size[0],raw_size[1]) else [(tile%columns)*8,(tile/columns)*8,raw_size[0],raw_size[1]]
	for tile: int in allowed:
		if not out.has(str(tile)):return {}
	for r: Array in out.values():
		if r[0]<0 or r[1]<0 or r[2]<=0 or r[3]<=0 or r[0]+r[2]>texture.get_width() or r[1]+r[3]>texture.get_height():return {}
	return out

static func _group(owner: Node2D) -> Session:return owner.get_meta(STATE) as Session if owner.has_meta(STATE) else null
static func _slot(c: BattleAnimationContext,id: int) -> Dictionary:
	if c.source_positions.has(id):
		var raw: Variant=c.source_positions[id]
		if not Solar._number(raw,true) or int(raw)<0 or int(raw)>3:return {}
		return {"explicit":true,"raw":raw,"value":int(raw)}
	return {"explicit":false,"value":c.source_position(id)}
static func _capture(c: BattleAnimationContext,id: int=-1) -> Dictionary:
	var actor: BattleAnimationActor=c.actors.get(c.attacker_id if id==-1 else id)
	if actor==null or not actor.is_present() or actor.sprite.is_queued_for_deletion() or not actor.sprite.get_parent() is Node2D:return {}
	var slot: Dictionary=_slot(c,actor.id)
	if slot.is_empty() or (slot.value==-1 and actor.side not in [0,1]):return {}
	var origin: Vector2=c.field.to_local(actor.sprite.global_position)
	if not origin.is_finite():return {}
	return {"actor":actor,"sprite":actor.sprite,"parent":actor.sprite.get_parent(),"texture":actor.sprite.texture,"generation":actor._generation,"slot":slot,"contest":c.contest,"rect":actor.sprite.get_rect(),"origin":origin,"center":actor.anchor(c.field),"side":actor.side,"basis":actor.sprite.transform}
static func _bound(b: Dictionary,c: BattleAnimationContext) -> bool:
	return not b.is_empty() and c.actors.get(b.actor.id)==b.actor and b.actor.sprite==b.sprite and b.actor._generation==b.generation and b.actor.is_present() and not b.sprite.is_queued_for_deletion() and b.sprite.get_parent()==b.parent and b.sprite.texture==b.texture and Same._same(_slot(c,b.actor.id),b.slot) and c.contest==b.contest
static func _whole(owner: Node2D) -> bool:
	var program: Dictionary=_descriptor(owner)
	if program.is_empty() or owner.definition.key!=program.key or owner.definition.coverage!=program.coverage or owner.definition.source_script!=program.source_script:return false
	if owner._steps.size()!=program.steps.size() or not Same._same(owner._steps,owner.definition.steps):return false
	for pc: int in program.steps.size():
		if not _shape(owner._steps[pc],program.steps[pc],program):return false
	return true
## Cheap proof that the live program still equals the one this session admitted.
static func _fast(owner: Node2D,g: Session) -> bool:
	if g==null or g.proof==null:return false
	var program: Dictionary=_descriptor(owner)
	if program.is_empty() or owner.definition.key!=program.key or owner.definition.coverage!=program.coverage or owner.definition.source_script!=program.source_script or owner._steps.size()!=program.steps.size():return false
	return Fast.holds(owner._steps,owner.definition.steps,g.program,g.proof,func(pc: int,step: Variant) -> bool:return _shape(step,program.steps[pc],program))

static func open_dispatch(owner: Node2D,s: Dictionary) -> Invocation:
	if not matches(owner) or _calls.has(owner.get_instance_id()):return null
	var call:=Invocation.new();call.incoming=s;call.context=owner.context;call.definition=owner.definition;call.pc=owner._pc;call.attacker_id=owner.context.attacker_id;call.target_ids=owner.context.target_ids.duplicate();call.descriptor=_descriptor(owner);_calls[owner.get_instance_id()]=call;return call
static func close_dispatch(owner: Node2D,call: Invocation) -> void:
	if call!=null and is_same(_calls.get(owner.get_instance_id()),call):_calls.erase(owner.get_instance_id())
static func _admit(owner: Node2D,c: BattleAnimationContext,s: Dictionary,kind: String) -> bool:
	var call: Invocation=_calls.get(owner.get_instance_id()) as Invocation;var g: Session=_group(owner)
	if call==null or call.claimed or not is_same(call.incoming,s) or call.context!=c or owner.context!=c or call.definition!=owner.definition or call.pc!=owner._pc or not owner._i159_dispatch_live or c.attacker_id!=call.attacker_id or c.target_ids!=call.target_ids:return false
	var program: Dictionary=_descriptor(owner)
	if not is_same(program,call.descriptor) or not (_fast(owner,g) or _whole(owner)) or (g!=null and (not g.valid or not is_same(g.descriptor,program) or not _bound(g.binding,c))) or _capture(c).is_empty():return false
	if call.pc<=0 or call.pc>=program.steps.size() or program.steps[call.pc].get("behavior")!=kind:return false
	var expected: Dictionary=program.steps[call.pc];var incoming: Dictionary=s.duplicate(true)
	if not expected.has("source_command_priority"):
		var priority: Dictionary=BattleSourcePriority.command_metadata(program.steps[call.pc-1])
		if not priority.is_empty():
			if not Same._same(incoming.get("source_command_priority"),priority):return false
			incoming.erase("source_command_priority")
		elif incoming.has("source_command_priority"):return false
	if not _shape(incoming,expected,program) or not Same._same(incoming,owner._steps[call.pc]):return false
	if _profile(program).power and expected.get("selector")=="target":
		var target: Dictionary=_capture(c,c.target_ids[0]) if not c.target_ids.is_empty() else {}
		if target.is_empty() or (g!=null and (g.target_lost or not _bound(g.target_binding,c))):return false
	if expected.get("source_callback")=="sub_80D28AC" and (not Solar._number(owner._source_args.get(1),true) or int(owner._source_args[1])!=12):return false
	if not owner.claim_effect_dispatch(s):return false
	call.claimed=true;return true

static func _session(owner: Node2D,c: BattleAnimationContext) -> Session:
	var g: Session=_group(owner)
	if g!=null:return g
	g=Session.new();g.context=c;g.definition=owner.definition;g.descriptor=_descriptor(owner);g.program=owner._steps.duplicate(true);g.proof=Fast.capture(g.program);g.attacker_id=c.attacker_id;g.target_ids=c.target_ids.duplicate();g.binding=_capture(c);g.center=g.binding.center
	var side: int=int(g.binding.slot.value);g.direction=1 if side in [0,2] else -1 if side in [1,3] else 1 if g.binding.side==0 else -1
	if not c.target_ids.is_empty():
		var target: BattleAnimationActor=c.actors.get(c.target_ids[0])
		if target!=null and target.is_present() and not target.sprite.is_queued_for_deletion():
			var tx: float=c.field.to_local(target.sprite.global_position).x
			if is_finite(tx):g.direction=1 if g.binding.origin.x<tx else -1 if g.binding.origin.x>tx else g.direction
	if not c.target_ids.is_empty():g.target_binding=_capture(c,c.target_ids[0])
	g.lease={"node":g.binding.sprite,"parent":g.binding.parent,"material":null,"shader":null,"previous":g.binding.sprite.material,"uniforms":{},"revoked":{},"lost_material":false}
	owner.set_meta(STATE,g);return g
static func effect(s: Dictionary,c: BattleAnimationContext,owner: Node2D,kind: String) -> Variant:
	var call: Invocation=_calls.get(owner.get_instance_id()) as Invocation
	if call!=null and not call.physical.is_empty() and is_same(call.physical,s) and call.context==c:return null
	var g: Session=_group(owner)
	if g!=null and (not g.valid or owner.definition!=g.definition or owner.context!=g.context or c!=g.context or c.attacker_id!=g.attacker_id or c.target_ids!=g.target_ids or not is_same(_descriptor(owner),g.descriptor)):return []
	if not matches(owner):return null
	var profile: Dictionary=_profile(_descriptor(owner))
	if kind not in profile.kinds:return []
	if not _admit(owner,c,s,kind):return []
	g=_session(owner,c)
	if kind in ["source_orb_state","source_particle"]:return _particle(s,c,owner,g,call)
	var settings: Dictionary=s.duplicate(true);settings.source_contest=c.contest
	if profile.shakes and kind=="source_actor":
		var shake: Dictionary={"kind":"source_stockpile_shake","age":0,"ticks":23,"actor":g.binding.actor,"owner":owner,"settings":settings,"initial":Vector2.ZERO,"amplitude":Vector2(int(s.x),int(s.y))}
		BattleSourceActorMotion.initialize(shake);g.shakes.append(shake)
		if profile.body=="burst":
			g.shake=shake;g.binding.actor.apply(_field_offset(g,shake.displacement),Color.WHITE)
		elif not g.offset_lost:
			# Birth adds only the new source contribution to the already applied
			# aggregate; subsequent runner callbacks recompute channels normally.
			g.binding.actor.apply(g.binding.actor._offset+_field_offset(g,shake.displacement),g.binding.actor._tint)
		return [shake]
	if profile.power and s.get("motion")=="power_shake":
		var power: Dictionary={"kind":"source_stockpile_power","age":0,"ticks":16,"actor":g.target_binding.actor,"owner":owner,"settings":settings,"magnitude":clampi(int(c.source_power)/12,1,16)};g.power=power;return [power]
	if kind=="actor_motion":
		var body: Dictionary={"kind":"source_stockpile_actor","age":0,"ticks":int(profile.body_end),"actor":g.binding.actor,"owner":owner,"settings":settings};g.body=body;return [body]
	if not profile.palette:return []
	var initial: bool=int(s.source_line)==8136
	var palette: Dictionary={"kind":"source_stockpile_palette","age":0,"ticks":67 if initial else 19,"actor":g.binding.actor,"owner":owner,"settings":settings,"initial":initial};g.palettes.append(palette);return [palette]

static func _field_offset(g: Session,value: Vector2,target: bool=false) -> Vector2:
	var binding: Dictionary=g.target_binding if target else g.binding
	return binding.parent.global_transform.affine_inverse().basis_xform(g.context.field.global_transform.basis_xform(value))

static func _particle(s: Dictionary,c: BattleAnimationContext,owner: Node2D,g: Session,call: Invocation) -> Array[Dictionary]:
	# Original admission precedes a single derived physical lane. Target
	# dependencies and generic immediate poses cannot leak into this lane.
	var physical: Dictionary=s.duplicate(true);physical.behavior="source_particle";physical.mode="static";physical.offset=[0,0];physical.offset_direction="";physical.mirror_offset=false;physical.affine_program=[];physical.frame_rects=_rects(s,g.descriptor)
	call.physical=physical
	var tracks: Array[Dictionary]=BattleEffectBehaviorRegistry._create(physical,c,owner,"source_particle")
	call.physical={}
	var profile: String=_profile(g.descriptor).particles[str(s.source_callback)]
	for t: Dictionary in tracks:
		var settings: Dictionary=s.duplicate(true);settings.source_contest=c.contest;settings.frame_rects=physical.frame_rects
		t.settings=settings;t.ticks={"inhale":15,"spray":13,"impact":14,"bounce":65536,"star":22}[profile];t.age=0;t.update=_advance;t.source_owner=owner
		var delta:=Vector2.ZERO if profile=="spray" else Vector2(int(s.source_args[0])*g.direction,int(s.source_args[1]))
		var anchor: Vector2=g.target_binding.center if profile=="impact" else g.binding.origin if profile=="bounce" else g.center
		var item: Dictionary={"node":t.node,"parent":owner,"group":g,"track":t,"origin":anchor+delta,"delta":-delta,"factor":float(s.get("scale_factor",1.0)),"settings":settings.duplicate(true),"texture":t.node.texture,"writes":{"material":t.node.material},"lost":{},"material":t.node.material,"shader":t.node.material.shader if t.node.material is ShaderMaterial else null,"uniforms":{},"revoked":{},"lost_material":false,"retired":false,"profile":profile}
		if profile=="spray":item.velocity=Spit.VELOCITIES[int(s.source_args[0])]
		if profile=="bounce":item.callback_age=0;item.velocity=2304;item.y2=0;item.threshold=g.center.y
		if profile=="impact":t.source_affine_ended=false;t.source_affine_pc=1;t.source_affine_remaining=8;t.source_affine_callback_age=0
		if profile=="star":item.frame_pc=0;item.frame_end=false
		if item.material!=null:item.uniforms.tint=item.material.get_shader_parameter("tint")
		t.stockpile_item=item;t.cleanup=_particle_cleanup.bind(t);g.objects.append(item);_advance(t,c)
	return tracks

static func _axis(delta: int,count: int) -> int:
	var velocity: int=((absi(delta)<<8)&65535)/13;velocity=(velocity|1) if delta<0 else velocity&~1
	var result: int=((velocity*count)&65535)>>8
	return -result if velocity&1 else result
static func _advance(t: Dictionary,c: BattleAnimationContext) -> void:
	var item: Dictionary=t.stockpile_item;var g: Session=item.group
	if item.retired:return
	if not g.valid or not _bound(g.binding,c) or not Owned.node(item) or item.node.texture!=item.texture or not Same._same(t.settings,item.settings) or int(t.age)>=int(t.ticks):_retire(item);return
	var age: int=int(t.age);var position: Vector2=item.origin;var size: float=1.0;var tile: int=0
	match str(item.profile):
		"spray":
			position+=Vector2(_s16(int(item.velocity.x)*age),_s16(int(item.velocity.y)*age));size=(128+8*age)/256.0
		"impact":
			_impact_affine(t);size=216.0/256.0
		"bounce":
			# Post-pose reuses presentation, never advances a callback twice.
			while int(item.callback_age)<age:
				item.callback_age+=1;item.y2=_s16(int(item.y2)-(int(item.velocity)>>8));item.velocity=_s16(int(item.velocity)-96)
				if item.origin.y+int(item.y2)>float(item.threshold):_retire(item);return
			position.y+=int(item.y2)
		"star":
			var remaining: int=age
			for index: int in Swallow.STAR_FRAMES.size():
				item.frame_pc=index;tile=int(Swallow.STAR_FRAMES[index][0])
				if remaining<int(Swallow.STAR_FRAMES[index][1]):break
				remaining-=int(Swallow.STAR_FRAMES[index][1])
			if age>=21:item.frame_pc=Swallow.STAR_FRAMES.size();item.frame_end=true
		_:
			position+=Vector2(_axis(int(item.delta.x),mini(age,13)),_axis(int(item.delta.y),mini(age,13)));size=(320-14*age)/256.0
	size*=float(item.factor)
	var pose: Transform2D=t.source_owner.global_transform.affine_inverse()*c.field.global_transform*Transform2D(0.0,Vector2.ONE*size,0.0,position)
	Owned.write(item,"transform",pose);Owned.write(item,"region_enabled",true)
	var r: Array=item.settings.frame_rects[str(tile)];Owned.write(item,"region_rect",Rect2(r[0],r[1],r[2],r[3]))
	Owned.write(item,"hframes",1);Owned.write(item,"vframes",1);Owned.write(item,"frame",0)
	Owned.write(item,"flip_h",bool(item.settings.get("flip_h",false)));Owned.write(item,"flip_v",bool(item.settings.get("flip_v",false)));Owned.write(item,"visible",age%2==0 if item.profile=="impact" else true)
	if item.material!=null:Owned.observe_material(item)
	Owned.write(item,"material",item.material)

static func _s16(value: int) -> int:return ((value+32768)&65535)-32768
static func _impact_affine(t: Dictionary) -> void:
	# END is executable continuation state: after END no affine command is read.
	# Post-pose reapplication is not a second source callback.
	if t.source_affine_ended:return
	while int(t.source_affine_callback_age)<int(t.age) and not t.source_affine_ended:
		t.source_affine_callback_age+=1
		if t.source_affine_remaining>0:t.source_affine_remaining-=1
		else:
			t.source_affine_pc+=1
			if t.source_affine_pc==2:t.source_affine_ended=true

static func _retire(item: Dictionary) -> void:
	if item.retired:return
	item.retired=true;item.track.ticks=int(item.track.age)
	if Owned.node(item):Owned.write(item,"visible",false);item.node.queue_free()
static func _particle_cleanup(t: Dictionary) -> void:
	if t.has("stockpile_item"):t.stockpile_item.erase("track")
	t.erase("stockpile_item");t.erase("cleanup");t.erase("update");t.erase("source_owner")
static func actor_pose(t: Dictionary,c: BattleAnimationContext) -> Dictionary:
	var g: Session=_group(t.owner)
	if g==null or not g.valid or g.motion_lost or not _bound(g.binding,c):t.ticks=int(t.age);return {"offset":Vector2.ZERO,"scale":Vector2.ONE}
	var profile: Dictionary=_profile(g.descriptor)
	if profile.body=="burst":return _spit_body(g,t)
	if profile.body=="recovery":return _swallow_body(g,t)
	var age: int=int(t.age);var frame: int=age if age<=36 else age-37 if age<=73 else 36
	var matrix:=Vector2(256,256)
	if frame<=12:matrix+=Vector2(8,-8)*frame
	elif frame<=24:matrix=Vector2(352,160)+Vector2(-16,16)*(frame-12)
	else:matrix=Vector2(160,352)+Vector2(8,-8)*(frame-24)
	if age>=75:matrix=Vector2(256,256)
	var scale:=Vector2(256.0/matrix.x,256.0/matrix.y)
	return {"offset":Vector2(0,(1.0-scale.y)*g.binding.rect.end.y),"scale":scale}
static func _spit_body(g: Session,t: Dictionary) -> Dictionary:
	var matrix:=Vector2(256,256);var remaining: int=int(t.age)
	if remaining<78:
		var durations: Array=[20,20,6,3,15,13];var deltas: Array=[Vector2(0,6),Vector2.ZERO,Vector2(0,-18),Vector2(-18,-18),Vector2.ZERO,Vector2(4,4)]
		for index: int in durations.size():
			var count: int=mini(remaining,int(durations[index]));matrix+=deltas[index]*count;remaining-=count
			if remaining==0:break
	var scale:=Vector2(256.0/matrix.x,256.0/matrix.y)
	return {"offset":Vector2.ZERO if g.offset_lost else Vector2(0,(1.0-scale.y)*g.binding.rect.end.y),"scale":scale}
static func _swallow_body(g: Session,t: Dictionary) -> Dictionary:
	var matrix:=Vector2(256,256);var remaining: int=int(t.age)
	if remaining<87:
		for command: Array in Swallow.BODY_FRAMES:
			var count: int=mini(remaining,int(command[2]));matrix+=Vector2(int(command[0]),int(command[1]))*count;remaining-=count
			if remaining==0:break
	var scale:=Vector2(256.0/matrix.x,256.0/matrix.y)
	var feet:=Vector2(0,g.binding.rect.end.y)
	# Pin native custom-art feet using ORIGINAL basis, independently of x2.
	# The runner's additive/approach/held channels remain separate, once-only.
	var offset: Vector2=g.binding.basis.basis_xform(feet-Vector2(feet.x*scale.x,feet.y*scale.y))
	return {"offset":Vector2.ZERO if g.offset_lost else offset,"scale":scale}
static func actor_offset(t: Dictionary,c: BattleAnimationContext) -> Vector2:
	var g: Session=_group(t.owner)
	if g==null or not g.valid or not _bound(g.binding,c):t.ticks=int(t.age);return Vector2.ZERO
	if t.kind=="source_stockpile_shake":
		BattleSourceActorMotion.advance(t)
		return Vector2.ZERO if g.offset_lost else _field_offset(g,t.displacement)
	if g.target_lost or not _bound(g.target_binding,c):t.ticks=int(t.age);return Vector2.ZERO
	var events: int=int(t.age)/2;var value: int=0
	if int(t.age)<16 and events>0:value=(int(t.magnitude)+1)/2 if events%2 else -(int(t.magnitude)/2)
	return _field_offset(g,Vector2(value,0),true)
static func note_held_write(owner: Node2D,t: Dictionary,value: Vector2) -> void:
	var g: Session=_group(owner)
	if g==null or not g.valid or not _profile(g.descriptor).owned_offset or t.get("actor")!=g.binding.actor or not is_same(owner._i159_actor_callback_track,t) or not owner._tracks.any(func(actual):return is_same(actual,t)):return
	# A genuine separate held writer owns x2/y2, even at an equal value. Body
	# matrix and independent additive/approach channels remain separate.
	g.offset_lost=true;g.held_writer={"track":t,"value":value}

static func owns_offset(owner: Node2D,t: Dictionary) -> bool:
	var g: Session=_group(owner)
	if g==null or not _profile(g.descriptor).owned_offset:return false
	return is_same(t,g.body) or g.shakes.any(func(actual):return is_same(actual,t)) or is_same(t,g.power)
static func resolve_offset(owner: Node2D,actor: BattleAnimationActor,source_offset: Vector2) -> Vector2:
	var g: Session=_group(owner)
	if g==null:return Vector2.ZERO
	# Resolve after ALL callbacks: a later genuine held writer can revoke this
	# producer's already-computed offset, never another compositor channel.
	if not g.valid or not actor_allowed(owner,actor) or (actor.id==g.attacker_id and g.offset_lost):return Vector2.ZERO
	return source_offset

static func advance_palette(t: Dictionary,c: BattleAnimationContext) -> void:
	var g: Session=_group(t.owner)
	if g==null or not g.valid or not _bound(g.binding,c):t.ticks=int(t.age);return
	if g.palette_lost:return
	var age: int=int(t.age);var amount: int=0
	if t.initial:
		if age<1 or age>61 or (age-1)%10!=0:return
		amount=((age-1)/10)*2
	else:
		if age<1 or age>13 or age%2!=1:return
		amount=12-((age-1)/2)*2
	t.owner._held_blends[g.attacker_id]={"color":Color.WHITE,"amount":float(amount)/16.0}
static func before_palette_writer(owner: Node2D,t: Dictionary) -> void:
	var g: Session=_group(owner)
	if g==null or not g.valid or t.get("kind")!="source_palette" or t.get("actor")!=g.binding.actor or not is_same(owner._i159_actor_callback_track,t) or not owner._tracks.any(func(actual):return is_same(actual,t)):return
	g.palette_lost=true;g.foreign={"writer":t,"receipt":null}
static func after_palette_writer(owner: Node2D,t: Dictionary) -> void:
	var g: Session=_group(owner)
	if g!=null and not g.foreign.is_empty() and is_same(g.foreign.writer,t):g.foreign.receipt=owner._held_blends.get(g.attacker_id)
static func handle_palette(owner: Node2D,c: BattleAnimationContext,actor: BattleAnimationActor,blend: Dictionary) -> bool:
	var g: Session=_group(owner)
	if g==null or actor.id!=g.attacker_id or not _profile(g.descriptor).palette:return false
	if not g.valid or not _bound(g.binding,c):return true
	var lease: Dictionary=g.lease
	if lease.material!=null:
		if not Owned.observe_material(lease) or not lease.revoked.is_empty():g.palette_lost=true;return true
	elif lease.node.material!=lease.previous:g.palette_lost=true;return true
	if g.palette_lost and g.foreign.is_empty():return true
	var amount: float=float(blend.get("amount",0.0))
	if amount<=0:
		if lease.material!=null:lease.node.material=lease.previous;lease.material=null;lease.shader=null;lease.uniforms.clear()
		return true
	if lease.material==null:
		var material:=ShaderMaterial.new();material.shader=PALETTE;lease.material=material;lease.shader=material.shader;lease.node.material=material
		lease.uniforms={"blend_color":material.get_shader_parameter("blend_color"),"blend_amount":material.get_shader_parameter("blend_amount")}
	Owned.uniform(lease,"blend_color",blend.get("color",Color.WHITE));Owned.uniform(lease,"blend_amount",amount);return true
static func actor_allowed(owner: Node2D,actor: BattleAnimationActor) -> bool:
	var g: Session=_group(owner)
	if g==null:return true
	if actor.id==g.attacker_id:return _bound(g.binding,g.context)
	if _profile(g.descriptor).power and not g.target_binding.is_empty() and actor.id==g.target_binding.actor.id:return not g.target_lost and _bound(g.target_binding,g.context)
	return true
static func before_actor_track(owner: Node2D,t: Dictionary) -> bool:
	var g: Session=_group(owner)
	if g==null or not str(t.get("kind","")).begins_with("source_stockpile_"):return true
	if not g.valid or not actor_allowed(owner,t.actor):owner._tracks.erase(t);return false
	return true

static func begin_tick(owner: Node2D,c: BattleAnimationContext) -> void:
	var g: Session=_group(owner)
	if g==null:return
	if not g.valid or owner.definition!=g.definition or owner.context!=g.context or c.attacker_id!=g.attacker_id or c.target_ids!=g.target_ids or not is_same(_descriptor(owner),g.descriptor) or not (_fast(owner,g) or (_whole(owner) and Same._same(owner._steps,g.program))) or not _bound(g.binding,c):
		g.valid=false
		for item: Dictionary in g.objects:_retire(item)
		for t: Dictionary in g.palettes:
			owner._tracks.erase(t)
		if not g.body.is_empty():owner._tracks.erase(g.body)
		for shake: Dictionary in g.shakes:owner._tracks.erase(shake)
		if not g.power.is_empty():owner._tracks.erase(g.power)
		if g.foreign.is_empty():_release_palette(g)
		return
	if not g.target_binding.is_empty() and not _bound(g.target_binding,c):g.target_lost=true
	var a: BattleAnimationActor=g.binding.actor
	if g.binding.sprite.position!=a._expected_position or g.binding.sprite.scale!=a._expected_scale or g.binding.sprite.rotation!=a._expected_rotation:g.motion_lost=true
	if g.lease.material!=null and (not Owned.observe_material(g.lease) or not g.lease.revoked.is_empty()):g.palette_lost=true
static func after_pose(owner: Node2D,c: BattleAnimationContext) -> void:
	var g: Session=_group(owner)
	if g==null:return
	for item: Dictionary in g.objects:
		if item.has("track"):_advance(item.track,c)
static func _release_palette(g: Session) -> void:
	var lease: Dictionary=g.lease
	if _bound(g.binding,g.context) and lease.material!=null and Owned.observe_material(lease) and lease.revoked.is_empty():lease.node.material=lease.previous
static func terminal(owner: Node2D) -> Array:
	var g: Session=_group(owner)
	if g==null:return []
	var invalid: Array=[]
	if is_same(g.descriptor,Swallow.PROGRAM) and _bound(g.binding,g.context) and not g.foreign.is_empty() and is_same(owner._held_blends.get(g.attacker_id),g.foreign.receipt):
		# This producer never owns a palette. A genuine independently scheduled
		# writer's applied material remains its intent after ordinary Actor cleanup.
		var material: Material=g.binding.sprite.material
		var position: Vector2=g.binding.sprite.position
		g.binding.actor.release()
		g.binding.sprite.material=material
		if not g.held_writer.is_empty():g.binding.sprite.position=position
		invalid.append(g.binding.actor)
	elif not _bound(g.binding,g.context):invalid.append(g.binding.actor)
	elif _profile(g.descriptor).owned_offset and not g.held_writer.is_empty():
		# Release only our matrix/tint; genuine independently held displacement
		# remains owned by its writer across source task retirement and cancel.
		g.binding.actor.apply_transform(Vector2.ONE)
		invalid.append(g.binding.actor)
	if not g.target_binding.is_empty() and (g.target_lost or not _bound(g.target_binding,g.context)):invalid.append(g.target_binding.actor)
	return invalid

static func release(owner: Node2D) -> void:
	var g: Session=_group(owner)
	if g==null:return
	if g.foreign.is_empty():_release_palette(g)
	g.objects.clear();g.palettes.clear();g.body={};g.shake={};g.shakes.clear();g.power={};g.held_writer={};g.target_binding.clear();g.descriptor={};g.binding.clear();g.lease.clear();g.foreign.clear();owner.remove_meta(STATE);_calls.erase(owner.get_instance_id())

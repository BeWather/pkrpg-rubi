extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Blizzard's source registers are FIELD values, never owner-local displacements.
const Data=preload("res://scripts/battle/animations/sequence/source_blizzard_data.gd")
const Same=preload("res://scripts/battle/animations/sequence/source_cutting_slice.gd")
const Solar=preload("res://scripts/battle/animations/sequence/source_solar_beam_composition.gd")
const Geometry=preload("res://scripts/battle/animations/sequence/source_petal_composition.gd")
const Owned=preload("res://scripts/battle/animations/sequence/source_owned_composition.gd")
const Pair=preload("res://scripts/battle/animations/sequence/source_charge_owned.gd")
const Fast=preload("res://scripts/battle/animations/sequence/source_program_proof.gd")
const Recolor=preload("res://scripts/battle/animations/sequence/particle_recolor.gdshader")
const STATE="i170_blizzard_session"
static var _calls: Dictionary={}
# Proof memo: bumped whenever control can leave this module (dispatch, births, tick/pose boundaries).
static var _stamp: int=0
class Invocation extends RefCounted:
	var incoming: Dictionary
	var context: BattleAnimationContext
	var definition: BattleAnimationDefinition
	var pc: int
	var roles: Array=[]
	var claimed: bool=false
	var physical: Dictionary={}
	var consumed: bool=false
	var initial: Dictionary={}
class Scroll extends RefCounted:
	var creation_tick: int
	var parent_line: int
	var parent_callback: String
	var source_callback: String
	var publication: Array=[]
	var data: Array=[0,0,0,-1,0,0,0,0,0,0,0,0]
	var raw: Vector2i=Vector2i.ZERO
	var native: Vector2=Vector2.ZERO
class Session extends RefCounted:
	var owner: Node2D
	var context: BattleAnimationContext
	var definition: BattleAnimationDefinition
	var roles: Array=[]
	var program: Array=[]
	var proof: Fast.Proof
	var proof_stamp: int=-1
	var provider: Array=[]
	var double_mode: bool=false
	var side: int=-1
	var bindings: Dictionary={}
	var lost: Dictionary={}
	var objects: Array=[]
	var controllers: Array=[]
	var records: Array=[]
	var raw_provider: Array=[]
	var raw_entry: Vector2i=Vector2i.ZERO
	var shade: Dictionary={}
	var scrolls: Array=[]
	var valid: bool=true
	var bg: Dictionary={}
	var restored: bool=false
	var held: Dictionary={}
	var palettes: Dictionary={}
	var palette_serial: Dictionary={}
	var material_leases: Dictionary={}
	var released: Dictionary={}
	var entry_offset: Vector2=Vector2.ZERO
static func matches(owner: Node2D) -> bool:
	if not _runner(owner) or owner.definition==null:return false
	var original: Variant=BattleAnimationSequenceRegistry._builtin_source_definitions.get("ruby:move/59")
	return _definition_object(original) and is_same(owner.definition,original)
static func _group(owner: Node2D) -> Session:
	if not _object(owner) or not owner.has_meta(STATE):return null
	var value: Variant=owner.get_meta(STATE)
	return value as Session if _object(value) and value is Session and is_same(value.owner,owner) else null
static func _roles(c: BattleAnimationContext) -> Array:return [c.attacker_id,c.target_ids.duplicate(),c.contest]
static func _provider(c: BattleAnimationContext) -> Array:
	if c.has_meta("source_double_battle"):
		var value: Variant=c.get_meta("source_double_battle")
		return [true,value] if typeof(value)==TYPE_BOOL else []
	return [false]
static func _rects(s: Dictionary) -> Dictionary:
	var raw: Variant=s.get("texture");var texture: Texture2D=null
	if _texture(raw):texture=raw
	elif typeof(raw)==TYPE_STRING and ResourceLoader.exists(raw):texture=_load_texture(raw)
	if texture==null or texture.get_width()<=0 or texture.get_height()<=0:return {}
	if s.has("scale_factor") and (not Solar._number(s.scale_factor) or float(s.scale_factor)<=0):return {}
	for key: String in ["recolor","flip_h","flip_v"]:
		if s.has(key) and typeof(s[key])!=TYPE_BOOL:return {}
	if s.has("color") and (typeof(s.color)!=TYPE_STRING or not Color.html_is_valid(s.color)):return {}
	if typeof(s.get("frame_commands"))!=TYPE_ARRAY or s.frame_commands.is_empty() or typeof(s.frame_commands[0])!=TYPE_DICTIONARY or not Solar._number(s.frame_commands[0].get("tile"),true):return {}
	var tile: int=int(s.frame_commands[0].tile);var out: Dictionary={}
	if typeof(s.get("frame_rects"))!=TYPE_DICTIONARY:return {}
	for key: Variant in s.frame_rects:
		if typeof(key)!=TYPE_STRING or key!=str(tile):return {}
		var rect: Variant=s.frame_rects[key]
		if typeof(rect)!=TYPE_ARRAY or rect.size()!=4:return {}
		for n: Variant in rect:
			if not Solar._number(n):return {}
		if rect[0]<0 or rect[1]<0 or rect[2]<=0 or rect[3]<=0 or rect[0]+rect[2]>texture.get_width() or rect[1]+rect[3]>texture.get_height():return {}
		out[key]=rect.duplicate()
	return out
static func _shape(s: Variant,e: Dictionary) -> bool:
	if typeof(s)!=TYPE_DICTIONARY:return false
	var art: bool=e.get("behavior")=="source_particle"
	for key: String in e:
		if art and key in Solar.ART:continue
		if not s.has(key) or not Same._same(s[key],e[key]):return false
	for key: Variant in s:
		if typeof(key)!=TYPE_STRING and not (typeof(key)==TYPE_STRING_NAME and art and str(key) in Solar.ART):return false
		if not e.has(str(key)) and (not art or str(key) not in Solar.ART):return false
	return not art or not _rects(s).is_empty()
static func _definition_header(d: BattleAnimationDefinition) -> bool:
	var original: Variant=BattleAnimationSequenceRegistry._builtin_source_definitions.get("ruby:move/59")
	return _definition_object(original) and is_same(d,original) and d.schema_version==1 and d.key==Data.PROGRAM.key and d.coverage==Data.PROGRAM.coverage and d.source_script==Data.PROGRAM.source_script and d.steps.size()==236
static func _definition(d: BattleAnimationDefinition) -> bool:
	if not _definition_header(d):return false
	for pc: int in 236:
		if not _shape(d.steps[pc],Data.PROGRAM.steps[pc]):return false
	return true
static func _whole(owner: Node2D) -> bool:
	return matches(owner) and _definition(owner.definition) and Same._same(owner._steps,owner.definition.steps)
## Cheap proof that the live program still equals the one this session admitted.
static func _fast(owner: Node2D,g: Session) -> bool:
	if g==null or g.proof==null or not matches(owner) or not _definition_header(owner.definition) or owner._steps.size()!=236:return false
	return Fast.holds(owner._steps,owner.definition.steps,g.program,g.proof,func(pc: int,step: Dictionary) -> bool:return _shape(step,Data.PROGRAM.steps[pc]))
static func _whole_for(owner: Node2D,g: Session) -> bool:return _fast(owner,g) or _whole(owner)
static func _program_ok(owner: Node2D,g: Session,memo: bool) -> bool:
	if memo and g.proof_stamp==_stamp:return true
	var good: bool=_fast(owner,g) or (_whole(owner) and Same._same(owner._steps,g.program))
	if good:g.proof_stamp=_stamp
	return good
static func accepts_texture_dependency(d: BattleAnimationDefinition,s: Dictionary) -> bool:
	return _definition(d) and _texture(s.get("texture")) and d.steps.any(func(actual):return is_same(actual,s)) and not _rects(s).is_empty()
static func open_dispatch(owner: Node2D,s: Dictionary) -> Invocation:
	if not matches(owner) or _calls.has(owner.get_instance_id()):return null
	_stamp+=1
	var call:=Invocation.new();call.incoming=s;call.context=owner.context;call.definition=owner.definition;call.pc=owner._pc;call.roles=_roles(owner.context);_calls[owner.get_instance_id()]=call;return call
static func close_dispatch(owner: Node2D,call: Invocation) -> void:
	_stamp+=1
	if call!=null and is_same(_calls.get(owner.get_instance_id()),call):_calls.erase(owner.get_instance_id())
static func _valid(g: Session,memo: bool=false) -> bool:
	if not g.valid:return false
	if g.owner.context!=g.context or g.owner.definition!=g.definition or not Same._same(_roles(g.context),g.roles) or not Same._same(_provider(g.context),g.provider) or not Same._same(_raw_provider(g.context),g.raw_provider) or not _program_ok(g.owner,g,memo):g.valid=false
	return g.valid
static func _session(owner: Node2D,c: BattleAnimationContext) -> Session:
	var g: Session=_group(owner)
	if g!=null:return g
	var provider: Array=_provider(c);var raw_provider: Array=_raw_provider(c)
	if provider.is_empty() or raw_provider.is_empty():return null
	g=Session.new();g.owner=owner;g.context=c;g.definition=owner.definition;g.program=owner._steps.duplicate(true);g.proof=Fast.capture(g.program);g.roles=_roles(c);g.provider=provider;g.raw_provider=raw_provider;g.raw_entry=raw_provider[1]
	for key: Variant in c.actors:
		if typeof(key)!=TYPE_INT or not _actor(c.actors[key]):continue
		var b: Dictionary=Geometry._capture(c,int(key))
		if not b.is_empty():g.bindings[key]=b
	g.double_mode=bool(provider[1]) if provider[0] else g.bindings.values().any(func(b):return b.slot.value in [2,3])
	var attacker: Dictionary=g.bindings.get(c.attacker_id,{})
	if not attacker.is_empty():g.side=int(attacker.side)
	elif c.source_positions.has(c.attacker_id):
		var source: Variant=c.source_positions[c.attacker_id]
		if Solar._number(source,true) and int(source) in [0,1,2,3]:g.side=int(source)&1
	owner.set_meta(STATE,g);return g
static func _binding(g: Session,id: int,frame: bool=true) -> Dictionary:
	if g.lost.has(id):return {}
	var b: Dictionary=g.bindings.get(id,{})
	if b.is_empty():return {}
	var current: Variant=g.context.actors.get(id)
	var ok: bool=_actor(current) and _actor(b.actor) and is_same(current,b.actor) and _sprite(b.sprite) and b.actor.sprite==b.sprite and b.actor._generation==b.generation and b.sprite.get_parent()==b.parent and b.sprite.texture==b.texture and b.actor.side==b.side
	if ok and frame:ok=Same._same(Geometry._frame(b.sprite),b.frame)
	if ok:ok=Same._same(g.context.source_position(id),b.slot.value)
	if g.owner.context!=null:
		for value: Variant in g.owner.context.actors.values():
			if not _actor(value):ok=false;break
			if not is_same(value,b.actor) and _sprite(value.sprite) and value.sprite==b.sprite:ok=false;break
	if not ok:g.lost[id]=true;return {}
	return b
static func _average(g: Session) -> Dictionary:
	if g.context.target_ids.is_empty():return {}
	var b: Dictionary=_binding(g,g.context.target_ids[0])
	if b.is_empty():return {}
	var point: Vector2=b.center
	if g.double_mode and not g.context.contest:
		for id: int in g.bindings:
			var other: Dictionary=_binding(g,id)
			if not other.is_empty() and int(other.slot.value)==(int(b.slot.value)^2):
				point=Vector2(int((int(point.x)+int(other.center.x))/2.0),int((int(point.y)+int(other.center.y))/2.0));break
	return {"point":point,"binding":b}
static func _admit(s: Dictionary,c: BattleAnimationContext,owner: Node2D,kind: String) -> Invocation:
	var call: Invocation=_invocation(owner);var g: Session=_group(owner)
	if call==null or call.claimed or not is_same(call.incoming,s) or call.context!=c or owner.context!=c or call.definition!=owner.definition or call.pc!=owner._pc or not owner._i159_dispatch_live or not Same._same(call.roles,_roles(c)) or not _whole_for(owner,g) or _provider(c).is_empty() or _raw_provider(c).is_empty() or (g!=null and not _valid(g)):return null
	if call.pc<=0 or call.pc>=236:return null
	var expected: Dictionary=Data.PROGRAM.steps[call.pc]
	if expected.get("behavior")!=kind:return null
	var plain: Dictionary=s.duplicate(true);var priority: Dictionary=BattleSourcePriority.command_metadata(Data.PROGRAM.steps[call.pc-1])
	if not priority.is_empty():
		if not Same._same(plain.get("source_command_priority"),priority):return null
		plain.erase("source_command_priority")
	elif plain.has("source_command_priority"):return null
	if not _shape(plain,expected) or not Same._same(plain,owner._steps[call.pc]) or not owner.claim_effect_dispatch(s):return null
	call.claimed=true;return call
static func physical_entry(s: Dictionary,c: BattleAnimationContext,owner: Node2D,kind: String) -> bool:
	if kind!="source_particle" or not _runner(owner):return false
	var call: Invocation=_invocation(owner);var g: Session=_group(owner)
	if call==null or g==null or not call.claimed or call.consumed or not is_same(call.physical,s) or call.context!=c or owner.context!=c or call.definition!=owner.definition or call.pc!=owner._pc or not owner._i159_dispatch_live or not _valid(g):return false
	call.consumed=true;return true
static func effect(s: Dictionary,c: BattleAnimationContext,owner: Node2D,kind: String,physical: bool=false) -> Variant:
	if physical:return _render(s,owner)
	var call: Invocation=_invocation(owner)
	if call!=null and not call.physical.is_empty() and is_same(call.physical,s):return []
	var g: Session=_group(owner)
	if g!=null and not _valid(g):return []
	if not matches(owner):return null
	if kind not in ["source_particle","source_scroll","source_background","source_legacy_impact_command"]:return null
	call=_admit(s,c,owner,kind)
	if call==null:return []
	g=_session(owner,c)
	if g==null:return []
	if kind=="source_scroll":return _child(s,g)
	if kind=="source_background":return _background(s,g)
	if kind=="source_legacy_impact_command":
		if s.mode=="clearmonbg":
			for r: Dictionary in g.records:
				if r.kind=="source_blizzard_mirrors" and not r.retired:
					if _record_shape(g,r):
						var wrote_material: bool=not r.track.cleared
						Pair._clear_pair(r.track);_sync_clones(r,wrote_material)
					else:_retire_record(g,r)
			return []
		var result: Array[Dictionary]=Pair._create_pair_bg(c,owner,3,"source_blizzard_mirrors","source_blizzard_mirrors")
		for t: Dictionary in result:
			t.update=_mirrors;g.controllers.append(t);_register(g,t)
		return result
	return _particle(s,g,call)
static func _render(s: Dictionary,owner: Node2D) -> Array[Dictionary]:
	# Reentrant registry ENTRY consumed the sole admitted physical packet.
	var node:=Sprite2D.new();var raw: Variant=s.texture
	if _texture(raw):node.texture=raw
	elif typeof(raw)==TYPE_STRING:node.texture=_load_texture(raw)
	if node.texture==null:node.free();return []
	if bool(s.get("recolor",false)):
		var material:=ShaderMaterial.new();material.shader=Recolor;material.set_shader_parameter("tint",Color(str(s.get("color","ffffff"))));node.material=material
	owner.add_child(node)
	return [{"kind":"source_particle","age":0,"ticks":65536,"node":node,"settings":s.duplicate(true)}]
static func _velocity(start: Vector2,target: Vector2,speed: int) -> Dictionary:
	var dx: int=int(target.x-start.x);var dy: int=int(target.y-start.y);var duration: int=int(absi(dx)*16/speed)
	if duration<=0:return {}
	var vx: int=(int(((absi(dx)*16)&65535)/duration)&65534)|(1 if dx<0 else 0)
	var vy: int=(int(((absi(dy)*16)&65535)/duration)&65534)|(1 if dy<0 else 0)
	return {} if vx<2 and vy<2 else {"duration":duration,"vx":vx,"vy":vy}
static func _delta(v: Dictionary,n: int,reverse: bool=false) -> Vector2:
	var vx: int=int(v.vx)^(1 if reverse else 0);var vy: int=int(v.vy)^(1 if reverse else 0)
	return Vector2((-1 if vx&1 else 1)*(((vx*n)&65535)>>4),(-1 if vy&1 else 1)*(((vy*n)&65535)>>4))
static func _outside(point: Vector2,ymax: int=160) -> bool:return point.x< -16 or point.x>256 or point.y< -16 or point.y>ymax
static func _particle(s: Dictionary,g: Session,call: Invocation) -> Array[Dictionary]:
	var average: Dictionary=_average(g)
	if average.is_empty() or g.side<0:return []
	var heavy: bool=s.source_callback=="AnimIceEffectParticle";var small: bool=s.source_callback=="AnimSwirlingSnowball_Step1"
	var point: Vector2=average.point;var target: Vector2=point;var velocity: Dictionary={};var reverse: int=0
	if heavy:point+=Vector2(float(s.offset[0])*(1 if g.side==0 else -1),float(s.offset[1]))
	else:
		var a: Dictionary=_binding(g,g.context.attacker_id)
		if a.is_empty():return []
		var args: Array=s.source_args;point=a.center+Vector2(float(args[0])*(1 if g.side==0 else -1),float(args[1]));target.x+=float(args[2])*(1 if g.side==0 else -1)
		if not small:target.y+=float(args[3])
		velocity=_velocity(point,target,int(args[4]))
		if not velocity.is_empty():
			var initial: Vector2=point
			for n: int in range(1,65537):
				point=initial+_delta(velocity,n,true);reverse=n
				if _outside(point):break
				if n==65536:velocity={};point=initial
			if small and not velocity.is_empty():velocity=_velocity(point,target,int(args[4]))
	call.physical=s.duplicate(true)
	_stamp+=1
	var result: Array[Dictionary]=BattleEffectBehaviorRegistry._create(call.physical,g.context,g.owner,"source_particle")
	_stamp+=1
	call.physical={}
	for t: Dictionary in result:
		var settings: Dictionary=s.duplicate(true);settings.source_contest=g.context.contest;settings.frame_rects=_rects(s)
		t.settings=settings;t.update=_advance;t.blizzard_owner=g.owner;t.owner=g.owner
		BattleSourcePriority.initialize(t,g.context,g.owner)
		var captured_material: Variant=_native_material(t.node)
		var captured_shader: Variant=_native_shader(captured_material) if _shader(captured_material) else null
		var item: Dictionary={"node":t.node,"parent":g.owner,"track":t,"settings":settings.duplicate(true),"texture":t.node.texture,"origin":point,"point":point,"base":point,"velocity":velocity,"reverse":reverse,"small":small,"heavy":heavy,"stage":"arrival","n":0,"callback_age":-1,"retired":false,"factor":float(s.get("scale_factor",1.0)),"tile":int(s.frame_commands[0].tile),"writes":{},"lost":{},"material":captured_material,"shader":captured_shader,"uniforms":{},"revoked":{},"lost_material":false,"affine_end":false,"delegate":false}
		if _shader(item.material):
			for p: Dictionary in item.shader.get_shader_uniform_list():item.uniforms[str(p.name)]=item.material.get_shader_parameter(str(p.name))
		item.writes.texture=t.node.texture;t.blizzard_item=item;g.objects.append(item);_register(g,t,item);t.cleanup=_cleanup.bind(_record(g,t));call.initial=t;_advance(t,g.context);call.initial={}
	return result
static func _controller(t: Dictionary,c: BattleAnimationContext) -> bool:
	var owner: Variant=t.get("blizzard_owner",t.get("owner"))
	if not _runner(owner):return false
	var g: Session=_group(owner)
	if g==null or g.context!=c or not _valid(g,true):return false
	var record: Dictionary=_record(g,t)
	if record.is_empty() or not _record_shape(g,record):return false
	var call: Invocation=_invocation(owner)
	var immediate: bool=call!=null and call.claimed and is_same(call.initial,t) and call.context==c and call.pc==owner._pc and owner._i159_dispatch_live
	if not immediate and (not is_same(owner._i161_control_callback_track,t) or not owner._tracks.any(func(actual):return is_same(actual,t))):return false
	if int(t.age)!=int(record.last_age)+1:return false
	record.last_age=int(t.age);return true
static func _advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if not _controller(t,c):return
	var item: Dictionary=t.blizzard_item
	if item.retired or int(t.age)!=int(item.callback_age)+1:return
	if not Owned.node(item) or not Same._same(t.settings,item.settings):_retire(item);return
	item.callback_age=int(t.age);var age: int=int(t.age)
	if item.heavy:
		if age>=38:_retire(item);return
		item.affine_end=age>=17;item.delegate=age>=18
	else:
		var v: Dictionary=item.velocity
		if v.is_empty():
			if age>0:_retire(item);return
		elif age>0:
			if not item.small:
				item.point=item.origin+_delta(v,age)
				if age>=int(v.duration)-1 and _outside(item.point):_retire(item);return
			elif age<=int(v.duration):item.point=item.origin+_delta(v,age)
			elif age==int(v.duration)+1:pass # assign Step2 only
			elif age<=int(v.duration)+33:
				if age==int(v.duration)+2:item.base=item.point
				var phase: int=(128+16*(age-int(v.duration)-2))&255
				item.point=item.base+Vector2(BattleSourceTrig.sine(phase,20 if _group(t.blizzard_owner).side else -20),BattleSourceTrig.sine((phase+64)&255,15)+15)
			elif age==int(v.duration)+34:item.base=item.point # commit, assign End only
			else:
				item.point=item.base+_delta(v,age-int(v.duration)-34)
				if _outside(item.point,256):_retire(item);return
	_project(item,_group(t.blizzard_owner))
static func _project(item: Dictionary,g: Session) -> void:
	var record: Dictionary=_record_item(g,item)
	if record.is_empty() or record.retired:return
	if not _valid(g,true) or not _record_shape(g,record):_retire_record(g,record);return
	if item.retired or not Owned.node(record.visual):return
	var age: int=int(item.track.age);var factor: float=item.factor*((206+5*mini(age,10))/256.0 if item.heavy else 1.0)
	Owned.write(record.visual,"texture",item.texture)
	Owned.write(record.visual,"transform",g.owner.global_transform.affine_inverse()*g.context.field.global_transform*Transform2D(0.0,Vector2.ONE*factor,0.0,item.point))
	var r: Array=item.settings.frame_rects[str(item.tile)]
	Owned.write(record.visual,"region_enabled",true);Owned.write(record.visual,"region_rect",Rect2(r[0],r[1],r[2],r[3]));Owned.write(record.visual,"hframes",1);Owned.write(record.visual,"vframes",1);Owned.write(record.visual,"frame",0)
	Owned.write(record.visual,"flip_h",bool(item.settings.get("flip_h",false)));Owned.write(record.visual,"flip_v",bool(item.settings.get("flip_v",false)));Owned.write(record.visual,"visible",not item.heavy or age<19 or age%2==0)
	if _shader(record.material.material):Owned.observe_material(record.material)
	if not record.material.lost_material:
		Owned.write(record.visual,"material",record.material.material)
		_normalize_written_material(record.visual)
	item.writes=record.writes.duplicate();item.lost=record.lost.duplicate();item.revoked=record.material.revoked.duplicate();item.lost_material=record.material.lost_material
static func _retire(item: Dictionary) -> void:
	var parent: Variant=item.get("parent")
	if not _object(parent) or not _runner(parent):return
	var g: Session=_group(parent)
	if g==null:return
	var r: Dictionary=_record_item(g,item)
	if not r.is_empty():_retire_record(g,r)
static func _cleanup(r: Dictionary) -> void:
	# No read of mutable item.track, t.clones, or published cleanup Callables.
	var t: Dictionary=r.track
	if not r.item.is_empty():
		r.item.retired=true
		var node: Variant=r.node
		if _object(node) and _sprite(node) and node.get_parent()==r.parent:
			var visual: Dictionary={"node":node,"parent":r.parent,"writes":r.writes,"lost":r.lost}
			Owned.write(visual,"visible",false);node.queue_free()
		r.item.erase("track")
	t.erase("cleanup");t.erase("blizzard_item")
static func _child(s: Dictionary,g: Session) -> Array[Dictionary]:
	# CreateTask allocates now; the child is first invoked by a LATER scheduler pass.
	var state:=Scroll.new();state.creation_tick=int(g.owner.elapsed_ticks);state.parent_line=int(s.source_line);state.parent_callback=str(s.source_task);state.source_callback=str(s.source_child)
	state.data[1]=-2304 if g.side==0 else 2304;state.data[2]=0;state.native=g.entry_offset;state.raw=g.raw_entry
	g.owner.set_meta("source_bg3_xy",state.raw)
	var t: Dictionary={"kind":"source_blizzard_scroll","domain":"maintenance","owner":g.owner,"age":0,"ticks":0x7fffffff,"settings":s.duplicate(true),"blizzard_scroll":state,"update":_scroll,"blizzard_owner":g.owner}
	g.controllers.append(t);g.scrolls.append({"track":t,"state":state,"settings":t.settings.duplicate(true)});_register(g,t,{},state);return [t]
static func _publication(state: Scroll,t: Dictionary,stage: String,g: Session) -> Dictionary:
	return {"stage":stage,"tick":int(g.owner.elapsed_ticks),"age":int(t.age),"raw":[state.raw.x,state.raw.y],"native":[state.native.x,state.native.y],"data":state.data.duplicate(),"ARG7":int(g.owner._source_args.get(7,0))}
static func _scroll(t: Dictionary,c: BattleAnimationContext) -> void:
	if not _controller(t,c):return
	var g: Session=_group(t.owner)
	var actual: Array=g.scrolls.filter(func(record):return is_same(record.track,t) and is_same(t.get("blizzard_scroll"),record.state) and Same._same(t.settings,record.settings))
	if actual.size()!=1:t.ticks=int(t.age);return
	var state: Scroll=actual[0].state
	state.publication=[_publication(state,t,"before",g)]
	state.data[10]=_s16(int(state.data[10])+int(state.data[1]));state.data[11]=_s16(int(state.data[11])+int(state.data[2]))
	var delta:=Vector2i(floori(float(state.data[10])/256.0),floori(float(state.data[11])/256.0))
	state.raw=Vector2i((state.raw.x+delta.x)&65535,(state.raw.y+delta.y)&65535);state.native+=Vector2(delta)
	state.data[10]=int(state.data[10])&255;state.data[11]=int(state.data[11])&255
	t.owner.set_meta("source_bg3_xy",state.raw)
	if not g.restored and not g.bg.is_empty() and Owned.node(g.bg):
		var r: Rect2=g.bg.node.region_rect;r.position=state.native;Owned.write(g.bg,"region_rect",r)
	state.publication.append(_publication(state,t,"moved",g))
	if int(t.owner._source_args.get(7,0))==65535:
		state.raw=Vector2i.ZERO;state.native=g.entry_offset;t.owner.set_meta("source_bg3_xy",state.raw)
		if not g.bg.is_empty() and Owned.node(g.bg):
			var r: Rect2=g.bg.node.region_rect;r.position=g.entry_offset;Owned.write(g.bg,"region_rect",r)
		state.publication.append(_publication(state,t,"reset",g));t.ticks=int(t.age)
static func _s16(n: int) -> int:return ((n+32768)&65535)-32768
static func query_publication(owner: Node2D,s: Dictionary,before: int) -> void:
	if not matches(owner) or not _whole(owner) or owner._pc!=7 or not is_same(s,owner._steps[7]) or not Same._same(s,Data.PROGRAM.steps[7]):return
	var g: Session=_group(owner)
	if g==null or not _valid(g):return
	var rows: Array=owner.get_meta("source_blizzard_query_publications",[])
	rows.append({"pc":int(owner._pc),"source_line":int(s.source_line),"index":int(s.index),"property":str(s.property),"source_task":str(s.source_task),"before":before,"value":int(owner._source_args.get(int(s.index),0)),"owner_id":owner.get_instance_id(),"definition_id":owner.definition.get_instance_id()});owner.set_meta("source_blizzard_query_publications",rows)
static func _background(s: Dictionary,g: Session) -> Array[Dictionary]:
	if g.bg.is_empty():
		var candidate: Variant=g.owner._source_background
		var prior: bool=_sprite(candidate)
		var node: Sprite2D=candidate if prior else null
		if not prior:
			node=Sprite2D.new();g.owner.add_child(node);g.owner._source_background=node
		var baseline: Dictionary={}
		for key: String in Owned.FOLLOW+["transform","visible","texture_repeat","z_index"]:baseline[key]=node.get(key)
		g.bg={"node":node,"parent":node.get_parent(),"writes":{},"lost":{},"baseline":baseline,"prior":prior}
		g.entry_offset=node.region_rect.position if prior else Vector2.ZERO
	_capture_shade(g)
	var t: Dictionary={"kind":"source_background","domain":"background","owner":g.owner,"age":0,"ticks":int(s.ticks),"settings":s.duplicate(true),"blizzard_owner":g.owner,"update":advance_background}
	g.controllers.append(t);_register(g,t);return [t]
static func is_background(owner: Node2D,t: Dictionary) -> bool:
	var g: Session=_group(owner)
	return g!=null and g.controllers.any(func(actual):return is_same(actual,t)) and t.kind=="source_background"
static func advance_background(t: Dictionary,c: BattleAnimationContext) -> void:
	if not _controller(t,c):t.ticks=int(t.age);return
	var g: Session=_group(t.owner);var item: Dictionary=g.bg
	if not Owned.node(item) or not is_same(g.owner._source_background,item.node):t.ticks=int(t.age);return
	var half: int=int(t.settings.source_fade_out_ticks);var age: int=int(t.age)
	var darkness: float=float(age)/half if age<=half else float(int(t.ticks)-age)/half
	_shade_write(g,"transform",g.owner.global_transform.affine_inverse()*c.field.global_transform)
	_shade_write(g,"polygon",PackedVector2Array([Vector2.ZERO,Vector2(240,0),Vector2(240,160),Vector2(0,160)]))
	_shade_write(g,"color",Color(0,0,0,clampf(darkness,0,1)));_shade_write(g,"visible",true)
	if bool(t.settings.restore):
		if age>=half:_restore_bg(g)
	else:
		if age>=half:
			Owned.write(item,"texture",load(str(t.settings.texture)))
			Owned.write(item,"transform",g.owner.global_transform.affine_inverse()*c.field.global_transform)
			Owned.write(item,"centered",false);Owned.write(item,"offset",Vector2.ZERO);Owned.write(item,"hframes",1);Owned.write(item,"vframes",1);Owned.write(item,"frame",0)
			Owned.write(item,"region_enabled",true);Owned.write(item,"region_rect",Rect2(g.entry_offset,Vector2(240,160)));Owned.write(item,"texture_repeat",CanvasItem.TEXTURE_REPEAT_ENABLED)
			Owned.write(item,"flip_h",false);Owned.write(item,"flip_v",false);Owned.write(item,"modulate",Color.WHITE);Owned.write(item,"self_modulate",Color.WHITE);Owned.write(item,"visible",true)
		else:Owned.write(item,"visible",false)
	if age>=int(t.ticks):_restore_shade(g)
static func _restore_bg(g: Session) -> void:
	if g.bg.is_empty() or not Owned.node(g.bg):return
	for key: String in g.bg.baseline:
		if g.bg.writes.has(key):Owned.write(g.bg,key,g.bg.baseline[key])
	g.restored=true
static func _mirrors(t: Dictionary,c: BattleAnimationContext) -> void:
	if not _controller(t,c):return
	var g: Session=_group(t.owner)
	for item: Dictionary in t.clones:
		if item.retired:continue
		if _binding(g,item.actor.id).is_empty():
			_retire_mirror(item,g)
	Pair._advance_pair(t,c);_sync_clones(_record(g,t))
static func after_pose(owner: Node2D,c: BattleAnimationContext) -> void:
	var g: Session=_group(owner)
	if g==null or not is_same(c,g.context):return
	_stamp+=1
	if not _valid(g):return
	for r: Dictionary in g.records:
		if r.retired:continue
		var t: Dictionary=r.track
		if not owner._tracks.any(func(actual):return is_same(actual,t)):continue
		if not _record_shape(g,r):_retire_record(g,r);continue
		if r.kind=="source_blizzard_mirrors":
			for item: Dictionary in t.clones:
				if not item.retired and _binding(g,item.actor.id).is_empty():_retire_mirror(item,g)
			var wrote_material: bool=not t.cleared
			Pair._after_pair_pose(t);_sync_clones(r,wrote_material)
		elif not r.item.is_empty():_project(r.item,g)
static func begin_tick(owner: Node2D,c: BattleAnimationContext) -> void:
	var g: Session=_group(owner)
	if g==null:return
	for id: int in g.bindings:_binding(g,id)
	_stamp+=1
	if c!=g.context or not _valid(g):
		for r: Dictionary in g.records:_retire_record(g,r)
static func terminal(owner: Node2D) -> Array:
	var g: Session=_group(owner);var invalid: Array=[]
	if g==null:return invalid
	for b: Dictionary in g.bindings.values():
		if not _hide_bound({"actor":b.actor},g):invalid.append(b.actor)
		elif g.owner.context==null or not g.owner.context.actors.values().any(func(current):return _actor(current) and is_same(current,b.actor)):release_actor(owner,b.actor)
	for r: Dictionary in g.records:_retire_record(g,r)
	_restore_bg(g);return invalid
static func release(owner: Node2D) -> void:
	var g: Session=_group(owner)
	if g==null:return
	for r: Dictionary in g.records:_retire_record(g,r)
	if not g.bg.is_empty() and not g.bg.prior and Owned.node(g.bg):
		Owned.write(g.bg,"visible",false);g.bg.node.queue_free()
	_restore_shade(g)
	if not g.shade.is_empty() and not g.shade.prior and Owned.node(g.shade):g.shade.node.queue_free()
	g.shade={};g.records.clear();g.objects.clear();g.controllers.clear();g.scrolls.clear();g.bindings.clear();g.bg={};owner.remove_meta(STATE);_calls.erase(owner.get_instance_id())
static func _hide_bound(item: Dictionary,g: Session) -> bool:
	var b: Dictionary=g.bindings.get(item.actor.id,{})
	if b.is_empty() or not _actor(b.get("actor")) or not _sprite(b.get("sprite")) or b.actor.sprite!=b.sprite or b.actor._generation!=b.generation or b.sprite.get_parent()!=b.parent or b.sprite.texture!=b.texture:return false
	if g.owner.context!=null:
		for value: Variant in g.owner.context.actors.values():
			if not _actor(value):continue
			if not is_same(value,b.actor) and _sprite(value.sprite) and value.sprite==b.sprite:return false
	var generation: int=b.actor.slot.animation_generation if _object(b.actor.slot) else int(b.sprite.get_meta("animation_generation",0))
	return generation==b.generation
static func _retire_mirror(item: Dictionary,g: Session) -> void:
	if item.retired:return
	if _hide_bound(item,g):_restore_mirror_hide(item,g)
	else:item.restored=true
	if Owned.node(item):Owned.write(item,"visible",false);item.node.queue_free()
	item.retired=true
static func before_track(owner: Node2D,t: Dictionary) -> bool:
	var g: Session=_group(owner)
	if g==null:return true
	var record: Dictionary=_record(g,t)
	if not record.is_empty() and (not _record_shape(g,record) or not Solar._number(t.get("age"),true) or int(t.age)!=int(record.last_age)):
		_retire_record(g,record);return false
	var actor: Variant=t.get("actor")
	if t.has("actor") and not _actor(actor):
		owner._tracks.erase(t);return false
	if _actor(actor) and g.bindings.has(actor.id):
		var b: Dictionary=_binding(g,actor.id)
		if b.is_empty() or not is_same(actor,b.actor):owner._tracks.erase(t);return false
	return true
static func actor_allowed(owner: Node2D,candidate: Variant) -> bool:
	var g: Session=_group(owner)
	if g==null:return true
	if not _actor(candidate):return false
	if not g.bindings.has(candidate.id):return true
	return not _binding(g,candidate.id).is_empty() and is_same(candidate,g.bindings[candidate.id].actor)
static func note_held_write(owner: Node2D,t: Dictionary,value: Vector2) -> void:
	var g: Session=_group(owner);var a: Variant=t.get("actor")
	if g==null or not _actor(a) or not actor_allowed(owner,a) or not is_same(owner._i159_actor_callback_track,t) or not owner._tracks.any(func(actual):return is_same(actual,t)):return
	g.held[a.id]={"value":value,"applied":false}
static func note_application(owner: Node2D,a: Variant,held: Vector2,approach: Vector2,offset: Vector2) -> void:
	var g: Session=_group(owner)
	if g==null or not _actor(a) or not g.held.has(a.id) or not is_same(owner._i159_actor_apply_actor,a) or not actor_allowed(owner,a):return
	var receipt: Dictionary=g.held[a.id]
	receipt.applied=held==receipt.value and a._offset==held+approach+offset and a.sprite.position==a._expected_position
	receipt.position=a._expected_position;receipt.composed=a._offset
static func after_palette_writer(owner: Node2D,t: Dictionary) -> void:
	var g: Session=_group(owner);var a: Variant=t.get("actor")
	if g==null or not _actor(a) or not actor_allowed(owner,a) or not is_same(owner._i159_actor_callback_track,t) or not owner._tracks.any(func(actual):return is_same(actual,t)):return
	var receipt: Variant=owner._held_blends.get(a.id)
	if typeof(receipt)==TYPE_DICTIONARY:
		g.palettes[a.id]=receipt;g.palette_serial[a.id]=int(g.palette_serial.get(a.id,0))+1
static func handle_palette(owner: Node2D,c: BattleAnimationContext,a: Variant,blend: Dictionary,transient: bool) -> bool:
	var g: Session=_group(owner)
	if g==null:return false
	if not _actor(a):return true
	if not g.bindings.has(a.id):return false
	if c!=g.context or not actor_allowed(owner,a):return true
	var lease: Dictionary=g.material_leases.get(a.id,{})
	if lease.is_empty():
		lease={"material":null,"shader":null,"expected":{},"baseline":{},"wave_active":{},"lost":{},"property_lost":false,"shader_lost":false,"held":false,"applied_receipt":null,"applied_value":{},"applied_fields":{},"applied_serial":-1};g.material_leases[a.id]=lease
	var material: ShaderMaterial=_material_ref(lease.material)
	_observe_material(a,lease)
	lease.held=false;lease.applied_receipt=null;lease.applied_value={};lease.applied_fields={};lease.applied_serial=-1
	if lease.property_lost or lease.shader_lost:return true
	var created_material: bool=false
	if material==null:
		if float(blend.amount)<=0 and not a._owned_grayscale and not a._owned_invert:a.apply_blend(blend.color,blend.amount);return true
		material=a._blend_material
		if material==null:
			material=ShaderMaterial.new();material.shader=load("res://scripts/battle/animations/sequence/palette_blend.gdshader");a._blend_material=material;created_material=true
		if not is_same(a.sprite.material,material):a._previous_material=a.sprite.material;a.sprite.material=material
		lease.material=weakref(material);lease.shader=material.shader
		for p: Dictionary in material.shader.get_shader_uniform_list():
			lease.baseline[str(p.name)]=material.get_shader_parameter(str(p.name))
	if created_material:
		# Actual allocation here grants initial ownership, unlike adoption of
		# another writer's material. Preserve the established explicit defaults.
		for key: String in ["wave_amplitude","wave_phase","wave_height","wave_start","wave_end","wave_scale_x","wave_scale_y"]:
			material.set_shader_parameter(key,64.0 if key=="wave_height" else 0.0)
			lease.expected[key]=material.get_shader_parameter(key)
	var values: Dictionary={"grayscale":a._owned_grayscale,"invert":a._owned_invert,"blend_color":blend.color,"blend_amount":clampf(float(blend.amount),0,1)}
	# A captured baseline is not a lease. Only explicit wave inputs command
	# these fields; a plain color/amount recipe must leave unrelated waves alone.
	for key: String in ["wave_amplitude","wave_phase","wave_height","wave_start","wave_end","wave_scale_x","wave_scale_y"]:
		if blend.has(key):
			values[key]=float(blend[key]);lease.wave_active[key]=true
		elif lease.wave_active.has(key):
			# Ceasing an actual transient restores its captured field once, only
			# while still owned. Keep observing the last write for sticky loss.
			if not lease.lost.has(key):
				material.set_shader_parameter(key,lease.baseline.get(key));lease.expected[key]=material.get_shader_parameter(key)
			lease.wave_active.erase(key)
	for key: String in values:
		if not lease.lost.has(key):material.set_shader_parameter(key,values[key]);lease.expected[key]=material.get_shader_parameter(key)
	lease.held=not transient and g.palettes.has(a.id) and is_same(owner._held_blends.get(a.id),g.palettes[a.id]) and Same._same(blend,g.palettes[a.id])
	if lease.held:
		lease.applied_receipt=g.palettes[a.id];lease.applied_value=g.palettes[a.id].duplicate(true);lease.applied_serial=int(g.palette_serial.get(a.id,0))
		for key: String in ["blend_color","blend_amount"]:
			if not lease.lost.has(key):lease.applied_fields[key]=material.get_shader_parameter(key)
	return true
static func release_actor(owner: Node2D,a: Variant) -> bool:
	var g: Session=_group(owner)
	if g==null:return false
	if not _actor(a):return true
	if not g.bindings.has(a.id):
		for b: Dictionary in g.bindings.values():
			if _sprite(a.sprite) and a.sprite==b.sprite:return true
		return false
	if g.released.has(a.id) or not is_same(a,g.bindings[a.id].actor) or not _hide_bound({"actor":a},g):return true
	var receipt: Dictionary=g.held.get(a.id,{})
	var keep: bool=not receipt.is_empty() and receipt.get("applied",false) and owner._held_offsets.get(a.id)==receipt.value and a.sprite.position==receipt.position and a._offset==receipt.composed
	var lease: Dictionary=g.material_leases.get(a.id,{})
	_observe_material(a,lease)
	if not lease.is_empty():
		var current: Variant=owner._held_blends.get(a.id)
		lease.held=lease.held and typeof(current)==TYPE_DICTIONARY and g.palettes.has(a.id) and is_same(current,lease.applied_receipt) and is_same(g.palettes[a.id],lease.applied_receipt) and int(g.palette_serial.get(a.id,0))==int(lease.applied_serial) and Same._same(current,lease.applied_value)
	var material: Material=a.sprite.material
	var retain: bool=not lease.is_empty() and (lease.property_lost or lease.shader_lost or lease.held or not lease.lost.is_empty())
	var properties: Dictionary={}
	if retain and _shader(material):
		for p: Dictionary in material.shader.get_shader_uniform_list():
			var key: String=str(p.name)
			if lease.property_lost or lease.shader_lost or lease.lost.has(key) or (lease.held and lease.applied_fields.has(key) and not lease.lost.has(key) and Same._same(material.get_shader_parameter(key),lease.applied_fields[key])):properties[key]=material.get_shader_parameter(key)
	a.release()
	if not _hide_bound({"actor":a},g):return true
	if keep:a.add_layout_offset(receipt.value)
	if retain:
		a.sprite.material=material
		if _shader(material):
			if not lease.property_lost and not lease.shader_lost:
				for key: String in lease.expected:
					if not properties.has(key):material.set_shader_parameter(key,lease.baseline.get(key))
			for key: String in properties:material.set_shader_parameter(key,properties[key])
	g.released[a.id]=true;return true

static func query_side(owner: Node2D) -> Variant:
	if not matches(owner):return null
	var g: Session=_group(owner)
	return g.side if g!=null and _valid(g,true) else -1
static func sound_side(owner: Node2D,incoming: Dictionary) -> Variant:
	# Sound commands use the original admitted source side, not a live visual.
	if not matches(owner):return null
	var g: Session=_group(owner)
	if g==null or not _valid(g,true) or g.side not in [0,1]:return -1
	var pc: int=owner._pc
	if pc<0 or pc>=Data.PROGRAM.steps.size() or not is_same(incoming,owner._steps[pc]):return -1
	var expected: Dictionary=Data.PROGRAM.steps[pc]
	if expected.get("op")!="sound" or not Same._same(incoming,expected):return -1
	return g.side
static func _raw_provider(c: BattleAnimationContext) -> Array:
	# Optional source-register input, NOT a projection of fractional native ART.
	# Context metadata is immutable admission input; owner metadata is live output.
	if not c.has_meta("source_bg3_xy"):return [false,Vector2i.ZERO]
	var raw: Variant=c.get_meta("source_bg3_xy")
	if typeof(raw)!=TYPE_VECTOR2I or raw.x<0 or raw.x>65535 or raw.y<0 or raw.y>65535:return []
	return [true,raw]
static func _register(g: Session,t: Dictionary,item: Dictionary={},state: Variant=null) -> void:
	g.records.append({"track":t,"kind":t.kind,"settings":t.get("settings",{}).duplicate(true),"update":t.get("update",Callable()),"item":item,"node":t.get("node"),"parent":g.owner,"state":state,"last_age":-1 if not item.is_empty() else 0,"writes":item.get("writes",{}).duplicate(),"lost":item.get("lost",{}).duplicate(),"retired":false,"clones":t.get("clones",[]).map(_capture_clone)})
	if not item.is_empty():
		var r: Dictionary=g.records.back()
		r.visual={"node":r.node,"parent":r.parent,"writes":r.writes,"lost":r.lost}
		r.material={"node":r.node,"parent":r.parent,"material":item.material,"shader":item.shader,"uniforms":item.uniforms.duplicate(),"revoked":item.revoked.duplicate(),"lost_material":false}
		r.particle={}
		for key: String in ["texture","factor","tile","small","heavy","origin","velocity"]:r.particle[key]=item[key].duplicate(true) if typeof(item[key])==TYPE_DICTIONARY else item[key]
static func _record_item(g: Session,item: Dictionary) -> Dictionary:
	for r: Dictionary in g.records:
		if not r.item.is_empty() and is_same(r.item,item):return r
	return {}
static func _record(g: Session,t: Dictionary) -> Dictionary:
	for record: Dictionary in g.records:
		if is_same(record.track,t):return record
	return {}
static func _delegates(actual: Variant,original: Callable) -> bool:
	if typeof(actual)!=TYPE_CALLABLE or not actual.is_valid():return false
	if actual==original:return true
	# A passive observer may wrap the genuine static callback. This check does
	# not grant authority: the exact scheduler/immediate lane is required too.
	var count: int=0
	for bound: Variant in actual.get_bound_arguments():
		if typeof(bound)==TYPE_CALLABLE and bound==original:count+=1
	return count==1
static func _record_shape(g: Session,r: Dictionary) -> bool:
	var t: Dictionary=r.track
	if r.retired or typeof(t.get("kind"))!=TYPE_STRING or t.kind!=r.kind or not _object(t.get("owner")) or not is_same(t.owner,g.owner) or (t.has("blizzard_owner") and (not _object(t.blizzard_owner) or not is_same(t.blizzard_owner,g.owner))):return false
	if not Same._same(t.get("settings",{}),r.settings) or not _delegates(t.get("update"),r.update):return false
	if not Solar._number(t.get("age"),true) or not Solar._number(t.get("ticks"),true) or int(t.age)<0 or int(t.ticks)<0:return false
	if not r.item.is_empty():
		if typeof(r.item.get("retired"))!=TYPE_BOOL or not _object(r.item.get("parent")) or not is_same(r.item.parent,r.parent) or not _sprite(r.item.get("node")) or not is_same(r.item.node,r.node):return false
		if not is_same(t.get("blizzard_item"),r.item) or not is_same(r.item.get("track"),t):return false
		if typeof(r.item.get("settings"))!=TYPE_DICTIONARY or not Same._same(r.item.settings,r.settings) or _rects(r.item.settings).is_empty():return false
		for key: String in r.particle:
			if not _field_same(r.item.get(key),r.particle[key]):return false
		for key: String in ["point","base"]:
			if typeof(r.item.get(key))!=TYPE_VECTOR2 or not r.item[key].is_finite():return false
		if not Solar._number(r.item.get("callback_age"),true) or typeof(r.item.get("affine_end"))!=TYPE_BOOL or typeof(r.item.get("delegate"))!=TYPE_BOOL:return false
		if not _property_map(r.item.get("writes"),r.writes) or not _bool_map(r.item.get("lost"),r.lost):return false
		if not _field_same(r.item.get("material"),r.material.material) or not _field_same(r.item.get("shader"),r.material.shader):return false
		if typeof(r.item.get("uniforms"))!=TYPE_DICTIONARY or not _uniform_map(r.item.uniforms,r.material.uniforms) or not _bool_map(r.item.get("revoked"),r.material.revoked) or typeof(r.item.get("lost_material"))!=TYPE_BOOL or r.item.lost_material!=r.material.lost_material:return false
		var node: Variant=t.get("node")
		if not _object(node) or not _sprite(node) or not is_same(node,r.node) or node.is_queued_for_deletion() or node.get_parent()!=r.parent:return false
	if r.state!=null:
		if not _object(t.get("blizzard_scroll")) or not _object(r.state) or not is_same(t.blizzard_scroll,r.state) or typeof(r.state.data)!=TYPE_ARRAY or r.state.data.size()!=12:return false
		for value: Variant in r.state.data:
			if not Solar._number(value,true):return false
	if r.kind=="source_blizzard_mirrors":
		if not _actors_typed(g.context):return false
		if not is_same(t.get("context"),g.context) or typeof(t.get("clones"))!=TYPE_ARRAY or t.clones.size()!=r.clones.size():return false
		for index: int in r.clones.size():
			if not _clone_shape(t.clones[index],r.clones[index]):return false
	return true
static func _retire_record(g: Session,r: Dictionary) -> void:
	if r.retired:return
	r.retired=true
	var t: Dictionary=r.track
	if not r.item.is_empty():_cleanup(r)
	elif r.kind=="source_blizzard_mirrors":
		for item: Dictionary in r.clones:_retire_mirror(item,g)
		t.erase("cleanup");t.erase("clones")
	if Solar._number(t.get("age"),true):t.ticks=int(t.age)
	g.owner._tracks.erase(t)
static func _observe_material(a: BattleAnimationActor,lease: Dictionary) -> void:
	if lease.is_empty() or not _weak(lease.material):return
	var material: Variant=lease.material.get_ref()
	if not _shader(material) or not is_same(a.sprite.material,material):lease.property_lost=true;return
	if not is_same(material.shader,lease.shader):lease.shader_lost=true;return
	for key: String in lease.expected:
		if not Same._same(material.get_shader_parameter(key),lease.expected[key]):lease.lost[key]=true
static func _capture_shade(g: Session) -> void:
	if not g.shade.is_empty():return
	var candidate: Variant=g.owner._source_blackout;var prior: bool=_object(candidate) and candidate is Polygon2D
	var node: Polygon2D=candidate if prior else null
	if not prior:
		node=Polygon2D.new();g.owner.add_child(node);g.owner._source_blackout=node
	var baseline: Dictionary={}
	for key: String in ["transform","color","visible","polygon","z_index"]:baseline[key]=node.get(key)
	g.shade={"node":node,"parent":node.get_parent(),"prior":prior,"baseline":baseline,"writes":baseline.duplicate(),"lost":{},"identity_lost":false}
static func _shade_write(g: Session,key: String,value: Variant) -> void:
	if g.shade.is_empty():return
	var item: Dictionary=g.shade
	if not is_same(g.owner._source_blackout,item.node) or not Owned.node(item):item.identity_lost=true
	if not item.identity_lost:Owned.write(item,key,value)
static func _restore_shade(g: Session) -> void:
	if g.shade.is_empty():return
	if not is_same(g.owner._source_blackout,g.shade.node) or not Owned.node(g.shade):g.shade.identity_lost=true
	if g.shade.identity_lost:return
	for key: String in g.shade.baseline:
		if g.shade.writes.has(key):Owned.write(g.shade,key,g.shade.baseline[key])
static func terminal_actor_allowed(owner: Node2D,candidate: Variant) -> bool:
	return _group(owner)==null or _actor(candidate)
static func finish_context_loss(owner: Node2D,terminal_state: String="cancelled") -> bool:
	var g: Session=_group(owner)
	if g==null or owner.context==g.context:return false
	# Do not lend the captured context to generic consumers or overwrite the
	# live replacement context. Cleanup authority remains on original bindings.
	g.valid=false;owner.state=terminal_state
	for record: Dictionary in g.records:_retire_record(g,record)
	_restore_bg(g);_restore_shade(g)
	for b: Dictionary in g.bindings.values():release_actor(owner,b.actor)
	for track: Dictionary in owner._tracks:
		if typeof(track.get("cleanup"))==TYPE_CALLABLE and track.cleanup.is_valid():track.cleanup.call()
	owner._tracks.clear()
	for lease: BattleOwnedAppearanceLease in owner._appearance_leases:lease.finalize(false)
	owner._appearance_leases.clear()
	for player: Variant in owner._sounds:
		if _object(player) and player is AudioStreamPlayer2D:player.stop()
	owner._sounds.clear();owner._source_palette_banks.clear()
	release(owner)
	owner.terminated.emit(owner.state);owner.queue_free();return true
static func _restore_mirror_hide(item: Dictionary,g: Session) -> void:
	if item.restored:return
	item.restored=true
	var actor: BattleAnimationActor=item.actor
	if item.projection!=null:item.projection.release_view();return
	# _hide_bound checked the live map without feeding malformed Variants into
	# Pair's typed Actor loop. Restore only the independent hide contribution.
	if actor._owned_hidden and not actor._expected_visible:
		if not item.sprite.visible:item.sprite.visible=item.base_visible
		actor._owned_hidden=false
static func _object(value: Variant) -> bool:return typeof(value)==TYPE_OBJECT and is_instance_valid(value)
static func _actor(value: Variant) -> bool:return _object(value) and value is BattleAnimationActor
static func _runner(value: Variant) -> bool:return _object(value) and value is BattleAnimationSequenceRunner
static func _sprite(value: Variant) -> bool:return _object(value) and value is Sprite2D
static func _shader(value: Variant) -> bool:return _object(value) and value is ShaderMaterial
static func _texture(value: Variant) -> bool:return _object(value) and value is Texture2D
static func _weak(value: Variant) -> bool:return _object(value) and value is WeakRef
static func _definition_object(value: Variant) -> bool:return _object(value) and value is BattleAnimationDefinition
static func _material_ref(value: Variant) -> ShaderMaterial:
	if not _weak(value):return null
	var raw: Variant=value.get_ref()
	return raw as ShaderMaterial if _shader(raw) else null
static func _invocation(owner: Node2D) -> Invocation:
	var value: Variant=_calls.get(owner.get_instance_id())
	return value as Invocation if _object(value) and value is Invocation else null
static func _load_texture(path: String) -> Texture2D:
	var value: Variant=Fast.texture(path)
	return value as Texture2D if _texture(value) else null
static func _field_same(actual: Variant,expected: Variant) -> bool:
	if typeof(actual)!=typeof(expected):return false
	if typeof(expected)==TYPE_OBJECT:return _object(actual) and _object(expected) and is_same(actual,expected)
	return Same._same(actual,expected)
static func _bool_map(actual: Variant,expected: Dictionary) -> bool:
	if typeof(actual)!=TYPE_DICTIONARY or actual.size()!=expected.size():return false
	for key: Variant in actual:
		if typeof(key) not in [TYPE_STRING,TYPE_STRING_NAME] or typeof(actual[key])!=TYPE_BOOL or not expected.has(key) or actual[key]!=expected[key]:return false
	return true
static func _property_value(key: String,value: Variant) -> bool:
	match key:
		"texture":return value==null if typeof(value)==TYPE_NIL else _texture(value)
		"material":return typeof(value)==TYPE_NIL or (_object(value) and value is Material)
		"centered","region_enabled","flip_h","flip_v","visible":return typeof(value)==TYPE_BOOL
		"hframes","vframes","frame","z_index":return typeof(value)==TYPE_INT
		"transform":return typeof(value)==TYPE_TRANSFORM2D
		"offset":return typeof(value)==TYPE_VECTOR2
		"region_rect":return typeof(value)==TYPE_RECT2
		"modulate","self_modulate":return typeof(value)==TYPE_COLOR
	return false
static func _property_map(actual: Variant,expected: Dictionary) -> bool:
	if typeof(actual)!=TYPE_DICTIONARY or actual.size()!=expected.size():return false
	for key: Variant in actual:
		if typeof(key) not in [TYPE_STRING,TYPE_STRING_NAME] or not expected.has(key) or not _property_value(str(key),actual[key]) or not _field_same(actual[key],expected[key]):return false
	return true
static func _uniform_map(actual: Dictionary,expected: Dictionary) -> bool:
	if actual.size()!=expected.size():return false
	for key: Variant in actual:
		if typeof(key) not in [TYPE_STRING,TYPE_STRING_NAME] or not expected.has(key) or not _field_same(actual[key],expected[key]):return false
	return true
static func _clone_snapshot(value: Dictionary) -> Dictionary:
	var result: Dictionary=value.duplicate()
	result.writes=value.writes.duplicate();result.lost=value.lost.duplicate()
	return result
static func _clone_shape(actual: Variant,frozen: Dictionary) -> bool:
	if typeof(actual)!=TYPE_DICTIONARY:return false
	if frozen.retired:return typeof(actual.get("retired"))==TYPE_BOOL and actual.retired and typeof(actual.get("restored"))==TYPE_BOOL and actual.restored==frozen.restored
	# Pair._pair_bound has typed owner/Actor sinks: validate before entering it.
	if not _object(actual.get("parent")) or not actual.parent is Node2D or not _object(actual.get("sprite_parent")) or not actual.sprite_parent is Node2D:return false
	if not _actor(actual.get("actor")) or not _sprite(actual.get("node")) or not _sprite(actual.get("sprite")):return false
	for key: String in ["actor","node","sprite","parent","sprite_parent","texture","slot","projection","context","definition","definition_key","script","operand","primary","contest","position","bg_plane","generation","base_visible","retired","restored"]:
		if not actual.has(key) or not frozen.has(key) or not _field_same(actual[key],frozen[key]):return false
	return _property_map(actual.get("writes"),frozen.writes) and _bool_map(actual.get("lost"),frozen.lost)
static func _sync_clones(r: Dictionary,wrote_material: bool=false) -> void:
	# A callback that only checks lifetime/binding does NOT grant a material
	# normalization boundary. Follow/clear explicitly report their own writes.
	if wrote_material:
		for item: Dictionary in r.track.clones:
			if not item.retired:_normalize_written_material(item)
	r.clones=r.track.clones.map(_clone_snapshot)
static func _actors_typed(c: BattleAnimationContext) -> bool:
	for value: Variant in c.actors.values():
		if not _actor(value):return false
	return true
static func _native_material(node: Sprite2D) -> Variant:
	# ONLY a live typed Sprite getter at genuine construction/write boundaries.
	# A Sprite's typed Resource reference cannot contain a freed Node. The same
	# ==null test is UNSAFE for exposed Variant maps and is never used there.
	var material: Material=node.material
	if material==null:return null
	return material
static func _native_shader(material: ShaderMaterial) -> Variant:
	var shader: Shader=material.shader
	if shader==null:return null
	return shader
static func _normalize_written_material(visual: Dictionary) -> void:
	# Called only after an admitted genuine Owned/FOLLOW material write. A lost
	# field was not written: leave its maps and the foreign property untouched.
	if visual.lost.has("material") or not _sprite(visual.node):return
	for key: Variant in visual.writes:
		if typeof(key) in [TYPE_STRING,TYPE_STRING_NAME] and str(key)=="material":
			visual.writes[key]=_native_material(visual.node);return
static func _capture_clone(value: Dictionary) -> Dictionary:
	# Only Pair._create_pair_bg outputs reach this trusted creation boundary.
	# Do not read nullness from an arbitrary exposed projection Variant.
	var projection: BattleHiddenProjection=value.actor.hidden_projection
	value.projection=null if projection==null else projection
	_normalize_written_material(value)
	return _clone_snapshot(value)

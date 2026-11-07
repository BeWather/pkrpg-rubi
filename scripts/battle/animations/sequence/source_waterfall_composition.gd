extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Finite Waterfall registers. Independent native compositor channels stay separate.
const Data=preload("res://scripts/battle/animations/sequence/source_waterfall_data.gd")
const Same=preload("res://scripts/battle/animations/sequence/source_cutting_slice.gd")
const Solar=preload("res://scripts/battle/animations/sequence/source_solar_beam_composition.gd")
const Capture=preload("res://scripts/battle/animations/sequence/source_stockpile_composition.gd")
const Geometry=preload("res://scripts/battle/animations/sequence/source_petal_composition.gd")
const Coordinates=preload("res://scripts/battle/animations/sequence/source_coordinate_contract.gd")
const Owned=preload("res://scripts/battle/animations/sequence/source_owned_composition.gd")
const Pair=preload("res://scripts/battle/animations/sequence/source_charge_owned.gd")
const COMBINED=preload("res://scripts/battle/animations/sequence/source_agility_aerial_palette_ab.gdshader")
const STATE="i169_waterfall_session"
static var _calls: Dictionary={}
# Proof memo: the deep program/definition comparison costs ~0.3 ms and used to run
# several times per particle per tick. A session proof stays valid until control
# leaves this module (dispatch open/close, births, tick/pose boundaries) which
# bumps the stamp; the next _valid then re-proves in full.
static var _stamp: int=0
# Nobody else holds the step textures, so ResourceCache drops them and every
# load(path) in proof/rect checks re-decoded the PNG from disk (~1 ms each).
static var _textures: Dictionary={}
static func _load_texture(path: String) -> Texture2D:
	var cached: Variant=_textures.get(path)
	if cached is Texture2D and is_instance_valid(cached):return cached
	var texture: Texture2D=load(path) as Texture2D
	if texture!=null:_textures[path]=texture
	return texture
class Invocation extends RefCounted:
	var incoming: Dictionary
	var context: BattleAnimationContext
	var definition: BattleAnimationDefinition
	var pc: int
	var claimed: bool=false
	var physical: Dictionary={}
	var physical_consumed: bool=false
	var roles: Array=[]
	var initial: Dictionary={}
class Session extends RefCounted:
	var owner: Node2D
	var context: BattleAnimationContext
	var definition: BattleAnimationDefinition
	var roles: Array=[]
	var program: Array=[]
	var program_keys: Array=[]
	var rect_keys: Dictionary={}
	var resource_guards: Array=[]
	var bindings: Dictionary={}
	var lost: Dictionary={}
	var offsets: Dictionary={}
	var offset_writers: Dictionary={}
	var actor_receipts: Array=[]
	var writers: Dictionary={}
	var motion_lost: Dictionary={}
	var palettes: Dictionary={}
	var material_leases: Dictionary={}
	var objects: Array=[]
	var actors: Array=[]
	var valid: bool=true
	var released: Dictionary={}
	var proof_stamp: int=-1
static func matches(owner: Node2D) -> bool:
	if not owner is BattleAnimationSequenceRunner or owner.definition==null:return false
	var original: Variant=BattleAnimationSequenceRegistry._builtin_source_definitions.get("ruby:move/127")
	return original is BattleAnimationDefinition and is_same(owner.definition,original)
static func _group(owner: Node2D) -> Session:return owner.get_meta(STATE) as Session if owner.has_meta(STATE) else null
static func _roles(c: BattleAnimationContext) -> Array:return [c.attacker_id,c.target_ids.duplicate(),c.contest]
static func _rects(s: Dictionary) -> Dictionary:
	var raw: Variant=s.get("texture")
	var texture: Texture2D=null
	if raw is Texture2D:texture=raw
	elif raw is String and ResourceLoader.exists(raw):texture=_load_texture(raw)
	if texture==null or texture.get_width()<=0 or texture.get_height()<=0:return {}
	if s.has("scale_factor") and (not Solar._number(s.scale_factor) or float(s.scale_factor)<=0):return {}
	for key: String in ["recolor","flip_h","flip_v"]:
		if s.has(key) and typeof(s[key])!=TYPE_BOOL:return {}
	if s.has("color") and (not s.color is String or not Color.html_is_valid(s.color)):return {}
	var tiles: Array=[12,13] if s.get("source_callback")=="sub_80D3838" else [8] if s.get("source_callback")=="sub_80D4044" else [0]
	var out: Dictionary={}
	if s.has("frame_rects"):
		if not s.frame_rects is Dictionary:return {}
		for key: Variant in s.frame_rects:
			if not key is String or not key.is_valid_int() or not tiles.has(int(key)):return {}
			var rect: Variant=s.frame_rects[key]
			if not rect is Array or rect.size()!=4:return {}
			for n: Variant in rect:
				if not Solar._number(n,true):return {}
			out[key]=rect.duplicate()
	else:
		var size: Variant=s.get("frame_size")
		if not size is Array or size.size()!=2:return {}
		for n: Variant in size:
			if not Solar._number(n,true) or n<=0:return {}
		var columns: int=texture.get_width()/8
		if columns<1:return {}
		for tile: int in tiles:out[str(tile)]=[0,0,size[0],size[1]] if texture.get_size()==Vector2(size[0],size[1]) else [(tile%columns)*8,(tile/columns)*8,size[0],size[1]]
	for tile: int in tiles:
		if not out.has(str(tile)):return {}
	for rect: Array in out.values():
		if rect[0]<0 or rect[1]<0 or rect[2]<=0 or rect[3]<=0 or rect[0]+rect[2]>texture.get_width() or rect[1]+rect[3]>texture.get_height():return {}
	return out
static func _shape(s: Variant,e: Dictionary) -> bool:
	if not s is Dictionary:return false
	var art: bool=e.get("behavior")=="source_particle"
	for key: String in e:
		if art and key in Solar.ART:continue
		if not s.has(key) or not Same._same(s[key],e[key]):return false
	for key: Variant in s:
		if typeof(key)!=TYPE_STRING and not (typeof(key)==TYPE_STRING_NAME and art and str(key) in Solar.ART):return false
		if not e.has(str(key)) and (not art or str(key) not in Solar.ART):return false
	return not art or not _rects(s).is_empty()
static func _whole(owner: Node2D) -> bool:
	if not matches(owner) or owner.definition.key!=Data.PROGRAM.key or owner.definition.coverage!=Data.PROGRAM.coverage or owner.definition.source_script!=Data.PROGRAM.source_script or owner._steps.size()!=229 or not Same._same(owner._steps,owner.definition.steps):return false
	for pc: int in 229:
		if not _shape(owner._steps[pc],Data.PROGRAM.steps[pc]):return false
	return true
static func accepts_texture_dependency(definition: BattleAnimationDefinition,step: Dictionary) -> bool:
	# Public definition validation happens BEFORE a runner has copied _steps.
	# Pure definition/Resource proof: no invocation, session or runtime mutation.
	var original: Variant=BattleAnimationSequenceRegistry._builtin_source_definitions.get("ruby:move/127")
	if not original is BattleAnimationDefinition or not is_same(definition,original) or definition.schema_version!=1 or definition.key!=Data.PROGRAM.key or definition.coverage!=Data.PROGRAM.coverage or definition.source_script!=Data.PROGRAM.source_script or definition.steps.size()!=229:return false
	if not step.get("texture") is Texture2D or step.get("op")!="effect" or step.get("behavior")!="source_particle":return false
	var member: bool=false
	for pc: int in 229:
		if not _shape(definition.steps[pc],Data.PROGRAM.steps[pc]):return false
		if is_same(definition.steps[pc],step):member=true
	return member and not _rects(step).is_empty()
static func physical_entry(s: Dictionary,c: BattleAnimationContext,owner: Node2D,kind: String) -> bool:
	# Consume only the genuine admitted synchronous delegation, at registry ENTRY.
	if kind!="source_particle" or not owner is BattleAnimationSequenceRunner:return false
	var call: Invocation=_calls.get(owner.get_instance_id()) as Invocation;var g: Session=_group(owner)
	if call==null or g==null or not call.claimed or call.physical_consumed or call.physical.is_empty() or not is_same(call.physical,s) or call.context!=c or owner.context!=c or call.definition!=owner.definition or call.pc!=owner._pc or not owner._i159_dispatch_live or not Same._same(call.roles,_roles(c)) or not _valid(owner,g):return false
	if s.get("mode")!="static" or not Same._same(s.get("offset"),[0,0]) or s.get("offset_direction")!="" or s.get("mirror_offset")!=false or s.get("seeded_splash")!=false or not Same._same(s.get("affine_program"),[]):return false
	call.physical_consumed=true;return true
static func open_dispatch(owner: Node2D,s: Dictionary) -> Invocation:
	if not matches(owner) or _calls.has(owner.get_instance_id()):return null
	_stamp+=1
	var call:=Invocation.new();call.incoming=s;call.context=owner.context;call.definition=owner.definition;call.pc=owner._pc;call.roles=_roles(owner.context);_calls[owner.get_instance_id()]=call;return call
static func close_dispatch(owner: Node2D,call: Invocation) -> void:
	_stamp+=1
	if call!=null and is_same(_calls.get(owner.get_instance_id()),call):_calls.erase(owner.get_instance_id())
static func _valid(owner: Node2D,g: Session,memo: bool=false) -> bool:
	if not g.valid:return false
	if owner.context!=g.context or owner.definition!=g.definition or not Same._same(_roles(g.context),g.roles) or not matches(owner) or owner.definition.key!=Data.PROGRAM.key or owner.definition.coverage!=Data.PROGRAM.coverage or owner.definition.source_script!=Data.PROGRAM.source_script:
		g.valid=false;return false
	if memo and g.proof_stamp==_stamp:return true
	# Native equality is a strict fast SUCCESS, not a replacement for Same's
	# asymmetric numeric compatibility. Key arrays also prove _shape's key types.
	if owner._steps==owner.definition.steps and owner._steps==g.program and _keys_match(owner._steps,g):
		if not _resources_valid(g):g.valid=false
	elif not _whole(owner) or not Same._same(owner._steps,g.program):g.valid=false
	if g.valid:g.proof_stamp=_stamp
	return g.valid
static func _keys_match(program: Array,g: Session) -> bool:
	if program.size()!=g.program_keys.size():return false
	for pc: int in program.size():
		var step: Dictionary=program[pc]
		if step.keys()!=g.program_keys[pc]:return false
		if g.rect_keys.has(pc) and step.frame_rects.keys()!=g.rect_keys[pc]:return false
	return true
static func _texture_size(raw: Variant) -> Vector2:
	var texture: Texture2D=null
	if raw is Texture2D:texture=raw
	elif raw is String and ResourceLoader.exists(raw):texture=_load_texture(raw)
	return texture.get_size() if texture!=null else Vector2.ZERO
static func _capture_program_proof(g: Session) -> void:
	var resources: Dictionary={}
	for pc: int in g.program.size():
		var step: Dictionary=g.program[pc]
		g.program_keys.append(step.keys())
		if step.get("behavior")!="source_particle":continue
		if step.get("frame_rects") is Dictionary:g.rect_keys[pc]=step.frame_rects.keys()
		var raw: Variant=step.texture
		if not resources.has(raw):
			var guard: Dictionary={"raw":raw,"dimensions":_texture_size(raw),"settings":[]}
			resources[raw]=guard;g.resource_guards.append(guard)
		resources[raw].settings.append(step)
static func _resources_valid(g: Session) -> bool:
	for guard: Dictionary in g.resource_guards:
		# Keep path existence and mutable Texture2D dimensions live at EVERY
		# publication boundary. Unchanged dimensions inherit admitted rect proof.
		var dimensions: Vector2=_texture_size(guard.raw)
		if dimensions.x<=0 or dimensions.y<=0:return false
		if dimensions==guard.dimensions:continue
		for settings: Dictionary in guard.settings:
			if _rects(settings).is_empty():return false
		guard.dimensions=dimensions
	return true
static func _live_clear(b: Dictionary,g: Session) -> bool:
	if g.owner.context==null:return true
	for value: Variant in g.owner.context.actors.values():
		if not value is BattleAnimationActor:return false
		if not is_same(value,b.actor) and is_instance_valid(value.sprite) and value.sprite==b.sprite:return false
	return true
static func _original_bound(b: Dictionary,g: Session) -> bool:
	if not b.get("actor") is BattleAnimationActor or not is_instance_valid(b.get("sprite")):return false
	var current: Variant=g.context.actors.get(b.actor.id)
	return current is BattleAnimationActor and is_same(current,b.actor) and Capture._bound(b,g.context) and b.actor.side==b.side and Same._same(Geometry._frame(b.sprite),b.frame) and _live_clear(b,g)
static func _binding(g: Session,id: int) -> Dictionary:
	if g.lost.has(id):return {}
	var b: Dictionary=g.bindings.get(id,{})
	if not b.is_empty() and not _original_bound(b,g):g.lost[id]=true;return {}
	return b
static func _session(owner: Node2D,c: BattleAnimationContext) -> Session:
	var g: Session=_group(owner)
	if g!=null:return g
	g=Session.new();g.owner=owner;g.context=c;g.definition=owner.definition;g.roles=_roles(c);g.program=owner._steps.duplicate(true)
	# _session is reached only after genuine _admit's complete canonical proof.
	_capture_program_proof(g)
	for key: Variant in c.actors:
		if typeof(key)!=TYPE_INT:continue
		var value: Variant=c.actors[key]
		if not value is BattleAnimationActor or value.id!=key:continue
		# Reuse only pure captured source geometry, never another producer's authority.
		var b: Dictionary=Geometry._capture(c,int(key))
		if not b.is_empty():
			# Coordinate receipts govern future births, never actor restoration or
			# already-born independent endpoints. Keep Geometry's ART capture intact.
			b.source_coordinates_lost=false
			for domain: String in ["source_visual","source_nominal"]:
				var provider: Variant=c.get(domain).get(key)
				b[domain]=provider
				b[domain+"_snapshot"]=provider.duplicate(true) if provider is Dictionary else provider
			g.bindings[key]=b
	owner.set_meta(STATE,g);return g
static func _coordinates(g: Session,b: Dictionary) -> Dictionary:
	if b.source_coordinates_lost:return {}
	for domain: String in ["source_visual","source_nominal"]:
		if not is_same(g.context.get(domain).get(b.actor.id),b[domain]) or not Same._same(b[domain],b[domain+"_snapshot"]):
			b.source_coordinates_lost=true;return {}
	var body: Dictionary=Coordinates.visual(b.actor,g.context)
	var nominal: Dictionary=Coordinates.nominal(b.actor,g.context)
	if body.state=="invalid" or nominal.state=="invalid":b.source_coordinates_lost=true;return {}
	return {"body":body.point if body.state=="valid" else b.center,"nominal":nominal.point if nominal.state=="valid" else b.origin}
static func _admit(s: Dictionary,c: BattleAnimationContext,owner: Node2D,kind: String) -> bool:
	var call: Invocation=_calls.get(owner.get_instance_id()) as Invocation;var g: Session=_group(owner)
	if call==null or call.claimed or not is_same(call.incoming,s) or call.context!=c or owner.context!=c or call.definition!=owner.definition or call.pc!=owner._pc or not owner._i159_dispatch_live or not Same._same(call.roles,_roles(c)):return false
	if not (_whole(owner) if g==null else _valid(owner,g)):return false
	if call.pc<=0 or call.pc>=229:return false
	var expected: Dictionary=Data.PROGRAM.steps[call.pc]
	if expected.get("behavior")!=kind:return false
	var plain: Dictionary=s.duplicate(true);var priority: Dictionary=BattleSourcePriority.command_metadata(Data.PROGRAM.steps[call.pc-1])
	if not priority.is_empty():
		if not Same._same(plain.get("source_command_priority"),priority):return false
		plain.erase("source_command_priority")
	elif plain.has("source_command_priority"):return false
	if not _shape(plain,expected) or not Same._same(plain,owner._steps[call.pc]) or not owner.claim_effect_dispatch(s):return false
	call.claimed=true;return true
static func effect(s: Dictionary,c: BattleAnimationContext,owner: Node2D,kind: String,physical: bool=false) -> Variant:
	var call: Invocation=_calls.get(owner.get_instance_id()) as Invocation
	if call!=null and not call.physical.is_empty() and is_same(call.physical,s):return null if physical and call.physical_consumed and call.context==c else []
	var g: Session=_group(owner)
	if g!=null and not _valid(owner,g):return []
	if not matches(owner):return null
	if kind not in ["source_particle","actor_motion","source_actor","source_legacy_impact_command"] or not _admit(s,c,owner,kind):return []
	g=_session(owner,c)
	if kind=="source_legacy_impact_command":return _command(s,c,owner,g)
	var target: bool=s.get("selector")=="target"
	var id: int=c.target_ids[0] if target and not c.target_ids.is_empty() else -1 if target else c.attacker_id
	var b: Dictionary=_binding(g,id)
	if b.is_empty():return []
	if kind=="source_particle":return _particle(s,c,owner,g,b,call)
	var t: Dictionary={"kind":"source_waterfall_actor","age":0,"ticks":16 if kind=="actor_motion" else int(s.ticks),"actor":b.actor,"owner":owner,"settings":s.duplicate(true),"waterfall_id":id,"start":g.offsets.get(id,Vector2.ZERO),"callback_age":0}
	g.actors.append(t);g.actor_receipts.append({"track":t,"id":id,"settings":t.settings.duplicate(true),"retired":false})
	if kind=="source_actor":
		var previous: Vector2=g.offsets.get(id,Vector2.ZERO)
		g.offsets[id]=Vector2(float(s.x),float(s.y));g.offset_writers[id]=t;call.initial=t
		if not g.writers.has(id) and not g.motion_lost.has(id):b.actor.apply(b.actor._offset+_parent_offset(g,id,g.offsets[id]-previous),b.actor._tint)
		call.initial={}
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
	if g==null:return
	_guard_bg(t,g)
	if c!=g.context or not _valid(t.owner,g):Pair._clear_pair(t)
	# Cleanup retains captured original binding authority even if live context is replaced.
	Pair._advance_pair(t,g.context)
static func _direction(g: Session,b: Dictionary,point: Vector2) -> int:
	var other: Dictionary=g.bindings.get(g.roles[1][0],{}) if not g.roles[1].is_empty() else {}
	if not other.is_empty():
		var target: Dictionary=_coordinates(g,other)
		if target.is_empty():return 0
		if point.x<target.nominal.x:return 1
		if point.x>target.nominal.x:return -1
	return 1 if int(b.side)==0 else -1
static func _particle(s: Dictionary,c: BattleAnimationContext,owner: Node2D,g: Session,b: Dictionary,call: Invocation) -> Array[Dictionary]:
	var coordinates: Dictionary=_coordinates(g,b)
	if coordinates.is_empty():return []
	var direction: int=_direction(g,b,coordinates.nominal)
	if direction==0:return []
	var callback: String=str(s.source_callback);var impact: bool=callback=="sub_80E27A0";var splash: bool=callback=="sub_80D4044"
	var rects: Dictionary=_rects(s);var physical: Dictionary=s.duplicate(true)
	physical.mode="static";physical.offset=[0,0];physical.offset_direction="";physical.mirror_offset=false;physical.affine_program=[];physical.frame_rects=rects;physical.seeded_splash=false
	if s.texture is Texture2D:physical.texture=Data.PROGRAM.steps[call.pc].texture
	var rng:=RandomNumberGenerator.new();rng.seed=c.seed_value+owner.elapsed_ticks*977+owner.get_child_count()*37
	var vx: int=0;var vy: int=0
	if splash:
		vx=(rng.randi()&255)|256;vy=rng.randi()&511
		if vy>255:vy=256-vy
	call.physical=physical;call.physical_consumed=false
	_stamp+=1
	var result: Array[Dictionary]=BattleEffectBehaviorRegistry._create(physical,c,owner,"source_particle")
	_stamp+=1
	call.physical={}
	for t: Dictionary in result:
		var settings: Dictionary=s.duplicate(true);settings.source_contest=c.contest;settings.frame_rects=rects
		var factor: float=float(s.get("scale_factor",1.0))
		if impact and factor==float(Data.PROGRAM.steps[call.pc].get("scale_factor",1.0)):factor=1.0
		if impact:factor*=216.0/256.0
		var origin: Vector2=coordinates.body+Vector2(float(s.offset[0])*direction,float(s.offset[1]))
		t.settings=settings;t.age=0;t.ticks=11 if impact else 21 if splash else 26;t.update=_advance;t.waterfall_owner=owner
		if s.texture is Texture2D:t.node.texture=s.texture
		var material: Material=t.node.material
		if impact:
			var combined:=ShaderMaterial.new();combined.shader=COMBINED;combined.set_shader_parameter("eva",0.75);combined.set_shader_parameter("evb",0.5);combined.set_shader_parameter("blend_amount",0.0);combined.set_shader_parameter("source_recolor",bool(s.get("recolor",false)));combined.set_shader_parameter("source_recolor_tint",Color(str(s.get("color","ffffff"))));t.node.material=combined;material=combined
		var item: Dictionary={"node":t.node,"parent":owner,"id":b.actor.id,"origin":origin,"point":origin,"settings":settings.duplicate(true),"texture":t.node.texture,"factor":factor,"track":t,"writes":{},"lost":{},"material":material,"shader":material.shader if material is ShaderMaterial else null,"uniforms":{},"revoked":{},"lost_material":false,"retired":false,"affine_remaining":0,"affine_end":false,"delegate":false,"callback_age":-1,"impact":impact,"splash":splash,"independent_endpoint":impact or splash,"vx":vx,"vy":vy,"ax":0,"ay":0,"phase":0}
		if material is ShaderMaterial:
			for parameter: Dictionary in material.shader.get_shader_uniform_list():item.uniforms[str(parameter.name)]=material.get_shader_parameter(str(parameter.name))
		item.writes.texture=t.node.texture;t.waterfall_item=item;t.cleanup=_cleanup.bind(item);g.objects.append(item);call.initial=t;_advance(t,c);call.initial={}
	return result
static func _controller(t: Dictionary,c: BattleAnimationContext,particle: bool) -> bool:
	var owner: Variant=t.get("waterfall_owner") if particle else t.get("owner")
	if not owner is BattleAnimationSequenceRunner:return false
	var g: Session=_group(owner)
	if g==null or c!=g.context or owner.context!=c or not _valid(owner,g,true):return false
	var actor_receipt: Dictionary=_actor_receipt(g,t) if not particle else {}
	var registered: bool=(not actor_receipt.is_empty() and not actor_receipt.retired) if not particle else g.objects.any(func(item):return is_same(item.get("track"),t) and is_same(t.get("waterfall_item"),item))
	if not registered:return false
	var call: Invocation=_calls.get(owner.get_instance_id()) as Invocation
	if call!=null and call.claimed and is_same(call.initial,t) and call.context==c and call.definition==owner.definition and call.pc==owner._pc and owner._i159_dispatch_live and Same._same(call.roles,_roles(c)):return true
	var boundary: Dictionary=owner._i161_control_callback_track if particle else owner._i159_actor_callback_track
	return is_same(boundary,t) and owner._tracks.any(func(actual):return is_same(actual,t))
static func _s16(n: int) -> int:return ((n+32768)&65535)-32768
static func _advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if not _controller(t,c,true):return
	var item: Dictionary=t.waterfall_item;var g: Session=_group(t.waterfall_owner)
	if item.retired or int(t.age)!=int(item.callback_age)+1:return
	if (not item.independent_endpoint and _binding(g,int(item.id)).is_empty()) or not Owned.node(item) or not Same._same(t.settings,item.settings):_retire(item);return
	item.callback_age=int(t.age);var age: int=int(t.age)
	if item.impact:
		if item.delegate:_retire(item);return
		if item.affine_end:item.delegate=true
		elif age==1:item.affine_remaining=7
		elif age>1:
			if item.affine_remaining>0:item.affine_remaining-=1
			else:item.affine_end=true
	elif age>0:
		if item.splash:
			item.ax=_s16(int(item.ax)+int(item.vx));item.ay=_s16(int(item.ay)+int(item.vy))
			item.point=item.origin+Vector2((-1 if int(item.vx)&1 else 1)*floori(float(item.ax)/256.0),floori(float(item.ay)/256.0))
		else:
			item.phase=(int(item.phase)+11)&255;item.ay=_s16(int(item.ay)+48)
			item.point=item.origin+Vector2(BattleSourceTrig.sine(int(item.phase),4),-floori(float(item.ay)/256.0))
		if age>=int(t.ticks):_retire(item);return
	_project(item,g)
static func _project(item: Dictionary,g: Session) -> void:
	if item.retired or not item.has("track") or not g.objects.any(func(actual):return is_same(actual,item)):return
	var t: Dictionary=item.track
	if not is_same(t.get("waterfall_item"),item) or not _valid(g.owner,g,true) or (not item.independent_endpoint and _binding(g,int(item.id)).is_empty()) or not Owned.node(item):return
	Owned.write(item,"texture",item.texture)
	var matrix: Transform2D=g.owner.global_transform.affine_inverse()*g.context.field.global_transform*Transform2D(0.0,Vector2.ONE*float(item.factor),0.0,item.point)
	Owned.write(item,"transform",matrix)
	var tile: int=0 if item.impact else 8 if item.splash else 12+(int(t.age)/6)%2
	var rect: Array=item.settings.frame_rects[str(tile)]
	Owned.write(item,"region_enabled",true);Owned.write(item,"region_rect",Rect2(rect[0],rect[1],rect[2],rect[3]));Owned.write(item,"hframes",1);Owned.write(item,"vframes",1);Owned.write(item,"frame",0)
	Owned.write(item,"flip_h",bool(item.settings.get("flip_h",false)));Owned.write(item,"flip_v",bool(item.settings.get("flip_v",false)));Owned.write(item,"visible",true)
	if item.material is ShaderMaterial:Owned.observe_material(item)
	if not item.lost_material:Owned.write(item,"material",item.material)
static func _parent_offset(g: Session,id: int,value: Vector2) -> Vector2:return g.bindings[id].parent.global_transform.affine_inverse().basis_xform(g.context.field.global_transform.basis_xform(value))
static func actor_step(t: Dictionary,c: BattleAnimationContext) -> void:
	if not _controller(t,c,false) or int(t.age)!=int(t.callback_age)+1:return
	t.callback_age=int(t.age);var g: Session=_group(t.owner);var id: int=int(t.waterfall_id)
	if _binding(g,id).is_empty():t.ticks=int(t.age);return
	var age: int=int(t.age);var line: int=int(t.settings.source_line);var value: Vector2=g.offsets.get(id,Vector2.ZERO)
	if line==1576:
		var direction: int=1 if int(g.bindings[id].side)==0 else -1
		if age>=1 and age<=6:value.x+=5*direction
		elif age>=9 and age<=14:value.x-=5*direction
		if age>=16:t.ticks=age
	elif line==1549:
		value=Vector2(0,2 if ((age+1)/2)%2==0 else 0)
		if age>=45:value=Vector2.ZERO;t.ticks=age
	else:
		value=Vector2(4 if ((age+1)/2)%2==0 else -4,0)
		if age>=33:value=Vector2.ZERO;t.ticks=age
	g.offsets[id]=value;g.offset_writers[id]=t
static func resolve_offset(owner: Node2D,a: BattleAnimationActor) -> Vector2:
	var g: Session=_group(owner)
	if g==null or not _valid(owner,g,true) or (g.writers.has(a.id) or g.motion_lost.has(a.id)) or _binding(g,a.id).is_empty():return Vector2.ZERO
	return _parent_offset(g,a.id,g.offsets.get(a.id,Vector2.ZERO))
static func note_held_write(owner: Node2D,t: Dictionary,value: Vector2) -> void:
	var g: Session=_group(owner);var candidate: Variant=t.get("actor")
	if g==null or not candidate is BattleAnimationActor or t.get("kind")=="source_waterfall_actor" or not value.is_finite() or not is_same(owner._i159_actor_callback_track,t) or not owner._tracks.any(func(actual):return is_same(actual,t)):return
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
static func _material_lease(g: Session,id: int) -> Dictionary:
	if not g.material_leases.has(id):g.material_leases[id]={"material":null,"shader":null,"expected":{},"baseline":{},"lost":{},"property_lost":false,"shader_lost":false,"final_held":false,"final_receipt":null,"held_fields":{}}
	return g.material_leases[id]
static func _observe_actor_material(g: Session,id: int) -> void:
	var lease: Dictionary=g.material_leases[id]
	if not lease.material is WeakRef:return
	var b: Dictionary=_binding(g,id)
	if b.is_empty():lease.property_lost=true;return
	var material: Variant=lease.material.get_ref()
	if not material is ShaderMaterial or not is_same(b.sprite.material,material):lease.property_lost=true;return
	if not is_same(material.shader,lease.shader):lease.shader_lost=true;return
	for key: String in lease.expected:
		if not Same._same(material.get_shader_parameter(key),lease.expected[key]):lease.lost[key]=true
static func handle_palette(owner: Node2D,c: BattleAnimationContext,candidate: Variant,blend: Dictionary,transient: bool) -> bool:
	var g: Session=_group(owner)
	if g==null:return false
	if not candidate is BattleAnimationActor:return true
	if not g.bindings.has(candidate.id):return false
	var b: Dictionary=_binding(g,candidate.id)
	if b.is_empty() or not is_same(candidate,b.actor) or c!=g.context or not _valid(owner,g,true):return true
	var lease: Dictionary=_material_lease(g,candidate.id)
	_observe_actor_material(g,candidate.id)
	lease.final_held=false;lease.final_receipt=null;lease.held_fields={}
	# Observe BEFORE Actor or wave writes: restored equal values never reacquire a field.
	if lease.property_lost or lease.shader_lost:return true
	var material: ShaderMaterial=lease.material.get_ref() as ShaderMaterial if lease.material is WeakRef else null
	if material==null:
		if float(blend.amount)<=0 and not candidate._owned_grayscale and not candidate._owned_invert:
			candidate.apply_blend(blend.color,blend.amount);return true
		# Capture actual overrides BEFORE the first palette publication, not its output.
		material=candidate._blend_material
		if material==null:
			material=ShaderMaterial.new();material.shader=load("res://scripts/battle/animations/sequence/palette_blend.gdshader");candidate._blend_material=material
		if not is_same(b.sprite.material,material):candidate._previous_material=b.sprite.material;b.sprite.material=material
		lease.material=weakref(material);lease.shader=material.shader
		for parameter: Dictionary in material.shader.get_shader_uniform_list():
			var key: String=str(parameter.name);lease.expected[key]=material.get_shader_parameter(key);lease.baseline[key]=material.get_shader_parameter(key)
	elif float(blend.amount)<=0 and not candidate._owned_grayscale and not candidate._owned_invert and lease.lost.is_empty():
		candidate.apply_blend(blend.color,blend.amount)
		lease.material=null;lease.expected={};lease.baseline={};return true
	var values: Dictionary={"grayscale":candidate._owned_grayscale,"invert":candidate._owned_invert,"blend_color":blend.color,"blend_amount":clampf(float(blend.amount),0,1)}
	for key: String in ["wave_amplitude","wave_phase","wave_height","wave_start","wave_end","wave_scale_x","wave_scale_y"]:values[key]=float(blend.get(key,64.0 if key=="wave_height" else 0.0))
	for key: String in values:
		if lease.lost.has(key):continue
		material.set_shader_parameter(key,values[key]);lease.expected[key]=material.get_shader_parameter(key)
	var held: Dictionary=g.palettes.get(candidate.id,{})
	# Transient blends may share the material but can never promote the old held receipt.
	if not transient and not held.is_empty() and is_same(owner._held_blends.get(candidate.id),held.receipt) and Same._same(blend,held.receipt):
		lease.final_held=true;lease.final_receipt=held.receipt
		for key: String in ["blend_color","blend_amount"]:
			if not lease.lost.has(key):lease.held_fields[key]=lease.expected[key]
	return true
static func observe_palette_application(owner: Node2D) -> void:
	var g: Session=_group(owner)
	if g==null:return
	for id: int in g.material_leases:_observe_actor_material(g,id)
static func scheduled_actor_shape_allowed(owner: Node2D,candidate: Variant) -> bool:
	return _group(owner)==null or candidate is BattleAnimationActor
static func scheduled_track_shape_allowed(owner: Node2D,track: Variant) -> bool:
	if _group(owner)==null:return true
	return track is Dictionary and typeof(track.get("kind")) in [TYPE_STRING,TYPE_STRING_NAME] and (not track.has("actor") or track.actor is BattleAnimationActor)
static func _actor_receipt(g: Session,track: Dictionary) -> Dictionary:
	for receipt: Dictionary in g.actor_receipts:
		if is_same(receipt.track,track):return receipt
	return {}
static func retire_scheduled(owner: Node2D,track: Variant) -> void:
	var g: Session=_group(owner)
	if g==null:return
	# Membership, not mutable actor/kind/id fields, establishes cleanup authority.
	if track is Dictionary:
		var receipt: Dictionary=_actor_receipt(g,track)
		if not receipt.is_empty():
			receipt.retired=true
			if is_same(g.offset_writers.get(receipt.id),track):g.offsets.erase(receipt.id);g.offset_writers.erase(receipt.id)
		for item: Dictionary in g.objects:
			if is_same(item.get("track"),track):_retire(item);_cleanup(item);break
	for index: int in range(owner._tracks.size()-1,-1,-1):
		if is_same(owner._tracks[index],track):owner._tracks.remove_at(index)
static func before_track(owner: Node2D,t: Dictionary) -> bool:
	var g: Session=_group(owner)
	if g==null:return true
	_valid(owner,g,true)
	for id: int in g.bindings:_binding(g,id)
	var receipt: Dictionary=_actor_receipt(g,t)
	if receipt.is_empty():
		if t.get("kind")=="source_waterfall_actor":retire_scheduled(owner,t);return false
		return true
	var binding: Dictionary=_binding(g,int(receipt.id))
	if receipt.retired or not g.valid or binding.is_empty() or t.get("kind")!="source_waterfall_actor" or not t.get("actor") is BattleAnimationActor or not is_same(t.actor,binding.actor) or not Same._same(t.get("settings"),receipt.settings) or typeof(t.get("waterfall_id"))!=TYPE_INT or int(t.waterfall_id)!=int(receipt.id):
		retire_scheduled(owner,t);return false
	return true
static func begin_tick(owner: Node2D,c: BattleAnimationContext) -> void:
	var g: Session=_group(owner)
	if g==null:return
	_stamp+=1
	_valid(owner,g)
	for id: int in g.bindings:
		var b: Dictionary=_binding(g,id)
		if not b.is_empty() and (b.sprite.position!=b.actor._expected_position or b.sprite.scale!=b.actor._expected_scale or b.sprite.rotation!=b.actor._expected_rotation):g.motion_lost[id]=true
	for id: int in g.material_leases:_observe_actor_material(g,id)
	for item: Dictionary in g.objects:
		if not g.valid or (not item.independent_endpoint and _binding(g,int(item.id)).is_empty()):_retire(item)
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
	t.erase("cleanup");t.erase("update");t.erase("waterfall_item");item.erase("track")
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
	var palette: Dictionary=g.material_leases.get(candidate.id,{})
	if not palette.is_empty():_observe_actor_material(g,candidate.id)
	var material: Material=null
	if not palette.is_empty() and not palette.property_lost and palette.material is WeakRef and is_same(palette.material.get_ref(),b.sprite.material):
		var foreign_fields: bool=palette.shader_lost or not palette.lost.is_empty()
		var final_held: bool=palette.final_held and not palette.shader_lost and is_same(owner._held_blends.get(candidate.id),palette.final_receipt)
		if foreign_fields or final_held:material=b.sprite.material
		if material!=null and not palette.shader_lost:
			# Winner proof is field-local: a lost wave must not erase held color/amount.
			for key: String in palette.expected:
				if palette.lost.has(key):continue
				var held_field: bool=final_held and palette.held_fields.has(key) and Same._same(material.get_shader_parameter(key),palette.held_fields[key])
				if not held_field:material.set_shader_parameter(key,palette.baseline.get(key))
	# Generic release must not regain a lost material-property lease after equal return.
	# Drop only its internal restoration capability; actual foreign sprite state is untouched.
	if not palette.is_empty() and palette.property_lost:candidate._blend_material=null
	# First release ALL transient additive/approach/matrix/source contributions.
	# Retain only the proven winning held vector, never a mixed visual snapshot.
	candidate.release()
	if keep_offset and _cleanup_bound(b,g):candidate.add_layout_offset(held.value)
	if material!=null and _cleanup_bound(b,g):b.sprite.material=material
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
	g.objects.clear();g.actors.clear();g.actor_receipts.clear();g.bindings.clear();g.offsets.clear();g.offset_writers.clear();g.writers.clear();g.palettes.clear();g.material_leases.clear();g.released.clear();owner.remove_meta(STATE);_calls.erase(owner.get_instance_id())

static func actor_allowed(owner: Node2D,a: Variant) -> bool:
	var g: Session=_group(owner)
	if g==null:return true
	return a is BattleAnimationActor and (not g.bindings.has(a.id) or not _binding(g,a.id).is_empty())

extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Finite338: source event clocks, FIELD recipes and independent native channels.
const Data=preload("res://scripts/battle/animations/sequence/source_frenzy_plant_data.gd")
const Same=preload("res://scripts/battle/animations/sequence/source_cutting_slice.gd")
const Owned=preload("res://scripts/battle/animations/sequence/source_owned_composition.gd")
const Pair=preload("res://scripts/battle/animations/sequence/source_charge_owned.gd")
const Capture=preload("res://scripts/battle/animations/sequence/source_stockpile_composition.gd")
const Fast=preload("res://scripts/battle/animations/sequence/source_program_proof.gd")
const COMBINED=preload("res://scripts/battle/animations/sequence/source_agility_aerial_palette_ab.gdshader")
const PALETTE=preload("res://scripts/battle/animations/sequence/palette_blend.gdshader")
const RECOLOR=preload("res://scripts/battle/animations/sequence/particle_recolor.gdshader")
const KEY="ruby:move/338"
const STATE="i171_frenzy_session"
const ART=["texture","frame_rects","scale_factor","color","recolor","flip_h","flip_v"]
static var _calls: Dictionary={}
# Proof memo: bumped whenever control can leave this module (dispatch, tick/pose boundaries).
static var _stamp: int=0
class Invocation extends RefCounted:
	var incoming: Dictionary
	var recipe: Dictionary={}
	var context: BattleAnimationContext
	var definition: BattleAnimationDefinition
	var pc: int
	var roles: Array=[]
	var claimed: bool=false
	var validating: bool=false
	var initial: Dictionary={}
class Record extends RefCounted:
	var track: Dictionary
	var settings: Dictionary
	var recipe: Dictionary={}
	var item: Dictionary={}
	var node: Node2D
	var kind: String
	var line: int
	var actor_id: int=-1
	var callback: int=-1
	var retired: bool=false
	var baseline: Dictionary={}
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
	var records: Array[Record]=[]
	var valid: bool=true
	var anchor: Variant=null
	var floor_z: int=0
	var priority28: bool=false
	var alpha: Array=[16,0]
	var serial: int=0
	var offset: Vector2=Vector2.ZERO
	var offset_lost: bool=false
	var held_receipt: Dictionary={}
	var applied: Dictionary={}
	var palettes: Dictionary={}
	var released_actors: Dictionary={}
	var shade: Dictionary={}
	var shade_lost: bool=false
	var released: bool=false
	var bank_receipt: Array=[]
	var source_subpriority: int=30
static func _object(v: Variant) -> bool:return typeof(v)==TYPE_OBJECT and is_instance_valid(v)
static func _actor(v: Variant) -> bool:return _object(v) and v is BattleAnimationActor
static func _sprite(v: Variant) -> bool:return _object(v) and v is Sprite2D
static func _number(v: Variant,integral: bool=false) -> bool:return typeof(v) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(v)) and (not integral or float(v)==floorf(float(v)))
static func _canonical(d: Variant) -> bool:
	var original: Variant=BattleAnimationSequenceRegistry._builtin_source_definitions.get(KEY)
	return original is BattleAnimationDefinition and d is BattleAnimationDefinition and is_same(d,original)
static func matches(owner: Variant) -> bool:return _object(owner) and owner is BattleAnimationSequenceRunner and _canonical(owner.definition)
static func _group(owner: Node2D) -> Session:return owner.get_meta(STATE) as Session if owner.has_meta(STATE) else null
static func _roles(c: BattleAnimationContext) -> Array:return [c.attacker_id,c.target_ids.duplicate(),c.contest,c.source_positions.duplicate()]
static func _position(c: BattleAnimationContext,id: int) -> int:
	var raw: Variant=c.source_positions.get(id,BattleAnimationContext.source_position_for_slot(id))
	return int(raw) if _number(raw,true) and int(raw) in [0,1,2,3] else -1
static func _normal(s: Dictionary) -> Dictionary:
	var out: Dictionary={}
	for key: Variant in s:
		if typeof(key)!=TYPE_STRING and not(typeof(key)==TYPE_STRING_NAME and str(key) in ART):return {}
		if out.has(str(key)):return {}
		out[str(key)]=s[key]
	return out
static func _texture(s: Dictionary) -> Texture2D:
	var raw: Variant=s.get("texture")
	if _object(raw) and raw is Texture2D:return raw
	if raw is String:return Fast.texture(raw)
	return null
static func _rects(s: Dictionary,e: Dictionary) -> Dictionary:
	var texture: Texture2D=_texture(s)
	if texture==null or texture.get_width()<=0 or texture.get_height()<=0:return {}
	if s.has("scale_factor") and (not _number(s.scale_factor) or float(s.scale_factor)<=0):return {}
	for key: String in ["flip_h","flip_v","recolor"]:
		if s.has(key) and typeof(s[key])!=TYPE_BOOL:return {}
	if s.has("color") and (not s.color is String or not Color.html_is_valid(s.color)):return {}
	var allowed: Array=[0,16,32,48] if e.get("source_callback")=="sub_80CB620" else [0]
	var raw: Variant=s.get("frame_rects",e.get("frame_rects",{}))
	if raw is Dictionary and raw.is_empty() and e.get("source_callback")=="sub_80E27A0":
		var size: Variant=s.get("frame_size",[])
		if not size is Array or size.size()!=2:return {}
		for value: Variant in size:
			if not _number(value,true) or float(value)<=0:return {}
		raw={"0":[0,0,size[0],size[1]]}
	if not raw is Dictionary:return {}
	var out: Dictionary={}
	for key: Variant in raw:
		var tile: int=-1
		if key is String and key.is_valid_int():tile=int(key)
		elif _number(key,true):tile=int(key)
		else:return {}
		if tile not in allowed or out.has(str(tile)):return {}
		var r: Variant=raw[key]
		if not r is Array or r.size()!=4:return {}
		for n: Variant in r:
			if not _number(n,true):return {}
		if r[0]<0 or r[1]<0 or r[2]<=0 or r[3]<=0 or r[0]+r[2]>texture.get_width() or r[1]+r[3]>texture.get_height():return {}
		out[str(tile)]=r.duplicate()
	for frame: Dictionary in e.get("frame_commands",[{"tile":0}]):
		if not out.has(str(int(frame.tile))):return {}
	return out
static func _shape(raw: Variant,e: Dictionary) -> bool:
	if not raw is Dictionary:return false
	var s: Dictionary=_normal(raw)
	if s.is_empty():return false
	var art: bool=e.get("source_callback") in ["sub_80CB620","sub_80E27A0"]
	for key: String in e:
		if art and key in ART:continue
		if not s.has(key) or not Same._same(s[key],e[key]):return false
	for key: String in s:
		if not e.has(key) and (not art or key not in ART):return false
	return not art or not _rects(s,e).is_empty()
static func _definition(d: BattleAnimationDefinition) -> bool:
	if not _canonical(d) or d.key!=Data.PROGRAM.key or d.source_script!=Data.PROGRAM.source_script or d.coverage!=Data.PROGRAM.coverage or d.steps.size()!=175:return false
	for pc: int in 175:
		if not _shape(d.steps[pc],Data.PROGRAM.steps[pc]):return false
	return true
static func accepts_texture_dependency(d: BattleAnimationDefinition,s: Dictionary) -> bool:
	if not _definition(d):return false
	for pc: int in 175:
		if is_same(d.steps[pc],s):return Data.PROGRAM.steps[pc].get("source_callback") in ["sub_80CB620","sub_80E27A0"] and _texture(_normal(s))!=null
	return false
static func _whole(owner: Node2D) -> bool:return matches(owner) and _definition(owner.definition) and Same._same(owner._steps,owner.definition.steps)
## Cheap proof that the live program still equals the one this session admitted.
static func _fast(owner: Node2D,g: Session) -> bool:
	if g==null or g.proof==null or not matches(owner):return false
	var d: BattleAnimationDefinition=owner.definition
	if not _canonical(d) or d.key!=Data.PROGRAM.key or d.source_script!=Data.PROGRAM.source_script or d.coverage!=Data.PROGRAM.coverage or d.steps.size()!=175 or owner._steps.size()!=175:return false
	return Fast.holds(owner._steps,d.steps,g.program,g.proof,func(pc: int,step: Variant) -> bool:return _shape(step,Data.PROGRAM.steps[pc]))
static func _whole_for(owner: Node2D,g: Session) -> bool:return _fast(owner,g) or _whole(owner)
static func _program_ok(owner: Node2D,g: Session,memo: bool) -> bool:
	if memo and g.proof_stamp==_stamp:return true
	var good: bool=_fast(owner,g) or (_whole(owner) and Same._same(owner._steps,g.program))
	if good:g.proof_stamp=_stamp
	return good
static func open_dispatch(owner: Node2D,s: Dictionary) -> Invocation:
	if not matches(owner) or owner.context==null or _calls.has(owner.get_instance_id()):return null
	_stamp+=1
	var call:=Invocation.new();call.incoming=s;call.context=owner.context;call.definition=owner.definition;call.pc=owner._pc;call.roles=_roles(owner.context);_calls[owner.get_instance_id()]=call;return call
static func close_dispatch(owner: Node2D,call: Invocation) -> void:
	_stamp+=1
	if call!=null and is_same(_calls.get(owner.get_instance_id()),call):_calls.erase(owner.get_instance_id())
static func _valid(g: Session,memo: bool=false) -> bool:
	if not g.valid:return false
	if not Same._same(_bank_receipt(g.context),g.bank_receipt) or g.owner.context!=g.context or g.owner.definition!=g.definition or not Same._same(_roles(g.context),g.roles) or not _program_ok(g.owner,g,memo):g.valid=false
	return g.valid
static func _frame(n: Sprite2D) -> Array:return [n.hframes,n.vframes,n.frame,n.region_enabled,n.region_rect,n.centered,n.offset,n.flip_h,n.flip_v]
static func _capture(c: BattleAnimationContext,id: int) -> Dictionary:
	var value: Variant=c.actors.get(id)
	if not _actor(value) or value.id!=id or not _sprite(value.sprite) or not value.sprite.get_parent() is Node2D or value.side not in [0,1] or _position(c,id)<0:return {}
	if value.sprite.get_canvas()!=c.field.get_canvas():return {}
	var b: Dictionary=Capture._capture(c,id)
	if not b.is_empty():b.frame=_frame(b.sprite)
	return b
static func _same_visual(b: Dictionary,g: Session,strict: bool=true) -> bool:
	if b.is_empty() or not _actor(b.get("actor")) or not _sprite(b.get("sprite")):return false
	var actor: BattleAnimationActor=b.actor;var n: Sprite2D=b.sprite
	if actor.sprite!=n or not actor.is_present() or n.is_queued_for_deletion() or n.get_parent()!=b.parent or n.texture!=b.texture or actor._generation!=b.generation:return false
	var live: Variant=g.owner.context
	if live is BattleAnimationContext:
		for occupant: Variant in live.actors.values():
			if _actor(occupant) and not is_same(occupant,actor) and occupant.sprite==n:return false
	return not strict or (actor.side==b.side and g.context.actors.get(actor.id)==actor and Capture._bound(b,g.context) and Same._same(_frame(n),b.frame))
static func _binding(g: Session,id: int) -> Dictionary:
	if g.lost.has(id):return {}
	var b: Dictionary=g.bindings.get(id,{})
	if not _same_visual(b,g):g.lost[id]=true;return {}
	return b
static func _center(g: Session,b: Dictionary) -> Vector2i:
	var actor: BattleAnimationActor=b.actor;var n: Sprite2D=b.sprite;var parent: Node2D=n.get_parent()
	var point: Vector2=g.context.field.to_local(parent.to_global(n.transform*n.get_rect().get_center()-actor._offset))
	return Vector2i(int(point.x),int(point.y))
static func _z(n: CanvasItem) -> int:
	var chain: Array[CanvasItem]=[];var cursor: Node=n
	while cursor!=null:
		if cursor is CanvasItem:chain.push_front(cursor)
		cursor=cursor.get_parent()
	var value: int=0
	for item: CanvasItem in chain:value=clampi(value+item.z_index,-4096,4096) if item.z_as_relative else item.z_index
	return value
static func _session(owner: Node2D,c: BattleAnimationContext) -> Session:
	var g: Session=_group(owner)
	if g!=null:return g
	g=Session.new();g.owner=owner;g.context=c;g.definition=owner.definition;g.roles=_roles(c);g.program=owner._steps.duplicate(true);g.proof=Fast.capture(g.program);g.floor_z=_z(c.field);g.bank_receipt=_bank_receipt(c);g.source_subpriority=_source_subpriority(c)
	for key: Variant in c.actors:
		if typeof(key)!=TYPE_INT:continue
		var b: Dictionary=_capture(c,int(key))
		if not b.is_empty():g.bindings[int(key)]=b
	var target: Dictionary=g.bindings.get(c.target_ids[0],{}) if not c.target_ids.is_empty() else {}
	if not target.is_empty():g.anchor=_z(target.sprite)
	else:
		var members: Array[BattleAnimationActor]=Owned.source_bg_members(c,1)
		if not members.is_empty():g.anchor=_z(members[0].sprite)
	owner.set_meta(STATE,g);return g
static func _admit(s: Dictionary,c: BattleAnimationContext,owner: Node2D,kind: String) -> bool:
	var call: Invocation=_calls.get(owner.get_instance_id()) as Invocation;var g: Session=_group(owner)
	if not _context_shape(c):return false
	if call==null or not call.validating or call.claimed or not is_same(call.incoming,s) or call.context!=c or owner.context!=c or call.definition!=owner.definition or call.pc!=owner._pc or not owner._i159_dispatch_live or not Same._same(call.roles,_roles(c)) or not _whole_for(owner,g) or(g!=null and not _valid(g)):return false
	if call.pc<0 or call.pc>=175 or Data.PROGRAM.steps[call.pc].get("behavior")!=kind:return false
	var plain: Dictionary=s.duplicate(true);var priority: Dictionary=BattleSourcePriority.command_metadata(Data.PROGRAM.steps[call.pc-1]) if call.pc>0 else {}
	if not priority.is_empty():
		if not Same._same(plain.get("source_command_priority"),priority):return false
		plain.erase("source_command_priority")
	elif plain.has("source_command_priority"):return false
	if not _shape(plain,Data.PROGRAM.steps[call.pc]) or not Same._same(plain,owner._steps[call.pc]):return false
	# Semantic recipe is canonical after ONLY the validated dispatch decoration is removed.
	# Raw incoming/settings remain a separate identity/typed tamper receipt.
	var recipe: Dictionary=_normal(plain)
	if recipe.is_empty() or not owner.claim_effect_dispatch(s):return false
	call.recipe=recipe.duplicate(true);call.claimed=true;return true
static func effect(s: Dictionary,c: BattleAnimationContext,owner: Node2D,kind: String) -> Variant:
	# Reserve physical validation BEFORE Texture2D virtual getters or full-program scans.
	var call: Invocation=_calls.get(owner.get_instance_id()) as Invocation
	if call!=null and (call.validating or call.claimed):return []
	if not matches(owner) and _group(owner)==null:return null
	if call==null or not is_same(call.incoming,s) or call.context!=c or call.pc!=owner._pc or not owner._i159_dispatch_live:return []
	call.validating=true
	var result: Variant=_effect_reserved(s,c,owner,kind)
	call.validating=false
	return result
static func _effect_reserved(s: Dictionary,c: BattleAnimationContext,owner: Node2D,kind: String) -> Variant:
	var g: Session=_group(owner)
	if g!=null and not _valid(g):return []
	if not matches(owner):return null
	if c==null or not _object(c.field) or not c.field is Node2D or not _admit(s,c,owner,kind):return []
	g=_session(owner,c)
	if kind=="source_legacy_impact_command":return _command(s,g)
	if kind=="source_palette":return _palette(s,g)
	var id: int=c.target_ids[0] if not c.target_ids.is_empty() else -1
	var b: Dictionary=_binding(g,id)
	if b.is_empty() or g.anchor==null:return []
	if kind in ["source_particle","sheet"]:
		if _binding(g,c.attacker_id).is_empty():return []
		return _particle(s,g,b)
	if kind=="source_actor":
		var r:=Record.new();r.kind="actor";r.line=int(s.source_line);r.actor_id=id;r.settings=s.duplicate(true)
		r.track={"kind":"source_frenzy_actor","age":0,"ticks":39,"actor":b.actor,"owner":owner,"settings":s.duplicate(true)};g.records.append(r)
		var call: Invocation=_calls.get(owner.get_instance_id()) as Invocation;call.initial=r.track;actor_step(r.track,c)
		var parent: Node2D=b.sprite.get_parent();var delta: Vector2=parent.global_transform.basis_xform_inv(c.field.global_transform.basis_xform(g.offset))
		b.actor.apply(b.actor._offset+delta,b.actor._tint)
		call.initial={};return [r.track]
	return []
static func _record(g: Session,t: Dictionary) -> Record:
	for r: Record in g.records:
		if is_same(r.track,t):return r
	return null
static func _lane(r: Record,g: Session,c: BattleAnimationContext) -> bool:
	if r.retired or c!=g.context or not _valid(g,true) or not Same._same(r.track.get("settings"),r.settings):return false
	var call: Invocation=_calls.get(g.owner.get_instance_id()) as Invocation
	if call!=null and call.claimed and is_same(call.initial,r.track) and call.context==c and g.owner._i159_dispatch_live:return true
	var boundary: Dictionary=g.owner._i159_actor_callback_track if r.kind=="actor" else g.owner._i161_control_callback_track
	return is_same(boundary,r.track) and g.owner._tracks.any(func(actual):return is_same(actual,r.track))
static func _particle(s: Dictionary,g: Session,b: Dictionary) -> Array[Dictionary]:
	var invocation: Invocation=_calls.get(g.owner.get_instance_id()) as Invocation
	if invocation==null or not invocation.claimed or not is_same(invocation.incoming,s) or invocation.recipe.is_empty():return []
	var settings: Dictionary=invocation.recipe.duplicate(true);var expected: Dictionary=Data.PROGRAM.steps[g.owner._pc]
	var rects: Dictionary=_rects(settings,expected)
	if rects.is_empty():return []
	var impact: bool=int(s.source_line) in [8791,8795,8798,8801,8804,8807]
	var a: Vector2i=_center(g,_binding(g,g.context.attacker_id));var target: Vector2i=_center(g,b);var point: Vector2
	if impact:
		var sign_x: int=1 if a.x<target.x else -1 if a.x>target.x else 1 if int(g.bindings[g.context.attacker_id].side)==0 else -1
		point=Vector2(target)+Vector2(float(s.offset[0])*sign_x,float(s.offset[1]))
	else:
		var args: Array=s.source_args;var dx: int=((target.x-a.x+32768)&65535)-32768;var dy: int=((target.y-a.y+32768)&65535)-32768
		point=Vector2(a.x+int(float(dx*int(args[0]))/100.0)+int(args[1]),a.y+int(float(dy*int(args[0]))/100.0)+int(args[2]))
	var n:=Sprite2D.new();n.texture=_texture(settings)
	var r:=Record.new();r.node=n;r.kind="hit" if impact else "root";r.line=int(s.source_line);r.actor_id=b.actor.id;r.settings=s.duplicate(true);r.recipe=settings.duplicate(true)
	var factor: float=1.0
	if impact:
		var base: float=[1.0,216.0/256.0,176.0/256.0,0.5][int(s.source_affine_variant)]
		factor=base if float(s.get("scale_factor",1.0))==float(expected.get("scale_factor",1.0)) else base*float(settings.scale_factor)
	else:factor=float(settings.get("scale_factor",1.0))
	r.item={"node":n,"parent":null,"writes":{},"lost":{},"point":point,"texture":n.texture,"factor":factor,"rects":rects,"birth":g.serial,"retired":false,"sub":maxi(3,g.source_subpriority-2) if impact else 30}
	g.serial+=1;r.track={"kind":"source_frenzy_particle","age":0,"ticks":12 if impact else int(s.source_args[5])+1,"node":n,"owner":g.owner,"settings":s.duplicate(true),"update":advance};g.records.append(r)
	var tint:=Color(str(settings.get("color","ffffff")));n.modulate=Color.WHITE if bool(settings.get("recolor",false)) else tint
	if impact:
		var material:=ShaderMaterial.new();material.shader=COMBINED;material.set_shader_parameter("eva",float(g.alpha[0])/16.0);material.set_shader_parameter("evb",float(g.alpha[1])/16.0);material.set_shader_parameter("blend_amount",0.0);material.set_shader_parameter("source_recolor",bool(settings.get("recolor",false)));material.set_shader_parameter("source_recolor_tint",tint);n.material=material
	elif bool(settings.get("recolor",false)):
		var material:=ShaderMaterial.new();material.shader=RECOLOR;material.set_shader_parameter("tint",tint);n.material=material
	# These are actual explicit off-tree writes, not adopted observations.
	for key: String in ["texture","modulate","self_modulate","material","centered","offset"]:_seed(r.item,key,n.get(key))
	_project(r,g)
	if not _depth(g):return []
	r.item.parent=g.owner
	g.owner.add_child(n)
	var call: Invocation=_calls.get(g.owner.get_instance_id()) as Invocation;call.initial=r.track;advance(r.track,g.context);call.initial={};return [r.track]
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	var owner: Variant=t.get("owner")
	if not _object(owner) or not owner is BattleAnimationSequenceRunner:return
	var g: Session=_group(owner)
	if g==null:return
	var r: Record=_record(g,t)
	if r==null or not _lane(r,g,c) or not _number(t.get("age"),true):return
	var age: int=int(t.age)
	if age!=r.callback+1:return
	r.callback=age
	if r.kind=="palette":_fade(r,g,age);return
	if r.kind=="BG":
		if t.get("cleared",false):
			t.clear_callbacks=int(t.get("clear_callbacks",0))+1
			if int(t.clear_callbacks)>=2:
				for member: Record in r.baseline.members:_retire(member)
				r.retired=true;t.ticks=age
		return
	if r.kind not in ["root","hit"]:return
	if (r.kind=="hit" and age>=12)or(r.kind=="root" and age>int(r.recipe.source_args[5])):_retire(r);return
	_project(r,g)
static func _project(r: Record,g: Session) -> void:
	if r.retired or not _sprite(r.node) or not Owned.node(r.item):return
	var s: Dictionary=r.recipe
	if s.is_empty():_retire(r);return
	var age: int=maxi(0,r.callback);var item: Dictionary=r.item
	Owned.write(item,"texture",item.texture)
	Owned.write(item,"transform",g.owner.global_transform.affine_inverse()*g.context.field.global_transform*Transform2D(0.0,Vector2.ONE*float(item.factor),0.0,item.point))
	var frame: int=0
	if r.kind=="root":frame=mini(age/7,2 if int(s.source_args[4])>=2 else 3)*16
	var raw: Array=item.rects[str(frame)];Owned.write(item,"region_enabled",true);Owned.write(item,"region_rect",Rect2(raw[0],raw[1],raw[2],raw[3]));Owned.write(item,"hframes",1);Owned.write(item,"vframes",1);Owned.write(item,"frame",0)
	Owned.write(item,"flip_h",bool(s.get("flip_h",false))!=(r.kind=="root" and int(s.source_args[4]) in [1,3]));Owned.write(item,"flip_v",bool(s.get("flip_v",false)))
	var visible: bool=true
	if r.kind=="root":visible=age<=int(s.source_args[5])-10 or age%2==0
	Owned.write(item,"visible",visible)
static func _retire(r: Record) -> void:
	if r.retired:return
	r.retired=true
	if not r.item.is_empty() and _sprite(r.node) and r.node.get_parent()==r.item.parent:
		Owned.write(r.item,"visible",false);r.node.queue_free()
	if _number(r.track.get("age"),true):r.track.ticks=int(r.track.age)
static func _shade_write(g: Session,key: String,value: Variant) -> void:
	if g.shade_lost or g.shade.is_empty():return
	var n: Variant=g.shade.get("node")
	if not _object(n) or not n is Polygon2D or n.get_parent()!=g.owner or not is_same(g.owner._background_blend,n):g.shade_lost=true;return
	var expected: Variant=g.shade.writes.get(key,g.shade.baseline.get(key))
	if n.get(key)!=expected:g.shade.lost[key]=true
	if g.shade.lost.has(key):return
	n.set(key,value);g.shade.writes[key]=n.get(key)
static func _palette(s: Dictionary,g: Session) -> Array[Dictionary]:
	if g.shade.is_empty():
		var prior: bool=_object(g.owner._background_blend) and g.owner._background_blend is Polygon2D
		var n: Polygon2D=g.owner._background_blend if prior else Polygon2D.new()
		if not prior:g.owner.add_child(n);g.owner._background_blend=n
		var base: Dictionary={}
		for key: String in ["polygon","transform","color","visible","show_behind_parent"]:base[key]=n.get(key)
		g.shade={"node":n,"parent":g.owner,"baseline":base,"writes":{},"lost":{},"prior":prior}
	var r:=Record.new();r.kind="palette";r.line=int(s.source_line);r.settings=s.duplicate(true)
	r.track={"kind":"source_frenzy_palette","domain":"visual","age":0,"ticks":19,"owner":g.owner,"settings":s.duplicate(true),"update":advance};g.records.append(r)
	var call: Invocation=_calls.get(g.owner.get_instance_id()) as Invocation;call.initial=r.track;advance(r.track,g.context);call.initial={};return [r.track]
static func _fade(r: Record,g: Session,age: int) -> void:
	if age>=19:r.retired=true;r.track.ticks=age;return
	if age not in [0,4,8,12]:return
	var coefficients: Array=[0,2,4,5] if r.line==8762 else [5,3,1,0]
	_shade_write(g,"transform",g.owner.global_transform.affine_inverse()*g.context.field.global_transform)
	_shade_write(g,"polygon",PackedVector2Array([Vector2.ZERO,Vector2(240,0),Vector2(240,160),Vector2(0,160)]))
	_shade_write(g,"show_behind_parent",true)
	_shade_write(g,"color",Color(0,0,0,float(coefficients[age/4])/16.0));_shade_write(g,"visible",true)
static func before_scene_palette(owner: Node2D,t: Dictionary) -> void:
	var g: Session=_group(owner)
	if g==null or not is_same(owner._i171_palette_callback,t) or not owner._tracks.any(func(actual):return is_same(actual,t)) or t.get("kind")!="source_palette" or t.has("actor"):return
	# Distinct actual scheduled writer intent revokes even equal color/amount.
	g.shade_lost=true
static func _command(s: Dictionary,g: Session) -> Array[Dictionary]:
	var trace: Array=g.owner.get_meta("source_legacy_impact_commands",[]);trace.append(int(s.source_line));g.owner.set_meta("source_legacy_impact_commands",trace)
	match str(s.mode):
		"setalpha":
			g.alpha=[int(s.source_args[0]),int(s.source_args[1])]
			g.owner.set_meta("source_legacy_impact_alpha",g.alpha.duplicate())
			_refresh_AB(g);return []
		"blendoff":
			g.alpha=[16,0];g.owner.set_meta("source_legacy_impact_alpha",g.alpha.duplicate())
			_refresh_AB(g);return []
		"monbgprio_28":
			var target_id: int=g.context.target_ids[0] if not g.context.target_ids.is_empty() else -1
			g.priority28=not g.context.contest and _position(g.context,target_id) in [0,3]
			_depth(g);return []
		"clearmonbg":
			for r: Record in g.records:
				if r.kind!="BG" or r.retired:continue
				r.track.cleared=true;r.track.clear_callbacks=0
				for member: Record in r.baseline.members:_hide_mirror(member,g)
			return []
	if s.mode!="monbg" or g.anchor==null:return []
	var r:=Record.new();r.kind="BG";r.line=int(s.source_line);r.settings=s.duplicate(true);r.baseline.members=[]
	r.track={"kind":"source_frenzy_BG","domain":"maintenance","age":0,"ticks":4096,"owner":g.owner,"context":g.context,"settings":s.duplicate(true),"clones":[],"cleared":false,"clear_callbacks":0,"update":advance}
	for actor: BattleAnimationActor in Owned.source_bg_members(g.context,1):
		var b: Dictionary=_binding(g,actor.id)
		if b.is_empty():continue
		var n:=Sprite2D.new()
		var member:=Record.new();member.kind="mirror";member.node=n;member.actor_id=actor.id;member.settings={};member.baseline={"binding":b,"visible":actor.sprite.visible,"frame":_frame(actor.sprite),"restored":false,"hide_owned":false}
		member.item={"node":n,"parent":null,"writes":{},"lost":{},"position":_position(g.context,actor.id),"birth":g.serial};g.serial+=1
		# Publish the FULL current recipe off-tree, including shear and both tints.
		for key: String in Owned.FOLLOW:_seed(member.item,key,actor.sprite.get(key))
		_seed(member.item,"transform",g.owner.global_transform.affine_inverse()*actor.sprite.global_transform)
		_seed(member.item,"visible",true)
		_install_AB(member,actor.sprite.material,g,true)
		# Register the complete prospective group before ranking or observable publication.
		r.baseline.members.append(member);g.records.append(member);r.track.clones.append({"actor":actor,"node":n})
	g.records.append(r)
	if not _depth(g):
		# No partial publication, no original hide, no controller/barrier admission.
		for member: Record in r.baseline.members:
			g.records.erase(member)
			if _sprite(member.node) and not member.node.is_queued_for_deletion():member.node.queue_free()
		g.records.erase(r)
		return []
	for member: Record in r.baseline.members:
		member.item.parent=g.owner
		g.owner.add_child(member.node)
		# Source membership/recipes/depth already exist for synchronous read-only observers.
		var b: Dictionary=_binding(g,member.actor_id)
		if b.is_empty():_retire(member);continue
		b.actor.apply_source_state("hidden",true);member.baseline.hide_owned=true
	var call: Invocation=_calls.get(g.owner.get_instance_id()) as Invocation;call.initial=r.track;advance(r.track,g.context);call.initial={}
	return [r.track]
static func _hide_mirror(r: Record,g: Session) -> void:
	if not r.baseline.get("restored",false):
		r.baseline.restored=true
		var b: Dictionary=r.baseline.binding
		if r.baseline.get("hide_owned",false) and _same_visual(b,g,false):
			var actor: BattleAnimationActor=b.actor
			if actor._owned_hidden and not actor._expected_visible:
				# Conditional release preserves a differing foreign value and tombstones
				# this original hide so a later equal return cannot reacquire it.
				actor.apply_source_state("hidden",false)
	if _sprite(r.node) and r.node.get_parent()==g.owner:Owned.write(r.item,"visible",false)
static func _mirror(r: Record,g: Session) -> void:
	if r.retired:return
	var b: Dictionary=_binding(g,r.actor_id)
	if b.is_empty() or not _sprite(r.node) or r.node.get_parent()!=g.owner:_hide_mirror(r,g);_retire(r);return
	var n: Sprite2D=b.sprite
	for key: String in Owned.FOLLOW:
		if key=="material":continue
		Owned.write(r.item,key,n.get(key))
	Owned.write(r.item,"transform",g.owner.global_transform.affine_inverse()*n.global_transform)
	Owned.write(r.item,"visible",true)
	_install_AB(r,n.material,g)

static func _depth(g: Session) -> bool:
	if g.anchor==null:return false
	var low: int=maxi(-4096,maxi(g.floor_z,_z(g.owner)-4096));var high: int=mini(4096,_z(g.owner)+4096)-16
	if low>high:
		for r: Record in g.records:
			if r.kind=="mirror":_hide_mirror(r,g);_retire(r)
			elif r.kind in ["root","hit"]:_retire(r)
		return false
	var band: int=clampi(int(g.anchor)-2,low,high);var members: Array=[]
	for r: Record in g.records:
		if r.retired or not r.kind in ["root","hit","mirror"] or not _sprite(r.node) or r.node.is_queued_for_deletion():continue
		if r.item.lost.has("z_index"):continue
		var key: Array=[]
		if r.kind=="mirror":
			var bg: int=1 if g.context.contest or int(r.item.position) in [1,2] else 2
			key=[0,0,0,int(r.item.birth)] if bg==1 and g.priority28 else [2,bg,0,int(r.item.birth)]
		else:
			var y: int=(int(r.item.point.y)-16)&255
			if y>=160:y-=256
			key=[1,int(r.item.sub),-y,int(r.item.birth)]
		members.append({"record":r,"key":key})
	members.sort_custom(func(a: Dictionary,b: Dictionary)->bool:
		for index: int in 4:
			if a.key[index]!=b.key[index]:return a.key[index]>b.key[index]
		return false)
	for rank: int in members.size():
		var r: Record=members[rank].record
		Owned.write(r.item,"z_index",band+rank-_z(g.owner))
	return true
static func actor_step(t: Dictionary,c: BattleAnimationContext) -> void:
	var owner: Variant=t.get("owner")
	if not _object(owner) or not owner is BattleAnimationSequenceRunner:return
	var g: Session=_group(owner)
	if g==null:return
	var r: Record=_record(g,t)
	if r==null or not _lane(r,g,c) or not _number(t.get("age"),true):return
	if int(t.age)!=r.callback+1:return
	r.callback=int(t.age)
	if _binding(g,r.actor_id).is_empty():g.offset=Vector2.ZERO;r.retired=true;t.ticks=int(t.age);return
	var age: int=int(t.age)
	g.offset=Vector2.ZERO if age>=39 else Vector2(8 if ((age+1)/2)%2==0 else 0,0)
	if age>=39:r.retired=true;t.ticks=age
static func resolve_offset(owner: Node2D,a: BattleAnimationActor) -> Vector2:
	var g: Session=_group(owner)
	if g==null or not _valid(g,true) or g.offset_lost or _binding(g,a.id).is_empty() or g.context.target_ids.is_empty() or a.id!=g.context.target_ids[0]:return Vector2.ZERO
	var parent: Node2D=a.sprite.get_parent()
	return parent.global_transform.basis_xform_inv(g.context.field.global_transform.basis_xform(g.offset))
static func note_held_write(owner: Node2D,t: Dictionary,value: Vector2) -> void:
	var g: Session=_group(owner);var candidate: Variant=t.get("actor")
	if g==null or not _actor(candidate) or not is_same(owner._i159_actor_callback_track,t) or not owner._tracks.any(func(actual):return is_same(actual,t)) or t.get("kind")=="source_frenzy_actor":return
	var b: Dictionary=_binding(g,candidate.id)
	if b.is_empty() or not is_same(candidate,b.actor) or g.context.target_ids.is_empty() or candidate.id!=g.context.target_ids[0]:return
	g.offset_lost=true;g.held_receipt={"actor_id":candidate.id,"value":value}
static func before_track(owner: Node2D,t: Variant) -> bool:
	var g: Session=_group(owner)
	if g==null:return true
	if not t is Dictionary:return false
	var r: Record=_record(g,t)
	if r!=null:
		var good: bool=_valid(g,true) and _object(t.get("owner")) and is_same(t.get("owner"),owner) and _number(t.get("age"),true) and _number(t.get("ticks"),true) and Same._same(t.get("settings"),r.settings)
		if r.kind in ["root","hit"]:good=good and _sprite(t.get("node")) and is_same(t.get("node"),r.node)
		if r.kind=="actor":good=good and _actor(t.get("actor")) and t.actor.id==r.actor_id
		if r.kind=="BG":
			var public_members: Variant=t.get("clones")
			good=good and public_members is Array and public_members.size()==r.baseline.members.size()
			if good:
				for index: int in public_members.size():
					var exposed: Variant=public_members[index];var member: Record=r.baseline.members[index]
					if not exposed is Dictionary or not _sprite(exposed.get("node")) or not is_same(exposed.node,member.node) or not _actor(exposed.get("actor")) or not is_same(exposed.actor,member.baseline.binding.actor):good=false;break
		if r.kind=="actor":good=good and g.bindings.has(r.actor_id) and is_same(t.get("actor"),g.bindings[r.actor_id].actor)
		if r.kind!="actor":good=good and t.get("update") is Callable
		good=good and int(t.get("age",-1))==r.callback and str(t.get("kind",""))==("source_frenzy_particle" if r.kind in ["root","hit"] else "source_frenzy_"+r.kind)
		if not good:
			if r.kind=="BG":
				for member: Record in r.baseline.members:_hide_mirror(member,g);_retire(member)
			if r.kind=="actor":g.offset=Vector2.ZERO
			_retire(r);owner._tracks.erase(t);return false
	if r==null and str(t.get("kind","")).begins_with("source_frenzy_"):owner._tracks.erase(t);return false
	if t.has("actor") and not _actor(t.actor):owner._tracks.erase(t);return false
	return true
static func actor_allowed(owner: Node2D,value: Variant) -> bool:
	var g: Session=_group(owner)
	if g==null:return true
	if not _actor(value):return false
	if not g.bindings.has(value.id):return true
	return not _binding(g,value.id).is_empty()
static func after_pose(owner: Node2D,c: BattleAnimationContext) -> void:
	var g: Session=_group(owner)
	if g==null or not owner._i171_post_pose:return
	_stamp+=1
	if not _valid(g):
		for r: Record in g.records:
			if r.kind=="mirror":_hide_mirror(r,g)
			if r.kind in ["mirror","root","hit"]:_retire(r)
		return
	for r: Record in g.records:
		if r.kind=="BG" and not r.track.get("cleared",false):
			for member: Record in r.baseline.members:_mirror(member,g)
		elif r.kind in ["root","hit"]:_project(r,g)
	_depth(g)
static func terminal(owner: Node2D) -> Array:
	var g: Session=_group(owner);var invalid: Array=[]
	if g==null:return invalid
	for id: int in g.bindings:
		var b: Dictionary=g.bindings[id]
		if not _same_visual(b,g,false):invalid.append(b.actor)
		else:release_actor(owner,b.actor)
	return invalid
static func release(owner: Node2D) -> void:
	var g: Session=_group(owner)
	if g==null or g.released:return
	g.released=true
	for r: Record in g.records:
		if r.kind=="mirror":_hide_mirror(r,g)
		_retire(r)
	if not g.shade.is_empty() and _object(g.shade.node) and g.shade.node is Polygon2D and g.shade.node.get_parent()==owner and is_same(owner._background_blend,g.shade.node):
		if g.shade.prior:
			for key: String in g.shade.writes:
				if not g.shade.lost.has(key) and g.shade.node.get(key)==g.shade.writes[key]:g.shade.node.set(key,g.shade.baseline[key])
		elif not g.shade_lost:g.shade.node.queue_free();owner._background_blend=null
	g.records.clear();g.bindings.clear();g.shade={};g.program.clear()
	_calls.erase(owner.get_instance_id());owner.remove_meta(STATE)

static func finish_context_loss(owner: Node2D,terminal_state: String="cancelled") -> bool:
	var g: Session=_group(owner)
	if g==null:return false
	_stamp+=1 # The runner calls this first every tick: a new tick re-proves the program.
	var live: Variant=owner.context
	if live is BattleAnimationContext and _object(live.field) and live.field is Node2D and live.field.is_inside_tree():return false
	# Captured cleanup is not a temporary replacement of the live source context.
	owner.state=terminal_state;owner.lifecycle_aborted=true
	for id: int in g.bindings:
		var b: Dictionary=g.bindings[id]
		if _same_visual(b,g,false):release_actor(owner,b.actor)
	release(owner)
	for child: Node in owner.get_children():
		if child is AudioStreamPlayer2D:child.stop()
		child.queue_free()
	owner._tracks.clear();owner._source_palette_banks.clear();owner.terminated.emit(terminal_state);owner.queue_free();return true

static func note_application(owner: Node2D,a: Variant,held: Vector2,approach: Vector2,offset: Vector2) -> void:
	var g: Session=_group(owner)
	if g==null or not _actor(a) or not is_same(owner._i159_actor_apply_actor,a) or g.held_receipt.is_empty() or a.id!=g.held_receipt.actor_id:return
	var b: Dictionary=_binding(g,a.id)
	if b.is_empty() or not is_same(a,b.actor):return
	var total: Vector2=held+approach+offset
	g.applied={"held":held,"total":total,"position":a._expected_position,"valid":held==g.held_receipt.value and a._offset==total and b.sprite.position==a._expected_position}
static func after_palette_writer(_owner: Node2D,_t: Dictionary) -> void:pass
static func observe_palette_application(_owner: Node2D,_a: BattleAnimationActor,_transient: bool) -> void:pass
static func release_actor(owner: Node2D,candidate: Variant) -> bool:
	var g: Session=_group(owner)
	if g==null:return false
	if not _actor(candidate):return true
	if not g.bindings.has(candidate.id):
		for b: Dictionary in g.bindings.values():
			if _sprite(candidate.sprite) and candidate.sprite==b.sprite:return true
		return false
	var b: Dictionary=g.bindings[candidate.id]
	if not is_same(candidate,b.actor) or g.released_actors.has(candidate.id) or not _same_visual(b,g,false):return true
	var keep_held: bool=not g.held_receipt.is_empty() and candidate.id==g.held_receipt.actor_id and g.applied.get("valid",false) and owner._held_offsets.get(candidate.id)==g.held_receipt.value and candidate._offset==g.applied.total and b.sprite.position==g.applied.position
	# Finite338 never owns the original actor's material as a side effect of hiding it.
	# Material publication is independently receipted; release must not reset a borrowed one.
	var material: Material=b.sprite.material
	_restore_palette(g,candidate)
	material=b.sprite.material
	candidate.release()
	if keep_held and _same_visual(b,g,false):candidate.add_layout_offset(g.held_receipt.value)
	if _same_visual(b,g,false):b.sprite.material=material
	g.released_actors[candidate.id]=true;return true

static func _context_shape(c: BattleAnimationContext) -> bool:
	if c==null or not _object(c.field) or not c.field is Node2D or not c.field.is_inside_tree():return false
	for key: Variant in c.source_positions:
		if typeof(key)!=TYPE_INT or not _number(c.source_positions[key],true) or int(c.source_positions[key]) not in [0,1,2,3]:return false
	var bank: Array=_bank_receipt(c)
	if c.contest and bank.size()==2 and bank[0] and (typeof(bank[1])!=TYPE_INT or int(bank[1]) not in [0,1,2,3]):return false
	if _position(c,c.attacker_id)<0 or c.target_ids.is_empty() or _position(c,c.target_ids[0])<0:return false
	return true

static func _seed(item: Dictionary,key: String,value: Variant) -> void:
	item.node.set(key,value);item.writes[key]=item.node.get(key)
static func _bank_receipt(c: BattleAnimationContext) -> Array:
	if c==null:return []
	if not c.contest:return [false]
	var actor: Variant=c.actors.get(c.attacker_id)
	if not _actor(actor) or not _sprite(actor.sprite):return [false]
	var n: Sprite2D=actor.sprite
	if not n.has_meta("animation_source_bank"):return [false]
	return [true,n.get_meta("animation_source_bank")]
static func _source_subpriority(c: BattleAnimationContext) -> int:
	if not c.contest:return [30,40,20,50][_position(c,c.attacker_id)]
	var receipt: Array=_bank_receipt(c)
	if receipt.size()==2 and receipt[0]:return 30 if int(receipt[1])==2 else 40
	# Explicit semantic source-position fallback, never arbitrary native ID parity.
	return 30 if _position(c,c.attacker_id)==2 else 40
static func _known_material(m: Variant) -> bool:
	return _object(m) and m is ShaderMaterial and (m.shader==COMBINED or m.shader==PALETTE)
static func _uniforms(m: ShaderMaterial) -> Dictionary:
	var out: Dictionary={}
	if m.shader==null:return out
	for field: Dictionary in m.shader.get_shader_uniform_list():
		var key: String=str(field.name)
		out[key]=m.get_shader_parameter(key)
	return out
static func _install_AB(r: Record,source: Material,g: Session,initial: bool=false) -> void:
	var item: Dictionary=r.item
	if not initial and not Owned.node(item):return
	var state: Dictionary=item.get("AB",{})
	if not state.is_empty():
		if r.node.material!=state.material or state.material.shader!=state.shader:state.lost=true
		for key: String in state.writes:
			if state.material.get_shader_parameter(key)!=state.writes[key]:state.revoked[key]=true
		if state.lost:return
	if state.is_empty() or not is_same(state.source,source):
		if not initial and item.lost.has("material"):return
		if source!=null and not _known_material(source):
			# Literal input-stage custom-shader policy: no post-shader parity promise.
			if initial:_seed(item,"material",source)
			else:Owned.write(item,"material",source)
			item.erase("AB");return
		var revoked: Dictionary=state.get("revoked",{}).duplicate()
		var m:=ShaderMaterial.new();m.shader=COMBINED
		if source!=null:
			for key: String in _uniforms(source):m.set_shader_parameter(key,source.get_shader_parameter(key))
		m.set_shader_parameter("eva",float(g.alpha[0])/16.0);m.set_shader_parameter("evb",float(g.alpha[1])/16.0)
		if source==null:m.set_shader_parameter("blend_amount",0.0)
		state={"material":m,"shader":COMBINED,"source":source,"writes":{},"revoked":revoked,"lost":false};item.AB=state
		if initial:_seed(item,"material",m)
		else:Owned.write(item,"material",m)
	if source!=null:
		for key: String in _uniforms(source):
			if key in ["eva","evb"] or state.revoked.has(key):continue
			state.material.set_shader_parameter(key,source.get_shader_parameter(key))
			state.writes[key]=state.material.get_shader_parameter(key)
	for key: String in ["eva","evb"]:
		if state.revoked.has(key):continue
		state.material.set_shader_parameter(key,float(g.alpha[0 if key=="eva" else 1])/16.0)
		state.writes[key]=state.material.get_shader_parameter(key)
static func _refresh_AB(g: Session) -> void:
	for r: Record in g.records:
		if r.retired:continue
		if r.kind=="mirror":_install_AB(r,r.baseline.binding.sprite.material,g)
		elif r.kind=="hit" and _sprite(r.node) and r.node.material is ShaderMaterial:
			# Particle material belongs only to this finite object, never its actor.
			if not r.item.has("AB"):r.item.AB={"material":r.node.material,"shader":COMBINED,"source":null,"writes":{},"revoked":{},"lost":false}
			_install_AB(r,null,g)
static func _palette_observe(lease: Dictionary,n: Sprite2D) -> bool:
	if n.material!=lease.material or not _object(lease.material) or lease.material.shader!=lease.shader:lease.lost=true
	if lease.lost:return false
	for key: String in lease.writes:
		if lease.material.get_shader_parameter(key)!=lease.writes[key]:lease.revoked[key]=true
	for key: String in lease.baseline:
		if not lease.writes.has(key) and lease.material.get_shader_parameter(key)!=lease.baseline[key]:lease.foreign[key]=true
	return true
static func handle_palette(owner: Node2D,a: BattleAnimationActor,blend: Dictionary,transient: bool) -> bool:
	var g: Session=_group(owner)
	if g==null or not g.bindings.has(a.id):return false
	var b: Dictionary=_binding(g,a.id)
	if b.is_empty():return true
	var held: Variant=owner._held_blends.get(a.id)
	var actual: bool=transient or held is Dictionary
	var lease: Dictionary=g.palettes.get(a.id,{})
	if not actual and lease.is_empty():return true # Borrowed entry material is unclaimed.
	if not lease.is_empty() and not _palette_observe(lease,b.sprite):return true
	if lease.is_empty():
		var prior: Material=b.sprite.material
		var m:=ShaderMaterial.new();m.shader=PALETTE
		# Adopted known recipes keep unrelated wave/invert/tint inputs.
		if _known_material(prior):
			for key: String in _uniforms(prior):m.set_shader_parameter(key,prior.get_shader_parameter(key))
		lease={"material":m,"shader":PALETTE,"prior":prior,"writes":{},"revoked":{},"lost":false,"held":{},"held_receipt":null,"transient":false,"foreign":{},"baseline":_uniforms(m)}
		g.palettes[a.id]=lease;b.sprite.material=m
	var fields: Dictionary={"blend_color":blend.get("color",Color.WHITE),"blend_amount":float(blend.get("amount",0.0))}
	for key: String in ["wave_amplitude","wave_phase","wave_height","wave_start","wave_end","wave_scale_x","wave_scale_y"]:
		if blend.has(key):fields[key]=blend[key]
	# Capture the actual held recipe even while a transient is the final winner.
	if held is Dictionary:
		lease.held={"blend_color":held.get("color",Color.WHITE),"blend_amount":float(held.get("amount",0.0))};lease.held_receipt=held
		for key: String in ["wave_amplitude","wave_phase","wave_height","wave_start","wave_end","wave_scale_x","wave_scale_y"]:
			if held.has(key):lease.held[key]=held[key]
	if not transient and not held is Dictionary and lease.transient:
		_restore_palette(g,a);return true
	# Only explicit fields are owned. Stop stale transient wave fields independently.
	for key: String in lease.writes:
		if key not in fields and not lease.revoked.has(key):
			if lease.held.has(key):fields[key]=lease.held[key]
			else:fields[key]=lease.baseline.get(key) if lease.has("baseline") else null
	if not lease.has("baseline"):lease.baseline=_uniforms(lease.material)
	for key: String in fields:
		if lease.revoked.has(key):continue
		lease.material.set_shader_parameter(key,fields[key]);lease.writes[key]=lease.material.get_shader_parameter(key)
	lease.transient=transient
	return true
static func _restore_palette(g: Session,a: BattleAnimationActor) -> void:
	var lease: Dictionary=g.palettes.get(a.id,{})
	if lease.is_empty() or not _palette_observe(lease,a.sprite):return
	var held_valid: bool=not lease.held.is_empty() and is_same(g.owner._held_blends.get(a.id),lease.held_receipt)
	if not held_valid:
		# Release only still-owned writes; preserve foreign shader/uniform intent.
		if lease.revoked.is_empty() and lease.foreign.is_empty():a.sprite.material=lease.prior
		else:
			for key: String in lease.writes:
				if not lease.revoked.has(key):lease.material.set_shader_parameter(key,lease.baseline.get(key))
		return
	for key: String in lease.writes:
		if lease.revoked.has(key):continue
		lease.material.set_shader_parameter(key,lease.held.get(key,lease.baseline.get(key)))

extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Finite Secret Power/Magical Leaf composition. Each original builtin invocation is the capability;
## copied resources retain their independent literal workers. Ordinary Surf/Muddy Water
## opt in only to the shared Surf parent/child and its existing ownership leases.
const Data=preload("res://scripts/battle/animations/sequence/source_secret_power_data.gd")
const SurfData=preload("res://scripts/battle/animations/sequence/source_surf_data.gd")
const MagicalData=preload("res://scripts/battle/animations/sequence/source_magical_leaf_data.gd")
const Gate=preload("res://scripts/battle/animations/sequence/source_musical_composition.gd")
const Same=preload("res://scripts/battle/animations/sequence/source_cutting_slice.gd")
const Owned=preload("res://scripts/battle/animations/sequence/source_owned_composition.gd")
const Pair=preload("res://scripts/battle/animations/sequence/source_charge_owned.gd")
const Fast=preload("res://scripts/battle/animations/sequence/source_program_proof.gd")
const RECOLOR=preload("res://scripts/battle/animations/sequence/particle_recolor.gdshader")
const PALETTE=preload("res://scripts/battle/animations/sequence/palette_blend.gdshader")
const COMBINED=preload("res://scripts/battle/animations/sequence/source_agility_aerial_palette_ab.gdshader")
const SURF=preload("res://scripts/battle/animations/sequence/source_surf.gdshader")
const ATLAS="res://graficos/batalla/animaciones/secret_power_surf_maps.png"
const MUDDY_ATLAS="res://graficos/batalla/animaciones/source_muddy_water_maps.png"
const KEY="ruby:move/290"
# Fixed readonly canonical descriptions select authority, never equal recipe values.
# Execution/tables/leases below remain shared; environment narrowing belongs290 only.
const SECRET_DESCRIPTOR={"key":KEY,"program":Data.PROGRAM,"sites":Data.SITES,"environment_u8":true}
const MAGICAL_DESCRIPTOR={"key":"ruby:move/345","program":MagicalData.PROGRAM,"sites":MagicalData.SITES,"environment_u8":false}
const STATE="i159_secret_power_session"
const ART=["texture","frame_rects","color","recolor","scale_factor","flip_h","flip_v","palette_bank_height"]
const COLORS=[Vector3i(31,0,0),Vector3i(31,19,0),Vector3i(31,31,0),Vector3i(0,31,0),Vector3i(5,14,31),Vector3i(22,10,31),Vector3i(22,21,31)]
class Invocation extends RefCounted:
	var incoming: Dictionary
	var context: BattleAnimationContext
	var definition: Resource
	var descriptor: Dictionary={}
	var pc: int
	var claimed: bool=false
class Session extends RefCounted:
	var context: BattleAnimationContext
	var definition: Resource
	var descriptor: Dictionary={}
	var program: Array
	var proof: Fast.Proof
	var proof_stamp: int=-1
	var originals: Dictionary={}
	var objects: Array=[]
	var backgrounds: Array=[]
	var valid: bool=true
	var alpha: bool=false
	var coefficients:=Vector2(0.75,0.5)
	var priority: int=2
	var promoted: bool=false
	var random:=RandomNumberGenerator.new()
	var palette_color:=Color(1,0,0)
	var palette_amount: float=0.0
	var lost_roles: Dictionary={}
	var held: Dictionary={}
	var applied: Dictionary={}
	var birth_delta: Dictionary={}
	var foreign_actors: Array=[]
	var foreign_palette_writes: Array=[]
static var _invocations: Dictionary={}
# Proof memo: bumped whenever control can leave this module (tick start, dispatch open/close).
static var _stamp: int=0

static func _descriptor(owner: Node2D) -> Dictionary:
	if not owner is BattleAnimationSequenceRunner or owner.definition==null:return {}
	if is_same(owner.definition,BattleAnimationSequenceRegistry._builtin_source_definitions.get(KEY)):return SECRET_DESCRIPTOR
	if is_same(owner.definition,BattleAnimationSequenceRegistry._builtin_source_definitions.get(MAGICAL_DESCRIPTOR.key)):return MAGICAL_DESCRIPTOR
	for descriptor: Dictionary in [SurfData.DESCRIPTOR_57,SurfData.DESCRIPTOR_330]:
		if is_same(owner.definition,BattleAnimationSequenceRegistry._builtin_source_definitions.get(descriptor.key)):return descriptor
	return {}
static func matches(owner: Node2D) -> bool:return not _descriptor(owner).is_empty()
static func _integral(v: Variant) -> bool:return Gate._integral(v)
static func _s16(v: int) -> int:return ((v+32768)&65535)-32768
static func _div(n: int,d: int) -> int:return int(float(n)/float(d)) if d!=0 else 0
static func _sin(p: int,a: int) -> int:return BattleSourceTrig.sine(p,a)
static func _cos(p: int,a: int) -> int:return BattleSourceTrig.cosine(p,a)
static func _texture(v: Variant) -> Texture2D:return Fast.texture(v)
static func _visible(s: Dictionary) -> bool:return s.get("behavior") in ["sheet","source_particle","source_surf"]
static func _art(s: Dictionary) -> Dictionary:
	var a: Dictionary={}
	for key: Variant in s:
		if str(key) in ART:a[str(key)]=s[key]
	var texture: Texture2D=_texture(a.get("texture"))
	if texture==null:return {}
	var factor: Variant=a.get("scale_factor",1)
	if typeof(factor) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(factor)) or float(factor)<=0:return {}
	for flag: String in ["recolor","flip_h","flip_v"]:
		if a.has(flag) and typeof(a[flag])!=TYPE_BOOL:return {}
	if a.has("color") and (typeof(a.color)!=TYPE_STRING or not Color.html_is_valid(a.color)):return {}
	if a.has("palette_bank_height") and (not _integral(a.palette_bank_height) or float(a.palette_bank_height)<=0):return {}
	if a.has("frame_rects"):
		if not a.frame_rects is Dictionary or a.frame_rects.is_empty():return {}
		for key: Variant in a.frame_rects:
			if typeof(key)!=TYPE_STRING:return {}
			var rect: Variant=a.frame_rects[key]
			if not rect is Array or rect.size()!=4:return {}
			for value: Variant in rect:
				if not _integral(value):return {}
			if rect[0]<0 or rect[1]<0 or rect[2]<=0 or rect[3]<=0 or rect[0]+rect[2]>texture.get_width() or rect[1]+rect[3]>texture.get_height():return {}
	return a
static func _shape(actual: Variant,expected: Dictionary) -> bool:
	if not actual is Dictionary:return false
	var art: bool=_visible(expected)
	for key: String in expected:
		if art and key in ART:continue
		if not actual.has(key) or not Same._same(actual[key],expected[key]):return false
	for key: Variant in actual:
		var name: String
		if typeof(key)==TYPE_STRING:name=key
		elif typeof(key)==TYPE_STRING_NAME and art and str(key) in ART:name=str(key)
		else:return false
		if not expected.has(name) and (not art or name not in ART):return false
	return not art or not _art(actual).is_empty()
## Texture resources bypass pathname validation only for an exact supported ordinary
## builtin, complete unchanged non-ART program and the original Surf effect object.
static func accepts_texture_dependency(d: BattleAnimationDefinition,s: Dictionary) -> bool:
	for descriptor: Dictionary in [SurfData.DESCRIPTOR_57,SurfData.DESCRIPTOR_330]:
		if not is_same(d,BattleAnimationSequenceRegistry._builtin_source_definitions.get(descriptor.key)):continue
		var program: Dictionary=descriptor.program
		if d.key!=descriptor.key or d.coverage!=program.coverage or d.source_script!=program.source_script or d.steps.size()!=program.steps.size():return false
		for pc: int in program.steps.size():
			if not _shape(d.steps[pc],program.steps[pc]):return false
		for pc: int in program.steps.size():
			if not is_same(d.steps[pc],s):continue
			if program.steps[pc].get("behavior")!="source_surf" or program.steps[pc].get("source_task")!="AnimTask_CreateSurfWave" or not s.get("texture") is Texture2D:return false
			var rects: Variant=s.get("frame_rects")
			if not rects is Dictionary:return false
			for index: int in 21:
				if not rects.has(str(index)):return false
			return not _art(s).is_empty()
	return false
static func _whole(owner: Node2D) -> bool:
	var descriptor: Dictionary=_descriptor(owner)
	if descriptor.is_empty():return false
	var program: Dictionary=descriptor.program
	if owner.definition.key!=descriptor.key or owner.definition.coverage!=program.coverage or owner.definition.source_script!=program.source_script or not Same._same(owner._steps,owner.definition.steps) or owner._steps.size()!=program.steps.size():return false
	for pc: int in program.steps.size():
		if not _shape(owner._steps[pc],program.steps[pc]):return false
	return true
## Cheap proof that the live program still equals the admitted one; the full scan stays the authority.
static func _program_ok(owner: Node2D,g: Session,snapshot: bool,memo: bool=false) -> bool:
	if memo and g!=null and g.proof_stamp==_stamp:return true
	var descriptor: Dictionary=_descriptor(owner)
	if descriptor.is_empty():return false
	var program: Dictionary=descriptor.program
	var good: bool=false
	if g!=null and g.proof!=null and owner.definition.key==descriptor.key and owner.definition.coverage==program.coverage and owner.definition.source_script==program.source_script and owner._steps.size()==program.steps.size():
		good=Fast.holds(owner._steps,owner.definition.steps,g.program,g.proof,func(pc: int,step: Dictionary) -> bool:return _shape(step,program.steps[pc]))
	if not good:good=(not snapshot or Same._same(g.program,owner._steps)) and _whole(owner)
	if good and g!=null:g.proof_stamp=_stamp
	return good
static func open_dispatch(owner: Node2D,step: Dictionary) -> Invocation:
	if not matches(owner) or not owner._i159_dispatch_live or _invocations.has(owner.get_instance_id()):return null
	_stamp+=1
	var scope:=Invocation.new();scope.incoming=step;scope.context=owner.context;scope.definition=owner.definition;scope.descriptor=_descriptor(owner);scope.pc=owner._pc
	_invocations[owner.get_instance_id()]=scope;return scope
static func close_dispatch(owner: Node2D,scope: Invocation) -> void:
	_stamp+=1
	if scope!=null and is_same(_invocations.get(owner.get_instance_id()),scope):_invocations.erase(owner.get_instance_id())
static func _group(owner: Node2D) -> Session:return owner.get_meta(STATE) as Session if owner.has_meta(STATE) else null
static func _admit(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> bool:
	var scope: Invocation=_invocations.get(owner.get_instance_id()) as Invocation;var g: Session=_group(owner);var descriptor: Dictionary=_descriptor(owner)
	if scope==null or scope.claimed or not owner._i159_dispatch_live or not is_same(scope.incoming,s) or not is_same(scope.context,c) or not is_same(owner.context,c) or not is_same(scope.definition,owner.definition) or not is_same(scope.descriptor,descriptor) or scope.pc!=owner._pc or (g!=null and (not g.valid or not is_same(g.descriptor,descriptor))) or not _program_ok(owner,g,false):return false
	var program: Dictionary=descriptor.program
	if scope.pc<0 or scope.pc>=program.steps.size():return false
	var expected: Dictionary=program.steps[scope.pc];var plain: Dictionary=s.duplicate(true)
	var priority: Dictionary=BattleSourcePriority.command_metadata(program.steps[scope.pc-1]) if scope.pc>0 else {}
	if expected.has("source_command_priority"):
		var authored: Dictionary=expected.source_command_priority;var projected: Dictionary={}
		for key: String in ["template","raw_offset","encoded_byte","basis","raw_role","delta"]:
			if not priority.has(key):return false
			projected[key]=priority[key]
		if not Gate._priority_exact(authored,projected) or not Gate._priority_exact(plain.get("source_command_priority"),authored):return false
	elif not priority.is_empty():
		if priority.size()!=9 or not Gate._priority_exact(plain.get("source_command_priority"),priority):return false
		plain.erase("source_command_priority")
	elif plain.has("source_command_priority"):return false
	if not _shape(plain,expected) or not Same._same(plain,owner._steps[scope.pc]):return false
	if not owner.claim_effect_dispatch(s):return false
	scope.claimed=true;return true
static func _session(owner: Node2D,c: BattleAnimationContext) -> Session:
	var g: Session=_group(owner)
	if g==null:
		g=Session.new();g.context=c;g.definition=owner.definition;g.descriptor=_descriptor(owner);g.program=owner._steps.duplicate(true);g.proof=Fast.capture(g.program);g.random.seed=c.seed_value
		for a: BattleAnimationActor in c.actors.values():
			if a.is_present():g.originals[a.id]=Gate._binding(a,c,owner)
		owner.set_meta(STATE,g)
	return g
static func environment(owner: Node2D,value: Variant) -> Variant:
	var descriptor: Dictionary=_descriptor(owner)
	if descriptor.is_empty() or not descriptor.environment_u8:return value
	return int(value)&255 if _integral(value) else null
static func _original(g: Session,c: BattleAnimationContext,role: int) -> Dictionary:
	var id: int=c.attacker_id if role==0 else (c.target_ids[0] if not c.target_ids.is_empty() else -1)
	var binding: Dictionary=g.originals.get(id,{})
	return binding if g.valid and not g.lost_roles.has(id) and not binding.is_empty() and Gate._bound(binding,c) else {}
static func _center(b: Dictionary,c: BattleAnimationContext) -> Vector2:return Gate._source_center(b.actor,c)
static func _field_pose(c: BattleAnimationContext,owner: Node2D,point: Vector2,scale: Vector2=Vector2.ONE,angle: float=0) -> Transform2D:
	return owner.global_transform.affine_inverse()*c.field.global_transform*Transform2D(angle,scale,0,point)
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var out: Array[Dictionary]=[]
	if not _admit(s,c,owner):return out
	var g: Session=_session(owner,c)
	match str(s.mode):
		"monbg":
			out=Pair._create_pair_bg(c,owner,int(s.source_args[0]),"source_legacy_impact_bg","source_legacy_impact_backgrounds")
			for t: Dictionary in out:g.backgrounds.append(t)
		"clearmonbg":
			for t: Dictionary in g.backgrounds:
				if not t.get("cleared",false):Pair._clear_pair(t)
		"setalpha":g.alpha=true;g.coefficients=Vector2(float(s.source_args[0])/16,float(s.source_args[1])/16)
		"blendoff":g.alpha=false
		"monbgprio_28":
			var role: int=0 if int(s.source_args[0])==0 else 1;var selected: Dictionary=_original(g,c,role)
			if not c.contest and not selected.is_empty() and c.source_position(selected.actor.id) in [0,3]:g.promoted=true
	return out

## Exact original admission occurs before any source-specific normalization.
static func effect(s: Dictionary,c: BattleAnimationContext,owner: Node2D,kind: String) -> Variant:
	if not matches(owner):return null
	# Surf-only descriptors must not capture any other Secret Power effect.
	if _descriptor(owner).get("surf_only",false) and (kind!="source_surf" or s.get("source_task")!="AnimTask_CreateSurfWave"):return null
	if not _admit(s,c,owner):return []
	var g: Session=_session(owner,c);var site: Dictionary=g.descriptor.sites.get(str(int(s.get("source_line",-1))),{})
	if site.is_empty():return []
	var root: String=site.root_profile
	if root=="sub_80E24B8":return BattleEffectBehaviorRegistry.LegacyDummyShake.create(s,c,owner)
	if root=="AnimTask_CreateSurfWave":return _surf(s,c,owner,g,site)
	if root=="sub_80CC5F8" or root=="sub_80D3630":return _maintenance(s,c,owner,g,site)
	if kind in ["source_actor","actor_motion"] or root in ["AnimTask_ShakeMon","AnimTask_ShakeMon2","AnimTask_ShakeMonInPlace","AnimTask_ShakeAndSinkMon","AnimTask_SwayMon","AnimTask_TranslateMonEllipticalRespectSide","DoHorizontalLunge","SlideMonToOffset","SlideMonToOriginalPos"]:return _actor(s,c,owner,g,site)
	return _particle(s,c,owner,g,site)

static func _table(name: String,index: int,affine: bool=false) -> Array:
	var rows: Array=Data.TABLES.get(name,[])
	if rows.is_empty():return [{"op":"frame","args":[0,0,0,1] if affine else [0,1]},{"op":"end","args":[]}]
	if rows[0] is String:return _table(str(rows[clampi(index,0,rows.size()-1)]),0,affine)
	return rows
static func _vm(commands: Array,age: int,affine: bool=false) -> Dictionary:
	var result: Dictionary={"tile":0,"flags":0,"matrix":Vector2i(256,256),"angle":0,"ended":false}
	var pc: int=-1;var delay: int=0
	for tick: int in maxi(0,age)+1:
		if result.ended:break
		if delay>0:
			delay-=1
			if affine:
				var a: Array=commands[pc].args
				result.matrix=Vector2i(_s16(result.matrix.x+int(a[0])),_s16(result.matrix.y+int(a[1])))
				result.angle=(int(result.angle)+int(a[2]))&255
			continue
		pc+=1
		for guard: int in 128:
			if pc<0 or pc>=commands.size():result.ended=true;break
			var row: Dictionary=commands[pc];var a: Array=row.args
			match str(row.op):
				"end":result.ended=true;break
				"jump":pc=int(a[0]);continue
				"loop":pc=0;continue
				"frame":
					if affine:
						var duration: int=int(a[3])&255
						if duration==0:result.matrix=Vector2i(_s16(int(a[0])),_s16(int(a[1])));result.angle=int(a[2])&255
						else:
							result.matrix=Vector2i(_s16(result.matrix.x+int(a[0])),_s16(result.matrix.y+int(a[1])))
							result.angle=(int(result.angle)+int(a[2]))&255;delay=duration-1
					else:
						result.tile=int(a[0]);result.flags=0;delay=maxi(0,(int(a[1])&255)-1)
						for flag: Variant in a.slice(2):
							if "hFlip" in str(flag):result.flags|=1
							if "vFlip" in str(flag):result.flags|=2
					break
	return result
static func _end_age(commands: Array,affine: bool=false) -> int:
	for age: int in 512:
		if _vm(commands,age,affine).ended:return age
	return -1
# The frame table is constant per site; scanning it up to 512 ages every tick was quadratic.
static func _item_end_age(i: Dictionary) -> int:
	if not i.has("end_age"):i.end_age=_end_age(_table(str(i.site.frame_table),0))
	return int(i.end_age)
static func _point(g: Session,c: BattleAnimationContext,role: int) -> Variant:
	var b: Dictionary=_original(g,c,role)
	return null if b.is_empty() else _center(b,c)
static func _pair_center(g: Session,c: BattleAnimationContext) -> Variant:
	var first: Variant=_point(g,c,1)
	if first==null:return null
	var id: int=c.target_ids[0];var position: int=c.source_position(id);var partner: Variant=null
	for candidate: BattleAnimationActor in c.actors.values():
		if c.source_position(candidate.id)==(position^2):partner=candidate;break
	# Source partner average uses a genuine visible original, never array order.
	if partner is BattleAnimationActor:
		var b: Dictionary=g.originals.get(partner.id,{})
		if not b.is_empty() and Gate._bound(b,c):return (first+_center(b,c))/2
	return first
static func _relative_sign(g: Session,c: BattleAnimationContext) -> int:
	# rom_8077ABC.c sub_807867C compares u16 source X; side only breaks equal X.
	var attacker: Variant=_point(g,c,0);var target: Variant=_point(g,c,1)
	if attacker!=null and target!=null:
		var x: int=int(attacker.x)&65535;var y: int=int(target.x)&65535
		if x!=y:return -1 if x>y else 1
	return -1 if c.actors.has(c.attacker_id) and c.actors[c.attacker_id].side!=0 else 1
static func _factor(s: Dictionary,owner: Node2D,site: Dictionary) -> float:
	var factor: float=float(s.get("scale_factor",1));var expected: Dictionary=_group(owner).descriptor.program.steps[owner._pc]
	if site.root_profile=="sub_80E27A0" and expected.get("source_template") in ["gBasicHitSplatSpriteTemplate","gBattleAnimSpriteTemplate_83DB4D8"] and factor==float(expected.get("scale_factor",1)):return 1.0
	return factor
static func _particle(s: Dictionary,c: BattleAnimationContext,owner: Node2D,g: Session,site: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary]=[];var a: Array=site.args;var root: String=site.root_profile
	var role: int=0 if str(s.get("selector","target"))=="attacker" else 1
	if root in ["sub_80CAED8","sub_80D31C8","sub_80D3554","AnimTranslateLinearSingleSineWave"]:role=0
	if root=="sub_80CC6CC":role=int(a[0])
	if root=="AnimBasicFistOrFoot":role=int(a[3])
	if root=="sub_80E27A0":role=int(a[2])
	if root=="sub_80D3838":role=1 if int(a[3])!=0 else 0
	if root=="AnimBubbleEffect":role=1
	var binding: Dictionary=_original(g,c,role)
	if binding.is_empty():return out
	var source: Variant=_point(g,c,0);var target: Variant=_point(g,c,1)
	if root in ["sub_80D31C8","sub_80D3554","AnimTranslateLinearSingleSineWave"] and (source==null or target==null):return out
	var art: Dictionary=_art(s);var settings: Dictionary=s.duplicate(true)
	for key: String in ART:
		if art.has(key):settings[key]=art[key]
	settings.source_contest=c.contest
	var n:=Sprite2D.new();n.texture=_texture(art.texture);n.region_enabled=true;owner.add_child(n)
	var priority: Dictionary=s.get("source_command_priority",{})
	var t: Dictionary={"kind":"source_particle","age":0,"ticks":1,"node":n,"owner":owner,"settings":settings,"source_oam_priority":int(Data.OAM.get(str(site.OAM).trim_prefix("&"),{}).get("fields",{}).get("priority",2)),"source_oam_subpriority":3,"origin":_center(binding,c),"destination":target if target!=null else Vector2.ZERO,"update":advance}
	var item: Dictionary={"track":t,"node":n,"parent":owner,"group":g,"binding":binding,"texture":n.texture,"site":site,"args":a,"original_recipe":s.duplicate(true),"normalized_recipe":settings.duplicate(true),"writes":{},"lost":{},"material":null,"shader":null,"uniforms":{},"revoked":{},"lost_material":false,"retired":false,"pose":t.origin,"factor":_factor(s,owner,site),"frame_age":0,"state":0,"counter":0,"registers":[],"start":t.origin,"end":t.destination,"side":-1 if c.actors.has(c.attacker_id) and c.actors[c.attacker_id].side!=0 else 1,"angle":0,"callback_age":0,"palette_lost":false}
	t.i159_item=item;BattleSourcePriority.initialize(t,c,owner)
	var tint:=Color(str(settings.get("color","ffffff")));n.modulate=tint
	var oam: Dictionary=Data.OAM.get(str(site.OAM).trim_prefix("&"),{}).get("fields",{})
	if int(oam.get("objMode",0))==1:
		_install_material(item,COMBINED,{"source_recolor":bool(settings.get("recolor",false)),"source_recolor_tint":tint,"blend_color":g.palette_color,"blend_amount":g.palette_amount,"eva":g.coefficients.x if g.alpha else 1.0,"evb":g.coefficients.y if g.alpha else 0.0})
	elif root in ["sub_80CAED8","AnimTranslateLinearSingleSineWave"]:
		_install_material(item,PALETTE,{"source_recolor":bool(settings.get("recolor",false)),"source_recolor_tint":tint,"blend_color":g.palette_color,"blend_amount":g.palette_amount})
	elif bool(settings.get("recolor",false)):_install_material(item,RECOLOR,{"tint":tint})
	var offset: Array=settings.get("offset",[0,0])
	var relative: int=_relative_sign(g,c)
	var helper_offset: bool=root in ["sub_80CC884","sub_80D4044","sub_80D3838","sub_80D3554","AnimTranslateLinearSingleSineWave","AnimBasicFistOrFoot","sub_80E27A0"] or (root=="AnimBubbleEffect" and int(a[2])==0)
	item.pose+=Vector2(float(offset[0])*relative if helper_offset else float(offset[0])*float(item.side) if bool(settings.get("mirror_offset",false)) else float(offset[0]),float(offset[1]))
	match root:
		"sub_80CAED8":item.start=source;item.pose=source;item.counter=int(a[2])
		"sub_80CC6CC":
			var p: Vector2=Vector2(int(t.origin.x)&255,int(t.origin.y)&255)
			item.start=p+Vector2(a[2],a[3]) if int(a[1])==0 else p
			item.end=p if int(a[1])==0 else p+Vector2(a[2],a[3]);item.pose=item.start
			item.registers=[_s16(int(item.start.x)*16),_s16(int(item.start.y)*16),_s16(_div(int((item.end.x-item.start.x)*16),int(a[4]))),_s16(_div(int((item.end.y-item.start.y)*16),int(a[4]))),int(a[4])]
			item.angle=(item.end-item.start).angle()+PI/2-(PI if c.contest else 0)
		"sub_80D31C8":
			item.start=source+Vector2(int(a[0])*int(item.side),int(a[1]));item.end=target
			item.start-=Vector2(_sin(int(a[4]),int(a[2])*int(item.side)),_cos(int(a[4]),int(a[3])))
			var dummy:=Node2D.new();dummy.visible=false;owner.add_child(dummy)
			t.invisible_child={"node":dummy,"data":[int(a[2])*int(item.side),int(a[3]),int(a[5]),_s16(int(a[4])<<8),int(a[6])],"retired":false}
		"sub_80D3554":
			item.start=source+Vector2(int(a[0])*relative,int(a[1]));item.end=target
			var phase: int=int(owner._source_args.get(7,0));var amplitude: int=int(a[3])
			if phase>127:phase-=127;amplitude=-amplitude
			item.registers=[_s16(phase<<8),amplitude,_div(0xD200,30)]
		"AnimTranslateLinearSingleSineWave":
			if a.size()>6 and int(a[6])!=0:target=_pair_center(g,c)
			item.start=source+Vector2(int(a[0])*relative,int(a[1]));item.end=target+Vector2(int(a[2])*int(item.side),int(a[3]));item.phase=0;item.crossed=0
			item.same_side=_original(g,c,0).actor.side==_original(g,c,1).actor.side
		"sub_80D3838":item.start=t.origin+Vector2(int(a[0])*relative,int(a[1]));item.pose=item.start
		"AnimBubbleEffect":
			item.start=(_pair_center(g,c) if int(a[2])!=0 else target)+Vector2(int(a[0])*(int(item.side) if int(a[2])!=0 else relative),int(a[1]));item.pose=item.start
		"sub_80D4044":
			item.start=target+Vector2(int(a[0])*relative,a[1]);item.pose=item.start
			var first: int=int(g.random.randi())&255;var second: int=int(g.random.randi())&511
			item.registers=[first|256,256-second if second>255 else second,0,0]
		"sub_80DFF1C":item.start=t.origin+Vector2(a[0],a[1]);item.pose=item.start
		"sub_80DCE9C":item.start=(_pair_center(g,c) if int(a[3])!=0 else t.origin)+Vector2(a[0],14);item.pose=item.start
		"AnimBasicFistOrFoot","sub_80E27A0":item.pose=t.origin+Vector2(int(a[0])*relative,int(a[1]));item.start=item.pose
	g.objects.append(item);t.cleanup=_cleanup.bind(item)
	# Initializers that call their continuation do so before the first displayed VM pass.
	if root in ["sub_80D31C8","sub_80D3554","sub_80DCE9C"]:_particle_callback(item,c,0)
	_pose_particle(item,c,0)
	out.append(t);return out
static func _install_material(item: Dictionary,shader: Shader,uniforms: Dictionary) -> void:
	var m:=ShaderMaterial.new();m.shader=shader;item.material=m;item.shader=shader;item.node.material=m
	for key: String in uniforms:m.set_shader_parameter(key,uniforms[key]);item.uniforms[key]=m.get_shader_parameter(key)
static func _observe(item: Dictionary) -> bool:
	if item.retired:return false
	if not Owned.node(item) or item.node.texture!=item.texture or not Gate._bound(item.binding,item.group.context):_cleanup(item);return false
	for key: String in item.writes:
		if item.node.get(key)!=item.writes[key]:item.lost[key]=true
	# Revoking ANY owned shader/uniform field retires this material writer as a whole.
	if item.material!=null:
		if not Owned.observe_material(item) or not item.revoked.is_empty():item.palette_lost=true;item.lost_material=true
	return true
static func _kill(item: Dictionary) -> void:
	item.track.ticks=int(item.track.age);item.retired=true
	if is_instance_valid(item.node) and item.node.get_parent()==item.parent:item.node.queue_free()
static func _cleanup(item: Dictionary) -> void:
	var t: Dictionary=item.track;t.erase("cleanup");t.erase("update");t.erase("i159_item")
	if is_instance_valid(item.parent) and item.parent.state=="running":item.parent._tracks.erase(t)
	if t.has("invisible_child"):
		var child: Dictionary=t.invisible_child
		if is_instance_valid(child.node) and child.node.get_parent()==item.parent:child.node.queue_free()
		child.retired=true
	if t.has("scanline_child"):
		t.scanline_child.data[15]=65535;t.scanline_child.retired=true;t.scanline_child.erase("step");t.scanline_child.erase("item")
	_kill(item)

static func _packed(start: Vector2,end: Vector2,duration: int,count: int) -> Vector2:
	var dx: int=int(end.x-start.x);var dy: int=int(end.y-start.y)
	var vx: int=_div((absi(dx)<<8)&65535,duration);var vy: int=_div((absi(dy)<<8)&65535,duration)
	vx=(vx|1) if dx<0 else (vx&~1);vy=(vy|1) if dy<0 else (vy&~1)
	var x: int=(count*vx)&65535;var y: int=(count*vy)&65535
	return Vector2(-(x>>8) if vx&1 else x>>8,-(y>>8) if vy&1 else y>>8)
static func _particle_callback(i: Dictionary,c: BattleAnimationContext,age: int) -> void:
	var a: Array=i.args;var t: Dictionary=i.track;var root: String=i.site.root_profile
	match root:
		"sub_80CAED8":
			if age<=int(a[2]):i.pose=i.start+Vector2(a[0],a[1])*age
			else:
				var tail: int=age-int(a[2])-1;var phase: int=128 if int(a[1])&1 else 0
				i.pose=i.start+Vector2(a[0],a[1])*int(a[2])+Vector2(_sin(phase+maxi(0,tail-1)*2,25)*int(i.side),tail/2)
				if tail>=81:_kill(i)
		"sub_80CC6CC":
			var d: Array=i.registers
			if d[4]<=0:_kill(i);return
			d[0]=_s16(int(d[0])+int(d[2]));d[1]=_s16(int(d[1])+int(d[3]));d[4]-=1;i.pose=Vector2(int(d[0])>>4,int(d[1])>>4)
		"sub_80D31C8":
			var child: Dictionary=t.invisible_child;var d: Array=child.data
			if age<int(a[6]):
				var count: int=mini(age+1,int(a[6]));var phase: int=int(d[3])>>8
				i.pose=i.start+_packed(i.start+Vector2(_sin(int(a[4]),int(d[0])),_cos(int(a[4]),int(d[1]))),i.end,int(a[6]),count)+Vector2(_sin(phase,int(d[0])),_cos(phase,int(d[1])))
				d[3]=_s16(int(d[3])+int(d[2]));d[4]=maxi(1,int(a[6])-count)
				if count==int(a[6]):
					if is_instance_valid(child.node):child.node.queue_free()
					child.retired=true
			elif age>=int(a[6])+_item_end_age(i)+14:_kill(i)
		"sub_80D3554":
			var d: Array=i.registers;var wave: int=_sin(int(d[0])>>8,int(d[1]))
			i.pose=i.start+_packed(i.start,i.end,30,mini(age+1,30))+Vector2(0,wave)
			if ((int(d[0])+int(d[2]))>>8)>127:d[0]=0;d[1]=-int(d[1])
			else:d[0]=_s16(int(d[0])+int(d[2]))
			t.data=[0,0,0,0,0,d[2],d[0],d[1]]
			if age>=30:_kill(i)
		"AnimTranslateLinearSingleSineWave":
			var old: int=int(i.phase);i.phase=_s16(old+_div(32768,int(a[4])))
			i.pose=i.start+_packed(i.start,i.end,int(a[4]),age)+Vector2(0,_sin(int(i.phase)>>8,int(a[5])))
			if old>0xC8 and int(i.phase)<=0x37 and int(i.crossed)==0:i.crossed=1
			if int(i.crossed)!=0 and bool(i.same_side):
				Owned.write(i,"visible",not i.node.visible);i.crossed+=1
				if int(i.crossed)==30:_kill(i)
			if i.pose.x< -16 or i.pose.x>256 or i.pose.y< -16 or i.pose.y>160:_kill(i)
		"sub_80D3838","AnimBubbleEffect":
			i.pose=i.start+Vector2(_sin(age*11,4),-(_s16(age*48)>>8))
			if root=="sub_80D3838" and age>int(a[2]):_kill(i)
			if root=="AnimBubbleEffect" and _vm(_table(str(i.site.affine_table),0,true),age-1,true).ended:_kill(i)
		"sub_80D4044":
			var d: Array=i.registers;d[2]=_s16(int(d[2])+int(d[0]));d[3]=_s16(int(d[3])+int(d[1]))
			i.pose=i.start+Vector2((int(d[2])>>8)*(-1 if int(d[0])&1 else 1),int(d[3])>>8)
			if age>=21:_kill(i)
		"sub_80DFF1C":
			var count: int=mini(age,int(a[5])) if age<=int(a[5]) else maxi(0,2*int(a[5])-age)
			i.pose=i.start+Vector2(_s16(count*int(a[3]))>>8,_s16(count*int(a[4]))>>8)
			if age>=2*int(a[5]):_kill(i)
		"sub_80DCE9C":
			var count: int=mini(age,15) if age<17 else mini(age-17,31)
			i.pose=i.start
			if age<17:i.pose.y+=_sin(count*4+64,-70)
			else:i.pose+=Vector2(int(a[2])+_sin(192+count*4,int(a[2])),_sin(192+count*4+64,-24))
			if age>=50:_kill(i)
		"AnimBasicFistOrFoot":
			if age>=int(a[2])+2:_kill(i)
		"sub_80E27A0":
			if _vm(_table(str(i.site.affine_table),int(a[3]),true),maxi(0,age-2),true).ended:_kill(i)
		"sub_80CC884":
			if _vm(_table(str(i.site.frame_table),1 if int(i.side)==1 else 0),maxi(0,age-1)).ended:_kill(i)
static func _pose_particle(i: Dictionary,c: BattleAnimationContext,age: int) -> void:
	if not _observe(i):return
	var a: Array=i.args;var root: String=i.site.root_profile
	var frame_index: int=int(a[4]) if root=="AnimBasicFistOrFoot" else int(a[1]) if root=="sub_80DCE9C" else 1 if root=="sub_80CC884" and int(i.side)==1 else 0
	var affine_index: int=int(a[3]) if root=="sub_80E27A0" else int(a[2]) if root=="sub_80DFF1C" else 0
	var frame_age: int=maxi(0,age-int(a[6])) if root=="sub_80D31C8" else age
	var frame: Dictionary=_vm(_table(str(i.site.frame_table),frame_index),frame_age)
	var affine: Dictionary=_vm(_table(str(i.site.affine_table),affine_index,true),age,true)
	var s: Dictionary=i.track.settings;var rects: Dictionary=s.get("frame_rects",{});var tile: int=int(frame.tile)+(8 if root=="sub_80D4044" else 0);var rect: Rect2
	if rects.has(str(tile)):
		var r: Array=rects[str(tile)];rect=Rect2(r[0],r[1],r[2],r[3])
	else:
		var size: Array=s.get("frame_size",[32,32]);var columns: int=i.texture.get_width()/8
		rect=Rect2((tile%columns)*8,(tile/columns)*8,size[0],size[1])
	Owned.write(i,"region_rect",rect)
	Owned.write(i,"flip_h",bool(s.get("flip_h",false))!=bool(int(frame.flags)&1))
	Owned.write(i,"flip_v",bool(s.get("flip_v",false))!=bool(int(frame.flags)&2))
	var scale: Vector2=Vector2(affine.matrix)/256*float(i.factor)
	var angle: float=float(affine.angle)*TAU/256
	if root=="sub_80CC6CC":angle=float(i.angle)
	Owned.write(i,"transform",_field_pose(c,i.parent,i.pose,scale,angle))
	if i.material!=null and i.shader==COMBINED and not i.palette_lost:
		Owned.uniform(i,"eva",i.group.coefficients.x if i.group.alpha else 1.0);Owned.uniform(i,"evb",i.group.coefficients.y if i.group.alpha else 0.0)
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	var i: Dictionary=t.i159_item
	if not _observe(i):t.ticks=int(t.age);return
	if not Same._same(t.settings,i.normalized_recipe):_cleanup(i);return
	_particle_callback(i,c,int(t.age));_pose_particle(i,c,int(t.age))
	if not i.retired:t.ticks=int(t.age)+1

static func _local(b: Dictionary,c: BattleAnimationContext,value: Vector2) -> Vector2:
	return b.sprite_parent.global_transform.affine_inverse().basis_xform(c.field.global_transform.basis_xform(value))
static func _source_initial(g: Session,b: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Vector2:
	var actor: BattleAnimationActor=b.actor;var id: int=actor.id
	var native: Vector2=actor._offset
	var lease: Dictionary=g.held.get(id,{})
	var application: Dictionary=g.applied.get(id,{})
	var applied_ok: bool=not application.is_empty() and application.actor==actor and actor._offset==application.value and owner._held_offsets.get(id,Vector2.ZERO)==application.held and owner._held_approach_corrections.get(id,Vector2.ZERO)==application.approach and b.sprite_parent.global_transform==application.parent_transform and c.field.global_transform==application.field_transform
	if applied_ok:
		# Native additive/approach layers are intentionally separate from C x2/y2.
		# Snapshot only held state: baking additive into held would apply it twice.
		native=application.held
		if not lease.is_empty() and lease.exact and is_same(application.held_receipt,lease.receipt) and is_same(lease.item.binding,b) and g.valid and _actor_identity(b,c,owner) and lease.value==application.held and _local(b,c,lease.source)==lease.value:
			return lease.source
	if not lease.is_empty():lease.item.source_logical_lost=true
	# Unowned/native held state keeps its literal projection; never round it or
	# resurrect a lost exact register merely because displayed values match later.
	return c.field.global_transform.affine_inverse().basis_xform(b.sprite_parent.global_transform.basis_xform(native))
static func _capture_application(g: Session,owner: Node2D,actor: BattleAnimationActor,held: Vector2,approach: Vector2,additive: Vector2) -> void:
	if actor._offset!=held+approach+additive:return
	var lease: Dictionary=g.held.get(actor.id,{})
	g.applied[actor.id]={"receipt":RefCounted.new(),"actor":actor,"held_receipt":lease.get("receipt"),"held":held,"approach":approach,"additive":additive,"value":actor._offset,"parent_transform":actor.sprite.get_parent().global_transform,"field_transform":owner.context.field.global_transform}
static func note_actor_application(owner: Node2D,actor: BattleAnimationActor,held: Vector2,approach: Vector2,additive: Vector2) -> void:
	var g: Session=_group(owner)
	if g==null or not g.valid or not is_same(owner._i159_actor_apply_actor,actor) or owner.context.actors.get(actor.id)!=actor or not actor.is_present():return
	_capture_application(g,owner,actor,held,approach,additive)
static func _actor(s: Dictionary,c: BattleAnimationContext,owner: Node2D,g: Session,site: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary]=[];var a: Array=site.args;var root: String=site.root_profile
	var role: int=int(a[4]) if root=="AnimTask_SwayMon" else 0 if root=="DoHorizontalLunge" else int(a[0])
	var b: Dictionary=_original(g,c,role)
	if b.is_empty():return out
	var initial: Vector2=_source_initial(g,b,c,owner)
	var t: Dictionary={"kind":"source_secret_actor","age":0,"ticks":1,"actor":b.actor,"settings":s.duplicate(true),"pose":{"offset":Vector2.ZERO},"owner":owner}
	var i: Dictionary={"track":t,"group":g,"binding":b,"site":site,"args":a,"retired":false,"offset":Vector2.ZERO,"initial":initial,"remaining":0,"timer":0,"counter":0,"phase":0,"flags":Vector2i(0,1),"stage":0,"accum":Vector2i.ZERO,"sink":0,"sink_x":0,"side":-1 if c.actors.has(c.attacker_id) and c.actors[c.attacker_id].side!=0 else 1,"held":root not in ["AnimTask_SwayMon","AnimTask_TranslateMonEllipticalRespectSide","DoHorizontalLunge"],"actor_item":true,"cancelled":false,"normalized_recipe":s.duplicate(true)}
	t.i159_item=i
	match root:
		"AnimTask_ShakeMon","AnimTask_ShakeMon2":i.offset=Vector2(a[1],a[2]);i.remaining=int(a[3]);i.timer=int(a[4])
		"AnimTask_ShakeMonInPlace":i.offset=initial+Vector2(a[1],a[2]);i.remaining=int(a[3])
		"AnimTask_ShakeAndSinkMon":i.offset=Vector2(a[1],0);i.sink_x=int(a[1]);i.remaining=int(a[4])
		"AnimTask_SwayMon":i.remaining=int(a[3])
		"AnimTask_TranslateMonEllipticalRespectSide":i.remaining=int(a[3])
		"DoHorizontalLunge":i.remaining=int(a[0])
		"SlideMonToOffset":
			i.remaining=int(a[4]);var side: int=-1 if b.actor.side!=0 else 1
			i.velocity=Vector2i(_div(_s16(int(a[1])*side<<8),int(a[4])),_div(_s16(int(a[2])*(side if int(a[3])==1 else 1)<<8),int(a[4])))
		"SlideMonToOriginalPos":
			i.offset=initial;i.remaining=int(a[2]);i.velocity=Vector2i(_div(_s16(-int(initial.x)<<8),int(a[2])),_div(_s16(-int(initial.y)<<8),int(a[2])))
			if int(a[1])==1:i.velocity.y=0
			if int(a[1])==2:i.velocity.x=0
	g.objects.append(i);t.cleanup=_actor_cleanup.bind(i)
	if root in ["AnimTask_ShakeMon","AnimTask_ShakeMon2","AnimTask_ShakeMonInPlace","AnimTask_ShakeAndSinkMon","AnimTask_TranslateMonEllipticalRespectSide"]:_actor_callback(i,c)
	t.pose={"offset":_local(b,c,i.offset),"source_offset":i.offset,"hold_offset":i.held}
	var id: int=b.actor.id;var delta: Vector2=t.pose.offset
	if i.held:
		delta-=owner._held_offsets.get(id,Vector2.ZERO)
		owner._held_offsets[id]=t.pose.offset
		g.held[id]={"receipt":RefCounted.new(),"item":i,"actor":b.actor,"value":t.pose.offset,"source":i.offset,"exact":true}
	g.birth_delta[id]=g.birth_delta.get(id,Vector2.ZERO)+delta
	out.append(t);return out
static func _actor_callback(i: Dictionary,c: BattleAnimationContext) -> void:
	var a: Array=i.args;var root: String=i.site.root_profile;var dead: bool=false
	match root:
		"AnimTask_ShakeMon","AnimTask_ShakeMon2","AnimTask_ShakeMonInPlace":
			if int(i.timer)>0:i.timer-=1
			else:
				var amplitude:=Vector2(a[1],a[2]);i.timer=int(a[4])
				if root=="AnimTask_ShakeMonInPlace":
					i.offset+=amplitude*(2 if int(i.counter)&1 else -2);i.counter+=1
					if int(i.counter)>=int(i.remaining):i.offset+=amplitude*(1 if int(i.counter)&1 else -1);dead=true
				else:
					if root=="AnimTask_ShakeMon2":i.offset=-amplitude if i.offset==amplitude else amplitude
					else:i.offset=Vector2(amplitude.x if i.offset.x==0 else 0,amplitude.y if i.offset.y==0 else 0)
					i.remaining-=1
					if int(i.remaining)==0:i.offset=Vector2.ZERO;dead=true
		"AnimTask_ShakeAndSinkMon":
			var previous: int=int(i.counter);i.counter+=1
			if int(a[2])==previous:
				i.counter=0
				if int(i.offset.x)==int(i.sink_x):i.sink_x=-int(i.sink_x)
				i.offset.x=_s16(int(i.offset.x)+int(i.sink_x))
			i.sink=_s16(int(i.sink)+int(a[3]));i.offset.y=int(i.sink)>>8;i.remaining-=1;dead=int(i.remaining)==0
		"AnimTask_TranslateMonEllipticalRespectSide":
			i.offset=Vector2(_sin(int(i.phase),int(a[1])*int(i.side)),-_cos(int(i.phase),int(a[2]))+int(a[2]));i.phase=(int(i.phase)+(1<<mini(int(a[4]),5)))&255
			if int(i.phase)==0:i.remaining-=1
			if int(i.remaining)==0:i.offset=Vector2.ZERO;dead=true
		"AnimTask_SwayMon":
			i.phase=(int(i.phase)+int(a[2]))&65535
			var wave: int=int(i.phase)>>8;var value: int=_sin(wave,int(a[1])*int(i.side))
			if int(a[0])==0:i.offset.x=value
			else:i.offset.y=absi(value)*(1 if i.binding.actor.side==0 else -1)
			if (wave>=128 and i.flags==Vector2i(0,1)) or (wave<127 and i.flags==Vector2i(1,0)):
				i.flags=Vector2i(i.flags.x^1,i.flags.y^1);i.remaining-=1
				if int(i.remaining)==0:i.offset=Vector2.ZERO;dead=true
		"DoHorizontalLunge":
			if int(i.stage) in [0,2]:
				if int(i.remaining)>0:i.offset.x+=int(a[1])*int(i.side)*(1 if int(i.stage)==0 else -1);i.remaining-=1
				else:i.stage+=1
			elif int(i.stage)==1:i.remaining=int(a[0]);i.stage=2
			else:dead=true
		"SlideMonToOffset","SlideMonToOriginalPos":
			if int(i.remaining)>0:
				i.remaining-=1;i.accum=Vector2i(_s16(i.accum.x+i.velocity.x),_s16(i.accum.y+i.velocity.y))
				if root=="SlideMonToOffset":i.offset=Vector2(i.accum.x>>8,i.accum.y>>8)
				else:i.offset=i.initial+Vector2((((i.accum.x>>8)+128)&255)-128,(((i.accum.y>>8)+128)&255)-128)
			elif root=="SlideMonToOriginalPos":
				if int(a[1])<2:i.offset.x=0
				if int(a[1]) in [0,2]:i.offset.y=0
				dead=true
			elif int(i.stage)==0:i.stage=1
			else:dead=true
	i.track.pose={"offset":_local(i.binding,c,i.offset),"source_offset":i.offset,"hold_offset":i.held}
	if dead:i.retired=true;i.track.ticks=int(i.track.age)
static func advance_actor(t: Dictionary,c: BattleAnimationContext) -> bool:
	var i: Dictionary=t.i159_item
	if i.retired or i.cancelled or not i.group.valid or i.group.lost_roles.has(i.binding.actor.id) or not Gate._bound(i.binding,c) or not Same._same(t.settings,i.normalized_recipe):
		_retire_actor(i);return false
	_actor_callback(i,c)
	if not i.retired:t.ticks=int(t.age)+1
	return true

## All provenance hooks below are finite to this admitted session. Ordinary
## definitions still execute their literal actor workers and held assignments.
static func _scheduled(owner: Node2D,t: Dictionary) -> bool:
	for actual: Dictionary in owner._tracks:
		if is_same(actual,t):return true
	return false
static func _drop_held(g: Session,owner: Node2D,id: int) -> void:
	if not g.held.has(id):return
	var lease: Dictionary=g.held[id]
	# This receipt is erased by EVERY actual independent held publication, even
	# an equal-valued publication. Value comparison is only an external-write veto.
	if owner._held_offsets.has(id) and owner._held_offsets[id]==lease.value:owner._held_offsets.erase(id)
	g.held.erase(id)
static func _retire_actor(i: Dictionary) -> void:
	if i.cancelled:return
	i.cancelled=true;i.retired=true
	var owner: Node2D=i.track.owner;var g: Session=i.group;var id: int=i.binding.actor.id
	if g.held.has(id) and is_same(g.held[id].item,i):_drop_held(g,owner,id)
	g.birth_delta.erase(id)
	owner._tracks.erase(i.track)
	_actor_cleanup(i)
static func _lose_role(g: Session,owner: Node2D,id: int) -> void:
	if g.lost_roles.has(id):return
	g.lost_roles[id]=true;_drop_held(g,owner,id);g.birth_delta.erase(id);g.applied.erase(id)
	for i: Dictionary in g.objects:
		if i.get("actor_item",false) and i.binding.actor.id==id:_retire_actor(i)
static func before_actor_track(owner: Node2D,t: Dictionary) -> bool:
	var g: Session=_group(owner)
	if g==null:return true
	_begin_tick(owner,owner.context)
	if not is_same(owner._i159_actor_callback_track,t) or not _scheduled(owner,t):return false
	if t.kind=="source_secret_actor":
		var i: Dictionary=t.get("i159_item",{})
		if i.is_empty():return false
		if i.retired or i.cancelled or not g.valid or g.lost_roles.has(t.actor.id) or not Gate._bound(i.binding,owner.context):_retire_actor(i);return false
		return true
	# A genuine scheduled literal callback is independent work, not source
	# authority. Remember its actual visual occupant for aggregate/release only.
	if t.actor.is_present() and owner.context.actors.get(t.actor.id)==t.actor:
		var existing: Dictionary={}
		for entry: Dictionary in g.foreign_actors:
			if is_same(entry.track,t):existing=entry;break
		if existing.is_empty():existing={"track":t};g.foreign_actors.append(existing)
		existing.actor=t.actor;existing.sprite=t.actor.sprite;existing.parent=t.actor.sprite.get_parent();existing.texture=t.actor.sprite.texture;existing.generation=t.actor._generation
	return true
static func note_held_write(owner: Node2D,t: Dictionary,value: Vector2) -> void:
	var g: Session=_group(owner)
	if g==null or not is_same(owner._i159_actor_callback_track,t) or not _scheduled(owner,t):return
	var id: int=t.actor.id
	if t.kind=="source_secret_actor":
		var i: Dictionary=t.get("i159_item",{})
		if not i.is_empty() and g.valid and not i.cancelled and not g.lost_roles.has(id) and Gate._bound(i.binding,owner.context):g.held[id]={"receipt":RefCounted.new(),"item":i,"actor":t.actor,"value":value,"source":i.offset,"exact":not i.get("source_logical_lost",false)}
	else:
		# Actual callback identity, not a Dictionary/value ownership heuristic.
		if g.held.has(id):g.held[id].item.source_logical_lost=true
		g.held.erase(id)
		g.applied.erase(id)
static func _actor_identity(b: Dictionary,c: BattleAnimationContext,owner: Node2D) -> bool:
	# Source admission/whole-program validity and visual cleanup identity are
	# separate. Revocation never authorizes a replacement, but an intact original
	# still receives its single terminal restoration after its source work stops.
	return is_instance_valid(owner) and is_same(owner.context,c) and is_same(b.context,c) and c.attacker_id==b.attacker and c.contest==b.contest and c.actors.get(b.actor.id)==b.actor and b.actor.sprite==b.sprite and b.actor.is_present() and c.source_position(b.actor.id)==b.position and Pair._visual(b)
static func _foreign_actor(g: Session,a: BattleAnimationActor) -> bool:
	for entry: Dictionary in g.foreign_actors:
		if entry.actor==a and a.is_present() and a.sprite==entry.sprite and a.sprite.get_parent()==entry.parent and a.sprite.texture==entry.texture and a._generation==entry.generation:return true
	return false
static func actor_apply_allowed(owner: Node2D,a: BattleAnimationActor) -> bool:
	var g: Session=_group(owner)
	if g==null:return true
	_begin_tick(owner,owner.context)
	if _foreign_actor(g,a):return true
	var b: Dictionary=g.originals.get(a.id,{})
	return g.valid and not g.lost_roles.has(a.id) and not b.is_empty() and b.actor==a and Gate._bound(b,owner.context)
static func terminal_actors(owner: Node2D) -> Variant:
	var g: Session=_group(owner)
	if g==null:return null
	_begin_tick(owner,owner.context)
	var allowed: Array=[]
	for a: BattleAnimationActor in owner.context.actors.values():
		var b: Dictionary=g.originals.get(a.id,{})
		# Terminal cleanup is a single original-occupant restoration, never a
		# renewed source callback. Whole-program revocation does not transfer it.
		if _foreign_actor(g,a) or (not g.lost_roles.has(a.id) and not b.is_empty() and b.actor==a and _actor_identity(b,owner.context,owner)):allowed.append(a)
	return allowed
static func release_actor_allowed(snapshot: Variant,a: BattleAnimationActor) -> bool:
	if snapshot==null:return true
	for original: BattleAnimationActor in snapshot:
		if is_same(original,a):return true
	return false
static func _actor_cleanup(i: Dictionary) -> void:
	i.track.erase("cleanup");i.track.erase("i159_item")

static func _maintenance(s: Dictionary,c: BattleAnimationContext,owner: Node2D,g: Session,site: Dictionary) -> Array[Dictionary]:
	var t: Dictionary={"kind":"source_secret_maintenance","domain":"maintenance" if site.root_profile=="sub_80CC5F8" else "visual","age":0,"ticks":1,"settings":s.duplicate(true),"owner":owner,"group":g,"site":site,"update":_advance_maintenance}
	if site.root_profile=="sub_80D3630":owner._source_args[7]=0
	var out: Array[Dictionary]=[t];return out
static func _advance_maintenance(t: Dictionary,c: BattleAnimationContext) -> void:
	var owner: Node2D=t.owner;var g: Session=t.group;var age: int=int(t.age)
	if not g.valid:t.ticks=age;return
	if t.site.root_profile=="sub_80D3630":
		owner._source_args[7]=(int(owner._source_args.get(7,0))+3)&255
		if age<100:t.ticks=age+1
		return
	# Initial palette lookup pass precedes coefficient0. Only actual live eligible
	# objects are touched; every material/uniform lease is independently sticky.
	if age>=2:
		var palette_age: int=age-2;var color: Vector3i=COLORS[(palette_age/17)%7];var tint:=Color(float(color.x)/31,float(color.y)/31,float(color.z)/31)
		g.palette_color=tint;g.palette_amount=float(palette_age%17)/16
		for i: Dictionary in g.objects:
			if i.get("actor_item",false) or i.get("surf_item",false) or not i.has("site") or i.site.root_profile not in ["sub_80CAED8","AnimTranslateLinearSingleSineWave"]:continue
			if not _observe(i) or i.palette_lost or i.material==null or i.shader==RECOLOR:continue
			Owned.uniform(i,"blend_color",tint);Owned.uniform(i,"blend_amount",float(palette_age%17)/16)
	t.ticks=age if int(owner._source_args.get(7,0)) in [-1,65535] else age+1

static func _surf(s: Dictionary,c: BattleAnimationContext,owner: Node2D,g: Session,site: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary]=[];var b: Dictionary=_original(g,c,0)
	if b.is_empty():return out
	var authored: Dictionary=g.descriptor.program.steps[owner._pc];var custom: bool=not Same._same(s.get("texture"),authored.get("texture")) or not Same._same(s.get("frame_rects"),authored.get("frame_rects"))
	var settings: Dictionary=s.duplicate(true);settings.source_contest=c.contest
	var texture: Texture2D=_texture(s.get("texture")) if custom else load(MUDDY_ATLAS if bool(authored.get("muddy",false)) else ATLAS) as Texture2D
	if texture==null:return out
	if custom:
		var rects: Variant=s.get("frame_rects")
		if not rects is Dictionary:return out
		for index: int in 21:
			if not rects.has(str(index)):return out
	var n:=Polygon2D.new();n.polygon=PackedVector2Array([Vector2.ZERO,Vector2(240,0),Vector2(240,160),Vector2(0,160)]);n.texture=texture;n.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;owner.add_child(n)
	var map: int=2 if c.contest else 1 if b.actor.side!=0 else 0
	var t: Dictionary={"kind":"source_secret_surf","age":0,"ticks":1,"node":n,"owner":owner,"settings":settings,"priority":2,"update":_advance_surf}
	var i: Dictionary={"track":t,"node":n,"parent":owner,"group":g,"binding":b,"texture":texture,"site":site,"surf_item":true,"map":map,"custom":custom,"writes":{},"lost":{},"material":null,"shader":null,"uniforms":{},"revoked":{},"lost_material":false,"retired":false,"normalized_recipe":settings.duplicate(true),"palette_lost":false}
	t.i159_item=i
	var registers: Array=[];registers.resize(16);registers.fill(0)
	var child: Dictionary={"data":registers,"priority":3,"retired":false,"step":_surf_child,"item":i,"age":0}
	t.scanline_child=child
	_install_material(i,SURF,{"source_mode":true,"source_rect":Vector4(0,float(map*7)/21,1,1.0/21),"source_scroll":Vector2.ZERO,"source_band":Vector2.ZERO,"source_coeff":Vector2(0,16),"source_tint":Color(str(s.get("color","ffffff"))),"source_recolor":bool(s.get("recolor",false))})
	t.cleanup=_cleanup.bind(i);g.objects.append(i);_advance_surf(t,c);out.append(t);return out
static func _advance_surf(t: Dictionary,c: BattleAnimationContext) -> void:
	var i: Dictionary=t.i159_item
	if not _observe(i) or not Same._same(t.settings,i.normalized_recipe):_cleanup(i);return
	var age: int=int(t.age);var map: int=int(i.map);var s: Dictionary=t.settings
	Owned.write(i,"transform",_field_pose(c,i.parent,Vector2.ZERO,Vector2.ONE*float(s.get("scale_factor",1))))
	var scroll:=Vector2(-80,-48) if map==2 else Vector2(-224,256) if map==1 else Vector2(0,-48)
	var velocity:=Vector2(2,1) if map==2 else Vector2(2,-1) if map==1 else Vector2(-2,1)
	var index: int=map*7+(age/4)%7;var rect:=Vector4(0,float(index)/21,1,1.0/21)
	if i.custom:
		var r: Array=s.frame_rects[str(index)]
		rect=Vector4(float(r[0])/i.texture.get_width(),float(r[1])/i.texture.get_height(),float(r[2])/i.texture.get_width(),float(r[3])/i.texture.get_height())
	# Captured presentation flips apply to either selected source or custom rectangle.
	if bool(s.get("flip_h",false)):rect.x+=rect.z;rect.z=-rect.z
	if bool(s.get("flip_v",false)):rect.y+=rect.w;rect.w=-rect.w
	if not i.lost_material:
		Owned.uniform(i,"source_rect",rect);Owned.uniform(i,"source_scroll",scroll+velocity*age)
	var q: int=(age+1)/2;var eva: int=q if q<=13 else 13 if q<=54 else maxi(0,67-q)
	var child: Dictionary=t.scanline_child;child.age=age;child.data[1]=eva|((16-eva)<<8)
	if age>=133:child.data[15]=65535
	# This is the concrete finite child execution boundary, after parent registers.
	if child.get("step") is Callable:child.step.call(child,c)
	if age>=133:_kill(i)
	else:t.ticks=age+1
static func _surf_child(child: Dictionary,_c: BattleAnimationContext) -> void:
	if child.retired:return
	var i: Dictionary=child.item;var age: int=int(child.age);var map: int=int(i.map);var data: Array=child.data
	var band:=Vector2(0,mini(age,112)) if map==1 else Vector2(maxi(0,48-age),112)
	data[0]=2 if age>=(112 if map==1 else 48) else 1
	data[2]=int(band.x);data[3]=int(band.y);data[4]=160 # Source guard row, not part of the visible band.
	if not i.lost_material:
		Owned.uniform(i,"source_coeff",Vector2(int(data[1])&255,(int(data[1])>>8)&255));Owned.uniform(i,"source_band",band)
	if int(data[15]) in [-1,65535]:child.retired=true;child.erase("item")

## The runner's own call opens a tick, so it always re-proves the program in full;
## the hooks below reuse that proof until control leaves this module (dispatch or next tick).
static func begin_tick(owner: Node2D,c: BattleAnimationContext) -> void:
	_stamp+=1
	_begin_tick(owner,c)
static func _begin_tick(owner: Node2D,c: BattleAnimationContext) -> void:
	var g: Session=_group(owner)
	if g==null:return
	if g.valid and (not matches(owner) or not is_same(g.descriptor,_descriptor(owner)) or not is_same(g.context,c) or not is_same(g.definition,owner.definition) or not _program_ok(owner,g,true,true)):g.valid=false
	for id: int in g.originals:
		if not g.lost_roles.has(id) and not _actor_identity(g.originals[id],c,owner):_lose_role(g,owner,id)
	if not g.valid:
		for i: Dictionary in g.objects:
			if i.get("actor_item",false):_retire_actor(i)
			elif not i.retired:_cleanup(i)
		for id: int in g.held.keys():_drop_held(g,owner,id)
		g.birth_delta.clear();g.applied.clear()
		for t: Dictionary in g.backgrounds:
			if not t.get("cleared",false):Pair._clear_pair(t)
		return
	for i: Dictionary in g.objects:
		if i.get("actor_item",false):
			if g.lost_roles.has(i.binding.actor.id):_retire_actor(i)
		elif not i.retired:
			if g.lost_roles.has(i.binding.actor.id):_cleanup(i)
			else:_observe(i)
static func after_pose(owner: Node2D,c: BattleAnimationContext) -> void:
	var g: Session=_group(owner)
	if g==null:return
	_begin_tick(owner,c)
	if not g.valid:return
	# The runner already applied the real aggregate (including independent
	# literal work). Only immediate initializer deltas born AFTER that aggregate
	# are added here, exactly once; never rebuild/overwrite the aggregate by ID.
	for id: int in g.birth_delta.keys():
		var b: Dictionary=g.originals.get(id,{})
		if not b.is_empty() and actor_apply_allowed(owner,b.actor):
			b.actor.apply(b.actor._offset+g.birth_delta[id],b.actor._tint)
			var previous: Dictionary=g.applied.get(id,{})
			if not previous.is_empty():_capture_application(g,owner,b.actor,owner._held_offsets.get(id,Vector2.ZERO),previous.approach,previous.additive)
	g.birth_delta.clear()
	for i: Dictionary in g.objects:
		if not i.get("actor_item",false) and not i.retired and not i.get("surf_item",false):_pose_particle(i,c,int(i.track.age))
	for t: Dictionary in g.backgrounds:Pair._after_pair_pose(t)
	_order(g,owner,c)
static func release(owner: Node2D) -> void:
	var g: Session=_group(owner)
	if g==null:return
	for i: Dictionary in g.objects:
		if i.get("actor_item",false):i.track.erase("cleanup");i.track.erase("i159_item")
		else:_cleanup(i)
	for t: Dictionary in g.backgrounds:
		if not t.get("cleared",false):Pair._clear_pair(t)
	g.objects.clear();g.backgrounds.clear();g.originals.clear();g.held.clear();g.applied.clear();g.birth_delta.clear();g.foreign_actors.clear();g.foreign_palette_writes.clear();owner.remove_meta(STATE)
	_invocations.erase(owner.get_instance_id())

static func _order(g: Session,owner: Node2D,c: BattleAnimationContext) -> void:
	var floor_: int=BattleSourcePriority.effective_layer(c.field)-BattleSourcePriority.effective_layer(owner)
	var band: int=floor_+1
	for a: BattleAnimationActor in c.actors.values():
		if a.is_present():band=maxi(band,BattleSourcePriority.actor_layer(a,owner))
	for t: Dictionary in g.backgrounds:
		for item: Dictionary in t.clones:
			if not item.retired:Owned.write(item,"z_index",band+(5 if int(item.bg_plane)==1 and g.promoted else 1 if int(item.bg_plane)==1 else 0))
	for i: Dictionary in g.objects:
		if i.get("actor_item",false) or i.get("surf_item",false) or i.retired:continue
		Owned.write(i,"z_index",band+3+clampi(32-int(i.track.source_oam_subpriority),-1,1))

## Called only at the actual scheduled ordinary palette callback. This observes
## independent writer intent BEFORE values are written; equal values are valid
## foreign intent, never proof that the old source task still owns a material.
static func before_palette_writer(owner: Node2D,t: Dictionary) -> void:
	var g: Session=_group(owner)
	if g==null or not g.valid or not is_same(owner._i159_palette_callback_track,t) or not _scheduled(owner,t) or t.get("kind")!="source_particle_palette":return
	var s: Dictionary=t.settings
	# Match the unchanged generic worker's early return and branch precedence.
	if s.has("termination_arg") and int(owner._source_args.get(int(s.termination_arg),0))==(int(s.termination_value)&65535):return
	for actual: Dictionary in owner._tracks:
		if actual.get("kind")!="source_particle":continue
		var tag: String=str(actual.settings.get("source_palette_tag",""))
		if bool(s.get("palette_cycle",false)) and tag==str(s.get("palette_tag","")):continue
		if tag not in s.get("palette_tags",[]):continue
		for i: Dictionary in g.objects:
			if i.get("actor_item",false) or i.get("surf_item",false) or i.retired or i.palette_lost or not is_same(i.track,actual):continue
			if i.site.root_profile not in ["sub_80CAED8","AnimTranslateLinearSingleSineWave"]:continue
			if not Owned.node(i) or actual.node!=i.node or not actual.node.material is ShaderMaterial or actual.node.material!=i.material:continue
			i.palette_lost=true;i.lost_material=true
			g.foreign_palette_writes.append({"writer":t,"sprite":i.node,"material":i.material,"tag":tag})

extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Finite Swords Dance callback family. Source authority never follows tag/value equality.
const Same=preload("res://scripts/battle/animations/sequence/source_cutting_slice.gd")
const Pair=preload("res://scripts/battle/animations/sequence/source_charge_owned.gd")
const Owned=preload("res://scripts/battle/animations/sequence/source_owned_composition.gd")
const Art=preload("res://scripts/battle/animations/sequence/source_spinning_strike_composition.gd")
const STATE := "i157_swords_session"
const ART := ["texture","frame_rects","color","recolor","scale_factor","flip_h","flip_v"]
const COMBINED := preload("res://scripts/battle/animations/sequence/source_agility_aerial_palette_ab.gdshader")
const PROGRAM := {
	"key":"ruby:move/14",
	"coverage":"source-derived-unreviewed",
	"source_script":"Move_SWORDS_DANCE",
	"steps":[
		{"op":"source_control","condition":"always","target":800},
		{"op":"source_label","source_pc":800,"source_line":1326,"source_command":"loadspritegfx ANIM_TAG_SWORD"},
		{"op":"source_control","condition":"always","target":801},
		{"op":"source_label","source_pc":801,"source_line":1327,"source_command":"monbg ANIM_BATTLER_ATTACKER"},
		{"op":"effect","behavior":"source_legacy_impact_command","mode":"monbg","source_args":[0],"ticks":1,"source_line":1327,"source_command":"monbg ANIM_BATTLER_ATTACKER","source_script":"Move_SWORDS_DANCE"},
		{"op":"source_control","condition":"always","target":802},
		{"op":"source_label","source_pc":802,"source_line":1328,"source_command":"setalpha 12, 8"},
		{"op":"effect","behavior":"source_legacy_impact_command","mode":"setalpha","source_args":[12,8],"ticks":1,"source_line":1328,"source_command":"setalpha 12, 8","source_script":"Move_SWORDS_DANCE"},
		{"op":"source_control","condition":"always","target":803},
		{"op":"source_label","source_pc":803,"source_line":1329,"source_command":"playsewithpan SE_M_SWORDS_DANCE, SOUND_PAN_ATTACKER"},
		{"op":"sound","path":"res://Audio/SE/PRSFX- Swords Dance1.wav","source_sound":"SE_M_SWORDS_DANCE","source_pan":"SOUND_PAN_ATTACKER","repeat":1,"interval":1,"sound_delay":0,"source_line":1329},
		{"op":"source_control","condition":"always","target":804},
		{"op":"source_label","source_pc":804,"source_line":1330,"source_command":"createvisualtask AnimTask_TranslateMonEllipticalRespectSide, 2, ANIM_BATTLER_ATTACKER, 16, 6, 1, 4","source_args":[0,16,6,1,4]},
		{"op":"effect","behavior":"actor_motion","ticks":16,"selector":"attacker","x":16,"y":6,"cycles":1,"motion":"ellipse","mirror_source":"attacker","source_task":"AnimTask_TranslateMonEllipticalRespectSide","source_line":1330},
		{"op":"source_control","condition":"always","target":805},
		{"op":"source_label","source_pc":805,"source_line":1331,"source_command":"createsprite gBattleAnimSpriteTemplate_83D748C, ANIM_BATTLER_ATTACKER, 2, 0, 0","source_args":[0,0]},
		{"op":"effect","behavior":"source_particle","mode":"sword_rise","selector":"attacker","offset":[0,0],"mirror_offset":true,"offset_direction":"source_origin_toward_target","ticks":51,"frame_size":[32,64],"frame_program":[{"op":"frame","tile":0,"ticks":1},{"op":"end"}],"frame_commands":[{"tile":0,"ticks":1}],"affine_program":[{"op":"frame","x":16,"y":256,"rotation":0,"ticks":0},{"op":"frame","x":20,"y":0,"rotation":0,"ticks":12},{"op":"frame","x":0,"y":0,"rotation":0,"ticks":32},{"op":"end"}],"source_template":"gBattleAnimSpriteTemplate_83D748C","source_callback":"sub_80CF690","source_animation_index":0,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_SWORD","source_palette_tag":"ANIM_TAG_SWORD","source_oam":"&gOamData_837E0FC","source_module":"state_props","source_args":[0,0],"anchor":"origin","affine_hold_ticks":44,"travel_ticks":6,"rise":32,"source_private":["sub_80785E4","sub_80CF6B4","StartAnimLinearTranslation"],"texture":"res://graficos/batalla/animaciones/sword_pal_5_32x64_0.png","frame_rects":{"0":[0,0,32,64]},"source_line":1331},
		{"op":"source_control","condition":"always","target":806},
		{"op":"source_label","source_pc":806,"source_line":1332,"source_command":"delay 22"},
		{"op":"wait","ticks":22,"source_line":1332},
		{"op":"source_control","condition":"always","target":807},
		{"op":"source_label","source_pc":807,"source_line":1333,"source_command":"createvisualtask sub_80E21A8, 2, ANIM_TAG_SWORD, 2, 2, 32754, 16, 0, 0","source_args":[10005,2,2,32754,16,0,0]},
		{"op":"effect","behavior":"source_state_props_task","source_callback":"sub_80E21A8","task_mode":"tag_palette","source_palette_tag":"ANIM_TAG_SWORD","palette_states":[[32754,16],[0,0]],"switch_count":2,"interval":3,"ticks":11,"source_args":[10005,2,2,32754,16,0,0],"source_private":["sub_80E2214","sub_80E22CC"],"source_task":"sub_80E21A8","source_line":1333},
		{"op":"source_control","condition":"always","target":808},
		{"op":"source_label","source_pc":808,"source_line":1334,"source_command":"waitforvisualfinish"},
		{"op":"barrier","source_line":1334},
		{"op":"source_control","condition":"always","target":809},
		{"op":"source_label","source_pc":809,"source_line":1335,"source_command":"clearmonbg ANIM_BATTLER_ATTACKER"},
		{"op":"effect","behavior":"source_legacy_impact_command","mode":"clearmonbg","source_args":[0],"ticks":1,"source_line":1335,"source_command":"clearmonbg ANIM_BATTLER_ATTACKER","source_script":"Move_SWORDS_DANCE"},
		{"op":"source_control","condition":"always","target":810},
		{"op":"source_label","source_pc":810,"source_line":1336,"source_command":"blendoff"},
		{"op":"effect","behavior":"source_legacy_impact_command","mode":"blendoff","source_args":[],"ticks":1,"source_line":1336,"source_command":"blendoff","source_script":"Move_SWORDS_DANCE"},
		{"op":"source_control","condition":"always","target":811},
		{"op":"source_label","source_pc":811,"source_line":1337,"source_command":"delay 1"},
		{"op":"wait","ticks":1,"source_line":1337},
		{"op":"source_control","condition":"always","target":812},
		{"op":"source_label","source_pc":812,"source_line":1338,"source_command":"end"},
		{"op":"source_control","condition":"end","source_line":1338},
		{"op":"marker","name":"impact"},
		{"op":"barrier"},
		{"op":"end"},
	],
}

# Registry identity is separate from public dispatch slots and caller-created tokens.
# The runner opens/closes this synchronous scope around the actual selected factory.
static var _invocations: Dictionary={}

class Invocation extends RefCounted:
	var incoming: Dictionary
	var context: BattleAnimationContext
	var definition: BattleAnimationDefinition
	var pc: int
	var claimed: bool=false
	var pending: Dictionary={}

class Session extends RefCounted:
	var context: BattleAnimationContext
	var definition: BattleAnimationDefinition
	var program: Array=[]
	var originals: Dictionary={}
	var sprites: Dictionary={}
	var objects: Array[Dictionary]=[]
	var motions: Array[Dictionary]=[]
	var palettes: Array[Dictionary]=[]
	var valid: bool=true

static func matches(owner: Node2D) -> bool:
	return owner is BattleAnimationSequenceRunner and owner.definition!=null and is_same(owner.definition,BattleAnimationSequenceRegistry._builtin_source_definitions.get("ruby:move/14"))

static func _shape(actual: Variant,expected: Dictionary) -> bool:
	if not actual is Dictionary:return false
	var art: bool=expected.get("source_callback")=="sub_80CF690"
	for key: String in expected:
		if art and key in ART:continue
		if not actual.has(key) or not Same._same(actual[key],expected[key]):return false
	for key: Variant in actual:
		var name: String
		if typeof(key)==TYPE_STRING:name=key
		elif typeof(key)==TYPE_STRING_NAME and art and str(key) in ART:name=str(key)
		else:return false
		if not expected.has(name) and (not art or name not in ART):return false
	return not art or not Art._rects(actual).is_empty()

static func _whole(owner: Node2D) -> bool:
	if not matches(owner) or owner.definition.key!=PROGRAM.key or owner.definition.coverage!=PROGRAM.coverage or owner.definition.source_script!=PROGRAM.source_script:return false
	if not Same._same(owner._steps,owner.definition.steps) or owner._steps.size()!=PROGRAM.steps.size():return false
	for pc: int in PROGRAM.steps.size():
		if not _shape(owner._steps[pc],PROGRAM.steps[pc]):return false
	return true

static func _group(owner: Node2D) -> Session:
	return owner.get_meta(STATE) as Session if owner.has_meta(STATE) else null

static func open_dispatch(owner: Node2D,step: Dictionary) -> Invocation:
	if not matches(owner) or _invocations.has(owner.get_instance_id()):return null
	var scope:=Invocation.new();scope.incoming=step;scope.context=owner.context;scope.definition=owner.definition;scope.pc=owner._pc
	_invocations[owner.get_instance_id()]=scope
	return scope

static func close_dispatch(owner: Node2D,scope: Invocation) -> void:
	if scope==null:return
	scope.pending.clear()
	if is_same(_invocations.get(owner.get_instance_id()),scope):_invocations.erase(owner.get_instance_id())

static func _live(owner: Node2D,c: BattleAnimationContext,step: Dictionary) -> Invocation:
	var scope: Invocation=_invocations.get(owner.get_instance_id()) as Invocation
	if scope==null or not is_same(scope.context,c) or not is_same(owner.context,c) or not is_same(scope.definition,owner.definition) or scope.pc!=owner._pc or not is_same(scope.incoming,step):return null
	return scope

static func _admit(step: Dictionary,c: BattleAnimationContext,owner: Node2D,behavior: String) -> bool:
	var scope: Invocation=_live(owner,c,step);var group: Session=_group(owner)
	if scope==null or scope.claimed or (group!=null and not group.valid) or not _whole(owner):return false
	var pc: int=owner._pc
	if pc<=0 or pc>=PROGRAM.steps.size() or PROGRAM.steps[pc].get("behavior")!=behavior:return false
	var plain: Dictionary=step.duplicate(true);var priority: Dictionary=BattleSourcePriority.command_metadata(PROGRAM.steps[pc-1])
	if not priority.is_empty():
		if not Same._same(plain.get("source_command_priority"),priority):return false
		plain.erase("source_command_priority")
	elif plain.has("source_command_priority"):return false
	if not _shape(plain,PROGRAM.steps[pc]) or not Same._same(plain,owner._steps[pc]):return false
	if not owner.claim_effect_dispatch(step):return false
	scope.claimed=true
	return true

static func _session(owner: Node2D,c: BattleAnimationContext) -> Session:
	var group: Session=_group(owner)
	if group==null:
		group=Session.new();group.context=c;group.definition=owner.definition;group.program=owner._steps.duplicate(true)
		for actor: BattleAnimationActor in c.actors.values():group.originals[actor.id]=actor;group.sprites[actor.id]=actor.sprite
		owner.set_meta(STATE,group)
	return group

static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if not _admit(step,c,owner,"source_legacy_impact_command"):return []
	_session(owner,c)
	var trace: Array=owner.get_meta("source_legacy_impact_commands",[]);trace.append(int(step.source_line));owner.set_meta("source_legacy_impact_commands",trace)
	match str(step.mode):
		"setalpha","blendoff":
			owner.set_meta("source_legacy_impact_alpha",[12,8] if step.mode=="setalpha" else [16,0])
			for item: Dictionary in _group(owner).objects:
				if step.mode=="blendoff":_release_material(item)
				else:Owned.uniform(item,"eva",0.75);Owned.uniform(item,"evb",0.5)
			return []
		"clearmonbg":
			for t: Dictionary in owner.get_meta("source_legacy_impact_backgrounds",[]):Pair._clear_pair(t)
			return []
	var tracks: Array[Dictionary]=Pair._create_pair_bg(c,owner,0,"source_legacy_impact_bg","source_legacy_impact_backgrounds")
	for t: Dictionary in tracks:t.update=_background
	_order(owner,c);return tracks

# Normalization is a delegated recipe, not a source receipt. Original incoming
# identity remains in its real invocation until one matching construction consumes it.
static func prepare(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Dictionary:
	if not matches(owner):return {"handled":false}
	if not _admit(step,c,owner,"source_particle"):return {"handled":true}
	var actors: Array[BattleAnimationActor]=c.resolve("attacker")
	if actors.is_empty() or not actors[0].is_present():return {"handled":true}
	var group: Session=_session(owner,c);var scope: Invocation=_live(owner,c,step)
	if group.originals.get(c.attacker_id)!=actors[0] or group.sprites.get(c.attacker_id)!=actors[0].sprite:return {"handled":true}
	var normalized: Dictionary=step.duplicate(true);normalized.offset_direction="actor_side";normalized.frame_rects=Art._rects(step)
	# Mandatory Boolean decoration from the admitted context, not incoming intent.
	normalized["source_contest"]=c.contest
	# Zero source offset needs no target direction. Generic particle internals stay literal.
	var token:=RefCounted.new()
	scope.pending[token]={"normalized":normalized.duplicate(true),"original":step,"actor":actors[0],"sprite":actors[0].sprite,"origin":owner.to_local(actors[0].sprite.to_global(Vector2.ZERO)),"group":group}
	return {"handled":true,"step":normalized,"admission":token}

static func attach(t: Dictionary,c: BattleAnimationContext,owner: Node2D,token: RefCounted) -> void:
	var scope: Invocation=_invocations.get(owner.get_instance_id()) as Invocation
	if scope==null or not scope.pending.has(token):return
	var record: Dictionary=scope.pending[token];scope.pending.erase(token)
	if not is_same(_live(owner,c,record.original),scope) or not scope.claimed or not _whole(owner) or not Same._same(t.settings,record.normalized):return
	if t.kind!="source_particle" or not t.node is Sprite2D or t.node.get_parent()!=owner or t.node.is_queued_for_deletion() or not Same._same(t.age,0) or not Same._same(t.ticks,51):return
	var settings: Dictionary=record.normalized
	if t.node.texture!=load(settings.texture) or not t.node.region_enabled or t.node.hframes!=1 or t.node.vframes!=1 or t.node.modulate!=Color(str(settings.get("color","ffffff"))):return
	if not t.node.scale.is_equal_approx(Vector2.ONE*float(settings.get("scale_factor",1.0))):return
	if bool(settings.get("recolor",false)):
		if not t.node.material is ShaderMaterial or t.node.material.shader!=load("res://scripts/battle/animations/sequence/particle_recolor.gdshader") or t.node.material.get_shader_parameter("tint")!=Color(str(settings.get("color","ffffff"))):return
	elif t.node.material!=null:return
	var actor: BattleAnimationActor=record.actor
	if c.actors.get(actor.id)!=actor or actor.sprite!=record.sprite or not actor.is_present():return
	var item: Dictionary={"node":t.node,"output_texture":t.node.texture,"parent":owner,"context":c,"definition":owner.definition,"actor":actor,"sprite":actor.sprite,"sprite_parent":actor.sprite.get_parent(),"texture":actor.sprite.texture,"generation":actor._generation,"slot":actor.slot,"position":c.source_position(actor.id),"primary":c.attacker_id,"contest":c.contest,"origin":record.origin,"factor":float(t.settings.get("scale_factor",1.0)),"subpriority":maxi(3,BattleElectricContract.source_subpriority(actor,c)-2),"track":t,"settings":t.settings.duplicate(true),"writes":{},"lost":{},"material":null,"previous":t.node.material,"shader":null,"uniforms":{},"revoked":{},"lost_material":false,"active":true,"retired":false}
	# Capture the actual approved literal material tint, not COLOR (which also
	# contains inherited/self modulation). The literal recolor shader ignores COLOR.
	var recolor: bool=bool(settings.get("recolor",false))
	var recolor_tint: Color=t.node.material.get_shader_parameter("tint") if recolor else Color.WHITE
	var material:=ShaderMaterial.new();material.shader=COMBINED
	material.set_shader_parameter("source_recolor",recolor);material.set_shader_parameter("source_recolor_tint",recolor_tint)
	material.set_shader_parameter("eva",0.75);material.set_shader_parameter("evb",0.5);material.set_shader_parameter("blend_amount",0.0)
	t.node.material=material;item.material=material;item.shader=material.shader
	for parameter: Dictionary in material.shader.get_shader_uniform_list():item.uniforms[str(parameter.name)]=material.get_shader_parameter(str(parameter.name))
	t.origin=record.origin;t.destination=record.origin;t.i157_item=item;t.update=_advance;t.cleanup=_cleanup_art.bind(item)
	t.source_oam_priority=2;t.source_oam_subpriority=item.subpriority;t.source_priority_actor_id=actor.id
	record.group.objects.append(item)
	var objects: Array=owner.get_meta("source_legacy_impact_objects",[]);objects.append(item);owner.set_meta("source_legacy_impact_objects",objects)
	_advance(t,c);_order(owner,c)

static func _bound(item: Dictionary,c: BattleAnimationContext) -> bool:
	return not item.retired and is_instance_valid(item.parent) and is_same(item.parent.context,c) and is_same(item.parent.definition,item.definition) and c.attacker_id==item.primary and c.contest==item.contest and c.source_position(item.actor.id)==item.position and c.actors.get(item.actor.id)==item.actor and item.actor.sprite==item.sprite and item.actor.is_present() and Pair._visual(item)

static func _advance(t: Dictionary,c: BattleAnimationContext) -> void:
	var item: Dictionary=t.i157_item;var group: Session=_group(item.parent)
	if group==null or not group.valid or not _bound(item,c) or not Owned.node(item) or not Same._same(t.settings,item.settings):
		_retire(item);return
	var age: int=maxi(0,int(t.age));var logical: float=float(16+20*mini(age,12))/256.0
	var point: Vector2=item.origin+Vector2(0,-32.0*clampf(float(age-44)/6.0,0,1))
	Owned.write(item,"transform",Transform2D(0,Vector2(logical,1)*float(item.factor),0,point))
	var frame: Dictionary=t.settings.frame_commands[0];var rect: Array=t.settings.frame_rects[str(int(frame.tile))]
	Owned.write(item,"region_rect",Rect2(rect[0],rect[1],rect[2],rect[3]))
	Owned.write(item,"flip_h",bool(t.settings.get("flip_h",false))!=bool(frame.get("flip_h",false)))
	Owned.write(item,"flip_v",bool(t.settings.get("flip_v",false))!=bool(frame.get("flip_v",false)))

static func _release_material(item: Dictionary) -> void:
	if not item.active:return
	# Same-material foreign shader OR any uniform intent revokes restoration too.
	if Owned.observe_material(item) and item.revoked.is_empty():item.node.material=item.previous
	item.active=false

static func _retire(item: Dictionary) -> void:
	if item.retired:return
	item.retired=true;item.lost_material=true
	if item.has("track"):item.track.ticks=int(item.track.age)
	if Owned.node(item):item.node.queue_free()

static func _cleanup_art(item: Dictionary) -> void:
	_release_material(item)
	var t: Dictionary=item.get("track",{})
	if not t.is_empty():
		t.erase("cleanup");t.erase("update");t.erase("i157_item")
		if not Owned.node(item) and is_instance_valid(item.node) and not item.node.is_queued_for_deletion():t.erase("node")
	item.erase("track")

# A new direct task is a legitimate literal receipt even if all numeric values
# equal the source task. Only the task inside THIS actual invocation is admitted.
static func palette(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Variant:
	if _live(owner,c,step)==null:
		# Calling a genuine independent generic tag constructor is new intent,
		# even before its first write and even when that write equals ours.
		var original: Session=_group(owner)
		if original!=null and step.get("task_mode")=="tag_palette" and step.get("source_palette_tag")=="ANIM_TAG_SWORD":
			for item: Dictionary in original.objects:item.lost_material=true
		return null
	if not matches(owner):return null
	if not _admit(step,c,owner,"source_state_props_task"):return []
	var group: Session=_session(owner,c)
	var t: Dictionary={"kind":"source_state_props_task","age":0,"ticks":int(step.ticks),"settings":step.duplicate(true),"owner":owner,"update":_palette_update}
	t.cleanup=_cleanup_palette.bind(t);group.palettes.append(t);_palette_update(t,c)
	return [t]

static func _palette_update(t: Dictionary,c: BattleAnimationContext) -> void:
	var owner: Node2D=t.owner;var group: Session=_group(owner)
	if group==null or not group.valid or not group.palettes.any(func(receipt: Dictionary)->bool:return is_same(receipt,t)):return
	var age: int=int(t.age);var pair: Array=t.settings.palette_states[mini(2,age/3)%2]
	if age>=int(t.ticks)-1:pair=[0,0]
	for item: Dictionary in group.objects:
		if not item.active or not _bound(item,c) or not Owned.node(item):continue
		# Revoke the entire original palette lease after foreign intent, rather
		# than continuing to write its other still-equal channels.
		if item.node.texture!=item.output_texture or not Owned.observe_material(item) or not item.revoked.is_empty():item.lost_material=true;continue
		var value: int=int(pair[0])
		Owned.uniform(item,"blend_color",Color(float(value&31)/31.0,float((value>>5)&31)/31.0,float((value>>10)&31)/31.0))
		Owned.uniform(item,"blend_amount",float(pair[1])/16.0)

static func _cleanup_palette(t: Dictionary) -> void:
	if t.has("owner") and is_instance_valid(t.owner):
		var group: Session=_group(t.owner)
		if group!=null:
			for index: int in range(group.palettes.size()-1,-1,-1):
				if is_same(group.palettes[index],t):group.palettes.remove_at(index)
	t.erase("cleanup");t.erase("update");t.erase("owner")

# The shared ellipse constructor stays unchanged; only this admitted source call
# receives an identity binding so its offset cannot migrate to a successor.
static func motion(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Dictionary:
	if not matches(owner):return {"handled":false}
	if not _admit(step,c,owner,"actor_motion"):return {"handled":true}
	var group: Session=_session(owner,c)
	var actors: Array[BattleAnimationActor]=c.resolve("attacker")
	if actors.is_empty() or group.originals.get(c.attacker_id)!=actors[0] or group.sprites.get(c.attacker_id)!=actors[0].sprite:return {"handled":true}
	return {"handled":true,"admitted":true}

static func bind_motion(owner: Node2D,c: BattleAnimationContext,tracks: Array[Dictionary]) -> void:
	var group: Session=_group(owner)
	if group==null:return
	for t: Dictionary in tracks:
		var actor: BattleAnimationActor=t.actor
		group.motions.append({"track":t,"actor":actor,"sprite":actor.sprite,"sprite_parent":actor.sprite.get_parent(),"texture":actor.sprite.texture,"generation":actor._generation,"slot":actor.slot,"position":c.source_position(actor.id),"primary":c.attacker_id,"contest":c.contest,"parent":owner,"definition":owner.definition,"retired":false})

static func _background(t: Dictionary,c: BattleAnimationContext) -> void:
	var group: Session=_group(t.owner)
	if group==null or not group.valid:
		Pair._cleanup_pair(t);t.ticks=int(t.age);return
	Pair._advance_pair(t,c)

static func begin_tick(owner: Node2D,c: BattleAnimationContext) -> void:
	var group: Session=_group(owner)
	if group==null:return
	if not _whole(owner) or not Same._same(owner._steps,group.program) or not is_same(group.context,c) or not is_same(group.definition,owner.definition):group.valid=false
	for t: Dictionary in owner.get_meta("source_legacy_impact_backgrounds",[]):
		for item: Dictionary in t.clones:
			for key: String in item.writes:
				if is_instance_valid(item.node) and item.node.get(key)!=item.writes[key]:item.lost[key]=true
	for item: Dictionary in group.objects:
		if is_instance_valid(item.node):
			for key: String in item.writes:
				if item.node.get(key)!=item.writes[key]:item.lost[key]=true
			if item.node.texture!=item.output_texture or not Owned.observe_material(item) or not item.revoked.is_empty():item.lost_material=true
		if not group.valid or not _bound(item,c):_retire(item)
	for binding: Dictionary in group.motions:
		if group.valid and _bound(binding,c):continue
		binding.retired=true
		# Remove before runner accumulates per-id offsets. Do not touch a successor.
		for index: int in range(owner._tracks.size()-1,-1,-1):
			if is_same(owner._tracks[index],binding.track):owner._tracks.remove_at(index)

static func _order(owner: Node2D,c: BattleAnimationContext) -> void:
	var group: Session=_group(owner)
	if group==null or not group.valid:return
	var band: int=BattleSourcePriority.effective_layer(c.field)-BattleSourcePriority.effective_layer(owner)+1
	for actor: BattleAnimationActor in c.actors.values():
		if actor.is_present():band=maxi(band,BattleSourcePriority.actor_layer(actor,owner))
	for t: Dictionary in owner.get_meta("source_legacy_impact_backgrounds",[]):
		for item: Dictionary in t.clones:
			if not item.retired and Owned.node(item):Owned.write(item,"z_index",band+(1 if int(item.bg_plane)==1 else 0))
	for item: Dictionary in group.objects:
		if _bound(item,c) and Owned.node(item):Owned.write(item,"z_index",band+62-int(item.subpriority))

static func after_pose(owner: Node2D,c: BattleAnimationContext) -> void:
	var group: Session=_group(owner)
	if group==null or not group.valid:return
	for t: Dictionary in owner.get_meta("source_legacy_impact_backgrounds",[]):Pair._after_pair_pose(t)
	for item: Dictionary in group.objects:
		if item.has("track"):_advance(item.track,c)
	_order(owner,c)

static func release(owner: Node2D) -> void:
	var group: Session=_group(owner)
	if group==null:return
	for item: Dictionary in group.objects:_release_material(item);item.erase("track")
	for t: Dictionary in group.palettes.duplicate():_cleanup_palette(t)
	group.motions.clear();group.objects.clear();owner.remove_meta(STATE)
	_invocations.erase(owner.get_instance_id())

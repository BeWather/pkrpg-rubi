extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Complete finite CrossImpact source composition; no global blend/selector authority.
const Same=preload("res://scripts/battle/animations/sequence/source_cutting_slice.gd")
const Jump=preload("res://scripts/battle/animations/sequence/source_jump_kick_composition.gd")
const Pair=preload("res://scripts/battle/animations/sequence/source_charge_owned.gd")
const Owned=preload("res://scripts/battle/animations/sequence/source_owned_composition.gd")
const SPECS := {"ruby:move/238":"Move_CROSS_CHOP","ruby:move/348":"Move_LEAF_BLADE"}
const ART := ["texture","frame_rects","color","recolor","scale_factor","flip_h","flip_v"]
const COMMANDS := {4505:["ruby:move/348",39,{"op":"effect","behavior":"source_legacy_impact_command","mode":"monbg","source_args":[1],"ticks":1,"source_line":4505,"source_command":"monbg ANIM_BATTLER_TARGET","source_script":"Move_LEAF_BLADE"}],4506:["ruby:move/348",42,{"op":"effect","behavior":"source_legacy_impact_command","mode":"setalpha","source_args":[12,8],"ticks":1,"source_line":4506,"source_command":"setalpha 12, 8","source_script":"Move_LEAF_BLADE"}],4512:["ruby:move/348",60,{"op":"effect","behavior":"source_legacy_impact_command","mode":"clearmonbg","source_args":[1],"ticks":1,"source_line":4512,"source_command":"clearmonbg ANIM_BATTLER_TARGET","source_script":"Move_LEAF_BLADE"}],4513:["ruby:move/348",63,{"op":"effect","behavior":"source_legacy_impact_command","mode":"blendoff","source_args":[],"ticks":1,"source_line":4513,"source_command":"blendoff","source_script":"Move_LEAF_BLADE"}],6460:["ruby:move/238",6,{"op":"effect","behavior":"source_legacy_impact_command","mode":"monbg","source_args":[3],"ticks":1,"source_line":6460,"source_command":"monbg ANIM_BATTLER_DEF_PARTNER","source_script":"Move_CROSS_CHOP"}],6461:["ruby:move/238",9,{"op":"effect","behavior":"source_legacy_impact_command","mode":"setalpha","source_args":[12,8],"ticks":1,"source_line":6461,"source_command":"setalpha 12, 8","source_script":"Move_CROSS_CHOP"}],6471:["ruby:move/238",43,{"op":"effect","behavior":"source_legacy_impact_command","mode":"clearmonbg","source_args":[3],"ticks":1,"source_line":6471,"source_command":"clearmonbg ANIM_BATTLER_DEF_PARTNER","source_script":"Move_CROSS_CHOP"}],6472:["ruby:move/238",46,{"op":"effect","behavior":"source_legacy_impact_command","mode":"blendoff","source_args":[],"ticks":1,"source_line":6472,"source_command":"blendoff","source_script":"Move_CROSS_CHOP"}]}
const SITES := {4509:["ruby:move/348",51,{"op":"effect","behavior":"source_particle","mode":"h_cross_impact","selector":"target","offset":[0,0],"mirror_offset":false,"offset_direction":"source_origin_toward_target","ticks":37,"frame_size":[32,32],"frame_program":[{"op":"frame","tile":0,"ticks":1},{"op":"end"}],"frame_commands":[{"tile":0,"ticks":1}],"affine_program":[],"source_template":"gBattleAnimSpriteTemplate_83DB520","source_callback":"sub_80E2978","source_animation_index":0,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_CROSS_IMPACT","source_palette_tag":"ANIM_TAG_CROSS_IMPACT","source_oam":"&gOamData_837E054","source_module":"contact_selected","source_args":[0,0,1,36],"anchor":"center","source_private":["WaitAnimForDuration","DestroyAnimSprite"],"texture":"res://graficos/batalla/animaciones/cross_impact_pal_285_32x32_0.png","frame_rects":{"0":[0,0,32,32]},"source_line":4509}],6463:["ruby:move/238",15,{"op":"effect","behavior":"source_particle","mode":"h_cross_chop","selector":"target","offset":[0,0],"mirror_offset":false,"offset_direction":"source_origin_toward_target","ticks":50,"frame_size":[32,32],"frame_program":[{"op":"frame","tile":48,"ticks":1,"flip_h":false,"flip_v":false},{"op":"end"}],"frame_commands":[{"tile":48,"ticks":1,"flip_h":false,"flip_v":false}],"affine_program":[],"source_template":"gBattleAnimSpriteTemplate_83D9FD8","source_callback":"sub_80D92D0","source_animation_index":0,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_HANDS_AND_FEET","source_palette_tag":"ANIM_TAG_HANDS_AND_FEET","source_oam":"&gOamData_837DF34","source_module":"contact_selected","source_args":[0,0,0],"phase_ticks":[30,11,8],"flip_h":false,"source_private":["StartAnimLinearTranslation","sub_80D9328"],"texture":"res://graficos/batalla/animaciones/hands_and_feet_pal_143_32x32_48.png","frame_rects":{"48":[0,0,32,32]},"source_line":6463}],6464:["ruby:move/238",18,{"op":"effect","behavior":"source_particle","mode":"h_cross_chop","selector":"target","offset":[0,0],"mirror_offset":false,"offset_direction":"source_origin_toward_target","ticks":50,"frame_size":[32,32],"frame_program":[{"op":"frame","tile":48,"ticks":1,"flip_h":false,"flip_v":false},{"op":"end"}],"frame_commands":[{"tile":48,"ticks":1,"flip_h":false,"flip_v":false}],"affine_program":[],"source_template":"gBattleAnimSpriteTemplate_83D9FD8","source_callback":"sub_80D92D0","source_animation_index":0,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_HANDS_AND_FEET","source_palette_tag":"ANIM_TAG_HANDS_AND_FEET","source_oam":"&gOamData_837DF34","source_module":"contact_selected","source_args":[0,0,1],"phase_ticks":[30,11,8],"flip_h":true,"source_private":["StartAnimLinearTranslation","sub_80D9328"],"texture":"res://graficos/batalla/animaciones/hands_and_feet_pal_143_32x32_48.png","frame_rects":{"48":[0,0,32,32]},"source_line":6464}],6468:["ruby:move/238",34,{"op":"effect","behavior":"source_particle","mode":"h_cross_impact","selector":"target","offset":[0,0],"mirror_offset":false,"offset_direction":"source_origin_toward_target","ticks":21,"frame_size":[32,32],"frame_program":[{"op":"frame","tile":0,"ticks":1},{"op":"end"}],"frame_commands":[{"tile":0,"ticks":1}],"affine_program":[],"source_template":"gBattleAnimSpriteTemplate_83DB520","source_callback":"sub_80E2978","source_animation_index":0,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_CROSS_IMPACT","source_palette_tag":"ANIM_TAG_CROSS_IMPACT","source_oam":"&gOamData_837E054","source_module":"contact_selected","source_args":[0,0,1,20],"anchor":"center","source_private":["WaitAnimForDuration","DestroyAnimSprite"],"texture":"res://graficos/batalla/animaciones/cross_impact_pal_285_32x32_0.png","frame_rects":{"0":[0,0,32,32]},"source_line":6468}]}

static func matches(owner: Node2D) -> bool:
	return owner is BattleAnimationSequenceRunner and owner.definition!=null and SPECS.has(owner.definition.key) and BattleAnimationSequenceRegistry.is_builtin_source_definition(owner.definition) and owner.definition.source_script==SPECS[owner.definition.key]

static func _shape(actual: Dictionary,expected: Dictionary,art: bool=false) -> bool:
	for key: String in expected:
		if art and key in ART:continue
		if not actual.has(key) or not Same._same(actual[key],expected[key]):return false
	for key: String in actual:
		if not expected.has(key) and (not art or key not in ART):return false
		if key in ["recolor","flip_h","flip_v"] and typeof(actual[key])!=TYPE_BOOL:return false
	if actual.has("scale_factor") and (typeof(actual.scale_factor) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(actual.scale_factor))):return false
	return true

# The runner alone decorates the current createsprite dispatch. Validate its
# complete typed priority descriptor before comparing the unadorned preimages.
static func _plain(owner: Node2D,step: Dictionary) -> Dictionary:
	var plain: Dictionary=step.duplicate(true)
	if plain.has("source_command_priority"):
		if owner._pc<=0 or owner._pc>=owner.definition.steps.size():return {}
		var expected: Dictionary=BattleSourcePriority.command_metadata(owner.definition.steps[owner._pc-1])
		if expected.is_empty() or not Same._same(plain.source_command_priority,expected):return {}
		plain.erase("source_command_priority")
	if plain.has("source_contest"):
		if not Same._same(plain.source_contest,owner.context.contest):return {}
		plain.erase("source_contest")
	return plain

static func _line(step: Dictionary) -> int:
	var value: Variant=step.get("source_line")
	return int(value) if typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floor(float(value)) else -1

static func _at(owner: Node2D,step: Dictionary,spec: Array,art: bool=false) -> bool:
	var pc: int=int(spec[1])
	return matches(owner) and owner.definition.key==spec[0] and owner._pc==pc and pc<owner._steps.size() and pc<owner.definition.steps.size() and _shape(_plain(owner,step),spec[2],art) and _shape(owner._steps[pc],spec[2],art) and _shape(owner.definition.steps[pc],spec[2],art)

static func _bound(item: Dictionary,c: BattleAnimationContext) -> bool:
	var current: Dictionary=Jump._snapshot(c)
	return (not item.has("parent") or matches(item.parent)) and not current.is_empty() and current.positions==item.binding.positions and Jump._bound(item,c)

static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var spec: Array=COMMANDS.get(_line(step),[])
	if spec.is_empty() or not _at(owner,step,spec) or not owner.claim_effect_dispatch(step):return []
	var trace: Array=owner.get_meta("source_legacy_impact_commands",[]);trace.append(int(step.source_line));owner.set_meta("source_legacy_impact_commands",trace)
	var mode: String=step.mode
	if mode in ["setalpha","blendoff"]:
		owner.set_meta("source_legacy_impact_alpha",[12,8] if mode=="setalpha" else [16,0])
		for item: Dictionary in owner.get_meta("source_legacy_impact_objects",[]):
			if mode=="blendoff":Owned.release_object(item)
			else:Owned.uniform(item,"eva",0.75);Owned.uniform(item,"evb",0.5)
		return []
	if mode=="clearmonbg":
		for track: Dictionary in owner.get_meta("source_legacy_impact_backgrounds",[]):
			if track.get("i154_pair",false):Pair._clear_pair(track);continue
			track.cleared=true;track.ticks=int(track.age)+2
			for item: Dictionary in track.clones:
				Owned.restore(item,c)
				if Owned.node(item):Owned.write(item,"visible",false)
		return []
	if owner.definition.key=="ruby:move/348":
		var tracks: Array[Dictionary]=Pair._create_pair_bg(c,owner,1,"source_legacy_impact_bg","source_legacy_impact_backgrounds")
		_order(owner,c);return tracks
	var binding: Dictionary=Jump._snapshot(c)
	var targets: Array=c.resolve("target")
	if binding.is_empty() or targets.is_empty():return []
	var track: Dictionary={"kind":"source_legacy_impact_bg","domain":"maintenance","age":0,"ticks":4096,"owner":owner,"context":c,"clones":[],"cleared":false,"update":_advance}
	for actor: BattleAnimationActor in c.actors.values():
		if actor!=targets[0] and (owner.definition.key=="ruby:move/348" or c.source_position(actor.id)!=(c.source_position(targets[0].id)^2)):continue
		if not actor.is_present() or not actor.sprite.is_visible_in_tree() or (c.contest and actor.id!=c.attacker_id):continue
		var node: Sprite2D=BattleIdentityCopy.clone_sprite(actor,owner);owner.add_child(node)
		var item: Dictionary={"actor":actor,"node":node,"parent":owner,"binding":binding,"bg_plane":1 if c.contest or c.source_position(actor.id) in [1,2] else 2,"writes":{},"lost":{},"retired":false}
		track.clones.append(item);Owned.follow(item,owner);Owned.write(item,"visible",true);actor.apply_source_state("hidden",true)
	if track.clones.is_empty():return []
	track.cleanup=Owned.cleanup_bg.bind(track)
	var backgrounds: Array=owner.get_meta("source_legacy_impact_backgrounds",[]);backgrounds.append(track);owner.set_meta("source_legacy_impact_backgrounds",backgrounds)
	_order(owner,c);return [track]

static func attach(t: Dictionary,c: BattleAnimationContext,owner: Node2D,incoming: Dictionary) -> void:
	var spec: Array=SITES.get(_line(t.settings),[])
	if spec.is_empty() or not _at(owner,t.settings,spec,true) or t.kind!="source_particle" or not t.node is Sprite2D:return
	if not owner.claim_effect_dispatch(incoming):return
	var binding: Dictionary=Jump._snapshot(c)
	var actors: Array=c.resolve("target" if owner.definition.key=="ruby:move/348" else "attacker")
	if binding.is_empty() or actors.is_empty():return
	var impact: bool=int(t.settings.source_line) in [6468,4509]
	var subpriority: int=maxi(3,BattleElectricContract.source_subpriority(actors[0],c)-(3 if int(t.settings.source_line)==6468 else 2))
	t.source_oam_priority=2;t.source_oam_subpriority=subpriority
	var node: Sprite2D=t.node
	var target: BattleAnimationActor=c.actors[c.target_ids[0]]
	var field_origin: Vector2=c.field.to_local(target.sprite.to_global(target.sprite.get_rect().get_center()))
	node.position=owner.to_local(c.field.to_global(field_origin))
	t.origin=node.position;t.destination=node.position
	var item: Dictionary={"node":node,"parent":owner,"binding":binding,"actor":actors[0],"subpriority":subpriority,"writes":{},"lost":{},"material":null,"previous":node.material,"shader":null,"uniforms":{},"revoked":{},"lost_material":false,"active":true,"track":t,"field_origin":field_origin}
	if impact and node.material==null and not bool(t.settings.get("recolor",false)):
		var material: ShaderMaterial=BattleIdentityCopy.blend_material(false);material.set_shader_parameter("eva",0.75);material.set_shader_parameter("evb",0.5)
		node.material=material;item.material=material;item.shader=material.shader
		for key: String in ["eva","evb","first_tint"]:item.uniforms[key]=material.get_shader_parameter(key)
	var objects: Array=owner.get_meta("source_legacy_impact_objects",[]);objects.append(item);owner.set_meta("source_legacy_impact_objects",objects)
	t.cleanup=_release_art.bind(item)
	_order(owner,c)

static func _release_art(item: Dictionary) -> void:
	item.erase("track") # Break track -> cleanup -> item -> track ownership cycle.
	Owned.release_object(item)

static func _advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if t.get("i154_pair",false):Pair._advance_pair(t,c);return
	for item: Dictionary in t.clones:
		if not _bound(item,c) or not Owned.node(item):Owned.retire(item,c)
	if not t.cleared and not t.clones.any(func(item: Dictionary)->bool:return not item.retired):t.ticks=int(t.age)

static func _order(owner: Node2D,c: BattleAnimationContext) -> void:
	var band: int=BattleSourcePriority.effective_layer(c.field)-BattleSourcePriority.effective_layer(owner)+1
	for actor: BattleAnimationActor in c.actors.values():
		if actor.is_present():band=maxi(band,BattleSourcePriority.actor_layer(actor,owner))
	for t: Dictionary in owner.get_meta("source_legacy_impact_backgrounds",[]):
		for item: Dictionary in t.clones:
			if not item.retired and (Pair._pair_bound(item,c) if t.get("i154_pair",false) else _bound(item,c)):Owned.write(item,"z_index",band+(1 if int(item.bg_plane)==1 else 0))
	for item: Dictionary in owner.get_meta("source_legacy_impact_objects",[]):
		Owned.observe_material(item)
		if _bound(item,c):Owned.write(item,"z_index",band+2+60-int(item.subpriority))

static func after_pose(owner: Node2D,c: BattleAnimationContext) -> void:
	begin_tick(owner,c)
	for t: Dictionary in owner.get_meta("source_legacy_impact_backgrounds",[]):
		if t.get("i154_pair",false):Pair._after_pair_pose(t);continue
		for item: Dictionary in t.clones:
			if item.retired:continue
			if not _bound(item,c) or not Owned.node(item):Owned.retire(item,c);continue
			Owned.follow(item,owner)
			if not t.cleared:Owned.write(item,"visible",true)
	for item: Dictionary in owner.get_meta("source_legacy_impact_objects",[]):
		if not item.has("track") or not Owned.node(item) or not _bound(item,c):continue
		var t: Dictionary=item.track
		var delta: Vector2=Vector2.ZERO
		if int(t.settings.source_line) in [6463,6464]:
			var age: int=int(t.age)
			var progress: float=float(mini(age,30))/30 if age<=41 else 1.0-float(mini(age-41,8))/8
			delta=Vector2(-20 if int(t.settings.source_args[2])==0 else 20,-20)*progress
		item.node.position=owner.to_local(c.field.to_global(item.field_origin+delta))
	_order(owner,c)

class PaletteGroup extends RefCounted:
	var binding: Dictionary={}
	var roles: Array=[]
	var selected: Array=[]
	var dispatched: Dictionary={}
	var writers: Array=[]
	var revoked: bool=false

const ROLES := ["background","attacker","target","attacker_partner","target_partner"]
const PALETTE := {"op":"effect","behavior":"source_palette","selector":"background","ticks":9,"palette_states":[{"ticks":4,"color":"ffffff","amount":10},{"ticks":4,"color":"000000","amount":10},{"ticks":1,"color":"000000","amount":0}],"source_line":6467}

static func _future(owner: Node2D) -> bool:
	if not matches(owner) or owner.definition.key!="ruby:move/238" or owner._steps.size()<32 or owner.definition.steps.size()<32:return false
	for n: int in 5:
		var expected: Dictionary=PALETTE.duplicate(true);expected.selector=ROLES[n]
		if not Same._same(owner._steps[27+n],expected) or not Same._same(owner.definition.steps[27+n],expected):return false
	return true

static func _logical_visible(owner: Node2D,c: BattleAnimationContext,actor: BattleAnimationActor) -> bool:
	if c.contest and actor.id!=c.attacker_id:return false
	if actor.sprite.is_visible_in_tree():return true
	for t: Dictionary in owner.get_meta("source_legacy_impact_backgrounds",[]):
		for item: Dictionary in t.clones:
			if item.actor==actor and not item.retired and _bound(item,c) and actor._owned_hidden and not actor.sprite.visible and not actor._expected_visible:return true
	return false

static func _mapped(owner: Node2D,c: BattleAnimationContext) -> Dictionary:
	var binding: Dictionary=Jump._snapshot(c)
	if binding.is_empty() or not c.actors.has(c.attacker_id) or c.target_ids.is_empty() or not c.actors.has(c.target_ids[0]):return {}
	var selected: Array=[];var roles: Array=[[]]
	for role: int in 4:
		var direct: int=c.attacker_id if role in [0,2] else c.target_ids[0]
		var position: int=int(binding.positions[direct])^(2 if role>=2 else 0)
		var members: Array=[]
		for id: int in binding.actors:
			var actor: BattleAnimationActor=binding.actors[id]
			if binding.positions[id]!=position or not actor.is_present():continue
			if role>=2 and not _logical_visible(owner,c,actor):continue
			if id not in selected:selected.append(id);members.append(actor)
		roles.append(members)
	return {"binding":binding,"selected":selected,"roles":roles}

static func _retire_group(owner: Node2D,g: PaletteGroup) -> void:
	g.revoked=true
	for writer: Dictionary in g.writers:
		for n: int in range(owner._tracks.size()-1,-1,-1):
			if is_same(owner._tracks[n],writer.track):owner._tracks.remove_at(n)
		if not writer.held.is_empty() and is_same(owner._held_blends.get(writer.actor.id),writer.held):
			owner._held_blends.erase(writer.actor.id)
			writer.actor.apply_blend(Color.WHITE,0.0)

static func _valid(owner: Node2D,c: BattleAnimationContext,g: PaletteGroup) -> bool:
	if g.revoked:_retire_group(owner,g);return false
	var mapped: Dictionary=_mapped(owner,c)
	var good: bool=_future(owner) and not mapped.is_empty() and _bound({"binding":g.binding},c) and mapped.roles==g.roles and mapped.selected==g.selected
	if good:
		for writer: Dictionary in g.writers:
			if writer.track.get("actor")!=writer.actor or not Same._same(writer.track.get("settings"),writer.step):good=false;break
			if not writer.held.is_empty() and not is_same(owner._held_blends.get(writer.actor.id),writer.held):good=false;break
	if not good:_retire_group(owner,g)
	return good

static func begin_tick(owner: Node2D,c: BattleAnimationContext,transients: Dictionary={}) -> void:
	if not owner.has_meta("i151_palette_group"):return
	var group: PaletteGroup=owner.get_meta("i151_palette_group")
	if not _valid(owner,c,group):return
	# Entry presence is a competing contributor, even at coefficient zero.
	for writer: Dictionary in group.writers:
		if transients.has(writer.actor.id):_retire_group(owner,group);return

static func palette_members(owner: Node2D,c: BattleAnimationContext,step: Dictionary,incoming: Dictionary) -> Dictionary:
	if not _future(owner) or owner._pc<27 or owner._pc>31:return {"handled":false}
	var g: PaletteGroup=(owner.get_meta("i151_palette_group") if owner.has_meta("i151_palette_group") else null)
	if g==null:
		if owner._pc!=27:return {"handled":false}
		var mapped: Dictionary=_mapped(owner,c)
		if mapped.is_empty():return {"handled":false}
		g=PaletteGroup.new();g.binding=mapped.binding;g.roles=mapped.roles;g.selected=mapped.selected
	if not _valid(owner,c,g) or g.dispatched.has(owner._pc) or not Same._same(_plain(owner,step),owner._steps[owner._pc]) or not owner.claim_effect_dispatch(incoming):return {"handled":false}
	owner.set_meta("i151_palette_group",g);g.dispatched[owner._pc]=true
	return {"handled":true,"actors":g.roles[owner._pc-27],"group":weakref(g)}

static func admit_palette(owner: Node2D,c: BattleAnimationContext,t: Dictionary,selected: Dictionary) -> void:
	if not selected.get("handled",false) or not selected.has("group") or not t.has("actor"):return
	var g: PaletteGroup=selected.group.get_ref()
	if g==null or not _valid(owner,c,g):return
	g.writers.append({"actor":t.actor,"track":t,"step":t.settings.duplicate(true),"held":{}})

static func note_palette_write(owner: Node2D,t: Dictionary,held: Dictionary) -> void:
	var g: PaletteGroup=(owner.get_meta("i151_palette_group") if owner.has_meta("i151_palette_group") else null)
	if g==null or g.revoked:return
	for writer: Dictionary in g.writers:
		if is_same(writer.track,t):held.i151_source_actor=writer.actor;writer.held=held;return

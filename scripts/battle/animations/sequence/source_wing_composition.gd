extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Complete finite Wing Attack/Steel Wing composition; no global blend authority.
const Same=preload("res://scripts/battle/animations/sequence/source_cutting_slice.gd")
const Jump=preload("res://scripts/battle/animations/sequence/source_jump_kick_composition.gd")
const Owned=preload("res://scripts/battle/animations/sequence/source_owned_composition.gd")
const SPECS := {"ruby:move/17":"Move_WING_ATTACK","ruby:move/211":"Move_STEEL_WING"}
const ART := ["texture","frame_rects","color","recolor","scale_factor","flip_h","flip_v"]
const POSE := ["transform","region_rect","flip_h","flip_v","visible"]
const BINDING := "source_wing_binding"
const REVOKED := "source_wing_revoked"
const COMMANDS := {"6169":["ruby:move/17",6,{"op":"effect","behavior":"source_legacy_impact_command","mode":"monbg","source_args":[3],"ticks":1,"source_line":6169,"source_command":"monbg ANIM_BATTLER_DEF_PARTNER","source_script":"Move_WING_ATTACK"},{"op":"source_label","source_pc":5175,"source_line":6169,"source_command":"monbg ANIM_BATTLER_DEF_PARTNER"}],"6170":["ruby:move/17",9,{"op":"effect","behavior":"source_legacy_impact_command","mode":"monbgprio_28","source_args":[1],"ticks":1,"source_line":6170,"source_command":"monbgprio_28 1","source_script":"Move_WING_ATTACK"},{"op":"source_label","source_pc":5176,"source_line":6170,"source_command":"monbgprio_28 1"}],"6171":["ruby:move/17",12,{"op":"effect","behavior":"source_legacy_impact_command","mode":"setalpha","source_args":[12,8],"ticks":1,"source_line":6171,"source_command":"setalpha 12, 8","source_script":"Move_WING_ATTACK"},{"op":"source_label","source_pc":5177,"source_line":6171,"source_command":"setalpha 12, 8"}],"6186":["ruby:move/17",57,{"op":"effect","behavior":"source_legacy_impact_command","mode":"clearmonbg","source_args":[3],"ticks":1,"source_line":6186,"source_command":"clearmonbg ANIM_BATTLER_DEF_PARTNER","source_script":"Move_WING_ATTACK"},{"op":"source_label","source_pc":5192,"source_line":6186,"source_command":"clearmonbg ANIM_BATTLER_DEF_PARTNER"}],"6187":["ruby:move/17",60,{"op":"effect","behavior":"source_legacy_impact_command","mode":"blendoff","source_args":[],"ticks":1,"source_line":6187,"source_command":"blendoff","source_script":"Move_WING_ATTACK"},{"op":"source_label","source_pc":5193,"source_line":6187,"source_command":"blendoff"}],"7206":["ruby:move/211",16,{"op":"effect","behavior":"source_legacy_impact_command","mode":"monbg","source_args":[3],"ticks":1,"source_line":7206,"source_command":"monbg ANIM_BATTLER_DEF_PARTNER","source_script":"Move_STEEL_WING"},{"op":"source_label","source_pc":6105,"source_line":7206,"source_command":"monbg ANIM_BATTLER_DEF_PARTNER"}],"7207":["ruby:move/211",19,{"op":"effect","behavior":"source_legacy_impact_command","mode":"monbgprio_28","source_args":[1],"ticks":1,"source_line":7207,"source_command":"monbgprio_28 1","source_script":"Move_STEEL_WING"},{"op":"source_label","source_pc":6106,"source_line":7207,"source_command":"monbgprio_28 1"}],"7208":["ruby:move/211",22,{"op":"effect","behavior":"source_legacy_impact_command","mode":"setalpha","source_args":[12,8],"ticks":1,"source_line":7208,"source_command":"setalpha 12, 8","source_script":"Move_STEEL_WING"},{"op":"source_label","source_pc":6107,"source_line":7208,"source_command":"setalpha 12, 8"}],"7223":["ruby:move/211",67,{"op":"effect","behavior":"source_legacy_impact_command","mode":"clearmonbg","source_args":[3],"ticks":1,"source_line":7223,"source_command":"clearmonbg ANIM_BATTLER_DEF_PARTNER","source_script":"Move_STEEL_WING"},{"op":"source_label","source_pc":6122,"source_line":7223,"source_command":"clearmonbg ANIM_BATTLER_DEF_PARTNER"}],"7224":["ruby:move/211",70,{"op":"effect","behavior":"source_legacy_impact_command","mode":"blendoff","source_args":[],"ticks":1,"source_line":7224,"source_command":"blendoff","source_script":"Move_STEEL_WING"},{"op":"source_label","source_pc":6123,"source_line":7224,"source_command":"blendoff"}]}
const SITES := {"6175":["ruby:move/17",24,{"op":"effect","behavior":"source_particle","mode":"linear","selector":"target","offset":[-25,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":46,"frame_size":[32,64],"frame_program":[{"op":"frame","tile":0,"ticks":1},{"op":"end"}],"frame_commands":[{"tile":0,"ticks":1}],"affine_program":[{"op":"frame","x":16,"y":256,"rotation":0,"ticks":0},{"op":"frame","x":10,"y":0,"rotation":0,"ticks":24},{"op":"end"}],"source_template":"gBattleAnimSpriteTemplate_83DA3B4","source_callback":"sub_80DA16C","source_animation_index":0,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_GUST","source_palette_tag":"ANIM_TAG_GUST","source_oam":"&gOamData_837DFDC","source_args":[-25,0,0,0,20],"from_selector":"attacker","to_selector":"target","end_offset":[0,0],"travel_ticks":20,"travel_delay":25,"texture":"res://graficos/batalla/animaciones/gust_pal_9_32x64_0_cycle.png","frame_rects":{"0":[0,0,32,64]},"palette_cycle_height":64,"palette_cycle_count":8,"source_line":6175},{"op":"source_label","source_pc":5181,"source_line":6175,"source_command":"createsprite gBattleAnimSpriteTemplate_83DA3B4, ANIM_BATTLER_ATTACKER, 2, -25, 0, 0, 0, 20","source_args":[-25,0,0,0,20]}],"6176":["ruby:move/17",27,{"op":"effect","behavior":"source_particle","mode":"linear","selector":"target","offset":[25,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":46,"frame_size":[32,64],"frame_program":[{"op":"frame","tile":0,"ticks":1},{"op":"end"}],"frame_commands":[{"tile":0,"ticks":1}],"affine_program":[{"op":"frame","x":16,"y":256,"rotation":0,"ticks":0},{"op":"frame","x":10,"y":0,"rotation":0,"ticks":24},{"op":"end"}],"source_template":"gBattleAnimSpriteTemplate_83DA3B4","source_callback":"sub_80DA16C","source_animation_index":0,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_GUST","source_palette_tag":"ANIM_TAG_GUST","source_oam":"&gOamData_837DFDC","source_args":[25,0,0,0,20],"from_selector":"attacker","to_selector":"target","end_offset":[0,0],"travel_ticks":20,"travel_delay":25,"texture":"res://graficos/batalla/animaciones/gust_pal_9_32x64_0_cycle.png","frame_rects":{"0":[0,0,32,64]},"palette_cycle_height":64,"palette_cycle_count":8,"source_line":6176},{"op":"source_label","source_pc":5182,"source_line":6176,"source_command":"createsprite gBattleAnimSpriteTemplate_83DA3B4, ANIM_BATTLER_ATTACKER, 2, 25, 0, 0, 0, 20","source_args":[25,0,0,0,20]}],"6180":["ruby:move/17",39,{"op":"effect","behavior":"sheet","ticks":8,"texture":"res://graficos/batalla/animaciones/impact.png","frame_size":[32,32],"frame_commands":[{"tile":0,"ticks":12}],"selector":"target","source_template":"gBasicHitSplatSpriteTemplate","source_callback":"sub_80E27A0","offset":[16,0],"source_affine_variant":1,"scale_factor":1.1851851851851851,"source_line":6180},{"op":"source_label","source_pc":5186,"source_line":6180,"source_command":"createsprite gBasicHitSplatSpriteTemplate, ANIM_BATTLER_ATTACKER, 2, 16, 0, 1, 1","source_args":[16,0,1,1]}],"6181":["ruby:move/17",42,{"op":"effect","behavior":"sheet","ticks":8,"texture":"res://graficos/batalla/animaciones/impact.png","frame_size":[32,32],"frame_commands":[{"tile":0,"ticks":12}],"selector":"target","source_template":"gBasicHitSplatSpriteTemplate","source_callback":"sub_80E27A0","offset":[-16,0],"source_affine_variant":1,"scale_factor":1.1851851851851851,"source_line":6181},{"op":"source_label","source_pc":5187,"source_line":6181,"source_command":"createsprite gBasicHitSplatSpriteTemplate, ANIM_BATTLER_ATTACKER, 2, -16, 0, 1, 1","source_args":[-16,0,1,1]}],"7212":["ruby:move/211",34,{"op":"effect","behavior":"source_particle","mode":"linear","selector":"target","offset":[-25,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":46,"frame_size":[32,64],"frame_program":[{"op":"frame","tile":0,"ticks":1},{"op":"end"}],"frame_commands":[{"tile":0,"ticks":1}],"affine_program":[{"op":"frame","x":16,"y":256,"rotation":0,"ticks":0},{"op":"frame","x":10,"y":0,"rotation":0,"ticks":24},{"op":"end"}],"source_template":"gBattleAnimSpriteTemplate_83DA3B4","source_callback":"sub_80DA16C","source_animation_index":0,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_GUST","source_palette_tag":"ANIM_TAG_GUST","source_oam":"&gOamData_837DFDC","source_args":[-25,0,0,0,20],"from_selector":"attacker","to_selector":"target","end_offset":[0,0],"travel_ticks":20,"travel_delay":25,"texture":"res://graficos/batalla/animaciones/gust_pal_9_32x64_0_cycle.png","frame_rects":{"0":[0,0,32,64]},"palette_cycle_height":64,"palette_cycle_count":8,"source_line":7212},{"op":"source_label","source_pc":6111,"source_line":7212,"source_command":"createsprite gBattleAnimSpriteTemplate_83DA3B4, ANIM_BATTLER_ATTACKER, 2, -25, 0, 0, 0, 20","source_args":[-25,0,0,0,20]}],"7213":["ruby:move/211",37,{"op":"effect","behavior":"source_particle","mode":"linear","selector":"target","offset":[25,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":46,"frame_size":[32,64],"frame_program":[{"op":"frame","tile":0,"ticks":1},{"op":"end"}],"frame_commands":[{"tile":0,"ticks":1}],"affine_program":[{"op":"frame","x":16,"y":256,"rotation":0,"ticks":0},{"op":"frame","x":10,"y":0,"rotation":0,"ticks":24},{"op":"end"}],"source_template":"gBattleAnimSpriteTemplate_83DA3B4","source_callback":"sub_80DA16C","source_animation_index":0,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_GUST","source_palette_tag":"ANIM_TAG_GUST","source_oam":"&gOamData_837DFDC","source_args":[25,0,0,0,20],"from_selector":"attacker","to_selector":"target","end_offset":[0,0],"travel_ticks":20,"travel_delay":25,"texture":"res://graficos/batalla/animaciones/gust_pal_9_32x64_0_cycle.png","frame_rects":{"0":[0,0,32,64]},"palette_cycle_height":64,"palette_cycle_count":8,"source_line":7213},{"op":"source_label","source_pc":6112,"source_line":7213,"source_command":"createsprite gBattleAnimSpriteTemplate_83DA3B4, ANIM_BATTLER_ATTACKER, 2, 25, 0, 0, 0, 20","source_args":[25,0,0,0,20]}],"7217":["ruby:move/211",49,{"op":"effect","behavior":"sheet","ticks":8,"texture":"res://graficos/batalla/animaciones/impact.png","frame_size":[32,32],"frame_commands":[{"tile":0,"ticks":12}],"selector":"target","source_template":"gBasicHitSplatSpriteTemplate","source_callback":"sub_80E27A0","offset":[16,0],"source_affine_variant":1,"scale_factor":1.1851851851851851,"source_line":7217},{"op":"source_label","source_pc":6116,"source_line":7217,"source_command":"createsprite gBasicHitSplatSpriteTemplate, ANIM_BATTLER_ATTACKER, 2, 16, 0, 1, 1","source_args":[16,0,1,1]}],"7218":["ruby:move/211",52,{"op":"effect","behavior":"sheet","ticks":8,"texture":"res://graficos/batalla/animaciones/impact.png","frame_size":[32,32],"frame_commands":[{"tile":0,"ticks":12}],"selector":"target","source_template":"gBasicHitSplatSpriteTemplate","source_callback":"sub_80E27A0","offset":[-16,0],"source_affine_variant":1,"scale_factor":1.1851851851851851,"source_line":7218},{"op":"source_label","source_pc":6117,"source_line":7218,"source_command":"createsprite gBasicHitSplatSpriteTemplate, ANIM_BATTLER_ATTACKER, 2, -16, 0, 1, 1","source_args":[-16,0,1,1]}]}

static func matches(owner: Node2D) -> bool:
	return owner is BattleAnimationSequenceRunner and owner.definition!=null and SPECS.has(owner.definition.key) and owner.definition.source_script==SPECS[owner.definition.key] and BattleAnimationSequenceRegistry.is_builtin_source_definition(owner.definition)

static func _number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value))

static func _shape(actual: Dictionary,expected: Dictionary,art: bool=false) -> bool:
	for key: String in expected:
		if art and key in ART:continue
		if not actual.has(key) or not Same._same(actual[key],expected[key]):return false
	for key: String in actual:
		if not expected.has(key) and (not art or key not in ART):return false
		if key in ["recolor","flip_h","flip_v"] and typeof(actual[key])!=TYPE_BOOL:return false
	if not art:return true
	if actual.has("scale_factor") and not _number(actual.scale_factor):return false
	if actual.has("color") and typeof(actual.color)!=TYPE_STRING:return false
	if actual.has("texture") and (typeof(actual.texture)!=TYPE_STRING or not ResourceLoader.exists(actual.texture)):return false
	if actual.has("frame_rects"):
		if not actual.frame_rects is Dictionary:return false
		var tiles: Dictionary={}
		for frame: Dictionary in expected.frame_commands:tiles[str(int(frame.tile))]=true
		if actual.frame_rects.size()!=tiles.size():return false
		for tile: String in tiles:
			if not actual.frame_rects.has(tile):return false
		for rect: Variant in actual.frame_rects.values():
			if not rect is Array or rect.size()!=4:return false
			for value: Variant in rect:
				if not _number(value) or float(value)!=floor(float(value)) or float(value)<0:return false
			if float(rect[2])<=0 or float(rect[3])<=0:return false
	return true

static func _plain(step: Dictionary,c: BattleAnimationContext,label: Dictionary) -> Dictionary:
	var result: Dictionary=step.duplicate(true)
	if result.has("source_command_priority"):
		var expected: Dictionary=BattleSourcePriority.command_metadata(label)
		if expected.is_empty() or not Same._same(result.source_command_priority,expected):return {}
		result.erase("source_command_priority")
	if result.has("source_contest"):
		if typeof(result.source_contest)!=TYPE_BOOL or result.source_contest!=c.contest:return {}
		result.erase("source_contest")
	return result

static func _at(owner: Node2D,c: BattleAnimationContext,incoming: Dictionary,spec: Array,art: bool=false,prepared: Dictionary={}) -> bool:
	var pc: int=int(spec[1])
	if art and (not incoming.has("source_command_priority") or not prepared.has("source_command_priority")):return false
	if not matches(owner) or owner.definition.key!=spec[0] or owner._pc!=pc or pc<1 or pc>=owner._steps.size() or pc>=owner.definition.steps.size():return false
	for steps: Array in [owner._steps,owner.definition.steps]:
		if not Same._same(steps[pc-1],spec[3]) or not _shape(steps[pc],spec[2],art):return false
	if not _shape(_plain(incoming,c,spec[3]),spec[2],art):return false
	if art and not _shape(_plain(prepared,c,spec[3]),spec[2],true):return false
	return true

static func _line(step: Dictionary) -> int:
	var value: Variant=step.get("source_line")
	return int(value) if _number(value) and float(value)==floor(float(value)) else -1

static func _snapshot(c: BattleAnimationContext,owner: Node2D) -> Dictionary:
	if not is_instance_valid(c.field) or not c.field.is_inside_tree():return {}
	for node: Node2D in [c.field,owner]:
		if not node.global_transform.is_finite() or is_zero_approx(node.global_transform.determinant()):return {}
	var result: Dictionary=Jump._snapshot(c)
	if result.is_empty() or not c.actors.has(c.attacker_id) or c.target_ids.is_empty() or not c.actors.has(c.target_ids[0]):return {}
	for actor: BattleAnimationActor in c.actors.values():
		if not actor.is_present() or actor.side!=(int(result.positions[actor.id])&1):return {}
	return result

static func _bound(binding: Dictionary,c: BattleAnimationContext,owner: Node2D) -> bool:
	if binding.is_empty() or not matches(owner) or owner.get_meta(REVOKED,false):return false
	var now: Dictionary=_snapshot(c,owner)
	return not now.is_empty() and Same._same(now.positions,binding.positions) and Jump._bound({"binding":binding},c)

static func _admitted(owner: Node2D,c: BattleAnimationContext) -> bool:
	return _bound(owner.get_meta(BINDING,{}),c,owner)

static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var spec: Array=COMMANDS.get(str(_line(step)),[])
	if spec.is_empty() or not _at(owner,c,step,spec):return []
	var mode: String=step.mode
	var binding: Dictionary=_snapshot(c,owner) if mode=="monbg" else owner.get_meta(BINDING,{})
	if binding.is_empty() or (mode!="monbg" and not _admitted(owner,c)) or not owner.claim_effect_dispatch(step):return []
	var trace: Array=owner.get_meta("source_legacy_impact_commands",[]);trace.append(int(step.source_line));owner.set_meta("source_legacy_impact_commands",trace)
	if mode=="monbgprio_28":
		owner.set_meta("source_wing_promoted",not c.contest and int(binding.positions[c.target_ids[0]]) in [0,3]);_order(owner,c);return []
	if mode in ["setalpha","blendoff"]:
		owner.set_meta("source_legacy_impact_alpha",[12,8] if mode=="setalpha" else [16,0])
		for item: Dictionary in owner.get_meta("source_legacy_impact_objects",[]):
			if mode=="blendoff":Owned.release_object(item)
			else:Owned.uniform(item,"eva",0.75);Owned.uniform(item,"evb",0.5)
		return []
	if mode=="clearmonbg":
		for t: Dictionary in owner.get_meta("source_legacy_impact_backgrounds",[]):
			t.cleared=true;t.ticks=int(t.age)+2
			for item: Dictionary in t.clones:
				# Final same-tick pose is real even when clear hides the copy now.
				if not item.retired and Owned.node(item):Owned.follow(item,owner)
				Owned.restore(item,c);Owned.write(item,"visible",false)
		return []
	owner.set_meta(BINDING,binding)
	var t: Dictionary={"kind":"source_legacy_impact_bg","domain":"maintenance","age":0,"ticks":4096,"owner":owner,"context":c,"clones":[],"cleared":false,"update":_advance}
	var target: int=int(binding.positions[c.target_ids[0]]);var seen: Dictionary={}
	for actor: BattleAnimationActor in c.actors.values():
		var position: int=int(binding.positions[actor.id])
		if position not in [target,target^2] or seen.has(actor.sprite) or not actor.sprite.is_visible_in_tree() or (c.contest and actor.id!=c.attacker_id):continue
		seen[actor.sprite]=true
		var copy: Sprite2D=BattleIdentityCopy.clone_sprite(actor,owner);owner.add_child(copy)
		var item: Dictionary={"actor":actor,"node":copy,"parent":owner,"binding":binding,"bg_plane":1 if c.contest or position in [1,2] else 2,"writes":{},"lost":{},"retired":false}
		t.clones.append(item);Owned.follow(item,owner);Owned.write(item,"visible",true);actor.apply_source_state("hidden",true)
	if t.clones.is_empty():return [] # Handled empty selection; no generic fall-through.
	t.cleanup=Owned.cleanup_bg.bind(t)
	var backgrounds: Array=owner.get_meta("source_legacy_impact_backgrounds",[]);backgrounds.append(t);owner.set_meta("source_legacy_impact_backgrounds",backgrounds)
	_order(owner,c);return [t]

static func attach(t: Dictionary,c: BattleAnimationContext,owner: Node2D,incoming: Dictionary) -> void:
	var spec: Array=SITES.get(str(_line(t.settings)),[])
	if spec.is_empty() or not _at(owner,c,incoming,spec,true,t.settings) or not _admitted(owner,c) or not t.node is Sprite2D:return
	if t.kind!=("source_particle" if t.settings.source_callback=="sub_80DA16C" else "sheet") or not owner.claim_effect_dispatch(incoming):return
	var wing: bool=t.kind=="source_particle";var actor: BattleAnimationActor=c.actors[c.attacker_id]
	var subpriority: int=maxi(3,BattleElectricContract.source_subpriority(actor,c)-2)
	t.source_oam_priority=2;t.source_oam_subpriority=subpriority
	var direction: int=BattleElectricContract.source_offset_direction(c,actor,c.actors[c.target_ids[0]])
	var offset: float=float(t.settings.offset[0])*direction
	var start: Vector2=BattleElectricContract.source_anchor(actor if wing else c.actors[c.target_ids[0]],c)+Vector2(offset,0)
	var end: Vector2=BattleElectricContract.source_anchor(c.actors[c.target_ids[0]],c)
	var item: Dictionary={"node":t.node,"parent":owner,"binding":owner.get_meta(BINDING),"actor":actor,"subpriority":subpriority,"writes":{},"lost":{},"foreign":{},"material":null,"previous":t.node.material,"shader":null,"uniforms":{},"revoked":{},"lost_material":false,"active":true,"track":t,"wing":wing,"start":start,"end":end,"scale":float(t.settings.get("scale_factor",1.0)) if wing else t.node.scale.x}
	if not wing and t.node.material==null and not bool(t.settings.get("recolor",false)):
		var material: ShaderMaterial=BattleIdentityCopy.blend_material(false);material.set_shader_parameter("eva",0.75);material.set_shader_parameter("evb",0.5)
		t.node.material=material;item.material=material;item.shader=material.shader
		for key: String in ["eva","evb","first_tint"]:item.uniforms[key]=material.get_shader_parameter(key)
	var objects: Array=owner.get_meta("source_legacy_impact_objects",[]);objects.append(item);owner.set_meta("source_legacy_impact_objects",objects)
	t.cleanup=_release.bind(item)
	_order(owner,c)

static func _release(item: Dictionary) -> void:
	item.erase("track") # Break track -> cleanup -> item -> track.
	Owned.release_object(item)

static func _advance(t: Dictionary,c: BattleAnimationContext) -> void:
	for item: Dictionary in t.clones:
		if not _bound(item.binding,c,t.owner) or not Owned.node(item):Owned.retire(item,c)
	if not t.cleared and not t.clones.any(func(item: Dictionary)->bool:return not item.retired):t.ticks=int(t.age)

static func _order(owner: Node2D,c: BattleAnimationContext) -> void:
	var band: int=BattleSourcePriority.effective_layer(c.field)-BattleSourcePriority.effective_layer(owner)+1
	for actor: BattleAnimationActor in c.actors.values():
		if actor.is_present():band=maxi(band,BattleSourcePriority.actor_layer(actor,owner))
	for t: Dictionary in owner.get_meta("source_legacy_impact_backgrounds",[]):
		for item: Dictionary in t.clones:
			if not item.retired and _bound(item.binding,c,owner):Owned.write(item,"z_index",band+(100 if int(item.bg_plane)==1 and owner.get_meta("source_wing_promoted",false) else 1 if int(item.bg_plane)==1 else 0))
	for item: Dictionary in owner.get_meta("source_legacy_impact_objects",[]):
		Owned.observe_material(item)
		if _bound(item.binding,c,owner):Owned.write(item,"z_index",band+2+60-int(item.subpriority))

static func begin_tick(owner: Node2D,c: BattleAnimationContext) -> void:
	if not owner.has_meta(BINDING):return
	if not _admitted(owner,c):owner.set_meta(REVOKED,true)
	for item: Dictionary in owner.get_meta("source_legacy_impact_objects",[]):
		Owned.observe_material(item)
		if not item.has("track") or not is_instance_valid(item.node):continue
		if not _bound(item.binding,c,owner) or not Owned.node(item):
			Owned.release_object(item)
			if item.node.get_parent()!=item.parent:item.track.erase("node")
			else:item.node.queue_free()
			item.track.ticks=int(item.track.age)+1
			continue
		# Observe BEFORE generic particle writes; returned foreign values never
		# reacquire authority. Remember the latest foreign value for final replay.
		for key: String in POSE:
			if item.writes.has(key) and item.node.get(key)!=item.writes[key]:item.lost[key]=true
			if item.lost.has(key):item.foreign[key]=item.node.get(key)

static func _pose_write(item: Dictionary,key: String,value: Variant) -> void:
	if item.lost.has(key):
		item.node.set(key,item.foreign[key]);return
	# Pre-generic observation already checked the previous expected write.
	# The generic update's current value is not an external competitor.
	item.writes.erase(key);Owned.write(item,key,value)

static func after_pose(owner: Node2D,c: BattleAnimationContext) -> void:
	for t: Dictionary in owner.get_meta("source_legacy_impact_backgrounds",[]):
		for item: Dictionary in t.clones:
			if item.retired:continue
			if not _bound(item.binding,c,owner) or not Owned.node(item):Owned.retire(item,c);continue
			Owned.follow(item,owner)
			if not t.cleared:Owned.write(item,"visible",true)
	for item: Dictionary in owner.get_meta("source_legacy_impact_objects",[]):
		Owned.observe_material(item)
		if not item.has("track") or not Owned.node(item) or not _bound(item.binding,c,owner):continue
		var t: Dictionary=item.track;var age: int=maxi(0,int(t.age));var point: Vector2=item.start
		var scale: Vector2=Vector2.ONE*float(item.scale)
		if item.wing:
			point=item.start.lerp(item.end,clampf(float(age-25)/20.0,0,1))
			scale.x*=256.0/(16+10*mini(age,24))
		var local: Transform2D=owner.global_transform.affine_inverse()*c.field.global_transform*Transform2D(0,scale,0,point)
		_pose_write(item,"transform",local)
		for key: String in ["region_rect","flip_h","flip_v","visible"]:_pose_write(item,key,item.node.get(key))
	_order(owner,c)

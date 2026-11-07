extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Finite canonical Charge commands; custom definitions retain literal semantics.
const Owned=preload("res://scripts/battle/animations/sequence/source_owned_composition.gd")
const Same=preload("res://scripts/battle/animations/sequence/source_cutting_slice.gd")
const COMMANDS := [[8,2796,3560,"monbg ANIM_BATTLER_ATTACKER","monbg",[0],[16,0]],[11,2797,3561,"setalpha 12, 8","alpha",[12,8],[12,8]],[89,2823,3587,"clearmonbg ANIM_BATTLER_ATTACKER","clear_monbg",[0],[16,0]],[92,2824,3588,"blendoff","blend_off",[],[16,0]]]

static func _canonical(owner: Node2D) -> bool:
	return owner is BattleAnimationSequenceRunner and owner.definition!=null and is_same(owner.definition,BattleAnimationSequenceRegistry._builtin_source_definitions.get("ruby:move/268"))

static func _at(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> bool:
	if not _canonical(owner) or not is_same(owner.context,c) or owner.definition.key!="ruby:move/268" or owner.definition.source_script!="Move_CHARGE" or owner.definition.coverage!="source-derived-unreviewed":return false
	for command: Array in COMMANDS:
		var pc: int=command[0]
		if owner._pc!=pc:continue
		if pc>=owner._steps.size() or pc>=owner.definition.steps.size():return false
		var effect: Dictionary={"op":"effect","behavior":"source_charge_command","mode":command[4],"source_args":command[5],"blend_pair":command[6],"ticks":1,"source_line":command[2]}
		var label: Dictionary={"op":"source_label","source_pc":command[1],"source_line":command[2],"source_command":command[3]}
		return Same._same(s,effect) and Same._same(owner._steps[pc],effect) and Same._same(owner.definition.steps[pc],effect) and Same._same(owner._steps[pc-1],label) and Same._same(owner.definition.steps[pc-1],label)
	return false

static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if s.behavior=="source_charge_ring":
		var binding: Dictionary=s.duplicate(true);binding.behavior="source_particle"
		var tracks: Array[Dictionary]=BattleEffectBehaviorRegistry.factories().source_particle.call(binding,c,owner)
		for t: Dictionary in tracks:BattleCounterSelected._blend_node(t.node,owner)
		return tracks
	# Original builtin rejection is handled empty, never a literal fallback.
	if _canonical(owner):
		if not _at(s,c,owner) or not owner.claim_effect_dispatch(s):return []
		match str(s.mode):
			"alpha","blend_off":return BattleCounterSelected.create(s,c,owner)
			"clear_monbg":
				for t: Dictionary in owner.get_meta("source_charge_monbg",[]):
					if t.get("i154_pair",false):_clear_pair(t)
				return []
		return _create_pair_bg(c,owner,0,"source_charge_monbg","source_charge_monbg")
	return _literal(s,c,owner)

static func _literal(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	match str(s.mode):
		"alpha","blend_off":return BattleCounterSelected.create(s,c,owner)
		"clear_monbg":
			for t: Dictionary in owner.get_meta("source_charge_monbg",[]):t.ticks=int(t.age)+2
			return []
	var actors: Array[BattleAnimationActor]=c.resolve("attacker")
	if actors.is_empty() or not actors[0].is_present():return []
	var actor: BattleAnimationActor=actors[0]
	var node: Sprite2D=BattleIdentityCopy.clone_sprite(actor,owner);owner.add_child(node)
	node.z_index=BattleSourcePriority.relative_layer(actor,1,c,owner);node.modulate=actor.sprite.modulate
	var t: Dictionary={"kind":"source_charge_monbg","domain":"maintenance","owner":owner,"age":0,"ticks":4096,"clones":[{"actor":actor,"node":node}],"update":BattleCounterSelected._bg_update}
	# Custom literal command compatibility: only the attacker.
	actor.apply_source_state("hidden",true);t.cleanup=BattleCounterSelected._bg_cleanup.bind(t)
	var backgrounds: Array=owner.get_meta("source_charge_monbg",[]);backgrounds.append(t);owner.set_meta("source_charge_monbg",backgrounds)
	return [t]


static func _position(c: BattleAnimationContext,id: int) -> int:
	var raw: Variant=c.source_positions[id] if c.source_positions.has(id) else BattleAnimationContext.source_position_for_slot(id)
	return int(raw) if typeof(raw) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(raw)) and float(raw)==floor(float(raw)) and int(raw) in [0,1,2,3] else -1

## Internal pair mechanics shared only by the two finite admitted adapters.
## Each copy binds its own original; another role disappearing is not revocation.
static func _create_pair_bg(c: BattleAnimationContext,owner: Node2D,operand: int,kind: String,key: String) -> Array[Dictionary]:
	var actors: Array[BattleAnimationActor]=Owned.source_bg_members(c,operand)
	var t: Dictionary={"kind":kind,"domain":"maintenance","owner":owner,"context":c,"age":0,"ticks":4096,"clones":[],"cleared":false,"clear_callbacks":0,"i154_pair":true,"update":_advance_pair}
	for actor: BattleAnimationActor in actors:
		var sprite: Sprite2D=actor.sprite
		var node: Sprite2D=BattleIdentityCopy.clone_sprite(actor,owner);owner.add_child(node)
		var position: int=_position(c,actor.id)
		var item: Dictionary={"actor":actor,"sprite":sprite,"sprite_parent":sprite.get_parent(),"texture":sprite.texture,"generation":actor._generation,"slot":actor.slot,"projection":actor.hidden_projection,"node":node,"parent":owner,"context":c,"definition":owner.definition,"definition_key":owner.definition.key,"script":owner.definition.source_script,"operand":operand,"primary":c.attacker_id if operand==0 else c.target_ids[0],"contest":c.contest,"position":position,"bg_plane":1 if c.contest or position in [1,2] else 2,"writes":{},"lost":{},"retired":false,"restored":false,"base_visible":sprite.visible}
		t.clones.append(item);Owned.follow(item,owner);Owned.write(item,"visible",true)
		actor.apply_source_state("hidden",true)
		if kind=="source_charge_monbg":Owned.write(item,"z_index",BattleSourcePriority.relative_layer(actor,1,c,owner))
	if t.clones.is_empty():return []
	t.cleanup=_cleanup_pair.bind(t)
	var backgrounds: Array=owner.get_meta(key,[]);backgrounds.append(t);owner.set_meta(key,backgrounds)
	return [t]

static func _visual(item: Dictionary) -> bool:
	var sprite: Sprite2D=item.sprite
	if not is_instance_valid(sprite) or not sprite.is_inside_tree() or sprite.get_parent()!=item.sprite_parent or sprite.texture!=item.texture:return false
	var generation: int=item.slot.animation_generation if is_instance_valid(item.slot) else int(sprite.get_meta("animation_generation",0))
	return generation==item.generation

static func _pair_bound(item: Dictionary,c: BattleAnimationContext) -> bool:
	var owner: Node2D=item.parent
	if not is_instance_valid(owner) or not is_same(owner.context,c) or not is_same(owner.definition,item.definition) or owner.definition.key!=item.definition_key or owner.definition.source_script!=item.script or not BattleAnimationSequenceRegistry.is_builtin_source_definition(owner.definition):return false
	var primary: int=c.attacker_id if int(item.operand)==0 else (c.target_ids[0] if not c.target_ids.is_empty() else -1)
	return primary==item.primary and c.contest==item.contest and c.actors.get(item.actor.id)==item.actor and item.actor.sprite==item.sprite and item.actor.is_present() and _visual(item) and _position(c,item.actor.id)==item.position and not item.sprite.visible

static func _restore_pair(item: Dictionary,c: BattleAnimationContext) -> void:
	if item.restored:return
	item.restored=true
	var actor: BattleAnimationActor=item.actor
	# The captured domain projection owns its handoff; view release stays inert.
	if item.projection!=null:item.projection.release_view();return
	var successor: bool=false
	for occupant: BattleAnimationActor in c.actors.values():
		if occupant!=actor and occupant.sprite==item.sprite:successor=true;break
	if actor._owned_hidden and not actor._expected_visible:
		if not successor and _visual(item) and not item.sprite.visible:item.sprite.visible=item.base_visible
		# Do not let the old wrapper's terminal release target a replacement sprite.
		actor._owned_hidden=false

static func _retire_pair(item: Dictionary,c: BattleAnimationContext) -> void:
	if item.retired:return
	_restore_pair(item,c)
	if Owned.node(item):item.node.queue_free()
	item.retired=true

static func _after_pair_pose(t: Dictionary) -> void:
	if t.cleared:return
	for item: Dictionary in t.clones:
		if item.retired:continue
		if not _pair_bound(item,t.context) or not Owned.node(item):_retire_pair(item,t.context);continue
		Owned.follow(item,t.owner);Owned.write(item,"visible",true)
		if t.kind=="source_charge_monbg":Owned.write(item,"z_index",BattleSourcePriority.relative_layer(item.actor,1,t.context,t.owner))

static func _clear_pair(t: Dictionary) -> void:
	if t.cleared:return
	_after_pair_pose(t)
	for item: Dictionary in t.clones:
		_restore_pair(item,t.context)
		if Owned.node(item):Owned.write(item,"visible",false)
	t.cleared=true;t.clear_callbacks=0;t.ticks=int(t.age)+2

static func _advance_pair(t: Dictionary,c: BattleAnimationContext) -> void:
	if t.cleared:
		t.clear_callbacks+=1
		if int(t.clear_callbacks)>=2:
			for item: Dictionary in t.clones:_retire_pair(item,c)
			t.ticks=int(t.age)
		return
	for item: Dictionary in t.clones:
		if not item.retired and (not _pair_bound(item,c) or not Owned.node(item)):_retire_pair(item,c)
	if not t.clones.any(func(item: Dictionary)->bool:return not item.retired):t.ticks=int(t.age)

static func _cleanup_pair(t: Dictionary) -> void:
	t.erase("cleanup")
	for item: Dictionary in t.clones:_retire_pair(item,t.context)
	t.clones.clear()

static func after_pose(owner: Node2D,c: BattleAnimationContext) -> void:
	if owner.context!=c:return
	for t: Dictionary in owner.get_meta("source_charge_monbg",[]):
		if t.get("i154_pair",false):_after_pair_pose(t)

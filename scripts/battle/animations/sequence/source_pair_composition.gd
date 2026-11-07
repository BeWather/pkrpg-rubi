extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Bounded ordinary monBG pair machinery. Private ghost callbacks stay unchanged.
const Owned = preload("res://scripts/battle/animations/sequence/source_owned_composition.gd")
const AB=preload("res://scripts/battle/animations/sequence/source_local_ab.gdshader")
const CONTRACTS := {
	250:{"key":"ruby:move/250","script":"Move_WHIRLPOOL","behavior":"source_whirlpool_command","state":"source_whirlpool_monbg","open":3,"clear":3,"clone":"","bg_above":false},
	61:{"key":"ruby:move/61","script":"Move_BUBBLE_BEAM","behavior":"source_bubble_command","state":"source_bubble_beam_monbg","open":1,"clear":1,"clone":"","bg_above":false},
	145:{"key":"ruby:move/145","script":"Move_BUBBLE","behavior":"source_bubble_command","state":"source_bubble_monbg","open":1,"clear":1,"clone":"","bg_above":false},
	53:{"key":"ruby:move/53","script":"Move_FLAMETHROWER","behavior":"source_flamethrower_command","state":"source_flamethrower_monbg","clear":3,"clone":"","bg_above":false},
	180:{"key":"ruby:move/180","script":"Move_SPITE","behavior":"source_spite_command","state":"source_spite_monbg","clear":1,"clone":"spite","bg_above":true},
	171:{"key":"ruby:move/171","script":"Move_NIGHTMARE","behavior":"source_nightmare_command","state":"source_nightmare_monbg","clear":3,"clone":"nightmare","bg_above":false},
}

static func _source_args_match(args: Variant, expected: int) -> bool:
	# JSON numbers are floats; Array equality is type-sensitive in Godot.
	# Do not int-cast before checking: fractional/malformed operands must fail.
	if not args is Array or args.size()!=1:return false
	return typeof(args[0]) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(args[0])) and args[0]==expected

static func _source_values_match(args: Variant, expected: Array) -> bool:
	if not args is Array or args.size()!=expected.size():return false
	for index: int in expected.size():
		if not _source_args_match([args[index]],expected[index]):return false
	return true

static func _blended_move(owner: Node2D) -> int:
	if not owner is BattleAnimationSequenceRunner or owner.definition==null:return 0
	for id: int in [61,145,250]:
		if owner.definition.key==CONTRACTS[id].key and owner.definition.source_script==CONTRACTS[id].script:return id
	return 0

static func _blended_dispatch(step: Dictionary,owner: Node2D) -> bool:
	if not owner is BattleAnimationSequenceRunner or owner.definition==null:return false
	if _blended_move(owner)==0 or not BattleAnimationSequenceRegistry.is_builtin_source_definition(owner.definition):return false
	var pc: int=int(owner._pc)
	return owner.state=="running" and pc>=0 and pc<owner._steps.size() and int(owner._effect_dispatch_pc)==pc and is_same(owner._effect_dispatch_step,step) and is_same(owner._steps[pc],step)

static func create_bubble(step: Dictionary,context: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	return create(step,context,owner,_blended_move(owner))

static func create_whirlpool(step: Dictionary,context: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	return create(step,context,owner,250)

static func attach_bubble(track: Dictionary,incoming: Dictionary,context: BattleAnimationContext,owner: Node2D) -> void:
	if not _blended_dispatch(incoming,owner) or context!=owner.context or track.kind!="source_particle":return
	var metadata: Variant=incoming.get("source_blended_composition" if _blended_move(owner)==250 else "source_bubble_composition")
	if not metadata is Dictionary or metadata.get("source_script","")!=CONTRACTS[_blended_move(owner)].script or metadata.get("oam","")!="gOamData_837E0AC":return
	if not _source_values_match([metadata.get("obj_mode"),metadata.get("priority")],[1,2]):return
	var callbacks: Dictionary={"gBattleAnimSpriteTemplate_83DACB8":"sub_80DCFE4"} if _blended_move(owner)==250 else {"gBattleAnimSpriteTemplate_83D9178":"sub_80D31C8","gWaterBubbleSpriteTemplate":"AnimBubbleEffect"}
	if callbacks.get(str(incoming.get("source_template","")),"")!=str(incoming.get("source_callback","")) or str(incoming.get("source_callback",""))=="":return
	var state: Dictionary=owner.get_meta(CONTRACTS[_blended_move(owner)].state,{})
	if state.is_empty() or state.clearing or state.alpha_pair!=[12,8]:return
	var receipt: Dictionary=Owned.item(track.node,owner)
	Owned.attach_material(receipt,AB)
	Owned.uniform(receipt,"eva",0.75);Owned.uniform(receipt,"evb",0.5)
	state.bubbles.append(receipt) # Include newborn before factory returns/runner enrollment.
	sync(owner)

static func create_spite(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Array[Dictionary]:
	return create(step,context,owner,180)

static func create_nightmare(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Array[Dictionary]:
	return create(step,context,owner,171)

static func create_flamethrower(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Array[Dictionary]:
	return create(step,context,owner,53)

static func create(step: Dictionary, context: BattleAnimationContext, owner: Node2D, move_id: int) -> Array[Dictionary]:
	if not CONTRACTS.has(move_id):return []
	if move_id in [61,145,250] and (not _blended_dispatch(step,owner) or context!=owner.context):return []
	var contract: Dictionary=CONTRACTS[move_id]
	if owner.definition.key!=contract.key or owner.definition.source_script!=contract.script:return []
	if step.get("behavior","")!=contract.behavior or step.get("source_script","")!=contract.script:return []
	var state: String=contract.state
	if (move_id==53 and step.get("mode","") in ["monbgprio_28","setalpha","blendoff"]) or (move_id in [61,145,250] and step.get("mode","") in (["monbgprio_28","setalpha"] if move_id==250 else ["monbgprio_28","setalpha","blendoff"] if move_id==61 else ["setalpha","blendoff"])):
		var command: String=step.mode
		var expected: Array=[1] if command=="monbgprio_28" else [12,8] if command=="setalpha" else []
		var literal_command: String=command+(" 1" if command=="monbgprio_28" else " 12, 8" if command=="setalpha" else "")
		if step.get("source_command","")!=literal_command or not _source_values_match(step.get("source_args"),expected):return []
		if move_id in [61,145,250] and not owner.claim_effect_dispatch(step):return []
		var current: Dictionary=owner.get_meta(state,{})
		if current.is_empty() or current.clearing and command!="blendoff":return []
		if command=="monbgprio_28":
			current.bg1_priority=1 if not context.contest and not context.target_ids.is_empty() and context.source_position(context.target_ids[0]) in [0,3] else 2
			if move_id in [61,250]:sync(owner) # Source priority opcode publishes immediately.
		else:
			# setalpha selects only second targets. Normal OBJ0 flames and
			# ordinary monBG are NOT first targets (battle_anim.c:2258-2265).
			current.alpha_pair=[12,8] if command=="setalpha" else []
			if move_id in [61,145,250] and command=="blendoff":
				for receipt: Dictionary in current.bubbles:Owned.release_material(receipt)
		return []
	if step.get("mode","") not in ["monbg","clearmonbg"]:return []
	var opening: bool=step.get("mode","")=="monbg"
	var opening_operand: int=int(contract.get("open",3))
	var literal: String=("monbg ANIM_BATTLER_TARGET" if opening_operand==1 else "monbg ANIM_BATTLER_DEF_PARTNER") if opening else ("clearmonbg ANIM_BATTLER_TARGET" if contract.clear==1 else "clearmonbg ANIM_BATTLER_DEF_PARTNER")
	if step.get("source_command","")!=literal or not _source_args_match(step.get("source_args"),opening_operand if opening else int(contract.clear)):return []
	if move_id in [61,145,250] and not owner.claim_effect_dispatch(step):return []
	if not opening:
		var pending: Dictionary=owner.get_meta(state,{})
		if pending.is_empty() or pending.clearing:return []
		# Ruby reveals both originals synchronously, then drains both BG tasks
		# on the clear worker's second invocation (battle_anim.c:2089-2148).
		for item: Dictionary in pending.clones:Owned.restore(item,context)
		pending.clearing=true;pending.domain="visual";pending.ticks=int(pending.age)+2
		return []
	if owner.has_meta(state):return []
	if move_id in [53,61,145,250] and not _flame_planes_available(context,owner):return []
	var members: Array[BattleAnimationActor]=Owned.source_bg_members(context,step.source_args[0])
	var track: Dictionary={"kind":state,"state":state,"contract":contract,"domain":"maintenance","age":0,"ticks":2147483647,"owner":owner,"context":context,"clones":[],"clearing":false,"update":_update}
	if move_id==53:track.bg1_priority=2;track.alpha_pair=[]
	if move_id in [61,145,250]:track.alpha_pair=[];track.bubbles=[];track.bg1_priority=2
	for actor: BattleAnimationActor in members:
		var node: Sprite2D=BattleIdentityCopy.clone_sprite(actor,owner);owner.add_child(node)
		var item: Dictionary=Owned.item(node,owner)
		item.actor=actor;item.binding={"sprites":{actor.id:actor.sprite}};item.retired=false
		item.bg_plane=1 if context.contest or context.source_position(actor.id) in [1,2] else 2
		# Both monBG planes use priority2 (battle_anim.c:1937/1971).
		# Per-move ghost ordering is applied after actor publication below.
		Owned.write(item,"z_index",BattleSourcePriority.relative_layer(actor,0,context,owner))
		track.clones.append(item);actor.apply_source_state("hidden",true)
	if track.clones.is_empty():return []
	if move_id in [53,61,145,250]:
		# The source BG1/BG2 tie can share the native floor's integer Z.
		# Order only our own siblings; never reorder battlers or terrain.
		for item: Dictionary in track.clones:
			if item.bg_plane==1:owner.move_child(item.node,-1)
	track.cleanup=_cleanup.bind(track);owner.set_meta(state,track)
	sync(owner)
	return [track]

static func _update(_track: Dictionary, _context: BattleAnimationContext) -> void:
	pass # Publication follows this tick's actor palette/pose, not the previous frame.

static func sync(owner: Node2D, newborn_flame: CanvasItem=null) -> void:
	# Single post-actor hook; only the admitted move's one pair is published.
	var contract: Dictionary={}
	for candidate: Dictionary in CONTRACTS.values():
		if owner.definition.key==candidate.key:contract=candidate;break
	if contract.is_empty():return
	var track: Dictionary=owner.get_meta(contract.state,{})
	if track.is_empty():return
	if contract.key in ["ruby:move/61","ruby:move/145","ruby:move/250"]:
		for item: Dictionary in track.clones:
			if not item.actor.is_present():Owned.retire(item,track.context)
			elif not item.retired:Owned.follow(item,owner)
		_sync_blended_planes(track,owner)
		return
	for item: Dictionary in track.clones:
		if not item.actor.is_present():Owned.retire(item,track.context);continue
		if item.retired:continue
		Owned.follow(item,owner)
		if contract.key=="ruby:move/53":
			_sync_flame_plane(item,track,owner,newborn_flame)
			continue
		for ghost: Dictionary in owner._tracks:
			if ghost.kind!="source_ghost_clone" or ghost.settings.clone_mode!=contract.clone or ghost.bound_actor!=item.actor:continue
			if not is_instance_valid(ghost.node):continue
			var ghost_layer: int=BattleSourcePriority.effective_layer(ghost.node)-BattleSourcePriority.effective_layer(owner)
			# Spite forces OBJ3, behind BG2. Nightmare retains battler OBJ2;
			# equal-priority OBJ wins over BG. Do not alter either callback's z.
			var layer: int=maxi(int(item.writes.z_index),ghost_layer+1) if contract.bg_above else mini(int(item.writes.z_index),ghost_layer-1)
			Owned.write(item,"z_index",clampi(layer,-4096,4096))

static func _sync_blended_planes(track: Dictionary,owner: Node2D) -> void:
	# OBJ2 wins ties over BG2; BG1 wins BG2 ties. Use admitted receipts, not
	# a Flame-only filter or owner._tracks (newborns are not enrolled there yet).
	var layers: Array[int]=[]
	for actor: BattleAnimationActor in track.context.actors.values():
		if actor.is_present():layers.append(BattleSourcePriority.effective_layer(actor.sprite))
	for receipt: Dictionary in track.bubbles:
		if Owned.node(receipt):layers.append(BattleSourcePriority.effective_layer(receipt.node))
	if layers.is_empty():return
	var floor_layer: int=_flame_floor(track.context)
	var promoted: bool=int(track.get("bg1_priority",2))==1
	var raised: int=layers.max()+1
	var relative_raised: int=raised-BattleSourcePriority.effective_layer(owner)
	if layers.min()<=floor_layer or promoted and (raised>4096 or relative_raised>4096 or relative_raised< -4096):
		_cleanup(track);track.ticks=int(track.age) # Impossible native topology: restore, never fade.
		return
	for item: Dictionary in track.clones:
		if item.retired:continue
		var layer: int=raised if promoted and item.bg_plane==1 else maxi(floor_layer,layers.min()-(1 if item.bg_plane==1 else 2))
		Owned.write(item,"z_index",clampi(layer-BattleSourcePriority.effective_layer(owner),-4096,4096))

static func _sync_flame_plane(item: Dictionary, track: Dictionary, owner: Node2D, newborn_flame: CanvasItem=null) -> void:
	# Scope is this pair, ordinary battlers, and this execution's normal OBJ2
	# flames. Equal-priority OBJ wins; equal-priority BG1 wins over BG2.
	var layers: Array[int]=[]
	for actor: BattleAnimationActor in track.context.actors.values():
		if actor.is_present():layers.append(BattleSourcePriority.effective_layer(actor.sprite))
	for particle: Dictionary in owner._tracks:
		if particle.kind=="source_particle" and particle.settings.get("mode","")=="source_beam" and is_instance_valid(particle.node):
			layers.append(BattleSourcePriority.effective_layer(particle.node))
	# Factories initialize before the runner appends their returned tracks. Include
	# that fully constructed OBJ now, so raised BG1 is correct on its birth frame.
	if is_instance_valid(newborn_flame) and newborn_flame.get_parent()==owner:
		layers.append(BattleSourcePriority.effective_layer(newborn_flame))
	if layers.is_empty():return
	var absolute: int=layers.max()+1 if item.bg_plane==1 and track.bg1_priority==1 else maxi(_flame_floor(track.context),layers.min()-(1 if item.bg_plane==1 else 2))
	Owned.write(item,"z_index",clampi(absolute-BattleSourcePriority.effective_layer(owner),-4096,4096))

static func _flame_floor(context: BattleAnimationContext) -> int:
	var floor_layer: int=BattleSourcePriority.effective_layer(context.field)
	for ground: Node in context.field.get_children():
		if ground is Sprite2D and ground.texture!=null:
			var battler: bool=false
			for actor: BattleAnimationActor in context.actors.values():
				if actor.sprite==ground:battler=true
			if not battler:floor_layer=maxi(floor_layer,BattleSourcePriority.effective_layer(ground))
	return floor_layer

static func _flame_planes_available(context: BattleAnimationContext, owner: Node2D) -> bool:
	var floor_layer: int=_flame_floor(context)
	var owner_layer: int=BattleSourcePriority.effective_layer(owner)
	if floor_layer-owner_layer< -4096 or floor_layer-owner_layer>4096:return false
	for actor: BattleAnimationActor in context.actors.values():
		if actor.is_present() and BattleSourcePriority.effective_layer(actor.sprite)<=floor_layer:return false
	for ground: Node in context.field.get_children():
		if ground is Sprite2D and ground.texture!=null and BattleSourcePriority.effective_layer(ground)==floor_layer:
			if not BattleSourcePriority.tree_before(ground,owner):return false
	return true

static func _cleanup(track: Dictionary) -> void:
	track.erase("cleanup")
	for receipt: Dictionary in track.get("bubbles",[]):Owned.release_material(receipt)
	for item: Dictionary in track.clones:Owned.retire(item,track.context)
	track.clones.clear()
	if is_instance_valid(track.owner) and is_same(track.owner.get_meta(track.state,{}),track):track.owner.remove_meta(track.state)

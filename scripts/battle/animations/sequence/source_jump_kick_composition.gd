extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

const Owned=preload("res://scripts/battle/animations/sequence/source_owned_composition.gd")
## Finite ordinary wrapper composition. I143 alone claims each foot dispatch.
const Same=preload("res://scripts/battle/animations/sequence/source_cutting_slice.gd")
const SPECS := {"ruby:move/26":["Move_JUMP_KICK",4,8,[6478,6479,6489,6490],[0,1,12,13],6482,6485,1],"ruby:move/136":["Move_HI_JUMP_KICK",7,11,[6496,6497,6515,6516],[0,1,20,21],6503,6506,2]}
const FOLLOW := ["texture","centered","offset","hframes","vframes","frame","region_enabled","region_rect","flip_h","flip_v","modulate","self_modulate","material"]
const ART := ["texture","frame_rects","color","recolor","scale_factor","flip_h","flip_v"]

static func matches(owner: Node2D) -> bool:
	return owner is BattleAnimationSequenceRunner and owner.definition!=null and SPECS.has(owner.definition.key) and BattleAnimationSequenceRegistry.is_builtin_source_definition(owner.definition) and owner.definition.source_script==SPECS[owner.definition.key][0]

static func _at(owner: Node2D,step: Dictionary,expected: Dictionary,pc: int) -> bool:
	return matches(owner) and owner._pc==pc and pc<owner._steps.size() and pc<owner.definition.steps.size() and Same._same(step,expected) and Same._same(owner._steps[pc],expected) and Same._same(owner.definition.steps[pc],expected)

static func _snapshot(c: BattleAnimationContext) -> Dictionary:
	var result: Dictionary={"context":c,"attacker":c.attacker_id,"targets":c.target_ids.duplicate(),"contest":c.contest,"actors":{},"sprites":{},"positions":{}}
	var occupied: Dictionary={};var visuals: Dictionary={}
	for actor: BattleAnimationActor in c.actors.values():
		var value: Variant=c.source_positions[actor.id] if c.source_positions.has(actor.id) else c.source_position(actor.id)
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value)!=floor(float(value)) or int(value) not in [0,1,2,3] or occupied.has(int(value)) or visuals.has(actor.sprite):return {}
		occupied[int(value)]=true;visuals[actor.sprite]=true
		result.actors[actor.id]=actor;result.sprites[actor.id]=actor.sprite;result.positions[actor.id]=int(value)
	return result

static func _bound(item: Dictionary,c: BattleAnimationContext) -> bool:
	var binding: Dictionary=item.binding
	if binding.context!=c or binding.attacker!=c.attacker_id or not Same._same(c.target_ids,binding.targets) or binding.contest!=c.contest:return false
	for id: int in binding.actors:
		var actor: BattleAnimationActor=binding.actors[id]
		if c.actors.get(id)!=actor or actor.sprite!=binding.sprites[id] or not actor.is_present() or c.source_position(id)!=binding.positions[id]:return false
	return true

static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if not matches(owner):return []
	var spec: Array=SPECS[owner.definition.key]
	var modes: Array=["monbg","setalpha","clearmonbg","blendoff"]
	var literals: Array=["monbg ANIM_BATTLER_DEF_PARTNER","setalpha 12, 8","clearmonbg ANIM_BATTLER_DEF_PARTNER","blendoff"]
	var args: Array=[[3],[12,8],[3],[]]
	var index: int=-1
	for n: int in 4:
		if Same._same(step.get("source_line"),spec[3][n]):index=n;break
	if index<0:return []
	var expected: Dictionary={"op":"effect","behavior":"source_legacy_impact_command","mode":modes[index],"source_args":args[index],"ticks":1,"source_line":spec[3][index],"source_command":literals[index],"source_script":spec[0]}
	if not _at(owner,step,expected,spec[4][index]) or not owner.claim_effect_dispatch(step):return []
	var trace: Array=owner.get_meta("source_legacy_impact_commands",[]);trace.append(int(expected.source_line));owner.set_meta("source_legacy_impact_commands",trace)
	if index in [1,3]:
		owner.set_meta("source_legacy_impact_alpha",[12,8] if index==1 else [16,0])
		for item: Dictionary in owner.get_meta("source_legacy_impact_objects",[]):
			if index==3:_release_object(item)
			else:
				_uniform(item,"eva",0.75);_uniform(item,"evb",0.5)
		return []
	if index==2:
		for track: Dictionary in owner.get_meta("source_legacy_impact_backgrounds",[]):
			track.cleared=true;track.ticks=int(track.age)+2
			for item: Dictionary in track.clones:
				_restore(item,c)
				if _node(item):_write(item,"visible",false)
		return []
	var targets:=c.resolve("target")
	if targets.is_empty():return []
	var binding:=_snapshot(c)
	if binding.is_empty():return []
	var position: int=c.source_position(targets[0].id)
	var track: Dictionary={"kind":"source_legacy_impact_bg","domain":"maintenance","age":0,"ticks":4096,"owner":owner,"context":c,"clones":[],"cleared":false,"update":_advance}
	for actor: BattleAnimationActor in c.actors.values():
		if actor!=targets[0] and c.source_position(actor.id)!=(position^2):continue
		if not actor.is_present() or not actor.sprite.is_visible_in_tree() or (c.contest and actor.id!=c.attacker_id):continue
		var node:=BattleIdentityCopy.clone_sprite(actor,owner);owner.add_child(node)
		var item: Dictionary={"actor":actor,"node":node,"parent":owner,"binding":binding,"bg_plane":1 if c.contest or c.source_position(actor.id) in [1,2] else 2,"writes":{},"lost":{},"retired":false}
		track.clones.append(item);_follow(item,owner);_write(item,"visible",true)
		actor.apply_source_state("hidden",true)
	if track.clones.is_empty():return []
	track.cleanup=_cleanup_bg.bind(track)
	var backgrounds: Array=owner.get_meta("source_legacy_impact_backgrounds",[]);backgrounds.append(track);owner.set_meta("source_legacy_impact_backgrounds",backgrounds)
	_order(owner,c)
	return [track]

static func _impact_shape(step: Dictionary,spec: Array) -> bool:
	var expected: Dictionary={"op":"effect","behavior":"sheet","ticks":8,"texture":"res://graficos/batalla/animaciones/impact.png","frame_size":[32,32],"frame_commands":[{"tile":0,"ticks":12}],"selector":"target","source_template":"gBasicHitSplatSpriteTemplate","source_callback":"sub_80E27A0","offset":[0,0],"source_affine_variant":1,"scale_factor":256.0/216.0,"source_line":spec[6]}
	for key: String in expected:
		if key not in ART and (not step.has(key) or not Same._same(step[key],expected[key])):return false
	for key: String in step:
		if not expected.has(key) and key not in ART:return false
		if key in ["recolor","flip_h","flip_v"] and typeof(step[key])!=TYPE_BOOL:return false
	if step.has("scale_factor") and (typeof(step.scale_factor) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(step.scale_factor))):return false
	return true

static func attach_impact(t: Dictionary,c: BattleAnimationContext,owner: Node2D,incoming: Dictionary) -> void:
	if not matches(owner):return
	var spec: Array=SPECS[owner.definition.key];var pc: int=spec[2]
	if owner._pc!=pc or pc>=owner.definition.steps.size() or pc>=owner._steps.size() or t.kind!="sheet" or not t.node is Sprite2D:return
	for shape: Dictionary in [t.settings,owner._steps[pc],owner.definition.steps[pc]]:
		if not _impact_shape(shape,spec):return
	if not owner.claim_effect_dispatch(incoming):return
	_register(t,c,owner,1,int(spec[7]))

# Internal worker: only I143's same successful claiming initialization calls it.
# Never a second admission endpoint, reusable flag, or another factory call.
static func _register_foot(t: Dictionary,c: BattleAnimationContext,owner: Node2D) -> void:
	if not matches(owner) or owner._pc!=SPECS[owner.definition.key][1]:return
	_register(t,c,owner,0,2)

static func _register(t: Dictionary,c: BattleAnimationContext,owner: Node2D,mode: int,offset: int) -> void:
	var attackers:=c.resolve("attacker")
	var binding:=_snapshot(c)
	if attackers.is_empty() or binding.is_empty():return
	var node: Sprite2D=t.node
	var subpriority: int=maxi(3,BattleElectricContract.source_subpriority(attackers[0],c)-offset)
	t.source_oam_priority=2;t.source_oam_subpriority=subpriority
	var item: Dictionary={"node":node,"parent":owner,"binding":binding,"actor":attackers[0],"subpriority":subpriority,"writes":{},"lost":{},"material":null,"previous":node.material,"shader":null,"uniforms":{},"revoked":{},"lost_material":false,"active":true}
	if mode==1 and node.material==null and not bool(t.settings.get("recolor",false)):
		var material:=BattleIdentityCopy.blend_material(false)
		material.set_shader_parameter("eva",0.75);material.set_shader_parameter("evb",0.5)
		node.material=material;item.material=material;item.shader=material.shader
		for key: String in ["eva","evb","first_tint"]:item.uniforms[key]=material.get_shader_parameter(key)
	var objects: Array=owner.get_meta("source_legacy_impact_objects",[]);objects.append(item);owner.set_meta("source_legacy_impact_objects",objects)
	if mode==1:t.cleanup=_release_object.bind(item)
	_order(owner,c)

static func _node(item: Dictionary) -> bool:
	return Owned.node(item)

static func _write(item: Dictionary,key: String,value: Variant) -> void:
	Owned.write(item,key,value)

static func _follow(item: Dictionary,owner: Node2D) -> void:
	Owned.follow(item,owner)

static func _observe_material(item: Dictionary) -> bool:
	return Owned.observe_material(item)

static func _uniform(item: Dictionary,key: String,value: Variant) -> void:
	Owned.uniform(item,key,value)

static func _release_object(item: Dictionary) -> void:
	Owned.release_object(item)

static func _restore(item: Dictionary,c: BattleAnimationContext) -> void:
	Owned.restore(item,c)

static func _retire(item: Dictionary,c: BattleAnimationContext) -> void:
	Owned.retire(item,c)

static func _advance(t: Dictionary,c: BattleAnimationContext) -> void:
	for item: Dictionary in t.clones:
		if not _bound(item,c) or not _node(item):_retire(item,c)
	if not t.cleared and not t.clones.any(func(item: Dictionary)->bool:return not item.retired):t.ticks=int(t.age)

static func _cleanup_bg(t: Dictionary) -> void:
	Owned.cleanup_bg(t)

static func _order(owner: Node2D,c: BattleAnimationContext) -> void:
	var band: int=BattleSourcePriority.effective_layer(c.field)-BattleSourcePriority.effective_layer(owner)+1
	for actor: BattleAnimationActor in c.actors.values():
		if actor.is_present():band=maxi(band,BattleSourcePriority.actor_layer(actor,owner))
	for t: Dictionary in owner.get_meta("source_legacy_impact_backgrounds",[]):
		for item: Dictionary in t.clones:
			if not item.retired and _bound(item,c):_write(item,"z_index",band+(1 if int(item.bg_plane)==1 else 0))
	for item: Dictionary in owner.get_meta("source_legacy_impact_objects",[]):
		_observe_material(item)
		if _bound(item,c):_write(item,"z_index",band+2+60-int(item.subpriority))

static func after_pose(owner: Node2D,c: BattleAnimationContext) -> void:
	# Ownership observation remains active after canonical Resource revocation.
	for t: Dictionary in owner.get_meta("source_legacy_impact_backgrounds",[]):
		for item: Dictionary in t.clones:
			if item.retired:continue
			if not _bound(item,c) or not _node(item):_retire(item,c);continue
			_follow(item,owner) # The clearing tick still has this tick's final pose.
			if not t.cleared:_write(item,"visible",true)
	_order(owner,c)

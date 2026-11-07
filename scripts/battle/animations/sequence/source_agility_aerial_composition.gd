extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Finite Agility/Aerial Ace composition; never a global afterimage override.
const Same=preload("res://scripts/battle/animations/sequence/source_cutting_slice.gd")
const SPECS := {"ruby:move/97":["Move_AGILITY",2707,10,[2704,2705,2719,2720],2],"ruby:move/332":["Move_AERIAL_ACE",4346,3,[4343,4344,4354,4355],1]}
const Composed=preload("res://scripts/battle/animations/sequence/source_agility_aerial_palette_ab.gdshader")
const SharedPalette=preload("res://scripts/battle/animations/sequence/palette_blend.gdshader")
const PALETTE_DEFAULTS := {"blend_color":Color.WHITE,"grayscale":false,"invert":false,"blend_amount":0.0,"wave_amplitude":0.0,"wave_phase":0.0,"wave_height":64.0,"wave_start":-32.0,"wave_end":32.0,"wave_scale_x":1.0,"wave_scale_y":1.0}
const PALETTE_STEP := {"op":"effect","behavior":"source_palette","selector":"attacker","ticks":9,"palette_states":[{"ticks":4,"color":"000000","amount":10},{"ticks":4,"color":"000000","amount":0},{"ticks":1,"color":"000000","amount":0}],"source_line":4351}
const PALETTE_ROLES := ["background","attacker","target","attacker_partner","target_partner"]
class PaletteGroup extends RefCounted:
	var owner: WeakRef
	var context: BattleAnimationContext
	var actors: Dictionary={}
	var positions: Dictionary={}
	var sprites: Dictionary={}
	var selected: Array=[]
	var roles: Array=[]
	var attacker_id: int
	var target_ids: Array=[]
	var contest: bool
	var tracks: Array[Dictionary]=[]
	var writers: Array[Dictionary]=[]
	var dispatched: Dictionary={}
	var revoked: bool=false

class BankEpisode extends RefCounted:
	var owner: WeakRef
	var context: BattleAnimationContext
	var actor: BattleAnimationActor
	var phase: String="RESERVED_NEUTRAL"
	var reason: String=""
	var track: Dictionary={}
	var held: Dictionary={}
	var receipt_tick: int=-1
	var source_material: ShaderMaterial
	var expected_material: Material
	var expected_shader: Shader
	var expected_uniforms: Dictionary={}
	var color: Color=Color.WHITE
	var amount: float=0.0
	var zero_tick: int=-1
	var admitted_tick: int=-1

const COPY_FIELDS := ["texture","centered","offset","hframes","vframes","frame","region_enabled","region_rect","flip_h","flip_v","modulate","self_modulate","material"]

static func matches(owner: Node2D) -> bool:
	return owner is BattleAnimationSequenceRunner and owner.definition!=null and SPECS.has(owner.definition.key) and BattleAnimationSequenceRegistry.is_builtin_source_definition(owner.definition) and owner.definition.source_script==SPECS[owner.definition.key][0]

static func _dispatch(owner: Node2D,step: Dictionary,incoming: Dictionary) -> bool:
	return matches(owner) and owner._pc>=0 and owner._pc<owner.definition.steps.size() and owner._pc<owner._steps.size() and Same._same(step,owner.definition.steps[owner._pc]) and Same._same(step,owner._steps[owner._pc]) and owner.claim_effect_dispatch(incoming)

static func _bound(c: BattleAnimationContext,actor: BattleAnimationActor) -> bool:
	return c.actors.get(actor.id)==actor and actor.is_present()

static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if not matches(owner):return []
	var spec: Array=SPECS[owner.definition.key]
	var commands: Array=["monbg","setalpha","clearmonbg","blendoff"]
	var operands: Array=[[spec[4]],[12,8],[spec[4]],[]]
	var literals: Array=["monbg ANIM_BATTLER_ATK_PARTNER" if spec[4]==2 else "monbg ANIM_BATTLER_TARGET","setalpha 12, 8","clearmonbg ANIM_BATTLER_ATK_PARTNER" if spec[4]==2 else "clearmonbg ANIM_BATTLER_TARGET","blendoff"]
	var index: int=-1
	for n: int in 4:
		if Same._same(step.get("source_line"),spec[3][n]):index=n;break
	if index<0:return []
	var expected: Dictionary={"op":"effect","behavior":"source_legacy_impact_command","mode":commands[index],"source_args":operands[index],"ticks":1,"source_line":spec[3][index],"source_command":literals[index],"source_script":spec[0]}
	if not Same._same(step,expected) or not _dispatch(owner,step,step):return []
	var trace: Array=owner.get_meta("source_legacy_impact_commands",[]);trace.append(int(expected.source_line));owner.set_meta("source_legacy_impact_commands",trace)
	var backgrounds: Array=owner.get_meta("source_legacy_impact_backgrounds",[])
	if index==1 or index==3:
		owner.set_meta("source_legacy_impact_alpha",[12,8] if index==1 else [16,0])
		for item: Dictionary in owner.get_meta("source_legacy_impact_objects",[]):
			_uniform_write(item,"eva",1.0 if index==3 else 0.75)
			_uniform_write(item,"evb",0.0 if index==3 else 0.5)
		return []
	if index==2:
		for t: Dictionary in backgrounds:
			for item: Dictionary in t.clones:
				if _bound(c,item.actor):item.actor.apply_source_state("hidden",false)
			t.ticks=int(t.age)+2
		return []
	var selected:=c.resolve("attacker" if int(spec[4])==2 else "target")
	if selected.is_empty():return []
	var primary: BattleAnimationActor=selected[0]
	var position: int=c.source_position(primary.id)
	var t: Dictionary={"kind":"source_legacy_impact_bg","domain":"maintenance","age":0,"ticks":4096,"owner":owner,"context":c,"clones":[],"update":_background_update}
	for actor: BattleAnimationActor in c.actors.values():
		if actor!=primary and c.source_position(actor.id)!=(position^2):continue
		if not _bound(c,actor) or not actor.sprite.is_visible_in_tree() or (c.contest and actor.id!=c.attacker_id):continue
		var node:=BattleIdentityCopy.clone_sprite(actor,owner);owner.add_child(node)
		var item: Dictionary={"actor":actor,"node":node,"bg_plane":1 if c.contest or c.source_position(actor.id) in [1,2] else 2,"writes":{},"lost":{},"transfer_visible":actor.sprite.visible}
		_snapshot(node,actor,owner);t.clones.append(item)
		actor.apply_source_state("hidden",true)
	if t.clones.is_empty():return []
	t.cleanup=_background_cleanup.bind(t)
	backgrounds.append(t);owner.set_meta("source_legacy_impact_backgrounds",backgrounds)
	_background_update(t,c);return [t]

static func descriptor(owner: Node2D) -> Dictionary:
	var spec: Array=SPECS[owner.definition.key]
	return {"script":spec[0],"source_line":spec[1],"source_command":"createvisualtask sub_80E2DD8, 2, 0, 4, 7, %d"%int(spec[2]),"source_task":"sub_80E2DD8","source_callback":"sub_80E2E10","source_child_callback":"sub_80E2EE8","source_helper":"duplicate_obj_of_side_rel2move_in_transparent_mode","source_args":[0,4,7,spec[2]],"obj_mode":1,"priority":2}

static func duplicates(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if not matches(owner):return []
	var spec: Array=SPECS[owner.definition.key]
	var expected: Dictionary={"op":"effect","behavior":"source_legacy_impact_duplicates","ticks":8,"selector":"attacker","emit_count":spec[2],"emit_interval":5,"source_task":"sub_80E2DD8","source_line":spec[1],"source_legacy_duplicate":descriptor(owner)}
	if not Same._same(step,expected) or not _dispatch(owner,step,step):return []
	var actors:=c.resolve("attacker")
	if actors.is_empty():return []
	if owner.definition.key=="ruby:move/332":_reserve(owner,c,actors[0])
	var t: Dictionary={"kind":"source_legacy_impact_duplicates","domain":"visual","age":0,"ticks":4096,"owner":owner,"context":c,"bound_actor":actors[0],"remaining":int(spec[2]),"counter":0,"children":[],"pending":false,"source_line":int(spec[1]),"update":_duplicate_update}
	t.cleanup=_duplicate_cleanup.bind(t)
	return [t]

static func _duplicate_update(t: Dictionary,c: BattleAnimationContext) -> void:
	if not _bound(c,t.bound_actor):
		_duplicate_cleanup(t);t.ticks=int(t.age);return
	for child: Dictionary in t.children.duplicate():
		if int(child.remaining)>0:child.remaining-=1
		else:
			if is_instance_valid(child.node):child.node.queue_free()
			t.children.erase(child)
	if int(t.remaining)>0:
		if int(t.counter)>0:t.counter-=1
		else:t.pending=true;t.remaining-=1;t.counter=4
	if int(t.remaining)==0 and t.children.is_empty() and not t.pending:t.ticks=int(t.age)

static func _duplicate_cleanup(t: Dictionary) -> void:
	t.erase("cleanup")
	t.pending=false;t.remaining=0
	for child: Dictionary in t.children:
		if is_instance_valid(child.node):child.node.queue_free()
	t.children.clear()

static func _snapshot(node: Sprite2D,actor: BattleAnimationActor,owner: Node2D) -> void:
	for property: String in COPY_FIELDS:node.set(property,actor.sprite.get(property))
	node.transform=owner.global_transform.affine_inverse()*actor.sprite.global_transform
	node.visible=true

static func _write(item: Dictionary,property: String,value: Variant) -> void:
	if item.lost.has(property):return
	if item.writes.has(property) and item.node.get(property)!=item.writes[property]:item.lost[property]=true;return
	item.node.set(property,value);item.writes[property]=item.node.get(property)

static func _background_update(t: Dictionary,c: BattleAnimationContext) -> void:
	for item: Dictionary in t.clones.duplicate():
		if not _bound(c,item.actor):
			if is_instance_valid(item.node):item.node.queue_free()
			t.clones.erase(item);continue
		for property: String in COPY_FIELDS:_write(item,property,item.actor.sprite.get(property))
		_write(item,"transform",t.owner.global_transform.affine_inverse()*item.actor.sprite.global_transform)
	if t.clones.is_empty():t.ticks=int(t.age)
	_order(t.owner,c)

static func _background_cleanup(t: Dictionary) -> void:
	t.erase("cleanup")
	for item: Dictionary in t.clones:
		if _bound(t.context,item.actor):item.actor.apply_source_state("hidden",false)
		if is_instance_valid(item.node):item.node.queue_free()
	t.clones.clear()

static func attach(track: Dictionary,c: BattleAnimationContext,owner: Node2D,incoming: Dictionary) -> void:
	if not matches(owner) or owner.definition.key!="ruby:move/332" or track.kind!="sheet":return
	var expected: Dictionary={"op":"effect","behavior":"sheet","ticks":23,"texture":"res://graficos/batalla/animaciones/cut.png","frame_size":[32,32],"frame_commands":Same.FRAMES,"selector":"target","source_template":Same.TEMPLATE,"source_callback":Same.CALLBACK,"offset":[40,-32],"travel":[-62,62],"travel_ticks":20,"source_line":4347,"source_legacy_composition":Same.AERIAL}
	if not Same._same(track.settings,expected) or not _dispatch(owner,track.settings,incoming):return
	var actors:=c.resolve("attacker")
	if actors.is_empty():return
	_register(track.node,maxi(3,BattleElectricContract.source_subpriority(actors[0],c)-2),owner,c)

static func _register(node: Sprite2D,subpriority: int,owner: Node2D,c: BattleAnimationContext,actor: BattleAnimationActor=null) -> Dictionary:
	var previous: Material=node.material
	var material: ShaderMaterial
	var episode: BankEpisode=(owner.get_meta("i149_bank_episode") if owner.has_meta("i149_bank_episode") else null)
	var bank_owned: bool=actor!=null and episode!=null and episode.actor==actor and _bound(c,actor) and episode.phase!="REVOKED" and (previous==null or (episode.phase=="ACTIVE" and previous==episode.source_material))
	if bank_owned:
		material=ShaderMaterial.new();material.shader=Composed
		for key: String in PALETTE_DEFAULTS:
			var value: Variant=PALETTE_DEFAULTS[key]
			if previous is ShaderMaterial and previous.shader==SharedPalette:value=_uniform_value(previous,key)
			material.set_shader_parameter(key,value)
		material.set_shader_parameter("blend_color",episode.color);material.set_shader_parameter("blend_amount",episode.amount)
	elif previous==null:material=BattleIdentityCopy.blend_material(false)
	if material!=null:
		var pair: Array=owner.get_meta("source_legacy_impact_alpha",[16,0])
		material.set_shader_parameter("eva",float(pair[0])/16);material.set_shader_parameter("evb",float(pair[1])/16)
		node.material=material
	var item: Dictionary={"node":node,"material":material,"previous":null,"subpriority":subpriority,"shader":material.shader if material!=null else null,"uniforms":{},"revoked":{},"lost_material":false,"bank_owned":bank_owned,"writes":{},"lost":{},"context":c,"actor":actor if actor!=null else c.resolve("attacker")[0]}
	if material!=null:
		for key: String in (["eva","evb"]+PALETTE_DEFAULTS.keys() if bank_owned else ["eva","evb","first_tint"]):item.uniforms[key]=_uniform_value(material,key)
	var objects: Array=owner.get_meta("source_legacy_impact_objects",[])
	objects.append(item);owner.set_meta("source_legacy_impact_objects",objects);_order(owner,c)
	return item

static func _uniform_value(material: ShaderMaterial,key: String) -> Variant:
	var value: Variant=material.get_shader_parameter(key)
	if value!=null:return value
	if PALETTE_DEFAULTS.has(key):return PALETTE_DEFAULTS[key]
	return Vector3.ONE if key=="first_tint" else 0.75 if key=="eva" else 0.5

static func _uniform_observe(item: Dictionary) -> bool:
	if item.lost_material or item.material==null or not is_instance_valid(item.node):return false
	if item.node.is_queued_for_deletion() or not _bound(item.context,item.actor):
		item.lost_material=true;item.material=null;item.shader=null;item.previous=null;return false
	if item.node.material!=item.material or item.material.shader!=item.shader:
		item.lost_material=true;item.material=null;item.shader=null;item.previous=null
		return false
	for key: String in item.uniforms:
		if not item.revoked.has(key) and _uniform_value(item.material,key)!=item.uniforms[key]:item.revoked[key]=true
	return true

static func _uniform_write(item: Dictionary,key: String,value: Variant) -> void:
	if not _uniform_observe(item) or item.revoked.has(key):return
	item.material.set_shader_parameter(key,value);item.uniforms[key]=_uniform_value(item.material,key)

static func _order(owner: Node2D,c: BattleAnimationContext) -> void:
	var band: int=BattleSourcePriority.effective_layer(c.field)-BattleSourcePriority.effective_layer(owner)+1
	for actor: BattleAnimationActor in c.actors.values():
		if actor.is_present():band=maxi(band,BattleSourcePriority.actor_layer(actor,owner))
	for t: Dictionary in owner.get_meta("source_legacy_impact_backgrounds",[]):
		for item: Dictionary in t.clones:
			if is_instance_valid(item.node):_write(item,"z_index",band+(1 if int(item.bg_plane)==1 else 0))
	for item: Dictionary in owner.get_meta("source_legacy_impact_objects",[]):
		if is_instance_valid(item.node) and not item.node.is_queued_for_deletion():_write(item,"z_index",band+62-int(item.subpriority))

static func after_pose(owner: Node2D,c: BattleAnimationContext) -> void:
	_update_child_bank(owner,c)
	for t: Dictionary in owner.get_meta("source_legacy_impact_backgrounds",[]):_background_update(t,c)
	for t: Dictionary in owner._tracks:
		if t.kind!="source_legacy_impact_duplicates" or not t.pending:continue
		t.pending=false
		if not _bound(c,t.bound_actor):continue
		# Create once, here, after ALL current-tick actor/appearance writes. No
		# half-born public node exists for a later fixup to clobber external edits.
		var node:=BattleIdentityCopy.clone_sprite(t.bound_actor,owner)
		owner.add_child(node);_snapshot(node,t.bound_actor,owner)
		node.set_meta("source_legacy_duplicate_line",int(t.source_line))
		var item: Dictionary=_register(node,BattleElectricContract.source_subpriority(t.bound_actor,c),owner,c,t.bound_actor)
		t.children.append({"node":node,"remaining":7,"ownership":item})
	_order(owner,c)

# A single selected original-attacker bank episode. Observation hooks are NOOP
# outside authentic332; they never write actor materials or general blend state.
static func _episode(owner: Node2D) -> BankEpisode:
	if not matches(owner) or owner.definition.key!="ruby:move/332":return null
	return (owner.get_meta("i149_bank_episode") if owner.has_meta("i149_bank_episode") else null)

static func _future(owner: Node2D) -> bool:
	if not matches(owner) or owner.definition.key!="ruby:move/332" or owner.definition.steps.size()<14 or owner._steps.size()<14:return false
	for index: int in 5:
		var expected: Dictionary=PALETTE_STEP.duplicate(true);expected.selector=PALETTE_ROLES[index]
		if not Same._same(owner.definition.steps[9+index],expected) or not Same._same(owner._steps[9+index],expected):return false
	return true

static func _reserve(owner: Node2D,c: BattleAnimationContext,actor: BattleAnimationActor) -> void:
	if owner.has_meta("i149_bank_episode") or not _future(owner) or _mapped(owner,c).is_empty():return
	var e:=BankEpisode.new();e.owner=weakref(owner);e.context=c;e.actor=actor
	e.expected_material=actor.sprite.material
	if e.expected_material!=null:
		e.phase="REVOKED";e.reason="material already installed at reservation";e.expected_material=null
	owner.set_meta("i149_bank_episode",e)

static func _revoke(e: BankEpisode,reason: String) -> void:
	e.phase="REVOKED";e.reason=reason;e.track={};e.held={};e.source_material=null;e.expected_material=null;e.expected_shader=null;e.expected_uniforms={}

static func begin_tick(owner: Node2D,c: BattleAnimationContext) -> void:
	var g: PaletteGroup=(owner.get_meta("i149_palette_group") if owner.has_meta("i149_palette_group") else null)
	if g!=null and not _group_valid(owner,c,g):return
	var e:=_episode(owner)
	if e==null or e.phase=="REVOKED":return
	if c!=e.context or not _bound(c,e.actor) or not _future(owner):_revoke(e,"original bank or future source shape lost");return
	var material: Material=e.actor.sprite.material
	if material!=e.expected_material:_revoke(e,"differing external source material observed");return
	if e.expected_shader!=null:
		if not material is ShaderMaterial or material.shader!=e.expected_shader:_revoke(e,"differing source Shader observed");return
		for key: String in e.expected_uniforms:
			if _uniform_value(material,key)!=e.expected_uniforms[key]:_revoke(e,"differing external source uniform:"+key);return
	for item: Dictionary in owner.get_meta("source_legacy_impact_objects",[]):_uniform_observe(item)

# Recover only the five-member lowering of the single source4351 OR-mask.
# This helper does not repair generic Context selectors or dynamic bank rebinding.
static func _partner_visible(owner: Node2D,c: BattleAnimationContext,actor: BattleAnimationActor) -> bool:
	if not _bound(c,actor):return false
	if c.contest:return actor.id==c.attacker_id
	if actor.sprite.is_visible_in_tree():return true
	# Only our still-owned monbg transfer can explain a hidden OBJ. A stale
	# actor base_visible alone is deliberately not logical-visibility evidence.
	for t: Dictionary in owner.get_meta("source_legacy_impact_backgrounds",[]):
		for item: Dictionary in t.clones:
			if item.actor==actor and item.get("transfer_visible",false) and is_instance_valid(item.node) and not item.node.is_queued_for_deletion() and actor.hidden_projection==null and actor._owned_hidden and actor._base_visible and not actor._expected_visible and not actor.sprite.visible:return true
	return false

static func _mapped(owner: Node2D,c: BattleAnimationContext) -> Dictionary:
	var positions: Dictionary={};var sprites: Array=[];var actors: Dictionary={}
	for id: Variant in c.actors:
		if not id is int:return {}
		var actor: BattleAnimationActor=c.actors[id]
		if actor==null or actor.id!=id:return {}
		var position: Variant=c.source_positions.get(id,c.source_position(id))
		if not (position is int or position is float) or not is_finite(float(position)) or float(position)!=floorf(float(position)) or position<0 or position>3 or positions.has(int(position)) or sprites.has(actor.sprite):return {}
		positions[int(position)]=actor;actors[id]=actor;sprites.append(actor.sprite)
	var roles: Array=[[],[],[],[],[]]
	var seen: Array=[]
	for index: int in range(1,5):
		var direct_id: int=c.attacker_id if index in [1,3] else int(c.target_ids[0]) if not c.target_ids.is_empty() else -1
		var direct: BattleAnimationActor=actors.get(direct_id)
		if direct==null or not _bound(c,direct):continue
		var actor: BattleAnimationActor=direct
		if index>=3:
			actor=positions.get(c.source_position(direct_id)^2)
			if actor==null or not _partner_visible(owner,c,actor):continue
		if not seen.has(actor):seen.append(actor);roles[index].append(actor)
	return {"actors":actors,"positions":positions,"roles":roles,"selected":seen}

# Only actual factory-admitted identities and their exact last held receipt
# are ours. This runs before the final actor loop, including post-retirement.
static func _retire_group(owner: Node2D,g: PaletteGroup) -> void:
	g.revoked=true
	for writer: Dictionary in g.writers:
		for index: int in range(owner._tracks.size()-1,-1,-1):
			if is_same(owner._tracks[index],writer.track):owner._tracks.remove_at(index)
		var held: Dictionary=writer.held
		if not held.is_empty() and is_same(owner._held_blends.get(writer.actor.id),held) and held.get("source_actor")==writer.actor:owner._held_blends.erase(writer.actor.id)

static func _group_valid(owner: Node2D,c: BattleAnimationContext,g: PaletteGroup) -> bool:
	if g.revoked:
		_retire_group(owner,g);return false
	var mapped: Dictionary=_mapped(owner,c)
	var valid: bool=c==g.context and _future(owner) and c.attacker_id==g.attacker_id and c.target_ids==g.target_ids and c.contest==g.contest and not mapped.is_empty() and mapped.actors==g.actors and mapped.positions==g.positions and mapped.roles==g.roles
	if valid:
		for id: int in g.actors:
			if g.actors[id].sprite!=g.sprites[id] or not _bound(c,g.actors[id]):valid=false;break
	if valid:
		for writer: Dictionary in g.writers:
			if writer.track.get("actor")!=writer.actor or not Same._same(writer.track.get("settings"),writer.step):valid=false;break
	if not valid:
		_retire_group(owner,g)
		var e:=_episode(owner)
		if e!=null:_revoke(e,"selected source group membership lost")
	return valid

static func palette_members(owner: Node2D,c: BattleAnimationContext,step: Dictionary,incoming: Dictionary) -> Dictionary:
	if not _future(owner) or owner._pc<9 or owner._pc>13:return {"handled":false}
	var g: PaletteGroup=(owner.get_meta("i149_palette_group") if owner.has_meta("i149_palette_group") else null)
	if g==null:
		if owner._pc!=9:return {"handled":false}
		var mapped: Dictionary=_mapped(owner,c)
		if mapped.is_empty():return {"handled":false}
		g=PaletteGroup.new();g.owner=weakref(owner);g.context=c;g.actors=mapped.actors;g.positions=mapped.positions;g.roles=mapped.roles;g.selected=mapped.selected
		g.attacker_id=c.attacker_id;g.target_ids=c.target_ids.duplicate();g.contest=c.contest
		for id: int in g.actors:g.sprites[id]=g.actors[id].sprite
		# No authority until the current synchronous incoming dispatch is claimed.
	if not _group_valid(owner,c,g) or g.dispatched.has(owner._pc) or not _dispatch(owner,step,incoming):return {"handled":false}
	owner.set_meta("i149_palette_group",g);g.dispatched[owner._pc]=true
	return {"handled":true,"actors":g.roles[owner._pc-9],"group":weakref(g),"pc":owner._pc}

static func admit_palette(owner: Node2D,c: BattleAnimationContext,track: Dictionary,admission: Dictionary) -> void:
	if not admission.get("handled",false):return
	var g: PaletteGroup=admission.group.get_ref()
	if g==null or not _group_valid(owner,c,g) or int(admission.pc)!=owner._pc:return
	if not admission.actors.has(track.get("actor")):return
	for previous: Dictionary in g.tracks:
		if previous.actor==track.actor:return
	g.tracks.append(track)
	g.writers.append({"track":track,"actor":track.actor,"step":track.settings.duplicate(true),"held":{}})
	var e:=_episode(owner)
	if e==null or e.phase!="RESERVED_NEUTRAL" or not e.track.is_empty() or track.actor!=e.actor:return
	e.track=track;e.admitted_tick=int(owner.elapsed_ticks)
	track.i149_bank_episode=weakref(e)

static func note_palette_write(owner: Node2D,track: Dictionary,held: Dictionary) -> void:
	var g: PaletteGroup=(owner.get_meta("i149_palette_group") if owner.has_meta("i149_palette_group") else null)
	if g!=null:
		for writer: Dictionary in g.writers:
			if not is_same(writer.track,track):continue
			# Original occupant marker also activates the runner's pre-existing
			# held-endpoint retirement guard. Never tag an independent producer.
			held.source_actor=writer.actor;writer.held=held
			if not _group_valid(owner,owner.context,g):
				# This callback can already be in the current tick's duplicate
				# iteration when a prior callback loses captured authority.
				_retire_group(owner,g);return
			break
	var e:=_episode(owner)
	if e==null or e.phase=="REVOKED" or track.get("actor")!=e.actor:return
	if not is_same(track,e.track) or not Same._same(track.get("settings"),PALETTE_STEP):_revoke(e,"competing source palette writer");return
	e.held=held;e.receipt_tick=int(owner.elapsed_ticks)

static func confirm_final(owner: Node2D,c: BattleAnimationContext,actor: BattleAnimationActor,blend: Dictionary,transient: bool) -> void:
	var e:=_episode(owner)
	if e==null or e.phase=="REVOKED" or actor!=e.actor:return
	if c!=e.context or not _bound(c,actor) or not _future(owner):_revoke(e,"original bank lost at final pose");return
	if transient:_revoke(e,"competing transient final contributor");return
	if e.track.is_empty() or int(e.track.age)==0:
		if owner._held_blends.has(actor.id) or actor.sprite.material!=e.expected_material:_revoke(e,"foreign neutral/pre-admission contributor")
		return
	if not is_same(blend,e.held) or not is_same(owner._held_blends.get(actor.id),e.held):_revoke(e,"final held reference was not admitted writer");return
	if e.phase!="RESTORED" and e.receipt_tick!=int(owner.elapsed_ticks):_revoke(e,"missing authentic progression");return
	var age: int=int(e.track.age)
	var amount: float=0.625 if age<=4 else 0.0
	if not Same._same(blend,{"color":Color.BLACK,"amount":amount,"source_actor":e.actor}):_revoke(e,"source endpoint value mismatch");return
	if amount>0:
		var material: ShaderMaterial=actor._blend_material
		if material==null or actor.sprite.material!=material or material.shader!=SharedPalette:_revoke(e,"final source material authority mismatch");return
		var expected_output: Dictionary={"blend_color":Color.BLACK,"blend_amount":amount,"grayscale":false,"invert":false,"wave_amplitude":0.0,"wave_phase":0.0,"wave_height":64.0,"wave_start":0.0,"wave_end":0.0,"wave_scale_x":0.0,"wave_scale_y":0.0}
		for key: String in expected_output:
			if _uniform_value(material,key)!=expected_output[key]:_revoke(e,"source palette output mismatch:"+key);return
		if actor._owned_grayscale or actor._owned_invert:_revoke(e,"unadmitted grayscale/invert ownership");return
		e.source_material=material;e.expected_material=material;e.expected_shader=SharedPalette;e.expected_uniforms={}
		for key: String in PALETTE_DEFAULTS:e.expected_uniforms[key]=_uniform_value(material,key)
		e.phase="ACTIVE"
	else:
		if actor._blend_material!=null or actor.sprite.material!=null:_revoke(e,"source zero did not restore reserved prior material");return
		if e.phase!="RESTORED" and (e.phase!="ACTIVE" or age!=5):_revoke(e,"zero without admitted active endpoint");return
		if e.phase!="RESTORED":e.zero_tick=int(owner.elapsed_ticks)
		e.phase="RESTORED";e.source_material=null;e.expected_material=null;e.expected_shader=null;e.expected_uniforms={}
	e.color=Color.BLACK;e.amount=amount

static func _update_child_bank(owner: Node2D,c: BattleAnimationContext) -> void:
	var e:=_episode(owner)
	for item: Dictionary in owner.get_meta("source_legacy_impact_objects",[]):
		_uniform_observe(item)
		if not item.bank_owned or e==null or not _bound(c,e.actor) or e.phase=="REVOKED":continue
		_uniform_write(item,"blend_color",e.color);_uniform_write(item,"blend_amount",e.amount)

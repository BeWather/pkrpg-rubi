extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Shared internal owned-visual mechanics; source admission stays in finite adapters.
const FOLLOW := ["texture","centered","offset","hframes","vframes","frame","region_enabled","region_rect","flip_h","flip_v","modulate","self_modulate","material"]

static func node(item: Dictionary) -> bool:
	return is_instance_valid(item.node) and not item.node.is_queued_for_deletion() and item.node.get_parent()==item.parent

static func write(item: Dictionary,key: String,value: Variant) -> void:
	if not node(item):return
	if item.writes.has(key) and item.node.get(key)!=item.writes[key]:item.lost[key]=true
	if item.lost.has(key):return
	item.node.set(key,value);item.writes[key]=item.node.get(key)

static func follow(item: Dictionary,owner: Node2D) -> void:
	for key: String in FOLLOW:write(item,key,item.actor.sprite.get(key))
	write(item,"transform",owner.global_transform.affine_inverse()*item.actor.sprite.global_transform)

static func observe_material(item: Dictionary) -> bool:
	if item.material==null or not is_instance_valid(item.node):return false
	if item.node.get_parent()!=item.parent or item.node.material!=item.material or item.material.shader!=item.shader:item.lost_material=true
	if item.lost_material:return false
	for key: String in item.uniforms:
		if item.material.get_shader_parameter(key)!=item.uniforms[key]:item.revoked[key]=true
	return true

static func uniform(item: Dictionary,key: String,value: Variant) -> void:
	if not observe_material(item) or item.revoked.has(key):return
	item.material.set_shader_parameter(key,value);item.uniforms[key]=item.material.get_shader_parameter(key)

static func release_object(item: Dictionary) -> void:
	if not item.active:return
	if observe_material(item) and is_instance_valid(item.node):item.node.material=item.previous
	item.active=false

static func restore(item: Dictionary,c: BattleAnimationContext) -> void:
	# Lost admission retires the mirror, not the surviving original's hide lease.
	var actor: BattleAnimationActor=item.actor
	var sprite: Sprite2D=item.binding.sprites[actor.id]
	if actor.sprite!=sprite or not actor.is_present():return
	# A new wrapper using this same visual is a successor, never old cleanup work.
	for occupant: BattleAnimationActor in c.actors.values():
		if occupant!=actor and occupant.sprite==sprite:return
	actor.apply_source_state("hidden",false)

static func retire(item: Dictionary,c: BattleAnimationContext) -> void:
	if item.retired:return
	restore(item,c)
	if node(item):item.node.queue_free()
	item.retired=true

static func cleanup_bg(t: Dictionary) -> void:
	t.erase("cleanup")
	for item: Dictionary in t.clones:retire(item,t.context)
	t.clones.clear()


## Ordinary monbg remaps both single operands to the same source-bank pair.
## Selection only: no clone, metadata, visibility, material or dispatch writes.
static func source_bg_members(c: BattleAnimationContext,operand: Variant) -> Array[BattleAnimationActor]:
	var number: Callable=func(value: Variant)->bool:
		return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floor(float(value)) and int(value) in [0,1,2,3]
	if c==null or not number.call(operand):return []
	var primary: int=c.attacker_id if int(operand) in [0,2] else (c.target_ids[0] if not c.target_ids.is_empty() else -1)
	if primary<0:return []
	var position_of: Callable=func(id: int)->int:
		var value: Variant=c.source_positions[id] if c.source_positions.has(id) else BattleAnimationContext.source_position_for_slot(id)
		return int(value) if number.call(value) else -1
	var source: int=position_of.call(primary)
	if source<0:return []
	var occupied: Dictionary={};var wrappers: Dictionary={}
	for value: Variant in c.actors.values():
		if not value is BattleAnimationActor:return []
		var actor: BattleAnimationActor=value
		if wrappers.has(actor):continue
		wrappers[actor]=true
		var position: int=position_of.call(actor.id)
		if position<0 or occupied.has(position):return []
		occupied[position]=actor
	if occupied.has(source) and occupied[source].id!=primary:return []
	var candidates: Array[BattleAnimationActor]=[]
	if occupied.has(source):candidates.append(occupied[source])
	if occupied.has(source^2):candidates.append(occupied[source^2])
	var result: Array[BattleAnimationActor]=[];var visuals: Dictionary={}
	for actor: BattleAnimationActor in candidates:
		if not actor.is_present() or not actor.sprite.is_visible_in_tree() or (c.contest and actor.id!=c.attacker_id) or visuals.has(actor.sprite):continue
		visuals[actor.sprite]=true;result.append(actor)
	return result

## Additive finite-consumer helpers. Existing consumers above keep their policies.
static func item(n: Node2D,parent: Node) -> Dictionary:
	var result: Dictionary = {"node":n,"parent":parent,"writes":{},"lost":{},"material":null,"shader":null,"uniforms":{},"revoked":{},"lost_material":false,"active":false,"previous":null}
	for property: Dictionary in n.get_property_list():
		var key: String = str(property.name)
		if key in ["transform","position","rotation","scale","skew","visible","z_index","texture","centered","offset","hframes","vframes","frame","region_enabled","region_rect","flip_h","flip_v","modulate","self_modulate","material","polygon","color","copy_mode","rect"]:result.writes[key] = n.get(key)
	return result

static func pose(receipt: Dictionary,transform: Transform2D) -> bool:
	if not transform.is_finite() or is_zero_approx(transform.determinant()):return false
	var orientation: float = 1.0 if transform.determinant()>0 else -1.0
	var y: Vector2 = transform.y*orientation
	write(receipt,"position",transform.origin);write(receipt,"rotation",transform.x.angle())
	write(receipt,"scale",Vector2(transform.x.length(),transform.y.length()*orientation))
	write(receipt,"skew",-atan2(transform.x.dot(y),transform.x.cross(y)))
	return not receipt.lost.has("position") and not receipt.lost.has("rotation") and not receipt.lost.has("scale") and not receipt.lost.has("skew")

static func attach_material(receipt: Dictionary,shader: Shader) -> void:
	receipt.previous = receipt.node.material
	var material := ShaderMaterial.new();material.shader = shader
	write(receipt,"material",material);receipt.material = material;receipt.shader = shader;receipt.active = true

static func release_material(receipt: Dictionary) -> void:
	if not receipt.get("active",false):return
	if observe_material(receipt) and receipt.revoked.is_empty() and not receipt.lost_material:receipt.node.material = receipt.previous
	receipt.active = false

static func image_input(texture: Texture2D) -> Dictionary:
	if texture==null:return {}
	var chain: Array = [];var seen: Dictionary = {};var cursor: Texture2D = texture
	for depth: int in 5:
		if not cursor is AtlasTexture:break
		if cursor.get_script()!=null or seen.has(cursor.get_instance_id()):return {}
		seen[cursor.get_instance_id()] = true
		chain.append({"view":cursor,"atlas":cursor.atlas,"region":cursor.region,"margin":cursor.margin,"filter_clip":cursor.filter_clip});cursor=cursor.atlas
		if cursor==null:return {}
	if cursor is AtlasTexture:return {}
	var raw: Image = cursor.get_image()
	if raw==null or raw.is_empty() or raw.get_width()>4096 or raw.get_height()>4096:return {}
	var result: Dictionary = {"texture":texture,"leaf":cursor,"bytes":raw.get_data(),"size":raw.get_size(),"format":raw.get_format(),"chain":chain}
	var image: Image = raw.duplicate();image.convert(Image.FORMAT_RGBA8)
	for index: int in range(chain.size()-1,-1,-1):
		var link: Dictionary = chain[index];var region: Rect2 = link.region
		if region.size==Vector2.ZERO:region.size = image.get_size()
		if not region.position.is_finite() or not region.size.is_finite() or not link.margin.position.is_finite() or not link.margin.size.is_finite() or region.position!=region.position.floor() or region.size!=region.size.floor() or link.margin.position!=link.margin.position.floor() or link.margin.size!=link.margin.size.floor() or region.position.x<0 or region.position.y<0 or region.end.x>image.get_width() or region.end.y>image.get_height():return {}
		var size: Vector2 = region.size+link.margin.size
		if size.x<=0 or size.y<=0 or size.x>4096 or size.y>4096 or size!=size.floor():return {}
		var expanded: Image = Image.create(int(size.x),int(size.y),false,Image.FORMAT_RGBA8)
		expanded.blit_rect(image,Rect2i(region),Vector2i(link.margin.position));image = expanded
	result.image = image
	return result if image_input_valid(result) else {}

static func image_input_valid(input: Dictionary) -> bool:
	if input.is_empty() or not is_instance_valid(input.leaf):return false
	for link: Dictionary in input.chain:
		if link.view.atlas!=link.atlas or link.view.region!=link.region or link.view.margin!=link.margin or link.view.filter_clip!=link.filter_clip:return false
	var image: Image = input.leaf.get_image()
	if image==null or image.get_size()!=input.size or image.get_format()!=input.format or image.get_data()!=input.bytes:return false
	for link: Dictionary in input.chain:
		if link.view.atlas!=link.atlas or link.view.region!=link.region or link.view.margin!=link.margin or link.view.filter_clip!=link.filter_clip:return false
	return true

class Voice extends RefCounted:
	var owner_ref: WeakRef
	var parent_ref: WeakRef
	var player_ref: WeakRef
	var stream_ref: WeakRef
	var properties: Array = []
	var exit_receipt: Dictionary = {}
	var lost := false
	func entered() -> void:exit_receipt = {}
	func exiting() -> void:
		var player: Variant = player_ref.get_ref();var owner: Variant = owner_ref.get_ref()
		exit_receipt = {}
		if not is_instance_valid(owner) or owner.state!="running" or not is_instance_valid(player) or not player.is_inside_tree() or not owns():return
		var playback: Variant = player.get_stream_playback() if player.has_stream_playback() else null
		exit_receipt = {"frame":Engine.get_process_frames(),"playback":weakref(playback) if is_instance_valid(playback) else null,"used":false}
	func values(player: AudioStreamPlayer2D) -> Array:return [player.stream_paused,player.pitch_scale,player.volume_db]
	func owns(native_exit: bool=false) -> bool:
		if lost:return false
		var player: Variant = player_ref.get_ref();var owner: Variant = owner_ref.get_ref()
		if not is_instance_valid(player) or not is_instance_valid(owner) or player.get_parent()!=owner or player.stream!=stream_ref.get_ref() or player.is_queued_for_deletion():lost=true;return false
		if properties==values(player):return true
		var grant: bool = native_exit and not exit_receipt.is_empty() and not exit_receipt.get("used",true) and exit_receipt.frame==Engine.get_process_frames() and owner.state=="cancelled" and owner.lifecycle_aborted and owner.is_inside_tree() and owner.get_parent()==parent_ref.get_ref() and not player.is_inside_tree() and properties[0]==false and player.stream_paused==true and player.pitch_scale==properties[1] and player.volume_db==properties[2]
		var playback_ref: Variant = exit_receipt.get("playback")
		if grant and playback_ref is WeakRef and player.has_stream_playback() and player.get_stream_playback()==playback_ref.get_ref():exit_receipt.used=true;return true
		lost=true;return false
	func note_write() -> void:
		var player: Variant = player_ref.get_ref()
		if not lost and is_instance_valid(player) and player.get_parent()==owner_ref.get_ref() and player.stream==stream_ref.get_ref():properties=values(player);exit_receipt={}

static func _voice_exit(reference: WeakRef) -> void:
	var receipt: Voice = reference.get_ref() as Voice
	if receipt!=null:receipt.exiting()
static func _voice_enter(reference: WeakRef) -> void:
	var receipt: Voice = reference.get_ref() as Voice
	if receipt!=null:receipt.entered()
static func voice(owner: Node2D,player: AudioStreamPlayer2D) -> Voice:
	var receipt := Voice.new();receipt.owner_ref=weakref(owner);receipt.parent_ref=weakref(owner.get_parent());receipt.player_ref=weakref(player);receipt.stream_ref=weakref(player.stream);receipt.properties=receipt.values(player)
	player.tree_exiting.connect(_voice_exit.bind(weakref(receipt)));player.tree_entered.connect(_voice_enter.bind(weakref(receipt)))
	return receipt

class LeafSweep extends RefCounted:
	var owner_ref: WeakRef
	var leaves: Array[WeakRef] = []
	var pending := false
	func changed(_child: Node=null) -> void:
		if pending:return
		pending=true;finish.call_deferred()
	func children_changed() -> void:changed()
	func enroll(n: Node) -> void:
		var owner: Variant = owner_ref.get_ref()
		if not is_instance_valid(n) or n.get_parent()!=owner:return
		leaves.append(weakref(n))
		if not n.child_exiting_tree.is_connected(changed):n.child_exiting_tree.connect(changed)
		if not n.child_order_changed.is_connected(children_changed):n.child_order_changed.connect(children_changed)
	func finish() -> void:
		pending=false
		var owner: Variant = owner_ref.get_ref()
		if not is_instance_valid(owner) or owner.state=="running":return
		for reference: WeakRef in leaves:
			var candidate: Variant = reference.get_ref()
			if is_instance_valid(candidate) and candidate.get_parent()==owner and candidate.get_child_count(true)==0 and not candidate.is_queued_for_deletion():candidate.queue_free()
		if owner.get_child_count(true)==0 and not owner.is_queued_for_deletion():owner.queue_free()

static func leaf_sweep(owner: Node2D) -> LeafSweep:
	var sweep := LeafSweep.new();sweep.owner_ref=weakref(owner)
	owner.child_exiting_tree.connect(sweep.changed);owner.child_order_changed.connect(sweep.children_changed)
	return sweep

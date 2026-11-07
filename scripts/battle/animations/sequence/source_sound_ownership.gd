extends RefCounted
class_name BattleSoundOwnership
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

const SourceCoordinates = preload("res://scripts/battle/animations/sequence/source_coordinate_contract.gd")
## Indexed note palette ownership and actual private fixed-point motion.

static func create_bank(step: Dictionary, owner: Node2D) -> Array[Dictionary]:
	if bool(step.allocate):
		owner._source_palette_banks[str(step.bank)] = step.palette_tags.duplicate()
	else:
		owner._source_palette_banks.erase(str(step.bank))
	owner.source_bank_events.append({"tick":owner.elapsed_ticks,"bank":step.bank,"allocate":step.allocate})
	return []

static func prepare_particle(step: Dictionary, owner: Node2D) -> Dictionary:
	if str(step.get("source_module", "")) != "sound_ownership": return step
	var result := step.duplicate(true)
	if owner.definition != null and owner.definition.key == "ruby:move/45" and str(result.get("mode", "")) == "noise_wave":
		var selected: Array[BattleAnimationActor] = owner.context.resolve("attacker")
		var nominal: Dictionary = SourceCoordinates.nominal(selected[0], owner.context) if not selected.is_empty() else {"state":"invalid"}
		if nominal.state == "valid":
			var args: Array = result.source_args
			result.source_nominal_field_origin = nominal.point + Vector2(int(args[0]) * (1 if selected[0].side == 0 else -1), int(args[1]))
			result.source_nominal_field = weakref(owner.context.field)
		elif nominal.state == "invalid":
			# A stale provider is NOT absent: never re-anchor onto successor art.
			result.source_nominal_invalid = true
	if result.has("palette_bank"):
		result.note_bank_active = owner._source_palette_banks.has(str(step.palette_bank))
	if bool(result.get("source_mutate_x",false)) and owner.context.actors[owner.context.attacker_id].side != 0:
		owner._source_args[0] = (-int(result.source_args[0])) & 65535
	if bool(result.get("source_mutate_end_x",false)) and owner.context.actors[owner.context.attacker_id].side != 0:
		owner._source_args[2] = (-int(result.source_args[2])) & 65535
	return result

static func create_cry(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Array[Dictionary]:
	var selected := context.resolve(str(step.selector))
	if selected.is_empty() or (context.contest and str(step.selector) != "attacker"): return []
	var actor: BattleAnimationActor = selected[0]
	if str(step.selector) in ["target","target_partner"] and not actor.sprite.is_visible_in_tree(): return []
	var appearance := str(context.source_appearance_species.get(actor.id,actor.sprite.get_meta("animation_species",actor.sprite.texture.resource_path.get_file().get_basename())))
	var species_source := str(step.get("cry_species_source","appearance"))
	var species := str(context.source_party_species.get(actor.id,actor.sprite.get_meta("animation_party_species",appearance))) if species_source=="party" and not context.contest else appearance
	# A procedural visual with no species is Ruby's species0: no cry. Arbitrary
	# textures can supply presentation-only animation_species (name/national ID).
	if species.is_empty(): return []
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(step.cry_catalog_path)))
	var assets: Dictionary = catalog.get("species_assets",{})
	if not assets.has(species) or not ResourceLoader.exists(str(assets[species])):
		owner.error_message = "Missing native source species cry: " + species
		owner.finish("failed")
		return []
	var players: Array[AudioStreamPlayer2D] = []
	for voice in (2 if int(step.cry_chorus) > 0 else 1):
		var player: AudioStreamPlayer2D = owner._play_sound(str(assets[species]),"SOUND_PAN_ATTACKER")
		var pitch := float(step.cry_pitch) / 15360.0
		if voice > 0: pitch *= 1.0 + float(step.cry_chorus) / 15360.0
		player.set_meta("source_pitch",pitch)
		player.pitch_scale = pitch * owner.speed
		player.volume_db += linear_to_db(float(step.cry_volume) / 125.0) - (12.0 if voice > 0 else 0.0)
		player.set_meta("source_volume_db",player.volume_db)
		players.append(player)
		owner.sound_events.back().merge({"cry_mode":step.cry_mode,"cry_release":step.cry_release,"cry_chorus":step.cry_chorus,"pitch":pitch,"cry_voice":voice,"cry_species_source":species_source,"cry_species":species})
	return [{"kind":"source_species_cry","domain":"sound","age":0,"ticks":int(step.cry_length),"players":players,"settings":step.duplicate(true)}]

static func update_cry(track: Dictionary) -> void:
	var age := int(track.age)
	var settings: Dictionary = track.settings
	var release_ticks := int(settings.cry_release) / 32
	for player in track.players:
		if not is_instance_valid(player): continue
		if release_ticks > 0 and age > int(track.ticks) - release_ticks:
			var fraction := maxf(0.001,float(int(track.ticks)-age)/release_ticks)
			player.volume_db = float(player.get_meta("source_volume_db")) + linear_to_db(fraction)
		if age >= int(track.ticks): player.stop()

static func anchor_pose(step: Dictionary, context: BattleAnimationContext, origin: Vector2, destination: Vector2) -> Dictionary:
	if step.has("source_nominal_field_origin"):
		origin = step.source_nominal_field_origin
		destination = origin
	if str(step.get("mode", "")) == "musical_note":
		if context.contest: destination = Vector2(48,40)
		var delta := destination - origin
		var speed := -40 if delta.x < 0 else 40
		var divisor := int(delta.x * 256) / speed
		if divisor == 0: divisor = 1
		step.note_velocity = [int(delta.x * 256) / divisor, int(delta.y * 256) / divisor]
	var mode := str(step.get("mode",""))
	if mode == "hyper_ring":
		var a: Array = step.source_args
		var source: BattleAnimationActor = context.resolve(str(step.from_selector))[0]
		var target: BattleAnimationActor = context.resolve(str(step.to_selector))[0]
		var anchor := "origin" if int(step.source_ring_coordinate_mode)==0 else "center"
		origin = source.anchor(context.field,anchor)+Vector2(int(a[0])*(1 if source.side==1 else -1),int(a[1]))
		var partners := context.resolve("attacker_partner" if bool(step.source_ring_reverse) else "target_partner")
		destination = target.anchor(context.field,anchor)
		if not context.contest and not partners.is_empty() and partners[0].sprite.is_visible_in_tree():
			destination = (destination+partners[0].anchor(context.field,anchor))/2
		destination += Vector2(int(a[3])*(1 if target.side==1 else -1),int(a[4]))
		var source_partners := context.resolve("target_partner" if bool(step.source_ring_reverse) else "attacker_partner")
		if source.side==1:
			step.source_z_index = (partners[0].sprite.z_index if not partners.is_empty() and partners[0].sprite.is_visible_in_tree() else target.sprite.z_index)+1
		elif not context.contest and not source_partners.is_empty() and source_partners[0].sprite.is_visible_in_tree() and source.anchor(context.field,"origin").x<source_partners[0].anchor(context.field,"origin").x:
			step.source_z_index = source_partners[0].sprite.z_index-1
		else: step.source_z_index = source.sprite.z_index+1
	elif mode == "heal_ring":
		var selected: BattleAnimationActor = context.resolve(str(step.selector))[0]
		var partner := context.resolve("attacker_partner" if str(step.selector)=="attacker" else "target_partner")
		if not context.contest and not partner.is_empty() and partner[0].sprite.is_visible_in_tree():
			var anchor := str(step.anchor)
			var delta := (partner[0].anchor(context.field,anchor).x-selected.anchor(context.field,anchor).x)/2
			var raw := float(step.source_args[0])
			var adjusted := delta if selected.side==0 else 2*raw-delta
			var direction := origin_offset_direction(context)
			origin = selected.anchor(context.field,anchor)+Vector2(adjusted*direction,int(step.source_args[1]))
			destination = origin
	return {"origin":origin,"destination":destination}

static func origin_offset_direction(context: BattleAnimationContext) -> int:
	# sub_807867C compares attacker/target coordinate0 even when the selected
	# sprite anchor is center/partner-average. Equal origins use attacker-side fallback.
	var source_x: float = context.actors[context.attacker_id].anchor(context.field,"origin").x
	var target_x: float = context.resolve("target")[0].anchor(context.field,"origin").x
	return 1 if source_x<target_x else -1 if source_x>target_x else 1 if context.actors[context.attacker_id].side==0 else -1

static func particle_pose(track: Dictionary) -> void:
	var settings: Dictionary = track.settings
	var node: Sprite2D = track.node
	var age := maxi(0,int(track.age))
	var mode := str(settings.get("mode",""))
	if mode == "perish_note":
		var count := mini(age+1,int(settings.orbit_ticks))
		var angle := (count*3+int(settings.perish_angle)) & 255
		var committed := Vector2(120+BattleSourceTrig.cosine(angle,100),int(settings.perish_y)/2-15+count/2+BattleSourceTrig.sine(angle,10)+BattleSourceTrig.cosine((count*10)&255,4))
		node.position = committed
		if age>=int(settings.orbit_ticks)+int(settings.wait_ticks):
			var dy := 0
			var velocity := 5
			var bounces := 0
			for tick in age-int(settings.orbit_ticks)-int(settings.wait_ticks)+1:
				dy += velocity
				velocity += 1
				if dy>48 and velocity>0:
					velocity = bounces-5
					bounces += 1
				if bounces>3:
					track.ticks = int(settings.orbit_ticks)+int(settings.wait_ticks)+tick
					break
			node.position.y += dy
			node.visible = bounces<=3 or age%2==0
		return
	if mode in ["heal_note","snore_note","hyper_ring"]:
		var ticks := maxi(1,int(settings.travel_ticks))
		var sample := age+1 if mode=="hyper_ring" else age
		if mode=="hyper_ring" and sample>ticks:
			node.visible = false
			return
		var delta: Vector2 = track.destination-track.origin
		var vx := int(absf(delta.x)*256)/ticks
		var vy := int(absf(delta.y)*256)/ticks
		vx = (vx | 1) if delta.x<0 else (vx & ~1)
		vy = (vy | 1) if delta.y<0 else (vy & ~1)
		node.position = track.origin+Vector2(((sample*vx)&65535)>>8,((sample*vy)&65535)>>8)*Vector2(-1 if delta.x<0 else 1,-1 if delta.y<0 else 1)
		if mode=="heal_note":node.region_rect.position.y += int(settings.note_palette)*int(settings.palette_bank_height)
		return
	if str(settings.get("mode", "")) == "noise_wave":
		var variant := int(settings.noise_variant)
		var direction := 1 if track.source_side == 0 else -1
		if bool(settings.get("source_nominal_invalid", false)):
			node.visible = false; track.ticks = age; return
		var point: Vector2 = track.origin + Vector2(floorf(age * 640.0 * direction / 256.0),floorf(age * (-640.0 if variant == 0 else 640.0 if variant == 1 else 0.0) / 256.0))
		if settings.has("source_nominal_field"):
			var field: Node2D = settings.source_nominal_field.get_ref() as Node2D
			if not is_instance_valid(field) or not field.is_inside_tree():
				node.visible = false; track.ticks = age; return
			node.position = SourceCoordinates.to_owner(field, node.get_parent() as Node2D, point)
		else: node.position = point
		node.flip_h = track.source_side != 0
		node.flip_v = variant == 1
		return
	if str(settings.get("mode", "")) != "musical_note": return
	var velocity: Array = settings.note_velocity
	# Source increments age then accumulates signed8.4 base coordinates. The
	# target is a velocity operand, NOT an endpoint or completion condition.
	var base := Vector2(floorf((track.origin.x * 16 + age * int(velocity[0])) / 16.0),floorf((track.origin.y * 16 + age * int(velocity[1])) / 16.0))
	node.position = base + Vector2(0,BattleSourceTrig.sine((age*5)&255,15))
	var palette := int(settings.note_palette)
	if int(settings.palette_interval) != 0:
		palette = (palette + age / (int(settings.palette_interval) + 1)) % 4
	if not bool(settings.get("note_bank_active", true)): palette = 0
	node.region_rect.position.y += palette * int(settings.palette_bank_height)
	if base.x < -16 or base.x > track.field_size.x + 16 or base.y < -16 or base.y > track.field_size.y * 0.8:
		track.ticks = age

static func create_field_offset(step: Dictionary, context: BattleAnimationContext) -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []
	var actor_z := 2147483647
	for actor in context.actors.values(): actor_z = mini(actor_z,actor.sprite.z_index)
	for node in context.field.get_children():
		if not (node is Sprite2D or node is Polygon2D):continue
		var is_actor := false
		for actor in context.actors.values():
			if node==actor.sprite:is_actor = true
		if not is_actor and (bool(node.get_meta("animation_background",false)) or node.z_index<actor_z):
			nodes.append({"node":node,"base":node.position,"expected":node.position})
	var track := {"kind":"source_field_offset","age":0,"ticks":int(step.ticks),"settings":step.duplicate(true),"nodes":nodes}
	update_field_offset(track)
	return [track]

static func update_field_offset(track: Dictionary, release: bool = false) -> void:
	var a: Array = track.settings.source_args
	var offset := Vector2.ZERO
	var age := int(track.age)
	if not release and age<int(track.ticks):
		if str(track.settings.register_mode)=="toggle_set":
			var count := (age+1)/maxi(1,int(a[3])+1)
			if count<int(a[2]):offset = -Vector2(int(a[0])*(1 if count%2==0 else -1),-int(a[1]) if count%2==1 else int(a[1]) if count==0 else 0)
		else:
			var count := age/maxi(1,int(a[1])+1)
			var value := int(a[0]) if count%2==1 else 0
			offset = Vector2(value,0) if int(a[3])==0 else Vector2(0,value)
	for owned in track.nodes:
		if not is_instance_valid(owned.node):continue
		owned.base += owned.node.position-owned.expected
		owned.node.position = owned.base+offset
		owned.expected = owned.node.position

static func update_note_grayscale(track: Dictionary, owner: Node2D) -> void:
	if int(track.age)+1!=int(track.settings.gray_after):return
	for particle in owner._tracks:
		if str(particle.kind)!="source_particle" or not is_instance_valid(particle.node):continue
		if str(particle.settings.get("source_palette_tag",""))!=str(track.settings.source_palette_tag):continue
		var material := ShaderMaterial.new()
		material.shader = load("res://scripts/battle/animations/sequence/palette_blend.gdshader")
		material.set_shader_parameter("grayscale",true)
		material.set_shader_parameter("blend_amount",0.0)
		particle.node.material = material

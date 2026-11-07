extends RefCounted
class_name BattlePlantActor
## Concrete plant private phases; source arguments are not family-effect aliases.
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

static func prepare_particle(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Dictionary:
	if str(step.get("source_module", "")) != "plant_actor":
		return step
	var result := step.duplicate(true)
	var side: int = context.actors[context.attacker_id].side
	if bool(result.get("source_mutate_end_x", false)) and side != 0:
		# Source negates ARG2 in its global argument array, while the native anchor
		# adapter already mirrors end_offset. Do not mirror the visual twice.
		owner._source_args[2] = (-int(result.source_args[2])) & 65535
	if str(result.mode) == "bullet_seed":
		var random := RandomNumberGenerator.new()
		random.seed = context.seed_value + owner.elapsed_ticks * 977 + owner.get_child_count() * 37
		result.recoil_amplitude = -12 - int(random.randi() & 7)
		result.recoil_speed = int(random.randi() % 160) + 160
	if str(result.mode) in ["spore_orbit", "petal_large"]:
		var selected := context.resolve("target" if str(result.mode) == "spore_orbit" else "attacker")
		if not selected.is_empty():
			result.layer_actor_z = BattleSourcePriority.actor_layer(selected[0],owner)
			result.layer_field_floor = BattleSourcePriority.effective_layer(context.field)-BattleSourcePriority.effective_layer(owner)
	return result

static func anchor_pose(step: Dictionary, context: BattleAnimationContext, origin: Vector2, destination: Vector2) -> Dictionary:
	if str(step.get("mode", "")) == "root_hold":
		var attacker := context.resolve("attacker")
		var target := context.resolve("target")
		if not attacker.is_empty() and not target.is_empty():
			var offset: Array = step.offset
			origin = attacker[0].anchor(context.field, "origin").lerp(target[0].anchor(context.field, "origin"), float(step.anchor_fraction)) + Vector2(float(offset[0]), float(offset[1]))
			# Source ground-root quirk is retained, not silently corrected.
			if bool(step.source_ground_root) and origin.y > 120:
				origin.y += origin.y - 120
			destination = origin
	return {"origin": origin, "destination": destination}

static func frame_pose(track: Dictionary, selected: Dictionary) -> Dictionary:
	var settings: Dictionary = track.settings
	if str(settings.get("mode", "")) == "seed_sprout":
		var sprout_age := int(track.age) - int(settings.travel_ticks) - int(settings.hidden_ticks) - 1
		if sprout_age >= 0:
			return BattleSourceCommandProgram.evaluate(settings.sprout_program, sprout_age).frame
	return selected

static func particle_pose(track: Dictionary) -> void:
	var settings: Dictionary = track.settings
	var age := maxi(0, int(track.age))
	var node: Sprite2D = track.node
	var direction := 1 if int(track.source_side) == 0 else -1
	match str(settings.get("mode", "")):
		"seed_sprout":
			var duration := int(settings.travel_ticks)
			node.position = BattleSourceParticle.source_arc(track, mini(age, duration))
			node.visible = age <= duration or age > duration + int(settings.hidden_ticks)
		"spore_orbit":
			var phase := (int(settings.angle) + age * int(settings.angle_step)) & 255
			node.position = track.origin + Vector2(sin(phase * TAU / 256.0) * 32, cos(phase * TAU / 256.0) * -3 + floorf((age + 1) * 24.0 / 256.0))
			node.z_index = maxi(int(settings.get("layer_field_floor",-4096)),int(settings.layer_actor_z) + (1 if ((phase - 64) & 65535) < 128 else -1))
			if bool(settings.source_obj_blend):
				node.modulate.a = 12.0 / 16.0
		"petal_large", "petal_small":
			var duration := maxi(1, int(settings.travel_ticks))
			var phase := (64 + age * int(settings.angle_step)) & 255
			node.position = track.origin.lerp(track.destination, minf(1, float(age) / duration))
			node.position.x += sin(phase * TAU / 256.0) * float(settings.radius)
			if str(settings.mode) == "petal_large":
				node.position.y += cos(phase * TAU / 256.0) * -5
				# Ruby's smaller subpriority is foreground; Godot's larger Z is.
				node.z_index = maxi(int(settings.get("layer_field_floor",-4096)),int(settings.layer_actor_z) + (1 if ((phase - 64) & 65535) < 128 else -1))
			else:
				# Source toggles OAM H-flip only at two narrow angle crossings.
				var toggles := 0
				for tick in age + 1:
					var p := (64 + tick * 5) & 255
					if ((p - 59) & 65535) < 5 or ((p - 187) & 65535) < 5:
						toggles += 1
				node.flip_h = bool(node.flip_h) != (toggles % 2 == 1)
		"root_hold":
			node.position = track.origin
			# Retain the customizable native root layer, invert source subpriority
			# around Ruby's baseline30 so overlapping roots preserve front/back.
			node.z_index = int(settings.get("root_layer", 30)) + 30 - int(settings.source_subpriority)
		"ingrain_absorb":
			node.position = track.origin + Vector2(int(settings.x_speed) * (age + 1), sin((((age + 1) * int(settings.angle_step)) & 255) * TAU / 256.0) * float(settings.amplitude))
		"bullet_seed":
			var duration := int(settings.travel_ticks) + 1
			if age <= duration:
				node.position = track.origin.lerp(track.destination, minf(1, float(age) / int(settings.travel_ticks)))
			else:
				var recoil := age - duration - 1
				var speed := int(settings.recoil_speed)
				node.position = track.destination + Vector2(floorf((recoil + 1) * speed / 256.0) * (-1 if speed & 1 else 1), sin(((recoil * 8) & 255) * TAU / 256.0) * int(settings.recoil_amplitude))
		"breath_drift":
			node.position = track.origin + Vector2(floorf(mini(age, 52) * float(settings.x_speed) * direction / 256.0), 0)

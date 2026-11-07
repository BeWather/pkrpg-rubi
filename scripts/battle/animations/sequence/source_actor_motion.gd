extends RefCounted
class_name BattleSourceActorMotion
## Semantic task adapter, not a GBA VM. Counters correspond to source task fields.
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

static func initialize(track: Dictionary) -> void:
	var settings: Dictionary = track.settings
	track.mode = str(settings.mode)
	track.displacement = track.initial if track.mode == "in_place" else Vector2.ZERO
	track.completed = false
	track.scale_pose = Vector2.ONE
	if track.mode == "splash":
		track.stage = 0
		track.stage_count = 0
		track.velocity = 0
		track.affine_frame = 0
		track.affine_scale = Vector2(256, 256)
		track.hops_left = int(settings.hops)
		return
	track.remaining = int(settings.count)
	track.countdown = 0 if track.mode == "in_place" else int(settings.delay)
	track.shakes = 0
	track.displacement += track.amplitude
	advance(track) # All three source shake initializers call their step immediately.

static func advance(track: Dictionary) -> void:
	if track.completed: return
	if track.mode == "splash":
		_splash(track)
		return
	if track.countdown > 0:
		track.countdown -= 1
		return
	track.countdown = int(track.settings.delay)
	if track.mode == "in_place":
		track.displacement += track.amplitude * (2 if int(track.shakes) % 2 == 1 else -2)
		track.shakes += 1
		if track.shakes >= int(track.settings.count):
			track.displacement = track.initial
			track.completed = true
	else:
		if track.mode == "signed":
			track.displacement = -track.displacement
		else:
			track.displacement = Vector2(track.amplitude.x if track.displacement.x == 0 else 0, track.amplitude.y if track.displacement.y == 0 else 0)
		track.remaining -= 1
		if track.remaining == 0:
			track.displacement = Vector2.ZERO
			track.completed = true

static func _affine(track: Dictionary) -> bool:
	if int(track.affine_frame) >= 24:
		track.displacement = Vector2.ZERO
		track.scale_pose = Vector2.ONE
		return false
	var deltas := [Vector2(-6,4),Vector2(10,-10),Vector2(-4,6)]
	track.affine_scale += deltas[int(track.affine_frame) / 8]
	track.affine_frame += 1
	track.scale_pose = Vector2(256.0/track.affine_scale.x,256.0/track.affine_scale.y)
	# Source sub_8079A64 resets y2 on EACH affine frame, before hop velocity.
	# Native rectangle feet replace species-specific GBA pic-coordinate padding.
	var feet := int(track.actor.sprite.get_rect().end.y)
	track.displacement = Vector2(0, int((feet * 2 - mini(128, int(feet * 2 * 256 / track.affine_scale.y))) / 2))
	return true

static func _splash(track: Dictionary) -> void:
	match int(track.stage):
		0, 1:
			_affine(track)
			if track.stage == 0: track.velocity += 3
			track.displacement.y += track.velocity
			track.stage_count += 1
			if track.stage_count == 8:
				track.stage += 1
				track.stage_count = 0
		2:
			if track.velocity != 0:
				track.displacement.y -= 2
				track.velocity -= 2
			else:
				track.stage = 3
		3:
			if not _affine(track):
				track.hops_left -= 1
				if track.hops_left == 0:
					track.completed = true
				else:
					track.stage = 0
					track.affine_frame = 0
					track.affine_scale = Vector2(256,256)

extends RefCounted
class_name BattleAuxiliaryEffects
## Source General_DoomDesireHit BG1 light mask, owned by its sequence.
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

static func create_light(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Array[Dictionary]:
	var light := Sprite2D.new()
	light.texture = load(str(step.texture))
	light.centered = false
	light.region_enabled = true
	light.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	light.region_rect = Rect2(Vector2.ZERO, context.field_size)
	light.z_index = 10
	owner.add_child(light)
	var target := context.resolve("target")[0]
	var base := -135 if target.side == 1 else -10
	if context.actors.size() > 2:
		base = [-14,20,155,115][target.id] * -1
	return [{"kind":"source_doom_light", "age":0, "ticks":160, "node":light, "settings":step.duplicate(true), "source_side":target.side, "base_x":base, "update":update_light}]

static func update_light(track: Dictionary, _context: BattleAnimationContext) -> void:
	var age := int(track.age)
	var stage := mini(3, age / 22)
	var phase := age % 22
	var offset := int(track.settings.source_offsets[stage])
	track.node.region_rect.position.x = int(track.base_x) + offset * (1 if int(track.source_side) == 1 else -1)
	# Native alpha envelope retains repeated reveal/fade and final hold;
	# source hardware BLDCNT is not globally shared with other sequences.
	track.node.modulate.a = clampf(0.3 + float(phase if phase < 11 else 22-phase) / 16.0,0.3,0.8) if age < 88 else 0.55 * clampf(float(160-age)/20.0,0,1)

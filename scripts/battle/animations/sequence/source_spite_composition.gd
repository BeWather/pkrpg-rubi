extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Strict Spite180 entry point; ordinary pair lifecycle is shared with Nightmare171.
const Pair = preload("res://scripts/battle/animations/sequence/source_pair_composition.gd")
const STATE := "source_spite_monbg"

static func _source_args_match(args: Variant, expected: int) -> bool:
	return Pair._source_args_match(args,expected)

static func create(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Array[Dictionary]:
	return Pair.create_spite(step,context,owner)

static func sync(owner: Node2D) -> void:
	Pair.sync(owner)

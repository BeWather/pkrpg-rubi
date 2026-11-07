extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Nature Power's UNUSED animation-table alias previews Ancient Power's rocks.
## Gameplay atkCC plays only the selected environment move, never this alias.
static func create(step: Dictionary,context: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var binding: Dictionary=step.duplicate(true);binding.behavior="source_particle"
	var tracks: Array[Dictionary]=BattleEffectBehaviorRegistry.factories().source_particle.call(binding,context,owner)
	for track: Dictionary in tracks:BattleCounterSelected._blend_node(track.node,owner)
	return tracks

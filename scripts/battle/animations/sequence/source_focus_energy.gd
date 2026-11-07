extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Exact shared sub_80E1F8C clock; Move116 chooses white32767, General20 red31.
## Selector2 selects attacker OBJ only. Neither BG palettes nor flames are selected.
const Focus=preload("res://scripts/battle/animations/sequence/source_focus_setup.gd")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var tracks: Array[Dictionary]=Focus.create(s,c,owner)
	for track: Dictionary in tracks:track.update=advance
	return tracks
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	Focus.advance(t,c)
	if t.owner._held_blends.has(t.original_actor.id):t.owner._held_blends[t.original_actor.id].color=Color.WHITE

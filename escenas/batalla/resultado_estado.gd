extends RefCounted
class_name ResultadoEstado
## Resultado ya calculado de un movimiento de estado. `StatusEffectResolver`
## lo produce sin llamar de vuelta a `batalla.gd`/`BattleTurnController`/
## presentación (Decisión D2/D4, SDD `2026-09-14-move-effect-resolver`): quien
## lo recibe decide cuándo mostrar el mensaje y cuándo refrescar el visual.

## Mensaje de resultado a mostrar ("¡Pero falló!", "¡DEFENSOR quedó
## paralizado!", etc.).
var mensaje: String = ""
## true si el handler aplicó su efecto (protección activada, parálisis
## aplicada, etc.); false si falló (objetivo inmune, ya con estado, etc.).
var aplicado: bool = false
## No nulo únicamente cuando el handler cambió un estado persistente que
## necesita refrescar el ícono de estado en pantalla (parálisis, tóxico); el
## llamador debe pasar este valor a `_actualizar_estado_visual_pokemon()`
## (Decisión D2 — el resolver nunca llama a esa función directamente).
var pokemon_a_refrescar_visual: BasePokemon = null
## Otros Pokémon cuyo icono de estado también hay que refrescar (SINCRONÍA
## pasa el estado al atacante).
var pokemones_a_refrescar_extra: Array[BasePokemon] = []
## Mensajes que siguen a `mensaje`, uno por caja de texto (p. ej. Danza
## Dragón: "¡ATAQUE de X\nsubió!" y luego "¡VELOC. de X\nsubió!").
var mensajes_adicionales: PackedStringArray = PackedStringArray()
## No nulo cuando cambió algún nivel de característica: el llamador reproduce
## la animación de subida/bajada sobre este Pokémon antes de los mensajes.
var pokemon_cambio_estadistica: BasePokemon = null
var cambio_estadistica_sube: bool = true
var source_stat_animation: int=-1
## Animación de estado (p. ej. "ruby:status/1") sobre `estado_animado_pokemon`
## justo antes del mensaje número `estado_animado_indice` (0 = `mensaje`, 1 = el
## primero de `mensajes_adicionales`...): Contoneo anima la subida y después la confusión.
var estado_animado_clave: String = ""
var estado_animado_pokemon: BasePokemon = null
var estado_animado_indice: int = -1

## Presentation is independent of gameplay mutation (e.g. Splash).
var presentation_requested: bool = false

func should_present_animation() -> bool:
	return aplicado or presentation_requested

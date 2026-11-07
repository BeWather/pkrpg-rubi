extends RefCounted
class_name MoveAnimationContext
## Lo que una animación de movimiento necesita para reproducirse (Etapa 3,
## SDD 2026-09-14-battle-architecture-split). `batalla` es una referencia de
## vuelta a la composition root — mismo patrón pragmático de Etapa 1/2
## (`BattleIntroController`/`MoveResolver`): todavía no existe
## `BattlePresentationController` (Etapa 4) que sea dueño exclusivo de los
## slots, así que las animaciones alcanzan `get_tree()` y las utilidades
## públicas (`emitir_particulas_pokeball`, `aplicar_offset`) a través suyo.

var batalla  # composition root (batalla.gd) — sin tipo estático a propósito,
             # igual que BattleIntroController._b (ver ese archivo).
var slot_atacante: BattleSlot
var slot_defensor: BattleSlot
# Presentation metadata only. The domain scheduler owns actual hit/turn execution.
var action_id: int = 0
var phase: String = "hit"
var authoritative_action := false
var target_slots: Array[BattleSlot] = []
var source_move_turn: int = 0
var source_hit_index: int = 0
var source_power: int = 0
var source_power_override: int=-1
var source_damage: int = 0
var source_counter_inputs: Dictionary = {}
## Concurso (DoMoveAnim de src/contest.c): marcas fijas de la escena nativa en coordenadas del campo, con las claves
## centro_atacante, base_atacante, centro_defensor y base_defensor. Vacío = batalla: salen de los slots.
var geometria_concurso: Dictionary = {}

static func nueva(batalla_, slot_atacante_: BattleSlot, slot_defensor_: BattleSlot) -> MoveAnimationContext:
	var contexto := MoveAnimationContext.new()
	contexto.batalla = batalla_
	contexto.slot_atacante = slot_atacante_
	contexto.slot_defensor = slot_defensor_
	return contexto

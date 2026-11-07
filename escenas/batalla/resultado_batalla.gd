## Shared battle outcome enum.
##
## Single source of truth for battle result values, replacing the implicit
## magic-int contract (`callback_batalla.call(0|1|2)`) between `batalla.gd`
## and `OverworldBattleManager.gd`. Ordinals are preserved exactly to keep
## the callback contract behavior-identical to before this change.
extends RefCounted
class_name ResultadoBatalla

enum Valor {
	VICTORIA_JUGADOR = 0,
	VICTORIA_ENEMIGO = 1,
	HUIDA = 2,
	EMPATE = 3,
	## El jugador atrapó al Pokémon salvaje (pokeruby B_OUTCOME_CAUGHT).
	CAPTURA = 4,
}


## true si el combate acabó con el jugador derrotado (política de derrota:
## volver al último punto de curación). Victoria, huida, empate y captura
## terminan el combate sin derrota.
static func es_derrota_jugador(valor: Valor) -> bool:
	return valor == Valor.VICTORIA_ENEMIGO

## resultados_combate.gd
## Equivalente mínimo a gBattleResults de pokeruby (include/battle.h): lo que el
## overworld consulta del último combate al terminar (GabbyAndTyBeforeInterview).
##
## Se reinicia al empezar cada combate (battle_main.c:3496) y lo rellena el motor:
## - pokemon_1 / pokemon_2 (poke1Species / opponentSpecies): especies de los
##   Pokémon del jugador en el campo al acabar (HandleEndTurn_FinishBattle). Pese
##   al nombre del decomp, opponentSpecies es el SEGUNDO Pokémon del jugador.
## - ultimo_movimiento (lastUsedMove): último movimiento elegido por el lado del
##   jugador (HandleAction_UseMove).
## - jugador_danado (playerMonWasDamaged): un Pokémon del jugador recibió daño > 0
##   (atk0B_healthbarupdate).
## - debilitados_jugador (playerFaintCounter): Pokémon del jugador debilitados
##   (atk19_tryfaintmon), tope 255.
## - curaciones_jugador (playerHealInBattleCount): objetos de PS (no revivir)
##   usados en un Pokémon del jugador en el campo (PokemonUseItemEffects), tope 255.
## - master_ball / balls_lanzadas (usedMasterBall / usedBalls): balls lanzadas en
##   atkEF_handleballthrow; contra un entrenador la ball se bloquea antes y no cuenta.
extends RefCounted
class_name ResultadosCombate

const TOPE_CONTADOR: int = 0xFF
const BALL_SAFARI: String = "SAFARIBALL"
const BALL_MASTER: String = "MASTERBALL"

## Resultados del combate en curso o del último terminado.
static var actual: ResultadosCombate = ResultadosCombate.new()

## nombre_interno de las especies ("" = SPECIES_NONE).
var pokemon_1: String = ""
var pokemon_2: String = ""
## nombre_interno del movimiento ("" = MOVE_NONE).
var ultimo_movimiento: String = ""
var jugador_danado: bool = false
var debilitados_jugador: int = 0
var curaciones_jugador: int = 0
var master_ball: bool = false
var balls_lanzadas: int = 0


## Inicio de combate: todo a cero.
static func reiniciar() -> void:
	actual = ResultadosCombate.new()


## HandleAction_UseMove: el lado del jugador usa `nombre_interno`.
static func registrar_movimiento(nombre_interno: String) -> void:
	if not nombre_interno.is_empty():
		actual.ultimo_movimiento = nombre_interno


## atk0B_healthbarupdate sobre un Pokémon del jugador con daño > 0.
static func registrar_dano_jugador() -> void:
	actual.jugador_danado = true


## atk19_tryfaintmon de un Pokémon del jugador.
static func registrar_debilitado_jugador() -> void:
	actual.debilitados_jugador = mini(actual.debilitados_jugador + 1, TOPE_CONTADOR)


## Objeto de PS (no revivir) usado en un Pokémon del jugador en el campo.
static func registrar_curacion_jugador() -> void:
	actual.curaciones_jugador = mini(actual.curaciones_jugador + 1, TOPE_CONTADOR)


## atkEF_handleballthrow tras el bloqueo de entrenador: la SAFARI BALL no cuenta.
static func registrar_ball(nombre_interno: String) -> void:
	var ball := nombre_interno.to_upper()
	if ball == BALL_SAFARI:
		return
	if ball == BALL_MASTER:
		actual.master_ball = true
	else:
		actual.balls_lanzadas = mini(actual.balls_lanzadas + 1, TOPE_CONTADOR)


## HandleEndTurn_FinishBattle: el primero con especie es pokemon_1; el siguiente,
## pokemon_2 (solo en dobles).
static func registrar_fin(activos_jugador: Array) -> void:
	for pokemon in activos_jugador:
		if not (pokemon is BasePokemon):
			continue
		var especie: String = (pokemon as BasePokemon).nombre_interno
		if actual.pokemon_1.is_empty():
			actual.pokemon_1 = especie
		else:
			actual.pokemon_2 = especie


## usedMasterBall o algún usedBalls[i] != 0.
func uso_balls() -> bool:
	return master_ball or balls_lanzadas > 0

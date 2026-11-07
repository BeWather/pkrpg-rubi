class_name EstadoConcurso
extends RefCounted
## Estado global de un concurso: `struct Contest` (sContest), `ContestAppealMoveResults`
## y `ContestExcitement` de pokeruby, más las puntuaciones de src/contest.c.

const NUM_CONCURSANTES: int = 4
const NUM_APELACIONES: int = 5
const NIVEL_APLAUSO_MAXIMO: int = 5

## gSpecialVar_ContestCategory (Movimiento.CategoriaConcurso) y gSpecialVar_ContestRank
## (0 NORMAL … 3 EXPERTO).
var categoria: int = 0
var nivel: int = 0
var concursantes: Array[ConcursanteConcurso] = []
## gContestPlayerMonIndex (3 fuera de los concursos por cable).
var indice_jugador: int = 3

## sContest.appealNumber (0..4) y turnNumber (0..3).
var numero_apelacion: int = 0
var numero_turno: int = 0
## sContest.applauseLevel (0..5); persiste entre apelaciones.
var aplausos: int = 0
## sContest.playerMoveChoice.
var eleccion_jugador: int = 0
## sContest.moveHistory / excitementHistory [apelación][concursante] (los lee la IA).
var historial_movimientos: Array = []
var historial_emocion: Array = []

## gContestantTurnOrder (= eContestAppealResults.turnOrder): posición 0..3 de cada
## concursante en la apelación en curso.
var orden: Array[int] = [0, 1, 2, 3]

# --- ContestAppealMoveResults del turno en curso ---
## eContestAppealResults.contestant.
var actor: int = 0
## jam / jam2.
var interferencia: int = 0
var interferencia2: int = 0
## unnervedPokes.
var marcados: Array[bool] = [false, false, false, false]

# --- ContestExcitement ---
## moveExcitement (-1, 0, +1), excitementFrozen, excitementFreezer y excitementAppealBonus.
var emocion_mov: int = 0
var emocion_congelada: bool = false
var congelador: int = 0
var bonus_emocion: int = 0

# --- Puntuaciones ---
## gContestMonRound1Points, gContestMonAppealPointTotals, Round2Points, TotalPoints y
## gContestFinalStandings (puesto 0..3 de cada concursante).
var puntos_ronda1: Array[int] = [0, 0, 0, 0]
var totales_apelacion: Array[int] = [0, 0, 0, 0]
var puntos_ronda2: Array[int] = [0, 0, 0, 0]
var puntos_finales: Array[int] = [0, 0, 0, 0]
var puestos_finales: Array[int] = [0, 1, 2, 3]
var terminado: bool = false


func _init() -> void:
	historial_movimientos.clear()
	historial_emocion.clear()
	for i in NUM_APELACIONES:
		historial_movimientos.append([0, 0, 0, 0])
		historial_emocion.append([0, 0, 0, 0])


## Índice del concursante que actúa en la posición `posicion`.
func concursante_en(posicion: int) -> int:
	for i in NUM_CONCURSANTES:
		if orden[i] == posicion:
			return i
	return -1


## ScrSpecial_GetContestWinnerIdx: el que quedó primero.
func ganador() -> int:
	for i in NUM_CONCURSANTES:
		if puestos_finales[i] == 0:
			return i
	return 0

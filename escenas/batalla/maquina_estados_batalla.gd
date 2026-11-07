## Battle phase state machine.
##
## Owns the three phase enums promoted from `batalla.gd`'s previously
## unnamed ones, with identical ordinals, plus an explicit transition table.
## `batalla.gd` delegates every phase *write* to this machine while every
## *read* site (`fase == X`, `match fase`) stays source-compatible via
## getter-backed properties in `batalla.gd`. This machine owns state
## legality only — phase *actions* (`ejecutar_ronda()`, `revisar_ronda()`,
## animations, audio, UI) stay in `batalla.gd`.
##
## The transition tables below were built by enumerating every
## `fase = X` / `fase_ronda = X` write site in `batalla.gd` (27 sites total)
## and widening the design draft to match every transition actually
## observed in the code, per the behavior-freeze decision — nothing here
## is stricter than what the pre-refactor code already allowed.
extends RefCounted
class_name MaquinaEstadosBatalla

enum Fase {
	INICIO = 0,
	INPUT = 1,
	RONDA = 2,
	CAMBIO_POKEMON = 3,
	FIN_BATALLA = 4,
}

enum SubfaseInicio {
	INI_SUELO = 0,
	INI_ICONOS_POKEBALL = 1,
	INI_RIVAL_SALE = 2,
	INI_JUGADOR_SALE = 3,
}

enum FaseRonda {
	PRIORIDADES = 0,
	TURNO_JUGADOR = 1,
	TURNO_ENEMIGO = 2,
	REVISAR_RONDA = 3,
}

## Fase.INICIO self-loop covers the single `_ejecutar_intro()` call that
## (re)assigns INICIO to its own default value at battle start.
## Fase.INPUT self-loop covers re-entering the input menu from itself
## (invalid move reselection, `_on_input_continuar()`'s INPUT case, etc.).
## Fase.CAMBIO_POKEMON self-loop covers re-forcing pokemon selection after
## a cancelled forced-change attempt (`_on_seleccion_cancelada()`).
const TRANSICIONES_FASE: Dictionary = {
	Fase.INICIO:          [Fase.INICIO, Fase.INPUT, Fase.FIN_BATALLA],
	Fase.INPUT:           [Fase.INPUT, Fase.RONDA, Fase.CAMBIO_POKEMON, Fase.FIN_BATALLA],
	Fase.RONDA:           [Fase.INPUT, Fase.CAMBIO_POKEMON, Fase.FIN_BATALLA],
	Fase.CAMBIO_POKEMON:  [Fase.INPUT, Fase.RONDA, Fase.CAMBIO_POKEMON, Fase.FIN_BATALLA],
	Fase.FIN_BATALLA:     [],
}

## FaseRonda.REVISAR_RONDA self-loop covers `revisar_ronda()`'s own
## early-return branches (skipping a fainted side's turn), which
## reassign REVISAR_RONDA to itself before recursing.
const TRANSICIONES_RONDA: Dictionary = {
	FaseRonda.PRIORIDADES:    [FaseRonda.TURNO_JUGADOR, FaseRonda.TURNO_ENEMIGO],
	FaseRonda.TURNO_JUGADOR:  [FaseRonda.REVISAR_RONDA],
	FaseRonda.TURNO_ENEMIGO:  [FaseRonda.REVISAR_RONDA],
	FaseRonda.REVISAR_RONDA:  [FaseRonda.REVISAR_RONDA, FaseRonda.TURNO_JUGADOR, FaseRonda.TURNO_ENEMIGO, FaseRonda.PRIORIDADES],
}

## Linear order SubfaseInicio advances through; strictly sequential,
## no table needed (see `avanzar_subfase_inicio()`).
const ORDEN_SUBFASE_INICIO: Array[SubfaseInicio] = [
	SubfaseInicio.INI_SUELO,
	SubfaseInicio.INI_ICONOS_POKEBALL,
	SubfaseInicio.INI_RIVAL_SALE,
	SubfaseInicio.INI_JUGADOR_SALE,
]

signal fase_cambiada(anterior: Fase, nueva: Fase)
signal transicion_rechazada(actual: Fase, destino: Fase)

var fase_actual: Fase = Fase.INICIO
var fase_ronda_actual: FaseRonda = FaseRonda.PRIORIDADES
var subfase_inicio_actual: SubfaseInicio = SubfaseInicio.INI_SUELO

var _historial: Array = []


static func nueva() -> MaquinaEstadosBatalla:
	return MaquinaEstadosBatalla.new()


func puede_cambiar_fase(destino: Fase) -> bool:
	return TRANSICIONES_FASE.get(fase_actual, []).has(destino)


## Changes `fase_actual` if the transition is legal. Rejected transitions
## are logged and return `false` without mutating state — they never
## silently assign.
func cambiar_fase(destino: Fase) -> bool:
	if not puede_cambiar_fase(destino):
		_loggear("Transición de fase rechazada: %s -> %s" % [Fase.keys()[fase_actual], Fase.keys()[destino]])
		transicion_rechazada.emit(fase_actual, destino)
		return false
	var anterior := fase_actual
	fase_actual = destino
	_historial.append({"tipo": "fase", "anterior": anterior, "nueva": destino})
	fase_cambiada.emit(anterior, destino)
	return true


func cambiar_fase_ronda(destino: FaseRonda) -> bool:
	if not TRANSICIONES_RONDA.get(fase_ronda_actual, []).has(destino):
		_loggear("Transición de fase_ronda rechazada: %s -> %s" % [FaseRonda.keys()[fase_ronda_actual], FaseRonda.keys()[destino]])
		return false
	var anterior := fase_ronda_actual
	fase_ronda_actual = destino
	_historial.append({"tipo": "fase_ronda", "anterior": anterior, "nueva": destino})
	return true


## Advances subfase_inicio to the next value in its strictly linear order.
## Clamps at the last value (no-op past INI_JUGADOR_SALE).
func avanzar_subfase_inicio() -> void:
	var indice_actual := ORDEN_SUBFASE_INICIO.find(subfase_inicio_actual)
	var siguiente_indice: int = mini(indice_actual + 1, ORDEN_SUBFASE_INICIO.size() - 1)
	subfase_inicio_actual = ORDEN_SUBFASE_INICIO[siguiente_indice]
	_historial.append({"tipo": "subfase_inicio", "nueva": subfase_inicio_actual})


## Resets subfase_inicio back to the first value. Mirrors the single
## `subfase_inicio = INI_SUELO` write site inside `_ejecutar_intro()`.
func reiniciar_subfase_inicio() -> void:
	subfase_inicio_actual = SubfaseInicio.INI_SUELO
	_historial.append({"tipo": "subfase_inicio", "nueva": subfase_inicio_actual})


func historial() -> Array:
	return _historial.duplicate()


func _loggear(mensaje: String) -> void:
	print("[⚙️⚔️MaquinaEstadosBatalla] %s" % mensaje)

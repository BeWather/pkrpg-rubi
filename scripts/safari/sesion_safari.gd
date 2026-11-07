## sesion_safari.gd
## Estado de la partida SAFARI de la ZONA SAFARI (pokeruby `src/safari_zone.c`):
##
##   EnterSafariMode()   → `entrar()`  : FLAG_SYS_SAFARI_MODE, 30 SAFARI BALLS y 500 pasos.
##   ExitSafariMode()    → `salir()`   : bandera, BALLS y pasos a cero.
##   SafariZoneTakeStep()→ `dar_paso()`: resta un paso; al llegar a 0 la partida termina.
##   VAR_SAFARI_ZONE_STATE → `estado_zona()`: 0 normal, 1 acaba de terminar (la ENTRADA saca al
##                           jugador del pasillo y llama a ExitSafariMode), 2 acaba de entrar (el
##                           CAMPISTA de la ZONA SE aparta y el jugador baja un paso).
##
## Todo vive en `datos_persistentes` de la partida (banderas y contadores existentes): no hay
## campos nuevos, así que las partidas antiguas cargan sin migración. En Rubí `gNumSafariBalls` y
## `gSafariZoneStepCounter` son EWRAM (no se guardan) y el menú de pausa cambia GUARDAR por RETIRARSE
## dentro de la ZONA SAFARI; aquí el menú hace lo mismo, así que no se puede guardar a medias. Si
## se cargase una partida guardada dentro, la sesión sigue donde estaba.
##
## Contrato para el combate SAFARI (todavía no existe, ver documentacion/20261019-zona-safari.md):
## `balls_restantes()` y `gastar_ball()` son la fuente única de las SAFARI BALLS (viven aparte de la
## mochila); cuando `gastar_ball()` devuelve 0, el combate llama a
## `AdministradorMapa.finalizar_safari(SesionSafari.Motivo.BALLS)` al volver al mapa
## (sub_80C824C: gNumSafariBalls == 0 con gBattleOutcome == B_OUTCOME_NO_SAFARI_BALLS).
class_name SesionSafari
extends RefCounted

## "That will be ¥500, please."
const PRECIO_ENTRADA: int = 500
## gNumSafariBalls = 30.
const BALLS_INICIALES: int = 30
## gSafariZoneStepCounter = 500 (el texto de la ROM española dice «500 pasos»).
const PASOS_INICIALES: int = 500

## FLAG_SYS_SAFARI_MODE.
const BANDERA_MODO: String = "safari_modo"
## gNumSafariBalls.
const CONTADOR_BALLS: String = "safari_balls"
## gSafariZoneStepCounter.
const CONTADOR_PASOS: String = "safari_pasos"
## VAR_SAFARI_ZONE_STATE.
const CONTADOR_ESTADO: String = "safari_zona_estado"
## GAME_STAT_ENTERED_SAFARI_ZONE.
const CONTADOR_VISITAS: String = "safari_visitas"

## Valores de VAR_SAFARI_ZONE_STATE.
enum Estado {
	NORMAL = 0,
	TERMINADA = 1,
	ENTRANDO = 2,
}

## Por qué acaba la partida.
enum Motivo {
	PASOS,
	BALLS,
	RETIRADA,
}

## Mensaje de cada motivo (UnknownString_81C34E4, _81C3514 y la recepción al retirarse).
const TEXTO_FIN: Dictionary = {
	Motivo.PASOS: "SAFARI_FIN_TIEMPO",
	Motivo.BALLS: "SAFARI_FIN_BALLS",
}


## GetSafariZoneFlag.
static func activa() -> bool:
	return SistemaGuardado.get_flag(BANDERA_MODO)


static func balls_restantes() -> int:
	return SistemaGuardado.get_contador(CONTADOR_BALLS)


static func pasos_restantes() -> int:
	return SistemaGuardado.get_contador(CONTADOR_PASOS)


## EnterSafariMode. Nunca cobra: el pago es cosa de la taquilla.
static func entrar() -> void:
	SistemaGuardado.incrementar_contador(CONTADOR_VISITAS)
	SistemaGuardado.set_flag(BANDERA_MODO, true)
	SistemaGuardado.set_contador(CONTADOR_BALLS, BALLS_INICIALES)
	SistemaGuardado.set_contador(CONTADOR_PASOS, PASOS_INICIALES)


## ExitSafariMode.
static func salir() -> void:
	SistemaGuardado.set_flag(BANDERA_MODO, false)
	SistemaGuardado.set_contador(CONTADOR_BALLS, 0)
	SistemaGuardado.set_contador(CONTADOR_PASOS, 0)


## SafariZoneTakeStep: cuenta un paso. true si era el último (la partida termina).
static func dar_paso() -> bool:
	if not activa():
		return false
	var restantes := maxi(pasos_restantes() - 1, 0)
	SistemaGuardado.set_contador(CONTADOR_PASOS, restantes)
	return restantes == 0


## Lanza una SAFARI BALL (--gNumSafariBalls). Devuelve las que quedan; 0 = se acabaron.
static func gastar_ball() -> int:
	if not activa() or balls_restantes() <= 0:
		return 0
	var restantes := balls_restantes() - 1
	SistemaGuardado.set_contador(CONTADOR_BALLS, restantes)
	return restantes


## TryStartStepCountScript → SafariZoneTakeStep: cuenta el paso y, si era el último, pide al
## administrador (`finalizar_safari`) que cierre la partida. true = ese paso termina aquí.
static func procesar_paso(administrador: Object) -> bool:
	if not dar_paso():
		return false
	administrador.finalizar_safari(Motivo.PASOS)
	return true


## sub_80C824C, al volver de un combate salvaje: sin BALLS la partida termina. true = termina.
static func procesar_fin_de_combate(administrador: Object) -> bool:
	if not activa() or balls_restantes() > 0:
		return false
	administrador.finalizar_safari(Motivo.BALLS)
	return true


## VAR_SAFARI_ZONE_STATE.
static func estado_zona() -> int:
	return SistemaGuardado.get_contador(CONTADOR_ESTADO)


static func fijar_estado_zona(estado: int) -> void:
	SistemaGuardado.set_contador(CONTADOR_ESTADO, estado)

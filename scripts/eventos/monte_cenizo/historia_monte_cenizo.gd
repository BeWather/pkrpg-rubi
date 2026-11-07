## historia_monte_cenizo.gd
## Estado persistente del MONTE CENIZO (pokeruby data/maps/MtChimney, data/scripts/magma_chimney.inc) y del
## TELEFÉRICO: banderas de SistemaGuardado con su equivalente en Rubí. No es un nodo: lo consultan el guion
## de EventoMonteCenizo, los NPC de la escena, PUEBLO PARDAL, la CASCADA METEORO y los
## tests (patrón HistoriaCascadaMeteoro / HistoriaMalvalona).
##
## Qué banderas de Rubí se juntan aquí:
## - FLAG_DEFEATED_EVIL_TEAM_MT_CHIMNEY, FLAG_HIDE_PROF_COSMO_METEOR_FALLS y la inversa de
##   FLAG_HIDE_PROF_COSMO_FALLARBOR se activan en el mismo guion (la salida de AQUILES): una sola bandera,
##   `monte_cenizo_equipo_derrotado`, que ya usaban PUEBLO PARDAL y la CASCADA METEORO.
## - FLAG_HIDE_EVIL_TEAM_MT_CHIMNEY (los MAGMA, MAGNO y los perros) se activa a media escena, tras el
##   fundido; FLAG_HIDE_OTHER_TEAM_MT_CHIMNEY (el EQUIPO AQUA y sus perros) al final.
## - FLAG_HIDE_MT_CHIMNEY_PEOPLE está activa desde el principio de la partida (los entrenadores y la
##   GALLETERA no están) y la apaga el OnTransition de PUEBLO LAVACALDA si ya se venció al equipo malo:
##   `monte_cenizo_gente_visible` es su inversa y la activa EventoMonteCenizo al cargar el monte con el equipo
##   ya vencido (Rubí pide haber pasado por PUEBLO LAVACALDA; ver documentacion/20261017-monte-cenizo-fase1.md).
## - VAR_CABLE_CAR_STATION_STATE (0, 1 o 2) es el contador `teleferico_estado_estacion`.
class_name HistoriaMonteCenizo
extends RefCounted

## FLAG_DEFEATED_EVIL_TEAM_MT_CHIMNEY (+ FLAG_HIDE_PROF_COSMO_METEOR_FALLS y la inversa de
## FLAG_HIDE_PROF_COSMO_FALLARBOR).
const BANDERA_EQUIPO_DERROTADO: String = "monte_cenizo_equipo_derrotado"
## FLAG_HIDE_EVIL_TEAM_MT_CHIMNEY: los MAGMA, MAGNO y sus perros ya no están.
const BANDERA_MAGMA_FUERA: String = "monte_cenizo_magma_se_fue"
## FLAG_HIDE_OTHER_TEAM_MT_CHIMNEY: AQUILES, el EQUIPO AQUA y sus perros ya no están.
const BANDERA_AQUA_FUERA: String = "monte_cenizo_aqua_se_fue"
## Inversa de FLAG_HIDE_MT_CHIMNEY_PEOPLE: los entrenadores y la GALLETERA están en el monte.
const BANDERA_GENTE: String = "monte_cenizo_gente_visible"
## FLAG_EVIL_LEADER_PLEASE_STOP: AQUILES ya te pidió que detuvieras al EQUIPO MAGMA.
const BANDERA_AQUILES_AVISADO: String = "monte_cenizo_aquiles_avisado"
## FLAG_RECEIVED_METEORITE: ya sacaste el METEORITO de la máquina.
const BANDERA_METEORITO: String = "monte_cenizo_meteorito_recibido"
## VAR_CABLE_CAR_STATION_STATE (src/cable_car.c y los scripts de las dos estaciones): 0 reposo, 1 llegada
## al MONTE CENIZO (subiendo), 2 llegada a la RUTA 112 (bajando).
const CONTADOR_ESTADO_ESTACION: String = "teleferico_estado_estacion"
## GAME_STAT_RODE_CABLE_CAR.
const CONTADOR_VIAJES: String = "teleferico_viajes"

## Qué dice la máquina del METEORITO (MtChimney_EventScript_15D17D).
enum Maquina { ENERGIA, SACAR, MUDA }

## Clave de SistemaGuardado → [tipo, equivalente en Gen 3].
const PERSISTENTE := {
	BANDERA_EQUIPO_DERROTADO: ["bandera", "FLAG_DEFEATED_EVIL_TEAM_MT_CHIMNEY / FLAG_HIDE_PROF_COSMO_METEOR_FALLS"],
	BANDERA_MAGMA_FUERA: ["bandera", "FLAG_HIDE_EVIL_TEAM_MT_CHIMNEY"],
	BANDERA_AQUA_FUERA: ["bandera", "FLAG_HIDE_OTHER_TEAM_MT_CHIMNEY"],
	BANDERA_GENTE: ["bandera", "!FLAG_HIDE_MT_CHIMNEY_PEOPLE"],
	BANDERA_AQUILES_AVISADO: ["bandera", "FLAG_EVIL_LEADER_PLEASE_STOP"],
	BANDERA_METEORITO: ["bandera", "FLAG_RECEIVED_METEORITE"],
}


## ¿Ya se venció al EQUIPO MAGMA en el monte?
static func equipo_derrotado() -> bool:
	return SistemaGuardado.get_flag(BANDERA_EQUIPO_DERROTADO)


## Texto de la máquina: sin vencer al equipo, «almacena energía»; vencido y con el METEORITO aún dentro,
## pregunta si quieres sacarlo; sacado, no responde.
static func estado_maquina() -> Maquina:
	if not equipo_derrotado():
		return Maquina.ENERGIA
	if SistemaGuardado.get_flag(BANDERA_METEORITO):
		return Maquina.MUDA
	return Maquina.SACAR


## Final del guion de MAGNO: setflag FLAG_HIDE_OTHER_TEAM_MT_CHIMNEY, FLAG_DEFEATED_EVIL_TEAM_MT_CHIMNEY,
## clearflag FLAG_HIDE_PROF_COSMO_FALLARBOR y setflag FLAG_HIDE_PROF_COSMO_METEOR_FALLS.
static func marcar_equipo_derrotado() -> void:
	SistemaGuardado.set_flag(BANDERA_AQUA_FUERA, true)
	SistemaGuardado.set_flag(BANDERA_EQUIPO_DERROTADO, true)


## Equivalente de LavaridgeTown_OnTransition: call_if_set FLAG_DEFEATED_EVIL_TEAM_MT_CHIMNEY → clearflag
## FLAG_HIDE_MT_CHIMNEY_PEOPLE. Devuelve true si la bandera quedó activa.
static func mostrar_gente_si_toca() -> bool:
	if equipo_derrotado():
		SistemaGuardado.set_flag(BANDERA_GENTE, true)
	return SistemaGuardado.get_flag(BANDERA_GENTE)


## VAR_CABLE_CAR_STATION_STATE.
static func estado_estacion() -> int:
	return SistemaGuardado.get_contador(CONTADOR_ESTADO_ESTACION)


static func fijar_estado_estacion(valor: int) -> void:
	SistemaGuardado.set_contador(CONTADOR_ESTADO_ESTACION, valor)


## Valores actuales de todo lo persistente (depuración y tests).
static func instantanea() -> Dictionary:
	var datos := {}
	for clave: String in PERSISTENTE:
		datos[clave] = SistemaGuardado.get_flag(clave)
	datos[CONTADOR_ESTADO_ESTACION] = estado_estacion()
	datos[CONTADOR_VIAJES] = SistemaGuardado.get_contador(CONTADOR_VIAJES)
	return datos


## Restaura una instantánea (o, vacía, la partida antes de pisar el monte).
static func restablecer(datos: Dictionary = {}) -> void:
	for clave: String in PERSISTENTE:
		SistemaGuardado.set_flag(clave, bool(datos.get(clave, false)))
	SistemaGuardado.set_contador(CONTADOR_ESTADO_ESTACION, int(datos.get(CONTADOR_ESTADO_ESTACION, 0)))
	SistemaGuardado.set_contador(CONTADOR_VIAJES, int(datos.get(CONTADOR_VIAJES, 0)))

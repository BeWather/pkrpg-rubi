## historia_cascada_meteoro.gd
## Estado persistente de la CASCADA METEORO (pokeruby data/maps/MeteorFalls_*): banderas de
## SistemaGuardado con su equivalente en Rubí. No es un nodo: lo consultan el guion de
## EventoCascadaMeteoro, los NPC de la escena y los tests (patrón HistoriaMalvalona).
##
## Lo que Rubí reparte entre VAR_METEOR_FALLS_STATE y las banderas HIDE de los objetos
## sale aquí de una sola bandera:
## - VAR_METEOR_FALLS_STATE pasa de 0 a 1 en el mismo guion que `removeobject 5/6`
##   (FLAG_HIDE_GRUNTS_METEOR_FALLS_1F), así que "estado 1" y "soldados ocultos" son lo mismo.
## - FLAG_HIDE_OTHER_TEAM_METEOR_FALLS_1F (el EQUIPO AQUA) solo existe durante el guion
##   (addobject / removeobject): no deja rastro y no necesita bandera.
class_name HistoriaCascadaMeteoro
extends RefCounted

## VAR_METEOR_FALLS_STATE == 1 y FLAG_HIDE_GRUNTS_METEOR_FALLS_1F: los dos soldados MAGMA
## y el EQUIPO AQUA ya se han ido hacia el MONTE CENIZO con el METEORITO.
const BANDERA_EQUIPO_SE_FUE: String = "cascada_meteoro_equipo_se_fue"
## FLAG_MET_PROF_COSMO: el PROF. COZMO ya contó su historia.
const BANDERA_COZMO_CONOCIDO: String = "cascada_meteoro_cosmo_conocido"
## FLAG_HIDE_GRUNTS_BLOCKING_CABLE_CAR (RUTA 112, SoldadoMagma1/2): el guion la activa.
const BANDERA_SOLDADOS_TELEFERICO: String = "ruta_112_soldados_teleferico_ocultos"
## FLAG_HIDE_PROF_COSMO_METEOR_FALLS: el MONTE CENIZO la activa junto con
## FLAG_DEFEATED_EVIL_TEAM_MT_CHIMNEY (pendiente de migrar; PUEBLO PARDAL ya la usa).
const BANDERA_COZMO_OCULTO: String = "monte_cenizo_equipo_derrotado"

## Clave de SistemaGuardado → [tipo, equivalente en Gen 3].
const PERSISTENTE := {
	BANDERA_EQUIPO_SE_FUE: ["bandera", "VAR_METEOR_FALLS_STATE == 1 / FLAG_HIDE_GRUNTS_METEOR_FALLS_1F"],
	BANDERA_COZMO_CONOCIDO: ["bandera", "FLAG_MET_PROF_COSMO"],
	BANDERA_SOLDADOS_TELEFERICO: ["bandera", "FLAG_HIDE_GRUNTS_BLOCKING_CABLE_CAR"],
}


## ¿Toca todavía el guion de los dos equipos (coord_event (14,18) con VAR_METEOR_FALLS_STATE == 0)?
static func escena_pendiente() -> bool:
	return not SistemaGuardado.get_flag(BANDERA_EQUIPO_SE_FUE)


## Final del guion: setflag FLAG_HIDE_GRUNTS_BLOCKING_CABLE_CAR + setvar VAR_METEOR_FALLS_STATE, 1
## (+ las banderas HIDE de los soldados al hacer removeobject).
static func marcar_equipo_fuera() -> void:
	SistemaGuardado.set_flag(BANDERA_EQUIPO_SE_FUE, true)
	SistemaGuardado.set_flag(BANDERA_SOLDADOS_TELEFERICO, true)


## Valores actuales de todo lo persistente (depuración y tests).
static func instantanea() -> Dictionary:
	var datos := {}
	for clave: String in PERSISTENTE:
		datos[clave] = SistemaGuardado.get_flag(clave)
	return datos


## Restaura una instantánea (o, vacía, la partida antes de pisar la cueva).
static func restablecer(datos: Dictionary = {}) -> void:
	for clave: String in PERSISTENTE:
		SistemaGuardado.set_flag(clave, bool(datos.get(clave, false)))

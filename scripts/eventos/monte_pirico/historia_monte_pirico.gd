## historia_monte_pirico.gd
## Estado persistente del MONTE PÍRICO (pokeruby data/maps/MtPyre_Summit y data/scripts/magma_summit.inc):
## banderas de SistemaGuardado con su equivalente en Rubí. No es un nodo: lo consultan el guion de
## EventoMontePirico, los NPC de la cima, CIUDAD PORTUAL y los tests (patrón HistoriaMonteCenizo).
##
## VAR_MT_PYRE_STATE (`monte_pirico_estado`): 0 al llegar a la cima (MAGNO sigue allí con el ORBE
## AZUL); 1 tras el robo (el equipo se va, la ancianita te da la ESFERA ROJA); 2 cuando se vence a
## GROUDON en la CUEVA ANCESTRAL (MAGNO reaparece en la cima: FLAG_HIDE_LEADER_MT_PYRE_SUMMIT se
## apaga); 3 cuando MAGNO devuelve la ESFERA AZUL y se marcha. `legendario_escapo_cueva_marina` y
## `legendario_batalla_completada` (FLAG_LEGEND_ESCAPED_SEAFLOOR_CAVERN / FLAG_LEGENDARY_BATTLE_COMPLETED) las
## activan la CAVERNA ABISAL y la CUEVA ANCESTRAL (HistoriaArrecipolis), que además ponen el estado 2.
class_name HistoriaMontePirico
extends RefCounted

## FLAG_MT_PYRE_ORB_STOLEN (la leen la GUARIDA AQUA/MAGMA; no existe aún).
const BANDERA_ORBE_ROBADO: String = "monte_pirico_orbe_robado"
## VAR_MT_PYRE_STATE.
const CONTADOR_ESTADO: String = "monte_pirico_estado"
## FLAG_HIDE_LEADER_MT_PYRE_SUMMIT (MAGNO). Empieza sin activar: está en la cima al llegar.
const BANDERA_JEFE_OCULTO: String = "monte_pirico_cima_jefe_oculto"
## FLAG_HIDE_GRUNTS_MT_PYRE_SUMMIT (los tres soldados). Empieza sin activar.
const BANDERA_SOLDADOS_OCULTOS: String = "monte_pirico_cima_soldados_ocultos"
## FLAG_RECEIVED_RED_OR_BLUE_ORB (ITEM_RED_OR_BLUE_ORB es la ESFERA ROJA en Rubí).
const BANDERA_ESFERA_RECIBIDA: String = "monte_pirico_esfera_recibida"
## FLAG_RETURNED_RED_OR_BLUE_ORB.
const BANDERA_ESFERA_DEVUELTA: String = "monte_pirico_esfera_devuelta"
## FLAG_LEGENDARY_BATTLE_COMPLETED.
const BANDERA_LEGENDARIO_COMPLETADO: String = "legendario_batalla_completada"
## FLAG_LEGEND_ESCAPED_SEAFLOOR_CAVERN.
const BANDERA_LEGENDARIO_ESCAPO: String = "legendario_escapo_cueva_marina"
## FLAG_RECEIVED_CLEANSE_TAG (la ancianita de la 1F).
const BANDERA_AMULETO: String = "monte_pirico_amuleto_recibido"

## VAR_SLATEPORT_STATE == 1 (+ clearflag FLAG_HIDE_STERN_SLATEPORT y FLAG_HIDE_GABBY_AND_TY_SLATEPORT):
## la entrevista de CIUDAD PORTUAL (la usa ciudad_portual.tscn con bandera_mostrar).
const BANDERA_ENTREVISTA_PORTUAL: String = "portual_entrevista_babor"
## VAR_SLATEPORT_HARBOR_STATE (1: escena del submarino pendiente; la lee CAP. BABOR).
const CONTADOR_ESTADO_PUERTO: String = "portual_puerto_estado"

## ITEM_RED_ORB (ITEM_RED_OR_BLUE_ORB en la versión Rubí).
const OBJETO_ESFERA: String = "ESFERAROJA"

## Clave de SistemaGuardado → [tipo, equivalente en Gen 3].
const PERSISTENTE := {
	BANDERA_ORBE_ROBADO: ["bandera", "FLAG_MT_PYRE_ORB_STOLEN"],
	BANDERA_JEFE_OCULTO: ["bandera", "FLAG_HIDE_LEADER_MT_PYRE_SUMMIT"],
	BANDERA_SOLDADOS_OCULTOS: ["bandera", "FLAG_HIDE_GRUNTS_MT_PYRE_SUMMIT"],
	BANDERA_ESFERA_RECIBIDA: ["bandera", "FLAG_RECEIVED_RED_OR_BLUE_ORB"],
	BANDERA_ESFERA_DEVUELTA: ["bandera", "FLAG_RETURNED_RED_OR_BLUE_ORB"],
	BANDERA_LEGENDARIO_COMPLETADO: ["bandera", "FLAG_LEGENDARY_BATTLE_COMPLETED"],
	BANDERA_LEGENDARIO_ESCAPO: ["bandera", "FLAG_LEGEND_ESCAPED_SEAFLOOR_CAVERN"],
	BANDERA_AMULETO: ["bandera", "FLAG_RECEIVED_CLEANSE_TAG"],
	BANDERA_ENTREVISTA_PORTUAL: ["bandera", "VAR_SLATEPORT_STATE == 1"],
}


## VAR_MT_PYRE_STATE.
static func estado() -> int:
	return SistemaGuardado.get_contador(CONTADOR_ESTADO)


static func fijar_estado(valor: int) -> void:
	SistemaGuardado.set_contador(CONTADOR_ESTADO, valor)


## MtPyre_Summit_EventScript_15D57A: el robo del ORBE AZUL. FLAG_MT_PYRE_ORB_STOLEN,
## VAR_SLATEPORT_STATE = 1 (+ aparecen CAP. BABOR y los reporteros en la ciudad),
## VAR_SLATEPORT_HARBOR_STATE = 1 y VAR_MT_PYRE_STATE = 1.
static func marcar_orbe_robado() -> void:
	SistemaGuardado.set_flag(BANDERA_ORBE_ROBADO, true)
	SistemaGuardado.set_flag(BANDERA_ENTREVISTA_PORTUAL, true)
	SistemaGuardado.set_contador(CONTADOR_ESTADO_PUERTO, 1)
	fijar_estado(1)


## Valores actuales de todo lo persistente (depuración y tests).
static func instantanea() -> Dictionary:
	var datos := {}
	for clave: String in PERSISTENTE:
		datos[clave] = SistemaGuardado.get_flag(clave)
	datos[CONTADOR_ESTADO] = estado()
	datos[CONTADOR_ESTADO_PUERTO] = SistemaGuardado.get_contador(CONTADOR_ESTADO_PUERTO)
	return datos


## Restaura una instantánea (o, vacía, la partida antes de pisar el monte).
static func restablecer(datos: Dictionary = {}) -> void:
	for clave: String in PERSISTENTE:
		SistemaGuardado.set_flag(clave, bool(datos.get(clave, false)))
	SistemaGuardado.set_contador(CONTADOR_ESTADO, int(datos.get(CONTADOR_ESTADO, 0)))
	SistemaGuardado.set_contador(CONTADOR_ESTADO_PUERTO, int(datos.get(CONTADOR_ESTADO_PUERTO, 0)))

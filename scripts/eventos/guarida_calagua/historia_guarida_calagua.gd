## historia_guarida_calagua.gd
## Estado persistente de la GUARIDA del EQUIPO de CIUDAD CALAGUA (pokeruby data/maps/MagmaHideout_*
## y AquaHideout_*): banderas de SistemaGuardado con su equivalente en Rubí. No es un nodo: lo
## consultan los NPC, el guion de EventoGuaridaCalagua y los tests (patrón HistoriaMontePirico).
##
## En Rubí (`constants/version.inc`: `MUS_EVIL_TEAM = MUS_ENCOUNTER_MAGMA`) la guarida que se usa es
## la de MAGMA (escenas guarida_p4..p6 = MagmaHideout_1F/B1F/B2F, entrada por el warp (71, 5) de
## LilycoveCity). Las de AQUA (guarida_p1..p3 = AquaHideout_*) son la guarida de Zafiro: en Rubí
## nadie llega a ellas (el warp (70, 5) de LilycoveCity queda tapado por `LilycoveCity_OnLoad`)
## y sus objetos usan `OBJ_EVENT_GFX_VAR_1/2`, que en Rubí son MAGMA_MEMBER_M/F.
class_name HistoriaGuaridaCalagua
extends RefCounted

## FLAG_HIDE_GRUNT_1_BLOCKING_HIDEOUT y FLAG_HIDE_GRUNT_2_BLOCKING_HIDEOUT (los dos soldados que
## tapan el pasillo de la 1F). Rubí las activa juntas en la escena del submarino del PUERTO de
## CIUDAD PORTUAL (`VAR_SLATEPORT_HARBOR_STATE` 1 -> 2): EventoHuidaSubmarino. Un solo valor para los dos.
const BANDERA_BLOQUEO_OCULTO: String = "guarida_bloqueo_entrada_oculto"
## FLAG_HIDE_GRUNTS_HIDEOUTS (soldados de B1F/B2F y 1F de AQUA): Rubí nunca la activa.
const BANDERA_SOLDADOS_OCULTOS: String = "guarida_soldados_ocultos"
## FLAG_HIDE_SUBMARINE_SHADOW_HIDEOUT: `removeobject` de la sombra del submarino (B2F).
const BANDERA_SUBMARINO_OCULTO: String = "guarida_submarino_oculto"
## FLAG_HIDE_ELECTRODE_1_HIDEOUT / FLAG_HIDE_ELECTRODE_2_HIDEOUT (las dos "pelotas" de B1F).
const BANDERA_ELECTRODE_1_OCULTO: String = "guarida_electrode1_oculto"
const BANDERA_ELECTRODE_2_OCULTO: String = "guarida_electrode2_oculto"

## FLAG_MT_PYRE_ORB_STOLEN: cambia el texto de los dos soldados de la 1F (la activa la CIMA del
## MONTE PÍRICO).
const BANDERA_ORBE_ROBADO: String = "monte_pirico_orbe_robado"
## FLAG_EVIL_TEAM_ESCAPED_IN_SUBMARINE: la activa el guion de B2F (la leen CIUDAD CALAGUA y el
## PUERTO de CIUDAD PORTUAL).
const BANDERA_EQUIPO_ESCAPO: String = "calagua_equipo_escapo"
## FLAG_HIDE_GRUNTS_LILYCOVE: los soldados de CIUDAD CALAGUA desaparecen con el escape.
const BANDERA_SOLDADOS_CALAGUA_OCULTOS: String = "calagua_soldados_ocultos"

## Prefijo que SistemaGuardado da a las bolas del suelo (`ItemOverworld.PREFIJO_BANDERA`).
const PREFIJO_OBJETO: String = "item_"

## Clave de SistemaGuardado -> [tipo, equivalente en Gen 3]. Solo las que crea este cambio o
## que este cambio activa; las demás ya están registradas en HistoriaMontePirico y el exterior.
const PERSISTENTE := {
	BANDERA_BLOQUEO_OCULTO: ["bandera", "FLAG_HIDE_GRUNT_1_BLOCKING_HIDEOUT + FLAG_HIDE_GRUNT_2_BLOCKING_HIDEOUT"],
	BANDERA_SOLDADOS_OCULTOS: ["bandera", "FLAG_HIDE_GRUNTS_HIDEOUTS"],
	BANDERA_SUBMARINO_OCULTO: ["bandera", "FLAG_HIDE_SUBMARINE_SHADOW_HIDEOUT"],
	BANDERA_ELECTRODE_1_OCULTO: ["bandera", "FLAG_HIDE_ELECTRODE_1_HIDEOUT"],
	BANDERA_ELECTRODE_2_OCULTO: ["bandera", "FLAG_HIDE_ELECTRODE_2_HIDEOUT"],
}

## Las que activa o lee el guion y pertenecen a otros mapas (para que los tests las limpien).
const AJENAS := [BANDERA_ORBE_ROBADO, BANDERA_EQUIPO_ESCAPO, BANDERA_SOLDADOS_CALAGUA_OCULTOS]


## Valores actuales de todo lo persistente (depuración y tests).
static func instantanea() -> Dictionary:
	var datos := {}
	for clave: String in PERSISTENTE:
		datos[clave] = SistemaGuardado.get_flag(clave)
	for clave: String in AJENAS:
		datos[clave] = SistemaGuardado.get_flag(clave)
	return datos


## Restaura una instantánea (o, vacía, la partida antes de pisar la guarida).
static func restablecer(datos: Dictionary = {}) -> void:
	for clave: String in PERSISTENTE:
		SistemaGuardado.set_flag(clave, bool(datos.get(clave, false)))
	for clave: String in AJENAS:
		SistemaGuardado.set_flag(clave, bool(datos.get(clave, false)))

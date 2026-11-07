## historia_arrecipolis.gd
## Estado persistente de ARRECÍPOLIS (pokeruby data/maps/SootopolisCity) durante el despertar de GROUDON: banderas
## de SistemaGuardado con su equivalente en Rubí. No es un nodo: lo consultan EventoArrecipolis, los NPC de la ciudad
## (bandera_mostrar / bandera_ocultar), ClimaLegendario y los tests (patrón HistoriaMontePirico).
##
## - al_escapar_legendario(): el final de la CAVERNA ABISAL (SeafloorCavern_Room9, EventoCavernaAbisal) limpia
##   FLAG_HIDE_CAVE_OF_ORIGIN_ENTRANCE_WOMAN_1/2, FLAG_HIDE_WALLACE_SOOTOPOLIS y FLAG_HIDE_STEVEN_SOOTOPOLIS, pone
##   VAR_SOOTOPOLIS_STATE = 1, FLAG_SYS_WEATHER_CTRL (la sequía) y FLAG_HIDE_SOOTOPOLIS_RESIDENTS, y
##   FLAG_LEGEND_ESCAPED_SEAFLOOR_CAVERN.
## - al_completar_legendario(): el combate con GROUDON en la CUEVA ANCESTRAL (CaveOfOrigin_B4F, EventoCuevaAncestral)
##   oculta a PLUBIO y a las dos mujeres, muestra a PLUBIO en su GIMNASIO (FLAG_HIDE_WALLACE_SOOTOPOLIS_GYM: aquí es
##   FLAG_LEGENDARY_BATTLE_COMPLETED, que se activa a la vez), vuelven los vecinos, se acaba la sequía y el MONTE PÍRICO
##   pasa al estado 2 con MAGNO otra vez en la cima.
## Las banderas «*_visible» son las FLAG_HIDE_* invertidas: en Rubí new_game.inc las activa (empiezan ocultos).
class_name HistoriaArrecipolis
extends RefCounted

## VAR_SOOTOPOLIS_STATE: 0 antes del despertar; 1 con MÁXIMO y PLUBIO esperando arriba (coord_event (25,6)); 2 tras
## llevarte a la CUEVA ANCESTRAL.
const CONTADOR_ESTADO: String = "arrecipolis_estado"
## FLAG_HIDE_CAVE_OF_ORIGIN_ENTRANCE_WOMAN_1 y _2, invertidas (siempre cambian juntas).
const BANDERA_MUJERES_VISIBLES: String = "arrecipolis_mujeres_cueva_visibles"
## FLAG_HIDE_WALLACE_SOOTOPOLIS, invertida.
const BANDERA_PLUBIO_VISIBLE: String = "arrecipolis_plubio_visible"
## FLAG_HIDE_STEVEN_SOOTOPOLIS, invertida (MÁXIMO se va volando tras el legendario: removeobject).
const BANDERA_MAXIMO_VISIBLE: String = "arrecipolis_maximo_visible"
## FLAG_HIDE_SOOTOPOLIS_RESIDENTS.
const BANDERA_VECINOS_OCULTOS: String = "arrecipolis_vecinos_ocultos"
## FLAG_SYS_WEATHER_CTRL (ver ClimaLegendario).
const BANDERA_CLIMA: String = ClimaLegendario.BANDERA

const PERSISTENTE := {
	CONTADOR_ESTADO: ["contador", "VAR_SOOTOPOLIS_STATE"],
	BANDERA_MUJERES_VISIBLES: ["bandera", "!FLAG_HIDE_CAVE_OF_ORIGIN_ENTRANCE_WOMAN_1/2"],
	BANDERA_PLUBIO_VISIBLE: ["bandera", "!FLAG_HIDE_WALLACE_SOOTOPOLIS"],
	BANDERA_MAXIMO_VISIBLE: ["bandera", "!FLAG_HIDE_STEVEN_SOOTOPOLIS"],
	BANDERA_VECINOS_OCULTOS: ["bandera", "FLAG_HIDE_SOOTOPOLIS_RESIDENTS"],
	BANDERA_CLIMA: ["bandera", "FLAG_SYS_WEATHER_CTRL"],
}


static func estado() -> int:
	return SistemaGuardado.get_contador(CONTADOR_ESTADO)


## FLAG_LEGEND_ESCAPED_SEAFLOOR_CAVERN. También vale `caverna_abisal_estado` ≥ 1, para las partidas que terminaron la
## CAVERNA ABISAL antes de que existiera la bandera.
static func legendario_escapo() -> bool:
	return SistemaGuardado.get_flag(HistoriaMontePirico.BANDERA_LEGENDARIO_ESCAPO) \
		or SistemaGuardado.get_contador(EventoCavernaAbisal.CONTADOR_ESTADO) >= 1


## FLAG_LEGENDARY_BATTLE_COMPLETED.
static func legendario_completado() -> bool:
	return SistemaGuardado.get_flag(HistoriaMontePirico.BANDERA_LEGENDARIO_COMPLETADO)


## SeafloorCavern_Room9_EventScript_1612FC (después del despertar).
static func al_escapar_legendario() -> void:
	SistemaGuardado.set_flag(BANDERA_MUJERES_VISIBLES, true)
	SistemaGuardado.set_flag(BANDERA_PLUBIO_VISIBLE, true)
	SistemaGuardado.set_flag(BANDERA_MAXIMO_VISIBLE, true)
	SistemaGuardado.set_contador(CONTADOR_ESTADO, 1)
	SistemaGuardado.set_flag(HistoriaMontePirico.BANDERA_LEGENDARIO_ESCAPO, true)
	SistemaGuardado.set_flag(BANDERA_CLIMA, true)
	SistemaGuardado.set_flag(BANDERA_VECINOS_OCULTOS, true)


## CaveOfOrigin_B4F_EventScript_15DDD7 (tras el combate con GROUDON, gane, huya o lo atrape).
static func al_completar_legendario() -> void:
	SistemaGuardado.set_flag(BANDERA_PLUBIO_VISIBLE, false)
	SistemaGuardado.set_flag(BANDERA_MUJERES_VISIBLES, false)
	SistemaGuardado.set_flag(HistoriaMontePirico.BANDERA_LEGENDARIO_COMPLETADO, true)
	SistemaGuardado.set_flag(BANDERA_VECINOS_OCULTOS, false)
	SistemaGuardado.set_flag(BANDERA_CLIMA, false)
	SistemaGuardado.set_contador(HistoriaMontePirico.CONTADOR_ESTADO, 2)
	SistemaGuardado.set_flag(HistoriaMontePirico.BANDERA_JEFE_OCULTO, false)

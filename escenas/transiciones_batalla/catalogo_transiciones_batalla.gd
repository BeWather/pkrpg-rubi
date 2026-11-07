## Escenas de las transiciones de batalla por id de estilo (los que admite
## `OpcionesBatallaOverworld.secuencia_transicion`). La fase 1 es común
## (Phase1Task_TransitionAll); las fases 2 siguen sPhase2_Tasks de
## battle_transition.c, en el mismo orden que las constantes B_TRANSITION_*.
class_name CatalogoTransicionesBatalla
extends RefCounted

const CARPETA: String = "res://escenas/transiciones_batalla/"

## Fase 1: Phase1Task_TransitionAll (tres destellos grises).
const DESTELLOS: StringName = &"destellos"
const DESENFOQUE: StringName = &"desenfoque"
const REMOLINO: StringName = &"remolino"
const SACUDIDA: StringName = &"sacudida"
const POKEBALL_GIGANTE: StringName = &"pokeball_gigante"
const ESTELA_POKEBALLS: StringName = &"estela_pokeballs"
const RELOJ: StringName = &"reloj"
const ONDAS: StringName = &"ondas"
const OLA: StringName = &"ola"
const CORTES: StringName = &"cortes"
const FUNDIDO_BLANCO: StringName = &"fundido_blanco"
const CUADRICULA: StringName = &"cuadricula"
const FRAGMENTOS: StringName = &"fragmentos"
const MUGSHOT_SIXTO: StringName = &"mugshot_sixto"
const MUGSHOT_FATIMA: StringName = &"mugshot_fatima"
const MUGSHOT_NIVEA: StringName = &"mugshot_nivea"
const MUGSHOT_DRACON: StringName = &"mugshot_dracon"
const MUGSHOT_MAXIMO: StringName = &"mugshot_maximo"

## Lo sustituye OverworldBattleManager por la fase 2 que toque (battle_setup.c).
const AUTOMATICA: StringName = &"automatica"
## Estilos que no hacen nada.
const NINGUNA: PackedStringArray = ["ninguna", ""]

## B_TRANSITION_* (índice) → id. Mismo orden que sPhase2_Tasks.
const POR_INDICE_DECOMP: Array[StringName] = [
	DESENFOQUE,        # 0  B_TRANSITION_BLUR
	REMOLINO,          # 1  B_TRANSITION_SWIRL
	SACUDIDA,          # 2  B_TRANSITION_SHUFFLE
	POKEBALL_GIGANTE,  # 3  B_TRANSITION_BIG_POKEBALL
	ESTELA_POKEBALLS,  # 4  B_TRANSITION_POKEBALLS_TRAIL
	RELOJ,             # 5  B_TRANSITION_CLOCKWISE_BLACKFADE
	ONDAS,             # 6  B_TRANSITION_RIPPLE
	OLA,               # 7  B_TRANSITION_WAVE
	CORTES,            # 8  B_TRANSITION_SLICE
	FUNDIDO_BLANCO,    # 9  B_TRANSITION_WHITEFADE
	CUADRICULA,        # 10 B_TRANSITION_GRID_SQUARES
	FRAGMENTOS,        # 11 B_TRANSITION_SHARDS
	MUGSHOT_SIXTO,     # 12 B_TRANSITION_SYDNEY
	MUGSHOT_FATIMA,    # 13 B_TRANSITION_PHOEBE
	MUGSHOT_NIVEA,     # 14 B_TRANSITION_GLACIA
	MUGSHOT_DRACON,    # 15 B_TRANSITION_DRAKE
	MUGSHOT_MAXIMO,    # 16 B_TRANSITION_STEVEN
]

const ESCENAS: Dictionary[StringName, String] = {
	DESTELLOS: CARPETA + "fase1_destellos.tscn",
	DESENFOQUE: CARPETA + "00_desenfoque.tscn",
	REMOLINO: CARPETA + "01_remolino.tscn",
	SACUDIDA: CARPETA + "02_sacudida.tscn",
	POKEBALL_GIGANTE: CARPETA + "03_pokeball_gigante.tscn",
	ESTELA_POKEBALLS: CARPETA + "04_estela_pokeballs.tscn",
	RELOJ: CARPETA + "05_reloj.tscn",
	ONDAS: CARPETA + "06_ondas.tscn",
	OLA: CARPETA + "07_ola.tscn",
	CORTES: CARPETA + "08_cortes.tscn",
	FUNDIDO_BLANCO: CARPETA + "09_fundido_blanco.tscn",
	CUADRICULA: CARPETA + "10_cuadricula.tscn",
	FRAGMENTOS: CARPETA + "11_fragmentos.tscn",
	MUGSHOT_SIXTO: CARPETA + "12_mugshot_sixto.tscn",
	MUGSHOT_FATIMA: CARPETA + "13_mugshot_fatima.tscn",
	MUGSHOT_NIVEA: CARPETA + "14_mugshot_nivea.tscn",
	MUGSHOT_DRACON: CARPETA + "15_mugshot_dracon.tscn",
	MUGSHOT_MAXIMO: CARPETA + "16_mugshot_maximo.tscn",
}

## Nombres de la implementación anterior que siguen aceptándose.
const ALIAS: Dictionary[StringName, StringName] = {
	&"parpadeo_rapido": DESTELLOS,
	&"entrenador_pokeball": ESTELA_POKEBALLS,
	&"salvaje_cierre_simple": CORTES,
}


## Id canónico de un estilo (aplica los alias).
static func resolver(estilo: String) -> StringName:
	var id := StringName(estilo)
	return ALIAS.get(id, id)


static func existe(estilo: String) -> bool:
	return ESCENAS.has(resolver(estilo))


## Ruta de la escena del estilo, o "" si no existe.
static func ruta(estilo: String) -> String:
	return ESCENAS.get(resolver(estilo), "")


## Id de la constante B_TRANSITION_* del decomp, o &"" si está fuera de rango.
static func por_indice_decomp(indice: int) -> StringName:
	if indice < 0 or indice >= POR_INDICE_DECOMP.size():
		return &""
	return POR_INDICE_DECOMP[indice]

extends RefCounted
## Banderas FLAG_LANDMARK_* de pokeruby (include/constants/flags.h) y mapa o
## evento que activa cada una.
##
## En el original, `GetLandmarkName` (src/landmark.c) solo lista un landmark del
## panel del mapa de región si su bandera es 0xFFFF (sin bandera) o está activada;
## cada bandera se activa con `setflag FLAG_LANDMARK_*` en el `MAP_SCRIPT_ON_TRANSITION`
## del mapa correspondiente (`data/maps/<Mapa>/scripts.inc`), es decir, cada vez
## que se entra en él, salvo FLAG_LANDMARK_WINSTRATE_FAMILY (ver abajo).
##
## Se guardan como banderas normales de la partida (`SistemaGuardado.set_flag`),
## con el nombre completo del decomp, como `FLAG_RECEIVED_SECRET_POWER`.
## `region_map_metadata.json` referencia estos nombres en el campo `bandera` de los
## POI de landmarks.
##
## `AdministradorMapa._registrar_visita_mapa_actual` llama a `activar_por_mapa`
## con la clave de escena del mapa al que entra el jugador (por warp, por el borde
## entre mapas o al cargar la partida), igual que FLAG_VISITED_*.
##
## No lleva `class_name`: los consumidores la cargan con `preload`.

const FLOWER_SHOP := "FLAG_LANDMARK_FLOWER_SHOP"
const MR_BRINEY_HOUSE := "FLAG_LANDMARK_MR_BRINEY_HOUSE"
const ABANDONED_SHIP := "FLAG_LANDMARK_ABANDONED_SHIP"
const SEASHORE_HOUSE := "FLAG_LANDMARK_SEASHORE_HOUSE"
const NEW_MAUVILLE := "FLAG_LANDMARK_NEW_MAUVILLE"
const OLD_LADY_REST_SHOP := "FLAG_LANDMARK_OLD_LADY_REST_SHOP"
const TRICK_HOUSE := "FLAG_LANDMARK_TRICK_HOUSE"
const WINSTRATE_FAMILY := "FLAG_LANDMARK_WINSTRATE_FAMILY"
const GLASS_WORKSHOP := "FLAG_LANDMARK_GLASS_WORKSHOP"
const LANETTES_HOUSE := "FLAG_LANDMARK_LANETTES_HOUSE"
const POKEMON_DAYCARE := "FLAG_LANDMARK_POKEMON_DAYCARE"
const SEAFLOOR_CAVERN := "FLAG_LANDMARK_SEAFLOOR_CAVERN"
const FIERY_PATH := "FLAG_LANDMARK_FIERY_PATH"
const ISLAND_CAVE := "FLAG_LANDMARK_ISLAND_CAVE"
const DESERT_RUINS := "FLAG_LANDMARK_DESERT_RUINS"
const FOSSIL_MANIACS_HOUSE := "FLAG_LANDMARK_FOSSIL_MANIACS_HOUSE"
const SCORCHED_SLAB := "FLAG_LANDMARK_SCORCHED_SLAB"
const ANCIENT_TOMB := "FLAG_LANDMARK_ANCIENT_TOMB"
const TUNNELERS_REST_HOUSE := "FLAG_LANDMARK_TUNNELERS_REST_HOUSE"
const HUNTERS_HOUSE := "FLAG_LANDMARK_HUNTERS_HOUSE"
const SEALED_CHAMBER := "FLAG_LANDMARK_SEALED_CHAMBER"
const SKY_PILLAR := "FLAG_LANDMARK_SKY_PILLAR"
const BERRY_MASTERS_HOUSE := "FLAG_LANDMARK_BERRY_MASTERS_HOUSE"

## Clave de escena del mapa (minúsculas, sin extensión) → bandera que activa al
## entrar en él. Solo mapas que existen en `escenas/mapas/`.
const POR_MAPA: Dictionary = {
	"ruta_104_floristeria": FLOWER_SHOP,
	"ruta_104_casa": MR_BRINEY_HOUSE,
	# AbandonedShip_Deck_OnTransition (setflag FLAG_LANDMARK_ABANDONED_SHIP).
	"nao_abandonada_cubierta": ABANDONED_SHIP,
	# NewMauville_Entrance_MapScript1_15E4D8 (el interior no activa la bandera).
	"malvalanova_entrada": NEW_MAUVILLE,
	"ruta_109_casa": SEASHORE_HOUSE,
	# Las tres salas de Route110_TrickHouse* son una sola escena (entrada, final y pasillo).
	"ruta_110_casa_treta": TRICK_HOUSE,
	"ruta_111_casa_abuela": OLD_LADY_REST_SHOP,
	# DesertRuins es un único mapa en el original; aquí son dos escenas.
	"ruta_111_ruinas_desierto_1": DESERT_RUINS,
	"ruta_111_ruinas_desierto_2": DESERT_RUINS,
	# IslandCave y AncientTomb, igual que DesertRuins: un mapa del original, dos escenas.
	"ruta_105_cueva_insular_1": ISLAND_CAVE,
	"ruta_105_cueva_insular_2": ISLAND_CAVE,
	"ruta_120_tumba_antigua_1": ANCIENT_TOMB,
	"ruta_120_tumba_antigua_2": ANCIENT_TOMB,
	# SealedChamber_OuterRoom_MapScript1_15F0E7 (la sala interior no tiene scripts de mapa).
	"camara_sellada_exterior": SEALED_CHAMBER,
	"ruta_112_senda_ignea": FIERY_PATH,
	"ruta_113_casa": GLASS_WORKSHOP,
	"ruta_114_casa_aredia": LANETTES_HOUSE,
	"ruta_114_casa_fosilmaniaco": FOSSIL_MANIACS_HOUSE,
	"ruta_116_casa_tunelero": TUNNELERS_REST_HOUSE,
	"ruta_117_guarderia": POKEMON_DAYCARE,
	"ruta_123_casa1": BERRY_MASTERS_HOUSE,
	"ruta_124_casa": HUNTERS_HOUSE,
	# SkyPillar_Entrance_MapScript1_15F2C3 (el resto del PILAR no activa la bandera).
	"pilar_celeste_entrada": SKY_PILLAR,
	# Underwater_SeafloorCavern_MapScript1_15D9AE: la bandera la pone la caverna submarina, no la entrada de la CAVERNA ABISAL.
	"bajo_agua_caverna_abisal": SEAFLOOR_CAVERN,
}

## Banderas que no se activan al entrar en un mapa. FLAG_LANDMARK_WINSTRATE_FAMILY
## se fija en Route111_EventScript_1501D1, al hablar con VÍCTOR frente a la casa
## (antes de la pregunta), no en un script de mapa: lo hace
## `EventoFamiliaEstratega`.
const POR_EVENTO: PackedStringArray = [WINSTRATE_FAMILY]

## Banderas cuyo mapa aún no existe en el proyecto: bandera → mapa del decomp
## que la activaba. Quedan definidas y los POI ya las referencian; basta añadir
## la escena a `POR_MAPA` (y quitarla de aquí) cuando se cree.
const PENDIENTES: Dictionary = {
	SCORCHED_SLAB: "ScorchedSlab",
}


## Todas las banderas FLAG_LANDMARK_* que usa landmark.c, sin repetir.
static func todas() -> PackedStringArray:
	var banderas := PackedStringArray()
	for bandera: String in POR_MAPA.values():
		if not banderas.has(bandera):
			banderas.append(bandera)
	for bandera: String in POR_EVENTO:
		if not banderas.has(bandera):
			banderas.append(bandera)
	for bandera: String in PENDIENTES:
		if not banderas.has(bandera):
			banderas.append(bandera)
	return banderas


## Bandera que activa el mapa `clave_mapa`; "" si no activa ninguna.
static func bandera_de_mapa(clave_mapa: String) -> String:
	return str(POR_MAPA.get(clave_mapa.strip_edges().to_lower(), ""))


## setflag FLAG_LANDMARK_* al entrar en el mapa `clave_mapa` (idempotente). No
## hace nada si el mapa no tiene bandera asociada o aún no hay partida.
static func activar_por_mapa(clave_mapa: String) -> void:
	var bandera := bandera_de_mapa(clave_mapa)
	if not bandera.is_empty():
		activar(bandera)


## setflag de una bandera de landmark. Idempotente (no repite el log de guardado).
static func activar(bandera: String) -> void:
	if bandera.is_empty() or SistemaGuardado.datos_vivos == null:
		return
	if not SistemaGuardado.get_flag(bandera):
		SistemaGuardado.set_flag(bandera, true)


## FlagGet de una bandera de landmark; false si todavía no hay partida.
static func esta_activa(bandera: String) -> bool:
	if bandera.is_empty() or SistemaGuardado.datos_vivos == null:
		return false
	return SistemaGuardado.get_flag(bandera)

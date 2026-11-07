class_name EscenarioBatalla
extends RefCounted

## Elección del escenario de batalla (fondo, plataformas y tira de entrada o
## "frente") con la lógica de Rubí:
##   - `resolver_terreno()`: BattleSetup_GetTerrain (battle_setup.c), terreno
##     según la baldosa bajo el jugador y el tipo de mapa.
##   - `resolver_escenario()`: DrawMainBattleBackground / LoadBattleEntryBackground
##     (battle_bg.c), qué gráficos se usan según terreno, escena de batalla del
##     mapa (MAP_BATTLE_SCENE_*) y clase del entrenador.
## Los gráficos están en `CARPETA` como `<id>_fondo.png`, `<id>_suelo.png` y
## `<id>_entrada.png` (herramientas/graficos_batalla/generar_terrenos.py).

## gBattleTerrain (BATTLE_TERRAIN_*), mismo orden que gBattleTerrainTable.
enum Terreno { HIERBA_ALTA, HIERBA_LARGA, ARENA, BAJO_AGUA, AGUA, ESTANQUE, MONTANA, CUEVA, EDIFICIO, LLANURA }

## MAP_BATTLE_SCENE_* de la cabecera del mapa, en el mismo orden.
enum Escena { NORMAL, GIMNASIO, MAGMA, AQUA, SIDNEY, PHOEBE, GLACIA, DRAKE, TORRE_BATALLA }

## gMapHeader.mapType tal como lo distingue BattleSetup_GetTerrain:
## TOWN/CITY/ROUTE → RUTA; MAP_TYPE_6 → RUTA_MARITIMA; UNDERGROUND → SUBTERRANEO;
## UNDERWATER → SUBMARINO; INDOOR/SECRET_BASE → INTERIOR. AUTOMATICO lo deduce
## MapaConfiguracion (obtener_tipo_mapa_batalla) de esInterior/es_cueva.
enum TipoMapa { AUTOMATICO, RUTA, RUTA_MARITIMA, SUBTERRANEO, SUBMARINO, INTERIOR }

const CARPETA: String = "res://graficos/batalla/terrenos/"

## Id del escenario de cada Terreno (índice = valor del enum).
const IDS_TERRENO: PackedStringArray = [
	"hierba_alta", "hierba_larga", "arena", "bajo_agua", "agua",
	"estanque", "montana", "cueva", "edificio", "llanura",
]
## Id del escenario de cada Escena (NORMAL usa el del terreno).
const IDS_ESCENA: PackedStringArray = [
	"", "edificio_gimnasio", "estadio_magma", "estadio_aqua", "estadio_sidney",
	"estadio_phoebe", "estadio_glacia", "estadio_drake", "torre_batalla",
]
const ID_BAJO_AGUA: String = "bajo_agua"
## BATTLE_TYPE_KYOGRE_GROUDON en Rubí: cueva con la paleta de Groudon.
const ID_GROUDON: String = "groudon"
## TRAINER_CLASS_LEADER: edificio con gBattleTerrainPalette_BuildingLeader.
const ID_LIDER: String = "edificio_lider"
## TRAINER_CLASS_CHAMPION: estadio con gBattleTerrainPalette_StadiumSteven.
const ID_CAMPEON: String = "estadio_steven"

## Clases de DatosEntrenador.clase_entrenador (texto en mayúsculas).
const CLASE_LIDER: String = "LÍDER"
const CLASE_CAMPEON: String = "CAMPEÓN"

## Puentes sobre estanque (MetatileBehavior_GetBridgeType != 0).
const _MASCARA_PUENTE: int = TPTileDataMap.Flags.PUENTE_BAJO | TPTileDataMap.Flags.PUENTE_MEDIO | TPTileDataMap.Flags.PUENTE_ALTO


## BattleSetup_GetTerrain. `flags`: banderas TPTileDataMap de la celda del
## jugador (si surfea bajo un puente, incluidas las PUENTE_* de la capa elevada);
## `tipo_mapa`: tipo efectivo (AUTOMATICO se trata como RUTA); `tormenta_arena`:
## GetSav1Weather() == WEATHER_SANDSTORM.
static func resolver_terreno(flags: int, surfea: bool, tipo_mapa: TipoMapa, es_ruta_113: bool = false, tormenta_arena: bool = false) -> Terreno:
	# MB_LONG_GRASS antes que MB_TALL_GRASS: en el GBA son comportamientos
	# distintos; aquí una celda podría llevar las dos banderas.
	if flags & TPTileDataMap.Flags.HIERBA_MAS_ALTA:
		return Terreno.HIERBA_LARGA
	# La hierba con ceniza (MB_ASHGRASS) no es MB_TALL_GRASS.
	if flags & TPTileDataMap.Flags.HIERBA_ALTA and not (flags & TPTileDataMap.Flags.HIERBA_CENIZA):
		return Terreno.HIERBA_ALTA
	# MetatileBehavior_IsSandOrDeepSand.
	if flags & (TPTileDataMap.Flags.ARENA_HUELLA | TPTileDataMap.Flags.DESIERTO):
		return Terreno.ARENA

	# MetatileBehavior_IsSurfableWaterOrUnderwater: el jugador solo pisa agua
	# surfeando, así que vale tanto la bandera como el estado.
	var en_agua := surfea or bool(flags & TPTileDataMap.Flags.SURF)
	match tipo_mapa:
		TipoMapa.SUBTERRANEO:
			# MetatileBehavior_IsIndoorEncounter → EDIFICIO, antes que el agua.
			if flags & TPTileDataMap.Flags.ENCUENTRO_INTERIOR:
				return Terreno.EDIFICIO
			return Terreno.ESTANQUE if en_agua else Terreno.CUEVA
		TipoMapa.INTERIOR:
			return Terreno.EDIFICIO
		TipoMapa.SUBMARINO:
			return Terreno.BAJO_AGUA
		TipoMapa.RUTA_MARITIMA:
			return Terreno.AGUA if en_agua else Terreno.LLANURA

	# Surfeando bajo un puente sobre estanque (GetBridgeType) → ESTANQUE. En el
	# GBA esa baldosa es de puente y no de agua; aquí la celda también lleva SURF,
	# así que se comprueba antes que el agua.
	if surfea and flags & _MASCARA_PUENTE:
		return Terreno.ESTANQUE
	if en_agua:
		# MB_OCEAN_WATER → AGUA; el resto del agua surfeable (estanques, que
		# reflejan) → ESTANQUE.
		return Terreno.ESTANQUE if flags & TPTileDataMap.Flags.REFLEJO else Terreno.AGUA
	# MetatileBehavior_IsMountainTop → MONTANA.
	if flags & TPTileDataMap.Flags.CIMA_MONTANA:
		return Terreno.MONTANA
	if es_ruta_113 or tormenta_arena:
		return Terreno.ARENA
	return Terreno.LLANURA


## DrawMainBattleBackground / LoadBattleEntryBackground: id del escenario.
## `clase_entrenador` vacía en combates salvajes; `legendario` equivale a
## BATTLE_TYPE_KYOGRE_GROUDON (Groudon en Rubí).
static func resolver_escenario(terreno: Terreno, escena: Escena, clase_entrenador: String = "", legendario: bool = false) -> String:
	if legendario:
		return ID_GROUDON
	var clase := clase_entrenador.strip_edges().to_upper()
	if clase == CLASE_LIDER:
		return ID_LIDER
	if clase == CLASE_CAMPEON:
		return ID_CAMPEON
	if escena == Escena.NORMAL or escena < 0 or escena >= IDS_ESCENA.size():
		return id_terreno(terreno)
	return IDS_ESCENA[escena]


## Id del escenario de un terreno (gBattleTerrainTable).
static func id_terreno(terreno: Terreno) -> String:
	if terreno < 0 or terreno >= IDS_TERRENO.size():
		return IDS_TERRENO[Terreno.LLANURA]
	return IDS_TERRENO[terreno]


## Terreno aproximado de un escenario cuando no se conoce el real (datos sin
## `terreno`, lanzador de depuración): el del propio terreno si el id es uno de
## IDS_TERRENO, CUEVA para Groudon y EDIFICIO para gimnasios, estadios y la
## torre (todos interiores).
static func terreno_de_escenario(id: String) -> Terreno:
	var indice := IDS_TERRENO.find(id)
	if indice >= 0:
		return indice as Terreno
	if id == ID_GROUDON:
		return Terreno.CUEVA
	if id.is_empty():
		return Terreno.LLANURA
	return Terreno.EDIFICIO


## Todos los ids de escenario con gráficos.
static func ids_escenarios() -> PackedStringArray:
	var ids := PackedStringArray(IDS_TERRENO)
	ids.append(ID_GROUDON)
	ids.append(ID_LIDER)
	ids.append(ID_CAMPEON)
	for i in range(1, IDS_ESCENA.size()):
		ids.append(IDS_ESCENA[i])
	return ids


## Rutas de los gráficos del escenario: {"fondo", "suelo", "entrada"}.
static func rutas(id: String) -> Dictionary:
	return {
		"fondo": CARPETA + id + "_fondo.png",
		"suelo": CARPETA + id + "_suelo.png",
		"entrada": CARPETA + id + "_entrada.png",
	}

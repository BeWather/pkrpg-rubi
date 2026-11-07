## submarino_caverna_abisal.gd
## SUBMARINO EXPLORADOR 1 en la caverna submarina de la RUTA 128 (pokeruby data/maps/Underwater_SeafloorCavern):
## mientras GROUDON no haya escapado, cuatro objetos invisibles en (5..8,4) dicen «En el casco pone: SUBMARINO
## EXPLORADOR 1...» (aquí, carteles `carteles`). Con FLAG_LEGEND_ESCAPED_SEAFLOOR_CAVERN (EventoCavernaAbisal.completado):
## OnTransition oculta los objetos (FLAG_HIDE_UNDERWATER_SUBMARINE_INTERACTION) y OnLoad quita el submarino
## (Underwater_SeafloorCavern_EventScript_15D9C9): pared de roca impasable en la fila 3 y suelo en sombra pasable en
## las filas 4 y 5, columnas 5..8. Las baldosas son las equivalentes del arte del proyecto (tileset_cuevas) que la
## escena ya usa para METATILE_Underwater_RockWall y METATILE_Underwater_FloorShadow.
extends Node
class_name SubmarinoCavernaAbisal

const FUENTE: int = 1
const PARED := Vector2i(22, 3)  # METATILE_Underwater_RockWall
const SUELO_SOMBRA := Vector2i(16, 5)  # METATILE_Underwater_FloorShadow
const COLUMNAS: Array[int] = [5, 6, 7, 8]
const FILA_PARED: int = 3
const FILAS_SUELO: Array[int] = [4, 5]

@export var capa: NodePath
@export var datos_tiles: NodePath
@export var carteles: Array[NodePath] = []


func _ready() -> void:
	var mapa := _mapa()
	if mapa != null:
		mapa.mapa_activado.connect(func(_por_warp: bool) -> void: aplicar())
	aplicar.call_deferred()


func _mapa() -> MapaConfiguracion:
	var nodo: Node = get_parent()
	while nodo != null and not nodo is MapaConfiguracion:
		nodo = nodo.get_parent()
	return nodo as MapaConfiguracion


static func submarino_presente() -> bool:
	return not EventoCavernaAbisal.completado()


func aplicar() -> void:
	if submarino_presente():
		return
	var fondo := get_node_or_null(capa) as TileMapLayer
	var tp := get_node_or_null(datos_tiles) as TPTileDataMap
	for x in COLUMNAS:
		if fondo != null:
			fondo.set_cell(Vector2i(x, FILA_PARED), FUENTE, PARED)
			for y in FILAS_SUELO:
				fondo.set_cell(Vector2i(x, y), FUENTE, SUELO_SOMBRA)
		if tp != null:
			tp.set_flag(Vector2(x, FILA_PARED), TPTileDataMap.Flags.BLOQUEO)
			for y in FILAS_SUELO:
				tp.clear_flag(Vector2(x, y), TPTileDataMap.Flags.BLOQUEO)
	for ruta in carteles:
		var cartel := get_node_or_null(ruta)
		if cartel != null:
			cartel.remove_from_group("Cartel")
			(cartel as CanvasItem).visible = false

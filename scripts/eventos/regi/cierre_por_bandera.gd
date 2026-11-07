## cierre_por_bandera.gd
## `setmetatile x, y, metatile, impasable` de un OnLoad de pokeruby condicionado por una
## bandera (`call_if_unset FLAG_..., EventScript_Tapa`): mientras `bandera` NO esté activa,
## las celdas de `tiles_cerrados` de la capa `capa` muestran otro tile (o ninguno, con
## SIN_TILE) y las de `celdas_bloqueadas` no se pueden pisar. Con la bandera, todo vuelve a
## como está en la escena (la puerta abierta). Si una puerta toca varias capas, cada capa
## lleva su nodo, todos con la misma bandera. En vez de reemplazar tiles, la puerta puede
## dibujarse en una capa propia (`capa_cerrada`) que solo se ve mientras está cerrada.
##
## Lo usan las entradas a las cámaras de los REGI (FLAG_REGI_DOORS_OPENED en las RUTAS 105,
## 111 y 120), las paredes con braille de sus salas (FLAG_SYS_BRAILLE_*) y la de la CÁMARA
## SELLADA (FLAG_SYS_BRAILLE_DIG). `abrir()` es el setmetatile del efecto del puzle.
##
## Los mapas se reutilizan (se ocultan y se muestran), así que se vuelve a aplicar en cada
## `mapa_activado`. Los tiles y el BLOQUEO originales se recuerdan al cargar, no se limpian a
## ciegas, y el diccionario del TPTileDataMap se duplica para no tocar el de la escena.
extends Node
class_name CierrePorBandera

## Atlas "sin tile": borra la celda de la capa mientras está cerrada.
const SIN_TILE: Vector2i = Vector2i(-1, -1)
const BLOQUEO: int = TPTileDataMap.Flags.BLOQUEO

## Bandera de SistemaGuardado que abre el paso.
@export var bandera: String = ""
@export var capa: NodePath
## Fuente del TileSet de `capa` de los tiles cerrados.
@export var fuente: int = 0
## Celda -> coordenadas de atlas con el paso cerrado (SIN_TILE: vacía).
@export var tiles_cerrados: Dictionary[Vector2i, Vector2i] = {}
## Celdas impasables con el paso cerrado.
@export var celdas_bloqueadas: Array[Vector2i] = []
@export var datos_tiles: NodePath
## Capa visible solo con el paso cerrado (los tiles que tapan la entrada).
@export var capa_cerrada: NodePath

## Celda -> [fuente, atlas, alternativo] de la escena.
var _tiles_originales: Dictionary = {}
var _bloqueo_original: Dictionary = {}
var _preparado: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	aplicar()
	var mapa := _buscar_mapa()
	if mapa != null and not mapa.mapa_activado.is_connected(_on_mapa_activado):
		mapa.mapa_activado.connect(_on_mapa_activado)


func _on_mapa_activado(_por_warp: bool) -> void:
	aplicar()


func esta_abierto() -> bool:
	return not bandera.is_empty() and SistemaGuardado.get_flag(bandera)


## Pone el estado que corresponde a la bandera.
func aplicar() -> void:
	_preparar()
	_fijar(not esta_abierto())


## Activa la bandera y abre el paso (setmetatile + setflag del puzle).
func abrir() -> void:
	if not bandera.is_empty():
		SistemaGuardado.set_flag(bandera, true)
	aplicar()


func _preparar() -> void:
	if _preparado:
		return
	_preparado = true
	var layer := get_node_or_null(capa) as TileMapLayer
	if layer != null:
		for celda: Vector2i in tiles_cerrados:
			_tiles_originales[celda] = [layer.get_cell_source_id(celda), layer.get_cell_atlas_coords(celda),
					layer.get_cell_alternative_tile(celda)]
	var datos := get_node_or_null(datos_tiles) as TPTileDataMap
	if datos != null and not celdas_bloqueadas.is_empty():
		# El diccionario de la escena se comparte entre instancias: copia propia.
		datos.tile_data = datos.tile_data.duplicate(true)
		for celda in celdas_bloqueadas:
			_bloqueo_original[celda] = datos.has_flag(Vector2(celda), BLOQUEO)


func _fijar(cerrado: bool) -> void:
	var tapa := get_node_or_null(capa_cerrada) as CanvasItem
	if tapa != null:
		tapa.visible = cerrado
	var layer := get_node_or_null(capa) as TileMapLayer
	if layer != null:
		for celda: Vector2i in tiles_cerrados:
			if cerrado:
				var atlas: Vector2i = tiles_cerrados[celda]
				if atlas == SIN_TILE:
					layer.erase_cell(celda)
				else:
					layer.set_cell(celda, fuente, atlas)
			else:
				var original: Array = _tiles_originales.get(celda, [-1, SIN_TILE, 0])
				if int(original[0]) < 0:
					layer.erase_cell(celda)
				else:
					layer.set_cell(celda, int(original[0]), original[1], int(original[2]))
	var datos := get_node_or_null(datos_tiles) as TPTileDataMap
	if datos == null:
		return
	for celda in celdas_bloqueadas:
		if cerrado or bool(_bloqueo_original.get(celda, false)):
			datos.set_flag(Vector2(celda), BLOQUEO)
		else:
			datos.clear_flag(Vector2(celda), BLOQUEO)


func _buscar_mapa() -> Node:
	var nodo: Node = get_parent()
	while nodo != null and not nodo.has_signal("mapa_activado"):
		nodo = nodo.get_parent()
	return nodo

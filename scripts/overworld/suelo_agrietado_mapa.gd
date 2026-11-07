class_name SueloAgrietadoMapa
extends Node

## Suelo agrietado de la Cueva Granito B1F (MB_CRACKED_FLOOR de pokeruby,
## PerStepCallback_806A07C). Al empezar un paso del jugador hacia una celda con
## la bandera SUELO_AGRIETADO, `frames_rotura` frames después (a 60 fps) la celda
## pasa al tile de agujero (atlas_agrietado -> atlas_agujero), siempre. Solo se
## cruza sin caer en bici de carrera a máxima velocidad: el jugador ya ha salido
## de la celda cuando se rompe (eso lo decide el personaje, ver es_agujero()).
##
## Una celda rota o con la bandera AGUJERO hace caer al jugador al piso de
## `mapa_inferior` (nombre base de su .tscn) en las mismas coordenadas. Las
## celdas rotas se restauran al salir del árbol (los interiores se liberan al
## cambiar de mapa, así que las grietas reaparecen al volver, como en Rubí) o
## cuando el mapa vuelve a ser el actual (estado volátil).
##
## El tile se cambia con set_cell en `nombre_capa` (hermana de este nodo).

const GRUPO := &"suelo_agrietado"
const GRUPO_VOLATIL := &"estado_mapa_volatil"
const SEGUNDOS_POR_FRAME := 1.0 / 60.0

@export var nombre_capa: StringName = &"Suelo"
@export var fuente_atlas: int = 1
@export var atlas_agrietado: Vector2i = Vector2i(7, 5)
@export var atlas_agujero: Vector2i = Vector2i(6, 0)
## Nombre base del .tscn del piso de abajo (p. ej. "cueva_granito_3").
@export var mapa_inferior: String = ""
## Agujeros que no aterrizan en la misma celda: celda del agujero -> celda de llegada
## en `mapa_inferior` (warp_event del agujero en Rubí; MONTE PÍRICO: 2F (11,9) -> 1F (20,9)).
@export var llegadas_especiales: Dictionary[Vector2i, Vector2i] = {}
@export var frames_rotura: int = 3

## Celdas rotas (o a punto de romperse): Vector2i -> true.
var _rotas: Dictionary = {}
## Vector2i -> Tween de la rotura pendiente de esa celda.
var _roturas: Dictionary = {}


func _enter_tree() -> void:
	add_to_group(GRUPO)
	add_to_group(GRUPO_VOLATIL)


func _exit_tree() -> void:
	restaurar_todo()


## Paso del jugador hacia `destino` sobre la capa de datos `tp`. Si la celda está
## agrietada y sin romper, programa su rotura y devuelve true.
func procesar_paso(tp: TPTileDataMap, destino: Vector2i) -> bool:
	if tp == null or _rotas.has(destino):
		return false
	if not tp.has_flag(Vector2(destino), TPTileDataMap.Flags.SUELO_AGRIETADO):
		return false
	_rotas[destino] = true
	if not is_inside_tree():
		_poner(destino, atlas_agujero)
		return true
	var tween := create_tween()
	tween.tween_interval(frames_rotura * SEGUNDOS_POR_FRAME)
	tween.tween_callback(_romper.bind(destino))
	_roturas[destino] = tween
	return true


## ¿Hace caer `celda`? Rota (aunque el tile aún no haya cambiado) o marcada como
## AGUJERO en la capa de datos.
func es_agujero(tp: TPTileDataMap, celda: Vector2i) -> bool:
	if _rotas.has(celda):
		return true
	return tp != null and tp.has_flag(Vector2(celda), TPTileDataMap.Flags.AGUJERO)


func esta_rota(celda: Vector2i) -> bool:
	return _rotas.has(celda)


## Celda del piso de abajo en la que se aterriza al caer por `celda`: la misma, salvo
## que `llegadas_especiales` diga otra.
func celda_de_llegada(celda: Vector2i) -> Vector2i:
	return llegadas_especiales.get(celda, celda)


## Estado volátil: al volver al mapa desde otro, las grietas reaparecen.
func regenerar_estado_volatil(_desde_carga: bool = false) -> void:
	restaurar_todo()


## Deja todas las celdas rotas con su tile agrietado y anula las roturas pendientes.
func restaurar_todo() -> void:
	for celda: Vector2i in _roturas.keys():
		var tween: Tween = _roturas[celda]
		if tween != null:
			tween.kill()
	_roturas.clear()
	for celda: Vector2i in _rotas.keys():
		_poner(celda, atlas_agrietado)
	_rotas.clear()


func _romper(celda: Vector2i) -> void:
	_roturas.erase(celda)
	_poner(celda, atlas_agujero)


func _poner(celda: Vector2i, atlas: Vector2i) -> void:
	var padre := get_parent()
	if padre == null:
		return
	var capa := padre.get_node_or_null(NodePath(nombre_capa)) as TileMapLayer
	if capa == null or capa.get_cell_source_id(celda) != fuente_atlas:
		return
	var actual := capa.get_cell_atlas_coords(celda)
	if actual != atlas_agrietado and actual != atlas_agujero:
		return
	capa.set_cell(celda, fuente_atlas, atlas, capa.get_cell_alternative_tile(celda))

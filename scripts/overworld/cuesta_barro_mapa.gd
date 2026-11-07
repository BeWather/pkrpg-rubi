class_name CuestaBarroMapa
extends Node

## Cuestas de barro de la Ruta 111 (MB_MUDDY_SLOPE, Task_MuddySlope de pokeruby).
## Al empezar un paso del jugador hacia una celda con la bandera CUESTA_BARRO, esa
## celda hace una salpicadura de barro: 8 frames (a 60 fps) en cada uno de los
## tiles de `atlas_frames`, y vuelve a `atlas_base`. Como en pokeruby, a lo sumo
## hay MAX_SIMULTANEAS animaciones a la vez; las demás se ignoran.
##
## `atlas_frames` va de más a menos barro (sMuddySlopeAnimationMetatiles recorrido
## 0xe9, 0xea, 0xeb): en Ruta 111 son los tres tiles a la izquierda de atlas_base.
## El tile se cambia con set_cell en `nombre_capa` (hermana de este nodo).

const GRUPO := &"cuesta_barro"
const MAX_SIMULTANEAS := 4
const FRAMES_POR_TILE := 8
const SEGUNDOS_POR_FRAME := 1.0 / 60.0

@export var nombre_capa: StringName = &"Rocas"
@export var fuente_atlas: int = 0
@export var atlas_base: Vector2i = Vector2i(4, 18)
@export var atlas_frames: Array[Vector2i] = [Vector2i(5, 18), Vector2i(6, 18), Vector2i(7, 18)]

## Vector2i -> Tween de la animación en curso de esa celda.
var _animaciones: Dictionary = {}


func _enter_tree() -> void:
	add_to_group(GRUPO)


func _exit_tree() -> void:
	restaurar_todo()


## Paso del jugador hacia `destino` sobre la capa de datos `tp`.
func procesar_paso(tp: TPTileDataMap, destino: Vector2i) -> void:
	if tp == null or not tp.has_flag(Vector2(destino), TPTileDataMap.Flags.CUESTA_BARRO):
		return
	if _animaciones.size() >= MAX_SIMULTANEAS and not _animaciones.has(destino):
		return
	_animar(destino)


## Deja todas las cuestas en su tile base y corta las animaciones.
func restaurar_todo() -> void:
	for celda: Vector2i in _animaciones.keys():
		var tween: Tween = _animaciones[celda]
		if tween != null:
			tween.kill()
		_poner(celda, atlas_base)
	_animaciones.clear()


func _animar(celda: Vector2i) -> void:
	var anterior: Tween = _animaciones.get(celda)
	if anterior != null:
		anterior.kill()
	if not is_inside_tree():
		return
	var tween := create_tween()
	for atlas: Vector2i in atlas_frames:
		tween.tween_callback(_poner.bind(celda, atlas))
		tween.tween_interval(FRAMES_POR_TILE * SEGUNDOS_POR_FRAME)
	tween.tween_callback(_terminar.bind(celda))
	_animaciones[celda] = tween


func _terminar(celda: Vector2i) -> void:
	_poner(celda, atlas_base)
	_animaciones.erase(celda)


func _poner(celda: Vector2i, atlas: Vector2i) -> void:
	var padre := get_parent()
	if padre == null:
		return
	var capa := padre.get_node_or_null(NodePath(nombre_capa)) as TileMapLayer
	if capa == null or capa.get_cell_source_id(celda) != fuente_atlas:
		return
	var actual := capa.get_cell_atlas_coords(celda)
	if actual != atlas_base and not atlas_frames.has(actual):
		return
	capa.set_cell(celda, fuente_atlas, atlas, capa.get_cell_alternative_tile(celda))

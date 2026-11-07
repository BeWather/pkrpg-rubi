class_name TroncosOromarMapa
extends PuenteMaderaMapa

## Troncos flotantes de PUEBLO OROMAR (MB_PACIFIDLOG_*_LOG_1/2 de pokeruby,
## PerStepCallback_8069864 de src/field_tasks.c). Cada tronco ocupa dos celdas
## (2x1 o 1x2) de la capa Estructuras, y la fila del atlas dice qué mitad es
## (herramientas/importar_troncos_oromar.py): horizontal oeste/este y vertical
## norte/sur. En reposo el tile de `col_flotando` está animado en el TileSet
## (FloatingLogs, 3,75 fps); al hundirse usa los tiles fijos de las columnas
## `col_medio_hundido` y `col_sumergido`, y al volver a flotar retoma la animación.
##
## Al empezar un paso del jugador:
##   - si sale de un tronco (sin pasar a su otra mitad), la pareja pasa a medio
##     hundida y, 8 frames después, a flotando;
##   - si entra en un tronco nuevo, la pareja pasa a medio hundida y, 8 frames
##     después, a sumergida;
##   - si llega a cualquier celda de tronco suena SE_PUDDLE, también al pasar de
##     una mitad a la otra del mismo tronco (que sigue sumergido sin moverse).
## Al volver al mapa o cargar la partida todo vuelve a flotar salvo el tronco
## bajo el jugador, que aparece sumergido (case 0 del callback, en OnResume).

const SONIDO_TRONCOS := "SE_PUDDLE"
const GRUPO_VOLATIL := &"estado_mapa_volatil"
const GRUPO_JUGADOR := &"Personaje"
## data[6] = 8 del callback: frames de medio hundido.
const FRAMES_TRANSICION: int = 8

enum Estado { FLOTANDO, MEDIO_HUNDIDO, SUMERGIDO }

## Filas del atlas de cada mitad en `fuente_atlas`.
@export var fila_horizontal_oeste: int = 71
@export var fila_horizontal_este: int = 72
@export var fila_vertical_norte: int = 73
@export var fila_vertical_sur: int = 74
## Columnas del atlas de cada estado.
@export var col_flotando: int = 0
@export var col_medio_hundido: int = 4
@export var col_sumergido: int = 5

## Celda ancla (mitad oeste o norte) -> Tween de la transición en curso.
var _transiciones: Dictionary = {}
## Celda ancla -> Estado, solo de los troncos que no están flotando.
var _estados: Dictionary = {}


func _enter_tree() -> void:
	super()
	add_to_group(GRUPO_VOLATIL)


func procesar_paso(_tp: TPTileDataMap, origen: Vector2i, destino: Vector2i) -> void:
	var tronco_origen := pareja(origen)
	var tronco_destino := pareja(destino)
	if tronco_origen.is_empty() and tronco_destino.is_empty():
		return
	var mismo_tronco := not tronco_origen.is_empty() and not tronco_destino.is_empty() \
		and tronco_origen[0] == tronco_destino[0]
	if not mismo_tronco:
		if not tronco_origen.is_empty():
			_transicion(tronco_origen, Estado.FLOTANDO)
		if not tronco_destino.is_empty():
			_transicion(tronco_destino, Estado.SUMERGIDO)
	if not tronco_destino.is_empty():
		_reproducir_sonido()


## [ancla, compañera] del tronco que ocupa `celda`, o [] si no hay tronco.
func pareja(celda: Vector2i) -> Array[Vector2i]:
	var capa := _capa()
	if capa == null or capa.get_cell_source_id(celda) != fuente_atlas:
		return []
	var atlas := capa.get_cell_atlas_coords(celda)
	if atlas.x != col_flotando and atlas.x != col_medio_hundido and atlas.x != col_sumergido:
		return []
	if atlas.y == fila_horizontal_oeste:
		return [celda, celda + Vector2i.RIGHT]
	if atlas.y == fila_horizontal_este:
		return [celda + Vector2i.LEFT, celda]
	if atlas.y == fila_vertical_norte:
		return [celda, celda + Vector2i.DOWN]
	if atlas.y == fila_vertical_sur:
		return [celda + Vector2i.UP, celda]
	return []


## Estado del tronco que ocupa `celda` (FLOTANDO si no hay tronco).
func estado_de(celda: Vector2i) -> Estado:
	var tronco := pareja(celda)
	if tronco.is_empty():
		return Estado.FLOTANDO
	return _estados.get(tronco[0], Estado.FLOTANDO)


## Hunde sin transición el tronco de `celda`, si lo hay.
func hundir_sin_transicion(celda: Vector2i) -> void:
	var tronco := pareja(celda)
	if tronco.is_empty():
		return
	_cancelar_transicion(tronco[0])
	_poner_tronco(tronco, Estado.SUMERGIDO)


## Deja todos los troncos flotando y corta las transiciones.
func restaurar_todo() -> void:
	for ancla: Vector2i in _transiciones.keys():
		_cancelar_transicion(ancla)
	for ancla: Vector2i in _estados.keys():
		var tronco := pareja(ancla)
		if not tronco.is_empty():
			_poner_tronco(tronco, Estado.FLOTANDO)
	_estados.clear()


## AdministradorMapa al volver al mapa desde otro, desde un interior o al cargar
## la partida.
func regenerar_estado_volatil(_desde_carga: bool = false) -> void:
	restaurar_todo()
	var mapa := get_parent() as MapaConfiguracion
	var jugador := get_tree().get_first_node_in_group(GRUPO_JUGADOR) as Node2D if is_inside_tree() else null
	if mapa != null and jugador != null:
		hundir_sin_transicion(mapa.global_to_map_cell(jugador.global_position))


func _nombre_sonido() -> String:
	return SONIDO_TRONCOS


func _transicion(tronco: Array[Vector2i], final: Estado) -> void:
	_cancelar_transicion(tronco[0])
	if not is_inside_tree():
		_poner_tronco(tronco, final)
		return
	_poner_tronco(tronco, Estado.MEDIO_HUNDIDO)
	var tween := create_tween()
	tween.tween_interval(FRAMES_TRANSICION * SEGUNDOS_POR_FRAME)
	tween.tween_callback(_poner_tronco.bind(tronco, final))
	tween.tween_callback(_terminar_transicion.bind(tronco[0]))
	_transiciones[tronco[0]] = tween


func _terminar_transicion(ancla: Vector2i) -> void:
	_transiciones.erase(ancla)


func _cancelar_transicion(ancla: Vector2i) -> void:
	var tween: Tween = _transiciones.get(ancla)
	if tween != null:
		tween.kill()
	_transiciones.erase(ancla)


func _poner_tronco(tronco: Array[Vector2i], estado: Estado) -> void:
	var capa := _capa()
	if capa == null:
		return
	var columna := col_flotando
	if estado == Estado.MEDIO_HUNDIDO:
		columna = col_medio_hundido
	elif estado == Estado.SUMERGIDO:
		columna = col_sumergido
	for celda: Vector2i in tronco:
		var fila := capa.get_cell_atlas_coords(celda).y
		capa.set_cell(celda, fuente_atlas, Vector2i(columna, fila), capa.get_cell_alternative_tile(celda))
	if estado == Estado.FLOTANDO:
		_estados.erase(tronco[0])
	else:
		_estados[tronco[0]] = estado


func _capa() -> TileMapLayer:
	var padre := get_parent()
	if padre == null or nombres_capas.is_empty():
		return null
	return padre.get_node_or_null(NodePath(nombres_capas[0])) as TileMapLayer

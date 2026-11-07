class_name PuenteMaderaMapa
extends Node

## Puentes de madera de Ciudad Arborada (MB_FORTREE_BRIDGE de pokeruby,
## PerStepCallback_8069AA0). Al empezar un paso del jugador, si la celda de salida
## o la de llegada tiene la bandera PUENTE_MADERA suena SE_HASHI. La celda de
## llegada se hunde (atlas_normal -> atlas_hundido) y la de salida rebota:
## vuelve a su forma normal y, desde el frame 4 tras salir, se hunde de nuevo
## 4 frames (frames 4-8), vuelve a la normal 3 frames y se hunde otros 4
## (frames 11-15), hasta quedar normal en el frame 15 (a 60 fps).
##
## El tile se cambia con set_cell en cada capa de `nombres_capas` (hermanas de
## este nodo bajo el mapa) donde la celda use atlas_normal o atlas_hundido; en
## Arborada el puente está en Estructuras y se repite en Alto.

const GRUPO := &"puente_madera"
const SONIDO := "SE_HASHI"
const SEGUNDOS_POR_FRAME := 1.0 / 60.0
## Rebote tras salir de una celda: [frames de espera, hundida al terminar la espera].
const REBOTE: Array = [[4, true], [4, false], [3, true], [4, false]]

@export var nombres_capas: Array[StringName] = [&"Estructuras", &"Alto"]
@export var fuente_atlas: int = 2
@export var atlas_normal: Vector2i = Vector2i(13, 35)
@export var atlas_hundido: Vector2i = Vector2i(14, 35)

## Vector2i -> Tween del rebote en curso de esa celda.
var _rebotes: Dictionary = {}
## Celdas que ahora mismo se muestran hundidas (para restaurarlas al salir del árbol).
var _hundidas: Dictionary = {}
var _reproductor: AudioStreamPlayer = null


func _enter_tree() -> void:
	add_to_group(GRUPO)


func _exit_tree() -> void:
	restaurar_todo()


## Paso del jugador de `origen` a `destino` sobre la capa de datos `tp`.
func procesar_paso(tp: TPTileDataMap, origen: Vector2i, destino: Vector2i) -> void:
	if tp == null:
		return
	var en_origen := tp.has_flag(Vector2(origen), TPTileDataMap.Flags.PUENTE_MADERA)
	var en_destino := tp.has_flag(Vector2(destino), TPTileDataMap.Flags.PUENTE_MADERA)
	if not en_origen and not en_destino:
		return
	_reproducir_sonido()
	if en_origen:
		_iniciar_rebote(origen)
	if en_destino:
		_cancelar_rebote(destino)
		_poner(destino, atlas_hundido)


## Reproductor propio y sin posición: el AudioStreamPlayer2D del administrador
## atenúa por distancia al origen y, lejos de él, el crujido no se oiría.
func _reproducir_sonido() -> void:
	if _reproductor == null:
		_reproductor = AudioStreamPlayer.new()
		_reproductor.name = "Reproductor"
		_reproductor.stream = Singleton.se[_nombre_sonido()]
		add_child(_reproductor)
	_reproductor.play()


## Clave de Singleton.se del sonido de paso (TroncosOromarMapa la cambia).
func _nombre_sonido() -> String:
	return SONIDO


## Deja todos los puentes en su forma normal y corta los rebotes.
func restaurar_todo() -> void:
	for celda: Vector2i in _rebotes.keys():
		_cancelar_rebote(celda)
	for celda: Vector2i in _hundidas.keys():
		_poner(celda, atlas_normal)


func _iniciar_rebote(celda: Vector2i) -> void:
	_cancelar_rebote(celda)
	_poner(celda, atlas_normal)
	if not is_inside_tree():
		return
	var tween := create_tween()
	for tramo: Array in REBOTE:
		tween.tween_interval(int(tramo[0]) * SEGUNDOS_POR_FRAME)
		tween.tween_callback(_poner.bind(celda, atlas_hundido if tramo[1] else atlas_normal))
	tween.tween_callback(_terminar_rebote.bind(celda))
	_rebotes[celda] = tween


func _terminar_rebote(celda: Vector2i) -> void:
	_rebotes.erase(celda)


func _cancelar_rebote(celda: Vector2i) -> void:
	var tween: Tween = _rebotes.get(celda)
	if tween != null:
		tween.kill()
	_rebotes.erase(celda)


func _poner(celda: Vector2i, atlas: Vector2i) -> void:
	var padre := get_parent()
	if padre == null:
		return
	for nombre: StringName in nombres_capas:
		var capa := padre.get_node_or_null(NodePath(nombre)) as TileMapLayer
		if capa == null or capa.get_cell_source_id(celda) != fuente_atlas:
			continue
		var actual := capa.get_cell_atlas_coords(celda)
		if actual != atlas_normal and actual != atlas_hundido:
			continue
		capa.set_cell(celda, fuente_atlas, atlas, capa.get_cell_alternative_tile(celda))
	if atlas == atlas_hundido:
		_hundidas[celda] = true
	else:
		_hundidas.erase(celda)

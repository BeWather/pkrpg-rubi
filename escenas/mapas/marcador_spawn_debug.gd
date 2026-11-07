@tool
class_name SpawnDebug
extends Sprite2D

## Marcador de spawn de debug.
##
## Marca el tile donde aparece el jugador al ejecutar ESTA escena de mapa con
## F6 (arranque directo: juego completo, sin intro). Ver
## herramientas/debug/debug_arranque.gd.
##
## Uso: con la escena del mapa abierta, Add Child Node → SpawnDebug, y luego
## arrastrarlo por el lienzo. La posición se engancha sola al centro del tile
## más cercano, así que no hace falta afinarla a mano.
##
## Es una herramienta de editor: en el juego el nodo se libera y no existe.
## El mapa lee su tile en _enter_tree (antes de que este nodo se libere).

const TEXTURA: String = "res://graficos/editor/editor_tile_spawn.png"
const TILE_SIZE: int = 16
const ALPHA_MIN: float = 0.35
const ALPHA_MAX: float = 1.0
const DURACION_PULSO: float = 0.9

## Coordenada de tile del marcador. Se recalcula al mover el nodo.
var coord_tile: Vector2i = Vector2i.ZERO

var _tween: Tween = null
## Evita reentrar en el enganche a la rejilla mientras se recoloca el nodo.
var _enganchando: bool = false


func _ready() -> void:
	if not Engine.is_editor_hint():
		# Herramienta de editor: no debe existir durante el juego. El mapa ya
		# leyó su tile en _enter_tree, antes de llegar aquí.
		queue_free()
		return
	texture = load(TEXTURA)
	centered = true
	z_index = 1000
	modulate.a = ALPHA_MAX
	set_notify_transform(true)
	_enganchar_a_tile()
	_iniciar_pulso()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		_enganchar_a_tile()


func _exit_tree() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


## Devuelve el tile del marcador. Sirve también en runtime, donde el nodo ya se
## ha liberado: el mapa lo lee en _enter_tree, antes de eso.
func obtener_coord_tile() -> Vector2i:
	coord_tile = tile_desde_posicion(position)
	return coord_tile


## Tile cuyo centro cubre `pos` (los tiles se centran en tile*16 + 8).
static func tile_desde_posicion(pos: Vector2) -> Vector2i:
	return Vector2i(
		round((pos.x - TILE_SIZE * 0.5) / TILE_SIZE),
		round((pos.y - TILE_SIZE * 0.5) / TILE_SIZE)
	)


## Posición del centro del tile indicado.
static func posicion_desde_tile(tile: Vector2i) -> Vector2:
	return Vector2(
		tile.x * TILE_SIZE + TILE_SIZE * 0.5,
		tile.y * TILE_SIZE + TILE_SIZE * 0.5
	)


## Encaja la posición al centro del tile más cercano.
func _enganchar_a_tile() -> void:
	if _enganchando:
		return
	_enganchando = true
	position = posicion_desde_tile(tile_desde_posicion(position))
	_enganchando = false


## Pulso de opacidad entre ALPHA_MIN y ALPHA_MAX. Nunca llega a 0 para que el
## marcador siga siendo seleccionable con un clic en el editor.
func _iniciar_pulso() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_loops()
	_tween.tween_property(self, "modulate:a", ALPHA_MIN, DURACION_PULSO)
	_tween.tween_property(self, "modulate:a", ALPHA_MAX, DURACION_PULSO)

@tool
extends Sprite2D
class_name Signpost

## Capa de datos donde aplicar: -1 todas, >=0 solo capa especificada
@export var capa_datos: int = -1

@export var id_texto : String
const EDITOR_ICON := "res://graficos/editor/editor_tile_cartel.png"
@export var coord_tile: Vector2i = Vector2i.ZERO:		# Coordenada en tiles
	set(value):
		coord_tile = value
		if is_inside_tree():
			position = Vector2(value.x * 16 + 8, value.y * 16 + 8)
			update_configuration_warnings()

@export var direccion: Singleton.enum_dir_cartel = Singleton.enum_dir_cartel.TODAS_DIRECCIONES
## Si no está vacía, el cartel solo se puede leer con esta bandera puesta (p. ej. la de un objeto
## oculto en la misma celda: hasta recogerlo, la acción la atiende el objeto).
@export var bandera_requerida: String = ""
var cuadro_dialogo: Node = null

func _ready() -> void:
	add_to_group("Cartel")

	if Engine.is_editor_hint():
		set_notify_transform(true)
		_preparar_icono_editor()
		# Activar process para actualizar la modulación en el editor
		set_process(true)
	else:
		set_process(false)

# Ajustar la posición a la coordenada más cercana en la cuadrícula de tiles
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		coord_tile = Vector2i(round((position.x - 8) / 16), round((position.y - 8) / 16))
		position = Vector2(coord_tile.x * 16 + 8, coord_tile.y * 16 + 8)
	elif what == NOTIFICATION_EDITOR_PRE_SAVE:
		_limpiar_icono_editor()
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		_preparar_icono_editor()

func _process(_delta: float) -> void:
	# Solo en editor: animar modulación del editor_cartel para hacerlo más visible
	if not Engine.is_editor_hint():
		return
	var t = Time.get_ticks_msec() / 1000.0
	# Pulso suave entre 0.6 y 1.0
	modulate.a = 0.6 + 0.4 * (sin(t * 2.0) * 0.5 + 0.5)

## Icono de editor: el propio nodo es el Sprite2D, así todo su rect de 16x16 es
## clicable en el lienzo (un Sprite2D hijo sin owner lo ignora el editor).
func _preparar_icono_editor() -> void:
	texture = load(EDITOR_ICON)
	centered = true
	z_index = 1000
	modulate = Color(1, 1, 1, 0.8)

## Quita el icono antes de guardar para que no acabe serializado en la escena.
func _limpiar_icono_editor() -> void:
	texture = null
	z_index = 0
	modulate = Color.WHITE

## false mientras falte `bandera_requerida`: el administrador lo ignora al buscar carteles.
func esta_activo() -> bool:
	return bandera_requerida.is_empty() or SistemaGuardado.get_flag(bandera_requerida)

## Función llamada desde el administrador de mapas cuando el jugador interactúa con el cartel
func accionar_cartel() -> void:
	Singleton.mostrar_texto(tr(id_texto))

@tool
extends Control
class_name PkSelectorSimple

@export var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()

@export var parpadeo: bool = false:
	set(value):
		parpadeo = value
		_configurar_parpadeo()

@export var mostrar_area_seleccionable: bool = false:
	set(value):
		mostrar_area_seleccionable = value
		queue_redraw()

@export var offset_subpixel: Vector2 = Vector2(0.5, 0.5):
	set(value):
		offset_subpixel = value
		queue_redraw()

@export var ancho_borde: int = 2:
	set(value):
		ancho_borde = clamp(value, 1, 2)
		queue_redraw()

# Variables internas para animaciones
var tween_posicion: Tween
var tween_tamanio: Tween
var tween_color: Tween
var tween_parpadeo: Tween

const TIEMPO_VISIBLE: float = 0.375
const TIEMPO_INVISIBLE: float = 0.125

func _ready():
	# Usar position y tamaño definidos en el Control
	_configurar_parpadeo()
	queue_redraw()

func _draw():
	var x = offset_subpixel.x
	var y = offset_subpixel.y
	
	if ancho_borde == 1:
		# Dibujar borde de 1 pixel con esquinas recortadas
		# Líneas horizontales (arriba y abajo)
		draw_line(Vector2(x + 0.5, y), Vector2(x + size.x - 1.5, y), color, 1.0)
		draw_line(Vector2(x + 0.5, y + size.y - 1), Vector2(x + size.x - 1.5, y + size.y - 1), color, 1.0)
		# Líneas verticales (izquierda y derecha)
		draw_line(Vector2(x, y + 0.5), Vector2(x, y + size.y - 1.5), color, 1.0)
		draw_line(Vector2(x + size.x - 1, y + 0.5), Vector2(x + size.x - 1, y + size.y - 1.5), color, 1.0)
	else:
		# Dibujar borde de 2 pixeles con esquinas recortadas (original)
		# Borde horizontal
		draw_rect(Rect2(Vector2(x + 1, y), Vector2(size.x - 3, size.y - 1)), color, false, 1.0)
		# Borde vertical
		draw_rect(Rect2(Vector2(x, y + 1), Vector2(size.x - 1, size.y - 3)), color, false, 1.0)

	if mostrar_area_seleccionable:
		draw_rect(Rect2(Vector2.ZERO, size), color, false, 0.5)

func _animar_posicion():
	if tween_posicion:
		tween_posicion.kill()
	tween_posicion = create_tween()
	tween_posicion.tween_property(self, "position", position.round(), 0.2)
	tween_posicion.tween_callback(func(): queue_redraw())

func _animar_tamanio():
	if tween_tamanio:
		tween_tamanio.kill()
	tween_tamanio = create_tween()
	tween_tamanio.tween_property(self, "custom_minimum_size", size, 0.15)
	tween_tamanio.tween_callback(func(): queue_redraw())

func _animar_color():
	if tween_color:
		tween_color.kill()
	tween_color = create_tween()
	var destello = Color(min(color.r + 0.3,1.0), min(color.g + 0.3,1.0), min(color.b + 0.3,1.0), color.a)
	modulate = destello
	tween_color.tween_property(self, "modulate", Color(1,1,1,1), 0.1)
	tween_color.tween_callback(func(): queue_redraw())

func _configurar_parpadeo():
	if tween_parpadeo:
		tween_parpadeo.kill()
	if parpadeo:
		tween_parpadeo = create_tween().set_loops()
		tween_parpadeo.tween_property(self, "modulate:a", 1.0, 0.0)
		tween_parpadeo.tween_interval(TIEMPO_VISIBLE)
		tween_parpadeo.tween_property(self, "modulate:a", 0.0, 0.05)
		tween_parpadeo.tween_interval(TIEMPO_INVISIBLE - 0.05)
		tween_parpadeo.tween_property(self, "modulate:a", 1.0, 0.05)
	else:
		modulate.a = 1.0

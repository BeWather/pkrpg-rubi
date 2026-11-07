class_name EfectoClimaBase
extends Control

## Contrato común de todos los renderers de clima.

var intensidad: float = 1.0
var factor_mezcla: float = 1.0
var area_visible: Rect2 = Rect2()

## Inyectable en tests (Vector2); si es null se usa la transformación del canvas
## del viewport, es decir, la cámara del mundo.
var posicion_camara_override: Variant = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configurar(nueva_intensidad: float, nueva_area_visible: Rect2) -> void:
	intensidad = clampf(nueva_intensidad, 0.0, 1.0)
	actualizar_area_visible(nueva_area_visible)
	queue_redraw()


func actualizar_area_visible(nueva_area_visible: Rect2) -> void:
	area_visible = nueva_area_visible
	position = nueva_area_visible.position
	size = nueva_area_visible.size
	queue_redraw()


func set_factor_mezcla(nuevo_factor: float) -> void:
	factor_mezcla = clampf(nuevo_factor, 0.0, 1.0)
	queue_redraw()


func detener() -> void:
	set_process(false)


## Esquina superior izquierda visible en coordenadas de mundo, redondeada a píxel.
## Sin cámara, la transformación del canvas es la identidad y devuelve (0, 0).
## Los efectos anclados al mundo (ceniza, salpicaduras de lluvia) la usan para
## convertir entre pantalla lógica y mundo.
func obtener_posicion_camara() -> Vector2:
	if posicion_camara_override is Vector2:
		return posicion_camara_override as Vector2
	if not is_inside_tree():
		return Vector2.ZERO
	var transformacion := get_viewport().get_canvas_transform()
	var escala := transformacion.get_scale()
	if is_zero_approx(escala.x) or is_zero_approx(escala.y):
		return Vector2.ZERO
	return (-transformacion.origin / escala).round()

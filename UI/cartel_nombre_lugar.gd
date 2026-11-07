class_name CartelNombreLugar
extends NinePatchRect

## Cartel que muestra el nombre del lugar al cambiar de mapa (exterior↔exterior
## con nombre distinto y al salir de un interior al exterior).
## Nodo en coordenadas de UI, tamaño 112x32, texto centrado, con el borde
## (textura menu_box_N) según la opción imagen_tipo del jugador.
## Reposo en (0, -32) (fuera de pantalla): entra a (0,0) en 0.2 s, fijo 2 s,
## sale en 0.2 s. Un mostrar a mitad de animación revierte el movimiento y
## vuelve a entrar con el nombre nuevo.

## Fases de la animación del cartel.
enum Estado { OCULTO, ENTRANDO, FIJO, SALIENDO }

const ALTURA := 32.0
const Y_OCULTO := -32.0
const Y_VISIBLE := 0.0
const DURACION_ENTRADA := 0.2
const DURACION_SALIDA := 0.2
const TIEMPO_FIJO := 2.0

# Los miembros se inicializan antes del cuerpo de _init(): así los hijos
# existen cuando _init los añade (con @onready llegarían null).
var _etiqueta: Label = Label.new()

var _tween: Tween = null
var _estado: Estado = Estado.OCULTO

var _image_type_aplicado: int = 0

func _init() -> void:
	name = "CartelNombreLugar"
	position = Vector2(0, Y_OCULTO)
	custom_minimum_size = Vector2(112, 32)
	size = Vector2(112, 32)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Margenes del parche segun el patron del proyecto (UI/menu_box_N.png)
	patch_margin_left = 16
	patch_margin_top = 8
	patch_margin_right = 16
	patch_margin_bottom = 8
	axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE

	_etiqueta.name = "Etiqueta"
	_etiqueta.set_anchors_preset(Control.PRESET_FULL_RECT)
	_etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_etiqueta.clip_text = true
	_etiqueta.add_theme_font_override("font", preload("res://fuentes/pokemon-rs.ttf"))
	_etiqueta.add_theme_font_size_override("font_size", 13)
	_etiqueta.add_theme_color_override("font_color", Color(0.282353, 0.282353, 0.282353))
	_etiqueta.add_theme_color_override("font_shadow_color", Color(0.282353, 0.282353, 0.282353, 0.5))
	_etiqueta.add_theme_constant_override("shadow_offset_x", 1)
	_etiqueta.add_theme_constant_override("shadow_offset_y", 0)
	add_child(_etiqueta)

func _ready() -> void:
	_aplicar_textura_opciones()
	_conectar_opciones_cambiadas()

## Muestra el cartel: entra a (0,0) en 0.2 s, se mantiene fijo `segundos_fijo`
## y sale a (0,-32) en 0.2 s. Si se llama de nuevo a mitad de animación,
## revierte lo que estaba haciendo y vuelve a entrar con el nombre nuevo.
func mostrar(nombre: String, segundos_fijo: float = TIEMPO_FIJO) -> void:
	if nombre.is_empty():
		return
	_aplicar_textura_opciones()
	_matar_tween()
	visible = true
	_tween = create_tween()
	match _estado:
		Estado.OCULTO:
			position = Vector2(0, Y_OCULTO)
			_encadenar_ciclo(nombre, segundos_fijo)
		Estado.ENTRANDO, Estado.FIJO:
			# A mitad de entrada o fijo: sale (aunque esté a mitad de camino)
			# y vuelve a entrar con el nombre nuevo.
			_estado = Estado.SALIENDO
			_tween.tween_property(self, "position:y", Y_OCULTO, _duracion_salida_desde(position.y))
			_encadenar_ciclo(nombre, segundos_fijo, DURACION_ENTRADA)
		Estado.SALIENDO:
			# Estaba saliendo: revierte y vuelve a entrar desde donde esté.
			_encadenar_ciclo(nombre, segundos_fijo)

## Cancela la animación actual (si la hay).
func _matar_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

## Encadena: poner el texto → entrar → fijo → salir → ocultar.
func _encadenar_ciclo(nombre: String, segundos_fijo: float, dur_entrada: float = -1.0) -> void:
	var dur_in := _duracion_entrada_desde(position.y) if dur_entrada < 0.0 else dur_entrada
	_tween.tween_callback(_poner_texto.bind(nombre))
	_estado = Estado.ENTRANDO
	_tween.tween_property(self, "position:y", Y_VISIBLE, dur_in)
	_tween.tween_callback(_al_quedar_fijo)
	_tween.tween_interval(maxf(segundos_fijo, 0.0))
	_tween.tween_callback(_al_empezar_a_salir)
	_tween.tween_property(self, "position:y", Y_OCULTO, DURACION_SALIDA)
	_tween.tween_callback(_terminar)

func _poner_texto(texto: String) -> void:
	_etiqueta.text = texto

func _al_quedar_fijo() -> void:
	_estado = Estado.FIJO

func _al_empezar_a_salir() -> void:
	_estado = Estado.SALIENDO

func _terminar() -> void:
	_estado = Estado.OCULTO
	position = Vector2(0, Y_OCULTO)
	visible = false

## Duración de salida proporcional al recorrido restante hasta (0,-32).
func _duracion_salida_desde(y: float) -> float:
	return DURACION_SALIDA * clampf((y - Y_OCULTO) / ALTURA, 0.0, 1.0)

## Duración de entrada proporcional al recorrido restante hasta (0,0).
func _duracion_entrada_desde(y: float) -> float:
	return DURACION_ENTRADA * clampf((Y_VISIBLE - y) / ALTURA, 0.0, 1.0)

## Oculta el cartel al instante (sin animación) y deja el reposo en (0,-32).
func ocultar() -> void:
	_matar_tween()
	_terminar()

func _aplicar_textura_opciones() -> void:
	var image_type := _get_image_type_actual()
	if image_type == _image_type_aplicado:
		return
	_image_type_aplicado = image_type
	var menu_box_manager = preload("res://scripts/clases/MenuBoxManager.gd")
	menu_box_manager.apply_texture_to_ninepatch(self, image_type)

func _get_image_type_actual() -> int:
	var sg = get_tree().root.get_node_or_null("SistemaGuardado")
	if sg and sg.datos_vivos and sg.datos_vivos.opciones:
		return int(sg.datos_vivos.opciones.imagen_tipo)
	return 1

func _conectar_opciones_cambiadas() -> void:
	var singleton = get_tree().root.get_node_or_null("Singleton")
	if singleton and singleton.has_signal("opciones_cambiadas"):
		if not singleton.is_connected("opciones_cambiadas", _on_opciones_cambiadas):
			singleton.connect("opciones_cambiadas", _on_opciones_cambiadas)

func _on_opciones_cambiadas() -> void:
	_aplicar_textura_opciones()

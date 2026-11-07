class_name VisorImagenCartel
extends NinePatchRect

## Ventana con el borde de menú elegido en las opciones (textura menu_box_N, en
## "tile fit") y una imagen dentro, sin texto ni cursor. Se cierra con btn_accion o
## btn_cancelar (o, con `cerrar_con_cualquier_tecla`, también con la cruceta,
## START y SELECT) y emite `cerrado`.
## La ventana mide lo que la imagen (240x160 = pantalla completa) y se coloca en la
## posición de `configurar`; la imagen va en su (0,0) sin centrar: las láminas se
## dibujan con su contenido ya dentro del margen de 8 px del borde.

signal cerrado

const ACCIONES_CIERRE: Array[StringName] = [&"btn_accion", &"btn_cancelar"]
## Acciones que cierran el visor con `cerrar_con_cualquier_tecla`
## (BrailleWait_CheckButtonPress: A, B, START, SELECT y la cruceta).
const ACCIONES_CUALQUIER_TECLA: Array[StringName] = [&"btn_accion", &"btn_cancelar", &"btn_menu",
		&"btn_select", &"btn_arriba", &"btn_abajo", &"btn_izquierda", &"btn_derecha"]

const TAMANO := Vector2(240, 160)

var _imagen: TextureRect = TextureRect.new()
## La pulsación que abrió el cartel sigue activa: no cerrar hasta soltarla.
var _esperando_soltar: bool = true
## true: cualquier tecla de ACCIONES_CUALQUIER_TECLA lo cierra.
var cerrar_con_cualquier_tecla: bool = false
## true si se cerró con una tecla; false si lo cerró quien lo abrió (cerrar()).
var cerrado_por_tecla: bool = false


func _init() -> void:
	name = "VisorImagenCartel"
	position = Vector2.ZERO
	custom_minimum_size = TAMANO
	size = TAMANO
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Márgenes del parche según UI/menu_box_N.png (24x24)
	patch_margin_left = 8
	patch_margin_top = 8
	patch_margin_right = 8
	patch_margin_bottom = 8
	axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE

	_imagen.name = "Imagen"
	_imagen.position = Vector2.ZERO
	_imagen.stretch_mode = TextureRect.STRETCH_KEEP
	_imagen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_imagen)


func _ready() -> void:
	var menu_box_manager = preload("res://scripts/clases/MenuBoxManager.gd")
	menu_box_manager.apply_texture_to_ninepatch(self, _get_image_type_actual())


func configurar(textura: Texture2D, posicion_ventana: Vector2 = Vector2.ZERO) -> void:
	_imagen.texture = textura
	position = posicion_ventana
	if textura != null:
		_imagen.size = textura.get_size()
		custom_minimum_size = textura.get_size()
		size = textura.get_size()


func _process(_delta: float) -> void:
	var acciones: Array[StringName] = ACCIONES_CUALQUIER_TECLA if cerrar_con_cualquier_tecla else ACCIONES_CIERRE
	if _esperando_soltar:
		if not acciones.any(func(a: StringName) -> bool: return Input.is_action_pressed(a)):
			_esperando_soltar = false
		return
	if acciones.any(func(a: StringName) -> bool: return Input.is_action_just_pressed(a)):
		cerrado_por_tecla = true
		cerrar()


func cerrar() -> void:
	if is_queued_for_deletion():
		return
	cerrado.emit()
	queue_free()


func _get_image_type_actual() -> int:
	var sg = get_tree().root.get_node_or_null("SistemaGuardado")
	if sg and sg.datos_vivos and sg.datos_vivos.opciones:
		return int(sg.datos_vivos.opciones.imagen_tipo)
	return 1

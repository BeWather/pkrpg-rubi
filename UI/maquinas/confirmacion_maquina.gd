extends MenuConfirmacion

## Mismo contrato/input que el SÍ/NO existente, sin construir nodos en runtime.
func crear_menu(posicion: Vector2 = Vector2(160, 64), _etiquetas: PackedStringArray = PackedStringArray(["SÍ", "NO"])) -> void:
	menu_node = $Marco
	etiqueta_si = $Marco/Si
	etiqueta_no = $Marco/No
	cursor_menu = $Marco/Cursor
	_menu_box_manager.apply_texture_to_ninepatch(menu_node, _get_saved_image_type())
	menu_node.position = posicion
	menu_node.show()
	menu_activo = true
	input_bloqueado = true
	opcion_actual = 0
	_actualizar_cursor()
	await get_tree().create_timer(0.3).timeout
	if menu_activo: input_bloqueado = false


func ocultar_menu() -> void:
	menu_activo = false
	if is_instance_valid(menu_node): menu_node.hide()


func cancelar() -> void:
	if menu_activo:
		opcion_actual = 1
		_confirmar_seleccion()

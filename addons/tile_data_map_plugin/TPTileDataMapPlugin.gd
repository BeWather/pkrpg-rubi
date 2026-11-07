@tool
extends EditorPlugin

const TILE_DATA_MAP_ICON_PATH = "res://addons/tile_data_map_plugin/icon_tile_data_map.svg"
const TILE_DATA_MAP_SCRIPT_PATH = "res://addons/tile_data_map_plugin/TPTileDataMap.gd"
const CAPAS_AGUA_SCENE_PATH = "res://escenas/mapas/capas_agua.tscn"
const CacheDibujoBanderas = preload("res://addons/tile_data_map_plugin/cache_dibujo_banderas.gd")
## Por debajo de este tamaño de celda en pantalla (px) no se dibuja la rejilla.
const LADO_MINIMO_REJILLA: float = 4.0

# ============================================================
# Clase interna: gestión de configuración de banderas
# ============================================================
class TPTileDataMapFlagsConfig extends RefCounted:
	const CONFIG_PATH = "res://addons/tile_data_map_plugin/tile_data_map_flags_config.json"
	var flags = []
	var next_id = 0

	func _init() -> void:
		load_from_file()

	func load_from_file() -> void:
		if not FileAccess.file_exists(CONFIG_PATH):
			_create_default_config()
			save_to_file()
			return
		var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
		if file == null:
			push_error("No se pudo abrir el archivo de configuración: " + CONFIG_PATH)
			_create_default_config()
			return
		var json_text = file.get_as_text()
		file.close()
		var data = JSON.parse_string(json_text)
		if data == null or typeof(data) != TYPE_DICTIONARY:
			push_error("Error al parsear JSON: " + CONFIG_PATH)
			_create_default_config()
			return
		flags = data.get("flags", [])
		next_id = data.get("next_id", 0)

	func save_to_file() -> void:
		var file = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
		if file == null:
			push_error("No se pudo escribir el archivo de configuración: " + CONFIG_PATH)
			return
		file.store_string(JSON.stringify({"flags": flags, "next_id": next_id}, "  "))
		file.close()

	func _create_default_config() -> void:
		flags = [
			{"id": 0, "name": "Bloqueo", "color": "#FF5555", "bit_index": 0},
			{"id": 1, "name": "Surf",    "color": "#5555FF", "bit_index": 1},
		]
		next_id = 2

	func add_flag(name: String, color: String) -> Dictionary:
		# Las máscaras son int de 64 bits (bits 0-62 sin tocar el signo).
		if flags.size() >= 63:
			push_error("No se pueden agregar más de 63 banderas")
			return {}
		var used_bits = []
		for flag in flags:
			used_bits.append(int(flag.bit_index))
		var bit_index = 0
		while bit_index in used_bits:
			bit_index += 1
		var new_flag = {"id": next_id, "name": name, "color": color, "bit_index": bit_index}
		flags.append(new_flag)
		next_id += 1
		save_to_file()
		return new_flag

	func remove_flag(id: int) -> void:
		for i in range(flags.size()):
			if flags[i].id == id:
				flags.remove_at(i)
				save_to_file()
				return

	func update_flag(id: int, name: String, color: String) -> void:
		for flag in flags:
			if flag.id == id:
				flag.name = name
				flag.color = color
				save_to_file()
				return

	func get_flag_by_id(id: int):
		for flag in flags:
			if flag.id == id:
				return flag
		return null

	func get_flag_mask(id: int) -> int:
		var flag = get_flag_by_id(id)
		return 0 if flag == null else 1 << int(flag.bit_index)

	func get_active_flag_names(mask: int) -> Array[String]:
		var names: Array[String] = []
		for flag in flags:
			if mask & (1 << int(flag.bit_index)):
				names.append(flag.name)
		return names

	func get_next_default_color() -> String:
		var default_colors = ["#FF5555","#5555FF","#55FF55","#FFFF55","#FF55FF","#55FFFF","#FF8800","#8800FF"]
		return default_colors[flags.size() % default_colors.size()]

# ============================================================

var tile_data_map: TPTileDataMap = null
var _toolbar: HBoxContainer = null
var _last_selected_object = null
var _tdm_panel: VBoxContainer = null
var _flags_config: TPTileDataMapFlagsConfig = null
var _selected_flag_id = null
var _config_selected_flag_id = null
var _flags_list_container: VBoxContainer = null
var _cell_info_label: Label = null
var _paint_mode_active: bool = false
var _erase_mode_active: bool = false
var _is_painting: bool = false  # Hay un trazo (libre o rectángulo) en curso
var _stroke_erase: bool = false
var _stroke_is_rect: bool = false
var _stroke_button: int = MOUSE_BUTTON_NONE
var _last_stroke_cell: Vector2 = Vector2.ZERO
var _rect_start_cell: Vector2 = Vector2.ZERO
var _rect_end_cell: Vector2 = Vector2.ZERO
var _flag_context_menu: PopupMenu = null
var _context_flag_id = null
var _is_editing: bool = false
var _last_selected_flag_id = null
var _btn_paint: Button = null
var _btn_erase: Button = null
var _tile_data_before_paint = null
var _config_list_container: VBoxContainer = null
var _config_window: Window = null
var _editing_original_name: String = ""
var _lang: String = "en"
# Aviso de celdas REFLEJO/AGUA_SALPICA sin AguaFX (ValidadorCapasAgua.faltan_efectos_agua)
var _aviso_agua: VBoxContainer = null
var _aviso_agua_label: Label = null
var _btn_arreglar_agua: Button = null
var _segundos_revision_aviso_agua: float = 0.0
# Banderas dibujadas en canvas items retenidos (ver PATRONES_DIBUJO_BANDERAS.md)
var _cache_banderas: CacheDibujoBanderas = null


func _t(es: String, en: String) -> String:
	return es if _lang == "es" else en


func _enter_tree() -> void:
	var editor_lang = get_editor_interface().get_editor_settings().get_setting("interface/editor/editor_language")
	if typeof(editor_lang) == TYPE_STRING and (editor_lang as String).begins_with("es"):
		_lang = "es"
	else:
		_lang = "en"
	add_custom_type("TPTileDataMap", "Node2D", load(TILE_DATA_MAP_SCRIPT_PATH), load(TILE_DATA_MAP_ICON_PATH))
	_flags_config = TPTileDataMapFlagsConfig.new()
	_cache_banderas = CacheDibujoBanderas.new()
	_cache_banderas.configurar_banderas(_flags_config.flags)
	_toolbar = _build_toolbar()
	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, _toolbar)
	_toolbar.hide()
	_tdm_panel = _build_tdm_panel()
	add_control_to_container(CONTAINER_CANVAS_EDITOR_SIDE_RIGHT, _tdm_panel)
	_tdm_panel.hide()
	set_process(true)
	# Diferir la inicialización para que el canvas overlay esté listo
	call_deferred("_init_with_current_selection")


func _exit_tree() -> void:
	remove_custom_type("TPTileDataMap")
	if _cache_banderas != null:
		_cache_banderas.liberar()
		_cache_banderas = null
	if _toolbar != null:
		remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, _toolbar)
		_toolbar.queue_free()
		_toolbar = null
	if _tdm_panel != null:
		remove_control_from_container(CONTAINER_CANVAS_EDITOR_SIDE_RIGHT, _tdm_panel)
		_tdm_panel.queue_free()
		_tdm_panel = null
	if _config_window != null:
		_config_window.queue_free()
		_config_window = null
	if _flag_context_menu != null:
		_flag_context_menu.queue_free()
		_flag_context_menu = null


func _build_toolbar() -> HBoxContainer:
	var base := get_editor_interface().get_base_control()
	var hbox := HBoxContainer.new()
	hbox.add_child(VSeparator.new())

	_btn_paint = Button.new()
	_btn_paint.icon = base.get_theme_icon("Edit", "EditorIcons")
	_btn_paint.tooltip_text = _t(
		"Pintar flags\nClick izq.: pintar · Click der.: borrar la flag\nShift + arrastrar: rectangulo (Esc cancela)",
		"Paint flags\nLeft click: paint · Right click: erase the flag\nShift + drag: rectangle (Esc cancels)")
	_btn_paint.toggle_mode = true
	_btn_paint.focus_mode = Control.FOCUS_NONE
	_btn_paint.toggled.connect(_on_paint_mode_toggled)
	hbox.add_child(_btn_paint)

	_btn_erase = Button.new()
	_btn_erase.icon = base.get_theme_icon("Clear", "EditorIcons")
	_btn_erase.tooltip_text = _t(
		"Borrar flags\nBorra la flag seleccionada, o todas si no hay ninguna\nShift + arrastrar: rectangulo (Esc cancela)",
		"Erase flags\nErases the selected flag, or all of them if none is selected\nShift + drag: rectangle (Esc cancels)")
	_btn_erase.toggle_mode = true
	_btn_erase.focus_mode = Control.FOCUS_NONE
	_btn_erase.toggled.connect(_on_erase_mode_toggled)
	hbox.add_child(_btn_erase)

	var btn_config := Button.new()
	btn_config.icon = load(TILE_DATA_MAP_ICON_PATH)
	btn_config.text = "TPTileDataMap"
	btn_config.focus_mode = Control.FOCUS_NONE
	btn_config.tooltip_text = _t("Configuracion de banderas", "Flag configuration")
	btn_config.pressed.connect(_on_open_config_pressed)
	hbox.add_child(btn_config)

	return hbox


func _on_paint_mode_toggled(pressed: bool) -> void:
	_paint_mode_active = pressed
	if pressed:
		if _btn_erase != null:
			_btn_erase.set_pressed_no_signal(false)
			_erase_mode_active = false
		# Restaurar la última bandera seleccionada, o seleccionar la primera disponible
		if _selected_flag_id == null:
			var target_id = _last_selected_flag_id
			if target_id == null and _flags_config != null and _flags_config.flags.size() > 0:
				target_id = _flags_config.flags[0].id
			if target_id != null:
				_select_flag(target_id)
				update_overlays()
	else:
		# Desactivar el boton desactiva también la bandera
		_deselect_flag()
		update_overlays()


func _on_erase_mode_toggled(pressed: bool) -> void:
	_erase_mode_active = pressed
	if pressed:
		# La goma conserva la bandera seleccionada: borra solo esa, o todas si no hay ninguna
		if _btn_paint != null:
			_btn_paint.set_pressed_no_signal(false)
			_paint_mode_active = false
	else:
		_deselect_flag()
	update_overlays()


func _on_open_config_pressed() -> void:
	if _config_window != null and is_instance_valid(_config_window):
		_config_window.popup_centered()
		return

	_config_window = Window.new()
	_config_window.title = _t("TPTileDataMap - Configuracion de Banderas", "TPTileDataMap - Flag Configuration")
	_config_window.min_size = Vector2i(280, 440)
	get_editor_interface().get_base_control().add_child(_config_window)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(260, 0)
	_config_window.add_child(vbox)

	var title := Label.new()
	title.text = "TPTileDataMap Flags"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 320)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_config_list_container = VBoxContainer.new()
	_config_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_config_list_container)

	var btn_add := Button.new()
	btn_add.text = _t("+ Nueva Bandera", "+ New Flag")
	btn_add.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn_add.pressed.connect(_on_add_flag_pressed)
	vbox.add_child(btn_add)

	_config_window.close_requested.connect(_on_config_window_closed)
	_update_flags_container(_config_list_container, true)
	if _config_selected_flag_id != null:
		_apply_selection_in_container(_config_list_container, _config_selected_flag_id)
	_config_window.popup_centered()


func _on_config_window_closed() -> void:
	_config_list_container = null
	var win := _config_window
	_config_window = null
	if win != null:
		win.queue_free()


func _build_tdm_panel() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(220, 0)

	var title := Label.new()
	title.text = "TPTileDataMap Flags"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	_aviso_agua = VBoxContainer.new()
	_aviso_agua_label = Label.new()
	_aviso_agua_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_aviso_agua_label.add_theme_color_override("font_color",
		get_editor_interface().get_base_control().get_theme_color(&"warning_color", &"Editor"))
	_aviso_agua.add_child(_aviso_agua_label)
	_btn_arreglar_agua = Button.new()
	_btn_arreglar_agua.pressed.connect(_on_arreglar_agua_pressed)
	_aviso_agua.add_child(_btn_arreglar_agua)
	_aviso_agua.add_child(HSeparator.new())
	_aviso_agua.hide()
	vbox.add_child(_aviso_agua)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 200)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_flags_list_container = VBoxContainer.new()
	_flags_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_flags_list_container)

	vbox.add_child(HSeparator.new())

	var info_label := Label.new()
	info_label.text = _t("Celda seleccionada:", "Selected cell:")
	vbox.add_child(info_label)

	_cell_info_label = Label.new()
	_cell_info_label.text = _t("Ninguna", "None")
	_cell_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_cell_info_label)

	_update_flags_list()
	# Deseleccionar bandera al hacer clic en el fondo del panel
	scroll.gui_input.connect(_on_panel_background_clicked)
	_flags_list_container.gui_input.connect(_on_panel_background_clicked)
	return vbox


func _on_panel_background_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_deselect_flag()
		update_overlays()


func _update_flags_list() -> void:
	if _cache_banderas != null:
		_cache_banderas.configurar_banderas(_flags_config.flags)
	_update_flags_container(_flags_list_container, false)
	_update_flags_container(_config_list_container, true)


func _update_flags_container(container: VBoxContainer, show_controls: bool) -> void:
	if container == null or _flags_config == null:
		return
	for child in container.get_children():
		child.queue_free()
	for flag in _flags_config.flags:
		container.add_child(_create_flag_item(flag, show_controls))


func _create_flag_item(flag: Dictionary, show_controls: bool) -> PanelContainer:
	var base := get_editor_interface().get_base_control()
	var panel := PanelContainer.new()
	panel.set_meta("flag_id", flag.id)

	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0, 0, 0, 0)
	style_normal.set_border_width_all(1)
	style_normal.border_color = Color(0.3, 0.3, 0.3, 1.0)

	var style_selected := StyleBoxFlat.new()
	style_selected.bg_color = Color(0.3, 0.5, 0.8, 0.3)
	style_selected.set_border_width_all(2)
	style_selected.border_color = Color(0.5, 0.7, 1.0, 1.0)

	panel.add_theme_stylebox_override("panel", style_normal)
	panel.set_meta("style_normal", style_normal)
	if not show_controls:
		panel.set_meta("style_selected", style_selected)

	var hbox := HBoxContainer.new()
	panel.add_child(hbox)

	var color_rect := ColorRect.new()
	color_rect.custom_minimum_size = Vector2(16, 16)
	color_rect.color = Color(flag.color)
	color_rect.tooltip_text = _t("Haz clic para cambiar el color", "Click to change color")
	color_rect.gui_input.connect(_on_flag_color_clicked.bind(flag.id))
	hbox.add_child(color_rect)

	var name_label := Label.new()
	name_label.text = flag.name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = false
	name_label.set_meta("flag_id", flag.id)
	name_label.set_meta("is_editing", false)
	hbox.add_child(name_label)

	if show_controls:
		var btn_edit := Button.new()
		btn_edit.icon = base.get_theme_icon("Edit", "EditorIcons")
		btn_edit.custom_minimum_size = Vector2(24, 0)
		btn_edit.tooltip_text = _t("Editar nombre", "Edit name")
		btn_edit.pressed.connect(_on_flag_edit_pressed.bind(flag.id, name_label))
		hbox.add_child(btn_edit)
		panel.set_meta("btn_edit", btn_edit)

		var btn_remove := Button.new()
		btn_remove.icon = base.get_theme_icon("Remove", "EditorIcons")
		btn_remove.custom_minimum_size = Vector2(24, 0)
		btn_remove.tooltip_text = _t("Eliminar bandera", "Remove flag")
		btn_remove.pressed.connect(_on_flag_remove_pressed.bind(flag.id))
		hbox.add_child(btn_remove)

	panel.gui_input.connect(_on_flag_item_gui_input.bind(flag.id, show_controls, panel))
	return panel


func _on_flag_item_gui_input(event: InputEvent, flag_id: int, is_config: bool, panel: PanelContainer) -> void:
	if not is_config and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_show_flag_context_menu(flag_id, panel.get_screen_position() + event.position)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_config:
			if panel.has_meta("btn_edit"):
				(panel.get_meta("btn_edit") as Button).grab_focus()
		else:
			if _selected_flag_id == flag_id:
				_deselect_flag()
			else:
				_select_flag(flag_id)
			update_overlays()


func _select_flag(flag_id: int) -> void:
	_selected_flag_id = flag_id
	_last_selected_flag_id = flag_id
	_apply_selection_in_container(_flags_list_container, flag_id)
	# Activar el botón de pintar sin disparar la señal, salvo con la goma activa
	# (en ese caso la goma pasa a borrar solo esta bandera)
	if not _erase_mode_active and _btn_paint != null and not _btn_paint.button_pressed:
		_btn_paint.set_pressed_no_signal(true)
		_paint_mode_active = true


func _deselect_flag() -> void:
	_selected_flag_id = null
	_apply_selection_in_container(_flags_list_container, -1)
	if _btn_paint != null and _btn_paint.button_pressed:
		_btn_paint.set_pressed_no_signal(false)
		_paint_mode_active = false


func _select_config_flag(flag_id: int) -> void:
	_config_selected_flag_id = flag_id
	_apply_selection_in_container(_config_list_container, flag_id)


func _apply_selection_in_container(container: VBoxContainer, flag_id: int) -> void:
	if container == null:
		return
	for child in container.get_children():
		if child is PanelContainer:
			if not child.has_meta("style_selected"):
				continue
			var item_flag_id: int = child.get_meta("flag_id")
			if item_flag_id == flag_id:
				child.add_theme_stylebox_override("panel", child.get_meta("style_selected"))
			else:
				child.add_theme_stylebox_override("panel", child.get_meta("style_normal"))


func _on_flag_color_clicked(event: InputEvent, flag_id: int) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	var popup := Window.new()
	popup.title = _t("Seleccionar Color", "Select Color")
	popup.min_size = Vector2i(300, 300)
	get_editor_interface().get_base_control().add_child(popup)

	var vbox := VBoxContainer.new()
	popup.add_child(vbox)
	var picker := ColorPicker.new()
	vbox.add_child(picker)

	var flag = _flags_config.get_flag_by_id(flag_id)
	if flag != null:
		picker.color = Color(flag.color)

	var btn_ok := Button.new()
	btn_ok.text = _t("Aceptar", "OK")
	vbox.add_child(btn_ok)
	btn_ok.pressed.connect(_on_color_picker_ok.bind(picker, flag_id, popup))
	popup.close_requested.connect(_on_color_picker_closed.bind(popup))
	popup.popup_centered()


func _on_color_picker_ok(picker: ColorPicker, flag_id: int, popup: Window) -> void:
	var color := picker.color
	var color_hex := "#%02X%02X%02X" % [int(color.r * 255), int(color.g * 255), int(color.b * 255)]
	var flag = _flags_config.get_flag_by_id(flag_id)
	if flag != null:
		_flags_config.update_flag(flag_id, flag.name, color_hex)
		_update_flags_list()
		_select_flag(_selected_flag_id)
	popup.hide()


func _on_color_picker_closed(popup: Window) -> void:
	popup.queue_free()


func _on_flag_edit_pressed(flag_id: int, label: Label) -> void:
	_start_editing_flag_name(flag_id, label)


func _start_editing_flag_name(flag_id: int, label: Label) -> void:
	if label.get_meta("is_editing"):
		return
	_editing_original_name = label.text
	label.set_meta("is_editing", true)

	var line_edit := LineEdit.new()
	line_edit.text = label.text
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var parent := label.get_parent()
	var index := label.get_index()
	parent.remove_child(label)
	parent.add_child(line_edit)
	parent.move_child(line_edit, index)

	line_edit.text_submitted.connect(_on_flag_name_entered.bind(flag_id, line_edit, label))
	line_edit.focus_exited.connect(_on_flag_name_focus_lost.bind(flag_id, line_edit, label))
	line_edit.gui_input.connect(_on_flag_name_line_edit_input.bind(flag_id, line_edit, label))
	line_edit.grab_focus()
	line_edit.select_all()


func _on_flag_name_entered(new_name: String, flag_id: int, line_edit: LineEdit, label: Label) -> void:
	_finish_editing_flag_name(true, new_name, flag_id, line_edit, label)


func _on_flag_name_focus_lost(flag_id: int, line_edit: LineEdit, label: Label) -> void:
	_finish_editing_flag_name(false, line_edit.text, flag_id, line_edit, label)


func _on_flag_name_line_edit_input(event: InputEvent, flag_id: int, line_edit: LineEdit, label: Label) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		line_edit.accept_event()
		_finish_editing_flag_name(false, "", flag_id, line_edit, label)


func _finish_editing_flag_name(save: bool, new_name: String, flag_id: int, line_edit: LineEdit, label: Label) -> void:
	if line_edit.focus_exited.is_connected(_on_flag_name_focus_lost):
		line_edit.focus_exited.disconnect(_on_flag_name_focus_lost)
	if line_edit.text_submitted.is_connected(_on_flag_name_entered):
		line_edit.text_submitted.disconnect(_on_flag_name_entered)
	if line_edit.gui_input.is_connected(_on_flag_name_line_edit_input):
		line_edit.gui_input.disconnect(_on_flag_name_line_edit_input)

	if save:
		if new_name.strip_edges() == "":
			new_name = _t("Bandera", "Flag")
		var flag = _flags_config.get_flag_by_id(flag_id)
		if flag != null:
			_flags_config.update_flag(flag_id, new_name, flag.color)
			label.text = new_name
			_update_flags_container(_flags_list_container, false)
			if _selected_flag_id != null:
				_apply_selection_in_container(_flags_list_container, _selected_flag_id)
	else:
		label.text = _editing_original_name

	var parent := line_edit.get_parent()
	var index := line_edit.get_index()
	parent.remove_child(line_edit)
	parent.add_child(label)
	parent.move_child(label, index)
	label.set_meta("is_editing", false)
	line_edit.queue_free()
	_editing_original_name = ""


func _on_flag_remove_pressed(flag_id: int) -> void:
	_flags_config.remove_flag(flag_id)
	if _selected_flag_id == flag_id:
		_selected_flag_id = null
	_update_flags_list()


func _on_add_flag_pressed() -> void:
	var new_name := _t("Bandera", "Flag") + "_" + str(_flags_config.flags.size() + 1)
	var new_color := _flags_config.get_next_default_color()
	var new_flag := _flags_config.add_flag(new_name, new_color)
	if new_flag.is_empty():
		push_error(_t("No se pudo agregar la bandera (limite de 16 alcanzado)", "Could not add flag (16 flag limit reached)"))
		return
	_update_flags_list()
	_select_config_flag(new_flag.id)


func _show_flag_context_menu(flag_id: int, screen_pos: Vector2) -> void:
	if tile_data_map == null or _flags_config == null:
		return
	if _flag_context_menu == null:
		_flag_context_menu = PopupMenu.new()
		_flag_context_menu.id_pressed.connect(_on_flag_context_menu_id_pressed)
		get_editor_interface().get_base_control().add_child(_flag_context_menu)
	_context_flag_id = flag_id
	var mask := _flags_config.get_flag_mask(flag_id)
	var count := 0
	for key in tile_data_map.tile_data:
		if int(tile_data_map.tile_data[key].get("flags", 0)) & mask:
			count += 1
	_flag_context_menu.clear()
	_flag_context_menu.add_item(_t("Quitar de todo el mapa (%d tiles)", "Remove from whole map (%d tiles)") % count, 0)
	_flag_context_menu.set_item_disabled(0, count == 0)
	_flag_context_menu.popup(Rect2i(Vector2i(screen_pos), Vector2i.ZERO))


func _on_flag_context_menu_id_pressed(_id: int) -> void:
	if tile_data_map == null or _context_flag_id == null:
		return
	var flag = _flags_config.get_flag_by_id(_context_flag_id)
	var mask := _flags_config.get_flag_mask(_context_flag_id)
	if flag == null or mask == 0:
		return
	_tile_data_before_paint = tile_data_map.tile_data.duplicate(true)
	for key in tile_data_map.tile_data.keys():
		var flags: int = tile_data_map.tile_data[key].get("flags", 0)
		if flags & mask:
			_write_cell_flags_by_key(key, flags & ~mask)
	_commit_paint_action(_t("Quitar bandera '%s' del mapa", "Remove flag '%s' from map") % flag.name)
	_update_cell_info()


func _update_cell_info() -> void:
	if _cell_info_label == null or tile_data_map == null:
		return
	if tile_data_map.selected_cell == Vector2(-1, -1):
		_cell_info_label.text = _t("Ninguna", "None")
		return
	var cell: Vector2 = tile_data_map.selected_cell
	var data := tile_data_map.get_cell_data(cell)
	var flags_mask: int = data.get("flags", 0)
	var flag_names := _flags_config.get_active_flag_names(flags_mask)
	var flags_text := _t("Ninguna", "None")
	if flag_names.size() > 0:
		flags_text = ", ".join(PackedStringArray(flag_names))
	_cell_info_label.text = "(%d, %d)\n%s %s" % [int(cell.x), int(cell.y), _t("Flags:", "Flags:"), flags_text]


func _process(delta: float) -> void:
	# El overlay ya no se redibuja en cada frame: solo con ratón, vista o cambios
	# (ver PATRONES_DIBUJO_BANDERAS.md). Aquí solo se rehacen los bloques de banderas pendientes.
	if _is_editing and tile_data_map != null:
		_cache_banderas.filtrar(0 if _selected_flag_id == null else _flags_config.get_flag_mask(_selected_flag_id))
		_cache_banderas.actualizar()
		# Revisión periódica del aviso de agua: detecta cambios hechos fuera del
		# panel (borrar CapasAgua, apagar `reflejos` en el inspector…).
		_segundos_revision_aviso_agua += delta
		if _segundos_revision_aviso_agua >= 1.0:
			_actualizar_aviso_agua()

	var current_selected = get_tree().edited_scene_root
	if current_selected != null:
		var selected_nodes := get_editor_interface().get_selection().get_selected_nodes()
		current_selected = selected_nodes[0] if selected_nodes.size() > 0 else null
	if current_selected != _last_selected_object:
		_last_selected_object = current_selected
		_edit(current_selected)


func _handles(object: Object) -> bool:
	if object == null:
		return false
	var s := object.get_script()
	return s != null and s.resource_path == TILE_DATA_MAP_SCRIPT_PATH


func _init_with_current_selection() -> void:
	var selected_nodes := get_editor_interface().get_selection().get_selected_nodes()
	if selected_nodes.size() > 0 and _handles(selected_nodes[0]):
		_last_selected_object = selected_nodes[0]
		_edit(selected_nodes[0])
		# Segundo diferido para dar tiempo al canvas overlay a montarse
		call_deferred("update_overlays")

## Deja las herramientas como recién abiertas: sin trazo en curso, sin pincel ni
## goma y sin bandera seleccionada. Evita que el estado de un nodo (o un trazo
## cuyo soltar de botón se perdió) reaparezca al volver a seleccionar.
func _reset_tool_state() -> void:
	# Un trazo libre ya modificó tile_data del nodo anterior: se confirma para que sea deshacible.
	if _is_painting and not _stroke_is_rect and is_instance_valid(tile_data_map):
		_commit_paint_action(_t("Borrar banderas", "Erase flags") if _stroke_erase else _t("Pintar banderas", "Paint flags"))
	_is_painting = false
	_stroke_is_rect = false
	_stroke_erase = false
	_stroke_button = MOUSE_BUTTON_NONE
	_tile_data_before_paint = null
	if _btn_erase != null:
		_btn_erase.set_pressed_no_signal(false)
	_erase_mode_active = false
	_deselect_flag()  # apaga también el botón de pintar


func _edit(object: Object) -> void:
	if _handles(object):
		if object != tile_data_map:
			_reset_tool_state()
		tile_data_map = object
		_is_editing = true
		_cache_banderas.asignar_capa(tile_data_map)
		_cache_banderas.set_visible(true)
		if _toolbar != null: _toolbar.show()
		if _tdm_panel != null: _tdm_panel.show()
		_actualizar_aviso_agua()
	else:
		# Mantener tile_data_map para que el overlay siga dibujándose
		_reset_tool_state()
		_is_editing = false
		# El editor deja de llamar al overlay al deseleccionar: las banderas se ocultan igual.
		_cache_banderas.set_visible(false)
		if _toolbar != null: _toolbar.hide()
		if _tdm_panel != null: _tdm_panel.hide()
	update_overlays()


func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	if tile_data_map == null or not is_instance_valid(tile_data_map):
		tile_data_map = null
		return
	if not tile_data_map.is_visible_in_tree():
		return
	var vp := tile_data_map.get_viewport()
	var xform: Transform2D = vp.global_canvas_transform
	var tile_size_v := Vector2(tile_data_map.tile_size, tile_data_map.tile_size)

	# Las banderas no se dibujan aquí: viven en _cache_banderas (canvas items
	# retenidos). El overlay solo lleva lo que depende del ratón y de la vista.
	if _is_editing:
		_draw_tile_grid(overlay, xform)

	if _is_editing:
		var mouse_pos := overlay.get_local_mouse_position()
		var world_pos := xform.affine_inverse() * mouse_pos
		var hovered_cell: Vector2 = (world_pos / tile_data_map.tile_size).floor()
		var erasing := _stroke_erase if _is_painting else _erase_mode_active
		var tool_color := _get_tool_color(erasing)
		if _is_painting and _stroke_is_rect:
			_draw_rect_preview(overlay, xform, tool_color)
		var hover_rect := Rect2(xform * (hovered_cell * tile_data_map.tile_size), xform.basis_xform(tile_size_v))
		overlay.draw_rect(hover_rect, tool_color, false, 2.0)
		if erasing:
			overlay.draw_line(hover_rect.position, hover_rect.end, tool_color, 2.0)
			overlay.draw_line(Vector2(hover_rect.end.x, hover_rect.position.y), Vector2(hover_rect.position.x, hover_rect.end.y), tool_color, 2.0)

		var font := get_editor_interface().get_base_control().get_theme_font("font", "Label")
		var texto := _get_status_text(hovered_cell, erasing)
		if font != null and texto != "":
			# Etiqueta con fondo apilada sobre la de coordenada (tilemap_inspector, 24 px + 8 de margen).
			var medida := font.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
			var caja := Rect2(Vector2(12, overlay.size.y - 8 - 24 - 4 - 24), medida + Vector2(12, 8))
			caja.size.y = 24
			overlay.draw_rect(caja, Color(0, 0, 0, 0.7))
			overlay.draw_string(font, caja.position + Vector2(6, 4 + font.get_ascent(14)), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1))


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if tile_data_map == null or not _is_editing:
		return false
	if not tile_data_map.is_visible_in_tree():
		return false

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and _is_painting and _stroke_is_rect:
		_cancel_rect_stroke()
		return true

	if event is InputEventMouseMotion:
		# Soltar de botón perdido (foco, cambio de selección…): sin botones pulsados
		# no puede haber trazo. Un rectángulo se descarta; el trazo libre ya está aplicado.
		if _is_painting and event.button_mask == 0:
			if _stroke_is_rect:
				_cancel_rect_stroke()
			else:
				_finish_stroke()
		if _is_painting:
			var cell := _cell_at(event.position)
			if _stroke_is_rect:
				_rect_end_cell = cell
			else:
				_stroke_to_cell(cell)
				_update_cell_info()
		update_overlays()
		return _is_painting

	if not (event is InputEventMouseButton):
		return false
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT:
		return false

	if not mb.pressed:
		if _is_painting and mb.button_index == _stroke_button:
			_finish_stroke()
			return true
		return mb.button_index == MOUSE_BUTTON_LEFT or _is_painting

	if _is_painting:
		# El otro botón cancela un rectángulo; en trazo libre se ignora
		if _stroke_is_rect:
			_cancel_rect_stroke()
		return true

	var tool_active := _erase_mode_active or (_paint_mode_active and _selected_flag_id != null)
	if mb.button_index == MOUSE_BUTTON_RIGHT and not tool_active:
		# Sin herramienta activa el click derecho no borra nada
		return false

	var cell := _cell_at(mb.position)
	tile_data_map.selected_cell = cell
	tile_data_map.notify_property_list_changed()
	if tool_active:
		var erase := _erase_mode_active or mb.button_index == MOUSE_BUTTON_RIGHT
		_start_stroke(cell, mb.button_index, erase, mb.shift_pressed)
	_update_cell_info()
	update_overlays()
	return true


func _cell_at(mouse_pos: Vector2) -> Vector2:
	var xform: Transform2D = tile_data_map.get_viewport().global_canvas_transform
	return ((xform.affine_inverse() * mouse_pos) / tile_data_map.tile_size).floor()


func _start_stroke(cell: Vector2, button: int, erase: bool, as_rect: bool) -> void:
	_tile_data_before_paint = tile_data_map.tile_data.duplicate(true)
	_is_painting = true
	_stroke_button = button
	_stroke_erase = erase
	_stroke_is_rect = as_rect
	_rect_start_cell = cell
	_rect_end_cell = cell
	_last_stroke_cell = cell
	if not as_rect:
		_apply_stroke_to_cell(cell)


func _finish_stroke() -> void:
	if _stroke_is_rect:
		var from := _rect_start_cell.min(_rect_end_cell)
		var to := _rect_start_cell.max(_rect_end_cell)
		for y in range(int(from.y), int(to.y) + 1):
			for x in range(int(from.x), int(to.x) + 1):
				_apply_stroke_to_cell(Vector2(x, y))
	_commit_paint_action(_t("Borrar banderas", "Erase flags") if _stroke_erase else _t("Pintar banderas", "Paint flags"))
	_is_painting = false
	_stroke_is_rect = false
	_update_cell_info()
	update_overlays()


## Un rectángulo aún no modificó tile_data, así que cancelarlo solo descarta el estado.
func _cancel_rect_stroke() -> void:
	_is_painting = false
	_stroke_is_rect = false
	_tile_data_before_paint = null
	update_overlays()


## Aplica el trazo a todas las celdas entre la última visitada y `cell`,
## para no dejar huecos cuando el mouse se mueve rápido.
func _stroke_to_cell(cell: Vector2) -> void:
	var steps := int(maxf(absf(cell.x - _last_stroke_cell.x), absf(cell.y - _last_stroke_cell.y)))
	for i in range(1, steps + 1):
		_apply_stroke_to_cell(_last_stroke_cell.lerp(cell, float(i) / steps).round())
	_last_stroke_cell = cell


## Pinta la bandera seleccionada, o la borra (todas si no hay bandera seleccionada).
func _apply_stroke_to_cell(cell: Vector2) -> void:
	var current: int = tile_data_map.get_cell_data(cell).get("flags", 0)
	var mask := 0 if _selected_flag_id == null else _flags_config.get_flag_mask(_selected_flag_id)
	var result: int
	if not _stroke_erase:
		result = current | mask
	elif _selected_flag_id == null:
		result = 0
	else:
		result = current & ~mask
	if result != current:
		_write_cell_flags_by_key("%d,%d" % [cell.x, cell.y], result)


## Escribe en tile_data sin notificar (la notificación llega al confirmar la acción
## de undo). Si la celda queda sin flags elimina la entrada para no acumular claves vacías.
func _write_cell_flags_by_key(key: String, flags: int) -> void:
	if tile_data_map.tile_data.is_read_only():
		tile_data_map.tile_data = tile_data_map.tile_data.duplicate(true)
	var data: Dictionary = tile_data_map.tile_data.get(key, {})
	if flags == 0 and data.size() <= 1:
		tile_data_map.tile_data.erase(key)
	else:
		data["flags"] = flags
		tile_data_map.tile_data[key] = data
	_cache_banderas.marcar_celda(key)


func _get_tool_color(erasing: bool) -> Color:
	if erasing:
		return Color(1.0, 0.25, 0.25, 0.9)
	if _paint_mode_active and _selected_flag_id != null:
		var flag = _flags_config.get_flag_by_id(_selected_flag_id)
		if flag != null:
			return Color(flag.color)
	return Color(1, 1, 1, 0.5)


## Descripción del pincel (sin coordenada: esa la muestra siempre el plugin
## tilemap_inspector en la esquina inferior izquierda). Vacía si no hay nada que decir.
func _get_status_text(_hovered_cell: Vector2, erasing: bool) -> String:
	var parts: PackedStringArray = []
	var flag = null if _selected_flag_id == null else _flags_config.get_flag_by_id(_selected_flag_id)
	if erasing:
		parts.append(_t("Borrar: ", "Erase: ") + (flag.name if flag != null else _t("todas", "all")))
	elif _paint_mode_active and flag != null:
		parts.append(_t("Pintar: ", "Paint: ") + flag.name)
	if _is_painting and _stroke_is_rect:
		var size := (_rect_start_cell - _rect_end_cell).abs() + Vector2.ONE
		parts.append("%d×%d" % [int(size.x), int(size.y)])
	return "  ·  ".join(parts)


func _draw_rect_preview(overlay: Control, xform: Transform2D, color: Color) -> void:
	var from := _rect_start_cell.min(_rect_end_cell)
	var size := _rect_start_cell.max(_rect_end_cell) - from + Vector2.ONE
	var rect := Rect2(xform * (from * tile_data_map.tile_size), xform.basis_xform(size * tile_data_map.tile_size))
	var fill := color
	fill.a = 0.25
	overlay.draw_rect(rect, fill, true)
	overlay.draw_rect(rect, color, false, 2.0)


func _draw_tile_grid(overlay: Control, xform: Transform2D) -> void:
	var tile_size := float(tile_data_map.tile_size)
	var inv := xform.affine_inverse()
	var tl := inv * Vector2.ZERO
	var br := inv * overlay.size
	if xform.get_scale().x * tile_size < LADO_MINIMO_REJILLA:
		return

	# Obtener color de grilla del tema del editor
	var base := get_editor_interface().get_base_control()
	var col: Color = base.get_theme_color("grid_minor_color", "Editor") if base.has_theme_color("grid_minor_color", "Editor") else Color(1, 1, 1, 0.07)

	# Líneas verticales
	var x: float = floor(tl.x / tile_size) * tile_size
	while x <= br.x + tile_size:
		var p0 := xform * Vector2(x, tl.y - tile_size)
		var p1 := xform * Vector2(x, br.y + tile_size)
		overlay.draw_line(p0, p1, col, 1.0)
		x += tile_size

	# Líneas horizontales
	var y: float = floor(tl.y / tile_size) * tile_size
	while y <= br.y + tile_size:
		var p0 := xform * Vector2(tl.x - tile_size, y)
		var p1 := xform * Vector2(br.x + tile_size, y)
		overlay.draw_line(p0, p1, col, 1.0)
		y += tile_size


func _commit_paint_action(action_name: String) -> void:
	if tile_data_map == null or _tile_data_before_paint == null:
		return
	var tile_data_after := tile_data_map.tile_data.duplicate(true)
	if tile_data_after == _tile_data_before_paint:
		_tile_data_before_paint = null
		return
	var undo_redo := get_undo_redo()
	undo_redo.create_action(action_name)
	undo_redo.add_do_property(tile_data_map, "tile_data", tile_data_after)
	undo_redo.add_undo_property(tile_data_map, "tile_data", _tile_data_before_paint)
	undo_redo.add_do_method(tile_data_map, "notify_property_list_changed")
	undo_redo.add_undo_method(tile_data_map, "notify_property_list_changed")
	undo_redo.add_do_method(self, "update_overlays")
	undo_redo.add_undo_method(self, "update_overlays")
	undo_redo.add_do_method(self, "_refrescar_avisos_agua")
	undo_redo.add_undo_method(self, "_refrescar_avisos_agua")
	undo_redo.commit_action()
	# El "do" asigna una copia con el mismo contenido que ya se dibujó celda a celda:
	# no hace falta reconstruir todo. Deshacer/rehacer después sí lo reconstruye.
	_cache_banderas.adoptar_datos()
	_tile_data_before_paint = null


# ============================================================
# Aviso de efectos de agua sin CapasAgua
# ============================================================

## MapaConfiguracion de la capa de datos editada, o null.
func _mapa_editado() -> MapaConfiguracion:
	if not is_instance_valid(tile_data_map) or not tile_data_map.is_inside_tree():
		return null
	return ValidadorCapasAgua.mapa_ancestro(tile_data_map)


## Muestra el aviso y el botón si la capa de datos 0 del mapa tiene celdas
## REFLEJO/AGUA_SALPICA que no se van a dibujar (sin CapasAgua o con sus
## `reflejos` apagados).
func _actualizar_aviso_agua() -> void:
	_segundos_revision_aviso_agua = 0.0
	if _aviso_agua == null:
		return
	var mapa := _mapa_editado()
	if mapa == null or not ValidadorCapasAgua.faltan_efectos_agua(mapa):
		_aviso_agua.hide()
		return
	if mapa.obtener_capas_agua() != null:
		_aviso_agua_label.text = _t(
			"Hay celdas REFLEJO/AGUA_SALPICA pero CapasAgua tiene 'reflejos' desactivado: no se verán.",
			"There are REFLEJO/AGUA_SALPICA cells but CapasAgua has 'reflejos' disabled: they won't show.")
		_btn_arreglar_agua.text = _t("Activar reflejos", "Enable reflections")
		_btn_arreglar_agua.disabled = false
	else:
		var hay_agua := ValidadorCapasAgua.capa_agua_de_mapa(mapa) != null
		_aviso_agua_label.text = _t(
			"Hay celdas REFLEJO/AGUA_SALPICA pero el mapa no tiene CapasAgua: no se verán los reflejos ni las ondas.",
			"There are REFLEJO/AGUA_SALPICA cells but the map has no CapasAgua: reflections and ripples won't show.")
		if not hay_agua:
			_aviso_agua_label.text += _t(" Falta la capa '%s' tras la que insertarla.", " The '%s' layer to insert it after is missing.") \
				% ValidadorCapasAgua.NOMBRE_CAPA_AGUA
		_btn_arreglar_agua.text = _t("Insertar CapasAgua", "Insert CapasAgua")
		_btn_arreglar_agua.disabled = not hay_agua
	_aviso_agua.show()


## Avisos del panel y del nodo mapa (tras pintar, deshacer o insertar).
func _refrescar_avisos_agua() -> void:
	var mapa := _mapa_editado()
	if mapa != null:
		mapa.update_configuration_warnings()
	_actualizar_aviso_agua()


## Inserta capas_agua.tscn justo después de la capa `Agua` (o activa sus
## `reflejos` si ya existe) como una acción del historial de deshacer.
func _on_arreglar_agua_pressed() -> void:
	var mapa := _mapa_editado()
	if mapa == null:
		return
	var undo_redo := get_undo_redo()
	var capas := mapa.obtener_capas_agua()
	if capas != null:
		undo_redo.create_action(_t("Activar reflejos de CapasAgua", "Enable CapasAgua reflections"))
		undo_redo.add_do_property(capas, "reflejos", true)
		undo_redo.add_undo_property(capas, "reflejos", capas.reflejos)
	else:
		var agua := ValidadorCapasAgua.capa_agua_de_mapa(mapa)
		if agua == null:
			return
		var escena := load(CAPAS_AGUA_SCENE_PATH) as PackedScene
		var nueva := escena.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as CapasAgua
		nueva.name = "CapasAgua"
		undo_redo.create_action(_t("Insertar CapasAgua", "Insert CapasAgua"))
		undo_redo.add_do_method(mapa, "add_child", nueva, true)
		undo_redo.add_do_method(mapa, "move_child", nueva, agua.get_index() + 1)
		undo_redo.add_do_method(nueva, "set_owner", get_editor_interface().get_edited_scene_root())
		undo_redo.add_do_reference(nueva)
		undo_redo.add_undo_method(mapa, "remove_child", nueva)
	undo_redo.add_do_method(self, "_refrescar_avisos_agua")
	undo_redo.add_undo_method(self, "_refrescar_avisos_agua")
	undo_redo.commit_action()

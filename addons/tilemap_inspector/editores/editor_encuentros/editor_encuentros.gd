@tool
## Editor interactivo de Pokémon de encuentro.
## Edita directamente BaseDatos/config_encuentros.json.
## Punto de entrada: abrir(mapa_id: String = "")
## Señal: encuentros_guardados(data: Dictionary)
extends Window

const RUTA_JSON      := "res://BaseDatos/config_encuentros.json"
const RUTA_BASE_DATOS := "res://BaseDatos/poke.db"

signal encuentros_guardados(data: Dictionary)

# ─── Datos ────────────────────────────────────────────────────────────────────
var _encuentros_data: Dictionary = {}
var _mapa_actual: String = ""

# DB (solo para validar nombre_interno)
var _db = null
var _nombres_validos: Dictionary = {}  # nombre_interno -> true
var _ac_lista_pokemon: Array = []      # [nombre_interno] ordenado para el dropdown

# ─── Tipos de encuentro ───────────────────────────────────────────────────────
const TIPOS: Array        = ["hierba", "agua", "pesca", "roca"]
const TIPO_NOMBRES: Dictionary = {
	"hierba": "🌿 Hierba",
	"agua":   "🌊 Agua",
	"pesca":  "🎣 Pesca",
	"roca":   "🪨 Roca",
}

## Probabilidad de aparición por slot (Pokémon Ruby). Índice = nº de slot (0-based).
const PROBABILIDADES: Dictionary = {
	"hierba": ["20%", "20%", "10%", "10%", "10%", "10%", "5%", "5%", "4%", "4%", "1%", "1%"],
	"agua":   ["60%", "30%", "5%", "4%", "1%"],
	"pesca":  ["70% caña vieja", "30% caña vieja", "60% caña buena", "20% caña buena", "20% caña buena",
			"40% supercaña", "40% supercaña", "15% supercaña", "4% supercaña", "1% supercaña"],
	"roca":   ["60%", "30%", "5%", "4%", "1%"],
}

# ─── Referencias UI ───────────────────────────────────────────────────────────
var _mapa_list: ItemList  = null
var _mapa_titulo: Label   = null
var _tabs: TabContainer   = null
var _status_label: Label  = null

# tipo → { "ratio_spin": SpinBox, "slot_container": VBoxContainer }
var _tipo_ui: Dictionary  = {}
# tipo → Array de { "hbox": HBoxContainer, "edit": LineEdit, "min": SpinBox, "max": SpinBox }
var _slots_ui: Dictionary = {}

# ─── Autocompletado ──────────────────────────────────────────────────────────
var _ac_panel: Panel = null
var _ac_item_list: ItemList = null
var _ac_target: LineEdit = null
var _ac_suppressing: bool = false

# ─── _ready ───────────────────────────────────────────────────────────────────
func _ready() -> void:
	title    = "Editor de Pokémon de Encuentro"
	size     = Vector2i(1280, 720)
	min_size = Vector2i(960, 560)
	close_requested.connect(_cerrar)
	_conectar_db()
	_construir_ui()
	_crear_popup_autocomplete()

func _input(event: InputEvent) -> void:
	if not is_instance_valid(_ac_panel) or not _ac_panel.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_ocultar_autocomplete()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not _ac_panel.get_global_rect().has_point(event.global_position):
			_ocultar_autocomplete()

func _exit_tree() -> void:
	if _db != null:
		_db.close_db()
		_db = null

# ─── Punto de entrada público ─────────────────────────────────────────────────
func abrir(mapa_id: String = "") -> void:
	_cargar_json()
	_refrescar_lista_mapas()
	if mapa_id != "" and _encuentros_data.has(mapa_id):
		_seleccionar_mapa_en_lista(mapa_id)
	elif _mapa_list.item_count > 0:
		_mapa_list.select(0)
		_cargar_mapa(_mapa_list.get_item_metadata(0))
	popup_centered()
	grab_focus()

func _cerrar() -> void:
	hide()

# ─── Base de datos ────────────────────────────────────────────────────────────
func _conectar_db() -> void:
	if not FileAccess.file_exists(RUTA_BASE_DATOS):
		return
	_db = SQLite.new()
	_db.path = RUTA_BASE_DATOS
	if not _db.open_db():
		_db = null
		return
	_db.query("SELECT nombre_interno FROM Pokemon ORDER BY nombre_interno")
	for row in _db.query_result:
		var ni: String = str(row.get("nombre_interno", ""))
		if ni != "":
			_nombres_validos[ni] = true
			_ac_lista_pokemon.append(ni)

func _es_especie_valida(nombre: String) -> bool:
	if _nombres_validos.is_empty():
		return true  # Sin DB no validamos
	return _nombres_validos.has(nombre)

# ─── JSON ─────────────────────────────────────────────────────────────────────
func _cargar_json() -> void:
	var file := FileAccess.open(RUTA_JSON, FileAccess.READ)
	if not file:
		_set_status("⚠️ No se encontró %s" % RUTA_JSON, true)
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) == TYPE_DICTIONARY:
		_encuentros_data = data
	else:
		_set_status("⚠️ Formato inválido en config_encuentros.json", true)

func _guardar_json() -> void:
	if _mapa_actual != "":
		_leer_formulario_a_datos()
	var file := FileAccess.open(RUTA_JSON, FileAccess.WRITE)
	if not file:
		_set_status("❌ No se pudo escribir en %s" % RUTA_JSON, true)
		return
	file.store_string(JSON.stringify(_encuentros_data, "\t"))
	file.close()
	_set_status("✅ Guardado correctamente en config_encuentros.json")
	encuentros_guardados.emit(_encuentros_data)

# ─── Construcción de la UI ────────────────────────────────────────────────────
func _construir_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + lado, 8)
	add_child(margin)

	var vbox_raiz := VBoxContainer.new()
	vbox_raiz.add_theme_constant_override("separation", 6)
	margin.add_child(vbox_raiz)

	# ── Contenido principal ──────────────────────────────────────────────────
	var hbox_main := HBoxContainer.new()
	hbox_main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox_main.add_theme_constant_override("separation", 10)
	vbox_raiz.add_child(hbox_main)

	# Panel izquierdo — lista de mapas
	var panel_izq := VBoxContainer.new()
	panel_izq.custom_minimum_size = Vector2(200, 0)
	panel_izq.add_theme_constant_override("separation", 4)
	hbox_main.add_child(panel_izq)

	var lbl_mapas := Label.new()
	lbl_mapas.text = "MAPAS"
	lbl_mapas.add_theme_font_size_override("font_size", 10)
	lbl_mapas.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	panel_izq.add_child(lbl_mapas)

	_mapa_list = ItemList.new()
	_mapa_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mapa_list.item_selected.connect(_on_mapa_seleccionado)
	panel_izq.add_child(_mapa_list)

	var hbox_btns := HBoxContainer.new()
	panel_izq.add_child(hbox_btns)

	var btn_nuevo := Button.new()
	btn_nuevo.text = "+ Nuevo"
	btn_nuevo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_nuevo.pressed.connect(_on_nuevo_mapa)
	hbox_btns.add_child(btn_nuevo)

	var btn_eliminar := Button.new()
	btn_eliminar.text = "✖ Eliminar"
	btn_eliminar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_eliminar.pressed.connect(_on_eliminar_mapa)
	hbox_btns.add_child(btn_eliminar)

	# Separador vertical
	hbox_main.add_child(VSeparator.new())

	# Panel derecho — editor de encuentros
	var panel_der := VBoxContainer.new()
	panel_der.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_der.add_theme_constant_override("separation", 6)
	hbox_main.add_child(panel_der)

	_mapa_titulo = Label.new()
	_mapa_titulo.text = "(selecciona un mapa)"
	_mapa_titulo.add_theme_font_size_override("font_size", 13)
	panel_der.add_child(_mapa_titulo)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_der.add_child(_tabs)

	for tipo: String in TIPOS:
		_crear_tab_tipo(tipo)

	# ── Barra inferior ────────────────────────────────────────────────────────
	vbox_raiz.add_child(HSeparator.new())
	var hbox_bottom := HBoxContainer.new()
	vbox_raiz.add_child(hbox_bottom)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.text = "Selecciona un mapa para editar sus encuentros."
	hbox_bottom.add_child(_status_label)

	var btn_guardar := Button.new()
	btn_guardar.text = "💾  Guardar JSON"
	btn_guardar.pressed.connect(_guardar_json)
	hbox_bottom.add_child(btn_guardar)

func _crear_tab_tipo(tipo: String) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = tipo
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_child(scroll)
	_tabs.set_tab_title(_tabs.get_tab_count() - 1, TIPO_NOMBRES[tipo])

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(vbox)

	# ── Fila de ratio + botón agregar ────────────────────────────────────────
	var hbox_top := HBoxContainer.new()
	hbox_top.add_theme_constant_override("separation", 8)
	vbox.add_child(hbox_top)

	var lbl_ratio := Label.new()
	lbl_ratio.text = "Ratio de encuentro:"
	hbox_top.add_child(lbl_ratio)

	var spin_ratio := SpinBox.new()
	spin_ratio.min_value = 0
	spin_ratio.max_value = 999
	spin_ratio.value = 0
	spin_ratio.custom_minimum_size = Vector2(80, 0)
	hbox_top.add_child(spin_ratio)

	var lbl_hint := Label.new()
	lbl_hint.text = "(pasos entre encuentros; 0 = sin encuentros)"
	lbl_hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	lbl_hint.add_theme_font_size_override("font_size", 10)
	hbox_top.add_child(lbl_hint)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_top.add_child(spacer)

	var btn_agregar := Button.new()
	btn_agregar.text = "+ Agregar slot"
	btn_agregar.pressed.connect(func(): _agregar_slot_nuevo(tipo))
	hbox_top.add_child(btn_agregar)

	vbox.add_child(HSeparator.new())

	# ── Cabecera de columnas ─────────────────────────────────────────────────
	var hbox_header := HBoxContainer.new()
	hbox_header.add_theme_constant_override("separation", 4)
	vbox.add_child(hbox_header)

	var _h0 := Label.new(); _h0.text = "#"; _h0.custom_minimum_size = Vector2(28, 0)
	hbox_header.add_child(_h0)
	var _hp := Label.new(); _hp.text = "Prob."; _hp.custom_minimum_size = Vector2(120, 0)
	_hp.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	_hp.add_theme_font_size_override("font_size", 10)
	hbox_header.add_child(_hp)
	var _h1 := Label.new(); _h1.text = "Especie  (nombre_interno)"
	_h1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_header.add_child(_h1)
	var _h2 := Label.new(); _h2.text = "Nv. mín"; _h2.custom_minimum_size = Vector2(72, 0)
	hbox_header.add_child(_h2)
	var _h3 := Label.new(); _h3.text = "Nv. máx"; _h3.custom_minimum_size = Vector2(72, 0)
	hbox_header.add_child(_h3)
	var _h4 := Label.new(); _h4.text = ""; _h4.custom_minimum_size = Vector2(32, 0)
	hbox_header.add_child(_h4)

	# ── Contenedor de filas de slots ─────────────────────────────────────────
	var slot_container := VBoxContainer.new()
	slot_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_container.add_theme_constant_override("separation", 2)
	vbox.add_child(slot_container)

	_tipo_ui[tipo] = {
		"ratio_spin":      spin_ratio,
		"slot_container":  slot_container,
	}
	_slots_ui[tipo] = []

# ─── Filas de slot ────────────────────────────────────────────────────────────
func _agregar_fila_slot(tipo: String, nombre_interno: String, nivel_min: int, nivel_max: int) -> void:
	var container: VBoxContainer = _tipo_ui[tipo]["slot_container"]
	var idx: int = _slots_ui[tipo].size()

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	container.add_child(hbox)

	# Número de slot
	var lbl_num := Label.new()
	lbl_num.text = "%02d" % (idx + 1)
	lbl_num.custom_minimum_size = Vector2(28, 0)
	lbl_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(lbl_num)

	# Probabilidad de encuentro
	var probs: Array = PROBABILIDADES.get(tipo, [])
	var lbl_prob := Label.new()
	lbl_prob.text = probs[idx] if idx < probs.size() else ""
	lbl_prob.custom_minimum_size = Vector2(120, 0)
	lbl_prob.add_theme_color_override("font_color", Color(0.45, 0.75, 0.45))
	lbl_prob.add_theme_font_size_override("font_size", 10)
	hbox.add_child(lbl_prob)

	# LineEdit de especie
	var edit := LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text = nombre_interno
	edit.placeholder_text = "NOMBRE_INTERNO"
	edit.text_changed.connect(func(_v: String):
		_aplicar_color_validacion(edit)
		_mostrar_autocomplete(edit)
	)
	edit.focus_exited.connect(_ocultar_autocomplete)
	hbox.add_child(edit)
	_aplicar_color_validacion(edit)

	# Nivel mínimo
	var spin_min := SpinBox.new()
	spin_min.min_value = 1
	spin_min.max_value = 100
	spin_min.value = nivel_min
	spin_min.custom_minimum_size = Vector2(72, 0)
	hbox.add_child(spin_min)

	# Nivel máximo
	var spin_max := SpinBox.new()
	spin_max.min_value = 1
	spin_max.max_value = 100
	spin_max.value = nivel_max
	spin_max.custom_minimum_size = Vector2(72, 0)
	hbox.add_child(spin_max)

	# Botón eliminar
	var btn_del := Button.new()
	btn_del.text = "✖"
	btn_del.custom_minimum_size = Vector2(32, 0)
	btn_del.pressed.connect(func(): _eliminar_slot(tipo, hbox))
	hbox.add_child(btn_del)

	_slots_ui[tipo].append({"hbox": hbox, "edit": edit, "min": spin_min, "max": spin_max, "prob": lbl_prob})

# ─── Autocompletado ──────────────────────────────────────────────────────────
func _crear_popup_autocomplete() -> void:
	_ac_panel = Panel.new()
	_ac_panel.top_level = true
	_ac_panel.hide()
	_ac_panel.z_index = 100
	_ac_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_ac_item_list = ItemList.new()
	_ac_item_list.focus_mode = Control.FOCUS_NONE
	_ac_item_list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ac_item_list.gui_input.connect(_on_ac_list_gui_input)
	_ac_panel.add_child(_ac_item_list)
	add_child(_ac_panel)

func _on_ac_list_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var idx := _ac_item_list.get_item_at_position(event.position, true)
		if idx >= 0:
			_on_ac_item_selected(idx)

func _mostrar_autocomplete(field: LineEdit) -> void:
	if _ac_suppressing or not is_instance_valid(_ac_panel):
		return
	_ac_target = field
	var query_str: String = field.text.strip_edges().to_upper()
	_ac_item_list.clear()
	var count := 0
	for ni: String in _ac_lista_pokemon:
		if query_str == "" or ni.find(query_str) != -1:
			_ac_item_list.add_item(ni)
			count += 1
			if count >= 30:
				break
	if count == 0:
		_ac_panel.hide()
		return
	var field_rect := field.get_global_rect()
	var panel_w := maxf(field_rect.size.x, 200.0)
	const PANEL_H := 160.0
	var pos_x := field_rect.position.x
	var pos_y := field_rect.position.y + field_rect.size.y
	var vp_size: Vector2 = get_visible_rect().size
	if pos_y + PANEL_H > vp_size.y:
		pos_y = field_rect.position.y - PANEL_H
	if pos_x + panel_w > vp_size.x:
		pos_x = vp_size.x - panel_w
	_ac_panel.set_global_position(Vector2(pos_x, pos_y))
	_ac_panel.custom_minimum_size = Vector2(panel_w, PANEL_H)
	_ac_panel.size = Vector2(panel_w, PANEL_H)
	_ac_panel.show()

func _ocultar_autocomplete() -> void:
	if is_instance_valid(_ac_panel):
		_ac_panel.hide()
	_ac_target = null

func _on_ac_item_selected(idx: int) -> void:
	if not is_instance_valid(_ac_target):
		_ocultar_autocomplete()
		return
	var selected_text: String = _ac_item_list.get_item_text(idx)
	var target := _ac_target
	_ocultar_autocomplete()
	_ac_suppressing = true
	target.text = selected_text
	target.caret_column = selected_text.length()
	_ac_suppressing = false
	_aplicar_color_validacion(target)
	target.grab_focus()

func _aplicar_color_validacion(edit: LineEdit) -> void:
	var nombre: String = edit.text.strip_edges().to_upper()
	if nombre == "":
		edit.modulate = Color.WHITE
	elif _es_especie_valida(nombre):
		edit.modulate = Color(0.75, 1.0, 0.75)  # Verde suave = válida
	else:
		edit.modulate = Color(1.0, 0.75, 0.75)  # Rojo suave = no encontrada en BD

func _agregar_slot_nuevo(tipo: String) -> void:
	_agregar_fila_slot(tipo, "", 1, 1)

func _eliminar_slot(tipo: String, hbox: HBoxContainer) -> void:
	var arr: Array = _slots_ui[tipo]
	for i: int in arr.size():
		if arr[i]["hbox"] == hbox:
			arr.remove_at(i)
			break
	hbox.queue_free()
	_renumerar_slots(tipo)

func _renumerar_slots(tipo: String) -> void:
	var arr: Array = _slots_ui[tipo]
	var probs: Array = PROBABILIDADES.get(tipo, [])
	for i: int in arr.size():
		var lbl: Label = arr[i]["hbox"].get_child(0) as Label
		if lbl:
			lbl.text = "%02d" % (i + 1)
		var lbl_p: Label = arr[i].get("prob") as Label
		if lbl_p:
			lbl_p.text = probs[i] if i < probs.size() else ""

# ─── Carga / lectura de datos ─────────────────────────────────────────────────
func _refrescar_lista_mapas() -> void:
	_mapa_list.clear()
	var claves: Array = _encuentros_data.keys()
	claves.sort()
	for clave: String in claves:
		_mapa_list.add_item(clave)
		_mapa_list.set_item_metadata(_mapa_list.item_count - 1, clave)

func _seleccionar_mapa_en_lista(mapa_id: String) -> void:
	for i: int in _mapa_list.item_count:
		if _mapa_list.get_item_metadata(i) == mapa_id:
			_mapa_list.select(i)
			_cargar_mapa(mapa_id)
			return

func _on_mapa_seleccionado(idx: int) -> void:
	if _mapa_actual != "":
		_leer_formulario_a_datos()
	_cargar_mapa(_mapa_list.get_item_metadata(idx))

func _cargar_mapa(mapa_id: String) -> void:
	_mapa_actual = mapa_id
	_mapa_titulo.text = mapa_id
	var config: Dictionary = _encuentros_data.get(mapa_id, {})

	for tipo: String in TIPOS:
		var tipo_data: Dictionary = config.get(tipo, {})
		var ratio: int  = int(tipo_data.get("ratio", 0))
		var slots: Array = tipo_data.get("encuentros", [])

		# Limpiar filas anteriores
		var container: VBoxContainer = _tipo_ui[tipo]["slot_container"]
		for child: Node in container.get_children():
			child.queue_free()
		_slots_ui[tipo].clear()

		_tipo_ui[tipo]["ratio_spin"].value = ratio

		for slot in slots:
			_agregar_fila_slot(
				tipo,
				str(slot.get("nombre_interno", "")),
				int(slot.get("nivel_min", 1)),
				int(slot.get("nivel_max", 1))
			)

	_set_status("Editando: %s  (%d tipos configurados)" % [mapa_id, config.size()])

func _leer_formulario_a_datos() -> void:
	if _mapa_actual == "":
		return
	var config: Dictionary = {}
	for tipo: String in TIPOS:
		var arr: Array = _slots_ui[tipo]
		var ratio: int = int(_tipo_ui[tipo]["ratio_spin"].value)
		var encuentros: Array = []
		for slot_data in arr:
			var nombre: String = (slot_data["edit"] as LineEdit).text.strip_edges().to_upper()
			if nombre == "":
				continue
			encuentros.append({
				"nombre_interno": nombre,
				"nivel_min":      int((slot_data["min"] as SpinBox).value),
				"nivel_max":      int((slot_data["max"] as SpinBox).value),
			})
		if not encuentros.is_empty():
			config[tipo] = {"ratio": ratio, "encuentros": encuentros}
	_encuentros_data[_mapa_actual] = config

# ─── Gestión de mapas ─────────────────────────────────────────────────────────
func _on_nuevo_mapa() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Nuevo mapa de encuentros"
	dialog.min_size = Vector2i(360, 130)

	var vbox := VBoxContainer.new()
	dialog.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "ID del mapa (ej: ruta_104):"
	vbox.add_child(lbl)

	var edit := LineEdit.new()
	edit.placeholder_text = "ruta_104"
	vbox.add_child(edit)

	dialog.confirmed.connect(func():
		var id: String = edit.text.strip_edges().to_lower()
		if id == "":
			_set_status("⚠️ El ID no puede estar vacío.", true)
			dialog.queue_free()
			return
		if _encuentros_data.has(id):
			_set_status("⚠️ Ya existe un mapa con ID '%s'." % id, true)
			dialog.queue_free()
			return
		_encuentros_data[id] = {}
		_refrescar_lista_mapas()
		_seleccionar_mapa_en_lista(id)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()
	edit.grab_focus()

func _on_eliminar_mapa() -> void:
	if _mapa_actual == "":
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Confirmar eliminación"
	dialog.dialog_text = "¿Eliminar todos los encuentros de '%s'?\nEsta acción no se guarda hasta que pulses 'Guardar JSON'." % _mapa_actual
	dialog.confirmed.connect(func():
		_encuentros_data.erase(_mapa_actual)
		_mapa_actual = ""
		_refrescar_lista_mapas()
		_mapa_titulo.text = "(selecciona un mapa)"
		for tipo: String in TIPOS:
			for child: Node in _tipo_ui[tipo]["slot_container"].get_children():
				child.queue_free()
			_slots_ui[tipo].clear()
			_tipo_ui[tipo]["ratio_spin"].value = 0
		_set_status("Mapa eliminado de la sesión. Guarda el JSON para hacerlo permanente.")
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()

# ─── Status bar ───────────────────────────────────────────────────────────────
func _set_status(msg: String, error: bool = false) -> void:
	if not is_instance_valid(_status_label):
		return
	_status_label.text = msg
	if error:
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	else:
		_status_label.remove_theme_color_override("font_color")

@tool
## Editor completo de dialogos.csv: buscar, editar y crear claves de texto.
## Los cuadros de la clave seleccionada se editan en el lugar: se guarda con el
## botón Guardar / Ctrl+S, y automáticamente al cambiar de clave, al elegirla o
## al cerrar la ventana.
## Es un Control (no una Window) para poder embeberse o vivir dentro de una
## Window transitoria armada por quien lo abre (ver plugin.gd e
## inspector_pkrpg.gd), igual que editor_instancia_pokemon.
## Punto de entrada: abrir(clave_inicial: String = "")
## Modo selector (para el botón "Editar…" del inspector cuando la clave no
## existe): activar_modo_selector() + señal clave_elegida(id: String).
extends Control

signal clave_elegida(id: String)

const DialogosCSV = preload("res://addons/tilemap_inspector/editores/editor_dialogos/dialogos_csv.gd")

const LARGO_PREVIEW := 42

var _modo_selector: bool = false
var _clave_seleccionada: String = ""
var _tabla_cache: Dictionary = {}

var _busqueda_edit: LineEdit = null
var _lista: ItemList = null
var _titulo_clave: Label = null
var _edit_es: TextEdit = null
var _edit_en: TextEdit = null
var _btn_guardar: Button = null
var _btn_usar_clave: Button = null
var _nueva_id_edit: LineEdit = null
var _nueva_es_edit: TextEdit = null
var _nueva_en_edit: TextEdit = null
var _estado_label: Label = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(900, 560)
	_construir_ui()
	_actualizar_modo_selector()
	_refrescar_lista("")
	# Cerrar la ventana contenedora no debe perder lo escrito. El host conecta su
	# propio close_requested antes que este (y libera la ventana con queue_free,
	# diferido), así que el guardado alcanza a correr.
	var ventana := get_window()
	if ventana != null and not ventana.close_requested.is_connected(_guardar_pendiente):
		ventana.close_requested.connect(_guardar_pendiente)

## Habilita el botón "Usar esta clave" (invisible por defecto, uso normal es solo buscar/editar/crear).
func activar_modo_selector() -> void:
	_modo_selector = true
	# El inspector puede configurar el selector antes de que su Window sea
	# agregada al árbol y, por lo tanto, antes de _ready(). En ese caso el botón
	# todavía no existe; _ready() aplicará el modo después de construir la UI.
	_actualizar_modo_selector()

func _actualizar_modo_selector() -> void:
	if is_instance_valid(_btn_usar_clave):
		_btn_usar_clave.visible = _modo_selector

## Punto de entrada público, imita el patrón `.call("abrir", ...)` de plugin.gd.
func abrir(clave_inicial: String = "") -> void:
	_busqueda_edit.text = clave_inicial
	_refrescar_lista(clave_inicial)
	if not clave_inicial.is_empty():
		_seleccionar_en_lista(clave_inicial)

## Deja el texto directo escrito en un nodo como texto español de una clave nueva por crear.
func precargar_texto_nuevo(texto: String) -> void:
	_nueva_es_edit.text = texto
	_set_estado("El nodo usa texto directo. Escribí un ID nuevo y presioná Crear para convertirlo en clave.")

# ─── Construcción de la UI ────────────────────────────────────────────────────

func _construir_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + lado, 8)
	add_child(margin)

	var vbox_raiz := VBoxContainer.new()
	vbox_raiz.add_theme_constant_override("separation", 6)
	margin.add_child(vbox_raiz)

	_busqueda_edit = LineEdit.new()
	_busqueda_edit.placeholder_text = "Buscar por id, texto en español o inglés..."
	_busqueda_edit.text_changed.connect(_on_busqueda_text_changed)
	vbox_raiz.add_child(_busqueda_edit)

	var hbox_main := HBoxContainer.new()
	hbox_main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox_main.add_theme_constant_override("separation", 10)
	vbox_raiz.add_child(hbox_main)

	_lista = ItemList.new()
	_lista.custom_minimum_size = Vector2(360, 0)
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista.item_selected.connect(_on_lista_item_selected)
	_lista.item_activated.connect(_on_lista_item_activated)
	hbox_main.add_child(_lista)

	hbox_main.add_child(VSeparator.new())

	var panel_der := VBoxContainer.new()
	panel_der.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_der.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_der.add_theme_constant_override("separation", 4)
	hbox_main.add_child(panel_der)

	_titulo_clave = Label.new()
	_titulo_clave.text = "(selecciona una clave de la lista)"
	_titulo_clave.add_theme_font_size_override("font_size", 13)
	panel_der.add_child(_titulo_clave)

	panel_der.add_child(_crear_label_seccion("Español"))
	_edit_es = _crear_edit_clave()
	panel_der.add_child(_edit_es)

	panel_der.add_child(_crear_label_seccion("Inglés"))
	_edit_en = _crear_edit_clave()
	panel_der.add_child(_edit_en)

	var hbox_acciones := HBoxContainer.new()
	hbox_acciones.add_theme_constant_override("separation", 8)
	panel_der.add_child(hbox_acciones)

	_btn_guardar = Button.new()
	_btn_guardar.text = "Guardar"
	_btn_guardar.disabled = true
	_btn_guardar.shortcut = _crear_atajo_guardar()
	_btn_guardar.shortcut_in_tooltip = true
	_btn_guardar.pressed.connect(_guardar_pendiente)
	hbox_acciones.add_child(_btn_guardar)

	_btn_usar_clave = Button.new()
	_btn_usar_clave.text = "Usar esta clave"
	_btn_usar_clave.disabled = true
	_btn_usar_clave.visible = false  # solo se muestra en modo selector
	_btn_usar_clave.pressed.connect(_on_btn_usar_clave_pressed)
	hbox_acciones.add_child(_btn_usar_clave)

	vbox_raiz.add_child(HSeparator.new())
	vbox_raiz.add_child(_construir_seccion_crear())

	_estado_label = Label.new()
	_estado_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox_raiz.add_child(_estado_label)

func _crear_label_seccion(texto: String) -> Label:
	var lbl := Label.new()
	lbl.text = texto
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	return lbl

## Solo editable cuando hay una clave seleccionada (ver _mostrar_clave).
func _crear_edit_clave() -> TextEdit:
	var edit := TextEdit.new()
	edit.editable = false
	edit.custom_minimum_size = Vector2(0, 90)
	edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.text_changed.connect(_actualizar_estado_cambios)
	return edit

func _crear_atajo_guardar() -> Shortcut:
	var tecla := InputEventKey.new()
	tecla.keycode = KEY_S
	tecla.ctrl_pressed = true
	var atajo := Shortcut.new()
	atajo.events = [tecla]
	return atajo

func _construir_seccion_crear() -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	vbox.add_child(_crear_label_seccion("CREAR NUEVA CLAVE"))

	_nueva_id_edit = LineEdit.new()
	_nueva_id_edit.placeholder_text = "ID (ej: CARTEL_NUEVO)"
	vbox.add_child(_nueva_id_edit)

	var hbox_textos := HBoxContainer.new()
	hbox_textos.add_theme_constant_override("separation", 8)
	vbox.add_child(hbox_textos)

	var col_es := VBoxContainer.new()
	col_es.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_es.add_child(_crear_label_seccion("Español"))
	_nueva_es_edit = TextEdit.new()
	_nueva_es_edit.custom_minimum_size = Vector2(0, 70)
	_nueva_es_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	col_es.add_child(_nueva_es_edit)
	hbox_textos.add_child(col_es)

	var col_en := VBoxContainer.new()
	col_en.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_en.add_child(_crear_label_seccion("Inglés"))
	_nueva_en_edit = TextEdit.new()
	_nueva_en_edit.custom_minimum_size = Vector2(0, 70)
	_nueva_en_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	col_en.add_child(_nueva_en_edit)
	hbox_textos.add_child(col_en)

	var btn_crear := Button.new()
	btn_crear.text = "+ Crear"
	btn_crear.pressed.connect(_on_btn_crear_pressed)
	vbox.add_child(btn_crear)

	return vbox

# ─── Búsqueda / lista ──────────────────────────────────────────────────────────

func _on_busqueda_text_changed(texto: String) -> void:
	_refrescar_lista(texto)

func _refrescar_lista(filtro: String) -> void:
	_tabla_cache = DialogosCSV.cargar()
	_lista.clear()
	var filas: Dictionary = _tabla_cache["filas"]
	for id in DialogosCSV.buscar(filtro):
		_lista.add_item(_texto_item(id, filas.get(id, {})))
		_lista.set_item_metadata(_lista.item_count - 1, id)

func _texto_item(id: String, fila: Dictionary) -> String:
	var texto_item := "%s  —  ES: %s" % [id, _acortar(String(fila.get("es", "")))]
	var en_valor := String(fila.get("en", ""))
	if not en_valor.is_empty():
		texto_item += "  |  EN: %s" % _acortar(en_valor)
	return texto_item

func _acortar(texto: String) -> String:
	var plano := texto.replace("\n", " ").replace("\r", " ")
	if plano.length() > LARGO_PREVIEW:
		plano = plano.substr(0, LARGO_PREVIEW) + "…"
	return plano

func _seleccionar_en_lista(id: String) -> void:
	for i in _lista.item_count:
		if _lista.get_item_metadata(i) == id:
			_lista.select(i)
			_mostrar_clave(id)
			return

func _on_lista_item_selected(idx: int) -> void:
	_mostrar_clave(_lista.get_item_metadata(idx))

## Doble clic / Enter sobre la lista: lleva el foco al texto en español para escribir ya.
func _on_lista_item_activated(idx: int) -> void:
	_mostrar_clave(_lista.get_item_metadata(idx))
	_edit_es.grab_focus()

func _mostrar_clave(id: String) -> void:
	# Lo escrito en la clave anterior se guarda antes de reemplazar los cuadros.
	_guardar_pendiente()
	_clave_seleccionada = id
	var fila: Dictionary = _tabla_cache["filas"].get(id, {})
	_edit_es.text = String(fila.get("es", ""))
	_edit_en.text = String(fila.get("en", ""))
	_edit_es.editable = true
	_edit_en.editable = true
	_btn_usar_clave.disabled = false
	_actualizar_estado_cambios()

# ─── Edición en el lugar ──────────────────────────────────────────────────────

func _hay_cambios() -> bool:
	if _clave_seleccionada.is_empty():
		return false
	var fila: Dictionary = _tabla_cache["filas"].get(_clave_seleccionada, {})
	return _edit_es.text != String(fila.get("es", "")) \
			or _edit_en.text != String(fila.get("en", ""))

func _actualizar_estado_cambios() -> void:
	var sucio := _hay_cambios()
	_btn_guardar.disabled = not sucio
	if not _clave_seleccionada.is_empty():
		_titulo_clave.text = "Clave: %s%s" % [_clave_seleccionada, "  ● sin guardar" if sucio else ""]

## Escribe en el CSV los cambios de la clave seleccionada (no hace nada si no hay).
func _guardar_pendiente() -> void:
	if not _hay_cambios():
		return
	var id := _clave_seleccionada
	var fila := {"es": _edit_es.text, "en": _edit_en.text}
	DialogosCSV.guardar_fila(id, fila["es"], fila["en"])
	_tabla_cache["filas"][id] = fila
	# Solo se actualiza el renglón: refrescar toda la lista perdería el scroll.
	for i in _lista.item_count:
		if _lista.get_item_metadata(i) == id:
			_lista.set_item_text(i, _texto_item(id, fila))
			break
	_actualizar_estado_cambios()
	_set_estado("Clave '%s' guardada." % id)

# ─── Crear clave nueva ────────────────────────────────────────────────────────

func _on_btn_crear_pressed() -> void:
	var id := _nueva_id_edit.text.strip_edges()
	if id.is_empty():
		_set_estado("El ID no puede estar vacío.", true)
		return
	if DialogosCSV.existe_clave(id):
		_set_estado("Ya existe una clave con el ID '%s'." % id, true)
		return

	DialogosCSV.guardar_fila(id, _nueva_es_edit.text, _nueva_en_edit.text)
	_nueva_id_edit.text = ""
	_nueva_es_edit.text = ""
	_nueva_en_edit.text = ""
	_set_estado("Clave '%s' creada." % id)

	_refrescar_lista(_busqueda_edit.text)
	_seleccionar_en_lista(id)

	if _modo_selector:
		clave_elegida.emit(id)

func _on_btn_usar_clave_pressed() -> void:
	if _clave_seleccionada.is_empty():
		return
	_guardar_pendiente()
	clave_elegida.emit(_clave_seleccionada)

func _set_estado(texto: String, error: bool = false) -> void:
	_estado_label.text = texto
	if error:
		_estado_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	else:
		_estado_label.remove_theme_color_override("font_color")

@tool
extends ConfirmationDialog

## Galería de avatares de NPC (SpriteFrames registrados en registro_avatares.json).
## Se abre desde el inspector de `selec_frames` (editor_property_avatar.gd) con
## abrir(valor_actual, al_elegir). Es una instancia única, hija del base control
## del editor, que se oculta al cerrar y se reutiliza: conserva tamaño, posición,
## filtro y scroll entre aperturas (además se guardan en variables estáticas para
## sobrevivir a una recarga del plugin). plugin.gd llama a liberar() en _exit_tree.
##
## Flujo rápido: al abrir, el foco está en la búsqueda; escribir filtra, Enter
## asigna el seleccionado (o el primero visible), ↓ pasa a la grilla, doble clic o
## Enter en la grilla asigna y cierra, Esc cierra sin cambios.

const RegistroAvatares = preload("res://addons/tilemap_inspector/registro_avatares.gd")
const RUTA_ESTE_SCRIPT := "res://addons/tilemap_inspector/ventana_galeria_avatares.gd"
## Nombre del nodo bajo el base control: permite encontrar (y liberar) la instancia
## aunque las variables estáticas se hayan reiniciado al recargar este script.
const NOMBRE_NODO := "GaleriaAvataresNPC"

const TAMANO_BASE := Vector2i(760, 520)
const TAMANO_MINIMO := Vector2i(560, 380)
const ICONO_GRILLA := 64
const ANCHO_COLUMNA_GRILLA := 96
const ICONO_RECIENTES := 40
const ANCHO_COLUMNA_RECIENTES := 76
const ALTO_FILA_RECIENTES := 78
## Margen respecto al área útil de la pantalla al abrir.
const MARGEN_PANTALLA := 32
const TAMANO_VISTA_PREVIA := 128
const ANCHO_PANEL_LATERAL := 210
## Miniaturas cargadas por frame (la galería se muestra al instante y los íconos
## aparecen enseguida, sin congelar el editor con muchos avatares).
const MINIATURAS_POR_FRAME := 8

enum AccionMenu { SELECCIONAR, RENOMBRAR, EDITAR_TAGS, MOSTRAR_EN_FS, QUITAR }

static var _instancia: ConfirmationDialog = null
## Estado de la sesión del editor.
static var _rect_guardado: Rect2i = Rect2i()
static var _filtro_guardado: String = ""
static var _scroll_guardado: float = 0.0
static var _textura_vacia: Texture2D = null

var _al_elegir: Callable = Callable()
var _valor_actual: SpriteFrames = null
## Clave en el registro del valor actual ("" si no está registrado o está vacío).
var _clave_actual: String = ""
var _clave_seleccionada: String = ""
var _escala: float = 1.0

var _filtro: LineEdit
var _boton_agregar: Button
var _boton_importar: Button
var _fila_aviso: HBoxContainer
var _etiqueta_aviso: Label
var _boton_registrar_actual: Button
var _caja_recientes: VBoxContainer
var _lista_recientes: ItemList
var _grilla: ItemList
var _vista_previa: TextureRect
var _etiqueta_nombre: Label
var _etiqueta_ruta: Label
var _etiqueta_tags: Label
var _boton_renombrar: Button
var _boton_tags: Button
var _boton_quitar: Button
var _etiqueta_estado: Label
var _menu_contextual: PopupMenu
var _dialogo_texto: ConfirmationDialog
var _dialogo_texto_etiqueta: Label
var _dialogo_texto_edit: LineEdit
var _dialogo_confirmar: ConfirmationDialog
var _dialogo_archivos: EditorFileDialog
var _accion_texto: Callable = Callable()
var _accion_confirmar: Callable = Callable()

## clave -> índice del ítem en cada lista (se rehacen en cada _poblar()).
var _items_grilla: Dictionary = {}
var _items_recientes: Dictionary = {}
## Claves cuya miniatura falta cargar (se procesan de a MINIATURAS_POR_FRAME).
var _cola_miniaturas: Array[String] = []

var _vista_texturas: Array[Texture2D] = []
var _vista_fps: float = 0.0
var _vista_tiempo: float = 0.0
var _vista_indice: int = 0


# ─── API estática ────────────────────────────────────────────────────────────────

## Abre la galería. `al_elegir` recibe el SpriteFrames elegido (no se llama si se cancela).
static func abrir(valor_actual: SpriteFrames, al_elegir: Callable) -> void:
	var script_galeria := load(RUTA_ESTE_SCRIPT) as GDScript
	var existente := _buscar_existente()
	# Una instancia de una versión anterior del script (recargado) se descarta.
	if existente != null and existente.get_script() != script_galeria:
		_liberar_nodo(existente)
		existente = null
	if existente == null:
		existente = script_galeria.new() as ConfirmationDialog
		existente.name = NOMBRE_NODO
		EditorInterface.get_base_control().add_child(existente)
	_instancia = existente
	_instancia.call(&"_mostrar", valor_actual, al_elegir)

## Libera la instancia única (al descargar el plugin).
static func liberar() -> void:
	_liberar_nodo(_buscar_existente())
	_instancia = null

static func _buscar_existente() -> ConfirmationDialog:
	if is_instance_valid(_instancia) and not _instancia.is_queued_for_deletion():
		return _instancia
	var base := EditorInterface.get_base_control()
	if base == null:
		return null
	var nodo := base.get_node_or_null(NodePath(NOMBRE_NODO)) as ConfirmationDialog
	if nodo != null and nodo.is_queued_for_deletion():
		return null
	return nodo

static func _liberar_nodo(nodo: ConfirmationDialog) -> void:
	if nodo == null:
		return
	if nodo.visible:
		nodo.hide()
	nodo.queue_free()


# ─── Construcción ────────────────────────────────────────────────────────────────

func _init() -> void:
	title = "Galería de avatares de NPC"
	ok_button_text = "Seleccionar"
	cancel_button_text = "Cancelar"
	dialog_hide_on_ok = false
	_escala = EditorInterface.get_editor_scale()
	min_size = Vector2i(Vector2(TAMANO_MINIMO) * _escala)

	var raiz := VBoxContainer.new()
	raiz.add_theme_constant_override(&"separation", int(6 * _escala))
	add_child(raiz)

	# Barra superior: búsqueda + agregar + importar
	var barra := HBoxContainer.new()
	raiz.add_child(barra)
	_filtro = LineEdit.new()
	_filtro.placeholder_text = "Buscar por nombre, tag o archivo…  (Enter: asignar, ↓: grilla)"
	_filtro.clear_button_enabled = true
	_filtro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.add_child(_filtro)
	_boton_agregar = Button.new()
	_boton_agregar.text = "+ Agregar"
	_boton_agregar.tooltip_text = "Registrar uno o varios SpriteFrames (.tres)."
	barra.add_child(_boton_agregar)
	_boton_importar = Button.new()
	_boton_importar.text = "Importar no registrados"
	_boton_importar.tooltip_text = "Registra todos los SpriteFrames de %s que no estén en el registro, con el nombre de archivo." % RegistroAvatares.CARPETA_AVATARES
	barra.add_child(_boton_importar)

	# Aviso: valor actual sin registrar
	_fila_aviso = HBoxContainer.new()
	_fila_aviso.visible = false
	raiz.add_child(_fila_aviso)
	_etiqueta_aviso = Label.new()
	_etiqueta_aviso.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_etiqueta_aviso.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_etiqueta_aviso.modulate = Color(1.0, 0.9, 0.6)
	_etiqueta_aviso.mouse_filter = Control.MOUSE_FILTER_PASS
	_fila_aviso.add_child(_etiqueta_aviso)
	_boton_registrar_actual = Button.new()
	_boton_registrar_actual.text = "Registrar"
	_boton_registrar_actual.tooltip_text = "Agrega el avatar actual al registro con un nombre."
	_fila_aviso.add_child(_boton_registrar_actual)

	# Recientes
	_caja_recientes = VBoxContainer.new()
	_caja_recientes.visible = false
	raiz.add_child(_caja_recientes)
	var etiqueta_recientes := Label.new()
	etiqueta_recientes.text = "Recientes"
	etiqueta_recientes.modulate = Color(1, 1, 1, 0.7)
	_caja_recientes.add_child(etiqueta_recientes)
	_lista_recientes = _crear_lista(ICONO_RECIENTES, ANCHO_COLUMNA_RECIENTES, 1)
	# Alto fijo de una fila (con scroll si no entra): auto_height mide con el ancho
	# actual, que en la primera apertura es 0 y apila los recientes en una columna,
	# agrandando el diálogo (wrap_controls) muy por encima de TAMANO_BASE.
	_lista_recientes.custom_minimum_size = Vector2(0, ALTO_FILA_RECIENTES * _escala)
	_caja_recientes.add_child(_lista_recientes)

	# Grilla + panel lateral
	var division := HSplitContainer.new()
	division.size_flags_vertical = Control.SIZE_EXPAND_FILL
	raiz.add_child(division)
	_grilla = _crear_lista(ICONO_GRILLA, ANCHO_COLUMNA_GRILLA, 2)
	_grilla.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grilla.size_flags_vertical = Control.SIZE_EXPAND_FILL
	division.add_child(_grilla)

	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(ANCHO_PANEL_LATERAL * _escala, 0)
	division.add_child(panel)
	_vista_previa = TextureRect.new()
	_vista_previa.custom_minimum_size = Vector2.ONE * TAMANO_VISTA_PREVIA * _escala
	_vista_previa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vista_previa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_vista_previa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.add_child(_vista_previa)
	_etiqueta_nombre = Label.new()
	_etiqueta_nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etiqueta_nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_etiqueta_nombre)
	_etiqueta_ruta = Label.new()
	_etiqueta_ruta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Sin autowrap: con ancho 0 (antes del primer layout) AUTOWRAP_ARBITRARY parte
	# la ruta en un carácter por línea y dispara el alto mínimo del diálogo.
	_etiqueta_ruta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_etiqueta_ruta.mouse_filter = Control.MOUSE_FILTER_PASS
	_etiqueta_ruta.modulate = Color(1, 1, 1, 0.6)
	panel.add_child(_etiqueta_ruta)
	_etiqueta_tags = Label.new()
	_etiqueta_tags.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etiqueta_tags.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_etiqueta_tags.modulate = Color(0.75, 0.85, 1.0)
	panel.add_child(_etiqueta_tags)
	var espaciador := Control.new()
	espaciador.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(espaciador)
	_boton_renombrar = Button.new()
	_boton_renombrar.text = "Renombrar…"
	panel.add_child(_boton_renombrar)
	_boton_tags = Button.new()
	_boton_tags.text = "Tags…"
	_boton_tags.tooltip_text = "Etiquetas separadas por coma (se usan en la búsqueda)."
	panel.add_child(_boton_tags)
	_boton_quitar = Button.new()
	_boton_quitar.text = "Quitar del registro…"
	_boton_quitar.tooltip_text = "Quita la entrada del registro. El archivo .tres no se borra."
	panel.add_child(_boton_quitar)

	_etiqueta_estado = Label.new()
	_etiqueta_estado.modulate = Color(1, 1, 1, 0.6)
	_etiqueta_estado.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	raiz.add_child(_etiqueta_estado)

	_crear_dialogos_auxiliares()

	# Señales
	_filtro.text_changed.connect(_on_filtro_cambiado)
	_filtro.text_submitted.connect(_on_filtro_enviado)
	_filtro.gui_input.connect(_on_filtro_gui_input)
	_boton_agregar.pressed.connect(_on_agregar_pressed)
	_boton_importar.pressed.connect(_on_importar_pressed)
	_boton_registrar_actual.pressed.connect(_on_registrar_actual_pressed)
	_grilla.item_selected.connect(_on_grilla_item_selected)
	_grilla.item_activated.connect(_on_grilla_item_activated)
	_grilla.item_clicked.connect(_on_lista_item_clicked.bind(_grilla))
	_lista_recientes.item_selected.connect(_on_recientes_item_selected)
	_lista_recientes.item_activated.connect(_on_recientes_item_activated)
	_lista_recientes.item_clicked.connect(_on_lista_item_clicked.bind(_lista_recientes))
	_boton_renombrar.pressed.connect(_renombrar_seleccionado)
	_boton_tags.pressed.connect(_editar_tags_seleccionado)
	_boton_quitar.pressed.connect(_quitar_seleccionado)
	confirmed.connect(_on_confirmado)
	visibility_changed.connect(_on_visibilidad_cambiada)

	set_process(false)
	_mostrar_detalle("")

func _crear_lista(icono: int, ancho_columna: int, lineas_texto: int) -> ItemList:
	var lista := ItemList.new()
	lista.icon_mode = ItemList.ICON_MODE_TOP
	lista.fixed_icon_size = Vector2i(Vector2.ONE * icono * _escala)
	lista.fixed_column_width = int(ancho_columna * _escala)
	lista.max_columns = 0
	lista.same_column_width = true
	lista.max_text_lines = lineas_texto
	lista.select_mode = ItemList.SELECT_SINGLE
	lista.allow_rmb_select = true
	lista.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return lista

func _crear_dialogos_auxiliares() -> void:
	_menu_contextual = PopupMenu.new()
	_menu_contextual.add_item("Seleccionar", AccionMenu.SELECCIONAR)
	_menu_contextual.add_separator()
	_menu_contextual.add_item("Renombrar…", AccionMenu.RENOMBRAR)
	_menu_contextual.add_item("Editar tags…", AccionMenu.EDITAR_TAGS)
	_menu_contextual.add_item("Mostrar en FileSystem", AccionMenu.MOSTRAR_EN_FS)
	_menu_contextual.add_separator()
	_menu_contextual.add_item("Quitar del registro…", AccionMenu.QUITAR)
	_menu_contextual.id_pressed.connect(_on_menu_contextual_id_pressed)
	add_child(_menu_contextual)

	_dialogo_texto = ConfirmationDialog.new()
	_dialogo_texto.ok_button_text = "Aceptar"
	_dialogo_texto.cancel_button_text = "Cancelar"
	var caja := VBoxContainer.new()
	_dialogo_texto.add_child(caja)
	_dialogo_texto_etiqueta = Label.new()
	caja.add_child(_dialogo_texto_etiqueta)
	_dialogo_texto_edit = LineEdit.new()
	_dialogo_texto_edit.custom_minimum_size = Vector2(340 * _escala, 0)
	caja.add_child(_dialogo_texto_edit)
	_dialogo_texto.register_text_enter(_dialogo_texto_edit)
	_dialogo_texto.confirmed.connect(func() -> void:
		var accion := _accion_texto
		_accion_texto = Callable()
		if accion.is_valid():
			accion.call(_dialogo_texto_edit.text)
	)
	add_child(_dialogo_texto)

	_dialogo_confirmar = ConfirmationDialog.new()
	_dialogo_confirmar.ok_button_text = "Aceptar"
	_dialogo_confirmar.cancel_button_text = "Cancelar"
	_dialogo_confirmar.confirmed.connect(func() -> void:
		var accion := _accion_confirmar
		_accion_confirmar = Callable()
		if accion.is_valid():
			accion.call()
	)
	add_child(_dialogo_confirmar)


# ─── Apertura / cierre ───────────────────────────────────────────────────────────

func _mostrar(valor_actual: SpriteFrames, al_elegir: Callable) -> void:
	_al_elegir = al_elegir
	_valor_actual = valor_actual
	RegistroAvatares.asegurar_cargado(true)
	RegistroAvatares.sincronizar_rutas()

	var entrada_actual := RegistroAvatares.buscar_por_recurso(valor_actual)
	_clave_actual = RegistroAvatares.clave_de(entrada_actual) if not entrada_actual.is_empty() else ""
	_filtro.set_block_signals(true)
	_filtro.text = _filtro_guardado
	_filtro.set_block_signals(false)
	# Si el filtro recordado oculta al valor actual, gana ver el actual.
	if not _clave_actual.is_empty() and not _pasa_filtro(entrada_actual, _filtro.text):
		_filtro.text = ""
	_actualizar_aviso_actual()
	_poblar(_clave_actual)

	var rect := _rect_inicial()
	popup(rect)
	# El primer layout puede pedir más alto del real (wrap_controls solo agranda):
	# una vez acomodado el contenido, se vuelve al tamaño pedido.
	_restaurar_tamano.call_deferred(rect.size)
	if _clave_seleccionada.is_empty():
		_restaurar_scroll(_scroll_guardado)
	_filtro.grab_focus.call_deferred()
	_filtro.select_all()

## Rect de apertura: el recordado (o TAMANO_BASE centrado), siempre dentro del área
## útil de la pantalla del editor para que la barra de título quede accesible.
func _rect_inicial() -> Rect2i:
	var ventana_editor := EditorInterface.get_base_control().get_window()
	# Con subventanas embebidas (modo ventana única) las coordenadas son de la ventana
	# del editor; si no, de la pantalla donde está.
	var area := Rect2i(Vector2i.ZERO, ventana_editor.size) if ventana_editor.gui_embed_subwindows \
		else DisplayServer.screen_get_usable_rect(ventana_editor.current_screen)
	var margen := int(MARGEN_PANTALLA * _escala)
	var maximo := (area.size - Vector2i.ONE * margen * 2).max(min_size)
	var rect := _rect_guardado
	if not rect.has_area():
		var tam := Vector2i(Vector2(TAMANO_BASE) * _escala)
		rect = Rect2i(area.position + (area.size - tam) / 2, tam)
	rect.size = rect.size.clamp(min_size, maximo)
	var pos_min := area.position + Vector2i.ONE * margen
	var pos_max := (area.end - rect.size - Vector2i.ONE * margen).max(pos_min)
	rect.position = rect.position.clamp(pos_min, pos_max)
	return rect

func _restaurar_tamano(objetivo: Vector2i) -> void:
	if not visible:
		return
	var tam := objetivo.max(Vector2i(get_contents_minimum_size()))
	if size != tam:
		size = tam

func _on_visibilidad_cambiada() -> void:
	if visible:
		return
	_rect_guardado = Rect2i(position, size)
	_filtro_guardado = _filtro.text
	_scroll_guardado = _grilla.get_v_scroll_bar().value
	_al_elegir = Callable()
	_valor_actual = null
	_cola_miniaturas.clear()
	_vista_texturas.clear()
	set_process(false)

## El scroll de ItemList se recalcula al dibujar: se aplica después del primer draw.
func _restaurar_scroll(valor: float) -> void:
	if valor <= 0.0:
		return
	_grilla.draw.connect(func() -> void:
		_grilla.get_v_scroll_bar().set_deferred(&"value", valor)
	, CONNECT_ONE_SHOT)
	_grilla.queue_redraw()


# ─── Poblado de listas ───────────────────────────────────────────────────────────

func _pasa_filtro(entrada: Dictionary, texto: String) -> bool:
	var f := texto.strip_edges().to_lower()
	if f.is_empty():
		return true
	if str(entrada.get("nombre", "")).to_lower().contains(f):
		return true
	if str(entrada.get("ruta", "")).get_file().to_lower().contains(f):
		return true
	var tags: Variant = entrada.get("tags", [])
	if tags is Array:
		for t: Variant in tags:
			if str(t).to_lower().contains(f):
				return true
	return false

## Rehace grilla y recientes. `clave_a_seleccionar` queda seleccionada y visible si
## pasa el filtro.
func _poblar(clave_a_seleccionar: String = "") -> void:
	_grilla.clear()
	_items_grilla.clear()
	_cola_miniaturas.clear()
	var total := 0
	for entrada in RegistroAvatares.obtener_avatares_ordenados():
		total += 1
		if not _pasa_filtro(entrada, _filtro.text):
			continue
		var clave := RegistroAvatares.clave_de(entrada)
		var indice := _agregar_item(_grilla, entrada, clave)
		_items_grilla[clave] = indice
	_poblar_recientes()

	_clave_seleccionada = ""
	if not clave_a_seleccionar.is_empty() and _items_grilla.has(clave_a_seleccionar):
		var indice: int = _items_grilla[clave_a_seleccionar]
		_grilla.select(indice)
		_grilla.ensure_current_is_visible()
		_clave_seleccionada = clave_a_seleccionar
	_mostrar_detalle(_clave_seleccionada)

	if total == 0:
		_actualizar_estado("El registro está vacío: usá «Importar no registrados» o «+ Agregar».")
	else:
		_actualizar_estado("")
	if not _cola_miniaturas.is_empty():
		set_process(true)

func _poblar_recientes() -> void:
	_lista_recientes.clear()
	_items_recientes.clear()
	for entrada in RegistroAvatares.obtener_recientes():
		var clave := RegistroAvatares.clave_de(entrada)
		_items_recientes[clave] = _agregar_item(_lista_recientes, entrada, clave)
	_caja_recientes.visible = _lista_recientes.item_count > 0

func _agregar_item(lista: ItemList, entrada: Dictionary, clave: String) -> int:
	var nombre := str(entrada.get("nombre", ""))
	var ruta := RegistroAvatares.resolver_ruta(entrada)
	var icono: Texture2D = null
	if ruta.is_empty():
		icono = get_theme_icon(&"FileBroken", &"EditorIcons")
	elif RegistroAvatares.miniatura_en_cache(ruta):
		icono = RegistroAvatares.miniatura_de_ruta(ruta)
	else:
		icono = _obtener_textura_vacia()
		if not _cola_miniaturas.has(clave):
			_cola_miniaturas.append(clave)
	var indice := lista.add_item(nombre, icono)
	lista.set_item_metadata(indice, clave)
	if ruta.is_empty():
		lista.set_item_text(indice, nombre + " (falta)")
		lista.set_item_custom_fg_color(indice, get_theme_color(&"error_color", &"Editor"))
		lista.set_item_tooltip(indice, "%s\nNo se encuentra el recurso: %s" % [nombre, str(entrada.get("ruta", ""))])
	else:
		lista.set_item_tooltip(indice, "%s\n%s" % [nombre, ruta])
	return indice

## Textura transparente para reservar el hueco del ícono mientras carga.
static func _obtener_textura_vacia() -> Texture2D:
	if _textura_vacia == null:
		_textura_vacia = ImageTexture.create_from_image(Image.create_empty(16, 22, false, Image.FORMAT_RGBA8))
	return _textura_vacia

func _process(delta: float) -> void:
	var procesadas := 0
	while not _cola_miniaturas.is_empty() and procesadas < MINIATURAS_POR_FRAME:
		var clave: String = _cola_miniaturas.pop_front()
		procesadas += 1
		var entrada := RegistroAvatares.buscar_por_clave(clave)
		if entrada.is_empty():
			continue
		var icono := RegistroAvatares.miniatura_de_ruta(RegistroAvatares.resolver_ruta(entrada))
		if icono == null:
			icono = get_theme_icon(&"FileBroken", &"EditorIcons")
		if _items_grilla.has(clave):
			_grilla.set_item_icon(int(_items_grilla[clave]), icono)
		if _items_recientes.has(clave):
			_lista_recientes.set_item_icon(int(_items_recientes[clave]), icono)

	if _vista_texturas.size() > 1 and _vista_fps > 0.0:
		_vista_tiempo += delta
		var duracion := 1.0 / _vista_fps
		if _vista_tiempo >= duracion:
			_vista_tiempo = fmod(_vista_tiempo, duracion)
			_vista_indice = (_vista_indice + 1) % _vista_texturas.size()
			_vista_previa.texture = _vista_texturas[_vista_indice]
	elif _cola_miniaturas.is_empty():
		set_process(false)


# ─── Selección / detalle ─────────────────────────────────────────────────────────

func _seleccionar(clave: String) -> void:
	_clave_seleccionada = clave
	_mostrar_detalle(clave)

func _mostrar_detalle(clave: String) -> void:
	var entrada := RegistroAvatares.buscar_por_clave(clave) if not clave.is_empty() else {}
	var hay := not entrada.is_empty()
	get_ok_button().disabled = not hay
	_boton_renombrar.disabled = not hay
	_boton_tags.disabled = not hay
	_boton_quitar.disabled = not hay
	_vista_texturas.clear()
	_vista_indice = 0
	_vista_tiempo = 0.0
	if not hay:
		_vista_previa.texture = null
		_etiqueta_nombre.text = "Ningún avatar seleccionado"
		_etiqueta_ruta.text = ""
		_etiqueta_ruta.tooltip_text = ""
		_etiqueta_tags.text = ""
		return
	_etiqueta_nombre.text = str(entrada.get("nombre", ""))
	var ruta := RegistroAvatares.resolver_ruta(entrada)
	_etiqueta_ruta.text = ruta if not ruta.is_empty() else "No se encuentra: %s" % str(entrada.get("ruta", ""))
	_etiqueta_ruta.tooltip_text = _etiqueta_ruta.text
	var tags: Variant = entrada.get("tags", [])
	_etiqueta_tags.text = ", ".join(PackedStringArray(tags as Array)) if tags is Array else ""
	var frames := RegistroAvatares.resolver_recurso(entrada)
	_vista_texturas = RegistroAvatares.frames_vista_previa(frames)
	_vista_fps = RegistroAvatares.velocidad_vista_previa(frames)
	_vista_previa.texture = _vista_texturas[0] if not _vista_texturas.is_empty() else null
	if _vista_texturas.size() > 1:
		set_process(true)

func _on_grilla_item_selected(indice: int) -> void:
	_lista_recientes.deselect_all()
	_seleccionar(str(_grilla.get_item_metadata(indice)))

func _on_recientes_item_selected(indice: int) -> void:
	_grilla.deselect_all()
	_seleccionar(str(_lista_recientes.get_item_metadata(indice)))

func _on_grilla_item_activated(indice: int) -> void:
	_asignar(str(_grilla.get_item_metadata(indice)))

func _on_recientes_item_activated(indice: int) -> void:
	_asignar(str(_lista_recientes.get_item_metadata(indice)))

func _on_confirmado() -> void:
	if not _clave_seleccionada.is_empty():
		_asignar(_clave_seleccionada)

## Asigna el avatar al NPC (vía el callback del inspector), lo pone en recientes y cierra.
func _asignar(clave: String) -> void:
	var entrada := RegistroAvatares.buscar_por_clave(clave)
	if entrada.is_empty():
		return
	var recurso := RegistroAvatares.resolver_recurso(entrada)
	if recurso == null:
		_actualizar_estado("No se pudo cargar «%s» como SpriteFrames (%s)." % [str(entrada.get("nombre", "")), str(entrada.get("ruta", ""))])
		return
	RegistroAvatares.registrar_reciente(clave)
	var callback := _al_elegir
	hide()
	if callback.is_valid():
		callback.call(recurso)


# ─── Búsqueda ────────────────────────────────────────────────────────────────────

func _on_filtro_cambiado(_texto: String) -> void:
	_poblar(_clave_seleccionada)
	# Mientras se escribe, dejar marcado el primer resultado para que Enter lo asigne.
	if _clave_seleccionada.is_empty() and _grilla.item_count > 0:
		_grilla.select(0)
		_grilla.ensure_current_is_visible()
		_seleccionar(str(_grilla.get_item_metadata(0)))

func _on_filtro_enviado(_texto: String) -> void:
	if not _clave_seleccionada.is_empty():
		_asignar(_clave_seleccionada)
	elif _grilla.item_count > 0 and not _filtro.text.strip_edges().is_empty():
		# Sin selección solo se toma el primero si hay búsqueda (evita asignar al azar).
		_asignar(str(_grilla.get_item_metadata(0)))

func _on_filtro_gui_input(evento: InputEvent) -> void:
	var tecla := evento as InputEventKey
	if tecla == null or not tecla.pressed or tecla.keycode != KEY_DOWN:
		return
	if _grilla.item_count == 0:
		return
	_grilla.grab_focus()
	var seleccionados := _grilla.get_selected_items()
	var indice := seleccionados[0] if not seleccionados.is_empty() else 0
	_grilla.select(indice)
	_grilla.ensure_current_is_visible()
	_seleccionar(str(_grilla.get_item_metadata(indice)))
	_filtro.accept_event()


# ─── Aviso del valor actual sin registrar ────────────────────────────────────────

func _actualizar_aviso_actual() -> void:
	var mostrar := _valor_actual != null and _clave_actual.is_empty()
	_fila_aviso.visible = mostrar
	if not mostrar:
		return
	var ruta := _valor_actual.resource_path
	if ruta.is_empty() or ruta.contains("::"):
		_etiqueta_aviso.text = "Actual: recurso incrustado en la escena (no se puede registrar)"
		_etiqueta_aviso.tooltip_text = ""
		_boton_registrar_actual.disabled = true
	else:
		_etiqueta_aviso.text = "Actual: %s (sin registrar)" % ruta.get_file()
		_etiqueta_aviso.tooltip_text = ruta
		_boton_registrar_actual.disabled = false

func _on_registrar_actual_pressed() -> void:
	if _valor_actual == null:
		return
	var ruta := _valor_actual.resource_path
	_pedir_texto("Registrar avatar", "Nombre para %s:" % ruta.get_file(), RegistroAvatares.nombre_de_archivo(ruta), func(nombre: String) -> void:
		var entrada := RegistroAvatares.agregar(ruta, nombre)
		if entrada.is_empty():
			_actualizar_estado("%s no es un SpriteFrames válido." % ruta)
			return
		_clave_actual = RegistroAvatares.clave_de(entrada)
		_actualizar_aviso_actual()
		if not _pasa_filtro(entrada, _filtro.text):
			_filtro.set_block_signals(true)
			_filtro.text = ""
			_filtro.set_block_signals(false)
		_poblar(_clave_actual)
	)


# ─── Agregar / importar ──────────────────────────────────────────────────────────

func _on_agregar_pressed() -> void:
	if _dialogo_archivos == null:
		_dialogo_archivos = EditorFileDialog.new()
		_dialogo_archivos.title = "Agregar avatares (SpriteFrames)"
		_dialogo_archivos.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILES
		_dialogo_archivos.access = EditorFileDialog.ACCESS_RESOURCES
		_dialogo_archivos.add_filter("*.tres", "SpriteFrames")
		_dialogo_archivos.files_selected.connect(func(rutas: PackedStringArray) -> void:
			_on_archivos_elegidos.call_deferred(rutas)
		)
		add_child(_dialogo_archivos)
	if DirAccess.dir_exists_absolute(RegistroAvatares.CARPETA_AVATARES):
		_dialogo_archivos.current_dir = RegistroAvatares.CARPETA_AVATARES
	_dialogo_archivos.popup_centered_ratio(0.6)

## Uno solo: se pide el nombre. Varios: se registran con el nombre de archivo y se
## pueden renombrar después (más rápido que un diálogo por archivo).
func _on_archivos_elegidos(rutas: PackedStringArray) -> void:
	var validas := PackedStringArray()
	var invalidas := 0
	for ruta in rutas:
		if RegistroAvatares.es_sprite_frames(ruta):
			validas.append(ruta)
		else:
			invalidas += 1
	if validas.is_empty():
		_actualizar_estado("Ninguno de los archivos elegidos es un SpriteFrames.")
		return
	if validas.size() == 1:
		var ruta := validas[0]
		var existente := RegistroAvatares.buscar_por_ruta_o_uid(ruta)
		if not existente.is_empty():
			_limpiar_filtro_si_oculta(existente)
			_poblar(RegistroAvatares.clave_de(existente))
			_actualizar_estado("%s ya estaba registrado como «%s»." % [ruta.get_file(), str(existente.get("nombre", ""))])
			return
		_pedir_texto("Registrar avatar", "Nombre para %s:" % ruta.get_file(), RegistroAvatares.nombre_de_archivo(ruta), func(nombre: String) -> void:
			var entrada := RegistroAvatares.agregar(ruta, nombre)
			if entrada.is_empty():
				return
			_limpiar_filtro_si_oculta(entrada)
			_poblar(RegistroAvatares.clave_de(entrada))
		)
		return
	var agregados := RegistroAvatares.agregar_varios(validas)
	var primera := RegistroAvatares.buscar_por_ruta_o_uid(validas[0])
	_limpiar_filtro_si_oculta(primera)
	_poblar(RegistroAvatares.clave_de(primera) if not primera.is_empty() else "")
	var mensaje := "Se agregaron %d (ya registrados: %d). Usá «Renombrar…» para darles nombre." % [agregados, validas.size() - agregados]
	if invalidas > 0:
		mensaje += " %d archivo(s) no eran SpriteFrames." % invalidas
	_actualizar_estado(mensaje)

func _on_importar_pressed() -> void:
	var pendientes := RegistroAvatares.escanear_no_registrados()
	if pendientes.is_empty():
		_actualizar_estado("No hay SpriteFrames sin registrar en %s." % RegistroAvatares.CARPETA_AVATARES)
		return
	_confirmar("Se registrarán %d SpriteFrames de %s usando el nombre de archivo como nombre.\n¿Continuar?" % [pendientes.size(), RegistroAvatares.CARPETA_AVATARES], func() -> void:
		var agregados := RegistroAvatares.agregar_varios(pendientes)
		_poblar(_clave_seleccionada if not _clave_seleccionada.is_empty() else _clave_actual)
		_actualizar_estado("Importados %d avatares." % agregados)
	)

func _limpiar_filtro_si_oculta(entrada: Dictionary) -> void:
	if entrada.is_empty() or _pasa_filtro(entrada, _filtro.text):
		return
	_filtro.set_block_signals(true)
	_filtro.text = ""
	_filtro.set_block_signals(false)


# ─── Renombrar / tags / quitar / menú contextual ─────────────────────────────────

func _renombrar_seleccionado() -> void:
	var clave := _clave_seleccionada
	var entrada := RegistroAvatares.buscar_por_clave(clave)
	if entrada.is_empty():
		return
	_pedir_texto("Renombrar avatar", "Nombre:", str(entrada.get("nombre", "")), func(nombre: String) -> void:
		if RegistroAvatares.renombrar(clave, nombre):
			_poblar(clave)
	)

func _editar_tags_seleccionado() -> void:
	var clave := _clave_seleccionada
	var entrada := RegistroAvatares.buscar_por_clave(clave)
	if entrada.is_empty():
		return
	var tags: Variant = entrada.get("tags", [])
	var texto := ", ".join(PackedStringArray(tags as Array)) if tags is Array else ""
	_pedir_texto("Tags de «%s»" % str(entrada.get("nombre", "")), "Tags separados por coma:", texto, func(nuevo: String) -> void:
		if RegistroAvatares.cambiar_tags(clave, Array(nuevo.split(",", false))):
			_poblar(clave)
	, true)

func _quitar_seleccionado() -> void:
	var clave := _clave_seleccionada
	var entrada := RegistroAvatares.buscar_por_clave(clave)
	if entrada.is_empty():
		return
	_confirmar("¿Quitar «%s» del registro?\n(El archivo %s no se borra.)" % [str(entrada.get("nombre", "")), str(entrada.get("ruta", "")).get_file()], func() -> void:
		if RegistroAvatares.quitar(clave):
			if clave == _clave_actual:
				_clave_actual = ""
				_actualizar_aviso_actual()
			_poblar("")
	)

func _on_lista_item_clicked(indice: int, posicion: Vector2, boton: int, lista: ItemList) -> void:
	if boton != MOUSE_BUTTON_RIGHT:
		return
	lista.select(indice)
	if lista == _grilla:
		_on_grilla_item_selected(indice)
	else:
		_on_recientes_item_selected(indice)
	_menu_contextual.position = Vector2i(lista.get_screen_position() + posicion)
	_menu_contextual.reset_size()
	_menu_contextual.popup()

func _on_menu_contextual_id_pressed(id: int) -> void:
	match id:
		AccionMenu.SELECCIONAR:
			_asignar.call_deferred(_clave_seleccionada)
		AccionMenu.RENOMBRAR:
			_renombrar_seleccionado.call_deferred()
		AccionMenu.EDITAR_TAGS:
			_editar_tags_seleccionado.call_deferred()
		AccionMenu.MOSTRAR_EN_FS:
			var ruta := RegistroAvatares.resolver_ruta(RegistroAvatares.buscar_por_clave(_clave_seleccionada))
			if not ruta.is_empty():
				EditorInterface.select_file(ruta)
		AccionMenu.QUITAR:
			_quitar_seleccionado.call_deferred()


# ─── Utilidades ──────────────────────────────────────────────────────────────────

## Diálogo de una línea. `accion` recibe el texto (solo si no queda vacío, salvo
## `permitir_vacio`).
func _pedir_texto(titulo: String, etiqueta: String, inicial: String, accion: Callable, permitir_vacio: bool = false) -> void:
	_dialogo_texto.title = titulo
	_dialogo_texto_etiqueta.text = etiqueta
	_dialogo_texto_edit.text = inicial
	_accion_texto = func(texto: String) -> void:
		if texto.strip_edges().is_empty() and not permitir_vacio:
			return
		accion.call(texto)
	_dialogo_texto.popup_centered()
	_dialogo_texto_edit.grab_focus()
	_dialogo_texto_edit.select_all()

func _confirmar(texto: String, accion: Callable) -> void:
	_dialogo_confirmar.title = "Confirmar"
	_dialogo_confirmar.dialog_text = texto
	_accion_confirmar = accion
	_dialogo_confirmar.popup_centered()

func _actualizar_estado(mensaje: String) -> void:
	var texto := "%d de %d avatares" % [_grilla.item_count, RegistroAvatares.cantidad()]
	if not mensaje.is_empty():
		texto += "  ·  " + mensaje
	_etiqueta_estado.text = texto
	_etiqueta_estado.tooltip_text = mensaje

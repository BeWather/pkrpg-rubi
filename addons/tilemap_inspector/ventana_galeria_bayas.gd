@tool
extends ConfirmationDialog

## Galería de bayas para `baya_inicial` del árbol de bayas (controlador_baya.gd).
## Se abre desde editor_property_baya.gd con abrir(valor_actual, al_elegir). Como
## la galería de avatares, es una instancia única hija del base control del editor
## que se oculta al cerrar y se reutiliza (tamaño, posición, filtro y vista se
## recuerdan en variables estáticas). plugin.gd llama a liberar() en _exit_tree.
##
## Flujo rápido: al abrir, el foco está en la búsqueda; escribir filtra (por nombre,
## número o clave), Enter asigna el seleccionado (o el primero visible), ↓ pasa a la
## grilla, doble clic o Enter en la grilla asigna y cierra, Esc cierra sin cambios.

const DatosBayas = preload("res://addons/tilemap_inspector/datos_bayas_editor.gd")
const RUTA_ESTE_SCRIPT := "res://addons/tilemap_inspector/ventana_galeria_bayas.gd"
## Nombre del nodo bajo el base control (ver ventana_galeria_avatares.gd).
const NOMBRE_NODO := "GaleriaBayas"

const TAMANO_BASE := Vector2i(720, 500)
const TAMANO_MINIMO := Vector2i(520, 360)
const ICONO_GRILLA := 64
const ANCHO_COLUMNA_GRILLA := 88
const TAMANO_VISTA_PREVIA := 128
const TAMANO_ETAPA := 40
const ANCHO_PANEL_LATERAL := 220

enum Vista { ARBOL, FRUTO }

static var _instancia: ConfirmationDialog = null
static var _rect_guardado: Rect2i = Rect2i()
static var _filtro_guardado: String = ""
static var _vista_guardada: int = Vista.ARBOL

var _al_elegir: Callable = Callable()
var _valor_actual: int = -1
var _valor_seleccionado: int = -1
var _escala: float = 1.0

var _filtro: LineEdit
var _selector_vista: OptionButton
var _grilla: ItemList
var _vista_previa: TextureRect
var _icono_fruto: TextureRect
var _etiqueta_nombre: Label
var _etiqueta_detalle: Label
var _fila_etapas: HBoxContainer
var _etiqueta_estado: Label

## valor (id de la baya) -> índice del ítem en la grilla.
var _items_grilla: Dictionary = {}

var _vista_texturas: Array[Texture2D] = []
var _vista_fps: float = 0.0
var _vista_tiempo: float = 0.0
var _vista_indice: int = 0


# ─── API estática ────────────────────────────────────────────────────────────────

## Abre la galería. `al_elegir` recibe el id de la baya elegida (no se llama si se cancela).
static func abrir(valor_actual: int, al_elegir: Callable) -> void:
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
	title = "Galería de bayas"
	ok_button_text = "Seleccionar"
	cancel_button_text = "Cancelar"
	dialog_hide_on_ok = false
	_escala = EditorInterface.get_editor_scale()
	min_size = Vector2i(Vector2(TAMANO_MINIMO) * _escala)

	var raiz := VBoxContainer.new()
	raiz.add_theme_constant_override(&"separation", int(6 * _escala))
	add_child(raiz)

	# Barra superior: búsqueda + vista
	var barra := HBoxContainer.new()
	raiz.add_child(barra)
	_filtro = LineEdit.new()
	_filtro.placeholder_text = "Buscar por nombre o número…  (Enter: asignar, ↓: grilla)"
	_filtro.clear_button_enabled = true
	_filtro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.add_child(_filtro)
	_selector_vista = OptionButton.new()
	_selector_vista.tooltip_text = "Qué sprite muestra la grilla."
	_selector_vista.add_item("Árbol", Vista.ARBOL)
	_selector_vista.add_item("Fruto", Vista.FRUTO)
	barra.add_child(_selector_vista)

	# Grilla + panel lateral
	var division := HSplitContainer.new()
	division.size_flags_vertical = Control.SIZE_EXPAND_FILL
	raiz.add_child(division)
	_grilla = ItemList.new()
	_grilla.icon_mode = ItemList.ICON_MODE_TOP
	_grilla.fixed_icon_size = Vector2i(Vector2.ONE * ICONO_GRILLA * _escala)
	_grilla.fixed_column_width = int(ANCHO_COLUMNA_GRILLA * _escala)
	_grilla.max_columns = 0
	_grilla.same_column_width = true
	_grilla.max_text_lines = 2
	_grilla.select_mode = ItemList.SELECT_SINGLE
	_grilla.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_grilla.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grilla.size_flags_vertical = Control.SIZE_EXPAND_FILL
	division.add_child(_grilla)

	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(ANCHO_PANEL_LATERAL * _escala, 0)
	division.add_child(panel)
	var fila_vista := HBoxContainer.new()
	fila_vista.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(fila_vista)
	_vista_previa = _crear_textura(TAMANO_VISTA_PREVIA)
	fila_vista.add_child(_vista_previa)
	_icono_fruto = _crear_textura(DatosBayas.TAM_ICONO_FRUTO)
	_icono_fruto.size_flags_vertical = Control.SIZE_SHRINK_END
	fila_vista.add_child(_icono_fruto)
	_etiqueta_nombre = Label.new()
	_etiqueta_nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etiqueta_nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_etiqueta_nombre)
	_etiqueta_detalle = Label.new()
	_etiqueta_detalle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etiqueta_detalle.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_etiqueta_detalle.modulate = Color(1, 1, 1, 0.6)
	panel.add_child(_etiqueta_detalle)
	var titulo_etapas := Label.new()
	titulo_etapas.text = "Etapas"
	titulo_etapas.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo_etapas.modulate = Color(1, 1, 1, 0.7)
	panel.add_child(titulo_etapas)
	_fila_etapas = HBoxContainer.new()
	_fila_etapas.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(_fila_etapas)
	for animacion: StringName in DatosBayas.ANIM_ETAPAS:
		var etapa := _crear_textura(TAMANO_ETAPA)
		etapa.tooltip_text = String(animacion).substr(2).capitalize()
		etapa.mouse_filter = Control.MOUSE_FILTER_PASS
		_fila_etapas.add_child(etapa)

	_etiqueta_estado = Label.new()
	_etiqueta_estado.modulate = Color(1, 1, 1, 0.6)
	_etiqueta_estado.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	raiz.add_child(_etiqueta_estado)

	# Señales
	_filtro.text_changed.connect(_on_filtro_cambiado)
	_filtro.text_submitted.connect(_on_filtro_enviado)
	_filtro.gui_input.connect(_on_filtro_gui_input)
	_selector_vista.item_selected.connect(_on_vista_cambiada)
	_grilla.item_selected.connect(_on_grilla_item_selected)
	_grilla.item_activated.connect(_on_grilla_item_activated)
	confirmed.connect(_on_confirmado)
	visibility_changed.connect(_on_visibilidad_cambiada)

	set_process(false)
	_mostrar_detalle(-1)

func _crear_textura(tamano: int) -> TextureRect:
	var textura := TextureRect.new()
	textura.custom_minimum_size = Vector2.ONE * tamano * _escala
	textura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	textura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	textura.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return textura


# ─── Apertura / cierre ───────────────────────────────────────────────────────────

func _mostrar(valor_actual: int, al_elegir: Callable) -> void:
	_al_elegir = al_elegir
	_valor_actual = valor_actual
	_selector_vista.select(_selector_vista.get_item_index(_vista_guardada))
	_filtro.set_block_signals(true)
	_filtro.text = _filtro_guardado
	_filtro.set_block_signals(false)
	# Si el filtro recordado oculta al valor actual, gana ver el actual.
	var entrada_actual := DatosBayas.buscar(valor_actual)
	if not entrada_actual.is_empty() and not _pasa_filtro(entrada_actual, _filtro.text):
		_filtro.text = ""
	_poblar(valor_actual)

	if _rect_guardado.has_area():
		popup(_rect_guardado)
	else:
		popup_centered(Vector2i(Vector2(TAMANO_BASE) * _escala))
	if position.y < 0:
		position = Vector2i(position.x, 0)
	_filtro.grab_focus.call_deferred()
	_filtro.select_all()

func _on_visibilidad_cambiada() -> void:
	if visible:
		return
	_rect_guardado = Rect2i(position, size)
	_filtro_guardado = _filtro.text
	_al_elegir = Callable()
	_vista_texturas.clear()
	set_process(false)


# ─── Poblado ─────────────────────────────────────────────────────────────────────

func _pasa_filtro(entrada: Dictionary, texto: String) -> bool:
	var f := texto.strip_edges().to_lower()
	if f.is_empty():
		return true
	if f.is_valid_int():
		return int(entrada.numero) == f.to_int() or int(entrada.valor) == f.to_int()
	return str(entrada.clave).to_lower().contains(f)

## Rehace la grilla. `valor_a_seleccionar` queda seleccionado y visible si pasa el filtro.
func _poblar(valor_a_seleccionar: int = -1) -> void:
	_grilla.clear()
	_items_grilla.clear()
	var vista: int = _selector_vista.get_selected_id()
	for entrada: Dictionary in DatosBayas.lista():
		if not _pasa_filtro(entrada, _filtro.text):
			continue
		var icono: Texture2D = DatosBayas.icono_fruto(entrada) if vista == Vista.FRUTO else DatosBayas.miniatura_arbol(entrada)
		var indice := _grilla.add_item(DatosBayas.texto(entrada), icono)
		_grilla.set_item_metadata(indice, int(entrada.valor))
		var tooltip := "%s\n%s (id %d)" % [DatosBayas.texto(entrada), entrada.clave, entrada.valor]
		if DatosBayas.frames(entrada) == null:
			_grilla.set_item_custom_fg_color(indice, get_theme_color(&"error_color", &"Editor"))
			tooltip += "\nFalta %s" % entrada.ruta
		if int(entrada.valor) == _valor_actual:
			tooltip += "\n(actual)"
		_grilla.set_item_tooltip(indice, tooltip)
		_items_grilla[int(entrada.valor)] = indice

	_valor_seleccionado = -1
	if _items_grilla.has(valor_a_seleccionar):
		_grilla.select(_items_grilla[valor_a_seleccionar])
		_grilla.ensure_current_is_visible()
		_valor_seleccionado = valor_a_seleccionar
	_mostrar_detalle(_valor_seleccionado)
	_etiqueta_estado.text = "%d de %d bayas" % [_grilla.item_count, DatosBayas.lista().size()]

func _process(delta: float) -> void:
	if _vista_texturas.size() < 2 or _vista_fps <= 0.0:
		set_process(false)
		return
	_vista_tiempo += delta
	var duracion := 1.0 / _vista_fps
	if _vista_tiempo >= duracion:
		_vista_tiempo = fmod(_vista_tiempo, duracion)
		_vista_indice = (_vista_indice + 1) % _vista_texturas.size()
		_vista_previa.texture = _vista_texturas[_vista_indice]


# ─── Selección / detalle ─────────────────────────────────────────────────────────

func _mostrar_detalle(valor: int) -> void:
	var entrada := DatosBayas.buscar(valor) if valor >= 0 else {}
	var hay := not entrada.is_empty()
	get_ok_button().disabled = not hay
	_vista_texturas.clear()
	_vista_indice = 0
	_vista_tiempo = 0.0
	var etapas := _fila_etapas.get_children()
	if not hay:
		_vista_previa.texture = null
		_icono_fruto.texture = null
		_etiqueta_nombre.text = "Ninguna baya seleccionada"
		_etiqueta_detalle.text = ""
		for etapa: Node in etapas:
			(etapa as TextureRect).texture = null
		set_process(false)
		return
	_etiqueta_nombre.text = DatosBayas.texto(entrada)
	_etiqueta_detalle.text = "%s · id %d" % [entrada.clave, entrada.valor]
	_icono_fruto.texture = DatosBayas.icono_fruto(entrada)
	for i: int in etapas.size():
		(etapas[i] as TextureRect).texture = DatosBayas.miniatura_arbol(entrada, DatosBayas.ANIM_ETAPAS[i])
	_vista_texturas = DatosBayas.frames_etapa(entrada)
	_vista_fps = DatosBayas.velocidad_etapa(entrada)
	_vista_previa.texture = _vista_texturas[0] if not _vista_texturas.is_empty() else null
	set_process(_vista_texturas.size() > 1)

func _seleccionar(valor: int) -> void:
	_valor_seleccionado = valor
	_mostrar_detalle(valor)

func _on_grilla_item_selected(indice: int) -> void:
	_seleccionar(int(_grilla.get_item_metadata(indice)))

func _on_grilla_item_activated(indice: int) -> void:
	_asignar(int(_grilla.get_item_metadata(indice)))

func _on_confirmado() -> void:
	if _valor_seleccionado >= 0:
		_asignar(_valor_seleccionado)

## Asigna la baya al árbol (vía el callback del inspector) y cierra.
func _asignar(valor: int) -> void:
	if DatosBayas.buscar(valor).is_empty():
		return
	var callback := _al_elegir
	hide()
	if callback.is_valid():
		callback.call(valor)

func _on_vista_cambiada(_indice: int) -> void:
	_vista_guardada = _selector_vista.get_selected_id()
	_poblar(_valor_seleccionado)


# ─── Búsqueda ────────────────────────────────────────────────────────────────────

func _on_filtro_cambiado(_texto: String) -> void:
	_poblar(_valor_seleccionado)
	# Mientras se escribe, dejar marcado el primer resultado para que Enter lo asigne.
	if _valor_seleccionado < 0 and _grilla.item_count > 0:
		_grilla.select(0)
		_grilla.ensure_current_is_visible()
		_seleccionar(int(_grilla.get_item_metadata(0)))

func _on_filtro_enviado(_texto: String) -> void:
	if _valor_seleccionado >= 0:
		_asignar(_valor_seleccionado)
	elif _grilla.item_count > 0 and not _filtro.text.strip_edges().is_empty():
		_asignar(int(_grilla.get_item_metadata(0)))

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
	_seleccionar(int(_grilla.get_item_metadata(indice)))
	_filtro.accept_event()

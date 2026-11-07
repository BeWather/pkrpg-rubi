@tool
extends EditorProperty

## Editor de la propiedad `baya_inicial` (enum ENBayas) del árbol de bayas
## (controlador_baya.gd). Reemplaza la lista desplegable: muestra el icono del
## fruto + «Nº06 ARANJA» y un botón «Elegir…» que abre la galería de bayas. Clic
## en el icono o el nombre también la abre. Asigna con emit_changed(): deshacer/rehacer y
## selección múltiple (MultiNodeEdit) los resuelve el inspector.

const DatosBayas = preload("res://addons/tilemap_inspector/datos_bayas_editor.gd")
const VentanaGaleriaBayas = preload("res://addons/tilemap_inspector/ventana_galeria_bayas.gd")

const TAMANO_MINIATURA := 32
const COLOR_ATENUADO := Color(1, 1, 1, 0.55)

var _miniatura: TextureRect
var _etiqueta: Label
var _boton_elegir: Button
var _valor: int = -1


func _init() -> void:
	var escala := EditorInterface.get_editor_scale()
	var fila := HBoxContainer.new()
	fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(fila)

	_miniatura = TextureRect.new()
	_miniatura.custom_minimum_size = Vector2.ONE * TAMANO_MINIATURA * escala
	_miniatura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_miniatura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_miniatura.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_miniatura.mouse_filter = Control.MOUSE_FILTER_STOP
	_miniatura.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	fila.add_child(_miniatura)

	_etiqueta = Label.new()
	_etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_etiqueta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_etiqueta.clip_text = true
	_etiqueta.mouse_filter = Control.MOUSE_FILTER_STOP
	_etiqueta.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	fila.add_child(_etiqueta)

	_boton_elegir = Button.new()
	_boton_elegir.text = "Elegir…"
	_boton_elegir.tooltip_text = "Abrir la galería de bayas."
	fila.add_child(_boton_elegir)
	add_focusable(_boton_elegir)

	_boton_elegir.pressed.connect(_abrir_galeria)
	_miniatura.gui_input.connect(_on_area_gui_input)
	_etiqueta.gui_input.connect(_on_area_gui_input)


func _update_property() -> void:
	var objeto := get_edited_object()
	if objeto == null:
		return
	_valor = int(objeto.get(get_edited_property()))

	if _hay_valores_distintos(objeto):
		_mostrar(null, "— varios valores —", "Los árboles seleccionados tienen bayas distintas.", false)
		return
	var entrada := DatosBayas.buscar(_valor)
	if entrada.is_empty():
		_mostrar(null, "(valor %d desconocido)" % _valor, "%d no es una baya de ENBayas." % _valor, false)
		return
	var tooltip := "%s\n%s (id %d)\nClic: abrir la galería" % [DatosBayas.texto(entrada), entrada.clave, entrada.valor]
	_mostrar(DatosBayas.icono_fruto(entrada), DatosBayas.texto(entrada), tooltip, true)

func _mostrar(miniatura: Texture2D, texto: String, tooltip: String, valido: bool) -> void:
	_miniatura.texture = miniatura
	_etiqueta.text = texto
	_etiqueta.tooltip_text = tooltip
	_miniatura.tooltip_text = tooltip
	_etiqueta.modulate = Color.WHITE if valido else COLOR_ATENUADO

## Con varios árboles seleccionados (MultiNodeEdit) indica si no comparten la misma baya.
func _hay_valores_distintos(objeto: Object) -> bool:
	if objeto is Node or objeto.get_class() != &"MultiNodeEdit":
		return false
	var propiedad := get_edited_property()
	var primero: Variant = null
	var hay_primero := false
	for nodo in EditorInterface.get_selection().get_selected_nodes():
		var valor: Variant = nodo.get(propiedad)
		if not hay_primero:
			primero = valor
			hay_primero = true
		elif valor != primero:
			return true
	return false

func _set_read_only(solo_lectura: bool) -> void:
	_boton_elegir.disabled = solo_lectura


# ─── Acciones ────────────────────────────────────────────────────────────────────

func _abrir_galeria() -> void:
	if is_read_only():
		return
	VentanaGaleriaBayas.abrir(_valor, _on_baya_elegida)

func _on_baya_elegida(valor: int) -> void:
	emit_changed(get_edited_property(), valor)

func _on_area_gui_input(evento: InputEvent) -> void:
	var clic := evento as InputEventMouseButton
	if clic != null and clic.pressed and clic.button_index == MOUSE_BUTTON_LEFT:
		_abrir_galeria()
		accept_event()

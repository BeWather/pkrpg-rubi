@tool
extends Control
class_name EditorPOI
## Editor visual de POI del mapa regional de Hoenn.

const ZOOMS: Array[int] = [2, 3, 4]

var ruta_json := RegionMapMetadata.RUTA_METADATA
var region_key := RegionMapMetadata.REGION_DEFECTO
var _datos := RegionMapMetadata.new()
var _indice := -1
var _indices_visibles: Array[int] = []
var _actualizando := false
var _cargado := false
var _al_cierre_confirmado := Callable()

var _filtro: LineEdit
var _lista: ItemList
var _conteo: Label
var _lienzo: LienzoMapaRegion
var _zoom: OptionButton
var _modo: OptionButton
var _cursor_label: Label
var _estado: Label
var _btn_eliminar: Button
var _btn_guardar: Button
var _campos: Dictionary = {}
var _confirmar_eliminar: ConfirmationDialog
var _confirmar_cierre: ConfirmationDialog


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_construir_ui()


func abrir() -> void:
	if not is_node_ready():
		await ready
	if _cargado and _datos.hay_cambios():
		return
	var error := _datos.cargar(ruta_json, region_key)
	_cargado = true
	if error != OK:
		_set_estado(_datos.ultimo_error, true)
		_actualizar_habilitacion()
		return
	_reconstruir_lista()
	seleccionar(0 if _datos.cantidad() > 0 else -1)
	_set_estado("Cargados %d POI." % _datos.cantidad())


func hay_cambios_pendientes() -> bool:
	return _datos.hay_cambios()


func solicitar_cierre(al_confirmar: Callable) -> void:
	if not hay_cambios_pendientes():
		al_confirmar.call()
		return
	_al_cierre_confirmado = al_confirmar
	_confirmar_cierre.dialog_text = "Hay cambios sin guardar en los POI.\n¿Cerrar y descartarlos?"
	_confirmar_cierre.popup_centered()


func seleccionar(indice: int) -> void:
	_indice = indice if indice >= 0 and indice < _datos.cantidad() else -1
	_cargar_formulario()
	_sincronizar_lista()
	_refrescar_lienzo()
	_actualizar_habilitacion()


func _construir_ui() -> void:
	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "top", "right", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 8)
	add_child(margen)
	var raiz := VBoxContainer.new()
	raiz.add_theme_constant_override("separation", 6)
	margen.add_child(raiz)
	var principal := HBoxContainer.new()
	principal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	principal.add_theme_constant_override("separation", 10)
	raiz.add_child(principal)
	principal.add_child(_crear_panel_lista())
	principal.add_child(VSeparator.new())
	principal.add_child(_crear_panel_edicion())
	_estado = Label.new()
	_estado.custom_minimum_size = Vector2(0, 26)
	_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	raiz.add_child(_estado)
	var ayuda := Label.new()
	ayuda.text = "Editar: clic/arrastre define la zona · Seleccionar: clic elige el POI (repite para superpuestos) · Ctrl+S: guardar."
	ayuda.modulate = Color(1, 1, 1, 0.7)
	raiz.add_child(ayuda)

	_confirmar_eliminar = ConfirmationDialog.new()
	_confirmar_eliminar.title = "Eliminar POI"
	_confirmar_eliminar.ok_button_text = "Eliminar"
	_confirmar_eliminar.confirmed.connect(_eliminar_confirmado)
	add_child(_confirmar_eliminar)
	_confirmar_cierre = ConfirmationDialog.new()
	_confirmar_cierre.title = "Cambios sin guardar"
	_confirmar_cierre.ok_button_text = "Descartar y cerrar"
	_confirmar_cierre.confirmed.connect(func(): if _al_cierre_confirmado.is_valid(): _al_cierre_confirmado.call())
	add_child(_confirmar_cierre)


func _crear_panel_lista() -> Control:
	var caja := VBoxContainer.new()
	caja.custom_minimum_size = Vector2(290, 0)
	var titulo := Label.new()
	titulo.text = "POI del mapa regional"
	titulo.add_theme_font_size_override("font_size", 18)
	caja.add_child(titulo)
	_filtro = LineEdit.new()
	_filtro.placeholder_text = "Filtrar por id, mapa o nombre..."
	_filtro.clear_button_enabled = true
	_filtro.text_changed.connect(func(_t: String): _reconstruir_lista())
	caja.add_child(_filtro)
	_lista = ItemList.new()
	_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista.item_selected.connect(func(i: int): seleccionar(_indices_visibles[i]))
	caja.add_child(_lista)
	_conteo = Label.new()
	caja.add_child(_conteo)
	var botones := HBoxContainer.new()
	var nuevo := Button.new()
	nuevo.text = "Nuevo"
	nuevo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nuevo.pressed.connect(_nuevo)
	botones.add_child(nuevo)
	_btn_eliminar = Button.new()
	_btn_eliminar.text = "Eliminar"
	_btn_eliminar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_eliminar.pressed.connect(_pedir_eliminar)
	botones.add_child(_btn_eliminar)
	caja.add_child(botones)
	return caja


func _crear_panel_edicion() -> Control:
	var caja := VBoxContainer.new()
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.add_theme_constant_override("separation", 6)
	var barra := HBoxContainer.new()
	var titulo := Label.new()
	titulo.text = "Ficha y zona del POI"
	titulo.add_theme_font_size_override("font_size", 18)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.add_child(titulo)
	barra.add_child(_etiqueta("Cursor:"))
	_modo = OptionButton.new()
	_modo.add_item("Editar zona", LienzoMapaRegion.MODO_EDITAR)
	_modo.add_item("Seleccionar POI", LienzoMapaRegion.MODO_SELECCIONAR)
	_modo.item_selected.connect(_modo_cambiado)
	barra.add_child(_modo)
	barra.add_child(_etiqueta("Zoom:"))
	_zoom = OptionButton.new()
	for factor in ZOOMS:
		_zoom.add_item("×%d" % factor, factor)
	_zoom.select(0)
	_zoom.item_selected.connect(func(i: int): _aplicar_zoom(ZOOMS[i]))
	barra.add_child(_zoom)
	caja.add_child(barra)

	var contenido := HBoxContainer.new()
	contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenido.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_theme_constant_override("separation", 10)
	caja.add_child(contenido)
	var formulario := GridContainer.new()
	formulario.columns = 2
	formulario.custom_minimum_size = Vector2(300, 0)
	contenido.add_child(formulario)
	_agregar_linea(formulario, "ID", "id", "villa_raiz")
	_agregar_linea(formulario, "Mapa", "map_id", "villa_raiz")
	_agregar_linea(formulario, "Nombre", "nombre", "VILLA RAÍZ")
	_agregar_spin(formulario, "Tile X", "tile_x", 0, 27)
	_agregar_spin(formulario, "Tile Y", "tile_y", 0, 14)
	_agregar_spin(formulario, "Ancho", "ancho", 1, 28)
	_agregar_spin(formulario, "Alto", "alto", 1, 15)
	_agregar_spin(formulario, "Prioridad", "prioridad", -100, 100)
	var etiqueta_vuelo := _etiqueta("Vuelo")
	formulario.add_child(etiqueta_vuelo)
	var vuelo := CheckBox.new()
	vuelo.text = "Destino disponible"
	vuelo.toggled.connect(func(_v: bool): _formulario_cambiado())
	formulario.add_child(vuelo)
	_campos["vuelo"] = vuelo

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	contenido.add_child(scroll)
	_lienzo = LienzoMapaRegion.new()
	_lienzo.zona_cambiada.connect(_zona_cambiada)
	_lienzo.poi_seleccionado.connect(_poi_desde_mapa)
	_lienzo.cursor_tile_cambiado.connect(_cursor_cambiado)
	scroll.add_child(_lienzo)
	_cursor_label = Label.new()
	_cursor_label.text = "Coordenada: —"
	_cursor_label.custom_minimum_size = Vector2(220, 0)
	caja.add_child(_cursor_label)

	var acciones := HBoxContainer.new()
	var relleno := Control.new()
	relleno.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	acciones.add_child(relleno)
	var revertir := Button.new()
	revertir.text = "Revertir todo"
	revertir.pressed.connect(_revertir)
	acciones.add_child(revertir)
	_btn_guardar = Button.new()
	_btn_guardar.text = "Guardar POI"
	_btn_guardar.pressed.connect(guardar)
	acciones.add_child(_btn_guardar)
	caja.add_child(acciones)
	return caja


func _etiqueta(texto: String) -> Label:
	var label := Label.new()
	label.text = texto
	return label


func _agregar_linea(grid: GridContainer, etiqueta: String, clave: String, placeholder: String) -> void:
	grid.add_child(_etiqueta(etiqueta))
	var campo := LineEdit.new()
	campo.placeholder_text = placeholder
	campo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	campo.text_changed.connect(func(_t: String): _formulario_cambiado())
	grid.add_child(campo)
	_campos[clave] = campo


func _agregar_spin(grid: GridContainer, etiqueta: String, clave: String, minimo: int, maximo: int) -> void:
	grid.add_child(_etiqueta(etiqueta))
	var campo := SpinBox.new()
	campo.min_value = minimo
	campo.max_value = maximo
	campo.allow_greater = false
	campo.allow_lesser = false
	campo.value_changed.connect(func(_v: float): _formulario_cambiado())
	grid.add_child(campo)
	_campos[clave] = campo


func _reconstruir_lista() -> void:
	if _lista == null:
		return
	_lista.clear()
	_indices_visibles.clear()
	var filtro := _filtro.text.strip_edges().to_lower()
	var pois := _datos.pois()
	for i in range(pois.size()):
		var poi: Dictionary = pois[i]
		var texto_busqueda := "%s %s %s" % [poi.get("id", ""), poi.get("map_id", ""), poi.get("nombre", "")]
		if not filtro.is_empty() and not texto_busqueda.to_lower().contains(filtro):
			continue
		_indices_visibles.append(i)
		_lista.add_item("%s  —  %s" % [poi.get("id", ""), poi.get("nombre", "")])
	_conteo.text = "%d / %d POI" % [_indices_visibles.size(), _datos.cantidad()]
	_sincronizar_lista()


func _sincronizar_lista() -> void:
	if _lista == null:
		return
	var visible := _indices_visibles.find(_indice)
	if visible >= 0:
		_lista.select(visible)
		_lista.ensure_current_is_visible()
	else:
		_lista.deselect_all()


func _cargar_formulario() -> void:
	_actualizando = true
	var poi := _datos.obtener(_indice)
	var habilitado := not poi.is_empty()
	if habilitado:
		var tile: Array = poi["tile"]
		var tam: Array = poi["tile_size"]
		(_campos["id"] as LineEdit).text = String(poi["id"])
		(_campos["map_id"] as LineEdit).text = String(poi["map_id"])
		(_campos["nombre"] as LineEdit).text = String(poi["nombre"])
		(_campos["tile_x"] as SpinBox).value = int(tile[0])
		(_campos["tile_y"] as SpinBox).value = int(tile[1])
		(_campos["ancho"] as SpinBox).value = int(tam[0])
		(_campos["alto"] as SpinBox).value = int(tam[1])
		(_campos["prioridad"] as SpinBox).value = int(poi["prioridad"])
		(_campos["vuelo"] as CheckBox).button_pressed = bool(poi["vuelo"])
	else:
		for clave in ["id", "map_id", "nombre"]:
			(_campos[clave] as LineEdit).text = ""
	for control in _campos.values():
		if control is LineEdit:
			control.editable = habilitado
		elif control is SpinBox:
			control.editable = habilitado
		elif control is CheckBox:
			control.disabled = not habilitado
	_actualizando = false


func _formulario_cambiado() -> void:
	if _actualizando or _indice < 0:
		return
	var poi := _datos.obtener(_indice)
	poi["id"] = (_campos["id"] as LineEdit).text.strip_edges()
	poi["map_id"] = (_campos["map_id"] as LineEdit).text.strip_edges()
	poi["nombre"] = (_campos["nombre"] as LineEdit).text
	poi["tile"] = [int((_campos["tile_x"] as SpinBox).value), int((_campos["tile_y"] as SpinBox).value)]
	poi["tile_size"] = [int((_campos["ancho"] as SpinBox).value), int((_campos["alto"] as SpinBox).value)]
	poi["prioridad"] = int((_campos["prioridad"] as SpinBox).value)
	poi["vuelo"] = (_campos["vuelo"] as CheckBox).button_pressed
	_datos.reemplazar(_indice, poi)
	_reconstruir_lista()
	_refrescar_lienzo()
	_set_estado("* Cambios sin guardar")
	_actualizar_habilitacion()


func _zona_cambiada(tile: Vector2i, tam: Vector2i) -> void:
	if _indice < 0:
		return
	_actualizando = true
	(_campos["tile_x"] as SpinBox).value = tile.x
	(_campos["tile_y"] as SpinBox).value = tile.y
	(_campos["ancho"] as SpinBox).value = tam.x
	(_campos["alto"] as SpinBox).value = tam.y
	_actualizando = false
	_formulario_cambiado()


func _modo_cambiado(indice: int) -> void:
	if _lienzo == null:
		return
	_lienzo.modo = _modo.get_item_id(indice)
	_cursor_label.text = "Coordenada: —"


func _cursor_cambiado(tile: Vector2i, valida: bool, cantidad_pois: int) -> void:
	if not valida:
		_cursor_label.text = "Coordenada: — (margen no seleccionable)"
		return
	var sufijo := " · %d POI" % cantidad_pois if cantidad_pois > 0 else " · sin POI"
	_cursor_label.text = "Coordenada: (%d, %d)%s" % [tile.x, tile.y, sufijo]


func _poi_desde_mapa(indice: int) -> void:
	if indice < 0 or indice >= _datos.cantidad():
		return
	# Garantiza que el POI también quede visible y seleccionado en la lista.
	if not _filtro.text.is_empty():
		_filtro.text = ""
	else:
		_reconstruir_lista()
	seleccionar(indice)


func _refrescar_lienzo() -> void:
	if _lienzo != null:
		_lienzo.mostrar(_datos.pois(), _indice)


func _nuevo() -> void:
	var nuevo := _datos.agregar()
	_filtro.text = ""
	_reconstruir_lista()
	seleccionar(nuevo)
	(_campos["id"] as LineEdit).grab_focus()
	(_campos["id"] as LineEdit).select_all()
	_set_estado("Nuevo POI creado; completa sus datos y guarda.")


func _pedir_eliminar() -> void:
	if _indice < 0:
		return
	var poi := _datos.obtener(_indice)
	_confirmar_eliminar.dialog_text = "¿Eliminar el POI '%s'?" % poi.get("id", "")
	_confirmar_eliminar.popup_centered()


func _eliminar_confirmado() -> void:
	if not _datos.eliminar(_indice):
		return
	var siguiente := mini(_indice, _datos.cantidad() - 1)
	_reconstruir_lista()
	seleccionar(siguiente)
	_set_estado("POI eliminado. Guarda para aplicar el cambio.")


func guardar() -> void:
	if _indice >= 0:
		_formulario_cambiado()
	var error := _datos.guardar(ruta_json)
	if error != OK:
		_set_estado("No se pudo guardar: %s" % _datos.ultimo_error, true)
		return
	_set_estado("Guardado: %d POI en %s." % [_datos.cantidad(), ruta_json])
	_actualizar_habilitacion()


func _revertir() -> void:
	_datos.revertir()
	_reconstruir_lista()
	seleccionar(mini(_indice, _datos.cantidad() - 1))
	_set_estado("Cambios revertidos.")


func _aplicar_zoom(factor: int) -> void:
	_lienzo.zoom = factor
	var ventana := get_window()
	if ventana != null and ventana != get_tree().root:
		var minimo := Vector2i(1580, 760) if factor == 4 else Vector2i(980, 650)
		ventana.min_size = minimo
		ventana.size = ventana.size.max(minimo)


func _actualizar_habilitacion() -> void:
	var cargado := _datos.puede_guardar()
	_btn_eliminar.disabled = _indice < 0 or not cargado
	_btn_guardar.disabled = not cargado or not _datos.hay_cambios()
	# El modo selección debe seguir disponible incluso si no hay ficha activa.
	_lienzo.editable = cargado


func _set_estado(texto: String, error: bool = false) -> void:
	if _estado == null:
		return
	_estado.text = texto
	_estado.modulate = Color(1.0, 0.45, 0.4) if error else Color(1, 1, 1, 0.85)


func _shortcut_input(evento: InputEvent) -> void:
	var tecla := evento as InputEventKey
	if tecla != null and tecla.pressed and not tecla.echo and tecla.is_command_or_control_pressed() and tecla.keycode == KEY_S:
		guardar()
		get_viewport().set_input_as_handled()

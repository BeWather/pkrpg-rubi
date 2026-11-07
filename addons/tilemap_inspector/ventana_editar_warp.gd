@tool
extends Window
## Editor mínimo de un warp de la escena abierta: elige mapa destino, tile de
## llegada, dirección y paso. Modal; Enter guarda y Escape cancela.

signal cerrada

const Datos = preload("res://addons/tilemap_inspector/datos_conexiones_warp.gd")
const Vista = preload("res://addons/tilemap_inspector/vista_mapa_destino.gd")

var _plugin: EditorPlugin
var _warp: Node2D
var _raiz: Node
var _mapas: Array[Dictionary] = []
var _original: Dictionary = {}
var _ruta_destino := ""
var _celda_definida := false
var _llenando := false
var _cerrando := false
var _abrir_destino_al_cerrar := false
var _boton_abrir_destino: Button

var _filtro: LineEdit
var _lista: ItemList
var _titulo_vista: Label
var _vista: Control
var _coord_x: SpinBox
var _coord_y: SpinBox
var _direccion: OptionButton
var _paso: CheckBox
var _boton_guardar: Button
var _confirmar_descartar: ConfirmationDialog


func configurar(plugin: EditorPlugin) -> void:
	_plugin = plugin


func _ready() -> void:
	title = "Editar conexión"
	size = Vector2i(800, 400)
	min_size = Vector2i(560, 300)
	exclusive = true
	transient = true
	wrap_controls = false
	_construir_ui()
	close_requested.connect(_pedir_cancelar)


## Devuelve false si el nodo no es un warp de la escena editada.
func abrir(warp: Node) -> bool:
	if not is_node_ready():
		await ready
	_raiz = EditorInterface.get_edited_scene_root()
	if not (warp is Node2D) or _raiz == null or not (warp == _raiz or _raiz.is_ancestor_of(warp)):
		queue_free()
		return false
	_warp = warp
	_mapas = Datos.listar_mapas()
	_original = {
		"destino": str(_warp.get("ruta_mapa_destino")),
		"llegada": Vector2(_warp.get("posicion_destino")),
		"modo_direccion": Datos.modo_direccion_de(_warp),
		"direccion": Vector2(_warp.get("direccion")),
		"dar_paso": bool(_warp.get("dar_paso")),
	}
	title = "Editar conexión · %s" % _warp.name
	var origen := Datos.leer_mapa(_raiz.scene_file_path, _raiz) if not _raiz.scene_file_path.is_empty() else {}
	_filtro.text = Datos.filtro_sugerido(origen) if not origen.is_empty() else ""
	var actual := Datos.por_clave(_mapas, _original.destino)
	_llenando = true
	_paso.button_pressed = _original.dar_paso
	var indice := Datos.indice_mirar(_original.modo_direccion, _original.direccion)
	if indice < 0:
		_direccion.add_item("Actual %s" % _original.direccion)
		indice = _direccion.item_count - 1
	_direccion.select(indice)
	_llenando = false
	_ruta_destino = str(actual.get("ruta", ""))
	_celda_definida = not _ruta_destino.is_empty()
	_poner_celda(_original.llegada if _celda_definida else Vector2.ZERO)
	_refrescar_lista()
	popup_centered()
	await get_tree().process_frame
	_mostrar_destino()
	_refrescar_estado()
	return true


func _construir_ui() -> void:
	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "top", "right", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 8)
	add_child(margen)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	margen.add_child(caja)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = -180
	caja.add_child(split)

	var izquierda := VBoxContainer.new()
	izquierda.custom_minimum_size.x = 170
	split.add_child(izquierda)
	_filtro = LineEdit.new()
	_filtro.placeholder_text = "Filtrar mapas…"
	_filtro.clear_button_enabled = true
	_filtro.text_changed.connect(func(_t: String): _refrescar_lista())
	izquierda.add_child(_filtro)
	_lista = ItemList.new()
	_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista.item_selected.connect(func(i: int): _elegir_mapa(str(_lista.get_item_metadata(i))))
	izquierda.add_child(_lista)

	var derecha := VBoxContainer.new()
	derecha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(derecha)
	var barra := HBoxContainer.new()
	derecha.add_child(barra)
	_titulo_vista = Label.new()
	_titulo_vista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_titulo_vista.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_titulo_vista.text = "Sin mapa destino"
	barra.add_child(_titulo_vista)
	var ajustar := Button.new()
	ajustar.text = "Ajustar"
	ajustar.pressed.connect(func(): _vista.ajustar())
	barra.add_child(ajustar)
	_boton_abrir_destino = Button.new()
	_boton_abrir_destino.text = "Abrir mapa destino"
	_boton_abrir_destino.tooltip_text = "Cierra esta ventana y abre el mapa destino en el editor, centrado en la llegada."
	_boton_abrir_destino.pressed.connect(_pedir_abrir_destino)
	barra.add_child(_boton_abrir_destino)
	_vista = Vista.new()
	_vista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vista.custom_minimum_size = Vector2(200, 120)
	_vista.tooltip_text = "Rueda: zoom · clic derecho y arrastrar: desplazar · clic izquierdo (o derecho sin arrastrar): elegir tile de llegada"
	_vista.celda_elegida.connect(func(celda: Vector2i):
		_celda_definida = true
		_poner_celda(Vector2(celda))
		_refrescar_estado()
	)
	derecha.add_child(_vista)

	var fila := HFlowContainer.new()
	caja.add_child(fila)
	fila.add_child(_texto("Llegada X:"))
	_coord_x = _spin()
	fila.add_child(_coord_x)
	fila.add_child(_texto("Y:"))
	_coord_y = _spin()
	fila.add_child(_coord_y)
	fila.add_child(_texto("Mirar:"))
	_direccion = OptionButton.new()
	for nombre in Datos.OPCIONES_MIRAR:
		_direccion.add_item(nombre)
	_direccion.tooltip_text = "Mantener: conserva la dirección con la que entra el jugador (escaleras de Rubí). Invertir: le da la vuelta."
	_direccion.item_selected.connect(func(_i: int): _refrescar_estado())
	fila.add_child(_direccion)
	_paso = CheckBox.new()
	_paso.text = "Dar paso"
	_paso.toggled.connect(func(_a: bool): _refrescar_estado())
	fila.add_child(_paso)
	var espacio := Control.new()
	espacio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	espacio.custom_minimum_size.x = 16
	fila.add_child(espacio)
	_boton_guardar = Button.new()
	_boton_guardar.text = "Guardar"
	_boton_guardar.pressed.connect(_guardar)
	fila.add_child(_boton_guardar)
	var cancelar := Button.new()
	cancelar.text = "Cancelar"
	cancelar.pressed.connect(_cerrar)
	fila.add_child(cancelar)

	_confirmar_descartar = ConfirmationDialog.new()
	_confirmar_descartar.title = "Cambios sin guardar"
	_confirmar_descartar.dialog_text = "Hay cambios sin guardar en el warp. ¿Descartarlos y cerrar?"
	_confirmar_descartar.ok_button_text = "Descartar y cerrar"
	_confirmar_descartar.confirmed.connect(func():
		if _abrir_destino_al_cerrar:
			_abrir_destino()
		_cerrar()
	)
	_confirmar_descartar.canceled.connect(func(): _abrir_destino_al_cerrar = false)
	add_child(_confirmar_descartar)


func _texto(valor: String) -> Label:
	var label := Label.new()
	label.text = valor
	return label


func _spin() -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = -100000
	spin.max_value = 100000
	spin.rounded = true
	spin.custom_minimum_size.x = 90
	spin.value_changed.connect(func(_v: float):
		if not _llenando:
			_celda_definida = true
			_refrescar_estado()
	)
	return spin


func _poner_celda(celda: Vector2) -> void:
	_llenando = true
	_coord_x.value = celda.x
	_coord_y.value = celda.y
	_llenando = false


func _input(event: InputEvent) -> void:
	if _cerrando or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			set_input_as_handled()
			_guardar()
		KEY_ESCAPE:
			set_input_as_handled()
			_pedir_cancelar()


func _refrescar_lista() -> void:
	_lista.clear()
	var filtro := _filtro.text.strip_edges().to_lower()
	var actual := Datos.por_ruta(_mapas, _ruta_destino)
	if not actual.is_empty():
		_lista.add_item("Actual · " + str(actual.clave))
		_lista.set_item_metadata(0, str(actual.ruta))
		_lista.select(0)
	for mapa in _mapas:
		if mapa.ruta == _ruta_destino:
			continue
		if filtro.is_empty() or str(mapa.clave).to_lower().contains(filtro):
			var indice := _lista.add_item(str(mapa.clave))
			_lista.set_item_metadata(indice, str(mapa.ruta))


func _elegir_mapa(ruta: String) -> void:
	if ruta == _ruta_destino:
		return
	_ruta_destino = ruta
	# Al cambiar de mapa no se reutiliza la coordenada del anterior.
	_celda_definida = false
	_poner_celda(Vector2.ZERO)
	_mostrar_destino()
	_refrescar_estado()


func _mostrar_destino() -> void:
	_titulo_vista.text = _clave_destino() if not _ruta_destino.is_empty() 		else "Sin mapa destino (\"%s\" no existe)" % _original.destino if not str(_original.destino).is_empty() else "Sin mapa destino"
	_vista.mostrar_ruta(_ruta_destino)


## {"modo_direccion", "direccion"} elegidos; el ítem «Actual …» conserva los originales.
func _mirar_actual() -> Dictionary:
	var valores := Datos.valores_mirar(_direccion.selected)
	if valores.is_empty():
		return {"modo_direccion": int(_original.get("modo_direccion", Datos.MODO_FIJA)), "direccion": Vector2(_original.direccion)}
	return valores


func _mirar_original() -> Dictionary:
	return Datos.mirar_normalizado(int(_original.get("modo_direccion", Datos.MODO_FIJA)), Vector2(_original.direccion))


func _clave_destino() -> String:
	return str(Datos.por_ruta(_mapas, _ruta_destino).get("clave", ""))


func _celda_actual() -> Vector2:
	return Vector2(_coord_x.value, _coord_y.value)


func hay_cambios() -> bool:
	if _original.is_empty():
		return false
	return _clave_destino() != _original.destino \
		or (_celda_definida and _celda_actual() != Vector2(_original.llegada)) \
		or _mirar_actual() != _mirar_original() \
		or _paso.button_pressed != bool(_original.dar_paso)


func _refrescar_estado() -> void:
	_boton_guardar.disabled = _ruta_destino.is_empty() or not _celda_definida
	_boton_abrir_destino.disabled = _ruta_destino.is_empty()
	var visible_destino := _celda_definida and not _ruta_destino.is_empty()
	var mirar := _mirar_actual()
	_vista.fijar_destino(Vector2i(_celda_actual()) if visible_destino else null, mirar.direccion, _paso.button_pressed, mirar.modo_direccion)


func _guardar() -> void:
	if _cerrando:
		return
	_coord_x.apply()
	_coord_y.apply()
	if _ruta_destino.is_empty() or not _celda_definida:
		return
	if not hay_cambios():
		_cerrar()
		return
	if not is_instance_valid(_warp) or EditorInterface.get_edited_scene_root() != _raiz \
			or not (_warp == _raiz or _raiz.is_ancestor_of(_warp)):
		push_warning("[PKRPG] El warp ya no está en la escena editada; no se guardó nada.")
		_cerrar()
		return
	var clave := _clave_destino()
	var celda := _celda_actual()
	var mirar := _mirar_actual()
	var ur: EditorUndoRedoManager = _plugin.get_undo_redo()
	ur.create_action("Conectar %s con %s" % [_warp.name, clave], UndoRedo.MERGE_DISABLE, _raiz)
	for par in [["ruta_mapa_destino", clave], ["posicion_destino", celda], ["modo_direccion", mirar.modo_direccion], ["direccion", mirar.direccion], ["dar_paso", _paso.button_pressed]]:
		ur.add_do_property(_warp, par[0], par[1])
		ur.add_undo_property(_warp, par[0], _warp.get(par[0]))
	ur.commit_action()
	EditorInterface.mark_scene_as_unsaved()
	_cerrar()


func _pedir_abrir_destino() -> void:
	if _cerrando or _ruta_destino.is_empty():
		return
	_coord_x.apply()
	_coord_y.apply()
	if hay_cambios():
		_abrir_destino_al_cerrar = true
		_confirmar_descartar.dialog_text = "Hay cambios sin guardar en el warp. ¿Descartarlos y abrir el mapa destino?"
		_confirmar_descartar.popup_centered()
	else:
		_abrir_destino()
		_cerrar()


func _abrir_destino() -> void:
	var punto := _celda_actual() * 16.0 + Vector2(8, 8) if _celda_definida else Vector2(-1, -1)
	_plugin.abrir_mapa_centrado(_ruta_destino, punto)


func _pedir_cancelar() -> void:
	if _cerrando:
		return
	_coord_x.apply()
	_coord_y.apply()
	if hay_cambios():
		_abrir_destino_al_cerrar = false
		_confirmar_descartar.dialog_text = "Hay cambios sin guardar en el warp. ¿Descartarlos y cerrar?"
		_confirmar_descartar.popup_centered()
	else:
		_cerrar()


func _cerrar() -> void:
	if _cerrando:
		return
	_cerrando = true
	hide()
	cerrada.emit()
	queue_free()

@tool
extends Window
## OBSOLETO: reemplazado por ventana_editar_warp.gd.
## Navegador visual de conexiones dirigidas entre mapas. Las vistas son copias
## visuales; las escrituras siempre se hacen sobre la escena abierta en Godot.

const Datos = preload("res://addons/tilemap_inspector/datos_conexiones_warp.gd")
const Lienzo = preload("res://addons/tilemap_inspector/lienzo_conexiones_warp.gd")
const PlantillaWarp = preload("res://addons/tilemap_inspector/plantillas_lapiz/warp.tscn")

var _plugin: EditorPlugin
var _mapas: Array[Dictionary] = []
var _izquierda := ""
var _derecha := ""
var _warp_izquierdo := NodePath("")
var _warp_derecho := NodePath("")
var _lado_edicion := ""
var _ruta_edicion := ""
var _nodo_edicion := NodePath("")
var _original: Dictionary = {}
var _borrador_mapa := ""
var _celda_confirmada := false
var _modo := ""  # "", "llegada" o "crear"
var _celda_creacion := Vector2i.ZERO
var _edicion_propia: Dictionary = {}
var _operando := false
var _llenando := false
var _borrador_cambiado := false
var _omitir_confirmacion := false
var _accion_tras_confirmar := Callable()
var _indices_izquierda: Array[NodePath] = []

var _selector_izquierda: OptionButton
var _nombre_derecha: Label
var _lienzo_izquierdo: Control
var _lienzo_derecho: Control
var _lista_izquierda: ItemList
var _panel_lista_izquierda: Control
var _filtro_destinos: LineEdit
var _lista_destinos: ItemList
var _lista_retornos: ItemList
var _mostrar_todos: CheckButton
var _estado_izquierda: Label
var _estado_derecha: Label
var _botones_escena: Dictionary = {}
var _titulo_edicion: Label
var _destino_edicion: Label
var _coord_x: SpinBox
var _coord_y: SpinBox
var _direccion: OptionButton
var _paso: CheckBox
var _boton_celda: Button
var _boton_aplicar: Button
var _boton_crear: Button
var _estado: Label
var _confirmar_descartar: ConfirmationDialog
var _confirmar_crear: ConfirmationDialog
var _confirmar_borrador: ConfirmationDialog
var _ruta_descartar := ""
var _timer: Timer


func configurar(plugin: EditorPlugin) -> void:
	_plugin = plugin
	plugin.scene_saved.connect(func(ruta: String): _edicion_propia.erase(ruta))
	plugin.scene_closed.connect(func(ruta: String): _edicion_propia.erase(ruta))


func _ready() -> void:
	title = "Conexiones entre mapas (OBSOLETO)"
	size = Vector2i(1480, 850)
	min_size = Vector2i(1040, 650)
	_construir_ui()
	_timer = Timer.new()
	_timer.wait_time = 0.6
	_timer.autostart = true
	_timer.timeout.connect(_actualizar_estados_escena)
	add_child(_timer)
	close_requested.connect(hide)


## Desde el menú no hay mapa ni filtro activo. Desde el inspector se prepara el
## mapa que contiene al warp y el filtro sugerido para buscar otros destinos.
func abrir(warp: Node = null) -> void:
	if not is_node_ready():
		await ready
	if _pedir_descartar_borrador(Callable(self, "abrir").bind(warp)):
		return
	_mapas = Datos.listar_mapas()
	# Reabrir no convierte en «cambios previos» los que esta ventana aplicó
	# antes de ocultarse. Las escenas guardadas sí dejan de estar pendientes.
	for ruta: String in _edicion_propia.keys():
		if not _escena_sucia(ruta):
			_edicion_propia.erase(ruta)
	_rellenar_selector_izquierda()
	_izquierda = ""
	_derecha = ""
	_warp_izquierdo = NodePath("")
	_warp_derecho = NodePath("")
	_limpiar_edicion()
	var raiz: Node = null
	if is_instance_valid(warp):
		for abierta in EditorInterface.get_open_scene_roots():
			if is_instance_valid(abierta) and (warp == abierta or abierta.is_ancestor_of(warp)):
				raiz = abierta
				break
	if raiz != null:
		var mapa := Datos.por_ruta(_mapas, raiz.scene_file_path)
		if not mapa.is_empty():
			_poner_izquierda(raiz.scene_file_path)
			var ruta := Datos._ruta_relativa(raiz, warp)
			_seleccionar_warp_izquierdo(ruta)
	else:
		_lienzo_izquierdo.mostrar_mapa({})
		_lienzo_derecho.mostrar_mapa({})
		_nombre_derecha.text = "Sin mapa relacionado"
		_filtro_destinos.text = ""
		_lista_destinos.show()
		_refrescar_lista_destinos()
		_refrescar_lista_izquierda()
	_refrescar_botones()
	popup_centered()
	grab_focus()


func _construir_ui() -> void:
	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "top", "right", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 8)
	add_child(margen)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	margen.add_child(caja)
	var encabezado := HBoxContainer.new()
	caja.add_child(encabezado)
	encabezado.add_child(_texto("Mapa de referencia:"))
	_selector_izquierda = OptionButton.new()
	_selector_izquierda.custom_minimum_size.x = 250
	_selector_izquierda.item_selected.connect(func(i: int):
		if not _llenando:
			_poner_izquierda(str(_selector_izquierda.get_item_metadata(i)))
			if str(_selector_izquierda.get_item_metadata(i)) != _izquierda:
				_seleccionar_ruta_izquierda()
	)
	encabezado.add_child(_selector_izquierda)
	encabezado.add_child(_boton("Abrir en editor", func(): _abrir_en_editor(_izquierda)))
	encabezado.add_child(_boton("↻", _refrescar_vistas))
	var separador := Control.new()
	separador.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	encabezado.add_child(separador)
	encabezado.add_child(_boton("⇄ Intercambiar", _intercambiar))
	var separador2 := Control.new()
	separador2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	encabezado.add_child(separador2)
	encabezado.add_child(_texto("Mapa relacionado:"))
	_nombre_derecha = _texto("Sin mapa seleccionado")
	_nombre_derecha.custom_minimum_size.x = 170
	encabezado.add_child(_nombre_derecha)
	encabezado.add_child(_boton("Abrir en editor", func(): _abrir_en_editor(_derecha)))

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 750
	caja.add_child(split)
	split.add_child(_crear_panel_izquierdo())
	split.add_child(_crear_panel_derecho())

	var estados := HBoxContainer.new()
	caja.add_child(estados)
	_estados_en_panel(estados, true)
	_estados_en_panel(estados, false)
	caja.add_child(HSeparator.new())
	_crear_formulario(caja)
	_estado = _texto("Selecciona un mapa y pulsa un marcador para navegar. Rueda: zoom · botón central/derecho: desplazar.")
	_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(_estado)

	_confirmar_descartar = ConfirmationDialog.new()
	_confirmar_descartar.title = "Descartar cambios de la escena"
	_confirmar_descartar.ok_button_text = "Descartar toda la escena"
	_confirmar_descartar.confirmed.connect(_descartar_confirmado)
	add_child(_confirmar_descartar)
	_confirmar_crear = ConfirmationDialog.new()
	_confirmar_crear.title = "Crear warp de retorno"
	_confirmar_crear.ok_button_text = "Crear retorno"
	_confirmar_crear.confirmed.connect(_crear_retorno)
	add_child(_confirmar_crear)
	_confirmar_borrador = ConfirmationDialog.new()
	_confirmar_borrador.title = "Cambios de conexión sin aplicar"
	_confirmar_borrador.ok_button_text = "Descartar propuesta y continuar"
	_confirmar_borrador.dialog_text = "La llegada o los datos del warp aún no se han aplicado. ¿Descartar esta propuesta y cambiar de selección?"
	_confirmar_borrador.confirmed.connect(func():
		_omitir_confirmacion = true
		if not _ruta_edicion.is_empty():
			_cargar_edicion(_lado_edicion, _mapa_actual(_ruta_edicion), _original)
		if _accion_tras_confirmar.is_valid():
			_accion_tras_confirmar.call()
		_accion_tras_confirmar = Callable()
		_omitir_confirmacion = false
	)
	_confirmar_borrador.canceled.connect(func(): _accion_tras_confirmar = Callable())
	add_child(_confirmar_borrador)


func _crear_panel_izquierdo() -> Control:
	var caja := VBoxContainer.new()
	caja.custom_minimum_size.x = 400
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var barra := HBoxContainer.new()
	caja.add_child(barra)
	barra.add_child(_texto("Clic en un marcador: elegir warp · rueda: zoom"))
	var espacio := Control.new()
	espacio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.add_child(espacio)
	barra.add_child(_boton("Lista de warps ☰", func(): _panel_lista_izquierda.visible = not _panel_lista_izquierda.visible))
	barra.add_child(_boton("Ajustar", func(): _lienzo_izquierdo.ajustar_mapa()))
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.add_child(split)
	_panel_lista_izquierda = VBoxContainer.new()
	_panel_lista_izquierda.custom_minimum_size.x = 210
	split.add_child(_panel_lista_izquierda)
	_panel_lista_izquierda.add_child(_texto("Warps del mapa de referencia"))
	_lista_izquierda = ItemList.new()
	_lista_izquierda.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista_izquierda.item_selected.connect(func(i: int): _seleccionar_warp_izquierdo(_indices_izquierda[i]))
	_panel_lista_izquierda.add_child(_lista_izquierda)
	_panel_lista_izquierda.hide()
	_lienzo_izquierdo = Lienzo.new()
	_lienzo_izquierdo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lienzo_izquierdo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lienzo_izquierdo.warp_elegido.connect(_seleccionar_warp_izquierdo)
	_lienzo_izquierdo.celda_elegida.connect(func(celda: Vector2i): _al_elegir_celda(celda, "izquierda"))
	_lienzo_izquierdo.cursor_en_celda.connect(func(celda: Vector2i): _estado_cursor(celda, "izquierda"))
	_lienzo_izquierdo.accion_cancelada.connect(_al_cancelar_modo)
	split.add_child(_lienzo_izquierdo)
	return caja


func _crear_panel_derecho() -> Control:
	var caja := VBoxContainer.new()
	caja.custom_minimum_size.x = 350
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var buscador := HBoxContainer.new()
	caja.add_child(buscador)
	_filtro_destinos = LineEdit.new()
	_filtro_destinos.placeholder_text = "Buscar mapa destino…"
	_filtro_destinos.clear_button_enabled = true
	_filtro_destinos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filtro_destinos.text_changed.connect(func(_texto_nuevo: String):
		_refrescar_lista_destinos()
		_lista_destinos.show()
	)
	buscador.add_child(_filtro_destinos)
	buscador.add_child(_boton("Ajustar", func(): _lienzo_derecho.ajustar_mapa()))
	_lista_destinos = ItemList.new()
	_lista_destinos.custom_minimum_size.y = 100
	_lista_destinos.item_selected.connect(func(i: int): _elegir_mapa_derecho(str(_lista_destinos.get_item_metadata(i))))
	caja.add_child(_lista_destinos)
	_lienzo_derecho = Lienzo.new()
	_lienzo_derecho.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lienzo_derecho.warp_elegido.connect(_seleccionar_warp_derecho)
	_lienzo_derecho.celda_elegida.connect(func(celda: Vector2i): _al_elegir_celda(celda, "derecha"))
	_lienzo_derecho.cursor_en_celda.connect(func(celda: Vector2i): _estado_cursor(celda, "derecha"))
	_lienzo_derecho.accion_cancelada.connect(_al_cancelar_modo)
	caja.add_child(_lienzo_derecho)
	var barra := HBoxContainer.new()
	caja.add_child(barra)
	barra.add_child(_texto("Warps del mapa derecho"))
	_mostrar_todos = CheckButton.new()
	_mostrar_todos.text = "Todos"
	_mostrar_todos.tooltip_text = "Mostrar también los warps que no regresan al mapa izquierdo"
	_mostrar_todos.toggled.connect(func(_activo: bool): _refrescar_retornos())
	barra.add_child(_mostrar_todos)
	_lista_retornos = ItemList.new()
	_lista_retornos.custom_minimum_size.y = 88
	_lista_retornos.item_selected.connect(func(i: int): _seleccionar_warp_derecho(_lista_retornos.get_item_metadata(i) as NodePath))
	caja.add_child(_lista_retornos)
	_boton_crear = _boton("Crear warp de retorno aquí…", _iniciar_creacion)
	caja.add_child(_boton_crear)
	return caja


func _estados_en_panel(contenedor: HBoxContainer, izquierda: bool) -> void:
	var caja := HBoxContainer.new()
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenedor.add_child(caja)
	var estado := _texto("")
	estado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	estado.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caja.add_child(estado)
	if izquierda:
		_estado_izquierda = estado
	else:
		_estado_derecha = estado
	var ruta_lado := "izquierda" if izquierda else "derecha"
	var guardar := _boton("Guardar escena", func(): _guardar_escena(_izquierda if ruta_lado == "izquierda" else _derecha))
	guardar.tooltip_text = "Guarda la escena completa, incluidos cambios ajenos a Conexiones."
	var descartar := _boton("Descartar…", func(): _pedir_descartar(_izquierda if ruta_lado == "izquierda" else _derecha))
	descartar.tooltip_text = "Descarta TODOS los cambios sin guardar de esta escena, previa confirmación."
	caja.add_child(guardar)
	caja.add_child(descartar)
	_botones_escena[ruta_lado] = {"guardar": guardar, "descartar": descartar}


func _crear_formulario(contenedor: VBoxContainer) -> void:
	var fila := HBoxContainer.new()
	contenedor.add_child(fila)
	_titulo_edicion = _texto("Ningún warp seleccionado")
	_titulo_edicion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(_titulo_edicion)
	_destino_edicion = _texto("")
	_destino_edicion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(_destino_edicion)
	var campos := HBoxContainer.new()
	contenedor.add_child(campos)
	campos.add_child(_texto("Llegada X:"))
	_coord_x = _spin()
	campos.add_child(_coord_x)
	campos.add_child(_texto("Y:"))
	_coord_y = _spin()
	campos.add_child(_coord_y)
	campos.add_child(_texto("Mirar / paso:"))
	_direccion = OptionButton.new()
	for nombre in Datos.OPCIONES_MIRAR:
		_direccion.add_item(nombre)
	campos.add_child(_direccion)
	_paso = CheckBox.new()
	_paso.text = "Dar paso"
	campos.add_child(_paso)
	_boton_celda = _boton("Elegir celda en el otro mapa", _iniciar_eleccion_celda)
	campos.add_child(_boton_celda)
	_boton_aplicar = _boton("Aplicar al warp", _aplicar_edicion)
	campos.add_child(_boton_aplicar)
	_coord_x.value_changed.connect(func(_v: float):
		if not _llenando:
			_celda_confirmada = true
			_borrador_cambiado = true
			_mostrar_llegada_propuesta()
			_refrescar_botones()
	)
	_coord_y.value_changed.connect(func(_v: float):
		if not _llenando:
			_celda_confirmada = true
			_borrador_cambiado = true
			_mostrar_llegada_propuesta()
			_refrescar_botones()
	)
	_direccion.item_selected.connect(func(_i: int):
		if not _llenando:
			_borrador_cambiado = true
			_mostrar_llegada_propuesta()
	)
	_paso.toggled.connect(func(_activo: bool):
		if not _llenando:
			_borrador_cambiado = true
			_mostrar_llegada_propuesta()
	)


func _texto(valor: String) -> Label:
	var label := Label.new()
	label.text = valor
	return label


func _boton(valor: String, accion: Callable) -> Button:
	var boton := Button.new()
	boton.text = valor
	boton.pressed.connect(accion)
	return boton


func _spin() -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = -100000
	spin.max_value = 100000
	spin.rounded = true
	spin.custom_minimum_size.x = 90
	return spin


func _rellenar_selector_izquierda() -> void:
	_llenando = true
	_selector_izquierda.clear()
	_selector_izquierda.add_item("Elegir mapa…")
	_selector_izquierda.set_item_metadata(0, "")
	for mapa in _mapas:
		var indice := _selector_izquierda.item_count
		_selector_izquierda.add_item(str(mapa.clave))
		_selector_izquierda.set_item_metadata(indice, str(mapa.ruta))
	_selector_izquierda.select(0)
	_llenando = false


func _poner_izquierda(ruta: String) -> void:
	if _pedir_descartar_borrador(Callable(self, "_poner_izquierda").bind(ruta)):
		return
	_cancelar_modo()
	_izquierda = ruta
	_derecha = ""
	_warp_izquierdo = NodePath("")
	_warp_derecho = NodePath("")
	_limpiar_edicion()
	var mapa := _mapa_actual(ruta)
	_lienzo_izquierdo.mostrar_mapa(mapa)
	_lienzo_derecho.mostrar_mapa({})
	_nombre_derecha.text = "Sin mapa relacionado"
	_refrescar_lista_izquierda()
	_filtro_destinos.text = Datos.filtro_sugerido(mapa) if not mapa.is_empty() else ""
	_lista_destinos.show()
	_refrescar_lista_destinos()
	_refrescar_retornos()
	_seleccionar_ruta_izquierda()
	_refrescar_botones()


func _seleccionar_ruta_izquierda() -> void:
	_llenando = true
	for i in _selector_izquierda.item_count:
		if str(_selector_izquierda.get_item_metadata(i)) == _izquierda:
			_selector_izquierda.select(i)
			break
	_llenando = false


func _mapa_actual(ruta: String) -> Dictionary:
	if ruta.is_empty():
		return {}
	var raiz := Datos.raiz_abierta(ruta)
	var cache := Datos.por_ruta(_mapas, ruta)
	if raiz == null and (cache.is_empty() or bool(cache.get("cargado", false))):
		return cache
	var mapa := Datos.leer_mapa(ruta, raiz)
	if not mapa.is_empty():
		for i in _mapas.size():
			if _mapas[i].ruta == ruta:
				_mapas[i] = mapa
				break
		return mapa
	return cache


func _refrescar_lista_izquierda() -> void:
	_lista_izquierda.clear()
	_indices_izquierda.clear()
	for warp in _mapa_actual(_izquierda).get("warps", []):
		var destino := str(warp.destino)
		if destino.is_empty():
			destino = "sin definir"
		_lista_izquierda.add_item("%s %s → %s" % [warp.nombre, warp.celda, destino])
		_indices_izquierda.append(warp.nodo)


func _refrescar_lista_destinos() -> void:
	if _lista_destinos == null:
		return
	_lista_destinos.clear()
	var incluidos: Dictionary = {}
	var mapa_izq := _mapa_actual(_izquierda)
	# Siempre accesibles el destino actual y todos los ya conectados, aunque sus
	# nombres no coincidan con el filtro sugerido (villa_raiz → nodo_casa…).
	for warp in mapa_izq.get("warps", []):
		var asociado := Datos.por_clave(_mapas, str(warp.destino))
		if not asociado.is_empty() and not incluidos.has(asociado.ruta):
			_agregar_destino(asociado, "Conectado · ")
			incluidos[asociado.ruta] = true
	var filtro := _filtro_destinos.text.strip_edges().to_lower()
	for mapa in _mapas:
		if incluidos.has(mapa.ruta):
			continue
		if filtro.is_empty() or str(mapa.clave).to_lower().contains(filtro):
			_agregar_destino(mapa, "")


func _agregar_destino(mapa: Dictionary, prefijo: String) -> void:
	var indice := _lista_destinos.add_item(prefijo + str(mapa.clave))
	_lista_destinos.set_item_metadata(indice, str(mapa.ruta))


func _elegir_mapa_derecho(ruta: String) -> void:
	if ruta == _derecha:
		_lista_destinos.hide()
		return
	if _lado_edicion == "derecha" and _pedir_descartar_borrador(Callable(self, "_elegir_mapa_derecho").bind(ruta)):
		return
	_poner_derecha(ruta)
	if _lado_edicion == "izquierda" and not _ruta_edicion.is_empty():
		_borrador_cambiado = true
		_borrador_mapa = ruta
		_celda_confirmada = str(_original.destino).to_lower() == str(_mapa_actual(ruta).clave).to_lower()
		_llenando = true
		_coord_x.value = _original.llegada.x if _celda_confirmada else 0
		_coord_y.value = _original.llegada.y if _celda_confirmada else 0
		_llenando = false
		_destino_edicion.text = "Destino propuesto: %s%s" % [str(_mapa_actual(ruta).clave), " · elige celda" if not _celda_confirmada else ""]
		_mostrar_llegada_propuesta()
		_refrescar_botones()
	_lista_destinos.hide()


func _poner_derecha(ruta: String) -> void:
	_cancelar_modo()
	if _lado_edicion == "derecha" and _ruta_edicion != ruta:
		_limpiar_edicion()
	_derecha = ruta
	_warp_derecho = NodePath("")
	var mapa := _mapa_actual(ruta)
	_nombre_derecha.text = str(mapa.get("clave", "Sin mapa relacionado"))
	_lienzo_derecho.mostrar_mapa(mapa)
	_refrescar_retornos()
	_refrescar_botones()


func _seleccionar_warp_izquierdo(ruta: NodePath) -> void:
	if _pedir_descartar_borrador(Callable(self, "_seleccionar_warp_izquierdo").bind(ruta)):
		return
	var mapa := _mapa_actual(_izquierda)
	var warp := _buscar_warp(mapa, ruta)
	if warp.is_empty():
		return
	_cancelar_modo()
	_warp_izquierdo = ruta
	_lienzo_izquierdo.seleccionar_warp(ruta)
	for i in _indices_izquierda.size():
		if _indices_izquierda[i] == ruta:
			_lista_izquierda.select(i)
			break
	var destino := Datos.por_clave(_mapas, str(warp.destino))
	_poner_derecha(str(destino.get("ruta", "")))
	_cargar_edicion("izquierda", mapa, warp)
	if not destino.is_empty():
		_lienzo_derecho.marcar_llegada(warp.llegada, warp.direccion, warp.dar_paso, int(warp.get("modo_direccion", Datos.MODO_FIJA)))
	_lista_destinos.visible = destino.is_empty()
	_refrescar_lista_destinos()
	_refrescar_retornos()
	_estado.text = "%s %s → %s %s" % [mapa.clave, warp.celda, str(warp.destino) if not str(warp.destino).is_empty() else "sin destino", warp.llegada]


func _refrescar_retornos() -> void:
	if _lista_retornos == null:
		return
	_lista_retornos.clear()
	var origen := _mapa_actual(_izquierda)
	var relacionado := _mapa_actual(_derecha)
	var warp := _buscar_warp(origen, _warp_izquierdo)
	var celda: Vector2i = warp.celda if not warp.is_empty() else Vector2i(100000, 100000)
	var candidatos: Array[Dictionary] = []
	if not origen.is_empty() and not relacionado.is_empty():
		candidatos = Datos.retornos_posibles(relacionado, origen, celda)
	var agregados: Dictionary = {}
	for retorno in candidatos:
		var etiqueta := "Llega a esta celda · " if retorno.exacto else "Al mapa (otra celda) · "
		var indice := _lista_retornos.add_item(etiqueta + str(retorno.nombre) + " " + str(retorno.celda))
		_lista_retornos.set_item_metadata(indice, retorno.nodo)
		agregados[retorno.nodo] = true
	if _mostrar_todos.button_pressed:
		for otro in relacionado.get("warps", []):
			if not agregados.has(otro.nodo):
				var indice := _lista_retornos.add_item("Otro · " + str(otro.nombre) + " " + str(otro.celda))
				_lista_retornos.set_item_metadata(indice, otro.nodo)
	if not origen.is_empty() and not relacionado.is_empty() and candidatos.is_empty() and not _mostrar_todos.button_pressed:
		_lista_retornos.add_item("Sin retorno detectado (puede ser intencional)")
		_lista_retornos.set_item_disabled(0, true)
	_refrescar_botones()


func _seleccionar_warp_derecho(ruta: NodePath) -> void:
	if _pedir_descartar_borrador(Callable(self, "_seleccionar_warp_derecho").bind(ruta)):
		return
	var mapa := _mapa_actual(_derecha)
	var warp := _buscar_warp(mapa, ruta)
	if warp.is_empty():
		return
	_cancelar_modo()
	_warp_derecho = ruta
	_lienzo_derecho.seleccionar_warp(ruta)
	_cargar_edicion("derecha", mapa, warp)
	var origen := _mapa_actual(_izquierda)
	if str(warp.destino).to_lower() == str(origen.get("clave", "")).to_lower():
		_lienzo_izquierdo.marcar_llegada(warp.llegada, warp.direccion, warp.dar_paso, int(warp.get("modo_direccion", Datos.MODO_FIJA)))
	else:
		_lienzo_izquierdo.marcar_llegada(null)
	_estado.text = "Editando %s del mapa derecho. Para asignarle un retorno, elige una celda en el mapa izquierdo." % warp.nombre


func _buscar_warp(mapa: Dictionary, ruta: NodePath) -> Dictionary:
	for warp in mapa.get("warps", []):
		if warp.nodo == ruta:
			return warp
	return {}


func _cargar_edicion(lado: String, mapa: Dictionary, warp: Dictionary) -> void:
	_lado_edicion = lado
	_ruta_edicion = str(mapa.ruta)
	_nodo_edicion = warp.nodo
	_original = warp.duplicate()
	var opuesto := _derecha if lado == "izquierda" else _izquierda
	var otro := _mapa_actual(opuesto)
	_borrador_mapa = opuesto
	_celda_confirmada = not otro.is_empty() and str(warp.destino).to_lower() == str(otro.clave).to_lower()
	_llenando = true
	_coord_x.value = warp.llegada.x if _celda_confirmada else 0
	_coord_y.value = warp.llegada.y if _celda_confirmada else 0
	_paso.button_pressed = warp.dar_paso
	var indice := Datos.indice_mirar(int(warp.get("modo_direccion", Datos.MODO_FIJA)), Vector2(warp.direccion))
	if _direccion.item_count > Datos.OPCIONES_MIRAR.size():
		_direccion.remove_item(_direccion.item_count - 1)
	if indice < 0:
		_direccion.add_item("Actual %s" % warp.direccion)
		indice = _direccion.item_count - 1
	_direccion.select(indice)
	_llenando = false
	_borrador_cambiado = false
	_titulo_edicion.text = "Editando %s de %s" % [warp.nombre, mapa.clave]
	_destino_edicion.text = "Llegada en %s%s" % [str(otro.get("clave", "—")), " · elige celda" if not _celda_confirmada else ""]
	_mostrar_llegada_propuesta()
	_refrescar_botones()


func _mostrar_llegada_propuesta() -> void:
	if _lado_edicion.is_empty():
		return
	var lienzo := _lienzo_derecho if _lado_edicion == "izquierda" else _lienzo_izquierdo
	if not _celda_confirmada or _borrador_mapa.is_empty():
		lienzo.marcar_llegada(null)
		return
	var mirar := _mirar_elegido(_original)
	lienzo.marcar_llegada(Vector2(_coord_x.value, _coord_y.value), mirar.direccion, _paso.button_pressed, mirar.modo_direccion)


## {"modo_direccion", "direccion"} del desplegable; el ítem «Actual …» conserva
## los valores del warp original.
func _mirar_elegido(original: Dictionary) -> Dictionary:
	var valores := Datos.valores_mirar(_direccion.selected)
	if valores.is_empty():
		return {"modo_direccion": int(original.get("modo_direccion", Datos.MODO_FIJA)), "direccion": Vector2(original.direccion)}
	return valores


func _limpiar_edicion() -> void:
	_lado_edicion = ""
	_ruta_edicion = ""
	_nodo_edicion = NodePath("")
	_original = {}
	_borrador_mapa = ""
	_celda_confirmada = false
	_borrador_cambiado = false
	if _titulo_edicion != null:
		_titulo_edicion.text = "Ningún warp seleccionado"
		_destino_edicion.text = ""
	_refrescar_botones()


func _pedir_descartar_borrador(accion: Callable) -> bool:
	if _operando:
		return true
	if _omitir_confirmacion or not _borrador_cambiado:
		return false
	_accion_tras_confirmar = accion
	if not visible:
		popup_centered()
	_confirmar_borrador.popup_centered()
	return true


func _intercambiar() -> void:
	if _derecha.is_empty():
		return
	if _pedir_descartar_borrador(Callable(self, "_intercambiar")):
		return
	var antiguo_izq := _izquierda
	var antiguo_warp := _warp_izquierdo
	var nuevo_izq := _derecha
	_poner_izquierda(nuevo_izq)
	_poner_derecha(antiguo_izq)
	_lienzo_derecho.seleccionar_warp(antiguo_warp)
	_lista_destinos.hide()
	_estado.text = "Se intercambiaron las referencias; selecciona un warp del nuevo mapa izquierdo. No se modificó ninguna conexión."


func _iniciar_eleccion_celda() -> void:
	if _ruta_edicion.is_empty() or _escena_bloqueada(_ruta_edicion):
		return
	var opuesto := _derecha if _lado_edicion == "izquierda" else _izquierda
	if opuesto.is_empty():
		return
	_modo = "llegada"
	_lienzo_izquierdo.elegir_celda(_lado_edicion == "derecha")
	_lienzo_derecho.elegir_celda(_lado_edicion == "izquierda")
	_estado.text = "Haz clic en la celda de llegada del mapa %s; no se moverá ningún warp." % str(_mapa_actual(opuesto).clave)


func _iniciar_creacion() -> void:
	if _derecha.is_empty() or _warp_izquierdo == NodePath("") or _escena_bloqueada(_derecha):
		return
	if _pedir_descartar_borrador(Callable(self, "_iniciar_creacion")):
		return
	_modo = "crear"
	_lienzo_derecho.elegir_celda(true)
	_estado.text = "Haz clic en el mapa derecho donde deseas colocar el warp de retorno (botón derecho para cancelar)."


func _al_elegir_celda(celda: Vector2i, lado: String) -> void:
	if _modo == "crear" and lado == "derecha":
		_celda_creacion = celda
		_cancelar_modo()
		var warp := _buscar_warp(_mapa_actual(_izquierda), _warp_izquierdo)
		if warp.is_empty():
			return
		_confirmar_crear.dialog_text = "Crear un warp en %s %s que vuelva a %s %s?\nSe usará la plantilla Warp (Salida); revisa su dirección y «Dar paso» después." % [
			str(_mapa_actual(_derecha).clave), celda, str(_mapa_actual(_izquierda).clave), warp.celda,
		]
		_confirmar_crear.popup_centered()
	elif _modo == "llegada" and ((lado == "derecha" and _lado_edicion == "izquierda") or (lado == "izquierda" and _lado_edicion == "derecha")):
		_llenando = true
		_coord_x.value = celda.x
		_coord_y.value = celda.y
		_llenando = false
		_celda_confirmada = true
		_borrador_cambiado = true
		var opuesto := _derecha if _lado_edicion == "izquierda" else _izquierda
		_borrador_mapa = opuesto
		_destino_edicion.text = "Llegada propuesta: %s %s" % [str(_mapa_actual(opuesto).clave), celda]
		_mostrar_llegada_propuesta()
		_cancelar_modo()
		_refrescar_botones()
		_estado.text = "Celda seleccionada: %s. Pulsa «Aplicar al warp» para confirmar." % celda


func _cancelar_modo() -> void:
	_modo = ""
	if is_instance_valid(_lienzo_izquierdo):
		_lienzo_izquierdo.elegir_celda(false)
	if is_instance_valid(_lienzo_derecho):
		_lienzo_derecho.elegir_celda(false)


func _al_cancelar_modo() -> void:
	_cancelar_modo()
	_estado.text = "Selección cancelada; no se aplicó ningún cambio."


func _estado_cursor(celda: Vector2i, lado: String) -> void:
	if not _modo.is_empty():
		_estado.text = "%s · celda %s · clic para elegir" % [lado.capitalize(), celda]


func _escena_bloqueada(ruta: String) -> bool:
	return _escena_sucia(ruta) and not _edicion_propia.has(ruta)


func _escena_sucia(ruta: String) -> bool:
	return Engine.is_editor_hint() and not ruta.is_empty() and EditorInterface.get_unsaved_scenes().has(ruta)


func _actualizar_estados_escena() -> void:
	for ruta: String in _edicion_propia.keys():
		if not _escena_sucia(ruta):
			_edicion_propia.erase(ruta)
	_estado_de_mapa(_izquierda, _estado_izquierda, _botones_escena.get("izquierda", {}))
	_estado_de_mapa(_derecha, _estado_derecha, _botones_escena.get("derecha", {}))
	_refrescar_botones()


func _estado_de_mapa(ruta: String, label: Label, controles: Dictionary) -> void:
	if label == null or controles.is_empty():
		return
	var sucia := _escena_sucia(ruta)
	label.text = ("⚠ Cambios previos sin guardar: solo lectura" if _escena_bloqueada(ruta)
		else "* Cambios de Conexiones sin guardar" if sucia else "")
	(controles.guardar as Button).disabled = not sucia or _operando
	(controles.descartar as Button).disabled = not sucia or _operando


func _refrescar_botones() -> void:
	if _boton_aplicar == null:
		return
	var editable := not _operando and not _ruta_edicion.is_empty() and not _escena_bloqueada(_ruta_edicion)
	var opuesto := _derecha if _lado_edicion == "izquierda" else _izquierda
	_boton_aplicar.disabled = not editable or not _borrador_cambiado or not _celda_confirmada or _borrador_mapa.is_empty()
	_boton_celda.disabled = not editable or opuesto.is_empty()
	# Tras elegir OTRO mapa, no reutilizar por accidente una coordenada del mapa
	# anterior. Primero se elige una celda en el lienzo; luego X/Y son editables.
	_coord_x.editable = editable and _celda_confirmada
	_coord_y.editable = editable and _celda_confirmada
	_direccion.disabled = not editable
	_paso.disabled = not editable
	if _boton_crear != null:
		_boton_crear.disabled = _operando or _derecha.is_empty() or _warp_izquierdo == NodePath("") or _escena_bloqueada(_derecha)
	if not editable and not _ruta_edicion.is_empty() and _escena_bloqueada(_ruta_edicion):
		_destino_edicion.tooltip_text = "Guarda o descarta los cambios previos de esta escena antes de editar el warp."
	else:
		_destino_edicion.tooltip_text = ""


func _abrir_en_editor(ruta: String) -> void:
	if Engine.is_editor_hint() and not ruta.is_empty():
		EditorInterface.open_scene_from_path(ruta)


func _activar_escena(ruta: String) -> Node:
	if not Engine.is_editor_hint() or ruta.is_empty():
		return null
	EditorInterface.open_scene_from_path(ruta)
	for _i in 45:
		await get_tree().process_frame
		var raiz := EditorInterface.get_edited_scene_root()
		if raiz != null and raiz.scene_file_path == ruta:
			return raiz
	return null


func _aplicar_edicion() -> void:
	if _operando or _ruta_edicion.is_empty() or _escena_bloqueada(_ruta_edicion) or not _borrador_cambiado or not _celda_confirmada:
		return
	var destino := _mapa_actual(_borrador_mapa)
	if destino.is_empty() or (_ruta_edicion != _izquierda and _ruta_edicion != _derecha):
		return
	var ruta := _ruta_edicion
	var nombre_nodo := _nodo_edicion
	var original := _original.duplicate()
	var celda := Vector2(_coord_x.value, _coord_y.value)
	var mirar := _mirar_elegido(original)
	var modo_original := int(original.get("modo_direccion", Datos.MODO_FIJA))
	var paso := _paso.button_pressed
	if str(destino.clave) == str(original.destino) and celda == Vector2(original.llegada) and mirar == Datos.mirar_normalizado(modo_original, Vector2(original.direccion)) and paso == bool(original.dar_paso):
		_estado.text = "No hay cambios en este warp."
		_borrador_cambiado = false
		_refrescar_botones()
		return
	_operando = true
	_refrescar_botones()
	var raiz := await _activar_escena(ruta)
	if raiz == null or _escena_bloqueada(ruta):
		_estado.text = "No se pudo activar la escena, o tiene cambios ajenos sin guardar. No se aplicó nada."
		_operando = false
		_refrescar_botones()
		return
	var nodo := raiz.get_node_or_null(nombre_nodo)
	if nodo == null or not Datos._hereda_script(nodo, Datos.SCRIPT_WARP):
		_estado.text = "El warp fue eliminado o cambió; actualiza la selección antes de aplicar."
		_operando = false
		_refrescar_botones()
		return
	if str(nodo.get("ruta_mapa_destino")) != str(original.destino) or Vector2(nodo.get("posicion_destino")) != Vector2(original.llegada) or Datos.modo_direccion_de(nodo) != modo_original or Vector2(nodo.get("direccion")) != Vector2(original.direccion) or bool(nodo.get("dar_paso")) != bool(original.dar_paso):
		_estado.text = "El warp cambió fuera de esta ventana. No se sobrescribió; vuelve a seleccionarlo."
		_operando = false
		_refrescar_botones()
		return
	var ur: EditorUndoRedoManager = _plugin.get_undo_redo()
	ur.create_action("Conectar %s con %s" % [nodo.name, destino.clave], UndoRedo.MERGE_DISABLE, raiz)
	for par in [["ruta_mapa_destino", str(destino.clave)], ["posicion_destino", celda], ["modo_direccion", mirar.modo_direccion], ["direccion", mirar.direccion], ["dar_paso", paso]]:
		ur.add_do_property(nodo, par[0], par[1])
		ur.add_undo_property(nodo, par[0], nodo.get(par[0]))
	ur.commit_action()
	EditorInterface.mark_scene_as_unsaved()
	_edicion_propia[ruta] = true
	_actualizar_mapa(ruta)
	_estado.text = "Conexión aplicada a %s. La escena está pendiente de guardar; Ctrl+Z la deshace." % str(_mapa_actual(ruta).clave)
	_operando = false
	_refrescar_botones()


func _actualizar_mapa(ruta: String) -> void:
	var mapa := _mapa_actual(ruta)
	if ruta == _izquierda:
		_lienzo_izquierdo.mostrar_mapa(mapa)
		_lienzo_izquierdo.seleccionar_warp(_warp_izquierdo)
		_refrescar_lista_izquierda()
	if ruta == _derecha:
		_lienzo_derecho.mostrar_mapa(mapa)
		_lienzo_derecho.seleccionar_warp(_warp_derecho)
	_refrescar_retornos()
	_refrescar_lista_destinos()
	var editado := _buscar_warp(_mapa_actual(_ruta_edicion), _nodo_edicion)
	if ruta == _ruta_edicion:
		if editado.is_empty():
			_limpiar_edicion()
		else:
			if _lado_edicion == "izquierda":
				var nuevo_destino := Datos.por_clave(_mapas, str(editado.destino))
				_poner_derecha(str(nuevo_destino.get("ruta", "")))
				if not nuevo_destino.is_empty():
					_lienzo_derecho.marcar_llegada(editado.llegada, editado.direccion, editado.dar_paso, int(editado.get("modo_direccion", Datos.MODO_FIJA)))
				else:
					_lista_destinos.show()
			elif _lado_edicion == "derecha" and str(editado.destino).to_lower() == str(_mapa_actual(_izquierda).get("clave", "")).to_lower():
				_lienzo_izquierdo.marcar_llegada(editado.llegada, editado.direccion, editado.dar_paso, int(editado.get("modo_direccion", Datos.MODO_FIJA)))
			_cargar_edicion(_lado_edicion, _mapa_actual(ruta), editado)
	_actualizar_estados_escena()


func _refrescar_vistas() -> void:
	if _pedir_descartar_borrador(Callable(self, "_refrescar_vistas")):
		return
	var origen := _izquierda
	var relacionado := _derecha
	var warp := _warp_izquierdo
	_mapas = Datos.listar_mapas()
	_rellenar_selector_izquierda()
	_poner_izquierda(origen)
	if warp != NodePath(""):
		_seleccionar_warp_izquierdo(warp)
	else:
		_poner_derecha(relacionado)
	_estado.text = "Mapas y warps actualizados. Los cambios no aplicados del formulario se descartaron."


func _crear_retorno() -> void:
	if _operando or _derecha.is_empty() or _escena_bloqueada(_derecha):
		return
	var warp := _buscar_warp(_mapa_actual(_izquierda), _warp_izquierdo)
	if warp.is_empty():
		return
	var ruta := _derecha
	var celda := _celda_creacion
	for existente in _mapa_actual(ruta).get("warps", []):
		if existente.celda == celda:
			_seleccionar_warp_derecho(existente.nodo)
			_estado.text = "Ya hay un warp en %s: se seleccionó para configurarlo, no se creó otro encima." % celda
			return
	var clave_origen := str(_mapa_actual(_izquierda).clave)
	var llegada: Vector2 = Vector2(warp.celda)
	_operando = true
	var raiz := await _activar_escena(ruta)
	if raiz == null or _escena_bloqueada(ruta) or not (raiz is Node2D):
		_estado.text = "No se pudo abrir el mapa de retorno sin conflicto; no se creó el warp."
		_operando = false
		return
	var nuevo := PlantillaWarp.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED) as Node2D
	if not (nuevo is Warp):
		# Plantilla desfasada (tipo nativo distinto al del script): el nodo saldría sin script.
		if nuevo != null:
			nuevo.free()
		_estado.text = "La plantilla de warp no generó un Warp con script; reinicia el editor y reintenta."
		_operando = false
		return
	nuevo.name = "WarpRetorno"
	var n := 2
	while raiz.has_node(NodePath(nuevo.name)):
		nuevo.name = "WarpRetorno%d" % n
		n += 1
	nuevo.position = Vector2(celda) * Datos.TAM_TILE + Vector2(8, 6)
	nuevo.set("ruta_mapa_destino", clave_origen)
	nuevo.set("posicion_destino", llegada)
	var ur: EditorUndoRedoManager = _plugin.get_undo_redo()
	ur.create_action("Crear warp de retorno en %s" % celda, UndoRedo.MERGE_DISABLE, raiz)
	ur.add_do_method(raiz, &"add_child", nuevo, true)
	ur.add_do_method(nuevo, &"set_owner", raiz)
	ur.add_do_reference(nuevo)
	ur.add_undo_method(raiz, &"remove_child", nuevo)
	ur.commit_action()
	EditorInterface.mark_scene_as_unsaved()
	_edicion_propia[ruta] = true
	var ruta_nueva := NodePath(str(nuevo.name))
	_actualizar_mapa(ruta)
	_operando = false
	_seleccionar_warp_derecho(ruta_nueva)
	_estado.text = "Retorno creado en %s. Revisa tipo, dirección y «Dar paso» antes de guardar la escena." % celda
	_refrescar_botones()


func _guardar_escena(ruta: String) -> void:
	if ruta.is_empty() or _operando or not _escena_sucia(ruta):
		return
	if ruta == _ruta_edicion and _pedir_descartar_borrador(Callable(self, "_guardar_escena").bind(ruta)):
		return
	_operando = true
	var raiz := await _activar_escena(ruta)
	if raiz == null:
		_estado.text = "No se pudo abrir la escena para guardarla."
	else:
		var error := EditorInterface.save_scene()
		if error == OK:
			_edicion_propia.erase(ruta)
			_estado.text = "Guardada la escena completa: %s" % ruta
			_actualizar_mapa(ruta)
		else:
			_estado.text = "Error al guardar %s: %s" % [ruta, error]
	_operando = false
	_actualizar_estados_escena()


func _pedir_descartar(ruta: String) -> void:
	if ruta.is_empty() or _operando or not _escena_sucia(ruta):
		return
	if ruta == _ruta_edicion and _pedir_descartar_borrador(Callable(self, "_pedir_descartar").bind(ruta)):
		return
	_ruta_descartar = ruta
	_confirmar_descartar.dialog_text = "¿Descartar TODOS los cambios sin guardar de %s?\nEsto incluye cambios ajenos a Conexiones. No se puede deshacer." % ruta
	_confirmar_descartar.popup_centered()


func _descartar_confirmado() -> void:
	var ruta := _ruta_descartar
	_ruta_descartar = ""
	if ruta.is_empty() or not EditorInterface.get_open_scenes().has(ruta):
		return
	_cancelar_modo()
	EditorInterface.reload_scene_from_path(ruta)
	_edicion_propia.erase(ruta)
	# Los nodos anteriores dejan de ser válidos: no reutilizar sus referencias.
	for _i in 4:
		await get_tree().process_frame
	_actualizar_mapa(ruta)
	_estado.text = "Se recargó %s desde disco; sus cambios pendientes se descartaron." % ruta

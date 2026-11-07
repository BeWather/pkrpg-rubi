@tool
extends Window
## Editor visual de encuentros salvajes. Edita `config_encuentros.json` o
## `config_encuentros_alternativo.json` (selector superior) mostrando cada slot
## como una tarjeta con su icono animado y su probabilidad, el resumen por especie
## y la ubicación de la clave en el mapa de región.
## Punto de entrada: abrir(mapa_id: String = "", alternativo: bool = false)

signal encuentros_guardados(ruta: String)

const FILA_RESUMEN := preload("res://addons/tilemap_inspector/editores/editor_encuentros_visual/fila_resumen.tscn")
const ARCHIVOS: Array[String] = [ModeloEncuentros.RUTA_DEFECTO, ModeloEncuentros.RUTA_ALTERNATIVO]
const TITULOS_TIPO: Dictionary = {"hierba": "🌿 Hierba", "agua": "🌊 Agua", "pesca": "🎣 Pesca", "roca": "🪨 Roca"}
const ICONOS_TIPO: Dictionary = {"hierba": "🌿", "agua": "🌊", "pesca": "🎣", "roca": "🪨"}
const MAX_AUTOCOMPLETADO := 40

@onready var _selector_archivo: OptionButton = %SelectorArchivo
@onready var _recargar: Button = %Recargar
@onready var _guardar: Button = %Guardar
@onready var _filtro: LineEdit = %Filtro
@onready var _lista_claves: ItemList = %ListaClaves
@onready var _conteo_claves: Label = %ConteoClaves
@onready var _nueva_clave: Button = %NuevaClave
@onready var _eliminar_clave: Button = %EliminarClave
@onready var _titulo_clave: Label = %TituloClave
@onready var _subtitulo_clave: Label = %SubtituloClave
@onready var _pestanas: TabContainer = %Pestanas
@onready var _lienzo: LienzoMapaRegion = %Lienzo
@onready var _lugar_mapa: Label = %LugarMapa
@onready var _titulo_resumen: Label = %TituloResumen
@onready var _resumen: VBoxContainer = %Resumen
@onready var _estado: Label = %Estado
@onready var _autocompletado: PanelContainer = %Autocompletado
@onready var _lista_autocompletado: ItemList = %ListaAutocompletado
@onready var _dialogo_nueva: ConfirmationDialog = %DialogoNuevaClave
@onready var _campo_nueva: LineEdit = %CampoNuevaClave
@onready var _dialogo_eliminar: ConfirmationDialog = %DialogoEliminar
@onready var _dialogo_descartar: ConfirmationDialog = %DialogoDescartar
@onready var _temporizador_iconos: Timer = %TemporizadorIconos

var _modelo := ModeloEncuentros.new()
var _catalogo := CatalogoPokemon.new()
var _lugares := ResolvedorLugaresEncuentro.new()
var _clave_actual: String = ""
var _indice_archivo: int = 0
## Lugares del mapa de región con encuentros en el archivo actual y, por clave,
## su índice en esa lista (-1 = sin lugar).
var _pois: Array[Dictionary] = []
var _poi_de_clave: Dictionary = {}
var _accion_pendiente: Callable = Callable()
var _fila_autocompletado: FilaSlotEncuentro = null
var _campo_autocompletado: LineEdit = null


func _ready() -> void:
	if Engine.is_editor_hint() and is_part_of_edited_scene():
		return
	_catalogo.cargar()
	for pestana: PestanaTipoEncuentro in _pestanas.get_children():
		pestana.configurar(_modelo, _catalogo)
		pestana.cambiado.connect(_on_pestana_cambiada)
		pestana.solicitar_autocompletado.connect(_mostrar_autocompletado)
	_actualizar_titulos_pestanas()
	_pestanas.tab_changed.connect(func(_i: int) -> void: _refrescar_resumen())
	_selector_archivo.item_selected.connect(_on_archivo_elegido)
	_recargar.pressed.connect(func() -> void: _con_descarte(_recargar_archivo))
	_guardar.pressed.connect(_guardar_archivo)
	_filtro.text_changed.connect(func(_t: String) -> void: _refrescar_lista())
	_lista_claves.item_selected.connect(func(i: int) -> void: _seleccionar(str(_lista_claves.get_item_metadata(i))))
	_nueva_clave.pressed.connect(_on_nueva_clave)
	_eliminar_clave.pressed.connect(_on_eliminar_clave)
	_dialogo_nueva.confirmed.connect(_on_nueva_clave_confirmada)
	_campo_nueva.text_submitted.connect(func(_t: String) -> void:
		_dialogo_nueva.hide()
		_on_nueva_clave_confirmada())
	_dialogo_eliminar.confirmed.connect(_on_eliminar_confirmado)
	_dialogo_descartar.confirmed.connect(_on_descarte_confirmado)
	_dialogo_descartar.canceled.connect(_on_descarte_cancelado)
	_lista_autocompletado.item_clicked.connect(func(i: int, _p: Vector2, _b: int) -> void: _aplicar_autocompletado(i))
	_lienzo.editable = true
	_lienzo.modo = LienzoMapaRegion.MODO_SELECCIONAR
	_lienzo.poi_seleccionado.connect(_on_poi_clicado)
	_temporizador_iconos.timeout.connect(_catalogo.alternar_frame)
	close_requested.connect(func() -> void: _con_descarte(hide))
	if _catalogo.esta_vacio():
		_set_estado("⚠️ No se pudo leer poke.db: sin nombres ni iconos, no se validan especies.", true)
	# Ejecutado como escena suelta (F6) no hay plugin que llame a abrir().
	if not Engine.is_editor_hint() and get_parent() == get_tree().root:
		(func() -> void:
			if _modelo.claves().is_empty():
				abrir()).call_deferred()


func abrir(mapa_id: String = "", alternativo: bool = false) -> void:
	if not is_node_ready():
		await ready
	var indice: int = 1 if alternativo else 0
	if not _modelo.modificado and (indice != _indice_archivo or _modelo.claves().is_empty()):
		_cargar_archivo(indice)
	if not mapa_id.is_empty() and _modelo.tiene_clave(mapa_id):
		_filtro.text = ""
		_refrescar_lista()
		_seleccionar(mapa_id)
	popup_centered()
	grab_focus()


# ─── Archivo ──────────────────────────────────────────────────────────────────

func _cargar_archivo(indice: int) -> void:
	_indice_archivo = indice
	_selector_archivo.select(indice)
	var clave_previa: String = _clave_actual
	if _modelo.cargar(ARCHIVOS[indice]) != OK:
		_set_estado("❌ " + _modelo.ultimo_error, true)
	else:
		_set_estado("Cargadas %d claves de %s." % [_modelo.claves().size(), ARCHIVOS[indice].get_file()])
	_calcular_pois()
	_refrescar_lista()
	var claves: Array[String] = _modelo.claves()
	if _modelo.tiene_clave(clave_previa):
		_seleccionar(clave_previa)
	elif not claves.is_empty():
		_seleccionar(claves[0])
	else:
		_seleccionar("")
	_actualizar_titulo_ventana()


func _recargar_archivo() -> void:
	_cargar_archivo(_indice_archivo)


func _on_archivo_elegido(indice: int) -> void:
	if indice == _indice_archivo:
		return
	# Hasta confirmar, el selector sigue mostrando el archivo abierto.
	_selector_archivo.select(_indice_archivo)
	_con_descarte(func() -> void: _cargar_archivo(indice))


func _guardar_archivo() -> void:
	if _modelo.guardar() != OK:
		_set_estado("❌ " + _modelo.ultimo_error, true)
		return
	_set_estado("✅ Guardado en %s" % _modelo.ruta.get_file())
	_actualizar_titulo_ventana()
	encuentros_guardados.emit(_modelo.ruta)


## Ejecuta `accion` ya o, si hay cambios sin guardar, tras confirmar el descarte.
func _con_descarte(accion: Callable) -> void:
	if not _modelo.modificado:
		accion.call()
		return
	_accion_pendiente = accion
	_dialogo_descartar.popup_centered()


func _on_descarte_confirmado() -> void:
	var accion: Callable = _accion_pendiente
	_accion_pendiente = Callable()
	# Descartar = volver al contenido del disco antes de seguir.
	_cargar_archivo(_indice_archivo)
	if accion.is_valid():
		accion.call()


func _on_descarte_cancelado() -> void:
	_accion_pendiente = Callable()


# ─── Lista de claves ──────────────────────────────────────────────────────────

func _refrescar_lista() -> void:
	_lista_claves.clear()
	var consulta: String = _filtro.text.strip_edges().to_upper()
	var claves: Array[String] = _modelo.claves()
	for clave: String in claves:
		if not consulta.is_empty() and not _coincide(clave, consulta):
			continue
		var marcas: String = ""
		for tipo: String in _modelo.tipos_de(clave):
			marcas += ICONOS_TIPO[tipo]
		var indice: int = _lista_claves.add_item("%s  %s" % [clave, marcas], _catalogo.icono(_especie_destacada(clave)))
		_lista_claves.set_item_metadata(indice, clave)
		_lista_claves.set_item_tooltip(indice, _nombre_lugar(clave))
		if clave == _clave_actual:
			_lista_claves.select(indice)
	_conteo_claves.text = "%d / %d claves" % [_lista_claves.item_count, claves.size()]


## Coincide por clave, por nombre del lugar o por alguna especie (interna o visible).
func _coincide(clave: String, consulta: String) -> bool:
	if clave.to_upper().contains(consulta) or _nombre_lugar(clave).to_upper().contains(consulta):
		return true
	for tipo: String in _modelo.tipos_de(clave):
		for slot: Dictionary in _modelo.slots(clave, tipo):
			var interno: String = str(slot["nombre_interno"])
			if interno.contains(consulta) or _catalogo.nombre_visible(interno).to_upper().contains(consulta):
				return true
	return false


## Primera especie del primer tipo con slots (la más común del mapa).
func _especie_destacada(clave: String) -> String:
	for tipo: String in _modelo.tipos_de(clave):
		var lista: Array[Dictionary] = _modelo.slots(clave, tipo)
		if not lista.is_empty():
			return str(lista[0]["nombre_interno"])
	return ""


func _seleccionar(clave: String) -> void:
	_ocultar_autocompletado()
	_clave_actual = clave
	for i: int in _lista_claves.item_count:
		if str(_lista_claves.get_item_metadata(i)) == clave:
			_lista_claves.select(i)
			_lista_claves.ensure_current_is_visible()
			break
	var vacia: bool = clave.is_empty()
	_titulo_clave.text = "(sin clave)" if vacia else clave
	_subtitulo_clave.text = "" if vacia else _descripcion_lugar(clave)
	_eliminar_clave.disabled = vacia
	for pestana: PestanaTipoEncuentro in _pestanas.get_children():
		pestana.cargar(clave)
	_actualizar_titulos_pestanas()
	_elegir_pestana_con_datos()
	_refrescar_mapa()
	_refrescar_resumen()


func _elegir_pestana_con_datos() -> void:
	var actual: PestanaTipoEncuentro = _pestanas.get_current_tab_control() as PestanaTipoEncuentro
	if actual != null and actual.cantidad_slots() > 0:
		return
	for i: int in _pestanas.get_tab_count():
		if (_pestanas.get_tab_control(i) as PestanaTipoEncuentro).cantidad_slots() > 0:
			_pestanas.current_tab = i
			return


func _on_nueva_clave() -> void:
	_campo_nueva.text = ""
	_dialogo_nueva.popup_centered()
	_campo_nueva.grab_focus()


func _on_nueva_clave_confirmada() -> void:
	var clave: String = _campo_nueva.text.strip_edges().to_lower()
	if clave.is_empty():
		_set_estado("⚠️ La clave no puede estar vacía.", true)
		return
	if not _modelo.agregar_clave(clave):
		_set_estado("⚠️ Ya existe la clave '%s'." % clave, true)
		return
	_calcular_pois()
	_filtro.text = ""
	_refrescar_lista()
	_seleccionar(clave)
	_actualizar_titulo_ventana()
	_set_estado("Clave '%s' creada (sin guardar)." % clave)


func _on_eliminar_clave() -> void:
	if _clave_actual.is_empty():
		return
	_dialogo_eliminar.dialog_text = "¿Eliminar todos los encuentros de '%s'?\nNo se escribe en disco hasta pulsar Guardar." % _clave_actual
	_dialogo_eliminar.popup_centered()


func _on_eliminar_confirmado() -> void:
	var clave: String = _clave_actual
	_modelo.eliminar_clave(clave)
	_calcular_pois()
	_refrescar_lista()
	_seleccionar(str(_lista_claves.get_item_metadata(0)) if _lista_claves.item_count > 0 else "")
	_actualizar_titulo_ventana()
	_set_estado("Clave '%s' eliminada (sin guardar)." % clave)


func _on_pestana_cambiada(_tipo: String) -> void:
	_actualizar_titulos_pestanas()
	_refrescar_resumen()
	_actualizar_titulo_ventana()
	_actualizar_item_actual()


## Solo la fila de la clave editada: rehacer toda la lista quitaría el foco.
func _actualizar_item_actual() -> void:
	for i: int in _lista_claves.item_count:
		if str(_lista_claves.get_item_metadata(i)) != _clave_actual:
			continue
		var marcas: String = ""
		for tipo: String in _modelo.tipos_de(_clave_actual):
			marcas += ICONOS_TIPO[tipo]
		_lista_claves.set_item_text(i, "%s  %s" % [_clave_actual, marcas])
		_lista_claves.set_item_icon(i, _catalogo.icono(_especie_destacada(_clave_actual)))
		return


func _actualizar_titulos_pestanas() -> void:
	for i: int in _pestanas.get_tab_count():
		var pestana: PestanaTipoEncuentro = _pestanas.get_tab_control(i) as PestanaTipoEncuentro
		var total: int = pestana.cantidad_slots()
		_pestanas.set_tab_title(i, "%s (%d)" % [TITULOS_TIPO[pestana.tipo], total] if total > 0 else str(TITULOS_TIPO[pestana.tipo]))


func _actualizar_titulo_ventana() -> void:
	title = "Encuentros · %s%s" % [_modelo.ruta.get_file(), "  ●" if _modelo.modificado else ""]


# ─── Mapa de región ───────────────────────────────────────────────────────────

func _calcular_pois() -> void:
	_pois.clear()
	_poi_de_clave.clear()
	var indice_por_id: Dictionary = {}
	for clave: String in _modelo.claves():
		var poi: Dictionary = _lugares.lugar_de(clave)
		if poi.is_empty():
			_poi_de_clave[clave] = -1
			continue
		var id: String = str(poi.get("id", ""))
		if not indice_por_id.has(id):
			indice_por_id[id] = _pois.size()
			_pois.append(poi)
		_poi_de_clave[clave] = indice_por_id[id]


func _nombre_lugar(clave: String) -> String:
	var indice: int = int(_poi_de_clave.get(clave, -1))
	return str(_pois[indice].get("nombre", "")) if indice >= 0 else ""


func _descripcion_lugar(clave: String) -> String:
	var nombre: String = _nombre_lugar(clave)
	var seccion: String = _lugares.seccion_de(clave)
	if nombre.is_empty():
		return "Sin lugar en el mapa de región" + ("" if seccion.is_empty() else " · sección %s" % seccion)
	return "%s · sección %s" % [nombre, seccion] if not seccion.is_empty() else nombre


func _refrescar_mapa() -> void:
	var indice: int = int(_poi_de_clave.get(_clave_actual, -1))
	_lienzo.mostrar(_pois, indice)
	if indice < 0:
		_lugar_mapa.text = "Sin POI para esta clave" if not _clave_actual.is_empty() else ""
		return
	var poi: Dictionary = _pois[indice]
	var tile: Array = poi.get("tile", [0, 0])
	var tam: Array = poi.get("tile_size", [1, 1])
	var compartidas: int = 0
	for clave: String in _poi_de_clave:
		if int(_poi_de_clave[clave]) == indice:
			compartidas += 1
	_lugar_mapa.text = "📍 %s  ·  casilla (%d, %d)  %d×%d%s" % [poi.get("nombre", ""), int(tile[0]), int(tile[1]),
			int(tam[0]), int(tam[1]), "  ·  %d claves" % compartidas if compartidas > 1 else ""]


## Clic en un lugar del mapa: selecciona su clave; con varias (plantas de una
## cueva) cada clic pasa a la siguiente.
func _on_poi_clicado(indice: int) -> void:
	var candidatas: Array[String] = []
	for clave: String in _modelo.claves():
		if int(_poi_de_clave.get(clave, -1)) == indice:
			candidatas.append(clave)
	if candidatas.is_empty():
		return
	var siguiente: int = (candidatas.find(_clave_actual) + 1) % candidatas.size()
	_filtro.text = ""
	_refrescar_lista()
	_seleccionar(candidatas[siguiente])


# ─── Resumen por especie ──────────────────────────────────────────────────────

func _refrescar_resumen() -> void:
	for fila: Node in _resumen.get_children():
		_resumen.remove_child(fila)
		fila.queue_free()
	var pestana: PestanaTipoEncuentro = _pestanas.get_current_tab_control() as PestanaTipoEncuentro
	if pestana == null:
		return
	_titulo_resumen.text = "Probabilidad por especie · %s" % TITULOS_TIPO[pestana.tipo]
	var entradas: Array[Dictionary] = ModeloEncuentros.resumen(pestana.tipo, pestana.slots_actuales())
	if entradas.is_empty():
		var vacio := Label.new()
		vacio.text = "Sin especies."
		vacio.add_theme_color_override("font_color", Color(0.5, 0.53, 0.6))
		_resumen.add_child(vacio)
		return
	var grupo_actual: String = ""
	for entrada: Dictionary in entradas:
		var grupo: String = str(entrada["grupo"])
		if grupo != grupo_actual and not grupo.is_empty():
			grupo_actual = grupo
			var cabecera := Label.new()
			cabecera.text = grupo
			cabecera.add_theme_color_override("font_color", Color(0.6, 0.75, 1.0))
			cabecera.add_theme_font_size_override("font_size", 12)
			_resumen.add_child(cabecera)
		var fila: FilaResumenEncuentro = FILA_RESUMEN.instantiate()
		_resumen.add_child(fila)
		fila.configurar(_catalogo, entrada)


# ─── Autocompletado de especies ───────────────────────────────────────────────

func _mostrar_autocompletado(fila: FilaSlotEncuentro, campo: LineEdit) -> void:
	_fila_autocompletado = fila
	_campo_autocompletado = campo
	_lista_autocompletado.clear()
	for interno: String in _catalogo.buscar(campo.text, MAX_AUTOCOMPLETADO):
		var visible_nombre: String = _catalogo.nombre_visible(interno)
		var texto: String = interno if visible_nombre == interno else "%s  ·  %s" % [visible_nombre, interno]
		var indice: int = _lista_autocompletado.add_item(texto, _catalogo.icono(interno))
		_lista_autocompletado.set_item_metadata(indice, interno)
	if _lista_autocompletado.item_count == 0:
		_ocultar_autocompletado()
		return
	_lista_autocompletado.select(0)
	var rect: Rect2 = campo.get_global_rect()
	var tam := Vector2(maxf(rect.size.x, 300.0), 240.0)
	var posicion := Vector2(rect.position.x, rect.end.y)
	var visible_rect: Vector2 = get_visible_rect().size
	if posicion.y + tam.y > visible_rect.y:
		posicion.y = rect.position.y - tam.y
	posicion.x = minf(posicion.x, visible_rect.x - tam.x)
	_autocompletado.global_position = posicion
	_autocompletado.size = tam
	_autocompletado.show()


func _ocultar_autocompletado() -> void:
	_autocompletado.hide()
	_fila_autocompletado = null
	_campo_autocompletado = null


func _aplicar_autocompletado(indice: int) -> void:
	if indice < 0 or not is_instance_valid(_fila_autocompletado):
		_ocultar_autocompletado()
		return
	var fila: FilaSlotEncuentro = _fila_autocompletado
	var interno: String = str(_lista_autocompletado.get_item_metadata(indice))
	_ocultar_autocompletado()
	fila.fijar_especie(interno)
	# grab_focus puede emitir focus_entered y reabrir la lista: se vuelve a cerrar.
	fila.campo_especie().grab_focus()
	_ocultar_autocompletado()


func _input(evento: InputEvent) -> void:
	if not is_node_ready() or not _autocompletado.visible:
		return
	var tecla := evento as InputEventKey
	if tecla != null and tecla.pressed:
		var seleccion: PackedInt32Array = _lista_autocompletado.get_selected_items()
		var actual: int = seleccion[0] if not seleccion.is_empty() else 0
		match tecla.keycode:
			KEY_ESCAPE:
				_ocultar_autocompletado()
			KEY_DOWN, KEY_UP:
				var delta: int = 1 if tecla.keycode == KEY_DOWN else -1
				var nuevo: int = clampi(actual + delta, 0, _lista_autocompletado.item_count - 1)
				_lista_autocompletado.select(nuevo)
				_lista_autocompletado.ensure_current_is_visible()
			KEY_ENTER, KEY_KP_ENTER, KEY_TAB:
				_aplicar_autocompletado(actual)
			_:
				return
		set_input_as_handled()
		return
	var boton := evento as InputEventMouseButton
	if boton != null and boton.pressed:
		var dentro_campo: bool = is_instance_valid(_campo_autocompletado) and _campo_autocompletado.get_global_rect().has_point(boton.position)
		if not dentro_campo and not _autocompletado.get_global_rect().has_point(boton.position):
			_ocultar_autocompletado()


func _set_estado(mensaje: String, error: bool = false) -> void:
	_estado.text = mensaje
	if error:
		_estado.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	else:
		_estado.remove_theme_color_override("font_color")

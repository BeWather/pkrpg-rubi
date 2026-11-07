@tool
extends Control
## Editor del guardado local (partida/partida_guardada.json). No usa
## SistemaGuardado: este script corre en el proceso del editor, no en la
## partida que se está ejecutando.
##
## Pestañas:
##   - Mochila: objetos por bolsillo.
##   - Pokémon: equipo y cajas del PC (panel_pokemon_partida.gd). La edición
##     completa de un Pokémon se hace en el Editor de Instancia de Pokémon
##     (señal solicitar_editor_instancia; plugin.gd devuelve los datos con
##     recibir_datos_pokemon()).
##   - Progreso: medallas, ceniza, dinero, repelente, revanchas y desbloqueos.
## Todas las pestañas editan el mismo Dictionary en memoria; Guardar lo escribe.

signal cierre_confirmado
signal solicitar_editor_instancia(datos: Dictionary)

const RUTA_PARTIDA := "res://partida/partida_guardada.json"
const RUTA_DB := "res://BaseDatos/poke.db"
const PanelProgreso := preload("res://addons/tilemap_inspector/panel_progreso_partida.gd")
const PanelPokemon := preload("res://addons/tilemap_inspector/panel_pokemon_partida.gd")

var _partida: Dictionary = {}
var _bolsillos: Array[Dictionary] = []
var _catalogo: Dictionary = {} # id de bolsillo (0-based) -> Array[Dictionary]
var _modificado := false
var _fecha_archivo: int = 0
var _hash_archivo := ""
var _seleccionado := ""
var _accion_pendiente: Callable

var _selector_bolsillo: OptionButton
var _lista_mochila: ItemList
var _lista_catalogo: ItemList
var _filtro: LineEdit
var _cantidad: SpinBox
var _estado: Label
var _confirmacion: ConfirmationDialog
var _pestanas: TabContainer
var _panel_pokemon: PanelPokemon
var _panel_progreso: PanelProgreso


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margen.add_theme_constant_override("margin_left", 16)
	margen.add_theme_constant_override("margin_right", 16)
	margen.add_theme_constant_override("margin_top", 12)
	margen.add_theme_constant_override("margin_bottom", 12)
	add_child(margen)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 10)
	margen.add_child(columna)
	columna.add_child(_etiqueta("Partida partida/partida_guardada.json  ·  Los cambios se aplican al pulsar Guardar."))
	_pestanas = TabContainer.new()
	_pestanas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columna.add_child(_pestanas)
	var mochila := VBoxContainer.new()
	mochila.name = "Mochila"
	mochila.add_theme_constant_override("separation", 10)
	_pestanas.add_child(mochila)
	var fila_bolsillo := HBoxContainer.new()
	mochila.add_child(fila_bolsillo)
	fila_bolsillo.add_child(_etiqueta("Bolsillo:"))
	_selector_bolsillo = OptionButton.new()
	_selector_bolsillo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila_bolsillo.add_child(_selector_bolsillo)
	_selector_bolsillo.item_selected.connect(func(_indice: int): _cambiar_bolsillo())

	var paneles := HSplitContainer.new()
	paneles.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mochila.add_child(paneles)
	var izquierda := VBoxContainer.new()
	izquierda.custom_minimum_size.x = 300
	paneles.add_child(izquierda)
	izquierda.add_child(_etiqueta("En la mochila (selecciona para editar o quitar)"))
	_lista_mochila = ItemList.new()
	_lista_mochila.size_flags_vertical = Control.SIZE_EXPAND_FILL
	izquierda.add_child(_lista_mochila)
	_lista_mochila.item_selected.connect(_seleccionar_de_mochila)

	var derecha := VBoxContainer.new()
	derecha.custom_minimum_size.x = 300
	paneles.add_child(derecha)
	derecha.add_child(_etiqueta("Objetos disponibles en la base de datos"))
	_filtro = LineEdit.new()
	_filtro.placeholder_text = "Buscar por nombre o identificador"
	derecha.add_child(_filtro)
	_filtro.text_changed.connect(func(_texto: String): _mostrar_catalogo())
	_lista_catalogo = ItemList.new()
	_lista_catalogo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	derecha.add_child(_lista_catalogo)
	_lista_catalogo.item_selected.connect(_seleccionar_del_catalogo)

	var fila_edicion := HBoxContainer.new()
	mochila.add_child(fila_edicion)
	fila_edicion.add_child(_etiqueta("Cantidad:"))
	_cantidad = SpinBox.new()
	_cantidad.min_value = 1
	_cantidad.max_value = 99
	_cantidad.value = 1
	fila_edicion.add_child(_cantidad)
	fila_edicion.add_child(_boton("Agregar", _agregar, "Suma la cantidad indicada al objeto seleccionado"))
	fila_edicion.add_child(_boton("Establecer", _establecer, "Fija la cantidad indicada"))
	fila_edicion.add_child(_boton("Quitar", _quitar, "Quita el objeto seleccionado por completo"))

	var fila_masiva := HBoxContainer.new()
	mochila.add_child(fila_masiva)
	fila_masiva.add_child(_boton("Vaciar bolsillo", func(): _pedir_confirmacion("¿Vaciar el bolsillo seleccionado?", _vaciar_bolsillo)))
	fila_masiva.add_child(_boton("Vaciar mochila", func(): _pedir_confirmacion("¿Vaciar TODOS los bolsillos de la mochila?", _vaciar_mochila)))
	fila_masiva.add_spacer(false)
	fila_masiva.add_child(_boton("Llenar bolsillo", func(): _pedir_confirmacion("¿Añadir todos los objetos de este bolsillo con su cantidad máxima?", _llenar_bolsillo)))
	fila_masiva.add_child(_boton("Llenar mochila", func(): _pedir_confirmacion("¿Llenar TODOS los bolsillos activos con sus objetos?", _llenar_mochila)))

	_panel_pokemon = PanelPokemon.new()
	_pestanas.add_child(_panel_pokemon)
	_panel_pokemon.modificado.connect(func(mensaje: String):
		_modificado = true
		_estado.text = mensaje
	)
	_panel_pokemon.estado_cambiado.connect(func(mensaje: String): _estado.text = mensaje)
	_panel_pokemon.solicitar_editor_instancia.connect(func(datos: Dictionary): solicitar_editor_instancia.emit(datos))

	_panel_progreso = PanelProgreso.new()
	_pestanas.add_child(_panel_progreso)
	_panel_progreso.modificado.connect(func(mensaje: String):
		_modificado = true
		_estado.text = mensaje
	)

	var pie := HBoxContainer.new()
	columna.add_child(pie)
	_estado = _etiqueta("")
	_estado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pie.add_child(_estado)
	pie.add_child(_boton("Releer", _releer))
	pie.add_child(_boton("Guardar", _guardar))
	pie.add_child(_boton("Cerrar", solicitar_cierre))

	_confirmacion = ConfirmationDialog.new()
	add_child(_confirmacion)
	_confirmacion.confirmed.connect(func():
		if _accion_pendiente.is_valid():
			_accion_pendiente.call()
	)


func _etiqueta(texto: String) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	return etiqueta


func _boton(texto: String, accion: Callable, ayuda: String = "") -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.tooltip_text = ayuda
	boton.pressed.connect(accion)
	return boton


## Recibe los datos del Editor de Instancia de Pokémon (botón "Seleccionar")
## y los escribe en el hueco elegido de la pestaña Pokémon.
func recibir_datos_pokemon(datos: Dictionary) -> void:
	_pestanas.current_tab = _panel_pokemon.get_index()
	_panel_pokemon.recibir_datos_pokemon(datos)


func abrir() -> void:
	if _modificado:
		_estado.text = "Hay cambios sin guardar. Guarda o pulsa Releer para descartarlos."
		return
	_cargar_catalogo()
	_panel_pokemon.cargar_catalogo()
	_cargar_partida()


func _cargar_catalogo() -> void:
	_bolsillos.clear()
	_catalogo.clear()
	var db := SQLite.new()
	db.path = RUTA_DB
	# Sin read_only: ese modo usa el VFS de godot-sqlite sobre FileAccess, que en
	# el editor (Windows) abre con _SH_DENYWR y falla si otra herramienta tiene
	# la BD abierta para escribir. La conexión nativa sí admite varias a la vez.
	if not db.open_db():
		_estado.text = "No se pudo abrir la base de datos de objetos."
		return
	if not db.query("SELECT id, nombre, cifras FROM Bolsillos WHERE activo = 1 ORDER BY id"):
		_estado.text = "No se pudieron leer los bolsillos de la base de datos."
		db.close_db()
		return
	for fila in db.query_result:
		var bolsillo: Dictionary = fila.duplicate()
		_bolsillos.append(bolsillo)
		_catalogo[int(bolsillo["id"]) - 1] = []
	if not db.query("SELECT o.nombre_interno, o.nombre, o.bolsillo_id FROM Objetos o JOIN Bolsillos b ON b.id = o.bolsillo_id WHERE b.activo = 1 ORDER BY o.nombre"):
		_estado.text = "No se pudieron leer los objetos de la base de datos."
		_bolsillos.clear()
		_catalogo.clear()
		db.close_db()
		return
	for fila in db.query_result:
		var id_bolsillo := int(fila["bolsillo_id"]) - 1
		if _catalogo.has(id_bolsillo):
			_catalogo[id_bolsillo].append(fila.duplicate())
	db.close_db()
	_selector_bolsillo.clear()
	for bolsillo in _bolsillos:
		_selector_bolsillo.add_item(str(bolsillo["nombre"]), int(bolsillo["id"]) - 1)
	if _bolsillos.is_empty():
		_estado.text = "No hay bolsillos activos en la base de datos."
	else:
		_cambiar_bolsillo()


## Lee el archivo y muestra la partida en todas las pestañas. El panel de
## Pokémon guarda la referencia al Dictionary, por eso se le vuelve a pasar
## después de cada lectura.
func _cargar_partida() -> void:
	_leer_archivo_partida()
	_panel_pokemon.mostrar(_partida)
	_panel_progreso.mostrar(_partida)


func _leer_archivo_partida() -> void:
	_partida.clear()
	if not FileAccess.file_exists(RUTA_PARTIDA):
		_estado.text = "No existe %s. No se ha creado ninguna partida." % RUTA_PARTIDA
		_mostrar_mochila()
		return
	var archivo := FileAccess.open(RUTA_PARTIDA, FileAccess.READ)
	if archivo == null:
		_estado.text = "No se pudo leer la partida: %s" % error_string(FileAccess.get_open_error())
		return
	var json := JSON.new()
	var error := json.parse(archivo.get_as_text())
	archivo.close()
	if error != OK or not json.data is Dictionary:
		_estado.text = "JSON de partida inválido; no se modificarán los datos."
		return
	var datos: Dictionary = json.data
	if not datos.get("mochila") is Dictionary or not datos["mochila"].get("bolsillos") is Dictionary:
		_estado.text = "La partida no tiene una mochila con bolsillos válidos."
		return
	_partida = datos
	_fecha_archivo = FileAccess.get_modified_time(RUTA_PARTIDA)
	_hash_archivo = FileAccess.get_sha256(RUTA_PARTIDA)
	_modificado = false
	_seleccionado = ""
	_mostrar_mochila()
	_estado.text = "Partida leída. Selecciona una pestaña para editar la partida." if not _bolsillos.is_empty() else "Partida leída, pero no se pudo cargar el catálogo de bolsillos y objetos."


func _id_bolsillo() -> int:
	if _selector_bolsillo.selected < 0:
		return -1
	return _selector_bolsillo.get_selected_id()


func _maximo() -> int:
	for bolsillo in _bolsillos:
		if int(bolsillo["id"]) - 1 == _id_bolsillo():
			var cifras := int(bolsillo.get("cifras", 0))
			if cifras <= 0:
				return 1
			return int(pow(10, min(cifras, 6))) - 1
	return 1


func _cambiar_bolsillo() -> void:
	_seleccionado = ""
	_cantidad.max_value = _maximo()
	_cantidad.value = 1
	_mostrar_mochila()
	_mostrar_catalogo()


func _items_bolsillo(crear: bool = false) -> Array:
	if _partida.is_empty() or _id_bolsillo() < 0:
		return []
	var bolsillos: Dictionary = _partida["mochila"]["bolsillos"]
	var clave := str(_id_bolsillo())
	if not bolsillos.has(clave):
		if not crear:
			return []
		bolsillos[clave] = {"items": []}
	if not bolsillos[clave] is Dictionary or not bolsillos[clave].get("items") is Array:
		_estado.text = "Estructura inválida en el bolsillo %s." % clave
		return []
	return bolsillos[clave]["items"]


func _mostrar_mochila() -> void:
	if _lista_mochila == null:
		return
	_lista_mochila.clear()
	for item in _items_bolsillo():
		if not item is Dictionary:
			continue
		var interno := str(item.get("nombre_interno", ""))
		var nombre := interno
		for objeto in _catalogo.get(_id_bolsillo(), []):
			if str(objeto["nombre_interno"]) == interno:
				nombre = str(objeto["nombre"])
				break
		var indice := _lista_mochila.item_count
		_lista_mochila.add_item("%s (%s)  × %s" % [nombre, interno, str(item.get("cantidad", 0))])
		_lista_mochila.set_item_metadata(indice, interno)
		if interno == _seleccionado:
			_lista_mochila.select(indice)


func _mostrar_catalogo() -> void:
	if _lista_catalogo == null:
		return
	_lista_catalogo.clear()
	var filtro := _filtro.text.strip_edges().to_lower()
	for objeto in _catalogo.get(_id_bolsillo(), []):
		var interno := str(objeto["nombre_interno"])
		var nombre := str(objeto["nombre"])
		if not filtro.is_empty() and not (filtro in interno.to_lower() or filtro in nombre.to_lower()):
			continue
		var indice := _lista_catalogo.item_count
		_lista_catalogo.add_item("%s  —  %s" % [nombre, interno])
		_lista_catalogo.set_item_metadata(indice, interno)
		if interno == _seleccionado:
			_lista_catalogo.select(indice)


func _seleccionar_de_mochila(indice: int) -> void:
	_seleccionado = str(_lista_mochila.get_item_metadata(indice))
	for item in _items_bolsillo():
		if item is Dictionary and str(item.get("nombre_interno", "")) == _seleccionado:
			_cantidad.value = clampi(int(item.get("cantidad", 1)), 1, _maximo())
			break
	_mostrar_catalogo()


func _seleccionar_del_catalogo(indice: int) -> void:
	_seleccionado = str(_lista_catalogo.get_item_metadata(indice))
	_cantidad.value = 1
	for item in _items_bolsillo():
		if item is Dictionary and str(item.get("nombre_interno", "")) == _seleccionado:
			_cantidad.value = clampi(int(item.get("cantidad", 1)), 1, _maximo())
			break
	_mostrar_mochila()


func _editar_cantidad(modo: String) -> void:
	if _partida.is_empty() or _seleccionado.is_empty():
		_estado.text = "Selecciona un objeto y comprueba que haya una partida válida."
		return
	var existe_en_catalogo := false
	for objeto in _catalogo.get(_id_bolsillo(), []):
		if str(objeto["nombre_interno"]) == _seleccionado:
			existe_en_catalogo = true
			break
	if modo != "quitar" and not existe_en_catalogo:
		_estado.text = "Solo se pueden añadir objetos válidos de este bolsillo."
		return
	var items := _items_bolsillo(true)
	var actual := 0
	for item in items:
		if item is Dictionary and str(item.get("nombre_interno", "")) == _seleccionado:
			actual += int(item.get("cantidad", 0))
	var nuevo := 0 if modo == "quitar" else int(_cantidad.value)
	if modo == "agregar":
		nuevo = min(actual + nuevo, _maximo())
	for i in range(items.size() - 1, -1, -1):
		if items[i] is Dictionary and str(items[i].get("nombre_interno", "")) == _seleccionado:
			items.remove_at(i)
	if nuevo > 0:
		items.append({"nombre_interno": _seleccionado, "cantidad": nuevo})
	_modificado = true
	_mostrar_mochila()
	_estado.text = "%s: %d (máximo %d). Cambios pendientes de guardar." % [_seleccionado, nuevo, _maximo()]


func _agregar() -> void:
	_editar_cantidad("agregar")


func _establecer() -> void:
	_editar_cantidad("establecer")


func _quitar() -> void:
	_editar_cantidad("quitar")


func _pedir_confirmacion(texto: String, accion: Callable) -> void:
	if _partida.is_empty() or _bolsillos.is_empty():
		_estado.text = "Primero carga una partida y la base de datos de bolsillos."
		return
	_mostrar_confirmacion(texto, accion)


## Confirmación sin exigir el catálogo de bolsillos (Releer / Cerrar también
## deben funcionar cuando solo se editaron Pokémon).
func _mostrar_confirmacion(texto: String, accion: Callable) -> void:
	_accion_pendiente = accion
	_confirmacion.dialog_text = texto
	_confirmacion.popup_centered()


func _vaciar_bolsillo() -> void:
	var clave := str(_id_bolsillo())
	var bolsillos: Dictionary = _partida["mochila"]["bolsillos"]
	if bolsillos.has(clave) and bolsillos[clave] is Dictionary:
		bolsillos[clave]["items"] = []
	_modificado = true
	_seleccionado = ""
	_mostrar_mochila()
	_estado.text = "Bolsillo vacío. Cambios pendientes de guardar."


func _vaciar_mochila() -> void:
	for bolsillo in _partida["mochila"]["bolsillos"].values():
		if bolsillo is Dictionary and bolsillo.get("items") is Array:
			bolsillo["items"] = []
	_modificado = true
	_seleccionado = ""
	_mostrar_mochila()
	_estado.text = "Mochila vacía. Cambios pendientes de guardar."


func _llenar_bolsillo() -> void:
	_llenar_ids([_id_bolsillo()])


func _llenar_mochila() -> void:
	var ids: Array = []
	for bolsillo in _bolsillos:
		ids.append(int(bolsillo["id"]) - 1)
	_llenar_ids(ids)


func _llenar_ids(ids: Array) -> void:
	var bolsillos: Dictionary = _partida["mochila"]["bolsillos"]
	# Validar todos los destinos antes de tocar ninguno.
	for id in ids:
		var clave := str(id)
		if bolsillos.has(clave) and (not bolsillos[clave] is Dictionary or not bolsillos[clave].get("items") is Array):
			_estado.text = "No se puede llenar: bolsillo %s inválido." % clave
			return
	for id in ids:
		var clave := str(id)
		if not bolsillos.has(clave):
			bolsillos[clave] = {"items": []}
		var maximo := 1
		for bolsillo in _bolsillos:
			if int(bolsillo["id"]) - 1 == id:
				var cifras := int(bolsillo.get("cifras", 0))
				maximo = int(pow(10, min(cifras, 6))) - 1 if cifras > 0 else 1
				break
		var items: Array = bolsillos[clave]["items"]
		for objeto in _catalogo.get(id, []):
			var interno := str(objeto["nombre_interno"])
			# Una sola entrada por objeto, incluso si el guardado ya tenía duplicados.
			for i in range(items.size() - 1, -1, -1):
				if items[i] is Dictionary and str(items[i].get("nombre_interno", "")) == interno:
					items.remove_at(i)
			items.append({"nombre_interno": interno, "cantidad": maximo})
	_modificado = true
	_mostrar_mochila()
	_estado.text = "Objetos añadidos hasta el máximo de cada bolsillo. Cambios pendientes de guardar."


func _guardar() -> void:
	if _partida.is_empty() or not _modificado:
		_estado.text = "No hay cambios que guardar."
		return
	if not FileAccess.file_exists(RUTA_PARTIDA) or FileAccess.get_modified_time(RUTA_PARTIDA) != _fecha_archivo or FileAccess.get_sha256(RUTA_PARTIDA) != _hash_archivo:
		_estado.text = "La partida cambió fuera de esta ventana. Relee antes de guardar (perderás tus cambios)."
		return
	var archivo := FileAccess.open(RUTA_PARTIDA, FileAccess.WRITE)
	if archivo == null:
		_estado.text = "No se pudo guardar: %s" % error_string(FileAccess.get_open_error())
		return
	archivo.store_string(JSON.stringify(_partida, "\t"))
	var error := archivo.get_error()
	archivo.close()
	if error != OK:
		_estado.text = "Error al escribir la partida: %s" % error_string(error)
		return
	_fecha_archivo = FileAccess.get_modified_time(RUTA_PARTIDA)
	_hash_archivo = FileAccess.get_sha256(RUTA_PARTIDA)
	_modificado = false
	_estado.text = "Partida guardada en %s." % RUTA_PARTIDA


func _releer() -> void:
	if _modificado:
		_mostrar_confirmacion("¿Descartar los cambios sin guardar y volver a leer el archivo?", _descartar_y_releer)
	else:
		_cargar_catalogo()
		_panel_pokemon.cargar_catalogo()
		_cargar_partida()


func _descartar_y_releer() -> void:
	_modificado = false
	_releer()


func solicitar_cierre() -> void:
	if _modificado:
		_mostrar_confirmacion("¿Cerrar sin guardar los cambios de la partida?", _cerrar_sin_guardar)
	else:
		cierre_confirmado.emit()


func _cerrar_sin_guardar() -> void:
	_modificado = false
	cierre_confirmado.emit()

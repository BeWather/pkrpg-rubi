@tool
extends VBoxContainer
## Pestaña "Pokémon" de Debug Partida Guardada: inspecciona y edita el equipo
## (`equipo_pokemon`) y las cajas del PC (`cajas_pc`) del guardado local.
##
## Trabaja EN EL SITIO sobre el mismo Dictionary de partida que guarda la
## ventana principal (ver mostrar()); cada cambio emite `modificado` y la
## ventana decide cuándo escribir el archivo.
##
## - Rejilla de iconos: 6 huecos de equipo + 30 de la caja elegida.
## - Arrastrar y soltar entre huecos intercambia su contenido. El equipo es
##   compacto (sin nulls) y nunca puede quedar vacío. Durante un arrastre, dejar
##   el ratón sobre ◀ / ▶ cambia de caja.
## - Editar/Crear abre el Editor de Instancia de Pokémon (señal
##   solicitar_editor_instancia); su botón "Seleccionar" devuelve los datos
##   por recibir_datos_pokemon(), que los escribe en el hueco de destino.

signal modificado(mensaje: String)
signal estado_cambiado(mensaje: String)
signal solicitar_editor_instancia(datos: Dictionary)

const Conversor := preload("res://addons/tilemap_inspector/conversor_pokemon_partida.gd")
const SINGLETON_DATA := preload("res://scripts/singleton.gd")
const MAX_EQUIPO := 6 # EstructuraGuardado / SistemaGuardado.MAX_POKEMON_EQUIPO
const TOTAL_CAJAS := 14 # TOTAL_CAJAS_PC
const SLOTS_CAJA := 30 # SLOTS_POR_CAJA_PC
const COLUMNAS_CAJA := 6
const TAMANO_SLOT := Vector2(64, 64)
const TIPO_ARRASTRE := "pokemon_partida"
const ZONA_EQUIPO := "equipo"
const ZONA_CAJA := "caja"
const ESPERA_CAMBIO_CAJA := 0.6

var conversor := Conversor.new()

var _partida: Dictionary = {}
var _caja_actual := 0
## Ubicación: {"zona": "equipo"|"caja", "caja": int, "indice": int}.
var _seleccion: Dictionary = {}
## Hueco al que irán los datos del editor (se fija al pulsar Editar/Crear).
var _destino: Dictionary = {}
var _accion_pendiente: Callable

var _grupo := ButtonGroup.new()
var _botones_equipo: Array[Button] = []
var _botones_caja: Array[Button] = []
var _selector_caja: OptionButton
var _flecha_anterior: Button
var _flecha_siguiente: Button
var _temporizador_caja: Timer
var _flecha_en_espera: Button
var _titulo: Label
var _detalle: RichTextLabel
var _boton_editar: Button
var _boton_quitar: Button
var _boton_curar: Button
var _boton_curar_equipo: Button
var _confirmacion: ConfirmationDialog


func _init() -> void:
	name = "Pokémon"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var paneles := HSplitContainer.new()
	paneles.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(paneles)

	var izquierda := VBoxContainer.new()
	izquierda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	izquierda.add_theme_constant_override("separation", 8)
	paneles.add_child(izquierda)
	izquierda.add_child(_etiqueta("Equipo  (arrastra para mover o intercambiar; doble clic para editar)"))
	var fila_equipo := HBoxContainer.new()
	izquierda.add_child(fila_equipo)
	for i in range(MAX_EQUIPO):
		var boton := _crear_slot(ZONA_EQUIPO, i)
		fila_equipo.add_child(boton)
		_botones_equipo.append(boton)

	var fila_caja := HBoxContainer.new()
	izquierda.add_child(fila_caja)
	fila_caja.add_child(_etiqueta("Caja:"))
	_flecha_anterior = _boton("◀", func(): _cambiar_caja(_caja_actual - 1), "Caja anterior (durante un arrastre, deja el ratón encima)")
	fila_caja.add_child(_flecha_anterior)
	_selector_caja = OptionButton.new()
	_selector_caja.custom_minimum_size.x = 160
	for c in range(TOTAL_CAJAS):
		_selector_caja.add_item("Caja %d" % (c + 1), c)
	fila_caja.add_child(_selector_caja)
	_selector_caja.item_selected.connect(func(indice: int): _cambiar_caja(indice))
	_flecha_siguiente = _boton("▶", func(): _cambiar_caja(_caja_actual + 1), "Caja siguiente (durante un arrastre, deja el ratón encima)")
	fila_caja.add_child(_flecha_siguiente)
	for flecha in [_flecha_anterior, _flecha_siguiente]:
		flecha.set_drag_forwarding(Callable(), _puede_soltar_en_flecha.bind(flecha), Callable())
	_temporizador_caja = Timer.new()
	_temporizador_caja.wait_time = ESPERA_CAMBIO_CAJA
	_temporizador_caja.timeout.connect(_al_temporizador_caja)
	add_child(_temporizador_caja)

	var rejilla := GridContainer.new()
	rejilla.columns = COLUMNAS_CAJA
	izquierda.add_child(rejilla)
	for i in range(SLOTS_CAJA):
		var boton := _crear_slot(ZONA_CAJA, i)
		rejilla.add_child(boton)
		_botones_caja.append(boton)

	var derecha := VBoxContainer.new()
	derecha.custom_minimum_size.x = 340
	derecha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paneles.add_child(derecha)
	_titulo = _etiqueta("Sin selección")
	_titulo.add_theme_font_size_override("font_size", 18)
	derecha.add_child(_titulo)
	_detalle = RichTextLabel.new()
	_detalle.bbcode_enabled = true
	_detalle.selection_enabled = true
	_detalle.context_menu_enabled = true
	_detalle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	derecha.add_child(_detalle)
	var acciones := HBoxContainer.new()
	derecha.add_child(acciones)
	_boton_editar = _boton("Editar…", _editar, "Abre el Pokémon en el Editor de Instancia; su botón \"Seleccionar\" lo devuelve aquí")
	acciones.add_child(_boton_editar)
	_boton_quitar = _boton("Quitar", _pedir_quitar, "Vacía el hueco seleccionado")
	acciones.add_child(_boton_quitar)
	_boton_curar = _boton("Curar", _curar_seleccion, "PS al máximo, sin problema de estado y PP completos")
	acciones.add_child(_boton_curar)
	acciones.add_spacer(false)
	_boton_curar_equipo = _boton("Curar equipo", _curar_equipo, "Cura a todo el equipo")
	acciones.add_child(_boton_curar_equipo)

	_confirmacion = ConfirmationDialog.new()
	add_child(_confirmacion)
	_confirmacion.confirmed.connect(func():
		if _accion_pendiente.is_valid():
			_accion_pendiente.call()
	)
	_refrescar()


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


func _crear_slot(zona: String, indice: int) -> Button:
	var boton := Button.new()
	boton.toggle_mode = true
	boton.button_group = _grupo
	boton.custom_minimum_size = TAMANO_SLOT
	boton.expand_icon = true
	boton.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boton.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	boton.clip_text = true
	boton.add_theme_font_size_override("font_size", 11)
	boton.set_meta("zona", zona)
	boton.set_meta("indice", indice)
	boton.pressed.connect(func(): _seleccionar(_ubicacion_de(boton)))
	boton.gui_input.connect(func(evento: InputEvent):
		if evento is InputEventMouseButton and evento.double_click and evento.button_index == MOUSE_BUTTON_LEFT:
			_seleccionar(_ubicacion_de(boton))
			_editar()
	)
	boton.set_drag_forwarding(_datos_arrastre.bind(boton), _puede_soltar.bind(boton), _soltar.bind(boton))
	return boton


# =====================================================================
# API pública
# =====================================================================

## Carga los catálogos de poke.db (especies, movimientos, ...).
func cargar_catalogo() -> bool:
	var ok := conversor.cargar()
	if not ok:
		estado_cambiado.emit(conversor.error)
	_refrescar()
	return ok


## Muestra la partida indicada. Guarda la REFERENCIA: las ediciones se hacen
## sobre ese mismo Dictionary.
func mostrar(partida: Dictionary) -> void:
	_partida = partida
	_destino = {}
	if _seleccion.is_empty() or _obtener(_seleccion) == null:
		_seleccion = _ubicacion(ZONA_EQUIPO, 0)
	_refrescar()


## Recibe los datos del Editor de Instancia (botón "Seleccionar") y los
## escribe en el hueco de destino (o en el seleccionado).
func recibir_datos_pokemon(datos: Dictionary) -> void:
	var problema := _problema_estructura()
	if problema != "":
		estado_cambiado.emit(problema)
		return
	var ubicacion := _destino if not _destino.is_empty() else _seleccion
	if ubicacion.is_empty():
		estado_cambiado.emit("Selecciona un hueco antes de enviar un Pokémon desde el editor.")
		return
	var actual: Variant = _obtener(ubicacion)
	var nuevo := conversor.a_partida(datos, actual if actual is Dictionary else {})
	if nuevo.is_empty():
		estado_cambiado.emit("No se pudo aplicar el Pokémon del editor: %s" % conversor.error)
		return
	ubicacion = ubicacion.duplicate()
	if ubicacion["zona"] == ZONA_EQUIPO and actual == null:
		var equipo: Array = _equipo()
		if equipo.size() >= MAX_EQUIPO:
			estado_cambiado.emit("El equipo ya tiene %d Pokémon." % MAX_EQUIPO)
			return
		equipo.append(nuevo)
		ubicacion["indice"] = equipo.size() - 1
	else:
		_poner(ubicacion, nuevo)
	_destino = ubicacion
	_seleccion = ubicacion
	_mostrar_caja_de(ubicacion)
	modificado.emit("%s escrito en %s. Cambios pendientes de guardar." % [conversor.nombre_especie(nuevo), _texto_ubicacion(ubicacion)])
	_refrescar()


# =====================================================================
# Acceso a la estructura del guardado
# =====================================================================

func _ubicacion(zona: String, indice: int, caja: int = -1) -> Dictionary:
	return {"zona": zona, "caja": caja if zona == ZONA_CAJA else -1, "indice": indice}


func _ubicacion_de(boton: Button) -> Dictionary:
	var zona := str(boton.get_meta("zona"))
	return _ubicacion(zona, int(boton.get_meta("indice")), _caja_actual)


func _texto_ubicacion(ubicacion: Dictionary) -> String:
	if ubicacion.is_empty():
		return "Sin selección"
	if ubicacion["zona"] == ZONA_EQUIPO:
		return "Equipo · %d" % (int(ubicacion["indice"]) + 1)
	return "Caja %d · %d" % [int(ubicacion["caja"]) + 1, int(ubicacion["indice"]) + 1]


## Mensaje de error si la partida no tiene una estructura editable ("" si es válida).
func _problema_estructura() -> String:
	if _partida.is_empty():
		return "No hay una partida válida cargada."
	if _partida.has("equipo_pokemon") and not _partida["equipo_pokemon"] is Array:
		return "equipo_pokemon no es una lista; no se modificará."
	for poke: Variant in _partida.get("equipo_pokemon", []):
		if not poke is Dictionary:
			return "equipo_pokemon contiene entradas que no son Pokémon; no se modificará."
	if _partida.has("cajas_pc"):
		if not _partida["cajas_pc"] is Array:
			return "cajas_pc no es una lista; no se modificará."
		for caja: Variant in _partida["cajas_pc"]:
			if not caja is Array:
				return "cajas_pc contiene cajas que no son listas; no se modificará."
	return ""


func _equipo() -> Array:
	if not _partida.get("equipo_pokemon") is Array:
		_partida["equipo_pokemon"] = []
	return _partida["equipo_pokemon"]


## Contenido de un hueco (Dictionary o null). No crea nada.
func _obtener(ubicacion: Dictionary) -> Variant:
	if ubicacion.is_empty() or _problema_estructura() != "":
		return null
	var indice := int(ubicacion["indice"])
	if ubicacion["zona"] == ZONA_EQUIPO:
		var equipo: Array = _partida.get("equipo_pokemon", [])
		return equipo[indice] if indice < equipo.size() else null
	var cajas: Array = _partida.get("cajas_pc", [])
	var c := int(ubicacion["caja"])
	if c < 0 or c >= cajas.size() or indice >= cajas[c].size():
		return null
	var valor: Variant = cajas[c][indice]
	return valor if valor is Dictionary else null


## Crea las cajas que falten (14 × 30 null) y rellena las cortas con null.
func _asegurar_cajas() -> Array:
	if not _partida.get("cajas_pc") is Array:
		_partida["cajas_pc"] = []
	var cajas: Array = _partida["cajas_pc"]
	while cajas.size() < TOTAL_CAJAS:
		cajas.append([])
	for caja: Array in cajas:
		while caja.size() < SLOTS_CAJA:
			caja.append(null)
	return cajas


## Escribe en un hueco. En el equipo, null quita al Pokémon (el equipo es
## compacto) y un índice fuera de rango lo añade al final.
func _poner(ubicacion: Dictionary, valor: Variant) -> void:
	var indice := int(ubicacion["indice"])
	if ubicacion["zona"] == ZONA_EQUIPO:
		var equipo := _equipo()
		if valor == null:
			if indice < equipo.size():
				equipo.remove_at(indice)
		elif indice < equipo.size():
			equipo[indice] = valor
		else:
			equipo.append(valor)
		return
	var cajas := _asegurar_cajas()
	cajas[int(ubicacion["caja"])][indice] = valor


func _ocupados_caja(c: int) -> int:
	var cajas: Variant = _partida.get("cajas_pc", [])
	if not cajas is Array or c >= cajas.size() or not cajas[c] is Array:
		return 0
	var total := 0
	for valor: Variant in cajas[c]:
		if valor is Dictionary:
			total += 1
	return total


# =====================================================================
# Movimientos entre huecos
# =====================================================================

## Mueve (o intercambia) el contenido de [param origen] a [param destino].
## Devuelve la ubicación final del Pokémon movido ({} si no se movió).
func mover(origen: Dictionary, destino: Dictionary) -> Dictionary:
	var problema := _problema_estructura()
	if problema != "":
		estado_cambiado.emit(problema)
		return {}
	if _misma_ubicacion(origen, destino):
		return {}
	var movido: Variant = _obtener(origen)
	if movido == null:
		return {}
	var otro: Variant = _obtener(destino)
	var equipo := _equipo()
	var final := destino.duplicate()
	var origen_equipo: bool = origen["zona"] == ZONA_EQUIPO
	var destino_equipo: bool = destino["zona"] == ZONA_EQUIPO
	if origen_equipo and destino_equipo:
		if otro == null:
			# Hueco vacío del equipo: pasa al final (el equipo es compacto).
			equipo.remove_at(int(origen["indice"]))
			equipo.append(movido)
			final["indice"] = equipo.size() - 1
		else:
			equipo[int(origen["indice"])] = otro
			equipo[int(destino["indice"])] = movido
	elif origen_equipo:
		if otro == null:
			if equipo.size() <= 1:
				estado_cambiado.emit("El equipo no puede quedar vacío.")
				return {}
			_poner(destino, movido)
			equipo.remove_at(int(origen["indice"]))
		else:
			equipo[int(origen["indice"])] = otro
			_poner(destino, movido)
	elif destino_equipo:
		if otro == null:
			if equipo.size() >= MAX_EQUIPO:
				estado_cambiado.emit("El equipo ya tiene %d Pokémon." % MAX_EQUIPO)
				return {}
			_poner(origen, null)
			equipo.append(movido)
			final["indice"] = equipo.size() - 1
		else:
			_poner(origen, otro)
			equipo[int(destino["indice"])] = movido
	else:
		_poner(origen, otro)
		_poner(destino, movido)
	# Las posiciones cambiaron: el destino del editor pasa a ser la selección.
	_destino = {}
	_seleccion = final
	_mostrar_caja_de(final)
	var verbo := "intercambiado con %s" % conversor.nombre_especie(otro) if otro is Dictionary else "movido"
	modificado.emit("%s %s → %s. Cambios pendientes de guardar." % [conversor.nombre_especie(movido), verbo, _texto_ubicacion(final)])
	_refrescar()
	return final


## Quita el Pokémon del hueco. Devuelve false si no se pudo.
func quitar(ubicacion: Dictionary) -> bool:
	var problema := _problema_estructura()
	if problema != "":
		estado_cambiado.emit(problema)
		return false
	var poke: Variant = _obtener(ubicacion)
	if poke == null:
		return false
	if ubicacion["zona"] == ZONA_EQUIPO and _equipo().size() <= 1:
		estado_cambiado.emit("El equipo no puede quedar vacío.")
		return false
	_poner(ubicacion, null)
	_destino = {}
	modificado.emit("%s quitado de %s. Cambios pendientes de guardar." % [conversor.nombre_especie(poke), _texto_ubicacion(ubicacion)])
	_refrescar()
	return true


func _misma_ubicacion(a: Dictionary, b: Dictionary) -> bool:
	return a["zona"] == b["zona"] and int(a["indice"]) == int(b["indice"]) and int(a["caja"]) == int(b["caja"])


func _mostrar_caja_de(ubicacion: Dictionary) -> void:
	if ubicacion.get("zona") == ZONA_CAJA:
		_caja_actual = int(ubicacion["caja"])


# =====================================================================
# Arrastrar y soltar
# =====================================================================

func _datos_arrastre(_posicion: Vector2, boton: Button) -> Variant:
	var ubicacion := _ubicacion_de(boton)
	var poke: Variant = _obtener(ubicacion)
	if poke == null:
		return null
	var raiz := Control.new()
	var vista := TextureRect.new()
	vista.texture = conversor.icono(poke)
	vista.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vista.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vista.size = Vector2(48, 48)
	vista.position = Vector2(-24, -24)
	raiz.add_child(vista)
	boton.set_drag_preview(raiz)
	return {"tipo": TIPO_ARRASTRE, "origen": ubicacion}


func _puede_soltar(_posicion: Vector2, datos: Variant, _boton: Button) -> bool:
	return datos is Dictionary and datos.get("tipo") == TIPO_ARRASTRE


func _soltar(_posicion: Vector2, datos: Variant, boton: Button) -> void:
	if not _puede_soltar(_posicion, datos, boton):
		return
	mover(datos["origen"], _ubicacion_de(boton))


## Las flechas no aceptan el Pokémon, pero mantener el arrastre encima cambia de caja.
func _puede_soltar_en_flecha(_posicion: Vector2, datos: Variant, flecha: Button) -> bool:
	if datos is Dictionary and datos.get("tipo") == TIPO_ARRASTRE and _flecha_en_espera != flecha:
		_flecha_en_espera = flecha
		_temporizador_caja.start()
	return false


func _al_temporizador_caja() -> void:
	var flecha := _flecha_en_espera
	var sigue_encima := is_instance_valid(flecha) and flecha.get_global_rect().has_point(flecha.get_global_mouse_position())
	if not sigue_encima or not get_viewport().gui_is_dragging():
		_flecha_en_espera = null
		_temporizador_caja.stop()
		return
	_cambiar_caja(_caja_actual + (1 if flecha == _flecha_siguiente else -1))


# =====================================================================
# Acciones
# =====================================================================

func _seleccionar(ubicacion: Dictionary) -> void:
	_seleccion = ubicacion
	_refrescar()


func _cambiar_caja(indice: int) -> void:
	_caja_actual = posmod(indice, TOTAL_CAJAS)
	_refrescar()


func _editar() -> void:
	var problema := _problema_estructura()
	if problema != "":
		estado_cambiado.emit(problema)
		return
	if _seleccion.is_empty():
		estado_cambiado.emit("Selecciona un hueco.")
		return
	var poke: Variant = _obtener(_seleccion)
	if poke == null and _seleccion["zona"] == ZONA_EQUIPO and _equipo().size() >= MAX_EQUIPO:
		estado_cambiado.emit("El equipo ya tiene %d Pokémon." % MAX_EQUIPO)
		return
	var datos := conversor.a_formulario(poke) if poke is Dictionary else {}
	if poke is Dictionary and conversor.error != "":
		estado_cambiado.emit(conversor.error)
		return
	_destino = _seleccion.duplicate()
	solicitar_editor_instancia.emit(datos)
	estado_cambiado.emit("Editor abierto para %s: pulsa \"Seleccionar\" en el editor para escribirlo aquí." % _texto_ubicacion(_destino))


func _pedir_quitar() -> void:
	var poke: Variant = _obtener(_seleccion)
	if poke == null:
		estado_cambiado.emit("El hueco seleccionado está vacío.")
		return
	if _seleccion["zona"] == ZONA_EQUIPO and _equipo().size() <= 1:
		estado_cambiado.emit("El equipo no puede quedar vacío.")
		return
	var ubicacion := _seleccion.duplicate()
	_accion_pendiente = func(): quitar(ubicacion)
	_confirmacion.dialog_text = "¿Quitar a %s de %s?" % [conversor.nombre_especie(poke), _texto_ubicacion(ubicacion)]
	_confirmacion.popup_centered()


func _curar_seleccion() -> void:
	var poke: Variant = _obtener(_seleccion)
	if poke == null:
		estado_cambiado.emit("El hueco seleccionado está vacío.")
		return
	if not conversor.curar(poke):
		estado_cambiado.emit("Movimiento inválido; curación cancelada.")
		return
	modificado.emit("%s curado. Cambios pendientes de guardar." % conversor.nombre_especie(poke))
	_refrescar()


func _curar_equipo() -> void:
	var problema := _problema_estructura()
	if problema != "":
		estado_cambiado.emit(problema)
		return
	var equipo := _equipo()
	if equipo.is_empty():
		estado_cambiado.emit("El equipo está vacío.")
		return
	var staged: Array = equipo.duplicate(true)
	for poke: Dictionary in staged:
		if not conversor.curar(poke):
			estado_cambiado.emit("Movimiento inválido; curación del equipo cancelada.")
			return
	for index: int in equipo.size():
		equipo[index].merge(staged[index], true)
	modificado.emit("Equipo curado. Cambios pendientes de guardar.")
	_refrescar()


# =====================================================================
# Presentación
# =====================================================================

func _refrescar() -> void:
	if _detalle == null:
		return
	var problema := _problema_estructura()
	for c in range(TOTAL_CAJAS):
		_selector_caja.set_item_text(c, "Caja %d (%d/%d)" % [c + 1, _ocupados_caja(c) if problema == "" else 0, SLOTS_CAJA])
	_selector_caja.select(_caja_actual)
	for boton in _botones_equipo + _botones_caja:
		var ubicacion := _ubicacion_de(boton)
		_configurar_slot(boton, _obtener(ubicacion))
		boton.disabled = problema != ""
		boton.set_pressed_no_signal(not _seleccion.is_empty() and _misma_ubicacion(ubicacion, _seleccion))
	var poke: Variant = _obtener(_seleccion)
	_boton_editar.text = "Editar…" if poke != null else "Crear…"
	_boton_editar.disabled = problema != "" or _seleccion.is_empty()
	_boton_quitar.disabled = poke == null
	_boton_curar.disabled = poke == null
	_boton_curar_equipo.disabled = problema != ""
	if problema != "":
		_titulo.text = "Pokémon no disponibles"
		_detalle.text = problema
		return
	_titulo.text = _texto_ubicacion(_seleccion)
	var aviso := ""
	if not conversor.esta_cargado():
		aviso = "[color=#ff7070]Catálogo de la base de datos no cargado. %s[/color]

" % _esc(conversor.error)
	_detalle.text = aviso + (_texto_detalle(poke) if poke is Dictionary else "Hueco vacío. Pulsa \"Crear…\" (o doble clic) para crear un Pokémon aquí con el Editor de Instancia.")


func _configurar_slot(boton: Button, poke: Variant) -> void:
	if not poke is Dictionary:
		boton.icon = null
		boton.text = ""
		boton.tooltip_text = "Vacío"
		boton.modulate = Color.WHITE
		return
	boton.icon = conversor.icono(poke)
	var huevo := Conversor.a_bool(poke.get("huevo", false))
	var texto := "Huevo" if huevo else "Nv %d" % int(poke.get("nivel", 0))
	if Conversor.a_bool(poke.get("shiny", false)):
		texto = "★ " + texto
	boton.text = texto
	var debilitado := int(poke.get("estad_ps_actual", 1)) <= 0
	boton.modulate = Color(1.0, 0.55, 0.55) if debilitado else Color.WHITE
	boton.tooltip_text = _texto_tooltip(poke)


func _nombre_estado(estado: int) -> String:
	var clave: Variant = SINGLETON_DATA.ProblemaEstado.find_key(estado)
	return str(clave) if clave != null else "DESCONOCIDO (%d)" % estado


func _texto_tooltip(poke: Dictionary) -> String:
	var lineas: Array[String] = []
	var nombre := conversor.nombre_especie(poke)
	var mote := str(poke.get("mote", ""))
	lineas.append(nombre if mote == "" else "%s (%s)" % [mote, nombre])
	lineas.append("Nivel %d" % int(poke.get("nivel", 0)))
	lineas.append("PS %d/%d" % [int(poke.get("estad_ps_actual", 0)), int(poke.get("estad_ps", 0))])
	lineas.append("Estado: %s" % _nombre_estado(int(poke.get("estado", -1))))
	for entrada: Variant in poke.get("movimientos", []):
		var mov := conversor.info_movimiento(entrada)
		if not mov.is_empty():
			lineas.append("· %s  %d/%d" % [mov["nombre"], int(mov["pp_act"]), int(mov["pp_tot"])])
	return "\n".join(lineas)


func _esc(valor: Variant) -> String:
	return str(valor).replace("[", "[lb]")


func _texto_detalle(poke: Dictionary) -> String:
	var t := PackedStringArray()
	var fila := conversor.especie_de(poke)
	var nombre := conversor.nombre_especie(poke)
	t.append("[b]%s[/b]  (%s)  #%03d" % [_esc(nombre), _esc(poke.get("nombre_interno", "?")), int(poke.get("numero_nacional", 0))])
	if fila.is_empty():
		t.append("[color=#ff7070]Especie no encontrada en la base de datos.[/color]")
	var mote := str(poke.get("mote", ""))
	t.append("Mote: %s" % (_esc(mote) if mote != "" else "—"))
	t.append("Sexo: %s   Nivel: %d" % [_esc(poke.get("sexo", "?")), int(poke.get("nivel", 0))])
	t.append("Experiencia: %d / %d (siguiente nivel)" % [int(poke.get("experiencia", 0)), int(poke.get("exp_sig_nivel", 0))])
	var ps_max := int(poke.get("estad_ps", 0))
	var linea_ps := "PS: %d / %d" % [int(poke.get("estad_ps_actual", 0)), ps_max]
	var ps_calculados := conversor.ps_maximos(poke)
	if ps_calculados >= 0 and ps_calculados != ps_max:
		linea_ps += "  [color=#ffb050](calculado: %d)[/color]" % ps_calculados
	t.append(linea_ps)
	t.append("Estado: %s" % _nombre_estado(int(poke.get("estado", -1))))
	t.append("Naturaleza: %s" % _esc(poke.get("naturaleza", "")))
	var habilidad := str(poke.get("habilidad", ""))
	t.append("Habilidad: %s (%s)" % [_esc(conversor.nombre_habilidad(habilidad)), _esc(habilidad)])
	var objeto := str(poke.get("objeto", ""))
	t.append("Objeto: %s" % ("—" if objeto == "" else "%s (%s)" % [_esc(conversor.nombre_objeto(objeto)), _esc(objeto)]))
	var tipo_2 := str(poke.get("tipo_2", ""))
	t.append("Tipos: %s%s   Poder Oculto: %s" % [_esc(poke.get("tipo_1", "")), "" if tipo_2 == "" else " / " + _esc(tipo_2), _esc(poke.get("tipo_poder_oculto", ""))])
	t.append("Felicidad: %d" % int(poke.get("felicidad", 0)))
	var banderas: Array[String] = []
	for par in [["huevo", "Huevo"], ["shiny", "Variocolor"], ["infectado", "Pokérus"], ["curado", "Pokérus curado"]]:
		if Conversor.a_bool(poke.get(par[0], false)):
			banderas.append(par[1])
	t.append("Indicadores: %s" % (", ".join(banderas) if not banderas.is_empty() else "—"))
	var marcas: Array[String] = []
	if poke.get("marcas") is Dictionary:
		for clave: Variant in poke["marcas"]:
			if Conversor.a_bool(poke["marcas"][clave]):
				marcas.append(str(clave))
	var cintas: Array = poke["cintas"] if poke.get("cintas") is Array else []
	t.append("Marcas: %s   Cintas: %d" % [", ".join(marcas) if not marcas.is_empty() else "—", cintas.size()])
	t.append("")
	t.append("[b]Estadísticas[/b]  (valor · IV · EV)")
	for par in [["ps", "PS"], ["ataque", "Ataque"], ["defensa", "Defensa"], ["ataque_especial", "At. Esp."], ["defensa_especial", "Def. Esp."], ["velocidad", "Velocidad"]]:
		var s: String = par[0]
		t.append("  %s: %d · %d · %d" % [par[1], int(poke.get("estad_" + s, 0)), int(poke.get("iv_" + s, 0)), int(poke.get("ev_" + s, 0))])
	t.append("")
	t.append("[b]Movimientos[/b]")
	var hay_movimientos := false
	for entrada: Variant in poke.get("movimientos", []):
		var mov := conversor.info_movimiento(entrada)
		if mov.is_empty():
			t.append("  [color=#ff7070]%s[/color]" % _esc(entrada))
			continue
		hay_movimientos = true
		t.append("  %s  PP %d/%d  ·  %s  ·  Potencia %d" % [_esc(mov["nombre"]), int(mov["pp_act"]), int(mov["pp_tot"]), _esc(mov["tipo"]), int(mov["potencia"])])
	if not hay_movimientos:
		t.append("  —")
	t.append("")
	t.append("[b]Entrenador original[/b]: %s (%s)  ID %d" % [_esc(poke.get("entrenador_original", "")), _esc(poke.get("entrenador_sexo", "")), int(poke.get("entrenador_id", 0))])
	t.append("Encuentro: %s · %s · Nv %d%s" % [_esc(poke.get("encuentro_lugar", "")), _esc(poke.get("encuentro_bola", "")), int(poke.get("encuentro_nivel", 0)), " · fatídico" if Conversor.a_bool(poke.get("encuentro_fatidico", false)) else ""])
	return "\n".join(t)

@tool
extends ScrollContainer
## Edita el Dictionary compartido; el archivo solo lo escribe la ventana principal.
signal modificado(mensaje: String)

const MEDALLAS := ["Piedra", "Puño", "Dinamo", "Calor", "Equilibrio", "Pluma", "Mente", "Lluvia"]
const BANDERAS := [
	["Pokédex obtenida", "pokedex_obtenida"],
	["Pokédex nacional", "dex_nacional"],
	["Pokénav obtenido", "pokenav_obtenido"],
]

var _partida: Dictionary = {}
var _medallas: Array[CheckBox] = []
var _campos: Array[Dictionary] = []
var _resumen: Label


func _init() -> void:
	name = "Progreso"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var columna := VBoxContainer.new()
	columna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columna.add_theme_constant_override("separation", 8)
	add_child(columna)
	columna.add_child(_etiqueta("Edita el guardado local y pulsa Guardar. Para usarlo, vuelve a cargar la partida en el juego."))
	_resumen = _etiqueta("")
	columna.add_child(_resumen)
	columna.add_child(_etiqueta("Medallas individuales"))
	var rejilla := GridContainer.new()
	rejilla.columns = 2
	columna.add_child(rejilla)
	for i in range(MEDALLAS.size()):
		var casilla := CheckBox.new()
		casilla.text = "%d. Medalla %s" % [i + 1, MEDALLAS[i]]
		rejilla.add_child(casilla)
		_medallas.append(casilla)
		casilla.toggled.connect(_cambiar_medalla.bind(i))
	columna.add_child(HSeparator.new())
	_numero(columna, "Ceniza en el Saco Hollín", ["datos_persistentes", "contadores", "ceniza_saco_hollin"], 9999,
		"La ceniza va de 0 a 9999. El SACOHOLLIN se añade desde Mochila, en Objetos clave.")
	_numero(columna, "Dinero", ["jugador", "dinero"], 999999)
	_numero(columna, "Pasos de repelente restantes", ["datos_persistentes", "contadores", "pasos_repelente"], 250,
		"0 desactiva el repelente; 100, 200 y 250 son las duraciones de los tres repelentes.")
	_numero(columna, "Pasos para sortear revanchas", ["revanchas", "pasos"], 255,
		"255 permite el sorteo al cambiar de mapa; requiere al menos cinco medallas y entrenadores ya vencidos.")
	columna.add_child(HSeparator.new())
	columna.add_child(_etiqueta("Desbloqueos"))
	for bandera in BANDERAS:
		var casilla := CheckBox.new()
		casilla.text = bandera[0]
		columna.add_child(casilla)
		var ruta: Array = ["datos_persistentes", "banderas", bandera[1]]
		_campos.append({"control": casilla, "ruta": ruta, "nombre": bandera[0], "booleano": true})
		casilla.toggled.connect(_cambiar_campo.bind(ruta, String(bandera[0])))
	mostrar({})


func _etiqueta(texto: String) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return etiqueta


func _numero(columna: VBoxContainer, titulo: String, ruta: Array, maximo: int, ayuda: String = "") -> void:
	var fila := HBoxContainer.new()
	columna.add_child(fila)
	var etiqueta := _etiqueta(titulo)
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(etiqueta)
	var numero := SpinBox.new()
	numero.min_value = 0
	numero.max_value = maximo
	numero.step = 1
	numero.custom_minimum_size.x = 150
	numero.tooltip_text = ayuda
	fila.add_child(numero)
	_campos.append({"control": numero, "ruta": ruta, "nombre": titulo, "booleano": false})
	numero.value_changed.connect(func(valor: float): _cambiar_campo(int(valor), ruta, titulo))
	if not ayuda.is_empty():
		columna.add_child(_etiqueta(ayuda))


## Leer/releer nunca completa ni normaliza datos: solo se crea un campo al editarlo.
func mostrar(partida: Dictionary) -> void:
	_partida = partida
	var ruta_medallas: Array = ["jugador", "medallas"]
	var valor: Variant = _leer(ruta_medallas, [])
	var validas := _ruta_valida(ruta_medallas) and valor is Array
	var total := 0
	for i in range(_medallas.size()):
		var activa: bool = validas and i < valor.size() and bool(valor[i])
		_medallas[i].set_pressed_no_signal(activa)
		_medallas[i].disabled = not validas
		if activa:
			total += 1
	_resumen.text = "Medallas: %d/8" % total if validas else "No hay una partida válida o los datos de medallas son inválidos."
	for campo in _campos:
		var ruta: Array = campo.ruta
		var actual: Variant = _leer(ruta, false if campo.booleano else 0)
		var valido := _ruta_valida(ruta)
		if campo.booleano:
			var casilla: CheckBox = campo.control
			casilla.disabled = not valido or not actual is bool
			casilla.set_pressed_no_signal(actual == true)
		else:
			var numero: SpinBox = campo.control
			numero.editable = valido and (actual is int or actual is float)
			numero.set_value_no_signal(float(actual) if actual is int or actual is float else 0.0)


func _ruta_valida(ruta: Array) -> bool:
	if _partida.is_empty():
		return false
	var actual: Dictionary = _partida
	for i in range(ruta.size() - 1):
		if not actual.has(ruta[i]):
			return true
		if not actual[ruta[i]] is Dictionary:
			return false
		actual = actual[ruta[i]]
	return true


func _leer(ruta: Array, defecto: Variant) -> Variant:
	var actual: Variant = _partida
	for clave in ruta:
		if not actual is Dictionary or not actual.has(clave):
			return defecto
		actual = actual[clave]
	return actual


func _escribir(ruta: Array, valor: Variant) -> void:
	var actual: Dictionary = _partida
	for i in range(ruta.size() - 1):
		if not actual.has(ruta[i]):
			actual[ruta[i]] = {}
		actual = actual[ruta[i]]
	actual[ruta.back()] = valor


func _cambiar_campo(valor: Variant, ruta: Array, titulo: String) -> void:
	if not _ruta_valida(ruta):
		return
	var previo: Variant = _leer(ruta, false if valor is bool else 0)
	if previo == valor:
		return
	_escribir(ruta, valor)
	modificado.emit("%s: %s. Cambios pendientes de guardar." % [titulo, str(valor)])


func _cambiar_medalla(activa: bool, indice: int) -> void:
	var ruta: Array = ["jugador", "medallas"]
	var valor: Variant = _leer(ruta, [])
	if not _ruta_valida(ruta) or not valor is Array:
		return
	var medallas: Array = valor.duplicate()
	while medallas.size() < MEDALLAS.size():
		medallas.append(false)
	medallas[indice] = activa
	_escribir(ruta, medallas)
	mostrar(_partida)
	modificado.emit("Medalla %s: %s. Cambios pendientes de guardar." % [MEDALLAS[indice], "obtenida" if activa else "quitada"])

@tool
extends Window
## Listado de la POKéDEX de HOENN o la Nacional con el icono de cada especie, dónde
## aparece salvaje y cuáles no tienen encuentro. Solo lectura.
## Punto de entrada: abrir()

const TABLAS = preload("res://UI/pokedex/tablas_pokedex.gd")

enum Dex { HOENN, NACIONAL }
enum Filtro { TODOS, CON_ENCUENTRO, SIN_ENCUENTRO }

const COLOR_SIN_ENCUENTRO := Color(1.0, 0.45, 0.4)
const TEXTO_SIN_ENCUENTRO := "Sin encuentro"

@onready var _selector_dex: OptionButton = %SelectorDex
@onready var _selector_tabla: OptionButton = %SelectorTabla
@onready var _selector_filtro: OptionButton = %SelectorFiltro
@onready var _busqueda: LineEdit = %Busqueda
@onready var _recargar: Button = %Recargar
@onready var _lista: Tree = %Lista
@onready var _icono: TextureRect = %Icono
@onready var _nombre: Label = %Nombre
@onready var _numeros: Label = %Numeros
@onready var _detalle: Tree = %Detalle
@onready var _estado: Label = %Estado
@onready var _temporizador_iconos: Timer = %TemporizadorIconos

var _catalogo := CatalogoPokemon.new()
var _lugares := ResolvedorLugaresEncuentro.new()
var _indice: Dictionary = {}
var _especie_actual: String = ""


func _ready() -> void:
	if Engine.is_editor_hint() and is_part_of_edited_scene():
		return
	_catalogo.cargar()
	_configurar_columnas(_lista, ["N.º", "Nombre", "Método", "Dónde se encuentra"], [96, 150, 96])
	_configurar_columnas(_detalle, ["Lugar", "Mapa", "Método", "Prob.", "Niveles"], [130, 140, 120, 56])
	_selector_dex.item_selected.connect(func(_i: int) -> void: _refrescar_lista())
	_selector_filtro.item_selected.connect(func(_i: int) -> void: _refrescar_lista())
	_selector_tabla.item_selected.connect(func(_i: int) -> void: recalcular())
	_busqueda.text_changed.connect(func(_t: String) -> void: _refrescar_lista())
	_recargar.pressed.connect(recalcular)
	_lista.item_selected.connect(_on_especie_seleccionada)
	_temporizador_iconos.timeout.connect(_on_temporizador_iconos)
	visibility_changed.connect(func() -> void: _temporizador_iconos.paused = not visible)
	close_requested.connect(hide)


func abrir() -> void:
	if not is_node_ready():
		await ready
	recalcular()
	popup_centered()
	grab_focus()
	_busqueda.grab_focus()


## Relee las tablas: pueden haber cambiado desde el editor de encuentros.
func recalcular() -> void:
	var modelos: Array[ModeloEncuentros] = IndiceEncuentrosPokedex.cargar_modelos(_selector_tabla.selected == 1)
	_indice = IndiceEncuentrosPokedex.indexar(modelos, _nombre_lugar)
	_refrescar_lista()


func _nombre_lugar(clave: String) -> String:
	return str(_lugares.lugar_de(clave).get("nombre", clave.to_upper()))


func _configurar_columnas(arbol: Tree, titulos: Array[String], anchos_fijos: Array[int]) -> void:
	arbol.columns = titulos.size()
	arbol.column_titles_visible = true
	for i: int in titulos.size():
		arbol.set_column_title(i, titulos[i])
		arbol.set_column_title_alignment(i, HORIZONTAL_ALIGNMENT_LEFT)
		if i < anchos_fijos.size():
			arbol.set_column_custom_minimum_width(i, anchos_fijos[i])
			arbol.set_column_expand(i, false)


# ─── Lista ────────────────────────────────────────────────────────────────────

## Especies de la POKéDEX elegida, en su orden: [{numero, interno}].
func _especies_de_dex() -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	var internos: Array[String] = _catalogo.buscar("", TABLAS.HOENN_A_NACIONAL.size() * 10)
	if _selector_dex.selected == Dex.NACIONAL:
		for interno: String in internos:
			resultado.append({"numero": _catalogo.numero(interno), "interno": interno})
		return resultado
	var interno_de_nacional: Dictionary = {}
	for interno: String in internos:
		interno_de_nacional[_catalogo.numero(interno)] = interno
	for i: int in TABLAS.HOENN_A_NACIONAL.size():
		var interno: String = str(interno_de_nacional.get(TABLAS.HOENN_A_NACIONAL[i], ""))
		if not interno.is_empty():
			resultado.append({"numero": i + 1, "interno": interno})
	return resultado


func _pasa_filtros(especie: Dictionary, entradas: Array, busqueda: String) -> bool:
	var filtro: int = _selector_filtro.selected
	if (filtro == Filtro.CON_ENCUENTRO and entradas.is_empty()) or (filtro == Filtro.SIN_ENCUENTRO and not entradas.is_empty()):
		return false
	if busqueda.is_empty():
		return true
	var interno: String = especie["interno"]
	if busqueda.is_valid_int():
		return int(especie["numero"]) == busqueda.to_int() or _catalogo.numero(interno) == busqueda.to_int()
	if interno.contains(busqueda) or _catalogo.nombre_visible(interno).to_upper().contains(busqueda):
		return true
	for entrada: Dictionary in entradas:
		if str(entrada["lugar"]).to_upper().contains(busqueda) or str(entrada["clave"]).to_upper().contains(busqueda):
			return true
	return false


func _refrescar_lista() -> void:
	var especies: Array[Dictionary] = _especies_de_dex()
	var busqueda: String = _busqueda.text.strip_edges().to_upper()
	var con_encuentro: int = 0
	var seleccion: TreeItem = null
	_lista.clear()
	var raiz: TreeItem = _lista.create_item()
	for especie: Dictionary in especies:
		var entradas: Array = _indice.get(especie["interno"], [])
		if not entradas.is_empty():
			con_encuentro += 1
		if _pasa_filtros(especie, entradas, busqueda):
			var fila: TreeItem = _crear_fila(raiz, especie, entradas)
			if especie["interno"] == _especie_actual:
				seleccion = fila
	if seleccion != null:
		seleccion.select(0)
		_lista.scroll_to_item(seleccion)
	else:
		_mostrar_detalle("")
	_estado.text = "%d especies · %d con encuentro · %d sin encuentro · mostrando %d" % [
			especies.size(), con_encuentro, especies.size() - con_encuentro, raiz.get_child_count()]


func _crear_fila(raiz: TreeItem, especie: Dictionary, entradas: Array) -> TreeItem:
	var interno: String = especie["interno"]
	var fila: TreeItem = raiz.create_child()
	fila.set_metadata(0, interno)
	fila.set_icon(0, _catalogo.icono(interno))
	fila.set_icon_max_width(0, int(CatalogoPokemon.TAM_FRAME.x))
	fila.set_text(0, "#%03d" % int(especie["numero"]))
	fila.set_text(1, _catalogo.nombre_visible(interno))
	if entradas.is_empty():
		fila.set_text(3, TEXTO_SIN_ENCUENTRO)
		for columna: int in [0, 1, 3]:
			fila.set_custom_color(columna, COLOR_SIN_ENCUENTRO)
		return fila
	var lugares: String = ", ".join(IndiceEncuentrosPokedex.lugares(entradas))
	fila.set_text(2, IndiceEncuentrosPokedex.iconos_metodos(entradas))
	fila.set_text(3, lugares)
	fila.set_tooltip_text(3, lugares)
	return fila


func _on_temporizador_iconos() -> void:
	_catalogo.alternar_frame()
	_lista.queue_redraw()


# ─── Detalle ──────────────────────────────────────────────────────────────────

func _on_especie_seleccionada() -> void:
	_mostrar_detalle(str(_lista.get_selected().get_metadata(0)))


func _mostrar_detalle(interno: String) -> void:
	_especie_actual = interno
	_detalle.clear()
	if interno.is_empty():
		_icono.texture = null
		_nombre.text = "Ninguna especie seleccionada"
		_numeros.text = ""
		return
	var nacional: int = _catalogo.numero(interno)
	var hoenn: int = TABLAS.HOENN_A_NACIONAL.find(nacional) + 1
	_icono.texture = _catalogo.icono(interno)
	_nombre.text = _catalogo.nombre_visible(interno)
	_numeros.text = "Nacional #%03d · %s" % [nacional, "Hoenn #%03d" % hoenn if hoenn > 0 else "Fuera de HOENN"]
	var entradas: Array = _indice.get(interno, [])
	var raiz: TreeItem = _detalle.create_item()
	if entradas.is_empty():
		var fila: TreeItem = raiz.create_child()
		fila.set_text(0, TEXTO_SIN_ENCUENTRO)
		fila.set_custom_color(0, COLOR_SIN_ENCUENTRO)
		return
	for entrada: Dictionary in entradas:
		var fila: TreeItem = raiz.create_child()
		fila.set_text(0, str(entrada["lugar"]))
		fila.set_text(1, str(entrada["clave"]))
		fila.set_text(2, IndiceEncuentrosPokedex.texto_metodo(entrada))
		if float(entrada["porcentaje"]) >= 0.0:
			fila.set_text(3, ModeloEncuentros.formatear_porcentaje(float(entrada["porcentaje"])))
			fila.set_text(4, _texto_niveles(int(entrada["nivel_min"]), int(entrada["nivel_max"])))


func _texto_niveles(minimo: int, maximo: int) -> String:
	return "Nv. %d" % minimo if minimo == maximo else "Nv. %d-%d" % [minimo, maximo]

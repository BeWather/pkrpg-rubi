@tool
extends Window
## Selector reutilizable de Pokemon (especie + nivel) que autogenera los datos
## completos con AutogeneradorPokemon. Emite pokemon_elegido(entrada) para que
## cualquier UI (slots de la ventana de prueba, lista de generados, ...) consuma
## la entrada lista.

signal pokemon_elegido(entrada: Dictionary)

const Autogenerador := preload("res://BaseDatos/autogenerador_pokemon.gd")

var _generador = null
var _especies: Array = []

@onready var campo_busqueda: LineEdit = $Margen/Caja/Buscar
@onready var lista: ItemList = $Margen/Caja/Lista
@onready var campo_nivel: SpinBox = $Margen/Caja/FilaNivel/Nivel
@onready var boton_usar: Button = $Margen/Caja/Acciones/Usar
@onready var boton_cancelar: Button = $Margen/Caja/Acciones/Cancelar


func _ready() -> void:
	_generador = Autogenerador.new()
	_cargar_especies()
	campo_busqueda.text_changed.connect(_on_busqueda_cambiada)
	lista.item_activated.connect(_on_lista_activada)
	boton_usar.pressed.connect(_usar_presionado)
	boton_cancelar.pressed.connect(hide)
	close_requested.connect(hide)


func esta_conectado() -> bool:
	return _generador != null and _generador.esta_conectado()


func _cargar_especies() -> void:
	if _generador == null or not _generador.esta_conectado():
		return
	_especies = _generador.lista_especies()
	_filtrar("")


func _filtrar(filtro: String) -> void:
	lista.clear()
	var texto := filtro.strip_edges().to_upper()
	for especie in _especies:
		var interno := str(especie.get("nombre_interno", ""))
		if texto == "" or interno.contains(texto) or str(especie.get("nombre", "")).to_upper().contains(texto):
			lista.add_item("%d  %s" % [int(especie.get("numero_nacional", 0)), interno])
			lista.set_item_metadata(lista.item_count - 1, interno)


func _on_busqueda_cambiada(texto: String) -> void:
	_filtrar(texto)


func _on_lista_activada(_indice: int) -> void:
	_usar_presionado()


func _especie_seleccionada() -> String:
	var seleccion := lista.get_selected_items()
	if seleccion.is_empty():
		return ""
	return str(lista.get_item_metadata(seleccion[0]))


## Autogenera la entrada de la especie seleccionada y emite pokemon_elegido.
func _usar_presionado() -> void:
	var especie := _especie_seleccionada()
	if especie.is_empty():
		return
	usar_especie(especie, int(campo_nivel.value))


## API directa (reutilizable por tests): autogenera y emite.
func usar_especie(nombre_interno: String, nivel: int = -1) -> void:
	if _generador == null or not _generador.esta_conectado():
		return
	var nivel_final := int(campo_nivel.value) if nivel < 1 else nivel
	var entrada: Dictionary = _generador.autogenerar(nombre_interno, nivel_final)
	if entrada.is_empty():
		return
	pokemon_elegido.emit(entrada)
	hide()

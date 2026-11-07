@tool
extends VBoxContainer
class_name PestanaTipoEncuentro
## Pestaña de un tipo de encuentro (hierba/agua/pesca/roca): ratio y lista de
## slots. Cada edición se vuelca al modelo y recalcula las probabilidades.

signal cambiado(tipo: String)
signal solicitar_autocompletado(fila: FilaSlotEncuentro, campo: LineEdit)

const FILA_SLOT := preload("res://addons/tilemap_inspector/editores/editor_encuentros_visual/fila_slot.tscn")
const SLOTS_ESPERADOS: Dictionary = {"hierba": 12, "agua": 5, "pesca": 10, "roca": 5}

@export_enum("hierba", "agua", "pesca", "roca") var tipo: String = "hierba"

@onready var _ratio: SpinBox = %Ratio
@onready var _conteo: Label = %Conteo
@onready var _agregar: Button = %Agregar
@onready var _filas: VBoxContainer = %Filas
@onready var _vacio: Label = %Vacio

var _modelo: ModeloEncuentros = null
var _catalogo: CatalogoPokemon = null
var _clave: String = ""
var _cargando: bool = false


func _ready() -> void:
	_ratio.value_changed.connect(func(_v: float) -> void: _volcar())
	_agregar.pressed.connect(_on_agregar)


func configurar(modelo: ModeloEncuentros, catalogo: CatalogoPokemon) -> void:
	_modelo = modelo
	_catalogo = catalogo


func cargar(clave: String) -> void:
	_clave = clave
	_cargando = true
	for fila: Node in _filas.get_children():
		_filas.remove_child(fila)
		fila.queue_free()
	_ratio.value = _modelo.ratio(clave, tipo) if not clave.is_empty() else 0
	for slot: Dictionary in _modelo.slots(clave, tipo):
		_crear_fila(slot)
	_agregar.disabled = clave.is_empty()
	_ratio.editable = not clave.is_empty()
	_cargando = false
	_refrescar()


func cantidad_slots() -> int:
	return _filas.get_child_count()


func slots_actuales() -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	for fila: FilaSlotEncuentro in _filas.get_children():
		resultado.append(fila.datos())
	return resultado


func _crear_fila(slot: Dictionary) -> FilaSlotEncuentro:
	var fila: FilaSlotEncuentro = FILA_SLOT.instantiate()
	_filas.add_child(fila)
	fila.configurar(_catalogo, slot)
	fila.cambiado.connect(_volcar)
	fila.mover_solicitado.connect(_on_mover)
	fila.eliminar_solicitado.connect(_on_eliminar)
	fila.solicitar_autocompletado.connect(func(campo: LineEdit) -> void: solicitar_autocompletado.emit(fila, campo))
	return fila


func _on_agregar() -> void:
	# Un slot nuevo hereda los niveles del último para agilizar la carga.
	var nuevo: Dictionary = {"nombre_interno": "", "nivel_min": 1, "nivel_max": 1}
	if _filas.get_child_count() > 0:
		var ultimo: Dictionary = (_filas.get_child(_filas.get_child_count() - 1) as FilaSlotEncuentro).datos()
		nuevo["nivel_min"] = ultimo["nivel_min"]
		nuevo["nivel_max"] = ultimo["nivel_max"]
	var fila: FilaSlotEncuentro = _crear_fila(nuevo)
	_refrescar()
	fila.campo_especie().grab_focus.call_deferred()


func _on_mover(fila: FilaSlotEncuentro, delta: int) -> void:
	var destino: int = clampi(fila.get_index() + delta, 0, _filas.get_child_count() - 1)
	_filas.move_child(fila, destino)
	_volcar()


func _on_eliminar(fila: FilaSlotEncuentro) -> void:
	_filas.remove_child(fila)
	fila.queue_free()
	_volcar()


func _volcar() -> void:
	if _cargando or _clave.is_empty():
		return
	_modelo.fijar_tipo(_clave, tipo, int(_ratio.value), slots_actuales())
	_refrescar()
	cambiado.emit(tipo)


func _refrescar() -> void:
	var total: int = _filas.get_child_count()
	var probs: Array[Dictionary] = ModeloEncuentros.probabilidades(tipo, total)
	for i: int in total:
		var fila: FilaSlotEncuentro = _filas.get_child(i)
		fila.fijar_posicion(i, total)
		fila.fijar_probabilidad(probs[i])
	var esperados: int = int(SLOTS_ESPERADOS.get(tipo, 0))
	_conteo.text = "%d / %d slots" % [total, esperados]
	var completo: bool = total == esperados
	_conteo.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75) if completo or total == 0 else Color(1.0, 0.7, 0.35))
	_conteo.tooltip_text = "" if completo else "El juego usa %d slots; con otra cantidad las probabilidades se renormalizan o los slots sobrantes no salen." % esperados
	_vacio.visible = total == 0

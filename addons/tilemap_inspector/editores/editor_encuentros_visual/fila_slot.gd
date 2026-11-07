@tool
extends PanelContainer
class_name FilaSlotEncuentro
## Tarjeta de un slot de encuentro: icono animado, nombre visible destacado,
## nombre interno editable, niveles y la probabilidad calculada para ese slot.

signal cambiado
signal solicitar_autocompletado(campo: LineEdit)
signal mover_solicitado(fila: FilaSlotEncuentro, delta: int)
signal eliminar_solicitado(fila: FilaSlotEncuentro)

const COLOR_VALIDO := Color(0.80, 1.0, 0.80)
const COLOR_INVALIDO := Color(1.0, 0.62, 0.62)
const COLOR_SIN_USO := Color(0.55, 0.55, 0.6)

@onready var _numero: Label = %Numero
@onready var _icono: TextureRect = %Icono
@onready var _nombre: Label = %Nombre
@onready var _interno: LineEdit = %Interno
@onready var _nivel_min: SpinBox = %NivelMin
@onready var _nivel_max: SpinBox = %NivelMax
@onready var _porcentaje: Label = %Porcentaje
@onready var _barra: ProgressBar = %Barra
@onready var _grupo: Label = %Grupo
@onready var _subir: Button = %Subir
@onready var _bajar: Button = %Bajar
@onready var _eliminar: Button = %Eliminar

var _catalogo: CatalogoPokemon = null
var _cargando: bool = false


func _ready() -> void:
	_interno.text_changed.connect(_on_interno_cambiado)
	_interno.focus_entered.connect(func() -> void: solicitar_autocompletado.emit(_interno))
	_nivel_min.value_changed.connect(_on_nivel_min_cambiado)
	_nivel_max.value_changed.connect(_on_nivel_max_cambiado)
	_subir.pressed.connect(func() -> void: mover_solicitado.emit(self, -1))
	_bajar.pressed.connect(func() -> void: mover_solicitado.emit(self, 1))
	_eliminar.pressed.connect(func() -> void: eliminar_solicitado.emit(self))


func configurar(catalogo: CatalogoPokemon, slot: Dictionary) -> void:
	_catalogo = catalogo
	_cargando = true
	_interno.text = str(slot.get("nombre_interno", ""))
	_nivel_min.value = int(slot.get("nivel_min", 1))
	_nivel_max.value = int(slot.get("nivel_max", 1))
	_cargando = false
	_actualizar_especie()


func datos() -> Dictionary:
	return {
		"nombre_interno": _interno.text.strip_edges().to_upper(),
		"nivel_min": int(_nivel_min.value),
		"nivel_max": int(_nivel_max.value),
	}


func campo_especie() -> LineEdit:
	return _interno


## Cambia la especie desde fuera (autocompletado) y avisa del cambio.
func fijar_especie(interno: String) -> void:
	_cargando = true
	_interno.text = interno
	_interno.caret_column = interno.length()
	_cargando = false
	_actualizar_especie()
	cambiado.emit()


func fijar_posicion(indice: int, total: int) -> void:
	_numero.text = "%02d" % (indice + 1)
	_subir.disabled = indice == 0
	_bajar.disabled = indice == total - 1


func fijar_probabilidad(info: Dictionary) -> void:
	var porcentaje: float = float(info.get("porcentaje", 0.0))
	var grupo: String = str(info.get("grupo", ""))
	var sin_uso: bool = porcentaje <= 0.0
	_porcentaje.text = "—" if sin_uso else ModeloEncuentros.formatear_porcentaje(porcentaje)
	_barra.value = porcentaje
	_grupo.text = grupo
	_grupo.visible = not grupo.is_empty()
	modulate = Color(1, 1, 1, 0.55) if sin_uso else Color.WHITE
	_porcentaje.add_theme_color_override("font_color", COLOR_SIN_USO if sin_uso else Color(0.55, 0.95, 0.55))


func _actualizar_especie() -> void:
	var interno: String = _interno.text.strip_edges().to_upper()
	if _catalogo == null:
		return
	var valida: bool = not interno.is_empty() and _catalogo.es_valida(interno)
	var visible_nombre: String = _catalogo.nombre_visible(interno)
	if interno.is_empty():
		_nombre.text = "(vacío)"
	elif visible_nombre.is_empty():
		_nombre.text = interno if valida else "¿%s?" % interno
	else:
		_nombre.text = visible_nombre
	_nombre.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35) if valida else COLOR_INVALIDO)
	_interno.modulate = Color.WHITE if interno.is_empty() else (COLOR_VALIDO if valida else COLOR_INVALIDO)
	_icono.texture = _catalogo.icono(interno if valida else "")


func _on_interno_cambiado(_texto: String) -> void:
	if _cargando:
		return
	_actualizar_especie()
	solicitar_autocompletado.emit(_interno)
	cambiado.emit()


func _on_nivel_min_cambiado(valor: float) -> void:
	if _cargando:
		return
	if _nivel_max.value < valor:
		_nivel_max.value = valor
	cambiado.emit()


func _on_nivel_max_cambiado(valor: float) -> void:
	if _cargando:
		return
	if _nivel_min.value > valor:
		_nivel_min.value = valor
	cambiado.emit()

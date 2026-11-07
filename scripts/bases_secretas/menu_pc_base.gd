extends Control
class_name MenuPCBase

## UI declarativa de 3/4 filas. No modifica propiedad, inventario ni mapas.
signal elegida(indice: int)
@export var panel: NinePatchRect
@export var filas: Array[Label]
@export var cursor: Control
@export var ayuda: Label
var activa: bool = false
var _cantidad: int = 0
var _indice: int = 0
var _ayudas: Array[String] = []
var _soltar: bool = true


func elegir(claves: Array[String], ayudas: Array[String] = []) -> int:
	if activa or claves.is_empty() or claves.size() > filas.size():
		return -1
	_cantidad = claves.size()
	_ayudas = ayudas.duplicate()
	_indice = 0
	_soltar = true
	for i: int in filas.size():
		filas[i].visible = i < _cantidad
		if i < _cantidad:
			filas[i].text = DatosPCBase.texto(claves[i])
	panel.size.y = 16 * _cantidad + 16
	_actualizar()
	activa = true
	show()
	return await elegida


func cancelar() -> void:
	if activa:
		_terminar(-1)


func _terminar(indice: int) -> void:
	activa = false
	hide()
	elegida.emit(indice)


func _actualizar() -> void:
	cursor.position.y = 7 + 16 * _indice
	ayuda.text = DatosPCBase.texto(_ayudas[_indice]) if _ayudas.size() == _cantidad else DatosPCBase.texto("BASES_PC_PREGUNTA")


func _process(_delta: float) -> void:
	if not activa:
		return
	if _soltar:
		if not Input.is_action_pressed("btn_accion") and not Input.is_action_pressed("btn_cancelar"):
			_soltar = false
		return
	if Input.is_action_just_pressed("btn_arriba") or Input.is_action_just_pressed("btn_abajo"):
		_indice = posmod(_indice + (-1 if Input.is_action_just_pressed("btn_arriba") else 1), _cantidad)
		Singleton.play_sound.emit("SE_SELECT")
		_actualizar()
	elif Input.is_action_just_pressed("btn_cancelar"):
		Singleton.play_sound.emit("SE_SELECT")
		_terminar(-1)
	elif Input.is_action_just_pressed("btn_accion"):
		Singleton.play_sound.emit("SE_SELECT")
		_terminar(_indice)


func _exit_tree() -> void:
	cancelar()

extends Control
class_name MenuCanjeVidrio

signal elegida(indice: int)
@export var filas: Array[Label]
@export var cursor: Control
@export var arriba: CanvasItem
@export var abajo: CanvasItem
var activa: bool = false
var indice: int = 0
var inicio: int = 0
var _soltar: bool = true


func elegir() -> int:
	indice = 0
	inicio = 0
	_soltar = true
	_actualizar()
	activa = true
	show()
	return await elegida


func _actualizar() -> void:
	for i: int in filas.size(): filas[i].text = DatosCanjeVidrio.texto("VIDRIO_MENU_%d" % (inicio + i))
	cursor.position.y = 7 + (indice - inicio) * 16
	arriba.visible = inicio > 0
	abajo.visible = inicio + filas.size() < 8


func cancelar() -> void:
	if activa: _terminar(-1)


func _terminar(valor: int) -> void:
	activa = false
	hide()
	elegida.emit(valor)


func _process(_delta: float) -> void:
	if not activa: return
	if _soltar:
		if not Input.is_action_pressed("btn_accion") and not Input.is_action_pressed("btn_cancelar"): _soltar = false
		return
	if Input.is_action_just_pressed("btn_arriba") or Input.is_action_just_pressed("btn_abajo"):
		indice = clampi(indice + (-1 if Input.is_action_just_pressed("btn_arriba") else 1), 0, 7)
		inicio = clampi(inicio, maxi(0, indice - filas.size() + 1), indice)
		_actualizar()
		Singleton.play_sound.emit("SE_SELECT")
	elif Input.is_action_just_pressed("btn_cancelar"):
		Singleton.play_sound.emit("SE_SELECT")
		_terminar(-1)
	elif Input.is_action_just_pressed("btn_accion"):
		Singleton.play_sound.emit("SE_SELECT")
		_terminar(indice if indice < 7 else -1)


func _exit_tree() -> void: cancelar()

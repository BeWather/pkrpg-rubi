extends CanvasLayer

const DURACION: float = 0.5

@onready var negro: ColorRect = $Negro
var _tween: Tween = null

func _ready() -> void:
	negro.color = Color(0, 0, 0, 0)
	negro.mouse_filter = Control.MOUSE_FILTER_STOP
	negro.visible = false

func ejecutar(accion: Callable, duracion: float = DURACION) -> void:
	await _animar_opacidad(1.0, duracion)
	if accion.is_valid():
		accion.call()
	await _animar_opacidad(0.0, duracion)
	negro.visible = false

func _animar_opacidad(opacidad: float, duracion: float) -> void:
	negro.visible = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(negro, "color:a", opacidad, duracion).set_trans(Tween.TRANS_LINEAR)
	await _tween.finished

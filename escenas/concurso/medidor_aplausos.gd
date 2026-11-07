class_name MedidorAplausos
extends Node2D
## Medidor de aplausos (CreateApplauseMeterSprite: 64×32 centrado en (30, 44)). Cada
## segmento es un bloque 8×16 en los tiles 17+i / 25+i (UpdateApplauseMeter). Entra y
## sale deslizándose desde x2 = −70 a 6,5 px por frame (Task_SlideApplauseMeterIn/Out).

const DESPLAZAMIENTO_OCULTO: float = -70.0
const PIXELES_POR_FRAME: float = 1664.0 / 256.0
const SEGMENTOS: int = 5

var escala_tiempo: float = 1.0
var nivel: int = 0
var dentro: bool = false

var _x_base: float = 0.0
var _tween_lleno: Tween

@onready var _segmentos: Array[Sprite2D] = [$Segmento1, $Segmento2, $Segmento3, $Segmento4, $Segmento5]


func _ready() -> void:
	_x_base = position.x
	position.x = _x_base + DESPLAZAMIENTO_OCULTO
	visible = false
	fijar_nivel(0)


func fijar_nivel(nuevo: int) -> void:
	nivel = clampi(nuevo, 0, SEGMENTOS)
	for i in SEGMENTOS:
		_segmentos[i].frame = 1 if i < nivel else 0
	# StartApplauseOverflowAnimation: el medidor lleno destella en blanco.
	if _tween_lleno != null:
		_tween_lleno.kill()
		_tween_lleno = null
	modulate = Color.WHITE
	if nivel >= SEGMENTOS:
		_tween_lleno = create_tween().set_loops()
		_tween_lleno.tween_property(self, "modulate", Color(1.6, 1.6, 1.6), 0.27)
		_tween_lleno.tween_property(self, "modulate", Color.WHITE, 0.27)


func entrar() -> void:
	if dentro:
		return
	visible = true
	await _deslizar(DESPLAZAMIENTO_OCULTO, 0.0)
	dentro = true


func salir() -> void:
	if not visible:
		dentro = false
		return
	await _deslizar(0.0, DESPLAZAMIENTO_OCULTO)
	visible = false
	dentro = false


## Task_ShowAndUpdateApplauseMeter: entra, espera 20 frames, cambia el nivel y espera 30.
func mostrar_y_actualizar(nuevo: int) -> void:
	await entrar()
	await TiempoConcurso.esperar(self, 20.0, escala_tiempo)
	fijar_nivel(nuevo)
	await TiempoConcurso.esperar(self, 30.0, escala_tiempo)


func _deslizar(desde: float, hasta: float) -> void:
	var x: float = desde
	var paso: float = PIXELES_POR_FRAME if hasta > desde else -PIXELES_POR_FRAME
	while not is_equal_approx(x, hasta):
		x = minf(x + paso, hasta) if paso > 0.0 else maxf(x + paso, hasta)
		position.x = _x_base + roundf(x)
		await TiempoConcurso.esperar(self, 1.0, escala_tiempo)

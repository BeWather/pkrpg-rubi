extends EfectoMovimientoNativo
## Lanzallamas (Move_FLAMETHROWER, subrutina _81D02E1). El AnimationPlayer de
## lanzallamas.tscn decide CUÁNDO sale cada ascua (pista de método, una cada 4
## frames: en el original `delay 2` separa los comandos 4 frames, verificado en la ROM), las sacudidas y el sonido; aquí solo vive la trayectoria de una
## ascua (sub_80D3554 de energy_wave.c): recta de 30 frames desde el atacante
## (+10,+10, reflejado por lado) al centro del defensor, con una onda vertical.

const FRAMES_VUELO: int = 30
const AMPLITUD_ONDA: float = 16.0
## Fase en unidades de la tabla de senos de 256 pasos: 0xD200 / 30 >> 8 = 7 por frame.
const PASO_FASE: float = 7.0
## sub_80D3630 suma 3 por frame a la fase de salida; sale una ascua cada 4 frames.
const FASE_POR_ASCUA: float = 12.0

@export var desplazamiento_salida: Vector2 = Vector2(10, 10)

@onready var plantilla_ascua: AnimatedSprite2D = $PlantillaAscua


## Pista de método: lanza la ascua número `indice` (0..21).
func emitir_ascua(indice: int) -> void:
	var ascua: AnimatedSprite2D = _instanciar_plantilla(plantilla_ascua) as AnimatedSprite2D
	var desde: Vector2 = marca_atacante.position + Vector2(desplazamiento_salida.x * direccion, desplazamiento_salida.y)
	var hasta: Vector2 = marca_defensor.position
	var fase_inicial: float = FASE_POR_ASCUA * indice
	var mover: Callable = func(t: float) -> void:
		var onda: float = AMPLITUD_ONDA * sin(TAU * (fase_inicial + PASO_FASE * t * FRAMES_VUELO) / 256.0)
		ascua.position = desde.lerp(hasta, t) + Vector2(0.0, onda)
	mover.call(0.0)
	# Visible un frame en el punto de salida antes de moverse (31 frames en total).
	var tween: Tween = _crear_tween()
	tween.tween_method(mover, 0.0, 1.0, FRAMES_VUELO * FRAME).set_delay(FRAME)
	tween.tween_callback(ascua.queue_free)

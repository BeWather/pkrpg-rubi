extends EfectoMovimientoNativo
## Viento Cortante (Move_RAZOR_WIND). viento_cortante.tscn tiene dos
## animaciones (choosetwoturnanim): «carga» (_81D1E16) y «ataque» (_81D1E66).
## Aquí solo viven las trayectorias:
## - remolino (gBattleAnimSpriteTemplate_83D765C, sub_80D0118 + sub_8078114):
##   gira 40 frames alrededor de la base del atacante +32 hacia el rival (+16
##   abajo si es del jugador), radio 16, 7/256 de vuelta por frame, mientras
##   su ancho crece de 0x10 a 0xB0 (afín +4 por frame);
## - onda de aire (83DA3E4, sub_80DA208): recta de 22 frames del centro del
##   atacante al del defensor, con offsets que el original niega enteros (x e y)
##   si ataca el rival; cambia de volteo cada 3 frames.

const FRAMES_REMOLINO: int = 40
const RADIO_REMOLINO: int = 16
const PASO_ANGULO: int = 7
const FRAMES_ONDA: int = 22

@onready var plantilla_remolino: Sprite2D = $PlantillaRemolino
@onready var plantilla_onda: Sprite2D = $PlantillaOnda


## Pista de método: un remolino que empieza en el ángulo `angulo` (0..255).
func emitir_remolino(angulo: int) -> void:
	var remolino: Sprite2D = _instanciar_plantilla(plantilla_remolino) as Sprite2D
	var centro: Vector2 = marca_atacante_base.position + Vector2(32.0 * direccion, 16.0 if direccion > 0.0 else 0.0)
	var paso: Callable = func(i: int) -> void:
		var fase: float = TAU * (angulo + PASO_ANGULO * i) / 256.0
		remolino.position = centro + Vector2(_seno_gba(fase, RADIO_REMOLINO), _seno_gba(fase + PI / 2.0, RADIO_REMOLINO))
		remolino.scale.x = (16.0 + 4.0 * i) / 256.0
	_cada_frame(FRAMES_REMOLINO, paso, remolino.queue_free)


## Pista de método: una onda de aire de (centro del atacante + `desde`) a
## (centro del defensor + `hasta`); `fase` es el paso inicial del volteo (0..3).
func emitir_onda(desde: Vector2, hasta: Vector2, fase: int) -> void:
	var onda: Sprite2D = _instanciar_plantilla(plantilla_onda) as Sprite2D
	var inicio: Vector2 = marca_atacante.position + desde * direccion
	var final: Vector2 = marca_defensor.position + hasta * direccion
	var paso: Callable = func(i: int) -> void:
		onda.position = inicio.lerp(final, float(i) / FRAMES_ONDA).floor()
		var volteo: int = (fase + i / 3) % 4
		onda.flip_h = volteo == 1 or volteo == 3
		onda.flip_v = volteo >= 2
	_cada_frame(FRAMES_ONDA, paso, onda.queue_free)


## Sin()/Cos() de trig.c: tabla de 256 pasos con amplitud 256 y desplazamiento
## aritmético (redondea hacia -infinito).
static func _seno_gba(fase: float, amplitud: int) -> float:
	return floorf(roundf(sin(fase) * 256.0) * amplitud / 256.0)

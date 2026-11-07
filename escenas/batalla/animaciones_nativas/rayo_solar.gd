extends EfectoMovimientoNativo
## Rayo Solar (Move_SOLAR_BEAM). rayo_solar.tscn tiene «carga» (_81CED73) y
## «ataque» (_81CEE70); la pista decide cuándo sale cada orbe, el tinte del
## atacante/defensor y el fondo (fadetobg 25/24 y restorebg en la capa Fondo).
## Aquí viven las trayectorias:
## - orbe de carga (gBattleAnimSpriteTemplate_83D62EC, sub_80CA7B0): del centro
##   del atacante + offset (x reflejada) a su centro en 16 frames, encogiendo
##   5/256 por frame, semitransparente (setalpha 12, 8);
## - orbe del rayo (83D6304, sub_80CA800): del centro del atacante +15 al del
##   defensor en 20 frames, con la imagen `indice` (0..6) de la tira de orbes;
## - orbe ondulante (gSpriteTemplate_83D631C, tarea sub_80CA928): igual pero en
##   80 frames, con una onda de ±5 px en x y ±14 px en y (15/256 de vuelta por frame).

const FRAMES_CARGA: int = 16
const FRAMES_RAYO: int = 20
const FRAMES_ONDULANTE: int = 80
const SALIDA_RAYO: float = 15.0

@onready var plantilla_carga: Sprite2D = $PlantillaCarga
@onready var plantilla_rayo: Sprite2D = $PlantillaRayo
@onready var plantilla_ondulante: Sprite2D = $PlantillaOndulante
@onready var imagen_fondo: Sprite2D = $Fondo/Imagen

## Fondos del original: BG_SOLARBEAM_PLAYER si el objetivo es el rival y
## BG_SOLARBEAM_OPPONENT si el objetivo es del jugador (sub_812C924).
@export var fondo_objetivo_rival: Texture2D
@export var fondo_objetivo_jugador: Texture2D


func _al_configurar() -> void:
	imagen_fondo.texture = fondo_objetivo_rival if direccion > 0.0 else fondo_objetivo_jugador
	if concurso:
		imagen_fondo.texture = load(RUTA_FONDO_RAYO_SOLAR_CONCURSO) as Texture2D


## Pista de método: orbe que converge en el atacante desde `desde` (x reflejada).
func emitir_orbe_carga(desde: Vector2) -> void:
	var orbe: Sprite2D = _instanciar_plantilla(plantilla_carga) as Sprite2D
	var centro: Vector2 = marca_atacante.position
	var inicio: Vector2 = centro + Vector2(desde.x * direccion, desde.y)
	var paso: Callable = func(i: int) -> void:
		orbe.position = inicio.lerp(centro, float(i) / FRAMES_CARGA).floor()
		orbe.scale = Vector2.ONE * (256.0 - 5.0 * i) / 256.0
	_cada_frame(FRAMES_CARGA, paso, orbe.queue_free)


## Pista de método: orbe del rayo con la imagen `indice` (0..6).
func emitir_orbe(indice: int) -> void:
	var orbe: Sprite2D = _instanciar_plantilla(plantilla_rayo) as Sprite2D
	orbe.frame = indice
	var inicio: Vector2 = marca_atacante.position + Vector2(SALIDA_RAYO * direccion, 0.0)
	var final: Vector2 = marca_defensor.position
	var paso: Callable = func(i: int) -> void:
		orbe.position = inicio.lerp(final, float(i) / FRAMES_RAYO).floor()
	_cada_frame(FRAMES_RAYO, paso, orbe.queue_free)


## Pista de método: orbe ondulante de la tarea sub_80CA928.
func emitir_orbe_ondulante() -> void:
	var orbe: Sprite2D = _instanciar_plantilla(plantilla_ondulante) as Sprite2D
	var inicio: Vector2 = marca_atacante.position + Vector2(SALIDA_RAYO * direccion, 0.0)
	var final: Vector2 = marca_defensor.position
	var paso: Callable = func(i: int) -> void:
		var fase: float = TAU * ((15 * i) % 256) / 256.0
		var onda: Vector2 = Vector2(floorf(roundf(sin(fase) * 256.0) * 5.0 / 256.0), floorf(roundf(cos(fase) * 256.0) * 14.0 / 256.0))
		orbe.position = inicio.lerp(final, float(i) / FRAMES_ONDULANTE).floor() + onda
	_cada_frame(FRAMES_ONDULANTE, paso, orbe.queue_free)

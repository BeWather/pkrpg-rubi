class_name BurbujasAlga
extends Node2D

## Burbujas al terminar un paso sobre algas (FLDEFF_BUBBLES de pokeruby).
##
## - event_object_movement.c: GetGroundEffectFlags_Seaweed solo está en
##   GetAllGroundEffectFlags_OnFinishStep (no al empezar el paso ni al aparecer)
##   y vale para cualquier objeto de evento, jugador o NPC, en una celda
##   MB_SEAWEED o MB_SEAWEED_NO_SURFACING (bandera ALGA). GroundEffect_Seaweed
##   lanza el efecto en currentCoords, la celda de llegada.
## - field_effect_helpers.c, FldEff_Bubbles: sub_8060470(x, y, 8, 0) pasa la
##   celda a píxeles (esquina superior izquierda) y suma (8, 0): el centro del
##   sprite de 16×32 queda en el centro del borde superior de la celda.
## - UpdateBubblesFieldEffect: `data[0] += 0x80; data[0] &= 0x100; y -= data[0]
##   >> 8`. Tal como está escrito, data[0] empieza en 0 y 0x80 & 0x100 = 0, así
##   que se queda siempre en 0 y el sprite NO se mueve: la subida que se ve es
##   la de los propios frames del gráfico. Se reproduce la fórmula literal (la
##   intención aparente, 1 px cada 2 frames, necesitaría restar antes del AND).
##   Se detiene en el frame siguiente a que la animación llegue a ANIMCMD_END.
## - field_effect_objects.h: 8 frames con duraciones 4,4,4,6,6,4,4,4 (las del
##   SpriteFrames, a 60 fps) y prioridad OAM 1: por encima del jugador (que va en
##   el nodo NPCs con z relativo 0), de ahí el z_index relativo 1 de la escena.

const RUTA_ESCENA := "res://escenas/mapas/animaciones/burbujas_alga.tscn"
const ANIMACION := &"default"
const FRAMES_POR_SEGUNDO: float = ConstantesGba.FPS
## Máximo de frames simulados en un solo _process (evita espirales tras un tirón).
const MAX_FRAMES_POR_PROCESO := 8
## sub_8060470(x, y, 8, 0) desde la esquina superior izquierda de la celda.
const DESPLAZAMIENTO_CELDA := Vector2(8.0, 0.0)
const TAMANO_CELDA := 16
## UpdateBubblesFieldEffect: data[0] += 0x80; data[0] &= 0x100.
const PASO_SUBIDA := 0x80
const MASCARA_SUBIDA := 0x100

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

## data[0] de UpdateBubblesFieldEffect.
var _contador_subida: int = 0
## Pasos de animación dados (AnimateSprites) desde que se creó.
var _pasos_animacion: int = 0
var _animacion_acabada: bool = false
var _terminada: bool = false
var _acumulador_frames: float = 0.0


## Crea las burbujas en `contenedor` si `celda` (local al mapa de `tp`) tiene la
## bandera ALGA. `origen` es la posición del mapa en el espacio del contenedor
## (Vector2.ZERO si el contenedor pertenece al mapa). Devuelve null si no aplica.
static func crear_si_alga(tp: TPTileDataMap, celda: Vector2i, contenedor: Node, origen: Vector2 = Vector2.ZERO) -> BurbujasAlga:
	if tp == null or contenedor == null:
		return null
	if not tp.has_flag(Vector2(celda), TPTileDataMap.Flags.ALGA):
		return null
	var escena := load(RUTA_ESCENA) as PackedScene
	var burbujas := escena.instantiate() as BurbujasAlga
	burbujas.position = origen + posicion_para_celda(celda)
	contenedor.add_child(burbujas)
	return burbujas


## Centro del sprite para una celda local del mapa.
static func posicion_para_celda(celda: Vector2i) -> Vector2:
	return Vector2(celda * TAMANO_CELDA) + DESPLAZAMIENTO_CELDA


func _ready() -> void:
	_sprite.stop()
	_sprite.animation = ANIMACION
	_sprite.frame = 0


func _process(delta: float) -> void:
	_acumulador_frames += maxf(0.0, delta) * FRAMES_POR_SEGUNDO
	var pasos: int = 0
	while _acumulador_frames >= 1.0 and pasos < MAX_FRAMES_POR_PROCESO and not _terminada:
		_acumulador_frames -= 1.0
		avanzar_frame()
		pasos += 1
	if _acumulador_frames >= 1.0:
		_acumulador_frames = fmod(_acumulador_frames, 1.0)


## Un frame del GBA: primero el callback (subida y fin) y después la animación.
func avanzar_frame() -> void:
	if _terminada:
		return
	_contador_subida = (_contador_subida + PASO_SUBIDA) & MASCARA_SUBIDA
	_sprite.position.y -= float(_contador_subida >> 8)
	if _animacion_acabada:
		_terminada = true
		queue_free()
		return
	_pasos_animacion += 1
	if _pasos_animacion > obtener_total_frames_animacion():
		_animacion_acabada = true
	else:
		_sprite.frame = frame_para_paso(_pasos_animacion)


## Avanza `frames` frames del GBA (tests y depuración).
func avanzar_frames(frames: int) -> void:
	for _frame: int in range(maxi(frames, 0)):
		avanzar_frame()


## Frames del GBA que dura la animación (suma de duraciones del SpriteFrames).
func obtener_total_frames_animacion() -> int:
	var total: int = 0
	for indice: int in range(_sprite.sprite_frames.get_frame_count(ANIMACION)):
		total += roundi(_sprite.sprite_frames.get_frame_duration(ANIMACION, indice))
	return total


## Frame que muestra el paso de animación `paso` (1 = primer frame del GBA).
func frame_para_paso(paso: int) -> int:
	var acumulado: int = 0
	var cantidad: int = _sprite.sprite_frames.get_frame_count(ANIMACION)
	for indice: int in range(cantidad):
		acumulado += roundi(_sprite.sprite_frames.get_frame_duration(ANIMACION, indice))
		if paso <= acumulado:
			return indice
	return cantidad - 1


## Píxeles subidos desde que se creó.
func obtener_subida() -> int:
	return roundi(-_sprite.position.y)


func obtener_frame() -> int:
	return _sprite.frame


func esta_terminada() -> bool:
	return _terminada

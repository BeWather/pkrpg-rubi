## efecto_destello.gd
## FLDEFF_SPARKLE (pokeruby src/field_effect_helpers.c:1320, `FldEff_Sparkle`): el destello
## que la CASA TRETA hace sobre el escondite del MAESTRO con 0, 1 o 2 salas. Dibuja
## `graficos/brillo_simple.png` (64×16 = 4 cuadros de 16×16: tres visibles y uno vacío)
## con los tiempos de la ROM, en ticks de 1/60 s:
##
##   ticks 0-2   cuadro 0 (pequeño)         3 ticks
##   ticks 3-7   cuadro 1 (grande)          5 ticks
##   ticks 8-12  cuadro 2 (= cuadro 0 de la ROM, 0-1-0)  5 ticks
##   ticks 13-47 cuadro 3 (vacío)           35 ticks (`UpdateSparkleFieldEffect`: ++data[1] > 34)
##   tick 48     FieldEffectStop: termina `waitfieldeffect`
##
## Sin sonido. El sprite se centra en la celda ((celda × 16) + (8, 8)), no en el ancla de
## pies (8, 14) de los NPC.
class_name EfectoDestello
extends Node2D

const TEXTURA: Texture2D = preload("res://graficos/brillo_simple.png")
const TAMANO_CUADRO: int = 16
const FOTOGRAMAS_POR_SEGUNDO: float = 60.0
## Duración en ticks de cada cuadro del atlas (el último es el vacío).
const TICKS_POR_CUADRO: Array[int] = [3, 5, 5, 35]
const ANIMACION: StringName = &"destello"
## Por encima del suelo y de los NPC (NPCs usa z_index = 1).
const Z_INDEX_DESTELLO: int = 10

signal terminado

var celda: Vector2i = Vector2i.ZERO
var sprite: AnimatedSprite2D = null


## Duración total en segundos (48 ticks ≈ 0,8 s).
static func duracion_total() -> float:
	var ticks := 0
	for t in TICKS_POR_CUADRO:
		ticks += t
	return ticks / FOTOGRAMAS_POR_SEGUNDO


## SpriteFrames de una sola animación sin bucle: un AtlasTexture por cuadro y la duración
## relativa en ticks (con la animación a 60 fps, 1 de duración = 1 tick).
static func crear_cuadros() -> SpriteFrames:
	var cuadros := SpriteFrames.new()
	cuadros.remove_animation(&"default")
	cuadros.add_animation(ANIMACION)
	cuadros.set_animation_loop(ANIMACION, false)
	cuadros.set_animation_speed(ANIMACION, FOTOGRAMAS_POR_SEGUNDO)
	for i in TICKS_POR_CUADRO.size():
		var region := AtlasTexture.new()
		region.atlas = TEXTURA
		region.region = Rect2(i * TAMANO_CUADRO, 0, TAMANO_CUADRO, TAMANO_CUADRO)
		cuadros.add_frame(ANIMACION, region, float(TICKS_POR_CUADRO[i]))
	return cuadros


## Crea el efecto en `celda` como hijo de `padre` y lo arranca. Libera el nodo al terminar.
static func lanzar(padre: Node, celda_destino: Vector2i) -> EfectoDestello:
	var efecto := EfectoDestello.new()
	efecto.celda = celda_destino
	padre.add_child(efecto)
	return efecto


func _ready() -> void:
	z_index = Z_INDEX_DESTELLO
	position = Vector2(celda.x * TAMANO_CUADRO + 8, celda.y * TAMANO_CUADRO + 8)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = crear_cuadros()
	add_child(sprite)
	sprite.animation_finished.connect(_al_terminar_animacion)
	sprite.play(ANIMACION)


func _al_terminar_animacion() -> void:
	terminado.emit()
	queue_free()

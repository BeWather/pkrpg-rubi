## pajaro_vuelo_npc.gd
## FLDEFF_NPCFLY_OUT (pokeruby src/field_effect.c, FldEff_NPCFlyOut + sub_8088BC4): el pájaro que
## cruza la pantalla en arco cuando un personaje se marcha volando. Nace en lo alto y en el centro
## de la pantalla: x2 = Cos(fase, 140), y2 = Sin(fase, 72), con la fase sumando 4 por fotograma
## (256 = vuelta completa) hasta 128, o sea 32 fotogramas.
extends Sprite2D
class_name PajaroVueloNpc

signal terminado

const AMPLITUD := Vector2(140.0, 72.0)
const FASE_POR_FOTOGRAMA: float = 4.0
const FASE_FINAL: float = 128.0
const FASES_POR_VUELTA: float = 256.0
const FOTOGRAMAS_POR_SEGUNDO: float = 60.0

var _origen: Vector2 = Vector2.ZERO
var _fase: float = 0.0


func _ready() -> void:
	# Lo alto y el centro de la pantalla, como CreateSprite(..., 0x78, 0, 1).
	var pantalla := get_viewport().get_visible_rect().size
	_origen = get_viewport().get_canvas_transform().affine_inverse() * Vector2(pantalla.x / 2.0, 0.0)
	_colocar()


func _process(delta: float) -> void:
	_fase += delta * FOTOGRAMAS_POR_SEGUNDO * FASE_POR_FOTOGRAMA
	if _fase >= FASE_FINAL:
		terminado.emit()
		queue_free()
		return
	_colocar()


func _colocar() -> void:
	var angulo := _fase / FASES_POR_VUELTA * TAU
	global_position = _origen + Vector2(cos(angulo) * AMPLITUD.x, sin(angulo) * AMPLITUD.y)

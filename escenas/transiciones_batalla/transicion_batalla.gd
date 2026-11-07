## Base de las transiciones de batalla del overworld (battle_transition.c de
## pokeruby). Cada escena es una Control de 240x160 con un AnimationPlayer cuya
## animación `transicion` reproduce la fase a 60 fps (horneada desde el decomp);
## el script solo la arranca y avisa al terminar.
##   - Fase 1 (Phase1Task_TransitionAll): fase1_destellos.tscn.
##   - Fase 2 (sPhase2_Tasks[B_TRANSITION_*]): ver CatalogoTransicionesBatalla.
class_name TransicionBatalla
extends Control

## La animación llegó a su último frame. Se emite una vez por cada iniciar().
signal terminada

const ANIMACION: StringName = &"transicion"

## Las fases 2 acaban con sub_811D6D4 (BlendPalettes a negro): la última clave
## deja la pantalla negra y la capa no debe quitarse hasta que algo la tape.
## La fase 1 termina con el mapa visible.
@export var termina_en_negro: bool = true

var _en_curso: bool = false

@onready var _animacion: AnimationPlayer = $AnimationPlayer


## Arranca la transición desde el principio. Si ya estaba en curso, se reinicia
## y la ejecución anterior ya no emite `terminada`.
func iniciar() -> void:
	_preparar()
	if not _animacion.animation_finished.is_connected(_al_terminar_animacion):
		_animacion.animation_finished.connect(_al_terminar_animacion)
	_en_curso = true
	_animacion.stop()
	_animacion.play(ANIMACION)


func esta_en_curso() -> bool:
	return _en_curso


## Duración de la animación en frames de GBA (60 fps).
func duracion_frames() -> int:
	return roundi(_animacion.get_animation(ANIMACION).length * ConstantesGba.FPS)


## Ajustes previos al arranque (lado aleatorio, sexo del jugador...).
func _preparar() -> void:
	pass


func _al_terminar_animacion(nombre: StringName) -> void:
	if nombre != ANIMACION or not _en_curso:
		return
	_en_curso = false
	terminada.emit()

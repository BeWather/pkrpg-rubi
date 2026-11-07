extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	visible = false
	if _es_escena_ejecutada_sola():
		reproducir_transicion_ball()

func _es_escena_ejecutada_sola() -> bool:
	# La escena se ejecuta sola si es root del árbol de juego completo
	return get_tree() != null and get_tree().current_scene == self

func reproducir_transicion_ball(color_overlay: ColorRect = null) -> void:
	visible = true
	# Esta escena tiene su propio fondo (ColorRect). Ocultamos el overlay
	# blanco del padre en cuanto la transición empieza a cubrir la pantalla.
	if color_overlay != null:
		color_overlay.visible = false
	animation_player.play("campo")
	await animation_player.animation_finished

## Detiene la transicion en curso y oculta la escena. stop() no emite
## animation_finished, por lo que la corrutina que la esperaba queda
## suspendida sin efectos secundarios.
func detener() -> void:
	animation_player.stop()
	visible = false

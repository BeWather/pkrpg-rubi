extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	visible = false
	animation_player.play("RESET")
	if _es_escena_ejecutada_sola():
		await animation_player.animation_finished
		reproducir_animacion()

func _es_escena_ejecutada_sola() -> bool:
	# La escena se ejecuta sola si es root del árbol de juego completo
	return get_tree() != null and get_tree().current_scene == self

func _process(delta: float) -> void:
	pass

func reproducir_animacion(
	color_overlay: ColorRect = null
) -> void:
	visible = true
	if color_overlay != null:
		color_overlay.visible = false
	animation_player.play("intro")
	await animation_player.animation_finished
	if color_overlay != null:
		visible = false
		color_overlay.visible = true

## Adelanta la animacion "intro" casi hasta su final, dejando un pequeno
## margen para que el reproductor la complete de forma natural: asi se emite
## animation_finished y quien la esperaba continua. La animacion queda
## asentada en su estado final (no se cancela).
func terminar_animacion() -> void:
	if animation_player.is_playing() and animation_player.current_animation == "intro":
		var posicion_final: float = maxf(animation_player.current_animation_length - 0.05, 0.0)
		animation_player.seek(posicion_final, true)

## Detiene la animacion en curso y oculta la escena. stop() no emite
## animation_finished, por lo que la corrutina que la esperaba queda
## suspendida sin efectos secundarios.
func detener() -> void:
	animation_player.stop()
	visible = false

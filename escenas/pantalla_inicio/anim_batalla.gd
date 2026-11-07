extends Node2D

const ANIMACION_DEFECTO: String = "chica"

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var btl_jugador: AnimatedSprite2D = $btlJugador

func _ready() -> void:
	visible = false
	animation_player.play("RESET")
	if _es_escena_ejecutada_sola():
		await animation_player.animation_finished
		reproducir_animacion()

func _es_escena_ejecutada_sola() -> bool:
	# La escena se ejecuta sola si es root del árbol de juego completo
	return get_tree() != null and get_tree().current_scene == self

func reproducir_animacion(
	color_overlay: ColorRect = null,
	animacion_jugador: String = ANIMACION_DEFECTO
) -> void:
	# La animacion anterior pudo dejar un destello blanco cubriendo la
	# escena; si la intro se vuelve a reproducir (ciclo de atraccion), hay
	# que retirarlo antes de mostrar nada.
	_retirar_destello()
	visible = true
	if color_overlay != null:
		color_overlay.visible = false
	seleccionar_personaje(animacion_jugador)
	animation_player.play("batalla")
	await animation_player.animation_finished
	if color_overlay != null:
		visible = false
		color_overlay.visible = true

## Fija la animacion de `btlJugador` ("chica"/"chico") con validacion:
## si el nombre no existe en sus SpriteFrames, conserva la actual.
func seleccionar_personaje(animacion_jugador: String) -> void:
	var cuadros: SpriteFrames = btl_jugador.sprite_frames
	if cuadros == null or not cuadros.has_animation(animacion_jugador):
		push_warning("Personaje desconocido en btlJugador: %s" % animacion_jugador)
		return
	btl_jugador.animation = animacion_jugador

## Detiene la intro de batalla en curso, retira el destello blanco si seguia
## en pantalla y oculta la escena. stop() no emite animation_finished, por lo
## que la corrutina que la esperaba queda suspendida sin efectos secundarios.
func detener() -> void:
	animation_player.stop()
	_retirar_destello()
	visible = false

## Libera el destello blanco creado dinamicamente por destello_blanco():
## nadie lo retiraba al terminar la animacion y en el ciclo siguiente quedaba
## encima, tapando toda la intro de blanco.
func _retirar_destello() -> void:
	var destello: Node = get_node_or_null("DestelloBlanco")
	if destello == null:
		return
	# get_meta con defecto igual registraria un error si falta la clave.
	if destello.has_meta("tween"):
		(destello.get_meta("tween") as Tween).kill()
	destello.free()

## Crea un color solido blanco del mismo tipo y tamano que `Centro`
## (ColorRect 240x160) pero inicialmente transparente, y lo desvanece
## hacia blanco pleno en `duracion` segundos. Se dibuja encima de todo
## para cubrir la pantalla al final de la animacion.
func destello_blanco(duracion: float = 0.5) -> void:
	var destello := ColorRect.new()
	destello.name = "DestelloBlanco"
	destello.offset_right = 240.0
	destello.offset_bottom = 160.0
	destello.z_index = 100
	destello.mouse_filter = Control.MOUSE_FILTER_IGNORE
	destello.color = Color(1, 1, 1, 0)
	add_child(destello)
	var interpolacion := create_tween()
	# El tween se guarda en un meta para que detener() pueda cortarlo antes
	# de liberar el destello.
	destello.set_meta("tween", interpolacion)
	interpolacion.tween_property(destello, "color:a", 1.0, duracion)

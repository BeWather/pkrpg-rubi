class_name AnimacionEvolucion
extends CanvasLayer

## Animación visual de la evolución con AnimationPlayer (misma secuencia que
## `EscenaEvolucion`: destellos previos, blanco, alternancia de siluetas cada vez
## más rápida y destello). Solo anima imagen: textos, gritos y música los pone
## quien la use entre una fase y otra.
##
## Fases (animaciones del AnimationPlayer):
##  entrada         fundido desde negro
##  transformacion  90 frames previos, a blanco, alternancia y destello
##  vuelta_color    la especie nueva recupera su color
##  cancelar        la especie previa recupera su color (tras detener)
##  salida          fundido a negro
##
## Alternancia de siluetas: la visibilidad se queda SIEMPRE activa (los sprites
## viven sobre el fondo negro y el shader blanco); el intercambio se hace por
## escala, `Vector2.ONE` para la que se muestra y `ESCALA_OCULTA` para la oculta.
##
## Contraparte completa: `EscenaEvolucionAnim`
## (`escenas/evolucion/escena_evolucion_anim.tscn`), que además orquesta
## diálogos, audio y aprendizaje de movimientos (equivalente a
## `EscenaEvolucion`). La contraparte completa ya incluye una secuencia nueva
## con partículas; esta capa visual mantiene de momento la animación anterior.

## Inicio y fin de la alternancia dentro de "transformacion" (se detiene con B).
const INICIO_ALTERNANCIA: float = 2.0
const FIN_ALTERNANCIA: float = 7.9333
## Escala de la silueta oculta. No se usa escala 0 para que la pista siga siendo
## un cambio de estado reversible y la silueta no desaparezca del render.
const ESCALA_OCULTA: Vector2 = Vector2(0.1, 0.1)

@onready var _sprite_previo: Sprite2D = $SpritePrevio
@onready var _sprite_nuevo: Sprite2D = $SpriteNuevo
@onready var _animador: AnimationPlayer = $AnimationPlayer


## Fija las especies (nombres internos). Deja el estado inicial: previa visible, negro.
func preparar(especie_previa: String, especie_nueva: String, shiny: bool = false) -> void:
	_sprite_previo.texture = PokemonSpriteManager.cargar_sprite_frente(especie_previa, shiny)
	_sprite_nuevo.texture = PokemonSpriteManager.cargar_sprite_frente(especie_nueva, shiny)
	_sprite_previo.visible = true
	_sprite_nuevo.visible = true
	_sprite_previo.scale = Vector2.ONE
	_sprite_nuevo.scale = ESCALA_OCULTA
	$Negro.modulate.a = 1.0


func entrada() -> void:
	await _reproducir(&"entrada")


## Devuelve true si se canceló con B (solo si `puede_cancelar`); en ese caso
## queda detenida y hay que llamar a `cancelar()`.
func transformacion(puede_cancelar: bool = true) -> bool:
	_animador.play(&"transformacion")
	while _animador.is_playing():
		var t := _animador.current_animation_position
		if puede_cancelar and t >= INICIO_ALTERNANCIA and t < FIN_ALTERNANCIA \
				and Input.is_action_pressed("btn_cancelar"):
			_animador.stop()
			return true
		await get_tree().process_frame
	return false


func vuelta_color() -> void:
	await _reproducir(&"vuelta_color")


func cancelar() -> void:
	await _reproducir(&"cancelar")


func salida() -> void:
	await _reproducir(&"salida")


func _reproducir(nombre: StringName) -> void:
	_animador.play(nombre)
	await _animador.animation_finished

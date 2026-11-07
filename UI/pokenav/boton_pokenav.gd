@tool
extends Node2D
class_name BotonPokenav

## Botón del POKéNAV: una fila (128x16) de la hoja `hoja`. No hay cursor: la opción
## elegida se adelanta 16 px (sub_80F2148). Los tiempos están en su AnimationPlayer.

@export var hoja: Texture2D:
	set(valor):
		hoja = valor
		_aplicar()
@export var filas_hoja: int = 1:
	set(valor):
		filas_hoja = valor
		_aplicar()
@export var fila: int = 0:
	set(valor):
		fila = valor
		_aplicar()

@onready var sprite: Sprite2D = $Sprite
@onready var anim: AnimationPlayer = $Anim


func _ready() -> void:
	_aplicar()
	if not Engine.is_editor_hint():
		poner_fuera()


func _aplicar() -> void:
	var nodo: Sprite2D = get_node_or_null(^"Sprite") as Sprite2D
	if nodo == null:
		return
	nodo.texture = hoja
	nodo.vframes = maxi(filas_hoja, 1)
	nodo.frame = clampi(fila, 0, nodo.vframes - 1)


## Fuera de pantalla por la derecha: estado inicial antes de `entrar`.
func poner_fuera() -> void:
	anim.play(&"RESET")
	anim.advance(0.0)
	anim.stop()


func reproducir(nombre: StringName) -> void:
	anim.play(nombre)
	await anim.animation_finished

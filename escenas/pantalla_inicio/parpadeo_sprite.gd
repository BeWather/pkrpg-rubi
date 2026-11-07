@tool
extends Sprite2D

## Parpadeo (CirculoChoque).
## Mientras la bandera `parpadear` este activa, intercambia la visibilidad
## del sprite en cada frame. Al desactivarse, el sprite queda oculto.

@export var parpadear: bool = false:
	set(valor):
		parpadear = valor
		if not parpadear:
			visible = false


func _process(_delta: float) -> void:
	if parpadear:
		visible = not visible

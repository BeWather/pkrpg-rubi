class_name NubeCeniza
extends AnimatedSprite2D

## Nube de ceniza (FLDEFF_ASH de Emerald) que salta al limpiar la hierba con
## ceniza. Se reproduce una vez (12/12/8/12/12 frames a 60 fps) y se libera.

const ANIMACION := &"default"


func _ready() -> void:
	set_meta(&"sin_reflejo", true)
	animation_finished.connect(queue_free)
	play(ANIMACION)


## Duración total de la animación en segundos.
func obtener_duracion() -> float:
	if sprite_frames == null or not sprite_frames.has_animation(ANIMACION):
		return 0.0
	var unidades := 0.0
	for indice: int in sprite_frames.get_frame_count(ANIMACION):
		unidades += sprite_frames.get_frame_duration(ANIMACION, indice)
	var velocidad := sprite_frames.get_animation_speed(ANIMACION)
	return unidades / velocidad if velocidad > 0.0 else 0.0

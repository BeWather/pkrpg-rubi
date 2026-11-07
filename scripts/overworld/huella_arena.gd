class_name HuellaArena
extends Sprite2D

## Huella temporal sobre un tile de arena. Permanece visible, parpadea durante el
## tramo final de su vida y se libera sola.

const INTERVALO_PARPADEO := 0.05

var duracion: float = 1.0
var parpadeo: float = 0.4
var _tiempo: float = 0.0


func configurar(
	textura: Texture2D,
	espejo_h: bool,
	espejo_v: bool,
	duracion_total: float = 1.0,
	duracion_parpadeo: float = 0.4
) -> void:
	texture = textura
	flip_h = espejo_h
	flip_v = espejo_v
	duracion = maxf(duracion_total, 0.0)
	parpadeo = clampf(duracion_parpadeo, 0.0, duracion)
	_tiempo = 0.0
	visible = true


func esta_viva() -> bool:
	return _tiempo < duracion


func _process(delta: float) -> void:
	avanzar(delta)


## Separado de `_process` para poder probar el ciclo de vida sin esperar frames.
func avanzar(delta: float) -> void:
	_tiempo += delta
	if not esta_viva():
		queue_free()
		return
	var inicio_parpadeo := duracion - parpadeo
	if _tiempo < inicio_parpadeo:
		visible = true
	else:
		visible = int((_tiempo - inicio_parpadeo) / INTERVALO_PARPADEO) % 2 == 1

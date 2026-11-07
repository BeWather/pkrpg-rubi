## Destello que sale despedido al acertar (sub_805156C / sub_8051524 del decomp).
## Los frames los anima el AnimationPlayer; solo el desplazamiento aleatorio se
## calcula aquí, porque depende de un número al azar por partícula.
class_name ParticulaLicuadora
extends ElementoLicuadora

## Píxeles por fotograma GBA (data[0..1] / 8 en el decomp: entre -2 y +2).
var velocidad := Vector2.ZERO


func _process(delta: float) -> void:
	position += velocidad * ConstantesGba.FPS * delta

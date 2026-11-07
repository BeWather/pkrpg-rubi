class_name EfectoClimaMundoBase
extends Node2D

## Contrato común de los efectos de clima en espacio de MUNDO. El controlador los
## instancia bajo el nodo `AnclaClimaMundo` del mapa actual, así que su posición
## local coincide con la del mapa y heredan su orden de dibujo (p. ej. entre las
## capas `Agua` y `Suelo`). Misma API duck-typed que EfectoClimaBase.

var intensidad: float = 1.0
var factor_mezcla: float = 1.0


func configurar(nueva_intensidad: float) -> void:
	intensidad = clampf(nueva_intensidad, 0.0, 1.0)
	queue_redraw()


func set_factor_mezcla(nuevo_factor: float) -> void:
	factor_mezcla = clampf(nuevo_factor, 0.0, 1.0)
	queue_redraw()


func detener() -> void:
	set_process(false)

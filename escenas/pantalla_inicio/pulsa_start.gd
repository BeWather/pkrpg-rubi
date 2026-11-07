@tool
extends Sprite2D

## Parpadeo controlado del indicador PulsaStart.
## `frecuencia` indica cuántos cambios de visibilidad se realizan por segundo.

@export_category("Parpadeo")
@export var mostrar: bool = false:
	set(valor):
		mostrar = valor
		if not mostrar:
			visible = false
			_acumulador = 0.0

@export_range(0.1, 60.0, 0.1, "or_greater") var frecuencia: float = 4.0

var _acumulador: float = 0.0


func _process(delta: float) -> void:
	if not mostrar or frecuencia <= 0.0:
		return

	_acumulador += delta
	var intervalo: float = 1.0 / frecuencia
	while _acumulador >= intervalo:
		_acumulador -= intervalo
		visible = not visible

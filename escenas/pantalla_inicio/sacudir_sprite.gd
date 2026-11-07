@tool
extends Sprite2D

## Sacudida de Sharpedo (Mon1).
## Mientras `sacudir` esté activo, alterna el `offset` del sprite
## entre (0, 0) y (-1, 1) a la velocidad de `fps_sacudida`.

const OFFSET_REPOSO: Vector2 = Vector2(0, 0)
const OFFSET_SACUDIDA: Vector2 = Vector2(-1, 1)

@export_category("Sacudida")

@export var sacudir: bool = false:
	set(valor):
		sacudir = valor
		if not sacudir:
			offset = OFFSET_REPOSO
			_acumulador = 0.0
			_alternada = false

@export_range(1.0, 60.0, 1.0, "or_greater") var fps_sacudida: float = 30.0

var _acumulador: float = 0.0
var _alternada: bool = false


func _process(delta: float) -> void:
	if not sacudir:
		return

	_acumulador += delta
	var intervalo: float = 1.0 / fps_sacudida
	while _acumulador >= intervalo:
		_acumulador -= intervalo
		_alternada = not _alternada
		offset = OFFSET_SACUDIDA if _alternada else OFFSET_REPOSO

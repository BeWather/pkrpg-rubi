@tool
class_name ZonaClimaEntrada
extends Resource

## Una zona del SelectorClimaEntrada: si la celda del jugador al entrar al mapa
## cae en la unión de `zonas_tiles`, se aplica `clima` de inmediato.

## Rectángulos en celdas locales del mapa (el borde final no se incluye). Pueden
## salirse del mapa: al cruzar un borde el jugador ya cuenta como dentro, pero
## conviene cubrir con margen las celdas negativas o fuera de rango.
@export var zonas_tiles: Array[Rect2i] = []
## Clima de la zona. Vacío equivale a NINGUNO.
@export var clima: DefinicionClima = null
## -1 usa `intensidad_base` del clima.
@export_range(-1.0, 1.0, 0.01) var intensidad: float = -1.0


func contiene(celda: Vector2i) -> bool:
	for rect: Rect2i in zonas_tiles:
		if rect.has_point(celda):
			return true
	return false

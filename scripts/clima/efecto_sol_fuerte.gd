class_name EfectoSolFuerteOverworld
extends EfectoClimaBase

## Filtro de WEATHER_DROUGHT (field_weather_effects.c, Drought_Main): las tablas de
## paleta drought0-5 aclaran por igual los tres canales. Se aproxima con blanco
## aditivo (material de la escena), con el alfa ajustado a cada tabla.

## Fotogramas del GBA por segundo: sub_807DA4C avanza una vez por fotograma.
const TICKS_POR_SEGUNDO: float = 59.7275
## Alfa aditivo de las tablas 1 a 5 (índice 0 = tabla 1).
const ALFA_POR_TABLA: PackedFloat32Array = [0.040, 0.063, 0.084, 0.110, 0.137]
## Fase inicial del pulso (unknown_740 = 0x3C).
const FASE_INICIAL: int = 60
const PASO_FASE: int = 3

var _fase: int = FASE_INICIAL
var _tabla: int = tabla_de_fase(FASE_INICIAL)
var _acumulado: float = 0.0


func _ready() -> void:
	super._ready()
	set_process(true)


func _process(delta: float) -> void:
	_acumulado += delta * TICKS_POR_SEGUNDO
	var ticks: int = int(_acumulado)
	if ticks == 0:
		return
	_acumulado -= ticks
	_fase = (_fase + ticks * PASO_FASE) & 0x7F
	var tabla: int = tabla_de_fase(_fase)
	if tabla != _tabla:
		_tabla = tabla
		queue_redraw()


func _draw() -> void:
	if intensidad <= 0.0 or factor_mezcla <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 1.0, 1.0, alfa_de_tabla(_tabla) * intensidad * factor_mezcla))


## unknown_73C = ((gSineTable[fase] - 1) >> 6) + 2, con fase en 0..127.
static func tabla_de_fase(fase: int) -> int:
	var seno: int = floori(256.0 * sin(TAU * float(fase & 0x7F) / 256.0))
	return ((seno - 1) >> 6) + 2


static func alfa_de_tabla(tabla: int) -> float:
	return ALFA_POR_TABLA[clampi(tabla, 1, ALFA_POR_TABLA.size()) - 1]

class_name EfectoTormentaOverworld
extends EfectoLluviaOverworld

## Tormenta (WEATHER_RAIN_MED de pokeruby): mismo movimiento que la lluvia ligera
## pero con 16 gotas que se activan una cada 5 frames. Conserva los destellos.

@export var destellos_habilitados: bool = true
@export_range(0.0, 0.8, 0.01) var alpha_max_destello: float = 0.34
@export var intervalo_minimo: float = 1.2
@export var intervalo_maximo: float = 4.5

var _rng_destellos := RandomNumberGenerator.new()
var _tiempo_hasta_destello: float = 2.0
var _alpha_destello: float = 0.0


func _init() -> void:
	super._init()
	max_gotas = 16
	frames_por_gota = 5


func _ready() -> void:
	_rng_destellos.seed = 804_221
	super._ready()
	_programar_destello()


func _process(delta: float) -> void:
	super._process(delta)
	if not destellos_habilitados or intensidad <= 0.0:
		_alpha_destello = 0.0
		return
	if _alpha_destello > 0.0:
		_alpha_destello = maxf(0.0, _alpha_destello - delta * 2.8)
	else:
		_tiempo_hasta_destello -= delta
		if _tiempo_hasta_destello <= 0.0:
			_alpha_destello = alpha_max_destello * intensidad
			_programar_destello()


func _draw() -> void:
	super._draw()
	if _alpha_destello <= 0.0 or factor_mezcla <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.9, 0.95, 1.0, _alpha_destello * factor_mezcla))


func detener() -> void:
	_alpha_destello = 0.0
	super.detener()


func _programar_destello() -> void:
	var minimo: float = minf(intervalo_minimo, intervalo_maximo)
	var maximo: float = maxf(intervalo_minimo, intervalo_maximo)
	_tiempo_hasta_destello = _rng_destellos.randf_range(minimo, maximo)

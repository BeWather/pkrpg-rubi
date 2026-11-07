@tool
extends Node2D

const STAR_COUNT: int = 8
const ANGLE_STEP: float = TAU / float(STAR_COUNT)

@export_category("Animacion de estrellas")
@export_range(0.0, 1000.0, 1.0, "or_greater") var distancia: float = 40.0:
	set(value):
		distancia = value
		_reiniciar_si_corresponde()
@export_range(0.01, 10.0, 0.01, "or_greater") var duracion: float = 0.54:
	set(value):
		duracion = value
		_reiniciar_si_corresponde()
@export var velocidad_rotacion: float = 360.0:
	set(value):
		velocidad_rotacion = value
		_reiniciar_si_corresponde()
@export_range(0.0, 10.0, 0.01, "or_greater") var espera: float = 1.0:
	set(value):
		espera = value
		_reiniciar_si_corresponde()
@export var alternar_visibilidad: bool = true:
	set(value):
		alternar_visibilidad = value
		_reiniciar_si_corresponde()
@export var reproducir_en_editor: bool = true:
	set(value):
		reproducir_en_editor = value
		_reiniciar_si_corresponde()
@export var textura_brillo: SpriteFrames

enum Fase { EXPANSION, ESPERA }

var _estrellas: Array[AnimatedSprite2D] = []
var _direcciones: Array[Vector2] = []
var _fase: Fase = Fase.EXPANSION
var _tiempo_fase: float = 0.0
var _distancia_actual: float = 40.0
var _duracion_actual: float = 0.54
var _espera_actual: float = 1.0
var _velocidad_rotacion_actual: float = 360.0
var _animacion_activa: bool = false
var _es_bucle: bool = false
var _frame_visibilidad: int = 0


func _ready() -> void:
	if textura_brillo == null:
		push_warning("estrellas_apertura: falta asignar 'textura_brillo'")
		return
	_asegurar_estrellas()
	_reiniciar_estrellas()
	set_process(true)


func _process(delta: float) -> void:
	if _estrellas.is_empty():
		if textura_brillo != null:
			_asegurar_estrellas()
		return

	if Engine.is_editor_hint() and reproducir_en_editor and not _animacion_activa:
		_iniciar_animacion(distancia, duracion, velocidad_rotacion, espera, true)

	if not _animacion_activa:
		return

	_frame_visibilidad += 1
	_rotar_estrellas(delta)

	if _fase == Fase.EXPANSION:
		_tiempo_fase += delta
		var progreso: float = 1.0 if _duracion_actual <= 0.0 else minf(_tiempo_fase / _duracion_actual, 1.0)
		_actualizar_estrellas(progreso)
		if progreso >= 1.0:
			_fase = Fase.ESPERA
			_tiempo_fase = 0.0
			_ocultar_estrellas()
	else:
		_tiempo_fase += delta
		if _tiempo_fase >= _espera_actual:
			if _es_bucle:
				_iniciar_animacion(_distancia_actual, _duracion_actual, _velocidad_rotacion_actual, _espera_actual, true)
			else:
				_reiniciar_estrellas()
				_animacion_activa = false


func reproducir_brillo(
	distancia_parametro: float = -1.0,
	duracion_parametro: float = -1.0,
	velocidad_rotacion_parametro: float = -1.0
) -> void:
	var distancia_animacion: float = distancia if distancia_parametro < 0.0 else distancia_parametro
	var duracion_animacion: float = duracion if duracion_parametro < 0.0 else duracion_parametro
	var velocidad_rotacion_animacion: float = velocidad_rotacion if velocidad_rotacion_parametro < 0.0 else velocidad_rotacion_parametro
	_iniciar_animacion(
		distancia_animacion,
		duracion_animacion,
		velocidad_rotacion_animacion,
		espera,
		false
	)


func _reiniciar_si_corresponde() -> void:
	if not is_node_ready():
		return
	if Engine.is_editor_hint():
		if reproducir_en_editor:
			_iniciar_animacion(distancia, duracion, velocidad_rotacion, espera, true)
		else:
			_animacion_activa = false
			_reiniciar_estrellas()
	elif _animacion_activa:
		_iniciar_animacion(distancia, duracion, velocidad_rotacion, espera, _es_bucle)


func _asegurar_estrellas() -> void:
	_estrellas.clear()
	_direcciones.clear()

	for i in STAR_COUNT:
		var star: AnimatedSprite2D = get_node_or_null("Star%d" % i) as AnimatedSprite2D
		if star == null:
			star = AnimatedSprite2D.new()
			add_child(star)
		star.name = "Star%d" % i
		star.sprite_frames = textura_brillo
		star.animation = &"default"
		star.frame = 0
		star.centered = true
		star.position = Vector2.ZERO
		star.visible = false
		_estrellas.append(star)
		_direcciones.append(Vector2.from_angle(-PI / 2.0 + i * ANGLE_STEP))


func _iniciar_animacion(
	distancia_parametro: float,
	duracion_parametro: float,
	velocidad_rotacion_parametro: float,
	espera_parametro: float,
	bucle: bool
) -> void:
	_distancia_actual = maxf(distancia_parametro, 0.0)
	_duracion_actual = maxf(duracion_parametro, 0.01)
	_espera_actual = maxf(espera_parametro, 0.0)
	_velocidad_rotacion_actual = velocidad_rotacion_parametro
	_es_bucle = bucle
	_fase = Fase.EXPANSION
	_tiempo_fase = 0.0
	_frame_visibilidad = 0
	_reiniciar_estrellas()
	_animacion_activa = true


func _actualizar_estrellas(progreso: float) -> void:
	for i in STAR_COUNT:
		var estrella: AnimatedSprite2D = _estrellas[i]
		estrella.position = _direcciones[i] * _distancia_actual * progreso
		estrella.visible = not alternar_visibilidad or (i + _frame_visibilidad) % 2 == 0


func _rotar_estrellas(delta: float) -> void:
	var rotacion: float = deg_to_rad(_velocidad_rotacion_actual) * delta
	for estrella in _estrellas:
		estrella.rotation += rotacion


func _ocultar_estrellas() -> void:
	for estrella in _estrellas:
		estrella.visible = false


func _reiniciar_estrellas() -> void:
	for estrella in _estrellas:
		estrella.position = Vector2.ZERO
		estrella.rotation = 0.0
		estrella.visible = false

@tool
extends Node2D

class GrupoBolas:
	var bolas: Array[AnimatedSprite2D] = []
	var distancia_recorrida: float = 0.0

const BOLAS_POR_GRUPO: int = 3
const SEPARACION_FASE: float = TAU / 3.0

@export_category("Trayectoria")
@export_range(1.0, 1000.0, 1.0, "or_greater") var distancia_maxima: float = 100.0
@export_range(0.0, 100.0, 1.0, "or_greater") var amplitud_maxima: float = 20.0
@export_range(0.0, 100.0, 1.0, "or_greater") var distancia_crecimiento_amplitud: float = 20.0
@export_range(0.0, 30.0, 0.1, "or_greater") var vueltas_sinusoidales: float = 7.0
@export var direccion: Vector2 = Vector2(-1.0, 1.0)
@export_range(1.0, 1000.0, 1.0, "or_greater") var velocidad: float = 80.0

@export_category("Emision")
@export_range(0.0, 120.0, 0.1, "or_greater") var fps_emision: float = 30.0
@export var reproducir_en_editor: bool = true
@export var sprite_frames: SpriteFrames
@export_range(0.0, 0.5, 0.01) var escala_profundidad: float = 0.08

var _grupos: Array[GrupoBolas] = []
var _acumulador_emision: float = 0.0
var _animacion_activa: bool = false
var _es_bucle: bool = false
var _direccion_actual: Vector2 = Vector2(-1.0, 1.0).normalized()
var _normal_actual: Vector2 = Vector2.ZERO
var _configuracion_preview: Array[Variant] = []
var _tiempo_animacion: float = 0.0
var _duracion_emision: float = 0.0


func _ready() -> void:
	_normal_actual = Vector2(-_direccion_actual.y, _direccion_actual.x)
	visibility_changed.connect(_al_cambiar_visibilidad)
	set_process(true)


func _al_cambiar_visibilidad() -> void:
	if not is_visible_in_tree() and _animacion_activa:
		_detener_animacion()


func _process(delta: float) -> void:
	if sprite_frames == null:
		return

	if not is_visible_in_tree():
		if _animacion_activa:
			_detener_animacion()
		return

	if Engine.is_editor_hint():
		var configuracion_actual: Array[Variant] = _obtener_configuracion()
		if reproducir_en_editor:
			if not _animacion_activa or configuracion_actual != _configuracion_preview:
				_iniciar_animacion(true, configuracion_actual)
		else:
			if _animacion_activa:
				_detener_animacion()
			return

	if not _animacion_activa:
		return

	_tiempo_animacion += delta
	_actualizar_grupos(delta)
	if (_es_bucle or _tiempo_animacion < _duracion_emision) and _fps_emision_activo > 0.0:
		_acumulador_emision += delta * _fps_emision_activo
		while _acumulador_emision >= 1.0:
			_acumulador_emision -= 1.0
			_emitir_grupo()


func iniciar_mov(
	distancia_maxima_parametro: float = -1.0,
	amplitud_maxima_parametro: float = -1.0,
	distancia_crecimiento_parametro: float = -1.0,
	vueltas_sinusoidales_parametro: float = -1.0,
	velocidad_parametro: float = -1.0,
	fps_emision_parametro: float = -1.0
) -> void:
	var configuracion: Array[Variant] = _obtener_configuracion()
	if distancia_maxima_parametro >= 0.0:
		configuracion[0] = distancia_maxima_parametro
	if amplitud_maxima_parametro >= 0.0:
		configuracion[1] = amplitud_maxima_parametro
	if distancia_crecimiento_parametro >= 0.0:
		configuracion[2] = distancia_crecimiento_parametro
	if vueltas_sinusoidales_parametro >= 0.0:
		configuracion[3] = vueltas_sinusoidales_parametro
	if velocidad_parametro >= 0.0:
		configuracion[4] = velocidad_parametro
	if fps_emision_parametro >= 0.0:
		configuracion[5] = fps_emision_parametro
	# Bucle permanente: la emision se detiene cuando el nodo deja de ser visible.
	_iniciar_animacion(true, configuracion)


func _obtener_configuracion() -> Array[Variant]:
	return [
		maxf(distancia_maxima, 1.0),
		maxf(amplitud_maxima, 0.0),
		maxf(distancia_crecimiento_amplitud, 0.0),
		maxf(vueltas_sinusoidales, 0.0),
		maxf(velocidad, 0.0),
		maxf(fps_emision, 0.0),
	]


func _iniciar_animacion(bucle: bool, configuracion: Array[Variant]) -> void:
	_detener_animacion()
	_distancia_maxima_activa = configuracion[0]
	_amplitud_maxima_activa = configuracion[1]
	_distancia_crecimiento_activa = configuracion[2]
	_vueltas_sinusoidales_activas = configuracion[3]
	_velocidad_activa = configuracion[4]
	_fps_emision_activo = configuracion[5]
	_direccion_actual = direccion.normalized() if direccion.length_squared() > 0.0 else Vector2(-1.0, 1.0).normalized()
	_normal_actual = Vector2(-_direccion_actual.y, _direccion_actual.x)
	_acumulador_emision = 0.0
	_tiempo_animacion = 0.0
	_duracion_emision = INF if _velocidad_activa <= 0.0 else _distancia_maxima_activa / _velocidad_activa
	_es_bucle = bucle
	_animacion_activa = true
	_configuracion_preview = configuracion.duplicate()
	_emitir_grupo()


func _actualizar_grupos(delta: float) -> void:
	var grupos_terminados: Array[GrupoBolas] = []
	for grupo in _grupos:
		grupo.distancia_recorrida += _velocidad_activa * delta
		var avance: float = grupo.distancia_recorrida
		var fase_base: float = 0.0
		if _distancia_maxima_activa > 0.0:
			fase_base = avance / _distancia_maxima_activa * TAU * _vueltas_sinusoidales_activas
		var amplitud_actual: float = minf(avance, _distancia_crecimiento_activa)
		if _distancia_crecimiento_activa > 0.0:
			amplitud_actual = amplitud_actual / _distancia_crecimiento_activa * _amplitud_maxima_activa
		else:
			amplitud_actual = _amplitud_maxima_activa
		var posicion_base: Vector2 = _direccion_actual * avance

		for indice in BOLAS_POR_GRUPO:
			var fase_bola: float = fase_base + indice * SEPARACION_FASE
			var profundidad: float = sin(fase_bola)
			var bola: AnimatedSprite2D = grupo.bolas[indice]
			bola.position = posicion_base + _normal_actual * profundidad * amplitud_actual
			bola.z_index = int(round(profundidad * 2.0))
			var escala: float = 1.0 + profundidad * escala_profundidad
			bola.scale = Vector2.ONE * escala

		if avance >= _distancia_maxima_activa:
			grupos_terminados.append(grupo)

	for grupo in grupos_terminados:
		_eliminar_grupo(grupo)

	if not _es_bucle and _tiempo_animacion >= _duracion_emision and _grupos.is_empty():
		_animacion_activa = false


func _emitir_grupo() -> void:
	var grupo := GrupoBolas.new()
	for indice in BOLAS_POR_GRUPO:
		var bola: AnimatedSprite2D = AnimatedSprite2D.new()
		bola.name = "Bola%d" % indice
		bola.sprite_frames = sprite_frames
		bola.animation = &"default"
		bola.frame = 0
		bola.centered = true
		bola.z_index = 0
		add_child(bola)
		grupo.bolas.append(bola)
	_grupos.append(grupo)


func _eliminar_grupo(grupo: GrupoBolas) -> void:
	for bola in grupo.bolas:
		bola.queue_free()
	_grupos.erase(grupo)


func _detener_animacion() -> void:
	for grupo in _grupos:
		for bola in grupo.bolas:
			bola.queue_free()
	_grupos.clear()
	_acumulador_emision = 0.0
	_animacion_activa = false


var _distancia_maxima_activa: float = 100.0
var _amplitud_maxima_activa: float = 20.0
var _distancia_crecimiento_activa: float = 20.0
var _vueltas_sinusoidales_activas: float = 7.0
var _velocidad_activa: float = 80.0
var _fps_emision_activo: float = 30.0

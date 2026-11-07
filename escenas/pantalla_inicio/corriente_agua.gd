@tool
extends Node2D

## Corriente de agua (Mon5Efecto).
## Emite gotas que avanzan siempre en `direccion` en linea recta. El valor del
## seno cambia en la distancia 0 (el origen) a medida que se emiten gotas:
## cada gota captura su desvio perpendicular al nacer y lo mantiene constante
## durante toda la trayectoria, formando una cadena con forma de onda que
## avanza con el flujo. Sin profundidad z_index.
## Las gotas emitidas durante los primeros `frames_escala_inicial` frames
## mantienen `escala_inicial` fija; las siguientes ya nacen a escala x1.

class Gota:
	var sprite: AnimatedSprite2D
	var avance: float = 0.0
	var desvio_perpendicular: float = 0.0
	var escala_nacimiento: float = 1.0


@export_category("Corriente")

@export var fluir: bool = false:
	set(valor):
		fluir = valor
		if fluir:
			_iniciar_corriente()
		else:
			_detener_corriente()

@export var reproducir_en_editor: bool = true

@export_category("Sprites")
@export var sprite_frames: SpriteFrames

@export_category("Trayectoria")
@export var direccion: Vector2 = Vector2(1, 0)
@export_range(1.0, 1000.0, 1.0, "or_greater") var velocidad: float = 80.0
@export_range(1.0, 2000.0, 1.0, "or_greater") var distancia_maxima: float = 160.0

@export_category("Ondulacion perpendicular")
@export_range(0.0, 200.0, 1.0, "or_greater") var amplitud_ondulacion: float = 12.0
@export_range(0.0, 30.0, 0.1, "or_greater") var vueltas_ondulacion: float = 2.0
@export_range(0.0, 720.0, 1.0, "or_greater") var velocidad_desfase: float = 0.0

@export_category("Emision")
@export_range(1.0, 120.0, 1.0, "or_greater") var fps_emision: float = 15.0
@export_range(0, 600, 1, "or_greater") var frames_escala_inicial: int = 30
@export_range(0.05, 4.0, 0.05) var escala_inicial: float = 0.5

var _gotas: Array[Gota] = []
var _acumulador_emision: float = 0.0
var _frames_emision: int = 0
var _fase_desfase: float = 0.0
var _corriente_activa: bool = false
var _direccion_actual: Vector2 = Vector2(1, 0)
var _normal_actual: Vector2 = Vector2(0, 1)


func _ready() -> void:
	visibility_changed.connect(_al_cambiar_visibilidad)
	set_process(true)


func _al_cambiar_visibilidad() -> void:
	if not is_visible_in_tree() and _corriente_activa:
		_detener_corriente()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		if _corriente_activa:
			_detener_corriente()
		return

	if Engine.is_editor_hint():
		if fluir and reproducir_en_editor and not _corriente_activa:
			_iniciar_corriente()
		elif (not fluir or not reproducir_en_editor) and _corriente_activa:
			_detener_corriente()
		if not _corriente_activa:
			return
	elif not _corriente_activa:
		return

	_frames_emision += 1
	# El seno cambia en la distancia 0: la fase avanza con el tiempo de emision
	# al ritmo que la corriente recorre una longitud de onda completa.
	_fase_desfase += (
		velocidad / distancia_maxima * TAU * vueltas_ondulacion
		+ deg_to_rad(velocidad_desfase)
	) * delta
	_acumulador_emision += delta * fps_emision
	while _acumulador_emision >= 1.0:
		_acumulador_emision -= 1.0
		_emitir_gota()
	_actualizar_gotas(delta)


func _iniciar_corriente() -> void:
	_detener_corriente()
	if sprite_frames == null:
		return
	_direccion_actual = direccion.normalized() if direccion.length_squared() > 0.0 else Vector2(1, 0)
	_normal_actual = Vector2(-_direccion_actual.y, _direccion_actual.x)
	_acumulador_emision = 0.0
	_frames_emision = 0
	_fase_desfase = 0.0
	_corriente_activa = true
	_emitir_gota()


func _emitir_gota() -> void:
	var gota := Gota.new()
	gota.avance = 0.0
	# La gota captura el seno en la distancia 0 y lo mantiene toda la trayectoria.
	gota.desvio_perpendicular = sin(_fase_desfase) * amplitud_ondulacion
	gota.escala_nacimiento = escala_inicial if _frames_emision < frames_escala_inicial else 1.0
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.sprite_frames = sprite_frames
	sprite.animation = &"default"
	sprite.frame = 0
	sprite.centered = true
	add_child(sprite)
	sprite.play()
	gota.sprite = sprite
	_gotas.append(gota)


func _actualizar_gotas(delta: float) -> void:
	var gotas_terminadas: Array[Gota] = []
	for gota in _gotas:
		gota.avance += velocidad * delta
		gota.sprite.position = _posicion_gota(gota.avance, gota.desvio_perpendicular)
		gota.sprite.scale = Vector2.ONE * gota.escala_nacimiento
		if gota.avance >= distancia_maxima:
			gotas_terminadas.append(gota)

	for gota in gotas_terminadas:
		gota.sprite.queue_free()
		_gotas.erase(gota)


# --- HISTORICO: oscilacion por avance (cada gota ondulaba en su recorrido) ---
#func _posicion_gota(avance: float) -> Vector2:
#	var fase: float = avance / distancia_maxima * TAU * vueltas_ondulacion + _fase_desfase
#	return _direccion_actual * avance + _normal_actual * sin(fase) * amplitud_ondulacion
# -----------------------------------------------------------------------------


## Desvio fijo capturado al nacer: la gota avanza en linea recta paralela a
## `direccion`, conservando el desvio perpendicular que tenia el seno en la
## distancia 0 al momento de su emision.
func _posicion_gota(avance: float, desvio_perpendicular: float) -> Vector2:
	return _direccion_actual * avance + _normal_actual * desvio_perpendicular


func _detener_corriente() -> void:
	for gota in _gotas:
		gota.sprite.queue_free()
	_gotas.clear()
	_acumulador_emision = 0.0
	_corriente_activa = false

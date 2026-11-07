@tool
extends Node2D

## Lanzallamas (Mon6Efecto).
## Todas las particulas nacen del mismo punto (el origen del nodo) y viajan
## en linea recta hasta un punto aleatorio dentro de la amplitud final,
## formando un cono de fuego en `direccion`. Cada particula crece de
## `escala_origen` a `escala_final` a lo largo del recorrido. Sin z_index.

class Particula:
	var sprite: AnimatedSprite2D
	var avance: float = 0.0
	var desvio_final: float = 0.0


@export_category("Lanzallamas")

@export var disparar: bool = false:
	set(valor):
		disparar = valor
		if disparar:
			_iniciar_lanzallamas()
		else:
			_detener_lanzallamas()

@export var reproducir_en_editor: bool = true

@export_category("Sprites")
@export var sprite_frames: SpriteFrames

@export_category("Trayectoria")
@export var direccion: Vector2 = Vector2(1, 0)
@export_range(1.0, 1000.0, 1.0, "or_greater") var velocidad: float = 120.0
@export_range(1.0, 2000.0, 1.0, "or_greater") var distancia_maxima: float = 160.0
@export_range(0.0, 500.0, 1.0, "or_greater") var amplitud_final: float = 40.0

@export_category("Escala")
@export_range(0.05, 4.0, 0.05) var escala_origen: float = 0.3
@export_range(0.05, 4.0, 0.05) var escala_final: float = 1.5

@export_category("Emision")
@export_range(1.0, 120.0, 1.0, "or_greater") var fps_emision: float = 20.0

var _particulas: Array[Particula] = []
var _acumulador_emision: float = 0.0
var _lanzallamas_activo: bool = false
var _direccion_actual: Vector2 = Vector2(1, 0)
var _normal_actual: Vector2 = Vector2(0, 1)


func _ready() -> void:
	visibility_changed.connect(_al_cambiar_visibilidad)
	set_process(true)


func _al_cambiar_visibilidad() -> void:
	if not is_visible_in_tree() and _lanzallamas_activo:
		_detener_lanzallamas()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		if _lanzallamas_activo:
			_detener_lanzallamas()
		return

	if Engine.is_editor_hint():
		if disparar and reproducir_en_editor and not _lanzallamas_activo:
			_iniciar_lanzallamas()
		elif (not disparar or not reproducir_en_editor) and _lanzallamas_activo:
			_detener_lanzallamas()
		if not _lanzallamas_activo:
			return
	elif not _lanzallamas_activo:
		return

	_acumulador_emision += delta * fps_emision
	while _acumulador_emision >= 1.0:
		_acumulador_emision -= 1.0
		_emitir_particula()
	_actualizar_particulas(delta)


func _iniciar_lanzallamas() -> void:
	_detener_lanzallamas()
	if sprite_frames == null:
		return
	_direccion_actual = direccion.normalized() if direccion.length_squared() > 0.0 else Vector2(1, 0)
	_normal_actual = Vector2(-_direccion_actual.y, _direccion_actual.x)
	_acumulador_emision = 0.0
	_lanzallamas_activo = true
	_emitir_particula()


func _emitir_particula() -> void:
	var particula := Particula.new()
	particula.avance = 0.0
	particula.desvio_final = randf_range(-amplitud_final, amplitud_final)
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.sprite_frames = sprite_frames
	sprite.animation = &"default"
	sprite.frame = 0
	sprite.centered = true
	sprite.scale = Vector2.ONE * escala_origen
	add_child(sprite)
	sprite.play()
	particula.sprite = sprite
	_particulas.append(particula)


func _actualizar_particulas(delta: float) -> void:
	var particulas_terminadas: Array[Particula] = []
	for particula in _particulas:
		particula.avance += velocidad * delta
		var progreso: float = minf(particula.avance / distancia_maxima, 1.0)
		particula.sprite.position = (
			_direccion_actual * particula.avance
			+ _normal_actual * particula.desvio_final * progreso
		)
		particula.sprite.scale = Vector2.ONE * lerpf(escala_origen, escala_final, progreso)
		if particula.avance >= distancia_maxima:
			particulas_terminadas.append(particula)

	for particula in particulas_terminadas:
		particula.sprite.queue_free()
		_particulas.erase(particula)


func _detener_lanzallamas() -> void:
	for particula in _particulas:
		particula.sprite.queue_free()
	_particulas.clear()
	_acumulador_emision = 0.0
	_lanzallamas_activo = false

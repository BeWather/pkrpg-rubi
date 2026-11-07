@tool
extends Node2D

## Orbita de sprites (Mon2Efecto).
## Crea `cantidad_sprites` sprites que giran en una elipse alrededor de la
## posicion del nodo. Al iniciar, el radio es 0 y crece cada frame hasta
## `radio_horizontal` / `radio_vertical`. El z_index de cada sprite varia con
## su profundidad en la orbita para simular 3D.

@export_category("Orbita")

@export var girar: bool = false:
	set(valor):
		girar = valor
		if girar:
			iniciar_orbita()
		else:
			detener_orbita()

@export var reproducir_en_editor: bool = true

@export_category("Sprites")
@export var sprite_frames: SpriteFrames
@export_range(2, 32, 1, "or_greater") var cantidad_sprites: int = 8

@export_category("Trayectoria")
@export_range(1.0, 500.0, 1.0, "or_greater") var radio_horizontal: float = 30.0
@export_range(1.0, 500.0, 1.0, "or_greater") var radio_vertical: float = 16.0
@export_range(1.0, 2000.0, 1.0, "or_greater") var velocidad_angular: float = 360.0
@export_range(1.0, 500.0, 1.0, "or_greater") var velocidad_crecimiento_radio: float = 60.0

@export_category("Oscilacion eje Y")
@export_range(0.0, 200.0, 1.0, "or_greater") var amplitud_eje_y: float = 32.0
@export_range(1.0, 2000.0, 1.0, "or_greater") var velocidad_oscilacion_y: float = 90.0

@export_category("Profundidad")
@export_range(0, 10, 1, "or_greater") var amplitud_z: int = 2
@export_range(0.0, 0.5, 0.01) var escala_profundidad: float = 0.08

var _sprites: Array[AnimatedSprite2D] = []
var _angulo: float = 0.0
var _angulo_oscilacion_y: float = 0.0
var _factor_radio: float = 0.0
var _orbita_activa: bool = false


func _ready() -> void:
	visibility_changed.connect(_al_cambiar_visibilidad)
	set_process(true)


func _al_cambiar_visibilidad() -> void:
	if not is_visible_in_tree() and _orbita_activa:
		detener_orbita()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		if _orbita_activa:
			detener_orbita()
		return

	if Engine.is_editor_hint():
		if girar and reproducir_en_editor and not _orbita_activa:
			iniciar_orbita()
		elif (not girar or not reproducir_en_editor) and _orbita_activa:
			detener_orbita()
		if not _orbita_activa:
			return
	elif not _orbita_activa:
		return

	_angulo += deg_to_rad(velocidad_angular) * delta
	_angulo_oscilacion_y += deg_to_rad(velocidad_oscilacion_y) * delta
	_factor_radio = minf(_factor_radio + velocidad_crecimiento_radio * delta, 1.0)
	_actualizar_sprites()


func iniciar_orbita() -> void:
	detener_orbita()
	if sprite_frames == null:
		return
	for indice in cantidad_sprites:
		var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
		sprite.name = "Orbita%d" % indice
		sprite.sprite_frames = sprite_frames
		sprite.animation = &"default"
		sprite.frame = 0
		sprite.centered = true
		add_child(sprite)
		sprite.play()
		_sprites.append(sprite)
	_angulo = 0.0
	_angulo_oscilacion_y = 0.0
	_factor_radio = 0.0
	_orbita_activa = true
	_actualizar_sprites()


func _actualizar_sprites() -> void:
	var separacion_fase: float = TAU / float(cantidad_sprites)
	var oscilacion_y: float = sin(_angulo_oscilacion_y) * amplitud_eje_y
	for indice in _sprites.size():
		var angulo_sprite: float = _angulo + indice * separacion_fase
		var profundidad: float = sin(angulo_sprite)
		var sprite: AnimatedSprite2D = _sprites[indice]
		sprite.position = Vector2(
			cos(angulo_sprite) * radio_horizontal * _factor_radio,
			sin(angulo_sprite) * radio_vertical * _factor_radio
		)
		sprite.offset.y = oscilacion_y
		sprite.z_index = int(round(profundidad * amplitud_z))
		var escala: float = 1.0 + profundidad * escala_profundidad
		sprite.scale = Vector2.ONE * escala


func detener_orbita() -> void:
	for sprite in _sprites:
		sprite.queue_free()
	_sprites.clear()
	_orbita_activa = false

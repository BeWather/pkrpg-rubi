class_name EfectoTormentaArenaOverworld
extends EfectoClimaBase

## Tormenta de arena compuesta por una trama desplazable de 64x64 y motas de
## 32x32 que ascienden mientras orbitan alrededor de su trayectoria lineal.

const TEXTURA_FONDO: Texture2D = preload("res://graficos/climas/arena1.png")
const TEXTURA_PARTICULA: Texture2D = preload("res://graficos/climas/arena2.png")
const TAMANO_REFERENCIA: Vector2 = ConstantesGba.RESOLUCION_LOGICA
const ORIGEN_Y_PARTICULA: float = 192.0
const DESTINO_Y_PARTICULA: float = -32.0

## Ángulo en grados medido desde +X. El valor por defecto apunta a (-240, -60).
@export_range(-360.0, 360.0, 0.01) var angulo_movimiento_grados: float = -165.96376
## Velocidad del fondo en píxeles lógicos por segundo.
@export_range(0.0, 1000.0, 0.01) var velocidad_movimiento: float = 247.38634

@export_group("Partículas orbitales")
@export_range(0.01, 5.0, 0.01) var intervalo_emision_minimo: float = 0.1
@export_range(0.01, 5.0, 0.01) var intervalo_emision_maximo: float = 0.7
@export_range(0.1, 10.0, 0.1) var duracion_recorrido: float = 3.0
@export_range(0.0, 20.0, 0.1) var vueltas_por_recorrido: float = 6.0
@export_range(0.0, 128.0, 1.0) var diametro_orbita: float = 32.0
## Límite estricto solicitado para las motas de arena de 32x32.
@export_range(1, 6, 1) var max_particulas: int = 6

class ParticulaArena extends RefCounted:
	var x_base: float
	var edad: float = 0.0
	var fase_inicial: float = 0.0


var _rng := RandomNumberGenerator.new()
var _particulas: Array[ParticulaArena] = []
var _tiempo_fondo: float = 0.0
var _tiempo_hasta_emision: float = 0.0


func _ready() -> void:
	super._ready()
	_rng.randomize()
	_programar_siguiente_emision()
	set_process(true)


func _process(delta: float) -> void:
	var paso: float = maxf(0.0, delta)
	_tiempo_fondo += paso
	_actualizar_particulas(paso)
	if intensidad > 0.0:
		_actualizar_emisor(paso)
	queue_redraw()


func _draw() -> void:
	if factor_mezcla <= 0.0 or intensidad <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		return
	var escala := Vector2(
		size.x / TAMANO_REFERENCIA.x,
		size.y / TAMANO_REFERENCIA.y
	)
	draw_set_transform(Vector2.ZERO, 0.0, escala)
	var modulacion := Color(1.0, 1.0, 1.0, factor_mezcla * intensidad)
	_dibujar_fondo(modulacion)
	_dibujar_particulas(modulacion)


## Vector efectivo del fondo. Con los valores predeterminados devuelve
## aproximadamente (-240, -60) píxeles por segundo.
func obtener_vector_movimiento_fondo() -> Vector2:
	return Vector2.RIGHT.rotated(deg_to_rad(angulo_movimiento_grados)) * velocidad_movimiento


## Posición lógica del centro de una mota para un progreso normalizado 0..1.
## Se expone para diagnóstico y pruebas de la trayectoria combinada.
func calcular_posicion_particula(
	x_base: float,
	progreso: float,
	fase_inicial: float = 0.0
) -> Vector2:
	var t: float = clampf(progreso, 0.0, 1.0)
	var centro_lineal := Vector2(
		x_base,
		lerpf(ORIGEN_Y_PARTICULA, DESTINO_Y_PARTICULA, t)
	)
	var angulo_orbita: float = fase_inicial - TAU * vueltas_por_recorrido * t
	var radio: float = diametro_orbita * 0.5
	return centro_lineal + Vector2(cos(angulo_orbita), sin(angulo_orbita)) * radio


func obtener_cantidad_particulas() -> int:
	return _particulas.size()


func detener() -> void:
	_particulas.clear()
	queue_redraw()
	super.detener()


func _dibujar_fondo(modulacion: Color) -> void:
	var tamano_textura: Vector2 = TEXTURA_FONDO.get_size()
	if tamano_textura.x <= 0.0 or tamano_textura.y <= 0.0:
		return
	var desplazamiento: Vector2 = obtener_vector_movimiento_fondo() * _tiempo_fondo
	var inicio := Vector2(
		fposmod(desplazamiento.x, tamano_textura.x) - tamano_textura.x,
		fposmod(desplazamiento.y, tamano_textura.y) - tamano_textura.y
	)
	var y: float = inicio.y
	while y < TAMANO_REFERENCIA.y:
		var x: float = inicio.x
		while x < TAMANO_REFERENCIA.x:
			draw_texture(TEXTURA_FONDO, Vector2(x, y), modulacion)
			x += tamano_textura.x
		y += tamano_textura.y


func _dibujar_particulas(modulacion: Color) -> void:
	var mitad_textura: Vector2 = TEXTURA_PARTICULA.get_size() * 0.5
	var duracion: float = maxf(0.001, duracion_recorrido)
	for particula: ParticulaArena in _particulas:
		var progreso: float = particula.edad / duracion
		var centro := calcular_posicion_particula(
			particula.x_base,
			progreso,
			particula.fase_inicial
		)
		draw_texture(TEXTURA_PARTICULA, centro - mitad_textura, modulacion)


func _actualizar_particulas(delta: float) -> void:
	for indice: int in range(_particulas.size() - 1, -1, -1):
		var particula: ParticulaArena = _particulas[indice]
		particula.edad += delta
		if particula.edad >= duracion_recorrido:
			_particulas.remove_at(indice)


func _actualizar_emisor(delta: float) -> void:
	_tiempo_hasta_emision -= delta
	var seguridad: int = 0
	while _tiempo_hasta_emision <= 0.0 and seguridad < max_particulas:
		_emitir_particula()
		_programar_siguiente_emision()
		seguridad += 1


func _emitir_particula() -> void:
	if _particulas.size() >= max_particulas:
		return
	var particula := ParticulaArena.new()
	particula.x_base = _rng.randf_range(0.0, TAMANO_REFERENCIA.x)
	# La fase aleatoria evita que todas las motas presenten la misma cara de la
	# órbita aunque mantengan exactamente seis vueltas durante el recorrido.
	particula.fase_inicial = _rng.randf_range(0.0, TAU)
	_particulas.append(particula)


func _programar_siguiente_emision() -> void:
	var minimo: float = minf(intervalo_emision_minimo, intervalo_emision_maximo)
	var maximo: float = maxf(intervalo_emision_minimo, intervalo_emision_maximo)
	_tiempo_hasta_emision += _rng.randf_range(maxf(0.01, minimo), maxf(0.01, maximo))

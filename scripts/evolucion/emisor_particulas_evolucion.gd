@tool
extends Node2D

## Emisor reutilizable. El origen del nodo es el centro del Pokémon; las
## posiciones, velocidades y tamaños se expresan en píxeles de juego (240x160).
## AnimationPlayer puede animar `emitiendo` (pista discreta): al ponerlo en
## false dejan de nacer partículas, pero las existentes completan su recorrido.
## Las partículas usan z=-1/+1 respecto al Pokémon (z=0). Al integrar un preset,
## poner el fondo por debajo de -1 y el destello/fundido por encima de +1.
## Referencia de proyección del suelo: documentacion/perspectiva-suelo-batalla-y-particulas.md

## Mantener los valores existentes: los presets guardan `patron` como entero.
enum Patron { REMOLINO, JAULA, CIRCULO, FUENTE, REMOLINO_CURVO }

class Particula:
	var sprite: Sprite2D
	var edad: float = 0.0
	var angulo: float = 0.0
	var carril: float = 0.0
	var velocidad: Vector2 = Vector2.ZERO
	var profundidad: int = 0


@export var patron: Patron = Patron.REMOLINO
@export var textura: Texture2D
@export var emitiendo: bool = false
@export var reproducir_en_editor: bool = false
@export_range(0.02, 5.0, 0.01, "or_greater") var intervalo_emision: float = 0.14
@export_range(0.05, 10.0, 0.05, "or_greater") var duracion_particula: float = 1.4
@export_range(0.05, 4.0, 0.05, "or_greater") var escala_inicial: float = 1.0
@export_range(0.05, 4.0, 0.05, "or_greater") var escala_final: float = 0.33
@export_range(1, 256, 1, "or_greater") var limite_particulas: int = 256
@export var z_detras: int = -1
@export var z_delante: int = 1

@export_group("Remolino")
@export var base_remolino: Vector2 = Vector2(0, 32)
@export_range(0.0, 200.0, 1.0, "or_greater") var radio_remolino: float = 38.0
@export_range(0.0, 100.0, 1.0, "or_greater") var profundidad_remolino: float = 14.0
@export_range(1.0, 300.0, 1.0, "or_greater") var altura_remolino: float = 100.0
@export_range(0.0, 1440.0, 1.0, "or_greater") var giro_remolino: float = 420.0
@export_range(2, 16, 1, "or_greater") var filas_remolino: int = 4

@export_group("Remolino curvo")
## Radio horizontal 62 y semieje de profundidad 15 al nacer: suelo 124x30.
@export_range(1.0, 200.0, 1.0, "or_greater") var radio_base_remolino_curvo: float = 62.0
@export_range(0.0, 200.0, 1.0, "or_greater") var radio_cima_remolino_curvo: float = 12.0
@export_range(0.01, 2.0, 0.01, "or_greater") var proporcion_suelo_remolino: float = 30.0 / 124.0
@export_range(0.01, 20.0, 0.1, "or_greater") var curvatura_remolino: float = 5.0

@export_group("Jaula")
@export var inicio_jaula: Vector2 = Vector2(0, -50)
@export_range(0.0, 100.0, 1.0, "or_greater") var separacion_inicio: float = 4.0
@export_range(1.0, 200.0, 1.0, "or_greater") var radio_jaula: float = 46.0
@export_range(1.0, 300.0, 1.0, "or_greater") var caida_jaula: float = 84.0
@export_range(0.0, 100.0, 1.0, "or_greater") var curva_jaula: float = 12.0
@export_range(3, 32, 1, "or_greater") var filas_jaula: int = 9
@export_range(0.1, 1.0, 0.05) var fin_crecimiento_jaula: float = 0.85

@export_group("Circulo")
@export_range(3, 64, 1, "or_greater") var cantidad_circulo: int = 16
@export_range(1.0, 500.0, 1.0, "or_greater") var radio_inicial_circulo: float = 155.0
@export_range(0.0, 200.0, 1.0, "or_greater") var radio_final_circulo: float = 2.0
@export_range(0.1, 2.0, 0.05, "or_greater") var proporcion_vertical: float = 0.9

@export_group("Fuente")
@export var inicio_fuente: Vector2 = Vector2(0, -8)
@export_range(1, 64, 1, "or_greater") var particulas_por_rafaga: int = 5
@export_range(0.0, 300.0, 1.0, "or_greater") var velocidad_horizontal: float = 65.0
@export_range(0.0, 300.0, 1.0, "or_greater") var impulso_minimo: float = 85.0
@export_range(0.0, 300.0, 1.0, "or_greater") var impulso_maximo: float = 115.0
@export_range(0.0, 500.0, 1.0, "or_greater") var gravedad: float = 125.0
@export_range(0.0, 200.0, 1.0, "or_greater") var suelo_fuente: float = 42.0

var _particulas: Array[Particula] = []
var _activo: bool = false
var _reloj_emision: float = 0.0
var _fase_remolino: float = 0.0
var _azar := RandomNumberGenerator.new()


func _ready() -> void:
	_azar.randomize()
	set_process(true)


func _process(delta: float) -> void:
	var solicitado: bool = emitiendo or (Engine.is_editor_hint() and reproducir_en_editor)
	if solicitado and not _activo:
		_activo = true
		_reloj_emision = 0.0
		_emitir()
	elif not solicitado and _activo:
		_activo = false

	_actualizar_particulas(delta)
	if not _activo or textura == null:
		return
	_reloj_emision += delta
	var intervalo: float = maxf(intervalo_emision, 0.02)
	while _reloj_emision >= intervalo:
		_reloj_emision -= intervalo
		_emitir()


func iniciar_emision() -> void:
	emitiendo = true


func detener_emision() -> void:
	emitiendo = false


## Útil al reiniciar/cancelar una animación; a diferencia de detener_emision,
## descarta inmediatamente las partículas aún visibles.
func limpiar() -> void:
	emitiendo = false
	_activo = false
	_reloj_emision = 0.0
	_fase_remolino = 0.0
	for particula in _particulas:
		particula.sprite.queue_free()
	_particulas.clear()


func _emitir() -> void:
	if textura == null:
		return
	match patron:
		Patron.REMOLINO, Patron.REMOLINO_CURVO:
			var cantidad_remolino: int = maxi(filas_remolino, 2)
			for i in cantidad_remolino:
				_crear_particula(_fase_remolino + TAU * i / cantidad_remolino)
			_fase_remolino += 0.33
		Patron.JAULA:
			var cantidad_jaula: int = maxi(filas_jaula, 3)
			for i in cantidad_jaula:
				_crear_particula(0.0, 2.0 * i / (cantidad_jaula - 1) - 1.0)
		Patron.CIRCULO:
			var cantidad_anillo: int = maxi(cantidad_circulo, 3)
			for i in cantidad_anillo:
				_crear_particula(-PI / 2.0 + TAU * i / cantidad_anillo)
		Patron.FUENTE:
			for i in maxi(particulas_por_rafaga, 1):
				var particula: Particula = _crear_particula()
				if particula == null:
					break
				particula.velocidad = Vector2(
					_azar.randf_range(-velocidad_horizontal, velocidad_horizontal),
					-_azar.randf_range(minf(impulso_minimo, impulso_maximo), maxf(impulso_minimo, impulso_maximo))
				)
				particula.carril = _azar.randf_range(-8.0, 8.0)
				particula.profundidad = -1 if i % 2 == 0 else 1
				_actualizar_particula(particula)


func _crear_particula(angulo: float = 0.0, carril: float = 0.0) -> Particula:
	if _particulas.size() >= limite_particulas:
		return null
	var particula := Particula.new()
	particula.angulo = angulo
	particula.carril = carril
	particula.sprite = Sprite2D.new()
	particula.sprite.texture = textura
	add_child(particula.sprite)
	_particulas.append(particula)
	_actualizar_particula(particula)
	return particula


func _actualizar_particulas(delta: float) -> void:
	for i in range(_particulas.size() - 1, -1, -1):
		var particula: Particula = _particulas[i]
		particula.edad += delta
		_actualizar_particula(particula)
		if particula.edad >= maxf(duracion_particula, 0.05) or (
			patron == Patron.FUENTE and particula.edad > 0.1
			and particula.sprite.position.y >= suelo_fuente
		):
			particula.sprite.queue_free()
			_particulas.remove_at(i)


func _actualizar_particula(particula: Particula) -> void:
	var avance: float = clampf(particula.edad / maxf(duracion_particula, 0.05), 0.0, 1.0)
	var sprite: Sprite2D = particula.sprite
	match patron:
		Patron.REMOLINO, Patron.REMOLINO_CURVO:
			# Ángulo positivo = giro horario en coordenadas de pantalla.
			var angulo: float = particula.angulo + deg_to_rad(giro_remolino) * particula.edad
			var profundidad: float = sin(angulo)
			if patron == Patron.REMOLINO_CURVO:
				var radio: float = _radio_remolino_curvo(avance)
				sprite.position = base_remolino + Vector2(
					cos(angulo) * radio,
					-altura_remolino * avance + profundidad * radio * proporcion_suelo_remolino
				)
			else:
				sprite.position = base_remolino + Vector2(
					cos(angulo) * radio_remolino,
					-altura_remolino * avance + profundidad * profundidad_remolino
				)
			sprite.z_index = z_delante if profundidad >= 0.0 else z_detras
		Patron.JAULA:
			var carril: float = particula.carril
			var apertura: float = avance * (2.0 - avance)
			sprite.position = inicio_jaula + Vector2(
				carril * lerpf(separacion_inicio, radio_jaula, apertura),
				caida_jaula * avance * avance + curva_jaula * sqrt(maxf(0.0, 1.0 - carril * carril)) * apertura
			)
			sprite.z_index = z_delante if sprite.position.y >= 0.0 else z_detras
		Patron.CIRCULO:
			var radio: float = lerpf(radio_inicial_circulo, radio_final_circulo, avance)
			var profundidad_circulo: float = sin(particula.angulo)
			sprite.position = Vector2(cos(particula.angulo), profundidad_circulo * proporcion_vertical) * radio
			sprite.z_index = z_delante if profundidad_circulo >= 0.0 else z_detras
		Patron.FUENTE:
			sprite.position = inicio_fuente + Vector2(
				particula.carril,
				0.5 * gravedad * particula.edad * particula.edad
			) + particula.velocidad * particula.edad
			sprite.z_index = z_delante if sprite.position.y > 0.0 or particula.profundidad > 0 else z_detras
	# Escala del dibujo independiente del radio de la trayectoria: el remolino
	# curvo estrecha ambos, mientras el remolino recto solo reduce el dibujo.
	# En la jaula se llega a escala normal ANTES de desaparecer en el suelo,
	# para que el tamaño final permanezca visible al terminar la caída.
	var avance_escala: float = minf(avance / maxf(fin_crecimiento_jaula, 0.1), 1.0) if patron == Patron.JAULA else avance
	var escala: float = lerpf(escala_inicial, escala_final, avance_escala)
	sprite.scale = Vector2.ONE * escala


## Perfil lateral curvado: el radio se reduce deprisa cerca del suelo y se
## estabiliza arriba. Se normaliza para alcanzar exactamente el radio de cima.
func _radio_remolino_curvo(avance: float) -> float:
	var curvatura: float = maxf(curvatura_remolino, 0.01)
	var exp_final: float = exp(-curvatura)
	var fraccion: float = (exp(-curvatura * clampf(avance, 0.0, 1.0)) - exp_final) / (1.0 - exp_final)
	return lerpf(radio_cima_remolino_curvo, radio_base_remolino_curvo, fraccion)

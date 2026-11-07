extends Node2D

# Variables del emisor
var particulas_emitidas = 0
var intervalo_emision = 0.04
var distancia_maxima = 48.0
var duracion_movimiento = 0.8
# var offset_posicion = Vector2(64, 64)
var offset_posicion = Vector2.ZERO
var max_particulas = 24
# Nueva variable para tiempo de emisión (alternativa a max_particulas)
var tiempo_emision = 0.0  # Si > 0, usa tiempo en lugar de cantidad

# Direcciones de las 8 direcciones básicas (en radianes)
var direcciones = [
	Vector2(0, -1),      # Arriba
	Vector2(1, -1),      # Arriba-derecha
	Vector2(1, 0),       # Derecha
	Vector2(1, 1),       # Abajo-derecha
	Vector2(0, 1),       # Abajo
	Vector2(-1, 1),      # Abajo-izquierda
	Vector2(-1, 0),      # Izquierda
	Vector2(-1, -1)      # Arriba-izquierda
]

# Timer para controlar la emisión
var timer_emision: Timer
var timer_duracion: Timer  # Timer para controlar duración total de emisión
var particula_base: AnimatedSprite2D

func _ready():
	# Obtener referencia a la partícula base
	particula_base = $partic
	particula_base.visible = false  # Ocultar la partícula base
	
	# Crear timer para la emisión
	timer_emision = Timer.new()
	timer_emision.wait_time = intervalo_emision
	timer_emision.one_shot = false
	timer_emision.timeout.connect(_emitir_particula)
	add_child(timer_emision)
	
	# Crear timer para duración total de emisión
	timer_duracion = Timer.new()
	timer_duracion.one_shot = true
	timer_duracion.timeout.connect(_detener_por_tiempo)
	add_child(timer_duracion)
	
	# Iniciar la emisión automáticamente
	iniciar_emision()

## Método público para iniciar la emisión manualmente
func iniciar_emision():
	if timer_emision and not timer_emision.is_stopped():
		timer_emision.stop()
	if timer_duracion and not timer_duracion.is_stopped():
		timer_duracion.stop()
		
	particulas_emitidas = 0
	timer_emision.start()
	
	# Si se especifica tiempo de emisión, usar timer de duración
	if tiempo_emision > 0:
		timer_duracion.wait_time = tiempo_emision
		timer_duracion.start()
		print("🕐 [EMISOR] Iniciando emisión por tiempo: %.2f segundos" % tiempo_emision)
	else:
		print("🔢 [EMISOR] Iniciando emisión por cantidad: %d partículas" % max_particulas)

## Método público para detener la emisión
func detener_emision():
	if timer_emision:
		timer_emision.stop()
	if timer_duracion:
		timer_duracion.stop()

## Método interno llamado cuando se cumple el tiempo de emisión
func _detener_por_tiempo():
	print("⏰ [EMISOR] Tiempo de emisión completado. Partículas emitidas: %d" % particulas_emitidas)
	detener_emision()

## Método público para configurar parámetros
func configurar(nuevos_parametros: Dictionary):
	if nuevos_parametros.has("max_particulas"):
		max_particulas = nuevos_parametros["max_particulas"]
	if nuevos_parametros.has("tiempo_emision"):
		tiempo_emision = nuevos_parametros["tiempo_emision"]
	if nuevos_parametros.has("intervalo_emision"):
		intervalo_emision = nuevos_parametros["intervalo_emision"]
		if timer_emision:
			timer_emision.wait_time = intervalo_emision
	if nuevos_parametros.has("distancia_maxima"):
		distancia_maxima = nuevos_parametros["distancia_maxima"]
	if nuevos_parametros.has("duracion_movimiento"):
		duracion_movimiento = nuevos_parametros["duracion_movimiento"]
	# Tinte de las partículas (Etapa 3, SDD 2026-09-14-battle-architecture-split):
	# usado por las animaciones de movimiento para reusar este emisor genérico
	# sin necesitar arte propio por elemento.
	if nuevos_parametros.has("color"):
		modulate = nuevos_parametros["color"]

func _emitir_particula():
	# Si usa tiempo de emisión, no verificar cantidad máxima
	if tiempo_emision <= 0 and particulas_emitidas >= max_particulas:
		timer_emision.stop()
		print("🔢 [EMISOR] Cantidad máxima de partículas alcanzada: %d" % max_particulas)
		return
	
	# Clonar la partícula base
	var nueva_particula = particula_base.duplicate()
	nueva_particula.visible = true
	nueva_particula.position = offset_posicion  # Aplicar offset
	add_child(nueva_particula)
	
	# Iniciar animación de rotación
	nueva_particula.play("default")
	
	# Calcular dirección (cicla entre las 8 direcciones)
	var direccion_index = particulas_emitidas % 8
	var direccion = direcciones[direccion_index].normalized()
	var destino = offset_posicion + (direccion * distancia_maxima)  # Aplicar offset al destino
	
	# Crear Tween para el movimiento
	var tween = create_tween()
	tween.tween_property(nueva_particula, "position", destino, duracion_movimiento)
	tween.tween_callback(func(): _eliminar_particula(nueva_particula))
	
	particulas_emitidas += 1

func _eliminar_particula(particula: AnimatedSprite2D):
	# Eliminar inmediatamente la partícula de la memoria
	particula.queue_free()

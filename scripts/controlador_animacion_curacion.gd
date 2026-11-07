## controlador_animacion_curacion.gd
## Controlador de animación de curación para el Centro Pokémon
## Maneja la animación de las pokéballs y la pantalla durante el proceso de curación
##
@tool
extends Node

## ============================================================================
## CONFIGURACIÓN DE ANIMACIÓN
## ============================================================================

## Número de pokéballs a animar (1-6)
@export_range(1, 6) var pokeballs_a_usar: int = 6 : set = _set_pokeballs_a_usar

## Flag para activar/desactivar la animación desde el editor
@export var activar_animacion: bool = false : set = _set_activar_animacion

## Duración de la animación de cada pokéball (en segundos)
@export var duracion_por_pokeball: float = 0.8

## Delay entre pokéballs (en segundos)
@export var delay_entre_pokeballs: float = 0.2

## Añade el ciclo de destello previo para acompañar la fanfarria completa.
@export var destello_extra: bool = true

## ============================================================================
## REFERENCIAS A NODOS
## ============================================================================

## Referencias a las pokéballs (se obtienen automáticamente)
var pokeballs: Array[AnimatedSprite2D] = []

## Referencia a la pantalla
var pantalla: AnimatedSprite2D = null

## ============================================================================
## CONTROL DE ANIMACIÓN
## ============================================================================

## Flag interno para saber si la animación está en curso
var animacion_en_progreso: bool = false

## Callback que se ejecuta al finalizar la animación
var callback_fin_animacion: Callable

## Clave en Singleton.TEMAS_REGISTRADOS (BaseDatos/temas_musicales.json).
const TEMA_CURACION: String = "POKEMON_RECUPERADOS"

## Clave en Singleton (Audio/SE-AVXS/023_SE_BALL.wav = SE_BOWA de la ROM).
const SE_COLOCAR_POKEBALL: String = "SE_BALL"

## true mientras suena la fanfarria de curación (playfanfare + waitfanfare).
var _fanfarria_en_curso: bool = false

## ============================================================================
## INICIALIZACIÓN
## ============================================================================

func _ready():
	print("🎬 [ANIMACION_CURACION] Inicializando controlador...")

	# Buscar y configurar las pokéballs
	_configurar_pokeballs()

	# Buscar y configurar la pantalla
	_configurar_pantalla()

	print("🎬 [ANIMACION_CURACION] Controlador configurado")
	print("   📦 Pokéballs encontradas: %d" % pokeballs.size())
	print("   📺 Pantalla configurada: %s" % (pantalla != null))

func _configurar_pokeballs():
	pokeballs.clear()

	# Buscar nodos que contengan "pokeball" en su nombre (case insensitive)
	for child in get_children():
		if child is AnimatedSprite2D and "pokeball" in child.name.to_lower():
			pokeballs.append(child)
			print("   🔴 Pokéball encontrada: %s" % child.name)

	# Ordenar por nombre para tener un orden consistente
	# pokeballs.sort_custom(func(a, b): return a.name < b.name)

	# Configurar estado inicial de las pokéballs
	for pokeball in pokeballs:
		pokeball.visible = false
		pokeball.play("default")
		pokeball.stop()

func _configurar_pantalla():
	# Buscar nodo que contenga "pantalla" en su nombre (case insensitive)
	for child in get_children():
		if child is AnimatedSprite2D and "pantalla" in child.name.to_lower():
			pantalla = child
			print("   📺 Pantalla encontrada: %s" % child.name)
			break

	# Configurar estado inicial de la pantalla
	if pantalla:
		pantalla.visible = false
		pantalla.stop()

## ============================================================================
## SETTERS PARA VARIABLES EXPORTADAS
## ============================================================================

func _set_pokeballs_a_usar(valor: int):
	pokeballs_a_usar = clamp(valor, 1, 6)
	print("🎬 [ANIMACION_CURACION] Pokéballs a usar configuradas: %d" % pokeballs_a_usar)

func _set_activar_animacion(valor: bool):
	if valor and not animacion_en_progreso:
		print("🎬 [ANIMACION_CURACION] Activando animación desde editor...")
		activar_animacion = false  # Reset inmediato para evitar loop
		iniciar_animacion_curacion()
	elif not valor:
		activar_animacion = false

## ============================================================================
## API PÚBLICA
## ============================================================================

## Inicia la animación de curación
## @param num_pokeballs: Número de pokéballs a animar (opcional, usa pokeballs_a_usar por defecto)
## @param callback: Función a ejecutar cuando termine la animación
func iniciar_animacion_curacion(num_pokeballs: int = -1, callback: Callable = Callable()) -> void:
	if animacion_en_progreso:
		print("🎬 [ANIMACION_CURACION] ⚠️ Animación ya en progreso, ignorando")
		return

	# Usar valor exportado si no se especifica
	if num_pokeballs == -1:
		num_pokeballs = pokeballs_a_usar

	# Validar número de pokéballs
	num_pokeballs = clamp(num_pokeballs, 1, min(6, pokeballs.size()))

	print("🎬 [ANIMACION_CURACION] ▶️ Iniciando animación con %d pokéballs" % num_pokeballs)

	# Configurar callback
	callback_fin_animacion = callback

	# Marcar animación en progreso
	animacion_en_progreso = true

	# Iniciar secuencia de animación
	_ejecutar_secuencia_animacion(num_pokeballs)

## Detiene la animación en curso (si la hay)
func detener_animacion() -> void:
	if not animacion_en_progreso:
		return

	print("🎬 [ANIMACION_CURACION] ⏹️ Deteniendo animación")

	# Detener pantalla
	if pantalla:
		pantalla.visible = false
		pantalla.stop()

	# Detener todas las pokéballs
	for pokeball in pokeballs:
		pokeball.stop()

	# Resetear estado
	animacion_en_progreso = false
	activar_animacion = false

## Verifica si hay una animación en progreso
func esta_animando() -> bool:
	return animacion_en_progreso

## ============================================================================
## LÓGICA DE ANIMACIÓN
## ============================================================================

func _ejecutar_secuencia_animacion(num_pokeballs: int) -> void:
	print("🎬 [ANIMACION_CURACION] 🎭 Ejecutando secuencia...")

	# 1. Asegurar que todo esté invisible al inicio
	_ocultar_todos_elementos()

	# 2. Mostrar pokéballs una por una cada 0.5 segundos
	await _mostrar_pokeballs_secuencial(num_pokeballs)

	# 3. El destello previo dura 0,5 s; la secuencia completa, otros 2 s.
	# Acompañan MUS_HEAL (2,204 s) y el fundido previo de la música (0,3 s).
	_activar_pantalla()
	_iniciar_fanfarria()
	if destello_extra:
		_reproducir_animacion_pokeballs(num_pokeballs, &"ciclo1")
		await _esperar_fin_animacion(&"ciclo1")
	_reproducir_animacion_pokeballs(num_pokeballs, &"completo")

	# 4. Esperar que termine la animación y la fanfarria
	await _esperar_fin_animacion()
	while _fanfarria_en_curso:
		await get_tree().process_frame

	# 5. Desactivar pantalla y ocultar pokéballs
	_desactivar_pantalla()
	_ocultar_pokeballs()

	# 6. Finalizar animación
	_finalizar_animacion()

func _ocultar_todos_elementos() -> void:
	print("🎬 [ANIMACION_CURACION] 👻 Ocultando todos los elementos")

	# Ocultar todas las pokéballs
	for pokeball in pokeballs:
		pokeball.visible = false
		pokeball.stop()

	# Ocultar pantalla
	if pantalla:
		pantalla.visible = false
		pantalla.stop()

func _mostrar_pokeballs_secuencial(num_pokeballs: int) -> void:
	print("🎬 [ANIMACION_CURACION] 📦 Mostrando %d pokéballs secuencialmente" % num_pokeballs)

	for i in range(num_pokeballs):
		if i >= pokeballs.size():
			print("🎬 [ANIMACION_CURACION] ⚠️ No hay suficientes pokéballs disponibles")
			break

		var pokeball: AnimatedSprite2D = pokeballs[i]
		print("🎬 [ANIMACION_CURACION] 👁️ Mostrando pokéball %d: %s" % [i + 1, pokeball.name])

		# Hacer visible la pokéball (sin animación aún)
		pokeball.visible = true
		pokeball.play("default")  # Mostrar frame por defecto
		pokeball.stop()  # Detener en el primer frame

		# SE_BOWA de la ROM: sonido al apoyar cada pokéball en la máquina
		if not Engine.is_editor_hint():
			Singleton.play_sound.emit(SE_COLOCAR_POKEBALL)

		# Esperar medio segundo antes de mostrar la siguiente
		await get_tree().create_timer(0.5).timeout

func _reproducir_animacion_pokeballs(num_pokeballs: int, nombre_animacion: StringName) -> void:
	for i in range(num_pokeballs):
		if i >= pokeballs.size():
			break

		var pokeball: AnimatedSprite2D = pokeballs[i]
		if pokeball.visible and pokeball.sprite_frames and pokeball.sprite_frames.has_animation(nombre_animacion):
			print("🎬 [ANIMACION_CURACION] ▶️ Iniciando animación '%s' en %s" % [nombre_animacion, pokeball.name])
			pokeball.play(nombre_animacion)
		else:
			print("🎬 [ANIMACION_CURACION] ❌ No se puede reproducir '%s' en %s" % [nombre_animacion, pokeball.name])

## Fanfarria de curación (MUS_HEAL) junto al parpadeo de las pokéballs. En el
## editor el autoload Singleton no es utilizable, así que allí no suena.
func _iniciar_fanfarria() -> void:
	if Engine.is_editor_hint():
		return
	_fanfarria_en_curso = true
	await Fanfarria.reproducir(self, TEMA_CURACION)
	_fanfarria_en_curso = false

func _esperar_fin_animacion(nombre_animacion: StringName = &"completo") -> void:
	print("🎬 [ANIMACION_CURACION] ⏱️ Esperando fin de animación...")

	# Respetar las duraciones editables de cada fotograma y la velocidad del nodo.
	var tiempo_espera: float = 0.0
	for pokeball: AnimatedSprite2D in pokeballs:
		if not pokeball.visible or pokeball.sprite_frames == null:
			continue
		var frames: SpriteFrames = pokeball.sprite_frames
		if not frames.has_animation(nombre_animacion):
			continue
		var fps: float = frames.get_animation_speed(nombre_animacion) * absf(pokeball.speed_scale)
		if fps <= 0.0:
			continue
		var duracion: float = 0.0
		for indice: int in range(frames.get_frame_count(nombre_animacion)):
			duracion += frames.get_frame_duration(nombre_animacion, indice) / fps
		tiempo_espera = maxf(tiempo_espera, duracion)
	if tiempo_espera <= 0.0:
		tiempo_espera = duracion_por_pokeball

	print("🎬 [ANIMACION_CURACION] ⏱️ Esperando %s segundos" % tiempo_espera)
	await get_tree().create_timer(tiempo_espera).timeout

func _ocultar_pokeballs() -> void:
	print("🎬 [ANIMACION_CURACION] 👻 Ocultando pokéballs")

	for pokeball in pokeballs:
		pokeball.visible = false
		pokeball.stop()

func _activar_pantalla() -> void:
	if not pantalla:
		print("🎬 [ANIMACION_CURACION] ⚠️ No se encontró la pantalla")
		return

	print("🎬 [ANIMACION_CURACION] 📺 Activando pantalla")
	pantalla.visible = true
	pantalla.play()  # Reproduce en bucle por defecto

func _desactivar_pantalla() -> void:
	if not pantalla:
		return

	print("🎬 [ANIMACION_CURACION] 📺 Desactivando pantalla")
	pantalla.visible = false
	pantalla.stop()

func _finalizar_animacion() -> void:
	print("🎬 [ANIMACION_CURACION] ✅ Animación completada")

	# Resetear estado
	animacion_en_progreso = false
	activar_animacion = false

	# Ejecutar callback si existe
	if callback_fin_animacion.is_valid():
		print("🎬 [ANIMACION_CURACION] 📞 Ejecutando callback de finalización")
		callback_fin_animacion.call()
		callback_fin_animacion = Callable()  # Limpiar

## ============================================================================
## UTILIDADES PARA DEPURACIÓN
## ============================================================================

## Información de debug
func debug_info() -> void:
	print("=== DEBUG ANIMACION CURACION ===")
	print("Pokéballs configuradas: %d" % pokeballs_a_usar)
	print("Pokéballs disponibles: %d" % pokeballs.size())
	print("Pantalla disponible: %s" % (pantalla != null))
	print("Animación en progreso: %s" % animacion_en_progreso)
	print("================================")

## Lista todas las pokéballs encontradas
func listar_pokeballs() -> void:
	print("🔴 POKÉBALLS DISPONIBLES:")
	for i in range(pokeballs.size()):
		var pokeball = pokeballs[i]
		print("  %d. %s" % [i + 1, pokeball.name])
		if pokeball.sprite_frames:
			print("     Animaciones: %s" % pokeball.sprite_frames.get_animation_names())

## Prueba individual de una pokéball
func probar_pokeball(indice: int) -> void:
	if indice < 0 or indice >= pokeballs.size():
		print("🎬 [ANIMACION_CURACION] ❌ Índice de pokéball inválido: %d" % indice)
		return

	var pokeball = pokeballs[indice]
	print("🎬 [ANIMACION_CURACION] 🧪 Probando pokéball: %s" % pokeball.name)

	if pokeball.sprite_frames and pokeball.sprite_frames.has_animation("completo"):
		pokeball.play("completo")
	else:
		print("🎬 [ANIMACION_CURACION] ❌ No se puede probar: animación 'completo' no encontrada")

## ============================================================================
## FUNCIONES PARA EL EDITOR (SOLO @tool)
## ============================================================================

# Estas funciones solo funcionan cuando el script está marcado como @tool
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []

	if pokeballs.is_empty():
		warnings.append("No se encontraron pokéballs. Asegúrate de que los nodos AnimatedSprite2D contengan 'pokeball' en su nombre.")

	if not pantalla:
		warnings.append("No se encontró la pantalla. Asegúrate de que el nodo AnimatedSprite2D contenga 'pantalla' en su nombre.")

	for pokeball in pokeballs:
		if not pokeball.sprite_frames or not pokeball.sprite_frames.has_animation("completo"):
			warnings.append("La pokéball '%s' no tiene la animación 'completo'." % pokeball.name)

	return warnings

func _loggear(mensaje: String) -> void:
	print("🎬 [ANIMACION_CURACION] %s" % mensaje)

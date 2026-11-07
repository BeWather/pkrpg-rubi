extends Control

# Referencias a nodos
@onready var cursor: Sprite2D = $Apuntando
@onready var pokeball1: AnimatedSprite2D = $poke1
@onready var pokeball2: AnimatedSprite2D = $poke2
@onready var pokeball3: AnimatedSprite2D = $poke3
@onready var info_box: Polygon2D = $Box
@onready var nombre_label: Label = $Box/Nombre
@onready var circle: Node2D = $Circle
@onready var pokemon_sprite: Sprite2D = $Circle/"poke-frente"
@onready var borde_mensaje: NinePatchRect = $BordeDinamico
@onready var mensaje: Label = $"BordeDinamico/Mensaje"	# El nodo BordeDinamico debe estar en z_index = 1 o no se redibujará cuando cambie de texto

# Variables para menú de confirmación
var menu_confirmacion = null
var menu_confirmacion_activo: bool = false
var opcion_seleccionada: int = 0  # 0 = SI, 1 = NO

# Configuración de selección
var pokemon_seleccionado: int = 0  # 0, 1, 2 (poke1, poke2, poke3)
var nombres_internos_configurados: Array = []  # Array para almacenar nombres internos desde activador
var pokemon_data: Array[Dictionary] = [
	{
		"name": "TREECKO",
		"description": "\ue0a7\ue0a8 GECO BOSQUE",
		"position": Vector2(49, 52),
		"texture": preload("res://graficos/pokemon/front/TREECKO.png")
	},
	{
		"name": "TORCHIC", 
		"description": "PKMN POLLUELO",
		"position": Vector2(109, 76),
		"texture": preload("res://graficos/pokemon/front/TORCHIC.png")
	},
	{
		"name": "MUDKIP",
		"description": "PKMN PEZ LODO", 
		"position": Vector2(169, 52),
		"texture": preload("res://graficos/pokemon/front/MUDKIP.png")
	}
]

## Grito del Pokémon (Audio/SE/Cries/<número nacional de 3 cifras>Cry.ogg).
const RUTA_GRITO: String = "res://Audio/SE/Cries/%03dCry.ogg"

# Configuración de animación
var tween: Tween

# Sistema de animación de pokeballs
var pokeball_timers: Array[Timer] = []
var pokeballs: Array[AnimatedSprite2D] = []
const POKEBALL_FPS = 6.0
const MIN_TIMER_DELAY = 1.0
const MAX_TIMER_DELAY = 4.0
# Configuración para pokeball seleccionada
const SELECTED_POKEBALL_COOLDOWN = 0.1
const MIN_SELECTED_FPS = 8.0
const MAX_SELECTED_FPS = 16.0

# Sistema de animación del cursor/mano
var cursor_tween: Tween
const CURSOR_POSITIONS = [
	Vector2(61, 41),   # Posición 1
	Vector2(121, 64),  # Posición 2  
	Vector2(181, 41)   # Posición 3
]
const CURSOR_MOVE_DISTANCE = 16  # Pixeles de movimiento vertical

# Posiciones del Box de información según pokeball seleccionada
const BOX_POSITIONS = [
	Vector2(4, 72),    # Posición para Treecko
	Vector2(132, 80),  # Posición para Mudkip
	Vector2(68, 32)    # Posición para Torchic
]

# Mensajes de texto
const MENSAJE_INICIAL = "¡El PROF. ABEDUL tiene problemas!\n¡Elige un POKéMON y ayúdale!"
const MENSAJE_CONFIRMACION = "¿Quieres este POKéMON?"

signal seleccion_hecha(pokemon_seleccionado: Dictionary)

## Función que se ejecuta constantemente
func _process(_delta):
	pass

func _ready():
	print("🎮 [Inicial] Iniciando escena de selección inicial")
	
	# Verificar si hay nombres internos configurados desde el activador
	if not nombres_internos_configurados.is_empty():
		print("📦 [Inicial] Configurando pokémon desde activador con ", nombres_internos_configurados.size(), " nombres")
		_configurar_pokemon_desde_nombres_internos(nombres_internos_configurados)
	else:
		print("📦 [Inicial] No hay configuración específica, usando pokémon por defecto")
	
	# Configurar array de pokeballs para fácil acceso
	pokeballs = [pokeball1, pokeball2, pokeball3]
	
	# Configurar sistema de animación de pokeballs
	_configurar_animacion_pokeballs()
	
	# Posicionar cursor inicial
	_actualizar_seleccion()
	
	# Asegurar que la pokeball inicialmente seleccionada no se anime
	_actualizar_estado_pokeball_seleccionada()
	
	# Iniciar animación del cursor
	_iniciar_animacion_cursor()
	
	# Configurar círculo inicial como invisible
	circle.visible = false

	_aplicar_marco_configurado()

	# Menú SÍ/NO
	menu_confirmacion = preload("res://UI/MenuConfirmacion.gd").new()
	add_child(menu_confirmacion)
	
	# Conectar señales del menú
	menu_confirmacion.opcion_seleccionada.connect(_on_menu_opcion_seleccionada)

	# Mostrar mensaje inicial
	mensaje.text = MENSAJE_INICIAL
	
	print("✅ [Inicial] Escena de selección inicial configurada correctamente")
	
	# Aclarar pantalla usando el telón si está disponible
	call_deferred("_aclarar_pantalla_inicial")

## Marco elegido en Opciones (menu_box_N) para el cuadro del mensaje, como el SÍ/NO
## de MenuConfirmacion: en mosaico, nunca estirado.
func _aplicar_marco_configurado() -> void:
	var tipo := 1
	if SistemaGuardado and SistemaGuardado.datos_vivos and SistemaGuardado.datos_vivos.opciones:
		tipo = int(SistemaGuardado.datos_vivos.opciones.imagen_tipo)
	MenuBoxManager.apply_texture_to_ninepatch(borde_mensaje, tipo)
	borde_mensaje.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	borde_mensaje.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE

## Configura el sistema de animación para las pokeballs
func _configurar_animacion_pokeballs():
	# Limpiar timers existentes si los hay
	for timer in pokeball_timers:
		if timer != null and timer.is_inside_tree():
			timer.queue_free()
	pokeball_timers.clear()
	
	# Configurar cada pokeball
	for i in range(pokeballs.size()):
		var pokeball = pokeballs[i]
		
		# Configurar velocidad de animación (6 FPS)
		# speed_scale = velocidad_deseada / velocidad_original_del_sprite
		# Asumiendo que el sprite original es a 12 FPS, para 6 FPS necesitamos 0.5
		pokeball.speed_scale = POKEBALL_FPS / 12.0
		
		# Detener animación inicial y poner en frame 0
		pokeball.stop()
		pokeball.frame = 0
		
		# Crear timer para esta pokeball
		var timer = Timer.new()
		timer.one_shot = true
		timer.wait_time = randf_range(MIN_TIMER_DELAY, MAX_TIMER_DELAY)
		add_child(timer)
		
		# Conectar la señal del timer
		timer.timeout.connect(_on_pokeball_timer_timeout.bind(i))
		
		# Agregar timer al array
		pokeball_timers.append(timer)
		
		# Iniciar timer
		timer.start()

## Se ejecuta cuando el timer de una pokeball termina
func _on_pokeball_timer_timeout(pokeball_index: int):
	var pokeball = pokeballs[pokeball_index]
	
	# Comportamiento diferente si está seleccionada
	if pokeball_index == pokemon_seleccionado:
		# Configurar FPS aleatorio para pokeball seleccionada
		var fps_aleatorio = randf_range(MIN_SELECTED_FPS, MAX_SELECTED_FPS)
		pokeball.speed_scale = fps_aleatorio / 12.0
	else:
		# Configurar FPS normal para pokeball no seleccionada
		pokeball.speed_scale = POKEBALL_FPS / 12.0
	
	# Asegurar que la pokeball esté en estado inicial
	pokeball.stop()
	pokeball.frame = 0
	
	# Desconectar señal anterior si existe para evitar duplicados
	if pokeball.animation_finished.is_connected(_on_pokeball_animation_finished):
		pokeball.animation_finished.disconnect(_on_pokeball_animation_finished)
	
	# Conectar señal apropiada según el tipo de pokeball
	if pokeball_index == pokemon_seleccionado:
		# Para pokeball seleccionada: usar timer corto al terminar animación
		pokeball.animation_finished.connect(_on_pokeball_seleccionada_animation_finished.bind(pokeball_index), CONNECT_ONE_SHOT)
	else:
		# Para pokeball no seleccionada: usar timer largo al terminar animación
		pokeball.animation_finished.connect(_on_pokeball_animation_finished.bind(pokeball_index), CONNECT_ONE_SHOT)
	
	# Reproducir animación
	pokeball.play()

## Se ejecuta cuando termina la animación de una pokeball
func _on_pokeball_animation_finished(pokeball_index: int):
	var pokeball = pokeballs[pokeball_index]
	
	# Detener animación y volver al frame 0
	pokeball.stop()
	pokeball.frame = 0
	
	# Resetear timer con nuevo tiempo aleatorio
	_resetear_timer_pokeball(pokeball_index)

## Se ejecuta cuando termina la animación de una pokeball SELECCIONADA
func _on_pokeball_seleccionada_animation_finished(pokeball_index: int):
	var pokeball = pokeballs[pokeball_index]
	
	# Detener animación y volver al frame 0
	pokeball.stop()
	pokeball.frame = 0
	
	# Resetear timer con cooldown corto para continuar el ciclo rápido
	var timer = pokeball_timers[pokeball_index]
	timer.wait_time = SELECTED_POKEBALL_COOLDOWN
	timer.start()

## Resetea el timer de una pokeball con un tiempo aleatorio
func _resetear_timer_pokeball(pokeball_index: int):
	if pokeball_index >= pokeball_timers.size():
		return
		
	var timer = pokeball_timers[pokeball_index]
	var nuevo_tiempo = randf_range(MIN_TIMER_DELAY, MAX_TIMER_DELAY)
	timer.wait_time = nuevo_tiempo
	timer.start()

## Actualiza el estado de la pokeball actualmente seleccionada
func _actualizar_estado_pokeball_seleccionada():
	var pokeball_actual = pokeballs[pokemon_seleccionado]
	pokeball_actual.stop()
	pokeball_actual.frame = 0
	
	# Configurar timer corto para pokeball seleccionada
	var timer_actual = pokeball_timers[pokemon_seleccionado]
	timer_actual.wait_time = SELECTED_POKEBALL_COOLDOWN
	timer_actual.start()
	
	# Desconectar cualquier señal de animación pendiente
	if pokeball_actual.animation_finished.is_connected(_on_pokeball_animation_finished):
		pokeball_actual.animation_finished.disconnect(_on_pokeball_animation_finished)

## Inicia la animación cíclica suave del cursor
func _iniciar_animacion_cursor():
	_animar_cursor_ciclico()

## Animación cíclica del cursor (sube y baja suavemente)
func _animar_cursor_ciclico():
	if cursor_tween:
		cursor_tween.kill()
	
	cursor_tween = create_tween()
	cursor_tween.set_loops()  # Bucle infinito
	
	var posicion_base = CURSOR_POSITIONS[pokemon_seleccionado]
	var posicion_arriba = posicion_base + Vector2(0, -CURSOR_MOVE_DISTANCE)
	
	# Establecer posición inicial
	cursor.position = posicion_base
	
	# Secuencia de animación: base -> arriba -> base
	cursor_tween.tween_property(cursor, "position", posicion_arriba, 0.5)
	cursor_tween.tween_property(cursor, "position", posicion_base, 0.5)
	
	# Aplicar easing suave
	cursor_tween.set_ease(Tween.EASE_IN_OUT)
	cursor_tween.set_trans(Tween.TRANS_SINE)

## Detiene la animación cíclica del cursor
func _detener_animacion_cursor():
	if cursor_tween:
		cursor_tween.kill()
		cursor_tween = null

## Reanuda la animación cíclica del cursor
func _reanudar_animacion_cursor():
	_animar_cursor_ciclico()

func _input(event):
	# Solo mostrar logs de eventos relevantes (no mouse motion)
	if event is InputEventKey and event.pressed:
		print("🎮 [Inicial] Input recibido: ", event.as_text())
	
	# No procesar input si el menú de confirmación está activo
	if menu_confirmacion_activo:
		if event is InputEventKey and event.pressed:
			print("🚫 [Inicial] Input bloqueado - menú de confirmación activo")
		return
		
	if event.is_action_pressed("btn_izquierda"):
		print("⬅️ [Inicial] Botón izquierda presionado")
		_cambiar_seleccion(-1)
	elif event.is_action_pressed("btn_derecha"):
		print("➡️ [Inicial] Botón derecha presionado")
		_cambiar_seleccion(1)
	elif event.is_action_pressed("btn_accion"):
		print("✅ [Inicial] Botón acción presionado")
		_confirmar_seleccion()

func _cambiar_seleccion(direccion: int):
	var anterior_seleccion = pokemon_seleccionado
	
	pokemon_seleccionado = (pokemon_seleccionado + direccion) % pokemon_data.size()
	if pokemon_seleccionado < 0:
		pokemon_seleccionado = pokemon_data.size() - 1
	
	# Manejar cambio de estado de pokeballs
	_actualizar_estado_pokeballs(anterior_seleccion)
	
	_actualizar_seleccion()

## Actualiza el estado de animación de las pokeballs al cambiar selección
func _actualizar_estado_pokeballs(anterior_seleccion: int):
	# La pokeball anteriormente seleccionada vuelve a comportamiento normal
	if anterior_seleccion != pokemon_seleccionado:
		var pokeball_anterior = pokeballs[anterior_seleccion]
		pokeball_anterior.stop()
		pokeball_anterior.frame = 0
		pokeball_anterior.speed_scale = POKEBALL_FPS / 12.0  # Restaurar FPS normal
		
		# Resetear su timer a tiempo normal
		var timer_anterior = pokeball_timers[anterior_seleccion]
		timer_anterior.wait_time = randf_range(MIN_TIMER_DELAY, MAX_TIMER_DELAY)
		timer_anterior.start()
	
	# La pokeball actualmente seleccionada cambia a comportamiento especial
	var pokeball_actual = pokeballs[pokemon_seleccionado]
	pokeball_actual.stop()
	pokeball_actual.frame = 0
	
	# Configurar timer corto para pokeball seleccionada
	var timer_actual = pokeball_timers[pokemon_seleccionado]
	timer_actual.wait_time = SELECTED_POKEBALL_COOLDOWN
	timer_actual.start()
	
	# Desconectar cualquier señal de animación pendiente
	if pokeball_actual.animation_finished.is_connected(_on_pokeball_animation_finished):
		pokeball_actual.animation_finished.disconnect(_on_pokeball_animation_finished)

func _actualizar_seleccion():
	print("🎯 [Inicial] Actualizando selección para pokémon ", pokemon_seleccionado)
	
	if pokemon_data.is_empty():
		print("⚠️ [Inicial] pokemon_data está vacío, no se puede actualizar selección")
		return
		
	if pokemon_seleccionado >= pokemon_data.size():
		print("⚠️ [Inicial] Índice de selección fuera de rango: ", pokemon_seleccionado, " >= ", pokemon_data.size())
		return
	
	var data = pokemon_data[pokemon_seleccionado]
	print("📋 [Inicial] Datos del pokémon seleccionado: ", data.get("name", "desconocido"))
	
	# Detener animación cíclica anterior
	if cursor_tween:
		cursor_tween.kill()
	
	# Animar cursor hacia la nueva posición base
	if tween:
		tween.kill()
	tween = create_tween()
	
	var target_pos = CURSOR_POSITIONS[pokemon_seleccionado]
	tween.tween_property(cursor, "position", target_pos, 0.2)
	
	# Animar Box hacia la nueva posición
	var box_target_pos = BOX_POSITIONS[pokemon_seleccionado]
	tween.parallel().tween_property(info_box, "position", box_target_pos, 0.2)
	
	tween.tween_callback(_animacion_cursor_completada)
	
	# Actualizar información del Pokémon
	nombre_label.text = data.name + "\n" + data.description

func _animacion_cursor_completada():
	# Iniciar animación cíclica en la nueva posición
	_animar_cursor_ciclico()

func _confirmar_seleccion():
	print("🎯 [Inicial] Confirmando selección de pokémon...")
	# Mostrar vista previa del Pokémon
	_mostrar_pokemon_seleccionado()
	
	# Mostrar menú de confirmación
	_mostrar_menu_confirmacion()

func _mostrar_pokemon_seleccionado():
	var data = pokemon_data[pokemon_seleccionado]
	
	# Configurar sprite del Pokémon
	pokemon_sprite.texture = data.texture
	
	# Posicionar círculo en el centro de la pokeball seleccionada
	circle.position = data.position + Vector2(12, 12)
	circle.visible = true

	# Animar aparición del círculo y desplazamiento al centro
	if tween:
		tween.kill()
	tween = create_tween()
	
	circle.scale = Vector2.ZERO
	var end_pos = Vector2(120, 64)
	tween.tween_property(circle, "scale", Vector2.ONE, 0.2)
	tween.parallel().tween_property(circle, "position", end_pos, 0.2)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

	# Como en Rubí, el grito suena al aparecer el Pokémon, antes de la pregunta.
	_reproducir_grito(data)

## Reproduce el grito del Pokémon `data`; sin número nacional ni archivo, no suena.
func _reproducir_grito(data: Dictionary) -> void:
	var numero := _obtener_numero_nacional(data)
	if numero <= 0:
		return
	var ruta := RUTA_GRITO % numero
	if not ResourceLoader.exists(ruta):
		return
	var grito := AudioStreamPlayer.new()
	grito.stream = load(ruta) as AudioStream
	grito.finished.connect(grito.queue_free)
	add_child(grito)
	grito.play()

## Número nacional de la entrada; los datos por defecto no lo traen y se busca en la
## base de datos por su nombre interno.
func _obtener_numero_nacional(data: Dictionary) -> int:
	var numero := int(data.get("numero_nacional", 0))
	if numero > 0:
		return numero
	var nombre_interno := str(data.get("nombre_interno", data.get("name", "")))
	if nombre_interno.is_empty() or not DatabaseManager.esta_conectado():
		return 0
	return int(DatabaseManager.obtener_datos_pokemon(nombre_interno).get("numero_nacional", 0))

## Muestra el menú de confirmación Si/No
func _mostrar_menu_confirmacion() -> void:
	print("🎯 [Inicial] Iniciando menú de confirmación...")
	_detener_animacion_cursor()
	menu_confirmacion_activo = true
	
	# Mostrar mensaje de confirmación
	mensaje.text = MENSAJE_CONFIRMACION
	
	# Crear y mostrar el menú
	var posicion_menu = Vector2(168, 56)
	menu_confirmacion.crear_menu(posicion_menu)
	print("📋 [Inicial] Menú de confirmación creado y mostrado")


# Callback para el menú de confirmación
## Maneja la selección de una opción en el menú de confirmación.
func _on_menu_opcion_seleccionada(respuesta: String) -> void:
	print("🎯 [Inicial] Callback de menú ejecutado con respuesta: ", respuesta)

	# Convertir respuesta String a int para compatibilidad
	opcion_seleccionada = 0 if respuesta == "Y" else 1
	
	# Marcar que el menú ya no está activo. Diferido: la pulsación que confirmó SI/NO
	# sigue propagándose al _input de esta escena y, con el bloqueo ya levantado,
	# reabriría la confirmación y reharía la animación del Pokémon.
	set_deferred("menu_confirmacion_activo", false)
	print("📋 [Inicial] Menu confirmación marcado como inactivo")
	
	# Procesar la respuesta
	if respuesta == "Y":
		print("✅ [Inicial] Usuario confirmó selección - finalizando...")
		_finalizar_seleccion_pokemon()
	else:
		print("❌ [Inicial] Usuario canceló selección - regresando al menú...")
		mensaje.text = MENSAJE_INICIAL
		circle.visible = false
		_actualizar_estado_pokeball_seleccionada()
		_reanudar_animacion_cursor()
	

## Finaliza la selección del Pokémon inicial
func _finalizar_seleccion_pokemon():
	print("🎯 [Inicial] Finalizando selección de pokémon...")
	
	# Obtener información del pokémon seleccionado
	var pokemon_info = _obtener_pokemon_seleccionado()
	print("✅ [Inicial] Pokémon seleccionado: ", pokemon_info.get("name", "DESCONOCIDO"))
	print("📋 [Inicial] Datos completos: ", pokemon_info)
	
	# Detener todas las animaciones de pokeballs y cursor
	_detener_sistema_animacion_pokeballs()
	_detener_animacion_cursor()
	
	print("⏹️ [Inicial] Animaciones detenidas")
	
	# Emitir señal con los datos completos del pokémon seleccionado
	print("📡 [Inicial] Emitiendo señal seleccion_hecha...")
	seleccion_hecha.emit(pokemon_info)
	print("✅ [Inicial] Señal emitida correctamente")
	
	print("🏁 [Inicial] Selección finalizada correctamente")

## Detiene completamente el sistema de animación de pokeballs
func _detener_sistema_animacion_pokeballs():
	# Detener todos los timers
	for timer in pokeball_timers:
		if timer != null and timer.is_inside_tree():
			timer.stop()
	
	# Detener todas las animaciones y desconectar señales
	for i in range(pokeballs.size()):
		var pokeball = pokeballs[i]
		pokeball.stop()
		pokeball.frame = 0
		
		# Desconectar señales
		if pokeball.animation_finished.is_connected(_on_pokeball_animation_finished):
			pokeball.animation_finished.disconnect(_on_pokeball_animation_finished)

## Configura los pokémon usando datos externos del activador
func _configurar_pokemon_desde_datos(datos: Dictionary):
	print("🔧 [Inicial] Configurando pokémon desde datos externos...")
	print("🔧 [Inicial] Datos recibidos: ", datos)
	
	# Limpiar configuración actual
	pokemon_data.clear()
	print("🔧 [Inicial] pokemon_data limpiado, tamaño actual: ", pokemon_data.size())
	
	# Posiciones predefinidas para las pokeballs
	var posiciones = [
		Vector2(49, 52),   # Posición 1
		Vector2(109, 76),  # Posición 2  
		Vector2(169, 52)   # Posición 3
	]
	
	var pokemon_configurados = 0
	
	# Procesar hasta 3 pokémon
	for i in range(3):
		var key = "pokemon_" + str(i + 1)
		print("🔧 [Inicial] Procesando ", key, "...")
		
		if datos.has(key) and datos[key] is Dictionary:
			var info_pokemon = datos[key]
			print("📋 [Inicial] Configurando pokémon ", i+1, ": ", info_pokemon.get("name", "DESCONOCIDO"))
			print("📋 [Inicial] Info completa: ", info_pokemon)
			
			# Cargar textura del pokémon
			var texture = null
			var texture_path = info_pokemon.get("texture_path", "")
			
			if texture_path != "" and ResourceLoader.exists(texture_path):
				texture = load(texture_path)
				print("🖼️ [Inicial] Textura cargada: ", texture_path)
			else:
				print("⚠️ [Inicial] Textura no encontrada: ", texture_path, " - usando textura por defecto")
				# Intentar cargar textura por defecto basada en nombre_interno
				var nombre_interno = info_pokemon.get("nombre_interno", "")
				if nombre_interno != "":
					var ruta_defecto = "res://graficos/pokemon/front/" + nombre_interno + ".png"
					if ResourceLoader.exists(ruta_defecto):
						texture = load(ruta_defecto)
						print("🖼️ [Inicial] Textura por defecto cargada: ", ruta_defecto)
			
			# Crear entrada en pokemon_data
			var entrada_pokemon = {
				"name": info_pokemon.get("name", info_pokemon.get("nombre_interno", "DESCONOCIDO")),
				# "description": "\ue0a7\ue0a8 " + info_pokemon.get("description", "POKéMON"),
				"description": info_pokemon.get("description", "POKéMON"),
				"position": posiciones[i],
				"texture": texture,
				"nombre_interno": info_pokemon.get("nombre_interno", ""),
				"numero_nacional": info_pokemon.get("numero_nacional", 0)
			}
			
			pokemon_data.append(entrada_pokemon)
			pokemon_configurados += 1
			
			print("✅ [Inicial] Pokémon configurado: ", entrada_pokemon.name)
			print("✅ [Inicial] pokemon_data tamaño actual: ", pokemon_data.size())
		else:
			print("⚠️ [Inicial] No hay datos para pokémon en posición ", i+1, " o datos incorrectos")
			if datos.has(key):
				print("⚠️ [Inicial] Datos encontrados pero tipo incorrecto: ", type_string(typeof(datos[key])))
	
	# Si no se configuró ningún pokémon, usar configuración por defecto
	if pokemon_configurados == 0:
		print("⚠️ [Inicial] No se configuró ningún pokémon, restaurando configuración por defecto")
		_restaurar_configuracion_por_defecto()
	else:
		print("📊 [Inicial] Total pokémon configurados: ", pokemon_configurados)
		print("📊 [Inicial] pokemon_data final: ", pokemon_data)

## Restaura la configuración por defecto de pokémon
func _restaurar_configuracion_por_defecto():
	print("🔄 [Inicial] Restaurando configuración por defecto...")
	
	pokemon_data = [
		{
			"name": "TREECKO",
			"description": "\ue0a7\ue0a8 GECO BOSQUE",
			"position": Vector2(49, 52),
			"texture": preload("res://graficos/pokemon/front/TREECKO.png")
		},
		{
			"name": "TORCHIC", 
			"description": "PKMN POLLUELO",
			"position": Vector2(109, 76),
			"texture": preload("res://graficos/pokemon/front/TORCHIC.png")
		},
		{
			"name": "MUDKIP",
			"description": "PKMN PEZ LODO", 
			"position": Vector2(169, 52),
			"texture": preload("res://graficos/pokemon/front/MUDKIP.png")
		}
	]
	
	print("✅ [Inicial] Configuración por defecto restaurada")

## Obtiene información del pokémon seleccionado
func _obtener_pokemon_seleccionado() -> Dictionary:
	if pokemon_seleccionado >= 0 and pokemon_seleccionado < pokemon_data.size():
		return pokemon_data[pokemon_seleccionado]
	return {}

## Aclara la pantalla usando el telón si está disponible
func _aclarar_pantalla_inicial():
	print("🎬 [Inicial] Intentando aclarar pantalla...")
	Singleton.transicion("aclarar")

# API Pública

## Configura los nombres internos de los pokémon desde el activador
## Esta función se ejecuta ANTES que _ready(), por lo que solo guarda los datos
func set_iniciales(nombres_internos: Array):
	print("🎮 [Inicial] Recibiendo configuración de pokémon iniciales...")
	print("🎮 [Inicial] Nombres internos: ", nombres_internos)
	
	# Guardar los nombres internos para procesarlos en _ready()
	nombres_internos_configurados = nombres_internos.duplicate()
	
	print("✅ [Inicial] Nombres internos guardados, se procesarán en _ready()")

## Configura los pokémon usando los nombres internos guardados
## Esta función se ejecuta en _ready() cuando ya tenemos acceso a los singletons
func _configurar_pokemon_desde_nombres_internos(nombres_internos: Array):
	print("🔧 [Inicial] Configurando pokémon desde nombres internos en _ready()...")
	print("🔧 [Inicial] Nombres a configurar: ", nombres_internos)
	
	if nombres_internos.size() == 0:
		print("⚠️ [Inicial] No hay nombres internos para configurar")
		return
	
	# Obtener datos desde la base de datos para cada pokémon
	var database_manager = get_node_or_null("/root/DatabaseManager")
	if not database_manager:
		print("❌ [Inicial] Error: No se encontró DatabaseManager")
		return
	
	# Posiciones predefinidas para las pokeballs
	var posiciones = [
		Vector2(49, 52),   # Posición 1
		Vector2(109, 76),  # Posición 2  
		Vector2(169, 52)   # Posición 3
	]
	
	# Limpiar configuración actual
	pokemon_data.clear()
	print("🔧 [Inicial] pokemon_data limpiado, tamaño actual: ", pokemon_data.size())
	
	var pokemon_configurados = 0
	
	# Configurar cada pokémon con los datos de la base de datos
	for i in range(min(nombres_internos.size(), 3)):
		var nombre_interno = nombres_internos[i]
		if nombre_interno == "":
			print("⚠️ [Inicial] Pokémon en posición ", i+1, " está vacío")
			continue
			
		print("🔍 [Inicial] Configurando pokémon ", i+1, ": ", nombre_interno)
		
		# Obtener datos del pokémon
		var datos_pokemon = database_manager.obtener_datos_pokemon(nombre_interno)
		if datos_pokemon.is_empty():
			print("❌ [Inicial] Pokémon no encontrado: ", nombre_interno)
			continue
		
		# Obtener ruta de imagen
		var ruta_imagen = _obtener_ruta_imagen_pokemon(nombre_interno)
		var texture = null
		
		if ResourceLoader.exists(ruta_imagen):
			texture = load(ruta_imagen)
			print("🖼️ [Inicial] Textura cargada: ", ruta_imagen)
		else:
			print("⚠️ [Inicial] Textura no encontrada: ", ruta_imagen)
		
		# Crear entrada en pokemon_data
		var entrada_pokemon = {
			"name": datos_pokemon.get("nombre", nombre_interno),
			"description": "\ue0a7\ue0a8 " + datos_pokemon.get("categoria", "POKéMON"),
			"position": posiciones[i],
			"texture": texture,
			"nombre_interno": nombre_interno,
			"numero_nacional": datos_pokemon.get("numero_nacional", 0)
		}
		
		pokemon_data.append(entrada_pokemon)
		pokemon_configurados += 1
		
		print("✅ [Inicial] Pokémon configurado: ", entrada_pokemon.name, " - ", entrada_pokemon.description)
	
	# Si no se configuró ningún pokémon, usar configuración por defecto
	if pokemon_configurados == 0:
		print("⚠️ [Inicial] No se configuró ningún pokémon, restaurando configuración por defecto")
		_restaurar_configuracion_por_defecto()
	else:
		print("📊 [Inicial] Total pokémon configurados: ", pokemon_configurados)
		print("📊 [Inicial] pokemon_data final: ", pokemon_data.size(), " elementos")
	
	print("🎮 [Inicial] Configuración desde nombres internos completada")
	
	# Actualizar la selección visual después de configurar los pokémon
	_actualizar_seleccion()

## Función auxiliar para obtener ruta de imagen
func _obtener_ruta_imagen_pokemon(nombre_interno: String) -> String:
	var ruta_base = "res://graficos/pokemon/front/"
	var ruta_completa = ruta_base + nombre_interno + ".png"
	
	if ResourceLoader.exists(ruta_completa):
		print("🖼️ [Inicial] Imagen encontrada: ", ruta_completa)
		return ruta_completa
	else:
		print("⚠️ [Inicial] Imagen no encontrada: ", ruta_completa)
		return ruta_base + "MISSINGNO.png"

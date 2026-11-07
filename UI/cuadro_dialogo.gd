## Cuadro de diálogo
##
## Comandos de escape principales (usar dentro del texto):
##  - \p : separador de párrafos (divide texto en páginas; limpia el texto al avanzar)
##  - \l : separador de secciones/lineas dentro de un párrafo
##  - \w : pausa esperando pulsación de botón SIN limpiar el texto (muestra el
##        cursor de espera hasta tocar un botón). Puede usarse incluso a mitad
##        de línea; combínala con \l (\w\l) para esperar y luego saltar de línea.
##  - {esperar:segundos} : pausa automática durante 'segundos' antes de continuar
##  - {menu_confirmacion} : inserta un comando que abre el menú Si/No
##  - Para escribir una llave literal use la forma escapada: \{texto}
##
## Comandos de sustitución de texto:
##  - {PN} : reemplaza con el nombre del jugador actual
##
## Puntos de entrada públicos:
##  - cartel(txt, callback)
##  - cartel_con_señal(txt)
##  - cartel_con_comando(txt, comando, callback)
##  - mensaje_sin_esperar(txt)
##  - mensaje_autocierre(txt, callback, tiempo_espera)
##  - preguntaSiNo(txt)
##
## Señales / callbacks:
##  - signal texto_completado : emitida cuando termina el texto y se cierra/avanza
##  - signal comando_ejecutado(comando, parametros) : cuando se procesa un comando
##
## Uso rápido: pase cadenas que mezclen texto y comandos de escape; el script
## tokeniza el contenido, genera una cola de operaciones (texto/comandos) y
## las ejecuta secuencialmente usando una máquina de estados unificada.
##
## Estados del diálogo: IDLE, APARECIENDO, ESPERANDO_INPUT, MOSTRANDO_MENU, CERRANDO

extends NinePatchRect

@onready var label: RichTextLabel = $RichTextLabel
@onready var cursor: AnimatedSprite2D = $Cursor
var nodo_raiz: Node2D = null
var nodo_jugador: Node2D = null

# Componentes extraídos
var menu_confirmacion = null
## Etiquetas del próximo menú de preguntaSiNo.
var _opciones_menu: PackedStringArray = PackedStringArray(["SÍ", "NO"])
## Opción donde empieza el cursor del menú de confirmación (0 = la primera).
var _indice_inicial_menu: int = 0
## Desplazamiento (px) de un solo uso sobre la posición por defecto del menú.
var _desplazamiento_menu: Vector2 = Vector2.ZERO
## El próximo menú sale en la esquina superior izquierda de la pantalla (un solo uso).
var _menu_en_esquina: bool = false
var command_processor = null

# Define las velocidades posibles
enum Velocidad { LENTA, MEDIA, RAPIDA, TURBO }
var velocidad_actual: Velocidad = Velocidad.LENTA

# Define las velocidades de desplazamiento del texto en caracteres por segundo.
# Rubí (text.c, sTextSpeedDelays) espera 6/3/1 frames por carácter a 60 fps.
var velocidad_texto = {
	Velocidad.LENTA: 10,
	Velocidad.MEDIA: 20,
	Velocidad.RAPIDA: 60,
	Velocidad.TURBO: 64
}

var parrafos: Array = []

# Sistema de máquina de estados unificada
enum EstadoDialogo {
	IDLE,           # Inactivo/cerrado
	APARECIENDO,    # Mostrando texto con efecto typewriter
	ESPERANDO_INPUT, # Esperando entrada del usuario para continuar
	MOSTRANDO_MENU,  # Menú de confirmación activo
	ESPERANDO_REINGRESO, # Esperando reingreso de texto
	ESPERANDO_CIERRE_EXTERNO, # Texto completado, esperando cierre por código externo (no input usuario)
	CERRANDO        # En proceso de cierre
}

# Modo de cierre del diálogo
enum ModoCierre {
	NO_INPUT_NO_CLOSE,
	NO_INPUT_CLOSE,
	ON_INPUT_NO_CLOSE,
	ON_INPUT_CLOSE
}

var estado_dialogo: EstadoDialogo = EstadoDialogo.IDLE
var metadatos_estado: Dictionary = {}  # Datos específicos del estado actual

# Variables de control derivadas del estado (reemplaza banderas múltiples)
var esperando_entrada: bool = false:
	get:
		return estado_dialogo == EstadoDialogo.ESPERANDO_INPUT
var procesando_comandos: bool = false:
	get:
		return estado_dialogo == EstadoDialogo.MOSTRANDO_MENU
var esta_activo: bool = false:
	get:
		return estado_dialogo != EstadoDialogo.IDLE

var _char_progress: float = 0.0  # Acumulador fraccional para animar visible_characters
var _limpiar_al_avanzar: bool = false  # Indica que al avanzar (tras input) debe limpiarse el texto mostrado (cambio de párrafo)
var respetar_pausas_internas: bool = false
var omitir_siguiente_sonido_inicio: bool = false

# Variables de cierre unificado
var modo_cierre: ModoCierre = ModoCierre.ON_INPUT_CLOSE
var auto_close_delay: float = 0.0
var _auto_close_disparado: bool = false
var _fin_dialogo_esperando_cierre: bool = false  # Verdadero cuando terminó el texto y se espera acción de cierre según modo
const DELAY_BREVE := 0.3  # Tiempo adicional para eventos de cierre
const DELAY_BAJO := 0.05  # Tiempo adicional para eventos de cierre

# Función centralizada para transiciones de estado
func _transicionar(desde: EstadoDialogo, hacia: EstadoDialogo, causa: String = "") -> void:
	if estado_dialogo != desde and estado_dialogo != EstadoDialogo.ESPERANDO_REINGRESO:
		print("🗨️ [DIALOGO] ⚠️  Transición inválida: esperaba ", EstadoDialogo.keys()[desde], " pero está en ", EstadoDialogo.keys()[estado_dialogo])
		return

	var estado_anterior = estado_dialogo
	estado_dialogo = hacia

	print("🗨️ [DIALOGO] 🔄 Transición: ", EstadoDialogo.keys()[estado_anterior], " → ", EstadoDialogo.keys()[hacia],
		  ((" (" + causa + ")") if causa != "" else ""))

	# Ejecutar acciones de salida del estado anterior
	_on_estado_salida(estado_anterior)

	# Ejecutar acciones de entrada al nuevo estado
	_on_estado_entrada(hacia)

## Acciones al salir de un estado
func _on_estado_salida(estado_saliente: EstadoDialogo) -> void:
	match estado_saliente:
		EstadoDialogo.APARECIENDO:
			# Completar animación de texto
			label.visible_characters = label.get_total_character_count()
			_char_progress = 0.0
		EstadoDialogo.ESPERANDO_INPUT:
			# Ocultar cursor
			cursor.visible = false
		EstadoDialogo.MOSTRANDO_MENU:
			# Limpiar estado del menú
			menu_confirmacion_activo = false
		EstadoDialogo.ESPERANDO_REINGRESO:
			label.visible_characters = 0
			_char_progress = 0.0
		EstadoDialogo.ESPERANDO_CIERRE_EXTERNO:
			# No hay acciones especiales al salir de este estado
			pass
		EstadoDialogo.CERRANDO:
			# Estado final, no hay acciones de salida
			pass

## Acciones al entrar en un estado
func _on_estado_entrada(estado_entrante: EstadoDialogo) -> void:
	match estado_entrante:
		EstadoDialogo.IDLE:
			visible = false
			metadatos_estado.clear()
			# Restaurar control al jugador y desbloquear el administrador de mapas
			if nodo_raiz:
				Singleton.mantener_pausa(&"dialogo", false)
			if nodo_jugador:
				nodo_jugador.no_control = false
			# Resetear estado de velocidad al cerrar completamente el diálogo
			velocidad_actual = Velocidad.LENTA
			velocidad_original = Velocidad.LENTA
			tecla_accion_mantenida = false
			debe_soltar_tecla_primero = false
			print("🗨️ [DIALOGO] Estado reseteado al entrar en IDLE - velocidad restaurada a LENTA")
		EstadoDialogo.APARECIENDO:
			visible = true
			# Configurar controles del jugador
			if nodo_raiz:
				Singleton.mantener_pausa(&"dialogo", true)
			if nodo_jugador:
				nodo_jugador.no_control = true
		EstadoDialogo.ESPERANDO_INPUT:
			# Mostrar cursor si hay más texto pendiente
			cursor.visible = _hay_operaciones_texto_pendientes()
		EstadoDialogo.MOSTRANDO_MENU:
			cursor.visible = false
			menu_confirmacion_activo = true
		EstadoDialogo.ESPERANDO_REINGRESO:
			velocidad_actual = Velocidad.LENTA
			velocidad_original = Velocidad.LENTA
			tecla_accion_mantenida = false
			debe_soltar_tecla_primero = false
		EstadoDialogo.ESPERANDO_CIERRE_EXTERNO:
			# Estado pasivo: texto completado, visible pero sin esperar input del usuario
			visible = true
			cursor.visible = false
			# Mantener controles del jugador como están (no cambiar no_control)
			print("🗨️ [DIALOGO] Entrando en ESPERANDO_CIERRE_EXTERNO - diálogo visible, sin esperar input")
		EstadoDialogo.CERRANDO:
			cursor.visible = false
			# Iniciar secuencia de cierre
			_ejecutar_cierre_dialogo()

## Ejecuta la secuencia de cierre del diálogo
func _ejecutar_cierre_dialogo() -> void:
	print("🗨️ [DIALOGO] Ejecutando cierre del diálogo")
	# Limpiar estado
	cola_operaciones.clear()
	operacion_actual_index = 0
	ejecutando_operacion = false
	esperando_pregunta_sino = false
	tecla_accion_mantenida = false
	debe_soltar_tecla_primero = true
	label.visible_characters = 0
	_char_progress = 0.0
	callback_texto_completado = Callable()
	# Reset cierre unificado
	modo_cierre = ModoCierre.ON_INPUT_CLOSE
	auto_close_delay = 0.0
	_auto_close_disparado = false
	_fin_dialogo_esperando_cierre = false

	# Transicionar a IDLE
	_transicionar(EstadoDialogo.CERRANDO, EstadoDialogo.IDLE, "cierre completado")

## Verifica si hay operaciones de texto pendientes en la cola
func _hay_operaciones_texto_pendientes() -> bool:
	for i in range(operacion_actual_index + 1, cola_operaciones.size()):
		var op = cola_operaciones[i]
		if op.tipo == "texto":
			return true
	return false

# Sistema de comandos de escape y callbacks
signal texto_completado
signal comando_ejecutado(comando: String, parametros: Array)
var callback_texto_completado: Callable

# Callback opcional por página: se espera (await) al completarse la última
# sección de texto de una página, ANTES de transicionar a ESPERANDO_INPUT y
# mostrar el cursor de espera. Mientras se espera, el estado sigue en
# APARECIENDO: cursor oculto y el input no avanza el texto.
# Firma: (indice_parrafo: int, parrafo_final: bool, contenido: String)
var callback_pagina_completada: Callable = Callable()

# Sistema de cola de operaciones
var cola_operaciones: Array = []
var operacion_actual_index: int = 0
var ejecutando_operacion: bool = false
# Se incrementa al reemplazar la cola; las corrutinas de una cola anterior se abandonan.
var _generacion_cola: int = 0

# Variables para menú de confirmación
var menu_confirmacion_activo: bool = false
var opcion_seleccionada: int = 0  # 0 = SI, 1 = NO
var etiqueta_si: Label = null
var etiqueta_no: Label = null
var cursor_menu: PkSelectorSimple = null
var menu_input_bloqueado: bool = false
var menu_confirmacion_node: NinePatchRect = null

# Variables para control de entrada avanzado
var tecla_accion_mantenida: bool = false
var velocidad_original: Velocidad
var esperando_pregunta_sino: bool = false
var debe_soltar_tecla_primero: bool = false  # Evita acelerar si viene de menú anterior
# Eliminadas banderas legacy de cierre (no_cerrar_automaticamente, cerrar_al_presionar, callback_diferido_hasta_input)

const FUENTE := preload("res://fuentes/pokemon-rs.ttf")
const LABEL_SETTINGS := preload("res://UI/texto_normal_negro.tres")

# Gestor de texturas dinámico

func _get_saved_image_type() -> int:
	var sg = get_tree().root.get_node_or_null("SistemaGuardado")
	if sg and sg.datos_vivos and sg.datos_vivos.opciones:
		return int(sg.datos_vivos.opciones.imagen_tipo)
	if typeof(SistemaGuardado) != TYPE_NIL and SistemaGuardado.datos_vivos and SistemaGuardado.datos_vivos.opciones:
		return int(SistemaGuardado.datos_vivos.opciones.imagen_tipo)
	return 1

func _ready() -> void:
	label.text = ""
	visible = false
	position = Vector2(0,112)

	# Inicializar componentes
	command_processor = preload("res://UI/DialogCommandProcessor.gd").new()
	menu_confirmacion = preload("res://UI/MenuConfirmacion.gd").new()
	add_child(menu_confirmacion)

	# Conectar señales del menú
	menu_confirmacion.opcion_seleccionada.connect(_on_menu_opcion_seleccionada)

	# Sincronizar velocidad desde opciones y suscribirse a cambios
	_sync_velocidad_desde_opciones()
	if Singleton and Singleton.has_signal("opciones_cambiadas") and not Singleton.is_connected("opciones_cambiadas", Callable(self, "_sync_velocidad_desde_opciones")):
		Singleton.connect("opciones_cambiadas", Callable(self, "_sync_velocidad_desde_opciones"))

func _process(delta: float) -> void:
	if nodo_raiz == null:
		nodo_raiz = get_tree().root.get_node_or_null("AdministradorMapa")
		if nodo_raiz:
			nodo_jugador = nodo_raiz.jugador

	# Solo actualizar texto si estamos en estado de aparición
	if estado_dialogo == EstadoDialogo.APARECIENDO:
		_actualizar_texto(delta)

func _actualizar_texto(delta: float) -> void:
	# Verificar si se está manteniendo la tecla de acción para acelerar
	var acelerando = (Input.is_action_pressed("btn_accion") or Input.is_action_pressed("btn_cancelar")) and not debe_soltar_tecla_primero
	if acelerando:
		if not tecla_accion_mantenida:
			tecla_accion_mantenida = true
			velocidad_original = velocidad_actual
			velocidad_actual = Velocidad.TURBO
			print("🗨️ [DIALOGO] Acelerando texto (TURBO) desde %s" % velocidad_original)
	else:
		if tecla_accion_mantenida:
			tecla_accion_mantenida = false
			velocidad_actual = velocidad_original
			print("🗨️ [DIALOGO] Restaurando velocidad original %s" % velocidad_original)
		if debe_soltar_tecla_primero and (Input.is_action_just_released("btn_accion") or Input.is_action_just_released("btn_cancelar")):
			debe_soltar_tecla_primero = false
			print("🗨️ [DIALOGO] Tecla soltada - aceleración habilitada nuevamente")

	# Animación basada en visible_characters (enteros) para evitar flashes al hacer append_text
	var total_chars = label.get_total_character_count()
	if total_chars > 0 and label.visible_characters < total_chars:
		_char_progress += delta * velocidad_texto[velocidad_actual]
		var avanzar = int(_char_progress)
		if avanzar > 0:
			label.visible_characters = min(total_chars, label.visible_characters + avanzar)
			_char_progress -= avanzar

## Punto de entrada para mostrar el texto de un cartel
func cartel(txt: String) -> void:
	print("🗨️ [DIALOGO] Iniciando cartel: ", txt)
	debe_soltar_tecla_primero = true
	modo_cierre = ModoCierre.ON_INPUT_CLOSE
	_mostrar_texto(txt)

## Pregunta de confirmación
## `opciones`: etiquetas de las dos respuestas (la primera responde "Y").
## `multichoice 0, 0, …`: el próximo menú de preguntaSiNo() sale en la esquina superior
## izquierda de la pantalla en lugar de sobre el cuadro.
func fijar_menu_en_esquina() -> void:
	_menu_en_esquina = true


func preguntaSiNo(txt: String, opciones: PackedStringArray = PackedStringArray(["SÍ", "NO"]), indice_inicial: int = 0, desplazamiento: Vector2 = Vector2.ZERO) -> void:
	print("🗨️ [DIALOGO] Iniciando pregunta con respuesta Si/No: ", txt)
	esperando_pregunta_sino = true
	debe_soltar_tecla_primero = true
	_sync_velocidad_desde_opciones()

	# Generar la cola SIN iniciar la ejecución aún
	_preparar_texto(txt)

	# Añadir operación de comando opera_menu_confirmacion al final de la cola
	cola_operaciones.append({
		"tipo": "comando",
		"comando": "opera_menu_confirmacion",
		"parametros": ["SÍ", "NO"]
	})
	_opciones_menu = opciones
	_indice_inicial_menu = indice_inicial
	_desplazamiento_menu = desplazamiento

	# Imprimir todas las operaciones creadas
	_logger("  -- Lista de operaciones en cola:")
	for op in cola_operaciones:
		print("🗨️ [DIALOGO] Operación: ", op)

	# Iniciar ejecución de la cola ahora que incluye el comando
	_transicionar(EstadoDialogo.IDLE, EstadoDialogo.APARECIENDO, "pregunta Si/No")
	_ejecutar_siguiente_operacion()

# Mensaje sin esperar - no bloquea la ejecución del código llamador
func mensaje_sin_esperar(txt: String) -> void:
	_logger("🗨️ [DIALOGO] Mensaje sin esperar: %s | label char ratio: %s / %s" % [txt, label.visible_characters, label.get_total_character_count()])
	# Forzar reset completo del estado para evitar conflictos
	if estado_dialogo != EstadoDialogo.IDLE:
		print("🗨️ [DIALOGO] [mensaje_sin_esperar] Forzando cierre de diálogo anterior")
		_transicionar(estado_dialogo, EstadoDialogo.IDLE, "reset para mensaje_sin_esperar")
	debe_soltar_tecla_primero = true
	tecla_accion_mantenida = false
	modo_cierre = ModoCierre.NO_INPUT_NO_CLOSE
	_mostrar_texto(txt, false)

# Mensaje que se muestra normalmente y se auto-cierra después de un tiempo
func mensaje_autocierre(txt: String, callback: Callable = Callable(), tiempo_espera: float = 2.0) -> void:
	print("🗨️ [DIALOGO] Mensaje con auto-cierre: ", txt, " (espera: ", tiempo_espera, "s)")
	debe_soltar_tecla_primero = true
	callback_texto_completado = callback
	auto_close_delay = tiempo_espera
	modo_cierre = ModoCierre.NO_INPUT_CLOSE
	_mostrar_texto(txt)

## Función para abrir el cuadro de diálogo
## mensaje: El mensaje a mostrar en el cuadro de diálogo
## esperar_entrada: Si debe esperar a que el jugador presione una tecla
## cerrar_dialogo: Si debe cerrar el diálogo después de mostrar el mensaje
## Cierra el cuadro de diálogo inmediatamente, restaurando el control al jugador.
## Seguro de llamar desde cualquier estado, incluyendo ESPERANDO_REINGRESO tras preguntaSiNo.
func cerrar() -> void:
	if estado_dialogo == EstadoDialogo.IDLE:
		return
	_transicionar(estado_dialogo, EstadoDialogo.IDLE, "cierre forzado externo")
	_limpiar_estado_anterior()
	visible = false

func mostrar(mensaje: String, esperar_entrada: bool = true, cerrar_dialogo: bool = true, callback: Callable = Callable(), mantener_pausas_internas: bool = false, omitir_sonido_inicio: bool = false) -> void:
	print("🗨️ [DIALOGO] Abriendo cuadro de diálogo: ", mensaje)
	print("🗨️ [DIALOGO] Parámetros - esperar_entrada: ", esperar_entrada, " cerrar_dialogo: ", cerrar_dialogo)

	# FORZAR RESET COMPLETO si no estamos en IDLE
	if estado_dialogo != EstadoDialogo.IDLE:
		print("🗨️ [DIALOGO] ⚠️ Forzando reset: estado actual es ", EstadoDialogo.keys()[estado_dialogo])
		_transicionar(estado_dialogo, EstadoDialogo.IDLE, "reset forzado antes de mostrar")
		# Limpiar completamente el estado
		_limpiar_estado_anterior()

	debe_soltar_tecla_primero = true
	callback_texto_completado = callback
	omitir_siguiente_sonido_inicio = omitir_sonido_inicio

	# Mapear comportamiento de cierre basado en los parámetros
	if not cerrar_dialogo and not esperar_entrada:
		# No cerrar y no esperar entrada: ejecutar callback inmediatamente tras mostrar texto
		modo_cierre = ModoCierre.NO_INPUT_NO_CLOSE
		print("🗨️ [DIALOGO] Configurado modo NO_INPUT_NO_CLOSE")
	elif not cerrar_dialogo and esperar_entrada:
		# No cerrar pero esperar entrada: usar ON_INPUT_NO_CLOSE (mantener abierto tras input)
		modo_cierre = ModoCierre.ON_INPUT_NO_CLOSE
		print("🗨️ [DIALOGO] Configurado modo ON_INPUT_NO_CLOSE")
	elif cerrar_dialogo and not esperar_entrada:
		# Cerrar sin esperar entrada: auto-cerrar tras mostrar texto
		modo_cierre = ModoCierre.NO_INPUT_CLOSE
		print("🗨️ [DIALOGO] Configurado modo NO_INPUT_CLOSE")
	else:
		# Cerrar y esperar entrada: comportamiento estándar
		modo_cierre = ModoCierre.ON_INPUT_CLOSE
		print("🗨️ [DIALOGO] Configurado modo ON_INPUT_CLOSE")

	print("🗨️ [DIALOGO] Modo confirmado antes de _mostrar_texto: ", modo_cierre)
	_mostrar_texto(mensaje, true, mantener_pausas_internas)

## Muestra un mensaje ya completado, sin typewriter, cursor ni avance por
## botones. Está pensado para estados de desarrollo o mensajes pasivos que
## deben permanecer visibles mientras otra interfaz recibe el input.
func mostrar_inmediatamente(mensaje: String) -> void:
	if estado_dialogo != EstadoDialogo.IDLE:
		_transicionar(estado_dialogo, EstadoDialogo.IDLE, "reset antes de mostrar inmediatamente")
		_limpiar_estado_anterior()

	_generacion_cola += 1
	cola_operaciones.clear()
	operacion_actual_index = 0
	ejecutando_operacion = false
	callback_texto_completado = Callable()
	modo_cierre = ModoCierre.NO_INPUT_NO_CLOSE
	_fin_dialogo_esperando_cierre = false
	# Misma presentación que el diálogo animado ({PN}, {PO}, {Ké}, etc.),
	# sin ejecutar esperas ni comandos interactivos en un mensaje pasivo.
	label.text = command_processor.procesar_comandos_sustitucion(mensaje)
	label.visible_characters = label.get_total_character_count()
	_char_progress = 0.0
	_transicionar(EstadoDialogo.IDLE, EstadoDialogo.ESPERANDO_CIERRE_EXTERNO, "mensaje inmediato")

## Vacía el texto del cuadro dejándolo visible, sin cursor y sin esperar
## input. Para limpiezas externas entre mensajes (p. ej. keyframes de
## AnimationPlayer en partida_nueva): el contenido se escribió con
## append_text, así que se usa clear() y no basta un string vacío.
func limpiar_texto() -> void:
	if estado_dialogo != EstadoDialogo.IDLE:
		_transicionar(estado_dialogo, EstadoDialogo.IDLE, "reset antes de limpiar texto")
	_limpiar_estado_anterior()
	_generacion_cola += 1
	cola_operaciones.clear()
	operacion_actual_index = 0
	ejecutando_operacion = false
	callback_texto_completado = Callable()
	modo_cierre = ModoCierre.NO_INPUT_NO_CLOSE
	_fin_dialogo_esperando_cierre = false
	label.clear()
	label.text = ""
	label.visible_characters = 0
	_char_progress = 0.0
	_transicionar(EstadoDialogo.IDLE, EstadoDialogo.ESPERANDO_CIERRE_EXTERNO, "limpiar texto")

# Callback para el menú de confirmación
## Maneja la selección de una opción en el menú de confirmación.
func _on_menu_opcion_seleccionada(respuesta: String) -> void:
	print("🗨️ [DIALOGO] Opción seleccionada en menú: ", respuesta)

	# Convertir respuesta String a int para compatibilidad
	opcion_seleccionada = 0 if respuesta == "Y" else 1
	if respuesta.is_valid_int():  # menú de más de dos opciones: el índice
		opcion_seleccionada = int(respuesta)

	# Marcar que el menú ya no está activo
	# menu_confirmacion_activo = false
	_transicionar(EstadoDialogo.MOSTRANDO_MENU, EstadoDialogo.ESPERANDO_REINGRESO, "opción ya seleccionada")

	# Emitir señal compatible con el sistema de confirmación
	emit_signal("comando_ejecutado", "respuesta_confirmacion", [respuesta])

	# NO llamar _ejecutar_siguiente_operacion aquí porque estamos en un bucle await
	print("🗨️ [DIALOGO] Menú cerrado, menu_confirmacion_activo=", menu_confirmacion_activo)

## Muestra el menú de confirmación Si/No
func _mostrar_menu_confirmacion() -> void:
	print("🗨️ [DIALOGO] ⭐ Iniciando menú de confirmación")

	# Marcar que estamos procesando comandos
	procesando_comandos = true
	menu_confirmacion_activo = true

	print("🗨️ [DIALOGO] Estado marcado: procesando_comandos=", procesando_comandos, " menu_confirmacion_activo=", menu_confirmacion_activo)

	# Cambiar al estado de mostrando menú
	_transicionar(estado_dialogo, EstadoDialogo.MOSTRANDO_MENU, "menú de confirmación")

	# Crear y mostrar el menú
	var posicion_menu = Vector2(160, -48)  # Posición por defecto
	print("🗨️ [DIALOGO] Llamando menu_confirmacion.crear_menu en posición: ", posicion_menu)
	menu_confirmacion.indice_inicial = _indice_inicial_menu
	menu_confirmacion.en_esquina = _menu_en_esquina
	_menu_en_esquina = false
	menu_confirmacion.crear_menu(posicion_menu + _desplazamiento_menu, _opciones_menu)
	_opciones_menu = PackedStringArray(["SÍ", "NO"])
	_indice_inicial_menu = 0
	_desplazamiento_menu = Vector2.ZERO

	print("🗨️ [DIALOGO] Esperando hasta que el menú no esté activo...")
	# Esperar hasta que el menú no esté activo (se haya seleccionado una opción)
	while menu_confirmacion_activo:
		# print("🗨️ [DIALOGO] Bucle de espera, menu_confirmacion_activo=", menu_confirmacion_activo)
		await get_tree().create_timer(0.1).timeout

	print("🗨️ [DIALOGO] ⭐ Menú de confirmación terminado")

## Función interna para mostrar texto (reemplaza mostrar_txt)
func _mostrar_texto(txt: String, tomar_control: bool = true, mantener_pausas_internas: bool = false) -> void:
	# Restablecer velocidad y aceleración al abrir el cuadro
	_sync_velocidad_desde_opciones()
	# velocidad_actual = velocidad_actual  # Se asegura que la velocidad sea la de opciones
	print("🗨️ [DIALOGO] Velocidad actual sincronizada: ", velocidad_actual)
	tecla_accion_mantenida = false
	print("🗨️ [DIALOGO] _mostrar_texto iniciado: ", txt)

	# Si no estamos en IDLE, limpiar estado anterior
	if estado_dialogo != EstadoDialogo.IDLE:
		print("🗨️ [DIALOGO] Limpiando estado anterior")
		_limpiar_estado_anterior()
	respetar_pausas_internas = mantener_pausas_internas

	# Preparar el texto y generar operaciones
	_preparar_texto(txt)

	# Tomar control del jugador si es necesario
	if tomar_control:
		if nodo_raiz:
			Singleton.mantener_pausa(&"dialogo", true)
		if nodo_jugador:
			nodo_jugador.no_control = true

	# Iniciar ejecución
	_transicionar(EstadoDialogo.IDLE, EstadoDialogo.APARECIENDO, "inicio de _mostrar_texto")
	_ejecutar_siguiente_operacion()

## Prepara el texto y genera la cola de operaciones sin iniciar ejecución
func _preparar_texto(txt: String) -> void:
	# Protección: descartar párrafos vacíos al final (p. ej. \p colgante) para
	# no crear una página vacía que exigiría una pulsación extra sin contenido.
	parrafos = _recortar_vacios_finales(txt.split("\\p"))
	if parrafos.size() == 0:
		print("🗨️ [DIALOGO] Sin párrafos, cerrando")
		cierra_dialogo()
		return

	# Inicializar estado de renderizado
	label.visible_characters = 0
	_char_progress = 0.0
	label.text = ""

	# Generar cola de operaciones a partir de los párrafos
	_generar_cola_operaciones()


## Lee la opción guardada de velocidad (1..3) y la aplica a velocidad_actual.
## No modifica TURBO si está activo; actualiza velocidad_original si aplica.
func _sync_velocidad_desde_opciones() -> void:
	var velocidad_opt = null
	if typeof(SistemaGuardado) != TYPE_NIL and SistemaGuardado.datos_vivos and SistemaGuardado.datos_vivos.opciones:
		velocidad_opt = int(SistemaGuardado.datos_vivos.opciones.velocidad_texto)
		_logger("🗨️ [DIALOGO] Velocidad de texto leida: %s" % velocidad_opt)


	if velocidad_opt != null:
		var mapa = { 1: Velocidad.LENTA, 2: Velocidad.MEDIA, 3: Velocidad.RAPIDA }
		if velocidad_opt in mapa:
			var nueva = mapa[velocidad_opt]
			velocidad_actual = nueva
			velocidad_original = nueva
			print("🗨️ [DIALOGO] _sync_velocidad_desde_opciones -> velocidad_actual=", velocidad_actual, " chars/s=", velocidad_texto[velocidad_actual])
		else:
			velocidad_original = Velocidad.LENTA
			velocidad_actual = Velocidad.LENTA
			print("🗨️ [DIALOGO] _sync_velocidad_desde_opciones => velocidad_original=", velocidad_original, " velocidad_actual=", velocidad_actual)

	else:
		velocidad_original = Velocidad.LENTA
		velocidad_actual = Velocidad.LENTA
		print("🗨️ [DIALOGO] _sync_velocidad_desde_opciones ==> velocidad_original=", velocidad_original, " velocidad_actual=", velocidad_actual)

## Limpia cualquier estado anterior del diálogo para evitar conflictos
func _limpiar_estado_anterior() -> void:
	print("🗨️ [DIALOGO] Limpiando estado anterior")
	_generacion_cola += 1
	ejecutando_operacion = false
	procesando_comandos = false
	cola_operaciones.clear()
	operacion_actual_index = 0
	esperando_entrada = false
	esperando_pregunta_sino = false
	modo_cierre = ModoCierre.ON_INPUT_CLOSE
	auto_close_delay = 0.0
	_auto_close_disparado = false
	_fin_dialogo_esperando_cierre = false
	cursor.visible = false
	label.visible_characters = 0
	_char_progress = 0.0
	if menu_confirmacion_activo:
		menu_confirmacion.ocultar_menu()
		menu_confirmacion_activo = false

## Elimina los elementos vacíos (o solo espacios) del final de un array
## empaquetado, conservando siempre al menos un elemento. Evita que etiquetas
## colgantes (\p, \l, \w) generen páginas, saltos u operaciones vacías.
func _recortar_vacios_finales(elementos: PackedStringArray) -> PackedStringArray:
	while elementos.size() > 1 and elementos[elementos.size() - 1].strip_edges() == "":
		elementos.remove_at(elementos.size() - 1)
	return elementos

## Convierte los párrafos en una cola de operaciones secuenciales.
## Estructura por párrafo: primero se divide por \w (pausa esperando botón,
## sin limpiar el texto) en trozos, y cada trozo se divide por \l (salto de
## línea). Así \w funciona incluso a mitad de línea y \w\l espera y salta.
func _generar_cola_operaciones() -> void:
	_generacion_cola += 1
	cola_operaciones.clear()
	operacion_actual_index = 0
	ejecutando_operacion = false

	for i in range(parrafos.size()):
		var parrafo: String = parrafos[i]
		var es_parrafo_final := (i == parrafos.size() - 1)
		var indices_operaciones_parrafo: Array = []

		var trozos := _recortar_vacios_finales(parrafo.split("\\w"))
		for t in range(trozos.size()):
			var secciones := _recortar_vacios_finales((trozos[t] as String).split("\\l"))
			for j in range(secciones.size()):
				var seccion := secciones[j] as String
				# Tokenizar la sección para encontrar texto y comandos
				_logger("🗨️ [DIALOGO] Procesando párrafo %d, sección %d: %s" % [i, j, seccion])
				var tokens = command_processor.split_section_tokens(seccion)
				for token in tokens:
					if typeof(token) == TYPE_STRING:
						# Secciones vacías (\l o \p colgantes): se omiten sin error
						if (token as String).strip_edges() == "":
							continue
						var operacion_texto := {
							"tipo": "texto",
							"contenido": token,
							"indice_parrafo": i,
							"parrafo_final": es_parrafo_final
						}
						indices_operaciones_parrafo.append(cola_operaciones.size())
						cola_operaciones.append(operacion_texto)
					else:
						var operacion_comando := {
							"tipo": "comando",
							"comando": token.get("comando", ""),
							"parametros": token.get("parametros", []),
							"indice_parrafo": i,
							"parrafo_final": es_parrafo_final
						}
						cola_operaciones.append(operacion_comando)

				if j < secciones.size() - 1:
					cola_operaciones.append({
						"tipo": "salto_linea",
						"indice_parrafo": i,
						"parrafo_final": es_parrafo_final
					})

			# Entre trozos separados por \w: pausa esperando pulsación de botón
			if t < trozos.size() - 1:
				cola_operaciones.append({
					"tipo": "esperar_input",
					"indice_parrafo": i,
					"parrafo_final": es_parrafo_final
				})

		# Marcar la última operación de texto REAL del párrafo (si existe)
		if indices_operaciones_parrafo.size() > 0:
			var idx_ultimo_texto = indices_operaciones_parrafo.back()
			cola_operaciones[idx_ultimo_texto]["ultimo_de_parrafo"] = true
			# Si NO es el último párrafo general, insertamos marcador de pausa de párrafo
			if not es_parrafo_final:
				cola_operaciones.append({
					"tipo": "pausa_parrafo",
					"indice_parrafo": i,
					"parrafo_final": false
				})

	print("🗨️ [DIALOGO] Cola generada con ", cola_operaciones.size(), " operaciones (parrafos=", parrafos.size(), ")")



## Ejecuta operaciones en la cola de forma iterativa.
## Procesa operaciones hasta terminar la cola o activar un comando modal (procesando_comandos == true).
## Evita recursión y reentradas usando la bandera `ejecutando_operacion`.
func _ejecutar_siguiente_operacion() -> void:
	if ejecutando_operacion:
		print("🗨️ [DIALOGO] Ya ejecutando operación, ignorando")
		return

	# Limpiar pantalla si venimos de un salto de párrafo
	if _limpiar_al_avanzar:
		label.clear()
		label.text = ""
		label.visible_characters = 0
		_char_progress = 0.0
		_limpiar_al_avanzar = false

	if operacion_actual_index >= cola_operaciones.size():
		print("🗨️ [DIALOGO] Cola completada")
		_finalizar_todas_operaciones()
		return

	ejecutando_operacion = true
	var generacion := _generacion_cola

	# Procesar tantas operaciones como sea posible hasta que se requiera
	# interacción modal (procesando_comandos) o la cola termine.
	while operacion_actual_index < cola_operaciones.size():
		var operacion = cola_operaciones[operacion_actual_index]
		print("🗨️ [DIALOGO] Ejecutando operación ", operacion_actual_index, ": ", operacion.tipo)
		var romper_por_parrafo: bool = false
		var romper_por_espera_input: bool = false

		match operacion.tipo:
			"texto":
				await _ejecutar_operacion_texto(operacion)
				if generacion != _generacion_cola:
					return
				# Si esta operación es el último texto del párrafo y NO es el párrafo final, detener loop para esperar input
				if operacion.get("ultimo_de_parrafo", false) and not operacion.get("parrafo_final", false):
					romper_por_parrafo = true
			"comando":
				await _ejecutar_operacion_comando(operacion)
				if generacion != _generacion_cola:
					return
			"salto_linea":
				_ejecutar_operacion_salto_linea()
			"pausa_parrafo":
				# Marcador lógico: al llegar aquí significa que ya se mostró el párrafo anterior y se presionó una tecla
				# Limpiar antes de continuar con el siguiente párrafo
				# (La limpieza real se hará al iniciar _ejecutar_siguiente_operacion nuevamente)
				pass
			"esperar_input":
				# Etiqueta \w: pausa esperando una pulsación de botón SIN limpiar
				# el texto (el salto \l, si lo hay, se ejecuta al reanudar).
				if (modo_cierre == ModoCierre.NO_INPUT_NO_CLOSE or modo_cierre == ModoCierre.NO_INPUT_CLOSE) and not respetar_pausas_internas:
					print("🗨️ [DIALOGO] \\w omitido: modo sin input del jugador")
				else:
					if estado_dialogo != EstadoDialogo.ESPERANDO_INPUT:
						_transicionar(estado_dialogo, EstadoDialogo.ESPERANDO_INPUT, "etiqueta \\w")
					cursor.visible = _hay_operaciones_texto_pendientes()
					print("🗨️ [DIALOGO] \\w: esperando pulsación del jugador")
					romper_por_espera_input = true

		# Si durante la ejecución se activó un comando modal, pausamos el loop
		operacion_actual_index += 1
		if procesando_comandos:
			print("🗨️ [DIALOGO] Comando modal activado, pausando ejecución de la cola")
			break
		if romper_por_parrafo:
			print("🗨️ [DIALOGO] Fin de párrafo: esperando input del jugador")
			# Mostrar cursor (ya lo hace la entrada de estado) y preparar limpieza al avanzar
			_limpiar_al_avanzar = true
			break
		if romper_por_espera_input:
			# Sin _limpiar_al_avanzar: al reanudar continúa el texto donde quedó
			break

	ejecutando_operacion = false

	# Si llegamos al final de la cola y no hay comando modal, finalizar
	if operacion_actual_index >= cola_operaciones.size() and not procesando_comandos:
		print("🗨️ [DIALOGO] Cola completada tras loop")
		_finalizar_todas_operaciones()

## Ejecuta una operación de texto
func _ejecutar_operacion_texto(operacion: Dictionary) -> void:
	print("🗨️ [DIALOGO] Mostrando texto: '", operacion.contenido, "'")

	# No sonar si esta sección continúa tras un \l (salto de línea manual dentro
	# del mismo párrafo): no es un avance real solicitado por el jugador.
	var op_anterior = cola_operaciones[operacion_actual_index - 1] if operacion_actual_index > 0 else null
	var es_continuacion_de_salto_linea = op_anterior != null and op_anterior.get("tipo", "") == "salto_linea"
	var omitir_sonido := omitir_siguiente_sonido_inicio
	omitir_siguiente_sonido_inicio = false
	if not es_continuacion_de_salto_linea and not omitir_sonido:
		Singleton.emit_signal("play_sound", "cursor_menu")

	# Transicionar a estado de aparición si no estamos ya ahí
	if estado_dialogo != EstadoDialogo.APARECIENDO:
		_transicionar(estado_dialogo, EstadoDialogo.APARECIENDO, "nueva operación de texto")

	# Guardar cuántos caracteres ya eran visibles para mantenerlos tras el append
	var visibles_previos = label.visible_characters
	label.append_text(operacion.contenido)
	# Mantener visible_characters (los nuevos quedan ocultos)
	label.visible_characters = visibles_previos

	# Configurar si hay más texto después
	var _es_ultima_operacion = (operacion_actual_index == cola_operaciones.size() - 1)
	var _hay_parrafos_pendientes = _hay_operaciones_texto_pendientes()

	# Esperar a que terminen de mostrarse los nuevos caracteres
	var generacion := _generacion_cola
	await _esperar_texto_completo()
	if generacion != _generacion_cola:
		return

	# Hook opcional: al completar la última sección de texto de una página,
	# esperar (p. ej., una animación de escena) antes de mostrar el cursor.
	if operacion.get("ultimo_de_parrafo", false) and callback_pagina_completada.is_valid():
		await callback_pagina_completada.call(
			operacion.get("indice_parrafo", -1),
			operacion.get("parrafo_final", false),
			str(operacion.get("contenido", ""))
		)

	# Transicionar a espera de input después de mostrar el texto
	_transicionar(EstadoDialogo.APARECIENDO, EstadoDialogo.ESPERANDO_INPUT, "texto completado")

## Espera a que todos los caracteres agregados estén visibles
func _esperar_texto_completo() -> void:
	var waited: float = 0.0
	var tick: float = 0.05
	var timeout: float = 5.0
	while estado_dialogo == EstadoDialogo.APARECIENDO and label.visible_characters < label.get_total_character_count() and waited < timeout:
		await get_tree().create_timer(tick).timeout
		waited += tick
	if label.visible_characters < label.get_total_character_count():
		print("🗨️ [DIALOGO] Timeout animando texto, forzando completion")
		label.visible_characters = label.get_total_character_count()

func _esperar_entrada() -> void:
	# Si hay callback activo, no esperar entrada del usuario - avanzar automáticamente
	if callback_texto_completado.is_valid():
		print("🗨️ [DIALOGO] Avance automático - hay callback activo")
		# Esperar que el texto termine de aparecer
		while estado_dialogo == EstadoDialogo.APARECIENDO:
			await get_tree().create_timer(0.1).timeout
		return

	# Comportamiento normal - esperar entrada del usuario
	var waited := 0.0
	var tick := 0.1
	var timeout := 60.0 # segundos máximos para esperar entrada del usuario
	while esperando_entrada and waited < timeout:
		await get_tree().create_timer(tick).timeout
		waited += tick

	if esperando_entrada:
		# Si se agotó el timeout, avanzar automáticamente para evitar bloqueo
		print("🗨️ [DIALOGO] Timeout esperando entrada del usuario, continuando automáticamente")

	cursor.visible = false

## Ejecuta una operación de comando
func _ejecutar_operacion_comando(operacion: Dictionary) -> void:
	print("🗨️ [DIALOGO] Ejecutando comando: ", operacion.comando)
	label.visible_characters = label.get_total_character_count()
	_transicionar(estado_dialogo, EstadoDialogo.ESPERANDO_INPUT, "antes de comando")
	cursor.visible = false
	print("🗨️ [DIALOGO] Llamando command_processor.ejecutar_comando...")
	var resultado = command_processor.ejecutar_comando(operacion.comando, Array(operacion.get("parametros", [])))
	print("🗨️ [DIALOGO] Resultado del comando: ", resultado)
	if resultado and resultado.has("tipo"):
		print("🗨️ [DIALOGO] Procesando resultado de tipo: ", resultado.tipo)
		match resultado.tipo:
			"modal":
				if resultado.datos == "menu_si_no":
					print("🗨️ [DIALOGO] Mostrando menú de confirmación")
					var generacion := _generacion_cola
					await _mostrar_menu_confirmacion()
					if generacion != _generacion_cola:
						return
					print("🗨️ [DIALOGO] Menú de confirmación completado")
			"espera":
				if resultado.has("datos") and typeof(resultado.datos) == TYPE_FLOAT:
					print("🗨️ [DIALOGO] Esperando: ", resultado.datos, " segundos")
					await get_tree().create_timer(resultado.datos).timeout
			"configuracion":
				if resultado.has("datos") and resultado.datos.has("velocidad"):
					print("🗨️ [DIALOGO] Cambiando velocidad a: ", resultado.datos.velocidad)
					velocidad_actual = resultado.datos.velocidad
	else:
		print("🗨️ [DIALOGO] ⚠️ Resultado inválido o sin tipo: ", resultado)
	print("🗨️ [DIALOGO] Continuando desde comando...")
	continuar_desde_comando()

## Ejecuta una operación de salto de línea sin afectar aceleración
func _ejecutar_operacion_salto_linea() -> void:
	var visibles_previos = label.visible_characters
	label.append_text("\n")
	label.visible_characters = visibles_previos
	# Mantener aceleración: no modificar tecla_accion_mantenida ni velocidad_actual

## Se ejecuta cuando se completan todas las operaciones
func _finalizar_todas_operaciones() -> void:
	print("🗨️ [DIALOGO] Todas las operaciones completadas")
	print("🗨️ [DIALOGO] Modo actual antes de finalizar: ", modo_cierre)
	if estado_dialogo == EstadoDialogo.IDLE:
		print("🗨️ [DIALOGO] Ya está en IDLE, no se espera input ni se hacen transiciones.")
		return
	if procesando_comandos:
		print("🗨️ [DIALOGO] Comando en proceso, no ejecutando callback")
		return
	# emit_signal("texto_completado")
	_fin_dialogo_esperando_cierre = false
	match modo_cierre:
		ModoCierre.NO_INPUT_NO_CLOSE:
			print("🗨️ [DIALOGO] Modo NO_INPUT_NO_CLOSE: diálogo permanece abierto hasta cierre externo")
			label.visible_characters = label.get_total_character_count()
			_programar_señal_fin(DELAY_BREVE)
			_programar_callback_unificado(DELAY_BREVE)
			# Transicionar a estado de espera de cierre externo
			_transicionar(estado_dialogo, EstadoDialogo.ESPERANDO_CIERRE_EXTERNO, "modo NO_INPUT_NO_CLOSE")
		ModoCierre.NO_INPUT_CLOSE:
			print("🗨️ [DIALOGO] Modo AUTO_CLOSE: programando cierre en ", auto_close_delay, "s (ajustado a callback si necesario)")
			label.visible_characters = label.get_total_character_count()
			_programar_señal_fin(DELAY_BREVE)
			_programar_callback_unificado(DELAY_BREVE)
			_programar_autocierre_respetando_callback(DELAY_BREVE)
		ModoCierre.ON_INPUT_CLOSE, ModoCierre.ON_INPUT_NO_CLOSE:
			print("🗨️ [DIALOGO] Modo ON_INPUT...: esperando tecla para cerrar")
			label.visible_characters = label.get_total_character_count()
			_fin_dialogo_esperando_cierre = true
			if estado_dialogo != EstadoDialogo.ESPERANDO_INPUT:
				_transicionar(estado_dialogo, EstadoDialogo.ESPERANDO_INPUT, "fin ON_INPUT...")

func _programar_señal_fin(delay: float) -> void:
	if estado_dialogo == EstadoDialogo.IDLE:
		print("🗨️ [DIALOGO] (SeñalFin) cancelado: diálogo ya cerrado")
		return
	var timer_cb = get_tree().create_timer(delay)
	timer_cb.timeout.connect(func():
		emit_signal("texto_completado")
	, CONNECT_ONE_SHOT)

## Programación del callback (si existe), diferido por DELAY_BREVE
func _programar_callback_unificado(delay: float) -> void:
	if not callback_texto_completado.is_valid():
		return
	var cb = callback_texto_completado
	callback_texto_completado = Callable() # Evita dobles ejecuciones
	var timer_cb = get_tree().create_timer(delay)
	timer_cb.timeout.connect(func():

		# Liberar controles del jugador
		if nodo_raiz:
			Singleton.mantener_pausa(&"dialogo", false)
		if nodo_jugador:
			nodo_jugador.no_control = false

		if estado_dialogo == EstadoDialogo.IDLE:
			print("🗨️ [DIALOGO] (CallbackUnificado) cancelado: diálogo ya cerrado")
			return
		if cb.is_valid():
			print("🗨️ [DIALOGO] (CallbackUnificado) ejecutando callback tras delay estándar")
			cb.call()
	, CONNECT_ONE_SHOT)

func _programar_autocierre_respetando_callback(delay: float) -> void:
	# Garantizar que el cierre ocurra siempre después del callback (añadir pequeño margen)
	var min_cierre = delay + 0.01
	# Si entre tanto se mostró otro texto (otra generación de cola), este cierre
	# programado ya no le corresponde y no debe cerrar el cuadro nuevo.
	var generacion := _generacion_cola
	var timer_close = get_tree().create_timer(min_cierre)
	timer_close.timeout.connect(func():
		if estado_dialogo == EstadoDialogo.IDLE or generacion != _generacion_cola:
			return
		cierra_dialogo()
	, CONNECT_ONE_SHOT)

## Reanuda operaciones tras el cierre de un comando modal
func continuar_desde_comando() -> void:
	print("🗨️ [DIALOGO] Continuando operaciones desde comando")
	procesando_comandos = false

	# Si quedaban operaciones pendientes, continuar
	if operacion_actual_index < cola_operaciones.size():
		_ejecutar_siguiente_operacion()
	else:
		_finalizar_todas_operaciones()

func cierra_dialogo() -> void:
	print("🗨️ [DIALOGO] Iniciando cierre del diálogo")
	if estado_dialogo != EstadoDialogo.IDLE:
		_transicionar(estado_dialogo, EstadoDialogo.CERRANDO, "solicitud de cierre")

## Función pública para cerrar desde código externo cuando está en estado de espera
func cerrar_dialogo_externo() -> void:
	print("🗨️ [DIALOGO] Solicitud de cierre externo")
	if estado_dialogo == EstadoDialogo.ESPERANDO_CIERRE_EXTERNO:
		print("🗨️ [DIALOGO] Cerrando desde estado ESPERANDO_CIERRE_EXTERNO")
		cierra_dialogo()
	elif estado_dialogo != EstadoDialogo.IDLE:
		print("🗨️ [DIALOGO] Forzando cierre desde estado: ", EstadoDialogo.keys()[estado_dialogo])
		cierra_dialogo()
	else:
		print("🗨️ [DIALOGO] Ya está cerrado (IDLE)")

## Verifica si el diálogo está esperando cierre externo
func esta_esperando_cierre_externo() -> bool:
	return estado_dialogo == EstadoDialogo.ESPERANDO_CIERRE_EXTERNO

## Procesa comandos de escape en el texto como {menu_confirmacion}
func _procesar_comandos_escape(texto: String) -> String:
	var texto_limpio = texto

	# Buscar comandos entre \\{ y }
	var regex = RegEx.new()
	# Acepta {comando} y también la forma escapada \{comando}
	regex.compile("(?:\\\\)?\\{([^}]+)\\}")
	var resultado = regex.search_all(texto)

	for match in resultado:
		var comando_completo = match.get_string()
		var comando = match.get_string(1)

		# Procesar diferentes tipos de comandos
		command_processor.ejecutar_comando(comando)

		# Remover el comando del texto
		texto_limpio = texto_limpio.replace(comando_completo, "")

	return texto_limpio


func _input(_event: InputEvent) -> void:
	if _event is InputEventMouseMotion:
		return

	# Ignorar input completamente si estamos esperando cierre externo
	if estado_dialogo == EstadoDialogo.ESPERANDO_CIERRE_EXTERNO:
		return

	var en_pausa_parrafo = _limpiar_al_avanzar
	#var debe_ignorar_input = callback_texto_completado.is_valid() and not en_pausa_parrafo and estado_dialogo != EstadoDialogo.ESPERANDO_INPUT and modo_cierre not in [ModoCierre.ON_INPUT_NO_CLOSE, ModoCierre.ON_INPUT_CLOSE]
	var debe_ignorar_input = not en_pausa_parrafo and estado_dialogo != EstadoDialogo.ESPERANDO_INPUT and modo_cierre not in [ModoCierre.ON_INPUT_NO_CLOSE, ModoCierre.ON_INPUT_CLOSE]
	if debe_ignorar_input:
		return
	if estado_dialogo != EstadoDialogo.IDLE:
		if (Input.is_action_just_pressed("btn_accion") or Input.is_action_just_pressed("btn_cancelar")):
			match estado_dialogo:
				EstadoDialogo.ESPERANDO_INPUT:
					Singleton.emit_signal("play_sound", "cursor_menu")
					if _fin_dialogo_esperando_cierre:
						_fin_dialogo_esperando_cierre = false
						_programar_señal_fin(DELAY_BAJO)
						_programar_callback_unificado(DELAY_BAJO)
						if modo_cierre == ModoCierre.ON_INPUT_CLOSE:
							_programar_autocierre_respetando_callback(DELAY_BAJO)
						else:
							_transicionar(estado_dialogo, EstadoDialogo.ESPERANDO_CIERRE_EXTERNO, "modo ON_INPUT_NO_CLOSE")
					else:
						_ejecutar_siguiente_operacion()
				EstadoDialogo.APARECIENDO:
					pass
				EstadoDialogo.MOSTRANDO_MENU:
					pass

## Función de logging para debugging
func _logger(mensaje: String):
	print("🗨️ [DIALOGO] → " + mensaje)

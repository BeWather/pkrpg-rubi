extends RichTextLabel
class_name CajaTextoBatalla

## Script controlador para la caja de texto de batalla
## Versión simplificada del cuadro_dialogo.gd específica para batallas

## ============================================================================
## SEÑALES
## ============================================================================

signal texto_completado
signal caracter_mostrado
var callback_mensaje: Callable = Callable()

## ============================================================================
## VARIABLES DE CONFIGURACIÓN
## ============================================================================

## Control de velocidad de texto. Rubí (text.c, sTextSpeedDelays) espera
## 6/3/1 frames por carácter en LENTA/MEDIA/RÁPIDA.
const SEGUNDOS_POR_CARACTER_LENTA := 6.0 / 60.0
const SEGUNDOS_POR_CARACTER_MEDIA := 3.0 / 60.0
const SEGUNDOS_POR_CARACTER_RAPIDA := 1.0 / 60.0
var velocidad_actual: float = SEGUNDOS_POR_CARACTER_MEDIA
var texto_instantaneo: bool = false
var mostrar_todo_instantaneo: bool = false

## Control de animación
var tween_texto: Tween
var mostrando_texto: bool = false
var puede_acelerar: bool = true

## Texto actual
var texto_completo: String = ""
var caracteres_mostrados: int = 0

var cursor: AnimatedSprite2D = null
## Combate que el jugador solo mira (DatosInicioBatalla.EXTRA_TEXTOS_AUTOMATICOS,
## tutorial de BLASCO): los mensajes que pedirían A/B siguen solos tras
## `pausa_automatica` segundos, como los {PAUSE} de Rubí.
var confirmacion_automatica: bool = false
var pausa_automatica: float = PAUSA_LECTURA

## Pausa de lectura de Rubí: los scripts de batalla siguen casi todo
## `printstring` con `waitmessage B_WAIT_TIME_LONG` (64 frames). Se aplica de
## forma diferida: un mensaje recién escrito no se sustituye por el siguiente
## hasta que haya estado 64 frames a la vista. Confirmar con A/B, abrir un menú
## o una pregunta la dan por cumplida (el jugador ya leyó).
const PAUSA_LECTURA := 64.0 / 60.0
## Instante (usec) en que terminó de escribirse el último mensaje pendiente de
## lectura; 0 si no hay ninguno.
var _lectura_pendiente_desde_usec: int = 0

## ============================================================================
## INICIALIZACIÓN
## ============================================================================

func _ready():
	# Configuración inicial
	visible_ratio = 0.0
	bbcode_enabled = true
	scroll_active = false
	
	# Obtener velocidad desde opciones del juego
	actualizar_velocidad_desde_opciones()
	
	print("📝 [CAJA_TEXTO_BATALLA] Inicializada")

func set_cursor(nodo_cursor: AnimatedSprite2D) -> void:
	cursor = nodo_cursor
	if cursor != null:
		cursor.visible = false

## ============================================================================
## GESTIÓN DE VELOCIDAD
## ============================================================================

## Actualiza la velocidad desde las opciones del juego
func actualizar_velocidad_desde_opciones():
	if SistemaGuardado and SistemaGuardado.datos_vivos:
		var opciones: Opciones = SistemaGuardado.datos_vivos.opciones
		var velocidad_opcion = opciones.velocidad_texto
		
		match velocidad_opcion:
			Singleton.VelocidadTexto.LENTA:
				velocidad_actual = SEGUNDOS_POR_CARACTER_LENTA
			Singleton.VelocidadTexto.MEDIA:
				velocidad_actual = SEGUNDOS_POR_CARACTER_MEDIA
			Singleton.VelocidadTexto.RAPIDA:
				velocidad_actual = SEGUNDOS_POR_CARACTER_RAPIDA
			_:
				velocidad_actual = SEGUNDOS_POR_CARACTER_MEDIA
		
		print("⚡ [CAJA_TEXTO_BATALLA] Velocidad configurada: %f (opción: %d)" % [velocidad_actual, velocidad_opcion])
	else:
		velocidad_actual = SEGUNDOS_POR_CARACTER_MEDIA  # Velocidad por defecto
		print("⚠️ [CAJA_TEXTO_BATALLA] Usando velocidad por defecto")

## ============================================================================
## MOSTRAR TEXTO PRINCIPAL
## ============================================================================

## Muestra texto con la velocidad configurada
func mostrar_texto(nuevo_texto: String, instantaneo: bool = false, callback: Callable = Callable()) -> void:
	callback_mensaje = callback
	nuevo_texto = nuevo_texto.replace("\\l", "\n")
	# Nombre del jugador en las frases de derrota oficiales (p. ej. el rival).
	if nuevo_texto.contains("{PN}"):
		nuevo_texto = nuevo_texto.replace("{PN}", SistemaGuardado.get_nombre_jugador())

	if mostrando_texto:
		detener_animacion()
	elif nuevo_texto != texto_completo:
		# El mensaje anterior debe quedar 64 frames a la vista antes de
		# sustituirlo (waitmessage).
		await esperar_lectura_pendiente()
		if mostrando_texto:
			detener_animacion()

	texto_completo = nuevo_texto
	caracteres_mostrados = 0
	mostrando_texto = true
	
	# Limpiar y configurar texto
	text = texto_completo
	visible_ratio = 0.0
	
	if instantaneo or mostrar_todo_instantaneo:
		_mostrar_instantaneo()
	else:
		await _animar_texto()

	mostrando_texto = false
	if not _limpiar_bbcode(texto_completo).strip_edges().is_empty():
		_lectura_pendiente_desde_usec = Time.get_ticks_usec()
	texto_completado.emit()
	if callback_mensaje.is_valid():
		callback_mensaje.call()
		callback_mensaje = Callable()

## ============================================================================
## ANIMACIÓN DE TEXTO
## ============================================================================

## Anima el texto carácter por carácter
func _animar_texto():
	var duracion_total = _calcular_duracion_texto()
	
	# Crear tween para animación
	tween_texto = create_tween()
	tween_texto.tween_method(_actualizar_visible_ratio, 0.0, 1.0, duracion_total)
	
	# Conectar señal de finalización
	await tween_texto.finished

## Actualiza el ratio visible durante la animación
func _actualizar_visible_ratio(ratio: float):
	visible_ratio = ratio
	
	# Calcular caracteres mostrados
	var nuevos_caracteres = int(texto_completo.length() * ratio)
	if nuevos_caracteres > caracteres_mostrados:
		caracteres_mostrados = nuevos_caracteres
		caracter_mostrado.emit()

## Calcula la duración total de la animación
func _calcular_duracion_texto() -> float:
	# Contar solo caracteres visibles (sin BBCode)
	var texto_limpio = _limpiar_bbcode(texto_completo)
	var num_caracteres = texto_limpio.length()
	
	return num_caracteres * velocidad_actual

## Limpia el BBCode para contar caracteres reales
func _limpiar_bbcode(texto: String) -> String:
	var regex = RegEx.new()
	regex.compile("\\[.*?\\]")
	return regex.sub(texto, "", true)

## ============================================================================
## CONTROL DE ANIMACIÓN
## ============================================================================

## Muestra el texto instantáneamente.
func _mostrar_instantaneo():
	visible_ratio = 1.0
	caracteres_mostrados = texto_completo.length()

## Detiene la animación actual.
func detener_animacion():
	if tween_texto and tween_texto.is_valid():
		tween_texto.kill()
	mostrando_texto = false

## Acelera o completa el texto instantáneamente.
func acelerar_o_completar():
	if not mostrando_texto:
		return
	
	if puede_acelerar and tween_texto and tween_texto.is_valid():
		# Acelerar animación (reducir tiempo a la mitad)
		tween_texto.set_speed_scale(3.0)
		print("⚡ [CAJA_TEXTO_BATALLA] Texto acelerado")
	else:
		# Mostrar instantáneamente
		detener_animacion()
		_mostrar_instantaneo()
		mostrando_texto = false
		texto_completado.emit()
		print("⚡ [CAJA_TEXTO_BATALLA] Texto completado instantáneamente")

## ============================================================================
## UTILIDADES PARA BATALLA
## ============================================================================

## Limpia la caja de texto
func limpiar():
	detener_animacion()
	descartar_lectura_pendiente()
	text = ""
	visible_ratio = 0.0
	texto_completo = ""
	caracteres_mostrados = 0

## Verifica si está mostrando texto actualmente
func esta_mostrando() -> bool:
	return mostrando_texto

## Verifica si el texto está completo
func texto_esta_completo() -> bool:
	return not mostrando_texto and visible_ratio >= 1.0

## ============================================================================
## PAUSA DE LECTURA (waitmessage 64)
## ============================================================================

func tiene_lectura_pendiente() -> bool:
	return _lectura_pendiente_desde_usec > 0

## Da por leído el mensaje actual (confirmación, menú, pregunta o limpieza).
func descartar_lectura_pendiente() -> void:
	_lectura_pendiente_desde_usec = 0

## Espera lo que falte para que el último mensaje cumpla los 64 frames a la
## vista. Se comprueba cada frame para soltar la espera en cuanto el mensaje
## se dé por leído (menú abierto, confirmación, limpieza).
func esperar_lectura_pendiente() -> void:
	var desde_usec: int = _lectura_pendiente_desde_usec
	if desde_usec <= 0:
		return
	var limite_usec: int = desde_usec + ceili(PAUSA_LECTURA * 1000000.0)
	while Time.get_ticks_usec() < limite_usec and is_inside_tree():
		await get_tree().process_frame
		if _lectura_pendiente_desde_usec != desde_usec:
			return
	if _lectura_pendiente_desde_usec == desde_usec:
		_lectura_pendiente_desde_usec = 0

## ============================================================================
## MÉTODOS ESPECÍFICOS PARA BATALLA
## ============================================================================

## Muestra mensaje de batalla con tipo específico
func mostrar_mensaje_batalla(mensaje: String, tipo_mensaje: TipoMensajeBatalla = TipoMensajeBatalla.NORMAL):
	var instantaneo = false
	
	# Determinar si debe ser instantáneo según el tipo
	match tipo_mensaje:
		TipoMensajeBatalla.CRITICO, TipoMensajeBatalla.EFECTIVIDAD:
			instantaneo = false  # Estos se ven mejor animados
		TipoMensajeBatalla.ESTADO:
			instantaneo = true   # Estados se pueden mostrar rápido
		_:
			instantaneo = false
	
	await mostrar_texto(mensaje, instantaneo)

## Muestra texto con duración personalizada (para efectos especiales)
func mostrar_con_duracion(mensaje: String, duracion: float):
	text = mensaje
	visible_ratio = 0.0
	
	if tween_texto and tween_texto.is_valid():
		tween_texto.kill()
	
	tween_texto = create_tween()
	tween_texto.tween_property(self, "visible_ratio", 1.0, duracion)
	await tween_texto.finished

## ============================================================================
## ENUMS Y CONSTANTES
## ============================================================================

enum TipoMensajeBatalla {
	NORMAL,        # Mensajes generales
	MOVIMIENTO,    # "¡X usó Y!"
	DANO,          # "¡Causó Z daños!"
	CRITICO,       # "¡Golpe crítico!"
	EFECTIVIDAD,   # "¡Es súper eficaz!"
	ESTADO,        # "¡X está paralizado!"
	DEBILITADO,    # "¡X se debilitó!"
	CAPTURA        # Mensajes de captura
}

## ============================================================================
## MANEJO DE ENTRADA
## ============================================================================

func _input(event):
	# Solo procesar si está mostrando texto
	if not mostrando_texto:
		return
	
	# Acelerar texto con botón de acción
	if event.is_action_pressed("btn_accion"):
		acelerar_o_completar()
		get_viewport().set_input_as_handled()

## Espera que se presione btn_accion o btn_cancelar, manejando el estado inicial
func esperar_input_continuar(callback: Callable, mostrar_cursor: bool = true) -> void:
	print("⏳ [CAJA_TEXTO] Esperando input para continuar...")
	# El mensaje que pide A/B no lleva además la pausa de lectura.
	descartar_lectura_pendiente()
	if confirmacion_automatica:
		if cursor != null:
			cursor.visible = false
			cursor.stop()
		await get_tree().create_timer(pausa_automatica).timeout
		if callback.is_valid():
			callback.call()
		return
	if cursor != null:
		cursor.visible = mostrar_cursor
		if mostrar_cursor:
			cursor.play("default")
		else:
			cursor.stop()
	
	# 1. Detectar si se están presionando las teclas actualmente
	var btn_accion_presionado = Input.is_action_pressed("btn_accion")
	var btn_cancelar_presionado = Input.is_action_pressed("btn_cancelar")
	
	# 2. Si alguna tecla está presionada, esperar a que se suelte antes de continuar
	if btn_accion_presionado or btn_cancelar_presionado:
		print("🔒 [CAJA_TEXTO] Teclas presionadas, esperando liberación...")
		await _esperar_liberacion_teclas()
	
	# 3. Ahora esperar a que se presione una de las dos teclas
	print("👆 [CAJA_TEXTO] Esperando presión de btn_accion o btn_cancelar...")
	await _esperar_presion_teclas()
	
	if cursor != null:
		cursor.visible = false
		cursor.stop()

	# 4. Ejecutar callback cuando se presione
	print("✅ [CAJA_TEXTO] Tecla presionada, ejecutando callback...")
	if callback.is_valid():
		callback.call()

## Espera a que se liberen las teclas btn_accion y btn_cancelar
func _esperar_liberacion_teclas():
	while Input.is_action_pressed("btn_accion") or Input.is_action_pressed("btn_cancelar"):
		await get_tree().process_frame

## Espera a que se presione btn_accion o btn_cancelar
func _esperar_presion_teclas():
	while true:
		if Input.is_action_just_pressed("btn_accion") or Input.is_action_just_pressed("btn_cancelar"):
			break
		await get_tree().process_frame

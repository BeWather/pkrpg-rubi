extends Control

# Confirmación de guardado simplificada usando escape commands
# Versión final limpia - Delegación completa al CuadroDialogo

# Señales
signal guardado_completado(acepta: bool)

# Variables principales
var acepta_guardado: bool = false
var cuadro_dialogo = null
var panel_info: NinePatchRect = null

# Referencias a escenas
const SCN_CUADRO_INFO = preload("res://UI/guardar/cuadro_info.tscn")

func _ready():
	"""Inicialización del sistema"""
	_logear("Construyendo UI simplificada")

	# Crear panel de información
	panel_info = NinePatchRect.new()
	panel_info.position = Vector2(0, 0)
	# Configurar márgenes estándar
	panel_info.patch_margin_left = 8
	panel_info.patch_margin_top = 8
	panel_info.patch_margin_right = 8
	panel_info.patch_margin_bottom = 8
	# Configurar Axis Stretch en Tile (horizontal y vertical)
	panel_info.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	panel_info.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	add_child(panel_info)
	_logear("Panel info creado")

	# Obtener cuadro de diálogo y conectar a comando
	cuadro_dialogo = Singleton.get_cuadro_dialogo()
	if cuadro_dialogo:
		# Conectar a la señal de comando ejecutado para capturar respuestas
		cuadro_dialogo.connect("comando_ejecutado", Callable(self, "_on_comando_ejecutado"))
		_logear("Conectado a comando_ejecutado del cuadro de diálogo")

	# Llenar panel info
	_llenar_panel_info()

	# Aplicar textura dinámica al panel usando MenuBoxManager
	var menu_box_manager = preload("res://scripts/clases/MenuBoxManager.gd")
	var img_type = 1
	var sg = get_tree().root.get_node_or_null("SistemaGuardado")
	if sg and sg.datos_vivos and sg.datos_vivos.opciones:
		img_type = int(sg.datos_vivos.opciones.imagen_tipo)
	menu_box_manager.apply_texture_to_ninepatch(panel_info, img_type)

func _llenar_panel_info():
	"""Llena el panel de información con datos de la partida"""
	var datos = _obtener_datos_partida()
	var cuadro_info = SCN_CUADRO_INFO.instantiate()
	panel_info.add_child(cuadro_info)

	# Configurar datos en el cuadro de información
	if cuadro_info.has_method("configurar_datos"):
		cuadro_info.configurar_datos(datos)

func _obtener_datos_partida() -> Dictionary:
	"""Obtiene los datos actuales de la partida"""
	var datos: Dictionary = {}

	if SistemaGuardado.datos_vivos:
		datos["localizacion"] = Singleton._get_nombre_lugar()
		datos["jugador"] = SistemaGuardado.datos_vivos.jugador["nombre"]
		datos["medallas"] = SistemaGuardado.datos_vivos.jugador["medallas"].count(true)
		# Mismo criterio que el menú de inicio (resumen del guardado).
		datos["pokedex"] = PokedexPartida.contar_atrapados_resumen(
			SistemaGuardado.datos_vivos.pokedex["atrapados"],
			SistemaGuardado.datos_vivos.datos_persistentes.banderas)
		datos["tiempo"] = _formatear_tiempo(SistemaGuardado.datos_vivos.tiempo_juego)
	else:
		datos = {
			"localizacion": "ABC",
			"jugador": "¿?",
			"medallas": 1,
			"pokedex": 2,
			"tiempo": "00:03"
		}

	return datos

func _formatear_tiempo(segundos_totales: float) -> String:
	"""Formatea el tiempo de juego"""
	var horas = int(segundos_totales / 3600.0)
	var minutos = int((int(segundos_totales) % 3600) / 60.0)
	return "%s:%02d" % [horas, minutos]

func iniciar():
	"""Punto de entrada principal - inicia el proceso de guardado"""
	_logear("Iniciando proceso de guardado")
	_iniciar_guardado()

func _iniciar_guardado():
	"""Inicia el flujo de guardado enviando texto con comando de escape"""
	_logear("Iniciando guardado con comando de escape")
	if cuadro_dialogo:
		# Enviar pregunta con comando de escape para mostrar menú SI/NO
		var pregunta = "¿Quieres guardar la partida?"
		# Preservar controles del jugador mientras el diálogo de confirmación está activo
		# if cuadro_dialogo.has_method("preservar_controles_push"):
		# 	cuadro_dialogo.preservar_controles_push()
		cuadro_dialogo.preguntaSiNo(pregunta)

func _on_comando_ejecutado(comando: String, parametros: Array):
	"""Se ejecuta cuando el cuadro de diálogo ejecuta un comando de escape"""
	_logear("Comando ejecutado: " + comando + " con parámetros: " + str(parametros))

	if comando == "opera_menu_confirmacion":
		_logear("Comando opera_menu_confirmacion detectado")
		# El cuadro de diálogo manejará el menú SI/NO automáticamente
	elif comando == "respuesta_confirmacion":
		if parametros.size() > 0:
			var respuesta = parametros[0]
			var acepta = (respuesta == "Y")
			_on_menu_resultado(acepta)

func _on_menu_resultado(acepta: bool):
	"""Callback que recibe el resultado del menú SI/NO"""
	_logear("Resultado del menú: " + str(acepta))
	acepta_guardado = acepta

	if acepta:
		_ejecutar_guardado()
	else:
		_cancelar_guardado()

func _ejecutar_guardado():
	"""Ejecuta el guardado y muestra resultado"""

	# Mostrar mensaje del proceso
	if cuadro_dialogo:
		cuadro_dialogo.mensaje_sin_esperar("GUARDANDO...")

	await get_tree().create_timer(0.5).timeout

	_logear("Ejecutando guardado")
	var exito = SistemaGuardado.guardar_partida()
	var mensaje = "¡{PN} guardó la partida!" if exito else "Error al guardar"

	_logear("Guardado resultado: " + str(exito))

	# Mostrar mensaje de resultado
	if cuadro_dialogo:
		cuadro_dialogo.mensaje_autocierre(mensaje, Callable(self, "_on_mensaje_completado"))

func _cancelar_guardado():
	"""Cancela el guardado y cierra"""
	_logear("Guardado cancelado")
	_cerrar_y_emitir_resultado()

func _on_mensaje_completado():
	"""Se ejecuta cuando termina de mostrarse el mensaje de resultado"""
	_logear("Mensaje completado, cerrando sistema")
	_cerrar_y_emitir_resultado()

func _cerrar_y_emitir_resultado():
	"""Cierra la interfaz y emite el resultado"""
	_logear("Cerrando interfaz y emitiendo resultado: " + str(acepta_guardado))

	# Desconectar señales
	if cuadro_dialogo and cuadro_dialogo.is_connected("comando_ejecutado", _on_comando_ejecutado):
		cuadro_dialogo.disconnect("comando_ejecutado", _on_comando_ejecutado)

	# Cerrar cuadro de diálogo si está abierto
	if cuadro_dialogo:
		cuadro_dialogo.cierra_dialogo()
		# # Liberar la preservación de controles que pusimos antes
		# if cuadro_dialogo.has_method("preservar_controles_pop"):
		# 	cuadro_dialogo.preservar_controles_pop()

	# Limpiar panel info si existe
	if panel_info:
		panel_info.queue_free()
		panel_info = null

	# Emitir señal con el resultado
	emit_signal("guardado_completado", acepta_guardado)

	# Limpiar la interfaz
	queue_free()

func _logear(mensaje: String):
	"""Función de logging para debugging"""
	print("💾 [GUARDADO_SIMPLE] → " + mensaje)

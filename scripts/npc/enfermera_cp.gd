## enfermera_centro_pokemon.gd
## Enfermera del Centro Pokémon que extiende de npc_base.gd
## AdministradorMapa resuelve el NPC directo o a través de MOSTRADOR (MB_COUNTER).
##
@tool
extends "res://scripts/npc/npc_base.gd"

## ============================================================================
## CONFIGURACIÓN DE LA ENFERMERA
## ============================================================================

## ID único de la enfermera
# @export var id_enfermera: String = "enfermera_centro_001"

## Nodo que contiene el controlador de animación de curación
@export var nodo_animacion_curacion: Node = null

## Referencia al controlador de animación de curación (se obtiene del nodo exportado)
var controlador_animacion = null

## Estado del sistema de curación
var curacion_activa: bool = false
var callback_curacion_actual: Callable

## Componentes del menú oficial
var menu_node: NinePatchRect = null
var labels_opciones: Array[Label] = []
var cursor_menu: PkSelectorSimple = null
var menu_box_component: Node = null

## Referencia al CanvasLayer del menú para posicionamiento fijo en pantalla
var canvas_layer_menu: CanvasLayer = null

## Control de cámara para centro Pokémon
var celda_activada: Vector2i = Vector2i(-1, -1)  # Celda donde se activó la enfermera
var desplazamiento_camara_original: Vector2 = Vector2.ZERO  # Posición original de la cámara
var camara_desplazada: bool = false  # Flag para saber si la cámara está desplazada

## ============================================================================
## INICIALIZACIÓN
## ============================================================================

func _ready() -> void:
	super._ready()

	# Configurar el NPC como enfermera
	_configurar_enfermera()

	_obtener_canvas_layer_menu()

	# Configurar controlador de animación
	_configurar_controlador_animacion()

	print("🏥 Enfermera configurada: ", name)

## setrespawn de la map_script ON_TRANSITION de cada PokemonCenter_1F: al entrar
## en el Centro por un warp, su entrada exterior pasa a ser el último punto de
## curación (aunque no se cure). Cargar la partida dentro no lo cambia.
## npc_base ya conecta `mapa_activado` a este método.
func _on_mapa_activado(por_warp: bool) -> void:
	super._on_mapa_activado(por_warp)
	if por_warp:
		fijar_punto_curacion_en_entrada_exterior()

## Copia la entrada exterior guardada al punto de curación. Sin entrada (p. ej.
## partida anterior a esta función) no toca el punto. true si lo cambió.
static func fijar_punto_curacion_en_entrada_exterior() -> bool:
	var entrada: Dictionary = SistemaGuardado.get_entrada_exterior()
	if entrada.is_empty():
		return false
	SistemaGuardado.set_punto_curacion(entrada)
	return true

func _configurar_enfermera():
	# Configuración específica de la enfermera
	# tipo_movimiento = TipoMovimientoNPC.SIN_MOVIMIENTO

	# Asegurar que el NPC tenga un sprite apropiado
	if animated_sprite:
		# Aquí podrías cambiar el sprite de la enfermera si es necesario
		pass

func _configurar_controlador_animacion():
	# Usar el nodo asignado desde el editor
	if nodo_animacion_curacion:
		controlador_animacion = nodo_animacion_curacion
		_loggear("✅ Controlador de animación configurado desde editor: %s" % nodo_animacion_curacion.name)
		_loggear("   Ruta: %s" % nodo_animacion_curacion.get_path())

		# Verificar si tiene el script correcto
		if controlador_animacion.has_method("iniciar_animacion_curacion"):
			_loggear("   ✅ Script de controlador detectado correctamente")
		else:
			_loggear("   ⚠️ El nodo no tiene el script de controlador de animación")
			controlador_animacion = null
	else:
		_loggear("⚠️ Nodo de animación no asignado en el editor")
		_loggear("   💡 Asigna el nodo 'Anims' en la propiedad 'Nodo Animacion Curacion' del Inspector")
		controlador_animacion = null

func _obtener_canvas_layer_menu():
	# Buscar el CanvasLayer en la ruta: raiz > AdministradorMapa > Menu
	canvas_layer_menu = get_tree().root.get_node_or_null("AdministradorMapa/Menu")

	if canvas_layer_menu and canvas_layer_menu is CanvasLayer:
		_loggear("✅ CanvasLayer del menú encontrado: %s" % canvas_layer_menu.get_path())
	else:
		_loggear("⚠️ CanvasLayer del menú no encontrado en AdministradorMapa/Menu")
		# Fallback: usar el nodo actual como contenedor
		canvas_layer_menu = null

## ============================================================================
## LÓGICA DE LA ENFERMERA
## ============================================================================

func evento_accion() -> void:
	if estado_actual != EstadoNPC.IDLE or curacion_activa or jugador.no_control:
		return

	celda_activada = nodo_administrador.celda_frente_jugador() if nodo_administrador else coord_celda
	cambiar_estado(EstadoNPC.INTERACTING)
	curacion_activa = true

	# Mirar hacia el jugador
	mirar_jugador()
	jugador.no_control = true
	jugador.start_dialog()

	# Establecer estado de diálogo en el administrador
	if nodo_administrador:
		Singleton.mantener_pausa(&"enfermera", true)
		_loggear("🔒 Pausa activada para bloquear menú de pausa")

	# Mostrar diálogo de bienvenida y verificar estado del equipo
	_iniciar_interaccion_centro()

func _iniciar_interaccion_centro():
	if nodo_administrador and nodo_administrador.cuadro_dialogo:
		var mensaje_bienvenida = "Hola. Éste es el CENTRO POKéMON.\\p"
		mensaje_bienvenida += "Nosotros curamos a los POKéMON\\ldebilitados.\\p"
		mensaje_bienvenida += "¿Quieres que nos ocupemos de los\\lPOKéMON de tu equipo?"
		nodo_administrador.cuadro_dialogo.mostrar(
			tr(mensaje_bienvenida),
			false,   # No se espera tecla
			false,   # No se cierra automáticamente
			Callable(self, "_mostrar_menu_centro")  # Mostrar menú después del texto
		)
	else:
		_mostrar_menu_centro()

func _mostrar_menu_centro():
	var opciones: Array[String] = ["SÍ", "NO"]
	_mostrar_menu_personalizado(opciones, Callable(self, "_procesar_opcion_menu"))

## Evaluación de la opción seleccionada
func _procesar_opcion_menu(opcion_index: int):
	_loggear("🏥 === PROCESANDO OPCIÓN DEL MENÚ ===")
	_loggear("🏥 Índice seleccionado: %d" % opcion_index)

	match opcion_index:
		0: # SÍ - Curar Pokémon
			_loggear("🏥 Opción SÍ seleccionada - iniciando curación")
			_iniciar_curacion()
		1: # NO - Salir
			_loggear("🏥 Opción NO seleccionada - cerrando centro")
			_despedida_cierre()
		_:
			_loggear("🏥 Opción desconocida: %d - cerrando centro" % opcion_index)
			_despedida_cierre()

## DESPEDIDA Y CIERRE
func _despedida_cierre():
	var mensaje_despedida = "¡Vuelve cuando quieras!"
	if nodo_administrador and nodo_administrador.cuadro_dialogo:
		nodo_administrador.cuadro_dialogo.mostrar(
			tr(mensaje_despedida),
			true,   # Esperar input
			true,   # Cerrar después del input
			Callable(self, "_cerrar_centro")  # Callback para liberar al jugador
		)
	else:
		_cerrar_centro()

## INICIO DEL PROCESO DE CURACIÓN
func _iniciar_curacion():
	# Ocultar menú actual
	_desactivar_captura_input_menu()

	# Verificar si hay Pokémon para curar
	if _tiene_pokemon_para_curar():
		_mensaje_espera()
	else:
		_mostrar_mensaje_sin_pokemon()

## Se solicitó curar al equipo, mostrando mensaje de espera y aplicar animación
func _mensaje_espera():
	var mensaje_espera = "Muy bien. Ten un poco de paciencia.\\lSerá sólo un momento."

	if nodo_administrador and nodo_administrador.cuadro_dialogo:
		nodo_administrador.cuadro_dialogo.mostrar(
			tr(mensaje_espera),
			false,   # no esperar input
			false,   # no cerrar después del input
			Callable(self, "_ejecutar_proceso_curacion")  # Callback para continuar la animacion
		)
	else:
		_ejecutar_proceso_curacion()

func _tiene_pokemon_para_curar() -> bool:
	# Verificar si el jugador tiene Pokémon en su equipo
	if SistemaGuardado and SistemaGuardado.datos_vivos and SistemaGuardado.datos_vivos.equipo_pokemon:
		return SistemaGuardado.datos_vivos.equipo_pokemon.size() > 0

	# Fallback: asumir que tiene Pokémon
	_loggear("⚠️ No se pudo verificar el equipo, asumiendo que tiene Pokémon")
	return true

func _ejecutar_proceso_curacion():
	_loggear("🏥 Ejecutando proceso de curación...")

	# Aplicar transición de oscurecer si está disponible
	# if Singleton.has_method("transicion"):
	# 	await Singleton.transicion("oscurecer")

	# Enfermera mirando hacia la izquierda
	mirar(Vector2i.LEFT)
	# Esperar al menos un frame para que se actualice la visualización
	await get_tree().process_frame
	# Ahora esperar el tiempo deseado
	await get_tree().create_timer(0.2).timeout

	# Iniciar animación de curación si está disponible
	if controlador_animacion and controlador_animacion.has_method("iniciar_animacion_curacion"):
		_loggear("🎬 Iniciando animación de curación...")
		# Obtener número de pokémon en el equipo para la animación
		var num_pokemon = _obtener_numero_pokemon_equipo()
		# Iniciar animación con callback
		controlador_animacion.iniciar_animacion_curacion(num_pokemon, Callable(self, "_animacion_curacion_terminada"))
		# Esperar a que termine la animación
		while controlador_animacion.esta_animando():
			await get_tree().process_frame
	else:
		# Fallback sin animación
		_loggear("⚠️ Controlador de animación no disponible, curando sin animación")
		await get_tree().create_timer(2.0).timeout  # Simular tiempo de curación
		_animacion_curacion_terminada()

func _obtener_numero_pokemon_equipo() -> int:
	# Intentar obtener el número real de pokémon en el equipo
	if SistemaGuardado and SistemaGuardado.datos_vivos and SistemaGuardado.datos_vivos.equipo_pokemon:
		var equipo = SistemaGuardado.datos_vivos.equipo_pokemon
		return equipo.size()

	# Fallback: asumir 3 pokémon
	return 1

func _animacion_curacion_terminada():
	_loggear("🎬 Animación de curación terminada")

	# Curar todos los Pokémon del equipo
	_curar_equipo_pokemon()

	# Mostrar mensaje de curación completada
	# if Singleton.has_method("transicion"):
	# 	await Singleton.transicion("aclarar")

	# Enfermera mirando hacia abajo
	mirar(Vector2i.DOWN)
	await get_tree().process_frame
	# await get_tree().create_timer(0.2).timeout

	_mostrar_mensaje_curacion_completada()

func _curar_equipo_pokemon():
	_loggear("🏥 Curando equipo Pokémon...")

	# Intentar curar usando el sistema de guardado
	if SistemaGuardado and SistemaGuardado.has_method("curar_equipo_completo"):
		SistemaGuardado.curar_equipo_completo()
		_loggear("✅ Equipo curado usando SistemaGuardado.curar_equipo_completo()")
	elif SistemaGuardado and SistemaGuardado.has_method("get_equipo_pokemon"):
		# Fallback: curar manualmente cada Pokémon
		var equipo = SistemaGuardado.get_equipo_pokemon()
		if equipo and equipo.has_method("curar_todos"):
			equipo.curar_todos()
			_loggear("✅ Equipo curado usando equipo.curar_todos()")
		else:
			_loggear("⚠️ No se pudo curar el equipo - métodos no disponibles")
	else:
		_loggear("⚠️ SistemaGuardado no disponible para curación")

func _mostrar_mensaje_curacion_completada():
	if nodo_administrador and nodo_administrador.cuadro_dialogo:
		var mensaje = "Gracias por esperar.\\p"
		mensaje += "Misión cumplida. Somos especialistas\\len devolver la forma a los POKéMON."
		nodo_administrador.cuadro_dialogo.mostrar(
			tr(mensaje),
			false,   # Esperar input
			false,   # Cerrar después del input
			Callable(self, "_anima_saludo")  # Callback para liberar al jugador
		)
	else:
		_anima_saludo()

func _anima_saludo():
	animated_sprite.frame = 1
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	animated_sprite.frame = 0
	# await get_tree().process_frame
	var mensaje = "¡Vuelve cuando quieras!"
	nodo_administrador.cuadro_dialogo.mostrar(
		tr(mensaje),
		true,   # Esperar input
		true,   # Cerrar después del input
		Callable(self, "_cerrar_centro")  # Callback para liberar al jugador
	)

func _mostrar_mensaje_sin_pokemon():
	if nodo_administrador and nodo_administrador.cuadro_dialogo:
		var mensaje = "No tienes ningún Pokémon\\nque necesite curación."
		nodo_administrador.cuadro_dialogo.mostrar(
			tr(mensaje),
			true,   # Esperar input
			true,   # Cerrar después del input
			Callable(self, "_cerrar_centro")  # Callback para liberar al jugador
		)
	else:
		_cerrar_centro()

## ============================================================================
## SISTEMA DE MENÚ SIGUIENDO PATRÓN OFICIAL
## ============================================================================

func _mostrar_menu_personalizado(opciones: Array[String], callback: Callable):
	if curacion_activa and menu_node != null:
		_loggear("⚠️ Menú ya activo, ignorando")
		return

	callback_curacion_actual = callback

	_crear_menu_con_patron_oficial(opciones)

func _crear_menu_con_patron_oficial(opciones: Array[String]):
	_loggear("📋 Creando menú con patrón oficial")

	# 1. Crear NinePatchRect principal
	menu_node = NinePatchRect.new()

	# 2. Aplicar textura según opciones del usuario
	var menu_box_manager = preload("res://scripts/clases/MenuBoxManager.gd")
	var image_type = _get_saved_image_type()
	menu_box_manager.apply_texture_to_ninepatch(menu_node, image_type)

	# 3. Configurar márgenes estándar del patrón oficial
	menu_node.patch_margin_left = 8
	menu_node.patch_margin_top = 8
	menu_node.patch_margin_right = 8
	menu_node.patch_margin_bottom = 8

	# 3.1. Configurar Axis Stretch en Tile (horizontal y vertical)
	menu_node.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	menu_node.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE

	# 4. Posición en esquina superior izquierda
	menu_node.position = Vector2(160, 64)

	# 5. Calcular tamaño dinámico según opciones
	var altura_total = (opciones.size() * 16) + 16  # 16px por línea + padding
	var ancho_maximo = 56
	menu_node.size = Vector2(ancho_maximo, altura_total)

	# 6. Agregar MenuBoxComponent para auto-actualización. Lo quitamos porque no necesitamos auto-actualización.
	# menu_box_component = preload("res://scripts/clases/MenuBoxComponent.gd").new()
	# menu_box_component.auto_update_on_options_change = true
	# menu_node.add_child(menu_box_component)

	# 7. Crear labels para cada opción
	_crear_labels_opciones(opciones)

	# 8. Crear cursor oficial
	_crear_cursor_oficial()

	# 9. Agregar al CanvasLayer Menu para posicionamiento fijo en pantalla
	if canvas_layer_menu:
		canvas_layer_menu.add_child(menu_node)
		_loggear("📋 Menú agregado al CanvasLayer")
	else:
		# Fallback: agregar a la enfermera
		add_child(menu_node)
		_loggear("📋 Menú agregado a la enfermera (fallback)")

	# 10. Actualizar display inicial
	_actualizar_display_menu_oficial()

	# 11. Activar captura de input tras delay
	await get_tree().create_timer(0.3).timeout
	set_process_input(true)
	_loggear("📋 Menú activo y listo para input")

func _crear_labels_opciones(opciones: Array[String]):
	const LABEL_SETTINGS = preload("res://UI/texto_normal_negro.tres")
	labels_opciones.clear()

	for i in range(opciones.size()):
		var label = Label.new()
		label.text = opciones[i]
		label.label_settings = LABEL_SETTINGS
		label.position = Vector2(8, 8 + (i * 16))
		menu_node.add_child(label)
		labels_opciones.append(label)

## Crear cursor oficial
func _crear_cursor_oficial():
	cursor_menu = PkSelectorSimple.new()
	cursor_menu.color = Color(239/255.0, 110/255.0, 96/255.0)  # Color oficial ef6960
	cursor_menu.ancho_borde = 1
	cursor_menu.parpadeo = false

	# Tamaño del cursor para cubrir toda la línea de texto
	var ancho_cursor = menu_node.size.x - 14  # -14 para márgenes
	cursor_menu.size = Vector2(ancho_cursor, 17)

	menu_node.add_child(cursor_menu)

var indice_seleccion: int = 0

func _actualizar_display_menu_oficial():
	if not cursor_menu or not curacion_activa:
		return

	# Actualizar posición del cursor según selección
	var posicion_y = 7 + (indice_seleccion * 16)
	cursor_menu.position = Vector2(7, posicion_y)

## Obtiene el tipo de imagen guardado en las opciones (patrón oficial)
func _get_saved_image_type() -> int:
	# Usar SistemaGuardado directamente
	if typeof(SistemaGuardado) != TYPE_NIL and SistemaGuardado.datos_vivos and SistemaGuardado.datos_vivos.opciones:
		return int(SistemaGuardado.datos_vivos.opciones.imagen_tipo)

	# Fallback si no está disponible
	var sg = get_tree().root.get_node_or_null("SistemaGuardado")
	if sg and sg.datos_vivos and sg.datos_vivos.opciones:
		return int(sg.datos_vivos.opciones.imagen_tipo)

	return 1  # Fallback a imagen_tipo 1

func _input(event: InputEvent):
	if not curacion_activa or labels_opciones.is_empty():
		return

	# Ignorar eventos de mouse
	if event is InputEventMouseMotion:
		return

	if event.is_action_pressed("btn_arriba"):
		if indice_seleccion > 0:
			_mover_cursor_menu(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("btn_abajo"):
		if indice_seleccion < labels_opciones.size() - 1:
			_mover_cursor_menu(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("btn_accion"):
		_confirmar_seleccion_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("btn_cancelar"):
		# En el centro Pokémon, cancelar equivale a seleccionar "NO"
		indice_seleccion = 1  # NO
		_confirmar_seleccion_menu()
		get_viewport().set_input_as_handled()

func _mover_cursor_menu(direccion: int):
	indice_seleccion += direccion

	# Wraparound del cursor
	if indice_seleccion < 0:
		indice_seleccion = labels_opciones.size() - 1
	elif indice_seleccion >= labels_opciones.size():
		indice_seleccion = 0

	# Reproducir sonido de cursor (patrón oficial)
	if Singleton.has_signal("play_sound"):
		Singleton.play_sound.emit("cursor_menu")

	_actualizar_display_menu_oficial()

func _confirmar_seleccion_menu():
	_loggear("🏥 === CONFIRMANDO SELECCIÓN DE MENÚ ===")
	_loggear("🏥 Índice actual: %d" % indice_seleccion)

	var seleccion = indice_seleccion
	# Guardar el callback ANTES de desactivar la captura de input
	var callback_guardado = callback_curacion_actual

	_loggear("🏥 Desactivando captura de input...")
	_desactivar_captura_input_menu()

	# Ejecutar callback con la selección usando el callback guardado
	_loggear("🏥 Verificando callback guardado...")
	if callback_guardado.is_valid():
		_loggear("🏥 ✅ Ejecutando callback con selección: %d" % seleccion)
		callback_guardado.call(seleccion)
	else:
		_loggear("🏥 ❌ Callback guardado no válido")

func _desactivar_captura_input_menu():
	set_process_input(false)
	_ocultar_menu_oficial()

## Oculta y limpia el menú siguiendo el patrón oficial
func _ocultar_menu_oficial():
	_loggear("📋 Ocultando menú oficial")

	if menu_node != null and menu_node.is_inside_tree():
		# Remover del contenedor correcto
		if canvas_layer_menu and menu_node.get_parent() == canvas_layer_menu:
			canvas_layer_menu.remove_child(menu_node)
		else:
			# Fallback: remover de la enfermera
			if menu_node.get_parent() == self:
				remove_child(menu_node)

		menu_node.queue_free()
		menu_node = null

	# Limpiar referencias
	labels_opciones.clear()
	cursor_menu = null
	menu_box_component = null
	callback_curacion_actual = Callable()

## Se selecciona la opción NO
func _cerrar_centro():
	curacion_activa = false
	_desactivar_captura_input_menu()
	cambiar_estado(EstadoNPC.IDLE)

	# Quitar desplazamiento de cámara si está aplicado
	_quitar_desplazamiento_camara()

	# Devolver control al jugador
	if jugador:
		_loggear("Devolviendo control al jugador")
		jugador.end_dialog()
		jugador.no_control = false
		Singleton.mantener_pausa(&"enfermera", false)

	_loggear("🏥 Centro Pokémon cerrado")

## ============================================================================
## CONTROL DE CÁMARA (OPCIONAL)
## ============================================================================

## Aplica desplazamiento de cámara si es necesario
func _aplicar_desplazamiento_camara():
	# Implementar si se necesita desplazamiento específico para el centro Pokémon
	pass

## Quita el desplazamiento de cámara si estaba aplicado
func _quitar_desplazamiento_camara():
	# Implementar si se aplicó desplazamiento
	pass

## ============================================================================
## DEPURACIÓN
## ============================================================================

func _on_debug_info():
	print("=== DEBUG ENFERMERA ===")
	print("ID: ", name)
	print("Estado: ", estado_actual)
	print("Celda accionada: ", celda_activada)
	print("Curación activa: ", curacion_activa)
	print("Nodo animación asignado: ", nodo_animacion_curacion != null)
	if nodo_animacion_curacion:
		print("  Nombre: ", nodo_animacion_curacion.name)
		print("  Ruta: ", nodo_animacion_curacion.get_path())
	print("Controlador configurado: ", controlador_animacion != null)
	print("========================")

## Debug de la estructura de nodos para encontrar Anims
func debug_estructura_nodos():
	print("🔍 [DEBUG] Estructura de nodos desde enfermera:")
	print("🔍 Posición actual: %s" % get_path())
	print("🔍 Padre: %s" % get_parent().get_path() if get_parent() else "Sin padre")
	print("🔍 Abuelo: %s" % get_parent().get_parent().get_path() if get_parent() and get_parent().get_parent() else "Sin abuelo")

	# Listar hermanos del padre (NPCs)
	if get_parent():
		print("🔍 Hermanos de NPCs:")
		for child in get_parent().get_parent().get_children():
			print("  - %s (%s)" % [child.name, child.get_class()])

	# Buscar Anims específicamente
	var rutas_check = ["../../Anims", "../Anims", "../../../Anims"]
	for ruta in rutas_check:
		var nodo = get_node_or_null(ruta)
		print("🔍 %s: %s" % [ruta, "✅ ENCONTRADO" if nodo else "❌ No encontrado"])

## Función de logging para debugging
func _loggear(mensaje: String):
	print("🏥 [ENFERMERA] → %s" % mensaje)

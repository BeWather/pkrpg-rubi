## vendedor_pokeshop.gd
## Vendedor clásico de pokeshop que extiende de npc_base.gd
## AdministradorMapa resuelve el NPC directo o a través de MOSTRADOR (MB_COUNTER).
##
@tool
extends "res://scripts/npc/npc_base.gd"

## ============================================================================
## CONFIGURACIÓN DEL VENDEDOR
## ============================================================================

## ID único del vendedor
# @export var id_vendedor: String = "vendedor_pokeshop_001"

## Estado del menú de la tienda
var menu_tienda_activo: bool = false
var opciones_menu_actual: Array[String] = []
var indice_seleccion: int = 0
var callback_menu_actual: Callable

## Componentes del menú oficial
var menu_node: NinePatchRect = null
var labels_opciones: Array[Label] = []
var cursor_menu: PkSelectorSimple = null
var menu_box_component: Node = null

## Referencia al CanvasLayer del menú para posicionamiento fijo en pantalla
var canvas_layer_menu: CanvasLayer = null

## Referencia a instancia actual de controlador de venta (para evitar duplicados)
var controlador_venta_actual: Node = null

## Inventario de la tienda (array de IDs de objetos con stock infinito)
@export var inventario_tienda: Array[String] = [
	"POKEBALL",
	"POCION",
	"SUPERPOCION",
	"ANTIDOTO",
	"ANTIPARALIZ",
	"CUERDAHUIDA",
	"REPELENTE",
	"VELOCIDADX",
	"ATAQUEX",
	"DEFENSAX"
]

## Inventario que sustituye a inventario_tienda cuando se cumplen todas las
## condiciones_ampliado (CondicionTexto: bandera o "MEDALLA_n"), como el
## goto_if_set FLAG_PETALBURG_MART_EXPANDED_ITEMS de la TIENDA de PETALIA.
@export var inventario_ampliado: Array[String] = []
@export var condiciones_ampliado: Array[String] = []

## Clave del saludo antes del menú (message de pokemart, p. ej. el de CURRO en
## CIUDAD PORTUAL). Vacía = saludo estándar de dependiente.
@export var id_texto_bienvenida: String = ""
## NOTICIA POKéMON que rebaja esta tienda a mitad de precio el día señalado
## (GetPriceReduction / IsPriceDiscounted: solo CURRO, el ENERGY GURU de PORTUAL).
@export var noticia_rebaja: NoticiasPokemon.Tipo = NoticiasPokemon.Tipo.NINGUNA

## Control de cámara para tienda
var celda_activada: Vector2i = Vector2i(-1, -1)  # Celda donde se activó el vendedor
var desplazamiento_camara_original: Vector2 = Vector2.ZERO  # Posición original de la cámara
var camara_desplazada: bool = false  # Flag para saber si la cámara está desplazada

## ============================================================================
## INICIALIZACIÓN
## ============================================================================

func _ready() -> void:
	super._ready()

	# Configurar el NPC como vendedor
	_configurar_vendedor()

	_obtener_canvas_layer_menu()

	print("🏪 Vendedor configurado: ", name)

## Hoy es el día de la NOTICIA POKéMON de esta tienda (mitad de precio).
func tiene_rebaja() -> bool:
	return NoticiasPokemon.hay_rebaja(noticia_rebaja)

func _configurar_vendedor():
	# Configuración específica del vendedor
	# tipo_movimiento = TipoMovimientoNPC.SIN_MOVIMIENTO

	# Asegurar que el NPC tenga un sprite apropiado
	if animated_sprite:
		# Aquí podrías cambiar el sprite del vendedor si es necesario
		pass

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
## LÓGICA DEL VENDEDOR
## ============================================================================

func evento_accion() -> void:
	if estado_actual != EstadoNPC.IDLE or menu_tienda_activo or jugador.no_control:
		return

	# También por MOSTRADOR se entra aquí, sin una segunda validación por celdas.
	celda_activada = nodo_administrador.celda_frente_jugador() if nodo_administrador else coord_celda
	cambiar_estado(EstadoNPC.INTERACTING)
	# menu_tienda_activo = true

	# Mirar hacia el jugador
	mirar_jugador()
	jugador.no_control = true
	jugador.start_dialog()

	# Establecer estado de diálogo en el administrador
	if nodo_administrador:
		Singleton.mantener_pausa(&"vendedor", true)
		_loggear("🔒 Pausa activada para bloquear menú de pausa")

	# Mostrar diálogo de bienvenida y abrir tienda
	_iniciar_interaccion_tienda()

func _iniciar_interaccion_tienda():
	if nodo_administrador and nodo_administrador.cuadro_dialogo:
		var mensaje_bienvenida = "¡Hola!\\p¿En qué puedo ayudarte?"
		if not id_texto_bienvenida.is_empty():
			mensaje_bienvenida = id_texto_bienvenida
		nodo_administrador.cuadro_dialogo.mostrar(
			tr(mensaje_bienvenida),
			false,   # No se espera tecla
			false,   # No se cierra automáticamente
			Callable(self, "_mostrar_menu_tienda"),  # así que esperamos callable apenas termina el texto
			true     # waitmessage: los \w internos (CURRO) sí esperan botón
		)
	else:
		_mostrar_menu_tienda()

func _volver_interaccion_tienda():
	if nodo_administrador and nodo_administrador.cuadro_dialogo:
		var mensaje_bienvenida = "¿Puedo ayudarte en\nalgo más?"
		nodo_administrador.cuadro_dialogo.mostrar(
			tr(mensaje_bienvenida),
			false,   # No se espera tecla
			false,   # No se cierra automáticamente
			Callable(self, "_mostrar_menu_tienda")  # así que esperamos callable apenas termina el texto
		)
	else:
		_mostrar_menu_tienda()

func _mostrar_menu_tienda():
	var opciones: Array[String] = ["COMPRAR", "VENDER", "SALIR"]
	_mostrar_menu_personalizado(opciones, Callable(self, "_procesar_opcion_menu"))

func _procesar_opcion_menu(opcion_index: int):
	_loggear("🛒 === PROCESANDO OPCIÓN DEL MENÚ ===")
	_loggear("🛒 Índice seleccionado: %d" % opcion_index)

	match opcion_index:
		0: # Comprar
			_loggear("🛒 Opción COMPRAR seleccionada")
			_abrir_pantalla_comprar()
		1: # Vender
			_loggear("🛒 Opción VENDER seleccionada")
			_mostrar_menu_vender()
		2: # Salir
			_loggear("🛒 Opción SALIR seleccionada")
			_cerrar_tienda()
		_:
			_loggear("🛒 Opción desconocida: %d - cerrando tienda" % opcion_index)
			_cerrar_tienda()

func _abrir_pantalla_comprar():
	# _loggear("🛒 === INICIANDO APERTURA DE PANTALLA DE COMPRA ===")

	# Ocultar menú actual
	# _loggear("🛒 Desactivando captura de input del menú")
	_desactivar_captura_input_menu()
	_cerrar_cuadro_dialogo()

	# Verificar si Singleton tiene el método transicion
	# _loggear("🛒 Verificando método transicion en Singleton...")
	if Singleton.has_method("transicion"):
		# _loggear("🛒 ✅ Método transicion encontrado")

		# Realizar transición de oscurecer
		# _loggear("🛒 Ejecutando transición 'oscurecer'...")
		await Singleton.transicion("oscurecer")
	else:
		_loggear("🛒 ❌ Singleton no tiene método transicion")

	# Aplicar desplazamiento de cámara antes de mostrar la tienda
	_aplicar_desplazamiento_camara()

	# Esperar que termine la transición de oscurecer
	# _loggear("🛒 Esperando 0.5 segundos para la transición...")
	# await get_tree().create_timer(0.5).timeout
	# _loggear("🛒 Transición de oscurecer completada")

	# Cargar escena de compra
	# _loggear("🛒 Cargando escena de compra...")
	var escena_compra = preload("res://UI/comprar/comprar.tscn")
	# _loggear("🛒 ✅ Escena preload exitoso")

	var instancia_compra = escena_compra.instantiate()
	# _loggear("🛒 ✅ Instancia creada: %s" % instancia_compra)

	# Verificar si tiene el método configurar_tienda
	# _loggear("🛒 Verificando método configurar_tienda...")
	if instancia_compra.has_method("configurar_tienda"):
		# _loggear("🛒 ✅ Configurando tienda con inventario...")
		instancia_compra.configurar_tienda(inventario_actual(), self)
	else:
		_loggear("🛒 ❌ El método configurar_tienda no existe en la instancia")

	# Agregar la escena al árbol - preferir CanvasLayer del menú
	# _loggear("🛒 Agregando escena al árbol de nodos...")
	var contenedor_target = null

	# Intentar usar el CanvasLayer del menú primero
	if canvas_layer_menu and canvas_layer_menu.is_inside_tree():
		contenedor_target = canvas_layer_menu
		# _loggear("🛒 Usando CanvasLayer del menú: %s" % canvas_layer_menu.get_path())
	else:
		# Fallback: usar escena actual
		contenedor_target = get_tree().current_scene
		# _loggear("🛒 Fallback: usando escena actual: %s" % contenedor_target)

	contenedor_target.add_child(instancia_compra)
	_loggear("🛒 ✅ Escena agregada al contenedor: %s" % contenedor_target.get_path())

	# Aclarar pantalla
	# _loggear("🛒 Ejecutando transición 'aclarar'...")
	Singleton.transicion("aclarar")

	# Conectar señal de cierre
	# _loggear("🛒 Verificando señal compra_cerrada...")
	if instancia_compra.has_signal("compra_cerrada"):
		# _loggear("🛒 ✅ Conectando señal compra_cerrada")
		instancia_compra.connect("compra_cerrada", _on_compra_cerrada)
	else:
		_loggear("🛒 ❌ La señal compra_cerrada no existe")

	# _loggear("🛒 === APERTURA DE PANTALLA DE COMPRA COMPLETADA ===")

func _on_compra_cerrada():
	_loggear("🛒 Pantalla de compra cerrada, volviendo al menú")

	# Quitar desplazamiento de cámara
	_quitar_desplazamiento_camara()

	# Volver al menú principal de la tienda
	_volver_interaccion_tienda()

## ============================================================================
## SISTEMA DE MENÚ SIGUIENDO PATRÓN OFICIAL
## ============================================================================

func _mostrar_menu_personalizado(opciones: Array[String], callback: Callable):
	if menu_tienda_activo:
		_loggear("⚠️ Menú ya activo, ignorando")
		return

	opciones_menu_actual = opciones
	callback_menu_actual = callback
	indice_seleccion = 0

	_crear_menu_con_patron_oficial()

func _crear_menu_con_patron_oficial():
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
	menu_node.position = Vector2(0, 0)

	# 5. Calcular tamaño dinámico según opciones
	var altura_total = (opciones_menu_actual.size() * 16) + 16  # 16px por línea + padding
	var ancho_maximo = 88
	menu_node.size = Vector2(ancho_maximo, altura_total)

	# 6. Agregar MenuBoxComponent para auto-actualización
	menu_box_component = preload("res://scripts/clases/MenuBoxComponent.gd").new()
	menu_box_component.auto_update_on_options_change = true
	menu_node.add_child(menu_box_component)

	# 7. Crear labels para cada opción
	_crear_labels_opciones()

	# 8. Crear cursor oficial
	_crear_cursor_oficial()

	# 9. Agregar al CanvasLayer para posicionamiento fijo en pantalla
	if canvas_layer_menu:
		canvas_layer_menu.add_child(menu_node)
		_loggear("📋 Menú agregado al CanvasLayer")
	else:
		# Fallback: agregar al vendedor
		add_child(menu_node)
		_loggear("📋 Menú agregado al vendedor (fallback)")

	# 10. Activar sistema
	menu_tienda_activo = true
	_actualizar_display_menu_oficial()

	# 11. Activar captura de input tras delay
	await get_tree().create_timer(0.3).timeout
	set_process_input(true)
	_loggear("📋 Menú activo y listo para input")

func _calcular_ancho_maximo_texto() -> int:
	var ancho_maximo = 100  # Mínimo
	var font_size = 12  # Tamaño estándar en el proyecto

	for opcion in opciones_menu_actual:
		var ancho_texto = len(opcion) * (font_size * 0.6)  # Estimación aproximada
		ancho_maximo = max(ancho_maximo, int(ancho_texto))

	return ancho_maximo

func _crear_labels_opciones():
	const LABEL_SETTINGS = preload("res://UI/texto_normal_negro.tres")
	labels_opciones.clear()

	for i in range(opciones_menu_actual.size()):
		var label = Label.new()
		label.text = opciones_menu_actual[i]
		label.label_settings = LABEL_SETTINGS
		label.position = Vector2(8, 8 + (i * 16))  # 24px para dejar espacio al cursor
		menu_node.add_child(label)
		labels_opciones.append(label)

func _crear_cursor_oficial():
	cursor_menu = PkSelectorSimple.new()
	cursor_menu.color = Color(239/255.0, 110/255.0, 96/255.0)  # Color oficial ef6960
	cursor_menu.ancho_borde = 1
	cursor_menu.parpadeo = false

	# Tamaño del cursor para cubrir toda la línea de texto
	var ancho_cursor = menu_node.size.x - 14  # -14 para márgenes
	cursor_menu.size = Vector2(ancho_cursor, 17)

	menu_node.add_child(cursor_menu)

func _actualizar_display_menu_oficial():
	if not cursor_menu or not menu_tienda_activo:
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
	if not menu_tienda_activo or opciones_menu_actual.is_empty():
		return

	# Ignorar eventos de mouse
	if event is InputEventMouseMotion:
		return

	if event.is_action_pressed("btn_arriba"):
		if indice_seleccion > 0:
			_mover_cursor_menu(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("btn_abajo"):
		if indice_seleccion < opciones_menu_actual.size() - 1:
			_mover_cursor_menu(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("btn_accion"):
		if indice_seleccion < 2:
			_confirmar_seleccion_menu()
		else:
			_cancelar_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("btn_cancelar"):
		_cancelar_menu()
		get_viewport().set_input_as_handled()

func _mover_cursor_menu(direccion: int):
	indice_seleccion += direccion

	# Wraparound del cursor
	if indice_seleccion < 0:
		indice_seleccion = opciones_menu_actual.size() - 1
	elif indice_seleccion >= opciones_menu_actual.size():
		indice_seleccion = 0

	# Reproducir sonido de cursor (patrón oficial)
	if Singleton.has_signal("play_sound"):
		Singleton.play_sound.emit("cursor_menu")

	_actualizar_display_menu_oficial()

func _confirmar_seleccion_menu():
	_loggear("🛒 === CONFIRMANDO SELECCIÓN DE MENÚ ===")
	_loggear("🛒 Índice actual: %d" % indice_seleccion)
	_loggear("🛒 Opciones disponibles: %s" % opciones_menu_actual)

	var seleccion = indice_seleccion
	# Guardar el callback ANTES de desactivar la captura de input
	var callback_guardado = callback_menu_actual

	_loggear("🛒 Desactivando captura de input...")
	_desactivar_captura_input_menu()

	# Ejecutar callback con la selección usando el callback guardado
	_loggear("🛒 Verificando callback guardado...")
	if callback_guardado.is_valid():
		_loggear("🛒 ✅ Ejecutando callback con selección: %d" % seleccion)
		callback_guardado.call(seleccion)
	else:
		_loggear("🛒 ❌ Callback guardado no válido")

func _cancelar_menu():
	_desactivar_captura_input_menu()
	_mostrar_dialogo_despedida()

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
			# Fallback: remover del vendedor
			if menu_node.get_parent() == self:
				remove_child(menu_node)

		menu_node.queue_free()
		menu_node = null

	# Limpiar referencias
	labels_opciones.clear()
	cursor_menu = null
	menu_box_component = null
	opciones_menu_actual.clear()
	callback_menu_actual = Callable()
	menu_tienda_activo = false

func _mostrar_menu_vender():
	_loggear("🛒 === INICIANDO SISTEMA DE VENTA ===")

	# Evitar crear múltiples instancias si ya hay una activa
	if controlador_venta_actual and is_instance_valid(controlador_venta_actual):
		_loggear("⚠️ Ya existe un controlador de venta activo. Ignorando nueva apertura.")
		return

	# Ocultar menú actual
	_desactivar_captura_input_menu()
	_cerrar_cuadro_dialogo()

	# Realizar transición de oscurecer
	if Singleton.has_method("transicion"):
		await Singleton.transicion("oscurecer")

	# Aplicar desplazamiento de cámara
	# _aplicar_desplazamiento_camara()

	# Crear instancia del controlador de venta
	var escena_venta = preload("res://UI/vender/vender.tscn")
	var controlador_venta = escena_venta.instantiate()
	controlador_venta.name = "UI_Vender"  # Nombre estándar para depuración

	# Agregar al árbol
	var contenedor_target = null
	if canvas_layer_menu and canvas_layer_menu.is_inside_tree():
		contenedor_target = canvas_layer_menu
	else:
		contenedor_target = get_tree().current_scene

	contenedor_target.add_child(controlador_venta)
	_loggear("🛒 ✅ Controlador de venta agregado")
	controlador_venta_actual = controlador_venta

	# Configurar el controlador
	controlador_venta.configurar_venta(self)

	# Conectar señal de cierre
	if controlador_venta.has_signal("venta_cerrada"):
		controlador_venta.connect("venta_cerrada", _on_venta_cerrada)

	# Aclarar pantalla. Lo quito, esto lo tiene que hacer la escena instanciada.
	# if Singleton.has_method("transicion"):
	# 	Singleton.transicion("aclarar")

	_loggear("🛒 === SISTEMA DE VENTA INICIADO ===")

func _on_venta_cerrada():
	_loggear("🛒 Sistema de venta cerrado, volviendo al menú")
	# Limpiar referencia para permitir nuevas aperturas
	if controlador_venta_actual and not is_instance_valid(controlador_venta_actual):
		controlador_venta_actual = null
	else:
		controlador_venta_actual = null

	# Quitar desplazamiento de cámara
	# _quitar_desplazamiento_camara()

	# Volver al menú principal de la tienda
	_volver_interaccion_tienda()

func _cerrar_cuadro_dialogo():
	if nodo_administrador and nodo_administrador.cuadro_dialogo:
		nodo_administrador.cuadro_dialogo.cierra_dialogo()

func _procesar_compra(item_index: int):
	# Con el array, todos los objetos están disponibles (stock infinito)
	var inventario := inventario_actual()
	if item_index >= inventario.size():
		# Opción "Volver"
		_mostrar_menu_tienda()
		return

	var objeto_seleccionado = inventario[item_index]
	_confirmar_compra(objeto_seleccionado)

func _confirmar_compra(objeto_id: String):
	var datos_objeto = _obtener_datos_objeto(objeto_id)
	var dinero_jugador = _obtener_dinero_jugador()

	if dinero_jugador >= datos_objeto.precio:
		# Realizar compra
		_ejecutar_compra(objeto_id, datos_objeto.precio)
	else:
		_mostrar_dialogo_simple("Lo siento, no tienes suficiente dinero.\\pNecesitas %d$ pero solo tienes %d$." % [datos_objeto.precio, dinero_jugador])

func _ejecutar_compra(objeto_id: String, precio: int):
	# Con stock infinito, no necesitamos verificar ni actualizar stock

	# Quitar dinero y dar objeto al jugador
	_quitar_dinero_jugador(precio)
	_dar_objeto_jugador(objeto_id, 1)

	var datos_objeto = _obtener_datos_objeto(objeto_id)
	_mostrar_dialogo_simple("¡Gracias por tu compra!\\pHas obtenido: %s" % datos_objeto.nombre)

## ============================================================================
## UTILIDADES Y HELPERS
## ============================================================================

## Obtiene todos los datos de un objeto desde caché local, base de datos o fallback.
## {"nombre_interno", "nombre", "icono", "descripcion", "bolsillo_id", "bolsillo_nombre", "precio", "orden"}
func _obtener_datos_objeto(objeto_id: String) -> Dictionary:
	_loggear("[%s] Obteniendo datos para: %s" % [name, objeto_id])

	# Interfaz con el sistema de objetos del juego
	if SistemaGuardado and SistemaGuardado.has_method("obtener_datos_objeto_completos"):
		_loggear("[%s] Usando SistemaGuardado.obtener_datos_objeto_completos" % [name])
		var datos = SistemaGuardado.obtener_datos_objeto_completos(objeto_id)
		_loggear("[%s] Datos recibidos de SistemaGuardado: %s" % [name, datos])

		# Verificar si los datos son válidos
		if datos and typeof(datos) == TYPE_DICTIONARY and not datos.is_empty():
			# Asegurar que tenga precio
			if not datos.has("precio"):
				_loggear("[%s] ⚠️ Datos sin precio, agregando fallback")
				datos["precio"] = 100
			return datos
		else:
			_loggear("[%s] ❌ Datos inválidos de SistemaGuardado, usando fallback" % [name])
	else:
		_loggear("[%s] ❌ SistemaGuardado no disponible o sin método" % [name])

	# Fallback con datos básicos
	var datos_fallback = {
		"nombre": objeto_id.capitalize(),
		"precio": 100,  # Precio por defecto
		"descripcion": "Un objeto útil."
	}
	_loggear("[%s] Usando datos fallback: %s" % [name, datos_fallback])
	return datos_fallback

func _obtener_dinero_jugador() -> int:
	if SistemaGuardado and SistemaGuardado.has_method("get_dinero_jugador"):
		return SistemaGuardado.get_dinero_jugador()
	return 0

func _quitar_dinero_jugador(cantidad: int):
	if SistemaGuardado and SistemaGuardado.has_method("quitar_dinero_jugador"):
		SistemaGuardado.quitar_dinero_jugador(cantidad)

func _dar_dinero_jugador(cantidad: int):
	if SistemaGuardado and SistemaGuardado.has_method("dar_dinero_jugador"):
		SistemaGuardado.dar_dinero_jugador(cantidad)

func _dar_objeto_jugador(objeto_id: String, cantidad: int):
	if SistemaGuardado and SistemaGuardado.has_method("dar_objeto_jugador"):
		SistemaGuardado.dar_objeto_jugador(objeto_id, cantidad)

func _mostrar_dialogo_simple(texto: String):
	if nodo_administrador and nodo_administrador.cuadro_dialogo:
		nodo_administrador.cuadro_dialogo.mostrar(
			tr(texto),
			true,
			true,
			Callable(self, "_cerrar_tienda")
		)
	else:
		_cerrar_tienda()

func _obtener_cuadro_dialogo():
	if nodo_administrador and nodo_administrador.cuadro_dialogo:
		return nodo_administrador.cuadro_dialogo
	return null

func _mostrar_dialogo_despedida():
	if nodo_administrador and nodo_administrador.cuadro_dialogo:
		nodo_administrador.cuadro_dialogo.mostrar(
			tr("¡Vuelve cuando quieras!"),
			true,   # Esperar input
			true,   # Cerrar después del input
			Callable(self, "_cerrar_tienda")  # Callback para liberar al jugador
		)
	else:
		_cerrar_tienda()

func _cerrar_tienda():
	menu_tienda_activo = false
	_desactivar_captura_input_menu()
	cambiar_estado(EstadoNPC.IDLE)

	# Quitar desplazamiento de cámara si está aplicado
	_quitar_desplazamiento_camara()

	# Devolver control al jugador
	if jugador:
		_loggear("Devolviendo control al jugador")
		jugador.end_dialog()
		jugador.no_control = false
		Singleton.mantener_pausa(&"vendedor", false)

	_loggear("🏪 Tienda cerrada")

## ============================================================================
## CONFIGURACIÓN AVANZADA
## ============================================================================

## Objetos a la venta ahora: el inventario ampliado si se cumplen sus condiciones.
func inventario_actual() -> Array[String]:
	if inventario_ampliado.is_empty():
		return inventario_tienda
	for condicion in condiciones_ampliado:
		if not CondicionTexto.cumple(condicion):
			return inventario_tienda
	return inventario_ampliado

## Actualizar inventario de la tienda (ya no maneja stock, solo verifica si existe)
func actualizar_stock(objeto_id: String, _nueva_cantidad: int = 0):
	# Con el nuevo sistema de array, solo verificamos si el objeto está en la lista
	if objeto_id in inventario_tienda:
		print("📦 Objeto %s ya está en el inventario (stock infinito)" % objeto_id)
	else:
		print("📦 ⚠️ Objeto %s no está en el inventario de la tienda" % objeto_id)

## Agregar nuevo objeto a la tienda
func agregar_objeto_tienda(objeto_id: String, _stock: int = -1):
	if objeto_id not in inventario_tienda:
		inventario_tienda.append(objeto_id)
		print("🆕 Nuevo objeto agregado a la tienda: %s (Stock infinito)" % objeto_id)
	else:
		print("🆕 El objeto %s ya existe en la tienda" % objeto_id)

## ============================================================================
## SISTEMA DE REGALOS ESPECIALES
## ============================================================================

func _es_pokeball(objeto_id: String) -> bool:
	"""A diferencia de Rubí (solo POKé BALL), cualquier tipo de ball cuenta para el regalo"""
	return objeto_id.ends_with("BALL")

func procesar_compra_con_regalos(objeto_id: String, cantidad: int) -> String:
	"""Procesa una compra y verifica si hay que dar regalos especiales"""
	_loggear("🎁 Verificando regalos para compra: %d x %s" % [cantidad, objeto_id])

	var mensaje_extra = ""

	# Verificar regalo de Honor Ball por compra de pokéballs
	if _es_pokeball(objeto_id) and cantidad >= 10:
		_loggear("🎁 ¡Compra de %d pokéballs detectada! Dando Honor Ball de regalo" % cantidad)

		# Dar la Honor Ball
		if SistemaGuardado and SistemaGuardado.has_method("dar_objeto_jugador"):
			SistemaGuardado.dar_objeto_jugador("HONORBALL", 1)
			mensaje_extra = "\\pAdemás te voy a dar una\\lHONOR BALL de regalo."
			_loggear("🎁 ✅ Honor Ball entregada como regalo")
		else:
			_loggear("🎁 ❌ No se pudo entregar Honor Ball - SistemaGuardado no disponible")

	return mensaje_extra

## ============================================================================
## CONTROL DE CÁMARA
## ============================================================================

## Ajuste visual según el lado del mostrador, independiente del alcance de interacción.
func _offset_camara_compra() -> Vector2:
	match celda_activada - coord_celda:
		Vector2i.RIGHT:
			return Vector2(48, 7)
		Vector2i.DOWN:
			return Vector2(64, -9)
		Vector2i.UP:
			return Vector2(64, 23)
		Vector2i.LEFT:
			return Vector2(80, 7)
	# Shop_DrawViewportTiles centra siempre la celda frente al jugador,
	# también cuando habla directamente, sin mostrador.
	if jugador != null:
		return Vector2(64, 7) + Vector2(jugador.facing_direction) * 16
	return Vector2.ZERO


## Aplica desplazamiento de cámara al abrir la lista de compra.
func _aplicar_desplazamiento_camara():
	var offset_cam: Vector2 = _offset_camara_compra()
	if offset_cam == Vector2.ZERO:
		return

	# Obtener la cámara del jugador
	var camara = _obtener_camara_jugador()
	if camara:
		# Guardar posición original (antes del override)
		desplazamiento_camara_original = camara.global_position
		# _loggear("🎥 Posición original de cámara guardada: %s" % desplazamiento_camara_original)

		# Aplicar desplazamiento usando el nuevo sistema de override: 48px derecha, 7px abajo
		var nueva_posicion = desplazamiento_camara_original + offset_cam

		# Usar el nuevo método de la cámara para establecer posición fija
		if camara.has_method("establecer_posicion_fija"):
			camara.establecer_posicion_fija(nueva_posicion)
			camara_desplazada = true
			# _loggear("🎥 ✅ Cámara desplazada usando override a: %s" % nueva_posicion)
		else:
			# Fallback al método anterior si la cámara no tiene el nuevo sistema
			camara.global_position = nueva_posicion
			camara_desplazada = true
			# _loggear("🎥 ✅ Cámara desplazada (fallback) a: %s" % nueva_posicion)
	# else:
		# _loggear("🎥 ❌ No se pudo obtener la cámara del jugador")
	# else:
	# 	_loggear("🎥 No se requiere desplazamiento (celda activada no es la primera)")

## Quita el desplazamiento de cámara si estaba aplicado
func _quitar_desplazamiento_camara():
	if camara_desplazada:
		# _loggear("🎥 Quitando desplazamiento de cámara...")

		var camara = _obtener_camara_jugador()
		if camara:
			# Usar el nuevo método de la cámara para quitar el override
			if camara.has_method("quitar_posicion_fija"):
				camara.quitar_posicion_fija()
				# _loggear("🎥 ✅ Override de cámara removido, volviendo al auto-enfoque")
			else:
				# Fallback al método anterior
				camara.global_position = desplazamiento_camara_original
				# _loggear("🎥 ✅ Cámara restaurada (fallback) a posición original: %s" % desplazamiento_camara_original)

			camara_desplazada = false
	# 	else:
	# 		_loggear("🎥 ❌ No se pudo obtener la cámara del jugador para restaurar")
	# else:
	# 	_loggear("🎥 No hay desplazamiento de cámara que quitar")

## Obtiene la cámara del jugador
func _obtener_camara_jugador() -> Camera2D:
	if jugador and jugador.has_method("get_node"):
		# Buscar la cámara en el jugador
		var camara = jugador.get_node_or_null("Camera2D")
		if camara and camara is Camera2D:
			return camara

		# Buscar en hijos del jugador
		for hijo in jugador.get_children():
			if hijo is Camera2D:
				return hijo

	# Fallback: buscar en la escena actual
	var camaras = get_tree().get_nodes_in_group("jugador_camara")
	if camaras.size() > 0:
		return camaras[0]

	# Último fallback: buscar cualquier Camera2D en la escena
	if get_tree().current_scene:
		var nodos_camara = []
		_buscar_nodos_tipo(get_tree().current_scene, Camera2D, nodos_camara)
		if nodos_camara.size() > 0:
			return nodos_camara[0]

	return null

## Función auxiliar para buscar nodos de un tipo específico
func _buscar_nodos_tipo(nodo: Node, tipo: Variant, resultado: Array):
	if nodo is Camera2D:
		resultado.append(nodo)

	for hijo in nodo.get_children():
		_buscar_nodos_tipo(hijo, tipo, resultado)

## ============================================================================
## DEPURACIÓN
## ============================================================================

func _on_debug_info():
	print("=== DEBUG VENDEDOR ===")
	print("ID: ", name)
	print("Estado: ", estado_actual)
	print("Celda accionada: ", celda_activada)
	print("Menú activo: ", menu_tienda_activo)
	print("Inventario: ", inventario_tienda)
	print("====================")

## Función de logging para debugging
func _loggear(mensaje: String):
	print("🏪 [VENDEDOR] → %s" % mensaje)

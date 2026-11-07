## comprar.gd
## Controlador para la pantalla de compra del pokeshop
## Basado en la estructura de mochila.gd
##
extends Control
class_name CompraUI

signal compra_cerrada

# Referencias a nodos de la escena
@onready var nd_marcador = get_node_or_null("marcador")
@onready var nd_pokeball = get_node_or_null("Pokeball")
@onready var lb_descripcion = $descripcion
# @onready var nd_lista = $Lista
@onready var nd_flecha_arriba = $"flecha-arriba"
@onready var nd_flecha_abajo = $"flecha-abajo"
@onready var nd_cursor = $cursor
@onready var nd_dinero = $"Dinero/Label_Dinero"
@onready var nd_lista_mostrada = $Lista # Tiene de hijo los RichTextLabels para los objetos

# Sistema de navegación
var item_actual: int = 0
var offset_lista: int = 0
var posicion_cursor_base = Vector2(111, 15)
var salto_cursor = 16
var max_items_visibles = 8

# Datos de la tienda
var inventario_tienda: Array[String] = []
var objetos_disponibles: Array[Dictionary] = []
var vendedor_ref: Node = null

# Control de input
var input_activo: bool = false
var nav_vertical_timer: Timer = null
var nav_vertical_direccion: int = 0
var nav_vertical_phase: int = 0
# Ruby: InitKeys (src/main.c), 40 fotogramas de espera y 5 entre repeticiones.
const NAV_VERTICAL_INITIAL_DELAY := 40.0 / 60.0
const NAV_VERTICAL_REPEAT_INTERVAL := 5.0 / 60.0

# Sistema de compra de unidades
var modo_unidades_activo: bool = false
var cantidad_compra: int = 1
var objeto_compra_actual: Dictionary = {}
var max_cantidad_comprable: int = 99

# Crear transición de pantalla negra a transparente
var transicion_opacidad := 1.0
var transicion_activa := false
var transicion_velocidad := 1.5

# Cuadro de diálogo para confirmaciones
var cuadro_dialogo = null
var dinero_jugador: int = 0

func _ready():
	print("🛒 === COMPRA.GD _READY INICIADO ===")
	print("🛒 Pantalla de compra inicializada")
	
	# Configurar cursor inicial
	print("🛒 Configurando cursor...")
	if nd_cursor:
		nd_cursor.position = posicion_cursor_base
		nd_cursor.visible = true
		print("🛒 ✅ Cursor configurado")
	else:
		print("🛒 ❌ nd_cursor no encontrado")
	
	# Configurar timer para navegación vertical
	print("🛒 Configurando timer de navegación...")
	nav_vertical_timer = Timer.new()
	nav_vertical_timer.wait_time = NAV_VERTICAL_INITIAL_DELAY
	nav_vertical_timer.one_shot = true
	nav_vertical_timer.timeout.connect(_on_nav_vertical_timeout)
	add_child(nav_vertical_timer)
	print("🛒 ✅ Timer configurado")
	
	# Aplicar texturas MenuBox iniciales
	_aplicar_texturas_menu_box()
	
	# Actualizar dinero del jugador
	print("🛒 Actualizando dinero...")
	_actualizar_dinero()
	nd_flecha_abajo.play("default")
	nd_flecha_arriba.play("default")
	print("🛒 Actualizando display...")
	_actualizar_display()

	if cuadro_dialogo == null:
		cuadro_dialogo = Singleton.get_cuadro_dialogo()

	# NO activar input aquí - se activará después de configurar_tienda()
	print("🛒 === COMPRA.GD _READY COMPLETADO ===")
	print("🛒 ⏳ Esperando configuración de tienda antes de activar input...")

## Configura la tienda con el inventario y referencia al vendedor
func configurar_tienda(inventario: Array, vendedor: Node):
	print("🛒 === CONFIGURANDO TIENDA ===")
	print("🛒 Inventario recibido: %s" % inventario)
	print("🛒 Vendedor recibido: %s" % vendedor)
	
	inventario_tienda = inventario
	vendedor_ref = vendedor
	
	# Crear lista de objetos disponibles
	print("🛒 Creando lista de objetos...")
	_crear_lista_objetos()
	print("🛒 === CONFIGURACIÓN DE TIENDA COMPLETADA ===")
	
	# Activar input después de que todo esté configurado
	print("🛒 Esperando que el nodo esté en el árbol y 0.3 segundos antes de activar input...")
	
	# Esperar hasta que el nodo esté en el árbol
	if not is_inside_tree():
		await tree_entered
	
	# Ahora sí podemos usar get_tree() de forma segura
	await get_tree().create_timer(0.3).timeout
	input_activo = true
	set_process_input(true)
	print("🛒 ✅ Input activado después de configuración")

## Crea la lista de objetos disponibles para comprar
func _crear_lista_objetos():
	objetos_disponibles.clear()
	
	for objeto_id in inventario_tienda:
		# Con el nuevo sistema, todos los objetos tienen stock infinito
		print("🛒 Procesando objeto: %s" % objeto_id)
		var datos_objeto = _obtener_datos_objeto(objeto_id)
		# print("🛒 Datos objeto recibidos: %s" % datos_objeto)
		# print("🛒 Tipo de datos: %s" % typeof(datos_objeto))

		# Omitir IDs desconocidos y objetos sin bolsillo activo.
		if datos_objeto.get("bolsillo_id", -1) < 0:
			push_warning("🛒 Objeto '%s' omitido de la tienda: no tiene un bolsillo activo en la mochila" % objeto_id)
			continue

		objetos_disponibles.append({
			"id": objeto_id,
			"nombre": datos_objeto.nombre,
			# ItemId_GetPrice(itemId) >> GetPriceReduction(1): mitad de precio con rebaja.
			"precio": int(datos_objeto.precio) >> (1 if _hay_rebaja() else 0),
			"descripcion": datos_objeto.descripcion,
			"stock": -1  # Stock infinito
		})
		
	# Agregamos opción para salir
	objetos_disponibles.append({
		"id": "salir",
		"nombre": "Salir",
		"precio": 0,
		"descripcion": "Dejar de comprar.",
		"stock": -1
	})

	print("🛒 Objetos disponibles: ", objetos_disponibles.size() - 1)

## GetPriceReduction(1) en la tienda: solo la del vendedor que la tiene (CURRO).
func _hay_rebaja() -> bool:
	return vendedor_ref != null and vendedor_ref.has_method("tiene_rebaja") and vendedor_ref.tiene_rebaja()

## Actualiza la visualización de la lista de objetos
func _actualizar_display():
	if not nd_lista_mostrada:
		print("🛒 ❌ nd_lista_mostrada no disponible")
		return
	
	# if objetos_disponibles.is_empty():
	# 	print("🛒 ⚠️ objetos_disponibles está vacío, ocultando todos los elementos")
	# 	# Ocultar todos los elementos si no hay objetos
	# 	for i in range(max_items_visibles):
	# 		var objeto_node = nd_lista_mostrada.get_node_or_null("objeto%d" % (i + 1))
	# 		var cantidad_label = objeto_node.get_node_or_null("cantidad") if objeto_node else null
			
	# 		if objeto_node:
	# 			objeto_node.text = ""
	# 			objeto_node.visible = false
	# 		if cantidad_label:
	# 			cantidad_label.visible = false
	# 	return
	
	print("🛒 Actualizando display con %d objetos disponibles" % (objetos_disponibles.size() - 1))
	
	# Obtener los RichTextLabels de la lista
	for i in range(max_items_visibles):
		var item_richlabel = nd_lista_mostrada.get_node_or_null("objeto%d" % (i + 1))
		var cantidad_label = item_richlabel.get_node_or_null("cantidad") if item_richlabel else null
		
		if not item_richlabel:
			print("🛒 ⚠️ item_richlabel %d no encontrado" % (i + 1))
			continue
			
		var indice_objeto = offset_lista + i
		
		if indice_objeto < objetos_disponibles.size():
			var objeto = objetos_disponibles[indice_objeto]
			
			# Actualizar texto del objeto
			item_richlabel.text = objeto.nombre
			item_richlabel.visible = true

			# Actualizar precio en la etiqueta de cantidad
			if cantidad_label:
				if objeto.id != "salir":
					cantidad_label.text = "%d$" % objeto.precio
					cantidad_label.visible = true
				else:
					cantidad_label.text = ""
					cantidad_label.visible = false
		else: # Slots vacios
			item_richlabel.text = ""
			item_richlabel.visible = false
			if cantidad_label:
				cantidad_label.visible = false
	
	# Actualizar posición del cursor
	_actualizar_cursor()
	
	# Actualizar descripción del objeto seleccionado
	_actualizar_descripcion()
	
	# Actualizar flechas de navegación
	_actualizar_flechas()

## Actualiza la posición del cursor
func _actualizar_cursor():
	if nd_cursor:
		var pos_y = posicion_cursor_base.y + ((item_actual - offset_lista) * salto_cursor)
		nd_cursor.position = Vector2(posicion_cursor_base.x, pos_y)

## Actualiza la descripción del objeto seleccionado
func _actualizar_descripcion():
	if lb_descripcion and item_actual < objetos_disponibles.size():
		var objeto = objetos_disponibles[item_actual]
		lb_descripcion.text = objeto.descripcion

## Actualiza la visibilidad de las flechas de navegación
func _actualizar_flechas():
	if nd_flecha_arriba:
		nd_flecha_arriba.visible = offset_lista > 0
	
	if nd_flecha_abajo:
		nd_flecha_abajo.visible = (offset_lista + max_items_visibles) < objetos_disponibles.size()

## Actualiza la visualización del dinero del jugador
func _actualizar_dinero():
	if nd_dinero:
		dinero_jugador = _obtener_dinero_jugador()
		nd_dinero.text = _formatear_dinero(dinero_jugador)

func _input(event: InputEvent):
	# Ignorar eventos de mouse
	if event is InputEventMouseMotion:
		return

	# Soltar la flecha corta la repetición incluso durante un diálogo.
	if (event.is_action_released("btn_arriba") and nav_vertical_direccion == -1) \
		or (event.is_action_released("btn_abajo") and nav_vertical_direccion == 1):
		_detener_nav_vertical()
		get_viewport().set_input_as_handled()
		return
	
	# Modo unidades tiene prioridad sobre el input normal
	if modo_unidades_activo:
		_procesar_input_unidades(event)
		return
	
	if not input_activo:
		return
	
	if event.is_action_pressed("btn_arriba"):
		_iniciar_nav_vertical(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("btn_abajo"):
		_iniciar_nav_vertical(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("btn_accion"):
		_confirmar_compra()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("btn_cancelar"):
		_cerrar_pantalla()
		get_viewport().set_input_as_handled()

func _procesar_input_unidades(event: InputEvent):
	"""Procesa el input cuando está activo el modo de selección de unidades"""
	if event.is_action_pressed("btn_arriba"):
		_cambiar_cantidad_compra(1)  # +1 unidad
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("btn_abajo"):
		_cambiar_cantidad_compra(-1)  # -1 unidad
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("btn_derecha"):
		_cambiar_cantidad_compra(10)  # +10 unidades
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("btn_izquierda"):
		_cambiar_cantidad_compra(-10)  # -10 unidades
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("btn_accion"):
		_confirmar_compra_unidades()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("btn_cancelar"):
		_cancelar_compra_unidades()
		get_viewport().set_input_as_handled()

## Mueve el cursor arriba (-1) o abajo (1)
func _mover_cursor(direccion: int):
	if objetos_disponibles.is_empty():
		return
	
	var nuevo_indice = item_actual + direccion
	
	# Limitar el cursor a los objetos disponibles
	nuevo_indice = clamp(nuevo_indice, 0, objetos_disponibles.size() - 1)
	
	if nuevo_indice != item_actual:
		item_actual = nuevo_indice
		
		# Ajustar offset si es necesario
		if item_actual < offset_lista:
			offset_lista = item_actual
		elif item_actual >= (offset_lista + max_items_visibles):
			offset_lista = item_actual - max_items_visibles + 1
		
		# Reproducir sonido de cursor
		if Singleton.has_signal("play_sound"):
			Singleton.play_sound.emit("cursor_menu")
		
		_actualizar_display()

## Confirma la compra del objeto seleccionado
func _confirmar_compra():
	_detener_nav_vertical()
	input_activo = false
	if objetos_disponibles.is_empty() or item_actual >= objetos_disponibles.size():
		return
	
	var objeto = objetos_disponibles[item_actual]
	
	# Si el objeto seleccionado es "salir", cerrar la pantalla
	if objeto.id == "salir":
		print("🛒 Opción 'Salir' seleccionada, cerrando pantalla")
		_cerrar_pantalla()
		return
	
	dinero_jugador = _obtener_dinero_jugador()
	
	if dinero_jugador >= objeto.precio:
		# Mostrar diálogo de confirmación
		_mostrar_confirmacion_compra(objeto)
	else:
		_mostrar_mensaje("No tienes suficiente dinero.\\pNecesitas %d$ pero solo tienes %d$." % [objeto.precio, dinero_jugador])

## Mostramos un diálogo preguntando la cantidad a comprar
## Visualizamos el nodo 'Unidades' de la escena 'Comprar'
func _mostrar_unidades_compra(objeto: Dictionary):
	_detener_nav_vertical()
	print("🛒 === INICIANDO SELECCIÓN DE UNIDADES ===")
	print("🛒 Objeto: %s - Precio: %d$" % [objeto.nombre, objeto.precio])
	
	# Guardar referencia del objeto actual
	objeto_compra_actual = objeto
	cantidad_compra = 1
	
	# Calcular máxima cantidad que se puede comprar
	dinero_jugador = _obtener_dinero_jugador()
	if objeto.precio == 0:
		max_cantidad_comprable = 99
	else:
		max_cantidad_comprable = min(99, dinero_jugador / objeto.precio)
	print("🛒 Dinero jugador: %d$ - Máximo comprable: %d" % [dinero_jugador, max_cantidad_comprable])
	
	# Mostrar el nodo de unidades
	var unidades = get_node("Unidades")
	unidades.visible = true
	
	# Actualizar visualización inicial
	_actualizar_display_unidades()
	
	# Cambiar a modo unidades
	input_activo = false
	modo_unidades_activo = true
	print("🛒 ✅ Modo unidades activado")

func _actualizar_display_unidades():
	"""Actualiza la visualización de cantidad y total en el modo unidades"""
	var unidades = get_node("Unidades")
	var lb_unidades = unidades.get_node("lbUnidades")
	var lb_total = unidades.get_node("lbTotal")
	
	lb_unidades.text = "x%d" % cantidad_compra
	var total = objeto_compra_actual.precio * cantidad_compra
	lb_total.text = _formatear_dinero(total)
	
	print("🛒 Cantidad: %d - Total: %s" % [cantidad_compra, _formatear_dinero(total)])

func _cambiar_cantidad_compra(delta: int):
	"""Cambia la cantidad a comprar y actualiza la visualización"""
	var nueva_cantidad = cantidad_compra + delta
	
	if delta == 1 and cantidad_compra == max_cantidad_comprable:
		nueva_cantidad = 1
	elif delta == -1 and cantidad_compra == 1:
		nueva_cantidad = max_cantidad_comprable
	else:
		# Limitar entre 1 y máximo comprable
		nueva_cantidad = clamp(nueva_cantidad, 1, max_cantidad_comprable)
	
	if nueva_cantidad != cantidad_compra:
		cantidad_compra = nueva_cantidad
		_actualizar_display_unidades()
		
		# Reproducir sonido de cursor
		# if Singleton.has_signal("play_sound"):
		# 	Singleton.play_sound.emit("cursor_menu")

## Confirma la compra con la cantidad seleccionada
func _confirmar_compra_unidades():
	print("🛒 Confirmando compra: %d x %s" % [cantidad_compra, objeto_compra_actual.nombre])
	
	# Ocultar el nodo de unidades
	var unidades = get_node("Unidades")
	unidades.visible = false
	
	# Salir del modo unidades
	modo_unidades_activo = false
	
	# Ejecutar la compra múltiple
	_ejecutar_compra_multiple(objeto_compra_actual, cantidad_compra)

func _cancelar_compra_unidades():
	"""Cancela la selección de unidades y vuelve a la lista"""
	print("🛒 Cancelando selección de unidades")
	
	# Ocultar el nodo de unidades
	var unidades = get_node("Unidades")
	unidades.visible = false
	
	# Salir del modo unidades
	modo_unidades_activo = false
	input_activo = true

	if cuadro_dialogo:
		cuadro_dialogo.z_index = 1
		cuadro_dialogo.cierra_dialogo()
	
	print("🛒 Volviendo a la lista de objetos")

## Muestra un diálogo de confirmación para la compra
func _mostrar_confirmacion_compra(objeto: Dictionary):
	_detener_nav_vertical()
	input_activo = false
	
	# Mostrar diálogo previo antes del selector de unidades
	var mensaje = "¿%s? Buena elección.\\l¿Cuántas unidades quieres?" % objeto.nombre
	
	# Usar el cuadro de diálogo del singleton
	if cuadro_dialogo == null:
		cuadro_dialogo = Singleton.get_cuadro_dialogo()
	if cuadro_dialogo:
		cuadro_dialogo.z_index = 3
		cuadro_dialogo.mostrar(
			tr(mensaje),
			false,  # NO esperar input
			false,  # NO cerrar automáticamente
			Callable(self, "_iniciar_seleccion_unidades").bind(objeto)  # Callback cuando termine el texto
		)
	else:
		# Fallback directo si no hay cuadro de diálogo
		_iniciar_seleccion_unidades(objeto)

func _iniciar_seleccion_unidades(objeto: Dictionary):
	"""Inicia el modo de selección de unidades después del diálogo previo"""
	print("🛒 Iniciando selección de unidades tras diálogo previo")
	_mostrar_unidades_compra(objeto)

## Ejecuta la compra múltiple del objeto
func _ejecutar_compra_multiple(objeto: Dictionary, cantidad: int):
	print("🛒 Comprando %d x %s" % [cantidad, objeto.nombre])
	
	var costo_total = objeto.precio * cantidad
	
	# Quitar dinero y dar objetos al jugador
	_quitar_dinero_jugador(costo_total)
	_dar_objeto_jugador(objeto.id, cantidad)
	
	# Con stock infinito, no necesitamos actualizar inventario
	# Solo actualizamos la visualización
	_actualizar_dinero()
	_actualizar_display()
	
	# Verificar regalos especiales a través del vendedor
	var mensaje_regalo = ""
	if vendedor_ref and vendedor_ref.has_method("procesar_compra_con_regalos"):
		mensaje_regalo = vendedor_ref.procesar_compra_con_regalos(objeto.id, cantidad)
	
	# Mostrar mensaje de éxito con regalo si aplica
	var mensaje_gracias = "¡Aquí tienes!\\lMuchas gracias."
	if mensaje_regalo != "":
		mensaje_gracias += mensaje_regalo
	_mostrar_mensaje(mensaje_gracias)

## Muestra un mensaje al jugador
func _mostrar_mensaje(texto: String):
	_detener_nav_vertical()
	input_activo = false
	
	# var cuadro_dialogo = Singleton.get_cuadro_dialogo()
	if cuadro_dialogo:
		cuadro_dialogo.mostrar(
			tr(texto),
			true,   # Esperar input
			true,   # Cerrar automáticamente
			Callable(self, "_reactivar_input")
		)
	else:
		_reactivar_input()

## Reactiva el input después de mostrar un mensaje
func _reactivar_input():
	input_activo = true

## Cierra la pantalla de compra
func _cerrar_pantalla():
	_detener_nav_vertical()
	print("🛒 Cerrando pantalla de compra")
	input_activo = false
	set_process_input(false)
	
	# Realizar transición
	if Singleton.has_method("transicion"):
		Singleton.transicion("oscurecer")
		await get_tree().create_timer(0.5).timeout
		
		# Emitir señal de cierre
		compra_cerrada.emit()
		
		# Aclarar pantalla
		Singleton.transicion("aclarar")
		
		# Remover del árbol
		queue_free()

## Mueve una vez al pulsar y programa la repetición sin depender del eco del SO.
func _iniciar_nav_vertical(direccion: int) -> void:
	if nav_vertical_direccion == direccion:
		return
	_mover_cursor(direccion)
	nav_vertical_direccion = direccion
	nav_vertical_phase = 1
	nav_vertical_timer.wait_time = NAV_VERTICAL_INITIAL_DELAY
	nav_vertical_timer.start()


func _detener_nav_vertical() -> void:
	if nav_vertical_timer != null:
		nav_vertical_timer.stop()
	nav_vertical_direccion = 0
	nav_vertical_phase = 0


## Maneja la navegación vertical continua solo mientras la lista tiene el control.
func _on_nav_vertical_timeout() -> void:
	if not input_activo or modo_unidades_activo or nav_vertical_direccion == 0:
		_detener_nav_vertical()
		return
	var accion: StringName = &"btn_arriba" if nav_vertical_direccion < 0 else &"btn_abajo"
	if not Input.is_action_pressed(accion):
		_detener_nav_vertical()
		return
	_mover_cursor(nav_vertical_direccion)
	nav_vertical_phase = 2
	nav_vertical_timer.wait_time = NAV_VERTICAL_REPEAT_INTERVAL
	nav_vertical_timer.start()


func _exit_tree() -> void:
	_detener_nav_vertical()

## ============================================================================
## UTILIDADES
## ============================================================================

## Obtiene todos los datos de un objeto desde caché local, base de datos o fallback.
## {"nombre_interno", "nombre", "icono", "descripcion", "bolsillo_id", "bolsillo_nombre", "precio", "orden"}
func _obtener_datos_objeto(objeto_id: String) -> Dictionary:
	print("🛒 Obteniendo datos para: %s" % objeto_id)
	
	var datos_objeto: Dictionary = {}
	
	# Intentar obtener datos del vendedor
	if vendedor_ref and vendedor_ref.has_method("_obtener_datos_objeto"):
		# print("🛒 Usando datos del vendedor...")
		datos_objeto = vendedor_ref._obtener_datos_objeto(objeto_id)
		# print("🛒 Datos del vendedor: %s" % datos_objeto)
	# else:
	# 	print("🛒 Vendedor no disponible o sin método _obtener_datos_objeto")
	
	# # Si no se obtuvieron datos válidos, usar fallback
	# if datos_objeto.is_empty() or not datos_objeto.has("nombre"):
	# 	# print("🛒 Usando datos fallback para: %s" % objeto_id)
	# 	datos_objeto = {
	# 		"nombre": objeto_id.capitalize(),
	# 		"precio": 100,
	# 		"descripcion": "Un objeto útil."
	# 	}
	
	# # Asegurar que tenga precio
	# if not datos_objeto.has("precio"):
	# 	datos_objeto["precio"] = 100
	# 	print("🛒 Agregando precio fallback: 100")
	
	# # Asegurar que tenga descripción
	# if not datos_objeto.has("descripcion"):
	# 	datos_objeto["descripcion"] = "Un objeto útil."
	# 	print("🛒 Agregando descripción fallback")
	
	# print("🛒 Datos finales: %s" % datos_objeto)
	return datos_objeto

## Obtiene el dinero del jugador
func _obtener_dinero_jugador() -> int:
	if SistemaGuardado and SistemaGuardado.has_method("get_dinero_jugador"):
		return SistemaGuardado.get_dinero_jugador()
	return 0

## Quita dinero al jugador
func _quitar_dinero_jugador(cantidad: int):
	dinero_jugador -= cantidad
	if SistemaGuardado and SistemaGuardado.has_method("set_dinero"):
		SistemaGuardado.set_dinero(dinero_jugador)

## Da un objeto al jugador
func _dar_objeto_jugador(objeto_id: String, cantidad: int):
	if SistemaGuardado and SistemaGuardado.has_method("dar_objeto_jugador"):
		SistemaGuardado.dar_objeto_jugador(objeto_id, cantidad)

## Formatea un número entero como dinero con separador de miles y símbolo $
func _formatear_dinero(cantidad: int) -> String:
	var cantidad_str = str(cantidad)
	var resultado = ""
	var contador = 0
	
	# Recorrer el string desde el final hacia el principio
	for i in range(cantidad_str.length() - 1, -1, -1):
		if contador > 0 and contador % 3 == 0:
			resultado = "." + resultado
		resultado = cantidad_str[i] + resultado
		contador += 1
	
	return resultado + "$"

## Aplica texturas del MenuBoxManager a los NinePatchRect
func _aplicar_texturas_menu_box():
	var menu_box_manager = preload("res://scripts/clases/MenuBoxManager.gd")
	var image_type = _get_saved_image_type()
	
	# Aplicar textura al cuadro de Dinero
	var dinero_box = get_node_or_null("Dinero")
	if dinero_box and dinero_box is NinePatchRect:
		menu_box_manager.apply_texture_to_ninepatch(dinero_box, image_type)
	
	# Aplicar textura al cuadro de Unidades
	var unidades_box = get_node_or_null("Unidades")
	if unidades_box and unidades_box is NinePatchRect:
		menu_box_manager.apply_texture_to_ninepatch(unidades_box, image_type)

## Obtiene el tipo de imagen guardado en las opciones
func _get_saved_image_type() -> int:
	# Usar SistemaGuardado directamente
	if typeof(SistemaGuardado) != TYPE_NIL and SistemaGuardado.datos_vivos and SistemaGuardado.datos_vivos.opciones:
		return int(SistemaGuardado.datos_vivos.opciones.imagen_tipo)
	
	# Fallback si no está disponible
	var sg = get_tree().root.get_node_or_null("SistemaGuardado")
	if sg and sg.datos_vivos and sg.datos_vivos.opciones:
		return int(sg.datos_vivos.opciones.imagen_tipo)
	
	return 1  # Fallback a imagen_tipo 1

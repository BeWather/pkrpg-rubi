## vender.gd
## Controlador de venta de objetos para el sistema de tienda
## Maneja la venta de objetos del inventario del jugador
##
extends Control

signal venta_cerrada

## Referencias externas
var vendedor_ref: Node = null
var mochila_ref: Node = null

## Referencias a nodos UI
@onready var cuadro_dinero: NinePatchRect = $Dinero
@onready var label_dinero: Label = $Dinero/Label_Dinero
@onready var cuadro_unidades: NinePatchRect = $Unidades
@onready var label_unidades: Label = $Unidades/lbUnidades
@onready var label_total: Label = $Unidades/lbTotal

## Estado del controlador
var venta_activa: bool = false
var objeto_seleccionado: Dictionary = {}
var precio_venta: int = 0
var cantidad_seleccionada: int = 1
var cantidad_maxima: int = 1
var modo_seleccion_cantidad: bool = false

## Configuración de precios de venta
const PORCENTAJE_VENTA: float = 0.5  # Los objetos se venden al 50% de su precio original

var cuadro_dialogo = null

## ============================================================================
## INICIALIZACIÓN Y CONFIGURACIÓN
## ============================================================================

func _ready():
	print("💰 === CONTROLADOR DE VENTA INICIALIZADO ===")
	_inicializar_ui()
	
	if cuadro_dialogo == null:
		cuadro_dialogo = Singleton.get_cuadro_dialogo()

## Inicializa los elementos de la UI
func _inicializar_ui():
	# Mostrar cuadro de dinero, ocultar cuadro de unidades
	cuadro_dinero.visible = false
	cuadro_unidades.visible = false
	
	# Aplicar texturas según opciones del jugador
	_aplicar_texturas_menu_box()
	
	# Actualizar dinero del jugador
	_actualizar_dinero_display()
	
	# Configurar input para selección de cantidad
	set_process_input(false)  # Se activará cuando sea necesario

	# Aclarar pantalla
	if Singleton.has_method("transicion"):
		Singleton.transicion("aclarar")

## Aplica las texturas de MenuBox según las opciones del jugador
func _aplicar_texturas_menu_box():
	var menu_box_manager = preload("res://scripts/clases/MenuBoxManager.gd")
	var image_type = _get_saved_image_type()
	
	menu_box_manager.apply_texture_to_ninepatch(cuadro_dinero, image_type)
	menu_box_manager.apply_texture_to_ninepatch(cuadro_unidades, image_type)

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

## Configura el controlador con las referencias necesarias
func configurar_venta(vendedor: Node):
	print("💰 === CONFIGURANDO SISTEMA DE VENTA ===")
	print("💰 Vendedor recibido: %s" % vendedor)
	
	vendedor_ref = vendedor
	venta_activa = true
	
	print("💰 === CONFIGURACIÓN DE VENTA COMPLETADA ===")
	
	# Abrir la mochila en modo venta
	_abrir_mochila_venta()

## ============================================================================
## GESTIÓN DE MOCHILA EN MODO VENTA
## ============================================================================

func _abrir_mochila_venta():
	print("💰 Abriendo mochila en modo venta...")
	
	# Realizar transición
	if Singleton.has_method("transicion"):
		await Singleton.transicion("oscurecer")
	
	# Cargar escena de mochila
	var escena_mochila = preload("res://UI/mochila/mochila.tscn")
	var instancia_mochila = escena_mochila.instantiate()
	
	# Configurar modo venta en la mochila
	if instancia_mochila.has_method("configurar_modo_venta"):
		instancia_mochila.configurar_modo_venta(true, self)
	else:
		print("💰 ❌ La mochila no tiene soporte para modo venta")
		_cerrar_venta()
		return
	
	# Agregar la mochila al árbol
	var contenedor_target = _obtener_contenedor_mochila()
	contenedor_target.add_child(instancia_mochila)
	mochila_ref = instancia_mochila
	
	# Conectar señales de la mochila
	_conectar_senales_mochila()
	
	# Aclarar pantalla
	if Singleton.has_method("transicion"):
		Singleton.transicion("aclarar")
	
	print("💰 ✅ Mochila abierta en modo venta")

func _obtener_contenedor_mochila() -> Node:
	# Intentar usar el CanvasLayer del menú primero
	var canvas_layer_menu = get_tree().root.get_node_or_null("AdministradorMapa/Menu")
	
	if canvas_layer_menu and canvas_layer_menu.is_inside_tree():
		return canvas_layer_menu
	else:
		# Fallback: usar escena actual
		return get_tree().current_scene

func _conectar_senales_mochila():
	if mochila_ref:
		# Conectar señal de objeto seleccionado para venta
		if mochila_ref.has_signal("objeto_seleccionado_venta"):
			mochila_ref.connect("objeto_seleccionado_venta", _on_objeto_seleccionado_venta)
		
		# Conectar señal de cierre de mochila
		if mochila_ref.has_signal("mochila_cerrada"):
			mochila_ref.connect("mochila_cerrada", _on_mochila_cerrada)

## ============================================================================
## MANEJO DE SEÑALES DE LA MOCHILA
## ============================================================================

func _on_objeto_seleccionado_venta(objeto_datos: Dictionary):
	print("💰 Objeto seleccionado para venta: %s" % objeto_datos)
	
	# Verificar si es "CERRAR LA MOCHILA" - manejar cierre especial
	var nombre = objeto_datos.get("nombre", "")
	if nombre == "CERRAR LA MOCHILA":
		print("💰 Cerrando venta desde mochila...")
		_cerrar_venta()
		return

	# Bloquear input de mochila mientras se procesa el diálogo / selección
	if mochila_ref and mochila_ref.has_method("bloquear_input"):
		mochila_ref.bloquear_input(true)
		print("💰 🔒 Input de mochila bloqueado (esperando diálogo)")
	
	objeto_seleccionado = objeto_datos
	cantidad_maxima = objeto_datos.get("cantidad", 1)
	cantidad_seleccionada = 1
	
	# Verificar si el objeto puede venderse usando la información de la mochila
	var es_vendible = objeto_datos.get("vendible", true)  # Default true para compatibilidad
	if not es_vendible:
		print("💰 Objeto marcado como no vendible por la mochila")
		_mostrar_mensaje_no_vendible(objeto_datos)
		return
	
	# Calcular precio de venta - obtener precio original del sistema
	var precio_original = 100  # Valor por defecto
	
	# Intentar obtener el precio real del objeto
	var objeto_id = objeto_datos.get("nombre_interno", "")
	if objeto_id != "" and SistemaGuardado and SistemaGuardado.has_method("obtener_datos_objeto_completos"):
		var datos_completos = SistemaGuardado.obtener_datos_objeto_completos(objeto_id)
		if datos_completos and datos_completos.has("precio"):
			precio_original = datos_completos.precio
	else:
		# Fallback: usar el precio del objeto si está disponible
		precio_original = objeto_datos.get("precio", 100)
	
	precio_venta = int(precio_original * PORCENTAJE_VENTA)

	# Regla adicional: si el precio original es 0 (u objeto sin valor), no se puede vender
	if precio_original <= 0:
		print("💰 Objeto con precio 0 detectado - marcado como no vendible")
		_mostrar_mensaje_no_vendible(objeto_datos)
		return
	
	print("💰 Precio original: %d$ - Precio de venta: %d$" % [precio_original, precio_venta])
	
	# Mostrar mensaje de confirmación y luego activar selección
	_mostrar_mensaje_vendible(objeto_datos)

func _on_mochila_cerrada():
	print("💰 Mochila cerrada, finalizando venta")
	_cerrar_venta()

## ============================================================================
## GESTIÓN DE UI
## ============================================================================

## Actualizar el dinero del jugador con formato
func _actualizar_dinero_display():
	var dinero_actual = _obtener_dinero_jugador()
	label_dinero.text = _formatear_dinero(dinero_actual)

func _activar_seleccion_cantidad():
	print("💰 === ACTIVANDO SELECCIÓN DE CANTIDAD ===")
	
	# Verificar que los nodos existen
	if not cuadro_dinero:
		print("💰 ❌ cuadro_dinero no existe!")
		return
	if not cuadro_unidades:
		print("💰 ❌ cuadro_unidades no existe!")
		return
	
	print("💰 Nodos UI verificados correctamente")
	
	# Mostrar ambos cuadros (dinero y unidades)
	cuadro_dinero.visible = true
	cuadro_unidades.visible = true
	print("💰 ✅ Cuadros mostrados - Dinero: %s, Unidades: %s" % [cuadro_dinero.visible, cuadro_unidades.visible])
	
	# Bloquear la mochila para que no procese más input
	if mochila_ref and mochila_ref.has_method("bloquear_input"):
		mochila_ref.bloquear_input(true)
		print("💰 ✅ Mochila bloqueada para input")
	else:
		print("💰 ⚠️ No se pudo bloquear la mochila - mochila_ref: %s" % mochila_ref)
	
	# Activar modo selección en el controlador de venta
	modo_seleccion_cantidad = true
	set_process_input(true)
	print("💰 ✅ Input activado - modo_seleccion_cantidad: %s" % modo_seleccion_cantidad)
	
	# Actualizar display
	_actualizar_display_unidades()
	
	print("💰 === SELECCIÓN DE CANTIDAD ACTIVADA ===")
	print("💰 Controles: ↑↓ = ±1, ←→ = ±10, ACCIÓN = confirmar, CANCELAR = cancelar")

## Actualizar cantidad y total
func _actualizar_display_unidades():
	# Actualizar cantidad
	label_unidades.text = "x%d" % cantidad_seleccionada
	
	# Actualizar total
	var total = precio_venta * cantidad_seleccionada
	label_total.text = _formatear_dinero(total)

func _desactivar_seleccion_cantidad(desbloquear_mochila: bool = true):
	print("💰 Desactivando selección de cantidad (desbloquear=%s)" % desbloquear_mochila)
	
	# Ocultar cuadro de unidades, mantener dinero visible
	cuadro_unidades.visible = false
	cuadro_dinero.visible = true
	
	# Solo desbloquear si se indica (para evitar reactivación antes de mostrar diálogos finales)
	if desbloquear_mochila and mochila_ref and mochila_ref.has_method("bloquear_input"):
		mochila_ref.bloquear_input(false)
		print("💰 ✅ Mochila desbloqueada para input")
	else:
		print("💰 🚫 Mochila permanece bloqueada")
	
	# Desactivar modo selección en el controlador de venta
	modo_seleccion_cantidad = false
	set_process_input(false)
	
	print("💰 ✅ Modo selección de cantidad desactivado")

func _formatear_dinero(cantidad: int) -> String:
	var cantidad_str = str(cantidad)
	var resultado = ""
	var contador = 0
	
	# Agregar separadores de miles
	for i in range(cantidad_str.length() - 1, -1, -1):
		if contador > 0 and contador % 3 == 0:
			resultado = "." + resultado
		resultado = cantidad_str[i] + resultado
		contador += 1
	
	return resultado + "$"

func _obtener_dinero_jugador() -> int:
	if SistemaGuardado and SistemaGuardado.has_method("get_dinero_jugador"):
		return SistemaGuardado.get_dinero_jugador()
	return 0

## ============================================================================
## MANEJO DE INPUT PARA SELECCIÓN DE CANTIDAD
## ============================================================================

func _input(event: InputEvent):
	if not modo_seleccion_cantidad:
		return
	
	# print("💰 Input recibido: %s - modo_seleccion_cantidad: %s" % [event.as_text(), modo_seleccion_cantidad])
	
	if event.is_action_pressed("btn_arriba"):
		# print("💰 ↑ Aumentar cantidad (+1)")
		_cambiar_cantidad(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("btn_abajo"):
		# print("💰 ↓ Disminuir cantidad (-1)")
		_cambiar_cantidad(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("btn_derecha"):
		# print("💰 → Aumentar cantidad (+10)")
		_cambiar_cantidad(10)  # +10 unidades
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("btn_izquierda"):
		# print("💰 ← Disminuir cantidad (-10)")
		_cambiar_cantidad(-10)  # -10 unidades
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("btn_accion"):
		print("💰 ✅ Confirmar venta")
		_confirmar_venta()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("btn_cancelar"):
		print("💰 ❌ Cancelar selección")
		_cancelar_seleccion_cantidad()
		get_viewport().set_input_as_handled()

func _cambiar_cantidad(delta: int):
	
	if delta == 1 and cantidad_seleccionada == cantidad_maxima:
		cantidad_seleccionada = 1
	elif delta == -1 and cantidad_seleccionada == 1:
		cantidad_seleccionada = cantidad_maxima
	else:
		cantidad_seleccionada += delta
		cantidad_seleccionada = clamp(cantidad_seleccionada, 1, cantidad_maxima)

	_actualizar_display_unidades()

func _cancelar_seleccion_cantidad():
	print("💰 === CANCELANDO SELECCIÓN DE CANTIDAD ===")
	
	# Ocultar ambos cuadros al cancelar
	cuadro_dinero.visible = false
	cuadro_unidades.visible = false
	print("💰 ✅ Cuadros ocultados")
	
	# Cerrar el cuadro de diálogo
	if cuadro_dialogo and cuadro_dialogo.has_method("cierra_dialogo"):
		cuadro_dialogo.cierra_dialogo()
	
	# Desbloquear la mochila para que pueda procesar input otra vez
	if mochila_ref and mochila_ref.has_method("bloquear_input"):
		mochila_ref.bloquear_input(false)
		print("💰 ✅ Mochila desbloqueada para input")
	
	# Desactivar modo selección en el controlador de venta
	modo_seleccion_cantidad = false
	set_process_input(false)
	
	print("💰 === CANCELACIÓN COMPLETADA - Puede continuar seleccionando objetos ===")

## ============================================================================
## CONFIRMACIÓN Y EJECUCIÓN DE VENTA
## ============================================================================

func _confirmar_venta():
	print("💰 Confirmando venta: %d x %s por %d$" % [cantidad_seleccionada, objeto_seleccionado.nombre, precio_venta * cantidad_seleccionada])
	
	# Desactivar selección de cantidad SIN desbloquear mochila para que no se procese input durante el diálogo de resultado
	_desactivar_seleccion_cantidad(false)
	
	# Ejecutar venta (mostrará mensaje y luego, al cerrar, desbloqueará)
	_ejecutar_venta()

## ============================================================================
## EJECUCIÓN DE VENTA
## ============================================================================

func _ejecutar_venta():
	print("💰 Ejecutando venta: %d x %s por %d$ total" % [cantidad_seleccionada, objeto_seleccionado.nombre, precio_venta * cantidad_seleccionada])
	
	var objeto_id = objeto_seleccionado.get("nombre_interno", "")
	var bolsillo = objeto_seleccionado.get("bolsillo_id", 0)
	
	# Verificar que el jugador aún tiene suficientes objetos
	if not _verificar_objeto_disponible(objeto_id, bolsillo, cantidad_seleccionada):
		_mostrar_mensaje_error("Ya no tienes suficientes objetos de ese tipo.")
		return
	
	# Quitar objetos del inventario
	if _quitar_objeto_jugador(objeto_id, cantidad_seleccionada, bolsillo):
		# Dar dinero al jugador
		var dinero_total = precio_venta * cantidad_seleccionada
		_dar_dinero_jugador(dinero_total)
		
		# Actualizar display de dinero
		_actualizar_dinero_display()
		# Refrescar inventario de mochila de manera incremental inmediatamente
		_actualizar_mochila_incremental(objeto_id, bolsillo, cantidad_seleccionada)
		
		# Mostrar mensaje de éxito y cerrar todo
		var mensaje = "Recibiste %d$\\lpor la venta." % [dinero_total]
		_mostrar_mensaje_exito_y_cerrar(mensaje)
	else:
		_mostrar_mensaje_error("Error al vender los objetos.")

func _verificar_objeto_disponible(objeto_id: String, bolsillo: int, cantidad: int = 1) -> bool:
	if SistemaGuardado and SistemaGuardado.has_method("tiene_objeto"):
		return SistemaGuardado.tiene_objeto(objeto_id, cantidad, bolsillo)
	return false

func _quitar_objeto_jugador(objeto_id: String, cantidad: int, bolsillo: int) -> bool:
	if SistemaGuardado and SistemaGuardado.has_method("quitar_objeto_jugador"):
		return SistemaGuardado.quitar_objeto_jugador(objeto_id, cantidad, bolsillo)
	return false

func _dar_dinero_jugador(cantidad: int):
	if SistemaGuardado and SistemaGuardado.has_method("dar_dinero_jugador"):
		SistemaGuardado.dar_dinero_jugador(cantidad)
	elif vendedor_ref and vendedor_ref.has_method("_dar_dinero_jugador"):
		vendedor_ref._dar_dinero_jugador(cantidad)

## ============================================================================
## CANCELACIÓN Y CIERRE
## ============================================================================

func _cancelar_venta():
	print("💰 Venta cancelada, volviendo a la mochila")
	_abrir_mochila_venta()

func _cerrar_venta():
	print("💰 === CERRANDO SISTEMA DE VENTA ===")
	
	venta_activa = false
	objeto_seleccionado.clear()
	precio_venta = 0
	
	# Limpiar referencia a mochila si existe
	if mochila_ref:
		print("💰 Liberando mochila...")
		mochila_ref.queue_free()
		mochila_ref = null
	
	# Realizar transición aclarar si es necesario
	if Singleton.has_method("transicion"):
		print("💰 Realizando transición aclarar...")
		Singleton.transicion("aclarar")
	
	# Emitir señal de cierre
	print("💰 Emitiendo señal venta_cerrada")
	emit_signal("venta_cerrada")

	# Liberar esta instancia para prevenir duplicados al reabrir
	if is_inside_tree():
		print("💰 Liberando instancia vender.gd (queue_free)")
		queue_free()

## ============================================================================
## UTILIDADES Y HELPERS
## ============================================================================

## Realizada la venta, se debe regresar a la selección de objeto de la mochila
func _mostrar_mensaje_exito_y_cerrar(mensaje: String):
	if cuadro_dialogo:
		cuadro_dialogo.mostrar(
			tr(mensaje),
			true,
			true,
			Callable(self, "_continuar_seleccion")
		)
	else:
		_continuar_seleccion()

## Refrescar el listado de la mochila después de la venta (antes de desbloquear input)
## Refrescar completo (fallback) - queda como respaldo si hiciera falta
func _refrescar_mochila_post_venta():
	if not mochila_ref:
		return
	if mochila_ref.has_method("cargar_datos_desde_guardado"):
		mochila_ref.cargar_datos_desde_guardado()
	if mochila_ref.has_method("actualizar_contenido_bolsillo"):
		mochila_ref.actualizar_contenido_bolsillo(false)
	if mochila_ref.has_method("actualizar_posicion_cursor"):
		mochila_ref.actualizar_posicion_cursor()
	if mochila_ref.has_method("actualizar_descripcion"):
		mochila_ref.actualizar_descripcion()

## Actualización incremental del listado sin recargar todos los bolsillos
func _actualizar_mochila_incremental(objeto_id: String, bolsillo_id: int, cantidad_vendida: int):
	if not mochila_ref:
		return
	# Verificar que exista la propiedad bolsillos_datos y sea un Dictionary
	var tiene_propiedad := false
	for p in mochila_ref.get_property_list():
		if p.name == "bolsillos_datos":
			tiene_propiedad = true
			break
	if not tiene_propiedad:
		_refrescar_mochila_post_venta()
		return
	var bolsillos = mochila_ref.bolsillos_datos
	if typeof(bolsillos) != TYPE_DICTIONARY:
		_refrescar_mochila_post_venta()
		return
	if not bolsillos.has(bolsillo_id):
		_refrescar_mochila_post_venta()
		return
	var bolsillo_data = bolsillos[bolsillo_id]
	if bolsillo_data == null or not bolsillo_data.has("items"):
		_refrescar_mochila_post_venta()
		return
	var lista_items = bolsillo_data.items
	if typeof(lista_items) != TYPE_ARRAY:
		_refrescar_mochila_post_venta()
		return

	var index_objetivo := -1
	for i in range(lista_items.size()):
		var it = lista_items[i]
		if typeof(it) == TYPE_DICTIONARY and it.has("nombre_interno") and it.nombre_interno == objeto_id:
			index_objetivo = i
			break
	if index_objetivo == -1:
		# No se encontró el item esperado en la estructura actual -> fallback completo
		_refrescar_mochila_post_venta()
		return

	# Ajustar cantidad apoyándonos en el dato ya descontado del SistemaGuardado
	var item_ref = lista_items[index_objetivo]
	var cantidad_restante := -1
	if SistemaGuardado and SistemaGuardado.has_method("get_cantidad_objeto"):
		# Si existe un método directo para obtener la cantidad, usarlo (robusto ante desincronizaciones)
		cantidad_restante = SistemaGuardado.get_cantidad_objeto(objeto_id, bolsillo_id)
	if cantidad_restante >= 0:
		# Modo robusto: sobrescribir con la cantidad real del sistema de guardado
		if cantidad_restante <= 0:
			lista_items.remove_at(index_objetivo)
		else:
			item_ref.cantidad = cantidad_restante
	else:
		# Fallback: ajustar restando lo vendido sobre el valor local
		if item_ref.has("cantidad"):
			item_ref.cantidad -= cantidad_vendida
			if item_ref.cantidad <= 0:
				lista_items.remove_at(index_objetivo)

	# Refrescar solo el bolsillo visible
	if mochila_ref.has_method("actualizar_contenido_bolsillo"):
		mochila_ref.actualizar_contenido_bolsillo(false)
	if mochila_ref.has_method("actualizar_posicion_cursor"):
		mochila_ref.actualizar_posicion_cursor()
	if mochila_ref.has_method("actualizar_descripcion"):
		mochila_ref.actualizar_descripcion()

func _mostrar_mensaje_error(mensaje: String):
	if cuadro_dialogo:
		cuadro_dialogo.mostrar(
			tr(mensaje),
			true,
			true,
			Callable(self, "_continuar_seleccion")
		)
	else:
		_continuar_seleccion()

func _continuar_seleccion():
	print("💰 === _continuar_seleccion() EJECUTÁNDOSE ===")
	# Actualizar inventario visible antes de permitir nueva selección
	# _refrescar_mochila_post_venta()
	# Aquí ya terminó el diálogo final: desbloquear mochila para seguir vendiendo o cerrar
	cuadro_dinero.visible = false
	if mochila_ref and mochila_ref.has_method("bloquear_input"):
		mochila_ref.bloquear_input(false)
		print("💰 🔓 Input de mochila desbloqueado tras diálogo final")
	print("💰 === _continuar_seleccion() COMPLETADO ===")

# Eliminado el sistema de cooldown; el bloqueo se maneja explícitamente

func _on_dialogo_texto_completado():
	# Mantener función por compatibilidad si alguna conexión antigua existe
	pass

func _volver_al_vendedor():
	_cerrar_venta()

## ============================================================================
## VALIDACIÓN Y MENSAJES DE VENTA
## ============================================================================

func _puede_venderse_objeto(objeto_datos: Dictionary) -> bool:
	# Obtener bolsillo desde la mochila
	var bolsillo_actual = 0
	if mochila_ref and mochila_ref.has_method("get_bolsillo_actual"):
		bolsillo_actual = mochila_ref.get_bolsillo_actual()
	else:
		# Intentar determinar por el nombre interno
		var nombre_interno = objeto_datos.get("nombre_interno", "")
		if "MO" in nombre_interno:
			return false  # Las MOs no se pueden vender
		if objeto_datos.get("bolsillo_id", 0) == 4:
			return false  # Objetos clave no se pueden vender
	
	# No se pueden vender objetos clave (bolsillo 4)
	if bolsillo_actual == 4:
		return false
	
	# No se pueden vender MOs
	var nombre = objeto_datos.get("nombre", "")
	if nombre.begins_with("MO"):
		return false
	
	# No se pueden vender objetos especiales
	var objetos_no_vendibles = [
		"CERRAR LA MOCHILA",
		"CANCELAR VENTA"
	]
	
	if nombre in objetos_no_vendibles:
		return false
	
	# Verificar que tenga cantidad > 0
	var cantidad = objeto_datos.get("cantidad", 0)
	if cantidad <= 0:
		return false
	
	return true

func _mostrar_mensaje_no_vendible(objeto_datos: Dictionary):
	var nombre = objeto_datos.get("nombre", "OBJETO")
	var mensaje = "¿%s? No, lo siento.\\lNo puedo comprar eso." % nombre
	
	print("💰 Objeto no vendible: %s" % nombre)
	print("💰 Preparando callback para _continuar_seleccion")
	
	# Mostrar mensaje que espera input y se cierra
	if cuadro_dialogo == null:
		cuadro_dialogo = Singleton.get_cuadro_dialogo()
	if cuadro_dialogo:
		print("💰 Mostrando diálogo con callback")
		
		# Conectar a la señal texto_completado para activar cooldown cuando se cierre
		if not cuadro_dialogo.is_connected("texto_completado", _on_dialogo_texto_completado):
			cuadro_dialogo.connect("texto_completado", _on_dialogo_texto_completado, CONNECT_ONE_SHOT)
			print("💰 ✅ Conectado a señal texto_completado")
		
		cuadro_dialogo.mostrar(
			tr(mensaje),
			true,   # Esperar input
			true,   # Cerrar automáticamente
			Callable(self, "_continuar_seleccion")  # Callback cuando termine
		)
	else:
		print("💰 No hay cuadro_dialogo, ejecutando _continuar_seleccion directamente")
		_continuar_seleccion()

func _mostrar_mensaje_vendible(objeto_datos: Dictionary):
	var nombre = objeto_datos.get("nombre", "OBJETO")
	var mensaje = "¿%s?\\l¿Cuántas unidades quieres vender?" % nombre
	
	print("💰 Confirmando venta de: %s" % nombre)
	
	# Mostrar mensaje que NO espera input y NO se cierra
	if cuadro_dialogo == null:
		cuadro_dialogo = Singleton.get_cuadro_dialogo()
	if cuadro_dialogo:
		cuadro_dialogo.mostrar(
			tr(mensaje),
			false,  # NO esperar input
			false,  # NO cerrar automáticamente
			Callable(self, "_activar_seleccion_cantidad")  # Callback cuando termine el texto
		)
	else:
		_activar_seleccion_cantidad()

## ============================================================================
## DEBUG Y LOGGING
## ============================================================================

func _loggear(mensaje: String):
	print("[VENDER] %s" % mensaje)

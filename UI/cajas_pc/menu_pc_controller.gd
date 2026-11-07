class_name MenuPCController
extends Control

## Descripción:
##
## Controlador simplificado para la escena menu_pc.
## Maneja NinePatchRect pre-existentes en la escena para mensajes y opciones.

# ===================================
# SEÑALES
# ===================================

signal opcion_seleccionada(opcion: String, contexto: Dictionary)
## Respuesta de la ventana SÍ/NO (B cuenta como NO).
signal confirmacion_respondida(si: bool)
## Caja elegida en la ventana "¿Dejar en qué CAJA?"; -1 si se canceló con B.
signal caja_elegida(indice: int)

const OPCION_DEJAR_POKEMON: String = "DEJAR"
## pokeruby TOTAL_BOXES_COUNT (= SistemaGuardado.TOTAL_CAJAS_PC).
const TOTAL_CAJAS_SELECTOR: int = 14
## Ventana de elección de caja (pokeruby sub_80963D0, pantalla de 240x160):
## centro de 64x64 en (160,96) y laterales en x=124/196; flechas animadas en
## x=124 y x=196, y=88.
const MARCO_SELECTOR_CAJA: Rect2 = Rect2(116, 64, 88, 56)
const CENTRO_FLECHA_IZQUIERDA: Vector2 = Vector2(124, 88)
const CENTRO_FLECHA_DERECHA: Vector2 = Vector2(196, 88)

# ===================================
# REFERENCIAS A NODOS (deben existir en la escena)
# ===================================

@onready var ventana_mensaje: NinePatchRect = $CuMensaje
@onready var label_mensaje: Label = $CuMensaje/mensaje
@onready var ventana_opciones: NinePatchRect = $CuOpciones
@onready var cursor_opciones: PkSelectorSimple = $CuOpciones/cursor1
@onready var ventana_confirmacion: NinePatchRect = $CuSiNo
@onready var cursor_confirmacion: PkSelectorSimple = $CuSiNo/cursor2

# ===================================
# VARIABLES
# ===================================

# Estado del menú de opciones
var menu_activo: bool = false
var opciones_actuales: Array[String] = []
var labels_opciones: Array[Label] = []
var indice_seleccionado: int = 0
var contexto_actual: Dictionary = {}
## 0 sacar, 1 dejar, 2 organizar (interfaz completa existente).
var operacion_almacenamiento: int = 2

# Estado de la ventana SÍ/NO (CuSiNo)
var confirmacion_activa: bool = false
var indice_confirmacion: int = 0  # 0 = SÍ, 1 = NO

# Estado de la ventana de elección de caja
var selector_caja_activo: bool = false
var caja_selector: int = 0
var nombres_cajas_selector: Array[String] = []
var conteos_cajas_selector: Array[int] = []
var ventana_selector_caja: NinePatchRect = null
var label_nombre_selector: Label = null
var label_conteo_selector: Label = null
var flecha_selector_izquierda: AnimatedSprite2D = null
var flecha_selector_derecha: AnimatedSprite2D = null

# Referencias a recursos
var menu_box_manager = preload("res://scripts/clases/MenuBoxManager.gd")

func _ready() -> void:
	# Asegurar que las ventanas están configuradas correctamente
	_configurar_ventanas()

	# Guardar labels opciones
	for etiqueta in ventana_opciones.get_children():
		if etiqueta is Label:
			labels_opciones.append(etiqueta)

	_crear_selector_caja()

	# Inicializar estado
	_ocultar_menu_opciones()

func _input(event: InputEvent) -> void:
	# Las ventanas de este menú consumen su input para que la pantalla de
	# cajas (nodo padre) no procese también la misma pulsación.
	if menu_activo:
		if _manejar_input_menu_opciones(event):
			get_viewport().set_input_as_handled()
	elif confirmacion_activa:
		if _manejar_input_confirmacion(event):
			get_viewport().set_input_as_handled()
	elif selector_caja_activo:
		if _manejar_input_selector_caja(event):
			get_viewport().set_input_as_handled()

# ===================================
# API PÚBLICA - VENTANA DE MENSAJE
# ===================================

## Muestra un mensaje en la ventana inferior
func mostrar_mensaje(mensaje: String) -> void:
	if label_mensaje:
		label_mensaje.text = mensaje
	if ventana_mensaje:
		ventana_mensaje.visible = true

## Oculta la ventana de mensaje
func ocultar_mensaje() -> void:
	if ventana_mensaje:
		ventana_mensaje.visible = false

# ===================================
# API PÚBLICA - MENÚ DE OPCIONES
# ===================================

## Muestra un menú de opciones para Pokémon
func mostrar_opciones_pokemon(nombre: String, del_equipo: bool, el_primero: bool, tiene_pokemon: bool) -> void:
	var opciones = _construir_opciones_pokemon(del_equipo, el_primero, tiene_pokemon)
	var mensaje = nombre + " seleccionado."
	mostrar_mensaje(mensaje)
	_mostrar_menu_opciones(opciones)

## Primera opción del menú de un Pokémon (la que ejecuta A en movimiento rápido).
func primera_opcion_pokemon(del_equipo: bool, el_primero: bool, tiene_pokemon: bool) -> String:
	return _construir_opciones_pokemon(del_equipo, el_primero, tiene_pokemon)[0]

## Muestra un menú de opciones para la caja
func mostrar_opciones_caja(caja_index: int) -> void:
	var opciones = _construir_opciones_caja(caja_index)
	var contexto = {
		"tipo": "caja",
		"caja_index": caja_index
	}
	_mostrar_menu_opciones(opciones)

## Cierra el menú de opciones
func cerrar_menu_opciones() -> void:
	_ocultar_menu_opciones()
	menu_activo = false
	opciones_actuales.clear()
	indice_seleccionado = 0

# ===================================
# API PÚBLICA - UTILIDADES
# ===================================

## Verifica si hay un menú activo (opciones, SÍ/NO o elección de caja)
func hay_menu_activo() -> bool:
	return menu_activo or confirmacion_activa or selector_caja_activo

# ===================================
# API PÚBLICA - VENTANA SÍ/NO
# ===================================

## Muestra `mensaje` en la ventana inferior con la ventana SÍ/NO; la respuesta
## llega por `confirmacion_respondida` (B equivale a NO).
func mostrar_confirmacion(mensaje: String, si_por_defecto: bool = true) -> void:
	cerrar_menu_opciones()
	mostrar_mensaje(mensaje)
	indice_confirmacion = 0 if si_por_defecto else 1
	confirmacion_activa = true
	if ventana_confirmacion:
		ventana_confirmacion.visible = true
	_actualizar_cursor_confirmacion()

## Cierra la ventana SÍ/NO y emite la respuesta.
func responder_confirmacion(si: bool) -> void:
	if not confirmacion_activa:
		return
	confirmacion_activa = false
	if ventana_confirmacion:
		ventana_confirmacion.visible = false
	ocultar_mensaje()
	confirmacion_respondida.emit(si)

# ===================================
# API PÚBLICA - ELECCIÓN DE CAJA ("¿Dejar en qué CAJA?")
# ===================================

## Muestra la ventana de elección de caja empezando en `caja_inicial`.
## `nombres` y `conteos` describen las 14 cajas. ←/→ cambian de caja dando la
## vuelta, A elige y B cancela (pokeruby sub_8096368); la respuesta llega por
## `caja_elegida`.
func mostrar_selector_caja(caja_inicial: int, nombres: Array[String], conteos: Array[int]) -> void:
	cerrar_menu_opciones()
	nombres_cajas_selector = nombres
	conteos_cajas_selector = conteos
	caja_selector = posmod(caja_inicial, TOTAL_CAJAS_SELECTOR)
	selector_caja_activo = true
	if ventana_selector_caja:
		ventana_selector_caja.visible = true
		flecha_selector_izquierda.play()
		flecha_selector_derecha.play()
	_actualizar_selector_caja()

## Cambia la caja mostrada en la ventana (-1 izquierda, +1 derecha).
func mover_selector_caja(direccion: int) -> void:
	if not selector_caja_activo:
		return
	caja_selector = posmod(caja_selector + direccion, TOTAL_CAJAS_SELECTOR)
	Singleton.play_sound.emit("SE_SELECT")
	_actualizar_selector_caja()

## A sobre la ventana: emite la caja mostrada. La ventana sigue visible (pero
## inactiva) para que, si la caja está llena, el aviso aparezca con ella.
func elegir_caja_selector() -> void:
	if not selector_caja_activo:
		return
	selector_caja_activo = false
	Singleton.play_sound.emit("SE_SELECT")
	caja_elegida.emit(caja_selector)

## B sobre la ventana: la cierra y emite -1.
func cancelar_selector_caja() -> void:
	if not selector_caja_activo:
		return
	Singleton.play_sound.emit("SE_SELECT")
	ocultar_selector_caja()
	caja_elegida.emit(-1)

## Vuelve a activar la ventana tras un aviso ("La CAJA está llena.").
func reactivar_selector_caja() -> void:
	if ventana_selector_caja and ventana_selector_caja.visible:
		selector_caja_activo = true
		_actualizar_selector_caja()

## Oculta la ventana de elección de caja.
func ocultar_selector_caja() -> void:
	selector_caja_activo = false
	if ventana_selector_caja:
		ventana_selector_caja.visible = false
		flecha_selector_izquierda.stop()
		flecha_selector_derecha.stop()

## Indica si la ventana de elección de caja está en pantalla (activa o no).
func selector_caja_visible() -> bool:
	return ventana_selector_caja != null and ventana_selector_caja.visible

## Oculta todos los elementos del menú
func ocultar_todo() -> void:
	ocultar_mensaje()
	cerrar_menu_opciones()
	confirmacion_activa = false
	ocultar_selector_caja()

## Muestra solo el mensaje (estado inicial)
func mostrar_solo_mensaje(mensaje: String = "Selecciona un POKéMON.") -> void:
	print("📋 [CAJAS PC] Mostrando solo mensaje: %s" % mensaje)
	cerrar_menu_opciones()
	mostrar_mensaje(mensaje)

# ===================================
# IMPLEMENTACIÓN INTERNA
# ===================================

## Configura las texturas dinámicas de las ventanas
func _configurar_ventanas() -> void:
	var image_type = _obtener_tipo_imagen_actual()

	# Configurar ventana de mensaje
	if ventana_mensaje:
		menu_box_manager.apply_texture_to_ninepatch(ventana_mensaje, image_type)

	# Configurar ventana de opciones
	if ventana_opciones:
		menu_box_manager.apply_texture_to_ninepatch(ventana_opciones, image_type)

	# Configurar ventana SÍ/NO
	if ventana_confirmacion:
		menu_box_manager.apply_texture_to_ninepatch(ventana_confirmacion, image_type)

## Muestra el menú de opciones con las opciones proporcionadas
func _mostrar_menu_opciones(opciones: Array[String]) -> void:
	# Guardar estado
	opciones_actuales = opciones
	indice_seleccionado = 0
	menu_activo = true

	# Actualizar labels
	_actualizar_opciones_labels()

	# Mostrar ventana y cursor
	if ventana_opciones:
		ventana_opciones.visible = true
	_actualizar_posicion_cursor()

## Oculta el menú de opciones
func _ocultar_menu_opciones() -> void:
	if ventana_opciones:
		ventana_opciones.visible = false
	if ventana_mensaje:
		ventana_mensaje.visible = false
	if ventana_confirmacion:
		ventana_confirmacion.visible = false

## Actualiza los labels de las opciones en el menú
func _actualizar_opciones_labels() -> void:
	if not ventana_opciones:
		return

	# Limpiar labels anteriores
	for label in labels_opciones:
		label.text = ""

	# Actualizar con nuevas opciones
	for i in range(min(opciones_actuales.size(), labels_opciones.size())):
		labels_opciones[i].text = opciones_actuales[i]

## Actualiza la posición del cursor según la opción seleccionada
func _actualizar_posicion_cursor() -> void:
	if cursor_opciones and menu_activo:
		cursor_opciones.position.y = 7 + (indice_seleccionado * 16)
		cursor_opciones.visible = true
	elif cursor_opciones:
		cursor_opciones.visible = false

# ===================================
# LÓGICA DE INPUT PARA MENÚS
# ===================================

## Devuelve true si el evento se usó (para consumirlo).
func _manejar_input_menu_opciones(event: InputEvent) -> bool:
	if event.is_action_pressed("btn_arriba"):
		_mover_cursor_arriba()
	elif event.is_action_pressed("btn_abajo"):
		_mover_cursor_abajo()
	elif event.is_action_pressed("btn_accion"):
		_ejecutar_opcion_seleccionada()
	elif event.is_action_pressed("btn_cancelar"):
		cerrar_menu_opciones()
		opcion_seleccionada.emit("SALIR", contexto_actual)
	else:
		return false
	return true

## ↑/↓ alternan SÍ/NO, A confirma la opción marcada y B responde NO.
func _manejar_input_confirmacion(event: InputEvent) -> bool:
	if event.is_action_pressed("btn_arriba") or event.is_action_pressed("btn_abajo"):
		indice_confirmacion = 1 - indice_confirmacion
		_actualizar_cursor_confirmacion()
	elif event.is_action_pressed("btn_accion"):
		responder_confirmacion(indice_confirmacion == 0)
	elif event.is_action_pressed("btn_cancelar"):
		responder_confirmacion(false)
	else:
		return false
	return true

func _actualizar_cursor_confirmacion() -> void:
	if cursor_confirmacion:
		cursor_confirmacion.position.y = 7 + (indice_confirmacion * 16)
		cursor_confirmacion.visible = true

func _manejar_input_selector_caja(event: InputEvent) -> bool:
	if event.is_action_pressed("btn_cancelar"):
		cancelar_selector_caja()
	elif event.is_action_pressed("btn_accion"):
		elegir_caja_selector()
	elif event.is_action_pressed("btn_izquierda"):
		mover_selector_caja(-1)
	elif event.is_action_pressed("btn_derecha"):
		mover_selector_caja(1)
	elif event.is_action_pressed("btn_arriba") or event.is_action_pressed("btn_abajo"):
		pass  # Sin efecto, pero no debe llegar a la pantalla de cajas.
	else:
		return false
	return true

## Crea la ventana de elección de caja reutilizando el marco de menús, la
## fuente de 15 px y las flechas animadas de la cabecera de la caja.
func _crear_selector_caja() -> void:
	ventana_selector_caja = NinePatchRect.new()
	ventana_selector_caja.name = "CuSelectorCaja"
	ventana_selector_caja.position = MARCO_SELECTOR_CAJA.position
	ventana_selector_caja.size = MARCO_SELECTOR_CAJA.size
	ventana_selector_caja.patch_margin_left = 8
	ventana_selector_caja.patch_margin_top = 8
	ventana_selector_caja.patch_margin_right = 8
	ventana_selector_caja.patch_margin_bottom = 8
	ventana_selector_caja.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	ventana_selector_caja.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	ventana_selector_caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ventana_selector_caja.visible = false
	menu_box_manager.apply_texture_to_ninepatch(ventana_selector_caja, _obtener_tipo_imagen_actual())
	add_child(ventana_selector_caja)

	var ajustes: LabelSettings = preload("res://UI/texto_normal_negro.tres")
	label_nombre_selector = _crear_label_selector(ajustes, 6)
	label_conteo_selector = _crear_label_selector(ajustes, 22)

	flecha_selector_izquierda = _crear_flecha_selector(preload("res://UI/cajas_pc/pc-flecha-izquierda.png"), CENTRO_FLECHA_IZQUIERDA)
	flecha_selector_derecha = _crear_flecha_selector(preload("res://UI/cajas_pc/pc-flecha-derecha.png"), CENTRO_FLECHA_DERECHA)

func _crear_label_selector(ajustes: LabelSettings, y: float) -> Label:
	var etiqueta := Label.new()
	etiqueta.label_settings = ajustes
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.position = Vector2(16, y)
	etiqueta.size = Vector2(MARCO_SELECTOR_CAJA.size.x - 32, 16)
	etiqueta.clip_text = true
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ventana_selector_caja.add_child(etiqueta)
	return etiqueta

## Flecha de 16x16 animada como las de la cabecera (hoja de 8 frames, 18 fps).
func _crear_flecha_selector(hoja: Texture2D, centro: Vector2) -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	frames.set_animation_loop(&"default", true)
	frames.set_animation_speed(&"default", 18.0)
	for i in 8:
		var cuadro := AtlasTexture.new()
		cuadro.atlas = hoja
		cuadro.region = Rect2(i * 16, 0, 16, 16)
		frames.add_frame(&"default", cuadro)
	var flecha := AnimatedSprite2D.new()
	flecha.sprite_frames = frames
	flecha.centered = false
	flecha.position = centro - MARCO_SELECTOR_CAJA.position - Vector2(8, 8)
	ventana_selector_caja.add_child(flecha)
	return flecha

## Nombre de la caja y "n/30" (pokeruby sub_809665C).
func _actualizar_selector_caja() -> void:
	if not label_nombre_selector:
		return
	var nombre: String = nombres_cajas_selector[caja_selector] if caja_selector < nombres_cajas_selector.size() else "CAJA %d" % (caja_selector + 1)
	var conteo: int = conteos_cajas_selector[caja_selector] if caja_selector < conteos_cajas_selector.size() else 0
	label_nombre_selector.text = nombre
	label_conteo_selector.text = "%d/30" % conteo

func _mover_cursor_arriba() -> void:
	if opciones_actuales.size() > 0:
		indice_seleccionado = (indice_seleccionado - 1 + opciones_actuales.size()) % opciones_actuales.size()
		_actualizar_posicion_cursor()

func _mover_cursor_abajo() -> void:
	if opciones_actuales.size() > 0:
		indice_seleccionado = (indice_seleccionado + 1) % opciones_actuales.size()
		_actualizar_posicion_cursor()

func _ejecutar_opcion_seleccionada() -> void:
	if indice_seleccionado < opciones_actuales.size():
		var opcion = opciones_actuales[indice_seleccionado]
		cerrar_menu_opciones()
		opcion_seleccionada.emit(opcion, contexto_actual)

# ===================================
# CONSTRUCCIÓN DE OPCIONES
# ===================================

func _construir_opciones_pokemon(del_equipo: bool, el_primero: bool, tiene_pokemon: bool) -> Array[String]:
	var opciones: Array[String] = []
	if operacion_almacenamiento != 2:
		if (operacion_almacenamiento == 1) == del_equipo:
			opciones.append(OPCION_DEJAR_POKEMON if del_equipo else "SACAR")
		opciones.append("DATOS")
		opciones.append("SALIR")
		return opciones

	if el_primero:	# Si es el primer Pokémon que se selecciona
		opciones.append("MOVER")
	else:
		if tiene_pokemon:
			opciones.append("CAMBIO")
		else:
			opciones.append("COLOCAR")

	opciones.append("DATOS")

	# Si se seleccionó un Pokémon del equipo, permitir dejarlo
	# Si se seleccionó un Pokémon de la caja, permitir sacarlo
	if del_equipo:
		opciones.append(OPCION_DEJAR_POKEMON)
	else:
		opciones.append("SACAR")

	opciones.append("MARCAR")
	opciones.append("SOLTAR")
	opciones.append("SALIR")

	return opciones

func _construir_opciones_caja(_caja_index: int) -> Array[String]:
	var opciones: Array[String] = []

	opciones.append("CAMBIAR NOMBRE")
	opciones.append("CAMBIAR FONDO")
	opciones.append("ORGANIZAR")
	opciones.append("BUSCAR POKéMON")
	opciones.append("CANCELAR")

	return opciones

# ===================================
# UTILIDADES
# ===================================

func _obtener_tipo_imagen_actual() -> int:
	var sg = get_tree().root.get_node_or_null("SistemaGuardado")
	if sg and sg.datos_vivos and sg.datos_vivos.opciones:
		return int(sg.datos_vivos.opciones.imagen_tipo)
	return 1

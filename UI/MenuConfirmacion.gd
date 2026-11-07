## Menú de confirmación SI/NO para diálogos
## Componente independiente que maneja la lógica de menús de confirmación

extends Control
class_name MenuConfirmacion

signal opcion_seleccionada(respuesta: String)  # "Y" o "N"

## Vacío conserva cancelar = última opción. Un multichoice como el ascensor
## puede pedir un resultado separado (case 127), sin agregar una opción SALIR.
var respuesta_cancelar: String = ""

var menu_activo: bool = false
var opcion_actual: int = 0  # 0 = SI, 1 = NO
## Opción donde empieza el cursor en el próximo `crear_menu` (p. ej. SALIR en un
## multichoice). Se consume y vuelve a 0 al crear el menú.
var indice_inicial: int = 0
## El próximo `crear_menu` ignora `posicion` y pone el menú en la esquina superior
## izquierda de la pantalla (`multichoice 0, 0, …`). Se consume al crear el menú.
var en_esquina: bool = false
var input_bloqueado: bool = false

var menu_node: NinePatchRect = null
var etiqueta_si: Label = null
var etiqueta_no: Label = null
var cursor_menu: PkSelectorSimple = null
## Etiquetas en orden (SÍ, NO y, en un multichoice de más de dos, las siguientes).
var _etiquetas: Array[Label] = []

const FUENTE := preload("res://fuentes/pokemon-rs.ttf")
const LABEL_SETTINGS := preload("res://UI/texto_normal_negro.tres")

const ANCHO_MINIMO: float = 56.0
const ALTO_FILA: float = 16.0
## Hueco mínimo entre la descripción y el precio de una opción «descripción|precio».
const SEPARACION_COLUMNAS: float = 6.0

var _menu_box_manager = preload("res://scripts/clases/MenuBoxManager.gd")

## `etiquetas`: las opciones (multichoice, p. ej. AZULIZA / SALIR). Si no caben, el menú
## se ensancha hacia la izquierda; con más de dos crece hacia arriba. Con dos responde
## "Y" / "N"; con más, el índice elegido ("0", "1"…; cancelar = la última).
func crear_menu(posicion: Vector2 = Vector2(160, 64), etiquetas: PackedStringArray = PackedStringArray(["SÍ", "NO"])) -> void:
	"""Crea y muestra el menú de confirmación"""
	if menu_activo:
		print("⚠️ [MENU CONFIRM] Menú ya activo, ignorando")
		return
		
	print("📋 [MENU CONFIRM] Creando menú de confirmación")
	menu_activo = true
	input_bloqueado = true
	opcion_actual = clampi(indice_inicial, 0, maxi(etiquetas.size() - 1, 0))
	indice_inicial = 0

	# Crear panel principal
	menu_node = NinePatchRect.new()
	
	# Aplicar textura según opciones guardadas
	var img_type_local = _get_saved_image_type()
	_menu_box_manager.apply_texture_to_ninepatch(menu_node, img_type_local)
	
	menu_node.patch_margin_left = 8
	menu_node.patch_margin_top = 8
	menu_node.patch_margin_right = 8
	menu_node.patch_margin_bottom = 8
	# Configurar Axis Stretch en Tile (horizontal y vertical)
	menu_node.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	menu_node.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	# Una opción «descripción|precio» se dibuja en dos columnas: la segunda, a la derecha.
	var izquierdas := PackedStringArray()
	var derechas := PackedStringArray()
	var ancho := ANCHO_MINIMO
	var max_izq := 0.0
	var max_der := 0.0
	for etiqueta in etiquetas:
		var partes := etiqueta.split("|", true, 1)
		izquierdas.append(partes[0])
		derechas.append(partes[1] if partes.size() > 1 else "")
		var tam_izq := _ancho_texto(partes[0])
		if partes.size() > 1:
			max_izq = maxf(max_izq, tam_izq)
			max_der = maxf(max_der, _ancho_texto(partes[1]))
		else:
			ancho = maxf(ancho, tam_izq + 24.0)
	if max_der > 0.0:
		ancho = maxf(ancho, max_izq + max_der + SEPARACION_COLUMNAS + 24.0)
	var filas_extra := maxi(etiquetas.size() - 2, 0)
	menu_node.position = posicion - Vector2(ancho - ANCHO_MINIMO, ALTO_FILA * filas_extra)
	menu_node.size = Vector2(ancho, 48 + ALTO_FILA * filas_extra)

	# Crear etiquetas
	etiqueta_si = Label.new()
	etiqueta_si.text = izquierdas[0]
	etiqueta_si.label_settings = LABEL_SETTINGS
	etiqueta_si.position = Vector2(8, 8)
	menu_node.add_child(etiqueta_si)
	_anadir_columna_derecha(derechas[0], etiqueta_si.position.y, ancho)

	etiqueta_no = Label.new()
	etiqueta_no.text = izquierdas[1]
	etiqueta_no.label_settings = LABEL_SETTINGS
	etiqueta_no.position = Vector2(8, 24)
	menu_node.add_child(etiqueta_no)
	_anadir_columna_derecha(derechas[1], etiqueta_no.position.y, ancho)
	_etiquetas = [etiqueta_si, etiqueta_no]
	for i in range(2, etiquetas.size()):
		var extra := Label.new()
		extra.text = izquierdas[i]
		extra.label_settings = LABEL_SETTINGS
		extra.position = Vector2(8, 8 + ALTO_FILA * i)
		menu_node.add_child(extra)
		_anadir_columna_derecha(derechas[i], extra.position.y, ancho)
		_etiquetas.append(extra)

	# Crear cursor
	cursor_menu = PkSelectorSimple.new()
	cursor_menu.ancho_borde = 1
	cursor_menu.color = Color(239/255.0, 110/255.0, 96/255.0) # Color ef6960
	cursor_menu.size = Vector2(ancho - 14.0, 17)
	cursor_menu.position = etiqueta_si.position - Vector2(1, 1)
	cursor_menu.parpadeo = false
	menu_node.add_child(cursor_menu)

	# Añadir al árbol
	add_child(menu_node)
	if en_esquina:
		menu_node.global_position = Vector2.ZERO
	en_esquina = false
	
	_actualizar_cursor()
	
	# Desbloquear input después de un delay
	await get_tree().create_timer(0.3).timeout
	input_bloqueado = false
	print("📋 [MENU CONFIRM] Input desbloqueado")

func _ancho_texto(texto: String) -> float:
	return ceilf(LABEL_SETTINGS.font.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SETTINGS.font_size).x)


## Segunda columna de una opción «descripción|precio»: alineada a la derecha del cursor.
func _anadir_columna_derecha(texto: String, y: float, ancho: float) -> void:
	if texto.is_empty():
		return
	var derecha := Label.new()
	derecha.text = texto
	derecha.label_settings = LABEL_SETTINGS
	derecha.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	derecha.position = Vector2(8, y)
	derecha.size = Vector2(ancho - 20.0, ALTO_FILA)
	menu_node.add_child(derecha)


func ocultar_menu() -> void:
	"""Oculta y limpia el menú"""
	print("📋 [MENU CONFIRM] Ocultando menú")
	menu_activo = false
	
	if menu_node != null and menu_node.is_inside_tree():
		remove_child(menu_node)
		menu_node.queue_free()
		menu_node = null
	
	etiqueta_si = null
	etiqueta_no = null
	_etiquetas.clear()
	cursor_menu = null

func _actualizar_cursor() -> void:
	"""Actualiza la posición del cursor según la opción seleccionada"""
	if cursor_menu != null and _etiquetas.size() > 2:
		cursor_menu.position = _etiquetas[opcion_actual].position - Vector2(1, 1)
	elif cursor_menu != null:
		if opcion_actual == 0:
			cursor_menu.position = etiqueta_si.position - Vector2(1, 1)
		else:
			cursor_menu.position = etiqueta_no.position - Vector2(1, 1)

func _confirmar_seleccion() -> void:
	"""Confirma la selección y emite la señal"""
	var respuesta = "Y" if opcion_actual == 0 else "N"
	if _etiquetas.size() > 2:
		respuesta = str(opcion_actual)
	print("📋 [MENU CONFIRM] Selección confirmada: ", respuesta)
	
	ocultar_menu()
	emit_signal("opcion_seleccionada", respuesta)

func _get_saved_image_type() -> int:
	"""Obtiene el tipo de imagen guardado en las opciones"""
	var sg = get_tree().root.get_node_or_null("SistemaGuardado")
	if sg and sg.datos_vivos and sg.datos_vivos.opciones:
		return int(sg.datos_vivos.opciones.imagen_tipo)
	if typeof(SistemaGuardado) != TYPE_NIL and SistemaGuardado.datos_vivos and SistemaGuardado.datos_vivos.opciones:
		return int(SistemaGuardado.datos_vivos.opciones.imagen_tipo)
	return 1

func _input(event: InputEvent) -> void:
	if not menu_activo or input_bloqueado:
		return
		
	if event is InputEventMouseMotion:
		return

	# Navegación del menú
	if Input.is_action_just_pressed("btn_arriba"):
		print("📋 [MENU CONFIRM] Tecla ARRIBA")
		_mover_cursor(maxi(opcion_actual - 1, 0))
	elif Input.is_action_just_pressed("btn_abajo"):
		print("📋 [MENU CONFIRM] Tecla ABAJO")
		_mover_cursor(mini(opcion_actual + 1, _num_opciones() - 1))
	elif Input.is_action_just_pressed("btn_accion"):
		print("📋 [MENU CONFIRM] Tecla ACCION")
		get_viewport().set_input_as_handled()
		_confirmar_seleccion()
	elif Input.is_action_just_pressed("btn_cancelar"):
		print("📋 [MENU CONFIRM] Tecla CANCELAR")
		# La respuesta reanuda al que esperaba en esta misma pulsación: sin consumirla, el
		# jugador la recibiría ya con el control devuelto (B bajo el agua repetiría la pregunta).
		get_viewport().set_input_as_handled()
		if not respuesta_cancelar.is_empty():
			var respuesta := respuesta_cancelar
			ocultar_menu()
			opcion_seleccionada.emit(respuesta)
			return
		# Cancelar = NO (la última opción)
		opcion_actual = _num_opciones() - 1
		_confirmar_seleccion()


## Mueve el cursor y suena SE_SELECT solo si cambia de opción (Menu_ProcessInput de
## pokeruby: sin sonido al chocar con el extremo).
func _mover_cursor(nueva: int) -> void:
	if nueva == opcion_actual:
		return
	opcion_actual = nueva
	Singleton.play_sound.emit("SE_SELECT")
	_actualizar_cursor()


func _num_opciones() -> int:
	return maxi(_etiquetas.size(), 2)

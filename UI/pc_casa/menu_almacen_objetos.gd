extends Control

## ItemStorage_* de player_pc.c (pokeruby ES): título arriba a la izquierda,
## lista a la derecha a toda altura y descripción abajo a la izquierda.
signal cerrado

enum Estado { LISTA, MOCHILA, CANTIDAD, CONFIRMACION, MENSAJE }

const TITULOS: Array[String] = ["SACAR OBJETO", "DEJAR OBJETO", "TIRAR OBJETO"]
## Tirar usa MOCHILA_TIRAR_CUANTOS (texto de la ROM compartido con la mochila).
const PREGUNTA_SACAR: String = "¿Cuántos quieres\nsacar?"
## Menu_DrawStdWindowFrame(0xF, 0, 0x1D, 0x13): 8 filas desde el tile 2.
const RECT_LISTA: Rect2 = Rect2(120, 0, 120, 160)
## Menu_DrawStdWindowFrame(0, 0, 0xB, 3)
const RECT_TITULO: Rect2 = Rect2(0, 0, 96, 32)
## Menu_DrawStdWindowFrame(0, 0xC, 0xE, 0x13); texto en (8, 0x68), 0x68 x 0x30.
const RECT_DESCRIPCION: Rect2 = Rect2(0, 96, 120, 64)
## Menu_DrawStdWindowFrame(6, 8, 13, 11)
const RECT_CANTIDAD: Rect2 = Rect2(48, 64, 64, 32)
## DisplayYesNoMenu(7, 6, 1)
const POS_SI_NO: Vector2 = Vector2(56, 48)
const FILAS: int = 8
const Y_PRIMERA_FILA: int = 16
## ItemStorage_DrawItemQuantity: "×" en el tile 26 y 3 cifras alineadas a la derecha.
const X_POR: int = 90
## CreateVerticalScrollIndicators(TOP_ARROW, 0xB8, 8) / (BOTTOM_ARROW, 0xB8, 0x98).
const POS_FLECHA_ARRIBA: Vector2 = Vector2(176, 0)
const POS_FLECHA_ABAJO: Vector2 = Vector2(176, 144)
const TEXTO: LabelSettings = preload("res://UI/texto_normal_negro.tres")

var estado: Estado = Estado.LISTA
var operacion: int = 0 # Sacar, dejar, tirar.
var indice: int = 0
var desplazamiento: int = 0
var cantidad: int = 1
var maximo: int = 1
var mover_desde: int = -1
var elegido: Dictionary = {}
var dialogo: NinePatchRect
var marco: NinePatchRect
var titulo: NinePatchRect
var descripcion: NinePatchRect
var etiqueta_descripcion: Label
var ventana_cantidad: NinePatchRect
var etiqueta_cantidad: Label
var etiquetas: Array[Label] = []
var signos: Array[Label] = []
var cantidades: Array[Label] = []
var cursor: PkSelectorSimple
var flecha_arriba: AnimatedSprite2D
var flecha_abajo: AnimatedSprite2D
var mochila: MochilaUI
var esperar_soltar: bool = true
## PlayerPC_ItemStorage vuelve al primer apartado si no había objetos.
var volver_al_inicio: bool = false
var _cerrar_tras_mensaje: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	marco = _crear_marco(RECT_LISTA)
	titulo = _crear_marco(RECT_TITULO)
	titulo.add_child(_crear_etiqueta(Vector2(8, 8), TITULOS[operacion]))
	descripcion = _crear_marco(RECT_DESCRIPCION)
	etiqueta_descripcion = _crear_etiqueta(Vector2(8, 8))
	etiqueta_descripcion.size = Vector2(104, 48)
	etiqueta_descripcion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta_descripcion.max_lines_visible = 3
	descripcion.add_child(etiqueta_descripcion)
	for i in range(FILAS):
		var y: float = Y_PRIMERA_FILA + 16 * i
		var etiqueta := _crear_etiqueta(Vector2(8, y))
		marco.add_child(etiqueta)
		etiquetas.append(etiqueta)
		var signo := _crear_etiqueta(Vector2(X_POR, y))
		marco.add_child(signo)
		signos.append(signo)
		var cifras := _crear_etiqueta(Vector2(X_POR + 4, y))
		cifras.size = Vector2(RECT_LISTA.size.x - 8 - (X_POR + 4), 16)
		cifras.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		marco.add_child(cifras)
		cantidades.append(cifras)
	cursor = PkSelectorSimple.new()
	cursor.size = Vector2(RECT_LISTA.size.x - 14, 17)
	cursor.color = Color(0.937255, 0.431373, 0.376471, 1)
	cursor.ancho_borde = 1
	marco.add_child(cursor)
	flecha_arriba = _crear_flecha(preload("res://UI/mochila/flecha-arriba.png"), POS_FLECHA_ARRIBA)
	flecha_abajo = _crear_flecha(preload("res://UI/mochila/flecha-abajo.png"), POS_FLECHA_ABAJO)
	if operacion == 1:
		_abrir_mochila()
	elif AlmacenObjetosPC.objetos().is_empty():
		# ItemStorage_Withdraw/Toss: gOtherText_NoItems en el cuadro de campo.
		volver_al_inicio = true
		_cerrar_tras_mensaje = true
		_mostrar_cajas(false)
		estado = Estado.MENSAJE
		dialogo.mostrar_inmediatamente("No hay objetos.")
	else:
		dialogo.cerrar()
		_lista()


func _crear_marco(rect: Rect2) -> NinePatchRect:
	var caja := NinePatchRect.new()
	caja.position = rect.position
	caja.size = rect.size
	caja.patch_margin_left = 8
	caja.patch_margin_right = 8
	caja.patch_margin_top = 8
	caja.patch_margin_bottom = 8
	caja.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	caja.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	MenuBoxManager.apply_texture_to_ninepatch(caja, int(SistemaGuardado.datos_vivos.opciones.imagen_tipo))
	add_child(caja)
	return caja


func _crear_etiqueta(posicion: Vector2, texto: String = "") -> Label:
	var etiqueta := Label.new()
	etiqueta.position = posicion
	etiqueta.label_settings = TEXTO
	etiqueta.text = texto
	return etiqueta


## Flechas animadas de 8 cuadros de 16x16, como en comprar.tscn.
func _crear_flecha(textura: Texture2D, posicion: Vector2) -> AnimatedSprite2D:
	var cuadros := SpriteFrames.new()
	cuadros.set_animation_speed(&"default", 18.0)
	for i in range(8):
		var atlas := AtlasTexture.new()
		atlas.atlas = textura
		atlas.region = Rect2(16 * i, 0, 16, 16)
		cuadros.add_frame(&"default", atlas)
	var flecha := AnimatedSprite2D.new()
	flecha.sprite_frames = cuadros
	flecha.centered = false
	flecha.position = posicion
	flecha.visible = false
	add_child(flecha)
	flecha.play(&"default")
	return flecha


func _mostrar_cajas(visibles: bool) -> void:
	marco.visible = visibles
	titulo.visible = visibles
	descripcion.visible = visibles
	if not visibles:
		flecha_arriba.visible = false
		flecha_abajo.visible = false


## ItemStorage_PrintItemPcResponse: sub_8072AB0 ajusta el texto al ancho de la
## ventana, así que los saltos del texto original no se respetan.
func _texto(mensaje: String) -> void:
	etiqueta_descripcion.text = FormateadorLigaduras.formatear(mensaje.replace("\n", " "))


func _process(_delta: float) -> void:
	if not Input.is_action_pressed("btn_accion") and not Input.is_action_pressed("btn_cancelar"):
		esperar_soltar = false


func _unhandled_input(event: InputEvent) -> void:
	if esperar_soltar or estado == Estado.MOCHILA or estado == Estado.CONFIRMACION or event.is_echo():
		return
	var arriba: bool = event.is_action_pressed("btn_arriba")
	var abajo: bool = event.is_action_pressed("btn_abajo")
	var accion: bool = event.is_action_pressed("btn_accion")
	var cancelar: bool = event.is_action_pressed("btn_cancelar")
	if not (arriba or abajo or accion or cancelar or event.is_action_pressed("btn_select") or event.is_action_pressed("btn_izquierda") or event.is_action_pressed("btn_derecha")):
		return
	get_viewport().set_input_as_handled()
	Singleton.emit_signal("play_sound", "cursor_menu")
	match estado:
		Estado.LISTA:
			if arriba or abajo:
				indice = clampi(indice + (1 if abajo else -1), 0, AlmacenObjetosPC.objetos().size())
				_lista()
			elif cancelar:
				if mover_desde >= 0:
					mover_desde = -1
					_lista()
				else:
					cerrado.emit()
			elif accion or event.is_action_pressed("btn_select"):
				if indice == AlmacenObjetosPC.objetos().size() and mover_desde < 0:
					if event.is_action_pressed("btn_select"):
						return # SALIR no se puede mover.
					cerrado.emit()
				elif mover_desde >= 0:
					AlmacenObjetosPC.intercambiar(mover_desde, indice)
					mover_desde = -1
					_lista()
				elif event.is_action_pressed("btn_select"):
					mover_desde = indice
					_lista()
				else:
					elegido = AlmacenObjetosPC.objetos()[indice].duplicate()
					_elegir_cantidad()
		Estado.CANTIDAD:
			if cancelar:
				_volver()
			elif accion:
				_confirmar_cantidad()
			else:
				var direccion := Vector2i.ZERO
				if arriba:
					direccion = Vector2i.UP
				elif abajo:
					direccion = Vector2i.DOWN
				elif event.is_action_pressed("btn_izquierda"):
					direccion = Vector2i.LEFT
				elif event.is_action_pressed("btn_derecha"):
					direccion = Vector2i.RIGHT
				cantidad = MochilaUI.rodar_cantidad(cantidad, maximo, direccion)
				_mostrar_cantidad()
		Estado.MENSAJE:
			if accion or cancelar:
				if _cerrar_tras_mensaje:
					cerrado.emit()
				else:
					_volver()


func _lista() -> void:
	estado = Estado.LISTA
	_ocultar_ventana_cantidad()
	_mostrar_cajas(true)
	var items: Array = AlmacenObjetosPC.objetos()
	indice = clampi(indice, 0, items.size())
	desplazamiento = clampi(desplazamiento, maxi(0, indice - (FILAS - 1)), indice)
	cursor.visible = true
	cursor.position = Vector2(7, Y_PRIMERA_FILA - 1 + (indice - desplazamiento) * 16)
	cursor.parpadeo = mover_desde >= 0
	for i in etiquetas.size():
		var fila: int = desplazamiento + i
		signos[i].text = ""
		cantidades[i].text = ""
		if fila < items.size():
			etiquetas[i].text = ObjetosLlevados.nombre_objeto(items[fila].nombre_interno)
			# Las MO no llevan cantidad (ItemStorage_DrawTMHMEntry).
			if not ObjetosLlevados.es_mo({"nombre_interno": items[fila].nombre_interno}):
				signos[i].text = "×"
				cantidades[i].text = str(int(items[fila].cantidad))
		else:
			etiquetas[i].text = "SALIR" if fila == items.size() else ""
	# La fila SALIR también cuenta para la flecha inferior.
	flecha_arriba.visible = desplazamiento > 0
	flecha_abajo.visible = desplazamiento + FILAS <= items.size()
	if mover_desde >= 0:
		_texto(tr("MOCHILA_CAMBIAR_CON_QUE"))
	elif indice < items.size():
		_texto(SistemaGuardado.obtener_datos_objeto_completos(items[indice].nombre_interno).descripcion)
	else:
		_texto("Volver al\nmenú anterior.")


func _abrir_mochila() -> void:
	estado = Estado.MOCHILA
	_mostrar_cajas(false)
	_ocultar_ventana_cantidad()
	dialogo.cerrar()
	mochila = preload("res://UI/mochila/mochila.tscn").instantiate()
	# Este selector vuelve al cuadro del PC, no a una pantalla con transición.
	mochila._func_oscurecer = _sin_fundido
	add_child(mochila)
	# DEJAR OBJETO se resuelve entero dentro de la mochila (OnItemSelect_PC).
	mochila.activar_modo_depositar_pc()
	mochila.mochila_cerrada.connect(_mochila_cerrada)


func _sin_fundido() -> void:
	pass


func _mochila_cerrada() -> void:
	if is_instance_valid(mochila):
		mochila.hide()
		mochila.queue_free()
	mochila = null
	if estado == Estado.MOCHILA:
		cerrado.emit()


## ItemStorage_DoItemAction: con una sola unidad no se pregunta la cantidad.
func _elegir_cantidad() -> void:
	esperar_soltar = true
	maximo = int(elegido.cantidad)
	cantidad = 1
	estado = Estado.CANTIDAD
	if maximo == 1:
		_confirmar_cantidad()
	else:
		_mostrar_cantidad()


func _mostrar_cantidad() -> void:
	_texto(tr("MOCHILA_TIRAR_CUANTOS") if operacion == 2 else PREGUNTA_SACAR)
	if ventana_cantidad == null:
		ventana_cantidad = _crear_marco(RECT_CANTIDAD)
		etiqueta_cantidad = _crear_etiqueta(Vector2(16, 8))
		ventana_cantidad.add_child(etiqueta_cantidad)
	etiqueta_cantidad.text = "×" + str(cantidad).pad_zeros(3)


func _ocultar_ventana_cantidad() -> void:
	if is_instance_valid(ventana_cantidad):
		ventana_cantidad.queue_free()
	ventana_cantidad = null
	etiqueta_cantidad = null


func _confirmar_cantidad() -> void:
	_ocultar_ventana_cantidad()
	if operacion == 2:
		if AlmacenObjetosPC.importancia(elegido.nombre_interno) != 0:
			_mensaje("¡Es demasiado\nimportante para\ntirarlo!")
			return
		_confirmar_tirar()
	else:
		_ejecutar()


## gOtherText_OkayToThrowAwayPrompt + SÍ/NO (el cursor pasa al SÍ/NO);
## NO o B devuelven a la lista.
func _confirmar_tirar() -> void:
	estado = Estado.CONFIRMACION
	cursor.visible = false
	var nombre: String = ObjetosLlevados.nombre_objeto(elegido.nombre_interno)
	_texto(tr("MOCHILA_TIRAR_CONFIRMAR").replace("{n}", str(cantidad)).replace("{key}", nombre))
	var menu := MenuConfirmacion.new()
	add_child(menu)
	menu.crear_menu(POS_SI_NO)
	var respuesta: String = await menu.opcion_seleccionada
	menu.queue_free()
	# La respuesta llega dentro del _input del SÍ/NO: que A/B no se reutilice aquí.
	if is_inside_tree():
		get_viewport().set_input_as_handled()
	esperar_soltar = true
	responder_tirar(respuesta == "Y")


func responder_tirar(si: bool) -> void:
	if si:
		_ejecutar()
	else:
		_lista()


func _ejecutar() -> void:
	var resultado: AlmacenObjetosPC.Resultado
	match operacion:
		0: resultado = AlmacenObjetosPC.sacar(indice, cantidad)
		2: resultado = AlmacenObjetosPC.tirar(indice, cantidad)
	var nombre: String = ObjetosLlevados.nombre_objeto(elegido.nombre_interno)
	match resultado:
		AlmacenObjetosPC.Resultado.EXITO:
			if operacion == 0:
				_mensaje("Has sacado %d." % cantidad)
			else:
				_mensaje(tr("MOCHILA_TIRAR_HECHO").replace("{n}", str(cantidad)).replace("{key}", nombre))
		AlmacenObjetosPC.Resultado.IMPORTANTE: _mensaje("¡Es demasiado\nimportante para\ntirarlo!")
		_: _mensaje("No se pudo mover el objeto.")


func _mensaje(texto: String) -> void:
	estado = Estado.MENSAJE
	esperar_soltar = true
	_ocultar_ventana_cantidad()
	_texto(texto)


func _volver() -> void:
	esperar_soltar = true
	_lista()

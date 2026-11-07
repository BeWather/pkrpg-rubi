extends Node2D
class_name PantallaEstuchePokecubos

## Pantalla de la CAJA POKéCUBOS (pokeruby src/pokeblock.c).
##
## Lista de los cubos del estuche (nombre por color y nivel = sabor más alto), con
## «Guardar TUBO» como última fila; abajo a la izquierda, los sabores del cubo elegido
## (sus iconos de color) y la MASA (suavidad, máx. 99). El dispositivo de la izquierda
## se tambalea al mover el cursor (sub_810C8D4).
##
## Controles (sub_810BF7C): ARRIBA/ABAJO mueven la fila resaltada; SELECT entra en el
## modo mover (sub_810C0C8: A o SELECT intercambian, B cancela); A abre el menú
## USAR / TIRAR / SALIR (o cierra en «Guardar TUBO»); B cierra.
## TIRAR pregunta «¿Tirar el X?» y, con SÍ, tira el cubo, compacta el estuche y
## muestra «Tiraste el X.» hasta A/B (mensajes en la ventana propia de la escena).
## USAR abre la pantalla de condición (PantallaCondicionPokecubo) para elegir quién
## se lo come; al volver, el estuche se reabre compactado (sub_810B96C).
##
## La pantalla se crea con la pantalla ya oscurecida y emite `estuche_cerrado` con la
## pantalla oscurecida otra vez.

signal estuche_cerrado

enum Modo { OCUPADO, LISTA, MOVER, MENU, PREGUNTA, MENSAJE }

## Filas de la lista a la vista: la del cursor llega hasta FILAS_CURSOR (sub_810BD08).
const FILAS_VISIBLES: int = 9
const FILAS_CURSOR: int = 8
## Tile (15, 2·fila + 1) de BG2 (sub_810BD64 / sub_810BB88).
const ORIGEN_LISTA: Vector2 = Vector2(120, 8)
const ALTO_FILA: int = 16
## Regiones de estuche_fila.png: paleta 1 (fila elegida) y paleta 2 (modo mover).
const REGION_FILA_ELEGIDA: Rect2 = Rect2(0, 0, 112, 16)
const REGION_FILA_MOVER: Rect2 = Rect2(0, 16, 112, 16)
## Fotograma vacío de estuche_sabores.png (tile 15).
const SABOR_VACIO: int = 5
## Sabores en el orden del decomp y su clave de texto.
const CLAVES_SABOR: Array[String] = [
	"POKECUBOS_SABOR_PICANTE", "POKECUBOS_SABOR_SECO", "POKECUBOS_SABOR_DULCE",
	"POKECUBOS_SABOR_AMARGO", "POKECUBOS_SABOR_ACIDO",
]
const OPC_USAR: int = 0
const OPC_TIRAR: int = 1
const OPC_SALIR: int = 2
## gUnknown_083F7EF4 / gUnknown_083F7F1C: USAR, TIRAR, SALIR.
const CLAVES_OPCION: Array[String] = ["POKECUBOS_OPCION_USAR", "POKECUBOS_OPCION_TIRAR", "POKECUBOS_OPCION_SALIR"]
const RUTA_CONDICION: String = "res://UI/pokecubos/pantalla_condicion_pokecubo.tscn"
## Nombre del objeto para el título (ItemId_GetName(ITEM_POKEBLOCK_CASE)).
const OBJETO_ESTUCHE: String = "CAJAPOKECUBOS"
## gSpriteAffineAnim_83F7F48: el dispositivo gira −2·2 + 2·4 − 2·4 + 2·2 unidades
## afines (256 = vuelta) en 12 fotogramas.
const PASOS_TAMBALEO: Array[Vector2] = [Vector2(-2, 2), Vector2(2, 4), Vector2(-2, 4), Vector2(2, 2)]
const FOTOGRAMA: float = 1.0 / 60.0

## Fila del cursor y desplazamiento de la lista, compartidos entre aperturas como
## gUnknown_02039248 (EWRAM) en Rubí.
static var fila_guardada: int = 0
static var desplazamiento_guardado: int = 0

@onready var lb_titulo: Label = $Titulo
@onready var nd_filas: Node2D = $Lista
@onready var spr_fila_cursor: Sprite2D = $FilaCursor
@onready var spr_fila_origen: Sprite2D = $FilaOrigen
@onready var nd_sabores: Node2D = $Sabores
@onready var lb_suavidad: Label = $Suavidad
@onready var spr_dispositivo: Sprite2D = $Dispositivo
@onready var nd_flecha_arriba: AnimatedSprite2D = $FlechaArriba
@onready var nd_flecha_abajo: AnimatedSprite2D = $FlechaAbajo
@onready var nd_menu: NinePatchRect = $Menu
@onready var nd_cursor_menu: Control = $Menu/Cursor
@onready var nd_si_no: NinePatchRect = $SiNo
@onready var nd_cursor_si_no: Control = $SiNo/Cursor
@onready var nd_ventana: NinePatchRect = $Ventana
@onready var lb_mensaje: Label = $Ventana/Texto

var estuche: EstuchePokecubos = null
var modo: Modo = Modo.OCUPADO
## unk0 / unk1 / unk2 / unk3 de gUnknown_02039248.
var fila: int = 0
var desplazamiento: int = 0
var cantidad: int = 0
var fila_maxima: int = 0
## Hueco de origen del modo mover (gTasks[].data[0]).
var origen_mover: int = -1
var indice_menu: int = 0
var indice_si_no: int = 0
## Pantalla de condición abierta con USAR.
var pantalla_condicion: PantallaCondicionPokecubo = null
var _tween_tambaleo: Tween = null


func _ready() -> void:
	spr_fila_origen.visible = false
	nd_menu.visible = false
	nd_si_no.visible = false
	nd_ventana.visible = false
	lb_titulo.text = _nombre_estuche()
	for i in CLAVES_SABOR.size():
		var etiqueta: Label = nd_sabores.get_node("Texto%d" % i) as Label
		etiqueta.text = tr(CLAVES_SABOR[i])
	for i in CLAVES_OPCION.size():
		(nd_menu.get_node("Opcion%d" % i) as Label).text = tr(CLAVES_OPCION[i])
	# Ejecutada sola (F6): estuche de prueba con los cubos de depuración del decomp.
	if get_tree().current_scene == self:
		scale = Vector2(3, 3)
		abrir(_estuche_de_prueba())


## Abre el estuche (sub_810B6C0): compacta los huecos, recalcula la lista con la
## posición guardada y aclara la pantalla. Se llama con la pantalla oscurecida.
func abrir(estuche_cubos: EstuchePokecubos = null) -> void:
	estuche = estuche_cubos if estuche_cubos != null else SistemaGuardado.obtener_estuche_pokecubos()
	fila = fila_guardada
	desplazamiento = desplazamiento_guardado
	estuche.compactar()
	_recalcular()
	_pintar_lista()
	_pintar_detalle(false)
	visible = true
	await Singleton.transicion("aclarar")
	modo = Modo.LISTA


## Índice del hueco bajo el cursor; == cantidad en «Guardar TUBO».
func indice_actual() -> int:
	return fila + desplazamiento


func en_guardar() -> bool:
	return indice_actual() == cantidad


func cubo_actual() -> Pokecubo:
	return null if en_guardar() else estuche.obtener(indice_actual())


# ─── Entrada ─────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not visible or not is_inside_tree():
		return
	match modo:
		Modo.LISTA:
			_input_lista(event)
		Modo.MOVER:
			_input_mover(event)
		Modo.MENU:
			_input_menu(event)
		Modo.PREGUNTA:
			_input_si_no(event)
		Modo.MENSAJE:
			if event.is_action_pressed("btn_accion") or event.is_action_pressed("btn_cancelar"):
				get_viewport().set_input_as_handled()
				_volver_a_lista()
		_:
			return


func _input_lista(event: InputEvent) -> void:
	if event.is_action_pressed("btn_arriba", true):
		mover_cursor(-1)
	elif event.is_action_pressed("btn_abajo", true):
		mover_cursor(1)
	elif event.is_action_pressed("btn_select"):
		iniciar_mover()
	elif event.is_action_pressed("btn_accion"):
		_sonido_seleccion()
		if en_guardar():
			cerrar()
		else:
			abrir_menu()
	elif event.is_action_pressed("btn_cancelar"):
		_sonido_seleccion()
		cerrar()
	else:
		return
	get_viewport().set_input_as_handled()


func _input_mover(event: InputEvent) -> void:
	if event.is_action_pressed("btn_arriba", true):
		mover_cursor(-1)
	elif event.is_action_pressed("btn_abajo", true):
		mover_cursor(1)
	elif event.is_action_pressed("btn_accion") or event.is_action_pressed("btn_select"):
		_sonido_seleccion()
		confirmar_mover()
	elif event.is_action_pressed("btn_cancelar"):
		_sonido_seleccion()
		cancelar_mover()
	else:
		return
	get_viewport().set_input_as_handled()


func _input_menu(event: InputEvent) -> void:
	if event.is_action_pressed("btn_arriba", true):
		mover_menu(-1)
	elif event.is_action_pressed("btn_abajo", true):
		mover_menu(1)
	elif event.is_action_pressed("btn_accion"):
		_sonido_seleccion()
		elegir_opcion(indice_menu)
	elif event.is_action_pressed("btn_cancelar"):
		_sonido_seleccion()
		cerrar_menu()
	else:
		return
	get_viewport().set_input_as_handled()


func _input_si_no(event: InputEvent) -> void:
	if event.is_action_pressed("btn_arriba") or event.is_action_pressed("btn_abajo"):
		var nuevo: int = 1 - indice_si_no
		if nuevo != indice_si_no:
			indice_si_no = nuevo
			Singleton.play_sound.emit("SE_SELECT")
			_colocar_cursor_si_no()
	elif event.is_action_pressed("btn_accion"):
		_sonido_seleccion()
		responder_tirar(indice_si_no == 0)
	elif event.is_action_pressed("btn_cancelar"):
		_sonido_seleccion()
		responder_tirar(false)
	else:
		return
	get_viewport().set_input_as_handled()


# ─── Lista ───────────────────────────────────────────────────────────────────

## ARRIBA/ABAJO (sub_810BF7C y sub_810C0C8): mueve la fila resaltada y, en los
## bordes, desplaza la lista. Devuelve true si se movió.
func mover_cursor(direccion: int) -> bool:
	if direccion < 0:
		if fila > 0:
			fila -= 1
		elif desplazamiento > 0:
			desplazamiento -= 1
		else:
			return false
	else:
		if fila != fila_maxima:
			fila += 1
		elif desplazamiento + fila != cantidad:
			desplazamiento += 1
		else:
			return false
	_pintar_lista()
	_pintar_detalle(modo == Modo.MOVER)
	_guardar_posicion()
	# sub_810BF38: SE_SELECT y tambaleo del dispositivo.
	Singleton.play_sound.emit("SE_SELECT")
	_tambalear_dispositivo()
	return true


## SELECT: modo mover sobre el cubo actual (no en «Guardar TUBO»).
func iniciar_mover() -> bool:
	if en_guardar():
		return false
	_sonido_seleccion()
	origen_mover = indice_actual()
	modo = Modo.MOVER
	_pintar_lista()
	_pintar_detalle(true)
	return true


## A o SELECT en el modo mover (sub_810C23C): intercambia el origen con el hueco
## del cursor; sobre «Guardar TUBO» no hace nada.
func confirmar_mover() -> void:
	if not en_guardar() and origen_mover >= 0:
		estuche.intercambiar(indice_actual(), origen_mover)
	_salir_de_mover()


func cancelar_mover() -> void:
	_salir_de_mover()


func _salir_de_mover() -> void:
	origen_mover = -1
	modo = Modo.LISTA
	_pintar_lista()
	_pintar_detalle(false)


# ─── Menú USAR / TIRAR / SALIR ───────────────────────────────────────────────

func abrir_menu() -> void:
	if en_guardar():
		return
	indice_menu = 0
	nd_menu.visible = true
	_colocar_cursor_menu()
	# sub_810C368: las flechas se paran mientras el menú está abierto.
	nd_flecha_arriba.pause()
	nd_flecha_abajo.pause()
	modo = Modo.MENU


func mover_menu(direccion: int) -> void:
	var nuevo: int = clampi(indice_menu + direccion, 0, CLAVES_OPCION.size() - 1)
	if nuevo == indice_menu:
		return
	indice_menu = nuevo
	Singleton.play_sound.emit("SE_SELECT")
	_colocar_cursor_menu()


func cerrar_menu() -> void:
	nd_menu.visible = false
	nd_flecha_arriba.play()
	nd_flecha_abajo.play()
	modo = Modo.LISTA


func elegir_opcion(opcion: int) -> void:
	match opcion:
		OPC_USAR:
			await usar()
		OPC_TIRAR:
			await iniciar_tirar()
		_:
			cerrar_menu()


# ─── TIRAR (sub_810C540 … sub_810C668) ───────────────────────────────────────

## «¿Tirar el X?» en la ventana de mensajes (DisplayItemMessageOnField, tiles
## (0,14)-(29,19)) y SÍ/NO en (56, 48).
func iniciar_tirar() -> void:
	nd_menu.visible = false
	nd_flecha_abajo.visible = false
	modo = Modo.OCUPADO
	await escribir_mensaje(tr("POKECUBOS_TIRAR_PREGUNTA").replace("{pokecubo}", _nombre_cubo(cubo_actual())))
	_mostrar_si_no()


func _mostrar_si_no() -> void:
	indice_si_no = 0
	nd_si_no.visible = true
	_colocar_cursor_si_no()
	modo = Modo.PREGUNTA


## SÍ: tira el cubo, compacta y muestra «Tiraste el X.» hasta A/B; NO: vuelve a la lista.
func responder_tirar(si: bool) -> void:
	nd_si_no.visible = false
	if not si:
		_volver_a_lista()
		return
	var nombre: String = _nombre_cubo(cubo_actual())
	estuche.tirar(indice_actual())
	_recalcular()
	_guardar_posicion()
	_pintar_lista()
	_pintar_detalle(false)
	nd_flecha_abajo.visible = false
	modo = Modo.OCUPADO
	await escribir_mensaje(tr("POKECUBOS_TIRADO").replace("{pokecubo}", nombre))
	modo = Modo.MENSAJE


## Escribe `texto` en la ventana de mensajes letra a letra (un carácter por fotograma).
func escribir_mensaje(texto: String) -> void:
	lb_mensaje.text = texto
	nd_ventana.visible = true
	if not is_inside_tree():
		return
	lb_mensaje.visible_characters = 0
	var total: int = lb_mensaje.get_total_character_count()
	while lb_mensaje.visible_characters < total and is_inside_tree():
		await get_tree().physics_frame
		lb_mensaje.visible_characters += 1
	lb_mensaje.visible_characters = -1


func _volver_a_lista() -> void:
	nd_menu.visible = false
	nd_si_no.visible = false
	nd_ventana.visible = false
	lb_mensaje.text = ""
	nd_flecha_arriba.play()
	nd_flecha_abajo.play()
	_pintar_detalle(false)
	modo = Modo.LISTA


# ─── USAR (sub_810C508 → sub_8136130) ────────────────────────────────────────

## Oscurece y abre la pantalla de condición con el cubo elegido. El estuche se queda
## oculto hasta que la pantalla de condición termina.
func usar() -> void:
	nd_menu.visible = false
	modo = Modo.OCUPADO
	var indice: int = indice_actual()
	await Singleton.transicion("oscurecer")
	pantalla_condicion = (load(RUTA_CONDICION) as PackedScene).instantiate() as PantallaCondicionPokecubo
	get_parent().add_child(pantalla_condicion)
	pantalla_condicion.terminado.connect(_on_condicion_terminada)
	visible = false
	pantalla_condicion.abrir(estuche, indice)


## Vuelta de la pantalla de condición (ya oscurecida): se reabre el estuche
## compactado, como al volver a sub_810B96C.
func _on_condicion_terminada() -> void:
	if is_instance_valid(pantalla_condicion):
		pantalla_condicion.queue_free()
	pantalla_condicion = null
	nd_flecha_arriba.play()
	nd_flecha_abajo.play()
	abrir(estuche)


# ─── Cerrar ──────────────────────────────────────────────────────────────────

## sub_810C31C: fundido a negro y vuelta a quien abrió el estuche.
func cerrar() -> void:
	modo = Modo.OCUPADO
	_guardar_posicion()
	await Singleton.transicion("oscurecer")
	visible = false
	estuche_cerrado.emit()


# ─── Dibujo ──────────────────────────────────────────────────────────────────

## sub_810BD08: cuenta los cubos, fija la última fila del cursor y, si la lista se
## acortó, retrocede el desplazamiento una fila.
func _recalcular() -> void:
	cantidad = estuche.cantidad()
	fila_maxima = mini(cantidad, FILAS_CURSOR)
	if desplazamiento + FILAS_CURSOR > cantidad and desplazamiento != 0:
		desplazamiento -= 1
	desplazamiento = clampi(desplazamiento, 0, maxi(0, cantidad - FILAS_CURSOR))
	fila = clampi(fila, 0, fila_maxima)


## sub_810BB88: nombre y nivel de cada fila; «Guardar TUBO» tras el último cubo.
func _pintar_lista() -> void:
	for i in FILAS_VISIBLES:
		var nodo: Node2D = nd_filas.get_node("Fila%d" % i) as Node2D
		var nombre: Label = nodo.get_node("Nombre") as Label
		var nivel: Label = nodo.get_node("Nivel") as Label
		var indice: int = desplazamiento + i
		if indice < cantidad:
			var cubo: Pokecubo = estuche.obtener(indice)
			nombre.text = _nombre_cubo(cubo)
			nivel.text = str(cubo.nivel()) if cubo != null else ""
			nodo.visible = true
		elif indice == cantidad:
			nombre.text = tr("POKECUBOS_GUARDAR")
			nivel.text = ""
			nodo.visible = true
		else:
			nodo.visible = false


## sub_810BDAC: fila resaltada, flechas, iconos de sabor y MASA del cubo actual.
func _pintar_detalle(moviendo: bool) -> void:
	spr_fila_cursor.position = ORIGEN_LISTA + Vector2(0, ALTO_FILA * fila)
	spr_fila_cursor.region_rect = REGION_FILA_MOVER if moviendo else REGION_FILA_ELEGIDA
	# sub_810C1C8: en el modo mover, la fila de origen sigue marcada si está a la vista.
	var fila_origen: int = origen_mover - desplazamiento
	spr_fila_origen.visible = moviendo and origen_mover >= 0 and fila_origen >= 0 \
		and fila_origen < FILAS_VISIBLES and fila_origen != fila
	spr_fila_origen.position = ORIGEN_LISTA + Vector2(0, ALTO_FILA * fila_origen)
	nd_flecha_arriba.visible = desplazamiento > 0
	nd_flecha_abajo.visible = cantidad > fila_maxima and desplazamiento + fila_maxima != cantidad
	var cubo: Pokecubo = cubo_actual()
	for i in Pokecubo.NUM_SABORES:
		var icono: Sprite2D = nd_sabores.get_node("Icono%d" % i) as Sprite2D
		icono.frame = i if cubo != null and cubo.sabor(i) > 0 else SABOR_VACIO
	lb_suavidad.text = str(cubo.suavidad_mostrada()) if cubo != null else ""


func _colocar_cursor_menu() -> void:
	var etiqueta: Label = nd_menu.get_node("Opcion%d" % indice_menu) as Label
	nd_cursor_menu.position = etiqueta.position - Vector2(1, 1)


func _colocar_cursor_si_no() -> void:
	nd_cursor_si_no.position = Vector2(7, 7 + 16 * indice_si_no)


## sub_810C8D4: tambaleo afín del dispositivo (12 fotogramas).
func _tambalear_dispositivo() -> void:
	if _tween_tambaleo != null and _tween_tambaleo.is_valid():
		_tween_tambaleo.kill()
	spr_dispositivo.rotation = 0.0
	_tween_tambaleo = create_tween()
	var angulo: float = 0.0
	for paso: Vector2 in PASOS_TAMBALEO:
		# AFFINEANIMCMD_FRAME(0, 0, rot, dur): `rot` unidades por fotograma (256 = vuelta).
		angulo += paso.x * paso.y
		_tween_tambaleo.tween_property(spr_dispositivo, "rotation", -angulo * TAU / 256.0, paso.y * FOTOGRAMA)


func _guardar_posicion() -> void:
	fila_guardada = fila
	desplazamiento_guardado = desplazamiento


func _sonido_seleccion() -> void:
	Singleton.play_sound.emit("SE_SELECT")


func _nombre_cubo(cubo: Pokecubo) -> String:
	return tr(cubo.clave_nombre()) if cubo != null else ""


func _nombre_estuche() -> String:
	var datos: Dictionary = {}
	if DatabaseManager != null and DatabaseManager.has_method("obtener_datos_objeto"):
		datos = DatabaseManager.obtener_datos_objeto(OBJETO_ESTUCHE)
	return FormateadorLigaduras.formatear(str(datos.get("nombre", "CAJA POKéCUBOS")))


## gUnknown_083F7F9C (cubos de depuración del decomp), para probar la escena con F6.
func _estuche_de_prueba() -> EstuchePokecubos:
	var prueba := EstuchePokecubos.new()
	var sabores: Array = [
		[20, 0, 0, 0, 0], [0, 20, 0, 0, 0], [0, 0, 20, 0, 0], [0, 0, 0, 20, 0], [0, 0, 0, 0, 20],
		[20, 0, 20, 0, 0], [0, 20, 0, 20, 0], [0, 0, 20, 0, 20], [20, 0, 0, 20, 0], [0, 20, 0, 0, 20],
		[0, 2, 0, 2, 2], [3, 3, 3, 4, 3], [1, 1, 1, 1, 1], [20, 0, 0, 0, 0],
	]
	for i in sabores.size():
		prueba.agregar(Pokecubo.crear(i + 1, sabores[i], 20))
	return prueba

class_name MenuPCCasa
extends Control

signal cerrado
signal accion_sin_implementar(opcion: String)

enum Estado { PRINCIPAL, ALMACEN, DECORACION, BUZON, MANTENIMIENTO, EDITOR, OBJETOS }

const OPCIONES_PRINCIPALES: Array[String] = [
	"ALMACÉN OBJ.",
	"BUZÓN",
	"DECORACIÓN",
	"DESCONEXIÓN",
]
const OPCIONES_PUBLICAS: Array[String] = ["ALMACÉN OBJ.", "BUZÓN", "DESCONEXIÓN"]
const OPCIONES_ALMACEN: Array[String] = [
	"SACAR OBJETO",
	"DEJAR OBJETO",
	"TIRAR OBJETO",
	"SALIR",
]
const DESCRIPCIONES_ALMACEN: Array[String] = [
	"Sacar objetos del PC.",
	"Guardar objetos en el PC.",
	"Tirar objetos del PC.",
	"Volver al menú\nanterior.",
]
const OPCIONES_DECORACION: Array[String] = [
	"DECORAR",
	"GUARDAR",
	"TIRAR",
	"SALIR",
]
const DESCRIPCIONES_DECORACION: Array[String] = [
	"Escoger un objeto para decorar.",
	"Guardar el adorno escogido en el PC.",
	"Eliminar los adornos no deseados.",
	"Volver al menú\nanterior.",
]

@onready var cuadro_opciones: NinePatchRect = $CuadroOpciones
@onready var etiquetas: Array[Label] = [
	$CuadroOpciones/Opcion1,
	$CuadroOpciones/Opcion2,
	$CuadroOpciones/Opcion3,
	$CuadroOpciones/Opcion4,
]
@onready var cursor: PkSelectorSimple = $CuadroOpciones/Cursor

var estado: Estado = Estado.PRINCIPAL
var indice: int = 0
var opciones_actuales: Array[String] = []
var descripciones_actuales: Array[String] = []
var activo: bool = false
var _esperando_soltar_boton: bool = true
var _texto_en_progreso: bool = false
var _cuadro_dialogo: NinePatchRect = null
var _estado_retorno_mantenimiento: Estado = Estado.PRINCIPAL
var habitacion: HabitacionJugador
var administrador: Node2D
var _editor: EditorDecoracion
var _sesion: int = 0
var _almacen: Control
## PlayerPC de Ruby (centros/guardería) no ofrece decoración de la habitación.
var modo_publico: bool = false


func _ready() -> void:
	var tipo_imagen := 1
	var sistema_guardado := get_tree().root.get_node_or_null("SistemaGuardado")
	if sistema_guardado and sistema_guardado.datos_vivos and sistema_guardado.datos_vivos.opciones:
		tipo_imagen = int(sistema_guardado.datos_vivos.opciones.imagen_tipo)
	MenuBoxManager.apply_texture_to_ninepatch(cuadro_opciones, tipo_imagen)
	cuadro_opciones.visible = false
	cursor.visible = false
	if _cuadro_dialogo:
		abrir()


func configurar_cuadro_dialogo(cuadro: NinePatchRect) -> void:
	_cuadro_dialogo = cuadro


func abrir() -> void:
	activo = true
	_esperando_soltar_boton = true
	_mostrar_menu_principal()


func _process(_delta: float) -> void:
	if _esperando_soltar_boton \
		and not Input.is_action_pressed("btn_accion") \
		and not Input.is_action_pressed("btn_cancelar"):
		_esperando_soltar_boton = false


func _unhandled_input(event: InputEvent) -> void:
	if not activo or _texto_en_progreso or _esperando_soltar_boton or event.is_echo():
		return

	if event.is_action_pressed("btn_arriba"):
		_mover_cursor(-1)
	elif event.is_action_pressed("btn_abajo"):
		_mover_cursor(1)
	elif event.is_action_pressed("btn_accion"):
		_confirmar()
	elif event.is_action_pressed("btn_cancelar"):
		_cancelar()
	else:
		return

	get_viewport().set_input_as_handled()


func _mostrar_menu_principal() -> void:
	estado = Estado.PRINCIPAL
	var principales: Array[String] = OPCIONES_PUBLICAS if modo_publico else OPCIONES_PRINCIPALES
	_preparar_opciones(principales, [])
	cuadro_opciones.size.y = 16.0 + principales.size() * 16.0
	cuadro_opciones.visible = false
	cursor.visible = false
	_texto_en_progreso = true
	_esperando_soltar_boton = true
	_cuadro_dialogo.mostrar("¿Qué quieres hacer?", false, false, _on_texto_principal_completo, false, true)


func _on_texto_principal_completo() -> void:
	if not activo or estado != Estado.PRINCIPAL:
		return
	_texto_en_progreso = false
	cuadro_opciones.visible = true
	cursor.visible = true


func _mostrar_menu_almacen() -> void:
	estado = Estado.ALMACEN
	cuadro_opciones.size.y = 80.0
	_configurar_menu_inmediato(OPCIONES_ALMACEN, DESCRIPCIONES_ALMACEN)


func _mostrar_menu_decoracion() -> void:
	estado = Estado.DECORACION
	var opciones: Array[String] = []
	var ayudas: Array[String] = []
	for clave: String in PCBaseSecreta.DECORACION:
		opciones.append(DatosPCBase.texto(clave))
	for clave: String in PCBaseSecreta.AYUDAS:
		ayudas.append(DatosPCBase.texto(clave))
	_configurar_menu_inmediato(opciones, ayudas)
	_esperando_soltar_boton = true


func _abrir_editor() -> void:
	if not is_instance_valid(habitacion) or not is_instance_valid(administrador) or not habitacion.pc_activo():
		return  # No simular una operación ni autorizar la habitación rival.
	var dialogo: DialogoBaseSecreta = administrador.get("dialogo_bases") as DialogoBaseSecreta
	if dialogo == null:
		return
	_editor = dialogo.get_node_or_null("EditorDecoracion") as EditorDecoracion
	if _editor == null:
		return
	var operacion: StringName = [&"decorar", &"guardar", &"tirar"][indice]
	estado = Estado.EDITOR
	_texto_en_progreso = true
	cuadro_opciones.hide()
	cursor.hide()
	_cuadro_dialogo.cerrar()
	_sesion += 1
	var sesion: int = _sesion
	await _editor.abrir_operacion(operacion, habitacion, administrador)
	if activo and sesion == _sesion and is_instance_valid(habitacion) and habitacion.pc_activo():
		_mostrar_menu_decoracion()


func _mostrar_buzon() -> void:
	estado = Estado.BUZON
	cuadro_opciones.visible = false
	cursor.visible = false
	_texto_en_progreso = true
	_esperando_soltar_boton = true
	_cuadro_dialogo.mostrar("Aquí no hay ninguna CARTA.", true, false, _on_buzon_terminado, false, true)


func _on_buzon_terminado() -> void:
	if not activo or estado != Estado.BUZON:
		return
	_texto_en_progreso = false
	_mostrar_menu_principal()


func _mostrar_mantenimiento() -> void:
	_estado_retorno_mantenimiento = estado
	estado = Estado.MANTENIMIENTO
	cuadro_opciones.visible = false
	cursor.visible = false
	_texto_en_progreso = true
	_esperando_soltar_boton = true
	_cuadro_dialogo.mostrar(
		"Sistema temporalmente en mantenimiento.",
		true,
		false,
		_on_mantenimiento_terminado,
		false,
		true
	)


func _on_mantenimiento_terminado() -> void:
	if not activo or estado != Estado.MANTENIMIENTO:
		return
	_texto_en_progreso = false
	match _estado_retorno_mantenimiento:
		Estado.ALMACEN:
			_mostrar_menu_almacen()
		Estado.DECORACION:
			_mostrar_menu_decoracion()
		_:
			_mostrar_menu_principal()


func _preparar_opciones(opciones: Array[String], descripciones: Array[String]) -> void:
	opciones_actuales = opciones
	descripciones_actuales = descripciones
	indice = 0
	for i in etiquetas.size():
		etiquetas[i].text = opciones_actuales[i] if i < opciones_actuales.size() else ""
	cursor.position.y = 7.0


func _configurar_menu_inmediato(opciones: Array[String], descripciones: Array[String]) -> void:
	_preparar_opciones(opciones, descripciones)
	_texto_en_progreso = false
	cuadro_opciones.visible = true
	cursor.visible = true
	_actualizar_cursor_y_descripcion()


func _mover_cursor(direccion: int) -> void:
	indice = posmod(indice + direccion, opciones_actuales.size())
	_reproducir_sonido_cursor()
	_actualizar_cursor_y_descripcion()


func _actualizar_cursor_y_descripcion() -> void:
	cursor.position.y = 7.0 + indice * 16.0
	if not descripciones_actuales.is_empty():
		_cuadro_dialogo.mostrar_inmediatamente(descripciones_actuales[indice])


func _confirmar() -> void:
	_reproducir_sonido_cursor()
	match estado:
		Estado.PRINCIPAL:
			match indice:
				0: _mostrar_menu_almacen()
				1: _mostrar_buzon()
				2:
					if modo_publico: _cerrar()
					else: _mostrar_menu_decoracion()
				3: _cerrar()
		Estado.DECORACION:
			if indice == 3:
				_mostrar_menu_principal()
			else:
				_abrir_editor()
		Estado.ALMACEN:
			if indice == 3:
				_mostrar_menu_principal()
			else:
				_abrir_almacen()


func _abrir_almacen() -> void:
	estado = Estado.OBJETOS
	_texto_en_progreso = true
	cuadro_opciones.hide()
	cursor.hide()
	_almacen = preload("res://UI/pc_casa/menu_almacen_objetos.gd").new()
	_almacen.operacion = indice
	_almacen.dialogo = _cuadro_dialogo
	_almacen.cerrado.connect(_cerrar_almacen)
	add_child(_almacen)


func _cerrar_almacen() -> void:
	# InitItemStorageMenu(CURRENT_ITEM_STORAGE_MENU): el cursor vuelve al apartado
	# usado; sin objetos, PlayerPC_ItemStorage reinicia en SACAR OBJETO.
	var apartado: int = 0 if _almacen.volver_al_inicio else _almacen.operacion
	_almacen.queue_free()
	_almacen = null
	_esperando_soltar_boton = true
	_mostrar_menu_almacen()
	indice = apartado
	_actualizar_cursor_y_descripcion()


func _cancelar() -> void:
	_reproducir_sonido_cursor()
	if estado == Estado.PRINCIPAL:
		_cerrar()
	else:
		_mostrar_menu_principal()


func _cerrar() -> void:
	if not activo:
		return
	activo = false
	_sesion += 1
	if is_instance_valid(_almacen):
		_almacen.queue_free()
		_almacen = null
	if is_instance_valid(_editor) and _editor.activo:
		_editor.cancelar()
	visible = false
	if not modo_publico:
		_reproducir_sonido("pc_cerrar")
	if _cuadro_dialogo:
		_cuadro_dialogo.cerrar_dialogo_externo()
	cerrado.emit()


func _exit_tree() -> void:
	activo = false
	_sesion += 1
	if is_instance_valid(_editor) and _editor.activo:
		_editor.cancelar()


func _reproducir_sonido_cursor() -> void:
	_reproducir_sonido("cursor_menu")


func _reproducir_sonido(nombre: String) -> void:
	var singleton := get_tree().root.get_node_or_null("Singleton")
	if singleton and singleton.has_signal("play_sound"):
		singleton.emit_signal("play_sound", nombre)

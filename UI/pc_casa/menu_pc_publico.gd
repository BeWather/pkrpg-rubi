class_name MenuPCPublico
extends Control

## data/scripts/pc.inc, script_menu.c y pokemon_storage_system.c de Ruby.
## Textos de la ROM española oficial (AXVS).
signal cerrado
enum Estado { PRINCIPAL, POKEMON, PERSONAL, CAJAS, MENSAJE, ACCESO, TRANSICION, CERRADO }
const OPCIONES_POKEMON: Array[String] = ["SACAR POKéMON", "DEJAR POKéMON", "MOVER POKéMON", "¡NOS VEMOS!"]
const AYUDAS_POKEMON: Array[String] = [
	"Pasar un POKéMON guardado en\nalguna CAJA a tu equipo.",
	"Guardar algún POKéMON de tu\nequipo en una CAJA.",
	"Ordenar los POKéMON de las\nCAJAS y de tu equipo.",
	"Regresar al menú anterior.",
]
## FLAG_SYS_PC_LANETTE: el jugador ya conoce a AREDIA (la activa su casa de la RUTA 114).
const BANDERA_PC_AREDIA := "FLAG_SYS_PC_LANETTE"
const BANDERA_JUEGO_COMPLETADO := "SYS_GAME_CLEAR"
const OPCION_HALL_FAMA := "HALL de la FAMA"
const TEXTO_HALL_SIN_DATOS := "No hay datos del HALL de la FAMA."
const TEXTO_ELEGIR_PC := "¿A qué PC quieres acceder?"
const TEXTO_PC_ALGUIEN := "Accedió al PC de alguien."
const TEXTO_PC_AREDIA := "Accedió al PC de AREDIA."
const TEXTO_PC_JUGADOR := "Accedió al PC de {PN}."
const TEXTO_ALMACENAMIENTO := "Acceso al Sistema de Almacenamiento\nde POKéMON concedido."
const TEXTO_EQUIPO_LLENO := "¡Tu equipo está completo!"
const TEXTO_SOLO_UNO := "Sólo llevas contigo un POKéMON."
## StorageSystemCreatePrimaryMenu: Menu_DrawStdWindowFrame(0, 0, 13, 9).
const ANCHO_MENU_POKEMON := 112.0

@onready var marco: NinePatchRect = $CuadroOpciones
@onready var cursor: PkSelectorSimple = $CuadroOpciones/Cursor
@onready var etiquetas: Array[Label] = [$CuadroOpciones/Opcion1, $CuadroOpciones/Opcion2, $CuadroOpciones/Opcion3, $CuadroOpciones/Opcion4]
@onready var dialogo: NinePatchRect = $Dialogo
var estado: Estado = Estado.PRINCIPAL
var opciones: Array[String] = []
var indice: int = 0
var indice_pokemon: int = 0
var esperar_soltar: bool = true
var usar_transiciones: bool = true
var personal: MenuPCCasa
var cajas: PantallaCajasPC
var hall_fama: PantallaHallFama
var _sesion: int = 0
## "message + waitmessage" de pc.inc: el multichoice aparece al terminar el texto.
var _escribiendo: bool = false


func _ready() -> void:
	MenuBoxManager.apply_texture_to_ninepatch(marco, int(SistemaGuardado.datos_vivos.opciones.imagen_tipo))
	_principal()


func _process(_delta: float) -> void:
	if not Input.is_action_pressed("btn_accion") and not Input.is_action_pressed("btn_cancelar"):
		esperar_soltar = false


func _unhandled_input(event: InputEvent) -> void:
	if esperar_soltar or _escribiendo or event.is_echo() or estado not in [Estado.PRINCIPAL, Estado.POKEMON, Estado.MENSAJE]:
		return
	if event.is_action_pressed("btn_arriba") or event.is_action_pressed("btn_abajo"):
		# Task_PokemonStorageSystem (caso 3): con el aviso en pantalla, ↑/↓ mueven el cursor.
		if estado == Estado.MENSAJE:
			estado = Estado.POKEMON
		indice = posmod(indice + (1 if event.is_action_pressed("btn_abajo") else -1), opciones.size())
		_actualizar()
	elif event.is_action_pressed("btn_accion"):
		_confirmar()
	elif event.is_action_pressed("btn_cancelar"):
		if estado == Estado.PRINCIPAL: cerrar()
		elif estado == Estado.MENSAJE: _pokemon(indice_pokemon)
		else: _principal()
	else:
		return
	get_viewport().set_input_as_handled()
	Singleton.play_sound.emit("cursor_menu")


## Primer aviso del Sistema de Almacenamiento: PC de AREDIA si ya la conoce (FLAG_SYS_PC_LANETTE).
static func texto_acceso_almacenamiento() -> String:
	return TEXTO_PC_AREDIA if SistemaGuardado.get_flag(BANDERA_PC_AREDIA) else TEXTO_PC_ALGUIEN


## Primera opción del menú principal: «PC de AREDIA» o «PC de ALGUIEN».
static func etiqueta_sistema_almacenamiento() -> String:
	return "PC de AREDIA" if SistemaGuardado.get_flag(BANDERA_PC_AREDIA) else "PC de ALGUIEN"


func opciones_principales() -> Array[String]:
	var nombre: String = str(SistemaGuardado.datos_vivos.jugador.get("nombre", ""))
	# ScriptMenu_CreatePCMultichoice: el HALL de la FAMA solo tras FLAG_SYS_GAME_CLEAR.
	if SistemaGuardado.get_flag(BANDERA_JUEGO_COMPLETADO):
		return [etiqueta_sistema_almacenamiento(), "PC de " + nombre, OPCION_HALL_FAMA, "DESCONEXIÓN"]
	return [etiqueta_sistema_almacenamiento(), "PC de " + nombre, "DESCONEXIÓN"]


func _principal() -> void:
	estado = Estado.PRINCIPAL
	var principales: Array[String] = opciones_principales()
	_preparar(principales, 0, _ancho_para(principales))
	marco.hide()
	_escribiendo = true
	_sesion += 1
	var sesion: int = _sesion
	dialogo.mostrar(TEXTO_ELEGIR_PC, false, false, func() -> void: _mostrar_selector(sesion), false, true)


func _mostrar_selector(sesion: int) -> void:
	if sesion != _sesion or estado != Estado.PRINCIPAL:
		return
	_escribiendo = false
	esperar_soltar = true
	marco.show()


## ShowPokemonStorageSystem empieza en SACAR; al volver de las CAJAS se
## conserva la opción usada (FieldCB_ReturnToOverworld).
func _pokemon(seleccion: int = 0) -> void:
	estado = Estado.POKEMON
	_preparar(OPCIONES_POKEMON, seleccion, ANCHO_MENU_POKEMON)


func _preparar(nuevas: Array[String], seleccion: int, ancho: float) -> void:
	opciones = nuevas
	indice = seleccion
	esperar_soltar = true
	_escribiendo = false
	marco.size = Vector2(ancho, 16 + opciones.size() * 16)
	marco.show()
	cursor.size.x = ancho - 14
	_actualizar()


## ScriptMenu_CreatePCMenu ajusta el marco a la opción más ancha.
func _ancho_para(textos: Array[String]) -> float:
	var ajustes: LabelSettings = etiquetas[0].label_settings
	var fuente: Font = ajustes.font if ajustes and ajustes.font else etiquetas[0].get_theme_font("font")
	var tamano: int = ajustes.font_size if ajustes else etiquetas[0].get_theme_font_size("font_size")
	var maximo: float = 0.0
	for texto: String in textos:
		maximo = maxf(maximo, fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x)
	return maxf(88.0, ceilf(maximo / 8.0) * 8.0 + 24.0)


func _actualizar() -> void:
	for i in etiquetas.size():
		etiquetas[i].text = opciones[i] if i < opciones.size() else ""
	cursor.position.y = 7 + indice * 16
	if estado == Estado.POKEMON:
		indice_pokemon = indice
		dialogo.mostrar_inmediatamente(AYUDAS_POKEMON[indice])


func _confirmar() -> void:
	match estado:
		Estado.PRINCIPAL:
			match indice:
				0: _acceder_almacenamiento()
				1: _acceder_personal()
				_:
					if opciones[indice] == OPCION_HALL_FAMA:
						_acceder_hall_fama()
					else:
						cerrar()
		Estado.POKEMON:
			indice_pokemon = indice
			if indice == 3:
				_principal()
				return
			var equipo: Array = SistemaGuardado.get_equipo()
			if indice == 0 and equipo.size() >= SistemaGuardado.MAX_POKEMON_EQUIPO:
				_mensaje(TEXTO_EQUIPO_LLENO)
			elif indice == 1 and equipo.size() <= 1:
				_mensaje(TEXTO_SOLO_UNO)
			else:
				_abrir_cajas(indice)
		Estado.MENSAJE: _pokemon(indice_pokemon)


## El menú sigue en pantalla; solo cambia el texto de la ventana de mensajes.
func _mensaje(texto: String) -> void:
	estado = Estado.MENSAJE
	esperar_soltar = true
	dialogo.mostrar_inmediatamente(texto)


## EventScript_AccessPokemonStorage: SE_PC_LOGIN y dos msgbox antes del menú.
func _acceder_almacenamiento() -> void:
	_mostrar_acceso([texto_acceso_almacenamiento(), TEXTO_ALMACENAMIENTO], _pokemon)


## EventScript_AccessPlayersPC: SE_PC_LOGIN y msgbox antes de PlayerPC.
func _acceder_personal() -> void:
	_mostrar_acceso([TEXTO_PC_JUGADOR], _abrir_personal)


func _mostrar_acceso(textos: Array[String], siguiente: Callable) -> void:
	estado = Estado.ACCESO
	marco.hide()
	Singleton.play_sound.emit("SE_PC_LOGIN")
	_sesion += 1
	_encadenar_acceso(textos, 0, siguiente, _sesion)


func _encadenar_acceso(textos: Array[String], paso: int, siguiente: Callable, sesion: int) -> void:
	if sesion != _sesion or estado != Estado.ACCESO:
		return
	if paso >= textos.size():
		siguiente.call()
		return
	dialogo.mostrar(textos[paso], true, false, func() -> void: _encadenar_acceso(textos, paso + 1, siguiente, sesion), false, true)


## EventScript_AccessHallOfFame: SE_PC_LOGIN y AccessHallOfFamePC, sin mensaje.
func _acceder_hall_fama() -> void:
	if RegistroHallFama.equipos(SistemaGuardado.datos_vivos.datos_persistentes).is_empty():
		_mostrar_acceso([TEXTO_HALL_SIN_DATOS], _principal)
		return
	Singleton.play_sound.emit("SE_PC_LOGIN")
	estado = Estado.TRANSICION
	marco.hide()
	dialogo.cerrar()
	_sesion += 1
	var sesion: int = _sesion
	await Singleton.transicion("oscurecer")
	if not is_inside_tree() or sesion != _sesion:
		return
	hall_fama = preload("res://UI/hall_fama/pantalla_hall_fama.tscn").instantiate() as PantallaHallFama
	hall_fama.terminada.connect(_cerrar_hall_fama)
	add_child(hall_fama)
	hall_fama.abrir_registro()
	await Singleton.transicion("aclarar")


func _cerrar_hall_fama() -> void:
	_sesion += 1
	var sesion: int = _sesion
	await Singleton.transicion("oscurecer")
	if not is_inside_tree() or sesion != _sesion:
		return
	hall_fama.queue_free()
	hall_fama = null
	_principal()
	await Singleton.transicion("aclarar")


func _abrir_personal() -> void:
	estado = Estado.PERSONAL
	marco.hide()
	personal = preload("res://UI/pc_casa/menu_pc_casa.tscn").instantiate() as MenuPCCasa
	personal.modo_publico = true
	personal.configurar_cuadro_dialogo(dialogo)
	personal.cerrado.connect(_cerrar_personal)
	add_child(personal)


func _cerrar_personal() -> void:
	personal.queue_free()
	personal = null
	_principal()


func _abrir_cajas(modo: int) -> void:
	estado = Estado.TRANSICION
	marco.hide()
	dialogo.cerrar()
	_sesion += 1
	var sesion: int = _sesion
	if usar_transiciones:
		await Singleton.transicion("oscurecer")
	if not is_inside_tree() or sesion != _sesion:
		return
	cajas = preload("res://UI/cajas_pc/pantalla_cajas_pc.tscn").instantiate() as PantallaCajasPC
	cajas.caja_cerrada.connect(_cerrar_cajas)
	add_child(cajas)
	cajas.abrir_caja(SistemaGuardado.obtener_indice_caja_activa())
	cajas.configurar_operacion(modo)
	if usar_transiciones:
		await Singleton.transicion("aclarar")
	if sesion == _sesion:
		estado = Estado.CAJAS


func _cerrar_cajas() -> void:
	estado = Estado.TRANSICION
	_sesion += 1
	var sesion: int = _sesion
	if usar_transiciones:
		await Singleton.transicion("oscurecer")
	if not is_inside_tree() or sesion != _sesion:
		return
	cajas.hide()
	cajas.queue_free()
	cajas = null
	_pokemon(indice_pokemon)
	if usar_transiciones:
		estado = Estado.TRANSICION
		await Singleton.transicion("aclarar")
		if sesion == _sesion:
			estado = Estado.POKEMON


func cerrar() -> void:
	if estado == Estado.CERRADO:
		return
	estado = Estado.CERRADO
	_sesion += 1
	if is_instance_valid(personal):
		personal.cerrado.disconnect(_cerrar_personal)
		personal._cerrar()
		personal.queue_free()
		personal = null
	if is_instance_valid(hall_fama):
		hall_fama.queue_free()
		hall_fama = null
	if is_instance_valid(cajas):
		cajas.cursor_activo = false
		cajas.hide()
		cajas.queue_free()
		cajas = null
	dialogo.cerrar()
	hide()
	cerrado.emit()


func _exit_tree() -> void:
	_sesion += 1

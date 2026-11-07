## npc_dialogo_condicional.gd
## NPC cuyo script de pokeruby es un msgbox con variantes, sin guion propio:
## - textos_condicionales: goto_if_set / call_if_eq → otro texto (ver
##   CondicionTexto). Sin ninguna condición cumplida se usa id_texto.
## - id_texto_si / id_texto_no: MSGBOX_YESNO. id_texto es la pregunta y la
##   respuesta elige el mensaje siguiente (cancelar equivale a NO).
## - volver_direccion_original: applymovement Common_Movement_FaceOriginalDirection
##   al cerrar el mensaje; sin él, los FACE_* conservan la mirada (npc_base).
## - girar_al_hablar = false: MSGBOX_SIGN o lockall sin faceplayer.
## Diálogo SÍ/NO y bloqueo del jugador: patrón de npc_hombre_malvalona.gd.
@tool
extends "res://scripts/npc/npc_base.gd"

const MOTIVO_PAUSA: StringName = &"dialogo_condicional"

@export var textos_condicionales: Dictionary[String, String] = {}
@export var id_texto_si: String
@export var id_texto_no: String
@export var volver_direccion_original: bool = false
@export var girar_al_hablar: bool = true

signal _mensaje_terminado

var _secuencia_activa: bool = false


func mirar_jugador() -> void:
	if girar_al_hablar:
		super.mirar_jugador()


func _consumir_id_texto() -> String:
	var condicional := CondicionTexto.resolver(textos_condicionales, "")
	return condicional if not condicional.is_empty() else super._consumir_id_texto()


func _volver_a_direccion_base() -> void:
	if volver_direccion_original:
		update_direction(direccion_base)
	else:
		super._volver_a_direccion_base()


func _procesar_interaccion() -> void:
	if id_texto_si.is_empty() and id_texto_no.is_empty():
		super._procesar_interaccion()
		return
	interrupcion_pendiente = false
	if _secuencia_activa:
		return
	if nodo_administrador == null or nodo_administrador.cuadro_dialogo == null:
		if jugador and jugador.has_method("esperar_dialogo"):
			jugador.esperar_dialogo(false)
		cambiar_estado(EstadoNPC.IDLE)
		return
	_ejecutar_pregunta()


func _ejecutar_pregunta() -> void:
	_secuencia_activa = true
	cambiar_estado(EstadoNPC.INTERACTING)
	if tipo_movimiento != TipoMovimientoNPC.SIN_MOVIMIENTO:
		mirar_jugador()  # faceplayer
	_bloquear_jugador(true)
	var respuesta := id_texto_si if await _preguntar_si_no(_consumir_id_texto()) else id_texto_no
	if not respuesta.is_empty():
		nodo_administrador.cuadro_dialogo.mostrar(tr(respuesta), true, true, _mensaje_terminado.emit)
		await _mensaje_terminado
	_bloquear_jugador(false)
	_volver_a_direccion_base()
	_secuencia_activa = false
	cambiar_estado(EstadoNPC.IDLE)


func _bloquear_jugador(activo: bool) -> void:
	Singleton.mantener_pausa(MOTIVO_PAUSA, activo)
	if jugador == null:
		return
	if activo:
		jugador.start_dialog()
	else:
		jugador.end_dialog()
	jugador.no_control = activo


## multichoice: muestra `texto` con un menú de `opciones` y devuelve el índice elegido.
## Cancelar (B) equivale a la última opción, como el `case 127` de los guiones de
## pokeruby. Con dos opciones el menú responde "Y"/"N"; con más, el índice.
func _elegir_opcion(texto: String, opciones: PackedStringArray, en_esquina: bool = false) -> int:
	var dialogo: NinePatchRect = nodo_administrador.cuadro_dialogo
	# preguntaSiNo() exige el cuadro en IDLE o ESPERANDO_REINGRESO.
	dialogo.cerrar()
	if en_esquina:
		dialogo.fijar_menu_en_esquina()
	dialogo.preguntaSiNo(tr(texto), opciones)
	while true:
		var datos: Array = await dialogo.comando_ejecutado
		if datos.size() >= 2 and str(datos[0]) == "respuesta_confirmacion":
			var parametros: Array = datos[1]
			var respuesta := str(parametros[0]) if not parametros.is_empty() else "N"
			if respuesta == "Y":
				return 0
			if respuesta.is_valid_int():
				return clampi(int(respuesta), 0, opciones.size() - 1)
			return opciones.size() - 1
	return opciones.size() - 1


## Muestra la pregunta con menú SÍ/NO y devuelve true si se eligió SÍ.
func _preguntar_si_no(texto: String) -> bool:
	var dialogo: NinePatchRect = nodo_administrador.cuadro_dialogo
	# preguntaSiNo() exige el cuadro en IDLE o ESPERANDO_REINGRESO.
	dialogo.cerrar()
	dialogo.preguntaSiNo(tr(texto))
	var respuesta: String = ""
	while respuesta.is_empty():
		var datos: Array = await dialogo.comando_ejecutado
		if datos.size() >= 2 and str(datos[0]) == "respuesta_confirmacion":
			var parametros: Array = datos[1]
			respuesta = str(parametros[0]) if not parametros.is_empty() else "N"
	return respuesta == "Y"

## npc_regalo_objeto.gd
## NPC que regala un objeto una sola vez (scripts de pokeruby con lock, faceplayer,
## goto_if_set FLAG_RECEIVED_*, msgbox, giveitem y setflag):
## - sin `bandera`: id_texto (cuadro abierto) + "¡Obtuvo X!" con fanfarria y la
##   bandera; con `texto_tras_entregar`, ese mensaje a continuación.
## - con `bandera`: id_texto_entregado, o la variante de `textos_entregado` cuya
##   condición se cumpla (CondicionTexto).
## - con `condicion_regalo` sin cumplir: msgbox normal con id_texto_sin_condicion
##   (o id_texto_primera_vez + bandera_primera_vez la primera vez), sin regalo.
## - mochila llena: Common_EventScript_ShowBagIsFull (MOCHILA_LLENA_REGALO) y sin
##   bandera, para volver a intentarlo.
## - con `pregunta_si_no` (msgbox MSGBOX_YESNO antes del giveitem): id_texto es la
##   pregunta; SÍ muestra `id_texto_si` (opcional) y entrega; NO muestra
##   `id_texto_no` y termina sin objeto ni bandera, así que vuelve a preguntar.
## Bloqueo del jugador: patrón de npc_dialogo_condicional.gd.
@tool
extends "res://scripts/npc/npc_base.gd"

const MOTIVO_PAUSA: StringName = &"regalo_objeto"
const TEXTO_MOCHILA_LLENA: String = "MOCHILA_LLENA_REGALO"

## Nombre interno del objeto (tabla Objetos).
@export var objeto: String = ""
@export var cantidad: int = 1
## Bandera de SistemaGuardado (FLAG_RECEIVED_*).
@export var bandera: String = ""
## Texto al hablarle una vez entregado.
@export var id_texto_entregado: String = ""
## Mensaje tras recibir el objeto (vacío: release sin más texto).
@export var texto_tras_entregar: String = ""
## Condición del regalo (CondicionTexto: bandera o "MEDALLA_n"). Vacía = siempre.
@export var condicion_regalo: String = ""
## Texto mientras no se cumple condicion_regalo.
@export var id_texto_sin_condicion: String = ""
## id_texto es una pregunta SÍ/NO (MSGBOX_YESNO) y el regalo solo va con SÍ.
@export var pregunta_si_no: bool = false
## Mensaje tras responder SÍ, antes del objeto (vacío: entrega sin más texto).
@export var id_texto_si: String = ""
## Mensaje tras responder NO (vacío: se cierra el cuadro sin más).
@export var id_texto_no: String = ""
## {condición: id_texto} que sustituye a id_texto_entregado (gana la primera).
@export var textos_entregado: Dictionary[String, String] = {}
## 1..8: además de bandera_ocultar / bandera_mostrar, solo visible con esa
## medalla (FLAG_BADGE0n_GET). 0 = sin condición.
@export_range(0, 8) var medalla_requerida: int = 0
## applymovement Common_Movement_FaceOriginalDirection al terminar.
@export var volver_direccion_original: bool = false

signal _mensaje_terminado

var _secuencia_activa: bool = false


func aplicar_bandera_ocultar() -> void:
	super.aplicar_bandera_ocultar()
	if medalla_requerida > 0 and not SistemaGuardado.tiene_medalla(medalla_requerida - 1):
		visible = false


func _volver_a_direccion_base() -> void:
	if volver_direccion_original:
		update_direction(direccion_base)
	else:
		super._volver_a_direccion_base()


func entregado() -> bool:
	return not bandera.is_empty() and SistemaGuardado.get_flag(bandera)


func puede_regalar() -> bool:
	return condicion_regalo.is_empty() or CondicionTexto.cumple(condicion_regalo)


func _consumir_id_texto() -> String:
	if entregado() and not id_texto_entregado.is_empty():
		return CondicionTexto.resolver(textos_entregado, id_texto_entregado)
	if not puede_regalar():
		var texto := super._consumir_id_texto()
		return id_texto_sin_condicion if texto == id_texto and not id_texto_sin_condicion.is_empty() else texto
	if not condicion_regalo.is_empty():
		return id_texto  # la bandera_primera_vez es de los mensajes previos al regalo
	return super._consumir_id_texto()


func _procesar_interaccion() -> void:
	if entregado() or objeto.is_empty() or not puede_regalar():
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
	_regalar()


func _regalar() -> void:
	_secuencia_activa = true
	cambiar_estado(EstadoNPC.INTERACTING)
	if tipo_movimiento != TipoMovimientoNPC.SIN_MOVIMIENTO:
		mirar_jugador()  # faceplayer
	_bloquear_jugador(true)
	var cuadro = nodo_administrador.cuadro_dialogo
	var acepta := true
	if pregunta_si_no:
		acepta = await _preguntar_si_no(_consumir_id_texto())
		var respuesta := id_texto_si if acepta else id_texto_no
		if not respuesta.is_empty():
			cuadro.mostrar(tr(respuesta), true, false, _mensaje_terminado.emit)
			await _mensaje_terminado
	else:
		cuadro.mostrar(tr(_consumir_id_texto()), true, false, _mensaje_terminado.emit)
		await _mensaje_terminado
	var siguiente := ""
	if acepta:
		var resultado: Dictionary = SistemaGuardado.dar_objeto_jugador(objeto, cantidad)
		if bool(resultado.get("exito", false)):
			await mostrar_objeto_recibido(objeto)
			SistemaGuardado.set_flag(bandera, true)
			siguiente = texto_tras_entregar
		else:
			siguiente = TEXTO_MOCHILA_LLENA
	if not siguiente.is_empty():
		continuar_dialogo(tr(siguiente), true, _mensaje_terminado.emit)
		await _mensaje_terminado
	cuadro.cerrar()
	_bloquear_jugador(false)
	_volver_a_direccion_base()
	_secuencia_activa = false
	cambiar_estado(EstadoNPC.IDLE)


## Muestra la pregunta con menú SÍ/NO y devuelve true si se eligió SÍ (cancelar
## equivale a NO). Mismo patrón que npc_dialogo_condicional.gd.
func _preguntar_si_no(clave: String) -> bool:
	var dialogo: NinePatchRect = nodo_administrador.cuadro_dialogo
	# preguntaSiNo() exige el cuadro en IDLE o ESPERANDO_REINGRESO.
	dialogo.cerrar()
	dialogo.preguntaSiNo(tr(clave))
	var respuesta: String = ""
	while respuesta.is_empty():
		var datos: Array = await dialogo.comando_ejecutado
		if datos.size() >= 2 and str(datos[0]) == "respuesta_confirmacion":
			var parametros: Array = datos[1]
			respuesta = str(parametros[0]) if not parametros.is_empty() else "N"
	return respuesta == "Y"


func _bloquear_jugador(activo: bool) -> void:
	Singleton.mantener_pausa(MOTIVO_PAUSA, activo)
	if jugador == null:
		return
	if activo:
		jugador.start_dialog()
	else:
		jugador.end_dialog()
	jugador.no_control = activo

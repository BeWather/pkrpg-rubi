## npc_regalo_diario.gd
## NPC que regala un objeto una vez al día (FLAG_DAILY_* de pokeruby, que
## `dotimebasedevents` limpia al cambiar de día del reloj). Ejemplo: la niña de
## las bayas de la Ruta 111 (Route111_EventScript_1500C5), que da una BAYA FRAMBU.
##
## Guion: si ya regaló hoy → `texto_ya_recibido`. Si no → `texto_regalo`, entrega
## (¡Obtuvo X! con fanfarria), marca el día y dice `texto_despues`.
## Con `texto_si`/`texto_no`, `texto_regalo` es una pregunta SÍ/NO (MSGBOX_YESNO) y
## cada respuesta muestra su texto antes de entregar: en Rubí la BELLA de la RUTA
## 120 regala la BAYA con las dos respuestas (la pregunta solo cambia el texto).
## Con `objetos_segundo_regalo`, tras `texto_despues` entrega otro objeto al azar y dice
## `texto_tras_segundo` (DULCINEA de ARRECÍPOLIS, SootopolisCity_EventScript_KiriGiveBerry:
## una de las BAYAS GRANA a MONLI y después HIGOG o PABAYA). Con `texto_ya_recibido_si` /
## `texto_ya_recibido_no`, `texto_ya_recibido` es una pregunta SÍ/NO (KiriReceivedBerry).
## El día se guarda en el contador `<id_regalo>_dia` de SistemaGuardado.
## Diálogos y bloqueo del jugador: patrón de npc_artesano_vidrio.gd.
@tool
extends "res://scripts/npc/npc_base.gd"

const MOTIVO_PAUSA: StringName = &"regalo_diario"
const SEGUNDOS_DIA: int = 86400

## Identificador persistente del regalo (p. ej. "ruta_111_baya_diaria").
@export var id_regalo: String = ""
## nombre_interno del objeto en la tabla Objetos.
@export var objeto: String = ""
@export var texto_regalo: String = ""
@export var texto_despues: String = ""
## Respuestas de una pregunta SÍ/NO en `texto_regalo` (ambas vacías: sin pregunta).
@export var texto_si: String = ""
@export var texto_no: String = ""
@export var texto_ya_recibido: String = ""
@export var texto_mochila_llena: String = "MOCHILA_LLENA_REGALO"
## Si no está vacío, entrega uno al azar en lugar de `objeto` (random N + addvar,
## p. ej. la niña de la FLORISTERÍA PITIMINÍ: una de las 8 primeras BAYAS).
@export var objetos_aleatorios: PackedStringArray = PackedStringArray()
## Si no está vacío (y objetos_aleatorios sí), entrega `[último dígito del ID del
## jugador % N]` en lugar de uno al azar: `GetPlayerTrainerIdOnesDigit` con un
## `switch` de dos dígitos por objeto (BELLA de la RUTA 120: 0/5 HIGOG, 1/6 WIKI,
## 2/7 ANGO, 3/8 GUAYA y 4/9 PABAYA, con N = 5).
@export var objetos_por_id_entrenador: PackedStringArray = PackedStringArray()
## Segundo regalo, uno al azar (vacío: no hay). Si no cabe se dice `texto_mochila_llena`.
@export var objetos_segundo_regalo: PackedStringArray = PackedStringArray()
@export var texto_tras_segundo: String = ""
## Respuestas si `texto_ya_recibido` es una pregunta SÍ/NO (ambas vacías: sin pregunta).
@export var texto_ya_recibido_si: String = ""
@export var texto_ya_recibido_no: String = ""

## Objeto entregado en la última entrega.
var objeto_entregado: String = ""

## Día actual; se puede sustituir en tests.
var proveedor_dia: Callable = dia_local_actual

signal _mensaje_terminado

var _secuencia_activa: bool = false


## Días transcurridos según la fecha local del sistema (el RTC de Rubí).
static func dia_local_actual() -> int:
	var local := Time.get_datetime_dict_from_system()
	@warning_ignore("integer_division")
	return int(Time.get_unix_time_from_datetime_dict(local)) / SEGUNDOS_DIA


func _clave_dia() -> String:
	return id_regalo + "_dia"


## true si hoy ya lo entregó (FLAG_DAILY_RECEIVED_* activa).
func regalo_entregado_hoy() -> bool:
	var clave := _clave_dia()
	if not SistemaGuardado.datos_vivos.datos_persistentes.contadores.has(clave):
		return false
	return SistemaGuardado.get_contador(clave) == int(proveedor_dia.call())


## ID visible (16 bits) del jugador, como GetPlayerTrainerId: 0 si no hay partida.
func id_jugador() -> int:
	var datos = SistemaGuardado.datos_vivos
	if datos == null or datos.jugador == null:
		return 0
	return int(datos.jugador.get("id", 0)) & 0xFFFF


## Entrega el objeto y marca el día. Devuelve false si no cabe en la mochila.
func entregar_regalo() -> bool:
	objeto_entregado = objeto
	if not objetos_por_id_entrenador.is_empty():
		objeto_entregado = objetos_por_id_entrenador[id_jugador() % 10 % objetos_por_id_entrenador.size()]
	elif not objetos_aleatorios.is_empty():
		objeto_entregado = objetos_aleatorios[randi() % objetos_aleatorios.size()]
	var resultado: Dictionary = SistemaGuardado.dar_objeto_jugador(objeto_entregado, 1)
	if not bool(resultado.get("exito", false)):
		return false
	SistemaGuardado.set_contador(_clave_dia(), int(proveedor_dia.call()))
	return true


func _procesar_interaccion() -> void:
	interrupcion_pendiente = false
	if _secuencia_activa:
		return
	if nodo_administrador == null or nodo_administrador.cuadro_dialogo == null:
		if jugador and jugador.has_method("esperar_dialogo"):
			jugador.esperar_dialogo(false)
		cambiar_estado(EstadoNPC.IDLE)
		return
	_ejecutar_secuencia()


func _ejecutar_secuencia() -> void:
	_secuencia_activa = true
	cambiar_estado(EstadoNPC.INTERACTING)
	if tipo_movimiento != TipoMovimientoNPC.SIN_MOVIMIENTO:
		mirar_jugador()  # faceplayer
	_bloquear_jugador(true)
	if regalo_entregado_hoy():
		if texto_ya_recibido_si.is_empty() and texto_ya_recibido_no.is_empty():
			await _mostrar_mensaje(texto_ya_recibido)
		else:
			var respuesta_ya := texto_ya_recibido_si if await _preguntar_si_no(texto_ya_recibido) else texto_ya_recibido_no
			if not respuesta_ya.is_empty():
				await _mostrar_mensaje(respuesta_ya)
	else:
		if texto_si.is_empty() and texto_no.is_empty():
			await _mostrar_mensaje(texto_regalo)
		else:
			var respuesta := texto_si if await _preguntar_si_no(texto_regalo) else texto_no
			if not respuesta.is_empty():
				await _mostrar_mensaje(respuesta)
		if entregar_regalo():
			await mostrar_objeto_recibido(objeto_entregado)
			await _mostrar_mensaje(texto_despues)
			if not objetos_segundo_regalo.is_empty():
				if entregar_segundo_regalo():
					await mostrar_objeto_recibido(objeto_entregado)
					await _mostrar_mensaje(texto_tras_segundo)
				else:
					await _mostrar_mensaje(texto_mochila_llena)
		else:
			await _mostrar_mensaje(texto_mochila_llena)
	_finalizar()


## Segundo objeto al azar de `objetos_segundo_regalo`. Devuelve false si no cabe.
func entregar_segundo_regalo() -> bool:
	objeto_entregado = objetos_segundo_regalo[randi() % objetos_segundo_regalo.size()]
	return bool(SistemaGuardado.dar_objeto_jugador(objeto_entregado, 1).get("exito", false))


func _finalizar() -> void:
	if nodo_administrador and is_instance_valid(nodo_administrador.cuadro_dialogo):
		nodo_administrador.cuadro_dialogo.cerrar()
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


## Espera el botón y deja el cuadro abierto para el siguiente mensaje.
func _mostrar_mensaje(clave: String) -> void:
	continuar_dialogo(tr(clave), true, _mensaje_terminado.emit)
	await _mensaje_terminado


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

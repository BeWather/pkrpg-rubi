## npc_acompanante.gd
## NPC de demostración del seguimiento (npc_base.seguir_a): al hablarle
## pregunta si debe acompañar al jugador; mientras le sigue, si debe dejar de
## hacerlo. Al soltarlo se queda en la celda donde estaba (nuevo hogar).
##
## Mismo patrón que npc_abuela_descanso.gd: sobrescribe _procesar_interaccion()
## para heredar la gestión de interrupción en movimiento; textos inline
## envueltos en tr() y SÍ/NO con cuadro_dialogo.preguntaSiNo().
@tool
extends "res://scripts/npc/npc_base.gd"

## Motivo de pausa global mientras dura la conversación.
const MOTIVO_PAUSA: StringName = &"npc_acompanante"

# Textos de la demo (no son de la ROM).
const TEXTO_OFRECER: String = "¿Quieres que te acompañe?"
const TEXTO_ACEPTA_SEGUIR: String = "¡Genial! Te sigo."
const TEXTO_RECHAZA_SEGUIR: String = "Vale, te espero aquí."
const TEXTO_OFRECER_PARAR: String = "¿Quieres que deje de seguirte?"
const TEXTO_ACEPTA_PARAR: String = "De acuerdo, me quedo por aquí."
const TEXTO_RECHAZA_PARAR: String = "¡Pues sigamos!"

## Emitida por el callback del cuadro de diálogo al avanzar/cerrar un mensaje.
signal _mensaje_terminado

var _secuencia_activa: bool = false

## ============================================================================
## INTERACCIÓN
## ============================================================================

## Punto de entrada tras evento_accion() (inmediato o al terminar un paso).
func _procesar_interaccion() -> void:
	interrupcion_pendiente = false
	if _secuencia_activa:
		return

	if nodo_administrador == null or nodo_administrador.cuadro_dialogo == null:
		_loggear("AdministradorMapa o cuadro de diálogo no disponible")
		if jugador and jugador.has_method("esperar_dialogo"):
			jugador.esperar_dialogo(false)
		cambiar_estado(EstadoNPC.IDLE)
		return

	_ejecutar_secuencia()

func _ejecutar_secuencia() -> void:
	_secuencia_activa = true
	cambiar_estado(EstadoNPC.INTERACTING)
	# Siguiendo es SIN_MOVIMIENTO, pero este NPC siempre se gira para hablar.
	mirar_jugador()
	_bloquear_jugador(true)

	if esta_siguiendo():
		if await _preguntar_si_no(TEXTO_OFRECER_PARAR):
			await _mostrar_mensaje(TEXTO_ACEPTA_PARAR, true)
			dejar_de_seguir()
		else:
			await _mostrar_mensaje(TEXTO_RECHAZA_PARAR, true)
	else:
		if await _preguntar_si_no(TEXTO_OFRECER):
			await _mostrar_mensaje(TEXTO_ACEPTA_SEGUIR, true)
			if jugador != null:
				seguir_a(jugador)
		else:
			await _mostrar_mensaje(TEXTO_RECHAZA_SEGUIR, true)
	_finalizar()

func _finalizar() -> void:
	_bloquear_jugador(false)
	# Sin _volver_a_direccion_base(): siguiendo, debe seguir mirando al jugador.
	_secuencia_activa = false
	cambiar_estado(EstadoNPC.IDLE)

## Bloqueo equivalente al de la abuela de la posada: pausa global + TALKING.
func _bloquear_jugador(activo: bool) -> void:
	Singleton.mantener_pausa(MOTIVO_PAUSA, activo)
	if jugador == null:
		return
	if activo:
		jugador.start_dialog()
	else:
		jugador.end_dialog()
	jugador.no_control = activo

## ============================================================================
## DIÁLOGOS
## ============================================================================

## Muestra un mensaje y espera a que el jugador lo avance.
func _mostrar_mensaje(texto: String, cerrar: bool) -> void:
	nodo_administrador.cuadro_dialogo.mostrar(tr(texto), true, cerrar, _mensaje_terminado.emit)
	await _mensaje_terminado

## Muestra la pregunta con menú SÍ/NO y devuelve true si se eligió SÍ.
## Cancelar en el menú equivale a NO.
func _preguntar_si_no(texto: String) -> bool:
	var dialogo = nodo_administrador.cuadro_dialogo
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

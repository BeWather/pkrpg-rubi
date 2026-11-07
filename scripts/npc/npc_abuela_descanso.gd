## npc_abuela_descanso.gd
## Abuela de la posada de la Ruta 111 que extiende de npc_base.gd.
## Ofrece descansar: si el jugador acepta, funde a negro, suena el jingle de
## curación, restaura el equipo y vuelve a ofrecer descanso (bucle) hasta que
## el jugador responda NO.
##
## Se activa como cualquier NPC (AdministradorMapa llama a evento_accion()); se
## sobrescribe _procesar_interaccion() para heredar la gestión de interrupción
## cuando el NPC está en movimiento. Los textos siguen el patrón de
## enfermera_cp.gd (inline envueltos en tr()); el SÍ/NO usa
## cuadro_dialogo.preguntaSiNo() como controlador_baya.gd.
@tool
extends "res://scripts/npc/npc_base.gd"

## Motivo de pausa global mientras dura la secuencia (bloquea jugador y menú).
const MOTIVO_PAUSA: StringName = &"abuela_descanso"
## Clave en Singleton.TEMAS_REGISTRADOS (BaseDatos/temas_musicales.json).
const TEMA_CURACION: String = "POKEMON_RECUPERADOS"
const DURACION_FUNDIDO: float = 0.5
## Espera en negro si el jingle no pudiera cargarse.
const ESPERA_SIN_JINGLE: float = 1.5

const TEXTO_OFERTA: String = "Ay, ay, ay...\\lTus POKéMON parecen agotados...\\p¿Por qué no descansas aquí?\\lEs lo mejor que puedes hacer, en serio."
const TEXTO_ACEPTA: String = "Exacto.\\lTómate tu tiempo y descansa."
const TEXTO_OFERTA_REPETIDA: String = "Ay, ay, ay...\\lTus POKéMON siguen hechos polvo...\\p¿Por qué no vuelves a descansar aquí?\\pEs lo mejor que puedes hacer, en serio."
const TEXTO_RECHAZA: String = "¿Seguro?\\lYo que tú me lo pensaría dos veces..."

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
	if tipo_movimiento != TipoMovimientoNPC.SIN_MOVIMIENTO:
		mirar_jugador()
	_bloquear_jugador(true)

	var acepta: bool = await _preguntar_si_no(TEXTO_OFERTA)
	while acepta:
		await _mostrar_mensaje(TEXTO_ACEPTA, false)
		await _descansar()
		acepta = await _preguntar_si_no(TEXTO_OFERTA_REPETIDA)

	await _mostrar_mensaje(TEXTO_RECHAZA, true)
	_finalizar()

## Fundido a negro, jingle de curación, restauración del equipo y vuelta.
func _descansar() -> void:
	nodo_administrador.cuadro_dialogo.cerrar()
	await Singleton.transicion("oscurecer", DURACION_FUNDIDO)
	await _reproducir_jingle_curacion()
	SistemaGuardado.curar_equipo_completo()  # PS, estados y PP
	await Singleton.transicion("aclarar", DURACION_FUNDIDO)

func _finalizar() -> void:
	_bloquear_jugador(false)
	_volver_a_direccion_base()
	_secuencia_activa = false
	cambiar_estado(EstadoNPC.IDLE)

## Bloqueo equivalente al de la enfermera: pausa global + estado TALKING.
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
## cerrar = false deja el cuadro abierto (ESPERANDO_CIERRE_EXTERNO).
func _mostrar_mensaje(texto: String, cerrar: bool) -> void:
	nodo_administrador.cuadro_dialogo.mostrar(tr(texto), true, cerrar, _mensaje_terminado.emit)
	await _mensaje_terminado

## Muestra la pregunta con menú SÍ/NO y devuelve true si se eligió SÍ.
## Cancelar en el menú equivale a NO.
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

## ============================================================================
## SONIDO DE CURACIÓN
## ============================================================================

## Fanfarria compartida de npc_base (baja 0,3 s, jingle, sube 0,5 s); aquí se
## espera también la subida antes de aclarar.
func _reproducir_jingle_curacion() -> void:
	if not await reproducir_fanfarria(TEMA_CURACION, true):
		await get_tree().create_timer(ESPERA_SIN_JINGLE).timeout

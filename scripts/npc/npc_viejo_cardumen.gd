## npc_viejo_cardumen.gd
## VIEJO de la entrada de la CUEVA CARDUMEN (pokeruby ShoalCave_LowTideEntranceRoom_EventScript_15E076): cambia
## 4 SAL CARDUMEN + 4 CONCHAS CARDUMEN por una CAMPANA CONCHA.
##
##   lock, faceplayer, dotimebasedevents → repone los ingredientes si es otro día (HistoriaCuevaCardumen)
##   sin 4 de cada: con algún ingrediente, «con cuatro de cada...»; sin ninguno, «¿por qué no me traes...?»
##   con 4 de cada: pregunta SÍ/NO; NO → «Pues vaya...»; SÍ → «Así me gusta...», CAMPANA CONCHA, «Haz que algún
##   POKéMON la sostenga...»
##   mochila sin hueco para la CAMPANA: solo se la hace si al quitar los ingredientes queda un hueco (con 5 o más de
##   cada, no): `checkitemspace` + `checkitem ..., 5` de Rubí. Aquí se quitan los ingredientes, se intenta dar la
##   CAMPANA y, si no cabe, se devuelven: mismo resultado.
## Diálogo SÍ/NO y bloqueo del jugador: patrón de npc_regalo_objeto.gd.
@tool
extends "res://scripts/npc/npc_base.gd"

const MOTIVO_PAUSA: StringName = &"viejo_cardumen"
const TEXTO_PIDE_INGREDIENTES: String = "CUEVA_CARDUMEN_VIEJO_PIDE_INGREDIENTES"
const TEXTO_CUATRO_DE_CADA: String = "CUEVA_CARDUMEN_VIEJO_CUATRO_DE_CADA"
const TEXTO_OFRECE: String = "CUEVA_CARDUMEN_VIEJO_OFRECE"
const TEXTO_HACE: String = "CUEVA_CARDUMEN_VIEJO_HACE"
const TEXTO_ENTREGA: String = "CUEVA_CARDUMEN_VIEJO_ENTREGA"
const TEXTO_NO: String = "CUEVA_CARDUMEN_VIEJO_NO"
const TEXTO_SIN_ESPACIO: String = "CUEVA_CARDUMEN_VIEJO_SIN_ESPACIO"

signal _mensaje_terminado

var _secuencia_activa: bool = false


func _procesar_interaccion() -> void:
	interrupcion_pendiente = false
	if _secuencia_activa:
		return
	if nodo_administrador == null or nodo_administrador.cuadro_dialogo == null:
		if jugador and jugador.has_method("esperar_dialogo"):
			jugador.esperar_dialogo(false)
		cambiar_estado(EstadoNPC.IDLE)
		return
	_hablar()


func _hablar() -> void:
	_secuencia_activa = true
	cambiar_estado(EstadoNPC.INTERACTING)
	mirar_jugador()  # faceplayer
	_bloquear_jugador(true)
	HistoriaCuevaCardumen.reponer_si_nuevo_dia()
	var sal: int = SistemaGuardado.get_cantidad_objeto(HistoriaCuevaCardumen.OBJETO_SAL)
	var conchas: int = SistemaGuardado.get_cantidad_objeto(HistoriaCuevaCardumen.OBJETO_CONCHA)
	var necesarias: int = HistoriaCuevaCardumen.CANTIDAD_DE_CADA
	if sal < necesarias or conchas < necesarias:
		await _mostrar(TEXTO_CUATRO_DE_CADA if sal >= 1 or conchas >= 1 else TEXTO_PIDE_INGREDIENTES)
		_finalizar()
		return
	if not await _preguntar_si_no(TEXTO_OFRECE):
		await _mostrar(TEXTO_NO)
		_finalizar()
		return
	if not hacer_campana():
		await _mostrar(TEXTO_SIN_ESPACIO)
		_finalizar()
		return
	await _mostrar(TEXTO_HACE)
	await mostrar_objeto_recibido(HistoriaCuevaCardumen.OBJETO_CAMPANA)
	await _mostrar(TEXTO_ENTREGA)
	_finalizar()


## removeitem 4 + 4, giveitem CAMPANA CONCHA. Si no cabe, devuelve los ingredientes y da false.
func hacer_campana() -> bool:
	var cantidad: int = HistoriaCuevaCardumen.CANTIDAD_DE_CADA
	if not SistemaGuardado.quitar_objeto_jugador(HistoriaCuevaCardumen.OBJETO_SAL, cantidad):
		return false
	if not SistemaGuardado.quitar_objeto_jugador(HistoriaCuevaCardumen.OBJETO_CONCHA, cantidad):
		SistemaGuardado.dar_objeto_jugador(HistoriaCuevaCardumen.OBJETO_SAL, cantidad)
		return false
	var resultado: Dictionary = SistemaGuardado.dar_objeto_jugador(HistoriaCuevaCardumen.OBJETO_CAMPANA, 1)
	if bool(resultado.get("exito", false)):
		return true
	SistemaGuardado.dar_objeto_jugador(HistoriaCuevaCardumen.OBJETO_SAL, cantidad)
	SistemaGuardado.dar_objeto_jugador(HistoriaCuevaCardumen.OBJETO_CONCHA, cantidad)
	return false


## Mensaje que espera botón y deja el cuadro abierto para el siguiente.
func _mostrar(clave: String) -> void:
	continuar_dialogo(tr(clave), true, _mensaje_terminado.emit)
	await _mensaje_terminado


func _finalizar() -> void:
	nodo_administrador.cuadro_dialogo.cerrar()
	_bloquear_jugador(false)
	_volver_a_direccion_base()
	_secuencia_activa = false
	cambiar_estado(EstadoNPC.IDLE)


## Pregunta con menú SÍ/NO; true si se eligió SÍ (cancelar equivale a NO).
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

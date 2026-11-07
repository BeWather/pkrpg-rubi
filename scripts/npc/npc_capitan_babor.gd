@tool
## npc_capitan_babor.gd
## CAP. BABOR en el PUERTO de CIUDAD PORTUAL (pokeruby SlateportCity_Harbor_EventScript_CaptStern:
## lock + faceplayer). Orden del guion de Rubí:
## 1. MEDALLA_7 (FLAG_BADGE07_GET):
##    a. ya cambió el ESCÁNER en esta visita (VAR_TEMP_1 == 1, se limpia al entrar en el mapa):
##       «Gracias… nos será de gran ayuda».
##    b. lleva el ESCÁNER: lo quiere cambiar por un DIENTE MARINO o una ESCAMA MARINA (menú
##       DIENTE / ESCAMA / SALIR; cancelar = SALIR). Cada opción pide confirmación SÍ/NO; con NO
##       «¿Cuál quieres?» y vuelve al menú. Con SÍ entrega el objeto (mochila llena: aviso, sin
##       perder el ESCÁNER), quita el ESCÁNER, «entregó el ESCÁNER» y marca FLAG_EXCHANGED_SCANNER.
##    c. SYS_GAME_CLEAR: «¡Por fin acabamos de construir el ferry S.S. MAREA!»; si no, «no tardaremos
##       mucho en acabar».
## 2. FLAG_EVIL_TEAM_ESCAPED_STERN_SPOKE: «necesitarías BUCEO».
## 3. FLAG_EVIL_TEAM_ESCAPED_IN_SUBMARINE: «el equipo se fue… BUCEO» y marca la anterior.
## 4. VAR_SLATEPORT_HARBOR_STATE == 2: «¿Por qué querría robar el EQUIPO MAGMA mi submarino?».
## 5. En otro caso: «son los mismos que intentaron robar las PIEZAS DEVON».
## Bloqueo del jugador y diálogo: patrón de npc_dialogo_condicional.gd.
extends "res://scripts/npc/npc_dialogo_condicional.gd"

const TEXTO_MISMOS: String = "PORTUAL_PUERTO_BABOR_MISMOS"
const TEXTO_POR_QUE: String = "PORTUAL_PUERTO_BABOR_POR_QUE"
const TEXTO_ESCAPO_BUCEO: String = "PORTUAL_PUERTO_BABOR_ESCAPO_BUCEO"
const TEXTO_BUCEO: String = "PORTUAL_PUERTO_BABOR_BUCEO"
const TEXTO_FERRY_FALTA: String = "PORTUAL_PUERTO_BABOR_FERRY_FALTA"
const TEXTO_FERRY_TERMINADO: String = "PORTUAL_PUERTO_BABOR_FERRY_TERMINADO"
const TEXTO_ESCANER: String = "PORTUAL_PUERTO_BABOR_ESCANER"
const TEXTO_CAMBIAR_DIENTE: String = "PORTUAL_PUERTO_BABOR_CAMBIAR_DIENTE"
const TEXTO_CAMBIAR_ESCAMA: String = "PORTUAL_PUERTO_BABOR_CAMBIAR_ESCAMA"
const TEXTO_CUAL: String = "PORTUAL_PUERTO_BABOR_CUAL"
const TEXTO_ENTREGO: String = "PORTUAL_PUERTO_BABOR_ENTREGO"
const TEXTO_GRACIAS: String = "PORTUAL_PUERTO_BABOR_GRACIAS"
const TEXTO_NO_CAMBIAR: String = "PORTUAL_PUERTO_BABOR_NO_CAMBIAR"
const TEXTO_MOCHILA_LLENA: String = "MOCHILA_LLENA_REGALO"
const OPCION_DIENTE: String = "PORTUAL_PUERTO_OPCION_DIENTE"
const OPCION_ESCAMA: String = "PORTUAL_PUERTO_OPCION_ESCAMA"
const OPCION_SALIR: String = "PORTUAL_PUERTO_OPCION_SALIR"

## ITEM_SCANNER, ITEM_DEEP_SEA_TOOTH, ITEM_DEEP_SEA_SCALE.
const OBJETO_ESCANER: String = "ESCANER"
const OBJETO_DIENTE: String = "DIENTEMARINO"
const OBJETO_ESCAMA: String = "ESCAMAMARINA"

## FLAG_EXCHANGED_SCANNER.
const BANDERA_ESCANER_CAMBIADO: String = "portual_escaner_cambiado"
## FLAG_EVIL_TEAM_ESCAPED_STERN_SPOKE.
const BANDERA_HABLO_ESCAPE: String = "portual_babor_escape_hablado"
## FLAG_EVIL_TEAM_ESCAPED_IN_SUBMARINE (la misma que usa CIUDAD CALAGUA).
const BANDERA_EQUIPO_ESCAPO: String = "calagua_equipo_escapo"
## VAR_SLATEPORT_HARBOR_STATE (1: escena del submarino pendiente; 2: ya ocurrió).
const CONTADOR_ESTADO_PUERTO: String = "portual_puerto_estado"
const BANDERA_LIGA: String = "SYS_GAME_CLEAR"

## VAR_TEMP_1 == 1: ya se cambió el ESCÁNER desde que se entró en el mapa.
var _escaner_cambiado_en_visita: bool = false


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	var mapa := _obtener_mapa_propio()
	if mapa != null and mapa.has_signal("mapa_activado"):
		mapa.mapa_activado.connect(func(_por_warp: bool) -> void: _escaner_cambiado_en_visita = false)


func _procesar_interaccion() -> void:
	interrupcion_pendiente = false
	if _secuencia_activa:
		return
	if nodo_administrador == null or nodo_administrador.cuadro_dialogo == null:
		if jugador and jugador.has_method("esperar_dialogo"):
			jugador.esperar_dialogo(false)
		cambiar_estado(EstadoNPC.IDLE)
		return
	_conversar()


func _conversar() -> void:
	_secuencia_activa = true
	cambiar_estado(EstadoNPC.INTERACTING)
	mirar_jugador()  # faceplayer
	_bloquear_jugador(true)
	await _guion()
	nodo_administrador.cuadro_dialogo.cerrar()
	_bloquear_jugador(false)
	_volver_a_direccion_base()
	_secuencia_activa = false
	cambiar_estado(EstadoNPC.IDLE)


func _guion() -> void:
	if CondicionTexto.cumple("MEDALLA_7"):
		await _con_medalla()
	elif SistemaGuardado.get_flag(BANDERA_HABLO_ESCAPE):
		await _mensaje(TEXTO_BUCEO)  # NeedDive
	elif SistemaGuardado.get_flag(BANDERA_EQUIPO_ESCAPO):
		SistemaGuardado.set_flag(BANDERA_HABLO_ESCAPE, true)
		await _mensaje(TEXTO_ESCAPO_BUCEO)  # EvilTeamLeftNeedDive
	elif SistemaGuardado.get_contador(CONTADOR_ESTADO_PUERTO) == 2:
		await _mensaje(TEXTO_POR_QUE)  # WhyStealSubmarine
	else:
		await _mensaje(TEXTO_MISMOS)


## CaptSternFerryOrScannerComment.
func _con_medalla() -> void:
	if _escaner_cambiado_en_visita:
		await _mensaje(TEXTO_GRACIAS)  # TradedScanner
	elif _cantidad(OBJETO_ESCANER) >= 1:
		await _proponer_cambio()
	elif SistemaGuardado.get_flag(BANDERA_LIGA):
		await _mensaje(TEXTO_FERRY_TERMINADO)  # FerryFinished
	else:
		await _mensaje(TEXTO_FERRY_FALTA)  # WontBeLongBeforeWeFinishFerry


## AskToTradeScanner / ChooseScannerTrade.
func _proponer_cambio() -> void:
	var pregunta := TEXTO_ESCANER
	var opciones := PackedStringArray([tr(OPCION_DIENTE), tr(OPCION_ESCAMA), tr(OPCION_SALIR)])
	while true:
		var eleccion := await _elegir_opcion(pregunta, opciones)
		if eleccion > 1:
			await _mensaje(TEXTO_NO_CAMBIAR)  # DeclineTrade
			return
		var diente := eleccion == 0
		if not await _preguntar_si_no(TEXTO_CAMBIAR_DIENTE if diente else TEXTO_CAMBIAR_ESCAMA):
			pregunta = TEXTO_CUAL  # ChooseDifferentTrade
			continue
		var objeto := OBJETO_DIENTE if diente else OBJETO_ESCAMA
		var resultado: Dictionary = SistemaGuardado.dar_objeto_jugador(objeto, 1)
		if not bool(resultado.get("exito", false)):
			await _mensaje(TEXTO_MOCHILA_LLENA)  # Common_EventScript_ShowBagIsFull
			return
		await mostrar_objeto_recibido(objeto)
		_quitar_objeto(OBJETO_ESCANER)
		await _mensaje_continuado(TEXTO_ENTREGO)  # HandedScannerToStern
		SistemaGuardado.set_flag(BANDERA_ESCANER_CAMBIADO, true)
		_escaner_cambiado_en_visita = true
		await _mensaje_continuado(TEXTO_GRACIAS)  # TradedScanner
		return


func _mensaje(clave: String) -> void:
	nodo_administrador.cuadro_dialogo.mostrar(tr(clave), true, false, _mensaje_terminado.emit)
	await _mensaje_terminado


## Mensaje a continuación de otro con el cuadro abierto (tras «¡Obtuvo X!»).
func _mensaje_continuado(clave: String) -> void:
	continuar_dialogo(tr(clave), true, _mensaje_terminado.emit)
	await _mensaje_terminado


static func _bolsillo(objeto: String) -> int:
	var datos: Dictionary = SistemaGuardado.obtener_datos_objeto_completos(objeto)
	return int(datos.get("bolsillo_id", 0))


static func _cantidad(objeto: String) -> int:
	return SistemaGuardado.get_cantidad_objeto(objeto, _bolsillo(objeto))


static func _quitar_objeto(objeto: String) -> void:
	SistemaGuardado.quitar_objeto_jugador(objeto, 1, _bolsillo(objeto))

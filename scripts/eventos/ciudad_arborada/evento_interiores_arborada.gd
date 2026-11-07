## evento_interiores_arborada.gd
## Guiones de las casas de CIUDAD ARBORADA con algo más que un msgbox
## (pokeruby data/maps/FortreeCity_House2 y FortreeCity_House4/scripts.inc). Una escena solo
## asigna los nodos que le corresponden:
##
## CASA1 (House1) — NO pasa por aquí: la COMERCIANTE (EventScript_Trader, el intercambio de un
## PIKACHU por SKITTY «SKITIT») la dirige el componente genérico `IntercambioNpc`
## (`scripts/npc/intercambio_npc.gd`, nodo `Eventos/Intercambio`, tabla ARBORADA de
## `BaseDatos/intercambios_npc.json`).
##
## CASA3 (House2) — `oraculo`, la ANCIANA del PODER OCULTO (HiddenPowerGiver): juego de la
## moneda con tres preguntas «¿mano derecha o izquierda?» (multichoice 21: DERECHA = 0,
## IZQUIERDA = 1). Aciertan DERECHA, DERECHA e IZQUIERDA; con un fallo, «te has equivocado» y
## vuelve a empezar la próxima vez. Al acertar las tres da la MT10 PODER OCULTO
## (FLAG_RECEIVED_TM10); si la mochila estaba llena no se marca y se repite el juego
## (FLAG_MET_HIDDEN_POWER_GIVER solo evita repetir el saludo). Con la MT10 ya recibida solo
## explica el movimiento.
##
## CASA5 (House4) — `chico` y `wingull`: el CHICO manda a su WINGULL de recado la primera vez
## (FLAG_WINGULL_SENT_ON_ERRAND): el pájaro baja dos casillas, va a la derecha, y desaparece
## (la bandera FLAG_HIDE_WINGULL_FORTREE_HOUSE ≡ `arborada_wingull_fuera` lo oculta). Lo
## activa hasta que la casa de CIUDAD ALGARIA (MossdeepCity_House2, `EventoCasasAlgaria`) active el correo
## entregado (FLAG_WINGULL_DELIVERED_MAIL) y limpie esa bandera: entonces el chico da la HIERBA MENTAL
## (FLAG_RECEIVED_MENTAL_HERB).
extends EventoGuionizado
class_name EventoInterioresArborada

const MOTIVO_PAUSA: StringName = &"interiores_arborada"

## FLAG_MET_HIDDEN_POWER_GIVER.
const BANDERA_CONOCIDA: String = "arborada_oraculo_conocida"
## FLAG_RECEIVED_TM10.
const BANDERA_MT10: String = "arborada_mt10_recibida"
const OBJETO_MT10: String = "MT10"
## multichoice 21: opciones en orden (DERECHA = 0, IZQUIERDA = 1) y la correcta de cada pregunta.
const CORRECTAS: Array[int] = [0, 0, 1]
const OPCION_DERECHA: String = "ARBORADA_CASA3_OPCION_DERECHA"
const OPCION_IZQUIERDA: String = "ARBORADA_CASA3_OPCION_IZQUIERDA"

## FLAG_WINGULL_SENT_ON_ERRAND.
const BANDERA_ENVIADO: String = "arborada_wingull_enviado"
## FLAG_WINGULL_DELIVERED_MAIL (la activa el WINGULL de la casa 6 de ALGARIA, EventoCasasAlgaria).
const BANDERA_CORREO: String = "arborada_correo_entregado"
## FLAG_RECEIVED_MENTAL_HERB.
const BANDERA_HIERBA: String = "arborada_hierba_mental_recibida"
## FLAG_HIDE_WINGULL_FORTREE_HOUSE: oculta al WINGULL mientras está fuera.
const BANDERA_WINGULL_FUERA: String = "arborada_wingull_fuera"
const OBJETO_HIERBA: String = "HIERBAMENTAL"
## FortreeCity_House4_Movement_WingullExit: walk_fast_down x2, walk_fast_right, face down, delay_8.
const SALIDA_WINGULL: Array[Vector2] = [Vector2.DOWN, Vector2.DOWN, Vector2.RIGHT]
const FOTOGRAMAS_ESPERA_SALIDA: int = 8

const T := "ARBORADA_CASA3_"
const TEXTO_SALUDO: String = T + "SALUDO"
const TEXTO_MONEDA: String = T + "MONEDA"
const TEXTO_MONEDA_2: String = T + "MONEDA_2"
const TEXTO_MONEDA_3: String = T + "MONEDA_3"
const TEXTO_DESPERTADO: String = T + "DESPERTADO"
const TEXTO_PODER_OCULTO: String = T + "PODER_OCULTO"
const TEXTO_FALLO: String = T + "FALLO"
const C := "ARBORADA_CASA5_"
const TEXTO_ENVIA: String = C + "CHICO_ENVIA"
const TEXTO_RECADO: String = C + "CHICO_RECADO"
const TEXTO_VUELTA: String = C + "CHICO_VUELTA"
const TEXTO_AMIGOS: String = C + "CHICO_AMIGOS"
const TEXTO_MOCHILA_LLENA: String = "MOCHILA_LLENA_REGALO"

@export var oraculo: NodePath
@export var chico: NodePath
@export var wingull: NodePath

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var anciana := get_node_or_null(oraculo)
	if anciana != null and anciana.has_signal("hablado"):
		anciana.hablado.connect(_on_oraculo)
	var chaval := get_node_or_null(chico)
	if chaval != null and chaval.has_signal("hablado"):
		chaval.hablado.connect(_on_chico)


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


## lock/lockall al hablarle a un NPC. false si ya hay un guion en curso.
func _empezar(npc: Node2D) -> bool:
	var administrador_npc: Node = npc.nodo_administrador if npc.nodo_administrador != null else _administrador()
	if _en_curso or not comenzar(administrador_npc):
		if not _en_curso and npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return false
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	return true


## multichoice: índice de la opción elegida (cancelar = la última).
func elegir_opcion(clave: String, opciones: PackedStringArray) -> int:
	var dialogo: NinePatchRect = admin.cuadro_dialogo
	dialogo.cerrar()
	dialogo.preguntaSiNo(tr(clave), opciones)
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


## ============================================================================
## CASA3: PODER OCULTO
## ============================================================================

## FortreeCity_House2_EventScript_HiddenPowerGiver.
func _on_oraculo(npc: Node2D) -> void:
	if not _empezar(npc):
		return
	npc.mirar_jugador()
	if SistemaGuardado.get_flag(BANDERA_MT10):
		await mensaje(TEXTO_PODER_OCULTO)  # ExplainHiddenPower
		terminar(false, [npc])
		return
	if not SistemaGuardado.get_flag(BANDERA_CONOCIDA):
		await mensaje(TEXTO_SALUDO)  # HiddenPowersArousedByNature
		SistemaGuardado.set_flag(BANDERA_CONOCIDA, true)
	var preguntas: Array[String] = [TEXTO_MONEDA, TEXTO_MONEDA_2, TEXTO_MONEDA_3]
	for i in preguntas.size():
		var elegida := await elegir_opcion(preguntas[i], PackedStringArray([tr(OPCION_DERECHA), tr(OPCION_IZQUIERDA)]))
		if elegida != CORRECTAS[i]:
			await mensaje(TEXTO_FALLO)  # WrongGuess
			terminar(false, [npc])
			return
	await mensaje(TEXTO_DESPERTADO)
	if not await dar_objeto(npc, OBJETO_MT10):
		await mensaje(TEXTO_MOCHILA_LLENA)  # Common_EventScript_ShowBagIsFull
		terminar(false, [npc])
		return
	SistemaGuardado.set_flag(BANDERA_MT10, true)
	await mensaje(TEXTO_PODER_OCULTO)
	terminar(false, [npc])


## ============================================================================
## CASA5: el WINGULL de recado
## ============================================================================

## FortreeCity_House4_EventScript_Boy.
func _on_chico(npc: Node2D) -> void:
	if not _empezar(npc):
		return
	if SistemaGuardado.get_flag(BANDERA_HIERBA):
		npc.mirar_jugador()
		await mensaje(TEXTO_AMIGOS)  # ReceivedMentalHerb
		terminar(false, [npc])
		return
	if SistemaGuardado.get_flag(BANDERA_CORREO):
		npc.mirar_jugador()
		await _dar_hierba_mental(npc)  # WingullReturned
		return
	if SistemaGuardado.get_flag(BANDERA_ENVIADO):
		npc.mirar_jugador()
		await mensaje(TEXTO_RECADO)  # WingullOnErrand
		terminar(false, [npc])
		return
	# Primera vez (lockall: el chico no se gira): «¡Adelante, POKéMON PÁJARO!» y el WINGULL se va.
	await mensaje(TEXTO_ENVIA)
	SistemaGuardado.set_flag(BANDERA_ENVIADO, true)
	await _enviar_wingull()
	terminar(false, [npc])


## WingullReturned: el WINGULL trae la HIERBA MENTAL y el chico se la da (solo si cabe).
func _dar_hierba_mental(npc: Node2D) -> void:
	await mensaje(TEXTO_VUELTA)
	if not await dar_objeto(npc, OBJETO_HIERBA):
		await mensaje(TEXTO_MOCHILA_LLENA)
		terminar(false, [npc])
		return
	SistemaGuardado.set_flag(BANDERA_HIERBA, true)
	terminar(false, [npc])


## applymovement 3, FortreeCity_House4_Movement_WingullExit + removeobject 3
## (removeobject activa su bandera de objeto: FLAG_HIDE_WINGULL_FORTREE_HOUSE).
func _enviar_wingull() -> void:
	var pajaro := get_node_or_null(wingull)
	if pajaro != null:
		for direccion in SALIDA_WINGULL:
			await caminar(pajaro, direccion, VelocidadPaso.RAPIDO)
		mirar(pajaro, Vector2.DOWN)
		await esperar_fotogramas(FOTOGRAMAS_ESPERA_SALIDA)
	SistemaGuardado.set_flag(BANDERA_WINGULL_FUERA, true)
	if pajaro != null and pajaro.has_method("aplicar_bandera_ocultar"):
		pajaro.aplicar_bandera_ocultar()

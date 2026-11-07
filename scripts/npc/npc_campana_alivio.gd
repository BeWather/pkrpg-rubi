@tool
## npc_campana_alivio.gd
## Mujer del CLUB FAN de CIUDAD PORTUAL que da el CASCABEL ALIVIO (pokeruby
## SlateportCity_PokemonFanClub_EventScript_SootheBellWoman: lock + faceplayer):
## - Con FLAG_RECEIVED_SOOTHE_BELL: «Los POKéMON son muy sensibles a los sentimientos…».
## - Si no: «Me encanta ver POKéMON que quieren a sus ENTRENADORES… vuelve a verme»
##   (siempre) y mira al primer POKéMON del equipo que no sea un HUEVO (GetLeadMonIndex):
##   con GetLeadMonFriendshipScore >= 4 (amistad >= 150) suena SE_PIN, «!» sobre ella,
##   «Tu POKéMON te adora…», el CASCABEL ALIVIO y la bandera. Con la mochila llena,
##   «¡Mala suerte! La MOCHILA está llena» y sin bandera (vuelve a intentarlo).
## Bloqueo del jugador y diálogo: patrón de npc_reportero_museo.gd.
extends "res://scripts/npc/npc_dialogo_condicional.gd"

const CintaEsfuerzo = preload("res://scripts/npc/npc_cinta_esfuerzo.gd")

const TEXTO_PIDE: String = "PORTUAL_CLUB_CAMPANA_PIDE"
const TEXTO_ENTREGA: String = "PORTUAL_CLUB_CAMPANA_ENTREGA"
const TEXTO_YA: String = "PORTUAL_CLUB_CAMPANA_YA"
const TEXTO_MOCHILA_LLENA: String = "MOCHILA_LLENA_REGALO"
## ITEM_SOOTHE_BELL (en la ROM española «CASCABEL ALIVIO»).
const OBJETO: String = "CASCABELALIVIO"
## FLAG_RECEIVED_SOOTHE_BELL.
const BANDERA_RECIBIDA: String = "club_portual_campana_alivio_recibida"
## GetLeadMonFriendshipScore >= 4 (50 = 2, 100 = 3, 150 = 4, 200 = 5, 255 = 6).
const AMISTAD_MINIMA: int = 150


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
	if SistemaGuardado.get_flag(BANDERA_RECIBIDA):
		await _mensaje(TEXTO_YA)
		return
	await _mensaje(TEXTO_PIDE)
	var lider: BasePokemon = CintaEsfuerzo.pokemon_lider(SistemaGuardado.get_equipo())
	if lider == null or lider.felicidad < AMISTAD_MINIMA:
		return
	nodo_administrador.cuadro_dialogo.cerrar()
	Singleton.play_sound.emit("SE_PIN")
	await mostrar_exclamacion()  # Common_Movement_ExclamationMark + Delay48
	nodo_administrador.cuadro_dialogo.mostrar(tr(TEXTO_ENTREGA), true, false, _mensaje_terminado.emit)
	await _mensaje_terminado
	var resultado: Dictionary = SistemaGuardado.dar_objeto_jugador(OBJETO, 1)
	if bool(resultado.get("exito", false)):
		await mostrar_objeto_recibido(OBJETO)
		SistemaGuardado.set_flag(BANDERA_RECIBIDA, true)
	else:
		continuar_dialogo(tr(TEXTO_MOCHILA_LLENA), true, _mensaje_terminado.emit)
		await _mensaje_terminado


func _mensaje(clave: String) -> void:
	nodo_administrador.cuadro_dialogo.mostrar(tr(clave), true, false, _mensaje_terminado.emit)
	await _mensaje_terminado

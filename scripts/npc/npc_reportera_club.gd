@tool
## npc_reportera_club.gd
## REPORTERA de TV del CLUB FAN de CIUDAD PORTUAL (pokeruby
## SlateportCity_PokemonFanClub_EventScript_1ADFA0 en data/event_scripts.s: lock + faceplayer).
## Mira al primer POKéMON del equipo que no sea un HUEVO:
## - con MOTE (LeadMonNicknamed) es la encuesta del programa 3 (PKMN FAN CLUB OPINIONS):
##   «¡Guau! Se ve a la legua que quieres a tu {especie}… se llama {mote}» SÍ/NO; SÍ → «¡Mola!
##   ¡Gracias!», una de tres preguntas al azar (`random 3`) y la pantalla del CHAT FÁCIL, la
##   pregunta «¿Qué significan los POKéMON para ti?», otra pantalla y el cierre.
## - sin mote es la carta del club (programa 1): «parece que hay un vínculo muy fuerte entre tu
##   {especie} y tú» SÍ/NO; SÍ → «¡Hala, qué bien!…», una pantalla del CHAT FÁCIL y el cierre.
## - cancelar cualquier pantalla (o responder NO) → «si de repente te entran unas ganas
##   irresistibles de decírmelo, ven a verme».
## - con la entrevista ya en la cola de la TV sin emitir, o sin sitio en ella (InterviewBefore
##   == 1) → «Me encanta este trabajo».
## Las respuestas van a ProgramasTV (InterviewAfter): la carta (4 palabras, PALABRAS FÁCILES en
## modo REPORTAJE) o las opiniones (dos palabras sueltas, modo ENTREVISTA).
## {especie} es el nombre de la especie y {mote} el mote (bufferleadmonspeciesname / nickname).
## Bloqueo del jugador y diálogo: patrón de npc_reportero_museo.gd.
extends "res://scripts/npc/npc_dialogo_condicional.gd"

const CintaEsfuerzo = preload("res://scripts/npc/npc_cinta_esfuerzo.gd")

const TEXTO_MOTE_INTRO: String = "PORTUAL_CLUB_REPORTERA_MOTE_INTRO"
const TEXTO_MOTE_ACEPTA: String = "PORTUAL_CLUB_REPORTERA_MOTE_ACEPTA"
const TEXTOS_PREGUNTA: Array[String] = [
	"PORTUAL_CLUB_REPORTERA_PREGUNTA_1",
	"PORTUAL_CLUB_REPORTERA_PREGUNTA_2",
	"PORTUAL_CLUB_REPORTERA_PREGUNTA_3",
]
const TEXTO_PREGUNTA_FINAL: String = "PORTUAL_CLUB_REPORTERA_PREGUNTA_4"
const TEXTO_MOTE_FIN: String = "PORTUAL_CLUB_REPORTERA_MOTE_FIN"
const TEXTO_RECHAZA: String = "PORTUAL_CLUB_REPORTERA_RECHAZA"
const TEXTO_YA: String = "PORTUAL_CLUB_REPORTERA_YA"
const TEXTO_INTRO: String = "PORTUAL_CLUB_REPORTERA_INTRO"
const TEXTO_ACEPTA: String = "PORTUAL_CLUB_REPORTERA_ACEPTA"
const TEXTO_FIN: String = "PORTUAL_CLUB_REPORTERA_FIN"

## Índice (0-2) de la pregunta al azar; -1 = `randi() % 3` (tests).
var pregunta_forzada: int = -1
## Sustituye a la pantalla de PALABRAS FÁCILES (tests): recibe el modo y devuelve las
## palabras aceptadas ([] = cancelada).
var editor_palabras: Callable = Callable()


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
	var lider: BasePokemon = CintaEsfuerzo.pokemon_lider(SistemaGuardado.get_equipo())
	if lider == null:
		await _mensaje(TEXTO_YA)
		return
	var sustituciones := {"{especie}": lider.nombre, "{mote}": lider.mote}
	if tiene_mote(lider):
		await _entrevista_con_mote(lider, sustituciones)
	else:
		await _entrevista_sin_mote(lider, sustituciones)


## LeadMonNicknamed: el mote existe y no es el nombre de la especie.
static func tiene_mote(pokemon: BasePokemon) -> bool:
	return not pokemon.mote.strip_edges().is_empty() and pokemon.mote != pokemon.nombre


## Programa 3 (1ADFA0 con LeadMonNicknamed == 1).
func _entrevista_con_mote(lider: BasePokemon, sustituciones: Dictionary) -> void:
	var hueco := ProgramasTV.antes_de_entrevista(ProgramasTV.Tipo.OPINIONES_CLUB)
	if hueco < 0:
		await _mensaje(TEXTO_YA)
		return
	if not await _preguntar_si_no(_texto(TEXTO_MOTE_INTRO, sustituciones)):
		await _mensaje(TEXTO_RECHAZA)  # 1AE0A2
		return
	await _mensaje(TEXTO_MOTE_ACEPTA, {}, false)
	var pregunta: int = pregunta_forzada if pregunta_forzada >= 0 else randi() % TEXTOS_PREGUNTA.size()
	await _mensaje(TEXTOS_PREGUNTA[pregunta], sustituciones)
	var primera := await _chat_facil(PantallaPalabrasFaciles.Modo.ENTREVISTA)  # VAR_0x8004 = 7
	if primera.is_empty():
		await _mensaje(TEXTO_RECHAZA, {}, false)
		return
	await _mensaje(TEXTO_PREGUNTA_FINAL, {}, false)
	var segunda := await _chat_facil(PantallaPalabrasFaciles.Modo.ENTREVISTA)
	if segunda.is_empty():
		await _mensaje(TEXTO_RECHAZA, {}, false)
		return
	await _mensaje(TEXTO_MOTE_FIN, {}, false)
	ProgramasTV.grabar_opiniones_club(hueco, lider, pregunta, [primera[0], segunda[0]])  # InterviewAfter


## Programa 1 (1ADE4D, sin mote).
func _entrevista_sin_mote(lider: BasePokemon, sustituciones: Dictionary) -> void:
	var hueco := ProgramasTV.antes_de_entrevista(ProgramasTV.Tipo.CARTA_CLUB)
	if hueco < 0:
		await _mensaje(TEXTO_YA)  # 1ADED6
		return
	if not await _preguntar_si_no(_texto(TEXTO_INTRO, sustituciones)):
		await _mensaje(TEXTO_RECHAZA)  # 1ADEB9
		return
	await _mensaje(TEXTO_ACEPTA, sustituciones, false)
	var carta := await _chat_facil(PantallaPalabrasFaciles.Modo.REPORTAJE)  # VAR_0x8004 = 5
	if carta.is_empty():
		await _mensaje(TEXTO_RECHAZA, {}, false)
		return
	await _mensaje(TEXTO_FIN, sustituciones, false)  # 1ADEC3
	ProgramasTV.grabar_carta_club(hueco, lider, carta)  # InterviewAfter


## Common_EventScript_ShowEasyChatScreen y, al volver, lock + faceplayer: las palabras
## aceptadas o [] si se cancela.
func _chat_facil(modo_pantalla: PantallaPalabrasFaciles.Modo) -> Array[int]:
	nodo_administrador.cuadro_dialogo.cerrar()
	var palabras: Array[int] = []
	if editor_palabras.is_valid():
		palabras.assign(await editor_palabras.call(modo_pantalla))
	else:
		palabras = await PantallaPalabrasFaciles.escribir(self, modo_pantalla, [], 1)
	mirar_jugador()
	return palabras


func _texto(clave: String, sustituciones: Dictionary) -> String:
	var texto: String = tr(clave)
	for marca in sustituciones:
		texto = texto.replace(str(marca), str(sustituciones[marca]))
	return texto


## SÍ/NO sobre un texto ya traducido y sustituido.
func _preguntar_si_no(texto: String) -> bool:
	var dialogo: NinePatchRect = nodo_administrador.cuadro_dialogo
	# preguntaSiNo() exige el cuadro en IDLE o ESPERANDO_REINGRESO.
	dialogo.cerrar()
	dialogo.preguntaSiNo(texto)
	var respuesta: String = ""
	while respuesta.is_empty():
		var datos: Array = await dialogo.comando_ejecutado
		if datos.size() >= 2 and str(datos[0]) == "respuesta_confirmacion":
			var parametros: Array = datos[1]
			respuesta = str(parametros[0]) if not parametros.is_empty() else "N"
	return respuesta == "Y"


## Escribe un mensaje y espera el botón. `continuar` lo encadena en el cuadro ya abierto;
## tras una pregunta SÍ/NO (o al empezar) se abre uno nuevo.
func _mensaje(clave: String, sustituciones: Dictionary = {}, continuar: bool = true) -> void:
	var texto: String = _texto(clave, sustituciones)
	if continuar:
		continuar_dialogo(texto, true, _mensaje_terminado.emit)
	else:
		nodo_administrador.cuadro_dialogo.mostrar(texto, true, false, _mensaje_terminado.emit)
	await _mensaje_terminado

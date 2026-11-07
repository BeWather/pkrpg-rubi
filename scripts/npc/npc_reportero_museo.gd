@tool
## npc_reportero_museo.gd
## REPORTERO de la 1F del MUSEO OCEÁNICO de CIUDAD PORTUAL (pokeruby
## SlateportCity_OceanicMuseum_1F_EventScript_1ADEE0: lock + faceplayer + `special
## InterviewBefore`). Orden del guion de Rubí:
## 1. Ya entrevistado para este programa, sin emitir todavía, o sin sitio en la cola de la TV
##    (InterviewBefore == 1): «Tengo una buena historia para la tele…».
## 2. Primera vez (FLAG_OCEANIC_MUSEUM_MET_REPORTER sin activar, que se activa): invitación
##    SÍ/NO; después, la versión corta. NO → «cuando tengas algo bueno que contar, ven a verme».
## 3. SÍ → «dime algo interesante…» y abre PALABRAS FÁCILES (modo REPORTAJE, 4 palabras):
##    si se acepta, «¡Qué historia tan edificante!» y la historia va a la cola de la TV
##    (InterviewAfter → ProgramasTV.grabar_novedades: ÚLTIMA HORA); si se cancela,
##    «cuando tengas algo bueno que contar, ven a verme».
## Bloqueo del jugador y diálogo: patrón de npc_dialogo_condicional.gd.
extends "res://scripts/npc/npc_dialogo_condicional.gd"

const TEXTO_INVITA: String = "PORTUAL_MUSEO_REPORTERO_INVITA"
const TEXTO_REPITE: String = "PORTUAL_MUSEO_REPORTERO_REPITE"
const TEXTO_ACEPTA: String = "PORTUAL_MUSEO_REPORTERO_ACEPTA"
const TEXTO_RECHAZA: String = "PORTUAL_MUSEO_REPORTERO_RECHAZA"
const TEXTO_GRACIAS: String = "PORTUAL_MUSEO_REPORTERO_GRACIAS"
const TEXTO_YA: String = "PORTUAL_MUSEO_REPORTERO_YA"

## FLAG_OCEANIC_MUSEUM_MET_REPORTER.
const BANDERA_CONOCIDO: String = "museo_portual_reportero_conocido"

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
	var hueco := ProgramasTV.antes_de_entrevista(ProgramasTV.Tipo.NOVEDADES)
	if hueco < 0:
		await _mensaje(TEXTO_YA, false)  # 1ADF96
	else:
		var primera_vez: bool = not SistemaGuardado.get_flag(BANDERA_CONOCIDO)
		SistemaGuardado.set_flag(BANDERA_CONOCIDO, true)
		if await _preguntar_si_no(TEXTO_INVITA if primera_vez else TEXTO_REPITE):
			await _mensaje(TEXTO_ACEPTA, false)
			var historia := await _chat_facil()  # VAR_0x8004 = 5
			if historia.is_empty():
				await _mensaje(TEXTO_RECHAZA, false)  # 1ADF79
			else:
				await _mensaje(TEXTO_GRACIAS, false)  # 1ADF83
				ProgramasTV.grabar_novedades(hueco, historia)  # InterviewAfter
		else:
			await _mensaje(TEXTO_RECHAZA, false)
	nodo_administrador.cuadro_dialogo.cerrar()
	_bloquear_jugador(false)
	_volver_a_direccion_base()
	_secuencia_activa = false
	cambiar_estado(EstadoNPC.IDLE)


## Common_EventScript_ShowEasyChatScreen y, al volver, lock + faceplayer.
func _chat_facil() -> Array[int]:
	nodo_administrador.cuadro_dialogo.cerrar()
	var palabras: Array[int] = []
	if editor_palabras.is_valid():
		palabras.assign(await editor_palabras.call(PantallaPalabrasFaciles.Modo.REPORTAJE))
	else:
		palabras = await PantallaPalabrasFaciles.escribir(self, PantallaPalabrasFaciles.Modo.REPORTAJE)
	mirar_jugador()
	return palabras


## Escribe un mensaje y espera el botón. `continuar` lo encadena en el cuadro ya abierto;
## tras una pregunta SÍ/NO se abre uno nuevo.
func _mensaje(clave: String, continuar: bool = true) -> void:
	if continuar:
		continuar_dialogo(tr(clave), true, _mensaje_terminado.emit)
	else:
		nodo_administrador.cuadro_dialogo.mostrar(tr(clave), true, false, _mensaje_terminado.emit)
	await _mensaje_terminado

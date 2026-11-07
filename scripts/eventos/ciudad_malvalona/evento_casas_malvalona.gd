## evento_casas_malvalona.gd
## Guiones de las dos casas de CIUDAD MALVALONA (pokeruby MauvilleCity_House1 y
## MauvilleCity_House2). Cada escena asigna solo el NPC que tiene.
##
## - CASA 1, científico (RockSmashHMMan): da la MO06 GOLPE ROCA una sola vez
##   (FLAG_RECEIVED_HM06). Después comenta que de una roca rota puede salir un POKéMON.
## - CASA 2, mujer: con el MONEDERO ya dado, dice que sirve en el CASINO; si no,
##   comenta que podría comprar CARTA PUERTO en CIUDAD PORTUAL y, si el jugador la
##   lleva, se asombra («!») y propone cambiársela por un MONEDERO (SÍ/NO; NO se
##   puede repetir).
extends EventoInteriorMalvalona
class_name EventoCasasMalvalona

const MOTIVO_PAUSA: StringName = &"casas_malvalona"
const OBJETO_MO06: String = "MO06"
const SONIDO_EXCLAMACION: String = "SE_PIN"
## Common_Movement_Delay48.
const FOTOGRAMAS_PAUSA: int = 48

const T1 := "CIUDAD_MALVALONA_CASA1_"
const T2 := "CIUDAD_MALVALONA_CASA2_"
const TEXTO_MO06_ENTREGA: String = T1 + "MO06_ENTREGA"
const TEXTO_MO06_EXPLICA: String = T1 + "MO06_EXPLICA"
const TEXTO_MO06_DESPUES: String = T1 + "MO06_DESPUES"
const TEXTO_SIN_CARTA: String = T2 + "SIN_CARTA"
const TEXTO_CAMBIO_PREGUNTA: String = T2 + "CAMBIO_PREGUNTA"
const TEXTO_CAMBIO_SI: String = T2 + "CAMBIO_SI"
const TEXTO_USA_MONEDERO: String = T2 + "USA_MONEDERO"
const TEXTO_CAMBIO_NO: String = T2 + "CAMBIO_NO"

## Científico de la CASA 1 y mujer de la CASA 2.
@export var cientifico: NodePath
@export var mujer: NodePath


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	escuchar(cientifico, _on_cientifico)
	escuchar(mujer, _on_mujer)


## MauvilleCity_House1_EventScript_RockSmashHMMan.
func _on_cientifico(npc: Node2D) -> void:
	if not empezar_con(npc):
		return
	if SistemaGuardado.get_flag(HistoriaMalvalona.BANDERA_MO06):
		await mensaje(TEXTO_MO06_DESPUES)  # ReceivedRockSmash
		terminar(false, [npc])
		return
	await mensaje(TEXTO_MO06_ENTREGA, false)
	if not await dar_objeto(npc, OBJETO_MO06):
		await mensaje_mochila_llena()
		terminar(false, [npc])
		return
	SistemaGuardado.set_flag(HistoriaMalvalona.BANDERA_MO06, true)
	await mensaje(TEXTO_MO06_EXPLICA)
	terminar(false, [npc])


## MauvilleCity_House2_EventScript_Woman.
func _on_mujer(npc: Node2D) -> void:
	if not empezar_con(npc):
		return
	if SistemaGuardado.get_flag(HistoriaMalvalona.BANDERA_MONEDERO):
		await mensaje(TEXTO_USA_MONEDERO)  # ReceivedCoinCase
		terminar(false, [npc])
		return
	await mensaje(TEXTO_SIN_CARTA)
	if not HistoriaMalvalona.tiene(HistoriaMalvalona.OBJETO_CARTA_PUERTO):
		terminar(false, [npc])
		return
	Singleton.play_sound.emit(SONIDO_EXCLAMACION)  # AskToTradeForHarborMail
	await exclamacion(npc)
	await esperar_fotogramas(FOTOGRAMAS_PAUSA)
	if not await preguntar_si_no(TEXTO_CAMBIO_PREGUNTA):
		await mensaje(TEXTO_CAMBIO_NO)  # DeclineTrade
		terminar(false, [npc])
		return
	await mensaje(TEXTO_CAMBIO_SI, false)  # AcceptTrade
	HistoriaMalvalona.quitar(HistoriaMalvalona.OBJETO_CARTA_PUERTO)
	if not await dar_objeto(npc, HistoriaMalvalona.OBJETO_MONEDERO):
		# Sin sitio: se devuelve la carta y se puede repetir.
		SistemaGuardado.dar_objeto_jugador(HistoriaMalvalona.OBJETO_CARTA_PUERTO)
		await mensaje_mochila_llena()
		terminar(false, [npc])
		return
	SistemaGuardado.set_flag(HistoriaMalvalona.BANDERA_MONEDERO, true)
	await mensaje(TEXTO_USA_MONEDERO)
	terminar(false, [npc])

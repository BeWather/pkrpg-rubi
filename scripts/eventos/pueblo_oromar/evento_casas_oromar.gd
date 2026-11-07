## evento_casas_oromar.gd
## Guiones de cuatro casas de PUEBLO OROMAR (PACIFIDLOG TOWN de Rubí). Cada escena asigna solo el NPC que tiene.
##
## - CASA 2 (PacifidlogTown_House2): HERMANO MENOR del PRESIDENTE del CLUB FAN (GENTLEMAN, FanClubYoungerBrother) y
##   dos AZURILL. Al hablarle (lock + faceplayer): con la bandera de la semana puesta solo dice «en {n} días recibiré
##   MT» (GetDaysUntilPacifidlogTMAvailable: 7 días desde que dio la última); si no, se presenta la primera vez
##   (FLAG_MET_FANCLUB_YOUNGER_BROTHER) y comenta «Tu POKéMON...» según la amistad del primer POKéMON del equipo que no
##   sea un HUEVO (GetLeadMonFriendshipScore): ≥ 4 → MT27 RETORNO, 2 o 3 → «esfuérzate más» sin regalo, < 2 → MT21
##   FRUSTRACIÓN. La MT se da una vez por semana (FLAG_RECEIVED_FANCLUB_TM_THIS_WEEK + VAR_PACIFIDLOG_TM_RECEIVED_DAY);
##   con la mochila llena avisa y no se marca. La bandera semanal se limpia al hablarle cuando ya pasaron los 7 días.
##   Los AZURILL (lock + faceplayer, waitse + playmoncry): el feliz dice «Azu, azuriril...», espera el grito y añade «se
##   lleva muy bien con su ENTRENADOR»; el infeliz, «Azuzú...» y «no se lleva muy bien». Rubí usa el modo 2 de
##   playmoncry en el segundo; el proyecto solo tiene un grito por especie, así que suenan igual.
## - CASA 1 (PacifidlogTown_House4), CHICO: SÍ/NO «¿De dónde vienes?»; SÍ → «¿del PUEBLO SÍ?», NO → «tendrás que venir
##   de algún sitio».
## - CASA 4 (PacifidlogTown_House5), VIGÍA de la ISLA ESPEJISMO (IsMirageIslandPresent): con la isla a la vista dice que
##   hoy la ve, si no, que no (IslaEspejismo.esta_presente).
extends EventoInteriorMalvalona
class_name EventoCasasOromar

const MOTIVO_PAUSA: StringName = &"casas_oromar"
const EvaluadorAmistad = preload("res://scripts/npc/npc_evaluador_amistad.gd")
const CintaEsfuerzo = preload("res://scripts/npc/npc_cinta_esfuerzo.gd")

## FLAG_MET_FANCLUB_YOUNGER_BROTHER.
const BANDERA_CONOCIDO: String = "oromar_hermano_club_conocido"
## FLAG_RECEIVED_FANCLUB_TM_THIS_WEEK.
const BANDERA_MT_SEMANA: String = "oromar_mt_club_semana"
## VAR_PACIFIDLOG_TM_RECEIVED_DAY (día del reloj del juego en que dio la MT).
const CONTADOR_DIA_MT: String = "oromar_mt_club_dia"
const DIAS_ENTRE_MT: int = 7
## ITEM_TM27_RETURN / ITEM_TM21_FRUSTRATION.
const OBJETO_RETORNO: String = "MT27"
const OBJETO_FRUSTRACION: String = "MT21"
## Puntuaciones de amistad (0-6) a partir de las que da cada MT.
const PUNTUACION_RETORNO: int = 4
const PUNTUACION_ESFUERZO: int = 2
## Depuración: fuerza la ISLA ESPEJISMO a la vista (ver IslaEspejismo).
const BANDERA_ISLA_PRESENTE: String = IslaEspejismo.BANDERA_FORZADA
## SPECIES_AZURILL.
const NUMERO_AZURILL: int = 298

const T2 := "OROMAR_CASA2_"
const TEXTO_PRESENTA: String = T2 + "HERMANO_PRESENTA"
const TEXTO_TU_POKEMON: String = T2 + "HERMANO_TU_POKEMON"
const TEXTO_RETORNO: String = T2 + "HERMANO_RETORNO"
const TEXTO_ESFUERZO: String = T2 + "HERMANO_ESFUERZO"
const TEXTO_FRUSTRACION: String = T2 + "HERMANO_FRUSTRACION"
const TEXTO_EXPLICA: String = T2 + "HERMANO_EXPLICA"
const TEXTO_DIAS: String = T2 + "HERMANO_DIAS"
const TEXTO_AZURILL_FELIZ_GRITO: String = T2 + "AZURILL_FELIZ_GRITO"
const TEXTO_AZURILL_FELIZ: String = T2 + "AZURILL_FELIZ"
const TEXTO_AZURILL_INFELIZ_GRITO: String = T2 + "AZURILL_INFELIZ_GRITO"
const TEXTO_AZURILL_INFELIZ: String = T2 + "AZURILL_INFELIZ"
const TEXTO_CHICO_PREGUNTA: String = "OROMAR_CASA1_CHICO_PREGUNTA"
const TEXTO_CHICO_SI: String = "OROMAR_CASA1_CHICO_SI"
const TEXTO_CHICO_NO: String = "OROMAR_CASA1_CHICO_NO"
const TEXTO_VIGIA_SI: String = "OROMAR_CASA4_VIGIA_SI"
const TEXTO_VIGIA_NO: String = "OROMAR_CASA4_VIGIA_NO"

@export var hermano: NodePath
@export var azurill_feliz: NodePath
@export var azurill_infeliz: NodePath
@export var chico: NodePath
@export var vigia: NodePath


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	escuchar(hermano, _on_hermano)
	escuchar(azurill_feliz, _on_azurill_feliz)
	escuchar(azurill_infeliz, _on_azurill_infeliz)
	escuchar(chico, _on_chico)
	escuchar(vigia, _on_vigia)


## ============================================================================
## CASA 2: el HERMANO MENOR del CLUB FAN
## ============================================================================

## Día del reloj del juego (gLocalTime.days).
static func dia_actual() -> int:
	return RelojJuego.dias_desde_inicio()


## GetDaysUntilPacifidlogTMAvailable: 0 si pasaron 7 días desde la última MT; si no, los que faltan.
static func dias_para_mt() -> int:
	var transcurridos: int = dia_actual() - SistemaGuardado.get_contador(CONTADOR_DIA_MT)
	if transcurridos >= DIAS_ENTRE_MT:
		return 0
	return DIAS_ENTRE_MT - transcurridos


## GetLeadMonFriendshipScore (0-6); sin POKéMON, 0.
static func puntuacion_lider() -> int:
	var lider: BasePokemon = CintaEsfuerzo.pokemon_lider(SistemaGuardado.get_equipo())
	if lider == null:
		return 0
	return EvaluadorAmistad.puntuacion_amistad(int(lider.felicidad))


## UpdateFanClubTMFlag: pasada la semana se limpia FLAG_RECEIVED_FANCLUB_TM_THIS_WEEK.
func _actualizar_bandera_semana() -> void:
	if SistemaGuardado.get_flag(BANDERA_MT_SEMANA) and dias_para_mt() == 0:
		SistemaGuardado.set_flag(BANDERA_MT_SEMANA, false)


## FanClubYoungerBrother (lock + faceplayer).
func _on_hermano(npc: Node2D) -> void:
	if not empezar_con(npc):
		return
	_actualizar_bandera_semana()
	if SistemaGuardado.get_flag(BANDERA_MT_SEMANA):
		await mensaje(TEXTO_DIAS, true, {"{n}": dias_para_mt()})  # ComeBackInXDays
		terminar(false, [npc])
		return
	if not SistemaGuardado.get_flag(BANDERA_CONOCIDO):
		await mensaje(TEXTO_PRESENTA)  # FirstMonAssessment
	await mensaje(TEXTO_TU_POKEMON)  # MonAssessment
	SistemaGuardado.set_flag(BANDERA_CONOCIDO, true)
	var puntuacion: int = puntuacion_lider()
	if puntuacion >= PUNTUACION_RETORNO:
		await _dar_mt(npc, TEXTO_RETORNO, OBJETO_RETORNO)  # GiveReturn
		return
	if puntuacion >= PUNTUACION_ESFUERZO:
		await mensaje(TEXTO_ESFUERZO)  # PutInEffort
		terminar(false, [npc])
		return
	await _dar_mt(npc, TEXTO_FRUSTRACION, OBJETO_FRUSTRACION)  # GiveFrustration


## GiveReturn / GiveFrustration: texto, MT y, si cupo, bandera semanal + día + explicación.
func _dar_mt(npc: Node2D, texto: String, objeto: String) -> void:
	await mensaje(texto)
	if not await dar_objeto(npc, objeto):
		await mensaje_mochila_llena()  # Common_EventScript_ShowBagIsFull (sin bandera)
		terminar(false, [npc])
		return
	SistemaGuardado.set_flag(BANDERA_MT_SEMANA, true)
	SistemaGuardado.set_contador(CONTADOR_DIA_MT, dia_actual())  # SetPacifidlogTMReceivedDay
	await mensaje(TEXTO_EXPLICA)
	terminar(false, [npc])


## HappyAzurill (lock + faceplayer, waitse + playmoncry).
func _on_azurill_feliz(npc: Node2D) -> void:
	await _azurill(npc, TEXTO_AZURILL_FELIZ_GRITO, TEXTO_AZURILL_FELIZ)


## UnhappyAzurill (playmoncry modo 2 en Rubí; aquí el mismo grito).
func _on_azurill_infeliz(npc: Node2D) -> void:
	await _azurill(npc, TEXTO_AZURILL_INFELIZ_GRITO, TEXTO_AZURILL_INFELIZ)


func _azurill(npc: Node2D, texto_grito: String, texto_estado: String) -> void:
	if not empezar_con(npc):
		return
	var reproductor: Variant = grito(NUMERO_AZURILL)
	await mensaje(texto_grito)
	await esperar_grito(reproductor)  # waitmoncry
	await mensaje(texto_estado)
	terminar(false, [npc])


## ============================================================================
## CASA 1: el chico de «¿De dónde vienes?»
## ============================================================================

## PacifidlogTown_House4_EventScript_Boy (lock + faceplayer, MSGBOX_YESNO).
func _on_chico(npc: Node2D) -> void:
	if not empezar_con(npc):
		return
	if await preguntar_si_no(TEXTO_CHICO_PREGUNTA):
		await mensaje(TEXTO_CHICO_SI)  # EventScript_Yes
	else:
		await mensaje(TEXTO_CHICO_NO)  # EventScript_No
	terminar(false, [npc])


## ============================================================================
## CASA 4: el vigía de la ISLA ESPEJISMO
## ============================================================================

## IsMirageIslandPresent.
static func isla_espejismo_presente() -> bool:
	return IslaEspejismo.esta_presente()


## PacifidlogTown_House5_EventScript_MirageIslandWatcher (lock + faceplayer).
func _on_vigia(npc: Node2D) -> void:
	if not empezar_con(npc):
		return
	await mensaje(TEXTO_VIGIA_SI if isla_espejismo_presente() else TEXTO_VIGIA_NO)
	terminar(false, [npc])

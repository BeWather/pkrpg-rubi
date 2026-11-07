## evento_interiores_pardal.gd
## Guiones de los interiores de PUEBLO PARDAL con lógica propia (pokeruby
## FallarborTown_House1 / House2 / PokemonCenter_1F). Cada escena asigna solo los NPC
## que tiene; el resto de personajes son NPC normales.
##
## - CASA 2, PROF. COZMO (CozmosHouse_EventScript_ProfCozmo): aparece tras derrotar al
##   EQUIPO MAGMA en el MONTE CENIZO. Si el jugador lleva el METEORITO se lo pide
##   (SÍ/NO; con NO la bandera temporal FLAG_TEMP_2 hace que la próxima vez solo
##   pregunte) y lo cambia por la MT27 RETORNO una sola vez (FLAG_RECEIVED_TM_RETURN).
## - CASA 1, TUTOR DE MOVIMIENTOS (MoveRelearnersHouse_EventScript_MoveRelearner):
##   presentación una vez por visita (FLAG_TEMP_1) y petición de la ESCAMA CORAZÓN.
##   La elección del POKéMON y del movimiento (SelectMoveTutorMon / DisplayMoveTutorMenu)
##   está pendiente: con SÍ se hace la primera pregunta y se termina sin cobrar la ESCAMA.
## - CENTRO POKÉMON, AREDIA (PokemonCenter_1F_EventScript_Lanette): se presenta, se va
##   caminando por la puerta y queda en su casa de la RUTA 114 (clearflag FLAG_HIDE_LANETTE).
extends EventoInteriorMalvalona
class_name EventoInteriorPardal

const MOTIVO_PAUSA: StringName = &"interiores_pardal"

const OBJETO_METEORITO: String = "METEORITO"
const OBJETO_MT27: String = "MT27"
const OBJETO_ESCAMA: String = "ESC_CORAZON"

## FLAG_RECEIVED_TM_RETURN.
const BANDERA_MT27: String = "pardal_mt27_recibida"
## FLAG_TEMP_2: ya le pidió el METEORITO en esta visita (se limpia al cambiar de mapa).
const TEMPORAL_COZMO_PIDIO: String = "pardal_cosmo_pidio_meteorito"
## FLAG_TEMP_1: el tutor ya se presentó en esta visita.
const TEMPORAL_TUTOR_PRESENTADO: String = "pardal_tutor_presentado"
## AREDIA conocida: oculta en el CENTRO POKÉMON (≈ FLAG_HIDE_LANETTE_FALLARBOR) y
## presente en su casa de la RUTA 114 (inversa de FLAG_HIDE_LANETTE).
const BANDERA_AREDIA_CONOCIDA: String = "pardal_aredia_conocida"
const BANDERA_AREDIA_EN_CASA: String = "ruta_114_aredia_en_casa"

const TEXTO_COZMO_SIN_METEORITO: String = "PARDAL_COZMO_SIN_METEORITO"
const TEXTO_COZMO_NOTA: String = "PARDAL_COZMO_NOTA"
const TEXTO_COZMO_PIDE: String = "PARDAL_COZMO_PIDE"
const TEXTO_COZMO_NO: String = "PARDAL_COZMO_NO"
const TEXTO_COZMO_MT: String = "PARDAL_COZMO_MT"
const TEXTO_COZMO_AYUDA: String = "PARDAL_COZMO_AYUDA"
## Common_EventScript_PlayerHandedOverTheItem.
const TEXTO_ENTREGA: String = "CUEVA_GRANITO_MAXIMO_ENTREGA"
const TEXTO_TUTOR_PRESENTACION: String = "PARDAL_TUTOR_PRESENTACION"
const TEXTO_TUTOR_ESCAMA: String = "PARDAL_TUTOR_ESCAMA"
const TEXTO_TUTOR_QUE_POKEMON: String = "PARDAL_TUTOR_QUE_POKEMON"
const TEXTO_TUTOR_VUELVE: String = "PARDAL_TUTOR_VUELVE"
const TEXTO_AREDIA: String = "PARDAL_CENTRO_AREDIA"

const SONIDO_PUERTA: String = "SE_SLIDING_DOOR"
## LanetteExitNorth (jugador mirando al norte) y LanetteExitWest (mirando al oeste).
const SALIDA_AREDIA_NORTE: Array = [R, D, D, L, L, L, L, D, D, D, D]
const SALIDA_AREDIA_OESTE: Array = [D, D, L, L, L, D, D, D, D]
## delay_8.
const FOTOGRAMAS_PAUSA_SALIDA: int = 8

@export var cosmo: NodePath
@export var tutor: NodePath
@export var aredia: NodePath


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	escuchar(cosmo, _on_cosmo)
	escuchar(tutor, _on_tutor)
	escuchar(aredia, _on_aredia)


## ============================================================================
## PROF. COZMO
## ============================================================================

func _on_cosmo(npc: Node2D) -> void:
	if not empezar_con(npc):
		return
	if SistemaGuardado.get_flag(BANDERA_MT27):
		await mensaje(TEXTO_COZMO_AYUDA)  # GaveMeteorite
		terminar(false, [npc])
		return
	if not CondicionTexto.objeto_en_mochila(OBJETO_METEORITO):
		await mensaje(TEXTO_COZMO_SIN_METEORITO)
		terminar(false, [npc])
		return
	# PlayerHasMeteorite: la primera vez de la visita lo nota; después solo lo pide.
	var pregunta: String = TEXTO_COZMO_PIDE
	if not SistemaGuardado.get_flag_temporal(TEMPORAL_COZMO_PIDIO):
		await mensaje(TEXTO_COZMO_SIN_METEORITO)
		pregunta = TEXTO_COZMO_NOTA
	if not await preguntar_si_no(pregunta):
		SistemaGuardado.set_flag_temporal(TEMPORAL_COZMO_PIDIO, true)
		await mensaje(TEXTO_COZMO_NO)  # DeclineGiveMeteorite
		terminar(false, [npc])
		return
	await mensaje(TEXTO_COZMO_MT, false)
	if not await dar_objeto(npc, OBJETO_MT27):
		await mensaje_mochila_llena()
		terminar(false, [npc])
		return
	var datos: Dictionary = SistemaGuardado.obtener_datos_objeto_completos(OBJETO_METEORITO)
	await mensaje_con_fanfarria(TEXTO_ENTREGA, Fanfarria.TEMA_MT_MO,
			{"{objeto}": str(datos.get("nombre", OBJETO_METEORITO))})
	SistemaGuardado.quitar_objeto_jugador(OBJETO_METEORITO, 1, int(datos.get("bolsillo_id", 0)))
	SistemaGuardado.set_flag(BANDERA_MT27, true)
	await mensaje(TEXTO_COZMO_AYUDA)
	terminar(false, [npc])


## ============================================================================
## TUTOR DE MOVIMIENTOS
## ============================================================================

func _on_tutor(npc: Node2D) -> void:
	if not empezar_con(npc):
		return
	if not SistemaGuardado.get_flag_temporal(TEMPORAL_TUTOR_PRESENTADO):
		await mensaje(TEXTO_TUTOR_PRESENTACION)  # ImTheMoveTutor
		SistemaGuardado.set_flag_temporal(TEMPORAL_TUTOR_PRESENTADO, true)
	# AskTeachMove: sin ESCAMA CORAZÓN, o con NO, «vuelve con una ESCAMA CORAZÓN».
	if not CondicionTexto.objeto_en_mochila(OBJETO_ESCAMA) or not await preguntar_si_no(TEXTO_TUTOR_ESCAMA):
		await mensaje(TEXTO_TUTOR_VUELVE)
		terminar(false, [npc])
		return
	# ChooseMon: pendiente SelectMoveTutorMon / DisplayMoveTutorMenu y el cobro de la ESCAMA.
	await mensaje(TEXTO_TUTOR_QUE_POKEMON)
	terminar(false, [npc])


## ============================================================================
## AREDIA (LANETTE)
## ============================================================================

func _on_aredia(npc: Node2D) -> void:
	if not empezar_con(npc):
		return
	await mensaje(TEXTO_AREDIA)
	admin.cuadro_dialogo.cerrar()
	var mirando_oeste: bool = admin.jugador != null and admin.jugador.facing_direction == Vector2.LEFT
	await recorrer(npc, SALIDA_AREDIA_OESTE if mirando_oeste else SALIDA_AREDIA_NORTE)
	await esperar_fotogramas(FOTOGRAMAS_PAUSA_SALIDA)
	Singleton.play_sound.emit(SONIDO_PUERTA)
	npc.visible = false  # removeobject
	SistemaGuardado.set_flag(BANDERA_AREDIA_CONOCIDA, true)
	SistemaGuardado.set_flag(BANDERA_AREDIA_EN_CASA, true)  # clearflag FLAG_HIDE_LANETTE
	terminar(false, [npc])

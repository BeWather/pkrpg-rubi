## evento_gimnasio_arrecipolis.gd
## Guion del LÍDER del GIMNASIO de ARRECÍPOLIS, PLUBIO (WALLACE en inglés), y de sus
## ocho entrenadoras (pokeruby data/maps/SootopolisCity_Gym_1F/scripts.inc). Las celdas
## de Godot son las de Rubí; el suelo de hielo fino lo lleva `HieloFino` (HieloFinoMapa)
## y las entrenadoras están en el sótano (arrecipolis_gimnasio_b1).
##
## PLUBIO (objeto 1, SootopolisCity_Gym_1F_EventScript_Wallace): se presenta, combate y,
## al ganarle, entrega la MEDALLA LLUVIA (FLAG_BADGE08_GET y FLAG_DEFEATED_SOOTOPOLIS_GYM),
## marca a las ocho entrenadoras como vencidas (Common_EventScript_SetGymTrainers,
## VAR_0x8008 = 8) y da la MT03 HIDROPULSO. Si la mochila estaba llena, la MT03 se pide
## hablándole otra vez (goto_if_unset FLAG_RECEIVED_TM_WATER_PULSE). Después, sin la
## MEDALLA PLUMA manda a ARBORADA (goto_if_unset FLAG_BADGE06_GET) y, con ella, habla de
## la LIGA POKéMON.
extends EventoGuionizado
class_name EventoGimnasioArrecipolis

const MOTIVO_PAUSA: StringName = &"gimnasio_arrecipolis"

## TRAINER_WALLACE.
const ENTRENADOR_PLUBIO: int = 272
const MUSICA_LIDER: String = "GYM_LEADER_BATTLE"
const FANFARRIA_MEDALLA: String = "OBTENIDA_MEDALLA"
## FLAG_BADGE08_GET (MEDALLA LLUVIA); también hace de FLAG_DEFEATED_SOOTOPOLIS_GYM.
const INDICE_MEDALLA: int = 7
## FLAG_BADGE06_GET (MEDALLA PLUMA, GIMNASIO de ARBORADA).
const INDICE_MEDALLA_ARBORADA: int = 5
const OBJETO_MT03: String = "MT03"
## FLAG_RECEIVED_TM_WATER_PULSE.
const BANDERA_MT03: String = "arrecipolis_mt03_recibida"
## npc_id de las ocho entrenadoras (la bandera de victoria es npc_id + "_combate").
const ENTRENADORES: Array[String] = [
	"arrecipolis_gimnasio_andrea", "arrecipolis_gimnasio_coro", "arrecipolis_gimnasio_barbara",
	"arrecipolis_gimnasio_brigida", "arrecipolis_gimnasio_tiziana", "arrecipolis_gimnasio_marisa",
	"arrecipolis_gimnasio_cristi", "arrecipolis_gimnasio_olivia",
]
const SUFIJO_COMBATE: String = "_combate"

const T := "ARRECIPOLIS_GIMNASIO_"
const TEXTO_INTRO: String = T + "PLUBIO_INI"
const TEXTO_MEDALLA: String = T + "MEDALLA_RECIBIDA"
const TEXTO_MEDALLA_INFO: String = T + "MEDALLA_INFO"
const TEXTO_MT03: String = T + "MT03"
const TEXTO_POST: String = T + "PLUBIO_POST"
const TEXTO_FALTA_ARBORADA: String = T + "PLUBIO_FALTA_ARBORADA"
const TEXTO_MOCHILA_LLENA: String = "MOCHILA_LLENA_REGALO"

@export var plubio: NodePath

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var lider := get_node_or_null(plubio)
	if lider != null and lider.has_signal("hablado"):
		lider.hablado.connect(_on_plubio)


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


## Common_EventScript_SetGymTrainers (gimnasio 8): settrainerflag de las ocho. Las NPC
## vivas dejan de ver al jugador al sincronizarse con la bandera.
static func marcar_entrenadores_vencidos() -> void:
	for id_npc in ENTRENADORES:
		SistemaGuardado.set_flag(id_npc + SUFIJO_COMBATE, true)


## SootopolisCity_Gym_1F_EventScript_Wallace.
func _on_plubio(npc: Node2D) -> void:
	var administrador_npc: Node = npc.nodo_administrador if npc.nodo_administrador != null else _administrador()
	if _en_curso or not comenzar(administrador_npc):
		if not _en_curso and npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()
	if SistemaGuardado.tiene_medalla(INDICE_MEDALLA):
		await _tras_combate(npc)
		return
	await mensaje(TEXTO_INTRO)
	var resultado := await combatir(ENTRENADOR_PLUBIO, MUSICA_LIDER)
	if resultado != &"victoria":
		terminar(resultado == &"derrota_transferida", [npc])
		return
	# SootopolisCity_Gym_1F_EventScript_WallaceDefeated.
	await mensaje_con_fanfarria(TEXTO_MEDALLA, FANFARRIA_MEDALLA)
	await mensaje(TEXTO_MEDALLA_INFO, false)
	EventoGimnasioPetalia.dar_medalla(INDICE_MEDALLA)  # FLAG_DEFEATED_SOOTOPOLIS_GYM + FLAG_BADGE08_GET
	marcar_entrenadores_vencidos()
	await _dar_mt03(npc)


## Después del combate: la MT03 pendiente, el aviso de ARBORADA o el comentario final.
func _tras_combate(npc: Node2D) -> void:
	if not SistemaGuardado.get_flag(BANDERA_MT03):
		await _dar_mt03(npc)
		return
	if not SistemaGuardado.tiene_medalla(INDICE_MEDALLA_ARBORADA):
		await mensaje(TEXTO_FALTA_ARBORADA)
	else:
		await mensaje(TEXTO_POST)
	terminar(false, [npc])


## SootopolisCity_Gym_1F_EventScript_GiveWaterPulse2: la bandera solo se pone si se entregó.
func _dar_mt03(npc: Node2D) -> void:
	if not await dar_objeto(npc, OBJETO_MT03):
		await mensaje(TEXTO_MOCHILA_LLENA)  # Common_EventScript_ShowBagIsFull
		terminar(false, [npc])
		return
	await mensaje(TEXTO_MT03)
	SistemaGuardado.set_flag(BANDERA_MT03, true)
	terminar(false, [npc])

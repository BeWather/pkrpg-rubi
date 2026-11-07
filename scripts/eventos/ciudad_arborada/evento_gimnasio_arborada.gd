## evento_gimnasio_arborada.gd
## Guion de la LÍDER del GIMNASIO de CIUDAD ARBORADA, ALANA (WINONA en inglés), y de sus
## cuatro entrenadores (pokeruby data/maps/FortreeCity_Gym/scripts.inc). Las celdas de
## Godot son las de Rubí y la escena trae el acertijo de las siete puertas giratorias
## (`PuertasGiratorias`, sRotatingGate_FortreePuzzleConfig).
##
## ALANA (objeto 1, FortreeCity_Gym_EventScript_Winona): se presenta, combate y, al
## ganarle, entrega la MEDALLA PLUMA (FLAG_BADGE06_GET y FLAG_DEFEATED_FORTREE_GYM), marca a
## los cuatro entrenadores como vencidos (Common_EventScript_SetGymTrainers, VAR_0x8008 = 6)
## y da la MT40 GOLPE AÉREO. Si la mochila estaba llena, la MT40 se pide hablándole otra vez
## (goto_if_unset FLAG_RECEIVED_TM_AERIAL_ACE). Después, solo comenta.
##
## Los entrenadores (JARED, TERRELL, KYLEE y WILL) son TRAINER_TYPE_NORMAL: combaten como
## cualquier `npc_entrenador` y no necesitan guion. El guía y las estatuas tampoco.
extends EventoGuionizado
class_name EventoGimnasioArborada

const MOTIVO_PAUSA: StringName = &"gimnasio_arborada"

## TRAINER_WINONA.
const ENTRENADOR_ALANA: int = 270
const MUSICA_LIDER: String = "GYM_LEADER_BATTLE"
const FANFARRIA_MEDALLA: String = "OBTENIDA_MEDALLA"
## FLAG_BADGE06_GET (MEDALLA PLUMA); también hace de FLAG_DEFEATED_FORTREE_GYM.
const INDICE_MEDALLA: int = 5
const OBJETO_MT40: String = "MT40"
## FLAG_RECEIVED_TM_AERIAL_ACE.
const BANDERA_MT40: String = "arborada_mt40_recibida"
## npc_id de los cuatro entrenadores (la bandera de victoria es npc_id + "_combate").
const ENTRENADORES: Array[String] = [
	"ciudad_arborada_gimnasio_javier", "ciudad_arborada_gimnasio_tristan",
	"ciudad_arborada_gimnasio_cloti", "ciudad_arborada_gimnasio_gonzalo",
]
const SUFIJO_COMBATE: String = "_combate"

const T := "ARBORADA_GIMNASIO_"
const TEXTO_INTRO: String = T + "ALANA_INI"
const TEXTO_MEDALLA: String = T + "MEDALLA_RECIBIDA"
const TEXTO_MEDALLA_INFO: String = T + "MEDALLA_INFO"
const TEXTO_MT40: String = T + "MT40"
const TEXTO_POST: String = T + "ALANA_POST"
const TEXTO_MOCHILA_LLENA: String = "MOCHILA_LLENA_REGALO"

@export var alana: NodePath

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var lider := get_node_or_null(alana)
	if lider != null and lider.has_signal("hablado"):
		lider.hablado.connect(_on_alana)


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


## Common_EventScript_SetGymTrainers (gimnasio 6): settrainerflag de los cuatro. Los NPC
## vivos dejan de ver al jugador al sincronizarse con la bandera.
static func marcar_entrenadores_vencidos() -> void:
	for id_npc in ENTRENADORES:
		SistemaGuardado.set_flag(id_npc + SUFIJO_COMBATE, true)


## FortreeCity_Gym_EventScript_Winona.
func _on_alana(npc: Node2D) -> void:
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
	var resultado := await combatir(ENTRENADOR_ALANA, MUSICA_LIDER)
	if resultado != &"victoria":
		terminar(resultado == &"derrota_transferida", [npc])
		return
	# FortreeCity_Gym_EventScript_WinonaDefeated.
	await mensaje_con_fanfarria(TEXTO_MEDALLA, FANFARRIA_MEDALLA)
	await mensaje(TEXTO_MEDALLA_INFO, false)
	EventoGimnasioPetalia.dar_medalla(INDICE_MEDALLA)  # FLAG_DEFEATED_FORTREE_GYM + FLAG_BADGE06_GET
	marcar_entrenadores_vencidos()
	await _dar_mt40(npc)


## Después del combate: la MT40 pendiente o el comentario final.
func _tras_combate(npc: Node2D) -> void:
	if not SistemaGuardado.get_flag(BANDERA_MT40):
		await _dar_mt40(npc)
		return
	await mensaje(TEXTO_POST)
	terminar(false, [npc])


## FortreeCity_Gym_EventScript_GiveAerialAce2: la bandera solo se pone si se entregó.
func _dar_mt40(npc: Node2D) -> void:
	if not await dar_objeto(npc, OBJETO_MT40):
		await mensaje(TEXTO_MOCHILA_LLENA)  # Common_EventScript_ShowBagIsFull
		terminar(false, [npc])
		return
	await mensaje(TEXTO_MT40)
	SistemaGuardado.set_flag(BANDERA_MT40, true)
	terminar(false, [npc])

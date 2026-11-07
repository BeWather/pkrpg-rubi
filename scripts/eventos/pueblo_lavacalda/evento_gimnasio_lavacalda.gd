## evento_gimnasio_lavacalda.gd
## Guion de la LÍDER del GIMNASIO de PUEBLO LAVACALDA, CANDELA (FLANNERY en inglés), y de
## sus cinco entrenadores enterrados (pokeruby data/maps/LavaridgeTown_Gym_1F/scripts.inc).
## Las dos plantas (1F y B1F) comparten escena: la 1F ocupa x = 0..10 y el sótano x = 18..28.
##
## CANDELA (objeto 1, LavaridgeTown_Gym_1F_EventScript_Flannery): se presenta, combate y, al
## ganarle, entrega la MEDALLA CALOR (FLAG_BADGE04_GET), marca a los cinco entrenadores como
## vencidos (Common_EventScript_SetGymTrainers), activa al rival en el pueblo
## (VAR_LAVARIDGE_RIVAL_STATE 1) y da la MT50 SOFOCO. Si la mochila estaba llena, la MT50 se
## pide hablándole otra vez (goto_if_unset FLAG_RECEIVED_TM_OVERHEAT). Después, solo comenta.
##
## ENTRENADORES (LavaridgeTown_Gym_1F_OnTransition → CheckBuryTrainers): los que no se han
## vencido (goto_if_defeated) quedan enterrados en la arena caliente: setobjectmovementtype 63
## es MOVEMENT_TYPE_HIDDEN (TipoMovimientoNPC.OCULTO). Salen de la arena al verte a una
## casilla o al hablarles; los vencidos conservan su tipo de la escena (mirar abajo).
## El guía y las estatuas no necesitan guion.
extends EventoGuionizado
class_name EventoGimnasioLavacalda

const MOTIVO_PAUSA: StringName = &"gimnasio_lavacalda"

## TRAINER_FLANNERY.
const ENTRENADOR_CANDELA: int = 268
const MUSICA_LIDER: String = "GYM_LEADER_BATTLE"
const FANFARRIA_MEDALLA: String = "OBTENIDA_MEDALLA"
## FLAG_BADGE04_GET (MEDALLA CALOR); también hace de FLAG_DEFEATED_LAVARIDGE_GYM.
const INDICE_MEDALLA: int = 3
const OBJETO_MT50: String = "MT50"
## FLAG_RECEIVED_TM_OVERHEAT.
const BANDERA_MT50: String = "lavacalda_mt50_recibida"
## VAR_LAVARIDGE_RIVAL_STATE 1 → el rival espera en el pueblo (FLAG_HIDE_RIVAL_LAVARIDGE_1).
const BANDERA_RIVAL: String = "lavacalda_rival_esperando"
## npc_id de los cinco entrenadores (la bandera de victoria es npc_id + "_combate").
const ENTRENADORES: Array[String] = [
	"pueblo_lavacalda_gimnasio_camilo", "pueblo_lavacalda_gimnasio_zacarias",
	"pueblo_lavacalda_gimnasio_alejo", "pueblo_lavacalda_gimnasio_sole",
	"pueblo_lavacalda_gimnasio_andi",
]
const SUFIJO_COMBATE: String = "_combate"

const T := "LAVACALDA_GIMNASIO_"
const TEXTO_INTRO: String = T + "CANDELA_INI"
const TEXTO_MEDALLA: String = T + "MEDALLA_RECIBIDA"
const TEXTO_MEDALLA_INFO: String = T + "MEDALLA_INFO"
const TEXTO_MT50: String = T + "MT50"
const TEXTO_POST: String = T + "CANDELA_POST"
const TEXTO_MOCHILA_LLENA: String = "MOCHILA_LLENA_REGALO"

@export var candela: NodePath
## Los cinco entrenadores de la escena (npc_entrenador_gimnasio).
@export var entrenadores: Array[NodePath] = []

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var lider := get_node_or_null(candela)
	if lider != null and lider.has_signal("hablado"):
		lider.hablado.connect(_on_candela)
	enterrar_entrenadores()


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


## CheckBuryTrainers: el que no se ha vencido se entierra; el vencido se queda como esté.
func enterrar_entrenadores() -> void:
	for ruta in entrenadores:
		var npc := get_node_or_null(ruta)
		if npc == null:
			continue
		npc.tipo_movimiento = tipo_entrenador(SistemaGuardado.get_flag(str(npc.npc_id) + SUFIJO_COMBATE))


## Tipo de movimiento de un entrenador del gimnasio: enterrado (OCULTO) hasta que se le vence.
static func tipo_entrenador(vencido: bool) -> int:
	return NpcBase.TipoMovimientoNPC.MIRAR_ABAJO if vencido else NpcBase.TipoMovimientoNPC.OCULTO


## Common_EventScript_SetGymTrainers: settrainerflag de los cinco. Los NPC vivos dejan de ver
## al jugador al sincronizarse con la bandera.
static func marcar_entrenadores_vencidos() -> void:
	for id_npc in ENTRENADORES:
		SistemaGuardado.set_flag(id_npc + SUFIJO_COMBATE, true)


## LavaridgeTown_Gym_1F_EventScript_Flannery.
func _on_candela(npc: Node2D) -> void:
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
	var resultado := await combatir(ENTRENADOR_CANDELA, MUSICA_LIDER)
	if resultado != &"victoria":
		terminar(resultado == &"derrota_transferida", [npc])
		return
	# LavaridgeTown_Gym_1F_EventScript_FlanneryDefeated.
	await mensaje_con_fanfarria(TEXTO_MEDALLA, FANFARRIA_MEDALLA)
	await mensaje(TEXTO_MEDALLA_INFO, false)
	EventoGimnasioPetalia.dar_medalla(INDICE_MEDALLA)  # FLAG_DEFEATED_LAVARIDGE_GYM + FLAG_BADGE04_GET
	marcar_entrenadores_vencidos()
	SistemaGuardado.set_flag(BANDERA_RIVAL, true)  # VAR_LAVARIDGE_RIVAL_STATE 1
	await _dar_mt50(npc)


## Después del combate: la MT50 pendiente o el comentario final.
func _tras_combate(npc: Node2D) -> void:
	if not SistemaGuardado.get_flag(BANDERA_MT50):
		await _dar_mt50(npc)
		return
	await mensaje(TEXTO_POST)
	terminar(false, [npc])


## LavaridgeTown_Gym_1F_EventScript_GiveOverheat: la bandera solo se pone si se entregó.
func _dar_mt50(npc: Node2D) -> void:
	if not await dar_objeto(npc, OBJETO_MT50):
		await mensaje(TEXTO_MOCHILA_LLENA)  # Common_EventScript_ShowBagIsFull
		terminar(false, [npc])
		return
	await mensaje(TEXTO_MT50)
	SistemaGuardado.set_flag(BANDERA_MT50, true)
	terminar(false, [npc])

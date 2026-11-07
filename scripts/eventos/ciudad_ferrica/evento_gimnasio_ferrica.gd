## evento_gimnasio_ferrica.gd
## Guion de la LÍDER del GIMNASIO de CIUDAD FÉRRICA, PETRA (ROXANNE en inglés)
## (pokeruby data/maps/RustboroCity_Gym/scripts.inc). La escena es 1:1 con Rubí.
##
## PETRA (objeto 1, RustboroCity_Gym_EventScript_Roxanne): se presenta, combate y,
## al ganarle, entrega la MEDALLA PIEDRA (VAR_RUSTBORO_STATE 1 → HistoriaFerrica) y
## la MT39 TUMBA ROCAS. Si la mochila estaba llena, la MT39 se pide hablándole otra
## vez (goto_if_unset FLAG_RECEIVED_TM_ROCK_TOMB). Después solo da su consejo.
## Los dos entrenadores (JOSÉ y TOMI), el guía y las estatuas no necesitan guion.
extends EventoGuionizado
class_name EventoGimnasioFerrica

const MOTIVO_PAUSA: StringName = &"gimnasio_ferrica"

## TRAINER_ROXANNE.
const ENTRENADOR_PETRA: int = 265
const MUSICA_LIDER: String = "GYM_LEADER_BATTLE"
const FANFARRIA_MEDALLA: String = "OBTENIDA_MEDALLA"
## FLAG_BADGE01_GET (MEDALLA PIEDRA); también hace de FLAG_DEFEATED_RUSTBORO_GYM.
const INDICE_MEDALLA: int = 0
const OBJETO_MT39: String = "MT39"

const T := "FERRICA_GIMNASIO_"
const TEXTO_INTRO: String = T + "PETRA_INI"
const TEXTO_MEDALLA: String = T + "MEDALLA_RECIBIDA"
const TEXTO_MEDALLA_INFO: String = T + "MEDALLA_INFO"
const TEXTO_MT39: String = T + "MT39"
const TEXTO_POST: String = T + "PETRA_POST"
const TEXTO_MOCHILA_LLENA: String = "MOCHILA_LLENA_REGALO"

@export var petra: NodePath

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var npc := get_node_or_null(petra)
	if npc != null and npc.has_signal("hablado"):
		npc.hablado.connect(_on_petra)


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


## RustboroCity_Gym_EventScript_Roxanne.
func _on_petra(npc: Node2D) -> void:
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
	var resultado := await combatir(ENTRENADOR_PETRA, MUSICA_LIDER)
	if resultado != &"victoria":
		terminar(resultado == &"derrota_transferida", [npc])
		return
	# RustboroCity_Gym_EventScript_RoxanneDefeated.
	await mensaje_con_fanfarria(TEXTO_MEDALLA, FANFARRIA_MEDALLA)
	await mensaje(TEXTO_MEDALLA_INFO, false)
	EventoGimnasioPetalia.dar_medalla(INDICE_MEDALLA)  # FLAG_DEFEATED_RUSTBORO_GYM + FLAG_BADGE01_GET
	HistoriaFerrica.vencer_gimnasio()  # VAR_RUSTBORO_STATE 1
	await _dar_mt39(npc)


## Después del combate: la MT39 pendiente o el consejo final.
func _tras_combate(npc: Node2D) -> void:
	if not SistemaGuardado.get_flag(HistoriaFerrica.BANDERA_MT39):
		await _dar_mt39(npc)
		return
	await mensaje(TEXTO_POST)
	terminar(false, [npc])


## RustboroCity_Gym_EventScript_GiveRockTomb.
func _dar_mt39(npc: Node2D) -> void:
	if not await dar_objeto(npc, OBJETO_MT39):
		await mensaje(TEXTO_MOCHILA_LLENA)  # Common_EventScript_ShowBagIsFull
		terminar(false, [npc])
		return
	SistemaGuardado.set_flag(HistoriaFerrica.BANDERA_MT39, true)
	await mensaje(TEXTO_MT39)
	terminar(false, [npc])

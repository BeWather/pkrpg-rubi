## evento_calle_victoria.gd
## BLASCO en la entrada de la CALLE VICTORIA (pokeruby data/maps/VictoryRoad_1F/scripts.inc). Las celdas de
## Godot son las de Rubí.
##
## `blasco` (coord_event (34,3), (34,4) y (34,5) con VAR_VICTORY_ROAD_1F_STATE = 0,
## VictoryRoad_1F_EventScript_WallyTrigger0..2): BLASCO (objeto 4, oculto con
## FLAG_HIDE_WALLY_BATTLE_VICTORY_ROAD) aparece en (31,12), sube por el pasillo hasta la fila del jugador
## (9, 8 o 7 pasos) y da dos pasos a la derecha; el jugador se gira a la izquierda, BLASCO le reta y combaten
## (trainerbattle_no_intro TRAINER_WALLY_1). Si gana el jugador, BLASCO se despide, se queda donde está
## (clearflag FLAG_HIDE_WALLY_BATTLE_VICTORY_ROAD: al hablarle repite la despedida) y se marca
## FLAG_DEFEATED_WALLY_VICTORY_ROAD (`calle_victoria_blasco_vencido`, que es también el VAR del disparador).
## Con una derrota manda el coordinador de derrota y BLASCO vuelve a quedar oculto en su sitio.
##
## OnTransition (VictoryRoad_1F_EventScript_HideWally): con FLAG_DEFEATED_WALLY_VICTORY_ROAD, BLASCO ya no
## está al volver a entrar.
##
## BLASCO de las revanchas (objeto 7, TRAINER_WALLY_3) es un npc_entrenador de la escena (visible con
## SYS_GAME_CLEAR) y no pasa por aquí.
extends EventoGuionizado
class_name EventoCalleVictoria

const MOTIVO_PAUSA: StringName = &"calle_victoria"

## FLAG_DEFEATED_WALLY_VICTORY_ROAD (y VAR_VICTORY_ROAD_1F_STATE = 1).
const BANDERA_BLASCO_VENCIDO: String = "calle_victoria_blasco_vencido"
## Inversa de FLAG_HIDE_WALLY_BATTLE_VICTORY_ROAD (`bandera_mostrar` del NPC).
const BANDERA_BLASCO_VISIBLE: String = "calle_victoria_blasco_visible"
## TRAINER_WALLY_1.
const ENTRENADOR_BLASCO: int = 519
## Celda de aparición de BLASCO (objeto 4).
const CELDA_BLASCO := Vector2i(31, 12)

const TEXTO_ENCUENTRO: String = "CALLE_VICTORIA_BLASCO_ENCUENTRO"
const TEXTO_DESPUES: String = "CALLE_VICTORIA_BLASCO_DESPUES"

## BLASCO del guion (NPCs/BlascoCombate).
@export var blasco: NodePath

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for hijo in get_children():
		if hijo is DisparadorEventoPorTiles:
			hijo.evento_activado.connect(_on_disparador)
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


func _blasco() -> Node2D:
	return get_node_or_null(blasco) as Node2D


static func blasco_vencido() -> bool:
	return SistemaGuardado.get_flag(BANDERA_BLASCO_VENCIDO)


## VictoryRoad_1F_OnTransition: vencido, BLASCO desaparece (setflag FLAG_HIDE_WALLY_BATTLE_VICTORY_ROAD). Sin
## vencerlo (p. ej. tras perder el combate) vuelve oculto a su celda.
func _on_mapa_activado(_por_warp: bool) -> void:
	if _en_curso:
		return
	var npc := _blasco()
	if blasco_vencido():
		SistemaGuardado.set_flag(BANDERA_BLASCO_VISIBLE, false)
		if npc != null:
			npc.visible = false
	elif npc != null and not SistemaGuardado.get_flag(BANDERA_BLASCO_VISIBLE):
		npc.visible = false
		colocar(npc, CELDA_BLASCO)


func _on_disparador(id_evento: StringName) -> void:
	if _en_curso or id_evento != &"blasco" or blasco_vencido():
		return
	await encuentro_blasco()


## VictoryRoad_1F_EventScript_WallyTrigger0..2 + VictoryRoad_1F_EventScript_WallyApproachPlayer.
func encuentro_blasco() -> void:
	var npc := _blasco()
	if npc == null or not comenzar(_administrador()):
		return
	var fila: int = admin.jugador.pos_celda_act.y
	# addobject 4 + applymovement 4, VictoryRoad_1F_Movement_WallyApproachPlayer0..2.
	colocar(npc, CELDA_BLASCO)
	npc.visible = true
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	var pasos: Array = []
	for i in CELDA_BLASCO.y - fila:
		pasos.append(Vector2.UP)
	await recorrer(npc, pasos + [Vector2.RIGHT, Vector2.RIGHT])
	girar_jugador(Vector2.LEFT)  # Common_Movement_WalkInPlaceFastestLeft
	await mensaje(TEXTO_ENCUENTRO)
	var resultado := await combatir(ENTRENADOR_BLASCO)
	if resultado != &"victoria":
		npc.visible = false
		colocar(npc, CELDA_BLASCO)
		terminar(resultado == &"derrota_transferida", [npc])
		return
	await mensaje(TEXTO_DESPUES)
	SistemaGuardado.set_flag(BANDERA_BLASCO_VISIBLE, true)  # clearflag FLAG_HIDE_WALLY_BATTLE_VICTORY_ROAD
	SistemaGuardado.set_flag(BANDERA_BLASCO_VENCIDO, true)  # setflag + setvar VAR_VICTORY_ROAD_1F_STATE, 1
	terminar(false, [npc])

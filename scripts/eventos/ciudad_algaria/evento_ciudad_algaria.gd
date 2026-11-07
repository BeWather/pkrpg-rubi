## evento_ciudad_algaria.gd
## Guion del exterior de CIUDAD ALGARIA (pokeruby data/maps/MossdeepCity/scripts.inc).
## Las celdas de Godot son las de Rubí.
##
## CHICO de la ROCA DEL REY (objeto 9, MossdeepCity_EventScript_KingsRockBoy): lock + faceplayer.
## Si ya la tiene (FLAG_RECEIVED_KINGS_ROCK) solo comenta que coleccionar rocas es raro.
## Si no, ofrece la ROCA DEL REY que le dio MÁXIMO (SÍ/NO). Con NO responde que sí, que es
## una roca rara. Con SÍ la regala («no se lo digas a MÁXIMO»); con la mochila llena avisa
## y puede volver a pedirla.
extends EventoGuionizado
class_name EventoCiudadAlgaria

const MOTIVO_PAUSA: StringName = &"ciudad_algaria"

## FLAG_RECEIVED_KINGS_ROCK.
const BANDERA_ROCA_DEL_REY: String = "algaria_roca_del_rey_recibida"
## ITEM_KINGS_ROCK.
const OBJETO_ROCA: String = "ROCADELREY"
const TEXTO_PREGUNTA: String = "ALGARIA_CHICO_ROCA_PREGUNTA"
const TEXTO_TOMA: String = "ALGARIA_CHICO_ROCA_TOMA"
const TEXTO_YA: String = "ALGARIA_CHICO_ROCA_YA"
const TEXTO_NO: String = "ALGARIA_CHICO_ROCA_NO"
const TEXTO_MOCHILA_LLENA: String = "MOCHILA_LLENA_REGALO"

@export var chico_roca: NodePath

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var npc := get_node_or_null(chico_roca)
	if npc != null and npc.has_signal("hablado"):
		npc.hablado.connect(_on_chico_roca)


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


func _on_chico_roca(npc: Node2D) -> void:
	var administrador_npc: Node = npc.nodo_administrador if npc.nodo_administrador != null else _administrador()
	if _en_curso or not comenzar(administrador_npc):
		if not _en_curso and npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()  # faceplayer
	if SistemaGuardado.get_flag(BANDERA_ROCA_DEL_REY):
		await mensaje(TEXTO_YA)  # ReceivedKingsRock
		terminar(false, [npc])
		return
	if not await preguntar_si_no(TEXTO_PREGUNTA):
		await mensaje(TEXTO_NO)  # DeclineKingsRock
		terminar(false, [npc])
		return
	await mensaje(TEXTO_TOMA)
	if not await dar_objeto(npc, OBJETO_ROCA):
		await mensaje(TEXTO_MOCHILA_LLENA)  # Common_EventScript_ShowBagIsFull
		terminar(false, [npc])
		return
	SistemaGuardado.set_flag(BANDERA_ROCA_DEL_REY, true)
	terminar(false, [npc])

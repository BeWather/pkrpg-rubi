## evento_ruta_121.gd
## Los tres soldados del EQUIPO MAGMA de la RUTA 121 (pokeruby data/maps/Route121/scripts.inc).
## Godot = Rubí + (0,0).
##
## Route121_EventScript_151B25 (coord_events (25,5) a (25,8) con VAR_ROUTE121_STATE == 0): anuncian que
## se van al MONTE PÍRICO y los tres (objetos 12, 13 y 14) caminan ocho casillas al sur y desaparecen.
## removeobject activa FLAG_HIDE_GRUNTS_ROUTE121 y setvar pone VAR_ROUTE121_STATE a 1, siempre a la
## vez: aquí las representa una sola bandera. Ningún guion de Rubí las cambia antes, así que los
## soldados están desde el principio de la partida.
extends EventoGuionizado
class_name EventoRuta121

const MOTIVO_PAUSA: StringName = &"ruta_121"

## FLAG_HIDE_GRUNTS_ROUTE121 + VAR_ROUTE121_STATE == 1.
const BANDERA_SOLDADOS: String = "ruta_121_soldados_ocultos"
const TEXTO_SOLDADOS: String = "RUTA121_SOLDADOS_PIRICO"

## Route121_Movement_151B57 / _151B60 / _151B69.
const SALIDA_SOLDADOS := [
	Vector2.DOWN, Vector2.DOWN, Vector2.DOWN, Vector2.DOWN,
	Vector2.DOWN, Vector2.DOWN, Vector2.DOWN, Vector2.DOWN,
]

@export var soldados: Array[NodePath] = [^"../../NPCs/Soldado1", ^"../../NPCs/Soldado2", ^"../../NPCs/Soldado3"]

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


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


func _on_disparador(_id: StringName) -> void:
	if not SistemaGuardado.get_flag(BANDERA_SOLDADOS):
		await escena_soldados()


## Route121_EventScript_151B25.
func escena_soldados() -> void:
	if not comenzar(_administrador()):
		return
	await mensaje(TEXTO_SOLDADOS)  # msgbox + closemessage
	var tareas: Array[Callable] = []
	var nodos: Array[Node2D] = []
	for ruta in soldados:
		var soldado := get_node(ruta) as Node2D
		nodos.append(soldado)
		tareas.append(recorrer.bind(soldado, SALIDA_SOLDADOS))
	await en_paralelo(tareas)  # applymovement 12, 13 y 14 + waitmovement 0
	SistemaGuardado.set_flag(BANDERA_SOLDADOS, true)
	for soldado in nodos:
		soldado.aplicar_bandera_ocultar()  # removeobject 12, 13 y 14
	terminar(false, nodos)

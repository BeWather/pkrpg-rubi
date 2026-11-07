## evento_centro_espacial.gd
## Guion del CENTRO ESPACIAL de CIUDAD ALGARIA (pokeruby MossdeepCity_SpaceCenter_1F y _2F, una sola escena con la 2F
## apilada encima: Godot (x, y) = Rubí (x, y) en la 1F y (x, y - 15) en la 2F).
##
## MOSTRADOR de lanzamientos (1F, objeto 1, SCIENTIST_1 en (7,2); RocketLaunchCounter): lock + faceplayer +
## dotimebasedevents. Con GetWeekCount = 0 «el despegue es inminente»; con 1 o más, «ha sido todo un éxito, ya son {n}»
## (n = semanas desde el inicio de la partida, RelojJuego.semanas_desde_inicio). Cierra el cuadro y vuelve a mirar hacia
## arriba (Common_Movement_FaceOriginalDirection).
## Los demás NPC del centro son msgbox y los resuelven los componentes genéricos (la PIEDRA SOLAR del MARINERO es un
## `npc_regalo_objeto`).
extends EventoInteriorMalvalona
class_name EventoCentroEspacial

const MOTIVO_PAUSA: StringName = &"centro_espacial"

const TEXTO_INMINENTE: String = "ALGARIA_CENTRO_ESPACIAL_MOSTRADOR_INMINENTE"
const TEXTO_EXITO: String = "ALGARIA_CENTRO_ESPACIAL_MOSTRADOR_EXITO"

@export var mostrador: NodePath


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	escuchar(mostrador, _on_mostrador)


## MossdeepCity_SpaceCenter_1F_EventScript_RocketLaunchCounter.
func _on_mostrador(npc: Node2D) -> void:
	if not empezar_con(npc):
		return
	var semanas: int = RelojJuego.semanas_desde_inicio()
	if semanas == 0:
		await mensaje(TEXTO_INMINENTE)  # NoLaunchesYet
	else:
		await mensaje(TEXTO_EXITO, true, {"{n}": semanas})  # ShowLaunchNumber
	admin.cuadro_dialogo.cerrar()  # closemessage
	mirar(npc, npc.direccion_base)  # Common_Movement_FaceOriginalDirection
	terminar(false, [npc])

## evento_pueblo_pardal.gd
## Guion del exterior de PUEBLO PARDAL (pokeruby data/maps/FallarborTown/scripts.inc).
## Las celdas de Godot son las de Rubí.
##
## AZURILL (objeto 4, FallarborTown_EventScript_Azurill): lock + faceplayer; suena su grito
## (playmoncry) mientras sale su texto y se espera a que acabe (waitmoncry).
extends EventoGuionizado
class_name EventoPuebloPardal

const MOTIVO_PAUSA: StringName = &"pueblo_pardal"

## SPECIES_AZURILL.
const NUMERO_AZURILL: int = 298
const TEXTO_AZURILL: String = "PARDAL_AZURILL"

@export var azurill: NodePath

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var npc := get_node_or_null(azurill)
	if npc != null and npc.has_signal("hablado"):
		npc.hablado.connect(_on_azurill)


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


func _on_azurill(npc: Node2D) -> void:
	var administrador_npc: Node = npc.nodo_administrador if npc.nodo_administrador != null else _administrador()
	if _en_curso or not comenzar(administrador_npc):
		if not _en_curso and npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()  # faceplayer
	var reproductor = grito(NUMERO_AZURILL)  # playmoncry SPECIES_AZURILL, 0
	await mensaje(TEXTO_AZURILL)
	await esperar_grito(reproductor)  # waitmoncry
	terminar(false, [npc])

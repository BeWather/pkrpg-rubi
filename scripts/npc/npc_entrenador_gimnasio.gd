## npc_entrenador_gimnasio.gd
## Entrenador de un GIMNASIO (pokeruby PetalburgCity_Gym_EventScript_Randall…):
## - `trainerbattle_single` con script de continuación: al ganarle emite `vencido`
##   para que el evento del mapa abra las puertas (SlideOpen*RoomDoors).
## - `goto_if_set FLAG_DEFEATED_*_GYM`: tras vencer al LÍDER, el texto posterior
##   pasa a ser texto_post_medalla.
@tool
extends "res://scripts/npc/npc_entrenador.gd"

signal vencido(npc: Node2D)

## Condición (CondicionTexto, p. ej. "MEDALLA_5") del texto posterior alternativo.
@export var condicion_post_medalla: String = ""
@export var texto_post_medalla: String = ""


## ¿Ya se le ganó? (call_if_defeated / goto_if_not_defeated).
func esta_vencido() -> bool:
	return not npc_id.is_empty() and SistemaGuardado.get_flag(npc_id + "_combate")


func _preparar_interaccion_vencido() -> void:
	super._preparar_interaccion_vencido()
	if id_texto == texto_post_combate and not texto_post_medalla.is_empty() \
			and not condicion_post_medalla.is_empty() and CondicionTexto.cumple(condicion_post_medalla):
		id_texto = texto_post_medalla


func _al_ganar_al_entrenador() -> void:
	await super._al_ganar_al_entrenador()
	vencido.emit(self)

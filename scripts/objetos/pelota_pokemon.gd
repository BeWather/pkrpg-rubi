## pelota_pokemon.gd
## POKé BALL del suelo que contiene un POKéMON (ITEM_BALL de pokeruby cuyo script hace givemon, como el
## BELDUM de la casa de MÁXIMO). Reutiliza la escena ow_item.tscn y todo lo de ItemOverworld (grupo NPC,
## celda, bloqueo del paso, bandera_mostrar / bandera_ocultar); solo cambia lo que ocurre al accionarla:
## emite `hablado` y lo resuelve el evento del mapa. Sin nadie escuchando no hace nada.
@tool
extends "res://scripts/ItemOverworld.gd"

signal hablado(pelota: Node2D)


func evento_accion() -> void:
	if not visible or hablado.get_connections().is_empty():
		return
	hablado.emit(self)


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray()

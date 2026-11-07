## npc_sombra_puente.gd
## Objeto que en Rubí está bajo un puente: su sprite queda tapado por las tablas y solo se ve su reflejo
## en el agua (Route120 objeto 36, KECLEON_2, que delata al KECLEON invisible). Aquí no se dibuja el sprite
## (`self_modulate` transparente), pero sigue visible para que ReflexionesAgua proyecte la silueta. No
## tiene guion y no bloquea el paso.
@tool
extends "res://scripts/npc/npc_base.gd"


func _ready() -> void:
	super._ready()
	if not Engine.is_editor_hint() and animated_sprite:
		animated_sprite.self_modulate.a = 0.0


func bloquea_paso() -> bool:
	return false


func evento_accion() -> void:
	pass

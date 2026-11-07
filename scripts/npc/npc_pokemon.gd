## npc_pokemon.gd
## Pokémon del overworld que habla con su grito (lock, faceplayer, waitse,
## playmoncry, msgbox, waitmoncry). Ejemplo: PEEKO en la casa del SR. ARENQUE.
## `tamano_sprite` (npc_base) para fotogramas que no son de 16x22.
@tool
extends "res://scripts/npc/npc_evento.gd"

const RUTA_GRITO: String = "res://Audio/SE/Cries/%03dCry.ogg"

## Número nacional del grito (0 = sin grito).
@export var numero_nacional: int = 0


func _procesar_interaccion() -> void:
	if hablado.get_connections().is_empty():
		reproducir_grito()
	super._procesar_interaccion()


## playmoncry. Devuelve el reproductor (null si no hay grito).
func reproducir_grito() -> AudioStreamPlayer:
	var ruta := RUTA_GRITO % numero_nacional
	if numero_nacional <= 0 or not is_inside_tree() or not ResourceLoader.exists(ruta):
		return null
	var reproductor := AudioStreamPlayer.new()
	reproductor.stream = load(ruta) as AudioStream
	reproductor.finished.connect(reproductor.queue_free)
	add_child(reproductor)
	reproductor.play()
	return reproductor

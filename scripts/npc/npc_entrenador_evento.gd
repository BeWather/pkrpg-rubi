## npc_entrenador_evento.gd
## Entrenador cuyo combate lo dirige un evento del mapa (`trainerbattle_no_intro`
## dentro de un guion de pokeruby; p. ej. la familia ESTRATEGA de la Ruta 111).
##
## No ve al jugador ni lanza la secuencia de entrenador: al hablarle emite
## `hablado` y el evento decide qué hacer. Si nadie escucha la señal se comporta
## como un NPC normal con `id_texto`. Conserva `entrenador_id` para que el editor
## de entrenadores lo encuentre (usos_entrenador.gd) y para precargar su música.
@tool
extends "res://scripts/npc/npc_entrenador.gd"

signal hablado(npc: Node2D)


func _ready() -> void:
	super._ready()
	# Sin exclamación ni visión: el combate lo inicia el evento.
	combate_pendiente = false


func evento_accion() -> void:
	if estado_actual == EstadoNPC.MOVING:
		interrupcion_pendiente = true
		if jugador and jugador.has_method("esperar_dialogo"):
			jugador.esperar_dialogo(true)
		return
	_procesar_interaccion()


func _procesar_interaccion() -> void:
	if hablado.get_connections().is_empty():
		super._procesar_interaccion()
		return
	interrupcion_pendiente = false
	hablado.emit(self)

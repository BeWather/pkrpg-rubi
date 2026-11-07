## npc_evento.gd
## NPC (u objeto) cuya interacción la resuelve el evento del mapa: al hablarle emite
## `hablado` si alguien escucha; si no, se comporta como un `npc_base` normal
## (id_texto). Sirve para el BOLSO de ABEDUL o para cualquier objeto de un guion
## de pokeruby cuyo `script` no es un simple msgbox.
##
## Los fotogramas que no son de 16x22 (POOCHYENA 32x32, BOLSO 16x16…) se indican con
## `tamano_sprite` de npc_base.
@tool
extends "res://scripts/npc/npc_base.gd"

signal hablado(npc: Node2D)


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

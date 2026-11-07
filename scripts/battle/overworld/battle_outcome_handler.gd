extends RefCounted
class_name BattleOutcomeHandler

var _administrador_mapa: Node = null


func _init(administrador_mapa: Node = null) -> void:
	_administrador_mapa = administrador_mapa


func cerrar(nodo_batalla: Node) -> void:
	if is_instance_valid(nodo_batalla):
		nodo_batalla.queue_free()
	if not is_instance_valid(_administrador_mapa):
		return
	var jugador := _administrador_mapa.get("jugador") as Node
	if is_instance_valid(jugador):
		jugador.set("visible", true)
	if _administrador_mapa.has_method("restaurar_musica_mapa_actual"):
		_administrador_mapa.restaurar_musica_mapa_actual()

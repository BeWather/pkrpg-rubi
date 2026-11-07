extends RefCounted
class_name BattleOverworldLock

var _administrador_mapa: Node = null
var _abierto: bool = false
var _jugador_bloqueado: Node = null
var _no_control_previo: bool = false


func _init(administrador_mapa: Node = null) -> void:
	_administrador_mapa = administrador_mapa


func abrir() -> void:
	if _abierto:
		return
	_abierto = true
	_jugador_bloqueado = _obtener_jugador()
	if is_instance_valid(_jugador_bloqueado):
		_no_control_previo = _leer_bloqueo_local(_jugador_bloqueado)
	Singleton.mantener_pausa(&"batalla", true)
	if is_instance_valid(_jugador_bloqueado):
		_jugador_bloqueado.set("no_control", true)


func cerrar() -> void:
	if not _abierto:
		return
	_abierto = false
	Singleton.mantener_pausa(&"batalla", false)
	if is_instance_valid(_jugador_bloqueado):
		_jugador_bloqueado.set("no_control", _no_control_previo)
	_jugador_bloqueado = null
	_no_control_previo = false


func esta_abierto() -> bool:
	return _abierto


func _obtener_jugador() -> Node:
	if not is_instance_valid(_administrador_mapa):
		return null
	return _administrador_mapa.get("jugador") as Node


func _leer_bloqueo_local(jugador: Node) -> bool:
	for propiedad in jugador.get_property_list():
		if propiedad.get("name", "") == "_no_control_local":
			return bool(jugador.get("_no_control_local"))
	return bool(jugador.get("no_control"))

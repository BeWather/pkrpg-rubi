extends RefCounted
class_name BattleDefeatCoordinator

var _administrador_mapa: Node = null


func _init(administrador_mapa: Node = null) -> void:
	_administrador_mapa = administrador_mapa


func recuperar_en_punto_curacion() -> bool:
	Singleton.mantener_pausa(&"derrota", true)
	var jugador: Node = null
	if is_instance_valid(_administrador_mapa):
		jugador = _administrador_mapa.get("jugador") as Node
	if is_instance_valid(jugador):
		jugador.set("no_control", true)

	if not is_instance_valid(SistemaGuardado):
		return _revertir_fallo(jugador)
	SistemaGuardado.curar_equipo_completo()
	# Overworld_ResetStateAfterWhiteOut: la derrota apaga Destello y el CAMINO de BICIS.
	EfectoOscuridadCueva.apagar_destello()
	CaminoBici.apagar()
	if not is_instance_valid(_administrador_mapa) or not _administrador_mapa.has_method("teletransportar_a_punto_curacion"):
		return _revertir_fallo(jugador)
	var inicio_warp: bool = _administrador_mapa.teletransportar_a_punto_curacion()
	if not inicio_warp:
		return _revertir_fallo(jugador)
	return true


func _revertir_fallo(jugador: Node) -> bool:
	Singleton.mantener_pausa(&"derrota", false)
	if is_instance_valid(jugador):
		jugador.set("visible", true)
		jugador.set("no_control", false)
	return false

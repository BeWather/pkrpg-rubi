@tool
class_name DisparadorClimaPorTiles
extends "res://scripts/eventos/disparador_evento_por_tiles.gd"

enum AccionClima {
	CAMBIAR,
	RESTAURAR_MAPA,
}

@export var accion_clima: AccionClima = AccionClima.CAMBIAR:
	set(valor):
		accion_clima = valor
		_actualizar_avisos_clima()
@export var clima_objetivo: DefinicionClima = null:
	set(valor):
		clima_objetivo = valor
		_actualizar_avisos_clima()
@export_range(0.0, 10.0, 0.1) var duracion_transicion: float = 1.0
@export_range(-1.0, 1.0, 0.01) var intensidad: float = -1.0
@export var restaurar_al_salir: bool = false


func _ejecutar_evento() -> bool:
	if _administrador == null:
		return false
	if _administrador.get("mapa_actual") != _mapa:
		return false
	if accion_clima == AccionClima.RESTAURAR_MAPA:
		if not _administrador.has_method("restaurar_clima_mapa"):
			return false
		return bool(_administrador.call("restaurar_clima_mapa", duracion_transicion))
	if not _administrador.has_method("cambiar_clima_overworld"):
		return false
	return bool(_administrador.call(
		"cambiar_clima_overworld",
		clima_objetivo,
		duracion_transicion,
		_mapa,
		intensidad
	))


func _al_abandonar_zona() -> void:
	if restaurar_al_salir and _administrador != null and _administrador.get("mapa_actual") == _mapa and _administrador.has_method("restaurar_clima_mapa"):
		_administrador.call("restaurar_clima_mapa", duracion_transicion)


func _get_configuration_warnings() -> PackedStringArray:
	var avisos := super._get_configuration_warnings()
	if accion_clima == AccionClima.CAMBIAR:
		if clima_objetivo == null:
			avisos.append("Clima Objetivo vacío: se aplicará NINGUNO. Usa ninguno.tres si es intencional.")
		else:
			avisos.append_array(clima_objetivo.obtener_avisos())
	return avisos


func _actualizar_avisos_clima() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		call_deferred("update_configuration_warnings")

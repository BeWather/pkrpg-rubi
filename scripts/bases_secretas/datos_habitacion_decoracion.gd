extends RefCounted
class_name DatosHabitacionDecoracion

static var _datos: Dictionary = {}

static func habitacion(casa: int) -> Dictionary:
	if _datos.is_empty():
		_datos = JSON.parse_string(FileAccess.get_file_as_string("res://BaseDatos/bases_secretas/habitaciones.json"))
	for datos: Dictionary in _datos["habitaciones"]:
		if int(datos["casa"]) == casa:
			return datos.duplicate(true)
	return {}

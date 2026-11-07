@tool
extends RefCounted
class_name DatosGraficosDecoracion

const RUTA_JSON: String = "res://BaseDatos/bases_secretas/graficos_decoracion.json"
static var _decoraciones: Dictionary = {}
static var _cargado: bool = false


static func decoracion(id: int) -> Dictionary:
	_cargar()
	return (_decoraciones.get(id, {}) as Dictionary).duplicate(true)


static func _cargar() -> void:
	if _cargado:
		return
	_cargado = true
	var archivo: FileAccess = FileAccess.open(RUTA_JSON, FileAccess.READ)
	if archivo == null:
		push_error("[DatosGraficosDecoracion] No se pudo abrir %s" % RUTA_JSON)
		return
	var datos: Variant = JSON.parse_string(archivo.get_as_text())
	if not datos is Dictionary or int(datos.get("version", -1)) != 1:
		push_error("[DatosGraficosDecoracion] Versión/formato inválidos")
		return
	var lista: Variant = datos.get("decoraciones", [])
	if not lista is Array or lista.size() != 120:
		push_error("[DatosGraficosDecoracion] Faltan definiciones")
		return
	for item: Variant in lista:
		if not item is Dictionary:
			push_error("[DatosGraficosDecoracion] Registro inválido")
			return
		_decoraciones[int(item.get("id", 0))] = item.duplicate(true)

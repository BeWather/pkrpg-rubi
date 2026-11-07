@tool
extends RefCounted
class_name DatosTextosDecoracion

## Texto visible separado del catálogo mecánico y sus nombres de referencia.
## Sin traducción disponible se usa español oficial, nunca el símbolo/inglés técnico.
const RUTA_JSON: String = "res://BaseDatos/bases_secretas/textos_decoracion.json"
static var _textos: Dictionary = {}
static var _cargado: bool = false


static func decoracion(id: int) -> Dictionary:
	_cargar()
	return (_textos.get(id, {}) as Dictionary).duplicate(true)


static func nombre(id: int) -> String:
	return _traducir(id, "clave_nombre", "nombre_es")


static func descripcion(id: int) -> String:
	return _traducir(id, "clave_descripcion", "descripcion_es")


static func _traducir(id: int, campo_clave: String, campo_es: String) -> String:
	var datos: Dictionary = decoracion(id)
	if datos.is_empty():
		return ""
	var clave: StringName = StringName(str(datos[campo_clave]))
	var traducido: String = str(TranslationServer.translate(clave))
	return str(datos[campo_es]) if traducido == str(clave) or traducido.is_empty() else traducido


static func _cargar() -> void:
	if _cargado:
		return
	_cargado = true
	var archivo: FileAccess = FileAccess.open(RUTA_JSON, FileAccess.READ)
	if archivo == null:
		push_error("[DatosTextosDecoracion] No se pudo abrir %s" % RUTA_JSON)
		return
	var datos: Variant = JSON.parse_string(archivo.get_as_text())
	if not datos is Dictionary or int(datos.get("version", -1)) != 1 or datos.get("idioma") != "es":
		push_error("[DatosTextosDecoracion] Formato/idioma inválidos")
		return
	var lista: Variant = datos.get("decoraciones", [])
	if not lista is Array or lista.size() != 120:
		push_error("[DatosTextosDecoracion] Faltan textos")
		return
	var candidatas: Dictionary = {}
	for i: int in lista.size():
		var item: Variant = lista[i]
		if not item is Dictionary or int(item.get("id", -1)) != i + 1:
			push_error("[DatosTextosDecoracion] ID de texto inválido")
			return
		for campo: String in ["clave_nombre", "clave_descripcion", "nombre_es", "descripcion_es"]:
			if not item.get(campo) is String or str(item[campo]).is_empty():
				push_error("[DatosTextosDecoracion] Texto inválido")
				return
		candidatas[i + 1] = item.duplicate(true)
	_textos = candidatas

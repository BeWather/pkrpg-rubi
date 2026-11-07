@tool
extends RefCounted
class_name DatosPCBase

const RUTA: String = "res://BaseDatos/bases_secretas/pc.json"
static var _textos: Dictionary = {}


static func texto(clave: String) -> String:
	if _textos.is_empty():
		var datos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RUTA))
		for item: Dictionary in datos.get("textos", []):
			_textos[str(item["clave"])] = str(item["texto_es"])
	var traducido: String = str(TranslationServer.translate(StringName(clave)))
	return str(_textos.get(clave, "")) if traducido == clave or traducido.is_empty() else traducido

extends RefCounted
class_name DatosCanjeVidrio

static var _textos: Dictionary = {}


static func texto(clave: String, nombre: String = "", pasos: int = 0) -> String:
	var resultado: String = str(TranslationServer.translate(clave))
	if resultado == clave:
		if _textos.is_empty():
			var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://BaseDatos/bases_secretas/canje_vidrio.json"))
			if datos is Dictionary:
				for registro: Dictionary in datos.get("textos", []): _textos[registro["clave"]] = registro["texto_es"]
		resultado = str(_textos.get(clave, ""))
	return resultado.replace("\\n", "\n").replace("{nombre}", nombre).replace("{pasos}", str(maxi(0, pasos))) \
		.replace("{jugador}", str(SistemaGuardado.datos_vivos.jugador.get("nombre", ""))) \
		.replace("{bolsillo}", "ITEMS" if TranslationServer.get_locale().begins_with("en") else "OBJETOS")


static func nombre_receta(indice: int) -> String:
	var receta: Dictionary = TallerVidrio.RECETAS[indice]
	if receta.get("decoracion", false): return DatosBasesSecretas.nombre_decoracion(int(receta.decoracion_id))
	return str(SistemaGuardado.obtener_datos_objeto_completos(str(receta.objeto)).get("nombre", receta.nombre))

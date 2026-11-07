@tool
extends RefCounted
class_name DatosBasesSecretas

## Catálogo mecánico importado de pokeruby. Las coordenadas son las originales,
## NO coordenadas Godot. Los nombres de referencia NO son traducciones visibles.
const RUTA_JSON: String = "res://BaseDatos/bases_secretas/catalogo.json"
const CATEGORIA_MUNECOS: StringName = &"MUNECOS"
const CATEGORIA_COJINES: StringName = &"COJINES"

static var _catalogo: Dictionary = {}
static var _cargado: bool = false


static func entradas() -> Array[Dictionary]:
	return _lista(&"entradas")


static func interiores() -> Array[Dictionary]:
	return _lista(&"interiores")


static func decoraciones() -> Array[Dictionary]:
	return _lista(&"decoraciones")


static func categorias() -> Array[Dictionary]:
	return _lista(&"categorias")


static func entrada(id: int) -> Dictionary:
	return _por_id(&"entradas", id)


static func interior(id: int) -> Dictionary:
	return _por_id(&"interiores", id)


static func decoracion(id: int) -> Dictionary:
	return _por_id(&"decoraciones", id)


static func nombre_decoracion(id: int) -> String:
	return DatosTextosDecoracion.nombre(id)


static func descripcion_decoracion(id: int) -> String:
	return DatosTextosDecoracion.descripcion(id)


static func capacidad_categoria(categoria: StringName) -> int:
	for datos: Dictionary in categorias():
		if StringName(str(datos["id"])) == categoria:
			return int(datos["capacidad"])
	return 0


static func admite_habitacion(id: int) -> bool:
	var datos: Dictionary = decoracion(id)
	var categoria: StringName = StringName(str(datos.get("categoria", "")))
	return categoria == CATEGORIA_MUNECOS or categoria == CATEGORIA_COJINES


static func _por_id(clave: StringName, id: int) -> Dictionary:
	_cargar()
	var lista: Array = _catalogo.get(clave, [])
	for datos: Dictionary in lista:
		if int(datos.get("id", -1)) == id:
			return datos.duplicate(true)
	return {}


static func _lista(clave: StringName) -> Array[Dictionary]:
	_cargar()
	var resultado: Array[Dictionary] = []
	var lista: Array = _catalogo.get(clave, [])
	for datos: Dictionary in lista:
		resultado.append(datos.duplicate(true))
	return resultado


static func _cargar() -> void:
	if _cargado:
		return
	_cargado = true
	var archivo: FileAccess = FileAccess.open(RUTA_JSON, FileAccess.READ)
	if archivo == null:
		push_error("[DatosBasesSecretas] No se pudo abrir %s" % RUTA_JSON)
		return
	var datos: Variant = JSON.parse_string(archivo.get_as_text())
	if not datos is Dictionary or int(datos.get("version", -1)) != 1:
		push_error("[DatosBasesSecretas] Catálogo inválido: %s" % RUTA_JSON)
		return
	for clave: String in ["entradas", "interiores", "decoraciones", "categorias"]:
		var lista: Variant = datos.get(clave)
		if not lista is Array:
			push_error("[DatosBasesSecretas] Falta la lista %s" % clave)
			return
		for item: Variant in lista:
			if not item is Dictionary:
				push_error("[DatosBasesSecretas] Registro inválido en %s" % clave)
				return
	_catalogo = datos.duplicate(true)

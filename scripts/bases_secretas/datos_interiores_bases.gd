@tool
extends RefCounted
class_name DatosInterioresBases

## Layouts y atributos GBA importados. No resuelve aún superficies del editor ni
## crea warps. Las consultas entregan snapshots; el mapa original permanece intacto.
const RUTA_JSON: String = "res://BaseDatos/bases_secretas/interiores.json"
static var _datos: Dictionary = {}
static var _cargado: bool = false
static var _id_por_atlas: Dictionary = {}


static func interior(id: int) -> Dictionary:
	_cargar()
	var lista: Array = _datos.get("interiores", [])
	if id < 0 or id >= lista.size():
		return {}
	return (lista[id] as Dictionary).duplicate(true)


static func celda(interior_id: int, posicion: Vector2i) -> Dictionary:
	_cargar()
	var lista: Array = _datos.get("interiores", [])
	if interior_id < 0 or interior_id >= lista.size():
		return {}
	var datos: Dictionary = lista[interior_id]
	var ancho: int = int(datos["ancho"])
	if posicion.x < 0 or posicion.y < 0 or posicion.x >= ancho or posicion.y >= int(datos["alto"]):
		return {}
	return (datos["celdas"][posicion.y * ancho + posicion.x] as Dictionary).duplicate(true)


static func metatile(id: int) -> Dictionary:
	_cargar()
	var lista: Array = _datos.get("metatiles", [])
	# La tabla original de bases tiene 2 metatiles primarios y 324 secundarios.
	for datos: Dictionary in lista:
		if int(datos["id"]) == id:
			return datos.duplicate(true)
	return {}


static func ruta_escena(id: int) -> String:
	return str(interior(id).get("escena", ""))


static func atlas_metatile(id: int) -> Vector2i:
	var datos: Dictionary = metatile(id)
	if datos.is_empty():
		return Vector2i(-1, -1)
	var indice: int = int(datos["indice_atlas"])
	@warning_ignore("integer_division")
	return Vector2i(indice % 16, indice / 16)


static func id_desde_atlas(atlas: Vector2i) -> int:
	_cargar()
	return int(_id_por_atlas.get(atlas, -1))


static func _cargar() -> void:
	if _cargado:
		return
	_cargado = true
	var archivo: FileAccess = FileAccess.open(RUTA_JSON, FileAccess.READ)
	if archivo == null:
		push_error("[DatosInterioresBases] No se pudo abrir %s" % RUTA_JSON)
		return
	var datos: Variant = JSON.parse_string(archivo.get_as_text())
	if not datos is Dictionary or int(datos.get("version", -1)) != 1:
		push_error("[DatosInterioresBases] Versión o formato inválido")
		return
	var interiores: Variant = datos.get("interiores", [])
	var metatiles: Variant = datos.get("metatiles", [])
	if not interiores is Array or interiores.size() != 24 or not metatiles is Array:
		push_error("[DatosInterioresBases] Faltan interiores o metatiles")
		return
	for i: int in interiores.size():
		var item: Variant = interiores[i]
		if not item is Dictionary or int(item.get("id", -1)) != i:
			push_error("[DatosInterioresBases] Índice de interior inválido")
			return
		var celdas: Variant = item.get("celdas", [])
		if not celdas is Array or celdas.size() != int(item.get("ancho", 0)) * int(item.get("alto", 0)):
			push_error("[DatosInterioresBases] Dimensiones/celdas incoherentes")
			return
	_datos = datos.duplicate(true)
	for meta: Dictionary in metatiles:
		var indice: int = int(meta["indice_atlas"])
		@warning_ignore("integer_division")
		var atlas: Vector2i = Vector2i(indice % 16, indice / 16)
		_id_por_atlas[atlas] = int(meta["id"])

class_name AliasObjetos
extends RefCounted

## Claves antiguas de objetos (estilo PokeAPI: "kings-rock") -> clave actual
## (`Objetos.nombre_interno`, mayúsculas y en español: "ROCADELREY"). El mapa
## lo genera herramientas/migraciones/renombrar_claves_objetos.py en
## BaseDatos/alias_objetos.json. Se usa al cargar partidas antiguas.

const RUTA: String = "res://BaseDatos/alias_objetos.json"

static var _alias: Dictionary = {}
static var _cargado: bool = false


## Clave actual de `clave`; si no hay alias, la misma clave en mayúsculas.
static func clave_actual(clave: String) -> String:
	var limpia := clave.strip_edges().to_upper()
	_cargar()
	return str(_alias.get(limpia, limpia))


## Migra en sitio los objetos de una mochila guardada
## ({"bolsillos": {"0": {"items": [{nombre_interno, cantidad}]}}}),
## sumando las entradas que pasan a tener la misma clave.
static func migrar_mochila(mochila: Dictionary) -> void:
	var bolsillos: Variant = mochila.get("bolsillos")
	if not (bolsillos is Dictionary):
		return
	for bolsillo in (bolsillos as Dictionary).values():
		if bolsillo is Dictionary and (bolsillo as Dictionary).get("items") is Array:
			bolsillo["items"] = migrar_lista(bolsillo["items"])


## Devuelve la lista de {nombre_interno, cantidad} con claves actuales y las
## entradas repetidas fusionadas (conserva el orden de primera aparición).
static func migrar_lista(items: Array) -> Array:
	var resultado: Array = []
	var posicion: Dictionary = {}
	for item in items:
		if not (item is Dictionary) or not (item as Dictionary).has("nombre_interno"):
			resultado.append(item)
			continue
		var clave := clave_actual(str(item["nombre_interno"]))
		if posicion.has(clave):
			var existente: Dictionary = resultado[posicion[clave]]
			existente["cantidad"] = int(existente.get("cantidad", 0)) + int(item.get("cantidad", 0))
			continue
		var copia: Dictionary = (item as Dictionary).duplicate()
		copia["nombre_interno"] = clave if _alias.has(str(item["nombre_interno"]).to_upper()) else item["nombre_interno"]
		posicion[clave] = resultado.size()
		resultado.append(copia)
	return resultado


static func _cargar() -> void:
	if _cargado:
		return
	_cargado = true
	if not FileAccess.file_exists(RUTA):
		return
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA))
	if datos is Dictionary:
		_alias = datos

@tool
extends RefCounted
class_name ResolvedorLugaresEncuentro
## Lugar del mapa de región de cada clave de encuentros, con la misma regla que la
## pantalla ÁREA de la Pokédex (sección de la escena; los interiores heredan la de
## su exterior; los submarinos usan su ruta de superficie). A diferencia de
## `Lugares`, no carga las escenas de mapa: lee como texto las propiedades del
## nodo raíz del .tscn, para que abrir el editor no arrastre todos los tilesets.
## Tampoco usa areas_pokedex.gd, que depende del autoload DatabaseManager.

const RUTA_ESCENAS_MAPAS := "res://escenas/mapas/"
const RUTA_LUGARES := "res://BaseDatos/region_map_metadata.json"
const RUTA_AREAS := "res://BaseDatos/pokedex_areas.json"
const MAX_SALTOS_EXTERIOR := 4

var _rutas_escena: Dictionary = {}  # nombre en minúsculas -> ruta .tscn
var _propiedades: Dictionary = {}  # clave -> {propiedad: texto}
var _indexado: bool = false
var _lugares: Dictionary = {}  # id o map_id en minúsculas -> POI (el primero gana)
var _casillas_marcador: Dictionary = {}
var _lugares_cargados: bool = false


func seccion_de(clave: String) -> String:
	return _seccion(clave.strip_edges().to_lower(), 0)


## POI de `region_map_metadata.json` ({} si no tiene lugar). Las secciones sin
## POI pero con marcador en la Pokédex (CALLE_VICTORIA, CUEVA_ANCESTRAL) devuelven
## un POI 1×1 en la casilla de `pokedex_areas.json`.
func lugar_de(clave: String) -> Dictionary:
	_cargar_lugares()
	var seccion: String = seccion_de(clave)
	# Mismo orden de búsqueda que AreasPokedex._lugar_de: sección, clave y clave sin
	# sufijo numérico de planta (cueva_granito_2 -> cueva_granito).
	var buscadas: Array[String] = []
	if not seccion.is_empty():
		buscadas.append(seccion.to_lower())
	buscadas.append(clave.to_lower())
	buscadas.append(RegEx.create_from_string("_\\d+$").sub(clave.to_lower(), ""))
	for buscada: String in buscadas:
		if _lugares.has(buscada):
			return _lugares[buscada]
	if _casillas_marcador.has(seccion):
		var casilla: Array = _casillas_marcador[seccion]
		return {"id": seccion.to_lower(), "nombre": seccion.replace("_", " "),
				"tile": [int(casilla[0]), int(casilla[1])], "tile_size": [1, 1]}
	return {}


func _cargar_lugares() -> void:
	if _lugares_cargados:
		return
	_lugares_cargados = true
	var metadata: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA_LUGARES))
	for lugar: Variant in (metadata.get("hoenn_poi", []) if metadata is Dictionary else []):
		if not (lugar is Dictionary):
			continue
		for id: String in [str(lugar.get("id", "")), str(lugar.get("map_id", ""))]:
			if not id.is_empty() and not _lugares.has(id.to_lower()):
				_lugares[id.to_lower()] = lugar
	var areas: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA_AREAS))
	if areas is Dictionary:
		_casillas_marcador = areas.get("casillas_marcador", {})


func _seccion(clave: String, saltos: int) -> String:
	if clave.is_empty() or saltos > MAX_SALTOS_EXTERIOR:
		return ""
	var propiedades: Dictionary = _propiedades_raiz(clave)
	var seccion: String = str(propiedades.get("seccion", ""))
	var exterior: String = str(propiedades.get("mapa_exterior_asociado", ""))
	if seccion.is_empty() and propiedades.get("esInterior", "") == "true" and not exterior.is_empty():
		seccion = _seccion(exterior.to_lower(), saltos + 1)
	# GetOverworldMapFromUnderwaterMap: resaltar la ruta de superficie.
	var superficie: String = str(propiedades.get("poi_mapa_region", ""))
	if seccion.begins_with("BAJO_AGUA_") and not superficie.is_empty():
		seccion = superficie.to_upper()
	return seccion


func _propiedades_raiz(clave: String) -> Dictionary:
	if _propiedades.has(clave):
		return _propiedades[clave]
	if not _indexado:
		_indexar(RUTA_ESCENAS_MAPAS)
		_indexado = true
	var resultado: Dictionary = {}
	var ruta: String = str(_rutas_escena.get(clave, ""))
	var archivo := FileAccess.open(ruta, FileAccess.READ) if not ruta.is_empty() else null
	if archivo != null:
		var en_raiz: bool = false
		while not archivo.eof_reached():
			var linea: String = archivo.get_line()
			if linea.begins_with("["):
				if en_raiz:
					break
				en_raiz = linea.begins_with("[node ")
				continue
			if not en_raiz:
				continue
			var igual: int = linea.find(" = ")
			if igual > 0:
				resultado[linea.substr(0, igual)] = linea.substr(igual + 3).trim_prefix("\"").trim_suffix("\"")
		archivo.close()
	_propiedades[clave] = resultado
	return resultado


func _indexar(base: String) -> void:
	var dir := DirAccess.open(base)
	if dir == null:
		return
	for subdir: String in dir.get_directories():
		if not subdir.begins_with("."):
			_indexar(base + subdir + "/")
	for archivo: String in dir.get_files():
		if archivo.ends_with(".tscn"):
			var nombre: String = archivo.get_basename().to_lower()
			if not _rutas_escena.has(nombre):
				_rutas_escena[nombre] = base + archivo

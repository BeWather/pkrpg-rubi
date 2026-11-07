extends RefCounted
## Dónde vive cada especie para la pantalla ÁREA de la POKéDEX.
## Equivale a FindMapsWithMon de pokeruby/src/pokedex_area_screen.c, pero lee
## la tabla activa de DatabaseManager (los mismos encuentros que las batallas).
##
## Las secciones de pueblos y rutas (las de la cuadrícula del mapa) brillan;
## cuevas, bosques y la ZONA SAFARI (mapas de los grupos 24 y 26 en Rubí)
## llevan un marcador en el centro de su lugar del mapa de región.

const TABLAS = preload("res://UI/pokedex/tablas_pokedex.gd")
const RUTA_LUGARES: String = "res://BaseDatos/region_map_metadata.json"
const RUTA_CONFIGURACION: String = "res://BaseDatos/pokedex_areas.json"
## sSpeciesHiddenFromAreaScreen.
const OCULTAS: PackedStringArray = ["WYNAUT"]
## sFeebasData: FEEBAS no está en las tablas (casillas especiales de pesca).
const SECCIONES_EXTRA: Dictionary = {"FEEBAS": ["RUTA_119"]}
## ROAMER_SPECIES de Rubí: ignora las tablas y solo se ve donde vaga.
const ERRANTE: String = "LATIOS"
## En la cuadrícula pero de grupo especial en Rubí: marcador, no brillo.
const MARCADOR_AUNQUE_EN_CUADRICULA: PackedStringArray = ["ZONA_SAFARI"]
const METODOS: PackedStringArray = ["hierba", "agua", "roca", "pesca"]
## gRegionMapEntries de las secciones con marcador (todas 1×1). Algunas no
## coinciden con la casilla del lugar en el mapa de región (CUEVA_GRANITO está
## en la (1, 14) para el cursor); el marcador va donde lo pone Rubí.
static var _lugares: Dictionary = {}
static var _casillas_marcador: Dictionary = {}
static var _secciones_por_mapa: Dictionary = {}


## {brillo: Array[String] de secciones, marcadores: Array[Dictionary] con
## {seccion, centro: Vector2 en píxeles de pantalla}}. Vacío = ÁREA
## DESCONOCIDA. seccion_errante: sección actual de LATIOS ("" si no vaga).
static func calcular(nombre_interno: String, seccion_errante: String = "",
		tabla: Dictionary = {}) -> Dictionary:
	var especie := nombre_interno.to_upper()
	var brillo: Array[String] = []
	var marcadores: Array[Dictionary] = []
	var resultado := {"brillo": brillo, "marcadores": marcadores}
	if especie in OCULTAS:
		return resultado
	if especie == ERRANTE:
		if not seccion_errante.is_empty():
			_agregar(seccion_errante, "", resultado)
		return resultado
	var encuentros: Dictionary = tabla if not tabla.is_empty() else DatabaseManager.obtener_tabla_encuentros_activa()
	for clave in encuentros:
		if _tiene_especie(encuentros[clave], especie):
			_agregar(_seccion_de_clave(str(clave)), str(clave), resultado)
	for seccion in SECCIONES_EXTRA.get(especie, []):
		_agregar(seccion, "", resultado)
	return resultado


static func esta_vacia(area: Dictionary) -> bool:
	return area["brillo"].is_empty() and area["marcadores"].is_empty()


## Casillas (x, y) de la cuadrícula 28×15 que pertenecen a la sección.
static func casillas_de(seccion: String) -> Array[Vector2i]:
	var casillas: Array[Vector2i] = []
	for i in TABLAS.CUADRICULA_HOENN.size():
		if TABLAS.CUADRICULA_HOENN[i] == seccion:
			casillas.append(Vector2i(i % TABLAS.ANCHO_CUADRICULA, i / TABLAS.ANCHO_CUADRICULA))
	return casillas


static func _agregar(seccion: String, clave_mapa: String, resultado: Dictionary) -> void:
	if seccion.is_empty():
		return
	if seccion in TABLAS.CUADRICULA_HOENN and not seccion in MARCADOR_AUNQUE_EN_CUADRICULA:
		if not seccion in resultado["brillo"]:
			resultado["brillo"].append(seccion)
		return
	for marcador in resultado["marcadores"]:
		if marcador["seccion"] == seccion:
			return
	var tile := [0, 0]
	var tamano := [1, 1]
	_cargar_lugares()
	if _casillas_marcador.has(seccion):
		tile = _casillas_marcador[seccion]
	else:
		var lugar := _lugar_de(seccion, clave_mapa)
		if lugar.is_empty():
			return
		tile = lugar.get("tile", tile)
		tamano = lugar.get("tile_size", tamano)
	# Centro del rectángulo: 8·x + 8 + 4·ancho, 8·y + 24 + 4·alto
	# (CreateAreaMarkerSprites, con el mapa 8 px más abajo que en el PokéNav).
	resultado["marcadores"].append({
		"seccion": seccion,
		"centro": Vector2(8 * int(tile[0]) + 8 + 4 * int(tamano[0]), 8 * int(tile[1]) + 24 + 4 * int(tamano[1])),
	})


static func _tiene_especie(metodos: Dictionary, especie: String) -> bool:
	for metodo in METODOS:
		for encuentro in metodos.get(metodo, {}).get("encuentros", []):
			if str(encuentro.get("nombre_interno", "")).to_upper() == especie:
				return true
	return false


## Escena existente: su `seccion` (los interiores heredan la del exterior).
## Sin escena (p. ej. cueva_granito_2): el lugar del mapa de región con ese
## map_id, sin el sufijo de planta.
static func _seccion_de_clave(clave: String) -> String:
	var normalizada: String = clave.to_lower()
	if _secciones_por_mapa.has(normalizada):
		return str(_secciones_por_mapa[normalizada])
	var seccion: String = Lugares.seccion_de_escena(normalizada)
	# GetOverworldMapFromUnderwaterMap: resaltar la ruta de superficie.
	# Leer el POI authored evita inferirla del número del nombre submarino.
	if seccion.begins_with("BAJO_AGUA_"):
		var superficie: String = Lugares.poi_mapa_region_de_escena(normalizada)
		if not superficie.is_empty():
			seccion = Lugares.normalizar_clave(superficie)
	if seccion.is_empty():
		var lugar: Dictionary = _lugar_de("", normalizada)
		seccion = str(lugar.get("id", "")).to_upper()
	_secciones_por_mapa[normalizada] = seccion
	return seccion


static func _lugar_de(seccion: String, clave_mapa: String) -> Dictionary:
	var lugares := _cargar_lugares()
	var buscadas: Array[String] = []
	if not seccion.is_empty():
		buscadas.append(seccion.to_lower())
	if not clave_mapa.is_empty():
		buscadas.append(clave_mapa.to_lower())
		var regex := RegEx.create_from_string("_\\d+$")
		buscadas.append(regex.sub(clave_mapa.to_lower(), ""))
	for buscada in buscadas:
		if lugares.has(buscada):
			return lugares[buscada]
	return {}


## Lugares del mapa de región por id y por map_id (el primero gana).
static func _cargar_lugares() -> Dictionary:
	if _lugares.is_empty():
		var configuracion: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA_CONFIGURACION))
		if configuracion is Dictionary:
			_casillas_marcador = configuracion.get("casillas_marcador", {})
		var json = JSON.parse_string(FileAccess.get_file_as_string(RUTA_LUGARES))
		for lugar in (json.get("hoenn_poi", []) if json is Dictionary else []):
			for clave in [str(lugar.get("id", "")), str(lugar.get("map_id", ""))]:
				if not clave.is_empty() and not _lugares.has(clave.to_lower()):
					_lugares[clave.to_lower()] = lugar
	return _lugares


static func limpiar_cache() -> void:
	_lugares.clear()
	_casillas_marcador.clear()
	_secciones_por_mapa.clear()

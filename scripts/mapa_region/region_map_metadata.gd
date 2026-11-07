@tool
extends RefCounted
class_name RegionMapMetadata
## Modelo editable de `BaseDatos/region_map_metadata.json`.
## Conserva las demás regiones y los campos opcionales de cada POI (`vuelo_destino`,
## `bandera` de landmark, y cualquier otro campo desconocido).

const RUTA_METADATA := "res://BaseDatos/region_map_metadata.json"
const REGION_DEFECTO := "hoenn_poi"

var ultimo_error: String = ""
var _ruta: String = RUTA_METADATA
var _region: String = REGION_DEFECTO
var _raiz: Dictionary = {}
var _pois: Array[Dictionary] = []
var _original: Array[Dictionary] = []
var _cargado := false
var _eol := "\n"
var _termina_en_eol := true


func cargar(ruta: String = RUTA_METADATA, region: String = REGION_DEFECTO) -> Error:
	_reiniciar()
	_ruta = ruta
	_region = region
	if not FileAccess.file_exists(ruta):
		ultimo_error = "No existe el archivo de metadata: %s" % ruta
		return ERR_FILE_NOT_FOUND
	var texto := FileAccess.get_file_as_string(ruta)
	if texto.is_empty():
		ultimo_error = "El archivo está vacío o no se pudo leer: %s" % ruta
		return ERR_FILE_CANT_READ
	var json := JSON.new()
	if json.parse(texto) != OK:
		ultimo_error = "JSON inválido (línea %d): %s" % [json.get_error_line(), json.get_error_message()]
		return ERR_PARSE_ERROR
	if not (json.data is Dictionary):
		ultimo_error = "La raíz de la metadata no es un diccionario."
		return ERR_INVALID_DATA
	_raiz = (json.data as Dictionary).duplicate(true)
	if not _raiz.has(region):
		_raiz[region] = []
	if not (_raiz[region] is Array):
		ultimo_error = "La región '%s' no contiene una lista de POI." % region
		return ERR_INVALID_DATA
	for valor in _raiz[region]:
		if not (valor is Dictionary):
			ultimo_error = "La región '%s' contiene una entrada que no es un diccionario." % region
			return ERR_INVALID_DATA
		_pois.append(_normalizar((valor as Dictionary).duplicate(true)))
	_original = _pois.duplicate(true)
	_eol = "\r\n" if texto.contains("\r\n") else "\n"
	_termina_en_eol = texto.ends_with("\n")
	_cargado = true
	ultimo_error = ""
	return OK


func _reiniciar() -> void:
	ultimo_error = ""
	_raiz.clear()
	_pois.clear()
	_original.clear()
	_cargado = false


static func _normalizar(entrada: Dictionary) -> Dictionary:
	var resultado := entrada.duplicate(true)
	resultado["id"] = String(resultado.get("id", "")).strip_edges()
	resultado["map_id"] = String(resultado.get("map_id", resultado["id"])).strip_edges()
	resultado["nombre"] = String(resultado.get("nombre", ""))
	resultado["tile"] = _par_entero(resultado.get("tile", [0, 0]), Vector2i.ZERO)
	resultado["tile_size"] = _par_entero(resultado.get("tile_size", [1, 1]), Vector2i.ONE, true)
	resultado["prioridad"] = int(resultado.get("prioridad", 4))
	resultado["vuelo"] = bool(resultado.get("vuelo", false))
	if resultado.has("vuelo_destino"):
		var destino := _normalizar_destino_vuelo(resultado["vuelo_destino"])
		if destino.is_empty():
			resultado.erase("vuelo_destino")
		else:
			resultado["vuelo_destino"] = destino
	# `bandera`: FLAG_LANDMARK_* que condiciona que un landmark se liste en el
	# panel del PokéNav. Vacía = sin bandera (el campo se omite).
	if resultado.has("bandera"):
		var bandera := String(resultado["bandera"]).strip_edges()
		if bandera.is_empty():
			resultado.erase("bandera")
		else:
			resultado["bandera"] = bandera
	return resultado


## Normaliza `vuelo_destino` ({mapa, cx, cy[, cx_f, cy_f]}): celdas enteras y
## par femenino solo si viene completo. Devuelve {} si no es utilizable.
static func _normalizar_destino_vuelo(valor: Variant) -> Dictionary:
	if not (valor is Dictionary):
		return {}
	var entrada := valor as Dictionary
	var mapa := String(entrada.get("mapa", "")).strip_edges()
	if mapa.is_empty():
		return {}
	var destino := {
		"mapa": mapa,
		"cx": int(entrada.get("cx", 0)),
		"cy": int(entrada.get("cy", 0)),
	}
	if entrada.has("cx_f") and entrada.has("cy_f"):
		destino["cx_f"] = int(entrada["cx_f"])
		destino["cy_f"] = int(entrada["cy_f"])
	return destino


static func _par_entero(valor: Variant, defecto: Vector2i, minimo_uno: bool = false) -> Array:
	var par := defecto
	if valor is Array and valor.size() >= 2:
		par = Vector2i(int(valor[0]), int(valor[1]))
	elif valor is Vector2i:
		par = valor
	if minimo_uno:
		par = Vector2i(maxi(1, par.x), maxi(1, par.y))
	return [par.x, par.y]


func puede_guardar() -> bool:
	return _cargado


func pois() -> Array[Dictionary]:
	return _pois.duplicate(true)


## Claves de mapa (`vuelo_destino.mapa`, en minúsculas y sin repetir) de los
## POI con `vuelo`: los lugares que cuentan como visitados para VUELO.
func mapas_destino_vuelo() -> PackedStringArray:
	var mapas := PackedStringArray()
	for poi in _pois:
		if not bool(poi.get("vuelo", false)) or not (poi.get("vuelo_destino") is Dictionary):
			continue
		var mapa := String(poi["vuelo_destino"].get("mapa", "")).strip_edges().to_lower()
		if not mapa.is_empty() and not mapas.has(mapa):
			mapas.append(mapa)
	return mapas


func cantidad() -> int:
	return _pois.size()


func obtener(indice: int) -> Dictionary:
	if indice < 0 or indice >= _pois.size():
		return {}
	return _pois[indice].duplicate(true)


func reemplazar(indice: int, datos: Dictionary) -> bool:
	if indice < 0 or indice >= _pois.size():
		return false
	_pois[indice] = _normalizar(datos)
	return true


func agregar(datos: Dictionary = {}) -> int:
	var entrada := {
		"id": id_disponible("nuevo_poi"),
		"map_id": "",
		"nombre": "NUEVO POI",
		"tile": [0, 0],
		"tile_size": [1, 1],
		"prioridad": 4,
		"vuelo": false,
	}
	entrada.merge(datos, true)
	entrada = _normalizar(entrada)
	_pois.append(entrada)
	return _pois.size() - 1


func eliminar(indice: int) -> bool:
	if indice < 0 or indice >= _pois.size():
		return false
	_pois.remove_at(indice)
	return true


func id_disponible(base: String) -> String:
	var candidato := base.strip_edges().to_lower().replace(" ", "_")
	if candidato.is_empty():
		candidato = "nuevo_poi"
	var usados := {}
	for poi in _pois:
		usados[String(poi.get("id", ""))] = true
	if not usados.has(candidato):
		return candidato
	var numero := 2
	while usados.has("%s_%d" % [candidato, numero]):
		numero += 1
	return "%s_%d" % [candidato, numero]


func validar() -> String:
	var usados := {}
	for i in range(_pois.size()):
		var poi: Dictionary = _pois[i]
		var id := String(poi.get("id", "")).strip_edges()
		if id.is_empty():
			return "El POI %d no tiene id." % (i + 1)
		if usados.has(id):
			return "El id '%s' está repetido." % id
		usados[id] = true
		var tile: Array = poi.get("tile", [])
		var tam: Array = poi.get("tile_size", [])
		if tile.size() < 2 or int(tile[0]) < 0 or int(tile[1]) < 0:
			return "El POI '%s' tiene coordenadas inválidas." % id
		if tam.size() < 2 or int(tam[0]) < 1 or int(tam[1]) < 1:
			return "El POI '%s' tiene un tamaño inválido." % id
		if int(tile[0]) + int(tam[0]) > 28 or int(tile[1]) + int(tam[1]) > 15:
			return "La zona del POI '%s' sale del área navegable (28×15 tiles)." % id
	return ""


func hay_cambios() -> bool:
	return _pois != _original


func revertir() -> void:
	_pois = _original.duplicate(true)


func serializar() -> String:
	# Serialización explícita para mantener el formato histórico: claves conocidas
	# en su orden habitual y pares tile/tile_size en una sola línea. De otro modo
	# JSON.stringify ordena las claves y expande cada par, ensuciando todo el diff.
	var claves_raiz: Array = _raiz.keys()
	if not claves_raiz.has(_region):
		claves_raiz.append(_region)
	var lineas := PackedStringArray(["{"])
	for indice_raiz in range(claves_raiz.size()):
		var clave := String(claves_raiz[indice_raiz])
		var coma_raiz := "," if indice_raiz < claves_raiz.size() - 1 else ""
		if clave == _region:
			lineas.append("\t%s: [" % JSON.stringify(clave))
			for i in range(_pois.size()):
				lineas.append_array(_serializar_poi(_pois[i], i < _pois.size() - 1))
			lineas.append("\t]%s" % coma_raiz)
		else:
			var valor := _json_indentado(_raiz[clave], 1)
			lineas.append("\t%s: %s%s" % [JSON.stringify(clave), valor, coma_raiz])
	lineas.append("}")
	var texto := "\n".join(lineas)
	# La construcción usa LF; se conserva el estilo de EOL del archivo original.
	if _eol == "\r\n":
		texto = texto.replace("\n", "\r\n")
	if _termina_en_eol:
		texto += _eol
	return texto


func _serializar_poi(poi: Dictionary, lleva_coma: bool) -> PackedStringArray:
	var lineas := PackedStringArray(["\t\t{"])
	var conocidas := ["id", "map_id", "nombre", "tile", "tile_size", "prioridad", "vuelo", "vuelo_destino",
			"vuelo_zonas_bandera", "vuelo_zonas", "bandera"]
	var claves: Array = conocidas.duplicate()
	for clave in poi.keys():
		if not claves.has(String(clave)):
			claves.append(String(clave))
	for i in range(claves.size()):
		var clave := String(claves[i])
		if not poi.has(clave):
			continue
		var valor: String
		if clave == "tile" or clave == "tile_size":
			var par: Array = poi[clave]
			valor = "[%d, %d]" % [int(par[0]), int(par[1])]
		elif clave == "vuelo_destino" and poi[clave] is Dictionary:
			valor = _serializar_destino_vuelo(poi[clave])
		elif clave == "vuelo_zonas" and poi[clave] is Array:
			valor = _serializar_zonas_vuelo(poi[clave])
		else:
			valor = _json_indentado(poi[clave], 3)
		# Puede haber claves conocidas ausentes; la coma depende de si queda otra
		# clave realmente presente, no de la posición en `claves`.
		var quedan := false
		for j in range(i + 1, claves.size()):
			if poi.has(claves[j]):
				quedan = true
				break
		lineas.append("\t\t\t%s: %s%s" % [JSON.stringify(clave), valor, "," if quedan else ""])
	lineas.append("\t\t}%s" % ("," if lleva_coma else ""))
	return lineas


## `vuelo_zonas` (secciones en varias partes, como COLOSALIA): una zona por línea, {tile, nombre, vuelo_destino}.
func _serializar_zonas_vuelo(zonas: Array) -> String:
	var lineas := PackedStringArray()
	for zona in zonas:
		var partes := PackedStringArray()
		if zona.get("tile") is Array:
			partes.append("\"tile\": [%d, %d]" % [int(zona["tile"][0]), int(zona["tile"][1])])
		partes.append("\"nombre\": %s" % JSON.stringify(String(zona.get("nombre", ""))))
		if zona.get("vuelo_destino") is Dictionary:
			partes.append("\"vuelo_destino\": %s" % _serializar_destino_vuelo(zona["vuelo_destino"]))
		lineas.append("\t\t\t\t{%s}" % ", ".join(partes))
	return "[\n%s\n\t\t\t]" % ",\n".join(lineas)


## `vuelo_destino` en una sola línea y con orden fijo (mapa, cx, cy, cx_f, cy_f).
func _serializar_destino_vuelo(destino: Dictionary) -> String:
	var partes := PackedStringArray(["\"mapa\": %s" % JSON.stringify(String(destino.get("mapa", "")))])
	for clave in ["cx", "cy", "cx_f", "cy_f"]:
		if destino.has(clave):
			partes.append("\"%s\": %d" % [clave, int(destino[clave])])
	return "{%s}" % ", ".join(partes)


func _json_indentado(valor: Variant, nivel: int) -> String:
	var texto := JSON.stringify(valor, "\t")
	return texto.replace("\n", "\n" + "\t".repeat(nivel))


func guardar(ruta: String = "") -> Error:
	if not _cargado:
		ultimo_error = "No se puede guardar porque la metadata no se cargó correctamente."
		return ERR_UNCONFIGURED
	var error_validacion := validar()
	if not error_validacion.is_empty():
		ultimo_error = error_validacion
		return ERR_INVALID_DATA
	var destino := _ruta if ruta.is_empty() else ruta
	var temporal := destino + ".tmp"
	var archivo := FileAccess.open(temporal, FileAccess.WRITE)
	if archivo == null:
		ultimo_error = "No se pudo abrir %s para escritura." % temporal
		return FileAccess.get_open_error()
	archivo.store_string(serializar())
	var error := archivo.get_error()
	archivo.close()
	if error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporal))
		ultimo_error = "No se pudo escribir la metadata (error %d)." % error
		return error
	error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporal), ProjectSettings.globalize_path(destino))
	if error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporal))
		ultimo_error = "No se pudo reemplazar %s (error %d)." % [destino, error]
		return error
	_original = _pois.duplicate(true)
	_raiz[_region] = _pois.duplicate(true)
	ultimo_error = ""
	return OK

@tool
extends RefCounted
class_name ModeloEncuentros
## Modelo editable de las tablas de encuentros (`config_encuentros.json` o
## `config_encuentros_alternativo.json`). Al guardar solo se reescriben las claves
## editadas: el resto conserva su texto original (los archivos mezclan `16` y
## `16.0` y JSON.parse lo lee todo como float), así el diff queda acotado.

const RUTA_DEFECTO := "res://BaseDatos/config_encuentros.json"
const RUTA_ALTERNATIVO := "res://BaseDatos/config_encuentros_alternativo.json"
const TIPOS: Array[String] = ["hierba", "agua", "pesca", "roca"]

## Mismos pesos que DatabaseManager (seleccionar_pokemon_salvaje).
const PESOS_HIERBA: Array[int] = [20, 20, 10, 10, 10, 10, 5, 5, 4, 4, 1, 1]
const PESOS_AGUA: Array[int] = [60, 30, 5, 4, 1]
const PESOS_ROCA: Array[int] = [60, 30, 5, 4, 1]
## Pesca: los 10 slots están concatenados por caña.
const SEGMENTOS_PESCA: Array[Dictionary] = [
	{"nombre": "Caña vieja", "inicio": 0, "pesos": [70, 30]},
	{"nombre": "Caña buena", "inicio": 2, "pesos": [60, 20, 20]},
	{"nombre": "Supercaña", "inicio": 5, "pesos": [40, 40, 15, 4, 1]},
]

var ultimo_error: String = ""
var ruta: String = RUTA_DEFECTO
var modificado: bool = false
var _datos: Dictionary = {}
var _termina_en_eol: bool = true
var _eol: String = "\n"
## clave -> texto original de su bloque (sin la coma final); las claves tocadas salen.
var _bloques_originales: Dictionary = {}


func cargar(ruta_archivo: String) -> Error:
	ruta = ruta_archivo
	_datos.clear()
	modificado = false
	if not FileAccess.file_exists(ruta_archivo):
		ultimo_error = "No existe %s" % ruta_archivo
		return ERR_FILE_NOT_FOUND
	var texto: String = FileAccess.get_file_as_string(ruta_archivo)
	var json := JSON.new()
	if json.parse(texto) != OK:
		ultimo_error = "JSON inválido (línea %d): %s" % [json.get_error_line(), json.get_error_message()]
		return ERR_PARSE_ERROR
	if not (json.data is Dictionary):
		ultimo_error = "La raíz de %s no es un diccionario." % ruta_archivo
		return ERR_INVALID_DATA
	_datos = json.data
	_termina_en_eol = texto.ends_with("\n")
	_eol = "\r\n" if texto.contains("\r\n") else "\n"
	_bloques_originales = _extraer_bloques(texto.replace("\r\n", "\n"))
	if _bloques_originales.size() != _datos.size():
		_bloques_originales.clear()  # Formato inesperado: se reserializa todo.
	ultimo_error = ""
	return OK


func serializar() -> String:
	var bloques: PackedStringArray = []
	for clave: String in claves():
		if _bloques_originales.has(clave):
			bloques.append(str(_bloques_originales[clave]))
		else:
			bloques.append("\t%s: %s" % [JSON.stringify(clave), JSON.stringify(_datos[clave], "\t").replace("\n", "\n\t")])
	var texto: String = "{}" if bloques.is_empty() else "{\n" + ",\n".join(bloques) + "\n}"
	if _termina_en_eol:
		texto += "\n"
	return texto.replace("\n", _eol)


## Bloques de primer nivel tal como los escribe JSON.stringify(datos, "\t"):
## empiezan en `\t"clave": ` y terminan en la línea `\t}` (o en la misma si es `{}`).
static func _extraer_bloques(texto: String) -> Dictionary:
	var resultado: Dictionary = {}
	var inicio := RegEx.create_from_string("^\\t(\"(?:[^\"\\\\]|\\\\.)*\"): ")
	var clave: String = ""
	var lineas: PackedStringArray = []
	for linea: String in texto.split("\n"):
		if clave.is_empty():
			var coincidencia: RegExMatch = inicio.search(linea)
			if coincidencia == null:
				continue
			clave = str(JSON.parse_string(coincidencia.get_string(1)))
			lineas = [linea]
		else:
			lineas.append(linea)
		var cierre: String = linea.trim_suffix(",")
		if cierre == "\t}" or (lineas.size() == 1 and not cierre.ends_with("{")):
			resultado[clave] = "\n".join(lineas).trim_suffix(",")
			clave = ""
	return resultado


func guardar() -> Error:
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		ultimo_error = "No se pudo escribir en %s" % ruta
		return FileAccess.get_open_error()
	archivo.store_string(serializar())
	archivo.close()
	modificado = false
	ultimo_error = ""
	return OK


func claves() -> Array[String]:
	var resultado: Array[String] = []
	for clave: Variant in _datos.keys():
		resultado.append(str(clave))
	resultado.sort()
	return resultado


func tiene_clave(clave: String) -> bool:
	return _datos.has(clave)


func agregar_clave(clave: String) -> bool:
	if clave.is_empty() or _datos.has(clave):
		return false
	_datos[clave] = {}
	_bloques_originales.erase(clave)
	modificado = true
	return true


func eliminar_clave(clave: String) -> void:
	if _datos.erase(clave):
		_bloques_originales.erase(clave)
		modificado = true


func tipos_de(clave: String) -> Array[String]:
	var resultado: Array[String] = []
	var config: Dictionary = _datos.get(clave, {})
	for tipo: String in TIPOS:
		if config.has(tipo):
			resultado.append(tipo)
	return resultado


func ratio(clave: String, tipo: String) -> int:
	var config: Dictionary = _datos.get(clave, {})
	return int(config.get(tipo, {}).get("ratio", 0))


## Copia de los slots: [{nombre_interno, nivel_min, nivel_max}] con enteros.
func slots(clave: String, tipo: String) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	var config: Dictionary = _datos.get(clave, {})
	for slot: Variant in config.get(tipo, {}).get("encuentros", []):
		if slot is Dictionary:
			resultado.append({
				"nombre_interno": str(slot.get("nombre_interno", "")),
				"nivel_min": int(slot.get("nivel_min", 1)),
				"nivel_max": int(slot.get("nivel_max", 1)),
			})
	return resultado


## Reemplaza un tipo completo. Los slots sin especie no se guardan y un tipo sin
## slots desaparece (mismo criterio que el editor clásico).
func fijar_tipo(clave: String, tipo: String, valor_ratio: int, nuevos_slots: Array[Dictionary]) -> void:
	if not _datos.has(clave):
		_datos[clave] = {}
	var config: Dictionary = _datos[clave]
	var encuentros: Array = []
	for slot: Dictionary in nuevos_slots:
		var nombre: String = str(slot.get("nombre_interno", "")).strip_edges().to_upper()
		if nombre.is_empty():
			continue
		encuentros.append({
			"nombre_interno": nombre,
			"nivel_min": float(slot.get("nivel_min", 1)),
			"nivel_max": float(slot.get("nivel_max", 1)),
		})
	if encuentros.is_empty():
		config.erase(tipo)
	else:
		config[tipo] = {"ratio": float(valor_ratio), "encuentros": encuentros}
	_bloques_originales.erase(clave)
	modificado = true


## Probabilidad (0-100) y grupo de cada slot, según los pesos del juego. Si hay
## menos slots que pesos se normaliza como hace DatabaseManager; los slots que
## sobran no salen nunca (0 %, grupo "Sin uso").
static func probabilidades(tipo: String, cantidad: int) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	for i: int in cantidad:
		resultado.append({"porcentaje": 0.0, "grupo": "Sin uso"})
	if tipo == "pesca":
		for segmento: Dictionary in SEGMENTOS_PESCA:
			_repartir(resultado, int(segmento["inicio"]), segmento["pesos"], str(segmento["nombre"]))
	else:
		var pesos: Array = PESOS_HIERBA
		if tipo == "agua":
			pesos = PESOS_AGUA
		elif tipo == "roca":
			pesos = PESOS_ROCA
		_repartir(resultado, 0, pesos, "")
	return resultado


## "20 %", "33.3 %"...
static func formatear_porcentaje(porcentaje: float) -> String:
	if is_equal_approx(porcentaje, roundf(porcentaje)):
		return "%d %%" % int(roundf(porcentaje))
	return "%.1f %%" % porcentaje


static func _repartir(resultado: Array[Dictionary], inicio: int, pesos: Array, grupo: String) -> void:
	var limite: int = mini(resultado.size() - inicio, pesos.size())
	if limite <= 0:
		return
	var total: int = 0
	for i: int in limite:
		total += int(pesos[i])
	for i: int in limite:
		resultado[inicio + i] = {"porcentaje": 100.0 * float(pesos[i]) / float(total), "grupo": grupo}


## Totales por grupo y especie: [{grupo, nombre_interno, porcentaje, nivel_min, nivel_max}],
## en el orden en que aparece cada especie dentro de su grupo.
static func resumen(tipo: String, lista_slots: Array[Dictionary]) -> Array[Dictionary]:
	var probs: Array[Dictionary] = probabilidades(tipo, lista_slots.size())
	var resultado: Array[Dictionary] = []
	var indice: Dictionary = {}
	for i: int in lista_slots.size():
		var nombre: String = str(lista_slots[i].get("nombre_interno", "")).strip_edges().to_upper()
		var porcentaje: float = float(probs[i]["porcentaje"])
		if nombre.is_empty() or porcentaje <= 0.0:
			continue
		var grupo: String = str(probs[i]["grupo"])
		var clave: String = grupo + "|" + nombre
		var nivel_min: int = int(lista_slots[i].get("nivel_min", 1))
		var nivel_max: int = int(lista_slots[i].get("nivel_max", nivel_min))
		if indice.has(clave):
			var entrada: Dictionary = resultado[int(indice[clave])]
			entrada["porcentaje"] = float(entrada["porcentaje"]) + porcentaje
			entrada["nivel_min"] = mini(int(entrada["nivel_min"]), nivel_min)
			entrada["nivel_max"] = maxi(int(entrada["nivel_max"]), nivel_max)
		else:
			indice[clave] = resultado.size()
			resultado.append({"grupo": grupo, "nombre_interno": nombre, "porcentaje": porcentaje,
					"nivel_min": nivel_min, "nivel_max": nivel_max})
	return resultado

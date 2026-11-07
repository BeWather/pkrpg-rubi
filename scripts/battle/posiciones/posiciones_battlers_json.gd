@tool
extends RefCounted
class_name PosicionesBattlersJSON
## Lógica pura (sin UI ni autoloads) del Editor de Posiciones de Battlers:
## carga, edición y guardado de `res://escenas/batalla/battle_positions.json`.
##
## El JSON guarda, por `nombre_interno`, un `enemy_offset` y un `player_offset`
## (enteros x/y) que `batalla.gd` suma al ancla del slot y, opcionalmente, la bandera
## booleana `sombra` (muestra `Sombra1` del BattleSlot; ausente = false). Esta clase guarda el
## archivo reproduciendo su formato actual (BOM UTF-8, tabuladores, EOL
## detectado, orden de claves `enemy_offset` -> `player_offset` y `y` -> `x`)
## para que el diff de git solo muestre lo realmente modificado; `JSON.stringify`
## reordenaría las claves y cambiaría el formato. `sombra` solo se escribe cuando es
## `true` (tras `player_offset`), así que las entradas sin sombra no cambian.
##
## Estado: `_actual` (copia editable) frente a `_original` (lo cargado/guardado por
## última vez). Navegar entre especies no descarta nada (design.md D9).

const RUTA_POSICIONES := "res://escenas/batalla/battle_positions.json"
## Orden de especies (nombre_interno -> nº Pokédex nacional), generado desde poke.db.
const RUTA_ORDEN_DEX := "res://scripts/battle/posiciones/orden_dex.json"

const LADO_ENEMIGO := &"enemy"
const LADO_JUGADOR := &"player"

const _BOM: PackedByteArray = [0xEF, 0xBB, 0xBF]

## Mensaje del último error de carga/guardado (vacío si no hubo).
var ultimo_error: String = ""

var _cargado: bool = false
var _tiene_bom: bool = false
var _eol: String = "\n"
var _termina_en_eol: bool = false
var _orden: Array[String] = []
var _actual: Dictionary = {}    # clave -> {"enemy": Vector2i, "player": Vector2i}
var _original: Dictionary = {}  # idem, estado cargado/guardado por última vez


# ─── Carga ─────────────────────────────────────────────────────────────────────

## Carga y parsea el archivo. Si falla deja el helper en estado no cargado
## (`puede_guardar() == false`) y no escribe nada.
func cargar(ruta: String = RUTA_POSICIONES) -> Error:
	_reiniciar()
	if not FileAccess.file_exists(ruta):
		ultimo_error = "No existe el archivo de posiciones: %s" % ruta
		return ERR_FILE_NOT_FOUND
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(ruta)
	if bytes.is_empty():
		ultimo_error = "El archivo de posiciones está vacío o no se pudo leer: %s" % ruta
		return ERR_FILE_CANT_READ

	var tiene_bom := bytes.size() >= 3 and bytes.slice(0, 3) == _BOM
	var texto: String = (bytes.slice(3) if tiene_bom else bytes).get_string_from_utf8()

	var json := JSON.new()
	if json.parse(texto) != OK:
		ultimo_error = "JSON inválido (línea %d): %s" % [json.get_error_line(), json.get_error_message()]
		return ERR_PARSE_ERROR
	if not (json.data is Dictionary):
		ultimo_error = "El JSON de posiciones no contiene un diccionario en la raíz."
		return ERR_INVALID_DATA

	var datos: Dictionary = json.data
	for clave in datos.keys():
		var entrada: Variant = datos[clave]
		if not (entrada is Dictionary):
			ultimo_error = "La entrada '%s' no es un diccionario." % clave
			_reiniciar()
			return ERR_INVALID_DATA
		var registro := {
			"enemy": _leer_offset(entrada.get("enemy_offset", null)),
			"player": _leer_offset(entrada.get("player_offset", null)),
			"sombra": _leer_sombra(String(clave), entrada.get("sombra", false)),
		}
		_orden.append(String(clave))
		_actual[String(clave)] = registro
		_original[String(clave)] = registro.duplicate()

	_tiene_bom = tiene_bom
	_eol = "\r\n" if texto.contains("\r\n") else "\n"
	_termina_en_eol = texto.ends_with("\n")
	_cargado = true
	ultimo_error = ""
	return OK


func _reiniciar() -> void:
	_cargado = false
	_tiene_bom = false
	_eol = "\n"
	_termina_en_eol = false
	_orden.clear()
	_actual.clear()
	_original.clear()
	ultimo_error = ""


## Bandera `sombra`: solo un booleano vale; cualquier otro tipo se trata como `false`
## (con aviso, porque `batalla.gd` tampoco la interpretaría como activa).
static func _leer_sombra(clave: String, valor: Variant) -> bool:
	if valor is bool:
		return valor
	push_warning("PosicionesBattlersJSON: 'sombra' de %s no es booleano; se usa false." % clave)
	return false


## Registro de una especie sin ningún ajuste (offsets a cero, sin sombra).
static func _registro_vacio() -> Dictionary:
	return {"enemy": Vector2i.ZERO, "player": Vector2i.ZERO, "sombra": false}


static func _leer_offset(valor: Variant) -> Vector2i:
	if not (valor is Dictionary):
		return Vector2i.ZERO
	return Vector2i(int(valor.get("x", 0)), int(valor.get("y", 0)))


## true si el archivo se cargó bien y se puede guardar sin riesgo de pisarlo.
func puede_guardar() -> bool:
	return _cargado


# ─── Consulta y edición ────────────────────────────────────────────────────────

## Claves del JSON en el orden del archivo, más las claves nuevas editadas.
func claves() -> Array[String]:
	return _orden.duplicate()


func tiene_clave(clave: String) -> bool:
	return _actual.has(clave)


## Ajustes actuales de `clave`: {"enemy": Vector2i, "player": Vector2i, "sombra": bool}.
## Una clave desconocida devuelve (0,0) en ambos lados y sin sombra.
func obtener(clave: String) -> Dictionary:
	if _actual.has(clave):
		return (_actual[clave] as Dictionary).duplicate()
	return _registro_vacio()


func obtener_original(clave: String) -> Dictionary:
	if _original.has(clave):
		return (_original[clave] as Dictionary).duplicate()
	return _registro_vacio()


## Fija el offset de un lado (`LADO_ENEMIGO` / `LADO_JUGADOR`). Una clave nueva se
## añade al final del orden.
func fijar(clave: String, lado: StringName, valor: Vector2i) -> void:
	if lado != LADO_ENEMIGO and lado != LADO_JUGADOR:
		push_warning("PosicionesBattlersJSON.fijar: lado desconocido '%s'" % lado)
		return
	_asegurar_clave(clave)
	_actual[clave][String(lado)] = valor


## Activa o desactiva la sombra de la especie (afecta a ambos lados). Una clave nueva
## se añade al final del orden.
func fijar_sombra(clave: String, activa: bool) -> void:
	_asegurar_clave(clave)
	_actual[clave]["sombra"] = activa


func _asegurar_clave(clave: String) -> void:
	if not _actual.has(clave):
		_actual[clave] = _registro_vacio()
		_orden.append(clave)


## Una clave es "modificada" si difiere de lo cargado/guardado. Una clave nueva
## solo cuenta si tiene algún offset distinto de cero.
func es_modificada(clave: String) -> bool:
	if not _actual.has(clave):
		return false
	if not _original.has(clave):
		return _actual[clave] != _registro_vacio()
	return _actual[clave] != _original[clave]


func modificadas() -> Array[String]:
	var resultado: Array[String] = []
	for clave in _orden:
		if es_modificada(clave):
			resultado.append(clave)
	return resultado


func hay_modificadas() -> bool:
	for clave in _orden:
		if es_modificada(clave):
			return true
	return false


## Restaura el original de una clave, sombra incluida (una clave nueva vuelve a (0,0)
## y sin sombra).
func descartar(clave: String) -> void:
	if not _actual.has(clave):
		return
	if _original.has(clave):
		_actual[clave] = (_original[clave] as Dictionary).duplicate()
	else:
		_actual[clave] = _registro_vacio()


# ─── Serialización y guardado ──────────────────────────────────────────────────

## Texto del archivo con el formato original (sin BOM; el BOM se antepone al
## escribir los bytes). Las claves nuevas sin ningún offset distinto de cero y sin
## sombra se omiten; una clave nueva con la sombra activa se escribe aunque sus
## offsets sean (0,0).
func serializar() -> String:
	var claves_emitidas: Array[String] = []
	for clave in _orden:
		if _original.has(clave) or es_modificada(clave):
			claves_emitidas.append(clave)

	if claves_emitidas.is_empty():
		return "{}" + (_eol if _termina_en_eol else "")

	var lineas := PackedStringArray()
	lineas.append("{")
	for i in range(claves_emitidas.size()):
		var clave: String = claves_emitidas[i]
		var registro: Dictionary = _actual[clave]
		var enemigo: Vector2i = registro["enemy"]
		var jugador: Vector2i = registro["player"]
		var con_sombra: bool = registro.get("sombra", false)
		lineas.append("\t%s: {" % JSON.stringify(clave))
		lineas.append("\t\t\"enemy_offset\": {")
		lineas.append("\t\t\t\"y\": %d," % enemigo.y)
		lineas.append("\t\t\t\"x\": %d" % enemigo.x)
		lineas.append("\t\t},")
		lineas.append("\t\t\"player_offset\": {")
		lineas.append("\t\t\t\"y\": %d," % jugador.y)
		lineas.append("\t\t\t\"x\": %d" % jugador.x)
		if con_sombra:
			lineas.append("\t\t},")
			lineas.append("\t\t\"sombra\": true")
		else:
			lineas.append("\t\t}")
		lineas.append("\t}" if i == claves_emitidas.size() - 1 else "\t},")
	lineas.append("}")
	return _eol.join(lineas) + (_eol if _termina_en_eol else "")


## Guarda de forma atómica (`<ruta>.tmp` + renombrado). Devuelve OK o el error; en
## caso de error el archivo original no se toca.
func guardar(ruta: String = RUTA_POSICIONES) -> Error:
	if not _cargado:
		ultimo_error = "No se puede guardar: el archivo no se cargó correctamente."
		return ERR_UNCONFIGURED

	var bytes := PackedByteArray()
	if _tiene_bom:
		bytes.append_array(_BOM)
	bytes.append_array(serializar().to_utf8_buffer())

	var ruta_tmp := ruta + ".tmp"
	var archivo := FileAccess.open(ruta_tmp, FileAccess.WRITE)
	if archivo == null:
		ultimo_error = "No se pudo abrir %s para escritura (error %d)." % [ruta_tmp, FileAccess.get_open_error()]
		return FileAccess.get_open_error()
	archivo.store_buffer(bytes)
	var error_escritura := archivo.get_error()
	archivo.close()
	if error_escritura != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta_tmp))
		ultimo_error = "Error al escribir %s (error %d)." % [ruta_tmp, error_escritura]
		return error_escritura

	var error_renombrado := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(ruta_tmp), ProjectSettings.globalize_path(ruta))
	if error_renombrado != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta_tmp))
		ultimo_error = "No se pudo reemplazar %s (error %d)." % [ruta, error_renombrado]
		return error_renombrado

	# El estado guardado pasa a ser el nuevo original; las claves nuevas sin
	# offsets (omitidas al serializar) desaparecen de la colección.
	var nuevo_orden: Array[String] = []
	var nuevo_original := {}
	for clave in _orden:
		if _original.has(clave) or es_modificada(clave):
			nuevo_orden.append(clave)
			nuevo_original[clave] = (_actual[clave] as Dictionary).duplicate()
		else:
			_actual.erase(clave)
	_orden = nuevo_orden
	_original = nuevo_original
	ultimo_error = ""
	return OK


# ─── Orden de especies (design.md D7) ──────────────────────────────────────────

## Ordena `claves` por número nacional con las formas (`UNOWN_n`, `CASTFORM_n`)
## justo después de su especie base. `indice_dex` mapea nombre_interno ->
## numero_nacional. Las claves sin coincidencia van al final en orden
## alfabético; con `indice_dex` vacío el resultado es alfabético puro.
static func ordenar_especies(claves_a_ordenar: Array, indice_dex: Dictionary) -> Array[String]:
	var entradas: Array = []
	for item in claves_a_ordenar:
		var clave := String(item)
		var numero: int = 1 << 30
		var sufijo: int = 0
		if indice_dex.has(clave):
			numero = int(indice_dex[clave])
		else:
			var corte := clave.rfind("_")
			if corte > 0:
				var base := clave.substr(0, corte)
				var resto := clave.substr(corte + 1)
				if resto.is_valid_int() and indice_dex.has(base):
					numero = int(indice_dex[base])
					sufijo = int(resto)
		entradas.append([numero, sufijo, clave])
	entradas.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return a[0] < b[0]
		if a[1] != b[1]:
			return a[1] < b[1]
		return a[2] < b[2])
	var resultado: Array[String] = []
	for entrada in entradas:
		resultado.append(entrada[2])
	return resultado


## nombre_interno -> numero_nacional desde `orden_dex.json` (no depende de `poke.db`,
## que el editor no siempre puede abrir). Las especies que no figuren en el archivo
## quedan al final en orden alfabético (`ordenar_especies`). Devuelve un diccionario
## vacío si el archivo falta o no es válido: el orden degrada a alfabético.
static func cargar_indice_dex(ruta: String = RUTA_ORDEN_DEX) -> Dictionary:
	var indice := {}
	if not FileAccess.file_exists(ruta):
		return indice
	var datos = JSON.parse_string(FileAccess.get_file_as_string(ruta))
	if not datos is Dictionary:
		return indice
	for clave in datos:
		var numero = datos[clave]
		if numero is float or numero is int:
			indice[String(clave)] = int(numero)
	return indice

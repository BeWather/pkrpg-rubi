@tool
extends RefCounted
class_name CatalogoPokemon
## Especies de poke.db (nombre visible y número nacional) y sus iconos de dos
## frames. Cada especie comparte un único AtlasTexture: alternar_frame() mueve la
## región de todos a la vez, así que cualquier control que lo use se anima solo.

const RUTA_BASE_DATOS := "res://BaseDatos/poke.db"
const PLANTILLA_ICONO := "res://graficos/Icons/icon%03d.png"
const TAM_FRAME := Vector2(32, 32)

var _especies: Dictionary = {}  # nombre_interno -> {nombre, numero}
var _orden: Array[String] = []
var _iconos: Dictionary = {}  # numero -> AtlasTexture
var _frame: int = 0


func cargar() -> bool:
	_especies.clear()
	_orden.clear()
	if not FileAccess.file_exists(RUTA_BASE_DATOS):
		return false
	var db := SQLite.new()
	db.path = RUTA_BASE_DATOS
	if not db.open_db():
		return false
	db.query("SELECT nombre_interno, nombre, numero_nacional FROM Pokemon ORDER BY numero_nacional")
	for fila: Dictionary in db.query_result:
		var interno: String = str(fila.get("nombre_interno", ""))
		if interno.is_empty():
			continue
		_especies[interno] = {"nombre": str(fila.get("nombre", interno)), "numero": int(fila.get("numero_nacional", 0))}
		_orden.append(interno)
	db.close_db()
	return true


func esta_vacio() -> bool:
	return _especies.is_empty()


func es_valida(interno: String) -> bool:
	return _especies.is_empty() or _especies.has(interno)


func nombre_visible(interno: String) -> String:
	return str(_especies.get(interno, {}).get("nombre", ""))


func numero(interno: String) -> int:
	return int(_especies.get(interno, {}).get("numero", 0))


## Especies cuyo nombre interno o visible contiene `texto` (sin distinguir mayúsculas).
func buscar(texto: String, maximo: int = 40) -> Array[String]:
	var consulta: String = texto.strip_edges().to_upper()
	var resultado: Array[String] = []
	for interno: String in _orden:
		if consulta.is_empty() or interno.contains(consulta) or nombre_visible(interno).to_upper().contains(consulta):
			resultado.append(interno)
			if resultado.size() >= maximo:
				break
	return resultado


## Icono animado de la especie (icon000 si no existe o no es válida).
func icono(interno: String) -> Texture2D:
	var num: int = numero(interno)
	if _iconos.has(num):
		return _iconos[num]
	var ruta: String = PLANTILLA_ICONO % num
	if not ResourceLoader.exists(ruta):
		if num == 0:
			return null
		return icono("")
	var atlas := AtlasTexture.new()
	atlas.atlas = load(ruta) as Texture2D
	atlas.region = Rect2(Vector2(TAM_FRAME.x * _frame, 0), TAM_FRAME)
	_iconos[num] = atlas
	return atlas


func alternar_frame() -> void:
	_frame = 1 - _frame
	for atlas: AtlasTexture in _iconos.values():
		atlas.region = Rect2(Vector2(TAM_FRAME.x * _frame, 0), TAM_FRAME)

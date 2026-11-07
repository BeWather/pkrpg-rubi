extends RefCounted
class_name DatosMaquinas

## MT01-50 y MO01-08 (`ItemUseOutOfBattle_TMHM`): relación objeto → movimiento de la
## tabla SQLite `MaquinasMovimientos`, textos oficiales de enseñanza y el estado que
## la pantalla de equipo muestra en cada caja (`sub_808AE8C` de pokemon_menu.c).

## Mochila/UI 0-based; Objetos.bolsillo_id en SQLite es 1-based (3).
const BOLSILLO: int = 2
const USO_CAMPO: String = "MT_MO"
const TEXTOS: String = "res://BaseDatos/maquinas/textos_maquinas.json"

## `DrawMonDescriptorStatus`: 0x8C = PUEDE, 0x9A = NO PUEDE, 0xA8 = APRENDIDO y, en la
## TORRE BATALLA, 0x1C / 0x2A / 0x38 = PRIMERO / SEGUNDO / TERCERO. Cada valor es una
## fila de UI/equipo/descriptores_maquina.png.
enum Descriptor { PUEDE, NO_PUEDE, APRENDIDO, PRIMERO, SEGUNDO, TERCERO }

static var _textos: Dictionary = {}
## objeto → fila de maquina(): la tabla no cambia durante la partida y `vigente()`
## la consulta en cada fotograma.
static var _cache: Dictionary = {}


## {objeto_id, objeto, bolsillo_id, movimiento_id, movimiento, nombre_movimiento} o {}
## si `objeto` no es una MT/MO del bolsillo MT/MO.
static func maquina(objeto: String) -> Dictionary:
	if objeto.is_empty():
		return {}
	if _cache.has(objeto):
		return _cache[objeto].duplicate(true)
	if not DatabaseManager.esta_conectado():
		return {}
	if not DatabaseManager.db.query_with_bindings("""
		SELECT o.id AS objeto_id, o.nombre_interno AS objeto, o.bolsillo_id,
		m.id AS movimiento_id, m.nombre_interno AS movimiento, m.nombre AS nombre_movimiento
		FROM Objetos o JOIN MaquinasMovimientos mm ON mm.objeto_id = o.id
		JOIN Movimientos m ON m.id = mm.movimiento_id WHERE o.nombre_interno = ?""", [objeto]):
		return {}
	var filas: Array = DatabaseManager.db.get_query_result()
	if filas.size() != 1 or int(filas[0]["bolsillo_id"]) != BOLSILLO + 1:
		return {}
	_cache[objeto] = filas[0].duplicate(true)
	return filas[0].duplicate(true)


## true si el objeto de la mochila es una MT/MO con movimiento asociado.
static func es_maquina(item: Dictionary) -> bool:
	var uso: String = str(item.get("uso_campo", USO_CAMPO))
	return uso == USO_CAMPO and not maquina(str(item.get("nombre_interno", ""))).is_empty()


## `gSpecialVar_ItemId >= ITEM_HM01_CUT`: las MO no se gastan al enseñarlas
## (Task_TeamMonTMMove2) y se anuncian con "MO activada.".
static func es_mo(objeto: String) -> bool:
	return ObjetosLlevados.es_mo({"nombre_interno": objeto})


## Nombre interno del movimiento de la máquina ("" si no lo es).
static func movimiento(objeto: String) -> String:
	return str(maquina(objeto).get("movimiento", ""))


## Nombre mostrable del movimiento (gMoveNames) en el idioma actual.
static func nombre_movimiento(objeto: String) -> String:
	var fila: Dictionary = maquina(objeto)
	if fila.is_empty():
		return ""
	var datos: Dictionary = DatabaseManager.obtener_datos_movimiento(str(fila["movimiento"]))
	return str(datos.get("nombre", fila.get("nombre_movimiento", fila["movimiento"])))


## Caja del equipo en modo MT/MO (`sub_808AE8C`): huevo o incompatible → NO PUEDE
## (antes que ya conocido), ya lo conoce → APRENDIDO, si no → PUEDE.
static func descriptor(pokemon: BasePokemon, objeto: String, datos: Object = null) -> Descriptor:
	var mov: String = movimiento(objeto)
	var fuente: Object = datos if datos != null else DatosCrianza.new()
	if pokemon == null or pokemon.huevo or mov.is_empty() or not fuente.puede_aprender_mt(pokemon.nombre_interno, mov):
		return Descriptor.NO_PUEDE
	for m in pokemon.movimientos:
		if m is Movimiento and fuente.id_movimiento(m) == mov:
			return Descriptor.APRENDIDO
	return Descriptor.PUEDE


## Texto oficial (`BaseDatos/maquinas/textos_maquinas.csv`) con {mon} y {mov}. Si la
## traducción aún no está importada, se lee del JSON del importador.
static func texto(clave: String, pokemon: BasePokemon = null, mov: String = "") -> String:
	var resultado: String = str(TranslationServer.translate(clave))
	if resultado == clave:
		if _textos.is_empty():
			var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEXTOS))
			if datos is Dictionary:
				for registro: Dictionary in datos.get("textos", []): _textos[registro["clave"]] = registro["texto_es"]
		resultado = str(_textos.get(clave, ""))
	return resultado.replace("\\n", "\n").replace("{mon}", pokemon.get_nombre_mostrar() if pokemon != null else "") \
		.replace("{mov}", mov)

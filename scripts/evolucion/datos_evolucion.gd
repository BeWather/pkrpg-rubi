class_name DatosEvolucion
extends RefCounted

## Tabla de evoluciones de pokeruby (`gEvolutionTable`, `src/data/pokemon/evolution.h`),
## importada por `herramientas/importar_evoluciones.py` y cotejada con la ROM
## española. Mapa especie de origen -> lista de evoluciones en el orden de las
## ranuras del decomp: `{"metodo": "EVO_LEVEL", "parametro": 16, "destino": "IVYSAUR"}`.
## `parametro` es un entero (nivel, belleza o 0) o, en `EVO_ITEM` y
## `EVO_TRADE_ITEM`, el `Objetos.nombre_interno` del objeto.

const RUTA_TABLA: String = "res://BaseDatos/evoluciones/evoluciones.json"

## Métodos de `include/pokemon.h`.
const EVO_FRIENDSHIP: String = "EVO_FRIENDSHIP"
const EVO_FRIENDSHIP_DAY: String = "EVO_FRIENDSHIP_DAY"
const EVO_FRIENDSHIP_NIGHT: String = "EVO_FRIENDSHIP_NIGHT"
const EVO_LEVEL: String = "EVO_LEVEL"
const EVO_TRADE: String = "EVO_TRADE"
const EVO_TRADE_ITEM: String = "EVO_TRADE_ITEM"
const EVO_ITEM: String = "EVO_ITEM"
const EVO_LEVEL_ATK_GT_DEF: String = "EVO_LEVEL_ATK_GT_DEF"
const EVO_LEVEL_ATK_EQ_DEF: String = "EVO_LEVEL_ATK_EQ_DEF"
const EVO_LEVEL_ATK_LT_DEF: String = "EVO_LEVEL_ATK_LT_DEF"
const EVO_LEVEL_SILCOON: String = "EVO_LEVEL_SILCOON"
const EVO_LEVEL_CASCOON: String = "EVO_LEVEL_CASCOON"
const EVO_LEVEL_NINJASK: String = "EVO_LEVEL_NINJASK"
const EVO_LEVEL_SHEDINJA: String = "EVO_LEVEL_SHEDINJA"
const EVO_BEAUTY: String = "EVO_BEAUTY"

static var _tabla: Dictionary = {}
static var _cargada: bool = false


## Evoluciones de `especie` en orden de ranura (vacío si no evoluciona).
static func evoluciones(especie: String) -> Array:
	_cargar()
	return _tabla.get(especie, []) as Array


## Especies de origen que tienen alguna evolución.
static func especies_con_evolucion() -> Array:
	_cargar()
	return _tabla.keys()


static func _cargar() -> void:
	if _cargada:
		return
	_cargada = true
	var archivo := FileAccess.open(RUTA_TABLA, FileAccess.READ)
	if archivo == null:
		push_error("[DatosEvolucion] No se pudo abrir %s" % RUTA_TABLA)
		return
	var datos: Variant = JSON.parse_string(archivo.get_as_text())
	archivo.close()
	if datos is Dictionary:
		_tabla = datos
	else:
		push_error("[DatosEvolucion] JSON inválido en %s" % RUTA_TABLA)

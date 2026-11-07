@tool
extends RefCounted
class_name TablaRevanchas

## Tabla de revanchas de Rubí (`gTrainerEyeTrainers` en `src/battle_setup.c`),
## importada por `herramientas/importar_tabla_revanchas.py`.
##
## Cada entrada: `{"nombre": String, "ids": Array[int] (5), "mapa": String}`.
## El índice de la entrada es el de `trainerRematches[]`; un ID 0 corta la
## cadena de tiers (solo WALLY).

const RUTA_JSON: String = "res://BaseDatos/revanchas/tabla_revanchas.json"
const NUM_TIERS: int = 5

static var _entradas: Array = []
static var _cargada: bool = false


static func entradas() -> Array:
	if not _cargada:
		_cargar()
	return _entradas


## Índice de la entrada cuyo tier 1 es `id` (`FirstBattleTrainerIdToRematchTableId`); −1 si no hay.
static func indice_por_primer_id(id: int) -> int:
	return indice_por_primer_id_en(entradas(), id)


## Índice de la entrada que contiene `id` en cualquier tier (`TrainerIdToRematchTableId`); −1 si no hay.
static func indice_por_cualquier_id(id: int) -> int:
	return indice_por_cualquier_id_en(entradas(), id)


static func indice_por_primer_id_en(tabla: Array, id: int) -> int:
	if id <= 0:
		return -1
	for i in tabla.size():
		if int(tabla[i]["ids"][0]) == id:
			return i
	return -1


static func indice_por_cualquier_id_en(tabla: Array, id: int) -> int:
	if id <= 0:
		return -1
	for i in tabla.size():
		for tier_id in tabla[i]["ids"]:
			if int(tier_id) == id:
				return i
	return -1


static func _cargar() -> void:
	_cargada = true
	_entradas = []
	var archivo := FileAccess.open(RUTA_JSON, FileAccess.READ)
	if archivo == null:
		push_error("[TablaRevanchas] No se pudo abrir %s" % RUTA_JSON)
		return
	var datos: Variant = JSON.parse_string(archivo.get_as_text())
	if not datos is Array:
		push_error("[TablaRevanchas] %s no es un array" % RUTA_JSON)
		return
	for entrada in datos:
		var ids: Array[int] = []
		for id in entrada.get("ids", []):
			ids.append(int(id))
		_entradas.append({
			"nombre": str(entrada.get("nombre", "")),
			"ids": ids,
			"mapa": str(entrada.get("mapa", "")),
		})

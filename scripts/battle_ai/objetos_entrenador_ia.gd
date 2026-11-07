## objetos_entrenador_ia.gd
## ShouldUseItem de pokeruby (battle_ai_switch_items.c): qué objeto usa el rival en la
## selección de acción. Reglas fijas, sin puntuación: recorre los objetos del entrenador
## (gTrainers[].items) por posición y gasta el primero que cumpla su condición.
extends RefCounted
class_name ObjetosEntrenadorIA

## GetAI_ItemType.
enum Tipo {
	RESTAURAR_TODO,  # AI_ITEM_FULL_RESTORE
	CURAR_PS,        # AI_ITEM_HEAL_HP
	ESTADISTICA,     # AI_ITEM_X_STAT
	DIRECTO,         # AI_ITEM_X_STAT con ITEM0_DIRE_HIT
	PROTECCION,      # AI_ITEM_GUARD_SPECS
}

## Los objetos que llevan los entrenadores de lista_entrenadores.json. Otro nombre es
## AI_ITEM_NOT_RECOGNIZABLE: corta la búsqueda sin usar nada.
const DATOS := {
	"RESTAUTODO": {"tipo": Tipo.RESTAURAR_TODO},
	"POCION": {"tipo": Tipo.CURAR_PS, "ps": 20},
	"SUPERPOCION": {"tipo": Tipo.CURAR_PS, "ps": 50},
	"HIPERPOCION": {"tipo": Tipo.CURAR_PS, "ps": 200},
	"ATAQUEX": {"tipo": Tipo.ESTADISTICA, "stat": "ataque"},
	"DEFENSAX": {"tipo": Tipo.ESTADISTICA, "stat": "defensa"},
	"VELOCIDADX": {"tipo": Tipo.ESTADISTICA, "stat": "velocidad"},
	"ESPECIALX": {"tipo": Tipo.ESTADISTICA, "stat": "ataque_especial"},
	"PRECISIONX": {"tipo": Tipo.ESTADISTICA, "stat": "precision"},
	"DIRECTO": {"tipo": Tipo.DIRECTO},
	"PROTECESP": {"tipo": Tipo.PROTECCION},
}

## AI_BATTLE_HISTORY->trainerItems: "" es un hueco ya gastado.
var _objetos: Array[String] = []
## AI_BATTLE_HISTORY->numItems: no baja al gastar objetos.
var _total: int = 0


func _init(objetos: Array[String] = []) -> void:
	for objeto in objetos:
		if not objeto.is_empty() and _objetos.size() < 4:
			_objetos.append(objeto.to_upper())
	_total = _objetos.size()


## Devuelve el objeto a usar y lo gasta, o "" si toca movimiento.
## `primer_turno`: isFirstTurn != 0. `neblina`: mistTimer del bando != 0.
func elegir(ps: int, ps_max: int, pokemon_vivos: int, primer_turno: bool, neblina: bool) -> String:
	for i in _objetos.size():
		if i != 0 and pokemon_vivos > _total - i + 1:
			continue
		var objeto := _objetos[i]
		if objeto.is_empty():
			continue
		if not DATOS.has(objeto):
			return ""
		if _debe_usar(DATOS[objeto], ps, ps_max, primer_turno, neblina):
			_objetos[i] = ""
			return objeto
	return ""


static func _debe_usar(datos: Dictionary, ps: int, ps_max: int, primer_turno: bool, neblina: bool) -> bool:
	match datos.tipo:
		Tipo.RESTAURAR_TODO:
			return ps > 0 and ps < ps_max / 4
		Tipo.CURAR_PS:
			return ps > 0 and (ps < ps_max / 4 or ps_max - ps > int(datos.ps))
		Tipo.ESTADISTICA, Tipo.DIRECTO:
			return primer_turno
		Tipo.PROTECCION:
			return primer_turno and not neblina
	return false

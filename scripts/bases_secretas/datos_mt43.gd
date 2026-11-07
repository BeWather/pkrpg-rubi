extends RefCounted
class_name DatosMT43

## Lo específico de la MT43 (regalo de Ruta 111). Enseñarla desde la mochila es el flujo
## genérico de cualquier MT/MO (DatosMaquinas, EnsenanzaMaquina, DialogoMaquina).

const OBJETO: String = "MT43"
const MOVIMIENTO: String = "DANOSECRETO"
## Mochila/UI 0-based; Objetos.bolsillo_id en SQLite es 1-based (3).
const BOLSILLO: int = DatosMaquinas.BOLSILLO


## Resolver relación SQLite; no confundir objeto GBA 331 con SQLite 347.
static func maquina() -> Dictionary:
	var fila: Dictionary = DatosMaquinas.maquina(OBJETO)
	if fila.is_empty() or str(fila["movimiento"]) != MOVIMIENTO:
		return {}
	return fila

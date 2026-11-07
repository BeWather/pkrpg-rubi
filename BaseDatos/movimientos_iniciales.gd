class_name MovimientosIniciales
extends RefCounted

## GiveBoxMonInitialMoveset: recorre el learnset en su orden hasta el nivel del Pokémon.
## Un movimiento ya conocido no ocupa otro hueco y, con los huecos llenos, se olvida el
## más antiguo. Las filas deben venir por `orden_aprendizaje` (SQL_ORDEN_RUBI) y conservan
## sus columnas; el resultado queda en el orden de los huecos de Rubí.

const MAX_MOVIMIENTOS: int = 4
const VERSION_GRUPO: String = "ruby-sapphire"
## Fragmento común a las consultas (parámetro: nivel), con `pm` = PokemonMovimientos.
const SQL_ORDEN_RUBI: String = """
	AND pm.version_grupo = 'ruby-sapphire'
	AND pm.nivel_aprendizaje <= %d
	ORDER BY pm.orden_aprendizaje"""


static func seleccionar(filas: Array, limite: int = MAX_MOVIMIENTOS) -> Array:
	var conocidos: Array = []
	for fila in filas:
		var mov: String = str(fila.get("nombre_interno", ""))
		if conocidos.any(func(previa) -> bool: return str(previa.get("nombre_interno", "")) == mov):
			continue
		if conocidos.size() >= limite:
			conocidos.pop_front()
		conocidos.append(fila)
	return conocidos

class_name AprendizajeMovimientos
extends RefCounted

## Aprendizaje de movimientos por nivel (`MonTryLearningNewMove`, `GiveMoveToMon`
## y `SetMonMoveSlot` de pokeruby). Recorre, en el orden del learnset, los
## movimientos que la especie actual aprende exactamente en su nivel actual.
##
## Uso (como `Task_EvolutionScene` estados 14-21):
##   var aprendizaje := AprendizajeMovimientos.new(pokemon)
##   while true:
##       var paso := aprendizaje.siguiente()
##       match paso.resultado: ...  # APRENDIDO, SIN_HUECO (preguntar), FIN
## Con SIN_HUECO quien llama decide: `sustituir(indice)` o renunciar.

enum Resultado {
	FIN,          ## No quedan movimientos de este nivel (0 en el decomp).
	APRENDIDO,    ## Tenía hueco y lo aprendió (devuelve el movimiento).
	SIN_HUECO,    ## Ya tiene 4 movimientos (0xFFFF): hay que elegir cuál olvidar.
}

const MAX_MOVIMIENTOS: int = 4
## `IsHMMove2`: las MO no se pueden olvidar al aprender un movimiento.
const MOVIMIENTOS_MO: Array[String] = [
	"CORTE", "VUELO", "SURF", "FUERZA", "DESTELLO", "GOLPEROCA", "CASCADA", "BUCEO",
]

var pokemon: BasePokemon
## Movimiento pendiente (gMoveToLearn) tras SIN_HUECO o APRENDIDO.
var movimiento_pendiente: String = ""

var _datos: Object
var _cola: Array[String] = []


## `datos`: DatosCrianza o un doble con `movimientos_en_nivel`, `crear_movimiento`
## e `id_movimiento`. `nivel` (por defecto el actual) es el nivel cuyo learnset se
## recorre: en combate la EXP sube todos los niveles de golpe y luego se aprende
## nivel a nivel (`atk5D_getexp` → `BattleScript_LevelUp` por cada subida).
func _init(p_pokemon: BasePokemon, datos: Object = null, nivel: int = -1) -> void:
	pokemon = p_pokemon
	_datos = datos if datos != null else DatosCrianza.new()
	if pokemon != null and not pokemon.huevo:
		_cola = _datos.movimientos_en_nivel(pokemon.nombre_interno, pokemon.nivel if nivel < 0 else nivel)


## Siguiente paso: {"resultado": Resultado, "movimiento": nombre_interno}. Los
## movimientos ya conocidos se saltan (0xFFFE).
func siguiente() -> Dictionary:
	while not _cola.is_empty():
		var mov: String = _cola.pop_front()
		if conoce(mov):
			continue
		movimiento_pendiente = mov
		if pokemon.movimientos.size() >= MAX_MOVIMIENTOS:
			return {"resultado": Resultado.SIN_HUECO, "movimiento": mov}
		var nuevo: Movimiento = _datos.crear_movimiento(mov)
		if nuevo == null:
			continue
		if not _aplicar_movimiento(nuevo, -1):
			continue
		return {"resultado": Resultado.APRENDIDO, "movimiento": mov}
	movimiento_pendiente = ""
	return {"resultado": Resultado.FIN, "movimiento": ""}


## true si el movimiento de la ranura `indice` es una MO (no se puede olvidar).
func es_mo(indice: int) -> bool:
	if indice < 0 or indice >= pokemon.movimientos.size():
		return false
	return MOVIMIENTOS_MO.has(_datos.id_movimiento(pokemon.movimientos[indice]))


## Movimiento pendiente con PP completos, sin aplicarlo (la 5.ª fila de la ficha de
## olvidar, `pssData.moveToLearn`). null si no hay pendiente o no existe.
func crear_movimiento_pendiente() -> Movimiento:
	if movimiento_pendiente.is_empty():
		return null
	return _datos.crear_movimiento(movimiento_pendiente)


## `RemoveMonPPBonus` + `SetMonMoveSlot`: olvida el movimiento de `indice` y
## pone el pendiente en su lugar con PP completos. Devuelve el nombre mostrable
## del olvidado ("" si no se pudo).
func sustituir(indice: int) -> String:
	if movimiento_pendiente.is_empty() or indice < 0 or indice >= pokemon.movimientos.size() or es_mo(indice):
		return ""
	var nuevo: Movimiento = _datos.crear_movimiento(movimiento_pendiente)
	if nuevo == null:
		return ""
	var olvidado: Movimiento = pokemon.movimientos[indice]
	if not _aplicar_movimiento(nuevo, indice):
		return ""
	return olvidado.nombre


## Punto de commit sin await; permite que una MT revalide/consuma junto al cambio.
func _aplicar_movimiento(nuevo: Movimiento, indice: int) -> bool:
	if indice < 0:
		pokemon.movimientos.append(nuevo)
	else:
		pokemon.movimientos[indice] = nuevo
	return true


func conoce(mov: String) -> bool:
	for m in pokemon.movimientos:
		if m is Movimiento and _datos.id_movimiento(m) == mov:
			return true
	return false


## Nombre mostrable de un movimiento por nombre_interno.
func nombre_movimiento(mov: String) -> String:
	var datos := DatabaseManager.obtener_datos_movimiento(mov)
	return str(datos.get("nombre", mov))

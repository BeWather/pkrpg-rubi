@tool
extends RefCounted
class_name MovimientosEntrenador

## Movimientos con los que entra en combate un Pokémon de entrenador.
##
## 1. Movimientos por nivel de la especie (`ruby-sapphire`), en el orden del
##    learnset y hasta su nivel: con 4 ocupados, cada nuevo saca al más viejo
##    (`GiveMonInitialMoveset` de pokeruby).
## 2. Movimientos fijos de `lista_entrenadores.json` (hasta 4), con la misma regla.
##    Un fijo ya conocido pasa a ser el más nuevo, así ningún fijo se pierde.
##
## `resolver()` es puro: lo comparten el juego y el editor de entrenadores (que
## corre como plugin, sin autoloads).

const MAX_MOVIMIENTOS: int = 4


## `movs_nivel`: [{"nivel": int, "mov": String}] en el orden del learnset.
static func resolver(movs_nivel: Array, nivel: int, fijos: Array) -> Array[String]:
	var set_movs: Array[String] = []
	for entrada in movs_nivel:
		if int(entrada.get("nivel", 0)) > nivel:
			break
		var mov := str(entrada.get("mov", "")).strip_edges()
		if mov.is_empty() or set_movs.has(mov):
			continue
		_empujar(set_movs, mov)
	var aplicados := 0
	for fijo in fijos:
		var mov := str(fijo).strip_edges().to_upper()
		if mov.is_empty():
			continue
		set_movs.erase(mov)
		_empujar(set_movs, mov)
		aplicados += 1
		if aplicados >= MAX_MOVIMIENTOS:
			break
	return set_movs


## Asigna a `pokemon.movimientos` el resultado de `resolver()` con PP completos.
## Si no se resuelve ninguno, conserva el set que BasePokemon calculó al crearse.
static func aplicar(pokemon: BasePokemon, fijos: Array, datos: DatosCrianza = null) -> void:
	if pokemon == null:
		return
	var fuente := datos if datos != null else DatosCrianza.new()
	var nombres := resolver(fuente.movimientos_nivel(pokemon.nombre_interno), pokemon.nivel, fijos)
	var movimientos: Array[Movimiento] = []
	for nombre in nombres:
		var movimiento := fuente.crear_movimiento(nombre)
		if movimiento != null:
			movimientos.append(movimiento)
	if not movimientos.is_empty():
		pokemon.movimientos = movimientos


static func _empujar(set_movs: Array[String], mov: String) -> void:
	if set_movs.size() >= MAX_MOVIMIENTOS:
		set_movs.remove_at(0)
	set_movs.append(mov)

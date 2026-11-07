class_name EfectosHabilidad
extends RefCounted

## Efectos de habilidad que ocurren FUERA del turno de combate (overworld y
## fin de batalla). Funciones estáticas sin UI, como ObjetosLlevados.
##
## La habilidad de un Pokémon se identifica por su nombre_interno de la tabla
## Habilidades (BasePokemon.habilidad), sin tildes ni espacios y en mayúsculas.
##
## Referencia pokeruby (Rubí no tiene más habilidades de campo que estas):
## - RECOGIDA: src/battle_script_commands.c atkE5_pickup + sPickupItems; se
##   dispara desde BattleScript_PayDayMoneyAndPickUpItems (data/battle_scripts_1.s)
##   al ganar una batalla salvaje o de entrenador (HandleEndTurn_BattleWon).
## - HEDOR / ILUMINACION: src/wild_encounter.c DoWildEncounterTest.

const RECOGIDA: String = "RECOGIDA"
const HEDOR: String = "HEDOR"
const ILUMINACION: String = "ILUMINACION"

## Probabilidad (1 entre N) de que cada Pokémon con RECOGIDA recoja algo tras
## una victoria (`Random() % 10 == 0`).
const RECOGIDA_UNA_ENTRE: int = 10

## sPickupItems: [objeto, umbral]. Se elige el primero cuyo umbral supera la
## tirada 0-99. Con 99 no queda ninguno y toca el último (ROCA DEL REY, 1%).
## Los ids son los nombre_interno de Objetos en mayúsculas, como se guardan en
## BasePokemon.objeto.
const TABLA_RECOGIDA: Array = [
	["SUPERPOCION", 30],
	["CURATOTAL", 40],
	["ULTRABALL", 50],
	["CARAMELORARO", 60],
	["RESTAUTODO", 70],
	["REVIVIR", 80],
	["PEPITA", 90],
	["PROTEINA", 95],
	["MASPP", 99],
]
const OBJETO_RECOGIDA_RARO: String = "ROCADELREY"


# ─── Consultas ───────────────────────────────────────────────────────────────

## Habilidad normalizada del Pokémon ("" si no hay Pokémon o es un huevo).
static func habilidad_de(pokemon: BasePokemon) -> String:
	if pokemon == null or pokemon.huevo:
		return ""
	return pokemon.habilidad.strip_edges().to_upper()


static func tiene_habilidad(pokemon: BasePokemon, habilidad: String) -> bool:
	return habilidad_de(pokemon) == habilidad


# ─── RECOGIDA ────────────────────────────────────────────────────────────────

## Objeto que corresponde a una tirada 0-99 (el bucle `j < 18` de atkE5_pickup).
static func objeto_recogida(tirada: int) -> String:
	for entrada in TABLA_RECOGIDA:
		if int(entrada[1]) > tirada:
			return str(entrada[0])
	return OBJETO_RECOGIDA_RARO


## atkE5_pickup: recorre todo el equipo (también los debilitados y los que no
## lucharon). Cada Pokémon con RECOGIDA, sin objeto y que no sea un huevo tiene
## 1 entre 10 de quedarse con un objeto. El objeto se equipa en silencio, sin
## mensaje y sin pasar por la mochila.
## `sortear` es opcional: Callable(n: int) -> int con un valor en [0, n); sirve
## para tests deterministas. Devuelve los Pokémon que recogieron algo.
static func aplicar_recogida(equipo: Array, sortear: Callable = Callable()) -> Array[BasePokemon]:
	var recogieron: Array[BasePokemon] = []
	for elemento in equipo:
		var poke := elemento as BasePokemon
		if not tiene_habilidad(poke, RECOGIDA):
			continue
		if ObjetosLlevados.lleva_objeto(poke):
			continue
		if _sortear(RECOGIDA_UNA_ENTRE, sortear) != 0:
			continue
		poke.objeto = objeto_recogida(_sortear(100, sortear))
		recogieron.append(poke)
	return recogieron


# ─── HEDOR / ILUMINACION ─────────────────────────────────────────────────────

## DoWildEncounterTest: la habilidad del primer Pokémon del equipo modifica la
## probabilidad de encuentro por paso (HEDOR la reduce a la mitad, ILUMINACION
## la duplica). Si el primero es un huevo no hay efecto. No se aplica al pescar.
## Devuelve la probabilidad ajustada, acotada a 1.0.
static func ajustar_probabilidad_encuentro(equipo: Array, probabilidad: float, pescando: bool = false) -> float:
	if pescando or equipo.is_empty():
		return probabilidad
	match habilidad_de(equipo[0] as BasePokemon):
		HEDOR:
			probabilidad /= 2.0
		ILUMINACION:
			probabilidad *= 2.0
	return minf(probabilidad, 1.0)


# ─── Interno ─────────────────────────────────────────────────────────────────

static func _sortear(n: int, sortear: Callable) -> int:
	if sortear.is_valid():
		return int(sortear.call(n))
	return randi() % n

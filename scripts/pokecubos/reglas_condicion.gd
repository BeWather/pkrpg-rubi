class_name ReglasCondicion
extends RefCounted
## Dar de comer un POKéCUBO a un Pokémon (src/use_pokeblock.c, src/pokeblock.c y
## src/pokeblock_feed.c de pokeruby).
##
## Sabor → condición (sContestStatsMonData + sub_8136F74 + gUnknown_0840612C):
## picante → CARISMA (cool), ácido → DUREZA (tough), amargo → INGENIO (smart),
## dulce → DULZURA (cute), seco → BELLEZA (beauty). Campos de BasePokemon
## (BaseDatos/basepoke.gd): carisma, dureza, ingenio, dulzura, belleza y brillo.
##
## Aumento (sub_8136F74 y sub_8136E40):
## - d[c] = sabor del cubo asociado a la condición c;
## - si la ganancia total (PokeblockGetGain) es ≠ 0, a cada condición cuyo sabor tenga
##   la relación con el mismo signo que la ganancia se le suma relación · round(d/10)
##   (+10 % a los que le gustan si la ganancia es positiva; −10 % a los que no le
##   gustan si es negativa); con ganancia 0 se suman los sabores tal cual;
## - condición = clamp(condición + d, 0, 255) y brillo = min(brillo + suavidad, 255);
## - con brillo 255 NO come (sub_8137058) y el cubo no se gasta.
##
## Naturaleza: se usa `BasePokemon.naturaleza` (el String que muestran la ficha y el
## experto de ALGARIA), convertido al índice canónico del decomp (gNatureNames:
## FUERTE = 0 … RARA = 24) por su nombre oficial en español. NO se deriva de la tabla
## `Naturalezas` de poke.db (incompleta y con estadísticas mal asignadas) ni de
## `personalidad % 25` (independiente de la naturaleza visible en rubi4, ver
## basepoke.gd). Solo si el String está vacío o no se reconoce se recurre a
## `personalidad % 25`, como hace el combate (held_flavor_berry_rules.gd).

const BayasSabor = preload("res://scripts/battle/held_flavor_berry_rules.gd")

enum Reaccion { INDIFERENTE, LE_GUSTA, NO_LE_GUSTA }

const VALOR_MAXIMO: int = 255
## Condiciones en el orden de sContestStatsMonData.
const CONDICIONES: Array[StringName] = [&"carisma", &"dureza", &"ingenio", &"dulzura", &"belleza"]
## gUnknown_0840612C: sabor (0 picante … 4 ácido) asociado a cada condición.
const SABOR_DE_CONDICION: Array[int] = [0, 4, 3, 2, 1]
## gNatureNames (orden canónico del decomp) con los nombres de la versión española,
## sin tildes para comparar.
const NOMBRES_NATURALEZA: Array[String] = [
	"FUERTE", "HURANA", "AUDAZ", "FIRME", "PICARA",
	"OSADA", "DOCIL", "PLACIDA", "AGITADA", "FLOJA",
	"MIEDOSA", "ACTIVA", "SERIA", "ALEGRE", "INGENUA",
	"MODESTA", "AFABLE", "MANSA", "TIMIDA", "ALOCADA",
	"SERENA", "AMABLE", "GROSERA", "CAUTA", "RARA",
]
## Nombres de la tabla `Naturalezas` de poke.db que no son oficiales, con la
## naturaleza a la que equivalen por sus estadísticas en esa tabla.
const ALIAS_NATURALEZA: Dictionary = {
	"SOLITARIA": 1, # Lonely (+ataque −defensa)
	"TRAVIESA": 3, # Adamant (+ataque −at. especial)
}


## Resultado de dar de comer un cubo, para que la UI escriba los textos.
class Resultado:
	extends RefCounted
	## false si no comió (brillo 255, Pokémon nulo, huevo o cubo vacío): no se gasta el cubo.
	var comio: bool = false
	## Signo de la ganancia: «tan feliz» / «normal» / «con desdén» (pokeblock_feed.c:722-740).
	var reaccion: Reaccion = Reaccion.INDIFERENTE
	## PokeblockGetGain(naturaleza, cubo).
	var ganancia: int = 0
	## Condiciones que cambiaron (en el orden de CONDICIONES), para «X subió».
	var condiciones_subidas: Array[StringName] = []
	## Lo que subió de verdad cada condición (tras el tope de 255), por nombre de campo.
	var incrementos: Dictionary = {}
	var brillo_anterior: int = 0
	var brillo_nuevo: int = 0


# ============================================================================
# Naturaleza y gusto por los sabores
# ============================================================================

## Índice canónico (0-24) de un nombre de naturaleza en español, con o sin tildes y
## en cualquier caja; -1 si no se reconoce.
static func indice_naturaleza_por_nombre(nombre: String) -> int:
	var clave: String = _normalizar(nombre)
	if clave.is_empty():
		return -1
	var indice: int = NOMBRES_NATURALEZA.find(clave)
	if indice >= 0:
		return indice
	return int(ALIAS_NATURALEZA.get(clave, -1))


## Índice canónico de la naturaleza del Pokémon (ver la cabecera del script).
static func indice_naturaleza(pokemon: BasePokemon) -> int:
	var indice: int = indice_naturaleza_por_nombre(pokemon.naturaleza)
	if indice >= 0:
		return indice
	return (pokemon.personalidad & 0xFFFFFFFF) % 25


## gPokeblockFlavorCompatibilityTable[naturaleza][sabor]: 1 le gusta, −1 no, 0 igual.
static func relacion_sabor(indice_nat: int, sabor: int) -> int:
	if indice_nat < 0 or indice_nat >= 25 or sabor < 0 or sabor >= Pokecubo.NUM_SABORES:
		return 0
	return int(BayasSabor.RELATIONS[indice_nat][sabor])


## PokeblockGetGain (src/pokeblock.c:1113-1127): Σ sabor · relación para los sabores > 0.
static func ganancia(indice_nat: int, cubo: Pokecubo) -> int:
	var total: int = 0
	for i in Pokecubo.NUM_SABORES:
		var valor: int = cubo.sabor(i)
		if valor > 0:
			total += valor * relacion_sabor(indice_nat, i)
	return total


static func reaccion_de_ganancia(valor: int) -> Reaccion:
	if valor > 0:
		return Reaccion.LE_GUSTA
	if valor < 0:
		return Reaccion.NO_LE_GUSTA
	return Reaccion.INDIFERENTE


## Primer sabor básico (0 ROJO … 4 AMARILLO) con ganancia positiva para la naturaleza,
## -1 si es neutra (sub_810CB68, el experto de ALGARIA).
static func sabor_preferido(indice_nat: int) -> int:
	for sabor in Pokecubo.NUM_SABORES:
		if relacion_sabor(indice_nat, sabor) > 0:
			return sabor
	return -1


# ============================================================================
# Dar de comer
# ============================================================================

## sub_8137058: con brillo 255 no quiere comer más. Los HUEVOS no se pueden elegir.
static func puede_comer(pokemon: BasePokemon) -> bool:
	return pokemon != null and not pokemon.huevo and pokemon.brillo < VALOR_MAXIMO


## sub_8136F74: lo que suma el cubo a cada condición (orden CONDICIONES) con la
## naturaleza `indice_nat`, antes de aplicar el tope. Nunca es negativo.
static func aumentos_condicion(cubo: Pokecubo, indice_nat: int) -> Array[int]:
	var aumentos: Array[int] = []
	for c in CONDICIONES.size():
		aumentos.append(cubo.sabor(SABOR_DE_CONDICION[c]))
	var g: int = ganancia(indice_nat, cubo)
	if g == 0:
		return aumentos
	var direccion: int = 1 if g > 0 else -1
	for c in CONDICIONES.size():
		var cantidad: int = aumentos[c]
		var extra: int = cantidad / 10
		if cantidad % 10 >= 5:
			extra += 1
		var gusto: int = relacion_sabor(indice_nat, SABOR_DE_CONDICION[c])
		if gusto == direccion:
			aumentos[c] += extra * gusto
	return aumentos


## Da `cubo` a `pokemon` (modifica sus condiciones y su brillo) y devuelve el
## resultado. No toca el estuche: si `comio`, quien llama quita el cubo
## (EstuchePokecubos.quitar, como PokeblockClearIfExists).
static func dar_de_comer(pokemon: BasePokemon, cubo: Pokecubo) -> Resultado:
	var resultado := Resultado.new()
	if pokemon == null or cubo == null or cubo.esta_vacio():
		return resultado
	resultado.brillo_anterior = pokemon.brillo
	resultado.brillo_nuevo = pokemon.brillo
	if not puede_comer(pokemon):
		return resultado
	var indice_nat: int = indice_naturaleza(pokemon)
	resultado.ganancia = ganancia(indice_nat, cubo)
	resultado.reaccion = reaccion_de_ganancia(resultado.ganancia)
	var aumentos: Array[int] = aumentos_condicion(cubo, indice_nat)
	for c in CONDICIONES.size():
		var campo: StringName = CONDICIONES[c]
		var antes: int = int(pokemon.get(campo))
		var despues: int = clampi(antes + aumentos[c], 0, VALOR_MAXIMO)
		pokemon.set(campo, despues)
		if despues != antes:
			resultado.condiciones_subidas.append(campo)
			resultado.incrementos[campo] = despues - antes
	pokemon.brillo = mini(pokemon.brillo + cubo.suavidad, VALOR_MAXIMO)
	resultado.brillo_nuevo = pokemon.brillo
	resultado.comio = true
	return resultado


static func _normalizar(nombre: String) -> String:
	var t: String = nombre.strip_edges().to_upper()
	for par in [["Á", "A"], ["É", "E"], ["Í", "I"], ["Ó", "O"], ["Ú", "U"], ["Ñ", "N"], ["Ü", "U"]]:
		t = t.replace(par[0], par[1])
	return t

extends RefCounted
## Fórmula de captura de Gen 3 (pokeruby `atkEF_handleballthrow`,
## src/battle_script_commands.c, y `sBallCatchBonuses`). Pura: no toca la
## escena de batalla ni SistemaGuardado; lo que depende del estado del juego
## (turnos, inmersión, Pokédex) llega en `contexto`, y el ratio de captura de
## la especie lo resuelve quien llama (DatabaseManager.obtener_ratio_captura).
##
## Toda la aritmética es entera, como en el original: los multiplicadores de
## ball van en décimas (×1.5 = 15) y `Random()` es de 16 bits.
##
## Sin `class_name` a propósito: se usa con `preload()` (igual que
## BattleItemEvaluator en batalla.gd) para no forzar la regeneración de la
## caché global de clases.

## Nombres internos (tabla Objetos) de las balls que maneja la fórmula.
const MASTERBALL := "MASTERBALL"
const ULTRABALL := "ULTRABALL"
const SUPERBALL := "SUPERBALL"
const POKEBALL := "POKEBALL"
const SAFARIBALL := "SAFARIBALL"
const MALLABALL := "MALLABALL"
const BUCEOBALL := "BUCEOBALL"
const NIDOBALL := "NIDOBALL"
const ACOPIOBALL := "ACOPIOBALL"
const TURNOBALL := "TURNOBALL"
const LUJOBALL := "LUJOBALL"
const HONORBALL := "HONORBALL"

## Balls de Gen 4 presentes en la BD. Sin efecto propio todavía: ×1.
## TODO: OCASO (noche/cueva), SANA (cura), VELOZ (primer turno), GLORIA.
const BALLS_GEN_4: PackedStringArray = ["OCASOBALL", "SANABALL", "VELOZBALL", "GLORIABALL"]

## Multiplicadores fijos en décimas (pokeruby sBallCatchBonuses: Ultra,
## Super, Poké, Safari; LUJO/HONOR ×1).
const MULTIPLICADORES_FIJOS: Dictionary = {
	ULTRABALL: 20,
	SUPERBALL: 15,
	POKEBALL: 10,
	# TODO: en la ZONA SAFARI el ratio sale de safariCatchFactor, no de la especie.
	SAFARIBALL: 15,
	LUJOBALL: 10,
	HONORBALL: 10,
}

## Mensajes cuando el Pokémon se escapa, indexados por sacudidas (0-3)
## (pokeruby gBallEscapeStringIds).
const MENSAJES_ESCAPE: PackedStringArray = [
	"¡Oh, no! ¡El POKéMON\nse ha escapado!",
	"¡Vaya! ¡Parecía que\nlo había atrapado!",
	"¡Qué pena!\n¡Casi lo consigues!",
	"¡Uf!\n¡Estuvo a punto!",
]

const SACUDIDAS_CAPTURA := 4


## true si `nombre_interno` es una ball que la fórmula sabe lanzar.
static func es_ball(nombre_interno: String) -> bool:
	var ball := nombre_interno.to_upper()
	return ball == MASTERBALL or MULTIPLICADORES_FIJOS.has(ball) or BALLS_GEN_4.has(ball) \
		or ball in [MALLABALL, BUCEOBALL, NIDOBALL, ACOPIOBALL, TURNOBALL]


## Nombre de la ball para mostrar en mensajes. `obtener_datos_objeto_completos`
## pasa el nombre a mayúsculas ("POKÉ BALL"); en Gen 3 se escribe "POKé".
static func nombre_ball_mostrar(nombre: String) -> String:
	return nombre.replace("POKÉ", "POKé")


## Mensaje de escape para `sacudidas` (0-3).
static func mensaje_escape(sacudidas: int) -> String:
	return MENSAJES_ESCAPE[clampi(sacudidas, 0, MENSAJES_ESCAPE.size() - 1)]


## Multiplicador de la ball en décimas. `contexto`:
##   "turnos": int — turnos completados en la batalla (TURNO BALL),
##   "bajo_agua": bool — combate bajo el agua (BUCEO BALL),
##   "especie_atrapada": bool — la especie ya figura como atrapada (ACOPIO BALL).
static func multiplicador_ball(nombre_interno: String, pokemon: BasePokemon, contexto: Dictionary = {}) -> int:
	var ball := nombre_interno.to_upper()
	if MULTIPLICADORES_FIJOS.has(ball):
		return int(MULTIPLICADORES_FIJOS[ball])
	match ball:
		MALLABALL:
			return 30 if _tiene_tipo(pokemon, "AGUA") or _tiene_tipo(pokemon, "BICHO") else 10
		BUCEOBALL:
			return 35 if bool(contexto.get("bajo_agua", false)) else 10
		NIDOBALL:
			return maxi(40 - pokemon.nivel, 10)
		ACOPIOBALL:
			return 30 if bool(contexto.get("especie_atrapada", false)) else 10
		TURNOBALL:
			return mini(int(contexto.get("turnos", 0)) + 10, 40)
	# Master Ball (no usa multiplicador), balls de Gen 4 y desconocidas: ×1.
	return 10


## Valor `odds` de pokeruby antes del cálculo de sacudidas.
@warning_ignore("integer_division")
static func calcular_odds(nombre_interno: String, ratio_captura: int, pokemon: BasePokemon, contexto: Dictionary = {}) -> int:
	var multiplicador := multiplicador_ball(nombre_interno, pokemon, contexto)
	var ps_max := maxi(pokemon.estad_ps, 1)
	var ps := clampi(pokemon.estad_ps_actual, 0, ps_max)
	var odds := (clampi(ratio_captura, 0, 255) * multiplicador / 10) * (ps_max * 3 - ps * 2) / (3 * ps_max)
	var estado := pokemon.estado
	if estado == Singleton.ProblemaEstado.DORMIDO or estado == Singleton.ProblemaEstado.CONGELADO:
		odds *= 2
	# pokeruby excluye STATUS1_TOXIC_POISON de este bonus (comentado en el
	# original); ProblemaEstado aún no distingue el envenenamiento grave.
	elif estado == Singleton.ProblemaEstado.ENVENENADO or estado == Singleton.ProblemaEstado.QUEMADO \
			or estado == Singleton.ProblemaEstado.PARALIZADO:
		odds = odds * 15 / 10
	return odds


## Umbral de cada sacudida para `odds` <= 254:
## 1048560 / sqrt(sqrt(16711680 / odds)), con raíces enteras.
@warning_ignore("integer_division")
static func umbral_sacudida(odds: int) -> int:
	if odds <= 0:
		return 0
	return 1048560 / raiz_entera(raiz_entera(16711680 / odds))


## Resuelve un lanzamiento. `rng` devuelve un entero de 16 bits (0-65535);
## por defecto usa randi(). Devuelve {"atrapado": bool, "sacudidas": int}
## con sacudidas 0-3 si se escapa y 4 si se atrapa.
static func calcular_captura(nombre_interno: String, ratio_captura: int, pokemon: BasePokemon, contexto: Dictionary = {}, rng: Callable = Callable()) -> Dictionary:
	if nombre_interno.to_upper() == MASTERBALL:
		return {"atrapado": true, "sacudidas": SACUDIDAS_CAPTURA}
	var odds := calcular_odds(nombre_interno, ratio_captura, pokemon, contexto)
	if odds > 254:
		return {"atrapado": true, "sacudidas": SACUDIDAS_CAPTURA}
	var umbral := umbral_sacudida(odds)
	var sacudidas := 0
	while sacudidas < SACUDIDAS_CAPTURA and _random_16(rng) < umbral:
		sacudidas += 1
	return {"atrapado": sacudidas == SACUDIDAS_CAPTURA, "sacudidas": sacudidas}


## Raíz cuadrada entera por defecto (la `Sqrt` del BIOS de GBA).
static func raiz_entera(valor: int) -> int:
	if valor <= 0:
		return 0
	var raiz := int(sqrt(float(valor)))
	while raiz * raiz > valor:
		raiz -= 1
	while (raiz + 1) * (raiz + 1) <= valor:
		raiz += 1
	return raiz


static func _random_16(rng: Callable) -> int:
	if rng.is_valid():
		return int(rng.call()) & 0xFFFF
	return randi() & 0xFFFF


static func _tiene_tipo(pokemon: BasePokemon, tipo: String) -> bool:
	return pokemon.tipo_1.to_upper() == tipo or pokemon.tipo_2.to_upper() == tipo

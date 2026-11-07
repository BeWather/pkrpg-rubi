extends RefCounted
class_name BattleMoveSchedule
## Pure Ruby schedule facts. Animation resources cannot choose real hit count.

const MULTIHIT := ["EFFECT_MULTI_HIT", "EFFECT_DOUBLE_HIT", "EFFECT_TWINEEDLE", "EFFECT_TRIPLE_KICK"]

static func es_multigolpe(move: Movimiento) -> bool:
	return move != null and MULTIHIT.has(move.get_efecto())

static func conteo(move: Movimiento, draw: Callable) -> int:
	match move.get_efecto():
		"EFFECT_DOUBLE_HIT", "EFFECT_TWINEEDLE": return 2
		"EFFECT_TRIPLE_KICK": return 3
		"EFFECT_MULTI_HIT":
			var first := int(draw.call()) & 3
			return first + 2 if first <= 1 else (int(draw.call()) & 3) + 2
	return 1

static func potencia(move: Movimiento, index: int) -> int:
	return (index + 1) * 10 if move.get_efecto() == "EFFECT_TRIPLE_KICK" else -1

const CHARGE := ["EFFECT_RAZOR_WIND", "EFFECT_SOLARBEAM", "EFFECT_SKULL_BASH", "EFFECT_SKY_ATTACK", "EFFECT_FLY"]

static func es_carga(move: Movimiento) -> bool:
	return move != null and CHARGE.has(move.get_efecto())

static func carga_necesaria(move: Movimiento, field: CampoCombate) -> bool:
	return move.get_efecto() != "EFFECT_SOLARBEAM" or field.clima_efectivo() != 1

static func contribuye_beatup(pokemon: BasePokemon) -> bool:
	return pokemon != null and pokemon.estad_ps_actual > 0 and not pokemon.nombre_interno.is_empty() and not pokemon.huevo and pokemon.estado == Singleton.ProblemaEstado.NORMAL

static func dano_beatup(base_attack: int, level: int, base_defense: int) -> int:
	var damage: int = base_attack * 10 * (level * 2 / 5 + 2)
	damage /= maxi(1, base_defense)
	return damage / 50 + 2

static func semi_estado(move: Movimiento) -> String:
	match move.get_nombre_interno():
		"VUELO", "BOTE": return "air"
		"EXCAVAR": return "underground"
		"BUCEO": return "underwater"
	return ""

## Accuracy helper runs this BEFORE always-hit/weather shortcuts. Sure-hit
## Lock-On/Mind Reader are not represented by the current combat domain.
static func multiplicador_semi(move: Movimiento, target: PokemonEnCombate) -> float:
	if target == null or target.semi_invulnerable.is_empty(): return 1.0
	var name := move.get_nombre_interno()
	match target.semi_invulnerable:
		"air":
			if move.get_efecto()=="EFFECT_SKY_UPPERCUT" or name=="SKY_UPPERCUT":return 1.0
			if name in ["TORNADO", "CICLON"]: return 2.0
			if name in ["TRUENO", "GANCHOALTO"]: return 1.0
		"underground":
			if name in ["TERREMOTO", "MAGNITUD"]: return 2.0
		"underwater":
			if name in ["SURF", "TORBELLINO"]: return 2.0
	return 0.0

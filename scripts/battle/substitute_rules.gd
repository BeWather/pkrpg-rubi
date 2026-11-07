extends RefCounted
class_name BattleSubstituteRules
## Source contract seam: accepted domain facts never come from animation events.
static func accept(state: PokemonEnCombate) -> Dictionary:
	if state==null or state.pokemon_base==null:return {"accepted":false,"cost":0}
	var pokemon: BasePokemon=state.pokemon_base
	var cost: int=maxi(1,pokemon.estad_ps/4)
	if state.substitute_hp>0 or pokemon.estad_ps_actual<=cost:return {"accepted":false,"cost":0}
	# Source atk9C + datahpupdate USER/IGNORE_SUBSTITUTE. Claim precedes HUD waits.
	pokemon.estad_ps_actual-=cost;state.substitute_hp=cost
	state.esta_atrapado=false;state.turnos_atrapado=0
	return {"accepted":true,"cost":cost}

static func absorb(state: PokemonEnCombate, damage: int) -> Dictionary:
	if state==null or state.substitute_hp<=0 or damage<=0:return {"substitute":false}
	var dealt: int=mini(state.substitute_hp,damage)
	state.substitute_hp-=dealt
	return {"substitute":true,"substitute_broken":state.substitute_hp==0,"damage":dealt,"endured":false}

static func blocks_status(move: Movimiento, actor: BasePokemon, target: BasePokemon, state: PokemonEnCombate) -> bool:
	if move==null or state==null or state.substitute_hp<=0 or actor==target:return false
	# Explicit supported source handlers, not a modern sound/Infiltrator bypass
	# or a blanket ban on Roar, field effects, self buffs and future migrations.
	if CambioEstadisticaGen3.es_movimiento_de_estadistica(move):return not CambioEstadisticaGen3.apunta_al_usuario(move)
	return move.get_efecto() in ["EFFECT_SLEEP","EFFECT_POISON","EFFECT_TOXIC","EFFECT_PARALYZE","EFFECT_WILL_O_WISP","EFFECT_CONFUSE","EFFECT_SWAGGER","EFFECT_FLATTER","EFFECT_YAWN"] or move.get_nombre_interno().to_upper().replace("-","") in ["YAWN","TOXIC","THUNDERWAVE"]

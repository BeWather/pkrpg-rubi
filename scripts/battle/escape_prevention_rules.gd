extends RefCounted
## Ruby MOVE_EFFECT_PREVENT_ESCAPE: volatile holder identity, not residual Bind.
const KEY="source_prevent_escape"
static func apply(actor: PokemonEnCombate,target: PokemonEnCombate,move_id: int=169) -> bool:
	if actor==null or target==null or actor.pokemon_base.estad_ps_actual<=0 or target.pokemon_base.estad_ps_actual<=0:return false
	if target.has_meta(KEY):return false
	target.set_meta(KEY,{"state":weakref(actor),"pokemon":weakref(actor.pokemon_base),"move_id":move_id})
	return true
static func blocked(pokemon: BasePokemon,field: CampoCombate) -> Dictionary:
	if not field.combatiente_de.is_valid():return {}
	var state: PokemonEnCombate=field.combatiente_de.call(pokemon)
	if state==null or not state.has_meta(KEY):return {}
	var trap: Dictionary=state.get_meta(KEY)
	var holder: PokemonEnCombate=trap.state.get_ref();var source: BasePokemon=trap.pokemon.get_ref()
	if holder==null or source==null or source.estad_ps_actual<=0 or not field.todos().has(source) or field.combatiente_de.call(source)!=holder:
		state.remove_meta(KEY);return {}
	return {"bloqueador":source,"source_move":int(trap.get("move_id",169))}

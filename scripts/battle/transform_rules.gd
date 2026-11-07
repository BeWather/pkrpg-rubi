extends RefCounted
class_name BattleTransformRules
## Native battle identity overlay. Party objects and database identity are never
## rewritten; legacy pure combat readers resolve only a live owner-scoped view.
static var _active: Dictionary={}
const STAGES: Array[String]=["mod_ataque","mod_defensa","mod_ataque_especial","mod_defensa_especial","mod_velocidad","mod_precision","mod_evasion"]
const STATS: Array[String]=["estad_ataque","estad_defensa","estad_ataque_especial","estad_defensa_especial","estad_velocidad"]

static func state_for(pokemon: BasePokemon) -> PokemonEnCombate:
	if pokemon==null or not _active.has(pokemon.get_instance_id()):return null
	var record: Dictionary=_active[pokemon.get_instance_id()]
	var state: PokemonEnCombate=record.state.get_ref()
	var owner: BattleSceneController=record.owner.get_ref()
	if state==null or not is_instance_valid(owner) or not owner.is_inside_tree() or owner.fase==owner.FIN_BATALLA or owner._obtener_combatiente(pokemon)!=state:
		if state!=null:retire(state)
		else:_active.erase(pokemon.get_instance_id())
		return null
	return state

static func data(pokemon: BasePokemon) -> Dictionary:
	var state: PokemonEnCombate=state_for(pokemon)
	return state.get_meta("transform_domain",{}) if state!=null else {}

static func types(pokemon: BasePokemon) -> Array[String]:
	var state: PokemonEnCombate=state_for(pokemon)
	if state!=null and state.has_meta("battle_type_override"):
		var result: Array[String]=[];result.assign(state.get_meta("battle_type_override"));return result
	var copy: Dictionary=data(pokemon)
	return [str(copy.get("type_1",pokemon.tipo_1)),str(copy.get("type_2",pokemon.tipo_2))]

static func bind_types(owner: BattleSceneController,state: PokemonEnCombate,first: String,second: String) -> void:
	if state.has_meta("transform_domain"):
		var copy: Dictionary=state.get_meta("transform_domain");copy.type_1=first;copy.type_2=second
	else:state.set_meta("battle_type_override",[first,second])
	_active[state.pokemon_base.get_instance_id()]={"state":weakref(state),"owner":weakref(owner)}

static func set_types(pokemon: BasePokemon, first: String, second: String) -> bool:
	var state: PokemonEnCombate=state_for(pokemon)
	if state!=null and state.has_meta("battle_type_override"):state.set_meta("battle_type_override",[first,second]);return true
	var copy: Dictionary=data(pokemon)
	if copy.is_empty():return false
	copy.type_1=first;copy.type_2=second
	return true

static func stat(state: PokemonEnCombate, property: String, fallback: int) -> int:
	var copy: Dictionary=state.get_meta("transform_domain",{})
	return int(copy.get("stats",{}).get(property,fallback))

static func bind_moves(owner: BattleSceneController,state: PokemonEnCombate,moves: Array) -> void:
	state.set_meta("mimic_moves",moves)
	_active[state.pokemon_base.get_instance_id()]={"state":weakref(state),"owner":weakref(owner)}

static func moves(pokemon: BasePokemon) -> Array[Movimiento]:
	var state: PokemonEnCombate=state_for(pokemon)
	var result: Array[Movimiento]=[]
	result.assign(state.get_movimientos() if state!=null else pokemon.movimientos)
	return result

static func accept(owner: BattleSceneController, actor: PokemonEnCombate, target: PokemonEnCombate, action: BattleMoveAction) -> Dictionary:
	if not action.transform_resolution.is_empty():return action.transform_resolution
	var accepted: Dictionary={"accepted":false}
	action.transform_resolution=accepted
	if actor==null or target==null or target.has_meta("transform_domain") or not target.semi_invulnerable.is_empty():return accepted
	var mon: BasePokemon=target.pokemon_base
	var copy: Dictionary={"species":mon.nombre_interno,"type_1":types(mon)[0],"type_2":types(mon)[1],"ability":HabilidadesCombate.de(mon),"stats":{},"moves":[],"ivs":{},"transformed_personality":mon.personalidad}
	for property: String in STATS:copy.stats[property]=mon.get(property)
	for property: String in ["iv_ps","iv_ataque","iv_defensa","iv_ataque_especial","iv_defensa_especial","iv_velocidad"]:copy.ivs[property]=mon.get(property)
	# Snapshot every source operand before copying into a possibly self target.
	var stages: Dictionary={}
	for property: String in STAGES:stages[property]=target.get(property)
	for move: Movimiento in mon.movimientos.slice(0,4):
		var base_pp: int=int(move._dato_combate("max_pp",move.pp_tot))
		var pp: int=mini(base_pp,5)
		copy.moves.append(Movimiento.new(move.nombre,pp,0,pp,move.datos.duplicate(true)))
	if actor.has_meta("battle_type_override"):actor.remove_meta("battle_type_override")
	if actor.has_meta("mimic_moves"):actor.remove_meta("mimic_moves")
	actor.set_meta("transform_domain",copy)
	for property: String in STAGES:actor.set(property,stages[property])
	_active[actor.pokemon_base.get_instance_id()]={"state":weakref(actor),"owner":weakref(owner)}
	accepted.accepted=true;accepted.snapshot=copy
	return accepted

static func retire(state: PokemonEnCombate) -> void:
	if state==null:return
	if state.has_meta("battle_type_override"):state.remove_meta("battle_type_override")
	if state.has_meta("mimic_moves"):state.remove_meta("mimic_moves")
	if state.has_meta("transform_domain"):
		state.remove_meta("transform_domain")
		for property: String in STAGES:state.set(property,0)
	var id: int=state.pokemon_base.get_instance_id()
	if _active.has(id) and _active[id].state.get_ref()==state:_active.erase(id)

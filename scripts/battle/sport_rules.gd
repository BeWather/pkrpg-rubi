class_name BattleSportRules
extends RefCounted
## Ruby user-held STATUS3 sports, not a modern five-turn field effect.
const EFFECTS={300:"EFFECT_MUD_SPORT",346:"EFFECT_WATER_SPORT"}
const TYPES={"EFFECT_MUD_SPORT":"ELECTRICO","EFFECT_WATER_SPORT":"FUEGO"}
static func supports(move: Movimiento) -> bool:
	return move!=null and EFFECTS.get(int(move.datos.get("numero_movimiento",0)),"")==move.get_efecto() and move.get_efecto() in TYPES
static func capture(move: Movimiento) -> Dictionary:
	var id: int=int(move.datos.get("numero_movimiento",0));var data: Dictionary=move.datos.duplicate(true)
	data.objetivo_id=7;data.precision=100;data.max_pp=15;data.pp=15;data.potencia=0;data.tipo="TIERRA" if id==300 else "AGUA"
	return {"id":id,"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_sport"):return move
	var fact: Dictionary=phase.source_sport
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
static func produce(battle: Node,action: BattleMoveAction,move: Movimiento) -> bool:
	if not supports(move) or not BattleScreenRules.action_live(action):return false
	var state: PokemonEnCombate=battle._obtener_combatiente(action.attacker)
	if state==null or state.pokemon_base.estad_ps_actual<=0 or state.has_meta(move.get_efecto()):return false
	state.set_meta(move.get_efecto(),true);return true
static func power(value: float,type: String,field: CampoCombate) -> float:
	if field==null or not field.combatiente_de.is_valid():return value
	var effect: String="EFFECT_MUD_SPORT" if type=="ELECTRICO" else "EFFECT_WATER_SPORT" if type=="FUEGO" else ""
	if effect.is_empty():return value
	for pokemon: BasePokemon in field.todos():
		if pokemon==null or pokemon.estad_ps_actual<=0:continue
		var state: PokemonEnCombate=field.combatiente_de.call(pokemon)
		if state!=null and state.has_meta(effect):return float(int(int(value)/2)) # gBattleMovePower /=2, BEFORE base+2.
	return value

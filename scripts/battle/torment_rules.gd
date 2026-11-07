extends RefCounted
## Ruby Torment is untimed status2; compare live last-used ID, never a Disable timer.
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==259
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true);data.categoria_dano_id=3;data.potencia=0;data.tipo="SINIESTRO";data.precision=100;data.max_pp=15;data.pp=15;data.contacto=0;data.objetivo_id=10;data.prioridad=0;data.prob_secundario=0;data.efecto="EFFECT_TORMENT"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_torment"):return move
	var fact: Dictionary=phase.source_torment
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
static func blocked(battle: Node,pokemon: BasePokemon,move: Movimiento) -> bool:
	if pokemon==null or move==null:return false
	var state: PokemonEnCombate=battle._obtener_combatiente(pokemon);var id: int=int(move.datos.get("numero_movimiento",0))
	return state!=null and state.source_tormented and id>0 and id!=165 and id==state.source_last_result_move
static func produce(battle: Node,target: BasePokemon) -> bool:
	var state: PokemonEnCombate=battle._obtener_combatiente(target)
	if state==null or state.source_tormented:return false
	state.source_tormented=true;return true

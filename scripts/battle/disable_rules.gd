extends RefCounted
## Ruby Disable: current last-used slot with PP; battle-local ID and 2–5 turn timer.
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0))==50
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true)
	data.categoria_dano_id=3;data.potencia=0;data.tipo="NORMAL";data.precision=55;data.max_pp=20;data.pp=20;data.contacto=0;data.objetivo_id=10;data.prioridad=0;data.prob_secundario=0;data.efecto="EFFECT_DISABLE"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_disable"):return move
	var fact: Dictionary=phase.source_disable
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
static func _id(move: Movimiento) -> int:
	return int(move.datos.get("numero_movimiento",0)) if move!=null else 0
static func slot(pokemon: BasePokemon,id: int) -> Movimiento:
	if id<=0 or id>=65535:return null
	for move: Movimiento in BattleTransformRules.moves(pokemon).slice(0,4):
		if _id(move)==id:return move
	return null
static func blocked(battle: Node,pokemon: BasePokemon,move: Movimiento) -> bool:
	var state: PokemonEnCombate=battle._obtener_combatiente(pokemon) if pokemon!=null else null
	return state!=null and move!=null and state.source_disable_turns>0 and state.source_disabled_move>0 and _id(move)==state.source_disabled_move
static func produce(battle: Node,target: BasePokemon) -> bool:
	var state: PokemonEnCombate=battle._obtener_combatiente(target)
	if state==null or state.source_disabled_move!=0:return false
	var last: Movimiento=slot(target,state.source_last_chosen_move)
	if last==null or last.pp_act<=0:return false
	state.source_disabled_move=_id(last);state.source_disable_turns=(randi()&3)+2;state.source_disable_start_turns=state.source_disable_turns
	return true
static func end_round(battle: Node,pokemon: BasePokemon,state: PokemonEnCombate) -> void:
	if state==null or state.source_disable_turns<=0 or pokemon.estad_ps_actual<=0:return
	if slot(pokemon,state.source_disabled_move)==null:state.source_disable_turns=0;state.source_disabled_move=0;return
	state.source_disable_turns-=1
	if state.source_disable_turns==0:
		state.source_disabled_move=0
		await battle.mostrar_texto_batalla("¡%s ya puede usar su movimiento!"%pokemon.get_nombre_combate())

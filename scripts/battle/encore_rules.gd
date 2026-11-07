extends RefCounted
## Ruby Encore owns a last-used current slot, not a cloned locked move or Disable flag.
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==227
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true);data.categoria_dano_id=3;data.potencia=0;data.tipo="NORMAL";data.precision=100;data.max_pp=5;data.pp=5;data.contacto=0;data.objetivo_id=10;data.prioridad=0;data.prob_secundario=0;data.efecto="EFFECT_ENCORE"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_encore"):return move
	var fact: Dictionary=phase.source_encore
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
static func _clear(state: PokemonEnCombate) -> void:state.source_encore_move=0;state.source_encore_slot=-1;state.source_encore_turns=0
static func move(battle: Node,pokemon: BasePokemon) -> Movimiento:
	if pokemon==null:return null
	var state: PokemonEnCombate=battle._obtener_combatiente(pokemon)
	if state==null or state.source_encore_turns<=0:return null
	var slots: Array=BattleTransformRules.moves(pokemon)
	if state.source_encore_slot<0 or state.source_encore_slot>=mini(4,slots.size()):_clear(state);return null
	var current: Movimiento=slots[state.source_encore_slot]
	if current==null or int(current.datos.get("numero_movimiento",0))!=state.source_encore_move:_clear(state);return null
	return current
static func blocked_choice(battle: Node,pokemon: BasePokemon,chosen: Movimiento) -> bool:
	var forced: Movimiento=move(battle,pokemon)
	return forced!=null and chosen!=forced
static func produce(battle: Node,target: BasePokemon) -> bool:
	var state: PokemonEnCombate=battle._obtener_combatiente(target)
	if state==null or state.source_encore_move!=0 or state.source_last_result_move in [0,65535,165,227,119]:return false
	var slots: Array=BattleTransformRules.moves(target).slice(0,4)
	for index: int in slots.size():
		var current: Movimiento=slots[index]
		if current!=null and int(current.datos.get("numero_movimiento",0))==state.source_last_result_move and current.pp_act>0:
			state.source_encore_move=state.source_last_result_move;state.source_encore_slot=index;state.source_encore_turns=(randi()&3)+3;return true
	return false
static func end_round(battle: Node,pokemon: BasePokemon,state: PokemonEnCombate) -> void:
	if state==null or state.source_encore_turns<=0 or pokemon.estad_ps_actual<=0:return
	var current: Movimiento=move(battle,pokemon)
	if current==null:return
	state.source_encore_turns-=1
	if state.source_encore_turns==0 or current.pp_act==0:
		_clear(state);await battle.mostrar_texto_batalla("¡%s ya no está repitiendo su movimiento!"%pokemon.get_nombre_combate())

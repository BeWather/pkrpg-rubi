extends RefCounted
## Source Curse branch policy and real recurring volatile HP authority.
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0)) in [174,171]
static func capture(move: Movimiento,actor: BasePokemon) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true);var curse: bool=int(data.numero_movimiento)==174
	data.categoria_dano_id=3;data.potencia=0;data.tipo="???" if curse else "FANTASMA";data.precision=0 if curse else 100;data.max_pp=10 if curse else 15;data.pp=data.max_pp;data.contacto=0;data.objetivo_id=10;data.prioridad=0;data.prob_secundario=0;data.efecto="EFFECT_CURSE" if curse else "EFFECT_NIGHTMARE"
	if curse:data.source_curse_ghost="FANTASMA" in BattleTransformRules.types(actor)
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_curse_nightmare"):return move
	var fact: Dictionary=phase.source_curse_nightmare
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
static func self_branch(move: Movimiento,actor: BasePokemon=null) -> bool:
	if move==null or int(move.datos.get("numero_movimiento",0))!=174:return false
	return not bool(move.datos.source_curse_ghost) if move.datos.has("source_curse_ghost") else actor!=null and "FANTASMA" not in BattleTransformRules.types(actor)
static func residual(battle: Node,pokemon: BasePokemon,state: PokemonEnCombate) -> void:
	# Ruby residual itself has no sleep check; ordinary waking retires Nightmare.
	for pair: Array in [["source_nightmare",8],["source_cursed",7]]:
		if not bool(state.get(str(pair[0]))) or pokemon.estad_ps_actual<=0:continue
		var guard: Dictionary=battle.field_rules.capture(pokemon)
		var requested: int=maxi(1,pokemon.estad_ps/4)
		if not await battle.turno.presentar_fase_estado("ruby:status/%d"%int(pair[1]),pokemon):return
		if not battle.field_rules.valid(guard):return
		await battle.field_rules.passive_hp(guard,requested)
		if battle.field_rules.valid(guard):await battle.mostrar_texto_batalla("¡%s sufrió una pesadilla!"%pokemon.get_nombre_combate() if int(pair[1])==8 else "¡La maldición dañó a %s!"%pokemon.get_nombre_combate())

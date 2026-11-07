extends RefCounted
## Ruby Perish Song is combat-holder state, not a field/bank timer or direct attack.
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==195
static func capture(move: Movimiento) -> Dictionary:
	var d: Dictionary=move.datos.duplicate(true);d.tipo="NORMAL";d.categoria_dano_id=3;d.potencia=0;d.precision=0;d.max_pp=5;d.pp=5;d.objetivo_id=7;d.prioridad=0;d.contacto=0;d.prob_secundario=0;d.efecto="EFFECT_PERISH_SONG"
	return {"name":move.nombre,"data":d}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_perish_song"):return move
	if not phase.has("source_perish_admitted"):
		var fact: Dictionary=phase.source_perish_song;phase.source_perish_admitted=Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
	return phase.source_perish_admitted
static func produce(battle: Node) -> bool:
	var changed: bool=false
	for bank: int in range(4 if battle.formato_batalla==Singleton.FormatoBatalla.DOBLE else 2):
		var pokemon: BasePokemon=battle.turno._future_occupant(bank)
		if pokemon==null or pokemon.estad_ps_actual<=0:continue
		var state: PokemonEnCombate=battle._obtener_combatiente(pokemon)
		if state==null or state.source_perish_song or HabilidadesCombate.tiene(pokemon,HabilidadesCombate.INSONORIZAR):continue
		state.source_perish_song=true;state.source_perish_count=3;changed=true
	return changed
static func end_round(battle: Node) -> bool:
	# HandleWishPerishSongOnTurnEnd runs after Future attacks, in accepted action order.
	var order: Array[int]=[]
	for fact: Dictionary in battle.turno.get_meta("source_protect_projection",[]):
		if int(fact.bank) not in order:order.append(int(fact.bank))
	for bank: int in range(4 if battle.formato_batalla==Singleton.FormatoBatalla.DOBLE else 2):
		if bank not in order:order.append(bank)
	for bank: int in order:
		var pokemon: BasePokemon=battle.turno._future_occupant(bank)
		if pokemon==null or pokemon.estad_ps_actual<=0:continue
		var record: Dictionary=battle.field_rules.capture(pokemon)
		if record.is_empty():continue
		var state: PokemonEnCombate=record.state.get_ref()
		if not state.source_perish_song:continue
		var displayed: int=state.source_perish_count
		if displayed>0:state.source_perish_count-=1
		else:state.source_perish_song=false
		await battle.mostrar_texto_batalla("¡La cuenta de %s es %d!"%[pokemon.get_nombre_combate(),displayed])
		if not battle.field_rules.valid(record):return false
		if displayed==0:
			# Passive full-current-HP loss bypasses Substitute/Endure/body-hit provenance.
			await battle.field_rules.passive_hp(record,pokemon.estad_ps_actual)
			if not await battle.turno.settle_end_round_faints():return false
	return battle.turno._future_battle_live()

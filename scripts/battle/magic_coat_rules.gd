extends RefCounted
## Ruby atk00/DF/76. Payment, effective banks and MoveEnd owner are independent.
const KEY="source_magic_coat_ready"
static var _facts: Dictionary={}
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==277
static func eligible(move: Movimiento) -> bool:
	if move==null:return false
	if _facts.is_empty():_facts=JSON.parse_string(FileAccess.get_file_as_string("res://recursos/animaciones/magic_coat_eligible.json")).moves
	return _facts.has(str(int(move.datos.get("numero_movimiento",0))))
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true)
	if supports(move):
		data.tipo="PSIQUICO";data.categoria_dano_id=3;data.potencia=0;data.precision=100;data.max_pp=15;data.pp=15;data.contacto=0;data.objetivo_id=1;data.source_target_mask=16;data.prioridad=4;data.prob_secundario=0;data.efecto="EFFECT_MAGIC_COAT"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_magic_coat_policy"):return move
	var fact: Dictionary=phase.source_magic_coat_policy
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
static func produce(battle: Node,actor: BasePokemon,fact: Dictionary) -> bool:
	if fact.is_empty() or bool(fact.last):return false
	var state: PokemonEnCombate=battle._obtener_combatiente(actor)
	state.set_meta(KEY,int(battle.contador_turnos));return true
static func rebound(battle: Node,bouncer: BasePokemon,previous: BasePokemon) -> BasePokemon:
	var side: bool=bool(battle.field_rules.position(bouncer).player)
	for pokemon: BasePokemon in battle.pokemones_activos_enemigo if side else battle.pokemones_activos_jugador:
		if pokemon!=null and pokemon.estad_ps_actual>0 and battle._obtener_combatiente(pokemon).source_follow_me:return pokemon
	return previous
static func pressure(incoming: BasePokemon,state: PokemonEnCombate) -> void:
	if not HabilidadesCombate.tiene(incoming,HabilidadesCombate.PRESION):return
	# Combat slots include Transform/Mimic overlays; never mutate their party donors.
	for move: Movimiento in state.get_movimientos():
		if supports(move):move.pp_act=maxi(0,move.pp_act-1);return
static func reflect(controller: RefCounted,battle: Node,move: Movimiento,actor: BasePokemon,targets: Array[BasePokemon],phase: Dictionary) -> BattleMoveAction:
	if not eligible(move) or targets.size()!=1 or phase.has("source_magic_coat_resume"):return null
	var flow: Dictionary=phase.get("flow",{})
	if not battle.field_rules.valid_flow(flow):return null
	# Every possible rebound owner is captured before the first message. The
	# all-bank flow protects Follow Me holders too, including slot generation.
	var records: Dictionary={};var tickets: Dictionary={}
	for record: Dictionary in flow.records:
		var pokemon: BasePokemon=record.pokemon
		records[pokemon]=record
		var ticket: Dictionary=BattleProtectRules.capture_result(battle,pokemon,move)
		var chosen: Dictionary=phase.get("source_result_ticket",{})
		ticket.selected_id=int(chosen.get("selected_id",move.datos.get("numero_movimiento",0)));ticket.chosen_effect=str(chosen.get("chosen_effect",move.get_efecto()))
		tickets[pokemon]=ticket
	var effective: BasePokemon=actor;var recipient: BasePokemon=targets[0];var count: int=0
	while records.has(recipient) and battle.field_rules.valid_flow(flow):
		# Source MOVES_BLOCK (Soundproof) precedes consumption, not type immunity.
		if HabilidadesCombate.tiene(recipient,HabilidadesCombate.INSONORIZAR) and move.es_sonoro():break
		var state: PokemonEnCombate=records[recipient].state.get_ref()
		if state==null or recipient.estad_ps_actual<=0 or int(state.get_meta(KEY,-1))!=int(battle.contador_turnos):break
		pressure(effective,state);state.remove_meta(KEY)
		var previous: BasePokemon=effective;effective=recipient;recipient=rebound(battle,effective,previous);count+=1
		await battle.mostrar_texto_batalla("¡CAPA MÁGICA hizo rebotar %s de %s!"%[move.nombre,previous.get_nombre_combate()])
		if not battle.field_rules.valid_flow(flow):
			var aborted:=BattleMoveAction.new(actor,targets,"entry_aborted");return aborted
	if count==0:return null
	if not records.has(effective) or not records.has(recipient):return BattleMoveAction.new(actor,targets,"entry_aborted")
	phase.source_snatch_skip_history=true
	var parent: WeakRef=phase.get("source_magic_coat_parent_action")
	if parent!=null and parent.get_ref()!=null:parent.get_ref().set_meta("source_snatch_skip_history",true)
	var resumed: Dictionary=phase.duplicate(true)
	resumed.source_magic_coat_current_id=int(move.datos.get("numero_movimiento",0));resumed.source_magic_coat_resume=true;resumed.source_snatch_skip_history=false;resumed.actor=records[effective];resumed.source_result_ticket=tickets[effective]
	var rebound_targets: Array[BasePokemon]=[recipient]
	var result: BattleMoveAction=await controller._resolver_accion_objetivos(move,effective,rebound_targets,false,true,resumed)
	result.set_meta("source_magic_coat_bounces",count)
	return result
static func called_phase(controller: RefCounted,actor: BasePokemon,move: Movimiento,action: BattleMoveAction) -> Dictionary:
	var phase: Dictionary=controller._capturar_fase_movimiento(actor,move)
	if action.has_meta("source_body_admission"):phase.source_body_admission=action.get_meta("source_body_admission")
	var parent: Dictionary=action.get_meta("source_result_ticket",{})
	if not parent.is_empty():
		phase.source_result_ticket.selected_id=parent.selected_id;phase.source_result_ticket.chosen_effect=parent.chosen_effect
	# Called scripts retain the originally selected effective slot, not the
	# ephemeral called move or an independently owned matching party move.
	if action.has_meta("source_grudge_selected_slot"):phase.source_grudge_selected_slot=action.get_meta("source_grudge_selected_slot")
	phase.source_magic_coat_parent_action=weakref(action)
	return phase

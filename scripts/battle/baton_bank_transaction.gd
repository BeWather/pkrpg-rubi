extends RefCounted
## Ordinary shared-party DOUBLE USER switch. No queued permission follows the entry.
const Pass=preload("res://scripts/battle/baton_pass_rules.gd")
static func capture(battle: Node,actor: BasePokemon) -> Dictionary:
	var original: Dictionary=battle.field_rules.capture(actor)
	if original.is_empty():return {}
	return {"original":original,"flow":battle.field_rules.capture_flow([actor]),"transfer":Pass.transfer_fact(original.state.get_ref()),"choice":-1,"visible":original.slot.get_ref().sprite_pokemon.visible}
static func valid(battle: Node,ticket: Dictionary) -> bool:
	return is_instance_valid(battle) and not ticket.is_empty() and battle.field_rules.valid_flow(ticket.flow) and battle.field_rules.valid(ticket.original)
static func candidates(battle: Node,actor: BasePokemon) -> Array[int]:
	var bank: Dictionary=battle.field_rules.position(actor)
	var result: Array[int]=[]
	if bank.is_empty():return result
	var party: Array= battle.equipo_jugador_pokemones if bool(bank.player) else battle.equipo_enemigo_pokemones
	var active: Array=battle.pokemones_activos_jugador if bool(bank.player) else battle.pokemones_activos_enemigo
	for index: int in mini(6,party.size()):
		var mon: BasePokemon=party[index]
		if mon!=null and not mon.nombre_interno.is_empty() and not mon.huevo and mon.puede_combatir() and not active.has(mon):result.append(index)
	return result
static func accept(battle: Node,ticket: Dictionary,index: int) -> void:
	if valid(battle,ticket) and int(ticket.choice)<0 and candidates(battle,ticket.original.pokemon).has(index):
		var party: Array=battle.equipo_jugador_pokemones if bool(ticket.original.bank.player) else battle.equipo_enemigo_pokemones
		ticket.choice=index;ticket.selected=party[index]
static func complete(battle: Node,action: BattleMoveAction,ticket: Dictionary,entry: Dictionary) -> bool:
	if not battle.field_rules.valid_flow(ticket.flow) or not battle.field_rules.valid(entry) or entry.bank!=ticket.original.bank:return false
	var chain: Array[BattleMoveAction]=[]
	var current: BattleMoveAction=action
	while current!=null:
		var guard: Dictionary=current.get_meta("source_screen_phase_guard",{})
		if guard.is_empty() or guard.actor.pokemon!=ticket.original.pokemon or guard.actor.state.get_ref()!=ticket.original.state.get_ref() or int(guard.actor.epoch)!=int(ticket.original.epoch) or int(guard.actor.generation)!=int(ticket.original.generation):return false
		for record: Dictionary in guard.flow.records:
			if record.pokemon!=ticket.original.pokemon and not battle.field_rules.valid(record):return false
		chain.append(current)
		var parent: WeakRef=guard.get("source_magic_coat_parent_action")
		current=parent.get_ref() if parent!=null else null
	# Publish only after the WHOLE original caller chain has been validated.
	for original_action: BattleMoveAction in chain:
		original_action.set_meta("source_baton_completed",true);original_action.set_meta("source_item_moveend_reached",true);original_action.phase="baton_complete"
	return true
static func run(battle: Node,action: BattleMoveAction,ticket: Dictionary) -> Dictionary:
	if not valid(battle,ticket):return {}
	var result: RefCounted=battle.resultado
	var old: BasePokemon=ticket.original.pokemon
	var player: bool=bool(ticket.original.bank.player)
	var party: Array=battle.equipo_jugador_pokemones if player else battle.equipo_enemigo_pokemones
	var legal: Array[int]=candidates(battle,old)
	if legal.is_empty():return {}
	ticket.original.slot.get_ref().sprite_pokemon.visible=false
	if player:
		# Own routing BEFORE fade/menu callbacks. Poll domain lifetime, never leave
		# a signal waiter orphaned on FIN, epoch change, removed scene or round.
		result._baton_transaction=ticket;result.baton_choice_pending=true
		var screen: Node=battle.presentacion.pantalla_equipo
		screen.set_meta("source_baton_chooser",true)
		screen.set_meta("battle_blocked_party_indices",[party.find(battle.pokemones_activos_jugador[0]),party.find(battle.pokemones_activos_jugador[1])])
		await battle.mostrar_pantalla_equipo("Choose a POKéMON.",Singleton.ModoPEquipo.BATALLA_CAMBIO_FORZADO)
		while valid(battle,ticket) and int(ticket.choice)<0:await battle.get_tree().process_frame
		result.baton_choice_pending=false
		if is_instance_valid(screen):screen.ocultar_pantalla_equipo();screen.remove_meta("battle_blocked_party_indices");screen.remove_meta("source_baton_chooser")
		if valid(battle,ticket):await battle.presentacion.aclarar()
		result._baton_transaction={}
	else:
		# OpponentHandlecmd22, never the active partner or forceout RNG.
		var chosen: int=party.find(result.elegir_relevo_rival(old))
		ticket.choice=chosen if legal.has(chosen) else legal[0];ticket.selected=party[int(ticket.choice)]
	if not valid(battle,ticket) or not candidates(battle,old).has(int(ticket.choice)) or party[int(ticket.choice)]!=ticket.get("selected"):
		if is_instance_valid(battle) and battle.field_rules.valid(ticket.original):ticket.original.slot.get_ref().sprite_pokemon.visible=bool(ticket.visible)
		return {}
	var index: int=int(ticket.choice);var next: BasePokemon=ticket.selected
	var entry: Dictionary=await result.cambiar_slot_forzado_doble(ticket.original,next,index,ticket.transfer,ticket.flow)
	if entry.is_empty() or not battle.field_rules.valid_flow(ticket.flow) or not battle.field_rules.valid(entry):return {}
	# Lethal Spikes owns its retirement; ordinary recursive faint settlement
	# replaces it WITHOUT any transfer argument. Only that owned bank may change.
	if next.estad_ps_actual<=0:
		if await BattleTurnController.new(battle).verificar_entradas_baton(ticket.flow):return {}
		if not battle.field_rules.valid_flow(ticket.flow):return {}
		var successor: BasePokemon=battle.field_rules.occupant(ticket.original.bank)
		entry=battle.field_rules.capture(successor)
	else:
		var tail: Dictionary=preload("res://scripts/battle/held_status_berry_rules.gd").capture_tail(battle,battle.field_rules.capture_flow())
		if not await preload("res://scripts/battle/held_status_berry_rules.gd").settle_tail(battle,tail):return {}
	if not complete(battle,action,ticket,entry):return {}
	var selected: int=int(action.get_meta("source_result_ticket",{}).get("selected_id",226))
	# SwitchInClearSetData reset CurrentMove to NONE0. MoveEnd still writes the
	# original caller's CHOSEN/printed ID to this BANK, not a queued action right.
	if selected!=226:
		var state: PokemonEnCombate=entry.state.get_ref()
		state.source_last_chosen_move=selected;state.source_last_printed_move=selected;state.source_last_result_move=0;state.source_last_landed_move=0;state.source_last_hit_type="NORMAL"
	preload("res://scripts/battle/choice_band_rules.gd").commit(battle,entry.pokemon,selected,false)
	return entry

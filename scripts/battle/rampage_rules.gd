extends RefCounted
class_name BattleRampageRules
## Ruby USER-owned Outrage/Uproar lock authority; never animation metadata or party DB.

static func capture(owner: Node, actor: BasePokemon) -> Dictionary:
	if owner==null or actor==null or not owner.is_inside_tree() or owner.fase==owner.FIN_BATALLA:return {}
	var state: PokemonEnCombate=owner._obtener_combatiente(actor)
	var slot: BattleSlot=owner.hud._obtener_slot_de_pokemon(actor)
	if state==null or slot==null:return {}
	return {"owner":weakref(owner),"state":weakref(state),"actor":weakref(actor),"slot":weakref(slot),"generation":slot.animation_generation,"epoch":state.body_attack_epoch}

static func _valid(guard: Dictionary, check_epoch: bool=false) -> bool:
	if guard.is_empty():return false
	var owner: Node=guard.owner.get_ref()
	var actor: BasePokemon=guard.actor.get_ref()
	var state: PokemonEnCombate=guard.state.get_ref()
	var slot: BattleSlot=guard.slot.get_ref()
	return is_instance_valid(owner) and owner.is_inside_tree() and owner.fase!=owner.FIN_BATALLA and actor!=null and actor.estad_ps_actual>0 and state!=null and owner._obtener_combatiente(actor)==state and is_instance_valid(slot) and owner.hud._obtener_slot_de_pokemon(actor)==slot and slot.animation_generation==int(guard.generation) and (not check_epoch or state.body_attack_epoch==int(guard.epoch))

static func move(owner: Node, actor: BasePokemon) -> Movimiento:
	var state: PokemonEnCombate=owner._obtener_combatiente(actor) if actor!=null else null
	if state==null or state.rampage_turns<=0:return null
	if not _valid(state.rampage_guard):retire(state);return null
	return state.rampage_move

static func accept(guard: Dictionary, accepted_move: Movimiento) -> void:
	if accepted_move==null or accepted_move.get_efecto() not in ["EFFECT_RAMPAGE","EFFECT_UPROAR"] or not _valid(guard,true):return
	var state: PokemonEnCombate=guard.state.get_ref()
	if state.rampage_turns>0:return # Continuation never rolls again or spends PP.
	state.rampage_turns=(randi()&(3 if accepted_move.get_efecto()=="EFFECT_UPROAR" else 1))+2
	state.rampage_move=accepted_move;state.rampage_guard=guard.duplicate()
	state.rampage_last_round=-1

static func retire(state: PokemonEnCombate) -> void:
	if state==null:return
	state.rampage_turns=0;state.rampage_move=null;state.rampage_guard.clear()

## Reconcile only the state captured before a presentation yield. A new slot
## occupant/state is not authority to inherit or resurrect the old lock.
static func reconcile(guard: Dictionary) -> void:
	if guard.is_empty() or _valid(guard):return
	var state: PokemonEnCombate=guard.state.get_ref()
	retire(state)

static func can_start(guard: Dictionary) -> bool:
	return _valid(guard,true)

static func finish_round(owner: Node, state: PokemonEnCombate, round_token: int) -> bool:
	if state==null or state.rampage_turns<=0:return false
	if not _valid(state.rampage_guard):retire(state);return false
	if state.rampage_last_round==round_token:return false
	state.rampage_last_round=round_token;state.rampage_turns-=1
	if state.rampage_turns>0:return false
	var uproar: bool=state.rampage_move!=null and state.rampage_move.get_efecto()=="EFFECT_UPROAR"
	retire(state)
	if uproar:return false
	if state.esta_confuso or HabilidadesCombate.tiene(state.pokemon_base,HabilidadesCombate.RITMOPROPIO):return false
	state.esta_confuso=true;state.turnos_confuso=(randi()%4)+2
	return true

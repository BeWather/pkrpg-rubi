extends RefCounted
## Ruby MoveEnd CHOICE and CheckMoveLimitations, not transferred/save data.
const KEY="source_choice_move"
static func effect(battle: Node,actor: BasePokemon) -> bool:
	var lease: Dictionary=battle.field_rules.capture(actor)
	return not lease.is_empty() and int(battle.held_item_effects.resolve(battle,actor,lease).source_effect)==29
static func owns_move(actor: BasePokemon,id: int) -> bool:
	for move: Movimiento in BattleTransformRules.moves(actor).slice(0,4):
		if move!=null and int(move.datos.get("numero_movimiento",0))==id:return true
	return false
static func blocked(battle: Node,actor: BasePokemon,move: Movimiento) -> bool:
	var state: PokemonEnCombate=battle._obtener_combatiente(actor) if actor!=null else null
	if state==null or move==null or not effect(battle,actor):return false
	if int(move.datos.get("numero_movimiento",0))==165:return false # Source forced Struggle bypasses selection lock.
	var locked: int=int(state.get_meta(KEY,0))
	return locked not in [0,65535] and int(move.datos.get("numero_movimiento",0))!=locked
static func commit(battle: Node,actor: BasePokemon,selected: int,failed_pass: bool) -> void:
	var state: PokemonEnCombate=battle._obtener_combatiente(actor)
	if state==null:return
	var locked: int=int(state.get_meta(KEY,0))
	if effect(battle,actor) and selected!=165 and locked in [0,65535] and (selected!=226 or failed_pass):locked=selected
	state.set_meta(KEY,locked if owns_move(actor,locked) else 0)
static func finish(record: Dictionary,category: String,action: BattleMoveAction) -> void:
	if category!="obeying" or action==null or action.has_meta("source_choice_received_item_deferred"):return
	var battle: Node=record.owner.get_ref()
	var failed: bool=action.outcomes.any(func(row: Dictionary)->bool:return str(row.kind)=="failed")
	commit(battle,record.actor.pokemon,int(record.selected_id),failed)

static func clear_state(state: PokemonEnCombate) -> void:
	if state!=null:state.remove_meta(KEY)

## Ruby Trick/Thief received items reaches CHANGED_ITEMS after CHOICE_MOVE.
## Native exchange stays atomic; defer only Choice observation on this action chain.
static func defer_received_item(action: BattleMoveAction) -> void:
	if action==null or action.has_meta("source_choice_received_item_deferred"):return
	action.set_meta("source_choice_received_item_deferred",true)
	var guard: Dictionary=action.get_meta("source_screen_phase_guard",{})
	var parent: WeakRef=guard.get("source_magic_coat_parent_action")
	if parent!=null:defer_received_item(parent.get_ref())

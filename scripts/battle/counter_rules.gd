extends RefCounted
class_name BattleCounterRules
## Ruby atkB3/atkB5 authority. Roll timers advance on accepted calculations,
## never ENDTHRASH; Fury has no successful different-move reset here.
static func supported(selected: Movimiento) -> bool:
	return selected!=null and selected.get_efecto() in ["EFFECT_FURY_CUTTER","EFFECT_ROLLOUT","EFFECT_RETURN","EFFECT_FRUSTRATION"]

static func capture_phase(owner: Node, actor: BasePokemon, selected: Movimiento) -> Dictionary:
	if not supported(selected):return {}
	var guard: Dictionary=BattleRampageRules.capture(owner,actor)
	if not guard.is_empty():guard.flow=owner.field_rules.capture_flow()
	return guard

static func phase_live(guard: Dictionary) -> bool:
	if not BattleRampageRules.can_start(guard):return false
	var owner: Node=guard.owner.get_ref()
	return owner.field_rules.valid_flow(guard.get("flow",{}))

static func bind_action(owner: Node, actor: BasePokemon, target: BasePokemon, selected: Movimiento, action: BattleMoveAction) -> void:
	if not supported(selected) or action.has_meta("source_counter_guard"):return
	var guard: Dictionary=capture_phase(owner,actor,selected)
	guard.target=weakref(target);guard.target_hp=target.estad_ps_actual
	action.set_meta("source_counter_guard",guard)

static func reconcile(action: BattleMoveAction, target: BasePokemon, committed: Dictionary) -> bool:
	if not action.has_meta("source_counter_guard"):return true
	var guard: Dictionary=action.get_meta("source_counter_guard")
	if guard.is_empty():return false
	var owner: Node=guard.owner.get_ref()
	# Accepted body KO owns exactly one retirement epoch of its original target.
	# No other bank/epoch/generation or FIN lifetime is refreshed on resume.
	if is_instance_valid(owner) and target==guard.target.get_ref() and target.estad_ps_actual==0 and int(committed.get("damage",0))>=int(guard.target_hp):
		for record: Dictionary in guard.flow.records:
			var state: PokemonEnCombate=record.state.get_ref()
			if record.pokemon==target and state!=null and owner._obtener_combatiente(target)==state and state.body_attack_epoch==int(record.epoch)+1:record.epoch=state.body_attack_epoch
	if phase_live(guard):return true
	return _abort_action(action,guard)

static func action_live(action: BattleMoveAction) -> bool:
	# The accepted guard belongs to the action, not the current presentation or
	# occupant. Check before deferred startup, claims and every resumed consumer.
	if not action.has_meta("source_counter_guard"):return true
	var guard: Dictionary=action.get_meta("source_counter_guard")
	if not guard.is_empty() and phase_live(guard):return true
	return _abort_action(action,guard)

static func _abort_action(action: BattleMoveAction, guard: Dictionary) -> bool:
	var original: PokemonEnCombate=guard.state.get_ref() if guard.has("state") else null
	cancel_multi(original);action.phase="counter_aborted"
	return false
static func move(owner: Node, actor: BasePokemon) -> Movimiento:
	var state: PokemonEnCombate=owner._obtener_combatiente(actor) if actor!=null else null
	if state==null or state.roll_turns<=0:return null
	if not BattleRampageRules._valid(state.roll_guard):retire_roll(state);return null
	return state.roll_move

static func retire_roll(state: PokemonEnCombate) -> void:
	if state==null:return
	state.roll_turns=0;state.roll_move=null;state.roll_guard.clear();state.roll_target.clear()

static func cancel_multi(state: PokemonEnCombate) -> void:
	if state==null:return
	state.fury_cutter_count=0;retire_roll(state)

static func retire(state: PokemonEnCombate) -> void:
	cancel_multi(state)
	if state!=null:state.remove_meta("source_defense_curl")

static func no_effect(state: PokemonEnCombate, effect: String) -> void:
	if state==null:return
	if effect=="EFFECT_FURY_CUTTER":state.fury_cutter_count=0
	elif effect=="EFFECT_ROLLOUT":cancel_multi(state)

static func prepare(owner: Node, actor: BasePokemon, target: BasePokemon, selected: Movimiento, action: BattleMoveAction) -> void:
	if action.accepted_power>=0 or selected.get_efecto() not in ["EFFECT_FURY_CUTTER","EFFECT_ROLLOUT"]:return
	var guard: Dictionary=BattleRampageRules.capture(owner,actor)
	if not BattleRampageRules.can_start(guard):return
	var state: PokemonEnCombate=guard.state.get_ref()
	if selected.get_efecto()=="EFFECT_FURY_CUTTER":
		state.fury_cutter_count=mini(5,state.fury_cutter_count+1)
		action.set_meta("source_fury_count",state.fury_cutter_count)
		# Native DB contains modern Fury40; Ruby battle_moves.c2528 uses10.
		# Snapshot source combat power without modifying party/DB move identity.
		action.accepted_power=10<<(state.fury_cutter_count-1)
	else:
		if state.roll_turns<=0:
			state.roll_turns=5;state.roll_move=selected;state.roll_guard=guard.duplicate();state.roll_target=owner.turno._posicion_pokemon(target).duplicate()
		state.roll_turns-=1
		var count: int=5-state.roll_turns
		action.set_meta("source_roll_count",count)
		action.accepted_power=selected.get_potencia()<<(count-1)
		if bool(state.get_meta("source_defense_curl",false)):action.accepted_power*=2
		# The fifth source calculation clears MULTIPLETURNS before animation,
		# while its accepted count remains immutable in this action.
		if state.roll_turns==0:retire_roll(state)

static func target(owner: Node, actor: BasePokemon) -> BasePokemon:
	if move(owner,actor)==null:return null
	var state: PokemonEnCombate=owner._obtener_combatiente(actor)
	return owner.turno._ocupante_posicion(state.roll_target,actor) if not state.roll_target.is_empty() else null

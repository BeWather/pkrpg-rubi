extends RefCounted
class_name BattleMoveActionPresenter
## One presentation per accepted action, never a gameplay command executor.

var action: BattleMoveAction
var battle: BattleSceneController
var animation: MoveAnimation
var gate: Dictionary = {}
var context: MoveAnimationContext
signal startup_finished
var _startup_pending: bool=false
var _started: bool=false
var _substitute_guard_bound: bool=false
var _substitute_guard: BattleOwnedAppearanceLease=null

func _init(scene: BattleSceneController, plan: BattleMoveAction) -> void:
	battle = scene
	action = plan

func bind_substitute_guard(guard: BattleOwnedAppearanceLease) -> void:
	if _started:return
	_substitute_guard_bound=true;_substitute_guard=guard

func start(move: Movimiento, result: ResultadoMovimiento) -> void:
	if _started or not live():
		return
	_started=true;_startup_pending=true
	_start_after_substitute(move,result)

func _start_after_substitute(move: Movimiento, result: ResultadoMovimiento) -> void:
	if action.substitute_coordinator==null:
		action.substitute_coordinator=BattleSubstituteActionCoordinator.new(battle,action.attacker)
	await action.substitute_coordinator.prepare()
	if live():_start_primary(move,result)
	_startup_pending=false;startup_finished.emit()

func _start_primary(move: Movimiento, result: ResultadoMovimiento) -> void:
	if not action.transform_presentation.is_empty():
		action.transform_presentation.guard=BattleTransformPresentation.bind(action.transform_presentation,action.substitute_coordinator)
		if action.substitute_coordinator!=null and action.substitute_coordinator.opened:
			action.substitute_coordinator.set_meta("transform_original_mon",BattleSubstitutePresentation.owned_state(action.substitute_coordinator.slot).duplicate(true))
	var primary: BattleSlot = battle.hud._obtener_slot_de_pokemon(action.targets[0]) if not action.targets.is_empty() else null
	context = MoveAnimationContext.nueva(battle, battle.hud._obtener_slot_de_pokemon(action.attacker), primary)
	context.action_id = action.action_id
	context.phase = action.phase
	context.source_move_turn = action.move_turn
	context.source_hit_index = action.hit_index
	context.authoritative_action = true
	if preload("res://scripts/battle/weather_ball_rules.gd").supports(move):context.source_counter_inputs.source_weather=battle.habilidades.crear_campo().clima_efectivo()
	if preload("res://scripts/battle/camouflage_rules.gd").supports(move):context.source_counter_inputs.source_environment=int(battle.obtener_terreno_batalla())
	# EFFECT_ROAR's LockOn gate admits an ORIGINAL hidden target view, not a
	# generic permission to reveal or reacquire an arbitrary invisible bank.
	if preload("res://scripts/battle/whirlwind_rules.gd").supports(move) and not action.targets.is_empty():
		var selected: Dictionary=battle.field_rules.capture(action.targets[0])
		if not selected.is_empty() and BattleSureHitRules.guarantees(battle._obtener_combatiente(action.attacker),selected.state.get_ref()):context.source_counter_inputs.source_forced_target_lease=selected
	context.source_power_override=action.accepted_power
	for property: String in ["source_friendship","source_fury_count","source_roll_count"]:
		if action.has_meta(property):context.source_counter_inputs[property]=action.get_meta(property)
	for target in action.targets:
		var slot := battle.hud._obtener_slot_de_pokemon(target)
		if slot != null: context.target_slots.append(slot)
	animation = BattleAnimationDirector.reproducir(context, move, result)
	# §33: la escena nativa (AnimacionEscenaNativa) recibe las mismas guardas que la VM y las aplica en
	# AparienciaNativa; el director arranca la reproducción un frame después, así que llegan a tiempo.
	var guarded: bool=animation is BattleSequenceAnimation or animation is AnimacionEscenaNativa
	if not action.transform_presentation.is_empty() and guarded:
		animation.set_meta("source_transform_guard_required",true)
		animation.set_meta("source_transform_snapshot",action.transform_presentation)
	# Startup may yield in the own-action coordinator. Attach the original
	# accepted appearance to the actual deferred primary, never a null placeholder.
	if _substitute_guard_bound and guarded:
		animation.set_meta("source_substitute_guard_required",true)
		if _substitute_guard!=null:animation.set_meta("source_substitute_guard",_substitute_guard)

func wait_impact() -> Dictionary:
	if _startup_pending:await startup_finished
	if not gate.is_empty():
		return gate
	if animation == null:
		gate = {"missing":true, "state":"unavailable"}
	elif animation is BattleSequenceAnimation:
		gate = await (animation as BattleSequenceAnimation).wait_marker("impact")
	else:
		await animation.esperar_impacto()
		gate = {"missing":false, "state":"legacy"}
	return gate

func wait_finished() -> void:
	if _startup_pending:await startup_finished
	if animation != null:
		await animation.esperar_finalizada()
	if not action.defer_substitute_restore:await finish_action()

func finish_action() -> void:
	if action.substitute_coordinator!=null:await action.substitute_coordinator.finish()
	# Special6 is allowed to restore owned presentation, but its asynchronous
	# completion must not authorize a retired combat flow or a fresh occupant.
	# Check domain identity/epoch, not texture: a successful doll swap changes art.
	BattleCounterRules.action_live(action)
	BattleScreenRules.action_live(action)

func live(target: BasePokemon = null) -> bool:
	# Failure/cancellation is a pacing fallback for an accepted action. Scene
	# teardown, battle end or replacement aborts queued effects instead.
	if not BattleCounterRules.action_live(action):return false
	if not BattleScreenRules.action_live(action):return false
	if action.substitute_coordinator!=null and not action.substitute_coordinator.allows_effects():return false
	if animation is BattleSequenceAnimation and (animation as BattleSequenceAnimation).lifecycle_aborted:
		# Candidate domain permission was checked above; a retired view alone
		# cannot revoke original accepted PP/continuation or acquire new art.
		var guard: Dictionary=action.get_meta("source_screen_phase_guard",{})
		if not guard.has("source_i4"):return false
	if not is_instance_valid(battle) or not battle.is_inside_tree() or battle.fase == battle.FIN_BATALLA:
		return false
	if battle.hud._obtener_slot_de_pokemon(action.attacker) == null:
		return false
	if target == null:
		return true
	return battle.hud._obtener_slot_de_pokemon(target) != null and target.estad_ps_actual > 0

func claim(outcome: Dictionary) -> bool:
	return live(outcome.get("target")) and action.claim(outcome)

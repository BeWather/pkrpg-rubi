extends RefCounted
class_name BattleLockedMoveRules
## Shared input query only. Each source effect retains separate acceptance,
## target selection, timer and termination authority.
static func move(owner: Node, actor: BasePokemon) -> Movimiento:
	var multi_turn_move: Movimiento=multi_turn(owner,actor)
	return multi_turn_move if multi_turn_move!=null else preload("res://scripts/battle/encore_rules.gd").move(owner,actor)
## Selection query: AreAllMovesUnusable runs first, so an unusable Encore move yields Struggle.
static func selection(owner: Node, actor: BasePokemon) -> Movimiento:
	var locked: Movimiento=move(owner,actor)
	if locked==null or multi_turn(owner,actor)!=null:return locked
	return null if preload("res://scripts/battle/move_availability_rules.gd").blocked(owner,actor,locked) else locked
## STATUS2_RECHARGE: no se elige acción (battle_main.c); el movimiento es irrelevante y
## se pasa Forcejeo como prioridad 0, porque el turno se pierde antes de usarlo.
static func recharging(owner: Node, actor: BasePokemon) -> bool:
	var state: PokemonEnCombate=owner._obtener_combatiente(actor) if actor!=null else null
	return state!=null and state.source_recharge_turns>0
## Use-time query: noValidMoves keeps the selected Struggle; anything else obeys the lock.
static func at_use(owner: Node, actor: BasePokemon, chosen: Movimiento) -> Movimiento:
	return null if chosen!=null and chosen.has_meta("source_forced_struggle") else move(owner,actor)
## STATUS2_MULTIPLETURNS skips the action menu. Encore does not: it still chooses
## an action and only replaces the move menu after LUCHA (battle_main.c).
static func multi_turn(owner: Node, actor: BasePokemon) -> Movimiento:
	var rampage: Movimiento=BattleRampageRules.move(owner,actor)
	return rampage if rampage!=null else BattleCounterRules.move(owner,actor)

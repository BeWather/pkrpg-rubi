extends RefCounted
## Source four-slot limitations; move-ID Choice memory never owns another slot's PP.
const Choice=preload("res://scripts/battle/choice_band_rules.gd")
static func blocked(battle: Node,actor: BasePokemon,move: Movimiento,check: int=255) -> bool:
	if move==null or int(move.datos.get("numero_movimiento",0))==0:return true
	if check&2 and not move.tiene_pp():return true
	return Choice.blocked(battle,actor,move) or preload("res://scripts/battle/torment_rules.gd").blocked(battle,actor,move) or preload("res://scripts/battle/encore_rules.gd").blocked_choice(battle,actor,move) or preload("res://scripts/battle/disable_rules.gd").blocked(battle,actor,move) or preload("res://scripts/battle/thought_finger_rules.gd").blocked(battle,actor,move) or preload("res://scripts/battle/imprison_rules.gd").sealed(battle,actor,move)
static func slots(battle: Node,actor: BasePokemon,check: int=255) -> Array[int]:
	var result: Array[int]=[]
	var moves: Array=BattleTransformRules.moves(actor).slice(0,4)
	for index: int in moves.size():
		if not blocked(battle,actor,moves[index],check):result.append(index)
	return result
static func struggle() -> Movimiento:
	var move: Movimiento=preload("res://scripts/battle/thought_finger_rules.gd").called_move(165)
	move.set_meta("source_forced_struggle",true);return move
static func legal(battle: Node,actor: BasePokemon,move: Movimiento) -> bool:
	if move==null:return false
	var allowed: Array[int]=slots(battle,actor)
	if move.has_meta("source_forced_struggle"):return int(move.datos.get("numero_movimiento",0))==165 and allowed.is_empty()
	var moves: Array=BattleTransformRules.moves(actor).slice(0,4)
	return allowed.any(func(index: int)->bool:return moves[index]==move)

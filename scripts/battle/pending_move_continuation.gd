extends RefCounted
class_name PendingMoveContinuation
## A locked domain action survives round cleanup, never a presentation handle.
var mode := "two_turn"
var bide_ticks := 2
var stored_damage := 0
var last_attacker_position: Dictionary = {}
var source_i4: BattleHiddenActorRules
var move: Movimiento
var actor: BasePokemon
var target_position: Dictionary = {}

func _init(accepted_move: Movimiento, accepted_actor: BasePokemon, selected_position: Dictionary) -> void:
	move = accepted_move
	actor = accepted_actor
	target_position = selected_position.duplicate()

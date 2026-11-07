extends RefCounted
class_name BattleMoveAction
## Domain-owned action facts. Presentation events never grant eligibility.

var action_id: int
var attacker: BasePokemon
var targets: Array[BasePokemon] = []
var phase := "hit"
var move_turn := 0
var hit_index := 0
var outcomes: Array[Dictionary] = []
var _claims: Dictionary = {}
var _resolved_targets: Dictionary = {}
var substitute_coordinator: BattleSubstituteActionCoordinator
var defer_substitute_restore: bool=false
var stockpile_resolution: Dictionary={}
var transform_resolution: Dictionary={}
var transform_presentation: Dictionary={}
var accepted_power: int=-1

func _init(actor: BasePokemon, selected: Array[BasePokemon], action_phase: String = "hit", source_turn: int = 0, source_hit: int = 0) -> void:
	action_id = get_instance_id()
	attacker = actor
	targets.assign(selected)
	phase = action_phase
	move_turn = source_turn
	hit_index = source_hit

func record(target: BasePokemon, kind: String, eligible: bool, pre_applied: bool = false) -> Dictionary:
	var outcome := {"action_id":action_id, "target":target, "kind":kind, "eligible":eligible, "pre_applied":pre_applied, "hit_index":hit_index}
	outcomes.append(outcome)
	return outcome

func claim(outcome: Dictionary) -> bool:
	if not bool(outcome.get("eligible", false)) or bool(outcome.get("pre_applied", false)) or phase == "charge":
		return false
	var target: BasePokemon = outcome.get("target")
	if target == null or int(outcome.get("action_id", -1)) != action_id:
		return false
	var key := "%d:%d:%s" % [target.get_instance_id(), int(outcome.hit_index), str(outcome.kind)]
	if _claims.has(key):
		return false
	_claims[key] = true # Claim before asynchronous HP/HUD work.
	return true

func begin_target(target: BasePokemon) -> bool:
	if target == null: return false
	var key := "%d:%d" % [target.get_instance_id(), hit_index]
	if _resolved_targets.has(key): return false
	_resolved_targets[key] = true
	return true

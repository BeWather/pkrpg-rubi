extends RefCounted
class_name BattleSafeguardRules
## Bounded I4 dependency: real own-side authority, not global status coverage.
var _owner: WeakRef
var _timers: Array[int]=[0,0]
var _last_round: int=-1
func _init(battle: Node) -> void:_owner=weakref(battle)
func remaining(side: int) -> int:return _timers[side] if side in [0,1] else 0
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0))==219 and move.get_efecto()=="EFFECT_SAFEGUARD"
static func capture(move: Movimiento) -> Dictionary:
	if not supports(move):return {}
	var data: Dictionary=move.datos.duplicate(true)
	data.precision=0;data.objetivo_id=7;data.max_pp=25;data.pp=25;data.potencia=0;data.tipo="NORMAL"
	return {"id":219,"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_safeguard"):return move
	var fact: Dictionary=phase.source_safeguard
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
func produce(action: BattleMoveAction) -> bool:
	var battle: Node=_owner.get_ref()
	if not is_instance_valid(battle) or not BattleScreenRules.action_live(action):return false
	var guard: Dictionary=action.get_meta("source_screen_phase_guard",{})
	if guard.get("source_safeguard",{}).get("id",0)!=219:return false
	if guard.owner.get_ref()!=battle or not battle.field_rules.valid(guard.actor):return false
	if action.has_meta("source_safeguard_produced"):return false
	action.set_meta("source_safeguard_produced",true)
	var side: int=0 if bool(guard.actor.bank.player) else 1
	if _timers[side]>0:return false # Ruby repeats fail without refreshing.
	_timers[side]=5
	return true
func active_for_original_bank(record: Dictionary) -> bool:
	var battle: Node=_owner.get_ref()
	return is_instance_valid(battle) and battle.field_rules.valid(record) and remaining(0 if bool(record.bank.player) else 1)>0
func blocks_status(move: Movimiento,actor: BasePokemon,target: BasePokemon) -> bool:
	# Ordinary opponent-inflicted major status/confusion. Mixed stat+confusion,
	# delayed Yawn, and unrelated secondary consumers remain separate routes.
	if move==null or actor==target or move.get_efecto() not in ["EFFECT_SLEEP","EFFECT_POISON","EFFECT_TOXIC","EFFECT_PARALYZE","EFFECT_WILL_O_WISP","EFFECT_CONFUSE"]:return false
	var battle: Node=_owner.get_ref()
	if not is_instance_valid(battle):return false
	return active_for_original_bank(battle.field_rules.capture(target))
func end_round() -> bool:
	var battle: Node=_owner.get_ref()
	if not is_instance_valid(battle):return false
	var flow: Dictionary=battle.field_rules.capture_flow()
	if not battle.field_rules.valid_flow(flow):return false
	if _last_round==int(battle.contador_turnos):return true
	_last_round=int(battle.contador_turnos)
	for side: int in [0,1]:
		if _timers[side]==0:continue
		_timers[side]-=1
		if _timers[side]==0:
			await battle.mostrar_texto_batalla("Velo Sagrado dejó de proteger a tu equipo." if side==0 else "Velo Sagrado dejó de proteger al equipo rival.")
			if not battle.field_rules.valid_flow(flow):return false
	return true
func clear() -> void:
	_timers.assign([0,0]);_last_round=-1

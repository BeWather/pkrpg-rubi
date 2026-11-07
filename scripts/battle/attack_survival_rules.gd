extends RefCounted
class_name BattleAttackSurvivalRules
## Ruby command07/08/69/93 admission. Never a passive HP or consuming item hook.
const Transaction=preload("res://scripts/battle/held_item_transaction.gd")
static func command(move: Movimiento) -> int:
	var id: int=int(move.datos.get("numero_movimiento",0)) if move!=null else 0
	if id in [162,220]:return 0 # Super Fang/Pain Split bypass adjustment.
	return 69 if id in [49,69,82,101,117,149,68,243,255,283] else 7
static func prepare(battle: Node,action: BattleMoveAction,target: BasePokemon,requested: int,opcode: int=7,move: Movimiento=null) -> Dictionary:
	var lease: Dictionary=battle.field_rules.capture(target);var flow: Dictionary=battle.field_rules.capture_flow()
	if not battle.field_rules.valid_flow(flow) or not battle.field_rules.valid(lease):return {}
	var descriptor: Dictionary=battle.held_item_effects.resolve(battle,target,lease)
	var accepted: Dictionary=Transaction.capture(battle,lease,flow,descriptor)
	var state: PokemonEnCombate=lease.state.get_ref();var bank: int=int(descriptor.bank)
	var latches: Dictionary=action.get_meta("source_focus_latches",{}) if action!=null else {}
	var drawn: bool=opcode!=0 and int(descriptor.source_effect)==39
	# A previous proc never short-circuits the next reached effect39 draw.
	var word: int=randi() if drawn else -1
	var proc: bool=drawn and word%100<int(descriptor.parameter)
	if proc:latches[bank]=true
	if action!=null:action.set_meta("source_focus_latches",latches)
	var banded: bool=bool(latches.get(bank,false))
	var eligible: bool=opcode!=0 and (opcode==93 or state.substitute_hp<=0) and target.estad_ps_actual>0 and requested>=target.estad_ps_actual
	var endured: bool=eligible and state.aguante_este_turno
	var false_swipe: bool=opcode in [7,69] and move!=null and move.get_efecto()=="EFFECT_FALSE_SWIPE"
	accepted.merge({"requested":maxi(0,target.estad_ps_actual-1) if eligible and (endured or banded or false_swipe) else requested,"endured":endured,"hung_on":eligible and banded and not endured,"drawn":drawn,"word":word,"proc":proc,"opcode":opcode,"sensitive":drawn or banded,"raw_item":target.objeto,"strict_ohko":drawn or banded,"committed":false,"presented":false})
	if action!=null:
		var generation: int=int(action.get_meta("source_survival_generation",0))+1
		action.set_meta("source_survival_generation",generation)
		accepted.merge({"action":weakref(action),"generation":generation,"hit_index":action.hit_index,"move_turn":action.move_turn})
	return accepted
static func valid(battle: Node,accepted: Dictionary) -> bool:
	if accepted.is_empty():return false
	if accepted.has("action"):
		var action: BattleMoveAction=accepted.action.get_ref()
		if action==null or action.hit_index!=int(accepted.hit_index) or action.move_turn!=int(accepted.move_turn) or int(action.get_meta("source_survival_generation",0))!=int(accepted.generation):return false
	if bool(accepted.sensitive):return accepted.pokemon.objeto==accepted.raw_item and Transaction.valid(battle,accepted)
	# No39 hits must not acquire a held-provider dependency: Shell Bell reads
	# its CURRENT actor profile at MoveEnd, after the accepted target damage.
	return battle.field_rules.valid_flow(accepted.flow) and battle.field_rules.valid(accepted.lease)
## Legacy direct internal callers have no previsual action; retain their accepted seam.
static func adjust(field: BattleFieldEffects,flow: Dictionary,target_record: Dictionary,requested: int) -> Dictionary:
	if field==null or not field.valid_flow(flow) or not field.valid(target_record):return {"accepted":false,"requested":0,"hung_on":false}
	var battle: Node=field.owner();var receipt: Dictionary=prepare(battle,null,target_record.pokemon,requested)
	return {"accepted":not receipt.is_empty(),"requested":int(receipt.get("requested",0)),"hung_on":bool(receipt.get("hung_on",false)),"endured":bool(receipt.get("endured",false))}

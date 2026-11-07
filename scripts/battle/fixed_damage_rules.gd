extends RefCounted
## Ruby82/149/162/283: typecalc flags precede fixed/fraction damage; only82/149/283 reach69.
const POLICIES={82:["EFFECT_DRAGON_RAGE","DRAGON",2,100,10,0],149:["EFFECT_PSYWAVE","PSIQUICO",2,80,15,0],162:["EFFECT_SUPER_FANG","NORMAL",1,90,10,1],283:["EFFECT_ENDEAVOR","NORMAL",1,100,5,1]}
static func supports(move: Movimiento) -> bool:
	return move!=null and POLICIES.has(int(move.datos.get("numero_movimiento",0)))
static func capture(move: Movimiento) -> Dictionary:
	var id: int=int(move.datos.numero_movimiento);var policy: Array=POLICIES[id];var data: Dictionary=move.datos.duplicate(true)
	data.efecto=policy[0];data.tipo=policy[1];data.categoria_dano_id=policy[2];data.precision=policy[3];data.max_pp=policy[4];data.pp=policy[4];data.contacto=policy[5];data.potencia=1;data.prioridad=0;data.objetivo_id=10;data.prob_secundario=0
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_fixed_damage"):return move
	if not phase.has("source_fixed_damage_admitted"):
		var fact: Dictionary=phase.source_fixed_damage
		phase.source_fixed_damage_admitted=Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
	return phase.source_fixed_damage_admitted
static func result(move: Movimiento,actor: BasePokemon,target: BasePokemon,state: PokemonEnCombate) -> ResultadoMovimiento:
	var answer:=ResultadoMovimiento.new()
	# This typecalc fact is independent of the amount subsequently overwritten.
	var effectiveness: float=MoveResolver.calc_efectividad(move,target,state)
	match int(move.datos.numero_movimiento):
		82:answer.damage=40
		149:
			var sample: int=randi()&15
			while sample>10:sample=randi()&15
			answer.damage=actor.nivel*(sample*10+50)/100 # Source has no minimum1.
		162:answer.damage=maxi(1,target.estad_ps_actual/2) # BODY HP, never doll HP.
		283:answer.damage=maxi(0,target.estad_ps_actual-actor.estad_ps_actual) # atkD8: body HP difference.
	answer.effectiveness=0.0 if effectiveness==0.0 else 1.0
	if effectiveness==0.0:answer.message="No afecta a\n%s..."%target.get_nombre_combate()
	return answer

static func endure_bypass(action: BattleMoveAction,move: Movimiento,receipt: Dictionary) -> Dictionary:
	if action==null or not supports(move) or int(move.datos.numero_movimiento)!=162 or receipt.is_empty() or int(receipt.opcode)!=0:return {}
	var fact: Dictionary={"move":move,"action":weakref(action),"receipt":receipt};fact.make_read_only();return fact
static func owns_endure_bypass(battle: Node,cause: Dictionary) -> bool:
	var fact: Dictionary=cause.get("source_super_fang_bypass",{})
	if fact.is_empty() or not fact.is_read_only() or fact.move!=cause.get("move"):return false
	var action: BattleMoveAction=fact.action.get_ref();var receipt: Dictionary=fact.receipt
	return action!=null and supports(fact.move) and int(fact.move.datos.numero_movimiento)==162 and fact.move.get_efecto()=="EFFECT_SUPER_FANG" and int(receipt.opcode)==0 and bool(receipt.committed) and action.get_meta("source_survival_receipt",{})==receipt and BattleAttackSurvivalRules.valid(battle,receipt)

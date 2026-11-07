extends RefCounted
## Ruby atkAD: effective last-used slot, PP >1, variable 2–5 deduction.
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==180
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true);data.categoria_dano_id=3;data.potencia=0;data.tipo="FANTASMA";data.precision=100;data.max_pp=10;data.pp=10;data.contacto=0;data.objetivo_id=10;data.prioridad=0;data.prob_secundario=0;data.efecto="EFFECT_SPITE"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_spite"):return move
	if not phase.has("source_spite_admitted"):
		var fact: Dictionary=phase.source_spite;phase.source_spite_admitted=Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
	return phase.source_spite_admitted
static func produce(battle: Node,target: BasePokemon,draw: Callable) -> Dictionary:
	var state: PokemonEnCombate=battle._obtener_combatiente(target)
	if state==null or not state.semi_invulnerable.is_empty():return {}
	var move: Movimiento=preload("res://scripts/battle/disable_rules.gd").slot(target,state.source_last_chosen_move)
	if move==null or move.pp_act<=1:return {}
	var lost: int=mini(move.pp_act,(int(draw.call())&3)+2);move.pp_act-=lost
	# Effective Mimic/Transform slots are distinct resources: party PP stays owned.
	if move.pp_act==0:
		BattleCounterRules.cancel_multi(state);BattleRampageRules.retire(state)
	return {"name":move.nombre,"lost":lost}

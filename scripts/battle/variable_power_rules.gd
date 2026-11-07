extends RefCounted
## Ruby gBattleMoves power1 moves whose DB power is NULL: LowKick/Flail/Reversal/Return/Frustration.
## The dynamic power (weightdamagecalculation, remaininghptopower, friendshiptodamagecalculation)
## is applied later as accepted_power; this only admits them as ordinary damaging moves.
const POLICIES={67:["EFFECT_LOW_KICK","LUCHA",20],175:["EFFECT_FLAIL","NORMAL",15],179:["EFFECT_FLAIL","LUCHA",15],216:["EFFECT_RETURN","NORMAL",20],218:["EFFECT_FRUSTRATION","NORMAL",20]}
## Ruby sWeightToDamageTable (hectograms, strict <); heavier → 120.
const WEIGHT_TABLE: Array=[[100,20],[250,40],[500,60],[1000,80],[2000,100]]
static func supports(move: Movimiento) -> bool:return move!=null and POLICIES.has(int(move.datos.get("numero_movimiento",0)))
static func low_kick_power(target: BasePokemon) -> int:
	var row: Dictionary=DatabaseManager.obtener_datos_pokemon(target.nombre_interno) if target!=null else {}
	var weight: int=roundi(float(row.get("peso",0.0) if row.get("peso")!=null else 0.0)*10.0)
	for pair: Array in WEIGHT_TABLE:
		if weight<int(pair[0]):return int(pair[1])
	return 120
static func capture(move: Movimiento) -> Dictionary:
	var policy: Array=POLICIES[int(move.datos.numero_movimiento)];var data: Dictionary=move.datos.duplicate(true)
	data.efecto=policy[0];data.tipo=policy[1];data.categoria_dano_id=1;data.potencia=1;data.precision=100;data.max_pp=policy[2];data.pp=policy[2];data.contacto=1;data.objetivo_id=10;data.prioridad=0;data.prob_secundario=0
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_variable_power"):return move
	var fact: Dictionary=phase.source_variable_power
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

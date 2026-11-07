extends RefCounted
## Ruby Poison Gas is55 accuracy /40PP /selected target, not modern90/spread.
static func supports(move: Movimiento) -> bool:
	return move!=null and (int(move.datos.get("numero_movimiento",0))==139 or move.get_nombre_interno() in ["GASVENENOSO","POISON_GAS"])
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true)
	data.precision=55;data.objetivo_id=10;data.max_pp=40;data.pp=40;data.potencia=0;data.tipo="VENENO";data.efecto="EFFECT_POISON"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_poison_gas"):return move
	var fact: Dictionary=phase.source_poison_gas
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

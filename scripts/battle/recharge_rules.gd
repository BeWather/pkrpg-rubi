extends RefCounted
## Source Hyper Beam policy; existing damage authority owns hit/HP; holder recharge owns the following action.
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0))==63
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true)
	data.categoria_dano_id=1;data.potencia=150;data.tipo="NORMAL";data.precision=90;data.max_pp=5;data.pp=5;data.contacto=0;data.objetivo_id=10;data.prioridad=0;data.prob_secundario=0;data.efecto="EFFECT_RECHARGE"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_recharge"):return move
	var fact: Dictionary=phase.source_recharge
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

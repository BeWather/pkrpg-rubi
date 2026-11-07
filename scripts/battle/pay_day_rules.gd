extends RefCounted
## Ruby Pay Day policy; the result controller, never the animation, owns money.
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==6
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true);data.categoria_dano_id=1;data.potencia=40;data.tipo="NORMAL";data.precision=100;data.max_pp=20;data.pp=20;data.contacto=0;data.objetivo_id=10;data.prioridad=0;data.prob_secundario=100;data.efecto="EFFECT_PAY_DAY"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_pay_day"):return move
	var fact: Dictionary=phase.source_pay_day
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

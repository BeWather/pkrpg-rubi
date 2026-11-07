extends RefCounted
## Ruby uses Random()&255, not an approximate percentage draw or visual RNG.
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==217
static func selection(draw: int) -> Dictionary:
	return {"heal":draw>=204,"power":40 if draw<102 else 80 if draw<178 else 120}
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true);data.categoria_dano_id=1;data.potencia=1;data.tipo="NORMAL";data.precision=90;data.max_pp=15;data.pp=15;data.contacto=0;data.objetivo_id=10;data.prioridad=0;data.prob_secundario=0;data.efecto="EFFECT_PRESENT"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_present"):return move
	var fact: Dictionary=phase.source_present
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

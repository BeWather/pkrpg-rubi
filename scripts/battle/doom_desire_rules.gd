extends RefCounted
## Ruby353 freezes120/85/physical Steel at setup; the existing BANK queue owns due08.
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0))==353
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true)
	data.efecto="EFFECT_FUTURE_SIGHT";data.tipo="ACERO";data.categoria_dano_id=1;data.potencia=120;data.precision=85;data.max_pp=5;data.pp=5;data.contacto=0;data.prob_secundario=0;data.prioridad=0;data.objetivo_id=10
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_doom_desire"):return move
	if not phase.has("source_doom_desire_admitted"):
		var fact: Dictionary=phase.source_doom_desire
		phase.source_doom_desire_admitted=Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
	return phase.source_doom_desire_admitted

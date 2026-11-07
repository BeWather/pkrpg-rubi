extends RefCounted
## Ruby Poison is PHYSICAL; Acid lowers Defense, not modern Special Defense.
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0))==51
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true)
	data.categoria_dano_id=1;data.potencia=40;data.tipo="VENENO";data.precision=100;data.max_pp=30;data.pp=30;data.objetivo_id=11;data.contacto=0;data.prob_secundario=10;data.efecto="EFFECT_DEFENSE_DOWN_HIT"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_acid"):return move
	var fact: Dictionary=phase.source_acid
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

extends RefCounted
## Ruby Barrage uses Ruby15NormalPhysical85accuracy20PP and the existing source hit schedule.
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0))==140
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true)
	data.categoria_dano_id=1;data.potencia=15;data.tipo="NORMAL";data.precision=85;data.max_pp=20;data.pp=20;data.objetivo_id=10;data.contacto=0;data.prob_secundario=0;data.efecto="EFFECT_MULTI_HIT"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_barrage"):return move
	var fact: Dictionary=phase.source_barrage
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

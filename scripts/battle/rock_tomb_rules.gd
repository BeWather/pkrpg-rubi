extends RefCounted
## Ruby Rock Tomb uses Ruby50/80accuracy10PP and certain target Speed minus one.
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0))==317
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true)
	data.categoria_dano_id=1;data.potencia=50;data.tipo="ROCA";data.precision=80;data.max_pp=10;data.pp=10;data.objetivo_id=10;data.contacto=0;data.prob_secundario=100;data.efecto="EFFECT_SPEED_DOWN_HIT"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_rock_tomb"):return move
	var fact: Dictionary=phase.source_rock_tomb
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

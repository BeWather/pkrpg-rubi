extends RefCounted
## Ruby Normal/status policy, independent of the modern Fairy database row.
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0)) in [186,213]
static func capture(move: Movimiento) -> Dictionary:
	var kiss: bool=int(move.datos.get("numero_movimiento",0))==186
	var data: Dictionary=move.datos.duplicate(true)
	data.categoria_dano_id=3;data.potencia=0;data.tipo="NORMAL";data.precision=75 if kiss else 100;data.max_pp=10 if kiss else 15;data.pp=data.max_pp;data.objetivo_id=10;data.contacto=0;data.prob_secundario=0;data.efecto="EFFECT_CONFUSE" if kiss else "EFFECT_ATTRACT"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_kiss_attract"):return move
	var fact: Dictionary=phase.source_kiss_attract
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

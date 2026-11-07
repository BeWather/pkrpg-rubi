extends RefCounted
## Ruby Fire Blast120power, not modern110; type-based SPECIAL/noncontact.
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0))==126
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true)
	data.categoria_dano_id=2;data.potencia=120;data.tipo="FUEGO";data.precision=85;data.max_pp=5;data.pp=5;data.objetivo_id=10;data.contacto=0;data.prob_secundario=10;data.efecto="EFFECT_BURN_HIT"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_fire_blast"):return move
	var fact: Dictionary=phase.source_fire_blast
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

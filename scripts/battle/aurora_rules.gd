extends RefCounted
## Ruby selected-target65Ice SPECIAL, noncontact,10% Attack-down and20PP.
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0))==62
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true)
	data.categoria_dano_id=2;data.potencia=65;data.tipo="HIELO";data.precision=100;data.max_pp=20;data.pp=20;data.objetivo_id=10;data.contacto=0;data.prob_secundario=10;data.efecto="EFFECT_ATTACK_DOWN_HIT"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_aurora"):return move
	var fact: Dictionary=phase.source_aurora
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

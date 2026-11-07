extends RefCounted
## Ruby source status policy; native stat resolver remains the sole producer.
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0)) in [313,321]
static func capture(move: Movimiento) -> Dictionary:
	var tears: bool=int(move.datos.get("numero_movimiento",0))==313
	var data: Dictionary=move.datos.duplicate(true)
	data.categoria_dano_id=3;data.potencia=0;data.tipo="SINIESTRO" if tears else "NORMAL";data.precision=100;data.max_pp=20;data.pp=20;data.objetivo_id=10;data.contacto=0;data.prob_secundario=0;data.efecto="EFFECT_SPECIAL_DEFENSE_DOWN_2" if tears else "EFFECT_TICKLE"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_tears_tickle"):return move
	var fact: Dictionary=phase.source_tears_tickle
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

extends RefCounted
## Ruby Psycho Boost uses Psychic SPECIAL140 and certain user Special Attack minus two.
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0))==354
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true)
	data.categoria_dano_id=2;data.potencia=140;data.tipo="PSIQUICO";data.precision=90;data.max_pp=5;data.pp=5;data.objetivo_id=10;data.contacto=0;data.prob_secundario=100;data.efecto="EFFECT_OVERHEAT"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_psycho_boost"):return move
	var fact: Dictionary=phase.source_psycho_boost
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

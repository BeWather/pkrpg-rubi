extends RefCounted
## Ruby Mist Ball uses Psychic SPECIAL70 and fifty-percent Special Attack down.
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0))==296
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true)
	data.categoria_dano_id=2;data.potencia=70;data.tipo="PSIQUICO";data.precision=100;data.max_pp=5;data.pp=5;data.objetivo_id=10;data.contacto=0;data.prob_secundario=50;data.efecto="EFFECT_SPECIAL_ATTACK_DOWN_HIT"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_mist_ball"):return move
	var fact: Dictionary=phase.source_mist_ball
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

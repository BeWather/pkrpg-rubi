extends RefCounted
## Ruby heart-family accepted policy; live party PP is never refilled.
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0)) in [204,343]
static func capture(move: Movimiento) -> Dictionary:
	var covet: bool=int(move.datos.get("numero_movimiento",0))==343
	var data: Dictionary=move.datos.duplicate(true)
	data.categoria_dano_id=1 if covet else 3;data.potencia=40 if covet else 0;data.tipo="NORMAL";data.precision=100;data.max_pp=40 if covet else 20;data.pp=data.max_pp;data.objetivo_id=10;data.contacto=0;data.prob_secundario=100 if covet else 0;data.efecto="EFFECT_THIEF" if covet else "EFFECT_ATTACK_DOWN_2"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_heart"):return move
	var fact: Dictionary=phase.source_heart
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

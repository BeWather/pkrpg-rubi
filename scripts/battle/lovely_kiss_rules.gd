extends RefCounted
## Actual Lovely Kiss source policy; native status/sleep counter authority is shared.
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0))==142
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true)
	data.categoria_dano_id=3;data.potencia=0;data.tipo="NORMAL";data.precision=75;data.max_pp=10;data.pp=10;data.objetivo_id=10;data.contacto=0;data.prob_secundario=0;data.efecto="EFFECT_SLEEP"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_lovely_kiss"):return move
	var fact: Dictionary=phase.source_lovely_kiss
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

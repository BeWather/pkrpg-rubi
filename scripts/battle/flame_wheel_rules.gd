extends RefCounted
## Ruby Flame Wheel uses Fire SPECIAL60, contact, ten-percent burn and self-thaw.
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0))==172
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true)
	data.categoria_dano_id=2;data.potencia=60;data.tipo="FUEGO";data.precision=100;data.max_pp=25;data.pp=25;data.objetivo_id=10;data.contacto=1;data.prob_secundario=10;data.efecto="EFFECT_THAW_HIT"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_flame_wheel"):return move
	var fact: Dictionary=phase.source_flame_wheel
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

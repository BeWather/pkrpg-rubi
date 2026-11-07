extends RefCounted
## Only source admission; the existing confusion authority owns volatile state.
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==298
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true);data.tipo="NORMAL";data.categoria_dano_id=3;data.potencia=0;data.precision=100;data.max_pp=20;data.pp=20;data.objetivo_id=9;data.prioridad=0;data.contacto=0;data.prob_secundario=0;data.efecto="EFFECT_TEETER_DANCE"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_teeter_dance"):return move
	var fact: Dictionary=phase.source_teeter_dance
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

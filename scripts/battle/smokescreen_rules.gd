extends RefCounted
## Ruby Smokescreen uses Normal status/100 accuracy/20PP selected target; existing Accuracy-1 authority.
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0))==108
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true)
	data.categoria_dano_id=3;data.potencia=0;data.tipo="NORMAL";data.precision=100;data.max_pp=20;data.pp=20;data.objetivo_id=10;data.contacto=0;data.prob_secundario=0;data.efecto="EFFECT_ACCURACY_DOWN"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_smokescreen"):return move
	var fact: Dictionary=phase.source_smokescreen
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

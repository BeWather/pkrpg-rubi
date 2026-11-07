extends RefCounted
## Ruby Kinesis uses Psychic status/80 accuracy/15PP selected target; existing Accuracy-1 authority.
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0))==134
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true)
	data.categoria_dano_id=3;data.potencia=0;data.tipo="PSIQUICO";data.precision=80;data.max_pp=15;data.pp=15;data.objetivo_id=10;data.contacto=0;data.prob_secundario=0;data.efecto="EFFECT_ACCURACY_DOWN"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_kinesis"):return move
	var fact: Dictionary=phase.source_kinesis
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

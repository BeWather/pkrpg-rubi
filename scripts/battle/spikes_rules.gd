extends RefCounted
## Ruby Spikes uses Ground status/zero accuracy/20PP enemy-side producer; owned PP is separate.
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0))==191
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true)
	data.categoria_dano_id=3;data.potencia=0;data.tipo="TIERRA";data.precision=0;data.max_pp=20;data.pp=20;data.objetivo_id=6;data.contacto=0;data.prob_secundario=0;data.efecto="EFFECT_SPIKES"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_spikes"):return move
	var fact: Dictionary=phase.source_spikes
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

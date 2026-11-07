extends RefCounted
## Ruby Flatter raises target SpAtk once before confusion; current owned PP stays authoritative.
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==260
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true);data.categoria_dano_id=3;data.potencia=0;data.tipo="SINIESTRO";data.precision=100;data.max_pp=15;data.pp=15;data.contacto=0;data.objetivo_id=10;data.prioridad=0;data.prob_secundario=0;data.efecto="EFFECT_FLATTER"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_flatter"):return move
	var fact: Dictionary=phase.source_flatter
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

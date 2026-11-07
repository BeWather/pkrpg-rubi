extends RefCounted
## Source Guillotine policy; existing OHKO authority owns hit and HP.
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0))==12
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true)
	data.categoria_dano_id=1;data.potencia=1;data.tipo="NORMAL";data.precision=30;data.max_pp=5;data.pp=5;data.contacto=1;data.objetivo_id=10;data.prioridad=0;data.prob_secundario=0;data.efecto="EFFECT_OHKO"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_guillotine"):return move
	var fact: Dictionary=phase.source_guillotine
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

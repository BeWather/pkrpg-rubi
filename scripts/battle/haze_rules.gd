extends RefCounted
## Only source admission; the native turn controller owns all-bank stat reset.
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==114
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true);data.tipo="HIELO";data.categoria_dano_id=3;data.potencia=0;data.precision=0;data.max_pp=30;data.pp=30;data.objetivo_id=7;data.prioridad=0;data.contacto=0;data.prob_secundario=0;data.efecto="EFFECT_HAZE"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_haze"):return move
	var fact: Dictionary=phase.source_haze
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

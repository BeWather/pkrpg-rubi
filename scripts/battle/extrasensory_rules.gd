extends RefCounted
## Source admission only: existing hit/secondary/preturn authority owns flinch.
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==326
static func capture(move: Movimiento) -> Dictionary:
	var d: Dictionary=move.datos.duplicate(true);d.tipo="PSIQUICO";d.categoria_dano_id=2;d.potencia=80;d.precision=100;d.max_pp=30;d.pp=30;d.contacto=0;d.objetivo_id=10;d.prioridad=0;d.prob_secundario=10;d.efecto="EFFECT_FLINCH_HIT_2"
	return {"name":move.nombre,"data":d}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_extrasensory"):return move
	var fact: Dictionary=phase.source_extrasensory
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

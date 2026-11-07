extends RefCounted
## Source admission only: source status producer owns HP and stat order, never animation.
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==262
static func capture(move: Movimiento) -> Dictionary:
	var d: Dictionary=move.datos.duplicate(true);d.tipo="SINIESTRO";d.categoria_dano_id=3;d.potencia=0;d.precision=100;d.max_pp=10;d.pp=10;d.contacto=0;d.objetivo_id=10;d.prioridad=0;d.prob_secundario=0;d.efecto="EFFECT_MEMENTO"
	return {"name":move.nombre,"data":d}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_memento"):return move
	var fact: Dictionary=phase.source_memento
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

extends RefCounted
## Source Faint Attack policy; existing nonnumeric accuracy authority owns hit and HP.
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0))==185
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true)
	data.categoria_dano_id=2;data.potencia=60;data.tipo="SINIESTRO";data.precision=0;data.max_pp=20;data.pp=20;data.contacto=0;data.objetivo_id=10;data.prioridad=0;data.prob_secundario=0;data.efecto="EFFECT_ALWAYS_HIT"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_faint_attack"):return move
	var fact: Dictionary=phase.source_faint_attack
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

extends RefCounted
## Only source admission; existing CambioEstadisticaGen3 owns the stat changes.
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==294
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true);data.tipo="BICHO";data.categoria_dano_id=3;data.potencia=0;data.precision=100;data.max_pp=20;data.pp=20;data.objetivo_id=7;data.prioridad=0;data.contacto=0;data.prob_secundario=0;data.efecto="EFFECT_SPECIAL_ATTACK_UP_2"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_tail_glow"):return move
	var fact: Dictionary=phase.source_tail_glow
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

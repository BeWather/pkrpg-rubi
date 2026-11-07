extends RefCounted
## Source Seismic Toss policy; shared fixed-damage calculation and existing attack authority own HP.
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0))==69
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true)
	data.categoria_dano_id=1;data.potencia=1;data.tipo="LUCHA";data.precision=100;data.max_pp=20;data.pp=20;data.contacto=1;data.objetivo_id=10;data.prioridad=0;data.prob_secundario=0;data.efecto="EFFECT_LEVEL_DAMAGE"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_seismic_toss"):return move
	var fact: Dictionary=phase.source_seismic_toss
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

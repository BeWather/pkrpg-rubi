extends RefCounted
## Ruby first-field-turn producer and distinct ordinary startle policies.
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0)) in [252,310]
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true);var fake: bool=int(data.numero_movimiento)==252
	data.potencia=40 if fake else 30;data.tipo="NORMAL" if fake else "FANTASMA";data.categoria_dano_id=1;data.precision=100;data.max_pp=10 if fake else 15;data.pp=data.max_pp;data.contacto=0 if fake else 1;data.objetivo_id=10;data.prioridad=1 if fake else 0;data.prob_secundario=0 if fake else 30;data.efecto="EFFECT_FAKE_OUT" if fake else "EFFECT_FLINCH_HIT_2"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_startle"):return move
	var fact: Dictionary=phase.source_startle
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

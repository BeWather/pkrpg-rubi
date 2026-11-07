extends RefCounted
## Ruby self-heals share an effect, not metadata accuracy. Retain current owned PP.
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0))in [105,135,208,303]
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true)
	data.categoria_dano_id=3;data.potencia=0;data.tipo="NORMAL";data.precision=100 if int(data.numero_movimiento) in [135,303] else 0;data.max_pp=20 if int(data.numero_movimiento)==105 else 10;data.pp=data.max_pp;data.objetivo_id=7;data.contacto=0;data.prob_secundario=0;data.efecto="EFFECT_RESTORE_HP" if int(data.numero_movimiento) in [105,303] else "EFFECT_SOFTBOILED"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_self_heal"):return move
	var fact: Dictionary=phase.source_self_heal
	if int(fact.data.numero_movimiento) in [105,303]:
		if not phase.has("source_restore_hp_admitted"):phase.source_restore_hp_admitted=Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
		return phase.source_restore_hp_admitted
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

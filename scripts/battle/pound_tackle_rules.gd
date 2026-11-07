extends RefCounted
## Ruby's original Normal contact policies; Tackle is35power/95accuracy, not modern40/100.
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0)) in [1,33]
static func capture(move: Movimiento) -> Dictionary:
	var tackle: bool=int(move.datos.get("numero_movimiento",0))==33;var data: Dictionary=move.datos.duplicate(true)
	data.potencia=35 if tackle else 40;data.precision=95 if tackle else 100;data.tipo="NORMAL";data.categoria_dano_id=1;data.max_pp=35;data.pp=35;data.contacto=1;data.objetivo_id=10;data.prioridad=0;data.prob_secundario=0;data.efecto="EFFECT_HIT"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_pound_tackle"):return move
	if phase.has("source_pound_tackle_admitted"):return phase.source_pound_tackle_admitted
	var fact: Dictionary=phase.source_pound_tackle;var accepted:=Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true));phase.source_pound_tackle_admitted=accepted;return accepted

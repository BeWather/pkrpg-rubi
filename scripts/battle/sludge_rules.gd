extends RefCounted
## Ruby Poison category remains PHYSICAL for both ordinary Sludge moves.
const POWER={124:65,188:90}
const PP={124:20,188:10}
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0)) in POWER
static func capture(move: Movimiento) -> Dictionary:
	var id: int=int(move.datos.get("numero_movimiento",0));var data: Dictionary=move.datos.duplicate(true)
	data.categoria_dano_id=1;data.potencia=POWER[id];data.tipo="VENENO";data.precision=100;data.max_pp=PP[id];data.pp=PP[id];data.objetivo_id=10;data.contacto=0;data.prob_secundario=30;data.efecto="EFFECT_POISON_HIT"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_sludge"):return move
	var fact: Dictionary=phase.source_sludge
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

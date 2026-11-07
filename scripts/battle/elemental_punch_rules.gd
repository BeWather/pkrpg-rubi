extends RefCounted
## Ruby type-based categories: Fire/Ice punches are SPECIAL, still contact.
static func supports(move: Movimiento) -> bool:
	if move==null:return false
	var id: int=int(move.datos.get("numero_movimiento",0))
	return id in [7,8] or (id==0 and move.get_nombre_interno() in ["PUNOFUEGO","PUNOHIELO"])
static func capture(move: Movimiento) -> Dictionary:
	if not supports(move):return {}
	var data: Dictionary=move.datos.duplicate(true)
	data.categoria_dano_id=2;data.potencia=75;data.precision=100
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_elemental_punch"):return move
	var fact: Dictionary=phase.source_elemental_punch
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

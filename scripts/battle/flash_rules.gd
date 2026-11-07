extends RefCounted
## Ruby Flash has70 accuracy, unlike the modern DB100; existing stat logic is−1.
static func supports(move: Movimiento) -> bool:
	return move!=null and (int(move.datos.get("numero_movimiento",0))==148 or move.get_nombre_interno() in ["DESTELLO","FLASH"])
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true)
	data.precision=70;data.objetivo_id=10;data.max_pp=20;data.pp=20;data.potencia=0;data.tipo="NORMAL";data.efecto="EFFECT_ACCURACY_DOWN"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_flash"):return move
	var fact: Dictionary=phase.source_flash
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

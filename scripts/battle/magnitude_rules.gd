extends RefCounted
## One Ruby Random()%100 draw maps to one dynamic power for the whole cast.
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==222
static func selection(draw: int) -> Dictionary:
	var limits: Array=[5,15,35,65,85,95,100];var powers: Array=[10,30,50,70,90,110,150]
	for index: int in 7:
		if draw<int(limits[index]):return {"level":index+4,"power":powers[index]}
	return {}
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true);data.categoria_dano_id=1;data.potencia=1;data.tipo="TIERRA";data.precision=100;data.max_pp=30;data.pp=30;data.contacto=0;data.objetivo_id=9;data.prioridad=0;data.prob_secundario=0;data.efecto="EFFECT_MAGNITUDE"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_magnitude"):return move
	var fact: Dictionary=phase.source_magnitude
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

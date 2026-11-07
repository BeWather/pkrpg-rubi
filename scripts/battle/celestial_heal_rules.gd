extends RefCounted
## Ruby atkC0: shared weather authority; party PP and animation remain independent.
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0)) in [234,235,236]
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true);var id: int=int(data.numero_movimiento)
	data.categoria_dano_id=3;data.potencia=0;data.tipo="PLANTA" if id==235 else "NORMAL";data.precision=0;data.max_pp=5;data.pp=5;data.objetivo_id=7;data.contacto=0;data.prob_secundario=0;data.efecto={234:"EFFECT_MORNING_SUN",235:"EFFECT_SYNTHESIS",236:"EFFECT_MOONLIGHT"}[id]
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_celestial_heal"):return move
	var fact: Dictionary=phase.source_celestial_heal
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
static func amount(maximum: int,field: CampoCombate) -> int:
	var weather: int=field.clima_efectivo()
	return maxi(1,maximum/2 if weather==0 else 20*maximum/30 if weather==Singleton.ClimaBatalla.SOLEADO else maximum/4)

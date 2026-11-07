extends RefCounted
## Ruby HP-scaled moves share one power authority; policy remains150.
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0)) in [284,323]
static func power(actor: BasePokemon) -> int:return maxi(1,150*actor.estad_ps_actual/maxi(1,actor.estad_ps))
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true);data.categoria_dano_id=2;data.potencia=150;data.tipo="FUEGO" if int(data.numero_movimiento)==284 else "AGUA";data.precision=100;data.max_pp=5;data.pp=5;data.contacto=0;data.objetivo_id=11;data.prioridad=0;data.prob_secundario=0;data.efecto="EFFECT_ERUPTION"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_hp_burst"):return move
	var fact: Dictionary=phase.source_hp_burst
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

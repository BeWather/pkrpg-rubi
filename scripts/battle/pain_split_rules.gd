extends RefCounted
## Ruby computes one uncapped common current-HP average, not a damage or healing move.
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==220
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true);data.categoria_dano_id=3;data.potencia=0;data.tipo="NORMAL";data.precision=100;data.max_pp=20;data.pp=20;data.contacto=0;data.objetivo_id=10;data.prioridad=0;data.prob_secundario=0;data.efecto="EFFECT_PAIN_SPLIT"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_pain_split"):return move
	var fact: Dictionary=phase.source_pain_split
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
static func plan(actor: BasePokemon,target: BasePokemon,state: PokemonEnCombate) -> Dictionary:
	if actor==null or target==null or actor.estad_ps_actual<=0 or target.estad_ps_actual<=0 or state==null or state.substitute_hp>0:return {}
	return {"average":int(actor.estad_ps_actual+target.estad_ps_actual)/2}
static func commit(actor: BasePokemon,target: BasePokemon,accepted: Dictionary) -> void:
	# Publish both precomputed endpoints before presentation yields; never recompute after user cap.
	actor.estad_ps_actual=mini(actor.estad_ps,int(accepted.average));target.estad_ps_actual=mini(target.estad_ps,int(accepted.average))

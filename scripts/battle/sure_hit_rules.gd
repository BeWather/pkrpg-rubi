class_name BattleSureHitRules
extends RefCounted
## Ruby target-held STATUS3_ALWAYS_HITS_TURN(2), decremented by rounds, not hits.
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0)) in [170,199]
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true)
	data.categoria_dano_id=3;data.potencia=0;data.tipo="NORMAL";data.precision=100;data.max_pp=5;data.pp=5;data.objetivo_id=10;data.contacto=0;data.prob_secundario=0;data.efecto="EFFECT_LOCK_ON"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_sure_hit"):return move
	var fact: Dictionary=phase.source_sure_hit
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
static func produce(actor: PokemonEnCombate,target: PokemonEnCombate) -> bool:
	if actor==null or target==null or actor.pokemon_base.estad_ps_actual<=0 or target.pokemon_base.estad_ps_actual<=0:return false
	target.source_sure_hit_turns=2;target.source_sure_hit_attacker=weakref(actor);return true
static func guarantees(actor: PokemonEnCombate,target: PokemonEnCombate) -> bool:
	return actor!=null and target!=null and target.source_sure_hit_turns>0 and target.source_sure_hit_attacker!=null and target.source_sure_hit_attacker.get_ref()==actor and actor.pokemon_base.estad_ps_actual>0 and target.pokemon_base.estad_ps_actual>0

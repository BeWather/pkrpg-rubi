extends RefCounted
## Ruby atkD3; copy effective battle ability, not party identity or entry hooks.
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==272
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true);data.tipo="PSIQUICO";data.categoria_dano_id=3;data.potencia=0;data.precision=100;data.max_pp=10;data.pp=10;data.contacto=0;data.objetivo_id=10;data.prioridad=0;data.prob_secundario=0;data.efecto="EFFECT_ROLE_PLAY"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_role_play"):return move
	var fact: Dictionary=phase.source_role_play
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
static func produce(actor: BasePokemon,target: BasePokemon) -> String:
	var ability: String=HabilidadesCombate.de(target)
	if ability.is_empty() or ability==HabilidadesCombate.SUPERGUARDA:return ""
	# Equal abilities succeed in Ruby. The shared setter preserves Transform/Trace.
	HabilidadesCombate.establecer_habilidad_combate(actor,ability)
	return ability

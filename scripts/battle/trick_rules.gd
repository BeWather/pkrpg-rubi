extends RefCounted
## Ruby selected-target status admission and live party-held ownership producer.
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0))==271
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true)
	data.categoria_dano_id=3;data.potencia=0;data.tipo="PSIQUICO";data.precision=100;data.max_pp=10;data.pp=10;data.contacto=0;data.objetivo_id=10;data.prioridad=0;data.prob_secundario=0;data.efecto="EFFECT_TRICK"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_trick"):return move
	var fact: Dictionary=phase.source_trick
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
static func produce(battle: Node,actor: BasePokemon,target: BasePokemon) -> bool:
	# Ruby ordinary opponent cannot initiate; link/tower/secret-base exceptions
	# require battle-mode metadata not yet represented by the native domain.
	var position: Dictionary=battle.field_rules.position(actor)
	if position.is_empty() or not bool(position.player):return false
	if HabilidadesCombate.evita_robo_objeto(target):return false
	var original_actor: Dictionary=battle.field_rules.capture(actor);var original_target: Dictionary=battle.field_rules.capture(target)
	if not battle.field_rules.valid(original_actor) or not battle.field_rules.valid(original_target):return false
	if not ObjetosLlevados.intercambiar_en_combate(actor,target):return false
	for original: Dictionary in [original_actor,original_target]:
		if battle.field_rules.valid(original):preload("res://scripts/battle/choice_band_rules.gd").clear_state(original.state.get_ref())
	return true

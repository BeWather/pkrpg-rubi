extends RefCounted
## Ruby status2 bit and tryfaintmon USER retaliation; no modern repeat restriction.
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==194
static func capture(move: Movimiento) -> Dictionary:
	var d: Dictionary=move.datos.duplicate(true);d.tipo="FANTASMA";d.categoria_dano_id=3;d.potencia=0;d.precision=0;d.max_pp=5;d.pp=5;d.contacto=0;d.objetivo_id=7;d.prioridad=0;d.prob_secundario=0;d.efecto="EFFECT_DESTINY_BOND"
	return {"name":move.nombre,"data":d}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_destiny_bond"):return move
	var fact: Dictionary=phase.source_destiny_bond
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
static func capture_hit(battle: Node,target: BasePokemon,actor: BasePokemon) -> Dictionary:
	var state: PokemonEnCombate=battle._obtener_combatiente(target)
	if state==null or not state.source_destiny_bond or target.estad_ps_actual<=0 or actor.estad_ps_actual<=0:return {}
	if bool(battle.field_rules.position(target).player)==bool(battle.field_rules.position(actor).player):return {}
	return {"owner":weakref(battle),"target":battle.field_rules.capture(target),"actor":battle.field_rules.capture(actor),"flow":battle.field_rules.capture_flow(),"hp":target.estad_ps_actual}
static func settle(hit: Dictionary,result: Dictionary) -> bool:
	if hit.is_empty() or bool(result.get("substitute",false)):return false
	var battle: Node=hit.owner.get_ref()
	if not is_instance_valid(battle):return false
	var target: BasePokemon=hit.target.pokemon;var actor: BasePokemon=hit.actor.pokemon
	if target.estad_ps_actual!=0 or int(result.get("damage",0))<int(hit.hp) or actor.estad_ps_actual<=0:return false
	# The hit owns one target retirement only. Neither the slot nor another
	# occupant/state/lifetime may be reacquired after an asynchronous HP HUD.
	var original: PokemonEnCombate=hit.target.state.get_ref()
	if original==null or original.body_attack_epoch!=int(hit.target.epoch)+1:return false
	var flow: Dictionary=hit.flow.duplicate(true)
	for record: Dictionary in flow.records:
		if record.pokemon==target:record.epoch=original.body_attack_epoch
	if not battle.field_rules.valid_flow(flow):return false
	original.source_destiny_bond=false
	await battle.mostrar_texto_batalla("¡%s se llevó a su rival consigo!"%target.get_nombre_combate())
	if not battle.field_rules.valid_flow(flow):return false
	# Passive source datahpupdate ignores Substitute and Endure; not an attack,
	# therefore it must not recurse into another Destiny Bond or contact effect.
	var actor_epoch: int=int(hit.actor.epoch)
	await battle.field_rules.passive_hp(hit.actor,actor.estad_ps_actual)
	if actor.estad_ps_actual!=0 or int(hit.actor.epoch)!=actor_epoch+1 or not battle.field_rules.valid(hit.actor):return false
	for record: Dictionary in flow.records:
		if record.pokemon==actor:record.epoch=int(hit.actor.epoch)
	return battle.field_rules.valid_flow(flow)

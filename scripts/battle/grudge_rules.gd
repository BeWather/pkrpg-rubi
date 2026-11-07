extends RefCounted
## Ruby STATUS3_GRUDGE and atk19 ChosenMoveID, not gCurrentMove's ID.
class SelectedSlot extends RefCounted:
	var actor: Dictionary
	var slots: Array
	var index: int
	var resource: Movimiento
	func live(battle: Node) -> bool:
		if not battle.field_rules.valid(actor):return false
		var state: PokemonEnCombate=actor.state.get_ref()
		return state!=null and is_same(slots,state.get_movimientos()) and index>=0 and index<slots.size() and slots[index]==resource
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==288
static func capture(move: Movimiento) -> Dictionary:
	var d: Dictionary=move.datos.duplicate(true);d.tipo="FANTASMA";d.categoria_dano_id=3;d.potencia=0;d.precision=100;d.max_pp=5;d.pp=5;d.contacto=0;d.objetivo_id=7;d.prioridad=0;d.prob_secundario=0;d.efecto="EFFECT_GRUDGE"
	return {"name":move.nombre,"data":d}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_grudge"):return move
	var fact: Dictionary=phase.source_grudge
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
static func selected_slot(battle: Node,actor: BasePokemon,move: Movimiento) -> SelectedSlot:
	var state: PokemonEnCombate=battle._obtener_combatiente(actor)
	if state==null:return null
	var slots: Array=state.get_movimientos();var index: int=slots.find(move)
	if index<0 or index>=4:return null
	var token: SelectedSlot=SelectedSlot.new();token.actor=battle.field_rules.capture(actor);token.slots=slots;token.index=index;token.resource=move
	return token
static func capture_hit(battle: Node,target: BasePokemon,actor: BasePokemon,action: BattleMoveAction) -> Dictionary:
	if action==null or int(action.get_meta("source_landed_policy",{}).get("id",0))==165:return {}
	# set_meta(key, null) erases the key, so a null selected slot arrives as missing;
	# get_meta(key, null) still errors because a null default means «no default».
	var token: SelectedSlot=action.get_meta("source_grudge_selected_slot") if action.has_meta("source_grudge_selected_slot") else null
	var state: PokemonEnCombate=battle._obtener_combatiente(target)
	if token==null or not token.live(battle) or token.actor.pokemon!=actor or state==null or not state.source_grudge or target.estad_ps_actual<=0 or actor.estad_ps_actual<=0:return {}
	if bool(battle.field_rules.position(target).player)==bool(battle.field_rules.position(actor).player):return {}
	return {"owner":weakref(battle),"target":battle.field_rules.capture(target),"slot":token,"flow":battle.field_rules.capture_flow(),"hp":target.estad_ps_actual}
static func settle(hit: Dictionary,result: Dictionary) -> void:
	if hit.is_empty() or bool(result.get("substitute",false)):return
	var battle: Node=hit.owner.get_ref()
	if not is_instance_valid(battle):return
	var target: BasePokemon=hit.target.pokemon;var token: SelectedSlot=hit.slot
	if target.estad_ps_actual!=0 or int(result.get("damage",0))<int(hit.hp) or not token.live(battle) or token.actor.pokemon.estad_ps_actual<=0:return
	# Adopt exactly the original target's one owned KO epoch. No replacement,
	# extra retirement, changed move array or newly matching ID is authorized.
	var original: PokemonEnCombate=hit.target.state.get_ref()
	if original==null or original.body_attack_epoch!=int(hit.target.epoch)+1:return
	var flow: Dictionary=hit.flow.duplicate(true)
	for record: Dictionary in flow.records:
		if record.pokemon==target:record.epoch=original.body_attack_epoch
	if not battle.field_rules.valid_flow(flow):return
	# The effective resource IS the party slot only for a noncopied move.
	# Temporary Mimic/Transform resources must never synchronize party PP.
	token.resource.pp_act=0
	await battle.mostrar_texto_batalla("¡El rencor agotó los PP de %s!"%token.resource.nombre)

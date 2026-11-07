extends RefCounted
## Ruby atk6A/EA history belongs to a battle BANK, not a party member.
## False case1 item dispatch; each family retains its source script order.
const HISTORY="source_used_held_items"
const Effects=preload("res://scripts/battle/held_item_effect_provider.gd")
const ItemTransaction=preload("res://scripts/battle/held_item_transaction.gd")
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==278
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true);data.tipo="NORMAL";data.categoria_dano_id=3;data.potencia=0;data.precision=100;data.max_pp=10;data.pp=10;data.contacto=0;data.objetivo_id=7;data.prioridad=0;data.prob_secundario=0;data.efecto="EFFECT_RECYCLE"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_recycle"):return move
	var fact: Dictionary=phase.source_recycle
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
static func clear(battle: BattleSceneController) -> void:
	battle.remove_meta(HISTORY)
static func _bank(battle: BattleSceneController,actor: BasePokemon) -> int:
	var slot: BattleSlot=battle.hud._obtener_slot_de_pokemon(actor)
	return slot.get_instance_id() if is_instance_valid(slot) else 0
static func consume(battle: BattleSceneController,actor: BasePokemon,lease: Dictionary) -> String:
	if battle.fase==battle.FIN_BATALLA or not battle.field_rules.valid(lease):return ""
	var bank: int=_bank(battle,actor);var item: String=ObjetosLlevados.en_combate(actor)
	if bank==0 or item.is_empty():return ""
	# The same actual party resource supplies and loses the item; no bag/save IO.
	var history: Dictionary=battle.get_meta(HISTORY,{})
	history[bank]=item;actor.objeto="";battle.set_meta(HISTORY,history)
	return item
static func produce(battle: BattleSceneController,actor: BasePokemon) -> String:
	var lease: Dictionary=battle.field_rules.capture(actor)
	if battle.fase==battle.FIN_BATALLA or lease.is_empty() or not battle.field_rules.valid(lease):return ""
	# Raw source item==0: Knock Off suppression does not make a held item empty.
	if not actor.objeto.strip_edges().is_empty():return ""
	var bank: int=_bank(battle,actor);var history: Dictionary=battle.get_meta(HISTORY,{})
	var item: String=str(history.get(bank,""))
	if item.is_empty():return ""
	history.erase(bank);battle.set_meta(HISTORY,history);actor.objeto=item
	return item
static func hp_end_round(battle: BattleSceneController,actor: BasePokemon,lease: Dictionary) -> void:
	if not battle.field_rules.valid(lease) or actor.estad_ps_actual<=0:return
	var descriptor: Dictionary=battle.held_item_effects.resolve(battle,actor,lease)
	var item: String=descriptor.item;var effect: int=int(descriptor.source_effect)
	if effect>=Effects.ATTACK_UP and effect<=Effects.RANDOM_STAT_UP:
		await preload("res://scripts/battle/held_stat_berry_rules.gd").end_round(battle,actor,lease);return
	if effect>=Effects.CONFUSE_SPICY and effect<=Effects.CONFUSE_SOUR:
		await preload("res://scripts/battle/held_flavor_berry_rules.gd").end_round(battle,actor,lease);return
	if effect!=Effects.RESTORE_HP or actor.estad_ps_actual>actor.estad_ps/2 or actor.estad_ps_actual>=actor.estad_ps:return
	# Case1 !moveTurn only, ability -> item -> Leech Seed. Source script:
	# General7, message/wait, HP HUD/data, then removeitem/history/party update.
	var amount: int=mini(int(descriptor.parameter),actor.estad_ps-actor.estad_ps_actual)
	var accepted: Dictionary=ItemTransaction.capture(battle,lease,battle.field_rules.capture_flow([actor]),descriptor)
	if not await ItemTransaction.present(battle,accepted):return
	if actor.estad_ps_actual<=0 or actor.estad_ps_actual>=actor.estad_ps:return
	await battle.mostrar_texto_batalla("¡%s restauró salud con %s!"%[actor.get_nombre_combate(),ObjetosLlevados.nombre_objeto(item)])
	if not ItemTransaction.valid(battle,accepted) or actor.estad_ps_actual<=0 or actor.estad_ps_actual>=actor.estad_ps:return
	# Native HP authority precedes its awaited HUD tween. A new assignment
	# during that tween never rolls back the accepted heal or consumes the new item.
	await battle.habilidades._curar(actor,amount)
	if not ItemTransaction.valid(battle,accepted) or actor.estad_ps_actual<=0:return
	consume(battle,actor,lease)

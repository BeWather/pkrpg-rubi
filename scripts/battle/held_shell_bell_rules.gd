extends RefCounted
## Ruby MoveEnd numeric stage9 / ItemBattleEffects case4. Never consumes.
const Ledger=preload("res://scripts/battle/shell_bell_damage_ledger.gd")
const StatusItems=preload("res://scripts/battle/held_status_berry_rules.gd")
const Transaction=preload("res://scripts/battle/held_item_transaction.gd")
const Effects=preload("res://scripts/battle/held_item_effect_provider.gd")
static func settle_hit(battle: Node,action: BattleMoveAction,target: BasePokemon) -> void:
	var receipt: Dictionary=action.get_meta("source_shell_bell_damage",{}).get(target.get_instance_id(),{})
	if not Ledger.valid(battle,receipt):return
	# Source case3 follows contact abilities and precedes case4 on every strike.
	await StatusItems.settle(battle,receipt.status_items)
	action.set_meta("source_item_moveend_reached",true)
	if not Ledger.valid(battle,receipt):return
	var actor: BasePokemon=receipt.actor.pokemon
	var damage: int=int(receipt.damage)
	if bool(receipt.self_ko) or not bool(receipt.nonzero) or damage in [0,65535] or actor==target or actor.estad_ps_actual<=0 or actor.estad_ps_actual>=actor.estad_ps:return
	# Read CURRENT item at the producer, never action admission. Capture once.
	var descriptor: Dictionary=battle.held_item_effects.resolve(battle,actor,receipt.actor)
	if int(descriptor.source_effect)!=Effects.SHELL_BELL or int(descriptor.parameter)<=0:return
	var amount: int=maxi(1,damage/int(descriptor.parameter))
	var accepted: Dictionary=Transaction.capture(battle,receipt.actor,receipt.flow,descriptor)
	if not Transaction.valid(battle,accepted):return
	receipt.damage=0 # Source consumes its DAMAGE token before yielding, not item.
	if not await Transaction.present(battle,accepted):return
	if actor.estad_ps_actual<=0 or actor.estad_ps_actual>=actor.estad_ps:return
	await battle.mostrar_texto_batalla("¡%s restauró PS usando su %s!"%[actor.get_nombre_combate(),ObjetosLlevados.nombre_objeto(descriptor.item)])
	if not Transaction.valid(battle,accepted) or actor.estad_ps_actual<=0 or actor.estad_ps_actual>=actor.estad_ps:return
	await battle.habilidades._curar(actor,amount)

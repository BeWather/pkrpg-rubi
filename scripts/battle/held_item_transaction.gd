extends RefCounted
## Shared item identity and holder lifetime; each source script owns its mutation order.
static func capture(battle: Node,lease: Dictionary,flow: Dictionary,descriptor: Dictionary={}) -> Dictionary:
	if not battle.field_rules.valid(lease):return {}
	var pokemon: BasePokemon=lease.pokemon
	if descriptor.is_empty():descriptor=battle.held_item_effects.resolve(battle,pokemon,lease)
	return {"descriptor":descriptor,"lease":lease,"flow":flow,"pokemon":pokemon,"item":ObjetosLlevados.en_combate(pokemon),"revision":pokemon.held_item_revision}
static func valid(battle: Node,accepted: Dictionary) -> bool:
	if accepted.is_empty():return false
	return battle.held_item_effects.revision==int(accepted.descriptor.provider_revision) and battle.field_rules.valid_flow(accepted.flow) and battle.field_rules.valid(accepted.lease) and accepted.pokemon.held_item_revision==int(accepted.revision) and accepted.pokemon.objeto==accepted.item and ObjetosLlevados.en_combate(accepted.pokemon)==accepted.item
static func present(battle: Node,accepted: Dictionary) -> bool:
	if not valid(battle,accepted):return false
	var slot: BattleSlot=accepted.lease.slot.get_ref()
	var context:=BattleAnimationContext.from_legacy(MoveAnimationContext.nueva(battle,slot,slot));context.phase="item"
	var animation:=BattleAnimationDirector.play_key("ruby:general/7",context,true)
	await animation.esperar_finalizada()
	# A settled view cannot revoke native continuation. In particular, a view-only
	# cancel must not leave accepted PP/status with a reusable item. Native
	# retirement, holder/slot replacement and item revision still invalidate it.
	return valid(battle,accepted)

extends RefCounted
## Ruby case1 !moveTurn / ItemHealHP_End2. No consumption or Recycle write.
const Effects=preload("res://scripts/battle/held_item_effect_provider.gd")
const ItemTransaction=preload("res://scripts/battle/held_item_transaction.gd")
static func amount(current: int,maximum: int) -> int:
	if current<=0 or current>=maximum:return 0
	return mini(maximum-current,maxi(1,maximum/16))
static func end_round(battle: Node,lease: Dictionary) -> void:
	if not battle.field_rules.valid(lease):return
	var pokemon: BasePokemon=lease.pokemon
	var descriptor: Dictionary=battle.held_item_effects.resolve(battle,pokemon,lease)
	if int(descriptor.source_effect)!=Effects.LEFTOVERS:return
	var requested: int=amount(pokemon.estad_ps_actual,pokemon.estad_ps)
	if requested==0:return
	# Ruby captures negative gBattleMoveDamage before its item script. Parameter
	# is irrelevant here; original item identity and provider revision are not.
	var accepted: Dictionary=ItemTransaction.capture(battle,lease,battle.field_rules.capture_flow([pokemon]),descriptor)
	if not await ItemTransaction.present(battle,accepted):return
	if pokemon.estad_ps_actual<=0 or pokemon.estad_ps_actual>=pokemon.estad_ps:return
	await battle.mostrar_texto_batalla("¡%s restauró PS usando su %s!"%[pokemon.get_nombre_combate(),ObjetosLlevados.nombre_objeto(descriptor.item)])
	if not ItemTransaction.valid(battle,accepted) or pokemon.estad_ps_actual<=0 or pokemon.estad_ps_actual>=pokemon.estad_ps:return
	# Native HP authority precedes the awaited HUD tween, as for HP berries.
	# No post-HUD write: a later invalidation never rolls back accepted healing.
	await battle.habilidades._curar(pokemon,requested)

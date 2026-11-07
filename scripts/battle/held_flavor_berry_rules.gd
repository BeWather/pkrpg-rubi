extends RefCounted
## Ruby ItemBattleEffects case1 FALSE only; source script owns ordered mutation.
const Transaction=preload("res://scripts/battle/held_item_transaction.gd")
const Effects=preload("res://scripts/battle/held_item_effect_provider.gd")
const FLAVORS=["picante","seco","dulce","amargo","ácido"]
# pokeruby/src/pokeblock.c gPokeblockFlavorCompatibilityTable, personality%25.
const RELATIONS=[
	[0,0,0,0,0],[1,0,0,0,-1],[1,0,-1,0,0],[1,-1,0,0,0],[1,0,0,-1,0],
	[-1,0,0,0,1],[0,0,0,0,0],[0,0,-1,0,1],[0,-1,0,0,1],[0,0,0,-1,1],
	[-1,0,1,0,0],[0,0,1,0,-1],[0,0,0,0,0],[0,-1,1,0,0],[0,0,1,-1,0],
	[-1,1,0,0,0],[0,1,0,0,-1],[0,1,-1,0,0],[0,0,0,0,0],[0,1,0,-1,0],
	[-1,0,0,1,0],[0,0,0,1,-1],[0,0,-1,1,0],[0,-1,0,1,0],[0,0,0,0,0]]
static func _valid(battle: Node,accepted: Dictionary) -> bool:
	return Transaction.valid(battle,accepted) and accepted.pokemon.estad_ps_actual>0
static func _duration_draw(_bound: int,word: Callable) -> int:
	return (int(word.call()) if word.is_valid() else randi())%4
static func end_round(battle: Node,actor: BasePokemon,lease: Dictionary) -> void:
	if not battle.field_rules.valid(lease) or actor.estad_ps_actual<=0:return
	var descriptor: Dictionary=battle.held_item_effects.resolve(battle,actor,lease)
	var item: String=descriptor.item;var effect: int=int(descriptor.source_effect)
	if effect<Effects.CONFUSE_SPICY or effect>Effects.CONFUSE_SOUR or actor.estad_ps_actual>int(actor.estad_ps/2) or actor.estad_ps_actual>=actor.estad_ps:return
	var flavor: int=effect-Effects.CONFUSE_SPICY
	var amount: int=mini(maxi(1,int(actor.estad_ps/int(descriptor.parameter))),actor.estad_ps-actor.estad_ps_actual)
	var relation: int=int(RELATIONS[(actor.personalidad & 0xffffffff)%25][flavor])
	var accepted: Dictionary=Transaction.capture(battle,lease,battle.field_rules.capture_flow([actor]),descriptor)
	if not await Transaction.present(battle,accepted) or not _valid(battle,accepted):return
	await battle.mostrar_texto_batalla("¡%s restauró salud con %s!"%[actor.get_nombre_combate(),ObjetosLlevados.nombre_objeto(item)])
	if not _valid(battle,accepted):return
	# datahpupdate commits before its awaited native HUD; no later rollback.
	await battle.habilidades._curar(actor,amount)
	if not _valid(battle,accepted):return
	if relation<0:
		await battle.mostrar_texto_batalla("¡A %s no le gustó el sabor %s!"%[actor.get_nombre_combate(),FLAVORS[flavor]])
		if not _valid(battle,accepted):return
		var word: Callable=battle.get_meta("source_flavor_word",Callable())
		# Existing synchronous producer guards Own Tempo/no-stack BEFORE RNG.
		# Primary self-effect ignores Safeguard/Substitute, not Own Tempo.
		var actions: Array[AccionHabilidad]=EfectosGolpe.confundir(actor,lease.state.get_ref(),_duration_draw.bind(word),true)
		if not actions.is_empty():
			await battle.turno.presentar_fase_estado("ruby:status/1",actor)
			if not _valid(battle,accepted):return
			for action: AccionHabilidad in actions:
				await battle.mostrar_texto_batalla(action.texto)
				if not _valid(battle,accepted):return
	preload("res://scripts/battle/recycle_rules.gd").consume(battle,actor,lease)

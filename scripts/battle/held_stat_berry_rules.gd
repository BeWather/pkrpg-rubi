extends RefCounted
## Ruby case1 FALSE stages only intent; statbuffchange follows General7.
const Transaction=preload("res://scripts/battle/held_item_transaction.gd")
const StatAnimation=preload("res://scripts/battle/stat_animation_rules.gd")
# Source stat order differs from the native member/Herb list order.
const Effects=preload("res://scripts/battle/held_item_effect_provider.gd")
static func _valid(battle: Node,accepted: Dictionary) -> bool:
	return Transaction.valid(battle,accepted) and accepted.pokemon.estad_ps_actual>0
# Only the actual Starf candidate producer draws; invalid test seams fail closed.
static func _random_stat(battle: Node,state: PokemonEnCombate) -> int:
	var stats: Array[String]=StatAnimation.STATS.slice(0,5)
	var available: bool=false
	for stat: String in stats:
		if state.obtener_modificador(stat)<6:available=true;break
	if not available:return -1
	var word_source: Callable=battle.get_meta("source_starf_word",Callable())
	while true:
		var word: Variant=word_source.call() if word_source.is_valid() else randi()
		if not word is int:return -1
		var selected: int=(int(word)&65535)%5
		if state.obtener_modificador(stats[selected])<6:return selected
	return -1
static func end_round(battle: Node,actor: BasePokemon,lease: Dictionary) -> void:
	if not battle.field_rules.valid(lease) or actor.estad_ps_actual<=0:return
	var descriptor: Dictionary=battle.held_item_effects.resolve(battle,actor,lease)
	var item: String=descriptor.item;var source_effect: int=int(descriptor.source_effect)
	if source_effect<Effects.ATTACK_UP or source_effect>Effects.RANDOM_STAT_UP:return
	var state: PokemonEnCombate=lease.state.get_ref()
	if actor.estad_ps_actual>int(actor.estad_ps/int(descriptor.parameter)):return
	var accepted: Dictionary=Transaction.capture(battle,lease,battle.field_rules.capture_flow([actor]),descriptor)
	if not _valid(battle,accepted):return
	var effect: String="focus" if source_effect==Effects.CRITICAL_UP else ("random" if source_effect==Effects.RANDOM_STAT_UP else "stat");var stat: String="";var amount: int=1;var argument: int=-1
	if effect=="focus":
		if state.source_focus_energy:return
	elif effect=="random":
		var selected: int=_random_stat(battle,state)
		if selected<0:return
		stat=StatAnimation.STATS[selected];amount=2;argument=39+selected
	else:
		var selected: int=source_effect-Effects.ATTACK_UP
		stat=StatAnimation.STATS[selected];argument=15+selected
		if state.obtener_modificador(stat)>=6:return
	if not _valid(battle,accepted):return
	# Ruby accepts the shared Focus Energy bit in the producer, before its script.
	if effect=="focus":state.source_focus_energy=true
	if not await Transaction.present(battle,accepted) or not _valid(battle,accepted):return
	if effect!="focus":
		# The immutable selected stat still belongs to the original item/state.
		if state.obtener_modificador(stat)>=6:return
		state.cambiar_modificador(stat,amount)
		if not _valid(battle,accepted):return
		await StatAnimation.present(battle,actor,argument)
		if not _valid(battle,accepted):return
		await battle.mostrar_texto_batalla("¡%s de %s subió con %s!"%[CambioEstadisticaGen3.nombre_estadistica(stat),actor.get_nombre_combate(),ObjetosLlevados.nombre_objeto(item)])
	else:
		await battle.mostrar_texto_batalla("¡%s se está preparando para luchar!"%actor.get_nombre_combate())
	# Accepted mutations are irreversible; revised items/occupants never inherit removal.
	if not _valid(battle,accepted):return
	preload("res://scripts/battle/recycle_rules.gd").consume(battle,actor,lease)

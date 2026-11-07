extends RefCounted
## Ruby cases0/1/3 mutate accepted combat state before the item script.
const Transaction=preload("res://scripts/battle/held_item_transaction.gd")
const Effects=preload("res://scripts/battle/held_item_effect_provider.gd")
const STATS=["ataque","defensa","ataque_especial","defensa_especial","velocidad","precision","evasion"]
static func eligible(state: PokemonEnCombate,effect: int,source_case: int) -> bool:
	if state==null:return false
	if effect==Effects.CURE_ATTRACT:return source_case in [1,3] and state.esta_enamorado
	if effect!=Effects.RESTORE_STATS or source_case not in [0,1,3]:return false
	for stat: String in STATS:
		if state.obtener_modificador(stat)<0:return true
	return false
static func present(battle: Node,lease: Dictionary,source_case: int,flow: Dictionary) -> void:
	if not battle.field_rules.valid(lease) or not battle.field_rules.valid_flow(flow):return
	var mon: BasePokemon=lease.pokemon;var state: PokemonEnCombate=lease.state.get_ref()
	var descriptor: Dictionary=battle.held_item_effects.resolve(battle,mon,lease);var effect: int=int(descriptor.source_effect);var item: String=descriptor.item
	if source_case==1 and mon.estad_ps_actual<=0:return
	if not eligible(state,effect,source_case):return
	var accepted: Dictionary=Transaction.capture(battle,lease,flow,descriptor)
	if not Transaction.valid(battle,accepted):return
	if effect==Effects.RESTORE_STATS:
		for stat: String in STATS:
			var stage: int=state.obtener_modificador(stat)
			if stage<0:state.cambiar_modificador(stat,-stage)
	else:state.esta_enamorado=false;state.target_enamorado=null
	if not await Transaction.present(battle,accepted):return
	var message: String="¡%s de %s restauró sus características!" if effect==Effects.RESTORE_STATS else "¡%s de %s curó su enamoramiento!"
	await battle.mostrar_texto_batalla(message%[ObjetosLlevados.nombre_objeto(item),mon.get_nombre_combate()])
	if not Transaction.valid(battle,accepted):return
	if effect==Effects.CURE_ATTRACT:battle.hud._actualizar_estado_visual_pokemon(mon)
	preload("res://scripts/battle/recycle_rules.gd").consume(battle,mon,lease)
static func entry(battle: Node,accepted: Dictionary) -> void:
	if not Transaction.valid(battle,accepted):return
	# ItemBattleEffects case 0: sin comprobar el bando, como en Rubí; dura toda la batalla.
	if int(accepted.descriptor.source_effect)==Effects.DOUBLE_PRIZE:
		battle.resultado.multiplicador_dinero=2
		return
	await present(battle,accepted.lease,0,accepted.flow)

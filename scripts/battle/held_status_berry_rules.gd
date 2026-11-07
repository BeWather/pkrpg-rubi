extends RefCounted
## Ruby ItemBattleEffects cases1/3; combat cure precedes script, removal follows it.
const ItemTransaction=preload("res://scripts/battle/held_item_transaction.gd")
const Herbs=preload("res://scripts/battle/held_herb_rules.gd")
const Effects=preload("res://scripts/battle/held_item_effect_provider.gd")
const CONDITIONS={2:Singleton.ProblemaEstado.PARALIZADO,3:Singleton.ProblemaEstado.DORMIDO,4:Singleton.ProblemaEstado.ENVENENADO,5:Singleton.ProblemaEstado.QUEMADO,6:Singleton.ProblemaEstado.CONGELADO}
const LABELS={Singleton.ProblemaEstado.PARALIZADO:"se curó de la parálisis",Singleton.ProblemaEstado.DORMIDO:"se despertó",Singleton.ProblemaEstado.ENVENENADO:"se curó del envenenamiento",Singleton.ProblemaEstado.QUEMADO:"se curó las quemaduras",Singleton.ProblemaEstado.CONGELADO:"se descongeló"}
static func eligible(pokemon: BasePokemon,state: PokemonEnCombate,effect: int) -> bool:
	if pokemon==null or state==null or effect not in [2,3,4,5,6,8,9]:return false
	if effect==Effects.CURE_CONFUSION:return state.esta_confuso
	if effect==Effects.CURE_STATUS:return LABELS.has(pokemon.estado) or state.esta_confuso
	return pokemon.estado==int(CONDITIONS[effect])
static func admission(battle: Node) -> Dictionary:
	var records: Array[Dictionary]=[];var excluded: Array=[]
	var active: Array=[battle.poke_jugador,battle.poke_enemigo] if battle.formato_batalla==Singleton.FormatoBatalla.SIMPLE else battle.pokemones_activos_jugador+battle.pokemones_activos_enemigo
	for pokemon: BasePokemon in active:
		if pokemon==null:continue
		excluded.append(pokemon)
		var lease: Dictionary=battle.field_rules.capture(pokemon)
		if not lease.is_empty():records.append(lease)
	records.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return battle.field_rules.source_bank(a.bank)<battle.field_rules.source_bank(b.bank))
	return {"flow":battle.field_rules.capture_flow(excluded),"records":records}
static func settle(battle: Node,accepted: Dictionary) -> void:
	if accepted.is_empty():return
	for lease: Dictionary in accepted.records:
		if not battle.field_rules.valid_flow(accepted.flow):return
		if battle.field_rules.valid(lease):await present(battle,lease,3,accepted.flow)
static func round_pass(battle: Node,lease: Dictionary) -> void:
	if not battle.field_rules.valid(lease) or lease.pokemon.estad_ps_actual<=0:return
	var accepted: Dictionary=admission(battle)
	# Source false then true pass; status cures are eligible in either pass.
	await present(battle,lease,1,accepted.flow)
	if battle.field_rules.valid_flow(accepted.flow) and battle.field_rules.valid(lease):await present(battle,lease,1,accepted.flow)
static func present(battle: Node,lease: Dictionary,source_case: int,flow: Dictionary) -> void:
	if not battle.field_rules.valid(lease):return
	var pokemon: BasePokemon=lease.pokemon;var state: PokemonEnCombate=lease.state.get_ref()
	var descriptor: Dictionary=battle.held_item_effects.resolve(battle,pokemon,lease);var item: String=descriptor.item;var effect: int=int(descriptor.source_effect)
	if effect in [Effects.RESTORE_STATS,Effects.CURE_ATTRACT]:
		await Herbs.present(battle,lease,source_case,flow);return
	if not eligible(pokemon,state,effect):return
	var accepted: Dictionary=ItemTransaction.capture(battle,lease,flow,descriptor)
	if not ItemTransaction.valid(battle,accepted):return
	var old: int=pokemon.estado;var confused: bool=state.esta_confuso;var label: String="se libró de la confusión" if effect==Effects.CURE_CONFUSION else str(LABELS.get(old,"se libró de la confusión"))
	if effect==Effects.CURE_STATUS and confused:label="se libró de la confusión"
	var multiple: bool=effect==Effects.CURE_STATUS and source_case==1 and LABELS.has(old) and confused
	# Source status1/controller mutation before General7; Persim touches status2 only.
	if effect!=Effects.CURE_CONFUSION and LABELS.has(old):
		pokemon.estado=Singleton.ProblemaEstado.NORMAL
		if old==Singleton.ProblemaEstado.DORMIDO:state.turnos_dormido=0;state.source_nightmare=false
		if old==Singleton.ProblemaEstado.ENVENENADO:state.envenenamiento_grave=false;state.contador_veneno_grave=0
	if effect in [Effects.CURE_CONFUSION,Effects.CURE_STATUS]:state.esta_confuso=false;state.turnos_confuso=0
	if not await ItemTransaction.present(battle,accepted):return
	await battle.mostrar_texto_batalla(("¡%s de %s curó su problema de estado!"%[ObjetosLlevados.nombre_objeto(item),pokemon.get_nombre_combate()]) if multiple else ("¡%s %s con %s!"%[pokemon.get_nombre_combate(),label,ObjetosLlevados.nombre_objeto(item)]))
	if not ItemTransaction.valid(battle,accepted):return
	if effect!=Effects.CURE_CONFUSION:battle.hud._actualizar_estado_visual_pokemon(pokemon)
	preload("res://scripts/battle/recycle_rules.gd").consume(battle,pokemon,lease)

## HandleFaintedMonActions case6 is case1 TRUE on numeric bank0 only.
## Bind this to the result operation, never the expired move's continuation.
static func capture_tail(battle: Node,flow: Dictionary) -> Dictionary:
	var pokemon: BasePokemon=battle.field_rules.occupant({"player":true,"flank":0})
	if pokemon==null:return {"flow":flow,"absent":true}
	return ItemTransaction.capture(battle,battle.field_rules.capture(pokemon),flow)
static func settle_tail(battle: Node,accepted: Dictionary) -> bool:
	if accepted.is_empty():return false
	if accepted.get("absent",false):return battle.field_rules.valid_flow(accepted.flow) and battle.field_rules.occupant({"player":true,"flank":0})==null
	if not battle.field_rules.valid_flow(accepted.flow) or not battle.field_rules.valid(accepted.lease):return false
	# A replacement item is not the accepted item, but cannot revoke an
	# otherwise live result continuation. Never dispatch that new item.
	if ItemTransaction.valid(battle,accepted) and accepted.pokemon.estad_ps_actual>0:await present(battle,accepted.lease,1,accepted.flow)
	# Successful removal changes item revision; only native lifetime survives.
	return battle.field_rules.valid_flow(accepted.flow) and battle.field_rules.valid(accepted.lease)

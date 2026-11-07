extends RefCounted
## B_ANIM_STATS_CHANGE argument encodes source stat/direction/requested magnitude.
const STATS: Array[String]=["ataque","defensa","velocidad","ataque_especial","defensa_especial","precision","evasion"]
static func argument(changes: Array) -> int:
	if changes.is_empty():return -1
	var amount: int=int(changes[0][1]);var down: bool=amount<0;var large: bool=absi(amount)>=2
	if changes.size()>1:return (58 if large else 57) if down else (56 if large else 55)
	var stat: int=STATS.find(str(changes[0][0]))
	if stat<0:return -1
	return (46 if down else 39) + stat if large else (22 if down else 15) + stat
static func present(battle: Node,pokemon: BasePokemon,argument_id: int) -> void:
	var record: Dictionary=battle.field_rules.capture(pokemon)
	if record.is_empty() or not battle.field_rules.valid(record):return
	var definition: BattleAnimationDefinition=BattleAnimationSequenceRegistry.get_definition("ruby:general/1",true)
	if definition==null or definition.source_script!="General_StatsChange":return
	var legacy: MoveAnimationContext=MoveAnimationContext.nueva(battle,record.slot.get_ref(),record.slot.get_ref());var context: BattleAnimationContext=BattleAnimationContext.from_legacy(legacy);context.set_meta("source_general_argument",argument_id)
	var animation: BattleSequenceAnimation=BattleAnimationDirector.play_key("ruby:general/1",context,true) # §32: nativa si la política lo permite
	if animation.state=="running":await animation.finalizada

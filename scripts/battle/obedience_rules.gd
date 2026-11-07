extends RefCounted
## Ruby IsOtherTrainer (pokemon_3.c) and IsMonDisobedient (battle_util.c).
## Native RNG adapter: `roll` returns a Random()&255 word, not Ruby LCG parity.
const SNORE: int=173
const SLEEP_TALK: int=214
const STRUGGLE: int=165
const RAGE: int=99
const NO_LIMIT: int=-1
const IGNORED_ASLEEP: String="¡%s ignoró las\nórdenes porque está dormido!"
const IGNORED: String="¡%s ignoró\nlas órdenes!"
const NAP: String="¡%s se fue a dormir!"
const WONT_OBEY: String="¡%s no\nquiere obedecer!"
## BattleScript_DoSelfConfusionDmg prints BATTLE_TEXT_HurtItself before the hit.
const HURT_ITSELF: String="¡Está tan confuso\nque se hirió a si mismo!"
## gInobedientStringIds, in table order.
const LOAFING: Array[String]=["¡%s está\nholgazaneando!",WONT_OBEY,"¡%s se alejó!","¡%s fingió\nno darse cuenta!"]

## Ruby compares otId first, then otName. An OT or player without a name has no
## comparable identity (wild fixtures, uninitialized save): never "other trainer".
static func is_other_trainer(ot_name: String,ot_id: int,player_name: String,player_id: int) -> bool:
	var ot: String=ot_name.strip_edges().to_upper()
	var player: String=player_name.strip_edges().to_upper()
	if ot.is_empty() or player.is_empty():return false
	return ot_id!=player_id or ot!=player

static func traded(pokemon: BasePokemon) -> bool:
	if pokemon==null:return false
	return is_other_trainer(pokemon.entrenador_original,pokemon.entrenador_id,SistemaGuardado.get_nombre_jugador(),int(SistemaGuardado.datos_vivos.jugador.get("id",0)))

## FLAG_BADGE02/04/06/08_GET; the save stores those flags at indexes 1/3/5/7.
static func level_limit() -> int:
	if SistemaGuardado.tiene_medalla(7):return NO_LIMIT
	if SistemaGuardado.tiene_medalla(5):return 70
	if SistemaGuardado.tiene_medalla(3):return 50
	if SistemaGuardado.tiene_medalla(1):return 30
	return 10

## Pure branch selection. `can_nap` is read only where Ruby reads status/ability/uproar.
## Result: {kind: obey|asleep|random|nap|hit|loaf}; loaf also carries `text`.
static func decide(level: int,limit: int,asleep_snoring: bool,can_nap: Callable,roll: Callable) -> Dictionary:
	if limit==NO_LIMIT or level<=limit:return {"kind":"obey"}
	if ((level+limit)*int(roll.call()))>>8<limit:return {"kind":"obey"}
	if asleep_snoring:return {"kind":"asleep"}
	if ((level+limit)*int(roll.call()))>>8<limit:return {"kind":"random"}
	var difference: int=level-limit
	var calc: int=int(roll.call())
	if calc<difference and bool(can_nap.call()):return {"kind":"nap"}
	# Signed in Ruby: a blocked nap leaves calc negative, so it always self-hits.
	calc-=difference
	if calc<difference:return {"kind":"hit"}
	return loaf(roll)

static func loaf(roll: Callable) -> Dictionary:
	return {"kind":"loaf","text":LOAFING[int(roll.call())&3]}

## CheckMoveLimitations(attacker, current slot, 0xFF) + the Random()&3 retry loop.
## -1 means every slot is unusable (Ruby loafs around instead).
static func random_slot(allowed: Array[int],current: int,roll: Callable) -> int:
	var usable: Array[int]=allowed.filter(func(slot: int)->bool:return slot!=current)
	if usable.is_empty():return -1
	while true:
		var slot: int=int(roll.call())&3
		if usable.has(slot):return slot
	return -1

static func move_id(move: Movimiento) -> int:
	return int(move.datos.get("numero_movimiento",0)) if move!=null else 0

## Ruby gChosenMove stays the ordered move; gCurrentMove becomes the random one.
static func bind_random_phase(phase: Dictionary,chosen: Movimiento,random: Movimiento) -> void:
	var ticket: Dictionary=phase.get("source_result_ticket",{})
	if not ticket.is_empty():
		ticket.selected_id=move_id(chosen);ticket.chosen_effect=chosen.get_efecto()
	phase.source_magic_coat_current_id=move_id(random)

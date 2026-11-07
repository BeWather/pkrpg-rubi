extends RefCounted
class_name BattleFieldEffects
## Generation3 bank-bound seed and side-bound spikes. Presentation never owns HP.
var _owner: WeakRef
var spikes: Array[int]=[0,0]
var _entries: Dictionary={}
var _lifetime: int=0

func _init(owner: Node) -> void:_owner=weakref(owner)
func owner() -> Node:return _owner.get_ref()
func live() -> bool:
	var battle: Node=owner()
	return is_instance_valid(battle) and battle.is_inside_tree() and battle.fase!=battle.FIN_BATALLA
func position(pokemon: BasePokemon) -> Dictionary:return owner().turno._posicion_pokemon(pokemon)
func occupant(bank: Dictionary) -> BasePokemon:
	var battle: Node=owner()
	if battle.formato_batalla==Singleton.FormatoBatalla.SIMPLE:return battle.poke_jugador if bool(bank.player) else battle.poke_enemigo
	var side: Array= battle.pokemones_activos_jugador if bool(bank.player) else battle.pokemones_activos_enemigo
	var flank: int=int(bank.flank)
	return side[flank] if flank>=0 and flank<side.size() else null
func capture(pokemon: BasePokemon) -> Dictionary:
	if not live() or pokemon==null:return {}
	var state: PokemonEnCombate=owner()._obtener_combatiente(pokemon)
	var slot: BattleSlot=owner().hud._obtener_slot_de_pokemon(pokemon)
	if state==null or not is_instance_valid(slot):return {}
	return {"pokemon":pokemon,"state":weakref(state),"epoch":state.body_attack_epoch,"bank":position(pokemon),"slot":weakref(slot),"generation":slot.animation_generation}
func valid(record: Dictionary) -> bool:
	if record.is_empty() or not live():return false
	var state: PokemonEnCombate=record.state.get_ref()
	var slot: BattleSlot=record.slot.get_ref()
	return state!=null and is_instance_valid(slot) and occupant(record.bank)==record.pokemon and owner()._obtener_combatiente(record.pokemon)==state and state.body_attack_epoch==int(record.epoch) and owner().hud._obtener_slot_de_pokemon(record.pokemon)==slot and slot.animation_generation==int(record.generation)
## Control continuation is separate from an occupant that this operation owns
## replacing. FIN/exit is irreversible even if the same scene reenters RONDA.
func capture_flow(excluded: Array=[]) -> Dictionary:
	if not live():return {}
	var battle: Node=owner()
	var records: Array[Dictionary]=[]
	var active: Array=[battle.poke_jugador,battle.poke_enemigo] if battle.formato_batalla==Singleton.FormatoBatalla.SIMPLE else battle.pokemones_activos_jugador+battle.pokemones_activos_enemigo
	for pokemon: BasePokemon in active:
		if pokemon!=null and not excluded.has(pokemon):
			var record: Dictionary=capture(pokemon)
			if record.is_empty():return {}
			records.append(record)
	return {"lifetime":_lifetime,"round":battle.contador_turnos,"records":records}
func valid_flow(flow: Dictionary) -> bool:
	if flow.is_empty() or not live() or int(flow.lifetime)!=_lifetime or int(flow.round)!=owner().contador_turnos:return false
	for record: Dictionary in flow.records:
		if not valid(record):return false
	return true
func seed(actor: BasePokemon,target: BasePokemon) -> bool:
	var state: PokemonEnCombate=owner()._obtener_combatiente(target)
	if state==null or state.substitute_hp>0 or not state.leech_seed_position.is_empty() or "PLANTA" in BattleTransformRules.types(target):return false
	state.leech_seed_position=position(actor).duplicate(true)
	return true
func add_spikes(actor: BasePokemon) -> bool:
	var side: int=1 if bool(position(actor).player) else 0
	if spikes[side]>=3:return false
	spikes[side]+=1;return true
func pressure(actor: BasePokemon) -> int:
	var side: int=1 if bool(position(actor).player) else 0
	if spikes[side]>=3:return 0 # atkB0 sets ppNotAffectedByPressure before ppreduce.
	var extra: int=0
	for pokemon: BasePokemon in owner().habilidades.crear_campo().todos():
		if pokemon!=null and bool(position(pokemon).player)!=bool(position(actor).player) and HabilidadesCombate.tiene(pokemon,HabilidadesCombate.PRESION):extra+=1
	return extra
func clear_user(record: Dictionary) -> void:
	if not valid(record):return
	var state: PokemonEnCombate=record.state.get_ref()
	state.esta_atrapado=false;state.turnos_atrapado=0
	state.leech_seed_position.clear()
	spikes[0 if bool(record.bank.player) else 1]=0
func retire(state: PokemonEnCombate) -> void:
	if state!=null:state.leech_seed_position.clear()
func clear() -> void:
	_lifetime+=1
	spikes.assign([0,0]);_entries.clear()
	var battle: Node=owner()
	if not is_instance_valid(battle):return
	for state: Variant in battle.combatientes_activos.values():
		if state is PokemonEnCombate:retire(state)
	retire(battle.combatiente_jugador);retire(battle.combatiente_enemigo)
func passive_hp(record: Dictionary,damage: int) -> int:
	if not valid(record):return 0
	var pokemon: BasePokemon=record.pokemon
	var before: int=pokemon.estad_ps_actual
	pokemon.estad_ps_actual=clampi(before-damage,0,pokemon.estad_ps)
	var dealt: int=before-pokemon.estad_ps_actual
	if pokemon.estad_ps_actual==0:
		owner()._retirar_sustituto_de_pokemon(pokemon)
		# This accepted KO owns retirement; subsequent external retirement remains invalid.
		record.epoch=record.state.get_ref().body_attack_epoch
	if dealt!=0:
		await owner().hud.animar_dano(owner().hud._obtener_cuadro_ps_de_pokemon(pokemon),pokemon.estad_ps,pokemon.estad_ps_actual)
	return dealt
func enter(pokemon: BasePokemon,record: Dictionary={}) -> bool:
	if record.is_empty():record=capture(pokemon)
	if not valid(record) or pokemon.estad_ps_actual<=0:return false
	var key: String="%s:%s:%s"%[record.state.get_ref().get_instance_id(),record.slot.get_ref().get_instance_id(),record.generation]
	if _entries.has(key):return valid(record)
	_entries[key]=true
	var layers: int=spikes[0 if bool(record.bank.player) else 1]
	if layers==0 or "VOLADOR" in BattleTransformRules.types(pokemon) or HabilidadesCombate.tiene(pokemon,HabilidadesCombate.LEVITACION):return true
	await passive_hp(record,maxi(1,pokemon.estad_ps/((5-layers)*2)))
	if valid(record):await owner().mostrar_texto_batalla("¡%s sufrió daño por púas!"%pokemon.get_nombre_combate())
	return valid(record)
func source_bank(bank: Dictionary) -> int:
	if bool(bank.player):return BattleAnimationContext.SourcePosition.PLAYER_LEFT if int(bank.flank)==0 else BattleAnimationContext.SourcePosition.PLAYER_RIGHT
	return BattleAnimationContext.SourcePosition.OPPONENT_LEFT if int(bank.flank)==0 else BattleAnimationContext.SourcePosition.OPPONENT_RIGHT
func present_drain(victim: Dictionary,receiver: Dictionary) -> void:
	# An unavailable qualified port is not permission to play a generic alias.
	# Candidate tests can register actual source definitions through the public
	# customization API; persistent auxiliary coverage changes only after review.
	var definition: BattleAnimationDefinition=BattleAnimationSequenceRegistry.get_definition("ruby:general/14",true)
	if definition.source_script!="General_LeechSeedDrain" or not valid(victim) or not valid(receiver):return
	var legacy: MoveAnimationContext=MoveAnimationContext.nueva(owner(),receiver.slot.get_ref(),victim.slot.get_ref())
	var context: BattleAnimationContext=BattleAnimationContext.from_legacy(legacy)
	context.set_meta("source_general_argument",source_bank(receiver.bank)|(source_bank(victim.bank)<<8))
	var animation: BattleSequenceAnimation=BattleAnimationDirector.play_key("ruby:general/14",context,true) # §32: nativa si la política lo permite
	if animation.state=="running":await animation.finalizada
func drain(pokemon: BasePokemon) -> void:
	var victim: Dictionary=capture(pokemon)
	if victim.is_empty() or pokemon.estad_ps_actual<=0:return
	var state: PokemonEnCombate=victim.state.get_ref()
	if state.leech_seed_position.is_empty():return
	var receiver: BasePokemon=occupant(state.leech_seed_position)
	if receiver==null or receiver.estad_ps_actual<=0:return
	var receiving: Dictionary=capture(receiver)
	var ooze: bool=HabilidadesCombate.tiene(pokemon,HabilidadesCombate.LODOLIQUIDO)
	var requested: int=maxi(1,pokemon.estad_ps/8) # Source computes before its animation command.
	await present_drain(victim,receiving)
	if not valid(victim) or not valid(receiving):return
	var dealt: int=await passive_hp(victim,requested)
	if dealt<=0 or not valid(victim) or not valid(receiving):return
	await passive_hp(receiving,dealt if ooze else -dealt)
	if valid(receiving):await owner().mostrar_texto_batalla("¡Drenadoras absorbió energía!")

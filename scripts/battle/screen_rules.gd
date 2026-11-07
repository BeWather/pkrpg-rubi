extends RefCounted
class_name BattleScreenRules
## Ruby side authority: persistent screens, immutable accepted phase guards.
const CurseNightmare=preload("res://scripts/battle/curse_nightmare_rules.gd")
const Imprison=preload("res://scripts/battle/imprison_rules.gd")
const SkillSwap=preload("res://scripts/battle/skill_swap_rules.gd")
const Trick=preload("res://scripts/battle/trick_rules.gd")
const Startle=preload("res://scripts/battle/startle_rules.gd")
const LovelyKiss=preload("res://scripts/battle/lovely_kiss_rules.gd")
const KissAttract=preload("res://scripts/battle/kiss_attract_rules.gd")
const TearsTickle=preload("res://scripts/battle/tears_tickle_rules.gd")
const Heart=preload("res://scripts/battle/heart_rules.gd")
const FireBlast=preload("res://scripts/battle/fire_blast_rules.gd")
const Sludge=preload("res://scripts/battle/sludge_rules.gd")
const Acid=preload("res://scripts/battle/acid_rules.gd")
const Aurora=preload("res://scripts/battle/aurora_rules.gd")
const Flash=preload("res://scripts/battle/flash_rules.gd")
const PoisonGas=preload("res://scripts/battle/poison_gas_rules.gd")
const ElementalPunch=preload("res://scripts/battle/elemental_punch_rules.gd")
const EFFECTS=["EFFECT_REFLECT","EFFECT_LIGHT_SCREEN","EFFECT_MIST"]
var _owner: WeakRef
var timers: Array[Dictionary]=[{},{}]
var _last_round: int=-1
func _init(owner: Node) -> void:_owner=weakref(owner)
func owner() -> Node:return _owner.get_ref()
func side(actor: BasePokemon) -> int:return 0 if bool(owner().field_rules.position(actor).player) else 1
func remaining(bank_side: int,effect: String) -> int:return int(timers[bank_side].get(effect,0))
func produce(actor: BasePokemon,effect: String) -> bool:
	if effect not in EFFECTS or not owner().field_rules.live():return false
	var index: int=side(actor)
	if remaining(index,effect)>0:return false
	timers[index][effect]=5;return true
func remove_opposite(actor: BasePokemon) -> int:
	var index: int=side(actor)^1
	var present: bool=remaining(index,EFFECTS[0])>0 or remaining(index,EFFECTS[1])>0
	for effect: String in ["EFFECT_REFLECT","EFFECT_LIGHT_SCREEN"]:timers[index][effect]=0
	return 1 if present else 0
func snapshot() -> Array[Dictionary]:return timers.duplicate(true)
func clear() -> void:
	timers.assign([{},{}]);_last_round=-1
func end_round() -> bool:
	var battle: Node=owner();var flow: Dictionary=battle.field_rules.capture_flow()
	if not battle.field_rules.valid_flow(flow):return false
	if _last_round==int(battle.contador_turnos):return true
	_last_round=int(battle.contador_turnos)
	# DoFieldEndTurnEffects: Reflect, LightScreen, then Mist; both sides in each case.
	for effect: String in EFFECTS:
		for index: int in [0,1]:
			var value: int=remaining(index,effect)
			if value<=0:continue
			timers[index][effect]=value-1
			if value==1:
				await battle.mostrar_texto_batalla("El efecto de %s terminó."%("Reflejo" if effect=="EFFECT_REFLECT" else "Neblina" if effect=="EFFECT_MIST" else "Pantalla Luz"))
				if not battle.field_rules.valid_flow(flow):return false
	return true
static func phase_supported(move: Movimiento) -> bool:
	if preload("res://scripts/battle/fixed_damage_rules.gd").supports(move) or preload("res://scripts/battle/doom_desire_rules.gd").supports(move):return true
	if preload("res://scripts/battle/rage_rules.gd").supports(move):return true
	if preload("res://scripts/battle/hidden_power_rules.gd").supports(move):return true
	if preload("res://scripts/battle/variable_power_rules.gd").supports(move):return true
	if preload("res://scripts/battle/retaliation_rules.gd").supports(move):return true
	if preload("res://scripts/battle/grudge_rules.gd").supports(move):return true
	if preload("res://scripts/battle/magic_coat_rules.gd").supports(move) or preload("res://scripts/battle/magic_coat_rules.gd").eligible(move):return true
	if preload("res://scripts/battle/recycle_rules.gd").supports(move):return true
	if preload("res://scripts/battle/role_play_rules.gd").supports(move):return true
	if preload("res://scripts/battle/charge_rules.gd").supports(move):return true
	if preload("res://scripts/battle/nature_power_rules.gd").supports(move):return true
	if preload("res://scripts/battle/destiny_bond_rules.gd").supports(move):return true
	if preload("res://scripts/battle/spite_rules.gd").supports(move):return true
	if preload("res://scripts/battle/conversion_rules.gd").supports(move):return true
	if preload("res://scripts/battle/mimic_rules.gd").supports(move):return true
	if preload("res://scripts/battle/teleport_rules.gd").supports(move):return true
	if preload("res://scripts/battle/mist_rules.gd").supports(move):return true
	if preload("res://scripts/battle/psych_up_rules.gd").supports(move):return true
	if preload("res://scripts/battle/refresh_rules.gd").supports(move):return true
	if preload("res://scripts/battle/perish_song_rules.gd").supports(move):return true
	if preload("res://scripts/battle/focus_energy_rules.gd").supports(move):return true
	if preload("res://scripts/battle/focus_punch_rules.gd").supports(move):return true
	if preload("res://scripts/battle/snatch_rules.gd").supports(move):return true
	if preload("res://scripts/battle/turn_trap_rules.gd").supports(move):return true
	if preload("res://scripts/battle/helping_hand_rules.gd").supports(move):return true
	if preload("res://scripts/battle/mirror_move_rules.gd").supports(move):return true
	if preload("res://scripts/battle/pound_tackle_rules.gd").supports(move):return true
	if preload("res://scripts/battle/sketch_rules.gd").supports(move):return true
	if preload("res://scripts/battle/assist_rules.gd").supports(move):return true
	if preload("res://scripts/battle/sleep_talk_rules.gd").supports(move):return true
	if preload("res://scripts/battle/pay_day_rules.gd").supports(move):return true
	if preload("res://scripts/battle/memento_rules.gd").supports(move):return true
	if preload("res://scripts/battle/superpower_rules.gd").supports(move):return true
	if preload("res://scripts/battle/extreme_speed_rules.gd").supports(move):return true
	if preload("res://scripts/battle/extrasensory_rules.gd").supports(move):return true
	if preload("res://scripts/battle/camouflage_rules.gd").supports(move):return true
	if preload("res://scripts/battle/weather_ball_rules.gd").supports(move):return true
	if preload("res://scripts/battle/uproar_rules.gd").supports(move):return true
	if preload("res://scripts/battle/whirlwind_rules.gd").supports(move):return true
	if preload("res://scripts/battle/present_rules.gd").supports(move):return true
	if preload("res://scripts/battle/magnitude_rules.gd").supports(move):return true
	if preload("res://scripts/battle/hp_burst_rules.gd").supports(move):return true
	if preload("res://scripts/battle/faint_attack_rules.gd").supports(move):return true
	if preload("res://scripts/battle/seismic_toss_rules.gd").supports(move):return true
	if preload("res://scripts/battle/recharge_rules.gd").supports(move):return true
	if preload("res://scripts/battle/guillotine_rules.gd").supports(move):return true
	if preload("res://scripts/battle/fissure_rules.gd").supports(move):return true
	if preload("res://scripts/battle/bonemerang_rules.gd").supports(move):return true
	if preload("res://scripts/battle/yawn_rules.gd").supports(move):return true
	if preload("res://scripts/battle/smelling_salt_rules.gd").supports(move):return true
	if preload("res://scripts/battle/pain_split_rules.gd").supports(move):return true
	if preload("res://scripts/battle/party_status_rules.gd").supports(move):return true
	if preload("res://scripts/battle/flatter_rules.gd").supports(move):return true
	if preload("res://scripts/battle/torment_rules.gd").supports(move):return true
	if preload("res://scripts/battle/encore_rules.gd").supports(move):return true
	if preload("res://scripts/battle/celestial_heal_rules.gd").supports(move):return true
	if preload("res://scripts/battle/self_heal_rules.gd").supports(move):return true
	if preload("res://scripts/battle/kinesis_rules.gd").supports(move):return true
	if preload("res://scripts/battle/disable_rules.gd").supports(move):return true
	if preload("res://scripts/battle/smokescreen_rules.gd").supports(move):return true
	if preload("res://scripts/battle/spikes_rules.gd").supports(move):return true
	if preload("res://scripts/battle/barrage_rules.gd").supports(move) or preload("res://scripts/battle/rock_tomb_rules.gd").supports(move) or preload("res://scripts/battle/flame_wheel_rules.gd").supports(move) or preload("res://scripts/battle/baton_pass_rules.gd").supports(move) or preload("res://scripts/battle/overheat_rules.gd").supports(move) or preload("res://scripts/battle/outrage_rules.gd").supports(move) or preload("res://scripts/battle/psycho_boost_rules.gd").supports(move) or preload("res://scripts/battle/tail_glow_rules.gd").supports(move) or preload("res://scripts/battle/luster_purge_rules.gd").supports(move) or preload("res://scripts/battle/mist_ball_rules.gd").supports(move) or preload("res://scripts/battle/haze_rules.gd").supports(move) or preload("res://scripts/battle/teeter_dance_rules.gd").supports(move) or preload("res://scripts/battle/belly_drum_rules.gd").supports(move) or preload("res://scripts/battle/cosmic_power_rules.gd").supports(move) or preload("res://scripts/battle/dragon_dance_rules.gd").supports(move) or BattleHeldItemRules.supports(move) or BattleHealingStreamRules.supports(move) or BattleDustWeatherRules.supports(move) or preload("res://scripts/battle/thought_finger_rules.gd").supports(move) or preload("res://scripts/battle/ice_rules.gd").supports(move) or CurseNightmare.supports(move) or Imprison.supports(move) or SkillSwap.supports(move) or Trick.supports(move) or Startle.supports(move) or LovelyKiss.supports(move) or KissAttract.supports(move) or TearsTickle.supports(move) or Heart.supports(move) or BattleIdentifiedRules.supports(move) or BattleSureHitRules.supports(move) or FireBlast.supports(move) or Sludge.supports(move) or Acid.supports(move) or Aurora.supports(move) or BattleSportRules.supports(move) or Flash.supports(move) or PoisonGas.supports(move) or ElementalPunch.supports(move) or BattleHiddenActorRules.supports(move) or BattleSafeguardRules.supports(move):return true
	return move!=null and (not BattleProtectRules.mode(move).is_empty() or BattleWindAirRules.supports(move) or BattleWindFeatherRules.supports(move) or move.get_efecto() in EFFECTS or move.get_efecto()=="EFFECT_SONICBOOM" or (move.get_efecto() in ["EFFECT_SKULL_BASH","EFFECT_BRICK_BREAK","EFFECT_MULTI_HIT"] and move.get_nombre_interno() in ["SKULL_BASH","CABEZAZO","BRICK_BREAK","DEMOLICION","ARM_THRUST","EMPUJON"]))
static func capture_phase(battle: Node,actor: BasePokemon,move: Movimiento) -> Dictionary:
	var pending: PendingMoveContinuation=battle.turno._pendiente(actor)
	var hidden: BattleHiddenActorRules=pending.source_i4 if pending!=null else null
	if hidden==null and not phase_supported(move):return {}
	var phase: Dictionary={"source_screen_phase":true,"owner":weakref(battle),"flow":battle.field_rules.capture_flow(),"actor":battle.field_rules.capture(actor)}
	if preload("res://scripts/battle/fixed_damage_rules.gd").supports(move):phase.source_fixed_damage=preload("res://scripts/battle/fixed_damage_rules.gd").capture(move)
	if preload("res://scripts/battle/doom_desire_rules.gd").supports(move):phase.source_doom_desire=preload("res://scripts/battle/doom_desire_rules.gd").capture(move)
	if preload("res://scripts/battle/magic_coat_rules.gd").supports(move) or preload("res://scripts/battle/magic_coat_rules.gd").eligible(move):phase.source_magic_coat_policy=preload("res://scripts/battle/magic_coat_rules.gd").capture(move)
	if preload("res://scripts/battle/helping_hand_rules.gd").supports(move):phase.source_helping_hand=preload("res://scripts/battle/helping_hand_rules.gd").capture(move)
	if preload("res://scripts/battle/teleport_rules.gd").supports(move):phase.source_teleport=preload("res://scripts/battle/teleport_rules.gd").capture(move)
	if preload("res://scripts/battle/mist_rules.gd").supports(move):phase.source_mist=preload("res://scripts/battle/mist_rules.gd").capture(move)
	if preload("res://scripts/battle/psych_up_rules.gd").supports(move):phase.source_psych_up=preload("res://scripts/battle/psych_up_rules.gd").capture(move)
	if preload("res://scripts/battle/refresh_rules.gd").supports(move):phase.source_refresh_move=preload("res://scripts/battle/refresh_rules.gd").capture(move)
	if preload("res://scripts/battle/perish_song_rules.gd").supports(move):phase.source_perish_song=preload("res://scripts/battle/perish_song_rules.gd").capture(move)
	if preload("res://scripts/battle/focus_energy_rules.gd").supports(move):phase.source_focus_energy=preload("res://scripts/battle/focus_energy_rules.gd").capture(move)
	if preload("res://scripts/battle/focus_punch_rules.gd").supports(move):phase.source_focus_punch=preload("res://scripts/battle/focus_punch_rules.gd").capture(move)
	if preload("res://scripts/battle/snatch_rules.gd").supports(move):phase.source_snatch=preload("res://scripts/battle/snatch_rules.gd").capture(move)
	if preload("res://scripts/battle/turn_trap_rules.gd").supports(move):phase.source_turn_trap=preload("res://scripts/battle/turn_trap_rules.gd").capture(move)
	if hidden!=null:phase.source_i4=hidden
	elif BattleHiddenActorRules.supports(move):phase.source_i4=BattleHiddenActorRules.capture(battle,actor,move)
	if preload("res://scripts/battle/mirror_move_rules.gd").supports(move):phase.source_mirror_move=preload("res://scripts/battle/mirror_move_rules.gd").capture(move)
	if preload("res://scripts/battle/pound_tackle_rules.gd").supports(move):phase.source_pound_tackle=preload("res://scripts/battle/pound_tackle_rules.gd").capture(move)
	if preload("res://scripts/battle/mimic_rules.gd").supports(move):phase.source_mimic=preload("res://scripts/battle/mimic_rules.gd").capture(move)
	if preload("res://scripts/battle/sketch_rules.gd").supports(move):phase.source_sketch=preload("res://scripts/battle/sketch_rules.gd").capture(move)
	if preload("res://scripts/battle/assist_rules.gd").supports(move):phase.source_assist=preload("res://scripts/battle/assist_rules.gd").capture(move)
	if preload("res://scripts/battle/nature_power_rules.gd").supports(move):phase.source_nature_power=preload("res://scripts/battle/nature_power_rules.gd").capture(battle,move)
	if preload("res://scripts/battle/sleep_talk_rules.gd").supports(move):phase.source_sleep_talk=preload("res://scripts/battle/sleep_talk_rules.gd").capture(move)
	if preload("res://scripts/battle/pay_day_rules.gd").supports(move):phase.source_pay_day=preload("res://scripts/battle/pay_day_rules.gd").capture(move)
	if preload("res://scripts/battle/dragon_dance_rules.gd").supports(move):phase.source_dragon_dance=preload("res://scripts/battle/dragon_dance_rules.gd").capture(move)
	if preload("res://scripts/battle/memento_rules.gd").supports(move):phase.source_memento=preload("res://scripts/battle/memento_rules.gd").capture(move)
	if preload("res://scripts/battle/superpower_rules.gd").supports(move):phase.source_superpower=preload("res://scripts/battle/superpower_rules.gd").capture(move)
	if preload("res://scripts/battle/extreme_speed_rules.gd").supports(move):phase.source_extreme_speed=preload("res://scripts/battle/extreme_speed_rules.gd").capture(move)
	if preload("res://scripts/battle/extrasensory_rules.gd").supports(move):phase.source_extrasensory=preload("res://scripts/battle/extrasensory_rules.gd").capture(move)
	if preload("res://scripts/battle/grudge_rules.gd").supports(move):phase.source_grudge=preload("res://scripts/battle/grudge_rules.gd").capture(move)
	if preload("res://scripts/battle/destiny_bond_rules.gd").supports(move):phase.source_destiny_bond=preload("res://scripts/battle/destiny_bond_rules.gd").capture(move)
	if preload("res://scripts/battle/recycle_rules.gd").supports(move):phase.source_recycle=preload("res://scripts/battle/recycle_rules.gd").capture(move)
	if preload("res://scripts/battle/role_play_rules.gd").supports(move):phase.source_role_play=preload("res://scripts/battle/role_play_rules.gd").capture(move)
	if preload("res://scripts/battle/charge_rules.gd").supports(move):phase.source_charge=preload("res://scripts/battle/charge_rules.gd").capture(move)
	if preload("res://scripts/battle/spite_rules.gd").supports(move):phase.source_spite=preload("res://scripts/battle/spite_rules.gd").capture(move)
	if preload("res://scripts/battle/conversion_rules.gd").supports(move):phase.source_conversion=preload("res://scripts/battle/conversion_rules.gd").capture(move)
	if preload("res://scripts/battle/camouflage_rules.gd").supports(move):phase.source_camouflage=preload("res://scripts/battle/camouflage_rules.gd").capture(move)
	if preload("res://scripts/battle/rage_rules.gd").supports(move):phase.source_rage=preload("res://scripts/battle/rage_rules.gd").capture(move)
	if preload("res://scripts/battle/hidden_power_rules.gd").supports(move):phase.source_hidden_power=preload("res://scripts/battle/hidden_power_rules.gd").capture(move,actor)
	if preload("res://scripts/battle/weather_ball_rules.gd").supports(move):phase.source_weather_ball=preload("res://scripts/battle/weather_ball_rules.gd").capture(move,battle.habilidades.crear_campo())
	if preload("res://scripts/battle/uproar_rules.gd").supports(move):phase.source_uproar=preload("res://scripts/battle/uproar_rules.gd").capture(move)
	if preload("res://scripts/battle/whirlwind_rules.gd").supports(move):phase.source_whirlwind=preload("res://scripts/battle/whirlwind_rules.gd").capture(move,actor,battle)
	if preload("res://scripts/battle/present_rules.gd").supports(move):phase.source_present=preload("res://scripts/battle/present_rules.gd").capture(move)
	if preload("res://scripts/battle/magnitude_rules.gd").supports(move):phase.source_magnitude=preload("res://scripts/battle/magnitude_rules.gd").capture(move)
	if preload("res://scripts/battle/hp_burst_rules.gd").supports(move):phase.source_hp_burst=preload("res://scripts/battle/hp_burst_rules.gd").capture(move)
	if preload("res://scripts/battle/variable_power_rules.gd").supports(move):phase.source_variable_power=preload("res://scripts/battle/variable_power_rules.gd").capture(move)
	if preload("res://scripts/battle/faint_attack_rules.gd").supports(move):phase.source_faint_attack=preload("res://scripts/battle/faint_attack_rules.gd").capture(move)
	if preload("res://scripts/battle/retaliation_rules.gd").supports(move):phase.source_retaliation=preload("res://scripts/battle/retaliation_rules.gd").capture(move)
	if preload("res://scripts/battle/seismic_toss_rules.gd").supports(move):phase.source_seismic_toss=preload("res://scripts/battle/seismic_toss_rules.gd").capture(move)
	if preload("res://scripts/battle/recharge_rules.gd").supports(move):phase.source_recharge=preload("res://scripts/battle/recharge_rules.gd").capture(move)
	if preload("res://scripts/battle/guillotine_rules.gd").supports(move):phase.source_guillotine=preload("res://scripts/battle/guillotine_rules.gd").capture(move)
	if preload("res://scripts/battle/fissure_rules.gd").supports(move):phase.source_fissure=preload("res://scripts/battle/fissure_rules.gd").capture(move)
	if preload("res://scripts/battle/bonemerang_rules.gd").supports(move):phase.source_bonemerang=preload("res://scripts/battle/bonemerang_rules.gd").capture(move)
	if preload("res://scripts/battle/yawn_rules.gd").supports(move):phase.source_yawn=preload("res://scripts/battle/yawn_rules.gd").capture(move)
	if preload("res://scripts/battle/smelling_salt_rules.gd").supports(move):phase.source_smelling_salt=preload("res://scripts/battle/smelling_salt_rules.gd").capture(move)
	if preload("res://scripts/battle/pain_split_rules.gd").supports(move):phase.source_pain_split=preload("res://scripts/battle/pain_split_rules.gd").capture(move)
	if preload("res://scripts/battle/party_status_rules.gd").supports(move):phase.source_party_cure=preload("res://scripts/battle/party_status_rules.gd").capture(move)
	if preload("res://scripts/battle/flatter_rules.gd").supports(move):phase.source_flatter=preload("res://scripts/battle/flatter_rules.gd").capture(move)
	if preload("res://scripts/battle/torment_rules.gd").supports(move):phase.source_torment=preload("res://scripts/battle/torment_rules.gd").capture(move)
	if preload("res://scripts/battle/encore_rules.gd").supports(move):phase.source_encore=preload("res://scripts/battle/encore_rules.gd").capture(move)
	if preload("res://scripts/battle/celestial_heal_rules.gd").supports(move):phase.source_celestial_heal=preload("res://scripts/battle/celestial_heal_rules.gd").capture(move)
	if preload("res://scripts/battle/self_heal_rules.gd").supports(move):phase.source_self_heal=preload("res://scripts/battle/self_heal_rules.gd").capture(move)
	if preload("res://scripts/battle/kinesis_rules.gd").supports(move):phase.source_kinesis=preload("res://scripts/battle/kinesis_rules.gd").capture(move)
	if preload("res://scripts/battle/disable_rules.gd").supports(move):phase.source_disable=preload("res://scripts/battle/disable_rules.gd").capture(move)
	if preload("res://scripts/battle/smokescreen_rules.gd").supports(move):phase.source_smokescreen=preload("res://scripts/battle/smokescreen_rules.gd").capture(move)
	if preload("res://scripts/battle/spikes_rules.gd").supports(move):phase.source_spikes=preload("res://scripts/battle/spikes_rules.gd").capture(move)
	if preload("res://scripts/battle/barrage_rules.gd").supports(move):phase.source_barrage=preload("res://scripts/battle/barrage_rules.gd").capture(move)
	if preload("res://scripts/battle/rock_tomb_rules.gd").supports(move):phase.source_rock_tomb=preload("res://scripts/battle/rock_tomb_rules.gd").capture(move)
	if preload("res://scripts/battle/flame_wheel_rules.gd").supports(move):phase.source_flame_wheel=preload("res://scripts/battle/flame_wheel_rules.gd").capture(move)
	if preload("res://scripts/battle/baton_pass_rules.gd").supports(move):phase.source_baton_pass=preload("res://scripts/battle/baton_pass_rules.gd").capture(move)
	if preload("res://scripts/battle/baton_pass_rules.gd").supports(move) and battle.formato_batalla==Singleton.FormatoBatalla.DOBLE:phase.source_baton_bank=preload("res://scripts/battle/baton_bank_transaction.gd").capture(battle,actor)
	if preload("res://scripts/battle/overheat_rules.gd").supports(move):phase.source_overheat=preload("res://scripts/battle/overheat_rules.gd").capture(move)
	if preload("res://scripts/battle/outrage_rules.gd").supports(move):phase.source_outrage=preload("res://scripts/battle/outrage_rules.gd").capture(move)
	if preload("res://scripts/battle/psycho_boost_rules.gd").supports(move):phase.source_psycho_boost=preload("res://scripts/battle/psycho_boost_rules.gd").capture(move)
	if preload("res://scripts/battle/tail_glow_rules.gd").supports(move):phase.source_tail_glow=preload("res://scripts/battle/tail_glow_rules.gd").capture(move)
	if preload("res://scripts/battle/cosmic_power_rules.gd").supports(move):phase.source_cosmic_power=preload("res://scripts/battle/cosmic_power_rules.gd").capture(move)
	if preload("res://scripts/battle/belly_drum_rules.gd").supports(move):phase.source_belly_drum=preload("res://scripts/battle/belly_drum_rules.gd").capture(move)
	if preload("res://scripts/battle/teeter_dance_rules.gd").supports(move):phase.source_teeter_dance=preload("res://scripts/battle/teeter_dance_rules.gd").capture(move)
	if preload("res://scripts/battle/haze_rules.gd").supports(move):phase.source_haze=preload("res://scripts/battle/haze_rules.gd").capture(move)
	if preload("res://scripts/battle/mist_ball_rules.gd").supports(move):phase.source_mist_ball=preload("res://scripts/battle/mist_ball_rules.gd").capture(move)
	if preload("res://scripts/battle/luster_purge_rules.gd").supports(move):phase.source_luster_purge=preload("res://scripts/battle/luster_purge_rules.gd").capture(move)
	if BattleHeldItemRules.supports(move):phase.source_held_item=BattleHeldItemRules.capture(move)
	if BattleHealingStreamRules.supports(move):phase.source_healing_stream=BattleHealingStreamRules.capture(move)
	if BattleDustWeatherRules.supports(move):phase.source_dust_weather=BattleDustWeatherRules.capture(move)
	if preload("res://scripts/battle/thought_finger_rules.gd").supports(move):phase.source_thought_finger=preload("res://scripts/battle/thought_finger_rules.gd").capture(move)
	if preload("res://scripts/battle/ice_rules.gd").supports(move):phase.source_ice=preload("res://scripts/battle/ice_rules.gd").capture(move)
	if CurseNightmare.supports(move):phase.source_curse_nightmare=CurseNightmare.capture(move,actor)
	if Imprison.supports(move):phase.source_imprison=Imprison.capture(move)
	if SkillSwap.supports(move):phase.source_skill_swap=SkillSwap.capture(move)
	if Trick.supports(move):phase.source_trick=Trick.capture(move)
	if Startle.supports(move):phase.source_startle=Startle.capture(move)
	if LovelyKiss.supports(move):phase.source_lovely_kiss=LovelyKiss.capture(move)
	if KissAttract.supports(move):phase.source_kiss_attract=KissAttract.capture(move)
	if TearsTickle.supports(move):phase.source_tears_tickle=TearsTickle.capture(move)
	if Heart.supports(move):phase.source_heart=Heart.capture(move)
	if BattleIdentifiedRules.supports(move):phase.source_identified=BattleIdentifiedRules.capture(move)
	if BattleSureHitRules.supports(move):phase.source_sure_hit=BattleSureHitRules.capture(move)
	if FireBlast.supports(move):phase.source_fire_blast=FireBlast.capture(move)
	if Sludge.supports(move):phase.source_sludge=Sludge.capture(move)
	if Acid.supports(move):phase.source_acid=Acid.capture(move)
	if Aurora.supports(move):phase.source_aurora=Aurora.capture(move)
	if ElementalPunch.supports(move):phase.source_elemental_punch=ElementalPunch.capture(move)
	if PoisonGas.supports(move):phase.source_poison_gas=PoisonGas.capture(move)
	if Flash.supports(move):phase.source_flash=Flash.capture(move)
	if BattleSportRules.supports(move):phase.source_sport=BattleSportRules.capture(move)
	if not BattleProtectRules.mode(move).is_empty():phase.source_protect=BattleProtectRules.capture(move)
	if BattleWindFeatherRules.supports(move):phase.source_i3=BattleWindFeatherRules.capture(move)
	if BattleSafeguardRules.supports(move):phase.source_safeguard=BattleSafeguardRules.capture(move)
	return phase
static func phase_live(guard: Dictionary) -> bool:
	if guard.has("source_hidden_power") and guard.source_hidden_power.is_empty():return false
	if guard.is_empty():return false
	var battle: Node=guard.owner.get_ref()
	if is_instance_valid(battle) and battle.field_rules.valid_flow(guard.flow) and (not guard.has("source_i4") or guard.source_i4.live()):return true
	var record: Dictionary=guard.actor
	var original: PokemonEnCombate=record.state.get_ref() if record.has("state") else null
	if original!=null:original.cancelar_continuacion()
	return false
static func bind_action(battle: Node,action: BattleMoveAction,move: Movimiento,accepted_phase: Dictionary={}) -> void:
	preload("res://scripts/battle/rage_rules.gd").bind(battle,action,accepted_phase)
	if accepted_phase.has("source_body_admission") and not action.has_meta("source_body_admission"):action.set_meta("source_body_admission",accepted_phase.source_body_admission)
	if accepted_phase.has("source_protect_receipt"):action.set_meta("source_protect_receipt",accepted_phase.source_protect_receipt.duplicate(true))
	if accepted_phase.has("source_grudge_selected_slot"):action.set_meta("source_grudge_selected_slot",accepted_phase.source_grudge_selected_slot)
	action.set_meta("source_landed_policy",{"id":int(move.datos.get("numero_movimiento",0)),"type":move.get_tipo()})
	if action.has_meta("source_screen_phase_guard") or (not accepted_phase.has("source_i3") and not accepted_phase.has("source_i4") and not phase_supported(move)):return
	# Scheduled dispatch carries the BEFORE-message lease; direct dispatch owns
	# its synchronous start capture. Never reacquire a changed accepted world.
	var guard: Dictionary=accepted_phase if accepted_phase.has("source_screen_phase") else capture_phase(battle,action.attacker,move)
	action.set_meta("source_screen_phase_guard",guard.duplicate(true))
static func action_live(action: BattleMoveAction) -> bool:
	if not action.has_meta("source_screen_phase_guard"):return true
	var guard: Dictionary=action.get_meta("source_screen_phase_guard");var battle: Node=guard.owner.get_ref()
	if is_instance_valid(battle) and battle.field_rules.valid_flow(guard.flow) and (not guard.has("source_i4") or guard.source_i4.live()):
		# Accepted contact USER faint returns to ordinary faint settlement. It
		# terminates further commands, not the outer turn as a stale operation.
		return not bool(guard.get("contact_ko",false))
	var record: Dictionary=guard.actor
	var original: PokemonEnCombate=record.state.get_ref() if record.has("state") else null
	if original!=null:original.cancelar_continuacion()
	action.phase="entry_aborted";return false
static func capture_contact(action: BattleMoveAction) -> Dictionary:
	if not action.has_meta("source_screen_phase_guard") or not action_live(action):return {}
	var guard: Dictionary=action.get_meta("source_screen_phase_guard")
	return {"flow":guard.flow.duplicate(true),"hp":action.attacker.estad_ps_actual}
static func complete_contact(action: BattleMoveAction,accepted: Dictionary) -> void:
	if accepted.is_empty() or int(accepted.hp)<=0 or action.attacker.estad_ps_actual!=0:return
	var guard: Dictionary=action.get_meta("source_screen_phase_guard")
	var battle: Node=guard.owner.get_ref()
	if not is_instance_valid(battle):return
	var flow: Dictionary=accepted.flow.duplicate(true)
	var owned_retirement: bool=false
	for record: Dictionary in flow.records:
		if record.pokemon!=action.attacker:continue
		var original: PokemonEnCombate=record.state.get_ref()
		if original!=null and battle._obtener_combatiente(action.attacker)==original and original.body_attack_epoch==int(record.epoch)+1:
			record.epoch=original.body_attack_epoch;owned_retirement=true
	# This verifies every other bank plus the original round/lifetime/slot. An
	# external same-party replacement or extra retirement is never adopted.
	if owned_retirement and battle.field_rules.valid_flow(flow):
		if guard.has("source_i4"):
			for record: Dictionary in flow.records:
				if record.pokemon==action.attacker:guard.source_i4.complete_owned_contact_ko(record)
		guard.flow=flow;guard.contact_ko=true
static func reconcile_ko(action: BattleMoveAction,target: BasePokemon,result: Dictionary,before_hp: int) -> bool:
	if action.has_meta("source_screen_phase_guard") and target.estad_ps_actual==0 and int(result.get("damage",0))>=before_hp:
		var guard: Dictionary=action.get_meta("source_screen_phase_guard");var battle: Node=guard.owner.get_ref()
		if is_instance_valid(battle):
			for record: Dictionary in guard.flow.records:
				var original: PokemonEnCombate=record.state.get_ref()
				if record.pokemon==target and original!=null and battle._obtener_combatiente(target)==original and original.body_attack_epoch==int(record.epoch)+1:record.epoch=original.body_attack_epoch
	return action_live(action)
static func reduce_base(base: int,double_side: bool) -> int:
	return 2*(base/3) if double_side else base/2

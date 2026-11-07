extends RefCounted
class_name BattleEffectBehaviorRegistry
## Factories return owned tracks; maintenance ends on explicit source args, not visual barriers.
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

const LegacyDummyShake=preload("res://scripts/battle/animations/sequence/source_legacy_dummy_shake.gd")
const PairComposition = preload("res://scripts/battle/animations/sequence/source_pair_composition.gd")
const Spite = preload("res://scripts/battle/animations/sequence/source_spite_composition.gd")
const ConversionOwned=preload("res://scripts/battle/animations/sequence/source_conversion_owned.gd")
const WaterPulse=preload("res://scripts/battle/animations/sequence/source_water_pulse.gd")
const Hail=preload("res://scripts/battle/animations/sequence/source_hail.gd")
const ElectricEmitter = preload("res://scripts/battle/animations/sequence/source_electric_emitter.gd")
const Visual = preload("res://scripts/battle/animations/sequence/effect_visual.gd")
const Recolor = preload("res://scripts/battle/animations/sequence/particle_recolor.gdshader")
const WindAirChildren = preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
const WindFeatherParticles = preload("res://scripts/battle/animations/sequence/source_wind_feather_particles.gd")
const HiddenActorEmergence = preload("res://scripts/battle/animations/sequence/source_hidden_actor_emergence.gd")
const BirdHornOwned = preload("res://scripts/battle/animations/sequence/source_bird_horn_owned.gd")
const ElementalPunch = preload("res://scripts/battle/animations/sequence/source_elemental_punch.gd")
const SleepZ = preload("res://scripts/battle/animations/sequence/source_sleep_z.gd")
const StatusAux = preload("res://scripts/battle/animations/sequence/source_status_aux.gd")
const Torment=preload("res://scripts/battle/animations/sequence/source_torment.gd")
const Memento=preload("res://scripts/battle/animations/sequence/source_memento.gd")
const Superpower=preload("res://scripts/battle/animations/sequence/source_superpower.gd")
const ExtremeSpeed=preload("res://scripts/battle/animations/sequence/source_extreme_speed.gd")
const Extrasensory=preload("res://scripts/battle/animations/sequence/source_extrasensory.gd")
const Camouflage=preload("res://scripts/battle/animations/sequence/source_camouflage.gd")
const WeatherBall=preload("res://scripts/battle/animations/sequence/source_weather_ball.gd")
const Uproar=preload("res://scripts/battle/animations/sequence/source_uproar.gd")
const HpBursts=preload("res://scripts/battle/animations/sequence/source_hp_bursts.gd")
const Faint=preload("res://scripts/battle/animations/sequence/source_faint_attack.gd")
const Dig=preload("res://scripts/battle/animations/sequence/source_dig.gd")
const Fissure=preload("res://scripts/battle/animations/sequence/source_fissure.gd")
const Bonemerang=preload("res://scripts/battle/animations/sequence/source_bonemerang.gd")
const Yawn=preload("res://scripts/battle/animations/sequence/source_yawn.gd")
const SmellingSalt=preload("res://scripts/battle/animations/sequence/source_smelling_salt.gd")
const PainSplit=preload("res://scripts/battle/animations/sequence/source_pain_split.gd")
const StatMask=preload("res://scripts/battle/animations/sequence/source_stat_mask.gd")
const MagicCoatOwned=preload("res://scripts/battle/animations/sequence/source_magic_coat_owned.gd")
const RecycleOwned=preload("res://scripts/battle/animations/sequence/source_recycle_owned.gd")
const ChargeOwned=preload("res://scripts/battle/animations/sequence/source_charge_owned.gd")
const HelpingHand=preload("res://scripts/battle/animations/sequence/source_helping_hand.gd")
const Flatter=preload("res://scripts/battle/animations/sequence/source_flatter.gd")
const Encore=preload("res://scripts/battle/animations/sequence/source_encore.gd")
const CelestialHeal=preload("res://scripts/battle/animations/sequence/source_celestial_heal.gd")
const SelfHeal=preload("res://scripts/battle/animations/sequence/source_self_heal.gd")
const Kinesis=preload("res://scripts/battle/animations/sequence/source_kinesis.gd")
const Disable=preload("res://scripts/battle/animations/sequence/source_disable.gd")
const Smokescreen=preload("res://scripts/battle/animations/sequence/source_smokescreen.gd")
const Spikes=preload("res://scripts/battle/animations/sequence/source_spikes.gd")
const Barrage=preload("res://scripts/battle/animations/sequence/source_barrage.gd")
const RockTomb=preload("res://scripts/battle/animations/sequence/source_rock_tomb.gd")
const FlameWheel=preload("res://scripts/battle/animations/sequence/source_flame_wheel.gd")
const BatonPass=preload("res://scripts/battle/animations/sequence/source_baton_pass.gd")
const Overheat=preload("res://scripts/battle/animations/sequence/source_overheat.gd")
const Outrage=preload("res://scripts/battle/animations/sequence/source_outrage.gd")
const PsychoBoost=preload("res://scripts/battle/animations/sequence/source_psycho_boost.gd")
const PoundTackle=preload("res://scripts/battle/animations/sequence/source_pound_tackle.gd")
const Sketch=preload("res://scripts/battle/animations/sequence/source_sketch.gd")
const Assist=preload("res://scripts/battle/animations/sequence/source_assist.gd")
const SleepTalk=preload("res://scripts/battle/animations/sequence/source_sleep_talk.gd")
const PayDay=preload("res://scripts/battle/animations/sequence/source_pay_day.gd")
const Whirlwind=preload("res://scripts/battle/animations/sequence/source_whirlwind.gd")
const Present=preload("res://scripts/battle/animations/sequence/source_present.gd")
const Magnitude=preload("res://scripts/battle/animations/sequence/source_magnitude.gd")
const SeismicToss=preload("res://scripts/battle/animations/sequence/source_seismic_toss.gd")
const HyperBeam=preload("res://scripts/battle/animations/sequence/source_hyper_beam.gd")
const HeldSurvival=preload("res://scripts/battle/animations/sequence/source_held_survival_actor.gd")
const FocusSetup=preload("res://scripts/battle/animations/sequence/source_focus_setup.gd")
const Snatch=preload("res://scripts/battle/animations/sequence/source_snatch.gd")
const TurnTrap=preload("res://scripts/battle/animations/sequence/source_turn_trap.gd")
const Guillotine=preload("res://scripts/battle/animations/sequence/source_guillotine.gd")
const Aromatherapy=preload("res://scripts/battle/animations/sequence/source_aromatherapy.gd")
const TailGlow=preload("res://scripts/battle/animations/sequence/source_tail_glow.gd")
const LusterPurge=preload("res://scripts/battle/animations/sequence/source_luster_purge.gd")
const MistBall=preload("res://scripts/battle/animations/sequence/source_mist_ball.gd")
const Haze=preload("res://scripts/battle/animations/sequence/source_haze.gd")
const TeeterDance=preload("res://scripts/battle/animations/sequence/source_teeter_dance.gd")
const BellyDrum=preload("res://scripts/battle/animations/sequence/source_belly_drum.gd")
const CosmicPower=preload("res://scripts/battle/animations/sequence/source_cosmic_power.gd")
const DragonDance=preload("res://scripts/battle/animations/sequence/source_dragon_dance.gd")
const ItemBag=preload("res://scripts/battle/animations/sequence/source_item_bag.gd")
const RainSun=preload("res://scripts/battle/animations/sequence/source_rain_sun.gd")
const WishStar=preload("res://scripts/battle/animations/sequence/source_wish_star.gd")
const DustWeather=preload("res://scripts/battle/animations/sequence/source_dust_weather.gd")
const ThoughtFinger=preload("res://scripts/battle/animations/sequence/source_thought_finger.gd")
const CompoundIce=preload("res://scripts/battle/animations/sequence/source_compound_ice.gd")
const CurseNightmare=preload("res://scripts/battle/animations/sequence/source_curse_nightmare.gd")
const Imprison=preload("res://scripts/battle/animations/sequence/source_imprison.gd")
const SkillSwap=preload("res://scripts/battle/animations/sequence/source_skill_swap.gd")
const Trick=preload("res://scripts/battle/animations/sequence/source_trick.gd")
const Startle=preload("res://scripts/battle/animations/sequence/source_startle.gd")
const LovelyKiss=preload("res://scripts/battle/animations/sequence/source_lovely_kiss.gd")
const KissAttract=preload("res://scripts/battle/animations/sequence/source_kiss_attract.gd")
const TearsTickle=preload("res://scripts/battle/animations/sequence/source_tears_tickle.gd")
const MagentaHeart=preload("res://scripts/battle/animations/sequence/source_magenta_heart.gd")
const Identified = preload("res://scripts/battle/animations/sequence/source_identified.gd")
const SureHit = preload("res://scripts/battle/animations/sequence/source_sure_hit.gd")
const FireBlast = preload("res://scripts/battle/animations/sequence/source_fire_blast.gd")
const Sludge = preload("res://scripts/battle/animations/sequence/source_sludge.gd")
const Acid = preload("res://scripts/battle/animations/sequence/source_acid.gd")
const Aurora = preload("res://scripts/battle/animations/sequence/source_aurora_rings.gd")
const Sports = preload("res://scripts/battle/animations/sequence/source_sports.gd")
const ProtectShield = preload("res://scripts/battle/animations/sequence/source_protect_shield.gd")
const GuardRing = preload("res://scripts/battle/animations/sequence/source_guard_ring.gd")
const FlashPalette = preload("res://scripts/battle/animations/sequence/source_flash_palette.gd")
const PoisonGas = preload("res://scripts/battle/animations/sequence/source_poison_gas.gd")
const ScentPetal = preload("res://scripts/battle/animations/sequence/source_scent_petal.gd")
const EscapeMark = preload("res://scripts/battle/animations/sequence/source_escape_mark.gd")
const LegacyImpact = preload("res://scripts/battle/animations/sequence/source_legacy_impact_composition.gd")
const KarateTranslation = preload("res://scripts/battle/animations/sequence/source_karate_translation.gd")
const CuttingSlice = preload("res://scripts/battle/animations/sequence/source_cutting_slice.gd")
const StringWeb = preload("res://scripts/battle/animations/sequence/source_string_web.gd")
const Tendril = preload("res://scripts/battle/animations/sequence/source_tendril.gd")
static var _custom: Dictionary = {}

static func register_behavior(key: String, factory: Callable) -> void:
	_custom[key] = factory

static func factories() -> Dictionary:
	var result := {}
	result["source_water_pulse_ring"]=WaterPulse.create
	result["source_hail_task"]=Hail.create
	result["source_legacy_impact_command"]=LegacyImpact.create
	result["source_legacy_impact_duplicates"]=LegacyImpact.create_duplicates
	for key in ["source_doom_light", "source_shadow", "source_refresh", "source_scroll", "source_particle_palette", "source_maintenance", "source_phase", "source_surf", "source_background", "source_particle", "source_palette", "source_actor", "shake", "lunge", "flash", "impact", "projectile", "ring", "barrier", "rain", "wave", "beam", "darken", "clap", "sheet", "actor_motion", "actor_scale", "palette_blend", "afterimage", "metallic_sweep"]:
		result[key] = _create.bind(key)
	result.merge(_custom, true)
	result["plant_target_layer"] = _create.bind("plant_target_layer")
	result["source_note_bank"] = _create.bind("source_note_bank")
	result["source_field_offset"] = _create.bind("source_field_offset")
	result["source_note_grayscale"] = _create.bind("source_note_grayscale")
	result["source_species_cry"] = _create.bind("source_species_cry")
	for key in ["source_ghost_clone","source_ghost_children","source_ghost_pan","source_ghost_palette"]:result[key]=_create.bind(key)
	result["source_grudge_command"]=BattleCounterSelected.create
	result["source_spite_command"]=Spite.create
	result["source_nightmare_command"]=PairComposition.create_nightmare
	result["source_flamethrower_command"]=PairComposition.create_flamethrower
	result["source_bubble_command"]=PairComposition.create_bubble
	result["source_whirlpool_command"]=PairComposition.create_whirlpool
	for kind: String in ["source_magic_coat_wall","source_magic_coat_command"]:result[kind]=MagicCoatOwned.create
	for kind: String in ["source_recycle_command","source_recycle_palette"]:result[kind]=RecycleOwned.create
	for kind: String in ["source_charge_ring","source_charge_command"]:result[kind]=ChargeOwned.create
	result["source_electric_emitter"]=ElectricEmitter.create
	result["source_electric_task"]=_create.bind("source_electric_task")
	result["source_charge_task"]=_create.bind("source_charge_task")
	result["source_state_props_task"]=_create.bind("source_state_props_task")
	result["source_actor_shadows"]=_create.bind("source_actor_shadows")
	result["source_orb_state"]=_create.bind("source_orb_state")
	result["source_identity_copy"]=_create.bind("source_identity_copy")
	result["source_identity_transition"]=_create.bind("source_identity_transition")
	result["source_approach"]=_create.bind("source_approach")
	result["source_field_owned"]=_create.bind("source_field_owned")
	result["source_conversion_particle"]=_create.bind("source_conversion_particle")
	result["source_conversion_task"]=_create.bind("source_conversion_task")
	result["source_counter_selected"]=_create.bind("source_counter_selected")
	result["source_phase_screen_hit"]=_create.bind("source_phase_screen_hit")
	result["source_wind_direct"]=_create.bind("source_wind_direct")
	result["source_wind_air_children"]=WindAirChildren.create
	result["source_wind_feather_particles"]=WindFeatherParticles.create
	result["source_hidden_actor_emergence"]=HiddenActorEmergence.create
	result["source_bird_horn_owned"]=BirdHornOwned.create
	result["source_elemental_punch"]=ElementalPunch.create
	result["source_sleep_z"]=SleepZ.create
	result["source_status_aux"]=StatusAux.create
	result["source_tendril"]=Tendril.create
	result["source_teleport_actor"]=preload("res://scripts/battle/animations/sequence/source_teleport_owned.gd").create
	for kind: String in ["source_mist_command","source_mist_cloud","source_mist_side_palette"]:result[kind]=preload("res://scripts/battle/animations/sequence/source_mist_owned.gd").create
	for kind: String in ["source_psych_up_command","source_psych_up_spiral","source_psych_up_palette"]:result[kind]=preload("res://scripts/battle/animations/sequence/source_psych_up_owned.gd").create
	for kind: String in ["source_recover_command","source_recover_palette","source_recover_orb","source_slack_squish"]:result[kind]=preload("res://scripts/battle/animations/sequence/source_restore_hp.gd").create
	result["source_refresh_mask"]=preload("res://scripts/battle/animations/sequence/source_refresh_owned.gd").create
	result["source_focus_energy"]=preload("res://scripts/battle/animations/sequence/source_focus_energy.gd").create
	result["source_focus_pulse"]=FocusSetup.create
	for kind: String in ["roles","side","substitute","sway","opposing","partner"]:result["source_snatch_"+kind]=_create.bind("source_snatch_"+kind)
	for kind: String in ["selector","particle","hit","command","stop_sound","palette"]:result["source_turn_trap_"+kind]=TurnTrap.create
	result["source_string_web"]=StringWeb.create
	result["source_escape_mark"]=EscapeMark.create
	result["source_scent_petal"]=ScentPetal.create
	result["source_poison_gas"]=PoisonGas.create
	result["source_flash_palette"]=FlashPalette.create
	result["source_guard_ring"]=GuardRing.create
	result["source_protect_shield"]=ProtectShield.create
	result["source_mind_reader"]=SureHit.create_mind
	result["source_lock_scan"]=SureHit.create_scan
	result["source_foresight_lens"]=Identified.create_lens
	result["source_magenta_heart"]=MagentaHeart.create
	result["source_fake_tear"]=TearsTickle.create_tear
	for kind in ["fountain","angel","travel","rise"]:result["source_kiss_"+kind]=KissAttract.create
	result["source_kiss_background"]=KissAttract.create_background
	for kind: String in ["monbg","cycle","circle","palette","impact"]:result["source_luster_"+kind]=LusterPurge.create
	for kind: String in ["projectile","bg","pulse","palette"]:result["source_mist_"+kind]=MistBall.create
	result.source_haze_bg=Haze.create;result.source_haze_palette=Haze.create
	result.source_teeter_note=TeeterDance.create;result.source_teeter_sway=TeeterDance.create
	result.source_drum_note=BellyDrum.create;result.source_drum_hand=BellyDrum.create
	for kind: String in ["thought","palette","anger"]:result["source_torment_"+kind]=Torment.create
	result["source_memento_task"]=Memento.create;result["source_memento_command"]=Memento.create
	for kind: String in ["aura","rock","meteor","quake","command"]:result["source_superpower_"+kind]=Superpower.create
	for kind: String in ["compress","recoil","dust","reentry","impact"]:result["source_extreme_"+kind]=ExtremeSpeed.create
	for kind: String in ["wave","palette","clone","command"]:result["source_extrasensory_"+kind]=Extrasensory.create
	for kind: String in ["palette","fade","command"]:result["source_camouflage_"+kind]=Camouflage.create
	for kind: String in ["launch","fall","dip","weather","chips"]:result["source_weather_ball_"+kind]=WeatherBall.create
	for kind: String in ["actor","ring","note","command"]:result["source_uproar_"+kind]=Uproar.create
	for kind: String in ["actor","fall","rain","palette","command","quake"]:result["source_hp_burst_"+kind]=HpBursts.create
	for kind: String in ["task","command","hit"]:result["source_faint_"+kind]=Faint.create
	for kind: String in ["actor","mound","command"]:result["source_dig_"+kind]=Dig.create
	for kind: String in ["plume","quake","align"]:result["source_fissure_"+kind]=Fissure.create
	for kind: String in ["source_bonemerang","source_bonemerang_lunge","source_bonemerang_command"]:result[kind]=Bonemerang.create
	for kind: String in ["actor","cloud"]:result["source_yawn_"+kind]=Yawn.create
	for kind: String in ["hand","actor","effect"]:result["source_smelling_salt_"+kind]=SmellingSalt.create
	for kind: String in ["bounce","actor"]:result["source_pain_split_"+kind]=PainSplit.create
	for kind: String in ["spotlight","confetti","dip"]:result["source_flatter_"+kind]=Flatter.create
	for kind: String in ["command","hardware","spotlight","hand"]:result["source_encore_"+kind]=Encore.create
	for kind: String in ["command","bg","green","moon","twinkle","dark","palette","alpha","flash"]:result["source_celestial_"+kind]=CelestialHeal.create
	for kind: String in ["command","egg","bottle","ring","palette"]:result["source_self_heal_"+kind]=SelfHeal.create
	for kind: String in ["source_kinesis_spoon","source_kinesis_alert","source_kinesis_cycle"]:result[kind]=Kinesis.create
	for kind: String in ["source_disable_command","source_disable_shadow","source_disable_sparkle"]:result[kind]=Disable.create
	for kind: String in ["source_smoke_ball","source_smoke_cloud","source_smoke_impact"]:result[kind]=Smokescreen.create
	result.source_spikes=Spikes.create
	result.source_barrage_ball=Barrage.create
	result.source_tomb_rock=RockTomb.create
	for kind: String in ["orbit","palette","monbg"]:result["source_flame_"+kind]=FlameWheel.create
	result.source_baton_ball=BatonPass.create;result.source_baton_pulse=BatonPass.create
	for kind: String in ["monbg","ember","fade","bank","impact"]:result["source_overheat_"+kind]=Overheat.create
	for kind: String in ["ember","palette","ellipse"]:result["source_outrage_"+kind]=Outrage.create
	for kind: String in ["monbg","light","palette"]:result["source_boost_"+kind]=PsychoBoost.create
	result.source_held_survival_actor=HeldSurvival.create
	result.source_pound_tackle_hit=PoundTackle.create
	result.source_pound_tackle_shake=PoundTackle.create
	result.source_pound_tackle_lunge=PoundTackle.create
	result.source_sketch_pencil=Sketch.create
	result.source_sketch_reveal=Sketch.create
	result.source_nature_preview_rock=preload("res://scripts/battle/animations/sequence/source_nature_preview.gd").create
	result.source_assist_paw=Assist.create
	for kind: String in ["z","sway"]:result["source_sleep_talk_"+kind]=SleepTalk.create
	for kind: String in ["projectile","bounce","hit"]:result["source_pay_day_"+kind]=PayDay.create
	for kind: String in ["line","ellipse","exit","release"]:result["source_whirlwind_"+kind]=Whirlwind.create
	for kind: String in ["branch","gift","sparkle"]:result["source_present_"+kind]=Present.create
	for kind: String in ["branch","quake"]:result["source_magnitude_"+kind]=Magnitude.create
	for kind: String in ["tier","rise","bounce","rock","command","hit"]:result["source_seismic_"+kind]=SeismicToss.create
	result.source_hyper_orb=HyperBeam.create;result.source_hyper_palette=HyperBeam.create;result.source_hyper_shake=HyperBeam.create
	for kind: String in ["cut","command","background","palette","hit"]:result["source_guillotine_"+kind]=Guillotine.create
	for kind: String in ["flower","mask","palette","monbg"]:result["source_aroma_"+kind]=Aromatherapy.create
	for kind: String in ["sprite","actor","shake","palette"]:result["source_helping_hand_"+kind]=HelpingHand.create
	result.source_stat_mask=StatMask.create
	result.source_tail_monbg=TailGlow.create;result.source_tail_light=TailGlow.create;result.source_tail_palette=TailGlow.create
	result.source_cosmic_palette=CosmicPower.create
	for kind: String in ["wave","palette","orb"]:result["source_dragon_"+kind]=DragonDance.create
	result.source_item_bag=ItemBag.create;result.source_item_roles=ItemBag.create
	result.source_rain_task=RainSun.create;result.source_sun_orb=RainSun.create
	result.source_wish_star=WishStar.create
	for kind in ["dust_bg","dust_particle","dust_palette","heat_shove"]:result["source_"+kind]=DustWeather.create
	result["source_thought_finger"]=ThoughtFinger.create
	result["source_compound_ice"]=CompoundIce.create
	for kind in ["window","nail","spirit","mask"]:result["source_curse_"+kind]=CurseNightmare.create
	for kind in ["orbs","sign"]:result["source_imprison_"+kind]=Imprison.create
	result["source_skill_swap_task"]=SkillSwap.create
	result["source_trick_bag"]=Trick.create
	for kind in ["fake_curtain","astonish_sweat"]:result["source_"+kind]=Startle.create
	for kind in ["pink","devil"]:result["source_lovely_"+kind]=LovelyKiss.create
	result["source_tickle_sparkle"]=TearsTickle.create_sparkle
	result["source_tag_palette_tint"]=TearsTickle.create_tint
	result["source_odor_sleuth"]=Identified.create_odor
	result["source_fire_blast"]=FireBlast.create
	result["source_fire_blast_sound"]=FireBlast.create_sound
	result["source_sludge"]=Sludge.create
	result["source_acid"]=Acid.create
	result["source_aurora_ring"]=Aurora.create_ring
	result["source_aurora_palette"]=Aurora.create_palette
	result["source_sport_dirt"]=Sports.create_dirt
	result["source_sport_water_task"]=Sports.create_water
	return result

static func _sheet_scale_factor(step: Dictionary, owner: Node2D, kind: String) -> float:
	var factor := float(step.get("scale_factor", 1.0))
	if kind != "sheet" or step.get("source_template") != "gBasicHitSplatSpriteTemplate" or step.get("source_callback") != "sub_80E27A0":
		return factor
	if not owner is BattleAnimationSequenceRunner or not BattleAnimationSequenceRegistry.is_builtin_source_definition(owner.definition):
		return factor
	var variant: Variant = step.get("source_affine_variant")
	if typeof(variant) not in [TYPE_INT, TYPE_FLOAT]:
		return factor
	var value := float(variant)
	if not is_finite(value) or value != floor(value) or value < 0 or value > 3:
		return factor
	var parameter: float = [256.0, 216.0, 176.0, 128.0][int(value)]
	# Ruby inverts this logical parameter for hardware; native geometry must not.
	# A changed literal factor remains custom intent. Never rewrite shared settings.
	return parameter / 256.0 if factor == 256.0 / parameter else factor

static func _create(step: Dictionary, context: BattleAnimationContext, owner: Node2D, kind: String) -> Array[Dictionary]:
	var night: Variant=LegacyImpact.NightShade.effect(step,context,owner,kind)
	if night!=null:
		var admitted_night: Array[Dictionary]=[];admitted_night.assign(night);return admitted_night
	var confuse: Variant=LegacyImpact.Confuse.effect(step,context,owner,kind)
	if confuse!=null:
		var admitted_confuse: Array[Dictionary]=[];admitted_confuse.assign(confuse);return admitted_confuse
	var dizzy: Variant=LegacyImpact.Dizzy.effect(step,context,owner,kind)
	if dizzy!=null:
		var admitted_dizzy: Array[Dictionary]=[];admitted_dizzy.assign(dizzy);return admitted_dizzy
	var dizzy_literal: Dictionary=LegacyImpact.Dizzy.literal_art(step,context,owner,kind)
	if dizzy_literal.get("handled",false) and not dizzy_literal.get("valid",false):return []
	var crab: Variant=LegacyImpact.Crab.effect(step,context,owner,kind)
	if crab!=null:
		var crab_tracks: Array[Dictionary]=[];crab_tracks.assign(crab);return crab_tracks
	var hydro: Variant=LegacyImpact.Hydro.effect(step,context,owner,kind)
	if hydro!=null:
		var hydro_tracks: Array[Dictionary]=[];hydro_tracks.assign(hydro);return hydro_tracks
	var frenzy: Variant=LegacyImpact.Frenzy.effect(step,context,owner,kind)
	if frenzy!=null:
		var frenzy_tracks: Array[Dictionary]=[];frenzy_tracks.assign(frenzy);return frenzy_tracks
	var blizzard_physical: bool=LegacyImpact.Blizzard.physical_entry(step,context,owner,kind)
	var blizzard: Variant=LegacyImpact.Blizzard.effect(step,context,owner,kind,blizzard_physical)
	if blizzard!=null:
		var admitted_blizzard: Array[Dictionary]=[];admitted_blizzard.assign(blizzard);return admitted_blizzard
	# Local consumed capability survives unrelated helper Dictionary copies.
	var waterfall_physical: bool=LegacyImpact.Waterfall.physical_entry(step,context,owner,kind)
	var waterfall: Variant=LegacyImpact.Waterfall.effect(step,context,owner,kind,waterfall_physical)
	if waterfall!=null:
		var waterfall_tracks: Array[Dictionary]=[];waterfall_tracks.assign(waterfall);return waterfall_tracks
	var petal: Variant=LegacyImpact.Petal.effect(step,context,owner,kind)
	if petal!=null:
		var petal_tracks: Array[Dictionary]=[];petal_tracks.assign(petal);return petal_tracks
	var snatch: Variant=Snatch.effect(step,context,owner,kind)
	if snatch!=null:
		var snatch_tracks: Array[Dictionary]=[];snatch_tracks.assign(snatch);return snatch_tracks
	if kind.begins_with("source_snatch_"):return Snatch.create(step,context,owner)
	var stockpile: Variant=LegacyImpact.Stockpile.effect(step,context,owner,kind)
	if stockpile!=null:
		var stockpile_tracks: Array[Dictionary]=[];stockpile_tracks.assign(stockpile);return stockpile_tracks
	var solar: Variant=LegacyImpact.Solar.effect(step,context,owner,kind)
	if solar!=null:
		var solar_tracks: Array[Dictionary]=[];solar_tracks.assign(solar);return solar_tracks
	var secret: Variant=LegacyImpact.Secret.effect(step,context,owner,kind)
	if secret!=null:
		var admitted_secret: Array[Dictionary]=[];admitted_secret.assign(secret);return admitted_secret
	if kind=="source_particle":
		var musical: Variant=LegacyImpact.Musical.particle(step,context,owner)
		if musical!=null:
			var admitted: Array[Dictionary]=[];admitted.assign(musical);return admitted
	var source_dispatch_step: Dictionary=step
	var spinning_packet: Dictionary={}
	var swords_packet: Dictionary={}
	if kind=="source_particle":
		swords_packet=LegacyImpact.Swords.prepare(step,context,owner)
		if swords_packet.get("handled",false):
			if not swords_packet.has("admission"):return []
			step=swords_packet.step
	if kind in ["sheet","source_particle"]:
		spinning_packet=LegacyImpact.Spinning.prepare(step,context,owner)
		if spinning_packet.get("handled",false):
			if not spinning_packet.has("admission"):return []
			step=spinning_packet.step
	var tracks: Array[Dictionary] = []
	if kind=="shake":
		var native: Variant=LegacyDummyShake.create(step,context,owner)
		if native!=null:
			tracks.assign(native);return tracks
	if kind=="source_wind_direct":return BattleWindDirect.create(step,context,owner)
	if kind=="source_phase_screen_hit":return BattlePhaseScreenHit.create(step,context,owner)
	if kind=="source_field_owned":return BattleFieldOwned.create(step,context,owner)
	if kind in ["source_conversion_particle","source_conversion_task"]:return ConversionOwned.create(step,context,owner)
	if kind=="source_counter_selected":return BattleCounterSelected.create(step,context,owner)
	if kind=="source_approach":return BattleApproachChildren.create(step,context,owner)
	if kind=="source_orb_state":return BattleOrbState.create(step,context,owner)
	if kind=="source_identity_copy":return BattleIdentityCopy.create(step,context,owner)
	if kind=="source_identity_transition":return BattleIdentityTransition.create(step,context,owner)
	var ticks := maxi(1, int(step.get("ticks", 18)))
	var tint := Color(str(step.get("color", "ffffff")))
	if kind=="source_electric_task":return BattleElectricContract.create_control(step,context,owner)
	if kind=="source_charge_task":return BattleChargeContract.create_control(step,context,owner)
	if kind=="source_state_props_task":
		var swords_palette: Variant=LegacyImpact.Swords.palette(step,context,owner)
		if swords_palette!=null:tracks.assign(swords_palette);return tracks
		return BattleStateProps.create_control(step,context,owner)
	if kind=="source_actor_shadows":return BattleActorShadows.create(step,context,owner)
	if kind=="source_ghost_clone":return BattleGhostContract.create_clone(step,context,owner)
	if kind=="source_ghost_children":return BattleGhostContract.create_children(step,context,owner)
	if kind in ["source_ghost_pan","source_ghost_palette"]:return BattleGhostContract.create_control(step,context,owner)
	if kind == "source_field_offset":
		return BattleSoundOwnership.create_field_offset(step,context)
	if kind == "source_note_grayscale":
		return [{"kind":kind,"age":0,"ticks":int(step.ticks),"settings":step.duplicate(true)}]
	if kind == "source_note_bank":
		var musical_bank: Variant=LegacyImpact.Musical.bank(step,context,owner)
		if musical_bank!=null:
			var admitted_bank: Array[Dictionary]=[];admitted_bank.assign(musical_bank);return admitted_bank
		return BattleSoundOwnership.create_bank(step,owner)
	if kind == "source_species_cry":
		return BattleSoundOwnership.create_cry(step,context,owner)
	if kind == "plant_target_layer":
		if not context.contest and not context.resolve("target_partner").is_empty():
			for actor in context.resolve("target"):
				actor.apply_source_layer(actor.sprite.z_index + (-1 if actor.id % 2 == 0 else 1))
		return tracks
	if kind == "source_doom_light":
		return BattleAuxiliaryEffects.create_light(step,context,owner)
	if kind in ["source_shadow","source_refresh"]:
		return BattlePostPsychic.create_owned(step,context,owner,kind)
	if kind in ["source_scroll","source_particle_palette"]:
		tracks.append({"kind":kind,"age":0,"ticks":2147483647 if kind=="source_scroll" else ticks,"domain":str(step.get("domain","visual")),"settings":step.duplicate(true),"owner":owner})
		return tracks
	if kind == "source_maintenance":
		tracks.append({"kind":kind,"age":0,"ticks":2147483647,"domain":"maintenance","settings":step.duplicate(true)})
		return tracks
	if kind == "source_phase":
		owner._source_phase_started = owner.elapsed_ticks
		owner._source_phase_duration = ticks
		tracks.append({"kind":kind,"age":0,"ticks":ticks,"settings":step.duplicate(true)})
		return tracks
	if kind == "source_background":
		tracks.append({"kind":kind,"age":0,"ticks":ticks,"domain":"background","settings":step.duplicate(true)})
		return tracks
	if kind == "source_palette":
		var selected: Dictionary=LegacyImpact.Spinning.palette_members(owner,context,step,source_dispatch_step)
		if not selected.get("handled",false):selected=LegacyImpact.AgilityAerial.palette_members(owner,context,step,source_dispatch_step)
		if not selected.get("handled",false):selected=LegacyImpact.CrossImpact.palette_members(owner,context,step,source_dispatch_step)
		if selected.get("rejected",false):return []
		if str(step.selector) == "background":
			tracks.append({"kind":kind,"age":0,"ticks":ticks,"settings":step.duplicate(true)})
			if LegacyImpact.Spinning.matches(owner):LegacyImpact.Spinning.admit_palette(owner,context,tracks.back(),selected)
		else:
			for actor in selected.actors if selected.get("handled",false) else context.resolve(str(step.selector)):
				tracks.append({"kind":kind,"age":0,"ticks":ticks,"actor":actor,"settings":step.duplicate(true)})
				if LegacyImpact.Spinning.matches(owner):LegacyImpact.Spinning.admit_palette(owner,context,tracks.back(),selected)
				elif LegacyImpact.CrossImpact.matches(owner):LegacyImpact.CrossImpact.admit_palette(owner,context,tracks.back(),selected)
				else:LegacyImpact.AgilityAerial.admit_palette(owner,context,tracks.back(),selected)
		return tracks
	if kind in ["source_actor", "shake", "lunge", "flash", "actor_motion", "actor_scale", "palette_blend"]:
		var swords_motion: Dictionary={}
		if kind=="actor_motion":
			swords_motion=LegacyImpact.Swords.motion(source_dispatch_step,context,owner)
			if swords_motion.get("handled",false) and not swords_motion.get("admitted",false):return []
		if kind=="actor_motion" and str(step.get("motion",""))=="power_shake":
			step = step.duplicate(true)
			step.source_magnitude = context.source_damage if str(step.amplitude_source)=="damage" else context.source_power
		for actor in context.resolve(str(step.get("selector", "target"))):
			if kind == "actor_motion" and str(step.get("motion","")) == "night_shade":
				actor.apply_source_state("visible",true)
				actor.apply_transform(Vector2.ONE*256.0/int(step.matrix_initial))
				actor.apply(Vector2.ZERO,Color(1,1,1,0))
			if kind == "actor_motion" and str(step.get("motion", "")) == "roar_exit":
				if str(step.selector).ends_with("partner") and not actor.sprite.is_visible_in_tree(): continue
				step = step.duplicate(true)
				step.target_side = context.resolve("target")[0].side
				step.source_base_x = actor.anchor(context.field,"origin").x
				step.exit_limit = int(context.field_size.x) + 64
			if kind=="actor_motion" and str(step.get("motion",""))=="source_startle":
				step=step.duplicate(true)
				var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(step.source_pic_y_offsets)))
				var species: String=str(context.source_appearance_species.get(actor.id,context.source_party_species.get(actor.id,""))).to_upper()
				var side: String="back" if context.contest or actor.side==0 else "front"
				var offsets: Dictionary=source.by_species.get(species,{})
				if not offsets.has(side):owner.error_message="Missing source startle picture offset: "+species;owner.finish("failed");return []
				step.source_height=64-2*int(offsets[side])
				actor.apply(Vector2(4,0),Color.WHITE) # Actual constructor x2 write.
			var destination := Vector2.ZERO
			if kind == "lunge" and not context.resolve("target").is_empty():
				destination = (context.resolve("target")[0].anchor(context.field) - actor.anchor(context.field)).normalized() * float(step.get("distance", 12))
			var initial: Vector2 = owner.get_actor_offset(actor.id) if owner.has_method("get_actor_offset") else Vector2.ZERO
			tracks.append({"kind": kind, "age": 0, "ticks": ticks, "initial": initial, "actor": actor, "color": tint, "destination": destination, "amplitude": Vector2(float(step.get("x", 3)), float(step.get("y", 0))), "settings": step.duplicate(true)})
		if swords_motion.get("admitted",false):LegacyImpact.Swords.bind_motion(owner,context,tracks)
		if kind == "source_actor":
			for track in tracks:
				BattleSourceActorMotion.initialize(track)
				owner._held_offsets[track.actor.id] = track.displacement
				track.actor.apply(track.displacement, Color.WHITE)
		return tracks
	if kind in ["afterimage", "metallic_sweep"]:
		for actor in context.resolve(str(step.get("selector", "attacker"))):
			var clone := Sprite2D.new()
			clone.z_index = 20 if kind == "metallic_sweep" else actor.sprite.z_index - 1
			clone.texture = actor.sprite.texture
			clone.hframes = actor.sprite.hframes
			clone.vframes = actor.sprite.vframes
			clone.frame = actor.sprite.frame
			clone.flip_h = actor.sprite.flip_h
			clone.flip_v = actor.sprite.flip_v
			clone.scale = actor.sprite.global_scale / context.field.global_scale
			clone.position = actor.anchor(context.field)
			clone.modulate.a = 0.4
			if kind == "afterimage":
				clone.visible = false
			if kind == "metallic_sweep":
				var material := ShaderMaterial.new()
				material.shader = load("res://scripts/battle/animations/sequence/metallic_sweep.gdshader")
				clone.material = material
				clone.modulate = Color.WHITE
			owner.add_child(clone)
			tracks.append({"kind": kind, "age": -1 if kind == "afterimage" else 0, "ticks": ticks, "node": clone, "actor_snapshot": actor, "snapshot_pending": kind == "afterimage"})
			if kind == "afterimage":
				for index in range(1, int(step.get("emit_count", 1))):
					var delayed := clone.duplicate() as Sprite2D
					delayed.visible = false
					owner.add_child(delayed)
					tracks.append({"kind": kind, "age": -1 - index * int(step.get("emit_interval", 4)), "ticks": ticks, "node": delayed, "actor_snapshot": actor, "snapshot_pending": true})
		return tracks
	var anchors: Array[Vector2] = []
	if kind=="source_particle":step=BattleContactSelected.prepare(step,context,owner)
	var stinger_packet: Dictionary={}
	if kind=="source_particle":stinger_packet=LegacyImpact.Stinger.prepare(step,context,owner,source_dispatch_step)
	if not stinger_packet.is_empty():step=stinger_packet.step
	var source_anchor_operands: Array[Dictionary] = []
	# Explicit196-only destination policy; generic selectors/arrival stay untouched.
	var source_pair_body: Dictionary={}
	if kind=="source_particle" and str(step.get("to_selector",""))=="source_target_position_pair_body":
		source_pair_body=context.source_position_pair_body_center()
		if str(source_pair_body.state)!="valid":return []

	if str(step.get("selector", "")) == "field" or kind in ["rain", "wave", "darken", "source_surf"]:
		anchors.append(Vector2.ZERO)
	elif kind == "projectile" or kind == "beam":
		for actor in context.resolve(str(step.get("to", "targets"))):
			anchors.append(actor.anchor(context.field,str(step.get("anchor","center"))))
	elif str(step.get("selector","")) == "targets_center":
		anchors.append(_center(context,"targets",str(step.get("anchor","center"))))
	elif str(step.get("selector","")) == "source_target_and_partner_visual_center":
		for actor in context.resolve("source_target_and_partner_visual_center"):
			var position := actor.anchor(context.field,str(step.get("anchor","center")))
			source_anchor_operands.append({"actor_id":actor.id,"position":[position.x,position.y]})
		anchors.append(_center(context,"source_target_and_partner_visual_center",str(step.get("anchor","center"))))
	else:
		for actor in context.resolve(str(step.get("selector", "target"))):
			anchors.append(actor.anchor(context.field,str(step.get("anchor","center"))))
	for destination in anchors:
		var offset_values: Array = step.get("offset", [0, 0])
		destination += Vector2(float(offset_values[0]), float(offset_values[1]))
		var origin := destination
		if kind == "source_particle":
			if stinger_packet.is_empty() and not waterfall_physical:step = BattlePostPsychic.prepare_particle(step,context,owner)
			step = BattlePlantActor.prepare_particle(step,context,owner)
			step = BattleSoundOwnership.prepare_particle(step,owner)
			var direction := 1.0 if waterfall_physical else (1.0 if context.actors[context.attacker_id].side == 0 else -1.0)
			var offset_direction := direction
			if str(step.get("offset_direction",""))=="toward_target":
				# Bound identity can disappear during an earlier source-script delay.
				# Drop this dependent constructor; normal source barriers still drain.
				var source_actors: Array[BattleAnimationActor]=context.resolve("attacker")
				var target_actors: Array[BattleAnimationActor]=context.resolve("target")
				if source_actors.is_empty() or target_actors.is_empty():continue
				var source_x: float = source_actors[0].anchor(context.field).x
				var target_x: float = target_actors[0].anchor(context.field).x
				if not is_equal_approx(source_x,target_x):offset_direction = 1.0 if source_x<target_x else -1.0
			elif str(step.get("offset_direction",""))=="source_origin_toward_target":
				# Audited Ruby sub_807867C policy; not the generic visual-center adapter.
				if context.resolve("attacker").is_empty() or context.resolve("target").is_empty():continue
				offset_direction = BattleSoundOwnership.origin_offset_direction(context)
			if str(step.get("offset_direction",""))=="actor_side":
				var selected := context.resolve(str(step.selector))
				if not selected.is_empty():offset_direction = 1.0 if selected[0].side==0 else -1.0
			elif str(step.get("offset_direction",""))=="target_side_inverse":
				offset_direction = -1.0 if context.resolve("target")[0].side==0 else 1.0
			if bool(step.get("mirror_offset",false)):
				destination.x += float(offset_values[0])*(offset_direction-1.0)
			origin = destination
			if (bool(step.get("double_wall",false)) or bool(step.get("double_barrier",false))) and not context.contest and context.resolve("attacker_partner").size()>0:
				origin = (Vector2(72,80)+Vector2(-float(offset_values[0]),float(offset_values[1]))) if bool(step.get("double_barrier",false)) and context.actors[context.attacker_id].side==0 else (Vector2(176,40)+Vector2(float(offset_values[0]),float(offset_values[1]))) if bool(step.get("double_barrier",false)) else Vector2(72,80) if context.actors[context.attacker_id].side==0 else Vector2(176,40)
				destination = origin
			if bool(step.get("source_actor_head",false)):
				var selected := context.resolve("attacker")[0]
				var bounds: Vector2 = selected.sprite.get_rect().size
				origin += Vector2(bounds.x/2.0*(1 if selected.side==0 else -1),-bounds.y/2.0)
				destination = origin
			if bool(step.get("partner_average",false)):
				origin = _center(context,"source_attacker_and_partner_visual_center" if str(step.selector)=="attacker" else "source_target_and_partner_visual_center",str(step.get("partner_average_anchor","origin")))+Vector2(float(offset_values[0])*offset_direction,float(offset_values[1]))
				destination = origin
			if str(step.get("mode",""))=="fog_orbit" and context.resolve("target")[0].side==0:
				origin.y += 8
				destination.y += 8
			if step.has("clamp_top"):
				origin.y = maxf(origin.y,float(step.clamp_top))
				destination.y = origin.y
			if bool(step.get("seeded_kick",false)):
				var selected := context.resolve(str(step.selector))[0]
				var random := RandomNumberGenerator.new()
				random.seed = context.seed_value+owner.elapsed_ticks*977
				var bounds: Vector2 = selected.sprite.get_rect().size
				var scatter := Vector2(random.randi_range(0,maxi(0,int(bounds.y/2)-1)),random.randi_range(0,maxi(0,int(bounds.x/4)-1)))
				if random.randi()&1:scatter.x *= -1
				if random.randi()&1:scatter.y *= -1
				if selected.side==0:scatter.y -= 16
				origin += scatter
				destination = origin
			if str(step.get("mode","")) in ["hail","hail_impact"]:
				step = step.duplicate(true)
				var landing := _hail_landing(step,context)
				if str(step.mode)=="hail":
					origin = landing.origin
					destination = landing.target
					ticks = int(landing.ticks)
				else:
					if context.resolve("actor:%d" % int(step.hail_actor)).is_empty():continue
					origin = landing.target
					destination = landing.target
					step.spawn_delay = int(step.spawn_delay)+int(landing.ticks)
			if step.has("from_selector"):
				var sources := context.resolve(str(step.from_selector))
				var targets := context.resolve("targets" if str(step.to_selector) in ["targets_center","source_target_and_partner_visual_center"] else str(step.to_selector))
				if sources.is_empty() or targets.is_empty(): continue
				origin = sources[0].anchor(context.field,str(step.get("from_anchor","center"))) + Vector2(float(offset_values[0])*offset_direction,float(offset_values[1]))
				var end_offset: Array = step.get("end_offset",[0,0])
				if str(step.to_selector)=="source_target_position_pair_body":
					destination=source_pair_body.point+Vector2(float(end_offset[0])*direction,float(end_offset[1]))
				else:
					destination = (_center(context,"targets" if str(step.to_selector)=="targets_center" else "source_target_and_partner_visual_center",str(step.get("to_anchor","center"))) if str(step.to_selector) in ["targets_center","source_target_and_partner_visual_center"] else targets[0].anchor(context.field,str(step.get("to_anchor","center")))) + Vector2(float(end_offset[0])*direction,float(end_offset[1]))
				if bool(step.get("mirror_vertical_by_side",false)) and context.actors[context.attacker_id].side!=0:
					origin.y -= float(offset_values[1])*2
					destination.y -= float(end_offset[1])*2
				if bool(step.get("source_absolute_offsets",false)):
					origin = sources[0].anchor(context.field)+Vector2(float(offset_values[0]),float(offset_values[1]))
					destination = targets[0].anchor(context.field)+Vector2(float(end_offset[0]),float(end_offset[1]))
				if bool(step.get("source_unmirrored_delta",false)):
					var source_args: Array = step.source_args
					destination = origin+Vector2(float(source_args[2]),float(source_args[3]))
				if bool(step.get("mirror_vertical_by_target",false)) and context.resolve("target")[0].side==0:
					origin.y -= float(offset_values[1])*2
			elif step.has("travel"):
				var travel: Array = step.travel
				destination = origin + Vector2(float(travel[0])*direction,float(travel[1]))
		if kind == "source_particle" and bool(step.get("seeded_scatter",false)):
			var rng := RandomNumberGenerator.new()
			rng.seed = context.seed_value + owner.elapsed_ticks*977 + owner.get_child_count()*37
			var x := int(rng.randi()) & 31
			var y := int(rng.randi()) & 31
			destination += Vector2(16-x if x>16 else x,16-y if y>16 else y)
		if kind=="source_particle" and bool(step.get("seeded_splash",false)):
			step = step.duplicate(true)
			var rng := RandomNumberGenerator.new()
			rng.seed = context.seed_value+owner.elapsed_ticks*977+owner.get_child_count()*37
			var vx := (rng.randi()&255)|256
			var vy := rng.randi()&511
			if vy>255:vy = 256-vy
			step.scatter_velocity = [(-vx if vx&1 else vx),vy]
		if kind == "source_particle" and str(step.get("mode","")) == "snow_swirl":
			step = step.duplicate(true)
			var direction: Vector2 = (destination-origin).normalized()
			if direction.is_zero_approx():direction = Vector2(1 if context.actors[context.attacker_id].side==0 else -1,0)
			var entrance: Vector2 = origin-direction*90
			step.arrival_ticks = maxi(1,int(ceil(entrance.distance_to(destination)/float(step.speed))))
			step.snow_direction = [direction.x,direction.y]
			ticks = int(step.arrival_ticks)+32+int(ceil(context.field_size.length()/float(step.speed)))
		if kind == "source_particle":
			var pose := BattlePlantActor.anchor_pose(step, context, origin, destination)
			origin = pose.origin
			destination = pose.destination
			pose = BattleSoundOwnership.anchor_pose(step, context, origin, destination)
			origin = pose.origin
			destination = pose.destination
			pose = BattleElectricContract.anchor_pose(step,context,origin,destination)
			origin = pose.origin
			destination = pose.destination
			pose = BattleChargeContract.anchor_pose(step,context,origin,destination)
			origin = pose.origin
			destination = pose.destination
		if kind in ["projectile", "beam"]:
			var sources := context.resolve(str(step.get("from", "attacker")))
			if sources.is_empty():
				continue
			origin = sources[0].anchor(context.field)
		var node: Node2D
		var literal_texture: Texture2D=dizzy_literal.get("texture") as Texture2D
		var texture_path: String = "" if literal_texture!=null else step.get("texture", "")
		if literal_texture!=null or (not texture_path.is_empty() and ResourceLoader.exists(texture_path)):
			var textured := Sprite2D.new()
			textured.texture = literal_texture if literal_texture!=null else load(texture_path)
			textured.modulate = tint
			textured.scale = Vector2.ONE * _sheet_scale_factor(step, owner, kind)
			if bool(step.get("recolor", false)):
				var material := ShaderMaterial.new()
				material.shader = Recolor
				material.set_shader_parameter("tint", tint)
				textured.material = material
			var frames := int(step.get("frames", 1))
			textured.vframes = frames
			if step.has("frame_commands"):
				textured.vframes = 1
				textured.region_enabled = true
				var size: Array = step.get("frame_size", [32, 32])
				textured.region_rect = Rect2(0, 0, size[0], size[1])
			node = textured
		else:
			node = Visual.new()
			node.kind = "ring" if kind == "projectile" else kind
			node.color = tint
			node.extent = destination - origin if kind == "beam" else context.field_size
			var random := RandomNumberGenerator.new()
			random.seed = context.seed_value
			for i in 48:
				node.points.append(Vector2(random.randf_range(0, context.field_size.x), random.randf_range(0, context.field_size.y)))
		if kind == "source_surf":
			var surf := node as Sprite2D
			surf.centered = false
			surf.scale = context.field_size / surf.texture.get_size()
			var material := ShaderMaterial.new()
			material.shader = load("res://scripts/battle/animations/sequence/source_surf.gdshader")
			material.set_shader_parameter("side",float(context.actors[context.attacker_id].side))
			surf.material = material
		if kind == "source_particle":
			step = step.duplicate(true)
			if str(step.get("phase_source","")) == "arg7":
				step["source_phase"] = (mini(owner.elapsed_ticks-owner._source_phase_started,owner._source_phase_duration)*3)&255
		owner.add_child(node)
		node.position = origin
		node.z_index = 10 if kind == "darken" else 20
		if step.has("source_z_index"):node.z_index = int(step.source_z_index)
		tracks.append({"kind": kind, "age": -int(step.get("spawn_delay",0)), "ticks": ticks, "node": node, "origin": origin, "destination": destination, "arc": float(step.get("arc", 0)), "phase": float(step.get("phase", 0)), "arrival_marker": str(step.get("arrival_marker", "")), "settings": step.duplicate(true), "source_side": context.actors[context.attacker_id].side if context.actors.has(context.attacker_id) else 0,"field_size":context.field_size,"ally_crossing":context.actors.has(context.attacker_id) and not context.resolve("target").is_empty() and context.actors[context.attacker_id].side==context.resolve("target")[0].side})
		BattleSourcePriority.initialize(tracks.back(),context,owner)
		LegacyImpact.attach(tracks.back(),context,owner,source_dispatch_step,stinger_packet.get("admission",{}))
		KarateTranslation.initialize(tracks.back(),context,owner,source_dispatch_step)
		CuttingSlice.initialize(tracks.back(),context,owner)
		if bool(step.get("source_ingrain_obj_blend",false)):BattleCounterSelected._blend_node(node,owner)
		if kind == "source_particle":BattlePostPsychic.initialize_particle(tracks.back(),context,owner)
		if kind == "source_particle":BattleGhostContract.initialize_particle(tracks.back(),context,owner)
		if kind == "source_particle":BattleElectricContract.initialize_particle(tracks.back(),context,owner)
		if kind == "source_particle":BattleChargeContract.initialize_particle(tracks.back(),context,owner)
		if kind == "source_particle":BattleStateProps.initialize(tracks.back(),context,owner)
		if kind == "source_particle":BattleContactSelected.initialize(tracks.back(),context)
		if swords_packet.has("admission"):LegacyImpact.Swords.attach(tracks.back(),context,owner,swords_packet.admission)
		if spinning_packet.has("admission"):LegacyImpact.Spinning.attach(tracks.back(),context,owner,spinning_packet.admission)
		if not source_anchor_operands.is_empty():
			# Later source commands can initialize actor motion in this same tick.
			# Preserve the actual visual operands at spawn for evidence, rather
			# than reconstructing them from the end-of-tick actor pose.
			tracks[-1]["source_anchor_operands"] = source_anchor_operands.duplicate(true)
	for track in tracks:
		update_track(track, context)
		if owner.definition.key in ["ruby:move/61","ruby:move/145","ruby:move/250"]:PairComposition.attach_bubble(track,source_dispatch_step,context,owner)
		if owner.definition.key=="ruby:move/53" and track.kind=="source_particle" and track.settings.get("mode","")=="source_beam" and track.settings.get("source_template","")=="gBattleAnimSpriteTemplate_83D9268":
			PairComposition.sync(owner,track.node)
	return tracks

static func update_track(track: Dictionary, context: BattleAnimationContext) -> void:
	if track.has("source_karate_translation"):
		KarateTranslation.update(track,context)
		return
	if track.has("source_cutting_slice"):
		CuttingSlice.update(track)
		return
	if track.has("update") and track.update is Callable:
		track.update.call(track, context)
		return
	var progress := clampf(float(track.age) / float(track.ticks), 0, 1)
	if not track.has("node") or not is_instance_valid(track.node):
		return
	var node: Node2D = track.node
	if track.kind in ["source_refresh","source_shadow_clone"]:
		BattlePostPsychic.update_clone(track)
		return
	if track.kind == "source_surf":
		node.material.set_shader_parameter("age",float(track.age))
		return
	if track.kind == "source_particle":
		BattleSourceParticle.update(track)
		return
	if track.kind == "projectile":
		node.position = track.origin.lerp(track.destination, progress)
		node.position.y += sin(progress * TAU + track.phase) * float(track.arc)
	if track.kind == "metallic_sweep":
		node.material.set_shader_parameter("progress", progress)
		return
	if track.kind == "afterimage":
		if track.age < 0:
			return
		node.modulate.a = 0.4
		return
	if node is Sprite2D:
		var settings: Dictionary = track.get("settings", {})
		if settings.has("frame_commands"):
			var commands: Array = settings.frame_commands
			if settings.has("side_frames"):
				commands = settings.side_frames.get("player" if track.source_side == 0 else "opponent", commands)
			var remaining := int(track.age) - 1
			var selected: Dictionary = commands.back()
			for command in commands:
				selected = command
				if remaining < int(command.ticks):
					break
				remaining -= int(command.ticks)
			if settings.has("frame_program"):
				var program: Array = settings.frame_program
				if settings.has("side_frame_programs"):
					program = settings.side_frame_programs["player" if track.source_side==0 else "opponent"]
				selected = BattleSourceCommandProgram.evaluate(program,maxi(0,int(track.age)-1)).frame
			var tile := int(selected.tile)
			var tiles_per_row: int = node.texture.get_width() / 8
			node.region_rect.position = Vector2((tile % tiles_per_row) * 8, (tile / tiles_per_row) * 8)
			if settings.has("frame_rects"):
				var rect: Array = settings.frame_rects[str(tile)]
				node.region_rect = Rect2(rect[0],rect[1],rect[2],rect[3])
			node.flip_h = bool(selected.get("flip_h", false)) != bool(settings.get("flip_h", false))
			node.flip_v = bool(selected.get("flip_v", false)) != bool(settings.get("flip_v", false))
			if settings.has("travel"):
				var travel: Array = settings.travel
				var travel_progress := clampf((float(track.age) - float(settings.get("travel_delay", 0))) / float(settings.get("travel_ticks", track.ticks)), 0, 1)
				node.position = track.origin + Vector2(travel[0], travel[1]) * travel_progress
			if int(settings.get("blink_after", -1)) >= 0 and track.age >= settings.blink_after:
				node.visible = (int(track.age) / 2) % 2 == 0
		elif node.vframes > 1:
			# Ruby ember loops frames 1,2,3 (32x32), not the unused first frame.
			node.frame = 1 + (int(track.age) / 2) % mini(3, node.vframes - 1)
		node.modulate.a = sin(progress * PI) if track.kind == "impact" else 1.0
	else:
		node.progress = progress
		node.queue_redraw()

static func _center(context: BattleAnimationContext, selector: String, anchor: String) -> Vector2:
	var actors := context.resolve(selector)
	var value := Vector2.ZERO
	for actor in actors: value += actor.anchor(context.field,anchor)
	return value/maxi(1,actors.size())

static func _hail_landing(step: Dictionary, context: BattleAnimationContext) -> Dictionary:
	# Shared absolute geometry: impact belongs to the shard, not attacker facing.
	var target := Vector2(float(step.hail_target[0]),float(step.hail_target[1]))
	var candidates := context.resolve("actor:%d" % int(step.hail_actor))
	if int(step.hail_variant)!=2 and not candidates.is_empty():
		target = candidates[0].anchor(context.field)+Vector2.ONE*(-6 if int(step.hail_variant)==0 else 6)
	return {"target":target,"origin":Vector2(target.x-(target.y+8)/2,-8),"ticks":maxi(1,int(ceil((target.y+8)/8.0)))}

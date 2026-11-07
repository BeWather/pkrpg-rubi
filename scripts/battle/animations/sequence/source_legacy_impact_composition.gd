extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

const NightShade=preload("res://scripts/battle/animations/sequence/source_night_shade_composition.gd")
const Confuse=preload("res://scripts/battle/animations/sequence/source_confuse_ray_composition.gd")
const Dizzy=preload("res://scripts/battle/animations/sequence/source_dizzy_punch_composition.gd")
const Crab=preload("res://scripts/battle/animations/sequence/source_crabhammer_composition.gd")
const Hydro=preload("res://scripts/battle/animations/sequence/source_hydro_cannon_composition.gd")
const Frenzy=preload("res://scripts/battle/animations/sequence/source_frenzy_plant_composition.gd")
const Blizzard=preload("res://scripts/battle/animations/sequence/source_blizzard_composition.gd")
const Waterfall=preload("res://scripts/battle/animations/sequence/source_waterfall_composition.gd")
const Petal=preload("res://scripts/battle/animations/sequence/source_petal_composition.gd")
const Snatch=preload("res://scripts/battle/animations/sequence/source_snatch.gd")
const Stockpile=preload("res://scripts/battle/animations/sequence/source_stockpile_composition.gd")
const Solar=preload("res://scripts/battle/animations/sequence/source_solar_beam_composition.gd")
const Secret=preload("res://scripts/battle/animations/sequence/source_secret_power_composition.gd")
const Musical=preload("res://scripts/battle/animations/sequence/source_musical_composition.gd")
const Swords=preload("res://scripts/battle/animations/sequence/source_swords_composition.gd")
const Spinning=preload("res://scripts/battle/animations/sequence/source_spinning_strike_composition.gd")
const MetallicTail=preload("res://scripts/battle/animations/sequence/source_metallic_tail_composition.gd")
const Stinger=preload("res://scripts/battle/animations/sequence/source_stinger_composition.gd")
const Wing=preload("res://scripts/battle/animations/sequence/source_wing_composition.gd")
const CrossImpact=preload("res://scripts/battle/animations/sequence/source_cross_impact_composition.gd")
const JumpKick=preload("res://scripts/battle/animations/sequence/source_jump_kick_composition.gd")
const AgilityAerial=preload("res://scripts/battle/animations/sequence/source_agility_aerial_composition.gd")
## Finite canonical ordinary composition; no global alpha or custom-program takeover.
const SITES := {
	6447:["ruby:move/2","gBattleAnimSpriteTemplate_83D9F78","sub_80D902C","gOamData_837DF34",0,2,[-16,0,0,0,10,1,3,0]],
	6450:["ruby:move/2","gBasicHitSplatSpriteTemplate","sub_80E27A0","gOamData_837E0B4",1,3,[0,0,1,2]],
	1497:["ruby:move/21","gBattleAnimSpriteTemplate_83D69DC","sub_80CC884","gOamData_837DF34",0,2,[0,0]],
	1500:["ruby:move/21","gBasicHitSplatSpriteTemplate","sub_80E27A0","gOamData_837E0B4",1,3,[0,0,1,1]],
}
const COMMANDS := {
	6443:["ruby:move/2","monbg",[3],"monbg ANIM_BATTLER_DEF_PARTNER"],6444:["ruby:move/2","monbgprio_28",[1],"monbgprio_28 1"],
	6445:["ruby:move/2","setalpha",[12,8],"setalpha 12, 8"],6453:["ruby:move/2","clearmonbg",[3],"clearmonbg ANIM_BATTLER_DEF_PARTNER"],6454:["ruby:move/2","blendoff",[],"blendoff"],
	1492:["ruby:move/21","monbg",[1],"monbg ANIM_BATTLER_TARGET"],1493:["ruby:move/21","setalpha",[12,8],"setalpha 12, 8"],
	1509:["ruby:move/21","clearmonbg",[1],"clearmonbg ANIM_BATTLER_TARGET"],1510:["ruby:move/21","blendoff",[],"blendoff"],
}
const REMAINDER_SCRIPTS := {"ruby:move/55":"Move_WATER_GUN","ruby:move/58":"Move_ICE_BEAM","ruby:move/10":"Move_SCRATCH","ruby:move/11":"Move_VICE_GRIP","ruby:move/15":"Move_CUT","ruby:move/34":"Move_BODY_SLAM","ruby:move/43":"Move_LEER","ruby:move/70":"Move_STRENGTH","ruby:move/98":"Move_QUICK_ATTACK","ruby:move/306":"Move_CRUSH_CLAW"}
const REMAINDER_COMMANDS := {
	560:["ruby:move/70","monbg",[3],"monbg ANIM_BATTLER_DEF_PARTNER"],
	561:["ruby:move/70","setalpha",[12,8],"setalpha 12, 8"],
	580:["ruby:move/70","clearmonbg",[3],"clearmonbg ANIM_BATTLER_DEF_PARTNER"],
	581:["ruby:move/70","blendoff",[],"blendoff"],
	600:["ruby:move/34","monbg",[3],"monbg ANIM_BATTLER_DEF_PARTNER"],
	601:["ruby:move/34","setalpha",[12,8],"setalpha 12, 8"],
	620:["ruby:move/34","clearmonbg",[3],"clearmonbg ANIM_BATTLER_DEF_PARTNER"],
	621:["ruby:move/34","blendoff",[],"blendoff"],
	1204:["ruby:move/15","monbg",[1],"monbg ANIM_BATTLER_TARGET"],
	1205:["ruby:move/15","setalpha",[12,8],"setalpha 12, 8"],
	1211:["ruby:move/15","clearmonbg",[1],"clearmonbg ANIM_BATTLER_TARGET"],
	1212:["ruby:move/15","blendoff",[],"blendoff"],
	1843:["ruby:move/11","monbg",[3],"monbg ANIM_BATTLER_DEF_PARTNER"],
	1844:["ruby:move/11","setalpha",[12,8],"setalpha 12, 8"],
	1852:["ruby:move/11","clearmonbg",[3],"clearmonbg ANIM_BATTLER_DEF_PARTNER"],
	1853:["ruby:move/11","blendoff",[],"blendoff"],
	2726:["ruby:move/98","monbg",[2],"monbg ANIM_BATTLER_ATK_PARTNER"],
	2727:["ruby:move/98","setalpha",[12,8],"setalpha 12, 8"],
	2736:["ruby:move/98","clearmonbg",[2],"clearmonbg ANIM_BATTLER_ATK_PARTNER"],
	2737:["ruby:move/98","blendoff",[],"blendoff"],
	4110:["ruby:move/306","monbg",[1],"monbg ANIM_BATTLER_TARGET"],
	4111:["ruby:move/306","setalpha",[12,8],"setalpha 12, 8"],
	4124:["ruby:move/306","blendoff",[],"blendoff"],
	4125:["ruby:move/306","clearmonbg",[1],"clearmonbg ANIM_BATTLER_TARGET"],
	4924:["ruby:move/10","monbg",[1],"monbg ANIM_BATTLER_TARGET"],
	4925:["ruby:move/10","setalpha",[12,8],"setalpha 12, 8"],
	4930:["ruby:move/10","clearmonbg",[1],"clearmonbg ANIM_BATTLER_TARGET"],
	4931:["ruby:move/10","blendoff",[],"blendoff"],
	5352:["ruby:move/58","monbg",[1],"monbg ANIM_BATTLER_TARGET"],
	5353:["ruby:move/58","monbgprio_28",[1],"monbgprio_28 1"],
	5354:["ruby:move/58","setalpha",[12,8],"setalpha 12, 8"],
	5385:["ruby:move/58","clearmonbg",[1],"clearmonbg ANIM_BATTLER_TARGET"],
	5386:["ruby:move/58","blendoff",[],"blendoff"],
	6242:["ruby:move/55","monbg",[3],"monbg ANIM_BATTLER_DEF_PARTNER"],
	6243:["ruby:move/55","monbgprio_28",[1],"monbgprio_28 1"],
	6244:["ruby:move/55","setalpha",[12,8],"setalpha 12, 8"],
	6259:["ruby:move/55","clearmonbg",[3],"clearmonbg ANIM_BATTLER_DEF_PARTNER"],
	6260:["ruby:move/55","blendoff",[],"blendoff"],
	6974:["ruby:move/43","monbg",[0],"monbg ANIM_BATTLER_ATTACKER"],
	6975:["ruby:move/43","monbgprio_28",[0],"monbgprio_28 0"],
	6976:["ruby:move/43","setalpha",[8,8],"setalpha 8, 8"],
	6985:["ruby:move/43","clearmonbg",[0],"clearmonbg ANIM_BATTLER_ATTACKER"],
	6986:["ruby:move/43","blendoff",[],"blendoff"],
}
const REMAINDER_SITES := {
	570:["ruby:move/70","gBasicHitSplatSpriteTemplate","sub_80E27A0","gOamData_837E0B4",1,3,[16,12,1,1],"attacker","ANIM_BATTLER_ATTACKER",1],
	573:["ruby:move/70","gBasicHitSplatSpriteTemplate","sub_80E27A0","gOamData_837E0B4",1,3,[-16,-12,1,1],"attacker","ANIM_BATTLER_ATTACKER",1],
	576:["ruby:move/70","gBasicHitSplatSpriteTemplate","sub_80E27A0","gOamData_837E0B4",1,3,[3,4,1,1],"attacker","ANIM_BATTLER_ATTACKER",1],
	608:["ruby:move/34","gBasicHitSplatSpriteTemplate","sub_80E27A0","gOamData_837E0B4",1,4,[-10,0,1,0],"attacker","ANIM_BATTLER_ATTACKER",1],
	1207:["ruby:move/15","gCuttingSliceSpriteTemplate","AnimCuttingSlice","gOamData_837E054",1,2,[40,-32,0],"attacker","ANIM_BATTLER_ATTACKER",1],
	1846:["ruby:move/11","gBattleAnimSpriteTemplate_83D769C","sub_80D0178","gOamData_837E054",1,2,[0],"attacker","ANIM_BATTLER_ATTACKER",1],
	1847:["ruby:move/11","gBattleAnimSpriteTemplate_83D769C","sub_80D0178","gOamData_837E054",1,2,[1],"attacker","ANIM_BATTLER_ATTACKER",1],
	1849:["ruby:move/11","gBasicHitSplatSpriteTemplate","sub_80E27A0","gOamData_837E0B4",1,1,[0,0,1,2],"attacker","ANIM_BATTLER_ATTACKER",1],
	2733:["ruby:move/98","gBasicHitSplatSpriteTemplate","sub_80E27A0","gOamData_837E0B4",1,4,[0,0,1,1],"target","ANIM_BATTLER_TARGET",1],
	4115:["ruby:move/306","gBattleAnimSpriteTemplate_83DB288","sub_80E0A10","gOamData_837DF34",0,2,[-10,-10,0],"target","ANIM_BATTLER_TARGET",1],
	4116:["ruby:move/306","gBattleAnimSpriteTemplate_83DB288","sub_80E0A10","gOamData_837DF34",0,2,[-10,10,0],"target","ANIM_BATTLER_TARGET",1],
	4119:["ruby:move/306","gBattleAnimSpriteTemplate_83DB288","sub_80E0A10","gOamData_837DF34",0,2,[10,-10,1],"target","ANIM_BATTLER_TARGET",1],
	4120:["ruby:move/306","gBattleAnimSpriteTemplate_83DB288","sub_80E0A10","gOamData_837DF34",0,2,[10,10,1],"target","ANIM_BATTLER_TARGET",1],
	4927:["ruby:move/10","gBattleAnimSpriteTemplate_8402180","sub_80793C4","gOamData_837E054",1,2,[0,0,1,0],"attacker","ANIM_BATTLER_ATTACKER",1],
	5359:["ruby:move/58","gIceBeamOuterParticleSpriteTemplate","AnimIceBeamParticle","gOamData_837E044",1,2,[20,12,0,12,20],"attacker","ANIM_BATTLER_ATTACKER",1],
	5360:["ruby:move/58","gIceBeamOuterParticleSpriteTemplate","AnimIceBeamParticle","gOamData_837E044",1,2,[20,-12,0,-12,20],"attacker","ANIM_BATTLER_ATTACKER",1],
	5375:["ruby:move/58","IceBeamCenterParticleSpriteTemplate","AnimIceBeamParticle","gOamData_837E0E4",1,2,[20,0,0,0,11],"attacker","ANIM_BATTLER_ATTACKER",1],
	5377:["ruby:move/58","IceBeamCenterParticleSpriteTemplate","AnimIceBeamParticle","gOamData_837E0E4",1,2,[20,0,0,0,11],"attacker","ANIM_BATTLER_ATTACKER",1],
	5389:["ruby:move/58","gIceBeamOuterParticleSpriteTemplate","AnimIceBeamParticle","gOamData_837E044",1,2,[20,12,0,12,20],"attacker","ANIM_BATTLER_ATTACKER",11],
	5390:["ruby:move/58","gIceBeamOuterParticleSpriteTemplate","AnimIceBeamParticle","gOamData_837E044",1,2,[20,-12,0,-12,20],"attacker","ANIM_BATTLER_ATTACKER",11],
	5391:["ruby:move/58","IceBeamCenterParticleSpriteTemplate","AnimIceBeamParticle","gOamData_837E0E4",1,2,[20,0,0,0,11],"attacker","ANIM_BATTLER_ATTACKER",11],
	6245:["ruby:move/55","gBattleAnimSpriteTemplate_83D9318","sub_80794A8","gOamData_837E04C",1,2,[20,0,0,0,40,-25],"attacker","ANIM_BATTLER_ATTACKER",1],
	6249:["ruby:move/55","gBattleAnimSpriteTemplate_83DB4D8","sub_80E27A0","gOamData_837E0B4",1,4,[0,0,1,2],"attacker","ANIM_BATTLER_ATTACKER",1],
	6250:["ruby:move/55","gBattleAnimSpriteTemplate_83D9330","sub_80D37FC","gOamData_837E10C",1,2,[0,-15,0,15,55],"attacker","ANIM_BATTLER_ATTACKER",1],
	6253:["ruby:move/55","gBattleAnimSpriteTemplate_83D9330","sub_80D37FC","gOamData_837E10C",1,2,[15,-20,0,15,50],"attacker","ANIM_BATTLER_ATTACKER",1],
	6256:["ruby:move/55","gBattleAnimSpriteTemplate_83D9330","sub_80D37FC","gOamData_837E10C",1,2,[-15,-10,0,10,45],"attacker","ANIM_BATTLER_ATTACKER",1],
	6978:["ruby:move/43","gBattleAnimSpriteTemplate_84022B0","sub_812C80C","gOamData_837DF34",0,2,[24,-12],"attacker","ANIM_BATTLER_ATTACKER",1],
	9932:["ruby:move/58","gLargeIceEffectParticleSpriteTemplate","AnimIceEffectParticle","gOamData_837E0E4",1,2,[-10,-10,0],"target","ANIM_BATTLER_TARGET",1],
	9935:["ruby:move/58","gSmallIceEffectParticleSpriteTemplate","AnimIceEffectParticle","gOamData_837E0A4",1,2,[10,20,0],"target","ANIM_BATTLER_TARGET",1],
	9938:["ruby:move/58","gLargeIceEffectParticleSpriteTemplate","AnimIceEffectParticle","gOamData_837E0E4",1,2,[-5,10,0],"target","ANIM_BATTLER_TARGET",1],
	9941:["ruby:move/58","gSmallIceEffectParticleSpriteTemplate","AnimIceEffectParticle","gOamData_837E0A4",1,2,[17,-12,0],"target","ANIM_BATTLER_TARGET",1],
	9944:["ruby:move/58","gSmallIceEffectParticleSpriteTemplate","AnimIceEffectParticle","gOamData_837E0A4",1,2,[-15,15,0],"target","ANIM_BATTLER_TARGET",1],
	9947:["ruby:move/58","gSmallIceEffectParticleSpriteTemplate","AnimIceEffectParticle","gOamData_837E0A4",1,2,[0,0,0],"target","ANIM_BATTLER_TARGET",1],
	9950:["ruby:move/58","gLargeIceEffectParticleSpriteTemplate","AnimIceEffectParticle","gOamData_837E0E4",1,2,[20,2,0],"target","ANIM_BATTLER_TARGET",1],
}

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floor(float(value))

static func _operands(value: Variant, expected: Array) -> bool:
	if not value is Array or value.size()!=expected.size():return false
	for index: int in expected.size():
		if not _integer(value[index]) or int(value[index])!=int(expected[index]):return false
	return true

static func _canonical(owner: Node2D) -> bool:
	if not owner is BattleAnimationSequenceRunner or owner.definition==null or not BattleAnimationSequenceRegistry.is_builtin_source_definition(owner.definition):return false
	var key: String=owner.definition.key
	var script: String=REMAINDER_SCRIPTS.get(key,"Move_KARATE_CHOP" if key=="ruby:move/2" else "Move_SLAM" if key=="ruby:move/21" else "")
	return not script.is_empty() and owner.definition.source_script==script

static func create(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Array[Dictionary]:
	var night: Variant=NightShade.effect(step,context,owner,"source_legacy_impact_command")
	if night!=null:
		var admitted_night: Array[Dictionary]=[];admitted_night.assign(night);return admitted_night
	var confuse: Variant=Confuse.effect(step,context,owner,"source_legacy_impact_command")
	if confuse!=null:
		var admitted_confuse: Array[Dictionary]=[];admitted_confuse.assign(confuse);return admitted_confuse
	var dizzy: Variant=Dizzy.effect(step,context,owner,"source_legacy_impact_command")
	if dizzy!=null:
		var admitted: Array[Dictionary]=[];admitted.assign(dizzy);return admitted
	if Crab.matches(owner) or owner.has_meta(Crab.STATE):
		var crab_tracks: Array[Dictionary]=[];crab_tracks.assign(Crab.effect(step,context,owner,"source_legacy_impact_command"));return crab_tracks
	if Hydro.matches(owner) or owner.has_meta(Hydro.STATE):
		var hydro_tracks: Array[Dictionary]=[];hydro_tracks.assign(Hydro.effect(step,context,owner,"source_legacy_impact_command"));return hydro_tracks
	if Frenzy.matches(owner):
		var frenzy_tracks: Array[Dictionary]=[];frenzy_tracks.assign(Frenzy.effect(step,context,owner,"source_legacy_impact_command"));return frenzy_tracks
	if Blizzard.matches(owner):
		var blizzard_tracks: Array[Dictionary]=[];blizzard_tracks.assign(Blizzard.effect(step,context,owner,"source_legacy_impact_command"));return blizzard_tracks
	if Waterfall.matches(owner):
		var result: Array[Dictionary]=[];result.assign(Waterfall.effect(step,context,owner,"source_legacy_impact_command"));return result
	if Petal.matches(owner):
		var result: Array[Dictionary]=[];result.assign(Petal.effect(step,context,owner,"source_legacy_impact_command"));return result
	if Solar.matches(owner):return Solar.create(step,context,owner)
	if Secret.matches(owner):return Secret.create(step,context,owner)
	if Musical.matches(owner):return Musical.create(step,context,owner)
	if Swords.matches(owner):return Swords.create(step,context,owner)
	if Spinning.matches(owner):return Spinning.create(step,context,owner)
	if MetallicTail.matches(owner):return MetallicTail.create(step,context,owner)
	if Stinger.matches(owner):return Stinger.create(step,context,owner)
	if Wing.matches(owner):return Wing.create(step,context,owner)
	if CrossImpact.matches(owner):return CrossImpact.create(step,context,owner)
	if JumpKick.matches(owner):return JumpKick.create(step,context,owner)
	if AgilityAerial.matches(owner):return AgilityAerial.create(step,context,owner)
	if not _canonical(owner) or not _integer(step.get("source_line")):return []
	var expected: Array=COMMANDS.get(int(step.get("source_line",-1)),REMAINDER_COMMANDS.get(int(step.get("source_line",-1)),[]))
	if expected.is_empty() or owner.definition.key!=expected[0] or step.get("mode")!=expected[1] or not _operands(step.get("source_args"),expected[2]) or step.get("source_command")!=expected[3] or step.get("source_script")!=owner.definition.source_script:return []
	var commands: Array=owner.get_meta("source_legacy_impact_commands",[]);commands.append(int(step.source_line));owner.set_meta("source_legacy_impact_commands",commands)
	var backgrounds: Array=owner.get_meta("source_legacy_impact_backgrounds",[])
	match str(step.mode):
		"setalpha","blendoff":
			owner.set_meta("source_legacy_impact_alpha",step.source_args.duplicate() if step.mode=="setalpha" else [16,0])
			for item: Dictionary in owner.get_meta("source_legacy_impact_objects",[]):
				if is_instance_valid(item.node) and item.material!=null and item.node.material==item.material:
					if step.mode=="blendoff":item.node.material=item.previous
					elif REMAINDER_SCRIPTS.has(owner.definition.key):
						item.material.set_shader_parameter("eva",float(step.source_args[0])/16)
						item.material.set_shader_parameter("evb",float(step.source_args[1])/16)
			return []
		"monbgprio_28":
			var targets:=context.resolve("attacker" if int(step.source_args[0])==0 else "target")
			if not context.contest and not targets.is_empty() and context.source_position(targets[0].id) in [0,3]:owner.set_meta("source_legacy_impact_promoted",true)
			_order(owner,context);return []
		"clearmonbg":
			for track: Dictionary in backgrounds:
				for clone: Dictionary in track.clones:clone.actor.apply_source_state("hidden",false)
				track.ticks=int(track.age)+2
			return []
	var selected:=context.resolve("attacker" if int(step.source_args[0]) in [0,2] else "target")
	if selected.is_empty():return []
	var primary: BattleAnimationActor=selected[0]
	var position: int=context.source_position(primary.id)
	var track: Dictionary={"kind":"source_legacy_impact_bg","domain":"maintenance","owner":owner,"age":0,"ticks":4096,"clones":[],"update":_update}
	for actor: BattleAnimationActor in context.actors.values():
		if actor!=primary and (position<0 or context.source_position(actor.id)!=(position^2)):continue
		if not actor.is_present() or not actor.sprite.is_visible_in_tree() or (context.contest and actor.id!=context.attacker_id):continue
		var node:=BattleIdentityCopy.clone_sprite(actor,owner);owner.add_child(node)
		track.clones.append({"actor":actor,"node":node,"bg_plane":1 if context.contest or context.source_position(actor.id) in [1,2] else 2})
		actor.apply_source_state("hidden",true)
	if track.clones.is_empty():return []
	track.cleanup=_cleanup.bind(track);backgrounds.append(track);owner.set_meta("source_legacy_impact_backgrounds",backgrounds)
	_update(track,context);_order(owner,context);return [track]

static func attach(track: Dictionary, context: BattleAnimationContext, owner: Node2D,incoming: Dictionary={},stinger_record: Dictionary={}) -> void:
	if Petal.matches(owner):return
	if Secret.matches(owner):return
	if Swords.matches(owner):return
	if Spinning.matches(owner):return
	if MetallicTail.matches(owner):MetallicTail.attach(track,context,owner,incoming);return
	if Stinger.matches(owner):Stinger.attach(track,context,owner,incoming,stinger_record);return
	if Wing.matches(owner):Wing.attach(track,context,owner,incoming);return
	if CrossImpact.matches(owner):CrossImpact.attach(track,context,owner,incoming);return
	if JumpKick.matches(owner):JumpKick.attach_impact(track,context,owner,incoming);return
	if AgilityAerial.matches(owner):AgilityAerial.attach(track,context,owner,incoming);return
	if not _canonical(owner) or track.kind not in ["sheet","source_particle"]:return
	if REMAINDER_SCRIPTS.has(owner.definition.key):
		_attach_remainder(track,context,owner);return
	var step: Dictionary=track.settings;var d: Dictionary=step.get("source_legacy_composition",{})
	if not _integer(step.get("source_line")):return
	for name: String in ["source_line","obj_mode","priority","raw_offset"]:
		if not _integer(d.get(name)):return
	var expected: Array=SITES.get(int(step.get("source_line",-1)),[])
	if expected.is_empty() or owner.definition.key!=expected[0] or step.get("source_template")!=expected[1] or step.get("source_callback")!=expected[2]:return
	if d.get("script")!=owner.definition.source_script or d.get("source_line")!=step.source_line or d.get("template")!=expected[1] or d.get("callback")!=expected[2] or d.get("oam")!=expected[3] or d.get("obj_mode")!=expected[4] or d.get("priority")!=2 or d.get("basis")!="attacker" or d.get("raw_role")!="ANIM_BATTLER_ATTACKER" or d.get("raw_offset")!=expected[5] or not _operands(d.get("source_args"),expected[6]):return
	var literal_command: String="createsprite %s, ANIM_BATTLER_ATTACKER, %s"%[expected[1],expected[5]]
	for operand: Variant in expected[6]:literal_command+=", %s"%int(operand)
	if d.get("source_command")!=literal_command:return
	var node: Sprite2D=track.node;var previous: Material=node.material;var material: ShaderMaterial
	if int(expected[4])==1 and previous==null and not bool(step.get("recolor",false)):
		material=BattleIdentityCopy.blend_material(false);var pair: Array=owner.get_meta("source_legacy_impact_alpha",[16,0])
		material.set_shader_parameter("eva",float(pair[0])/16);material.set_shader_parameter("evb",float(pair[1])/16);node.material=material
	var items: Array=owner.get_meta("source_legacy_impact_objects",[])
	items.append({"node":node,"offset":int(expected[5]),"previous":previous,"material":material});owner.set_meta("source_legacy_impact_objects",items)
	_order(owner,context)

static func _order(owner: Node2D, context: BattleAnimationContext) -> void:
	if REMAINDER_SCRIPTS.has(owner.definition.key):
		_order_remainder(owner,context);return
	# Only this owned group is ranked: BG2 < BG1(normal) < OBJ2 < BG1(promoted).
	# Lower source OBJ subpriority is foreground (offset3 before offset2).
	var floor: int=BattleSourcePriority.effective_layer(context.field)-BattleSourcePriority.effective_layer(owner)
	var band: int=floor+1
	for actor: BattleAnimationActor in context.actors.values():
		if actor.is_present():band=maxi(band,BattleSourcePriority.actor_layer(actor,owner))
	for track: Dictionary in owner.get_meta("source_legacy_impact_backgrounds",[]):
		for clone: Dictionary in track.clones:
			if is_instance_valid(clone.node):clone.node.z_index=band+(5 if int(clone.bg_plane)==1 and owner.get_meta("source_legacy_impact_promoted",false) else 1 if int(clone.bg_plane)==1 else 0)
	for item: Dictionary in owner.get_meta("source_legacy_impact_objects",[]):
		if is_instance_valid(item.node):item.node.z_index=band+item.offset

static func _update(track: Dictionary, context: BattleAnimationContext) -> void:
	for clone: Dictionary in track.clones:
		var actor: BattleAnimationActor=clone.actor;var node: Sprite2D=clone.node
		if not actor.is_present():node.visible=false;continue
		var source: Sprite2D=actor.sprite
		if REMAINDER_SCRIPTS.has(track.owner.definition.key):
			_follow_clone(clone,track.owner);continue
		node.position=actor.anchor(track.owner,"origin");node.scale=source.global_scale/track.owner.global_scale;node.rotation=source.global_rotation-track.owner.global_rotation
		node.modulate=source.modulate;node.material=source.material;node.frame=source.frame;node.region_rect=source.region_rect;node.flip_h=source.flip_h;node.flip_v=source.flip_v
	_order(track.owner,context)

static func _cleanup(track: Dictionary) -> void:
	track.erase("cleanup")
	for clone: Dictionary in track.clones:
		clone.actor.apply_source_state("hidden",false)
		if is_instance_valid(clone.node):clone.node.queue_free()
	track.clones.clear()

# New sites share the original owned composition, but validate source occurrences
# and source OAM basis rather than treating every visual anchor as the attacker.
static func _attach_remainder(track: Dictionary, context: BattleAnimationContext, owner: Node2D) -> void:
	var step: Dictionary=track.settings
	var d: Variant=step.get("source_legacy_composition",{})
	if not d is Dictionary or not _integer(step.get("source_line")):return
	var expected: Array=REMAINDER_SITES.get(int(step.source_line),[])
	if expected.is_empty() or expected[0]!=owner.definition.key:return
	for field: String in ["source_line","obj_mode","priority","raw_offset","source_occurrence","source_multiplicity"]:
		if not _integer(d.get(field)):return
	if step.get("source_template")!=expected[1] or step.get("source_callback")!=expected[2]:return
	if d.get("script")!=owner.definition.source_script or d.source_line!=step.source_line or d.get("template")!=expected[1] or d.get("callback")!=expected[2] or d.get("oam")!=expected[3] or d.obj_mode!=expected[4] or d.priority!=2 or d.raw_offset!=expected[5] or not _operands(d.get("source_args"),expected[6]) or d.get("basis")!=expected[7] or d.get("raw_role")!=expected[8] or d.source_multiplicity!=expected[9] or d.source_occurrence<1 or d.source_occurrence>expected[9]:return
	var command: String="createsprite %s, %s, %s"%[expected[1],expected[8],expected[5]]
	for operand: Variant in expected[6]:command+=", %s"%int(operand)
	if d.get("source_command")!=command:return
	var occurrences: Dictionary=owner.get_meta("source_legacy_impact_art_occurrences",{})
	if int(d.source_occurrence)!=int(occurrences.get(int(step.source_line),0))+1:return
	occurrences[int(step.source_line)]=int(d.source_occurrence)
	owner.set_meta("source_legacy_impact_art_occurrences",occurrences)
	var actors:=context.resolve(str(expected[7]))
	if actors.is_empty():return
	var subpriority: int=maxi(3,BattleElectricContract.source_subpriority(actors[0],context)-int(expected[5]))
	_register_object(track.node,int(expected[4]),subpriority,step,context,owner)

static func _register_object(node: Sprite2D, mode: int, subpriority: int, step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> void:
	var previous: Material=node.material
	var material: ShaderMaterial
	if mode==1 and previous==null and not bool(step.get("recolor",false)):
		material=BattleIdentityCopy.blend_material(false)
		var pair: Array=owner.get_meta("source_legacy_impact_alpha",[16,0])
		material.set_shader_parameter("eva",float(pair[0])/16)
		material.set_shader_parameter("evb",float(pair[1])/16)
		node.material=material
	var items: Array=owner.get_meta("source_legacy_impact_objects",[])
	items.append({"node":node,"subpriority":subpriority,"previous":previous,"material":material})
	owner.set_meta("source_legacy_impact_objects",items)
	_order_remainder(owner,context)

static func _owned_write(item: Dictionary, property: String, value: Variant) -> void:
	var node: Sprite2D=item.node
	var writes: Dictionary=item.get("writes",{})
	if writes.has(property) and node.get(property)!=writes[property]:
		var lost: Dictionary=item.get("lost_writes",{})
		lost[property]=true;item.lost_writes=lost
	if item.get("lost_writes",{}).has(property):return
	node.set(property,value);writes[property]=node.get(property);item.writes=writes

static func _follow_clone(clone: Dictionary, owner: Node2D) -> void:
	var source: Sprite2D=clone.actor.sprite
	for property: String in ["texture","centered","offset","hframes","vframes","frame","region_enabled","region_rect","flip_h","flip_v","modulate","material"]:
		_owned_write(clone,property,source.get(property))
	_owned_write(clone,"transform",owner.global_transform.affine_inverse()*source.global_transform)

static func _order_remainder(owner: Node2D, context: BattleAnimationContext) -> void:
	var floor: int=BattleSourcePriority.effective_layer(context.field)-BattleSourcePriority.effective_layer(owner)
	var band: int=floor+1
	for actor: BattleAnimationActor in context.actors.values():
		if actor.is_present():band=maxi(band,BattleSourcePriority.actor_layer(actor,owner))
	for track: Dictionary in owner.get_meta("source_legacy_impact_backgrounds",[]):
		for clone: Dictionary in track.clones:
			if is_instance_valid(clone.node) and not clone.node.is_queued_for_deletion():
				_owned_write(clone,"z_index",band+(100 if int(clone.bg_plane)==1 and owner.get_meta("source_legacy_impact_promoted",false) else 1 if int(clone.bg_plane)==1 else 0))
	for item: Dictionary in owner.get_meta("source_legacy_impact_objects",[]):
		if is_instance_valid(item.node) and not item.node.is_queued_for_deletion():
			_owned_write(item,"z_index",band+2+60-int(item.subpriority))

# Only the actual canonical Quick Attack task gets transparent OBJ children.
# First task callback emits immediately; counter4 means five callbacks between
# births, and child counter7 means deletion on its eighth later callback.
static func create_duplicates(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Array[Dictionary]:
	if AgilityAerial.matches(owner):return AgilityAerial.duplicates(step,context,owner)
	if not _canonical(owner) or owner.definition.key!="ruby:move/98" or not _integer(step.get("source_line")) or step.source_line!=2729 or step.get("source_task")!="sub_80E2DD8":return []
	var d: Variant=step.get("source_legacy_duplicate",{})
	if not d is Dictionary:return []
	for field: String in ["source_line","obj_mode","priority"]:
		if not _integer(d.get(field)):return []
	if d.source_line!=2729 or d.obj_mode!=1 or d.priority!=2 or d.get("script")!="Move_QUICK_ATTACK" or d.get("source_command")!="createvisualtask sub_80E2DD8, 2, 0, 4, 7, 3" or d.get("source_task")!="sub_80E2DD8" or d.get("source_callback")!="sub_80E2E10" or d.get("source_child_callback")!="sub_80E2EE8" or d.get("source_helper")!="duplicate_obj_of_side_rel2move_in_transparent_mode" or not _operands(d.get("source_args"),[0,4,7,3]):return []
	var actors:=context.resolve("attacker")
	if actors.is_empty():return []
	var track: Dictionary={"kind":"source_legacy_impact_duplicates","domain":"visual","owner":owner,"bound_actor":actors[0],"settings":step.duplicate(true),"created_tick":owner.elapsed_ticks,"age":0,"ticks":4096,"remaining":3,"counter":0,"children":[],"update":_duplicate_update}
	track.cleanup=_duplicate_cleanup.bind(track)
	return [track]

static func _duplicate_update(track: Dictionary, context: BattleAnimationContext) -> void:
	var owner: Node2D=track.owner
	for child: Dictionary in track.children.duplicate():
		if child.remaining>0:child.remaining-=1
		else:
			if is_instance_valid(child.node):child.node.queue_free()
			track.children.erase(child)
	if track.remaining>0:
		if track.counter>0:track.counter-=1
		else:
			var actor: BattleAnimationActor=track.bound_actor
			if actor.is_present():
				var node:=BattleIdentityCopy.clone_sprite(actor,owner)
				node.transform=owner.global_transform.affine_inverse()*actor.sprite.global_transform
				node.modulate=actor.sprite.modulate;node.material=actor.sprite.material;node.visible=true
				node.set_meta("source_legacy_duplicate_line",2729)
				owner.add_child(node)
				_register_object(node,1,BattleElectricContract.source_subpriority(actor,context),track.settings,context,owner)
				track.children.append({"node":node,"remaining":7,"pending_pose":true})
			track.remaining-=1;track.counter=4
	if track.remaining==0 and track.children.is_empty():track.ticks=int(track.age)

static func _duplicate_cleanup(track: Dictionary) -> void:
	track.erase("cleanup")
	for child: Dictionary in track.children:
		if is_instance_valid(child.node):child.node.queue_free()
	track.children.clear()

# Run after this tick's actor motion/palette writes. Ruby maintenance and duplicate
# snapshots must not observe the previous pose merely because BG was opened first.
static func after_actor_pose(owner: Node2D, context: BattleAnimationContext) -> void:
	if owner.has_meta(NightShade.STATE):NightShade.after_pose(owner,context);return
	if owner.has_meta(Dizzy.STATE):Dizzy.after_pose(owner,context);return
	if Crab.matches(owner) or owner.has_meta(Crab.STATE):Crab.after_pose(owner,context);return
	if Hydro.matches(owner) or owner.has_meta(Hydro.STATE):Hydro.after_pose(owner,context);return
	if Frenzy.matches(owner) or owner.has_meta(Frenzy.STATE):Frenzy.after_pose(owner,context);return
	if Petal.matches(owner) or owner.has_meta(Petal.STATE):Petal.after_pose(owner,context);return
	if Stockpile.matches(owner):Stockpile.after_pose(owner,context);return
	if Solar.matches(owner):Solar.after_pose(owner,context);return
	if Secret.matches(owner):Secret.after_pose(owner,context);return
	if Musical.matches(owner):Musical.after_pose(owner,context);return
	if Swords.matches(owner):Swords.after_pose(owner,context);return
	if Spinning.matches(owner):Spinning.after_pose(owner,context);return
	if MetallicTail.matches(owner):MetallicTail.after_pose(owner,context);return
	if owner is BattleAnimationSequenceRunner and (Stinger.SPECS.has(owner.definition.key) or owner.has_meta(Stinger.BINDING)):Stinger.after_pose(owner,context);return
	if owner is BattleAnimationSequenceRunner and (Wing.SPECS.has(owner.definition.key) or owner.has_meta(Wing.BINDING)):Wing.after_pose(owner,context);return
	if owner is BattleAnimationSequenceRunner and CrossImpact.SPECS.has(owner.definition.key):CrossImpact.after_pose(owner,context);return
	if owner is BattleAnimationSequenceRunner and JumpKick.SPECS.has(owner.definition.key):JumpKick.after_pose(owner,context);return
	if AgilityAerial.matches(owner):AgilityAerial.after_pose(owner,context);return
	if not _canonical(owner) or not REMAINDER_SCRIPTS.has(owner.definition.key):return
	for track: Dictionary in owner.get_meta("source_legacy_impact_backgrounds",[]):
		for clone: Dictionary in track.clones:
			if clone.actor.is_present() and is_instance_valid(clone.node) and not clone.node.is_queued_for_deletion():_follow_clone(clone,owner)
	for track: Dictionary in owner._tracks:
		if track.kind!="source_legacy_impact_duplicates":continue
		for child: Dictionary in track.children:
			if not child.pending_pose:continue
			var actor: BattleAnimationActor=track.bound_actor
			if actor.is_present():
				child.node.transform=owner.global_transform.affine_inverse()*actor.sprite.global_transform
				child.node.modulate=actor.sprite.modulate
			child.pending_pose=false
	_order_remainder(owner,context)

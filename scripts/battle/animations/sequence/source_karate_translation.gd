extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Finite direct/wrapper callback motion; art and composition remain literal.
const JumpKick=preload("res://scripts/battle/animations/sequence/source_jump_kick_composition.gd")
const Same=preload("res://scripts/battle/animations/sequence/source_cutting_slice.gd")
const SITES := {"ruby:move/2":["Move_KARATE_CHOP",4],"ruby:move/26":["Move_JUMP_KICK",4],"ruby:move/136":["Move_HI_JUMP_KICK",7]}
const SHAPES := {"ruby:move/26":{"op":"effect","behavior":"source_particle","mode":"linear","selector":"target","offset":[-16,8],"mirror_offset":true,"offset_direction":"toward_target","ticks":11,"frame_size":[32,32],"frame_program":[{"op":"frame","tile":16,"ticks":1,"flip_h":false,"flip_v":false},{"op":"end"}],"frame_commands":[{"tile":16,"ticks":1,"flip_h":false,"flip_v":false}],"affine_program":[],"source_template":"gBattleAnimSpriteTemplate_83D9F90","source_callback":"sub_80D9078","source_animation_index":1,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_HANDS_AND_FEET","source_palette_tag":"ANIM_TAG_HANDS_AND_FEET","source_oam":"&gOamData_837DF34","source_args":[-16,8,0,0,10,1,1,1],"from_selector":"target","to_selector":"target","end_offset":[0,0],"travel_ticks":10,"mirror_vertical_by_side":true,"source_layout_inference":"address table selects adjacent foot animation at index1","texture":"res://graficos/batalla/animaciones/hands_and_feet_pal_143_32x32_16.png","frame_rects":{"16":[0,0,32,32]},"source_line":6482},"ruby:move/136":{"op":"effect","behavior":"source_particle","mode":"linear","selector":"target","offset":[-16,8],"mirror_offset":true,"offset_direction":"toward_target","ticks":11,"frame_size":[32,32],"frame_program":[{"op":"frame","tile":16,"ticks":1,"flip_h":false,"flip_v":false},{"op":"end"}],"frame_commands":[{"tile":16,"ticks":1,"flip_h":false,"flip_v":false}],"affine_program":[],"source_template":"gBattleAnimSpriteTemplate_83D9F90","source_callback":"sub_80D9078","source_animation_index":1,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_HANDS_AND_FEET","source_palette_tag":"ANIM_TAG_HANDS_AND_FEET","source_oam":"&gOamData_837DF34","source_args":[-16,8,0,0,10,1,1,1],"from_selector":"target","to_selector":"target","end_offset":[0,0],"travel_ticks":10,"mirror_vertical_by_side":true,"source_layout_inference":"address table selects adjacent foot animation at index1","texture":"res://graficos/batalla/animaciones/hands_and_feet_pal_143_32x32_16.png","frame_rects":{"16":[0,0,32,32]},"source_line":6503},"ruby:move/2":{"op":"effect","behavior":"sheet","ticks":10,"texture":"res://graficos/batalla/animaciones/hands_and_feet.png","frame_size":[32,32],"frame_commands":[{"tile":48,"ticks":10}],"selector":"target","source_template":"gBattleAnimSpriteTemplate_83D9F78","source_callback":"sub_80D902C","offset":[-16,0],"travel":[16,0],"travel_ticks":10,"source_line":6447,"source_legacy_composition":{"script":"Move_KARATE_CHOP","source_line":6447,"template":"gBattleAnimSpriteTemplate_83D9F78","callback":"sub_80D902C","oam":"gOamData_837DF34","obj_mode":0,"priority":2,"basis":"attacker","raw_role":"ANIM_BATTLER_ATTACKER","raw_offset":2,"source_args":[-16,0,0,0,10,1,3,0],"source_command":"createsprite gBattleAnimSpriteTemplate_83D9F78, ANIM_BATTLER_ATTACKER, 2, -16, 0, 0, 0, 10, 1, 3, 0"}}}
const ART := ["texture","frame_rects","color","recolor","scale_factor","flip_h","flip_v"]

static func _shape(step: Dictionary,key: String,contest: bool) -> bool:
	var expected: Dictionary=SHAPES[key]
	for name: String in expected:
		if name not in ART and (not step.has(name) or not Same._same(step[name],expected[name])):return false
	var optional: Dictionary={"source_args":expected.get("source_args",[-16,0,0,0,10,1,3,0]),"source_script":SITES[key][0],"source_command":expected.get("source_legacy_composition",{}).get("source_command","createsprite gBattleAnimSpriteTemplate_83D9F90, ANIM_BATTLER_ATTACKER, 2, -16, 8, 0, 0, 10, 1, 1, 1"),"source_oam":"&gOamData_837DF34","source_animation_index":3 if key=="ruby:move/2" else 1,"source_affine_variant":0,"affine_program":[],"source_contest":contest,"spawn_delay":0,"travel_delay":0,"blink_after":-1,"anchor":"center","from_anchor":"center","to_anchor":"center","flip_h":false,"flip_v":false}
	for name: String in step:
		if name in ["flip_h","flip_v","recolor"]:
			if typeof(step[name])!=TYPE_BOOL:return false
		elif name in ART:continue
		elif optional.has(name):
			if not Same._same(step[name],optional[name]):return false
		elif not expected.has(name):return false
	return true

static func _preimage(track: Dictionary,c: BattleAnimationContext,owner: Node2D) -> bool:
	if not owner is BattleAnimationSequenceRunner or not BattleAnimationSequenceRegistry.is_builtin_source_definition(owner.definition):return false
	var key: String=owner.definition.key;var site: Array=SITES.get(key,[])
	if site.is_empty() or owner.definition.source_script!=site[0] or owner._pc!=site[1]:return false
	if owner._pc>=owner._steps.size() or owner._pc>=owner.definition.steps.size():return false
	for step: Dictionary in [track.settings,owner._steps[owner._pc],owner.definition.steps[owner._pc]]:
		if not _shape(step,key,c.contest):return false
	if track.kind!=SHAPES[key].behavior or not track.node is Sprite2D:return false
	return true

static func initialize(track: Dictionary,c: BattleAnimationContext,owner: Node2D,dispatch_step: Dictionary={}) -> void:
	if not _preimage(track,c,owner) or not owner.claim_effect_dispatch(dispatch_step):return
	var key: String=owner.definition.key
	var attackers:=c.resolve("attacker");var targets:=c.resolve("target")
	if attackers.is_empty() or targets.is_empty():return
	var attacker: BattleAnimationActor=attackers[0];var target: BattleAnimationActor=targets[0]
	if not attacker.is_present() or not target.is_present():return
	for node: Node2D in [c.field,owner,attacker.sprite,target.sprite]:
		if not node.global_transform.is_finite() or is_zero_approx(node.global_transform.determinant()):return
	var x: float=BattleElectricContract.source_anchor(attacker,c,"origin").x
	var end:=BattleElectricContract.source_anchor(target,c,"origin")+Vector2(0,8 if target.side==0 else 0)
	var direction: int=1 if x<end.x else -1 if x>end.x else 1 if attacker.side==0 else -1
	var vertical: int=-1 if c.contest!=(attacker.side!=0) else 1
	var start:=end+Vector2(-32*direction,16*vertical if key!="ruby:move/2" else 0)
	var node: Sprite2D=track.node;var tile: int=48 if key=="ruby:move/2" else 16
	var width: int=node.texture.get_width()/8
	node.region_rect=Rect2((tile%width)*8,(tile/width)*8,32,32)
	if track.settings.has("frame_rects"):
		var rect: Array=track.settings.frame_rects[str(tile)];node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3])
	node.flip_h=bool(track.settings.get("flip_h",false));node.flip_v=bool(track.settings.get("flip_v",false))
	node.position=owner.to_local(c.field.to_global(start));track.ticks=12
	track.source_karate_translation={"attacker":attacker,"target":target,"start":start,"end":end,"field_to_owner":owner.global_transform.affine_inverse()*c.field.global_transform,"pose":node.position,"pose_owned":true}
	if key!="ruby:move/2":JumpKick._register_foot(track,c,owner)

static func update(track: Dictionary,c: BattleAnimationContext) -> void:
	var lease: Dictionary=track.source_karate_translation;var node: Sprite2D=track.node
	for actor: BattleAnimationActor in [lease.attacker,lease.target]:
		if c.actors.get(actor.id)!=actor or not actor.is_present():
			node.visible=false;track.ticks=int(track.age);return
	lease.pose_owned=lease.pose_owned and node.position==lease.pose
	if not lease.pose_owned:return
	var point: Vector2=lease.start;var delta: Vector2=lease.end-lease.start
	for axis: int in 2:
		var rate: int=int(absf(delta[axis])*256)/10
		rate=(rate|1) if delta[axis]<0 else (rate&65534)
		var amount: int=((rate*clampi(int(track.age),0,10))&65535)>>8
		point[axis]+=-amount if (rate&1)!=0 else amount
	node.position=lease.field_to_owner*point;lease.pose=node.position

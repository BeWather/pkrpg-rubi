extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Finite Iron Tail / Poison Tail source composition. Literal custom programs opt out.
const Same=preload("res://scripts/battle/animations/sequence/source_cutting_slice.gd")
const Pair=preload("res://scripts/battle/animations/sequence/source_charge_owned.gd")
const Owned=preload("res://scripts/battle/animations/sequence/source_owned_composition.gd")
const ART := ["texture","frame_rects","color","recolor","scale_factor","flip_h","flip_v"]
# Complete reviewed programs, not partial current/future descriptor certificates.
const PROGRAMS := {
	"ruby:move/231": {
		"key":"ruby:move/231",
		"coverage":"source-derived-unreviewed",
		"source_script":"Move_IRON_TAIL",
		"steps": [
			{"op":"source_control","condition":"always","target":6125},
			{"op":"source_label","source_pc":6125,"source_line":7228,"source_command":"loadspritegfx ANIM_TAG_IMPACT"},
			{"op":"source_control","condition":"always","target":6126},
			{"op":"source_label","source_pc":6126,"source_line":7229,"source_command":"loopsewithpan SE_M_HARDEN, SOUND_PAN_ATTACKER, 28, 2"},
			{"op":"sound","path":"res://Audio/SE/PRSFX- Harden.wav","source_sound":"SE_M_HARDEN","source_pan":"SOUND_PAN_ATTACKER","repeat":2,"interval":29,"sound_delay":0,"source_line":7229},
			{"op":"source_control","condition":"always","target":6127},
			{"op":"source_label","source_pc":6127,"source_line":7230,"source_command":"createvisualtask sub_80E0A4C, 5, 1, 0, 0","source_args":[1,0,0]},
			{"op":"source_actor_state","selector":"attacker","property":"grayscale","value":true,"source_task":"sub_80E0A4C","source_line":7230},
			{"op":"effect","behavior":"metallic_sweep","selector":"attacker","ticks":64,"source_args":[1,0,0],"native_substitution":"owned shader sweep substitutes source64-tick double BG sweep; source grayscale/tint and explicit later restore retained","source_task":"sub_80E0A4C","source_line":7230},
			{"op":"source_control","condition":"always","target":6128},
			{"op":"source_label","source_pc":6128,"source_line":7231,"source_command":"waitforvisualfinish"},
			{"op":"barrier","source_line":7231},
			{"op":"source_control","condition":"always","target":6129},
			{"op":"source_label","source_pc":6129,"source_line":7232,"source_command":"monbg ANIM_BATTLER_TARGET"},
			{"op":"effect","behavior":"source_legacy_impact_command","mode":"monbg","source_args":[1],"ticks":1,"source_line":7232,"source_command":"monbg ANIM_BATTLER_TARGET","source_script":"Move_IRON_TAIL"},
			{"op":"source_control","condition":"always","target":6130},
			{"op":"source_label","source_pc":6130,"source_line":7233,"source_command":"setalpha 12, 8"},
			{"op":"effect","behavior":"source_legacy_impact_command","mode":"setalpha","source_args":[12,8],"ticks":1,"source_line":7233,"source_command":"setalpha 12, 8","source_script":"Move_IRON_TAIL"},
			{"op":"source_control","condition":"always","target":6131},
			{"op":"source_label","source_pc":6131,"source_line":7234,"source_command":"createsprite gHorizontalLungeSpriteTemplate, ANIM_BATTLER_ATTACKER, 2, 4, 4","source_args":[4,4]},
			{"op":"effect","behavior":"actor_motion","ticks":8,"selector":"attacker","motion":"triangle","x":16,"y":0,"mirror":true,"source_line":7234},
			{"op":"source_control","condition":"always","target":6132},
			{"op":"source_label","source_pc":6132,"source_line":7235,"source_command":"delay 6"},
			{"op":"wait","ticks":6,"source_line":7235},
			{"op":"source_control","condition":"always","target":6133},
			{"op":"source_label","source_pc":6133,"source_line":7236,"source_command":"createsprite gBasicHitSplatSpriteTemplate, ANIM_BATTLER_TARGET, 2, 0, 0, 1, 2","source_args":[0,0,1,2]},
			{"op":"effect","behavior":"sheet","ticks":8,"texture":"res://graficos/batalla/animaciones/impact.png","frame_size":[32,32],"frame_commands":[{"tile":0,"ticks":12}],"selector":"target","source_template":"gBasicHitSplatSpriteTemplate","source_callback":"sub_80E27A0","offset":[0,0],"source_affine_variant":2,"scale_factor":1.4545454545454546,"source_line":7236},
			{"op":"source_control","condition":"always","target":6134},
			{"op":"source_label","source_pc":6134,"source_line":7237,"source_command":"createvisualtask AnimTask_ShakeMon, 2, ANIM_BATTLER_TARGET, 3, 0, 6, 1","source_args":[1,3,0,6,1]},
			{"op":"effect","behavior":"source_actor","ticks":11,"selector":"target","mode":"zero_offset","count":6,"delay":1,"x":3,"y":0,"source_task":"AnimTask_ShakeMon","source_line":7237},
			{"op":"source_control","condition":"always","target":6135},
			{"op":"source_label","source_pc":6135,"source_line":7238,"source_command":"playsewithpan SE_M_VITAL_THROW2, SOUND_PAN_TARGET"},
			{"op":"sound","path":"res://Audio/SE/PRSFX- Vital Throw2.wav","source_sound":"SE_M_VITAL_THROW2","source_pan":"SOUND_PAN_TARGET","repeat":1,"interval":1,"sound_delay":0,"source_line":7238},
			{"op":"source_control","condition":"always","target":6136},
			{"op":"source_label","source_pc":6136,"source_line":7239,"source_command":"waitforvisualfinish"},
			{"op":"barrier","source_line":7239},
			{"op":"source_control","condition":"always","target":6137},
			{"op":"source_label","source_pc":6137,"source_line":7240,"source_command":"createvisualtask sub_80E0E24, 5, 0, 1","source_args":[0,1]},
			{"op":"source_actor_state","selector":"attacker","property":"grayscale","value":false,"source_task":"sub_80E0E24","source_line":7240},
			{"op":"source_control","condition":"always","target":6138},
			{"op":"source_label","source_pc":6138,"source_line":7241,"source_command":"clearmonbg ANIM_BATTLER_TARGET"},
			{"op":"effect","behavior":"source_legacy_impact_command","mode":"clearmonbg","source_args":[1],"ticks":1,"source_line":7241,"source_command":"clearmonbg ANIM_BATTLER_TARGET","source_script":"Move_IRON_TAIL"},
			{"op":"source_control","condition":"always","target":6139},
			{"op":"source_label","source_pc":6139,"source_line":7242,"source_command":"blendoff"},
			{"op":"effect","behavior":"source_legacy_impact_command","mode":"blendoff","source_args":[],"ticks":1,"source_line":7242,"source_command":"blendoff","source_script":"Move_IRON_TAIL"},
			{"op":"source_control","condition":"always","target":6140},
			{"op":"source_label","source_pc":6140,"source_line":7243,"source_command":"waitforvisualfinish"},
			{"op":"barrier","source_line":7243},
			{"op":"source_control","condition":"always","target":6141},
			{"op":"source_label","source_pc":6141,"source_line":7244,"source_command":"end"},
			{"op":"source_control","condition":"end","source_line":7244},
			{"op":"marker","name":"impact"},
			{"op":"barrier"},
			{"op":"end"},
		],
	},
	"ruby:move/342": {
		"key":"ruby:move/342",
		"coverage":"source-derived-unreviewed",
		"source_script":"Move_POISON_TAIL",
		"steps": [
			{"op":"source_control","condition":"always","target":6142},
			{"op":"source_label","source_pc":6142,"source_line":7247,"source_command":"loadspritegfx ANIM_TAG_IMPACT"},
			{"op":"source_control","condition":"always","target":6143},
			{"op":"source_label","source_pc":6143,"source_line":7248,"source_command":"loadspritegfx ANIM_TAG_POISON_BUBBLE"},
			{"op":"source_control","condition":"always","target":6144},
			{"op":"source_label","source_pc":6144,"source_line":7249,"source_command":"loopsewithpan SE_M_HARDEN, SOUND_PAN_ATTACKER, 28, 2"},
			{"op":"sound","path":"res://Audio/SE/PRSFX- Harden.wav","source_sound":"SE_M_HARDEN","source_pan":"SOUND_PAN_ATTACKER","repeat":2,"interval":29,"sound_delay":0,"source_line":7249},
			{"op":"source_control","condition":"always","target":6145},
			{"op":"source_label","source_pc":6145,"source_line":7250,"source_command":"createvisualtask sub_80E0A4C, 5, 1, 1, 23768","source_args":[1,1,23768]},
			{"op":"effect","behavior":"source_palette","selector":"attacker","ticks":1,"blend_start":11,"blend_end":11,"blend_delay":1,"color":"c531bd","source_task":"sub_80E0A4C","source_line":7250},
			{"op":"effect","behavior":"metallic_sweep","selector":"attacker","ticks":64,"source_args":[1,1,23768],"native_substitution":"owned shader sweep substitutes source64-tick double BG sweep; source grayscale/tint and explicit later restore retained","source_task":"sub_80E0A4C","source_line":7250},
			{"op":"source_control","condition":"always","target":6146},
			{"op":"source_label","source_pc":6146,"source_line":7251,"source_command":"waitforvisualfinish"},
			{"op":"barrier","source_line":7251},
			{"op":"source_control","condition":"always","target":6147},
			{"op":"source_label","source_pc":6147,"source_line":7252,"source_command":"monbg ANIM_BATTLER_TARGET"},
			{"op":"effect","behavior":"source_legacy_impact_command","mode":"monbg","source_args":[1],"ticks":1,"source_line":7252,"source_command":"monbg ANIM_BATTLER_TARGET","source_script":"Move_POISON_TAIL"},
			{"op":"source_control","condition":"always","target":6148},
			{"op":"source_label","source_pc":6148,"source_line":7253,"source_command":"setalpha 12, 8"},
			{"op":"effect","behavior":"source_legacy_impact_command","mode":"setalpha","source_args":[12,8],"ticks":1,"source_line":7253,"source_command":"setalpha 12, 8","source_script":"Move_POISON_TAIL"},
			{"op":"source_control","condition":"always","target":6149},
			{"op":"source_label","source_pc":6149,"source_line":7254,"source_command":"createsprite gHorizontalLungeSpriteTemplate, ANIM_BATTLER_ATTACKER, 2, 4, 4","source_args":[4,4]},
			{"op":"effect","behavior":"actor_motion","ticks":8,"selector":"attacker","motion":"triangle","x":16,"y":0,"mirror":true,"source_line":7254},
			{"op":"source_control","condition":"always","target":6150},
			{"op":"source_label","source_pc":6150,"source_line":7255,"source_command":"delay 6"},
			{"op":"wait","ticks":6,"source_line":7255},
			{"op":"source_control","condition":"always","target":6151},
			{"op":"source_label","source_pc":6151,"source_line":7256,"source_command":"createsprite gBasicHitSplatSpriteTemplate, ANIM_BATTLER_TARGET, 2, 0, 0, 1, 2","source_args":[0,0,1,2]},
			{"op":"effect","behavior":"sheet","ticks":8,"texture":"res://graficos/batalla/animaciones/impact.png","frame_size":[32,32],"frame_commands":[{"tile":0,"ticks":12}],"selector":"target","source_template":"gBasicHitSplatSpriteTemplate","source_callback":"sub_80E27A0","offset":[0,0],"source_affine_variant":2,"scale_factor":1.4545454545454546,"source_line":7256},
			{"op":"source_control","condition":"always","target":6152},
			{"op":"source_label","source_pc":6152,"source_line":7257,"source_command":"createvisualtask AnimTask_ShakeMon, 2, ANIM_BATTLER_TARGET, 3, 0, 6, 1","source_args":[1,3,0,6,1]},
			{"op":"effect","behavior":"source_actor","ticks":11,"selector":"target","mode":"zero_offset","count":6,"delay":1,"x":3,"y":0,"source_task":"AnimTask_ShakeMon","source_line":7257},
			{"op":"source_control","condition":"always","target":6153},
			{"op":"source_label","source_pc":6153,"source_line":7258,"source_command":"playsewithpan SE_M_VITAL_THROW2, SOUND_PAN_TARGET"},
			{"op":"sound","path":"res://Audio/SE/PRSFX- Vital Throw2.wav","source_sound":"SE_M_VITAL_THROW2","source_pan":"SOUND_PAN_TARGET","repeat":1,"interval":1,"sound_delay":0,"source_line":7258},
			{"op":"source_control","condition":"always","target":6154},
			{"op":"source_label","source_pc":6154,"source_line":7259,"source_command":"waitforvisualfinish"},
			{"op":"barrier","source_line":7259},
			{"op":"source_control","condition":"always","target":6155},
			{"op":"source_label","source_pc":6155,"source_line":7260,"source_command":"createvisualtask sub_80E0E24, 5, 0, 1","source_args":[0,1]},
			{"op":"source_actor_state","selector":"attacker","property":"grayscale","value":false,"source_task":"sub_80E0E24","source_line":7260},
			{"op":"source_control","condition":"always","target":6156},
			{"op":"source_label","source_pc":6156,"source_line":7261,"source_command":"clearmonbg ANIM_BATTLER_TARGET"},
			{"op":"effect","behavior":"source_legacy_impact_command","mode":"clearmonbg","source_args":[1],"ticks":1,"source_line":7261,"source_command":"clearmonbg ANIM_BATTLER_TARGET","source_script":"Move_POISON_TAIL"},
			{"op":"source_control","condition":"always","target":6157},
			{"op":"source_label","source_pc":6157,"source_line":7262,"source_command":"blendoff"},
			{"op":"effect","behavior":"source_legacy_impact_command","mode":"blendoff","source_args":[],"ticks":1,"source_line":7262,"source_command":"blendoff","source_script":"Move_POISON_TAIL"},
			{"op":"source_control","condition":"always","target":6158},
			{"op":"source_label","source_pc":6158,"source_line":7263,"source_command":"call PoisonBubblesAnim"},
			{"op":"source_control","condition":"call","target":8690,"return_target":6159,"source_line":7263},
			{"op":"source_label","source_pc":6159,"source_line":7264,"source_command":"waitforvisualfinish"},
			{"op":"barrier","source_line":7264},
			{"op":"source_control","condition":"always","target":6160},
			{"op":"source_label","source_pc":6160,"source_line":7265,"source_command":"end"},
			{"op":"source_control","condition":"end","source_line":7265},
			{"op":"source_label","source_pc":8690,"source_line":10061,"source_command":"createsprite gPoisonBubbleSpriteTemplate, ANIM_BATTLER_TARGET, 2, 10, 10, 0","source_args":[10,10,0]},
			{"op":"effect","behavior":"source_particle","mode":"bubble_rise","selector":"target","offset":[10,10],"mirror_offset":true,"frame_size":[16,16],"frame_commands":[{"tile":0,"ticks":1,"flip_h":false,"flip_v":false}],"source_template":"gPoisonBubbleSpriteTemplate","source_callback":"AnimBubbleEffect","affine_commands":[{"x":156,"y":156,"rotation":0,"ticks":0},{"x":5,"y":5,"rotation":0,"ticks":20}],"ticks":21,"texture":"res://graficos/batalla/animaciones/poison_bubble_16x16_0.png","frame_rects":{"0":[0,0,16,16]},"source_line":10061},
			{"op":"source_control","condition":"always","target":8691},
			{"op":"source_label","source_pc":8691,"source_line":10062,"source_command":"playsewithpan SE_M_TOXIC, SOUND_PAN_TARGET"},
			{"op":"sound","path":"res://Audio/SE/PRSFX- Toxic1.wav","source_sound":"SE_M_TOXIC","source_pan":"SOUND_PAN_TARGET","repeat":1,"interval":1,"sound_delay":0,"source_line":10062},
			{"op":"source_control","condition":"always","target":8692},
			{"op":"source_label","source_pc":8692,"source_line":10063,"source_command":"delay 6"},
			{"op":"wait","ticks":6,"source_line":10063},
			{"op":"source_control","condition":"always","target":8693},
			{"op":"source_label","source_pc":8693,"source_line":10064,"source_command":"createsprite gPoisonBubbleSpriteTemplate, ANIM_BATTLER_TARGET, 2, 20, -20, 0","source_args":[20,-20,0]},
			{"op":"effect","behavior":"source_particle","mode":"bubble_rise","selector":"target","offset":[20,-20],"mirror_offset":true,"frame_size":[16,16],"frame_commands":[{"tile":0,"ticks":1,"flip_h":false,"flip_v":false}],"source_template":"gPoisonBubbleSpriteTemplate","source_callback":"AnimBubbleEffect","affine_commands":[{"x":156,"y":156,"rotation":0,"ticks":0},{"x":5,"y":5,"rotation":0,"ticks":20}],"ticks":21,"texture":"res://graficos/batalla/animaciones/poison_bubble_16x16_0.png","frame_rects":{"0":[0,0,16,16]},"source_line":10064},
			{"op":"source_control","condition":"always","target":8694},
			{"op":"source_label","source_pc":8694,"source_line":10065,"source_command":"playsewithpan SE_M_TOXIC, SOUND_PAN_TARGET"},
			{"op":"sound","path":"res://Audio/SE/PRSFX- Toxic1.wav","source_sound":"SE_M_TOXIC","source_pan":"SOUND_PAN_TARGET","repeat":1,"interval":1,"sound_delay":0,"source_line":10065},
			{"op":"source_control","condition":"always","target":8695},
			{"op":"source_label","source_pc":8695,"source_line":10066,"source_command":"delay 6"},
			{"op":"wait","ticks":6,"source_line":10066},
			{"op":"source_control","condition":"always","target":8696},
			{"op":"source_label","source_pc":8696,"source_line":10067,"source_command":"createsprite gPoisonBubbleSpriteTemplate, ANIM_BATTLER_TARGET, 2, -20, 15, 0","source_args":[-20,15,0]},
			{"op":"effect","behavior":"source_particle","mode":"bubble_rise","selector":"target","offset":[-20,15],"mirror_offset":true,"frame_size":[16,16],"frame_commands":[{"tile":0,"ticks":1,"flip_h":false,"flip_v":false}],"source_template":"gPoisonBubbleSpriteTemplate","source_callback":"AnimBubbleEffect","affine_commands":[{"x":156,"y":156,"rotation":0,"ticks":0},{"x":5,"y":5,"rotation":0,"ticks":20}],"ticks":21,"texture":"res://graficos/batalla/animaciones/poison_bubble_16x16_0.png","frame_rects":{"0":[0,0,16,16]},"source_line":10067},
			{"op":"source_control","condition":"always","target":8697},
			{"op":"source_label","source_pc":8697,"source_line":10068,"source_command":"playsewithpan SE_M_TOXIC, SOUND_PAN_TARGET"},
			{"op":"sound","path":"res://Audio/SE/PRSFX- Toxic1.wav","source_sound":"SE_M_TOXIC","source_pan":"SOUND_PAN_TARGET","repeat":1,"interval":1,"sound_delay":0,"source_line":10068},
			{"op":"source_control","condition":"always","target":8698},
			{"op":"source_label","source_pc":8698,"source_line":10069,"source_command":"delay 6"},
			{"op":"wait","ticks":6,"source_line":10069},
			{"op":"source_control","condition":"always","target":8699},
			{"op":"source_label","source_pc":8699,"source_line":10070,"source_command":"createsprite gPoisonBubbleSpriteTemplate, ANIM_BATTLER_TARGET, 2, 0, 0, 0","source_args":[0,0,0]},
			{"op":"effect","behavior":"source_particle","mode":"bubble_rise","selector":"target","offset":[0,0],"mirror_offset":true,"frame_size":[16,16],"frame_commands":[{"tile":0,"ticks":1,"flip_h":false,"flip_v":false}],"source_template":"gPoisonBubbleSpriteTemplate","source_callback":"AnimBubbleEffect","affine_commands":[{"x":156,"y":156,"rotation":0,"ticks":0},{"x":5,"y":5,"rotation":0,"ticks":20}],"ticks":21,"texture":"res://graficos/batalla/animaciones/poison_bubble_16x16_0.png","frame_rects":{"0":[0,0,16,16]},"source_line":10070},
			{"op":"source_control","condition":"always","target":8700},
			{"op":"source_label","source_pc":8700,"source_line":10071,"source_command":"playsewithpan SE_M_TOXIC, SOUND_PAN_TARGET"},
			{"op":"sound","path":"res://Audio/SE/PRSFX- Toxic1.wav","source_sound":"SE_M_TOXIC","source_pan":"SOUND_PAN_TARGET","repeat":1,"interval":1,"sound_delay":0,"source_line":10071},
			{"op":"source_control","condition":"always","target":8701},
			{"op":"source_label","source_pc":8701,"source_line":10072,"source_command":"delay 6"},
			{"op":"wait","ticks":6,"source_line":10072},
			{"op":"source_control","condition":"always","target":8702},
			{"op":"source_label","source_pc":8702,"source_line":10073,"source_command":"createsprite gPoisonBubbleSpriteTemplate, ANIM_BATTLER_TARGET, 2, -20, -20, 0","source_args":[-20,-20,0]},
			{"op":"effect","behavior":"source_particle","mode":"bubble_rise","selector":"target","offset":[-20,-20],"mirror_offset":true,"frame_size":[16,16],"frame_commands":[{"tile":0,"ticks":1,"flip_h":false,"flip_v":false}],"source_template":"gPoisonBubbleSpriteTemplate","source_callback":"AnimBubbleEffect","affine_commands":[{"x":156,"y":156,"rotation":0,"ticks":0},{"x":5,"y":5,"rotation":0,"ticks":20}],"ticks":21,"texture":"res://graficos/batalla/animaciones/poison_bubble_16x16_0.png","frame_rects":{"0":[0,0,16,16]},"source_line":10073},
			{"op":"source_control","condition":"always","target":8703},
			{"op":"source_label","source_pc":8703,"source_line":10074,"source_command":"playsewithpan SE_M_TOXIC, SOUND_PAN_TARGET"},
			{"op":"sound","path":"res://Audio/SE/PRSFX- Toxic1.wav","source_sound":"SE_M_TOXIC","source_pan":"SOUND_PAN_TARGET","repeat":1,"interval":1,"sound_delay":0,"source_line":10074},
			{"op":"source_control","condition":"always","target":8704},
			{"op":"source_label","source_pc":8704,"source_line":10075,"source_command":"delay 6"},
			{"op":"wait","ticks":6,"source_line":10075},
			{"op":"source_control","condition":"always","target":8705},
			{"op":"source_label","source_pc":8705,"source_line":10076,"source_command":"createsprite gPoisonBubbleSpriteTemplate, ANIM_BATTLER_TARGET, 2, 16, -8, 0","source_args":[16,-8,0]},
			{"op":"effect","behavior":"source_particle","mode":"bubble_rise","selector":"target","offset":[16,-8],"mirror_offset":true,"frame_size":[16,16],"frame_commands":[{"tile":0,"ticks":1,"flip_h":false,"flip_v":false}],"source_template":"gPoisonBubbleSpriteTemplate","source_callback":"AnimBubbleEffect","affine_commands":[{"x":156,"y":156,"rotation":0,"ticks":0},{"x":5,"y":5,"rotation":0,"ticks":20}],"ticks":21,"texture":"res://graficos/batalla/animaciones/poison_bubble_16x16_0.png","frame_rects":{"0":[0,0,16,16]},"source_line":10076},
			{"op":"source_control","condition":"always","target":8706},
			{"op":"source_label","source_pc":8706,"source_line":10077,"source_command":"playsewithpan SE_M_TOXIC, SOUND_PAN_TARGET"},
			{"op":"sound","path":"res://Audio/SE/PRSFX- Toxic1.wav","source_sound":"SE_M_TOXIC","source_pan":"SOUND_PAN_TARGET","repeat":1,"interval":1,"sound_delay":0,"source_line":10077},
			{"op":"source_control","condition":"always","target":8707},
			{"op":"source_label","source_pc":8707,"source_line":10078,"source_command":"return"},
			{"op":"source_control","condition":"return","source_line":10078},
			{"op":"marker","name":"impact"},
			{"op":"barrier"},
			{"op":"end"},
		],
	},
}

static func matches(owner: Node2D) -> bool:
	return owner is BattleAnimationSequenceRunner and owner.definition!=null and PROGRAMS.has(owner.definition.key) and is_same(owner.definition,BattleAnimationSequenceRegistry._builtin_source_definitions.get(owner.definition.key))

static func _number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value))

static func _art(step: Dictionary) -> bool:
	return step.get("source_callback") in ["sub_80E27A0","AnimBubbleEffect"]

static func _art_valid(step: Dictionary) -> bool:
	for key: String in ["recolor","flip_h","flip_v"]:
		if step.has(key) and typeof(step[key])!=TYPE_BOOL:return false
	if step.has("scale_factor") and not _number(step.scale_factor):return false
	if step.has("color") and (not step.color is String or not Color.html_is_valid(step.color)):return false
	if not step.get("texture") is String or not ResourceLoader.exists(step.texture):return false
	var resource: Resource=load(step.texture)
	if not resource is Texture2D:return false
	var tiles: Dictionary={}
	for frame: Dictionary in step.get("frame_commands",[]):tiles[str(int(frame.tile))]=true
	if step.has("frame_rects") and (not step.frame_rects is Dictionary or step.frame_rects.size()!=tiles.size()):return false
	for key: String in tiles:
		var rect: Variant
		if step.has("frame_rects"):
			if not step.frame_rects.has(key):return false
			rect=step.frame_rects[key]
		else:
			# Omitted atlases use the same 8px tile grid and authored frame size.
			var columns: int=resource.get_width()/8
			if columns<=0:return false
			var tile: int=int(key);var size: Array=step.frame_size
			rect=[(tile%columns)*8,(tile/columns)*8,size[0],size[1]]
		if not rect is Array or rect.size()!=4:return false
		for value: Variant in rect:
			if not _number(value) or float(value)!=floorf(float(value)):return false
		if rect[0]<0 or rect[1]<0 or rect[2]<=0 or rect[3]<=0 or rect[0]+rect[2]>resource.get_width() or rect[1]+rect[3]>resource.get_height():return false
	return true

static func _shape(actual: Variant,expected: Dictionary) -> bool:
	if not actual is Dictionary:return false
	var art: bool=_art(expected)
	for key: String in expected:
		if art and key in ART:continue
		if not actual.has(key) or not Same._same(actual[key],expected[key]):return false
	for key: String in actual:
		if not expected.has(key) and (not art or key not in ART):return false
	return not art or _art_valid(actual)

static func _whole(owner: Node2D) -> bool:
	if not matches(owner):return false
	var expected: Dictionary=PROGRAMS[owner.definition.key]
	if owner.definition.source_script!=expected.source_script or owner.definition.coverage!=expected.coverage:return false
	# Valid custom art must also agree across the authored and running planes.
	if not Same._same(owner._steps,owner.definition.steps):return false
	for program: Array in [owner.definition.steps,owner._steps]:
		if program.size()!=expected.steps.size():return false
		for pc: int in program.size():
			if not program[pc] is Dictionary or not _shape(program[pc],expected.steps[pc]):return false
	return true

# Decorations are dispatch-only. Their complete source label must already have
# matched both whole programs; an injected approximation is never authority.
static func _admit(incoming: Dictionary,c: BattleAnimationContext,owner: Node2D,art: bool) -> bool:
	if not matches(owner) or not is_same(owner.context,c) or not _whole(owner):return false
	var program: Array=PROGRAMS[owner.definition.key].steps
	var pc: int=owner._pc
	if pc<=0 or pc>=program.size() or _art(program[pc])!=art:return false
	if not art and program[pc].get("behavior")!="source_legacy_impact_command":return false
	var plain: Dictionary=incoming.duplicate(true)
	if art and not plain.has("source_command_priority"):return false
	if plain.has("source_command_priority"):
		var expected: Dictionary=BattleSourcePriority.command_metadata(program[pc-1])
		if expected.is_empty() or not Same._same(plain.source_command_priority,expected):return false
		plain.erase("source_command_priority")
	if not _shape(plain,program[pc]):return false
	if not Same._same(plain,owner._steps[pc]) or not Same._same(plain,owner.definition.steps[pc]):return false
	return owner.claim_effect_dispatch(incoming)

static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if not _admit(step,c,owner,false):return []
	var trace: Array=owner.get_meta("source_legacy_impact_commands",[]);trace.append(int(step.source_line));owner.set_meta("source_legacy_impact_commands",trace)
	match str(step.mode):
		"setalpha","blendoff":
			var off: bool=step.mode=="blendoff"
			owner.set_meta("source_legacy_impact_alpha",[16,0] if off else [12,8])
			for item: Dictionary in owner.get_meta("source_legacy_impact_objects",[]):
				if off:Owned.release_object(item)
				else:Owned.uniform(item,"eva",0.75);Owned.uniform(item,"evb",0.5)
			return []
		"clearmonbg":
			for track: Dictionary in owner.get_meta("source_legacy_impact_backgrounds",[]):Pair._clear_pair(track)
			return []
	var tracks: Array[Dictionary]=Pair._create_pair_bg(c,owner,1,"source_legacy_impact_bg","source_legacy_impact_backgrounds")
	_order(owner,c);return tracks

static func _art_bound(item: Dictionary,c: BattleAnimationContext) -> bool:
	return is_instance_valid(item.parent) and matches(item.parent) and is_same(item.parent.context,c) and is_same(item.parent.definition,item.definition) and c.actors.get(item.actor.id)==item.actor and item.actor.sprite==item.sprite and item.actor.is_present() and Pair._visual(item)

static func attach(t: Dictionary,c: BattleAnimationContext,owner: Node2D,incoming: Dictionary) -> void:
	if t.kind not in ["sheet","source_particle"] or not t.node is Sprite2D or not _art(t.settings):return
	if not _admit(incoming,c,owner,true):return
	if c.target_ids.is_empty() or not c.actors.has(c.target_ids[0]):return
	var actor: BattleAnimationActor=c.actors[c.target_ids[0]]
	if not actor.is_present():return
	var sprite: Sprite2D=actor.sprite
	var origin: Vector2=c.field.to_local(sprite.get_parent().to_global(sprite.transform*sprite.get_rect().get_center()-actor._offset))
	var bubble: bool=t.settings.source_callback=="AnimBubbleEffect"
	if bubble:origin+=Vector2(float(t.settings.offset[0])*int(-1 if t.source_side else 1),float(t.settings.offset[1]))
	var factor: float=BattleEffectBehaviorRegistry._sheet_scale_factor(t.settings,owner,str(t.kind))
	var item: Dictionary={"node":t.node,"parent":owner,"context":c,"definition":owner.definition,"actor":actor,"sprite":sprite,"sprite_parent":sprite.get_parent(),"texture":sprite.texture,"generation":actor._generation,"slot":actor.slot,"field_origin":origin,"factor":factor,"bubble":bubble,"subpriority":maxi(3,BattleElectricContract.source_subpriority(actor,c)-2),"track":t,"writes":{},"lost":{},"material":null,"previous":t.node.material,"shader":null,"uniforms":{},"revoked":{},"lost_material":false,"active":true}
	if not bubble and t.node.material==null and not bool(t.settings.get("recolor",false)):
		var material: ShaderMaterial=BattleIdentityCopy.blend_material(false);material.set_shader_parameter("eva",0.75);material.set_shader_parameter("evb",0.5)
		t.node.material=material;item.material=material;item.shader=material.shader
		for key: String in ["eva","evb","first_tint"]:item.uniforms[key]=material.get_shader_parameter(key)
	t.source_oam_priority=2;t.source_oam_subpriority=item.subpriority;t.source_priority_actor_id=actor.id
	t.i155_item=item;t.update=_advance_art;t.cleanup=_release_art.bind(item)
	var objects: Array=owner.get_meta("source_legacy_impact_objects",[]);objects.append(item);owner.set_meta("source_legacy_impact_objects",objects)
	_advance_art(t,c);_order(owner,c)

static func _advance_art(t: Dictionary,c: BattleAnimationContext) -> void:
	var item: Dictionary=t.i155_item
	if not Owned.node(item) or not _art_bound(item,c):return
	var age: int=maxi(0,int(t.age));var point: Vector2=item.field_origin
	var scale: float=item.factor
	if item.bubble:
		point+=Vector2(sin(((age*11)&255)*TAU/256.0)*4,-floorf(age*48.0/256.0));scale=float(item.factor)*256.0/(156+5*mini(age,20))
	Owned.write(item,"transform",item.parent.global_transform.affine_inverse()*c.field.global_transform*Transform2D(0,Vector2.ONE*scale,0,point))
	var frame: Dictionary=t.settings.frame_commands[0];var tile: int=int(frame.tile)
	var rect: Array
	if t.settings.has("frame_rects"):rect=t.settings.frame_rects[str(tile)]
	else:
		var columns: int=item.node.texture.get_width()/8;var size: Array=t.settings.frame_size
		if columns<=0:return
		rect=[(tile%columns)*8,(tile/columns)*8,size[0],size[1]]
	Owned.write(item,"region_rect",Rect2(rect[0],rect[1],rect[2],rect[3]))
	Owned.write(item,"flip_h",bool(frame.get("flip_h",false))!=bool(t.settings.get("flip_h",false)))
	Owned.write(item,"flip_v",bool(frame.get("flip_v",false))!=bool(t.settings.get("flip_v",false)))

static func _release_art(item: Dictionary) -> void:
	var t: Dictionary=item.get("track",{})
	# Foreign reparenting transfers disposal authority as well as property writes.
	if not t.is_empty():
		if not Owned.node(item):t.erase("node")
		t.erase("i155_item");t.erase("cleanup")
	item.erase("track");Owned.release_object(item)

static func _observe_properties(item: Dictionary) -> void:
	if not is_instance_valid(item.node):return
	for key: String in item.writes:
		if item.node.get(key)!=item.writes[key]:item.lost[key]=true

# Observe BEFORE generic maintenance/appearance updates can erase foreign writes.
static func begin_tick(owner: Node2D,c: BattleAnimationContext) -> void:
	if not matches(owner):return
	for track: Dictionary in owner.get_meta("source_legacy_impact_backgrounds",[]):
		for item: Dictionary in track.clones:_observe_properties(item)
	for item: Dictionary in owner.get_meta("source_legacy_impact_objects",[]):
		_observe_properties(item);Owned.observe_material(item)
		if not _art_bound(item,c):item.lost_material=true

static func _order(owner: Node2D,c: BattleAnimationContext) -> void:
	var band: int=BattleSourcePriority.effective_layer(c.field)-BattleSourcePriority.effective_layer(owner)+1
	for actor: BattleAnimationActor in c.actors.values():
		if actor.is_present():band=maxi(band,BattleSourcePriority.actor_layer(actor,owner))
	for track: Dictionary in owner.get_meta("source_legacy_impact_backgrounds",[]):
		for item: Dictionary in track.clones:
			if not item.retired and Owned.node(item):Owned.write(item,"z_index",band+(1 if int(item.bg_plane)==1 else 0))
	for item: Dictionary in owner.get_meta("source_legacy_impact_objects",[]):
		if Owned.node(item) and _art_bound(item,c):Owned.write(item,"z_index",band+62-int(item.subpriority))

static func after_pose(owner: Node2D,c: BattleAnimationContext) -> void:
	if not matches(owner):return
	for track: Dictionary in owner.get_meta("source_legacy_impact_backgrounds",[]):Pair._after_pair_pose(track)
	for item: Dictionary in owner.get_meta("source_legacy_impact_objects",[]):
		if item.has("track"):_advance_art(item.track,c)
	_order(owner,c)

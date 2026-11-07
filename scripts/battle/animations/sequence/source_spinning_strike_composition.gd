extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Finite four-program spinning-strike source admission and owned composition.
const Same=preload("res://scripts/battle/animations/sequence/source_cutting_slice.gd")
const Pair=preload("res://scripts/battle/animations/sequence/source_charge_owned.gd")
const Owned=preload("res://scripts/battle/animations/sequence/source_owned_composition.gd")
const STATE := "i156_spinning_session"
const ART := ["texture","frame_rects","color","recolor","scale_factor","flip_h","flip_v"]
const PROGRAMS := {
	"ruby:move/5": {
		"key":"ruby:move/5",
		"coverage":"source-derived-unreviewed",
		"source_script":"Move_MEGA_PUNCH",
		"steps":[
			{"op":"source_control","condition":"always","target":461},
			{"op":"source_label","source_pc":461,"source_line":941,"source_command":"loadspritegfx ANIM_TAG_IMPACT"},
			{"op":"source_control","condition":"always","target":462},
			{"op":"source_label","source_pc":462,"source_line":942,"source_command":"loadspritegfx ANIM_TAG_HANDS_AND_FEET"},
			{"op":"source_control","condition":"always","target":463},
			{"op":"source_label","source_pc":463,"source_line":943,"source_command":"monbg ANIM_BATTLER_TARGET"},
			{"op":"effect","behavior":"source_legacy_impact_command","mode":"monbg","source_args":[1],"ticks":1,"source_line":943,"source_command":"monbg ANIM_BATTLER_TARGET","source_script":"Move_MEGA_PUNCH"},
			{"op":"source_control","condition":"always","target":464},
			{"op":"source_label","source_pc":464,"source_line":944,"source_command":"delay 2"},
			{"op":"wait","ticks":2,"source_line":944},
			{"op":"source_control","condition":"always","target":465},
			{"op":"source_label","source_pc":465,"source_line":945,"source_command":"createsprite gSimplePaletteBlendSpriteTemplate, ANIM_BATTLER_ATTACKER, 2, 1, 0, 0, 16, rgb(0, 0, 0)","source_args":[1,0,0,16,0]},
			{"op":"effect","behavior":"source_palette","selector":"background","ticks":17,"blend_start":0,"blend_end":16,"blend_delay":1,"color":"000000","source_negative_fade_delay":0,"source_line":945},
			{"op":"source_control","condition":"always","target":466},
			{"op":"source_label","source_pc":466,"source_line":946,"source_command":"setalpha 12, 8"},
			{"op":"effect","behavior":"source_legacy_impact_command","mode":"setalpha","source_args":[12,8],"ticks":1,"source_line":946,"source_command":"setalpha 12, 8","source_script":"Move_MEGA_PUNCH"},
			{"op":"source_control","condition":"always","target":467},
			{"op":"source_label","source_pc":467,"source_line":947,"source_command":"playsewithpan SE_M_MEGA_KICK, SOUND_PAN_TARGET"},
			{"op":"sound","path":"res://Audio/SE/PRSFX- Megakick.wav","source_sound":"SE_M_MEGA_KICK","source_pan":"SOUND_PAN_TARGET","repeat":1,"interval":1,"sound_delay":0,"source_line":947},
			{"op":"source_control","condition":"always","target":468},
			{"op":"source_label","source_pc":468,"source_line":948,"source_command":"createsprite gMegaPunchKickSpriteTemplate, ANIM_BATTLER_ATTACKER, 3, 0, 0, 0, 50","source_args":[0,0,0,50]},
			{"op":"effect","behavior":"source_particle","mode":"spinning_strike","selector":"target","offset":[0,0],"mirror_offset":false,"offset_direction":"toward_target","ticks":73,"frame_size":[32,32],"frame_program":[{"op":"frame","tile":0,"ticks":1,"flip_h":false,"flip_v":false},{"op":"end"}],"frame_commands":[{"tile":0,"ticks":1,"flip_h":false,"flip_v":false}],"affine_program":[{"op":"frame","x":256,"y":256,"rotation":0,"ticks":0},{"op":"frame","x":-4,"y":-4,"rotation":20,"ticks":1},{"op":"jump","target":1}],"source_template":"gMegaPunchKickSpriteTemplate","source_callback":"AnimSpinningKickOrPunch","source_animation_index":0,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_HANDS_AND_FEET","source_palette_tag":"ANIM_TAG_HANDS_AND_FEET","source_oam":"&gOamData_837DFF4","source_module":"charge_contract","source_args":[0,0,0,50],"spin_ticks":50,"frame_transition_ticks":52,"replacement_affine_program":[{"op":"frame","x":256,"y":256,"rotation":0,"ticks":0},{"op":"end"}],"source_private":["WaitAnimForDuration","AnimSpinningKickOrPunchFinish","DestroyAnimSprite"],"texture":"res://graficos/batalla/animaciones/hands_and_feet_pal_143_32x32_0.png","frame_rects":{"0":[0,0,32,32]},"source_line":948,"source_priority_basis":"attacker","source_priority_arg":3},
			{"op":"source_control","condition":"always","target":469},
			{"op":"source_label","source_pc":469,"source_line":949,"source_command":"createvisualtask sub_80E2A38, 10, 4, 2, 0, 7, 32767","source_args":[4,2,0,7,32767]},
			{"op":"effect","behavior":"source_palette","selector":"target","ticks":24,"blend_start":0,"blend_end":7,"blend_delay":3,"color":"ffffff","source_negative_fade_delay":0,"source_task":"sub_80E2A38","source_line":949},
			{"op":"source_control","condition":"always","target":470},
			{"op":"source_label","source_pc":470,"source_line":950,"source_command":"delay 50"},
			{"op":"wait","ticks":50,"source_line":950},
			{"op":"source_control","condition":"always","target":471},
			{"op":"source_label","source_pc":471,"source_line":951,"source_command":"call _81C85E9"},
			{"op":"source_control","condition":"call","target":484,"return_target":472,"source_line":951},
			{"op":"source_label","source_pc":472,"source_line":952,"source_command":"createsprite gBasicHitSplatSpriteTemplate, ANIM_BATTLER_ATTACKER, 2, 0, 0, 1, 0","source_args":[0,0,1,0]},
			{"op":"effect","behavior":"sheet","ticks":8,"texture":"res://graficos/batalla/animaciones/impact.png","frame_size":[32,32],"frame_commands":[{"tile":0,"ticks":12}],"selector":"target","source_template":"gBasicHitSplatSpriteTemplate","source_callback":"sub_80E27A0","offset":[0,0],"source_affine_variant":0,"scale_factor":1.0,"source_line":952},
			{"op":"source_control","condition":"always","target":473},
			{"op":"source_label","source_pc":473,"source_line":953,"source_command":"createvisualtask AnimTask_ShakeMon2, 2, ANIM_BATTLER_TARGET, 4, 0, 22, 1","source_args":[1,4,0,22,1]},
			{"op":"effect","behavior":"source_actor","ticks":43,"selector":"target","mode":"signed","count":22,"delay":1,"x":4,"y":0,"source_task":"AnimTask_ShakeMon2","source_line":953},
			{"op":"source_control","condition":"always","target":474},
			{"op":"source_label","source_pc":474,"source_line":954,"source_command":"createvisualtask sub_80E2A38, 10, 4, 2, 0, 0, 32767","source_args":[4,2,0,0,32767]},
			{"op":"effect","behavior":"source_palette","selector":"target","ticks":3,"blend_start":0,"blend_end":0,"blend_delay":3,"color":"ffffff","source_negative_fade_delay":0,"source_task":"sub_80E2A38","source_line":954},
			{"op":"source_control","condition":"always","target":475},
			{"op":"source_label","source_pc":475,"source_line":955,"source_command":"createsprite gBattleAnimSpriteTemplate_83DB3DC, ANIM_BATTLER_ATTACKER, 2, 31, 3, 1, 0, 8, 0, 0","source_args":[31,3,1,0,8,0,0]},
			{"op":"effect","behavior":"source_palette","selector":"background","ticks":9,"palette_states":[{"ticks":4,"color":"000000","amount":8},{"ticks":4,"color":"000000","amount":0},{"ticks":1,"color":"000000","amount":0}],"source_line":955},
			{"op":"effect","behavior":"source_palette","selector":"attacker","ticks":9,"palette_states":[{"ticks":4,"color":"000000","amount":8},{"ticks":4,"color":"000000","amount":0},{"ticks":1,"color":"000000","amount":0}],"source_line":955},
			{"op":"effect","behavior":"source_palette","selector":"target","ticks":9,"palette_states":[{"ticks":4,"color":"000000","amount":8},{"ticks":4,"color":"000000","amount":0},{"ticks":1,"color":"000000","amount":0}],"source_line":955},
			{"op":"effect","behavior":"source_palette","selector":"attacker_partner","ticks":9,"palette_states":[{"ticks":4,"color":"000000","amount":8},{"ticks":4,"color":"000000","amount":0},{"ticks":1,"color":"000000","amount":0}],"source_line":955},
			{"op":"effect","behavior":"source_palette","selector":"target_partner","ticks":9,"palette_states":[{"ticks":4,"color":"000000","amount":8},{"ticks":4,"color":"000000","amount":0},{"ticks":1,"color":"000000","amount":0}],"source_line":955},
			{"op":"source_control","condition":"always","target":476},
			{"op":"source_label","source_pc":476,"source_line":956,"source_command":"playsewithpan SE_M_VITAL_THROW2, SOUND_PAN_TARGET"},
			{"op":"sound","path":"res://Audio/SE/PRSFX- Vital Throw2.wav","source_sound":"SE_M_VITAL_THROW2","source_pan":"SOUND_PAN_TARGET","repeat":1,"interval":1,"sound_delay":0,"source_line":956},
			{"op":"source_control","condition":"always","target":477},
			{"op":"source_label","source_pc":477,"source_line":957,"source_command":"waitforvisualfinish"},
			{"op":"barrier","source_line":957},
			{"op":"source_control","condition":"always","target":478},
			{"op":"source_label","source_pc":478,"source_line":958,"source_command":"clearmonbg ANIM_BATTLER_TARGET"},
			{"op":"effect","behavior":"source_legacy_impact_command","mode":"clearmonbg","source_args":[1],"ticks":1,"source_line":958,"source_command":"clearmonbg ANIM_BATTLER_TARGET","source_script":"Move_MEGA_PUNCH"},
			{"op":"source_control","condition":"always","target":479},
			{"op":"source_label","source_pc":479,"source_line":959,"source_command":"blendoff"},
			{"op":"effect","behavior":"source_legacy_impact_command","mode":"blendoff","source_args":[],"ticks":1,"source_line":959,"source_command":"blendoff","source_script":"Move_MEGA_PUNCH"},
			{"op":"source_control","condition":"always","target":480},
			{"op":"source_label","source_pc":480,"source_line":960,"source_command":"delay 2"},
			{"op":"wait","ticks":2,"source_line":960},
			{"op":"source_control","condition":"always","target":481},
			{"op":"source_label","source_pc":481,"source_line":961,"source_command":"restorebg"},
			{"op":"effect","behavior":"source_background","ticks":32,"source_fade_out_ticks":16,"restore":true,"source_background_id":0,"texture":"res://graficos/batalla/animaciones/bg_00.png","palette_cycle_height":256,"palette_cycle_count":1,"source_line":961},
			{"op":"source_control","condition":"always","target":482},
			{"op":"source_label","source_pc":482,"source_line":962,"source_command":"waitbgfadein"},
			{"op":"background_barrier","phase":"in","source_line":962},
			{"op":"source_control","condition":"always","target":483},
			{"op":"source_label","source_pc":483,"source_line":963,"source_command":"end"},
			{"op":"source_control","condition":"end","source_line":963},
			{"op":"source_label","source_pc":484,"source_line":965,"source_command":"delay 2"},
			{"op":"wait","ticks":2,"source_line":965},
			{"op":"source_control","condition":"always","target":485},
			{"op":"source_label","source_pc":485,"source_line":966,"source_command":"createvisualtask sub_80E4200, 2","source_args":[]},
			{"op":"source_arg_context","index":7,"property":"contest","source_callback":"sub_80E4200","source_task":"sub_80E4200","source_line":966},
			{"op":"source_control","condition":"always","target":486},
			{"op":"source_label","source_pc":486,"source_line":967,"source_command":"jumpargeq 7, 1, _81C8620"},
			{"op":"source_control","condition":"arg_eq","index":7,"value":1,"target":495,"source_line":967},
			{"op":"source_control","condition":"always","target":487},
			{"op":"source_label","source_pc":487,"source_line":968,"source_command":"createvisualtask sub_812C924, 2","source_args":[]},
			{"op":"source_arg_context","index":7,"property":"target_side","source_callback":"sub_812C924","source_task":"sub_812C924","source_line":968},
			{"op":"source_control","condition":"always","target":488},
			{"op":"source_label","source_pc":488,"source_line":969,"source_command":"jumpargeq 7, 0, _81C8612"},
			{"op":"source_control","condition":"arg_eq","index":7,"value":0,"target":491,"source_line":969},
			{"op":"source_control","condition":"always","target":489},
			{"op":"source_label","source_pc":489,"source_line":970,"source_command":"jumpargeq 7, 1, _81C8619"},
			{"op":"source_control","condition":"arg_eq","index":7,"value":1,"target":493,"source_line":970},
			{"op":"source_control","condition":"always","target":490},
			{"op":"source_label","source_pc":490,"source_line":972,"source_command":"return"},
			{"op":"source_control","condition":"return","source_line":972},
			{"op":"source_label","source_pc":491,"source_line":974,"source_command":"changebg BG_IMPACT_OPPONENT"},
			{"op":"effect","behavior":"source_background","ticks":1,"source_fade_out_ticks":0,"restore":false,"source_background_id":4,"texture":"res://graficos/batalla/animaciones/bg_04.png","palette_cycle_height":256,"palette_cycle_count":1,"source_line":974,"immediate":true},
			{"op":"source_control","condition":"always","target":492},
			{"op":"source_label","source_pc":492,"source_line":975,"source_command":"goto _81C8611"},
			{"op":"source_control","condition":"always","target":490,"source_line":975},
			{"op":"source_label","source_pc":493,"source_line":977,"source_command":"changebg BG_IMPACT_PLAYER"},
			{"op":"effect","behavior":"source_background","ticks":1,"source_fade_out_ticks":0,"restore":false,"source_background_id":5,"texture":"res://graficos/batalla/animaciones/bg_05.png","palette_cycle_height":256,"palette_cycle_count":1,"source_line":977,"immediate":true},
			{"op":"source_control","condition":"always","target":494},
			{"op":"source_label","source_pc":494,"source_line":978,"source_command":"goto _81C8611"},
			{"op":"source_control","condition":"always","target":490,"source_line":978},
			{"op":"source_label","source_pc":495,"source_line":980,"source_command":"changebg BG_IMPACT_CONTESTS"},
			{"op":"effect","behavior":"source_background","ticks":1,"source_fade_out_ticks":0,"restore":false,"source_background_id":6,"texture":"res://graficos/batalla/animaciones/bg_06.png","palette_cycle_height":256,"palette_cycle_count":1,"source_line":980,"immediate":true},
			{"op":"source_control","condition":"always","target":496},
			{"op":"source_label","source_pc":496,"source_line":981,"source_command":"goto _81C8611"},
			{"op":"source_control","condition":"always","target":490,"source_line":981},
			{"op":"marker","name":"impact"},
			{"op":"barrier"},
			{"op":"end"},
		],
	},
	"ruby:move/25": {
		"key":"ruby:move/25",
		"coverage":"source-derived-unreviewed",
		"source_script":"Move_MEGA_KICK",
		"steps":[
			{"op":"source_control","condition":"always","target":497},
			{"op":"source_label","source_pc":484,"source_line":965,"source_command":"delay 2"},
			{"op":"wait","ticks":2,"source_line":965},
			{"op":"source_control","condition":"always","target":485},
			{"op":"source_label","source_pc":485,"source_line":966,"source_command":"createvisualtask sub_80E4200, 2","source_args":[]},
			{"op":"source_arg_context","index":7,"property":"contest","source_callback":"sub_80E4200","source_task":"sub_80E4200","source_line":966},
			{"op":"source_control","condition":"always","target":486},
			{"op":"source_label","source_pc":486,"source_line":967,"source_command":"jumpargeq 7, 1, _81C8620"},
			{"op":"source_control","condition":"arg_eq","index":7,"value":1,"target":495,"source_line":967},
			{"op":"source_control","condition":"always","target":487},
			{"op":"source_label","source_pc":487,"source_line":968,"source_command":"createvisualtask sub_812C924, 2","source_args":[]},
			{"op":"source_arg_context","index":7,"property":"target_side","source_callback":"sub_812C924","source_task":"sub_812C924","source_line":968},
			{"op":"source_control","condition":"always","target":488},
			{"op":"source_label","source_pc":488,"source_line":969,"source_command":"jumpargeq 7, 0, _81C8612"},
			{"op":"source_control","condition":"arg_eq","index":7,"value":0,"target":491,"source_line":969},
			{"op":"source_control","condition":"always","target":489},
			{"op":"source_label","source_pc":489,"source_line":970,"source_command":"jumpargeq 7, 1, _81C8619"},
			{"op":"source_control","condition":"arg_eq","index":7,"value":1,"target":493,"source_line":970},
			{"op":"source_control","condition":"always","target":490},
			{"op":"source_label","source_pc":490,"source_line":972,"source_command":"return"},
			{"op":"source_control","condition":"return","source_line":972},
			{"op":"source_label","source_pc":491,"source_line":974,"source_command":"changebg BG_IMPACT_OPPONENT"},
			{"op":"effect","behavior":"source_background","ticks":1,"source_fade_out_ticks":0,"restore":false,"source_background_id":4,"texture":"res://graficos/batalla/animaciones/bg_04.png","palette_cycle_height":256,"palette_cycle_count":1,"source_line":974,"immediate":true},
			{"op":"source_control","condition":"always","target":492},
			{"op":"source_label","source_pc":492,"source_line":975,"source_command":"goto _81C8611"},
			{"op":"source_control","condition":"always","target":490,"source_line":975},
			{"op":"source_label","source_pc":493,"source_line":977,"source_command":"changebg BG_IMPACT_PLAYER"},
			{"op":"effect","behavior":"source_background","ticks":1,"source_fade_out_ticks":0,"restore":false,"source_background_id":5,"texture":"res://graficos/batalla/animaciones/bg_05.png","palette_cycle_height":256,"palette_cycle_count":1,"source_line":977,"immediate":true},
			{"op":"source_control","condition":"always","target":494},
			{"op":"source_label","source_pc":494,"source_line":978,"source_command":"goto _81C8611"},
			{"op":"source_control","condition":"always","target":490,"source_line":978},
			{"op":"source_label","source_pc":495,"source_line":980,"source_command":"changebg BG_IMPACT_CONTESTS"},
			{"op":"effect","behavior":"source_background","ticks":1,"source_fade_out_ticks":0,"restore":false,"source_background_id":6,"texture":"res://graficos/batalla/animaciones/bg_06.png","palette_cycle_height":256,"palette_cycle_count":1,"source_line":980,"immediate":true},
			{"op":"source_control","condition":"always","target":496},
			{"op":"source_label","source_pc":496,"source_line":981,"source_command":"goto _81C8611"},
			{"op":"source_control","condition":"always","target":490,"source_line":981},
			{"op":"source_label","source_pc":497,"source_line":984,"source_command":"loadspritegfx ANIM_TAG_IMPACT"},
			{"op":"source_control","condition":"always","target":498},
			{"op":"source_label","source_pc":498,"source_line":985,"source_command":"loadspritegfx ANIM_TAG_HANDS_AND_FEET"},
			{"op":"source_control","condition":"always","target":499},
			{"op":"source_label","source_pc":499,"source_line":986,"source_command":"monbg ANIM_BATTLER_TARGET"},
			{"op":"effect","behavior":"source_legacy_impact_command","mode":"monbg","source_args":[1],"ticks":1,"source_line":986,"source_command":"monbg ANIM_BATTLER_TARGET","source_script":"Move_MEGA_KICK"},
			{"op":"source_control","condition":"always","target":500},
			{"op":"source_label","source_pc":500,"source_line":987,"source_command":"delay 2"},
			{"op":"wait","ticks":2,"source_line":987},
			{"op":"source_control","condition":"always","target":501},
			{"op":"source_label","source_pc":501,"source_line":988,"source_command":"createsprite gSimplePaletteBlendSpriteTemplate, ANIM_BATTLER_ATTACKER, 2, 1, 0, 0, 16, rgb(0, 0, 0)","source_args":[1,0,0,16,0]},
			{"op":"effect","behavior":"source_palette","selector":"background","ticks":17,"blend_start":0,"blend_end":16,"blend_delay":1,"color":"000000","source_negative_fade_delay":0,"source_line":988},
			{"op":"source_control","condition":"always","target":502},
			{"op":"source_label","source_pc":502,"source_line":989,"source_command":"setalpha 12, 8"},
			{"op":"effect","behavior":"source_legacy_impact_command","mode":"setalpha","source_args":[12,8],"ticks":1,"source_line":989,"source_command":"setalpha 12, 8","source_script":"Move_MEGA_KICK"},
			{"op":"source_control","condition":"always","target":503},
			{"op":"source_label","source_pc":503,"source_line":990,"source_command":"playsewithpan SE_M_MEGA_KICK, SOUND_PAN_TARGET"},
			{"op":"sound","path":"res://Audio/SE/PRSFX- Megakick.wav","source_sound":"SE_M_MEGA_KICK","source_pan":"SOUND_PAN_TARGET","repeat":1,"interval":1,"sound_delay":0,"source_line":990},
			{"op":"source_control","condition":"always","target":504},
			{"op":"source_label","source_pc":504,"source_line":991,"source_command":"createsprite gMegaPunchKickSpriteTemplate, ANIM_BATTLER_ATTACKER, 3, 0, 0, 1, 50","source_args":[0,0,1,50]},
			{"op":"effect","behavior":"source_particle","mode":"spinning_strike","selector":"target","offset":[0,0],"mirror_offset":false,"offset_direction":"toward_target","ticks":73,"frame_size":[32,32],"frame_program":[{"op":"frame","tile":16,"ticks":1,"flip_h":false,"flip_v":false},{"op":"end"}],"frame_commands":[{"tile":16,"ticks":1,"flip_h":false,"flip_v":false}],"affine_program":[{"op":"frame","x":256,"y":256,"rotation":0,"ticks":0},{"op":"frame","x":-4,"y":-4,"rotation":20,"ticks":1},{"op":"jump","target":1}],"source_template":"gMegaPunchKickSpriteTemplate","source_callback":"AnimSpinningKickOrPunch","source_animation_index":1,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_HANDS_AND_FEET","source_palette_tag":"ANIM_TAG_HANDS_AND_FEET","source_oam":"&gOamData_837DFF4","source_module":"charge_contract","source_args":[0,0,1,50],"spin_ticks":50,"frame_transition_ticks":52,"replacement_affine_program":[{"op":"frame","x":256,"y":256,"rotation":0,"ticks":0},{"op":"end"}],"source_private":["WaitAnimForDuration","AnimSpinningKickOrPunchFinish","DestroyAnimSprite"],"texture":"res://graficos/batalla/animaciones/hands_and_feet_pal_143_32x32_16.png","frame_rects":{"16":[0,0,32,32]},"source_line":991,"source_priority_basis":"attacker","source_priority_arg":3},
			{"op":"source_control","condition":"always","target":505},
			{"op":"source_label","source_pc":505,"source_line":992,"source_command":"createvisualtask sub_80E2A38, 10, 4, 2, 0, 7, 32767","source_args":[4,2,0,7,32767]},
			{"op":"effect","behavior":"source_palette","selector":"target","ticks":24,"blend_start":0,"blend_end":7,"blend_delay":3,"color":"ffffff","source_negative_fade_delay":0,"source_task":"sub_80E2A38","source_line":992},
			{"op":"source_control","condition":"always","target":506},
			{"op":"source_label","source_pc":506,"source_line":993,"source_command":"delay 50"},
			{"op":"wait","ticks":50,"source_line":993},
			{"op":"source_control","condition":"always","target":507},
			{"op":"source_label","source_pc":507,"source_line":994,"source_command":"playsewithpan SE_M_MEGA_KICK2, SOUND_PAN_TARGET"},
			{"op":"sound","path":"res://Audio/SE/PRSFX- Megakick.wav","source_sound":"SE_M_MEGA_KICK2","source_pan":"SOUND_PAN_TARGET","repeat":1,"interval":1,"sound_delay":0,"source_line":994},
			{"op":"source_control","condition":"always","target":508},
			{"op":"source_label","source_pc":508,"source_line":995,"source_command":"call _81C85E9"},
			{"op":"source_control","condition":"call","target":484,"return_target":509,"source_line":995},
			{"op":"source_label","source_pc":509,"source_line":996,"source_command":"createsprite gBasicHitSplatSpriteTemplate, ANIM_BATTLER_ATTACKER, 2, 0, 0, 1, 0","source_args":[0,0,1,0]},
			{"op":"effect","behavior":"sheet","ticks":8,"texture":"res://graficos/batalla/animaciones/impact.png","frame_size":[32,32],"frame_commands":[{"tile":0,"ticks":12}],"selector":"target","source_template":"gBasicHitSplatSpriteTemplate","source_callback":"sub_80E27A0","offset":[0,0],"source_affine_variant":0,"scale_factor":1.0,"source_line":996},
			{"op":"source_control","condition":"always","target":510},
			{"op":"source_label","source_pc":510,"source_line":997,"source_command":"createvisualtask AnimTask_ShakeMon2, 2, ANIM_BATTLER_TARGET, 4, 0, 22, 1","source_args":[1,4,0,22,1]},
			{"op":"effect","behavior":"source_actor","ticks":43,"selector":"target","mode":"signed","count":22,"delay":1,"x":4,"y":0,"source_task":"AnimTask_ShakeMon2","source_line":997},
			{"op":"source_control","condition":"always","target":511},
			{"op":"source_label","source_pc":511,"source_line":998,"source_command":"createvisualtask sub_80E2A38, 10, 4, 2, 0, 0, 32767","source_args":[4,2,0,0,32767]},
			{"op":"effect","behavior":"source_palette","selector":"target","ticks":3,"blend_start":0,"blend_end":0,"blend_delay":3,"color":"ffffff","source_negative_fade_delay":0,"source_task":"sub_80E2A38","source_line":998},
			{"op":"source_control","condition":"always","target":512},
			{"op":"source_label","source_pc":512,"source_line":999,"source_command":"createsprite gBattleAnimSpriteTemplate_83DB3DC, ANIM_BATTLER_ATTACKER, 2, 31, 3, 1, 0, 8, 0, 0","source_args":[31,3,1,0,8,0,0]},
			{"op":"effect","behavior":"source_palette","selector":"background","ticks":9,"palette_states":[{"ticks":4,"color":"000000","amount":8},{"ticks":4,"color":"000000","amount":0},{"ticks":1,"color":"000000","amount":0}],"source_line":999},
			{"op":"effect","behavior":"source_palette","selector":"attacker","ticks":9,"palette_states":[{"ticks":4,"color":"000000","amount":8},{"ticks":4,"color":"000000","amount":0},{"ticks":1,"color":"000000","amount":0}],"source_line":999},
			{"op":"effect","behavior":"source_palette","selector":"target","ticks":9,"palette_states":[{"ticks":4,"color":"000000","amount":8},{"ticks":4,"color":"000000","amount":0},{"ticks":1,"color":"000000","amount":0}],"source_line":999},
			{"op":"effect","behavior":"source_palette","selector":"attacker_partner","ticks":9,"palette_states":[{"ticks":4,"color":"000000","amount":8},{"ticks":4,"color":"000000","amount":0},{"ticks":1,"color":"000000","amount":0}],"source_line":999},
			{"op":"effect","behavior":"source_palette","selector":"target_partner","ticks":9,"palette_states":[{"ticks":4,"color":"000000","amount":8},{"ticks":4,"color":"000000","amount":0},{"ticks":1,"color":"000000","amount":0}],"source_line":999},
			{"op":"source_control","condition":"always","target":513},
			{"op":"source_label","source_pc":513,"source_line":1000,"source_command":"waitforvisualfinish"},
			{"op":"barrier","source_line":1000},
			{"op":"source_control","condition":"always","target":514},
			{"op":"source_label","source_pc":514,"source_line":1001,"source_command":"clearmonbg ANIM_BATTLER_TARGET"},
			{"op":"effect","behavior":"source_legacy_impact_command","mode":"clearmonbg","source_args":[1],"ticks":1,"source_line":1001,"source_command":"clearmonbg ANIM_BATTLER_TARGET","source_script":"Move_MEGA_KICK"},
			{"op":"source_control","condition":"always","target":515},
			{"op":"source_label","source_pc":515,"source_line":1002,"source_command":"blendoff"},
			{"op":"effect","behavior":"source_legacy_impact_command","mode":"blendoff","source_args":[],"ticks":1,"source_line":1002,"source_command":"blendoff","source_script":"Move_MEGA_KICK"},
			{"op":"source_control","condition":"always","target":516},
			{"op":"source_label","source_pc":516,"source_line":1003,"source_command":"delay 2"},
			{"op":"wait","ticks":2,"source_line":1003},
			{"op":"source_control","condition":"always","target":517},
			{"op":"source_label","source_pc":517,"source_line":1004,"source_command":"restorebg"},
			{"op":"effect","behavior":"source_background","ticks":32,"source_fade_out_ticks":16,"restore":true,"source_background_id":0,"texture":"res://graficos/batalla/animaciones/bg_00.png","palette_cycle_height":256,"palette_cycle_count":1,"source_line":1004},
			{"op":"source_control","condition":"always","target":518},
			{"op":"source_label","source_pc":518,"source_line":1005,"source_command":"waitbgfadein"},
			{"op":"background_barrier","phase":"in","source_line":1005},
			{"op":"source_control","condition":"always","target":519},
			{"op":"source_label","source_pc":519,"source_line":1006,"source_command":"end"},
			{"op":"source_control","condition":"end","source_line":1006},
			{"op":"marker","name":"impact"},
			{"op":"barrier"},
			{"op":"end"},
		],
	},
	"ruby:move/299": {
		"key":"ruby:move/299",
		"coverage":"source-derived-unreviewed",
		"source_script":"Move_BLAZE_KICK",
		"steps":[
			{"op":"source_control","condition":"always","target":7225},
			{"op":"source_label","source_pc":5888,"source_line":6963,"source_command":"createsprite gBattleAnimSpriteTemplate_83D9490, ANIM_BATTLER_TARGET, 1, 0, 10, 192, 176, 40","source_args":[0,10,192,176,40]},
			{"op":"effect","behavior":"source_particle","mode":"blaze_scatter","selector":"target","offset":[0,10],"mirror_offset":false,"offset_direction":"toward_target","ticks":42,"frame_size":[32,32],"frame_program":[{"op":"frame","tile":16,"ticks":4,"flip_h":false,"flip_v":false},{"op":"frame","tile":32,"ticks":4,"flip_h":false,"flip_v":false},{"op":"frame","tile":48,"ticks":4,"flip_h":false,"flip_v":false},{"op":"jump","target":0}],"frame_commands":[{"tile":16,"ticks":4,"flip_h":false,"flip_v":false},{"tile":32,"ticks":4,"flip_h":false,"flip_v":false},{"tile":48,"ticks":4,"flip_h":false,"flip_v":false}],"affine_program":[],"source_template":"gBattleAnimSpriteTemplate_83D9490","source_callback":"sub_80D4F18","source_animation_index":0,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_SMALL_EMBER","source_palette_tag":"ANIM_TAG_SMALL_EMBER","source_oam":"&gOamData_837DF34","source_module":"charge_contract","source_args":[0,10,192,176,40],"velocity":[192,176],"motion_ticks":40,"source_private":["sub_8078394","DestroyAnimSprite"],"texture":"res://graficos/batalla/animaciones/small_ember_pal_29_32x32_16_32_48.png","frame_rects":{"16":[0,0,32,32],"32":[0,32,32,32],"48":[0,64,32,32]},"source_line":6963,"source_priority_basis":"target","source_priority_arg":1},
			{"op":"source_control","condition":"always","target":5889},
			{"op":"source_label","source_pc":5889,"source_line":6964,"source_command":"createsprite gBattleAnimSpriteTemplate_83D9490, ANIM_BATTLER_TARGET, 1, 0, 10, -192, 240, 40","source_args":[0,10,-192,240,40]},
			{"op":"effect","behavior":"source_particle","mode":"blaze_scatter","selector":"target","offset":[0,10],"mirror_offset":false,"offset_direction":"toward_target","ticks":42,"frame_size":[32,32],"frame_program":[{"op":"frame","tile":16,"ticks":4,"flip_h":false,"flip_v":false},{"op":"frame","tile":32,"ticks":4,"flip_h":false,"flip_v":false},{"op":"frame","tile":48,"ticks":4,"flip_h":false,"flip_v":false},{"op":"jump","target":0}],"frame_commands":[{"tile":16,"ticks":4,"flip_h":false,"flip_v":false},{"tile":32,"ticks":4,"flip_h":false,"flip_v":false},{"tile":48,"ticks":4,"flip_h":false,"flip_v":false}],"affine_program":[],"source_template":"gBattleAnimSpriteTemplate_83D9490","source_callback":"sub_80D4F18","source_animation_index":0,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_SMALL_EMBER","source_palette_tag":"ANIM_TAG_SMALL_EMBER","source_oam":"&gOamData_837DF34","source_module":"charge_contract","source_args":[0,10,-192,240,40],"velocity":[-192,240],"motion_ticks":40,"source_private":["sub_8078394","DestroyAnimSprite"],"texture":"res://graficos/batalla/animaciones/small_ember_pal_29_32x32_16_32_48.png","frame_rects":{"16":[0,0,32,32],"32":[0,32,32,32],"48":[0,64,32,32]},"source_line":6964,"source_priority_basis":"target","source_priority_arg":1},
			{"op":"source_control","condition":"always","target":5890},
			{"op":"source_label","source_pc":5890,"source_line":6965,"source_command":"createsprite gBattleAnimSpriteTemplate_83D9490, ANIM_BATTLER_TARGET, 1, 0, 10, 192, -160, 40","source_args":[0,10,192,-160,40]},
			{"op":"effect","behavior":"source_particle","mode":"blaze_scatter","selector":"target","offset":[0,10],"mirror_offset":false,"offset_direction":"toward_target","ticks":42,"frame_size":[32,32],"frame_program":[{"op":"frame","tile":16,"ticks":4,"flip_h":false,"flip_v":false},{"op":"frame","tile":32,"ticks":4,"flip_h":false,"flip_v":false},{"op":"frame","tile":48,"ticks":4,"flip_h":false,"flip_v":false},{"op":"jump","target":0}],"frame_commands":[{"tile":16,"ticks":4,"flip_h":false,"flip_v":false},{"tile":32,"ticks":4,"flip_h":false,"flip_v":false},{"tile":48,"ticks":4,"flip_h":false,"flip_v":false}],"affine_program":[],"source_template":"gBattleAnimSpriteTemplate_83D9490","source_callback":"sub_80D4F18","source_animation_index":0,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_SMALL_EMBER","source_palette_tag":"ANIM_TAG_SMALL_EMBER","source_oam":"&gOamData_837DF34","source_module":"charge_contract","source_args":[0,10,192,-160,40],"velocity":[192,-160],"motion_ticks":40,"source_private":["sub_8078394","DestroyAnimSprite"],"texture":"res://graficos/batalla/animaciones/small_ember_pal_29_32x32_16_32_48.png","frame_rects":{"16":[0,0,32,32],"32":[0,32,32,32],"48":[0,64,32,32]},"source_line":6965,"source_priority_basis":"target","source_priority_arg":1},
			{"op":"source_control","condition":"always","target":5891},
			{"op":"source_label","source_pc":5891,"source_line":6966,"source_command":"createsprite gBattleAnimSpriteTemplate_83D9490, ANIM_BATTLER_TARGET, 1, 0, 10, -192, -112, 40","source_args":[0,10,-192,-112,40]},
			{"op":"effect","behavior":"source_particle","mode":"blaze_scatter","selector":"target","offset":[0,10],"mirror_offset":false,"offset_direction":"toward_target","ticks":42,"frame_size":[32,32],"frame_program":[{"op":"frame","tile":16,"ticks":4,"flip_h":false,"flip_v":false},{"op":"frame","tile":32,"ticks":4,"flip_h":false,"flip_v":false},{"op":"frame","tile":48,"ticks":4,"flip_h":false,"flip_v":false},{"op":"jump","target":0}],"frame_commands":[{"tile":16,"ticks":4,"flip_h":false,"flip_v":false},{"tile":32,"ticks":4,"flip_h":false,"flip_v":false},{"tile":48,"ticks":4,"flip_h":false,"flip_v":false}],"affine_program":[],"source_template":"gBattleAnimSpriteTemplate_83D9490","source_callback":"sub_80D4F18","source_animation_index":0,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_SMALL_EMBER","source_palette_tag":"ANIM_TAG_SMALL_EMBER","source_oam":"&gOamData_837DF34","source_module":"charge_contract","source_args":[0,10,-192,-112,40],"velocity":[-192,-112],"motion_ticks":40,"source_private":["sub_8078394","DestroyAnimSprite"],"texture":"res://graficos/batalla/animaciones/small_ember_pal_29_32x32_16_32_48.png","frame_rects":{"16":[0,0,32,32],"32":[0,32,32,32],"48":[0,64,32,32]},"source_line":6966,"source_priority_basis":"target","source_priority_arg":1},
			{"op":"source_control","condition":"always","target":5892},
			{"op":"source_label","source_pc":5892,"source_line":6967,"source_command":"createsprite gBattleAnimSpriteTemplate_83D9490, ANIM_BATTLER_TARGET, 1, 0, 10, 160, 48, 40","source_args":[0,10,160,48,40]},
			{"op":"effect","behavior":"source_particle","mode":"blaze_scatter","selector":"target","offset":[0,10],"mirror_offset":false,"offset_direction":"toward_target","ticks":42,"frame_size":[32,32],"frame_program":[{"op":"frame","tile":16,"ticks":4,"flip_h":false,"flip_v":false},{"op":"frame","tile":32,"ticks":4,"flip_h":false,"flip_v":false},{"op":"frame","tile":48,"ticks":4,"flip_h":false,"flip_v":false},{"op":"jump","target":0}],"frame_commands":[{"tile":16,"ticks":4,"flip_h":false,"flip_v":false},{"tile":32,"ticks":4,"flip_h":false,"flip_v":false},{"tile":48,"ticks":4,"flip_h":false,"flip_v":false}],"affine_program":[],"source_template":"gBattleAnimSpriteTemplate_83D9490","source_callback":"sub_80D4F18","source_animation_index":0,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_SMALL_EMBER","source_palette_tag":"ANIM_TAG_SMALL_EMBER","source_oam":"&gOamData_837DF34","source_module":"charge_contract","source_args":[0,10,160,48,40],"velocity":[160,48],"motion_ticks":40,"source_private":["sub_8078394","DestroyAnimSprite"],"texture":"res://graficos/batalla/animaciones/small_ember_pal_29_32x32_16_32_48.png","frame_rects":{"16":[0,0,32,32],"32":[0,32,32,32],"48":[0,64,32,32]},"source_line":6967,"source_priority_basis":"target","source_priority_arg":1},
			{"op":"source_control","condition":"always","target":5893},
			{"op":"source_label","source_pc":5893,"source_line":6968,"source_command":"createsprite gBattleAnimSpriteTemplate_83D9490, ANIM_BATTLER_TARGET, 1, 0, 10, -224, -32, 40","source_args":[0,10,-224,-32,40]},
			{"op":"effect","behavior":"source_particle","mode":"blaze_scatter","selector":"target","offset":[0,10],"mirror_offset":false,"offset_direction":"toward_target","ticks":42,"frame_size":[32,32],"frame_program":[{"op":"frame","tile":16,"ticks":4,"flip_h":false,"flip_v":false},{"op":"frame","tile":32,"ticks":4,"flip_h":false,"flip_v":false},{"op":"frame","tile":48,"ticks":4,"flip_h":false,"flip_v":false},{"op":"jump","target":0}],"frame_commands":[{"tile":16,"ticks":4,"flip_h":false,"flip_v":false},{"tile":32,"ticks":4,"flip_h":false,"flip_v":false},{"tile":48,"ticks":4,"flip_h":false,"flip_v":false}],"affine_program":[],"source_template":"gBattleAnimSpriteTemplate_83D9490","source_callback":"sub_80D4F18","source_animation_index":0,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_SMALL_EMBER","source_palette_tag":"ANIM_TAG_SMALL_EMBER","source_oam":"&gOamData_837DF34","source_module":"charge_contract","source_args":[0,10,-224,-32,40],"velocity":[-224,-32],"motion_ticks":40,"source_private":["sub_8078394","DestroyAnimSprite"],"texture":"res://graficos/batalla/animaciones/small_ember_pal_29_32x32_16_32_48.png","frame_rects":{"16":[0,0,32,32],"32":[0,32,32,32],"48":[0,64,32,32]},"source_line":6968,"source_priority_basis":"target","source_priority_arg":1},
			{"op":"source_control","condition":"always","target":5894},
			{"op":"source_label","source_pc":5894,"source_line":6969,"source_command":"createsprite gBattleAnimSpriteTemplate_83D9490, ANIM_BATTLER_TARGET, 1, 0, 10, 112, -128, 40","source_args":[0,10,112,-128,40]},
			{"op":"effect","behavior":"source_particle","mode":"blaze_scatter","selector":"target","offset":[0,10],"mirror_offset":false,"offset_direction":"toward_target","ticks":42,"frame_size":[32,32],"frame_program":[{"op":"frame","tile":16,"ticks":4,"flip_h":false,"flip_v":false},{"op":"frame","tile":32,"ticks":4,"flip_h":false,"flip_v":false},{"op":"frame","tile":48,"ticks":4,"flip_h":false,"flip_v":false},{"op":"jump","target":0}],"frame_commands":[{"tile":16,"ticks":4,"flip_h":false,"flip_v":false},{"tile":32,"ticks":4,"flip_h":false,"flip_v":false},{"tile":48,"ticks":4,"flip_h":false,"flip_v":false}],"affine_program":[],"source_template":"gBattleAnimSpriteTemplate_83D9490","source_callback":"sub_80D4F18","source_animation_index":0,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_SMALL_EMBER","source_palette_tag":"ANIM_TAG_SMALL_EMBER","source_oam":"&gOamData_837DF34","source_module":"charge_contract","source_args":[0,10,112,-128,40],"velocity":[112,-128],"motion_ticks":40,"source_private":["sub_8078394","DestroyAnimSprite"],"texture":"res://graficos/batalla/animaciones/small_ember_pal_29_32x32_16_32_48.png","frame_rects":{"16":[0,0,32,32],"32":[0,32,32,32],"48":[0,64,32,32]},"source_line":6969,"source_priority_basis":"target","source_priority_arg":1},
			{"op":"source_control","condition":"always","target":5895},
			{"op":"source_label","source_pc":5895,"source_line":6970,"source_command":"return"},
			{"op":"source_control","condition":"return","source_line":6970},
			{"op":"source_label","source_pc":7225,"source_line":8449,"source_command":"loadspritegfx ANIM_TAG_IMPACT"},
			{"op":"source_control","condition":"always","target":7226},
			{"op":"source_label","source_pc":7226,"source_line":8450,"source_command":"loadspritegfx ANIM_TAG_HANDS_AND_FEET"},
			{"op":"source_control","condition":"always","target":7227},
			{"op":"source_label","source_pc":7227,"source_line":8451,"source_command":"loadspritegfx ANIM_TAG_SMALL_EMBER"},
			{"op":"source_control","condition":"always","target":7228},
			{"op":"source_label","source_pc":7228,"source_line":8452,"source_command":"monbg ANIM_BATTLER_TARGET"},
			{"op":"effect","behavior":"source_legacy_impact_command","mode":"monbg","source_args":[1],"ticks":1,"source_line":8452,"source_command":"monbg ANIM_BATTLER_TARGET","source_script":"Move_BLAZE_KICK"},
			{"op":"source_control","condition":"always","target":7229},
			{"op":"source_label","source_pc":7229,"source_line":8453,"source_command":"setalpha 12, 8"},
			{"op":"effect","behavior":"source_legacy_impact_command","mode":"setalpha","source_args":[12,8],"ticks":1,"source_line":8453,"source_command":"setalpha 12, 8","source_script":"Move_BLAZE_KICK"},
			{"op":"source_control","condition":"always","target":7230},
			{"op":"source_label","source_pc":7230,"source_line":8454,"source_command":"playsewithpan SE_M_FLAME_WHEEL, SOUND_PAN_TARGET"},
			{"op":"sound","path":"res://Audio/SE/PRSFX- Flame Wheel1.wav","source_sound":"SE_M_FLAME_WHEEL","source_pan":"SOUND_PAN_TARGET","repeat":1,"interval":1,"sound_delay":0,"source_line":8454},
			{"op":"source_control","condition":"always","target":7231},
			{"op":"source_label","source_pc":7231,"source_line":8455,"source_command":"createsprite gBattleAnimSpriteTemplate_83DA024, ANIM_BATTLER_TARGET, 3, 0, 0, 1, 30","source_args":[0,0,1,30]},
			{"op":"effect","behavior":"source_particle","mode":"spinning_strike","selector":"target","offset":[0,0],"mirror_offset":false,"offset_direction":"toward_target","ticks":53,"frame_size":[32,32],"frame_program":[{"op":"frame","tile":16,"ticks":1,"flip_h":false,"flip_v":false},{"op":"end"}],"frame_commands":[{"tile":16,"ticks":1,"flip_h":false,"flip_v":false}],"affine_program":[{"op":"frame","x":256,"y":256,"rotation":0,"ticks":0},{"op":"frame","x":-8,"y":-8,"rotation":20,"ticks":1},{"op":"jump","target":1}],"source_template":"gBattleAnimSpriteTemplate_83DA024","source_callback":"AnimSpinningKickOrPunch","source_animation_index":1,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_HANDS_AND_FEET","source_palette_tag":"ANIM_TAG_HANDS_AND_FEET","source_oam":"&gOamData_837DFF4","source_module":"charge_contract","source_args":[0,0,1,30],"spin_ticks":30,"frame_transition_ticks":32,"replacement_affine_program":[{"op":"frame","x":256,"y":256,"rotation":0,"ticks":0},{"op":"end"}],"source_private":["WaitAnimForDuration","AnimSpinningKickOrPunchFinish","DestroyAnimSprite"],"texture":"res://graficos/batalla/animaciones/hands_and_feet_pal_143_32x32_16.png","frame_rects":{"16":[0,0,32,32]},"source_line":8455,"source_priority_basis":"target","source_priority_arg":3},
			{"op":"source_control","condition":"always","target":7232},
			{"op":"source_label","source_pc":7232,"source_line":8456,"source_command":"createvisualtask sub_80E2A38, 10, 4, 2, 0, 7, 32767","source_args":[4,2,0,7,32767]},
			{"op":"effect","behavior":"source_palette","selector":"target","ticks":24,"blend_start":0,"blend_end":7,"blend_delay":3,"color":"ffffff","source_negative_fade_delay":0,"source_task":"sub_80E2A38","source_line":8456},
			{"op":"source_control","condition":"always","target":7233},
			{"op":"source_label","source_pc":7233,"source_line":8457,"source_command":"delay 30"},
			{"op":"wait","ticks":30,"source_line":8457},
			{"op":"source_control","condition":"always","target":7234},
			{"op":"source_label","source_pc":7234,"source_line":8458,"source_command":"playsewithpan SE_M_FIRE_PUNCH, SOUND_PAN_TARGET"},
			{"op":"sound","path":"res://Audio/SE/PRSFX- Fire Punch1.wav","source_sound":"SE_M_FIRE_PUNCH","source_pan":"SOUND_PAN_TARGET","repeat":1,"interval":1,"sound_delay":0,"source_line":8458},
			{"op":"source_control","condition":"always","target":7235},
			{"op":"source_label","source_pc":7235,"source_line":8459,"source_command":"createsprite gBasicHitSplatSpriteTemplate, ANIM_BATTLER_TARGET, 2, 0, 0, 1, 0","source_args":[0,0,1,0]},
			{"op":"effect","behavior":"sheet","ticks":8,"texture":"res://graficos/batalla/animaciones/impact.png","frame_size":[32,32],"frame_commands":[{"tile":0,"ticks":12}],"selector":"target","source_template":"gBasicHitSplatSpriteTemplate","source_callback":"sub_80E27A0","offset":[0,0],"source_affine_variant":0,"scale_factor":1.0,"source_line":8459},
			{"op":"source_control","condition":"always","target":7236},
			{"op":"source_label","source_pc":7236,"source_line":8460,"source_command":"createvisualtask AnimTask_ShakeMon2, 2, ANIM_BATTLER_TARGET, 3, 0, 14, 1","source_args":[1,3,0,14,1]},
			{"op":"effect","behavior":"source_actor","ticks":27,"selector":"target","mode":"signed","count":14,"delay":1,"x":3,"y":0,"source_task":"AnimTask_ShakeMon2","source_line":8460},
			{"op":"source_control","condition":"always","target":7237},
			{"op":"source_label","source_pc":7237,"source_line":8461,"source_command":"createvisualtask sub_80E2A38, 10, 4, 2, 0, 0, 32767","source_args":[4,2,0,0,32767]},
			{"op":"effect","behavior":"source_palette","selector":"target","ticks":3,"blend_start":0,"blend_end":0,"blend_delay":3,"color":"ffffff","source_negative_fade_delay":0,"source_task":"sub_80E2A38","source_line":8461},
			{"op":"source_control","condition":"always","target":7238},
			{"op":"source_label","source_pc":7238,"source_line":8462,"source_command":"createsprite gBattleAnimSpriteTemplate_83DB3DC, ANIM_BATTLER_ATTACKER, 2, 31, 3, 1, 0, 8, 0, 0","source_args":[31,3,1,0,8,0,0]},
			{"op":"effect","behavior":"source_palette","selector":"background","ticks":9,"palette_states":[{"ticks":4,"color":"000000","amount":8},{"ticks":4,"color":"000000","amount":0},{"ticks":1,"color":"000000","amount":0}],"source_line":8462},
			{"op":"effect","behavior":"source_palette","selector":"attacker","ticks":9,"palette_states":[{"ticks":4,"color":"000000","amount":8},{"ticks":4,"color":"000000","amount":0},{"ticks":1,"color":"000000","amount":0}],"source_line":8462},
			{"op":"effect","behavior":"source_palette","selector":"target","ticks":9,"palette_states":[{"ticks":4,"color":"000000","amount":8},{"ticks":4,"color":"000000","amount":0},{"ticks":1,"color":"000000","amount":0}],"source_line":8462},
			{"op":"effect","behavior":"source_palette","selector":"attacker_partner","ticks":9,"palette_states":[{"ticks":4,"color":"000000","amount":8},{"ticks":4,"color":"000000","amount":0},{"ticks":1,"color":"000000","amount":0}],"source_line":8462},
			{"op":"effect","behavior":"source_palette","selector":"target_partner","ticks":9,"palette_states":[{"ticks":4,"color":"000000","amount":8},{"ticks":4,"color":"000000","amount":0},{"ticks":1,"color":"000000","amount":0}],"source_line":8462},
			{"op":"source_control","condition":"always","target":7239},
			{"op":"source_label","source_pc":7239,"source_line":8463,"source_command":"call _81D11A2"},
			{"op":"source_control","condition":"call","target":5888,"return_target":7240,"source_line":8463},
			{"op":"source_label","source_pc":7240,"source_line":8464,"source_command":"waitforvisualfinish"},
			{"op":"barrier","source_line":8464},
			{"op":"source_control","condition":"always","target":7241},
			{"op":"source_label","source_pc":7241,"source_line":8465,"source_command":"clearmonbg ANIM_BATTLER_TARGET"},
			{"op":"effect","behavior":"source_legacy_impact_command","mode":"clearmonbg","source_args":[1],"ticks":1,"source_line":8465,"source_command":"clearmonbg ANIM_BATTLER_TARGET","source_script":"Move_BLAZE_KICK"},
			{"op":"source_control","condition":"always","target":7242},
			{"op":"source_label","source_pc":7242,"source_line":8466,"source_command":"blendoff"},
			{"op":"effect","behavior":"source_legacy_impact_command","mode":"blendoff","source_args":[],"ticks":1,"source_line":8466,"source_command":"blendoff","source_script":"Move_BLAZE_KICK"},
			{"op":"source_control","condition":"always","target":7243},
			{"op":"source_label","source_pc":7243,"source_line":8467,"source_command":"end"},
			{"op":"source_control","condition":"end","source_line":8467},
			{"op":"marker","name":"impact"},
			{"op":"barrier"},
			{"op":"end"},
		],
	},
	"ruby:move/309": {
		"key":"ruby:move/309",
		"coverage":"source-derived-unreviewed",
		"source_script":"Move_METEOR_MASH",
		"steps":[
			{"op":"source_control","condition":"always","target":7434},
			{"op":"source_label","source_pc":7434,"source_line":8685,"source_command":"loadspritegfx ANIM_TAG_GOLD_STARS"},
			{"op":"source_control","condition":"always","target":7435},
			{"op":"source_label","source_pc":7435,"source_line":8686,"source_command":"loadspritegfx ANIM_TAG_IMPACT"},
			{"op":"source_control","condition":"always","target":7436},
			{"op":"source_label","source_pc":7436,"source_line":8687,"source_command":"loadspritegfx ANIM_TAG_HANDS_AND_FEET"},
			{"op":"source_control","condition":"always","target":7437},
			{"op":"source_label","source_pc":7437,"source_line":8688,"source_command":"panse_1B SE_M_BARRIER, SOUND_PAN_ATTACKER, SOUND_PAN_TARGET, 3, 0"},
			{"op":"sound","path":"res://Audio/SE/PRSFX- Barrier.wav","source_sound":"SE_M_BARRIER","source_pan":"SOUND_PAN_ATTACKER","pan_motion":[-64,63,3,1],"source_line":8688},
			{"op":"source_control","condition":"always","target":7438},
			{"op":"source_label","source_pc":7438,"source_line":8689,"source_command":"fadetobg BG_COSMIC"},
			{"op":"effect","behavior":"source_background","ticks":32,"source_fade_out_ticks":16,"restore":false,"source_background_id":16,"texture":"res://graficos/batalla/animaciones/bg_16.png","palette_cycle_height":256,"palette_cycle_count":1,"source_line":8689},
			{"op":"source_control","condition":"always","target":7439},
			{"op":"source_label","source_pc":7439,"source_line":8690,"source_command":"waitbgfadein"},
			{"op":"background_barrier","phase":"in","source_line":8690},
			{"op":"source_control","condition":"always","target":7440},
			{"op":"source_label","source_pc":7440,"source_line":8691,"source_command":"waitforvisualfinish"},
			{"op":"barrier","source_line":8691},
			{"op":"source_control","condition":"always","target":7441},
			{"op":"source_label","source_pc":7441,"source_line":8692,"source_command":"createsprite gBattleAnimSpriteTemplate_8402A3C, ANIM_BATTLER_TARGET, 3, -48, -64, 72, 32, 30","source_args":[-48,-64,72,32,30]},
			{"op":"effect","behavior":"source_particle","mode":"meteor_star","selector":"target","offset":[0,0],"mirror_offset":false,"offset_direction":"toward_target","ticks":31,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":0,"ticks":1},{"op":"end"}],"frame_commands":[{"tile":0,"ticks":1}],"affine_program":[],"source_template":"gBattleAnimSpriteTemplate_8402A3C","source_callback":"sub_8131264","source_animation_index":0,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_GOLD_STARS","source_palette_tag":"ANIM_TAG_GOLD_STARS","source_oam":"&gOamData_837DF2C","source_module":"charge_contract","source_args":[-48,-64,72,32,30],"travel_ticks":30,"child_binding":{"op":"effect","behavior":"source_particle","mode":"meteor_trail","selector":"target","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":62,"frame_size":[8,8],"frame_program":[{"op":"frame","tile":4,"ticks":1},{"op":"end"}],"frame_commands":[{"tile":4,"ticks":1},{"tile":5,"ticks":1}],"affine_program":[],"source_template":"gSpriteTemplate_8402500","source_callback":"sub_812D588","source_animation_index":0,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_GOLD_STARS","source_palette_tag":"ANIM_TAG_GOLD_STARS","source_oam":"&gOamData_837DF24","source_module":"charge_contract","source_args":[],"texture":"res://graficos/batalla/animaciones/gold_stars_pal_233_8x8_4_5.png","frame_rects":{"4":[0,0,8,8],"5":[0,8,8,8]},"source_absolute_priority":5,"source_private":["sub_812D5E8"],"native_substitution":"Seeded native RNG retains source tile4/5 probability and signed y-offset range; no hardware RNG equality claimed"},"source_private":["sub_81311E4","sub_812D588","sub_812D5E8"],"texture":"res://graficos/batalla/animaciones/gold_stars_pal_233_16x16_0.png","frame_rects":{"0":[0,0,16,16]},"source_line":8692,"source_priority_basis":"target","source_priority_arg":3},
			{"op":"source_control","condition":"always","target":7442},
			{"op":"source_label","source_pc":7442,"source_line":8693,"source_command":"delay 10"},
			{"op":"wait","ticks":10,"source_line":8693},
			{"op":"source_control","condition":"always","target":7443},
			{"op":"source_label","source_pc":7443,"source_line":8694,"source_command":"createsprite gBattleAnimSpriteTemplate_8402A3C, ANIM_BATTLER_TARGET, 3, -112, -64, 8, 32, 30","source_args":[-112,-64,8,32,30]},
			{"op":"effect","behavior":"source_particle","mode":"meteor_star","selector":"target","offset":[0,0],"mirror_offset":false,"offset_direction":"toward_target","ticks":31,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":0,"ticks":1},{"op":"end"}],"frame_commands":[{"tile":0,"ticks":1}],"affine_program":[],"source_template":"gBattleAnimSpriteTemplate_8402A3C","source_callback":"sub_8131264","source_animation_index":0,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_GOLD_STARS","source_palette_tag":"ANIM_TAG_GOLD_STARS","source_oam":"&gOamData_837DF2C","source_module":"charge_contract","source_args":[-112,-64,8,32,30],"travel_ticks":30,"child_binding":{"op":"effect","behavior":"source_particle","mode":"meteor_trail","selector":"target","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":62,"frame_size":[8,8],"frame_program":[{"op":"frame","tile":4,"ticks":1},{"op":"end"}],"frame_commands":[{"tile":4,"ticks":1},{"tile":5,"ticks":1}],"affine_program":[],"source_template":"gSpriteTemplate_8402500","source_callback":"sub_812D588","source_animation_index":0,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_GOLD_STARS","source_palette_tag":"ANIM_TAG_GOLD_STARS","source_oam":"&gOamData_837DF24","source_module":"charge_contract","source_args":[],"texture":"res://graficos/batalla/animaciones/gold_stars_pal_233_8x8_4_5.png","frame_rects":{"4":[0,0,8,8],"5":[0,8,8,8]},"source_absolute_priority":5,"source_private":["sub_812D5E8"],"native_substitution":"Seeded native RNG retains source tile4/5 probability and signed y-offset range; no hardware RNG equality claimed"},"source_private":["sub_81311E4","sub_812D588","sub_812D5E8"],"texture":"res://graficos/batalla/animaciones/gold_stars_pal_233_16x16_0.png","frame_rects":{"0":[0,0,16,16]},"source_line":8694,"source_priority_basis":"target","source_priority_arg":3},
			{"op":"source_control","condition":"always","target":7444},
			{"op":"source_label","source_pc":7444,"source_line":8695,"source_command":"delay 40"},
			{"op":"wait","ticks":40,"source_line":8695},
			{"op":"source_control","condition":"always","target":7445},
			{"op":"source_label","source_pc":7445,"source_line":8696,"source_command":"createsprite gBattleAnimSpriteTemplate_83DA024, ANIM_BATTLER_TARGET, 3, 0, 0, 0, 30","source_args":[0,0,0,30]},
			{"op":"effect","behavior":"source_particle","mode":"spinning_strike","selector":"target","offset":[0,0],"mirror_offset":false,"offset_direction":"toward_target","ticks":53,"frame_size":[32,32],"frame_program":[{"op":"frame","tile":0,"ticks":1,"flip_h":false,"flip_v":false},{"op":"end"}],"frame_commands":[{"tile":0,"ticks":1,"flip_h":false,"flip_v":false}],"affine_program":[{"op":"frame","x":256,"y":256,"rotation":0,"ticks":0},{"op":"frame","x":-8,"y":-8,"rotation":20,"ticks":1},{"op":"jump","target":1}],"source_template":"gBattleAnimSpriteTemplate_83DA024","source_callback":"AnimSpinningKickOrPunch","source_animation_index":0,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_HANDS_AND_FEET","source_palette_tag":"ANIM_TAG_HANDS_AND_FEET","source_oam":"&gOamData_837DFF4","source_module":"charge_contract","source_args":[0,0,0,30],"spin_ticks":30,"frame_transition_ticks":32,"replacement_affine_program":[{"op":"frame","x":256,"y":256,"rotation":0,"ticks":0},{"op":"end"}],"source_private":["WaitAnimForDuration","AnimSpinningKickOrPunchFinish","DestroyAnimSprite"],"texture":"res://graficos/batalla/animaciones/hands_and_feet_pal_143_32x32_0.png","frame_rects":{"0":[0,0,32,32]},"source_line":8696,"source_priority_basis":"target","source_priority_arg":3},
			{"op":"source_control","condition":"always","target":7446},
			{"op":"source_label","source_pc":7446,"source_line":8697,"source_command":"createsprite gBattleAnimSpriteTemplate_8402A3C, ANIM_BATTLER_TARGET, 3, -80, -64, 40, 32, 30","source_args":[-80,-64,40,32,30]},
			{"op":"effect","behavior":"source_particle","mode":"meteor_star","selector":"target","offset":[0,0],"mirror_offset":false,"offset_direction":"toward_target","ticks":31,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":0,"ticks":1},{"op":"end"}],"frame_commands":[{"tile":0,"ticks":1}],"affine_program":[],"source_template":"gBattleAnimSpriteTemplate_8402A3C","source_callback":"sub_8131264","source_animation_index":0,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_GOLD_STARS","source_palette_tag":"ANIM_TAG_GOLD_STARS","source_oam":"&gOamData_837DF2C","source_module":"charge_contract","source_args":[-80,-64,40,32,30],"travel_ticks":30,"child_binding":{"op":"effect","behavior":"source_particle","mode":"meteor_trail","selector":"target","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":62,"frame_size":[8,8],"frame_program":[{"op":"frame","tile":4,"ticks":1},{"op":"end"}],"frame_commands":[{"tile":4,"ticks":1},{"tile":5,"ticks":1}],"affine_program":[],"source_template":"gSpriteTemplate_8402500","source_callback":"sub_812D588","source_animation_index":0,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_GOLD_STARS","source_palette_tag":"ANIM_TAG_GOLD_STARS","source_oam":"&gOamData_837DF24","source_module":"charge_contract","source_args":[],"texture":"res://graficos/batalla/animaciones/gold_stars_pal_233_8x8_4_5.png","frame_rects":{"4":[0,0,8,8],"5":[0,8,8,8]},"source_absolute_priority":5,"source_private":["sub_812D5E8"],"native_substitution":"Seeded native RNG retains source tile4/5 probability and signed y-offset range; no hardware RNG equality claimed"},"source_private":["sub_81311E4","sub_812D588","sub_812D5E8"],"texture":"res://graficos/batalla/animaciones/gold_stars_pal_233_16x16_0.png","frame_rects":{"0":[0,0,16,16]},"source_line":8697,"source_priority_basis":"target","source_priority_arg":3},
			{"op":"source_control","condition":"always","target":7447},
			{"op":"source_label","source_pc":7447,"source_line":8698,"source_command":"delay 20"},
			{"op":"wait","ticks":20,"source_line":8698},
			{"op":"source_control","condition":"always","target":7448},
			{"op":"source_label","source_pc":7448,"source_line":8699,"source_command":"playsewithpan SE_M_VITAL_THROW2, SOUND_PAN_TARGET"},
			{"op":"sound","path":"res://Audio/SE/PRSFX- Vital Throw2.wav","source_sound":"SE_M_VITAL_THROW2","source_pan":"SOUND_PAN_TARGET","repeat":1,"interval":1,"sound_delay":0,"source_line":8699},
			{"op":"source_control","condition":"always","target":7449},
			{"op":"source_label","source_pc":7449,"source_line":8700,"source_command":"createsprite gBasicHitSplatSpriteTemplate, ANIM_BATTLER_TARGET, 3, 0, 0, 1, 1","source_args":[0,0,1,1]},
			{"op":"effect","behavior":"sheet","ticks":8,"texture":"res://graficos/batalla/animaciones/impact.png","frame_size":[32,32],"frame_commands":[{"tile":0,"ticks":12}],"selector":"target","source_template":"gBasicHitSplatSpriteTemplate","source_callback":"sub_80E27A0","offset":[0,0],"source_affine_variant":1,"scale_factor":1.1851851851851851,"source_line":8700},
			{"op":"source_control","condition":"always","target":7450},
			{"op":"source_label","source_pc":7450,"source_line":8701,"source_command":"createvisualtask AnimTask_ShakeMon2, 2, ANIM_BATTLER_TARGET, 5, 0, 20, 1","source_args":[1,5,0,20,1]},
			{"op":"effect","behavior":"source_actor","ticks":39,"selector":"target","mode":"signed","count":20,"delay":1,"x":5,"y":0,"source_task":"AnimTask_ShakeMon2","source_line":8701},
			{"op":"source_control","condition":"always","target":7451},
			{"op":"source_label","source_pc":7451,"source_line":8702,"source_command":"waitforvisualfinish"},
			{"op":"barrier","source_line":8702},
			{"op":"source_control","condition":"always","target":7452},
			{"op":"source_label","source_pc":7452,"source_line":8703,"source_command":"delay 10"},
			{"op":"wait","ticks":10,"source_line":8703},
			{"op":"source_control","condition":"always","target":7453},
			{"op":"source_label","source_pc":7453,"source_line":8704,"source_command":"restorebg"},
			{"op":"effect","behavior":"source_background","ticks":32,"source_fade_out_ticks":16,"restore":true,"source_background_id":0,"texture":"res://graficos/batalla/animaciones/bg_00.png","palette_cycle_height":256,"palette_cycle_count":1,"source_line":8704},
			{"op":"source_control","condition":"always","target":7454},
			{"op":"source_label","source_pc":7454,"source_line":8705,"source_command":"waitbgfadein"},
			{"op":"background_barrier","phase":"in","source_line":8705},
			{"op":"source_control","condition":"always","target":7455},
			{"op":"source_label","source_pc":7455,"source_line":8706,"source_command":"waitforvisualfinish"},
			{"op":"barrier","source_line":8706},
			{"op":"source_control","condition":"always","target":7456},
			{"op":"source_label","source_pc":7456,"source_line":8707,"source_command":"end"},
			{"op":"source_control","condition":"end","source_line":8707},
			{"op":"marker","name":"impact"},
			{"op":"barrier"},
			{"op":"end"},
		],
	},
}

# Original builtin identity is checked before mutable key/script fields.
static func _key(owner: Node2D) -> String:
	if not owner is BattleAnimationSequenceRunner or owner.definition==null:return ""
	for key: String in PROGRAMS:
		if is_same(owner.definition,BattleAnimationSequenceRegistry._builtin_source_definitions.get(key)):return key
	return ""

static func matches(owner: Node2D) -> bool:return not _key(owner).is_empty()

static func _number(value: Variant) -> bool:return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value))

static func _art(step: Dictionary) -> bool:return step.get("behavior") in ["source_particle","sheet"] and step.has("frame_commands")

static func _rects(step: Dictionary) -> Dictionary:
	if not step.get("texture") is String or not ResourceLoader.exists(step.texture):return {}
	var texture: Resource=load(step.texture)
	if not texture is Texture2D:return {}
	for key: String in ["recolor","flip_h","flip_v"]:
		if step.has(key) and typeof(step[key])!=TYPE_BOOL:return {}
	if step.has("scale_factor") and not _number(step.scale_factor):return {}
	if step.has("color") and (not step.color is String or not Color.html_is_valid(step.color)):return {}
	if not step.get("frame_commands") is Array or not step.get("frame_size") is Array:return {}
	var tiles: Dictionary={}
	for frame: Variant in step.frame_commands:
		if not frame is Dictionary or not _number(frame.get("tile")):return {}
		tiles[str(int(frame.tile))]=true
	if step.has("frame_rects") and (not step.frame_rects is Dictionary or step.frame_rects.size()!=tiles.size()):return {}
	var result: Dictionary={}
	for key: String in tiles:
		var rectangle: Variant
		if step.has("frame_rects"):
			if not step.frame_rects.has(key):return {}
			rectangle=step.frame_rects[key]
		else:
			var columns: int=texture.get_width()/8
			if columns<=0 or step.frame_size.size()!=2:return {}
			var tile: int=int(key);rectangle=[(tile%columns)*8,(tile/columns)*8,step.frame_size[0],step.frame_size[1]]
		if not rectangle is Array or rectangle.size()!=4:return {}
		for value: Variant in rectangle:
			if not _number(value) or float(value)!=floorf(float(value)):return {}
		if rectangle[0]<0 or rectangle[1]<0 or rectangle[2]<=0 or rectangle[3]<=0 or rectangle[0]+rectangle[2]>texture.get_width() or rectangle[1]+rectangle[3]>texture.get_height():return {}
		result[key]=rectangle.duplicate()
	return result

static func _shape(actual: Variant,expected: Dictionary) -> bool:
	if not actual is Dictionary:return false
	var art: bool=_art(expected)
	for key: String in expected:
		if art and key in ART:continue
		if not actual.has(key):return false
		if key=="child_binding":
			if not _shape(actual[key],expected[key]):return false
		elif not Same._same(actual[key],expected[key]):return false
	for key: String in actual:
		if not expected.has(key) and (not art or key not in ART):return false
	return not art or not _rects(actual).is_empty()

static func _whole(owner: Node2D) -> bool:
	var key: String=_key(owner)
	if key.is_empty():return false
	var expected: Dictionary=PROGRAMS[key]
	if owner.definition.key!=key or owner.definition.source_script!=expected.source_script or owner.definition.coverage!=expected.coverage or not Same._same(owner._steps,owner.definition.steps):return false
	for program: Array in [owner.definition.steps,owner._steps]:
		if program.size()!=expected.steps.size():return false
		for pc: int in program.size():
			if not _shape(program[pc],expected.steps[pc]):return false
	return true

static func _group(owner: Node2D) -> Session:
	return owner.get_meta(STATE) as Session if owner.has_meta(STATE) else null

class Invocation extends RefCounted:
	var incoming: Dictionary
	var owner: Node2D
	var context: BattleAnimationContext
	var definition: BattleAnimationDefinition
	var pc: int

# Separate from the consumed one-shot claim: exists only on the real factory stack.
static func open_dispatch(owner: Node2D,step: Dictionary) -> Invocation:
	if not matches(owner):return null
	var invocation:=Invocation.new();invocation.incoming=step;invocation.owner=owner;invocation.context=owner.context;invocation.definition=owner.definition;invocation.pc=owner._pc
	owner._source_spinning_invocation=invocation
	return invocation

static func close_dispatch(owner: Node2D,invocation: Invocation) -> void:
	if invocation==null:return
	var group: Session=_group(owner)
	if group!=null:
		for token: Admission in group.pending.keys():
			if is_same(group.pending[token].scope,invocation):group.pending.erase(token)
	if is_same(owner._source_spinning_invocation,invocation):owner._source_spinning_invocation=null

static func _live_invocation(owner: Node2D,c: BattleAnimationContext,step: Dictionary) -> Invocation:
	var invocation: Invocation=owner._source_spinning_invocation as Invocation
	if invocation==null or invocation.owner!=owner or not is_same(invocation.context,c) or not is_same(invocation.definition,owner.definition) or invocation.pc!=owner._pc or not is_same(invocation.incoming,step):return null
	return invocation

static func _admit(step: Dictionary,c: BattleAnimationContext,owner: Node2D,behavior: String) -> bool:
	var group: Session=_group(owner)
	if group!=null and not group.valid:return false
	if _live_invocation(owner,c,step)==null:return false
	if not matches(owner) or not is_same(owner.context,c) or not _whole(owner):return false
	var program: Array=PROGRAMS[_key(owner)].steps;var pc: int=owner._pc
	if pc<=0 or pc>=program.size() or program[pc].get("behavior")!=behavior:return false
	var plain: Dictionary=step.duplicate(true);var priority: Dictionary=BattleSourcePriority.command_metadata(program[pc-1])
	if not priority.is_empty():
		if not Same._same(plain.get("source_command_priority"),priority):return false
		plain.erase("source_command_priority")
	elif plain.has("source_command_priority"):return false
	if not _shape(plain,program[pc]) or not Same._same(plain,owner._steps[pc]):return false
	return owner.claim_effect_dispatch(step)

class Admission extends RefCounted:
	var owner: Node2D
	var context: BattleAnimationContext
	var step: Dictionary
	var child: bool=false
	var used: bool=false

class ChildScope extends RefCounted:
	var parent: Dictionary
	var context: BattleAnimationContext
	var expected: Dictionary
	var age: int
	var used: bool=false

class AliasHideLease extends RefCounted:
	var actor: BattleAnimationActor
	var sprite: Sprite2D
	var context: BattleAnimationContext
	var aliases: Array[BattleAnimationActor]=[]
	var base_visible: bool
	func release_view() -> void:
		if actor.sprite!=sprite or not actor.is_present():return
		for occupant: BattleAnimationActor in context.actors.values():
			if occupant.sprite==sprite and occupant not in aliases:return
		if actor._owned_hidden and not actor._expected_visible:
			if not sprite.visible:sprite.visible=base_visible
			actor._owned_hidden=false

class Session extends RefCounted:
	var context: BattleAnimationContext
	var definition: BattleAnimationDefinition
	var eligible: Dictionary={}
	var originals: Dictionary={}
	var original_sprites: Dictionary={}
	var program: Array=[]
	var pending: Dictionary={}
	var palette_seen: Dictionary={}
	var objects: Array[Dictionary]=[]
	var episodes: Array[Dictionary]=[]
	var writers: Array[Dictionary]=[]
	var scope: ChildScope
	var valid: bool=true

static func _session(owner: Node2D,c: BattleAnimationContext) -> Session:
	var group: Session=_group(owner)
	if group==null:
		group=Session.new();group.context=c;group.definition=owner.definition;group.program=owner._steps.duplicate(true)
		for actor: BattleAnimationActor in c.actors.values():group.eligible[actor]=actor.is_present() and actor.sprite.is_visible_in_tree() and (not c.contest or actor.id==c.attacker_id)
		for actor: BattleAnimationActor in c.actors.values():group.originals[actor.id]=actor;group.original_sprites[actor.id]=actor.sprite
		owner.set_meta(STATE,group)
	return group

static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if not _admit(step,c,owner,"source_legacy_impact_command"):return []
	_session(owner,c)
	var trace: Array=owner.get_meta("source_legacy_impact_commands",[]);trace.append(int(step.source_line));owner.set_meta("source_legacy_impact_commands",trace)
	match str(step.mode):
		"setalpha","blendoff":
			owner.set_meta("source_legacy_impact_alpha",[12,8] if step.mode=="setalpha" else [16,0])
			for item: Dictionary in owner.get_meta("source_legacy_impact_objects",[]):
				if step.mode=="blendoff":_release_material(item)
				else:Owned.uniform(item,"eva",0.75);Owned.uniform(item,"evb",0.5)
			return []
		"clearmonbg":
			for t: Dictionary in owner.get_meta("source_legacy_impact_backgrounds",[]):Pair._clear_pair(t)
			return []
	var tracks: Array[Dictionary]=Pair._create_pair_bg(c,owner,1,"source_legacy_impact_bg","source_legacy_impact_backgrounds")
	for t: Dictionary in tracks:
		t.update=_advance_background
		for item: Dictionary in t.clones:
			var aliases: Array[BattleAnimationActor]=[]
			for actor: BattleAnimationActor in c.actors.values():
				if actor.sprite==item.sprite:aliases.append(actor)
			if aliases.size()>1 and item.projection==null:
				var projection:=AliasHideLease.new();projection.actor=item.actor;projection.sprite=item.sprite;projection.context=c;projection.aliases=aliases;projection.base_visible=item.base_visible;item.projection=projection
	_order(owner,c);return tracks

# Preallocation receipt: ordinary original dispatch OR a real synchronous parent's
# one-shot scoped child; neither copied metadata nor a parked PC grants admission.
static func prepare(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Dictionary:
	if not matches(owner):return {"handled":false}
	var group: Session=_group(owner);var child: bool=step.get("mode")=="meteor_trail"
	if child:
		if group==null or group.scope==null or not group.valid or not _whole(owner):return {"handled":true}
		var scope: ChildScope=group.scope
		if scope.used or not is_same(scope.context,c) or not Same._same(scope.expected,step) or not group.objects.any(func(item: Dictionary)->bool:return is_same(item,scope.parent)) or not scope.parent.has("track") or int(scope.parent.track.age)!=scope.age:return {"handled":true}
		scope.used=true
	elif not _admit(step,c,owner,str(step.get("behavior",""))):return {"handled":true}
	var admission:=Admission.new();admission.owner=owner;admission.context=c;admission.child=child;admission.step=step.duplicate(true)
	var normalized: Dictionary=step.duplicate(true);normalized.frame_rects=_rects(step)
	if group==null:group=_session(owner,c)
	var role: BattleAnimationActor=group.originals.get(c.target_ids[0]) if not c.target_ids.is_empty() else null
	group.pending[admission]={"owner":owner,"context":c,"definition":owner.definition,"pc":owner._pc,"incoming":step,"original":step.duplicate(true),"normalized":normalized.duplicate(true),"child":child,"role":role,"sprite":group.original_sprites.get(role.id) if role!=null else null,"scope":group.scope if child else owner._source_spinning_invocation}
	return {"handled":true,"step":normalized,"admission":admission}

static func _anchor(c: BattleAnimationContext,actor: BattleAnimationActor) -> Vector2:
	return c.field.to_local(actor.sprite.get_parent().to_global(actor.sprite.transform*actor.sprite.get_rect().get_center()-actor._offset))

# The issued handle delegates ONE construction inside its original live scope.
# Validate the immutable recipe before binding the actual Dictionary AND Sprite.
static func _construction(t: Dictionary,c: BattleAnimationContext,owner: Node2D,record: Dictionary,group: Session) -> bool:
	if not t.get("settings") is Dictionary:return false
	var expected: Dictionary=record.normalized.duplicate(true)
	# The unchanged native particle preparer adds exactly this derived context
	# field. Delegated construction may use the original normalized recipe.
	if expected.behavior=="source_particle" and t.get("settings",{}).has("source_contest"):expected.source_contest=c.contest
	var required: Array=["kind","age","ticks","node","origin","destination","arc","phase","arrival_marker","settings","source_side","field_size","ally_crossing"]
	var optional: Array=["source_context","source_owner","source_contest","last_spawn_age","source_fixed_tile","source_priority_actor_id","source_oam_subpriority","source_oam_priority","source_layer_floor","target_layer"]
	for key: String in required:
		if not t.has(key):return false
	for key: Variant in t:
		if key not in required and key not in optional:return false
	if t.kind!=expected.behavior or not Same._same(t.settings,expected) or not Same._same(t.age,0) or not _number(t.ticks) or float(t.ticks)!=float(expected.ticks):return false
	if not t.origin is Vector2 or not t.destination is Vector2 or not t.origin.is_finite() or not t.destination.is_finite() or not Same._same(t.arc,0.0) or not Same._same(t.phase,0.0) or t.arrival_marker!="":return false
	var side: int=c.actors[c.attacker_id].side if c.actors.has(c.attacker_id) else 0
	var crossing: bool=c.actors.has(c.attacker_id) and not c.resolve("target").is_empty() and c.actors[c.attacker_id].side==c.resolve("target")[0].side
	if typeof(t.source_side)!=TYPE_INT or t.source_side!=side or not t.field_size is Vector2 or t.field_size!=c.field_size or typeof(t.ally_crossing)!=TYPE_BOOL or t.ally_crossing!=crossing:return false
	if not t.node is Sprite2D or not is_instance_valid(t.node) or not t.node.is_inside_tree() or t.node.is_queued_for_deletion() or t.node.get_parent()!=owner:return false
	var node: Sprite2D=t.node;var size: Array=expected.frame_size
	if node.texture!=load(expected.texture) or not node.region_enabled or node.region_rect!=Rect2(0,0,size[0],size[1]) or node.hframes!=1 or node.vframes!=1 or node.frame!=0 or not node.centered or node.offset!=Vector2.ZERO or node.flip_h or node.flip_v:return false
	if node.scale!=Vector2.ONE*BattleEffectBehaviorRegistry._sheet_scale_factor(expected,owner,str(t.kind)) or node.modulate!=Color(str(expected.get("color","ffffff"))):return false
	if expected.get("recolor",false):
		if not node.material is ShaderMaterial or node.material.shader!=BattleEffectBehaviorRegistry.Recolor or node.material.get_shader_parameter("tint")!=node.modulate:return false
	elif node.material!=null:return false
	if group.objects.any(func(item: Dictionary)->bool:return is_same(item.track,t) or item.node==node):return false
	if t.has("source_layer_floor") and (typeof(t.source_layer_floor)!=TYPE_INT or t.source_layer_floor!=BattleSourcePriority.effective_layer(c.field)-BattleSourcePriority.effective_layer(owner)):return false
	if t.has("target_layer"):
		var targets: Array[BattleAnimationActor]=c.resolve("target")
		if targets.is_empty() or typeof(t.target_layer)!=TYPE_INT or t.target_layer!=BattleSourcePriority.actor_layer(targets[0],owner):return false
	if t.has("source_owner") and t.source_owner!=owner:return false
	if t.has("source_context"):
		if not t.source_context is BattleAnimationContext:return false
		var snapshot: BattleAnimationContext=t.source_context
		if snapshot.field!=c.field or snapshot.field_size!=c.field_size or snapshot.attacker_id!=c.attacker_id or snapshot.target_ids!=c.target_ids or snapshot.actors!=c.actors or snapshot.source_positions!=c.source_positions or snapshot.contest!=c.contest or snapshot.seed_value!=c.seed_value:return false
	if t.has("source_contest") and (typeof(t.source_contest)!=TYPE_BOOL or t.source_contest!=c.contest):return false
	if t.has("last_spawn_age") and not Same._same(t.last_spawn_age,-1):return false
	if record.child:
		if not t.has("source_fixed_tile") or typeof(t.source_fixed_tile)!=TYPE_INT or int(t.source_fixed_tile) not in [4,5]:return false
		var point:=Vector2(record.original.absolute_origin[0],record.original.absolute_origin[1])
		var rng:=RandomNumberGenerator.new();rng.seed=c.seed_value+owner.elapsed_ticks*977+owner.get_child_count()*37
		var tile: int=4 if (rng.randi()&3)==0 else 5
		var dy: int=int(rng.randi())&7;dy=-dy if dy>3 else dy
		if t.source_fixed_tile!=tile or t.destination!=point or t.origin!=point+Vector2(0,dy):return false
	elif t.has("source_fixed_tile"):return false
	var priorities: Array=["source_priority_actor_id","source_oam_subpriority","source_oam_priority"]
	if priorities.any(func(key: String)->bool:return t.has(key)):
		if not expected.has("source_command_priority"):return false
		var metadata: Dictionary=expected.source_command_priority
		var basis: Array[BattleAnimationActor]=c.resolve(str(metadata.basis))
		if basis.is_empty() or not basis[0].is_present():return false
		var values: Array=[basis[0].id,maxi(3,BattleElectricContract.source_subpriority(basis[0],c)+int(metadata.delta)),2]
		for index: int in priorities.size():
			if not t.has(priorities[index]) or typeof(t[priorities[index]])!=TYPE_INT or t[priorities[index]]!=values[index]:return false
	return true

static func attach(t: Dictionary,c: BattleAnimationContext,owner: Node2D,admission: Admission) -> void:
	var group: Session=_group(owner)
	if group==null or not group.valid or admission==null or not group.pending.has(admission) or admission.used:return
	var record: Dictionary=group.pending[admission]
	if record.owner!=owner or not is_same(record.context,c) or not is_same(record.definition,owner.definition) or record.pc!=owner._pc or group.definition!=owner.definition or not is_same(group.context,owner.context) or not _whole(owner) or not Same._same(owner._steps,group.program):return
	if admission.owner!=owner or not is_same(admission.context,c) or admission.child!=record.child or not Same._same(admission.step,record.original):return
	if record.child:
		if not is_same(group.scope,record.scope) or group.scope==null or not group.scope.used or not is_same(group.scope.context,c) or not Same._same(record.incoming,group.scope.expected):return
	else:
		if not is_same(_live_invocation(owner,c,record.incoming),record.scope) or not Same._same(record.incoming,record.original):return
		if record.role==null or not record.role.is_present() or group.originals.get(record.role.id)!=record.role or record.role.sprite!=record.sprite:return
	if not _construction(t,c,owner,record,group):return
	group.pending.erase(admission);admission.used=true
	var origin: Vector2=t.origin;var destination: Vector2=t.destination;var actor: BattleAnimationActor
	var step: Dictionary=t.settings;var mode: String=step.get("mode","")
	if not admission.child:
		actor=group.originals.get(c.target_ids[0]) if not c.target_ids.is_empty() else null
		if actor==null or not actor.is_present():return
		origin=_anchor(c,actor);destination=origin
		if mode=="blaze_scatter":origin+=Vector2(0,10);destination=origin
		if mode=="meteor_star":
			var direction: int=-1 if actor.side==0 or c.contest else 1
			origin+=Vector2(step.source_args[0]*direction,step.source_args[1]);destination=_anchor(c,actor)+Vector2(step.source_args[2]*direction,step.source_args[3])
	var role: BattleAnimationActor=actor
	if owner.definition.key in ["ruby:move/5","ruby:move/25"]:role=c.actors.get(c.attacker_id)
	var delta: int=3 if mode in ["spinning_strike","meteor_star"] or owner.definition.key=="ruby:move/309" else 1 if mode=="blaze_scatter" else 2
	var subpriority: int=5 if admission.child else maxi(3,BattleElectricContract.source_subpriority(role,c)-delta) if role!=null else 3
	var item: Dictionary={"node":t.node,"parent":owner,"context":group.context,"definition":owner.definition,"track":t,"origin":origin,"destination":destination,"mode":mode,"factor":float(step.get("scale_factor",1.0)),"subpriority":subpriority,"writes":{},"lost":{},"material":null,"previous":t.node.material,"shader":null,"uniforms":{},"revoked":{},"lost_material":false,"active":true,"last_counter":-1,"pending":true,"frozen_step":step.duplicate(true),"frozen_context":BattleChargeContract.frozen_context(group.context)}
	if step.get("source_callback")=="sub_80E27A0":item.factor=BattleEffectBehaviorRegistry._sheet_scale_factor(step,owner,str(t.kind))
	if step.get("source_callback")=="sub_80E27A0" and owner.definition.key!="ruby:move/309" and t.node.material==null and not step.get("recolor",false):
		var material: ShaderMaterial=BattleIdentityCopy.blend_material(false);material.set_shader_parameter("eva",0.75);material.set_shader_parameter("evb",0.5);t.node.material=material;item.material=material;item.shader=material.shader
		for key: String in ["eva","evb","first_tint"]:item.uniforms[key]=material.get_shader_parameter(key)
	t.origin=origin;t.destination=destination;t.source_oam_priority=2;t.source_oam_subpriority=subpriority;t.source_priority_actor_id=role.id if role!=null else -1
	t.i156_item=item;t.update=_advance;t.cleanup=_release_art.bind(item);group.objects.append(item)
	if owner.definition.key!="ruby:move/309":
		var objects: Array=owner.get_meta("source_legacy_impact_objects",[]);objects.append(item);owner.set_meta("source_legacy_impact_objects",objects)
	_order(owner,group.context)

static func _advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	var item: Dictionary=t.i156_item;var owner: Node2D=item.parent;var group: Session=_group(owner)
	if group==null or not group.valid or not Owned.node(item):return
	if not Same._same(t.settings,item.frozen_step):return
	if not item.pending and not owner._tracks.any(func(live: Dictionary)->bool:return is_same(live,t)):return
	item.pending=false
	var age: int=maxi(0,int(t.age));var point: Vector2=item.origin;var angle: float=0;var factor: float=item.factor;var tile: int=int(t.settings.frame_commands[0].tile)
	match str(item.mode):
		"spinning_strike":
			var reset: int=52 if owner.definition.key in ["ruby:move/5","ruby:move/25"] else 32;var delta: int=4 if reset==52 else 8
			if age<reset:factor*=float(256-delta*age)/256.0;angle=((age*20)&255)*TAU/256.0
		"blaze_scatter":
			var count: int=mini(age,40);point+=Vector2(floorf(t.settings.velocity[0]*count/256.0),floorf(t.settings.velocity[1]*count/256.0));tile=[16,32,48][(age/4)%3]
		"meteor_star":
			var count: int=mini(age,30);var delta: Vector2=item.destination-item.origin;point+=Vector2(int(delta.x*count/30.0),int(delta.y*count/30.0))
		"meteor_trail":
			tile=int(t.source_fixed_tile)
	Owned.write(item,"transform",owner.global_transform.affine_inverse()*group.context.field.global_transform*Transform2D(angle,Vector2.ONE*factor,0,point))
	var rect: Array=t.settings.frame_rects[str(tile)];Owned.write(item,"region_rect",Rect2(rect[0],rect[1],rect[2],rect[3]))
	Owned.write(item,"flip_h",bool(t.settings.get("flip_h",false))!=bool(t.settings.frame_commands[0].get("flip_h",false)));Owned.write(item,"flip_v",bool(t.settings.get("flip_v",false))!=bool(t.settings.frame_commands[0].get("flip_v",false)))
	var visible: bool=true
	if item.mode=="meteor_trail":visible=(age/2)%2==0 if age<30 else age%4!=3
	Owned.write(item,"visible",visible)
	if item.mode=="meteor_star" and age<=30 and age%2==0 and int(item.last_counter)!=age:
		item.last_counter=age
		var scope:=ChildScope.new();scope.parent=item;scope.context=item.frozen_context;scope.age=age;scope.expected=t.settings.child_binding.duplicate(true);scope.expected.absolute_origin=[point.x,point.y];group.scope=scope
		BattleChargeContract.spawn_child(owner,scope.context,t.settings.child_binding,{"absolute_origin":[point.x,point.y]},"maintenance")
		for token: Admission in group.pending.keys():
			if is_same(group.pending[token].scope,scope):group.pending.erase(token)
		group.scope=null

static func _release_material(item: Dictionary) -> void:
	if not item.active:return
	if Owned.observe_material(item) and item.revoked.is_empty():item.node.material=item.previous
	item.active=false

static func _release_art(item: Dictionary) -> void:
	var track: Dictionary=item.get("track",{})
	if not track.is_empty():
		if not Owned.node(item):track.erase("node")
		track.erase("cleanup");track.erase("i156_item")
	item.erase("track");_release_material(item)
	if is_instance_valid(item.parent):
		var group: Session=_group(item.parent)
		if group!=null:group.objects.erase(item)

static func palette_members(owner: Node2D,c: BattleAnimationContext,step: Dictionary,incoming: Dictionary) -> Dictionary:
	if not matches(owner):return {"handled":false}
	if not _admit(incoming,c,owner,"source_palette"):return {"handled":true,"rejected":true,"actors":[]}
	var group: Session=_session(owner,c);var actors: Array[BattleAnimationActor]=[];var seen: Dictionary={}
	if not step.has("palette_states"):
		for actor: BattleAnimationActor in c.resolve("target"):
			if actor.is_present() and group.originals.get(actor.id)==actor and group.original_sprites.get(actor.id)==actor.sprite:actors.append(actor)
	elif step.selector!="background":
		var role: int=["attacker","target","attacker_partner","target_partner"].find(str(step.selector))
		if role>=0:
			var line: int=int(step.source_line)
			if not group.palette_seen.has(line):group.palette_seen[line]={}
			seen=group.palette_seen[line]
			var primary: int=c.attacker_id if role in [0,2] else c.target_ids[0];var position: int=c.source_position(primary)^(2 if role>=2 else 0)
			for actor: BattleAnimationActor in c.actors.values():
				if group.originals.get(actor.id)!=actor or group.original_sprites.get(actor.id)!=actor.sprite or c.source_position(actor.id)!=position or not actor.is_present() or seen.has(actor.sprite) or (role>=2 and not group.eligible.get(actor,false)):continue
				seen[actor.sprite]=true;actors.append(actor)
	return {"handled":true,"actors":actors,"session":group}

static func admit_palette(owner: Node2D,c: BattleAnimationContext,t: Dictionary,selected: Dictionary) -> void:
	if not selected.has("session"):return
	var group: Session=selected.session
	if _group(owner)!=group or group.context!=c or not group.valid:return
	if not t.has("actor"):
		group.writers.append({"track":t,"episode":{},"revoked":false});return
	var actor: BattleAnimationActor=t.actor;var episode: Dictionary={}
	for old: Dictionary in group.episodes:
		if old.actor==actor and old.node==actor.sprite:episode=old;break
	if episode.is_empty():
		episode={"actor":actor,"node":actor.sprite,"parent":actor.sprite.get_parent(),"previous":actor.sprite.material,"initial_custom":actor.sprite.material!=null,"material":null,"shader":null,"uniforms":{},"revoked":{},"lost_material":false,"active":true,"held":{},"track":{},"writes":{},"lost":{}};group.episodes.append(episode)
	group.writers.append({"track":t,"episode":episode,"revoked":false})

static func _revoke_palette_writer(owner: Node2D,writer: Dictionary) -> void:
	writer.revoked=true
	var episode: Dictionary=writer.episode
	if episode.is_empty():return
	episode.palette_revoked=true
	if not is_same(episode.get("track"),writer.track):return
	var held: Dictionary=episode.get("held",{})
	if not held.is_empty() and is_same(owner._held_blends.get(episode.actor.id),held):owner._held_blends.erase(episode.actor.id)
	episode.erase("held");episode.erase("track")

# Exact admitted Dictionary identity, never a caller-supplied track marker.
# This runs before the generic callback can allocate an overlay or replace held intent.
static func palette_callback_allowed(owner: Node2D,c: BattleAnimationContext,t: Dictionary) -> bool:
	var group: Session=_group(owner)
	if group==null:return true
	for writer: Dictionary in group.writers:
		if not is_same(writer.track,t):continue
		if writer.revoked:return false
		var episode: Dictionary=writer.episode
		var valid: bool=group.valid and group.context==c and group.definition==owner.definition
		if not episode.is_empty():
			valid=valid and c.actors.get(episode.actor.id)==episode.actor and episode.actor.sprite==episode.node and episode.actor.is_present()
			if episode.has("held") and not episode.held.is_empty():valid=valid and is_same(owner._held_blends.get(episode.actor.id),episode.held)
		if not valid:_revoke_palette_writer(owner,writer);return false
		return true
	return false

static func note_palette_write(owner: Node2D,t: Dictionary,held: Dictionary) -> void:
	var group: Session=_group(owner)
	if group==null:return
	for writer: Dictionary in group.writers:
		if not is_same(writer.track,t):continue
		if not group.valid or writer.revoked or writer.episode.is_empty():return
		var episode: Dictionary=writer.episode;held.source_actor=episode.actor;episode.held=held;episode.track=t
		if not episode.has("source_held_history"):episode.source_held_history=[]
		episode.source_held_history.append({"identity":held,"color":held.color,"amount":held.amount})
		return

static func _independent_held(owner: Node2D,episode: Dictionary,blend: Dictionary) -> bool:
	if blend.is_empty() or not is_same(owner._held_blends.get(episode.actor.id),blend):return false
	for receipt: Dictionary in episode.get("source_held_history",[]):
		if is_same(blend,receipt.identity):return false
	return true

static func _handoff_palette(episode: Dictionary) -> void:
	if episode.get("handed_off",false):return
	# Detach only OUR still-owned material BEFORE generic apply_blend captures
	# its previous material. Foreign material/shader/uniform ownership is untouched.
	if episode.active and Owned.observe_material(episode) and episode.revoked.is_empty():episode.node.material=episode.previous
	episode.active=false;episode.lost_material=true;episode.handed_off=true

# The handled branch replaces BOTH generic blend and wave writes before entry.
static func handle_palette(owner: Node2D,c: BattleAnimationContext,actor: BattleAnimationActor,blend: Dictionary,transient: bool) -> bool:
	var group: Session=_group(owner)
	if group==null:return false
	for episode: Dictionary in group.episodes:
		if episode.actor!=actor:continue
		else:
			if transient or _independent_held(owner,episode,blend):
				for writer: Dictionary in group.writers:
					if is_same(writer.episode,episode):_revoke_palette_writer(owner,writer)
				_handoff_palette(episode);return false
			if episode.get("palette_revoked",false):return true
			if episode.initial_custom:return true
			if not group.valid or not episode.active:return true
			if actor.sprite!=episode.node or not actor.is_present() or not is_instance_valid(episode.parent) or episode.node.get_parent()!=episode.parent:return true
			if episode.held.is_empty():return false
			if not is_same(owner._held_blends.get(actor.id),episode.held):episode.lost_material=true;return true
			if episode.material==null and not episode.lost_material and float(blend.amount)>0:
				if episode.node.material!=episode.previous:episode.lost_material=true;return true
				var material:=ShaderMaterial.new();material.shader=load("res://scripts/battle/animations/sequence/palette_blend.gdshader");episode.material=material;episode.shader=material.shader
				for parameter: Dictionary in material.shader.get_shader_uniform_list():episode.uniforms[str(parameter.name)]=material.get_shader_parameter(str(parameter.name))
				episode.node.material=material
			Owned.uniform(episode,"blend_color",blend.color);Owned.uniform(episode,"blend_amount",blend.amount)
			return true
	return false


static func _observe(item: Dictionary) -> void:
	if not is_instance_valid(item.node):return
	for key: String in item.writes:
		if item.node.get(key)!=item.writes[key]:item.lost[key]=true
	if item.has("material"):Owned.observe_material(item)

static func begin_tick(owner: Node2D,c: BattleAnimationContext) -> void:
	var group: Session=_group(owner)
	if group==null:return
	if not _whole(owner) or not Same._same(owner._steps,group.program) or group.context!=c or group.definition!=owner.definition:group.valid=false;group.pending.clear()
	if not group.valid:
		for writer: Dictionary in group.writers:_revoke_palette_writer(owner,writer)
	for t: Dictionary in owner.get_meta("source_legacy_impact_backgrounds",[]):
		for item: Dictionary in t.clones:_observe(item)
	for item: Dictionary in group.objects:_observe(item)
	for episode: Dictionary in group.episodes:Owned.observe_material(episode)

static func _order(owner: Node2D,c: BattleAnimationContext) -> void:
	var group: Session=_group(owner)
	if group==null or not group.valid:return
	var band: int=BattleSourcePriority.effective_layer(c.field)-BattleSourcePriority.effective_layer(owner)+1
	for actor: BattleAnimationActor in c.actors.values():
		if actor.is_present():band=maxi(band,BattleSourcePriority.actor_layer(actor,owner))
	for track: Dictionary in owner.get_meta("source_legacy_impact_backgrounds",[]):
		for item: Dictionary in track.clones:
			if not item.retired and Owned.node(item):Owned.write(item,"z_index",band+(1 if int(item.bg_plane)==1 else 0))
	for item: Dictionary in group.objects:
		if Owned.node(item):Owned.write(item,"z_index",band+62-int(item.subpriority))

# Revocation must drain an uncleared maintenance episode without admitting a
# future clear command. Already-cleared pairs keep their two native callbacks.
static func _advance_background(t: Dictionary,c: BattleAnimationContext) -> void:
	var group: Session=_group(t.owner)
	if group!=null and not group.valid and not t.cleared:
		Pair._cleanup_pair(t);t.ticks=int(t.age)
		return
	Pair._advance_pair(t,c)

static func after_pose(owner: Node2D,c: BattleAnimationContext) -> void:
	var group: Session=_group(owner)
	if group==null or not group.valid:return
	for t: Dictionary in owner.get_meta("source_legacy_impact_backgrounds",[]):Pair._after_pair_pose(t)
	_order(owner,c)

static func release(owner: Node2D) -> void:
	var group: Session=_group(owner)
	if group==null:return
	for episode: Dictionary in group.episodes:
		if episode.active and Owned.observe_material(episode) and episode.revoked.is_empty():episode.node.material=episode.previous
		episode.active=false;episode.erase("held");episode.erase("track")
	group.pending.clear();group.writers.clear();group.episodes.clear();group.scope=null;owner.remove_meta(STATE)

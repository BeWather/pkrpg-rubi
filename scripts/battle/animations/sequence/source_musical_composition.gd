extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Finite traveling-note callback and musical-bank receipts. Other sound producers stay literal.
const Same=preload("res://scripts/battle/animations/sequence/source_cutting_slice.gd")
const Pair=preload("res://scripts/battle/animations/sequence/source_charge_owned.gd")
const Owned=preload("res://scripts/battle/animations/sequence/source_owned_composition.gd")
const Fast=preload("res://scripts/battle/animations/sequence/source_program_proof.gd")
const RECOLOR=preload("res://scripts/battle/animations/sequence/particle_recolor.gdshader")
const STATE="i158_musical_session"
const ART=["texture","frame_rects","color","recolor","scale_factor","flip_h","flip_v","palette_bank_height"]
const TAGS=[10072,10097,10185,10175]
# Frozen whole programs are inserted below from the reviewed literal source packet.
const PROGRAMS := {
	"ruby:move/47": {
		"key":"ruby:move/47",
		"coverage":"source-derived-unreviewed",
		"source_script":"Move_SING",
		"steps":[
			{"op":"source_control","condition":"always","target":1909},
			{"op":"source_label","source_pc":1909,"source_line":2546,"source_command":"loadspritegfx ANIM_TAG_MUSIC_NOTES"},
			{"op":"source_control","condition":"always","target":1910},
			{"op":"source_label","source_pc":1910,"source_line":2547,"source_command":"monbg ANIM_BATTLER_DEF_PARTNER"},
			{"op":"effect","behavior":"source_legacy_impact_command","mode":"monbg","source_args":[3],"ticks":1,"source_line":2547,"source_command":"monbg ANIM_BATTLER_DEF_PARTNER","source_script":"Move_SING"},
			{"op":"source_control","condition":"always","target":1911},
			{"op":"source_label","source_pc":1911,"source_line":2548,"source_command":"createvisualtask sub_80CEA20, 2","source_args":[]},
			{"op":"effect","behavior":"source_note_bank","bank":"musical","palette_tags":[10072,10097,10185,10175],"allocate":true,"ticks":1,"native_substitution":"presentation-owned indexed atlas banks replace OBJ palette allocation; clear/cancel releases owner map","source_task":"sub_80CEA20","source_line":2548},
			{"op":"source_control","condition":"always","target":1912},
			{"op":"source_label","source_pc":1912,"source_line":2549,"source_command":"waitforvisualfinish"},
			{"op":"barrier","source_line":2549},
			{"op":"source_control","condition":"always","target":1913},
			{"op":"source_label","source_pc":1913,"source_line":2550,"source_command":"panse_1B SE_M_SING, SOUND_PAN_ATTACKER, SOUND_PAN_TARGET, 2, 0"},
			{"op":"sound","path":"res://Audio/SE/PRSFX- Sing.wav","source_sound":"SE_M_SING","source_pan":"SOUND_PAN_ATTACKER","pan_motion":[-64,63,2,1],"source_line":2550},
			{"op":"source_control","condition":"always","target":1914},
			{"op":"source_label","source_pc":1914,"source_line":2551,"source_command":"createsprite gBattleAnimSpriteTemplate_83D7114, ANIM_BATTLER_TARGET, 2, 7, 0, 12","source_args":[7,0,12]},
			{"op":"effect","behavior":"source_particle","mode":"musical_note","selector":"target","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":2048,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":4,"ticks":10,"flip_h":false,"flip_v":true},{"op":"end"}],"frame_commands":[{"tile":4,"ticks":10,"flip_h":false,"flip_v":true}],"affine_program":[{"op":"frame","x":12,"y":12,"rotation":0,"ticks":16},{"op":"frame","x":-12,"y":-12,"rotation":0,"ticks":16},{"op":"jump","target":0}],"source_template":"gBattleAnimSpriteTemplate_83D7114","source_callback":"sub_80CEB0C","source_animation_index":7,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_MUSIC_NOTES","source_palette_tag":"ANIM_TAG_MUSIC_NOTES","source_oam":"&gOamData_837DFEC","source_module":"sound_ownership","source_args":[7,0,12],"from_selector":"attacker","to_selector":"target","end_offset":[0,0],"note_palette":0,"palette_interval":12,"palette_bank":"musical","source_private":["sub_80CEBC4","sub_80CEC1C"],"native_substitution":"native visual anchors replace species padding; source8.4 accumulator, sine phase, offscreen lifetime and indexed source palette banks retained","texture":"res://graficos/batalla/animaciones/musical_banks_16x16_4.png","frame_rects":{"4":[0,0,16,16]},"palette_bank_height":16,"palette_banks_rgba":[[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[205,255,213,255],[164,255,172,255],[123,255,131,255],[82,255,98,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[255,255,197,255],[255,255,139,255],[255,255,82,255],[255,255,24,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[213,230,255,255],[172,213,255,255],[131,197,255,255],[98,180,255,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]]],"palette_index_colors":[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],"source_line":2551},
			{"op":"source_control","condition":"always","target":1915},
			{"op":"source_label","source_pc":1915,"source_line":2552,"source_command":"delay 5"},
			{"op":"wait","ticks":5,"source_line":2552},
			{"op":"source_control","condition":"always","target":1916},
			{"op":"source_label","source_pc":1916,"source_line":2553,"source_command":"createsprite gBattleAnimSpriteTemplate_83D7114, ANIM_BATTLER_TARGET, 2, 6, 1, 12","source_args":[6,1,12]},
			{"op":"effect","behavior":"source_particle","mode":"musical_note","selector":"target","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":2048,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":0,"ticks":10,"flip_h":false,"flip_v":true},{"op":"end"}],"frame_commands":[{"tile":0,"ticks":10,"flip_h":false,"flip_v":true}],"affine_program":[{"op":"frame","x":12,"y":12,"rotation":0,"ticks":16},{"op":"frame","x":-12,"y":-12,"rotation":0,"ticks":16},{"op":"jump","target":0}],"source_template":"gBattleAnimSpriteTemplate_83D7114","source_callback":"sub_80CEB0C","source_animation_index":6,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_MUSIC_NOTES","source_palette_tag":"ANIM_TAG_MUSIC_NOTES","source_oam":"&gOamData_837DFEC","source_module":"sound_ownership","source_args":[6,1,12],"from_selector":"attacker","to_selector":"target","end_offset":[0,0],"note_palette":1,"palette_interval":12,"palette_bank":"musical","source_private":["sub_80CEBC4","sub_80CEC1C"],"native_substitution":"native visual anchors replace species padding; source8.4 accumulator, sine phase, offscreen lifetime and indexed source palette banks retained","texture":"res://graficos/batalla/animaciones/musical_banks_16x16_0.png","frame_rects":{"0":[0,0,16,16]},"palette_bank_height":16,"palette_banks_rgba":[[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[205,255,213,255],[164,255,172,255],[123,255,131,255],[82,255,98,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[255,255,197,255],[255,255,139,255],[255,255,82,255],[255,255,24,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[213,230,255,255],[172,213,255,255],[131,197,255,255],[98,180,255,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]]],"palette_index_colors":[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],"source_line":2553},
			{"op":"source_control","condition":"always","target":1917},
			{"op":"source_label","source_pc":1917,"source_line":2554,"source_command":"delay 5"},
			{"op":"wait","ticks":5,"source_line":2554},
			{"op":"source_control","condition":"always","target":1918},
			{"op":"source_label","source_pc":1918,"source_line":2555,"source_command":"createsprite gBattleAnimSpriteTemplate_83D7114, ANIM_BATTLER_TARGET, 2, 1, 2, 12","source_args":[1,2,12]},
			{"op":"effect","behavior":"source_particle","mode":"musical_note","selector":"target","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":2048,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":4,"ticks":10,"flip_h":false,"flip_v":false},{"op":"end"}],"frame_commands":[{"tile":4,"ticks":10,"flip_h":false,"flip_v":false}],"affine_program":[{"op":"frame","x":12,"y":12,"rotation":0,"ticks":16},{"op":"frame","x":-12,"y":-12,"rotation":0,"ticks":16},{"op":"jump","target":0}],"source_template":"gBattleAnimSpriteTemplate_83D7114","source_callback":"sub_80CEB0C","source_animation_index":1,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_MUSIC_NOTES","source_palette_tag":"ANIM_TAG_MUSIC_NOTES","source_oam":"&gOamData_837DFEC","source_module":"sound_ownership","source_args":[1,2,12],"from_selector":"attacker","to_selector":"target","end_offset":[0,0],"note_palette":2,"palette_interval":12,"palette_bank":"musical","source_private":["sub_80CEBC4","sub_80CEC1C"],"native_substitution":"native visual anchors replace species padding; source8.4 accumulator, sine phase, offscreen lifetime and indexed source palette banks retained","texture":"res://graficos/batalla/animaciones/musical_banks_16x16_4.png","frame_rects":{"4":[0,0,16,16]},"palette_bank_height":16,"palette_banks_rgba":[[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[205,255,213,255],[164,255,172,255],[123,255,131,255],[82,255,98,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[255,255,197,255],[255,255,139,255],[255,255,82,255],[255,255,24,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[213,230,255,255],[172,213,255,255],[131,197,255,255],[98,180,255,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]]],"palette_index_colors":[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],"source_line":2555},
			{"op":"source_control","condition":"always","target":1919},
			{"op":"source_label","source_pc":1919,"source_line":2556,"source_command":"delay 5"},
			{"op":"wait","ticks":5,"source_line":2556},
			{"op":"source_control","condition":"always","target":1920},
			{"op":"source_label","source_pc":1920,"source_line":2557,"source_command":"createsprite gBattleAnimSpriteTemplate_83D7114, ANIM_BATTLER_TARGET, 2, 2, 3, 12","source_args":[2,3,12]},
			{"op":"effect","behavior":"source_particle","mode":"musical_note","selector":"target","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":2048,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":8,"ticks":41,"flip_h":false,"flip_v":false},{"op":"end"}],"frame_commands":[{"tile":8,"ticks":41,"flip_h":false,"flip_v":false}],"affine_program":[{"op":"frame","x":12,"y":12,"rotation":0,"ticks":16},{"op":"frame","x":-12,"y":-12,"rotation":0,"ticks":16},{"op":"jump","target":0}],"source_template":"gBattleAnimSpriteTemplate_83D7114","source_callback":"sub_80CEB0C","source_animation_index":2,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_MUSIC_NOTES","source_palette_tag":"ANIM_TAG_MUSIC_NOTES","source_oam":"&gOamData_837DFEC","source_module":"sound_ownership","source_args":[2,3,12],"from_selector":"attacker","to_selector":"target","end_offset":[0,0],"note_palette":3,"palette_interval":12,"palette_bank":"musical","source_private":["sub_80CEBC4","sub_80CEC1C"],"native_substitution":"native visual anchors replace species padding; source8.4 accumulator, sine phase, offscreen lifetime and indexed source palette banks retained","texture":"res://graficos/batalla/animaciones/musical_banks_16x16_8.png","frame_rects":{"8":[0,0,16,16]},"palette_bank_height":16,"palette_banks_rgba":[[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[205,255,213,255],[164,255,172,255],[123,255,131,255],[82,255,98,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[255,255,197,255],[255,255,139,255],[255,255,82,255],[255,255,24,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[213,230,255,255],[172,213,255,255],[131,197,255,255],[98,180,255,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]]],"palette_index_colors":[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],"source_line":2557},
			{"op":"source_control","condition":"always","target":1921},
			{"op":"source_label","source_pc":1921,"source_line":2558,"source_command":"delay 5"},
			{"op":"wait","ticks":5,"source_line":2558},
			{"op":"source_control","condition":"always","target":1922},
			{"op":"source_label","source_pc":1922,"source_line":2559,"source_command":"createsprite gBattleAnimSpriteTemplate_83D7114, ANIM_BATTLER_TARGET, 2, 3, 0, 12","source_args":[3,0,12]},
			{"op":"effect","behavior":"source_particle","mode":"musical_note","selector":"target","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":2048,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":12,"ticks":10,"flip_h":false,"flip_v":false},{"op":"end"}],"frame_commands":[{"tile":12,"ticks":10,"flip_h":false,"flip_v":false}],"affine_program":[{"op":"frame","x":12,"y":12,"rotation":0,"ticks":16},{"op":"frame","x":-12,"y":-12,"rotation":0,"ticks":16},{"op":"jump","target":0}],"source_template":"gBattleAnimSpriteTemplate_83D7114","source_callback":"sub_80CEB0C","source_animation_index":3,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_MUSIC_NOTES","source_palette_tag":"ANIM_TAG_MUSIC_NOTES","source_oam":"&gOamData_837DFEC","source_module":"sound_ownership","source_args":[3,0,12],"from_selector":"attacker","to_selector":"target","end_offset":[0,0],"note_palette":0,"palette_interval":12,"palette_bank":"musical","source_private":["sub_80CEBC4","sub_80CEC1C"],"native_substitution":"native visual anchors replace species padding; source8.4 accumulator, sine phase, offscreen lifetime and indexed source palette banks retained","texture":"res://graficos/batalla/animaciones/musical_banks_16x16_12.png","frame_rects":{"12":[0,0,16,16]},"palette_bank_height":16,"palette_banks_rgba":[[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[205,255,213,255],[164,255,172,255],[123,255,131,255],[82,255,98,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[255,255,197,255],[255,255,139,255],[255,255,82,255],[255,255,24,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[213,230,255,255],[172,213,255,255],[131,197,255,255],[98,180,255,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]]],"palette_index_colors":[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],"source_line":2559},
			{"op":"source_control","condition":"always","target":1923},
			{"op":"source_label","source_pc":1923,"source_line":2560,"source_command":"delay 4"},
			{"op":"wait","ticks":4,"source_line":2560},
			{"op":"source_control","condition":"always","target":1924},
			{"op":"source_label","source_pc":1924,"source_line":2561,"source_command":"createsprite gBattleAnimSpriteTemplate_83D7114, ANIM_BATTLER_TARGET, 2, 2, 1, 12","source_args":[2,1,12]},
			{"op":"effect","behavior":"source_particle","mode":"musical_note","selector":"target","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":2048,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":8,"ticks":41,"flip_h":false,"flip_v":false},{"op":"end"}],"frame_commands":[{"tile":8,"ticks":41,"flip_h":false,"flip_v":false}],"affine_program":[{"op":"frame","x":12,"y":12,"rotation":0,"ticks":16},{"op":"frame","x":-12,"y":-12,"rotation":0,"ticks":16},{"op":"jump","target":0}],"source_template":"gBattleAnimSpriteTemplate_83D7114","source_callback":"sub_80CEB0C","source_animation_index":2,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_MUSIC_NOTES","source_palette_tag":"ANIM_TAG_MUSIC_NOTES","source_oam":"&gOamData_837DFEC","source_module":"sound_ownership","source_args":[2,1,12],"from_selector":"attacker","to_selector":"target","end_offset":[0,0],"note_palette":1,"palette_interval":12,"palette_bank":"musical","source_private":["sub_80CEBC4","sub_80CEC1C"],"native_substitution":"native visual anchors replace species padding; source8.4 accumulator, sine phase, offscreen lifetime and indexed source palette banks retained","texture":"res://graficos/batalla/animaciones/musical_banks_16x16_8.png","frame_rects":{"8":[0,0,16,16]},"palette_bank_height":16,"palette_banks_rgba":[[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[205,255,213,255],[164,255,172,255],[123,255,131,255],[82,255,98,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[255,255,197,255],[255,255,139,255],[255,255,82,255],[255,255,24,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[213,230,255,255],[172,213,255,255],[131,197,255,255],[98,180,255,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]]],"palette_index_colors":[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],"source_line":2561},
			{"op":"source_control","condition":"always","target":1925},
			{"op":"source_label","source_pc":1925,"source_line":2562,"source_command":"delay 4"},
			{"op":"wait","ticks":4,"source_line":2562},
			{"op":"source_control","condition":"always","target":1926},
			{"op":"source_label","source_pc":1926,"source_line":2563,"source_command":"createsprite gBattleAnimSpriteTemplate_83D7114, ANIM_BATTLER_TARGET, 2, 5, 2, 12","source_args":[5,2,12]},
			{"op":"effect","behavior":"source_particle","mode":"musical_note","selector":"target","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":2048,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":20,"ticks":10,"flip_h":false,"flip_v":false},{"op":"end"}],"frame_commands":[{"tile":20,"ticks":10,"flip_h":false,"flip_v":false}],"affine_program":[{"op":"frame","x":12,"y":12,"rotation":0,"ticks":16},{"op":"frame","x":-12,"y":-12,"rotation":0,"ticks":16},{"op":"jump","target":0}],"source_template":"gBattleAnimSpriteTemplate_83D7114","source_callback":"sub_80CEB0C","source_animation_index":5,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_MUSIC_NOTES","source_palette_tag":"ANIM_TAG_MUSIC_NOTES","source_oam":"&gOamData_837DFEC","source_module":"sound_ownership","source_args":[5,2,12],"from_selector":"attacker","to_selector":"target","end_offset":[0,0],"note_palette":2,"palette_interval":12,"palette_bank":"musical","source_private":["sub_80CEBC4","sub_80CEC1C"],"native_substitution":"native visual anchors replace species padding; source8.4 accumulator, sine phase, offscreen lifetime and indexed source palette banks retained","texture":"res://graficos/batalla/animaciones/musical_banks_16x16_20.png","frame_rects":{"20":[0,0,16,16]},"palette_bank_height":16,"palette_banks_rgba":[[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[205,255,213,255],[164,255,172,255],[123,255,131,255],[82,255,98,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[255,255,197,255],[255,255,139,255],[255,255,82,255],[255,255,24,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[213,230,255,255],[172,213,255,255],[131,197,255,255],[98,180,255,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]]],"palette_index_colors":[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],"source_line":2563},
			{"op":"source_control","condition":"always","target":1927},
			{"op":"source_label","source_pc":1927,"source_line":2564,"source_command":"delay 4"},
			{"op":"wait","ticks":4,"source_line":2564},
			{"op":"source_control","condition":"always","target":1928},
			{"op":"source_label","source_pc":1928,"source_line":2565,"source_command":"createsprite gBattleAnimSpriteTemplate_83D7114, ANIM_BATTLER_TARGET, 2, 6, 3, 12","source_args":[6,3,12]},
			{"op":"effect","behavior":"source_particle","mode":"musical_note","selector":"target","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":2048,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":0,"ticks":10,"flip_h":false,"flip_v":true},{"op":"end"}],"frame_commands":[{"tile":0,"ticks":10,"flip_h":false,"flip_v":true}],"affine_program":[{"op":"frame","x":12,"y":12,"rotation":0,"ticks":16},{"op":"frame","x":-12,"y":-12,"rotation":0,"ticks":16},{"op":"jump","target":0}],"source_template":"gBattleAnimSpriteTemplate_83D7114","source_callback":"sub_80CEB0C","source_animation_index":6,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_MUSIC_NOTES","source_palette_tag":"ANIM_TAG_MUSIC_NOTES","source_oam":"&gOamData_837DFEC","source_module":"sound_ownership","source_args":[6,3,12],"from_selector":"attacker","to_selector":"target","end_offset":[0,0],"note_palette":3,"palette_interval":12,"palette_bank":"musical","source_private":["sub_80CEBC4","sub_80CEC1C"],"native_substitution":"native visual anchors replace species padding; source8.4 accumulator, sine phase, offscreen lifetime and indexed source palette banks retained","texture":"res://graficos/batalla/animaciones/musical_banks_16x16_0.png","frame_rects":{"0":[0,0,16,16]},"palette_bank_height":16,"palette_banks_rgba":[[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[205,255,213,255],[164,255,172,255],[123,255,131,255],[82,255,98,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[255,255,197,255],[255,255,139,255],[255,255,82,255],[255,255,24,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[213,230,255,255],[172,213,255,255],[131,197,255,255],[98,180,255,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]]],"palette_index_colors":[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],"source_line":2565},
			{"op":"source_control","condition":"always","target":1929},
			{"op":"source_label","source_pc":1929,"source_line":2566,"source_command":"delay 4"},
			{"op":"wait","ticks":4,"source_line":2566},
			{"op":"source_control","condition":"always","target":1930},
			{"op":"source_label","source_pc":1930,"source_line":2567,"source_command":"createsprite gBattleAnimSpriteTemplate_83D7114, ANIM_BATTLER_TARGET, 2, 2, 0, 12","source_args":[2,0,12]},
			{"op":"effect","behavior":"source_particle","mode":"musical_note","selector":"target","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":2048,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":8,"ticks":41,"flip_h":false,"flip_v":false},{"op":"end"}],"frame_commands":[{"tile":8,"ticks":41,"flip_h":false,"flip_v":false}],"affine_program":[{"op":"frame","x":12,"y":12,"rotation":0,"ticks":16},{"op":"frame","x":-12,"y":-12,"rotation":0,"ticks":16},{"op":"jump","target":0}],"source_template":"gBattleAnimSpriteTemplate_83D7114","source_callback":"sub_80CEB0C","source_animation_index":2,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_MUSIC_NOTES","source_palette_tag":"ANIM_TAG_MUSIC_NOTES","source_oam":"&gOamData_837DFEC","source_module":"sound_ownership","source_args":[2,0,12],"from_selector":"attacker","to_selector":"target","end_offset":[0,0],"note_palette":0,"palette_interval":12,"palette_bank":"musical","source_private":["sub_80CEBC4","sub_80CEC1C"],"native_substitution":"native visual anchors replace species padding; source8.4 accumulator, sine phase, offscreen lifetime and indexed source palette banks retained","texture":"res://graficos/batalla/animaciones/musical_banks_16x16_8.png","frame_rects":{"8":[0,0,16,16]},"palette_bank_height":16,"palette_banks_rgba":[[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[205,255,213,255],[164,255,172,255],[123,255,131,255],[82,255,98,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[255,255,197,255],[255,255,139,255],[255,255,82,255],[255,255,24,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[213,230,255,255],[172,213,255,255],[131,197,255,255],[98,180,255,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]]],"palette_index_colors":[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],"source_line":2567},
			{"op":"source_control","condition":"always","target":1931},
			{"op":"source_label","source_pc":1931,"source_line":2568,"source_command":"delay 4"},
			{"op":"wait","ticks":4,"source_line":2568},
			{"op":"source_control","condition":"always","target":1932},
			{"op":"source_label","source_pc":1932,"source_line":2569,"source_command":"createsprite gBattleAnimSpriteTemplate_83D7114, ANIM_BATTLER_TARGET, 2, 2, 1, 12","source_args":[2,1,12]},
			{"op":"effect","behavior":"source_particle","mode":"musical_note","selector":"target","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":2048,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":8,"ticks":41,"flip_h":false,"flip_v":false},{"op":"end"}],"frame_commands":[{"tile":8,"ticks":41,"flip_h":false,"flip_v":false}],"affine_program":[{"op":"frame","x":12,"y":12,"rotation":0,"ticks":16},{"op":"frame","x":-12,"y":-12,"rotation":0,"ticks":16},{"op":"jump","target":0}],"source_template":"gBattleAnimSpriteTemplate_83D7114","source_callback":"sub_80CEB0C","source_animation_index":2,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_MUSIC_NOTES","source_palette_tag":"ANIM_TAG_MUSIC_NOTES","source_oam":"&gOamData_837DFEC","source_module":"sound_ownership","source_args":[2,1,12],"from_selector":"attacker","to_selector":"target","end_offset":[0,0],"note_palette":1,"palette_interval":12,"palette_bank":"musical","source_private":["sub_80CEBC4","sub_80CEC1C"],"native_substitution":"native visual anchors replace species padding; source8.4 accumulator, sine phase, offscreen lifetime and indexed source palette banks retained","texture":"res://graficos/batalla/animaciones/musical_banks_16x16_8.png","frame_rects":{"8":[0,0,16,16]},"palette_bank_height":16,"palette_banks_rgba":[[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[205,255,213,255],[164,255,172,255],[123,255,131,255],[82,255,98,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[255,255,197,255],[255,255,139,255],[255,255,82,255],[255,255,24,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[213,230,255,255],[172,213,255,255],[131,197,255,255],[98,180,255,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]]],"palette_index_colors":[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],"source_line":2569},
			{"op":"source_control","condition":"always","target":1933},
			{"op":"source_label","source_pc":1933,"source_line":2570,"source_command":"delay 4"},
			{"op":"wait","ticks":4,"source_line":2570},
			{"op":"source_control","condition":"always","target":1934},
			{"op":"source_label","source_pc":1934,"source_line":2571,"source_command":"createsprite gBattleAnimSpriteTemplate_83D7114, ANIM_BATTLER_TARGET, 2, 1, 2, 12","source_args":[1,2,12]},
			{"op":"effect","behavior":"source_particle","mode":"musical_note","selector":"target","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":2048,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":4,"ticks":10,"flip_h":false,"flip_v":false},{"op":"end"}],"frame_commands":[{"tile":4,"ticks":10,"flip_h":false,"flip_v":false}],"affine_program":[{"op":"frame","x":12,"y":12,"rotation":0,"ticks":16},{"op":"frame","x":-12,"y":-12,"rotation":0,"ticks":16},{"op":"jump","target":0}],"source_template":"gBattleAnimSpriteTemplate_83D7114","source_callback":"sub_80CEB0C","source_animation_index":1,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_MUSIC_NOTES","source_palette_tag":"ANIM_TAG_MUSIC_NOTES","source_oam":"&gOamData_837DFEC","source_module":"sound_ownership","source_args":[1,2,12],"from_selector":"attacker","to_selector":"target","end_offset":[0,0],"note_palette":2,"palette_interval":12,"palette_bank":"musical","source_private":["sub_80CEBC4","sub_80CEC1C"],"native_substitution":"native visual anchors replace species padding; source8.4 accumulator, sine phase, offscreen lifetime and indexed source palette banks retained","texture":"res://graficos/batalla/animaciones/musical_banks_16x16_4.png","frame_rects":{"4":[0,0,16,16]},"palette_bank_height":16,"palette_banks_rgba":[[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[205,255,213,255],[164,255,172,255],[123,255,131,255],[82,255,98,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[255,255,197,255],[255,255,139,255],[255,255,82,255],[255,255,24,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[213,230,255,255],[172,213,255,255],[131,197,255,255],[98,180,255,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]]],"palette_index_colors":[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],"source_line":2571},
			{"op":"source_control","condition":"always","target":1935},
			{"op":"source_label","source_pc":1935,"source_line":2572,"source_command":"delay 4"},
			{"op":"wait","ticks":4,"source_line":2572},
			{"op":"source_control","condition":"always","target":1936},
			{"op":"source_label","source_pc":1936,"source_line":2573,"source_command":"createsprite gBattleAnimSpriteTemplate_83D7114, ANIM_BATTLER_TARGET, 2, 5, 3, 12","source_args":[5,3,12]},
			{"op":"effect","behavior":"source_particle","mode":"musical_note","selector":"target","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":2048,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":20,"ticks":10,"flip_h":false,"flip_v":false},{"op":"end"}],"frame_commands":[{"tile":20,"ticks":10,"flip_h":false,"flip_v":false}],"affine_program":[{"op":"frame","x":12,"y":12,"rotation":0,"ticks":16},{"op":"frame","x":-12,"y":-12,"rotation":0,"ticks":16},{"op":"jump","target":0}],"source_template":"gBattleAnimSpriteTemplate_83D7114","source_callback":"sub_80CEB0C","source_animation_index":5,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_MUSIC_NOTES","source_palette_tag":"ANIM_TAG_MUSIC_NOTES","source_oam":"&gOamData_837DFEC","source_module":"sound_ownership","source_args":[5,3,12],"from_selector":"attacker","to_selector":"target","end_offset":[0,0],"note_palette":3,"palette_interval":12,"palette_bank":"musical","source_private":["sub_80CEBC4","sub_80CEC1C"],"native_substitution":"native visual anchors replace species padding; source8.4 accumulator, sine phase, offscreen lifetime and indexed source palette banks retained","texture":"res://graficos/batalla/animaciones/musical_banks_16x16_20.png","frame_rects":{"20":[0,0,16,16]},"palette_bank_height":16,"palette_banks_rgba":[[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[205,255,213,255],[164,255,172,255],[123,255,131,255],[82,255,98,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[255,255,197,255],[255,255,139,255],[255,255,82,255],[255,255,24,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[213,230,255,255],[172,213,255,255],[131,197,255,255],[98,180,255,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]]],"palette_index_colors":[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],"source_line":2573},
			{"op":"source_control","condition":"always","target":1937},
			{"op":"source_label","source_pc":1937,"source_line":2574,"source_command":"delay 4"},
			{"op":"wait","ticks":4,"source_line":2574},
			{"op":"source_control","condition":"always","target":1938},
			{"op":"source_label","source_pc":1938,"source_line":2575,"source_command":"waitforvisualfinish"},
			{"op":"barrier","source_line":2575},
			{"op":"source_control","condition":"always","target":1939},
			{"op":"source_label","source_pc":1939,"source_line":2576,"source_command":"clearmonbg ANIM_BATTLER_DEF_PARTNER"},
			{"op":"effect","behavior":"source_legacy_impact_command","mode":"clearmonbg","source_args":[3],"ticks":1,"source_line":2576,"source_command":"clearmonbg ANIM_BATTLER_DEF_PARTNER","source_script":"Move_SING"},
			{"op":"source_control","condition":"always","target":1940},
			{"op":"source_label","source_pc":1940,"source_line":2577,"source_command":"createvisualtask sub_80CEAD8, 2","source_args":[]},
			{"op":"effect","behavior":"source_note_bank","bank":"musical","palette_tags":[10072,10097,10185,10175],"allocate":false,"ticks":1,"native_substitution":"presentation-owned indexed atlas banks replace OBJ palette allocation; clear/cancel releases owner map","source_task":"sub_80CEAD8","source_line":2577},
			{"op":"source_control","condition":"always","target":1941},
			{"op":"source_label","source_pc":1941,"source_line":2578,"source_command":"waitforvisualfinish"},
			{"op":"barrier","source_line":2578},
			{"op":"source_control","condition":"always","target":1942},
			{"op":"source_label","source_pc":1942,"source_line":2579,"source_command":"end"},
			{"op":"source_control","condition":"end","source_line":2579},
			{"op":"marker","name":"presented"},
			{"op":"barrier"},
			{"op":"end"},
		],
	},
	"ruby:move/320": {
		"key":"ruby:move/320",
		"coverage":"source-derived-unreviewed",
		"source_script":"Move_GRASS_WHISTLE",
		"steps":[
			{"op":"source_control","condition":"always","target":3408},
			{"op":"source_label","source_pc":3408,"source_line":4228,"source_command":"loadspritegfx ANIM_TAG_MUSIC_NOTES"},
			{"op":"source_control","condition":"always","target":3409},
			{"op":"source_label","source_pc":3409,"source_line":4229,"source_command":"createsprite gSimplePaletteBlendSpriteTemplate, ANIM_BATTLER_ATTACKER, 2, 1, 2, 0, 4, rgb(18, 31, 12)","source_args":[1,2,0,4,13298]},
			{"op":"effect","behavior":"source_palette","selector":"background","ticks":15,"blend_start":0,"blend_end":4,"blend_delay":3,"color":"94ff62","source_negative_fade_delay":2,"source_line":4229},
			{"op":"source_control","condition":"always","target":3410},
			{"op":"source_label","source_pc":3410,"source_line":4230,"source_command":"waitforvisualfinish"},
			{"op":"barrier","source_line":4230},
			{"op":"source_control","condition":"always","target":3411},
			{"op":"source_label","source_pc":3411,"source_line":4231,"source_command":"createvisualtask sub_80CEA20, 2","source_args":[]},
			{"op":"effect","behavior":"source_note_bank","bank":"musical","palette_tags":[10072,10097,10185,10175],"allocate":true,"ticks":1,"native_substitution":"presentation-owned indexed atlas banks replace OBJ palette allocation; clear/cancel releases owner map","source_task":"sub_80CEA20","source_line":4231},
			{"op":"source_control","condition":"always","target":3412},
			{"op":"source_label","source_pc":3412,"source_line":4232,"source_command":"waitforvisualfinish"},
			{"op":"barrier","source_line":4232},
			{"op":"source_control","condition":"always","target":3413},
			{"op":"source_label","source_pc":3413,"source_line":4233,"source_command":"panse_1B SE_M_GRASSWHISTLE, SOUND_PAN_ATTACKER, SOUND_PAN_TARGET, 2, 0"},
			{"op":"sound","path":"res://Audio/SE/PRSFX- Grass Whistle.wav","source_sound":"SE_M_GRASSWHISTLE","source_pan":"SOUND_PAN_ATTACKER","pan_motion":[-64,63,2,1],"source_line":4233},
			{"op":"source_control","condition":"always","target":3414},
			{"op":"source_label","source_pc":3414,"source_line":4234,"source_command":"createsprite gBattleAnimSpriteTemplate_83D7114, ANIM_BATTLER_TARGET, 2, 7, 1, 0","source_args":[7,1,0]},
			{"op":"effect","behavior":"source_particle","mode":"musical_note","selector":"target","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":2048,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":4,"ticks":10,"flip_h":false,"flip_v":true},{"op":"end"}],"frame_commands":[{"tile":4,"ticks":10,"flip_h":false,"flip_v":true}],"affine_program":[{"op":"frame","x":12,"y":12,"rotation":0,"ticks":16},{"op":"frame","x":-12,"y":-12,"rotation":0,"ticks":16},{"op":"jump","target":0}],"source_template":"gBattleAnimSpriteTemplate_83D7114","source_callback":"sub_80CEB0C","source_animation_index":7,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_MUSIC_NOTES","source_palette_tag":"ANIM_TAG_MUSIC_NOTES","source_oam":"&gOamData_837DFEC","source_module":"sound_ownership","source_args":[7,1,0],"from_selector":"attacker","to_selector":"target","end_offset":[0,0],"note_palette":1,"palette_interval":0,"palette_bank":"musical","source_private":["sub_80CEBC4","sub_80CEC1C"],"native_substitution":"native visual anchors replace species padding; source8.4 accumulator, sine phase, offscreen lifetime and indexed source palette banks retained","texture":"res://graficos/batalla/animaciones/musical_banks_16x16_4.png","frame_rects":{"4":[0,0,16,16]},"palette_bank_height":16,"palette_banks_rgba":[[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[205,255,213,255],[164,255,172,255],[123,255,131,255],[82,255,98,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[255,255,197,255],[255,255,139,255],[255,255,82,255],[255,255,24,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[213,230,255,255],[172,213,255,255],[131,197,255,255],[98,180,255,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]]],"palette_index_colors":[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],"source_line":4234},
			{"op":"source_control","condition":"always","target":3415},
			{"op":"source_label","source_pc":3415,"source_line":4235,"source_command":"delay 5"},
			{"op":"wait","ticks":5,"source_line":4235},
			{"op":"source_control","condition":"always","target":3416},
			{"op":"source_label","source_pc":3416,"source_line":4236,"source_command":"createsprite gBattleAnimSpriteTemplate_83D7114, ANIM_BATTLER_TARGET, 2, 6, 1, 0","source_args":[6,1,0]},
			{"op":"effect","behavior":"source_particle","mode":"musical_note","selector":"target","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":2048,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":0,"ticks":10,"flip_h":false,"flip_v":true},{"op":"end"}],"frame_commands":[{"tile":0,"ticks":10,"flip_h":false,"flip_v":true}],"affine_program":[{"op":"frame","x":12,"y":12,"rotation":0,"ticks":16},{"op":"frame","x":-12,"y":-12,"rotation":0,"ticks":16},{"op":"jump","target":0}],"source_template":"gBattleAnimSpriteTemplate_83D7114","source_callback":"sub_80CEB0C","source_animation_index":6,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_MUSIC_NOTES","source_palette_tag":"ANIM_TAG_MUSIC_NOTES","source_oam":"&gOamData_837DFEC","source_module":"sound_ownership","source_args":[6,1,0],"from_selector":"attacker","to_selector":"target","end_offset":[0,0],"note_palette":1,"palette_interval":0,"palette_bank":"musical","source_private":["sub_80CEBC4","sub_80CEC1C"],"native_substitution":"native visual anchors replace species padding; source8.4 accumulator, sine phase, offscreen lifetime and indexed source palette banks retained","texture":"res://graficos/batalla/animaciones/musical_banks_16x16_0.png","frame_rects":{"0":[0,0,16,16]},"palette_bank_height":16,"palette_banks_rgba":[[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[205,255,213,255],[164,255,172,255],[123,255,131,255],[82,255,98,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[255,255,197,255],[255,255,139,255],[255,255,82,255],[255,255,24,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[213,230,255,255],[172,213,255,255],[131,197,255,255],[98,180,255,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]]],"palette_index_colors":[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],"source_line":4236},
			{"op":"source_control","condition":"always","target":3417},
			{"op":"source_label","source_pc":3417,"source_line":4237,"source_command":"delay 5"},
			{"op":"wait","ticks":5,"source_line":4237},
			{"op":"source_control","condition":"always","target":3418},
			{"op":"source_label","source_pc":3418,"source_line":4238,"source_command":"createsprite gBattleAnimSpriteTemplate_83D7114, ANIM_BATTLER_TARGET, 2, 1, 1, 0","source_args":[1,1,0]},
			{"op":"effect","behavior":"source_particle","mode":"musical_note","selector":"target","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":2048,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":4,"ticks":10,"flip_h":false,"flip_v":false},{"op":"end"}],"frame_commands":[{"tile":4,"ticks":10,"flip_h":false,"flip_v":false}],"affine_program":[{"op":"frame","x":12,"y":12,"rotation":0,"ticks":16},{"op":"frame","x":-12,"y":-12,"rotation":0,"ticks":16},{"op":"jump","target":0}],"source_template":"gBattleAnimSpriteTemplate_83D7114","source_callback":"sub_80CEB0C","source_animation_index":1,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_MUSIC_NOTES","source_palette_tag":"ANIM_TAG_MUSIC_NOTES","source_oam":"&gOamData_837DFEC","source_module":"sound_ownership","source_args":[1,1,0],"from_selector":"attacker","to_selector":"target","end_offset":[0,0],"note_palette":1,"palette_interval":0,"palette_bank":"musical","source_private":["sub_80CEBC4","sub_80CEC1C"],"native_substitution":"native visual anchors replace species padding; source8.4 accumulator, sine phase, offscreen lifetime and indexed source palette banks retained","texture":"res://graficos/batalla/animaciones/musical_banks_16x16_4.png","frame_rects":{"4":[0,0,16,16]},"palette_bank_height":16,"palette_banks_rgba":[[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[205,255,213,255],[164,255,172,255],[123,255,131,255],[82,255,98,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[255,255,197,255],[255,255,139,255],[255,255,82,255],[255,255,24,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[213,230,255,255],[172,213,255,255],[131,197,255,255],[98,180,255,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]]],"palette_index_colors":[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],"source_line":4238},
			{"op":"source_control","condition":"always","target":3419},
			{"op":"source_label","source_pc":3419,"source_line":4239,"source_command":"delay 5"},
			{"op":"wait","ticks":5,"source_line":4239},
			{"op":"source_control","condition":"always","target":3420},
			{"op":"source_label","source_pc":3420,"source_line":4240,"source_command":"createsprite gBattleAnimSpriteTemplate_83D7114, ANIM_BATTLER_TARGET, 2, 2, 1, 0","source_args":[2,1,0]},
			{"op":"effect","behavior":"source_particle","mode":"musical_note","selector":"target","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":2048,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":8,"ticks":41,"flip_h":false,"flip_v":false},{"op":"end"}],"frame_commands":[{"tile":8,"ticks":41,"flip_h":false,"flip_v":false}],"affine_program":[{"op":"frame","x":12,"y":12,"rotation":0,"ticks":16},{"op":"frame","x":-12,"y":-12,"rotation":0,"ticks":16},{"op":"jump","target":0}],"source_template":"gBattleAnimSpriteTemplate_83D7114","source_callback":"sub_80CEB0C","source_animation_index":2,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_MUSIC_NOTES","source_palette_tag":"ANIM_TAG_MUSIC_NOTES","source_oam":"&gOamData_837DFEC","source_module":"sound_ownership","source_args":[2,1,0],"from_selector":"attacker","to_selector":"target","end_offset":[0,0],"note_palette":1,"palette_interval":0,"palette_bank":"musical","source_private":["sub_80CEBC4","sub_80CEC1C"],"native_substitution":"native visual anchors replace species padding; source8.4 accumulator, sine phase, offscreen lifetime and indexed source palette banks retained","texture":"res://graficos/batalla/animaciones/musical_banks_16x16_8.png","frame_rects":{"8":[0,0,16,16]},"palette_bank_height":16,"palette_banks_rgba":[[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[205,255,213,255],[164,255,172,255],[123,255,131,255],[82,255,98,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[255,255,197,255],[255,255,139,255],[255,255,82,255],[255,255,24,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[213,230,255,255],[172,213,255,255],[131,197,255,255],[98,180,255,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]]],"palette_index_colors":[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],"source_line":4240},
			{"op":"source_control","condition":"always","target":3421},
			{"op":"source_label","source_pc":3421,"source_line":4241,"source_command":"delay 5"},
			{"op":"wait","ticks":5,"source_line":4241},
			{"op":"source_control","condition":"always","target":3422},
			{"op":"source_label","source_pc":3422,"source_line":4242,"source_command":"createsprite gBattleAnimSpriteTemplate_83D7114, ANIM_BATTLER_TARGET, 2, 3, 1, 0","source_args":[3,1,0]},
			{"op":"effect","behavior":"source_particle","mode":"musical_note","selector":"target","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":2048,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":12,"ticks":10,"flip_h":false,"flip_v":false},{"op":"end"}],"frame_commands":[{"tile":12,"ticks":10,"flip_h":false,"flip_v":false}],"affine_program":[{"op":"frame","x":12,"y":12,"rotation":0,"ticks":16},{"op":"frame","x":-12,"y":-12,"rotation":0,"ticks":16},{"op":"jump","target":0}],"source_template":"gBattleAnimSpriteTemplate_83D7114","source_callback":"sub_80CEB0C","source_animation_index":3,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_MUSIC_NOTES","source_palette_tag":"ANIM_TAG_MUSIC_NOTES","source_oam":"&gOamData_837DFEC","source_module":"sound_ownership","source_args":[3,1,0],"from_selector":"attacker","to_selector":"target","end_offset":[0,0],"note_palette":1,"palette_interval":0,"palette_bank":"musical","source_private":["sub_80CEBC4","sub_80CEC1C"],"native_substitution":"native visual anchors replace species padding; source8.4 accumulator, sine phase, offscreen lifetime and indexed source palette banks retained","texture":"res://graficos/batalla/animaciones/musical_banks_16x16_12.png","frame_rects":{"12":[0,0,16,16]},"palette_bank_height":16,"palette_banks_rgba":[[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[205,255,213,255],[164,255,172,255],[123,255,131,255],[82,255,98,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[255,255,197,255],[255,255,139,255],[255,255,82,255],[255,255,24,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[213,230,255,255],[172,213,255,255],[131,197,255,255],[98,180,255,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]]],"palette_index_colors":[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],"source_line":4242},
			{"op":"source_control","condition":"always","target":3423},
			{"op":"source_label","source_pc":3423,"source_line":4243,"source_command":"delay 4"},
			{"op":"wait","ticks":4,"source_line":4243},
			{"op":"source_control","condition":"always","target":3424},
			{"op":"source_label","source_pc":3424,"source_line":4244,"source_command":"createsprite gBattleAnimSpriteTemplate_83D7114, ANIM_BATTLER_TARGET, 2, 2, 1, 0","source_args":[2,1,0]},
			{"op":"effect","behavior":"source_particle","mode":"musical_note","selector":"target","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":2048,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":8,"ticks":41,"flip_h":false,"flip_v":false},{"op":"end"}],"frame_commands":[{"tile":8,"ticks":41,"flip_h":false,"flip_v":false}],"affine_program":[{"op":"frame","x":12,"y":12,"rotation":0,"ticks":16},{"op":"frame","x":-12,"y":-12,"rotation":0,"ticks":16},{"op":"jump","target":0}],"source_template":"gBattleAnimSpriteTemplate_83D7114","source_callback":"sub_80CEB0C","source_animation_index":2,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_MUSIC_NOTES","source_palette_tag":"ANIM_TAG_MUSIC_NOTES","source_oam":"&gOamData_837DFEC","source_module":"sound_ownership","source_args":[2,1,0],"from_selector":"attacker","to_selector":"target","end_offset":[0,0],"note_palette":1,"palette_interval":0,"palette_bank":"musical","source_private":["sub_80CEBC4","sub_80CEC1C"],"native_substitution":"native visual anchors replace species padding; source8.4 accumulator, sine phase, offscreen lifetime and indexed source palette banks retained","texture":"res://graficos/batalla/animaciones/musical_banks_16x16_8.png","frame_rects":{"8":[0,0,16,16]},"palette_bank_height":16,"palette_banks_rgba":[[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[205,255,213,255],[164,255,172,255],[123,255,131,255],[82,255,98,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[255,255,197,255],[255,255,139,255],[255,255,82,255],[255,255,24,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[213,230,255,255],[172,213,255,255],[131,197,255,255],[98,180,255,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]]],"palette_index_colors":[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],"source_line":4244},
			{"op":"source_control","condition":"always","target":3425},
			{"op":"source_label","source_pc":3425,"source_line":4245,"source_command":"delay 4"},
			{"op":"wait","ticks":4,"source_line":4245},
			{"op":"source_control","condition":"always","target":3426},
			{"op":"source_label","source_pc":3426,"source_line":4246,"source_command":"createsprite gBattleAnimSpriteTemplate_83D7114, ANIM_BATTLER_TARGET, 2, 5, 1, 0","source_args":[5,1,0]},
			{"op":"effect","behavior":"source_particle","mode":"musical_note","selector":"target","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":2048,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":20,"ticks":10,"flip_h":false,"flip_v":false},{"op":"end"}],"frame_commands":[{"tile":20,"ticks":10,"flip_h":false,"flip_v":false}],"affine_program":[{"op":"frame","x":12,"y":12,"rotation":0,"ticks":16},{"op":"frame","x":-12,"y":-12,"rotation":0,"ticks":16},{"op":"jump","target":0}],"source_template":"gBattleAnimSpriteTemplate_83D7114","source_callback":"sub_80CEB0C","source_animation_index":5,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_MUSIC_NOTES","source_palette_tag":"ANIM_TAG_MUSIC_NOTES","source_oam":"&gOamData_837DFEC","source_module":"sound_ownership","source_args":[5,1,0],"from_selector":"attacker","to_selector":"target","end_offset":[0,0],"note_palette":1,"palette_interval":0,"palette_bank":"musical","source_private":["sub_80CEBC4","sub_80CEC1C"],"native_substitution":"native visual anchors replace species padding; source8.4 accumulator, sine phase, offscreen lifetime and indexed source palette banks retained","texture":"res://graficos/batalla/animaciones/musical_banks_16x16_20.png","frame_rects":{"20":[0,0,16,16]},"palette_bank_height":16,"palette_banks_rgba":[[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[205,255,213,255],[164,255,172,255],[123,255,131,255],[82,255,98,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[255,255,197,255],[255,255,139,255],[255,255,82,255],[255,255,24,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[213,230,255,255],[172,213,255,255],[131,197,255,255],[98,180,255,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]]],"palette_index_colors":[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],"source_line":4246},
			{"op":"source_control","condition":"always","target":3427},
			{"op":"source_label","source_pc":3427,"source_line":4247,"source_command":"delay 4"},
			{"op":"wait","ticks":4,"source_line":4247},
			{"op":"source_control","condition":"always","target":3428},
			{"op":"source_label","source_pc":3428,"source_line":4248,"source_command":"createsprite gBattleAnimSpriteTemplate_83D7114, ANIM_BATTLER_TARGET, 2, 6, 1, 0","source_args":[6,1,0]},
			{"op":"effect","behavior":"source_particle","mode":"musical_note","selector":"target","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":2048,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":0,"ticks":10,"flip_h":false,"flip_v":true},{"op":"end"}],"frame_commands":[{"tile":0,"ticks":10,"flip_h":false,"flip_v":true}],"affine_program":[{"op":"frame","x":12,"y":12,"rotation":0,"ticks":16},{"op":"frame","x":-12,"y":-12,"rotation":0,"ticks":16},{"op":"jump","target":0}],"source_template":"gBattleAnimSpriteTemplate_83D7114","source_callback":"sub_80CEB0C","source_animation_index":6,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_MUSIC_NOTES","source_palette_tag":"ANIM_TAG_MUSIC_NOTES","source_oam":"&gOamData_837DFEC","source_module":"sound_ownership","source_args":[6,1,0],"from_selector":"attacker","to_selector":"target","end_offset":[0,0],"note_palette":1,"palette_interval":0,"palette_bank":"musical","source_private":["sub_80CEBC4","sub_80CEC1C"],"native_substitution":"native visual anchors replace species padding; source8.4 accumulator, sine phase, offscreen lifetime and indexed source palette banks retained","texture":"res://graficos/batalla/animaciones/musical_banks_16x16_0.png","frame_rects":{"0":[0,0,16,16]},"palette_bank_height":16,"palette_banks_rgba":[[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[205,255,213,255],[164,255,172,255],[123,255,131,255],[82,255,98,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[255,255,197,255],[255,255,139,255],[255,255,82,255],[255,255,24,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[213,230,255,255],[172,213,255,255],[131,197,255,255],[98,180,255,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]]],"palette_index_colors":[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],"source_line":4248},
			{"op":"source_control","condition":"always","target":3429},
			{"op":"source_label","source_pc":3429,"source_line":4249,"source_command":"delay 4"},
			{"op":"wait","ticks":4,"source_line":4249},
			{"op":"source_control","condition":"always","target":3430},
			{"op":"source_label","source_pc":3430,"source_line":4250,"source_command":"createsprite gBattleAnimSpriteTemplate_83D7114, ANIM_BATTLER_TARGET, 2, 2, 1, 0","source_args":[2,1,0]},
			{"op":"effect","behavior":"source_particle","mode":"musical_note","selector":"target","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":2048,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":8,"ticks":41,"flip_h":false,"flip_v":false},{"op":"end"}],"frame_commands":[{"tile":8,"ticks":41,"flip_h":false,"flip_v":false}],"affine_program":[{"op":"frame","x":12,"y":12,"rotation":0,"ticks":16},{"op":"frame","x":-12,"y":-12,"rotation":0,"ticks":16},{"op":"jump","target":0}],"source_template":"gBattleAnimSpriteTemplate_83D7114","source_callback":"sub_80CEB0C","source_animation_index":2,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_MUSIC_NOTES","source_palette_tag":"ANIM_TAG_MUSIC_NOTES","source_oam":"&gOamData_837DFEC","source_module":"sound_ownership","source_args":[2,1,0],"from_selector":"attacker","to_selector":"target","end_offset":[0,0],"note_palette":1,"palette_interval":0,"palette_bank":"musical","source_private":["sub_80CEBC4","sub_80CEC1C"],"native_substitution":"native visual anchors replace species padding; source8.4 accumulator, sine phase, offscreen lifetime and indexed source palette banks retained","texture":"res://graficos/batalla/animaciones/musical_banks_16x16_8.png","frame_rects":{"8":[0,0,16,16]},"palette_bank_height":16,"palette_banks_rgba":[[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[205,255,213,255],[164,255,172,255],[123,255,131,255],[82,255,98,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[255,255,197,255],[255,255,139,255],[255,255,82,255],[255,255,24,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[213,230,255,255],[172,213,255,255],[131,197,255,255],[98,180,255,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]]],"palette_index_colors":[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],"source_line":4250},
			{"op":"source_control","condition":"always","target":3431},
			{"op":"source_label","source_pc":3431,"source_line":4251,"source_command":"delay 4"},
			{"op":"wait","ticks":4,"source_line":4251},
			{"op":"source_control","condition":"always","target":3432},
			{"op":"source_label","source_pc":3432,"source_line":4252,"source_command":"createsprite gBattleAnimSpriteTemplate_83D7114, ANIM_BATTLER_TARGET, 2, 2, 1, 0","source_args":[2,1,0]},
			{"op":"effect","behavior":"source_particle","mode":"musical_note","selector":"target","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":2048,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":8,"ticks":41,"flip_h":false,"flip_v":false},{"op":"end"}],"frame_commands":[{"tile":8,"ticks":41,"flip_h":false,"flip_v":false}],"affine_program":[{"op":"frame","x":12,"y":12,"rotation":0,"ticks":16},{"op":"frame","x":-12,"y":-12,"rotation":0,"ticks":16},{"op":"jump","target":0}],"source_template":"gBattleAnimSpriteTemplate_83D7114","source_callback":"sub_80CEB0C","source_animation_index":2,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_MUSIC_NOTES","source_palette_tag":"ANIM_TAG_MUSIC_NOTES","source_oam":"&gOamData_837DFEC","source_module":"sound_ownership","source_args":[2,1,0],"from_selector":"attacker","to_selector":"target","end_offset":[0,0],"note_palette":1,"palette_interval":0,"palette_bank":"musical","source_private":["sub_80CEBC4","sub_80CEC1C"],"native_substitution":"native visual anchors replace species padding; source8.4 accumulator, sine phase, offscreen lifetime and indexed source palette banks retained","texture":"res://graficos/batalla/animaciones/musical_banks_16x16_8.png","frame_rects":{"8":[0,0,16,16]},"palette_bank_height":16,"palette_banks_rgba":[[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[205,255,213,255],[164,255,172,255],[123,255,131,255],[82,255,98,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[255,255,197,255],[255,255,139,255],[255,255,82,255],[255,255,24,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[213,230,255,255],[172,213,255,255],[131,197,255,255],[98,180,255,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]]],"palette_index_colors":[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],"source_line":4252},
			{"op":"source_control","condition":"always","target":3433},
			{"op":"source_label","source_pc":3433,"source_line":4253,"source_command":"delay 4"},
			{"op":"wait","ticks":4,"source_line":4253},
			{"op":"source_control","condition":"always","target":3434},
			{"op":"source_label","source_pc":3434,"source_line":4254,"source_command":"createsprite gBattleAnimSpriteTemplate_83D7114, ANIM_BATTLER_TARGET, 2, 1, 1, 0","source_args":[1,1,0]},
			{"op":"effect","behavior":"source_particle","mode":"musical_note","selector":"target","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":2048,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":4,"ticks":10,"flip_h":false,"flip_v":false},{"op":"end"}],"frame_commands":[{"tile":4,"ticks":10,"flip_h":false,"flip_v":false}],"affine_program":[{"op":"frame","x":12,"y":12,"rotation":0,"ticks":16},{"op":"frame","x":-12,"y":-12,"rotation":0,"ticks":16},{"op":"jump","target":0}],"source_template":"gBattleAnimSpriteTemplate_83D7114","source_callback":"sub_80CEB0C","source_animation_index":1,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_MUSIC_NOTES","source_palette_tag":"ANIM_TAG_MUSIC_NOTES","source_oam":"&gOamData_837DFEC","source_module":"sound_ownership","source_args":[1,1,0],"from_selector":"attacker","to_selector":"target","end_offset":[0,0],"note_palette":1,"palette_interval":0,"palette_bank":"musical","source_private":["sub_80CEBC4","sub_80CEC1C"],"native_substitution":"native visual anchors replace species padding; source8.4 accumulator, sine phase, offscreen lifetime and indexed source palette banks retained","texture":"res://graficos/batalla/animaciones/musical_banks_16x16_4.png","frame_rects":{"4":[0,0,16,16]},"palette_bank_height":16,"palette_banks_rgba":[[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[205,255,213,255],[164,255,172,255],[123,255,131,255],[82,255,98,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[255,255,197,255],[255,255,139,255],[255,255,82,255],[255,255,24,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[213,230,255,255],[172,213,255,255],[131,197,255,255],[98,180,255,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]]],"palette_index_colors":[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],"source_line":4254},
			{"op":"source_control","condition":"always","target":3435},
			{"op":"source_label","source_pc":3435,"source_line":4255,"source_command":"delay 4"},
			{"op":"wait","ticks":4,"source_line":4255},
			{"op":"source_control","condition":"always","target":3436},
			{"op":"source_label","source_pc":3436,"source_line":4256,"source_command":"createsprite gBattleAnimSpriteTemplate_83D7114, ANIM_BATTLER_TARGET, 2, 5, 1, 0","source_args":[5,1,0]},
			{"op":"effect","behavior":"source_particle","mode":"musical_note","selector":"target","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":2048,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":20,"ticks":10,"flip_h":false,"flip_v":false},{"op":"end"}],"frame_commands":[{"tile":20,"ticks":10,"flip_h":false,"flip_v":false}],"affine_program":[{"op":"frame","x":12,"y":12,"rotation":0,"ticks":16},{"op":"frame","x":-12,"y":-12,"rotation":0,"ticks":16},{"op":"jump","target":0}],"source_template":"gBattleAnimSpriteTemplate_83D7114","source_callback":"sub_80CEB0C","source_animation_index":5,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_MUSIC_NOTES","source_palette_tag":"ANIM_TAG_MUSIC_NOTES","source_oam":"&gOamData_837DFEC","source_module":"sound_ownership","source_args":[5,1,0],"from_selector":"attacker","to_selector":"target","end_offset":[0,0],"note_palette":1,"palette_interval":0,"palette_bank":"musical","source_private":["sub_80CEBC4","sub_80CEC1C"],"native_substitution":"native visual anchors replace species padding; source8.4 accumulator, sine phase, offscreen lifetime and indexed source palette banks retained","texture":"res://graficos/batalla/animaciones/musical_banks_16x16_20.png","frame_rects":{"20":[0,0,16,16]},"palette_bank_height":16,"palette_banks_rgba":[[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[205,255,213,255],[164,255,172,255],[123,255,131,255],[82,255,98,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[255,255,197,255],[255,255,139,255],[255,255,82,255],[255,255,24,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[213,230,255,255],[172,213,255,255],[131,197,255,255],[98,180,255,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]]],"palette_index_colors":[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],"source_line":4256},
			{"op":"source_control","condition":"always","target":3437},
			{"op":"source_label","source_pc":3437,"source_line":4257,"source_command":"delay 4"},
			{"op":"wait","ticks":4,"source_line":4257},
			{"op":"source_control","condition":"always","target":3438},
			{"op":"source_label","source_pc":3438,"source_line":4258,"source_command":"waitforvisualfinish"},
			{"op":"barrier","source_line":4258},
			{"op":"source_control","condition":"always","target":3439},
			{"op":"source_label","source_pc":3439,"source_line":4259,"source_command":"createvisualtask sub_80CEAD8, 2","source_args":[]},
			{"op":"effect","behavior":"source_note_bank","bank":"musical","palette_tags":[10072,10097,10185,10175],"allocate":false,"ticks":1,"native_substitution":"presentation-owned indexed atlas banks replace OBJ palette allocation; clear/cancel releases owner map","source_task":"sub_80CEAD8","source_line":4259},
			{"op":"source_control","condition":"always","target":3440},
			{"op":"source_label","source_pc":3440,"source_line":4260,"source_command":"createsprite gSimplePaletteBlendSpriteTemplate, ANIM_BATTLER_ATTACKER, 2, 1, 4, 4, 0, rgb(18, 31, 12)","source_args":[1,4,4,0,13298]},
			{"op":"effect","behavior":"source_palette","selector":"background","ticks":25,"blend_start":4,"blend_end":0,"blend_delay":5,"color":"94ff62","source_negative_fade_delay":4,"source_line":4260},
			{"op":"source_control","condition":"always","target":3441},
			{"op":"source_label","source_pc":3441,"source_line":4261,"source_command":"waitforvisualfinish"},
			{"op":"barrier","source_line":4261},
			{"op":"source_control","condition":"always","target":3442},
			{"op":"source_label","source_pc":3442,"source_line":4262,"source_command":"end"},
			{"op":"source_control","condition":"end","source_line":4262},
			{"op":"marker","name":"presented"},
			{"op":"barrier"},
			{"op":"end"},
		],
	},
	"ruby:move/187": {
		"key":"ruby:move/187",
		"coverage":"source-derived-unreviewed",
		"source_script":"Move_BELLY_DRUM",
		"steps":[
			{"op":"source_control","condition":"always","target":3721},
			{"op":"source_label","source_pc":3721,"source_line":4577,"source_command":"loadspritegfx ANIM_TAG_MUSIC_NOTES"},
			{"op":"source_control","condition":"always","target":3722},
			{"op":"source_label","source_pc":3722,"source_line":4578,"source_command":"loadspritegfx ANIM_TAG_PURPLE_HAND_OUTLINE"},
			{"op":"source_control","condition":"always","target":3723},
			{"op":"source_label","source_pc":3723,"source_line":4579,"source_command":"createvisualtask sub_80CEA20, 2","source_args":[]},
			{"op":"effect","behavior":"source_note_bank","bank":"musical","palette_tags":[10072,10097,10185,10175],"allocate":true,"ticks":1,"native_substitution":"presentation-owned indexed atlas banks replace OBJ palette allocation; clear/cancel releases owner map","source_task":"sub_80CEA20","source_line":4579},
			{"op":"source_control","condition":"always","target":3724},
			{"op":"source_label","source_pc":3724,"source_line":4580,"source_command":"waitforvisualfinish"},
			{"op":"barrier","source_line":4580},
			{"op":"source_control","condition":"always","target":3725},
			{"op":"source_label","source_pc":3725,"source_line":4581,"source_command":"call _81CD9EB"},
			{"op":"source_control","condition":"call","target":3755,"return_target":3726,"source_line":4581},
			{"op":"source_label","source_pc":3726,"source_line":4582,"source_command":"createsprite gBattleAnimSpriteTemplate_83D71A8, ANIM_BATTLER_ATTACKER, 2, 0, 0, 0, 0","source_args":[0,0,0,0]},
			{"op":"effect","behavior":"source_drum_note","mode":"drum_note","selector":"attacker","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":41,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":0,"ticks":10,"flip_h":false,"flip_v":false},{"op":"end"}],"frame_commands":[{"tile":0,"ticks":10,"flip_h":false,"flip_v":false}],"affine_program":[{"op":"frame","x":160,"y":160,"rotation":0,"ticks":0},{"op":"frame","x":4,"y":4,"rotation":0,"ticks":1},{"op":"jump","target":1}],"source_template":"gBattleAnimSpriteTemplate_83D71A8","source_callback":"sub_80CEE60","source_animation_index":0,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_MUSIC_NOTES","source_palette_tag":"ANIM_TAG_MUSIC_NOTES","source_oam":"&gOamData_837DFEC","source_args":[0,0,0,0],"source_private":["sub_8078650","InitAnimLinearTranslation","TranslateAnimLinear","sub_80CEEE8","Sin","DestroyAnimSprite"],"note_palette":0,"palette_bank":"musical","texture":"res://graficos/batalla/animaciones/drum_note_banks_16x16_0.png","frame_rects":{"0":[0,0,16,16]},"palette_bank_height":16,"palette_banks_rgba":[[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[205,255,213,255],[164,255,172,255],[123,255,131,255],[82,255,98,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[255,255,197,255],[255,255,139,255],[255,255,82,255],[255,255,24,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[213,230,255,255],[172,213,255,255],[131,197,255,255],[98,180,255,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]]],"palette_index_colors":[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],"source_command_priority":{"raw_offset":2,"encoded_byte":2,"basis":"attacker","delta":-2,"raw_role":"ANIM_BATTLER_ATTACKER","template":"gBattleAnimSpriteTemplate_83D71A8"},"source_line":4582},
			{"op":"source_control","condition":"always","target":3727},
			{"op":"source_label","source_pc":3727,"source_line":4583,"source_command":"playsewithpan SE_M_BELLY_DRUM, SOUND_PAN_ATTACKER"},
			{"op":"sound","path":"res://Audio/SE/PRSFX- Belly Drum.wav","source_sound":"SE_M_BELLY_DRUM","source_pan":"SOUND_PAN_ATTACKER","repeat":1,"interval":1,"sound_delay":0,"source_line":4583},
			{"op":"source_control","condition":"always","target":3728},
			{"op":"source_label","source_pc":3728,"source_line":4584,"source_command":"delay 15"},
			{"op":"wait","ticks":15,"source_line":4584},
			{"op":"source_control","condition":"always","target":3729},
			{"op":"source_label","source_pc":3729,"source_line":4585,"source_command":"call _81CD9D0"},
			{"op":"source_control","condition":"call","target":3752,"return_target":3730,"source_line":4585},
			{"op":"source_label","source_pc":3730,"source_line":4586,"source_command":"createsprite gBattleAnimSpriteTemplate_83D71A8, ANIM_BATTLER_ATTACKER, 2, 1, 1, 1, 0","source_args":[1,1,1,0]},
			{"op":"effect","behavior":"source_drum_note","mode":"drum_note","selector":"attacker","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":41,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":4,"ticks":10,"flip_h":false,"flip_v":false},{"op":"end"}],"frame_commands":[{"tile":4,"ticks":10,"flip_h":false,"flip_v":false}],"affine_program":[{"op":"frame","x":160,"y":160,"rotation":0,"ticks":0},{"op":"frame","x":4,"y":4,"rotation":0,"ticks":1},{"op":"jump","target":1}],"source_template":"gBattleAnimSpriteTemplate_83D71A8","source_callback":"sub_80CEE60","source_animation_index":1,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_MUSIC_NOTES","source_palette_tag":"ANIM_TAG_MUSIC_NOTES","source_oam":"&gOamData_837DFEC","source_args":[1,1,1,0],"source_private":["sub_8078650","InitAnimLinearTranslation","TranslateAnimLinear","sub_80CEEE8","Sin","DestroyAnimSprite"],"note_palette":1,"palette_bank":"musical","texture":"res://graficos/batalla/animaciones/drum_note_banks_16x16_4.png","frame_rects":{"4":[0,0,16,16]},"palette_bank_height":16,"palette_banks_rgba":[[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[205,255,213,255],[164,255,172,255],[123,255,131,255],[82,255,98,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[255,255,197,255],[255,255,139,255],[255,255,82,255],[255,255,24,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[213,230,255,255],[172,213,255,255],[131,197,255,255],[98,180,255,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]]],"palette_index_colors":[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],"source_command_priority":{"raw_offset":2,"encoded_byte":2,"basis":"attacker","delta":-2,"raw_role":"ANIM_BATTLER_ATTACKER","template":"gBattleAnimSpriteTemplate_83D71A8"},"source_line":4586},
			{"op":"source_control","condition":"always","target":3731},
			{"op":"source_label","source_pc":3731,"source_line":4587,"source_command":"playsewithpan SE_M_BELLY_DRUM, SOUND_PAN_ATTACKER"},
			{"op":"sound","path":"res://Audio/SE/PRSFX- Belly Drum.wav","source_sound":"SE_M_BELLY_DRUM","source_pan":"SOUND_PAN_ATTACKER","repeat":1,"interval":1,"sound_delay":0,"source_line":4587},
			{"op":"source_control","condition":"always","target":3732},
			{"op":"source_label","source_pc":3732,"source_line":4588,"source_command":"delay 15"},
			{"op":"wait","ticks":15,"source_line":4588},
			{"op":"source_control","condition":"always","target":3733},
			{"op":"source_label","source_pc":3733,"source_line":4589,"source_command":"call _81CD9EB"},
			{"op":"source_control","condition":"call","target":3755,"return_target":3734,"source_line":4589},
			{"op":"source_label","source_pc":3734,"source_line":4590,"source_command":"createsprite gBattleAnimSpriteTemplate_83D71A8, ANIM_BATTLER_ATTACKER, 2, 0, 3, 3, 128","source_args":[0,3,3,128]},
			{"op":"effect","behavior":"source_drum_note","mode":"drum_note","selector":"attacker","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":41,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":12,"ticks":10,"flip_h":false,"flip_v":false},{"op":"end"}],"frame_commands":[{"tile":12,"ticks":10,"flip_h":false,"flip_v":false}],"affine_program":[{"op":"frame","x":160,"y":160,"rotation":0,"ticks":0},{"op":"frame","x":4,"y":4,"rotation":0,"ticks":1},{"op":"jump","target":1}],"source_template":"gBattleAnimSpriteTemplate_83D71A8","source_callback":"sub_80CEE60","source_animation_index":3,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_MUSIC_NOTES","source_palette_tag":"ANIM_TAG_MUSIC_NOTES","source_oam":"&gOamData_837DFEC","source_args":[0,3,3,128],"source_private":["sub_8078650","InitAnimLinearTranslation","TranslateAnimLinear","sub_80CEEE8","Sin","DestroyAnimSprite"],"note_palette":3,"palette_bank":"musical","texture":"res://graficos/batalla/animaciones/drum_note_banks_16x16_12.png","frame_rects":{"12":[0,0,16,16]},"palette_bank_height":16,"palette_banks_rgba":[[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[205,255,213,255],[164,255,172,255],[123,255,131,255],[82,255,98,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[255,255,197,255],[255,255,139,255],[255,255,82,255],[255,255,24,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[213,230,255,255],[172,213,255,255],[131,197,255,255],[98,180,255,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]]],"palette_index_colors":[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],"source_command_priority":{"raw_offset":2,"encoded_byte":2,"basis":"attacker","delta":-2,"raw_role":"ANIM_BATTLER_ATTACKER","template":"gBattleAnimSpriteTemplate_83D71A8"},"source_line":4590},
			{"op":"source_control","condition":"always","target":3735},
			{"op":"source_label","source_pc":3735,"source_line":4591,"source_command":"playsewithpan SE_M_BELLY_DRUM, SOUND_PAN_ATTACKER"},
			{"op":"sound","path":"res://Audio/SE/PRSFX- Belly Drum.wav","source_sound":"SE_M_BELLY_DRUM","source_pan":"SOUND_PAN_ATTACKER","repeat":1,"interval":1,"sound_delay":0,"source_line":4591},
			{"op":"source_control","condition":"always","target":3736},
			{"op":"source_label","source_pc":3736,"source_line":4592,"source_command":"delay 7"},
			{"op":"wait","ticks":7,"source_line":4592},
			{"op":"source_control","condition":"always","target":3737},
			{"op":"source_label","source_pc":3737,"source_line":4593,"source_command":"call _81CD9D0"},
			{"op":"source_control","condition":"call","target":3752,"return_target":3738,"source_line":4593},
			{"op":"source_label","source_pc":3738,"source_line":4594,"source_command":"createsprite gBattleAnimSpriteTemplate_83D71A8, ANIM_BATTLER_ATTACKER, 2, 1, 2, 0, 128","source_args":[1,2,0,128]},
			{"op":"effect","behavior":"source_drum_note","mode":"drum_note","selector":"attacker","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":41,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":8,"ticks":41,"flip_h":false,"flip_v":false},{"op":"end"}],"frame_commands":[{"tile":8,"ticks":41,"flip_h":false,"flip_v":false}],"affine_program":[{"op":"frame","x":160,"y":160,"rotation":0,"ticks":0},{"op":"frame","x":4,"y":4,"rotation":0,"ticks":1},{"op":"jump","target":1}],"source_template":"gBattleAnimSpriteTemplate_83D71A8","source_callback":"sub_80CEE60","source_animation_index":2,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_MUSIC_NOTES","source_palette_tag":"ANIM_TAG_MUSIC_NOTES","source_oam":"&gOamData_837DFEC","source_args":[1,2,0,128],"source_private":["sub_8078650","InitAnimLinearTranslation","TranslateAnimLinear","sub_80CEEE8","Sin","DestroyAnimSprite"],"note_palette":0,"palette_bank":"musical","texture":"res://graficos/batalla/animaciones/drum_note_banks_16x16_8.png","frame_rects":{"8":[0,0,16,16]},"palette_bank_height":16,"palette_banks_rgba":[[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[205,255,213,255],[164,255,172,255],[123,255,131,255],[82,255,98,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[255,255,197,255],[255,255,139,255],[255,255,82,255],[255,255,24,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[213,230,255,255],[172,213,255,255],[131,197,255,255],[98,180,255,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]]],"palette_index_colors":[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],"source_command_priority":{"raw_offset":2,"encoded_byte":2,"basis":"attacker","delta":-2,"raw_role":"ANIM_BATTLER_ATTACKER","template":"gBattleAnimSpriteTemplate_83D71A8"},"source_line":4594},
			{"op":"source_control","condition":"always","target":3739},
			{"op":"source_label","source_pc":3739,"source_line":4595,"source_command":"playsewithpan SE_M_BELLY_DRUM, SOUND_PAN_ATTACKER"},
			{"op":"sound","path":"res://Audio/SE/PRSFX- Belly Drum.wav","source_sound":"SE_M_BELLY_DRUM","source_pan":"SOUND_PAN_ATTACKER","repeat":1,"interval":1,"sound_delay":0,"source_line":4595},
			{"op":"source_control","condition":"always","target":3740},
			{"op":"source_label","source_pc":3740,"source_line":4596,"source_command":"delay 7"},
			{"op":"wait","ticks":7,"source_line":4596},
			{"op":"source_control","condition":"always","target":3741},
			{"op":"source_label","source_pc":3741,"source_line":4597,"source_command":"call _81CD9EB"},
			{"op":"source_control","condition":"call","target":3755,"return_target":3742,"source_line":4597},
			{"op":"source_label","source_pc":3742,"source_line":4598,"source_command":"createsprite gBattleAnimSpriteTemplate_83D71A8, ANIM_BATTLER_ATTACKER, 2, 0, 1, 1, 0","source_args":[0,1,1,0]},
			{"op":"effect","behavior":"source_drum_note","mode":"drum_note","selector":"attacker","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":41,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":4,"ticks":10,"flip_h":false,"flip_v":false},{"op":"end"}],"frame_commands":[{"tile":4,"ticks":10,"flip_h":false,"flip_v":false}],"affine_program":[{"op":"frame","x":160,"y":160,"rotation":0,"ticks":0},{"op":"frame","x":4,"y":4,"rotation":0,"ticks":1},{"op":"jump","target":1}],"source_template":"gBattleAnimSpriteTemplate_83D71A8","source_callback":"sub_80CEE60","source_animation_index":1,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_MUSIC_NOTES","source_palette_tag":"ANIM_TAG_MUSIC_NOTES","source_oam":"&gOamData_837DFEC","source_args":[0,1,1,0],"source_private":["sub_8078650","InitAnimLinearTranslation","TranslateAnimLinear","sub_80CEEE8","Sin","DestroyAnimSprite"],"note_palette":1,"palette_bank":"musical","texture":"res://graficos/batalla/animaciones/drum_note_banks_16x16_4.png","frame_rects":{"4":[0,0,16,16]},"palette_bank_height":16,"palette_banks_rgba":[[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[205,255,213,255],[164,255,172,255],[123,255,131,255],[82,255,98,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[255,255,197,255],[255,255,139,255],[255,255,82,255],[255,255,24,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[213,230,255,255],[172,213,255,255],[131,197,255,255],[98,180,255,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]]],"palette_index_colors":[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],"source_command_priority":{"raw_offset":2,"encoded_byte":2,"basis":"attacker","delta":-2,"raw_role":"ANIM_BATTLER_ATTACKER","template":"gBattleAnimSpriteTemplate_83D71A8"},"source_line":4598},
			{"op":"source_control","condition":"always","target":3743},
			{"op":"source_label","source_pc":3743,"source_line":4599,"source_command":"playsewithpan SE_M_BELLY_DRUM, SOUND_PAN_ATTACKER"},
			{"op":"sound","path":"res://Audio/SE/PRSFX- Belly Drum.wav","source_sound":"SE_M_BELLY_DRUM","source_pan":"SOUND_PAN_ATTACKER","repeat":1,"interval":1,"sound_delay":0,"source_line":4599},
			{"op":"source_control","condition":"always","target":3744},
			{"op":"source_label","source_pc":3744,"source_line":4600,"source_command":"delay 7"},
			{"op":"wait","ticks":7,"source_line":4600},
			{"op":"source_control","condition":"always","target":3745},
			{"op":"source_label","source_pc":3745,"source_line":4601,"source_command":"call _81CD9D0"},
			{"op":"source_control","condition":"call","target":3752,"return_target":3746,"source_line":4601},
			{"op":"source_label","source_pc":3746,"source_line":4602,"source_command":"createsprite gBattleAnimSpriteTemplate_83D71A8, ANIM_BATTLER_ATTACKER, 2, 1, 0, 3, 0","source_args":[1,0,3,0]},
			{"op":"effect","behavior":"source_drum_note","mode":"drum_note","selector":"attacker","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":41,"frame_size":[16,16],"frame_program":[{"op":"frame","tile":0,"ticks":10,"flip_h":false,"flip_v":false},{"op":"end"}],"frame_commands":[{"tile":0,"ticks":10,"flip_h":false,"flip_v":false}],"affine_program":[{"op":"frame","x":160,"y":160,"rotation":0,"ticks":0},{"op":"frame","x":4,"y":4,"rotation":0,"ticks":1},{"op":"jump","target":1}],"source_template":"gBattleAnimSpriteTemplate_83D71A8","source_callback":"sub_80CEE60","source_animation_index":0,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_MUSIC_NOTES","source_palette_tag":"ANIM_TAG_MUSIC_NOTES","source_oam":"&gOamData_837DFEC","source_args":[1,0,3,0],"source_private":["sub_8078650","InitAnimLinearTranslation","TranslateAnimLinear","sub_80CEEE8","Sin","DestroyAnimSprite"],"note_palette":3,"palette_bank":"musical","texture":"res://graficos/batalla/animaciones/drum_note_banks_16x16_0.png","frame_rects":{"0":[0,0,16,16]},"palette_bank_height":16,"palette_banks_rgba":[[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[205,255,213,255],[164,255,172,255],[123,255,131,255],[82,255,98,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[255,255,197,255],[255,255,139,255],[255,255,82,255],[255,255,24,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],[[0,0,0,0],[255,255,255,255],[213,230,255,255],[172,213,255,255],[131,197,255,255],[98,180,255,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]]],"palette_index_colors":[[0,0,0,0],[255,255,255,255],[255,213,230,255],[255,180,213,255],[255,139,197,255],[255,106,180,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255],[0,0,0,255]],"source_command_priority":{"raw_offset":2,"encoded_byte":2,"basis":"attacker","delta":-2,"raw_role":"ANIM_BATTLER_ATTACKER","template":"gBattleAnimSpriteTemplate_83D71A8"},"source_line":4602},
			{"op":"source_control","condition":"always","target":3747},
			{"op":"source_label","source_pc":3747,"source_line":4603,"source_command":"playsewithpan SE_M_BELLY_DRUM, SOUND_PAN_ATTACKER"},
			{"op":"sound","path":"res://Audio/SE/PRSFX- Belly Drum.wav","source_sound":"SE_M_BELLY_DRUM","source_pan":"SOUND_PAN_ATTACKER","repeat":1,"interval":1,"sound_delay":0,"source_line":4603},
			{"op":"source_control","condition":"always","target":3748},
			{"op":"source_label","source_pc":3748,"source_line":4604,"source_command":"waitforvisualfinish"},
			{"op":"barrier","source_line":4604},
			{"op":"source_control","condition":"always","target":3749},
			{"op":"source_label","source_pc":3749,"source_line":4605,"source_command":"createvisualtask sub_80CEAD8, 2","source_args":[]},
			{"op":"effect","behavior":"source_note_bank","bank":"musical","palette_tags":[10072,10097,10185,10175],"allocate":false,"ticks":1,"native_substitution":"presentation-owned indexed atlas banks replace OBJ palette allocation; clear/cancel releases owner map","source_task":"sub_80CEAD8","source_line":4605},
			{"op":"source_control","condition":"always","target":3750},
			{"op":"source_label","source_pc":3750,"source_line":4606,"source_command":"waitforvisualfinish"},
			{"op":"barrier","source_line":4606},
			{"op":"source_control","condition":"always","target":3751},
			{"op":"source_label","source_pc":3751,"source_line":4607,"source_command":"end"},
			{"op":"source_control","condition":"end","source_line":4607},
			{"op":"source_label","source_pc":3752,"source_line":4609,"source_command":"createsprite gBattleAnimSpriteTemplate_83D7174, ANIM_BATTLER_ATTACKER, 3, 0","source_args":[0]},
			{"op":"effect","behavior":"source_drum_hand","mode":"drum_hand","selector":"attacker","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":10,"frame_size":[32,32],"frame_program":[{"op":"frame","tile":0,"ticks":1},{"op":"end"}],"frame_commands":[{"tile":0,"ticks":1}],"affine_program":[],"source_template":"gBattleAnimSpriteTemplate_83D7174","source_callback":"sub_80CEDF0","source_animation_index":0,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_PURPLE_HAND_OUTLINE","source_palette_tag":"ANIM_TAG_PURPLE_HAND_OUTLINE","source_oam":"&gOamData_837DF34","source_args":[0],"source_private":["WaitAnimForDuration","SetCallbackToStoredInData","DestroyAnimSprite"],"texture":"res://graficos/batalla/animaciones/purple_hand_outline_pal_193_32x32_0.png","frame_rects":{"0":[0,0,32,32]},"source_command_priority":{"raw_offset":3,"encoded_byte":3,"basis":"attacker","delta":-3,"raw_role":"ANIM_BATTLER_ATTACKER","template":"gBattleAnimSpriteTemplate_83D7174"},"source_line":4609},
			{"op":"source_control","condition":"always","target":3753},
			{"op":"source_label","source_pc":3753,"source_line":4610,"source_command":"createvisualtask AnimTask_ShakeMon, 2, ANIM_BATTLER_ATTACKER, 0, 8, 2, 1","source_args":[0,0,8,2,1]},
			{"op":"effect","behavior":"source_actor","ticks":3,"selector":"attacker","mode":"zero_offset","count":2,"delay":1,"x":0,"y":8,"source_task":"AnimTask_ShakeMon","source_line":4610},
			{"op":"source_control","condition":"always","target":3754},
			{"op":"source_label","source_pc":3754,"source_line":4611,"source_command":"return"},
			{"op":"source_control","condition":"return","source_line":4611},
			{"op":"source_label","source_pc":3755,"source_line":4613,"source_command":"createsprite gBattleAnimSpriteTemplate_83D7174, ANIM_BATTLER_ATTACKER, 3, 1","source_args":[1]},
			{"op":"effect","behavior":"source_drum_hand","mode":"drum_hand","selector":"attacker","offset":[0,0],"mirror_offset":true,"offset_direction":"toward_target","ticks":10,"frame_size":[32,32],"frame_program":[{"op":"frame","tile":0,"ticks":1},{"op":"end"}],"frame_commands":[{"tile":0,"ticks":1}],"affine_program":[],"source_template":"gBattleAnimSpriteTemplate_83D7174","source_callback":"sub_80CEDF0","source_animation_index":0,"source_affine_variant":0,"source_tile_tag":"ANIM_TAG_PURPLE_HAND_OUTLINE","source_palette_tag":"ANIM_TAG_PURPLE_HAND_OUTLINE","source_oam":"&gOamData_837DF34","source_args":[1],"source_private":["WaitAnimForDuration","SetCallbackToStoredInData","DestroyAnimSprite"],"texture":"res://graficos/batalla/animaciones/purple_hand_outline_pal_193_32x32_0.png","frame_rects":{"0":[0,0,32,32]},"source_command_priority":{"raw_offset":3,"encoded_byte":3,"basis":"attacker","delta":-3,"raw_role":"ANIM_BATTLER_ATTACKER","template":"gBattleAnimSpriteTemplate_83D7174"},"source_line":4613},
			{"op":"source_control","condition":"always","target":3756},
			{"op":"source_label","source_pc":3756,"source_line":4614,"source_command":"createvisualtask AnimTask_ShakeMon, 2, ANIM_BATTLER_ATTACKER, 0, 8, 2, 1","source_args":[0,0,8,2,1]},
			{"op":"effect","behavior":"source_actor","ticks":3,"selector":"attacker","mode":"zero_offset","count":2,"delay":1,"x":0,"y":8,"source_task":"AnimTask_ShakeMon","source_line":4614},
			{"op":"source_control","condition":"always","target":3757},
			{"op":"source_label","source_pc":3757,"source_line":4615,"source_command":"return"},
			{"op":"source_control","condition":"return","source_line":4615},
			{"op":"marker","name":"presented"},
			{"op":"barrier"},
			{"op":"end"},
		],
	},
}

class Invocation extends RefCounted:
	var incoming: Dictionary
	var context: BattleAnimationContext
	var definition: BattleAnimationDefinition
	var pc: int
	var claimed: bool=false

class Session extends RefCounted:
	var context: BattleAnimationContext
	var definition: BattleAnimationDefinition
	var program: Array=[]
	var proof: Fast.Proof
	var originals: Dictionary={}
	var objects: Array[Dictionary]=[]
	var backgrounds: Array[Dictionary]=[]
	var bank: Array=[]
	var allocation: RefCounted
	var allocated: bool=false
	var bank_released: bool=false
	var valid: bool=true

static var _invocations: Dictionary={}

static func _integral(v: Variant) -> bool:
	return typeof(v) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(v)) and float(v)==floorf(float(v))

static func matches(owner: Node2D) -> bool:
	return not _canonical_key(owner).is_empty()

static func _canonical_key(owner: Node2D) -> String:
	if not owner is BattleAnimationSequenceRunner or owner.definition==null:return ""
	for key: String in PROGRAMS:
		if is_same(owner.definition,BattleAnimationSequenceRegistry._builtin_source_definitions.get(key)):return key
	return ""

static func _texture(v: Variant) -> Texture2D:
	return Fast.texture(v)

static func _art(s: Dictionary) -> Dictionary:
	var a: Dictionary={}
	for key: Variant in s:
		if str(key) in ART:a[str(key)]=s[key]
	var texture: Texture2D=_texture(a.get("texture"));var stride: Variant=a.get("palette_bank_height")
	if texture==null or not _integral(stride) or float(stride)<=0 or texture.get_height()<4*float(stride):return {}
	var factor: Variant=a.get("scale_factor",1)
	if typeof(factor) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(factor)) or float(factor)<=0:return {}
	for flag: String in ["recolor","flip_h","flip_v"]:
		if a.has(flag) and typeof(a[flag])!=TYPE_BOOL:return {}
	if a.has("color") and (typeof(a.color)!=TYPE_STRING or not Color.html_is_valid(a.color)):return {}
	var rects: Variant=a.get("frame_rects")
	if not rects is Dictionary or rects.is_empty():return {}
	for key: Variant in rects:
		if typeof(key)!=TYPE_STRING:return {}
		var rect: Variant=rects[key]
		if not rect is Array or rect.size()!=4:return {}
		for v: Variant in rect:
			if not _integral(v):return {}
		if float(rect[0])<0 or float(rect[1])<0 or float(rect[2])<=0 or float(rect[3])<=0 or float(rect[0])+float(rect[2])>texture.get_width() or float(rect[1])+float(rect[3])>float(stride):return {}
		for bank: int in 4:
			if float(rect[1])+float(rect[3])+bank*float(stride)>texture.get_height():return {}
	for frame: Dictionary in s.frame_commands:
		if not rects.has(str(int(frame.tile))):return {}
	return a

static func _shape(actual: Variant,expected: Dictionary) -> bool:
	if not actual is Dictionary:return false
	var art: bool=expected.get("source_callback")=="sub_80CEB0C"
	for key: String in expected:
		if art and key in ART:continue
		if not actual.has(key) or not Same._same(actual[key],expected[key]):return false
	for key: Variant in actual:
		var name: String
		if typeof(key)==TYPE_STRING:name=key
		elif typeof(key)==TYPE_STRING_NAME and art and str(key) in ART:name=str(key)
		else:return false
		if not expected.has(name) and (not art or name not in ART):return false
	return not art or not _art(actual).is_empty()

static func _whole(owner: Node2D) -> bool:
	if not matches(owner):return false
	var key: String=_canonical_key(owner)
	if owner.definition.key!=key:return false
	var expected: Dictionary=PROGRAMS[key]
	if owner.definition.coverage!=expected.coverage or owner.definition.source_script!=expected.source_script or not Same._same(owner._steps,owner.definition.steps) or owner._steps.size()!=expected.steps.size():return false
	for pc: int in expected.steps.size():
		if not _shape(owner._steps[pc],expected.steps[pc]):return false
	return true

## Cheap proof that the live program still equals the one this session admitted.
static func _fast(owner: Node2D,g: Session) -> bool:
	if g==null or g.proof==null or not matches(owner):return false
	var key: String=_canonical_key(owner)
	if owner.definition.key!=key:return false
	var expected: Dictionary=PROGRAMS[key]
	if owner.definition.coverage!=expected.coverage or owner.definition.source_script!=expected.source_script or owner._steps.size()!=expected.steps.size():return false
	return Fast.holds(owner._steps,owner.definition.steps,g.program,g.proof,func(pc: int,step: Variant) -> bool:return _shape(step,expected.steps[pc]))

static func open_dispatch(owner: Node2D,step: Dictionary) -> Invocation:
	if not matches(owner) or _invocations.has(owner.get_instance_id()):return null
	var scope:=Invocation.new();scope.incoming=step;scope.context=owner.context;scope.definition=owner.definition;scope.pc=owner._pc
	_invocations[owner.get_instance_id()]=scope;return scope

static func close_dispatch(owner: Node2D,scope: Invocation) -> void:
	if scope!=null and is_same(_invocations.get(owner.get_instance_id()),scope):_invocations.erase(owner.get_instance_id())

static func _group(owner: Node2D) -> Session:
	return owner.get_meta(STATE) as Session if owner.has_meta(STATE) else null

static func _priority_exact(actual: Variant,expected: Dictionary) -> bool:
	# Exact finite metadata schema; numeric equality does not admit bool/fraction/NaN.
	if not actual is Dictionary or actual.size()!=expected.size():return false
	for key: Variant in actual:
		if typeof(key)!=TYPE_STRING or not expected.has(key):return false
	for key: String in expected:
		if not actual.has(key):return false
		if key in ["raw_offset","encoded_byte","delta","source_pc","source_line"]:
			if not _integral(actual[key]) or not _integral(expected[key]) or float(actual[key])!=float(expected[key]):return false
		elif key in ["template","basis","raw_role","source_command"]:
			if typeof(actual[key])!=TYPE_STRING or typeof(expected[key])!=TYPE_STRING or actual[key]!=expected[key]:return false
		else:return false
	return true

static func _admit(s: Dictionary,c: BattleAnimationContext,owner: Node2D,behavior: String) -> bool:
	var scope: Invocation=_invocations.get(owner.get_instance_id()) as Invocation;var group: Session=_group(owner)
	if scope==null or scope.claimed or not is_same(scope.incoming,s) or not is_same(scope.context,c) or not is_same(owner.context,c) or not is_same(scope.definition,owner.definition) or scope.pc!=owner._pc or (group!=null and not group.valid) or not (_fast(owner,group) or _whole(owner)):return false
	if scope.pc<0 or scope.pc>=PROGRAMS[owner.definition.key].steps.size():return false
	var expected: Dictionary=PROGRAMS[owner.definition.key].steps[scope.pc]
	if expected.get("behavior")!=behavior:return false
	var plain: Dictionary=s.duplicate(true)
	var priority: Dictionary=BattleSourcePriority.command_metadata(PROGRAMS[owner.definition.key].steps[scope.pc-1]) if scope.pc>0 else {}
	if expected.has("source_command_priority"):
		# Canonical Belly effects already author six fields. The runner retains
		# them verbatim; provenance-only label fields are NOT injected here.
		var authored: Dictionary=expected.source_command_priority
		if authored.size()!=6 or priority.size()!=9:return false
		var projected: Dictionary={}
		for key: String in ["template","raw_offset","encoded_byte","basis","raw_role","delta"]:
			if not authored.has(key) or not priority.has(key):return false
			projected[key]=priority[key]
		if not _priority_exact(authored,projected) or not _priority_exact(plain.get("source_command_priority"),authored):return false
		# Retain the authored field for the exact whole-effect comparison below.
	elif not priority.is_empty():
		# Only formerly absent metadata is the full nine-field runner decoration.
		if priority.size()!=9 or not _priority_exact(plain.get("source_command_priority"),priority):return false
		plain.erase("source_command_priority")
	elif plain.has("source_command_priority"):return false
	if not _shape(plain,expected) or not Same._same(plain,owner._steps[scope.pc]):return false
	if not owner.claim_effect_dispatch(s):return false
	scope.claimed=true;return true

static func _binding(a: BattleAnimationActor,c: BattleAnimationContext,owner: Node2D) -> Dictionary:
	return {"actor":a,"sprite":a.sprite,"sprite_parent":a.sprite.get_parent(),"texture":a.sprite.texture,"generation":a._generation,"slot":a.slot,"position":c.source_position(a.id),"parent":owner,"context":c,"definition":owner.definition,"attacker":c.attacker_id,"contest":c.contest}

static func _bound(b: Dictionary,c: BattleAnimationContext) -> bool:
	return is_instance_valid(b.parent) and is_same(b.parent.context,c) and is_same(b.parent.definition,b.definition) and c.attacker_id==b.attacker and c.contest==b.contest and c.actors.get(b.actor.id)==b.actor and b.actor.sprite==b.sprite and b.actor.is_present() and c.source_position(b.actor.id)==b.position and Pair._visual(b)

static func _session(owner: Node2D,c: BattleAnimationContext) -> Session:
	var g: Session=_group(owner)
	if g==null:
		g=Session.new();g.context=c;g.definition=owner.definition;g.program=owner._steps.duplicate(true);g.proof=Fast.capture(g.program)
		for a: BattleAnimationActor in c.actors.values():
			if a.is_present():g.originals[a.id]=_binding(a,c,owner)
		owner.set_meta(STATE,g)
	return g

static func _source_center(a: BattleAnimationActor,c: BattleAnimationContext) -> Vector2:
	var n: Sprite2D=a.sprite;var parent: Node2D=n.get_parent() as Node2D
	var raw: Vector2=c.field.to_local(parent.to_global(n.transform*n.get_rect().get_center()-a._offset))
	return Vector2(int(raw.x),int(raw.y))

static func _s16(v: int) -> int:return ((v+32768)&65535)-32768

static func _velocity(origin: Vector2,destination: Vector2) -> Vector2i:
	var dx: int=_s16(int(destination.x)-int(origin.x));var dy: int=_s16(int(destination.y)-int(origin.y))
	var q: int=int(float(dx*256)/(-40.0 if dx<0 else 40.0))
	if q==0:q=1
	return Vector2i(_s16(int(float(dx*256)/q)),_s16(int(float(dy*256)/q)))

static func _base(origin: Vector2,v: Vector2i,age: int) -> Vector2i:
	if age==0:return Vector2i(_s16(int(origin.x)),_s16(int(origin.y)))
	return Vector2i(_s16(int(origin.x)*16+age*v.x)>>4,_s16(int(origin.y)*16+age*v.y)>>4)

static func _available(g: Session,index: int,owner: Node2D) -> bool:
	if index==0:return true
	var tags: Variant=owner._source_palette_banks.get("musical",[])
	if not tags is Array:return false
	for v: Variant in tags:
		if _integral(v) and float(v)==float(TAGS[index]):return true
	return false

# A direct finite constructor avoids generic anchor preconditions and preserves
# the original invocation/recipe BEFORE mandatory normalized decorations.
static func particle(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Variant:
	if not matches(owner) or _canonical_key(owner)=="ruby:move/187":return null
	if not _admit(s,c,owner,"source_particle"):return []
	var g: Session=_session(owner,c);var source: Dictionary=g.originals.get(c.attacker_id,{})
	if source.is_empty() or not _bound(source,c):return []
	var target_id: int=c.target_ids[0] if not c.target_ids.is_empty() else -1
	var destination:=Vector2(48,40)
	if not c.contest:
		var target: Dictionary=g.originals.get(target_id,{})
		if target.is_empty() or not _bound(target,c):return []
		destination=_source_center(target.actor,c)
	destination=Vector2(int(destination.x)&255,int(destination.y)&255)
	var original: Dictionary=s.duplicate(true);var settings: Dictionary=s.duplicate(true);var art: Dictionary=_art(s)
	for key: String in ART:
		if settings.has(StringName(key)):settings.erase(StringName(key))
		if art.has(key):settings[key]=art[key]
	settings.source_contest=c.contest
	var origin: Vector2=_source_center(source.actor,c);var velocity: Vector2i=_velocity(origin,destination)
	settings.note_bank_active=owner._source_palette_banks.has(str(s.palette_bank))
	settings.note_velocity=[velocity.x,velocity.y]
	var n:=Sprite2D.new();n.texture=_texture(settings.texture);n.region_enabled=true;n.modulate=Color(str(settings.get("color","ffffff")));owner.add_child(n)
	if settings.get("recolor",false):
		var material:=ShaderMaterial.new();material.shader=RECOLOR;material.set_shader_parameter("tint",n.modulate);n.material=material
	var requested: int=int(settings.note_palette);var selected: int=requested if _available(g,requested,owner) else 0
	var birth_frame: Dictionary=settings.frame_commands[0];var birth_rect: Array=settings.frame_rects[str(int(birth_frame.tile))]
	n.region_rect=Rect2(birth_rect[0],float(birth_rect[1])+selected*float(settings.palette_bank_height),birth_rect[2],birth_rect[3])
	# A later genuine birth can read the currently installed tag table without
	# acquiring its bank-task ownership. Existing sprite leases never re-acquire.
	var receipt: Variant=owner._source_palette_banks.get("musical")
	var target_position: int=int(c.source_positions.get(target_id,BattleAnimationContext.source_position_for_slot(target_id)))
	var raw: int=(30 if target_id==2 else 40) if c.contest else 30 if target_position==0 else 20 if target_position==2 else 40 if target_position==1 else 50
	var t: Dictionary={"kind":"source_particle","age":0,"ticks":1,"node":n,"settings":settings,"origin":origin,"destination":destination,"owner":owner,"source_oam_priority":2,"source_oam_subpriority":maxi(3,raw-2),"source_priority_actor_id":target_id,"update":_advance}
	var item: Dictionary={"node":n,"parent":owner,"binding":source,"group":g,"receipt":receipt,"allocation":g.allocation if is_same(receipt,g.bank) else null,"track":t,"original_recipe":original,"normalized_recipe":settings.duplicate(true),"velocity":velocity,"requested":requested,"selected":selected,"counter":0,"palette_age":0,"palette_lost":false,"writes":{},"lost":{},"material":n.material,"shader":n.material.shader if n.material is ShaderMaterial else null,"uniforms":{"tint":n.modulate} if n.material is ShaderMaterial else {},"revoked":{},"lost_material":false,"texture":n.texture,"retired":false}
	t.i158_item=item;t.cleanup=_cleanup.bind(item);g.objects.append(item);_advance(t,c)
	var result: Array[Dictionary]=[t];return result

static func _observe(item: Dictionary) -> void:
	if not is_instance_valid(item.node):return
	for key: String in item.writes:
		if item.node.get(key)!=item.writes[key]:item.lost[key]=true
	if item.node.texture!=item.texture:item.palette_lost=true
	if item.material==null:
		if item.node.material!=null:item.palette_lost=true
	elif not Owned.observe_material(item) or not item.revoked.is_empty():item.palette_lost=true
	var g: Session=item.group
	if item.allocation!=null and not is_same(item.allocation,g.allocation):item.palette_lost=true
	if not (g.bank_released and is_same(item.receipt,g.bank)) and not is_same(item.parent._source_palette_banks.get("musical"),item.receipt):item.palette_lost=true

static func _advance(t: Dictionary,c: BattleAnimationContext) -> void:
	var item: Dictionary=t.i158_item;var g: Session=item.group
	_observe(item)
	if item.retired or not g.valid or not _bound(item.binding,c) or not Owned.node(item) or not Same._same(t.settings,item.normalized_recipe):_retire(item);return
	var age: int=maxi(0,int(t.age));var base: Vector2i=_base(t.origin,item.velocity,age)
	# No artificial source timeout, including genuinely stationary notes.
	t.ticks=age+1
	var point: Vector2=Vector2(base)+Vector2(0,BattleSourceTrig.sine((age*5)&255,15))
	var phase: int=age%32;var matrix: int=256+12*mini(phase,16)-12*maxi(0,phase-16)
	var source_pose:=Transform2D(0,Vector2.ONE*(256.0/matrix)*float(t.settings.get("scale_factor",1.0)),0,point)
	Owned.write(item,"transform",item.parent.global_transform.affine_inverse()*c.field.global_transform*source_pose)
	# Bounds are on the base BEFORE palette callbacks, not sine/extent/viewport.
	if age>0 and (base.x< -16 or base.x>256 or base.y< -16 or base.y>128):t.ticks=age;return
	if not item.palette_lost:
		for sample: int in range(int(item.palette_age)+1,age+1):
			if int(t.settings.palette_interval)>0:
				item.counter+=1
				if int(item.counter)>int(t.settings.palette_interval):
					item.counter=0;item.requested=(int(item.requested)+1)%4
					if _available(g,int(item.requested),item.parent):item.selected=item.requested
		item.palette_age=age
		var palette_frame: Dictionary=t.settings.frame_commands[0];var rect: Array=t.settings.frame_rects[str(int(palette_frame.tile))]
		Owned.write(item,"region_rect",Rect2(rect[0],float(rect[1])+int(item.selected)*float(t.settings.palette_bank_height),rect[2],rect[3]))
	var frame: Dictionary=t.settings.frame_commands[0]
	Owned.write(item,"flip_h",bool(t.settings.get("flip_h",false))!=bool(frame.get("flip_h",false)))
	Owned.write(item,"flip_v",bool(t.settings.get("flip_v",false))!=bool(frame.get("flip_v",false)))
	Owned.write(item,"z_index",_band(item.parent,c)+62-int(t.source_oam_subpriority))

static func _retire(item: Dictionary) -> void:
	if item.retired:return
	item.retired=true;item.palette_lost=true
	if item.has("track"):
		item.track.ticks=int(item.track.age)
		for i: int in range(item.parent._tracks.size()-1,-1,-1):
			if is_same(item.parent._tracks[i],item.track):item.parent._tracks.remove_at(i)
	if Owned.node(item):item.node.queue_free()

static func _cleanup(item: Dictionary) -> void:
	# Never repair/reattach materials after shader/uniform/receipt loss.
	item.retired=true
	if item.has("track"):
		item.track.erase("cleanup");item.track.erase("update");item.track.erase("i158_item");item.erase("track")

static func bank(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Variant:
	if not matches(owner):return null
	if not _admit(s,c,owner,"source_note_bank"):return []
	var g: Session=_session(owner,c)
	if bool(s.allocate):
		g.bank=s.palette_tags.duplicate();g.allocation=RefCounted.new();g.allocated=true;g.bank_released=false;owner._source_palette_banks["musical"]=g.bank
	else:
		if g.allocated and is_same(owner._source_palette_banks.get("musical"),g.bank):owner._source_palette_banks.erase("musical")
		else:
			for item: Dictionary in g.objects:
				if is_same(item.receipt,g.bank):item.palette_lost=true
		g.bank_released=true
	owner.source_bank_events.append({"tick":owner.elapsed_ticks,"bank":s.bank,"allocate":s.allocate})
	return []

static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if not _admit(s,c,owner,"source_legacy_impact_command"):return []
	var g: Session=_session(owner,c)
	var trace: Array=owner.get_meta("source_legacy_impact_commands",[]);trace.append(int(s.source_line));owner.set_meta("source_legacy_impact_commands",trace)
	if s.mode=="clearmonbg":
		for t: Dictionary in g.backgrounds:Pair._clear_pair(t)
		return []
	var tracks: Array[Dictionary]=Pair._create_pair_bg(c,owner,3,"source_legacy_impact_bg","source_legacy_impact_backgrounds")
	for t: Dictionary in tracks:t.update=_background;t.ticks=1;g.backgrounds.append(t)
	_order_bg(owner,c);return tracks

static func _background(t: Dictionary,c: BattleAnimationContext) -> void:
	var g: Session=_group(t.owner)
	if g==null or not g.valid:Pair._cleanup_pair(t);t.ticks=int(t.age);return
	if not t.cleared:t.ticks=int(t.age)+1
	Pair._advance_pair(t,c)

# Belly's private Q8/41-tick worker is retained verbatim. Only this admitted
# child receives a musical receipt binding; hands and unrelated families do not.
static func drum_admit(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Dictionary:
	if not matches(owner) or _canonical_key(owner)!="ruby:move/187" or s.get("behavior")!="source_drum_note":return {"handled":false}
	if not _admit(s,c,owner,"source_drum_note"):return {"handled":true,"admitted":false}
	var g: Session=_session(owner,c);var original: Dictionary=g.originals.get(c.attacker_id,{})
	return {"handled":true,"admitted":not original.is_empty() and _bound(original,c)}

static func bind_drum(t: Dictionary,c: BattleAnimationContext,owner: Node2D) -> void:
	var g: Session=_session(owner,c);var b: Dictionary=g.originals.get(c.attacker_id,{})
	if b.is_empty():return
	var selected: int=int(t.settings.note_palette) if _available(g,int(t.settings.note_palette),owner) else 0
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.frame_program,0).frame;var rect: Array=t.settings.frame_rects[str(int(frame.tile))]
	t.node.region_rect=Rect2(rect[0],float(rect[1])+selected*float(t.settings.palette_bank_height),rect[2],rect[3])
	var receipt: Variant=owner._source_palette_banks.get("musical")
	var item: Dictionary={"node":t.node,"parent":owner,"binding":b,"group":g,"receipt":receipt,"allocation":g.allocation if is_same(receipt,g.bank) else null,"track":t,"palette_lost":false,"selected":selected,"writes":{"region_rect":t.node.region_rect,"transform":t.node.transform},"lost":{},"material":t.node.material,"shader":null,"uniforms":{},"revoked":{},"lost_material":false,"texture":t.node.texture,"retired":false,"saved_update":t.update}
	t.i158_item=item;t.update=_drum_update;t.cleanup=_cleanup.bind(item);g.objects.append(item)

static func _drum_update(t: Dictionary,c: BattleAnimationContext) -> void:
	var item: Dictionary=t.i158_item;var g: Session=item.group;_observe(item)
	if not g.valid or not _bound(item.binding,c) or not Owned.node(item):_retire(item);return
	var region: Rect2=t.node.region_rect
	var pose: Transform2D=t.node.transform
	item.saved_update.call(t,c)
	if item.lost.has("transform"):t.node.transform=pose
	else:item.writes.transform=t.node.transform
	if item.palette_lost or item.lost.has("region_rect"):t.node.region_rect=region
	else:
		var frame: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.frame_program,int(t.age)).frame;var rect: Array=t.settings.frame_rects[str(int(frame.tile))]
		t.node.region_rect=Rect2(rect[0],float(rect[1])+int(item.selected)*float(t.settings.palette_bank_height),rect[2],rect[3]);item.writes.region_rect=t.node.region_rect

static func _band(owner: Node2D,c: BattleAnimationContext) -> int:
	var band: int=BattleSourcePriority.effective_layer(c.field)-BattleSourcePriority.effective_layer(owner)+1
	for a: BattleAnimationActor in c.actors.values():
		if a.is_present():band=maxi(band,BattleSourcePriority.actor_layer(a,owner))
	return band

static func _order_bg(owner: Node2D,c: BattleAnimationContext) -> void:
	var g: Session=_group(owner)
	if g==null:return
	for t: Dictionary in g.backgrounds:
		for item: Dictionary in t.clones:
			if not item.retired and Owned.node(item):Owned.write(item,"z_index",_band(owner,c)+(1 if int(item.bg_plane)==1 else 0))

static func begin_tick(owner: Node2D,c: BattleAnimationContext) -> void:
	var g: Session=_group(owner)
	if g==null:return
	if not is_same(g.context,c) or not is_same(g.definition,owner.definition) or not (_fast(owner,g) or (_whole(owner) and Same._same(owner._steps,g.program))):g.valid=false
	for t: Dictionary in g.backgrounds:
		for item: Dictionary in t.clones:
			for key: String in item.writes:
				if is_instance_valid(item.node) and item.node.get(key)!=item.writes[key]:item.lost[key]=true
	for item: Dictionary in g.objects:
		_observe(item)
		if not g.valid or not _bound(item.binding,c) or not Owned.node(item):_retire(item)

static func after_pose(owner: Node2D,c: BattleAnimationContext) -> void:
	var g: Session=_group(owner)
	if g==null or not g.valid:return
	for t: Dictionary in g.backgrounds:Pair._after_pair_pose(t)
	for item: Dictionary in g.objects:
		if not item.retired and item.has("track") and item.track.kind=="source_particle":_advance(item.track,c)
	_order_bg(owner,c)

static func foreign_terminal_banks(owner: Node2D) -> Dictionary:
	var g: Session=_group(owner)
	if g!=null and g.allocated and owner._source_palette_banks.has("musical") and not is_same(owner._source_palette_banks["musical"],g.bank):return {"musical":owner._source_palette_banks["musical"]}
	return {}

static func release(owner: Node2D) -> void:
	var g: Session=_group(owner)
	if g!=null:
		for item: Dictionary in g.objects:_cleanup(item)
		g.objects.clear();g.backgrounds.clear();g.originals.clear();owner.remove_meta(STATE)
	_invocations.erase(owner.get_instance_id())

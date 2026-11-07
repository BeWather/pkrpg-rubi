extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Two canonical legacy sheets; source motion does not own art or composition.
const SITES := {"ruby:move/15":["Move_CUT",1207],"ruby:move/332":["Move_AERIAL_ACE",4347]}
const TEMPLATE := "gCuttingSliceSpriteTemplate"
const CALLBACK := "AnimCuttingSlice"
const FRAMES := [{"tile":0,"ticks":5,"flip_h":false,"flip_v":false},{"tile":16,"ticks":5,"flip_h":false,"flip_v":false},{"tile":32,"ticks":5,"flip_h":false,"flip_v":false},{"tile":48,"ticks":5,"flip_h":false,"flip_v":false}]
const CUT := {"script":"Move_CUT","source_line":1207,"template":TEMPLATE,"callback":CALLBACK,"oam":"gOamData_837E054","obj_mode":1,"priority":2,"basis":"attacker","raw_role":"ANIM_BATTLER_ATTACKER","raw_offset":2,"source_args":[40,-32,0],"source_command":"createsprite gCuttingSliceSpriteTemplate, ANIM_BATTLER_ATTACKER, 2, 40, -32, 0","source_occurrence":1,"source_multiplicity":1}
const AERIAL := {"script":"Move_AERIAL_ACE","source_line":4347,"template":TEMPLATE,"callback":CALLBACK,"oam":"gOamData_837E054","obj_mode":1,"priority":2,"basis":"attacker","raw_role":"ANIM_BATTLER_ATTACKER","raw_offset":2,"source_args":[40,-32,0],"source_command":"createsprite gCuttingSliceSpriteTemplate, ANIM_BATTLER_ATTACKER, 2, 40, -32, 0","source_occurrence":1,"source_multiplicity":1}

static func _same(value: Variant, expected: Variant) -> bool:
	if typeof(expected)==TYPE_INT:
		return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==float(expected)
	if expected is Array:
		if not value is Array or value.size()!=expected.size():return false
		for index: int in expected.size():
			if not _same(value[index],expected[index]):return false
		return true
	if expected is Dictionary:
		if not value is Dictionary or value.size()!=expected.size():return false
		for key: Variant in expected:
			if not value.has(key) or not _same(value[key],expected[key]):return false
		return true
	return typeof(value)==typeof(expected) and value==expected

static func initialize(track: Dictionary, context: BattleAnimationContext, owner: Node2D) -> void:
	if track.kind!="sheet" or not owner is BattleAnimationSequenceRunner or not BattleAnimationSequenceRegistry.is_builtin_source_definition(owner.definition):return
	var site: Array=SITES.get(owner.definition.key,[])
	if site.is_empty() or owner.definition.source_script!=site[0]:return
	var step: Dictionary=track.settings
	if bool(step.get("recolor",false)):return
	var shape: Dictionary={"op":"effect","behavior":"sheet","source_line":site[1],"source_template":TEMPLATE,"source_callback":CALLBACK,"selector":"target","offset":[40,-32],"travel":[-62,62],"travel_ticks":20,"ticks":23,"frame_size":[32,32],"frame_commands":FRAMES}
	for key: String in shape:
		if not step.has(key) or not _same(step[key],shape[key]):return
	var optional: Dictionary={"source_args":[40,-32,0],"source_script":site[0],"source_oam":"&gOamData_837E054","source_animation_index":0,"source_affine_variant":0,"affine_program":[],"spawn_delay":0,"travel_delay":0,"blink_after":-1,"source_command":CUT.source_command}
	for key: String in optional:
		if step.has(key) and not _same(step[key],optional[key]):return
	for key: String in ["frame_program","side_frames","side_frame_programs","source_command_priority"]:
		if step.has(key):return
	if owner.definition.key=="ruby:move/15":
		if not _same(step.get("source_legacy_composition"),CUT):return
	elif not _same(step.get("source_legacy_composition"),AERIAL):return
	var targets:=context.resolve("target");var attackers:=context.resolve("attacker")
	if targets.is_empty() or attackers.is_empty():return
	var target: BattleAnimationActor=targets[0]
	track.origin=owner.to_local(context.field.to_global(BattleElectricContract.source_anchor(target,context,"origin")))+Vector2(40,-32+(8 if target.side==0 else 0))
	track.ticks=25
	track.source_cutting_slice={"target":target,"attacker":attackers[0],"texture":track.node.texture,"position":track.node.position,"region":track.node.region_rect,"h":track.node.flip_h,"v":track.node.flip_v,"pose_owned":true,"region_owned":true,"h_owned":true,"v_owned":true}

static func update(track: Dictionary) -> void:
	var lease: Dictionary=track.source_cutting_slice;var node: Sprite2D=track.node
	if not lease.target.is_present() or not lease.attacker.is_present():
		node.visible=false;track.ticks=int(track.age);return
	var age: int=int(track.age);var count: int=clampi(age,0,20)
	# Accumulator-before-acceleration; canonical values never reach signed overflow.
	var x_q8: int=(-1024*count+12*count*(count-1))
	x_q8=((x_q8+32768)&65535)-32768
	var y_q8: int=((-x_q8+32768)&65535)-32768
	lease.pose_owned=lease.pose_owned and node.position==lease.position
	if lease.pose_owned:
		node.position=track.origin+Vector2(x_q8>>8,y_q8>>8);lease.position=node.position
	# Source END holds tile48. Expected writes leave literal external art alone.
	var tile: int=16*clampi(age/5,0,3)
	lease.region_owned=lease.region_owned and node.texture==lease.texture and node.region_rect==lease.region
	if lease.region_owned:
		var width: int=node.texture.get_width()/8
		var rect:=Rect2((tile%width)*8,(tile/width)*8,32,32)
		if track.settings.has("frame_rects"):
			var value: Array=track.settings.frame_rects[str(tile)];rect=Rect2(value[0],value[1],value[2],value[3])
		node.region_rect=rect;lease.region=rect
	lease.h_owned=lease.h_owned and node.flip_h==lease.h
	lease.v_owned=lease.v_owned and node.flip_v==lease.v
	if lease.h_owned:node.flip_h=bool(track.settings.get("flip_h",false));lease.h=node.flip_h
	if lease.v_owned:node.flip_v=bool(track.settings.get("flip_v",false));lease.v=node.flip_v

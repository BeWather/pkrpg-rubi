extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Actual BG3 register sampling and source affine-rock callbacks; no HP authority.
const Bird=preload("res://scripts/battle/animations/sequence/source_bird_horn_owned.gd")
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
const Affine=preload("res://scripts/battle/animations/sequence/source_self_heal.gd")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if s.behavior=="source_seismic_hit":
		var result: Array[Dictionary]=Bird.create(s,c,owner)
		# Source IMPACT OAM objMode1 alone uses active12/8; rocks/monbg stay opaque.
		for track: Dictionary in result:BattleCounterSelected._blend_node(track.node,owner)
		return result
	if s.behavior=="source_seismic_command":return BattleCounterSelected.create(s,c,owner)
	if s.behavior=="source_seismic_tier":owner._source_args[7]=0 if c.source_damage<33 else 1 if c.source_damage<66 else 2;return []
	var t: Dictionary={"kind":str(s.behavior),"settings":s,"owner":owner,"age":0,"ticks":int(s.ticks),"update":advance}
	if s.behavior in ["source_seismic_rise","source_seismic_bounce"]:
		t.register_y=int(owner.get_meta("source_seismic_bg3_y",0));t.counter=0;t.velocity=200;t.phase=0;t.base=t.register_y
		if s.behavior=="source_seismic_bounce":t.domain="maintenance"
		advance(t,c);return [t]
	var actor: BattleAnimationActor=c.resolve("target")[0];var a: Array=s.source_args;var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;owner.add_child(node);var frame: Dictionary=BattleSourceCommandProgram.evaluate(s.frame_program,0).frame;var rect: Array=s.frame_rects[str(int(frame.tile))];node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);t.node=node;t.origin=Geometry._anchor(actor,c,owner,"origin")+Vector2(a[0],a[1]);t.offset=Vector2.ZERO;t.phase=0;t.accum_x=0;t.accum_y=0;node.position=t.origin;Affine._start_affine(t,0);BattleSourcePriority.initialize(t,c,owner);return [t]
static func _project(t: Dictionary) -> void:
	t.owner.set_meta("source_seismic_bg3_y",t.register_y)
	var bg: Sprite2D=t.owner._source_background
	if is_instance_valid(bg) and bg.texture!=null:
		# The actual late-created decoded BG3 child samples a wrapping map. Do
		# not move the runner, actors or cached field siblings by a second offset.
		bg.region_rect.position.y=posmod(int(t.register_y),bg.texture.get_height())
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if t.kind=="source_seismic_rise":
		t.register_y=(int(t.register_y)+int(int(t.velocity)/10))&65535;t.velocity=int(t.velocity)-3;_project(t);t.counter=int(t.counter)+1;return
	if t.kind=="source_seismic_bounce":
		t.phase=(int(t.phase)+80)&255;t.register_y=(int(t.base)+BattleSourceTrig.cosine(4,int(t.phase)))&65535
		if int(t.owner._source_args.get(7,0))==4095:t.register_y=0;t.ticks=int(t.age)
		_project(t);return
	t.phase=int(t.phase)+8;t.accum_x=int(t.accum_x)+int(t.settings.source_args[0]);t.accum_y=int(t.accum_y)+int(t.settings.source_args[1]);t.offset.x+=int(int(t.accum_x)/40);t.offset.y-=BattleSourceTrig.sine(int(t.phase),int(t.settings.source_args[2]));t.node.position=t.origin+t.offset;Affine._affine(t)

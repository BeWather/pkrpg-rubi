extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Packed source cut velocity keeps its low-bit direction on the reversed leg.
const Bird=preload("res://scripts/battle/animations/sequence/source_bird_horn_owned.gd")
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if s.behavior=="source_guillotine_hit":
		var tracks: Array[Dictionary]=Bird.create(s,c,owner)
		# IMPACT OAM objMode1 uses active12/8; keep Bird update/cleanup/priority.
		for track: Dictionary in tracks:BattleCounterSelected._blend_node(track.node,owner)
		return tracks
	if s.behavior=="source_guillotine_background":
		var id: int=14 if c.contest else 13 if c.resolve("target")[0].side==0 else 12;var step: Dictionary=s.duplicate(true);step.behavior="source_background";step.texture=s.textures[str(id)];step.source_background_id=id
		return BattleEffectBehaviorRegistry._create(step,c,owner,"source_background")
	if s.behavior=="source_guillotine_palette":
		var tracks: Array[Dictionary]=Bird.create(s,c,owner)
		for t: Dictionary in tracks:t.kind="source_guillotine_palette";t.update=advance
		_sync_palettes(owner);return tracks
	if s.behavior=="source_guillotine_command":
		var tracks: Array[Dictionary]=BattleCounterSelected.create(s,c,owner)
		for t: Dictionary in tracks:t.kind="source_guillotine_bg";t.update=advance
		return tracks
	var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;owner.add_child(node);BattleCounterSelected._blend_node(node,owner)
	var n: int=s.source_args[0];var direction: int=1 if n==0 else -1;var target: BattleAnimationActor=c.resolve("target")[0]
	var t: Dictionary={"kind":"source_guillotine_cut","settings":s,"owner":owner,"node":node,"age":0,"ticks":65,"update":advance,"phase":0,"counter":0,"flip":false,"variant":n,"frame_age":0,"tile":0,"base":Geometry._anchor(target,c,owner,"center")+Vector2(32,-32)*direction,"offset":Vector2.ZERO,"remaining":6,"qx":0,"qy":0,"vx":683 if n==0 else 682,"vy":682 if n==0 else 683}
	_frame(t,0);node.position=t.base;BattleSourcePriority.initialize(t,c,owner);return [t]
static func _frame(t: Dictionary,age: int) -> void:
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.source_frame_variants[int(t.variant)],age).frame;t.tile=int(frame.tile);var r: Array=t.settings.frame_rects[str(t.tile)];t.node.region_rect=Rect2(r[0],r[1],r[2],r[3]);t.node.flip_h=bool(frame.get("flip_h",false));t.node.flip_v=bool(frame.get("flip_v",false))
static func _linear(t: Dictionary) -> bool:
	if int(t.remaining)==0:return true
	t.qx=(int(t.qx)+int(t.vx))&65535;t.qy=(int(t.qy)+int(t.vy))&65535;t.offset=Vector2((int(t.qx)>>8)*(-1 if int(t.vx)&1 else 1),(int(t.qy)>>8)*(-1 if int(t.vy)&1 else 1));t.remaining=int(t.remaining)-1;return false
static func _sync_palettes(owner: Node2D) -> void:
	for bg: Dictionary in owner.get_meta("source_counter_monbg",[]):
		for member: Dictionary in bg.clones:
			var blend: Dictionary=owner._held_blends.get(member.actor.id,{"color":Color.WHITE,"amount":0.0})
			member.actor.apply_blend(blend.color,float(blend.amount));member.node.material=member.actor.sprite.material
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if t.kind=="source_guillotine_palette":Bird.advance(t,c);_sync_palettes(t.owner);return
	if t.kind=="source_guillotine_bg":
		BattleCounterSelected._bg_update(t,c)
		for member: Dictionary in t.clones:
			if member.actor.is_present():member.node.material=member.actor.sprite.material
		return
	match int(t.phase):
		0:
			_frame(t,int(t.age))
			if _linear(t):
				t.base+=t.offset;t.offset=Vector2(2,-2);t.remaining=6;t.vx=int(t.vx)^1;t.vy=int(t.vy)^1;t.qx=0;t.qy=0;t.phase=1;_frame(t,0)
		1:
			if bool(t.flip):t.offset=-t.offset
			t.flip=not bool(t.flip);t.counter=int(t.counter)+1
			if int(t.counter)==51:t.offset=Vector2.ZERO;t.phase=2;t.variant=int(t.settings.source_args[0])^1;t.frame_age=0;_frame(t,0)
		2:
			t.frame_age=int(t.frame_age)+1;_frame(t,int(t.frame_age))
			if _linear(t):t.ticks=int(t.age)
	t.node.position=t.base+t.offset

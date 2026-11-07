extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Source integer callback and affine cadence; no status, PP or called-move writes.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
const Affine=preload("res://scripts/battle/animations/sequence/source_self_heal.gd")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var actor: BattleAnimationActor=c.resolve("attacker")[0]
	var t: Dictionary={"kind":s.behavior,"settings":s,"owner":owner,"original_actor":actor,"age":0,"ticks":int(s.ticks),"update":advance,"side":actor.side,"counter":0}
	if s.behavior=="source_sleep_talk_sway":t.cleanup=_cleanup.bind(t);return [t]
	var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;var rect: Array=s.frame_rects["0"];node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);owner.add_child(node);t.node=node;t.origin=Geometry._anchor(actor,c,owner,"center");t.vx=-5 if c.contest or actor.side!=0 else 5;t.vy=int(s.source_args[3])*(-1 if not c.contest and actor.side!=0 else 1)
	# sub_812C848 never reads arg1=20. Its first callback moves immediately.
	_motion(t);Affine._start_affine(t,0);_pose(t);BattleSourcePriority.initialize(t,c,owner);return [t]
static func _motion(t: Dictionary) -> void:
	t.counter=int(t.counter)+1;t.node.position=t.origin+Vector2(int(int(t.counter)*int(t.vx)/2),BattleSourceTrig.sine(int(t.counter)*20,5)+int(int(t.counter)*int(t.vy)/2))
	if (int(t.node.position.x)&65535)>240:t.ticks=int(t.age)
static func _pose(t: Dictionary) -> void:
	t.node.scale=Vector2(256.0/t.affine.matrix.x,256.0/t.affine.matrix.y);t.node.rotation=-float(t.affine.rotation)*TAU/256
static func advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	if t.kind=="source_sleep_talk_sway":
		t.offset=Vector2(BattleSourceTrig.sine(int(t.age)*16,4 if int(t.side)==0 else -4),0) if int(t.age)<16 else Vector2.ZERO;t.owner._held_offsets[t.original_actor.id]=t.offset;return
	_motion(t);Affine._affine(t);_pose(t)
static func _cleanup(t: Dictionary) -> void:
	t.erase("cleanup")
	if t.owner._held_offsets.get(t.original_actor.id)==t.get("offset",Vector2.ZERO):t.owner._held_offsets[t.original_actor.id]=Vector2.ZERO

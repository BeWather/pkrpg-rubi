extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Literal source coin callbacks; no HP, PP, wallet or battle counter writes.
const Bird=preload("res://scripts/battle/animations/sequence/source_bird_horn_owned.gd")
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if s.behavior=="source_pay_day_hit":
		var tracks: Array[Dictionary]=Bird.create(s,c,owner)
		for t: Dictionary in tracks:BattleCounterSelected._blend_node(t.node,owner)
		return tracks
	var actor: BattleAnimationActor=c.resolve("attacker")[0];var target: BattleAnimationActor=c.resolve("target")[0];var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;var rect: Array=s.frame_rects["8"];node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);owner.add_child(node)
	var t: Dictionary={"kind":s.behavior,"settings":s,"owner":owner,"node":node,"age":0,"ticks":int(s.ticks),"update":advance,"origin":Geometry._anchor(target,c,owner,"center")+Vector2(0,8),"side":actor.side,"phase":0,"amplitude":-16,"cycles":0,"qx":0,"qy":0}
	if s.behavior=="source_pay_day_projectile":
		t.origin=Geometry._anchor(actor,c,owner,"center")+Vector2(20*BattleElectricContract.source_offset_direction(c,actor,target),0);t.destination=Geometry._anchor(target,c,owner,"center");var delta: Vector2=t.destination-t.origin;var duration: int=(absi(int(delta.x))<<8)/1152
		# Source divides by zero at degenerate X; do not invent travel semantics.
		if duration<=0:node.queue_free();return []
		t.vx=_velocity(int(delta.x),duration);t.vy=_velocity(int(delta.y),duration);t.duration=duration;t.ticks=duration+2
		# OAM samples the inverse matrix; Node2D renders its inverse rotation.
		t.angle=Bird.geometric_angle(int(delta.x),int(delta.y));node.rotation=-float(t.angle)*TAU/65536
	else:node.rotation=-10.0*TAU/256 # BeginAffineAnim applies its first delta.
	node.position=t.origin;BattleSourcePriority.initialize(t,c,owner);return [t]
static func _velocity(distance: int,duration: int) -> int:
	var value: int=(absi(distance)<<8)/duration
	return value|1 if distance<0 else value&~1
static func advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	if t.kind=="source_pay_day_projectile":
		if int(t.age)>int(t.duration):return
		t.qx=(int(t.qx)+int(t.vx))&65535;t.qy=(int(t.qy)+int(t.vy))&65535;t.node.position=t.origin+Vector2((int(t.qx)>>8)*(-1 if int(t.vx)&1 else 1),(int(t.qy)>>8)*(-1 if int(t.vy)&1 else 1));return
	var offset: Vector2=Vector2((int(t.age)*128)>>8,BattleSourceTrig.sine(int(t.phase),int(t.amplitude)))
	if int(t.side)==0:offset.x=-offset.x
	t.node.position=t.origin+offset;t.phase=int(t.phase)+5
	if int(t.phase)>126:t.phase=0;t.amplitude=int(t.amplitude)/2;t.cycles=int(t.cycles)+1
	t.node.rotation=-float((10*(int(t.age)+1))&255)*TAU/256

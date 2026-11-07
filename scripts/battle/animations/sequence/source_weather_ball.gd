extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Weather Ball launch and target-relative falling sprites; no gameplay weather mutation.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
const Affine=preload("res://scripts/battle/animations/sequence/source_self_heal.gd")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if s.behavior=="source_weather_ball_weather":owner._source_args[7]=int(c.get_meta("source_weather",0));return []
	var t: Dictionary={"kind":s.behavior,"settings":s,"owner":owner,"age":0,"ticks":4096,"update":advance}
	if s.behavior=="source_weather_ball_dip":t.original_actor=c.resolve("attacker")[0];t.phase=0;t.remaining=8;t.speed=1;t.offset=Vector2.ZERO;return [t]
	var actor: BattleAnimationActor=c.resolve("attacker" if s.behavior=="source_weather_ball_launch" else "target")[0]
	var n:=Sprite2D.new();n.texture=load(str(s.texture));n.region_enabled=true;owner.add_child(n);t.node=n;t.original_actor=actor
	var anchor: Vector2=Geometry._anchor(actor,c,owner,"center");anchor=Vector2(int(anchor.x),int(anchor.y))
	if s.behavior=="source_weather_ball_chips":
		t.origin=Geometry._anchor(actor,c,owner,"origin")+Vector2(s.source_args[0],s.source_args[1]);t.accumulator=Vector2.ZERO;t.offset=Vector2.ZERO;t.ticks=18
	elif s.behavior=="source_weather_ball_launch":t.origin=anchor;t.velocity=Vector2(5 if actor.side==0 else -10,-40);t.accumulator=Vector2.ZERO
	else:
		var a: Array=s.source_args;t.destination=anchor+Vector2(a[4],a[5]);t.origin=Vector2(int(anchor.x)+int(a[4])+(30 if actor.side==0 else -30),int(a[5])-(20 if actor.side==0 else 80));t.remaining=int(a[2]);t.accumulator=Vector2i.ZERO
		var delta: Vector2=t.destination-t.origin;var x: int=int(abs(delta.x)*256)/int(a[2]);var y: int=int(abs(delta.y)*256)/int(a[2]);t.delta=Vector2i((x|1) if delta.x<0 else (x&~1),(y|1) if delta.y<0 else (y&~1))
	n.position=t.origin;_frame(t,0);Affine._start_affine(t,0);BattleSourcePriority.initialize(t,c,owner);return [t]
static func _frame(t: Dictionary,age: int) -> void:
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.frame_program,age).frame;var r: Array=t.settings.frame_rects[str(int(frame.tile))];t.node.region_rect=Rect2(r[0],r[1],r[2],r[3]);t.node.flip_h=bool(frame.get("flip_h",false));t.node.flip_v=bool(frame.get("flip_v",false))
static func advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	if t.kind=="source_weather_ball_dip":
		if int(t.phase) in [0,2]:
			if int(t.remaining)>0:t.offset+=Vector2(0,t.speed);t.owner._held_offsets[t.original_actor.id]=t.owner._held_offsets.get(t.original_actor.id,Vector2.ZERO)+Vector2(0,t.speed);t.remaining=int(t.remaining)-1
			else:t.phase=int(t.phase)+1
		elif int(t.phase)==1:t.remaining=8;t.speed=-1;t.phase=2
		else:t.ticks=int(t.age)
		return
	if t.kind=="source_weather_ball_chips":
		t.accumulator+=Vector2(t.settings.source_args[0],t.settings.source_args[1]);t.offset.x+=int(int(t.accumulator.x)/40.0);t.offset.y-=BattleSourceTrig.sine(int(t.age)*8,int(t.settings.source_args[2]));t.node.position=t.origin+t.offset
	elif t.kind=="source_weather_ball_launch":
		t.accumulator+=t.velocity;t.node.position=t.origin+Vector2(int(int(t.accumulator.x)/10.0),int(int(t.accumulator.y)/10.0))
		if int(t.velocity.y)< -20:t.velocity.y+=1
		if t.node.position.y< -32:t.ticks=int(t.age)
	else:
		if int(t.remaining)>0:
			t.accumulator=Vector2i((int(t.accumulator.x)+int(t.delta.x))&65535,(int(t.accumulator.y)+int(t.delta.y))&65535);t.remaining=int(t.remaining)-1
			t.node.position=t.origin+Vector2(-(int(t.accumulator.x)>>8) if int(t.delta.x)&1 else int(t.accumulator.x)>>8,-(int(t.accumulator.y)>>8) if int(t.delta.y)&1 else int(t.accumulator.y)>>8)
		elif int(t.age)>=int(t.settings.source_args[2])+2:t.ticks=int(t.age)
	Affine._affine(t);_frame(t,int(t.age))

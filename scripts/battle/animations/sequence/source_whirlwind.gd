extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Source literal line travel, synchronous side ellipse and unsigned offscreen test.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if s.behavior=="source_whirlwind_release":
		var pose: Dictionary=owner.get_meta("source_whirlwind_exit_pose",{})
		if not pose.is_empty() and owner._held_offsets.get(pose.id)==pose.offset:owner._held_offsets[pose.id]=Vector2.ZERO
		if owner.has_meta("source_whirlwind_exit_pose"):owner.remove_meta("source_whirlwind_exit_pose")
		return []
	var actor: BattleAnimationActor=c.resolve("target")[0];var a: Array=s.source_args
	var t: Dictionary={"kind":str(s.behavior),"settings":s,"owner":owner,"original_actor":actor,"age":0,"ticks":int(s.ticks),"update":advance,"offset":Vector2.ZERO,"phase":0,"loops":1}
	if s.behavior=="source_whirlwind_line":
		var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;owner.add_child(node);t.node=node;t.origin=Geometry._anchor(actor,c,owner,"origin")+Vector2((-24 if actor.side==0 else -32),int(a[1]));t.counter=int(a[4]);t.x2=12*int(a[4]);t.seek=int(a[4]);t.frame_age=0;_frame(t);node.position=t.origin+Vector2(t.x2,0);BattleSourcePriority.initialize(t,c,owner);return [t]
	t.cleanup=_cleanup.bind(t)
	if s.behavior=="source_whirlwind_ellipse":t.width=12 if c.resolve("attacker")[0].side==0 else -12;_ellipse(t);return [t]
	t.done=false;t.origin=Geometry._anchor(actor,c,owner,"origin");t.offset=owner.get_actor_offset(actor.id);t.velocity=8 if actor.side!=0 else -8;return [t]
static func _frame(t: Dictionary) -> void:
	var f: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.frame_program,int(t.seek)+int(t.frame_age)).frame;var rect: Array=t.settings.frame_rects[str(int(f.tile))];t.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);t.node.flip_h=bool(f.get("flip_h",false))
static func _ellipse(t: Dictionary) -> void:
	t.offset=Vector2(BattleSourceTrig.sine(int(t.phase),int(t.width)),6-BattleSourceTrig.cosine(int(t.phase),6));t.phase=(int(t.phase)+32)&255
	if int(t.phase)==0:t.offset=Vector2.ZERO;t.ticks=int(t.age)
	t.owner._held_offsets[t.original_actor.id]=t.offset
static func advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	if t.kind=="source_whirlwind_line":
		t.x2=int(t.x2)+12;t.counter=int(t.counter)+1;t.frame_age=int(t.frame_age)+1
		if int(t.counter)==6:t.counter=0;t.x2=0;t.seek=0;t.frame_age=0
		t.node.position=t.origin+Vector2(t.x2,0);_frame(t);return
	if t.kind=="source_whirlwind_ellipse":_ellipse(t);return
	if t.done:return
	t.offset.x+=int(t.velocity);t.owner._held_offsets[t.original_actor.id]=t.offset
	if ((int(t.origin.x+t.offset.x)+32)&0xffffffff)>304:
		# Source destroys the task but leaves x2 offscreen until bank replacement.
		# Retire the task; retain only an owned pose until source END.
		t.done=true;t.owner.set_meta("source_whirlwind_exit_pose",{"id":t.original_actor.id,"offset":t.offset});t.ticks=int(t.age)
static func _cleanup(t: Dictionary) -> void:
	t.erase("cleanup")
	if t.kind=="source_whirlwind_exit" and t.done:return
	if t.owner._held_offsets.get(t.original_actor.id)==t.offset:t.owner._held_offsets[t.original_actor.id]=Vector2.ZERO

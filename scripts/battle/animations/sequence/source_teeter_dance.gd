extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Distinct from Belly Drum: signed Q4 expansion, one orbit, looping +/- affine.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var actors: Array[BattleAnimationActor]=c.resolve("attacker")
	if actors.is_empty():return []
	var actor: BattleAnimationActor=actors[0];var t: Dictionary={"kind":str(step.behavior),"settings":step,"owner":owner,"original_actor":actor,"age":0,"ticks":int(step.ticks),"update":advance}
	if t.kind=="source_teeter_sway":return [t]
	var a: Array=step.source_args.duplicate()
	if actor.side!=0:a[1]=-int(a[1]);owner._source_args[1]=int(a[1])&65535
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;owner.add_child(node);t.node=node
	t.origin=Geometry._anchor(actor,c,owner,"center")+Vector2(int(a[1]),int(a[2]));t.vx=int(int(a[1])*16/5);t.vy=int(int(a[2])*128/5);t.orbit_phase=0
	BattleSourcePriority.initialize(t,c,owner);_note(t,0);return [t]
static func _note(t: Dictionary,age: int) -> void:
	var s: Dictionary=t.settings;var frame: Dictionary=BattleSourceCommandProgram.evaluate(s.frame_program,age).frame;var rect: Array=s.frame_rects[str(int(frame.tile))]
	t.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);t.node.flip_h=bool(frame.get("flip_h",false));t.node.flip_v=bool(frame.get("flip_v",false))
	var pose: Dictionary=BattleSourceCommandProgram.evaluate(s.affine_program,age,true);t.node.scale=Vector2(256.0/pose.matrix.x,256.0/pose.matrix.y)
	# Source increments the orbit only when PRE-increment lifetime exceeds5.
	var orbit_age: int=clampi(age-6,0,16);t.orbit_phase=(orbit_age*16)&255
	var orbit: Vector2=Vector2(BattleSourceTrig.cosine(int(t.orbit_phase),18),BattleSourceTrig.sine(int(t.orbit_phase),18)) if age>=7 else Vector2.ZERO
	t.node.position=t.origin+Vector2((age*int(t.vx))>>4,(age*int(t.vy))>>4)+orbit
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if t.kind=="source_teeter_note":_note(t,int(t.age));return
	var actor: BattleAnimationActor=t.original_actor
	if c.actors.get(actor.id)!=actor or not actor.is_present():t.ticks=int(t.age);return
	var age: int=int(t.age);var base: int=(BattleSourceTrig.VALUES[(age*2)&255]>>3)*(1 if actor.side==0 else -1) if age<=128 else 0
	var jitter: int=BattleSourceTrig.VALUES[(age*8)&255]>>5 if age<=160 else 0
	t.owner._held_offsets[actor.id]=Vector2(base+jitter,0)

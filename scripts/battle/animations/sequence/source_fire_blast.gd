extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## fire_2.c:222–310 and sfx.c:23–87; literal finite sprite/sound continuations.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
const PackedMotion=preload("res://scripts/battle/animations/sequence/source_sports.gd")
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var attackers: Array[BattleAnimationActor]=c.resolve("attacker");var targets: Array[BattleAnimationActor]=c.resolve("target");var a: Array=step.get("source_args",[])
	var ring: bool=str(step.get("mode",""))=="ring"
	if attackers.is_empty() or targets.is_empty() or a.size()!=(3 if ring else 5) or str(step.get("source_callback",""))!=("AnimFireRing" if ring else "AnimFireCross"):return []
	var actor: BattleAnimationActor=attackers[0];var target: BattleAnimationActor=targets[0]
	var origin: Vector2=Geometry._anchor(actor if ring else target,c,owner,"center")+Vector2(int(a[0]),int(a[1]))
	var destination: Vector2=Geometry._anchor(target,c,owner,"center")
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;node.position=origin;owner.add_child(node)
	var t: Dictionary={"kind":"source_fire_blast","mode":"ring" if ring else "cross","settings":step.duplicate(true),"owner":owner,"node":node,"original_actor":actor,"original_target":target,"args":a.duplicate(),"origin":origin,"destination":destination,"age":0,"ticks":4096,"stage":0,"counter":0,"angle":int(a[2]) if ring else 0,"remaining":0 if ring else int(a[2]),"acc_x":0,"acc_y":0,"update":advance}
	BattleSourcePriority.initialize(t,c,owner);_pose(t)
	return [t]
static func _pose(t: Dictionary) -> void:
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.frame_program,int(t.age)).frame
	var rect: Array=t.settings.frame_rects[str(int(frame.tile))]
	t.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);t.node.flip_h=bool(frame.get("flip_h",false));t.node.flip_v=bool(frame.get("flip_v",false))
static func _circle(t: Dictionary,linear: Vector2=Vector2.ZERO) -> void:
	t.node.position=t.origin+linear+Vector2(BattleSourceTrig.sine(int(t.angle),28),BattleSourceTrig.cosine(int(t.angle),28))
	t.angle=(int(t.angle)+20)&255
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if c.actors.get(t.original_actor.id)!=t.original_actor or c.actors.get(t.original_target.id)!=t.original_target or not t.original_actor.is_present() or not t.original_target.is_present():t.ticks=int(t.age);return
	if t.mode=="cross":
		if int(t.remaining)>0:
			t.remaining=int(t.remaining)-1;t.node.position+=Vector2(int(t.args[3]),int(t.args[4]))
		elif int(t.stage)==0:t.stage=1 # Switch to stored destroy; next callback destroys.
		else:t.ticks=int(t.age)
	else:
		match int(t.stage):
			0:
				_circle(t);t.counter=int(t.counter)+1
				if int(t.counter)==18:
					t.stage=1;t.remaining=25;t.acc_x=0;t.acc_y=0
					t.vx=PackedMotion._delta(int(t.destination.x-t.origin.x),25);t.vy=PackedMotion._delta(int(t.destination.y-t.origin.y),25)
			1:
				if int(t.remaining)>0:
					t.acc_x=(int(t.acc_x)+int(t.vx))&65535;t.acc_y=(int(t.acc_y)+int(t.vy))&65535;t.remaining=int(t.remaining)-1
					_circle(t,Vector2((int(t.acc_x)>>8)*(-1 if int(t.vx)&1 else 1),(int(t.acc_y)>>8)*(-1 if int(t.vy)&1 else 1)))
				else:
					t.origin=t.destination;t.stage=2;t.counter=1;_circle(t) # Source immediately calls Step3.
			2:
				_circle(t);t.counter=int(t.counter)+1
				if int(t.counter)==31:t.ticks=int(t.age)
	_pose(t)
static func create_sound(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if str(step.get("source_callback",""))!="sub_812AF30" or step.get("sound_paths",[]).size()!=2:return []
	for path: String in step.sound_paths:
		if not ResourceLoader.exists(path) or not load(path) is AudioStream:
			owner.error_message="Missing Fire Blast sound task dependency: "+path;owner.finish("failed");return []
	var start: int=BattleCounterSelected.adjust_panning(-64,c);var target: int=BattleCounterSelected.adjust_panning(63,c)
	return [{"kind":"source_fire_blast_sound","domain":"sound","settings":step.duplicate(true),"owner":owner,"age":0,"ticks":118,"stage":0,"counter":0,"cue_counter":10,"pan":start,"target_pan":target,"pan_increment":2*signi(target-start),"played":0,"update":advance_sound}]
static func _cue(t: Dictionary,index: int,pan: int) -> void:
	var player: AudioStreamPlayer2D=t.owner._play_sound(str(t.settings.sound_paths[index]),"",float(pan)/64.0,true)
	if is_instance_valid(player):t.owner.sound_events.back().merge({"source_callback":"sub_812AF30","source_task_age":int(t.age),"source_pan_value":pan,"source_sound":str(t.settings.source_sounds[index])})
static func advance_sound(t: Dictionary,_c: BattleAnimationContext) -> void:
	if int(t.stage)==0:
		t.counter=int(t.counter)+1
		if int(t.counter)==111:t.stage=1;t.cue_counter=5;t.counter=0
		else:
			t.cue_counter=int(t.cue_counter)+1
			if int(t.cue_counter)==11:t.cue_counter=0;_cue(t,0,int(t.pan))
			t.pan=clampi(int(t.pan)+int(t.pan_increment),-64,63)
	else:
		t.cue_counter=int(t.cue_counter)+1
		if int(t.cue_counter)==6:
			t.cue_counter=0;_cue(t,1,int(t.target_pan));t.played=int(t.played)+1
			if int(t.played)==2:t.ticks=int(t.age)

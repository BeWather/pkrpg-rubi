extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## thought.c/finger.c callback storage, side-aware frames and source fixed-point orbit.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var actors: Array[BattleAnimationActor]=c.resolve("attacker" if int(step.source_args[0])==0 else "target")
	if actors.is_empty():return []
	var actor: BattleAnimationActor=actors[0];var bounds: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(step.source_bounds)))
	var species: String=str(c.source_appearance_species.get(actor.id,c.source_party_species.get(actor.id,""))).to_upper();var side: String="back" if c.contest or actor.side==0 else "front";var sizes: Dictionary=bounds.by_species.get(species,{})
	if not sizes.has(side):owner.error_message="Missing source thought/finger picture bounds: "+species;owner.finish("failed");return []
	var picture:=Vector2(sizes[side][0],sizes[side][1]);var center: Vector2=Geometry._anchor(actor,c,owner,"center")
	var origin: Vector2=center+Vector2(picture.x/2+8 if actor.side==0 else -picture.x/2-8,-picture.y/4)
	if step.mode=="follow":origin=Vector2(Geometry._anchor(actor,c,owner,"origin").x,maxf(10,center.y-picture.y/2))
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;node.position=origin;owner.add_child(node)
	var t: Dictionary={"kind":"source_thought_finger","mode":str(step.mode),"settings":step.duplicate(true),"owner":owner,"original_actor":actor,"picture_size":picture,"center":center,"node":node,"origin":origin,"age":0,"ticks":4096,"stage":"expand" if step.mode=="bubble" else "wait_affine" if step.mode in ["metronome","follow"] else "wait_gesture","counter":0,"phase":0,"local_age":0,"frame_variant":0 if actor.side==0 else 1,"frame_tile":0,"affine_variant":0,"affine_start":0,"base_subpriority":0,"update":advance}
	BattleSourcePriority.initialize(t,c,owner);t.base_subpriority=int(t.get("source_oam_subpriority",BattleElectricContract.source_subpriority(actor,c)))
	_pose(t);return [t]
static func _pose(t: Dictionary) -> void:
	var p: Array=t.settings.source_frame_variants[str(t.frame_variant)] if t.settings.has("source_frame_variants") else t.settings.frame_program
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(p,int(t.local_age)).frame;t.frame_tile=int(frame.tile)
	var rect: Array=t.settings.frame_rects[str(int(frame.tile))];t.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);t.node.flip_h=bool(frame.get("flip_h",false));t.node.flip_v=bool(frame.get("flip_v",false))
	if t.settings.has("source_affine_variants"):
		var program: Array=t.settings.source_affine_variants[str(t.affine_variant)];var pose: Dictionary=BattleSourceCommandProgram.evaluate(program,int(t.age)-int(t.affine_start),true)
		# Source StartSpriteAffineAnim(1) retains the matrix from growth (256).
		var matrix: Vector2=pose.matrix
		t.node.scale=Vector2(256.0/matrix.x,256.0/matrix.y);t.node.rotation=-float(pose.rotation)*TAU/256.0
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	t.local_age=int(t.local_age)+1
	match str(t.stage):
		"expand":
			if bool(BattleSourceCommandProgram.evaluate(t.settings.source_frame_variants[str(t.frame_variant)],int(t.local_age)).ended):t.stage="hold";t.counter=int(t.settings.source_args[1]);t.local_age=0
		"hold":
			t.counter=int(t.counter)-1
			if int(t.counter)==0:t.frame_variant=int(t.frame_variant)+2;t.stage="contract";t.local_age=0
		"contract":
			if bool(BattleSourceCommandProgram.evaluate(t.settings.source_frame_variants[str(t.frame_variant)],int(t.local_age)).ended):t.stage="cleanup"
		"wait_affine":
			if bool(BattleSourceCommandProgram.evaluate(t.settings.source_affine_variants["0"],int(t.age),true).ended):t.stage="follow_wait" if t.mode=="follow" else "finger_wait";t.counter=0
		"follow_wait":
			t.counter=int(t.counter)+1
			if int(t.counter)>12:t.stage="orbit"
		"orbit":
			t.phase=int(t.phase)+4
			if int(t.phase)>254:t.node.position=t.origin;t.stage="finger_wait";t.counter=0
			else:
				var raw: int=BattleSourceTrig.sine(int(t.phase),256);var shifted: int=raw>>3
				t.node.position=t.origin+Vector2(shifted+(shifted>>1),0)
				var delta: int=4 if int(t.phase)>79 and int(t.phase)<=159 else 0
				t.source_oam_subpriority=int(t.base_subpriority)+delta;t.node.z_index=BattleSourcePriority.relative_layer(t.original_actor,int(t.source_oam_subpriority)-BattleElectricContract.source_subpriority(t.original_actor,c),c,t.owner)
		"finger_wait":
			t.counter=int(t.counter)+1
			if int(t.counter)>16:t.stage="shrink";t.affine_variant=1;t.affine_start=int(t.age)
		"shrink":
			if bool(BattleSourceCommandProgram.evaluate(t.settings.source_affine_variants["1"],int(t.age)-int(t.affine_start),true).ended):t.stage="cleanup"
		"wait_gesture":
			t.counter=int(t.counter)+1
			if int(t.counter)>10:t.stage="gesture";t.frame_variant=int(t.frame_variant)+2;t.local_age=0;t.counter=0
		"gesture":
			if bool(BattleSourceCommandProgram.evaluate(t.settings.source_frame_variants[str(t.frame_variant)],int(t.local_age)).ended):t.stage="gesture_hold";t.counter=0
		"gesture_hold":
			t.counter=int(t.counter)+1
			if int(t.counter)>5:t.stage="cleanup"
		"cleanup":t.ticks=int(t.age)
	_pose(t)

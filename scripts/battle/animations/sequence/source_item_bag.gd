extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Source packed-byte interpolation, discrete hops and side-specific tail cleanup.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if str(step.behavior)=="source_item_roles":
		var receiver: int=int(c.get_meta("source_item_receiver_id",c.attacker_id));var donor: int=int(c.get_meta("source_item_donor_id",c.target_ids[0]))
		if str(step.source_callback)=="sub_80E42D0":c.attacker_id=receiver
		c.target_ids.assign([donor]);c.set_meta("source_item_roles_bound",true);return []
	var actors: Array[BattleAnimationActor]=c.resolve("attacker");var targets: Array[BattleAnimationActor]=c.resolve("target")
	if actors.is_empty() or targets.is_empty():return []
	var target: BattleAnimationActor=targets[0];var steal: bool=str(step.source_callback)=="sub_80CBAE8"
	var origin: Vector2=Geometry._anchor(target,c,owner,"origin")+Vector2(0,-5 if steal else 0)
	var destination: Vector2=Geometry._anchor(actors[0] if steal else target,c,owner,"origin")+Vector2(0,10)
	origin=Vector2(int(origin.x)&255,int(origin.y)&255);destination=Vector2(int(destination.x)&255,int(destination.y)&255)
	if not steal:destination.x=0 if target.side==0 or c.contest else 255
	if destination.x==0:destination.x=-32
	elif destination.x==255:destination.x=272
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;owner.add_child(node)
	var t: Dictionary={"kind":"source_item_bag","settings":step,"owner":owner,"node":node,"origin":origin,"destination":destination,"original_actor":actors[0],"original_target":target,"steal":steal,"duration":60 if steal else 40,"age":0,"ticks":4096,"phase":0,"hops":0,"stage":"hop","tail_count":0,"affine_age":0,"tail_affine":false,"update":advance}
	t.frequency=1 if steal and (c.source_position(target.id)^2)==c.source_position(actors[0].id) else 3
	BattleSourcePriority.initialize(t,c,owner);node.position=origin;_pose(t);return [t]
static func _pose(t: Dictionary) -> void:
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.frame_program,int(t.age)).frame
	var rect: Array=t.settings.frame_rects[str(int(frame.tile))];t.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3])
	var p: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.source_tail_affine if t.tail_affine else t.settings.affine_program,int(t.affine_age),true)
	t.node.scale=Vector2(256.0/p.matrix.x,256.0/p.matrix.y);t.node.rotation=-float(p.rotation)*TAU/256
static func _cue(t: Dictionary,role: String) -> void:
	t.owner._play_sound(str(t.settings.source_sound_path),role)
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if not t.original_actor.is_present() or not t.original_target.is_present():t.ticks=int(t.age);return
	t.affine_age=int(t.affine_age)+1
	if t.stage=="hop":
		t.phase=int(t.phase)+int(int(t.frequency)*128/60)
		if int(t.phase)>=128:t.hops=int(t.hops)+1;t.phase=0
		var y: int=BattleSourceTrig.sine(int(t.phase)+128,30-int(t.hops)*8)
		var n: int=int(t.age)-1
		t.node.position=t.origin+Vector2(int((t.destination.x-t.origin.x)*n/int(t.duration)),int((t.destination.y-t.origin.y)*n/int(t.duration))+y)
		if t.steal and y==0:_cue(t,"SOUND_PAN_TARGET")
		if int(t.age)==int(t.duration):
			t.node.position.y-=y
			if not t.steal and t.original_target.side!=0:t.ticks=int(t.age)
			else:t.stage="tail";t.tail_count=0
			if t.steal:_cue(t,"SOUND_PAN_ATTACKER")
	else:
		if int(t.tail_count)==10:t.tail_affine=true;t.affine_age=0
		t.tail_count=int(t.tail_count)+1
		if int(t.tail_count)>50:t.ticks=int(t.age)
	_pose(t)

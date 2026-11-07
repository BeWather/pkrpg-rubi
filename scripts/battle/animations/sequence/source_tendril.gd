extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## tendrils.c:71–122: paused affine until ARG7, then finite source affine cycles.
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var attackers: Array[BattleAnimationActor]=c.resolve("attacker");var targets: Array[BattleAnimationActor]=c.resolve("target")
	if attackers.is_empty() or targets.is_empty() or str(step.get("source_callback",""))!="sub_80CB25C":return []
	var a: Array=step.get("source_args",[])
	if a.size()!=4 or int(a[2]) not in [0,1] or int(a[3])<=0:return []
	var attacker: BattleAnimationActor=attackers[0];var target: BattleAnimationActor=targets[0]
	var origin: Vector2=BattleElectricContract.source_anchor(target,c,"origin")+Vector2(int(a[0])*BattleElectricContract.source_offset_direction(c,attacker,target),int(a[1]))
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;node.position=origin;owner.add_child(node)
	var t: Dictionary={"kind":"source_tendril","settings":step.duplicate(true),"owner":owner,"node":node,"attacker":attacker,"target":target,"args":a.duplicate(),"age":0,"ticks":4096,"waiting":true,"affine_age":0,"affine_ended":false,"remaining_cycles":int(a[3]),"completed_cycles":0,"source_counter":256,"source_half_tick":0,"source_counter_down":false,"update":advance}
	BattleSourcePriority.initialize(t,c,owner);_pose(t)
	return [t]
static func _inverse(value: float) -> float:return 256.0/value if value!=0.0 else 256.0
static func _pose(t: Dictionary) -> void:
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.frame_program,int(t.age)).frame
	var rect: Array=t.settings.frame_rects[str(int(frame.tile))]
	t.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);t.node.flip_h=bool(frame.get("flip_h",false));t.node.flip_v=bool(frame.get("flip_v",false))
	var pose: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.affine_program,int(t.affine_age),true)
	t.node.scale=Vector2(_inverse(float(pose.matrix.x)),_inverse(float(pose.matrix.y)))
	t.node.rotation=-float(pose.rotation)*TAU/256.0
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if c.actors.get(t.attacker.id)!=t.attacker or c.actors.get(t.target.id)!=t.target or not t.attacker.is_present() or not t.target.is_present():t.node.visible=false;t.ticks=int(t.age);return
	if bool(t.waiting):
		if (int(t.owner._source_args.get(7,0))&65535)==65535:
			t.waiting=false;t.affine_age=1 # Unpaused sprite engine applies first relative frame.
	else:
		# Preserve the callback's private counter even though source never applies
		# it to a battler: only the tendril's own affine stream changes geometry.
		t.source_counter=int(t.source_counter)+(-11 if t.source_counter_down else 11)
		t.source_half_tick=int(t.source_half_tick)+1
		if int(t.source_half_tick)==6:t.source_half_tick=0;t.source_counter_down=not t.source_counter_down
		if bool(t.affine_ended):
			t.completed_cycles=int(t.completed_cycles)+1;t.remaining_cycles=int(t.remaining_cycles)-1
			if int(t.remaining_cycles)<=0:t.ticks=int(t.age);return
			t.affine_age=0;t.affine_ended=false # StartSpriteAffineAnim resets absolute matrix.
		else:
			t.affine_age=int(t.affine_age)+1
			# Relative stream consumes its durations, then an END tick; the next
			# callback observes affineAnimEnded and restarts/destroys the sprite.
			if int(t.affine_age)>int(t.settings.source_affine_ticks):t.affine_ended=true
	_pose(t)

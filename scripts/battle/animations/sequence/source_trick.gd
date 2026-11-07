extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## switch.c literal bag rise/squash/orbit-table/depth/blink continuation.
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var actors: Array[BattleAnimationActor]=c.resolve("attacker")
	if actors.is_empty():return []
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;owner.add_child(node)
	var phase: int=(int(step.source_args[1])-32)&255 if c.contest else int(step.source_args[1])
	var t: Dictionary={"kind":"source_trick_bag","settings":step.duplicate(true),"owner":owner,"node":node,"original_actor":actors[0],"age":0,"ticks":4096,"stage":"rise","x":70 if c.contest else 120,"y":int(step.source_args[0]),"velocity":20,"phase":phase,"initial_phase":phase,"affine_age":0,"table_index":0,"table_counter":0,"blink_count":1,"update":advance}
	BattleSourcePriority.initialize(t,c,owner);_depth(t,c);_pose(t)
	return [t]
static func _depth(t: Dictionary,c: BattleAnimationContext) -> void:
	var priority: int=31 if int(t.phase)>0 and int(t.phase)<192 else 29
	t.source_oam_subpriority=priority
	t.node.z_index=BattleSourcePriority.relative_layer(t.original_actor,priority-BattleElectricContract.source_subpriority(t.original_actor,c),c,t.owner)
static func _pose(t: Dictionary) -> void:
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.frame_program,int(t.age)).frame
	var rect: Array=t.settings.frame_rects[str(int(frame.tile))];t.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3])
	t.node.position=Vector2(t.x,t.y)+Vector2(BattleSourceTrig.cosine(int(t.phase),60),BattleSourceTrig.sine(int(t.phase),20))
	var pose: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.source_squash_program,int(t.affine_age),true)
	t.node.scale=Vector2(256.0/pose.matrix.x,256.0/pose.matrix.y)
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	match str(t.stage):
		"rise":
			if int(t.y)>78:t.stage="affine"
			else:t.y=int(t.y)+int(int(t.velocity)/10);t.velocity=int(t.velocity)+3
		"affine":
			if BattleSourceCommandProgram.evaluate(t.settings.source_squash_program,int(t.affine_age),true).ended:t.stage="orbit"
		"orbit":
			var row: Array=t.settings.source_orbit_table[int(t.table_index)]
			if int(t.table_counter)==int(row[1]):
				if int(row[2])==127:t.stage="blink";t.blink_count=1
				t.table_counter=0;t.table_index=int(t.table_index)+1
			else:
				t.table_counter=int(t.table_counter)+1;t.phase=(int(t.phase)+int(row[0])*int(row[2]))&255
				if not c.contest:_depth(t,c)
		"blink":
			if int(t.blink_count)>20:t.ticks=int(t.age)
			t.node.visible=int(t.blink_count)%2==0;t.blink_count=int(t.blink_count)+1
	if str(t.stage)=="affine" and int(t.affine_age)<21:t.affine_age=int(t.affine_age)+1
	_pose(t)

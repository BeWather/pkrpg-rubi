extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## battle_anim_effects_3.c: distinct Block and Mean Look continuation machines.
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var attackers: Array[BattleAnimationActor]=c.resolve("attacker");var targets: Array[BattleAnimationActor]=c.resolve("target")
	if attackers.is_empty() or targets.is_empty():return []
	var mode: String=str(step.get("mode",""))
	if mode not in ["block","eye"] or str(step.get("source_callback",""))!=("sub_8131564" if mode=="block" else "sub_812C358"):return []
	var target: BattleAnimationActor=targets[0]
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;owner.add_child(node)
	var origin: Vector2=BattleElectricContract.source_anchor(target,c,"center")
	var t: Dictionary={"kind":"source_escape_mark","mode":mode,"settings":step.duplicate(true),"owner":owner,"node":node,"attacker":attackers[0],"target":target,"origin":origin,"age":0,"ticks":4096,"update":advance,"stage":0,"counter":0,"phase":0,"flickers":0,"eva":4,"eva_down":false,"affine_age":0,"affine_index":0,"affine_paused":false,"affine_ended":false,"callback_sounds":[],"shake_phase":0}
	node.position=origin;BattleSourcePriority.initialize(t,c,owner)
	if mode=="block":
		t.y_offset=-144 if target.side==0 else -96;node.position.y+=int(t.y_offset)
		node.z_index=BattleSourcePriority.relative_layer(target,-2 if target.side==0 else 2,c,owner)
	else:node.modulate.a=0.0
	_pose(t)
	return [t]
static func _sound(t: Dictionary,cue: String) -> void:
	t.callback_sounds.append(cue)
	t.owner._play_sound(str(t.settings.source_callback_sound_assets[cue]),"SOUND_PAN_TARGET")
static func _block(t: Dictionary) -> void:
	match int(t.stage):
		0:
			t.y_offset=int(t.y_offset)+10
			if int(t.y_offset)>=0:t.y_offset=0;t.stage=1;_sound(t,"SE_M_SKETCH")
		1,2:
			t.phase=int(t.phase)+(4 if int(t.stage)==1 else 6)
			t.y_offset=-(BattleSourceTrig.sine(int(t.phase),256)>>(3 if int(t.stage)==1 else 4))
			if int(t.phase)>127:
				if int(t.stage)==1:_sound(t,"SE_M_SKETCH")
				t.phase=0;t.y_offset=0;t.stage=int(t.stage)+1
		3:
			t.counter=int(t.counter)+1
			if int(t.counter)>8:_sound(t,"SE_M_LEER");t.counter=0;t.stage=4
		4:
			t.counter=int(t.counter)+1
			if int(t.counter)>8:
				t.counter=0;t.flickers=int(t.flickers)+1;t.node.visible=(int(t.flickers)&1)==0
				if int(t.flickers)==7:t.ticks=int(t.age)
	t.node.position=t.origin+Vector2(0,int(t.y_offset))
static func _eye(t: Dictionary) -> void:
	match int(t.stage):
		0:
			t.node.modulate.a=float(t.eva)/16.0;t.eva=int(t.eva)+(-1 if t.eva_down else 1)
			if int(t.eva) in [4,15]:t.eva_down=not t.eva_down
			var previous: int=int(t.counter);t.counter=previous+1
			if previous>70:
				t.node.modulate.a=1.0;t.affine_index=1;t.affine_age=0;t.counter=0;t.node.visible=false;t.affine_paused=true;t.stage=1
		1:
			var previous: int=int(t.counter);t.counter=previous+1
			if previous>9:
				t.node.visible=true;t.affine_paused=false
				if t.affine_ended:t.stage=2;t.counter=0
		2:
			var offsets: Array[Vector2]=[Vector2(1,0),Vector2(1,0),Vector2(-1,0),Vector2(-1,0),Vector2(0,1),Vector2(0,1),Vector2(0,-1),Vector2(0,-1)]
			t.node.position=t.origin+offsets[int(t.shake_phase)];t.shake_phase=(int(t.shake_phase)+1)&7
			var previous: int=int(t.counter);t.counter=previous+1
			if previous>15:t.eva=16;t.counter=0;t.node.modulate.a=1.0;t.stage=3
		3:
			t.node.modulate.a=clampf(float(t.eva)/16.0,0.0,1.0)
			var previous: int=int(t.counter);t.counter=previous+1
			if previous>1:t.eva=int(t.eva)-1;t.counter=0
			if int(t.eva)==0:t.node.visible=false
			if int(t.eva)<0:t.ticks=int(t.age)
	if not t.affine_paused:
		t.affine_age=int(t.affine_age)+1
		if int(t.affine_index)==1 and int(t.affine_age)>int(t.settings.source_affine_restart_ticks):t.affine_ended=true
static func _pose(t: Dictionary) -> void:
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.frame_program,int(t.age)).frame
	var rect: Array=t.settings.frame_rects[str(int(frame.tile))]
	t.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);t.node.flip_h=bool(frame.get("flip_h",false));t.node.flip_v=bool(frame.get("flip_v",false))
	if t.mode=="eye":
		var program: Array=t.settings.affine_program if int(t.affine_index)==0 else t.settings.source_affine_restart
		var pose: Dictionary=BattleSourceCommandProgram.evaluate(program,int(t.affine_age),true)
		t.node.scale=Vector2(256.0/float(pose.matrix.x),256.0/float(pose.matrix.y));t.node.rotation=-float(pose.rotation)*TAU/256.0
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if c.actors.get(t.attacker.id)!=t.attacker or c.actors.get(t.target.id)!=t.target or not t.attacker.is_present() or not t.target.is_present():t.ticks=int(t.age);return
	if t.mode=="block":_block(t)
	else:_eye(t)
	_pose(t)

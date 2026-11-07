extends RefCounted
class_name BattlePhaseScreenHit
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## H5 callback-local controllers. Held sprite offsets/rotations are execution-owned,
## not layout baseline writes; particles carry snapshot anchors and bound identity.
static func create(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Array[Dictionary]:
	if str(step.mode) in ["monbg","clear_monbg","alpha","blend_off","monbg_priority"]:
		var backgrounds: Array[Dictionary]=BattleCounterSelected.create(step,context,owner)
		if str(step.mode)=="monbg":
			for track: Dictionary in backgrounds:
				for clone: Dictionary in track.clones:BattleCounterSelected._blend_node(clone.node,owner)
		return backgrounds
	var actors: Array[BattleAnimationActor]=context.resolve(str(step.selector))
	if actors.is_empty():return []
	var actor: BattleAnimationActor=actors[0]
	var mode: String=str(step.mode)
	var attackers: Array[BattleAnimationActor]=context.resolve("attacker")
	var targets: Array[BattleAnimationActor]=context.resolve("target")
	if mode in ["fist_foot","flicker_impact"] and (attackers.is_empty() or targets.is_empty()):return []
	var a: Array=step.source_args.duplicate()
	var actor_mode: bool=mode in ["charge_translation","horizontal_lunge","skull_lunge","skull_recovery","source_tilt","windup_lunge","source_shake","source_shake_in_place"]
	var track: Dictionary={"kind":"source_phase_screen_actor" if actor_mode else "source_phase_screen_particle","actor_owner":actor,"owner":owner,"settings":step.duplicate(true),"age":0,"ticks":4096,"update":advance,"pose":{},"args":a,"state":0,"counter":0,"initial":owner.get_actor_offset(actor.id),"angle":0,"remaining":0,"wait":0}
	var direction: int=1 if actor.side==0 else -1
	if actor_mode:
		track.actor=actor
		track.pose={"offset":track.initial,"hold_offset":true}
		match mode:
			"charge_translation":
				var delta:=Vector2(int(a[1])*direction,int(a[2])*(direction if int(a[3])==1 else 1))
				track.remaining=int(a[4]);track.q8=Vector2(int(track.initial.x)<<8,int(track.initial.y)<<8)
				track.delta_q8=Vector2(int(delta.x)*256/int(a[4]),int(delta.y)*256/int(a[4]))
			"horizontal_lunge":track.remaining=int(a[0]);track.delta=int(a[1])*direction
			"skull_lunge":track.remaining=8;track.x=0;track.angle=0
			"skull_recovery":track.remaining=8;track.angle=-1536*direction;track.pose.erase("offset");_rotation(track)
			"source_tilt":
				track.remaining=int(a[0]);track.rotation_delta=int(a[1])*(-1 if actor.side==0 and not context.contest else 1)
				track.angle=int(a[0])*int(track.rotation_delta) if int(a[3])==1 else 0
				track.pivot=context.contest or actor.side==0;track.pose.erase("offset");_rotation(track)
			"windup_lunge":
				var source_side: int=context.actors[context.attacker_id].side
				var sign_x: int=1 if source_side==0 else -1
				track.remaining=int(a[3]);track.wait=int(a[4]);track.q8=0;track.second_q8=0;track.wave=0
				track.delta=int(a[1])*sign_x*256/int(a[3]);track.second_delta=int(a[5])*sign_x*256/int(a[6]);track.wave_delta=32768/int(a[3])
			"source_shake","source_shake_in_place":
				track.remaining=int(a[3]);track.wait=int(a[4]) if mode=="source_shake" else 0
				track.pose.offset=Vector2(a[1],a[2]) if mode=="source_shake" else track.initial+Vector2(a[1],a[2])
				_shake(track) # Both task initializers execute their callback immediately.
		return [track]
	var sprite:=Sprite2D.new();sprite.texture=load(str(step.texture));sprite.region_enabled=true;owner.add_child(sprite);track.node=sprite
	var origin: Vector2=owner.to_local(context.field.to_global(BattleElectricContract.source_anchor(actor,context,"origin" if mode in ["screen_wall","screen_fragment"] else "center")))
	match mode:
		"screen_wall":origin+=Vector2(a[1],a[2]);track.remaining=int(a[3]);track.shakes=int(a[4])
		"screen_fragment":
			if int(a[1]) not in [0,1,2,3]:sprite.queue_free();return []
			origin+=Vector2(a[2],a[3]);track.velocity=Vector2(-3 if int(a[1])%2==0 else 3,-3 if int(a[1])<2 else 3)
		"arm_hand":
			var parity: int=(context.move_turn+(1 if actor.side==0 else 0))&1
			origin+=Vector2(int(a[0])*(-1 if parity else 1),a[1]);track.frame_program=step.source_frame_variants[str(int(a[3])+parity)]
		"fist_foot","flicker_impact":
			# InitAnimSpritePos and sub_8078764 share the raw-origin comparison;
			# unequal aesthetic rectangle widths must not reverse the sign.
			origin+=Vector2(int(a[0])*BattleElectricContract.source_offset_direction(context,attackers[0],targets[0]),a[1])
	track.origin=origin;sprite.position=origin
	_frame(track,0)
	BattleSourcePriority.initialize(track,context,owner)
	# All these source templates use NORMAL OBJ OAM; the alpha pair belongs
	# to the selected monBG snapshot, not the opaque hand/fist/wall sprites.
	return [track]

static func _frame(track: Dictionary, age: int) -> void:
	var program: Array=track.get("frame_program",track.settings.frame_program)
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(program,age).frame
	var rect: Array=track.settings.frame_rects[str(int(frame.tile))]
	track.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);track.node.flip_h=bool(frame.get("flip_h",false));track.node.flip_v=bool(frame.get("flip_v",false))
	if not track.settings.get("affine_program",[]).is_empty():
		var affine: Dictionary=BattleSourceCommandProgram.evaluate(track.settings.affine_program,age,true)
		track.node.scale=Vector2(256.0/maxf(1,affine.matrix.x),256.0/maxf(1,affine.matrix.y));track.node.rotation=float(affine.rotation)*TAU/256

static func _rotation(track: Dictionary) -> void:
	track.pose.rotation=float(track.angle)*TAU/65536;track.pose.hold_rotation=true
	if bool(track.get("pivot",true)):
		track.pose.matrix_correction=Vector2(0,absi(BattleSourceTrig.sine((int(track.angle)&65535)>>8,256))>>3)

static func _shake(track: Dictionary) -> void:
	var a: Array=track.args
	if int(track.wait)>0:track.wait-=1;return
	if str(track.settings.mode)=="source_shake":
		track.pose.offset=Vector2(int(a[1]) if track.pose.offset.x==0 else 0,int(a[2]) if track.pose.offset.y==0 else 0)
		track.remaining-=1
		if int(track.remaining)==0:track.pose.offset=Vector2.ZERO;track.ticks=int(track.age)
	else:
		track.pose.offset+=Vector2(a[1],a[2])*(2 if int(track.counter)&1 else -2);track.counter+=1;track.remaining-=1
		if int(track.remaining)==0:
			track.pose.offset+=Vector2(a[1],a[2])*(1 if int(track.counter)&1 else -1);track.ticks=int(track.age)
	track.wait=int(a[4])

static func advance(track: Dictionary, context: BattleAnimationContext) -> void:
	var actor: BattleAnimationActor=track.actor_owner
	if not actor.is_present():
		if track.has("node"):track.node.visible=false
		track.ticks=int(track.age);return
	var a: Array=track.args;var age: int=int(track.age);var mode: String=str(track.settings.mode)
	var direction: int=1 if actor.side==0 else -1
	match mode:
		"charge_translation":
			if int(track.remaining)>0:
				track.remaining-=1;track.q8+=track.delta_q8;track.pose.offset=Vector2(int(track.q8.x)>>8,int(track.q8.y)>>8)
			elif int(track.state)==0:track.state=1 # Stored callback transfer is not invocation.
			else:
				if int(a[5])!=0:track.pose.offset=Vector2.ZERO
				track.ticks=age
		"horizontal_lunge":
			if int(track.remaining)>0:track.remaining-=1;track.pose.offset.x+=int(track.delta)
			elif int(track.state)==0:track.state=1
			elif int(track.state)==1:track.state=2;track.remaining=int(a[0]);track.delta=-int(track.delta)
			elif int(track.state)==2:track.state=3
			else:track.ticks=age
		"source_tilt":
			track.angle+=int(track.rotation_delta);track.remaining-=1;_rotation(track)
			if int(track.remaining)<=0:
				if int(a[3])==2:a[3]=1;track.remaining=int(a[0]);track.rotation_delta=-int(track.rotation_delta)
				else:
					if int(a[3])==1:track.angle=0;_rotation(track)
					track.ticks=age
		"skull_lunge":_skull(track,direction)
		"skull_recovery":
			if int(track.remaining)>0:track.remaining-=1;track.angle+=192*direction;_rotation(track)
			else:track.angle=0;_rotation(track);track.ticks=age
		"windup_lunge":
			if int(track.state)==0:
				track.q8+=int(track.delta);track.pose.offset=Vector2(int(track.q8)>>8,BattleSourceTrig.sine(int(track.wave)>>8,int(a[2])));track.wave+=int(track.wave_delta);track.remaining-=1
				if int(track.remaining)==0:track.state=1;track.remaining=int(a[6])
			elif int(track.wait)>0:track.wait-=1
			else:
				track.second_q8+=int(track.second_delta);track.pose.offset.x=(int(track.second_q8)>>8)+(int(track.q8)>>8);track.remaining-=1
				if int(track.remaining)==0:track.ticks=age
		"source_shake","source_shake_in_place":_shake(track)
		"screen_wall":
			if int(track.state)==0:
				track.remaining-=1
				if int(track.remaining)==0:
					if int(track.shakes)==0:track.ticks=age
					else:track.state=1
			else:
				track.wait+=1
				if int(track.wait)>1:track.wait=0;track.counter+=1;track.node.position.x=track.origin.x+(2 if int(track.counter)&1 else -2)
				track.shakes-=1
				if int(track.shakes)==0:track.ticks=age
		"screen_fragment":track.node.position+=track.velocity;if age>40:track.ticks=age
		"arm_hand":if age-1==int(a[2]):track.ticks=age
		"fist_foot":if age>int(a[2])+1:track.ticks=age
		"flicker_impact":track.node.visible=not track.node.visible;if age>13:track.ticks=age
	if track.has("node"):_frame(track,age)

static func _skull(track: Dictionary, direction: int) -> void:
	var age: int=int(track.age)
	match int(track.state):
		0:
			if int(track.remaining)>0:track.x-=3*direction;track.pose.offset=Vector2(track.x,0);track.remaining-=1
			else:track.state=1;track.remaining=8
		1:
			if int(track.remaining)>0:track.angle-=192*direction;_rotation(track);track.remaining-=1
			else:track.state=2;track.remaining=8;track.wait=1
		2:
			if int(track.remaining)>0:
				if int(track.wait)>0:track.wait-=1
				else:track.pose.offset.x=int(track.x)+(2*direction if int(track.remaining)&1 else -2*direction);track.remaining-=1;track.wait=1
			else:track.pose.offset.x=track.x;track.state=3;track.remaining=12
		3:
			if int(track.remaining)>0:track.remaining-=1
			else:track.state=4;track.remaining=3
		4:
			if int(track.remaining)>0:track.x+=8*direction;track.pose.offset.x=track.x;track.remaining-=1
			else:track.ticks=age

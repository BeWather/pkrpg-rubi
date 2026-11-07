extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Source snapshots, private parent/child storage and fixed-point motion ownership.
static func create(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Array[Dictionary]:
	var attackers: Array[BattleAnimationActor]=context.resolve("attacker")
	var targets: Array[BattleAnimationActor]=context.resolve("target")
	if attackers.is_empty() or targets.is_empty():return []
	var attacker: BattleAnimationActor=attackers[0]
	var target: BattleAnimationActor=targets[0]
	var a: Array=step.source_args.duplicate()
	var track: Dictionary={"kind":"source_wind_air_particle","settings":step.duplicate(true),"owner":owner,"age":0,"ticks":4096,"update":advance,"args":a,"attacker":attacker,"target":target,"state":0,"counter":0}
	if step.mode=="air_cutter":return _cutter_task(track,context)
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true
	owner.add_child(node);track.node=node
	BattleSourcePriority.initialize(track,context,owner)
	track.frame_seek=0
	match str(step.mode):
		"cyclone":
			track.origin=_anchor(attacker,context,owner,"origin")+Vector2(int(a[0])*BattleElectricContract.source_offset_direction(context,attacker,target),int(a[1])+(16 if attacker.side==0 else 0))
			track.phase=int(a[4]);track.remaining=int(a[6]);_cyclone(track)
		"air_wave":
			if attacker.side!=0:
				for i: int in range(4):a[i]=-int(a[i])
			if context.contest:a[1]=-int(a[1]);a[3]=-int(a[3])
			_store_args(track)
			track.origin=_anchor(attacker,context,owner,"center")+Vector2(a[0],a[1])
			track.destination=(_average(target,context,owner,"center","air_wave") if int(a[6])!=0 else _anchor(target,context,owner,"center"))+Vector2(a[2],a[3])
			track.remaining=int(a[4]);track.x_q8=0;track.y_q8=0
			track.delta_x=_delta(int(track.destination.x-track.origin.x),int(a[4]))
			track.delta_y=_delta(int(track.destination.y-track.origin.y),int(a[4]))
			# SeekSpriteAnim seeks a frame command, not another animation table.
			var seek: int=int(a[5])
			for i: int in range(seek):track.frame_seek+=maxi(1,int(step.frame_program[i].get("ticks",1)))
			node.position=track.origin
		"cut_slice":
			track.origin=(_average(target,context,owner,"origin","cut_slice") if int(a[3])==2 else _partner_anchor(target,context,owner,"origin") if int(a[3])==1 else _anchor(target,context,owner,"origin"))+Vector2(int(a[0])*(-1 if int(a[2])==1 else 1),int(a[1])+(8 if target.side==0 else 0))
			track.velocity_x=1024 if int(a[2])==1 else -1024;track.velocity_y=1024
			track.x_q8=0;track.y_q8=0;track.remaining=20;track.wait=3
			node.position=track.origin
	_frame(track,0)
	return [track]

static func _anchor(actor: BattleAnimationActor, context: BattleAnimationContext, owner: Node2D, mode: String) -> Vector2:
	return owner.to_local(context.field.to_global(BattleElectricContract.source_anchor(actor,context,mode)))
static func _partner(actor: BattleAnimationActor,context: BattleAnimationContext,require_visible: bool=true) -> BattleAnimationActor:
	var position: int=context.source_position(actor.id)^2
	for candidate: BattleAnimationActor in context.actors.values():
		if context.contest and candidate.id!=context.attacker_id:continue
		if context.source_position(candidate.id)==position and candidate.is_present() and (not require_visible or candidate.sprite.visible or (candidate._owned_hidden and candidate._base_visible)):return candidate
	return null
static func _partner_anchor(actor: BattleAnimationActor,context: BattleAnimationContext,owner: Node2D,mode: String) -> Vector2:
	var partner: BattleAnimationActor=_partner(actor,context)
	return _anchor(partner,context,owner,mode) if partner!=null else _anchor(actor,context,owner,mode)
static func _average(actor: BattleAnimationActor,context: BattleAnimationContext,owner: Node2D,mode: String,policy: String) -> Vector2:
	# Ruby coordinate getters return s16; divide in source/field space BEFORE
	# transforming to the effect owner's potentially fractional local space.
	var point: Vector2=BattleElectricContract.source_anchor(actor,context,mode)
	var x: int=int(point.x)
	var y: int=int(point.y)
	var partner: BattleAnimationActor=null
	if policy=="cut_slice":partner=_partner(actor,context)
	elif _is_double(context) and not context.contest:partner=_partner(actor,context,policy!="air_wave")
	if partner!=null:
		var other: Vector2=BattleElectricContract.source_anchor(partner,context,mode)
		x=(x+int(other.x))/2
		y=(y+int(other.y))/2
	return owner.to_local(context.field.to_global(Vector2(x,y)))
static func _is_double(context: BattleAnimationContext) -> bool:
	if context.has_meta("source_double_battle"):return bool(context.get_meta("source_double_battle"))
	# Actual native provider includes only visible occupied slots. In a lab,
	# explicit source positions supply the same semantic right-bank evidence.
	for actor: BattleAnimationActor in context.actors.values():
		if actor.is_present() and context.source_position(actor.id) in [2,3]:return true
	return false
static func _store_args(track: Dictionary) -> void:
	for i: int in range(track.args.size()):track.owner._source_args[i]=int(track.args[i])&65535
static func _delta(distance: int,duration: int) -> int:
	var value: int=(absi(distance)<<8)/maxi(1,duration)
	return value|1 if distance<0 else value&~1
static func _signed(value: int) -> int:
	return ((value+32768)&65535)-32768
static func _multiply(left: int,right: int) -> int:
	return _signed(int(float(_signed(left)*_signed(right))/256.0))
static func _reciprocal(value: int) -> int:
	return _signed(65536/value) if value!=0 else 0
static func _frame(track: Dictionary,age: int) -> void:
	var selected: Dictionary=BattleSourceCommandProgram.evaluate(track.settings.frame_program,maxi(0,age)+int(track.frame_seek)).frame
	var rect: Array=track.settings.frame_rects[str(int(selected.tile))]
	track.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3])
	track.node.flip_h=bool(selected.get("flip_h",false));track.node.flip_v=bool(selected.get("flip_v",false))
	if track.settings.mode=="cut_slice":track.node.flip_h=int(track.args[2])==1
	if not track.settings.get("affine_program",[]).is_empty():
		var affine: Dictionary=BattleSourceCommandProgram.evaluate(track.settings.affine_program,maxi(0,age),true)
		track.node.scale=Vector2(256.0/maxf(1,affine.matrix.x),256.0/maxf(1,affine.matrix.y))
		track.node.rotation=float(affine.rotation)*TAU/256
static func _cyclone(track: Dictionary) -> void:
	if int(track.remaining)>0:
		track.node.position=track.origin+Vector2(BattleSourceTrig.sine(int(track.phase),int(track.args[2])),BattleSourceTrig.cosine(int(track.phase),int(track.args[2])))
		track.phase=(int(track.phase)+int(track.args[5]))&255;track.remaining-=1
	elif int(track.state)==0:track.state=1
	else:track.ticks=int(track.age)
static func advance(track: Dictionary,context: BattleAnimationContext) -> void:
	if not track.attacker.is_present() or not track.target.is_present():
		if track.has("node"):track.node.visible=false
		if track.has("children"):_children_cleanup(track)
		track.ticks=int(track.age);return
	if str(track.settings.mode)=="air_cutter":_cutter_advance(track,context);return
	_frame(track,maxi(0,int(track.age)-1))
	match str(track.settings.mode):
		"cyclone":_cyclone(track)
		"air_wave":
			if int(track.remaining)>0:
				track.x_q8=(int(track.x_q8)+int(track.delta_x))&65535
				track.y_q8=(int(track.y_q8)+int(track.delta_y))&65535
				track.node.position=track.origin+Vector2((int(track.x_q8)>>8)*(-1 if int(track.delta_x)&1 else 1),(int(track.y_q8)>>8)*(-1 if int(track.delta_y)&1 else 1))
				track.remaining-=1
			elif int(track.state)==0:track.state=1
			else:track.ticks=int(track.age)
		"cut_slice":
			if int(track.remaining)>0:
				track.x_q8=_signed(int(track.x_q8)+int(track.velocity_x));track.y_q8=_signed(int(track.y_q8)+int(track.velocity_y))
				track.velocity_x+=-24 if int(track.args[2])==1 else 24;track.velocity_y-=24
				track.node.position=track.origin+Vector2(int(track.x_q8)>>8,int(track.y_q8)>>8);track.remaining-=1
			elif int(track.wait)>0:track.wait-=1
			elif int(track.state)==0:track.state=1
			else:track.ticks=int(track.age)

static func _cutter_task(track: Dictionary,context: BattleAnimationContext) -> Array[Dictionary]:
	var a: Array=track.args
	track.kind="source_wind_air_task";track.children=[];track.spawned=0;track.spawn_wait=0
	track.flips=Vector2.ZERO
	if context.contest:a[0]=-int(a[0]);a[2]=int(a[2])^1;track.flips=Vector2(1,0)
	elif track.target.side==0:a[0]=-int(a[0]);a[1]=-int(a[1]);a[2]=int(a[2])^1;track.flips=Vector2(1,1)
	track.origin=_anchor(track.attacker,context,track.owner,"origin")
	track.destination=_average(track.target,context,track.owner,"origin","air_cutter")+Vector2(a[0],a[1])
	track.travel=_multiply(absi(int(track.destination.x-track.origin.x)),_reciprocal(int(a[2])&~1))
	if int(track.travel)<=0:return [] # Source reciprocal0 undefined; do not invent a trajectory.
	track.half=_multiply(int(track.travel),128);track.velocity_x=int(a[2])
	track.velocity_y=(_multiply(absi(int(track.destination.y-track.origin.y)),_reciprocal(int(track.travel)))&~1)|(1 if track.destination.y<track.origin.y else 0)
	var priority: int=int(a[4])&127
	a[4]=priority
	var base: int=BattleElectricContract.source_subpriority(track.target,context)
	track.source_oam_subpriority=maxi(3,base+(priority-64 if priority>=64 else -priority))
	track.depth_delta=int(track.source_oam_subpriority)-base
	_store_args(track)
	track.cleanup=_children_cleanup.bind(track)
	return [track]
static func _children_cleanup(track: Dictionary) -> void:
	track.erase("cleanup")
	for child: Dictionary in track.children:
		if is_instance_valid(child.node):child.node.queue_free()
	track.children.clear()
static func _cutter_advance(track: Dictionary,context: BattleAnimationContext) -> void:
	# Tasks run before sprite callbacks. The drain task sees the last child
	# decrement on its NEXT invocation, not inside that child's delete callback.
	if int(track.spawned)==3 and track.children.is_empty():track.ticks=int(track.age);return
	if int(track.spawned)<3:
		var previous: int=int(track.spawn_wait);track.spawn_wait-=1
		if previous<=0:
			var settings: Dictionary=track.settings.source_child_binding.duplicate(true)
			var node:=Sprite2D.new();node.texture=load(str(settings.texture));node.region_enabled=true
			var rect: Array=settings.frame_rects["0"];node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3])
			track.owner.add_child(node);node.position=track.origin;node.flip_h=bool(track.flips.x);node.flip_v=bool(track.flips.y)
			node.z_index=BattleSourcePriority.relative_layer(track.target,int(track.depth_delta)-int(track.spawned),context,track.owner)
			var child: Dictionary={"settings":settings,"node":node,"origin":track.origin,"remaining":int(track.travel)-int(track.half),"state":0,"x_q8":0,"y_q8":0,"speed_x":0,"speed_y":0,"age":0}
			track.children.append(child);track.spawned+=1;track.spawn_wait=int(track.args[3])
			track.owner._play_sound("res://"+str(track.settings.source_child_sound_path),"",float(BattleCounterSelected.adjust_panning(-63,context))/64.0,true)
	for child: Dictionary in track.children.duplicate():
		child.age+=1
		if int(child.state)==2:
			var previous: int=int(child.remaining);child.remaining-=1
			if previous<=0:child.node.queue_free();track.children.erase(child)
			continue
		if int(child.state)==0:
			child.x_q8=_signed(int(child.x_q8)+(int(track.velocity_x)&~1));child.y_q8=_signed(int(child.y_q8)+(int(track.velocity_y)&~1))
		else:
			var sign: int=1 if int(child.remaining)>int(track.travel) else -1
			child.speed_x=_signed(int(child.speed_x)+int(child.accel_x)*sign);child.speed_y=_signed(int(child.speed_y)+int(child.accel_y)*sign)
			child.x_q8=_signed(int(child.x_q8)+int(child.speed_x));child.y_q8=_signed(int(child.y_q8)+int(child.speed_y))
		child.node.position=child.origin+Vector2(((int(child.x_q8)&65535)>>8)*(-1 if int(track.velocity_x)&1 else 1),((int(child.y_q8)&65535)>>8)*(-1 if int(track.velocity_y)&1 else 1))
		var previous: int=int(child.remaining);child.remaining-=1
		if previous<=0:
			if int(child.state)==0:
				child.state=1;child.remaining=8;track.travel=4
				child.origin=child.node.position;child.x_q8=0;child.y_q8=0
				child.accel_x=_multiply(_multiply(absi(int(track.destination.x-child.origin.x))<<8,_reciprocal(4096)),_reciprocal(448))
				child.accel_y=_multiply(_multiply(absi(int(track.destination.y-child.origin.y))<<8,_reciprocal(4096)),_reciprocal(448))
			else:child.state=2;child.remaining=30

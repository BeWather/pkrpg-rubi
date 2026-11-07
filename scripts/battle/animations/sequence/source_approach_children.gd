extends RefCounted
class_name BattleApproachChildren
## Source-owned approach controllers and independently draining private sprites.
## Geometry uses the bound aesthetic actor; source frame/affine programs remain data.
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

static func create(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Array[Dictionary]:
	var selected: Array[BattleAnimationActor]=context.resolve(str(step.selector))
	if selected.is_empty():return []
	var actor: BattleAnimationActor=selected[0]
	var mode: String=str(step.mode)
	var container:=Node2D.new();owner.add_child(container)
	var track: Dictionary={"kind":"source_approach_actor" if mode in ["thrash_position","thrash_affine","drill_lunge"] else "source_approach_children","actor_owner":actor,"age":0,"ticks":int(step.ticks),"node":container,"owner":owner,"settings":step.duplicate(true),"pose":{},"children":[],"spawned":[],"source_task_finished":false,"visited_frames":[],"initial_offset":owner.get_actor_offset(actor.id),"initial_rotation":float(owner._held_rotations.get(actor.id,0.0)),"update":advance}
	if track.kind=="source_approach_actor":track.actor=actor
	if mode=="thrash_position":track.ticks=84;track.pose={"offset":Vector2.ZERO}
	elif mode=="thrash_affine":
		track.pose={"offset":Vector2.ZERO,"scale":Vector2.ONE}
		track.base_feet=actor.sprite.get_rect().end.y*actor.sprite.scale.y
		track.affine_pc=0;track.affine_frame_age=0;track.affine_loop=0;track.affine_matrix=Vector2(256,256)
	elif mode=="drill_lunge":
		var phase: int=int(step.source_args[0])
		track.ticks=13 if phase==0 else 7 if phase==1 else 13 if phase==2 else 1
		track.pose={"offset":track.initial_offset,"rotation":track.initial_rotation,"hold_offset":true,"hold_rotation":true}
	elif mode=="thrash_hit":
		var rng:=RandomNumberGenerator.new();rng.seed=context.seed_value+int(step.get("source_line",0))+owner.elapsed_ticks
		var dimensions: Vector2=actor.sprite.get_rect().size
		var x: int=rng.randi()%maxi(1,int(dimensions.x)/2)
		var y: int=rng.randi()%maxi(1,int(dimensions.y)/4)
		var origin: Vector2=actor.anchor(owner)+Vector2(x*(1 if rng.randi()&1 else -1),y*(1 if rng.randi()&1 else -1))
		if context.source_position(actor.id) in [BattleAnimationContext.SourcePosition.PLAYER_LEFT,BattleAnimationContext.SourcePosition.PLAYER_RIGHT]:origin.y-=16
		var fist: Dictionary=_sprite(track,step.fist,origin,int(step.ticks),false)
		# Command metadata belongs to the root priority, not its selected frame program.
		var priority_track: Dictionary={"node":fist.node,"settings":step}
		BattleSourcePriority.initialize(priority_track,context,owner)
		var hit: Dictionary=_sprite(track,step.child,origin,int(step.ticks),false)
		hit.node.z_index=maxi(BattleSourcePriority.effective_layer(context.field)-BattleSourcePriority.effective_layer(owner),fist.node.z_index-1)
		track.root=fist.node
	elif mode=="drill_children":
		# ScriptCmd_createvisualtask calls its initializer immediately. This
		# initializer is also the emitter callback, so angle0 exists at creation.
		advance(track,context)
	elif mode=="leaf_path":
		var center: Vector2=actor.anchor(owner)
		center=Vector2(int(center.x),int(center.y))
		var dimensions: Vector2=actor.sprite.get_rect().size
		var side: int=1 if actor.side==1 else -1
		var start_y: float=56-side*64
		var start:=Vector2(center.y-start_y+center.x,start_y)
		var extents:=Vector2(int(dimensions.x)/2+10,int(dimensions.y)/2+10)*side
		track.endpoints=[start,center+Vector2(-extents.x,extents.y),center,center-extents,center+extents,center,center+Vector2(-extents.x,extents.y),start]
		var root: Dictionary=_sprite(track,step.child,start,4096,false)
		track.children.erase(root);track.spawned.erase(root)
		track.root=root.node;track.root_settings=step.child;track.segment=0;track.segment_age=0;track.hold=0
		_leaf_frame(track,context)
		_leaf_begin(track,track.endpoints[1])
	return [track]

static func _sprite(track: Dictionary, settings: Dictionary, origin: Vector2, lifetime: int, flicker: bool, parity: int=0) -> Dictionary:
	var sprite:=Sprite2D.new();sprite.texture=load(str(settings.texture));sprite.region_enabled=true;sprite.position=origin
	track.node.add_child(sprite)
	var child: Dictionary={"node":sprite,"settings":settings.duplicate(true),"born":int(track.age),"lifetime":lifetime,"flicker":flicker,"parity":parity,"flips":0,"counter":parity}
	_frame(sprite,settings,settings.frame_program,0)
	track.children.append(child);track.spawned.append(child)
	return child

static func _frame(sprite: Sprite2D, settings: Dictionary, program: Array, age: int) -> void:
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(program,age).frame
	var rect: Array=settings.frame_rects[str(int(frame.tile))]
	sprite.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3])
	sprite.flip_h=bool(frame.get("flip_h",false));sprite.flip_v=bool(frame.get("flip_v",false))
	if not settings.get("affine_program",[]).is_empty():
		var affine: Dictionary=BattleSourceCommandProgram.evaluate(settings.affine_program,age,true)
		sprite.scale=Vector2(256.0/maxf(1,affine.matrix.x),256.0/maxf(1,affine.matrix.y))
		sprite.rotation=float(affine.rotation)*TAU/256

static func _leaf_frame(track: Dictionary, context: BattleAnimationContext) -> void:
	var segment: int=int(track.segment)
	_frame(track.root,track.root_settings,track.settings.frame_programs[segment],0)
	track.root.z_index=BattleSourcePriority.relative_layer(track.actor_owner,int(track.settings.depth_deltas[segment]),context,track.owner)
	track.visited_frames.append(segment)

static func advance(track: Dictionary, context: BattleAnimationContext) -> void:
	var actor: BattleAnimationActor=track.actor_owner
	if not actor.is_present():
		track.node.visible=false;track.ticks=int(track.age);return
	var age: int=int(track.age)
	var settings: Dictionary=track.settings
	var mode: String=str(settings.mode)
	var direction: int=1 if actor.side==0 else -1
	if mode=="thrash_position":
		var n: int=mini(age,84)%28
		var x: int=n*4 if n<=7 else 28-(n-7)*4 if n<=21 else -28+(n-21)*4
		track.pose={"offset":Vector2(x*direction,2 if (mini(age,84)/3)%2 else 0)}
		if age>=84:track.pose.offset=Vector2.ZERO
	elif mode=="thrash_affine":
		var ended: bool=_task_affine_tick(track)
		var scale:=Vector2(256.0/maxf(1,track.affine_matrix.x),256.0/maxf(1,track.affine_matrix.y))
		track.pose={"scale":scale,"offset":Vector2(0,float(track.base_feet)*(1-scale.y))}
		if ended:track.pose={"scale":Vector2.ONE,"offset":Vector2.ZERO};track.ticks=age
	elif mode=="drill_lunge":
		var phase: int=int(settings.source_args[0])
		var offset: Vector2=track.initial_offset
		var angle: float=float(track.initial_rotation)
		if phase==0:
			offset.x-=mini(maxi(0,age-1),6)*2*direction
			angle=-mini(maxi(0,age-8),4)*768*direction*TAU/65536
		elif phase==1:offset.x+=mini(maxi(0,age-1),4)*3*direction
		elif phase==2:angle=-maxi(0,3072-mini(maxi(0,age-9),3)*1024)*direction*TAU/65536
		track.pose={"offset":offset,"rotation":angle,"hold_offset":true,"hold_rotation":true}
		if phase in [0,2]:
			# sub_8078F9C writes y2 from the rotation matrix, independently of
			# actor height. Hold that owned correction after controller deletion;
			# phase1 translates x only, and phase2 restores matrix/y2 to zero.
			var rotation_units: int=int(round(angle*65536.0/TAU))
			var matrix_c: int=BattleSourceTrig.sine((rotation_units&65535)>>8,256)
			track.pose.matrix_correction=Vector2(0,absi(matrix_c)>>3)
	elif mode=="drill_children":
		if age%int(settings.spawn_interval)==0 and track.spawned.size()<8:
			var angle: int=int(settings.spawn_angles[track.spawned.size()])
			var args: Array=[BattleSourceTrig.sine(angle,int(settings.radius)),BattleSourceTrig.sine(angle+64,int(settings.radius)),1,3]
			var child_settings: Dictionary=settings.child.duplicate(true);child_settings.source_args=args
			var origin: Vector2=actor.anchor(track.owner)+Vector2(float(args[0])*BattleSoundOwnership.origin_offset_direction(context),float(args[1]))
			var child: Dictionary=_sprite(track,child_settings,origin,14,true)
			child.node.z_index=BattleSourcePriority.actor_layer(actor,track.owner)+1
			child.source_absolute_subpriority=3
		if age>=31:track.source_task_finished=true
	elif mode=="leaf_path":_leaf_advance(track,context)
	for child: Dictionary in track.children.duplicate():
		var elapsed: int=age-int(child.born)
		if mode=="leaf_path":
			child.counter+=1
			if int(child.counter)>1:
				child.counter=0;child.flips+=1;child.node.visible=not child.node.visible
			if int(child.flips)>=9:child.node.queue_free();track.children.erase(child)
		else:
			_frame(child.node,child.settings,child.settings.frame_program,elapsed)
			if child.flicker:child.node.visible=elapsed%2==0
			if elapsed>=int(child.lifetime):child.node.queue_free();track.children.erase(child)
	if bool(track.source_task_finished) and track.children.is_empty():track.ticks=age

static func _task_affine_tick(track: Dictionary) -> bool:
	# RunAffineAnimFromTaskData processes ONE command per callback. LOOP/END
	# are real callbacks, not instructions consumed inside a frame sample.
	var command: Dictionary=track.settings.affine_program[int(track.affine_pc)]
	match str(command.op):
		"frame":
			track.affine_matrix+=Vector2(command.x,command.y)
			track.affine_frame_age+=1
			if int(track.affine_frame_age)>=int(command.ticks):track.affine_frame_age=0;track.affine_pc+=1
		"loop":
			if int(track.affine_loop)==0:track.affine_loop=int(command.count)
			else:track.affine_loop-=1
			if int(track.affine_loop)==0:track.affine_pc+=1
			else:
				track.affine_pc=0
		"end":return true
	return false

static func _leaf_begin(track: Dictionary, destination: Vector2) -> void:
	# InitAnimLinearTranslation encodes sign in bit0 of unsigned Q8 deltas.
	# Next segments start at attained primary+secondary coordinates, not the
	# ideal destination (terminal TranslateAnimLinear returns before moving).
	track.arc_start=track.root.position
	var difference: Vector2=destination-track.arc_start
	var deltas: Array[int]=[]
	for value: float in [difference.x,difference.y]:
		var delta: int=((absi(int(value))<<8)&65535)/int(track.settings.segment_ticks)
		deltas.append((delta|1) if value<0 else (delta&~1))
	track.arc_deltas=deltas;track.arc_accumulators=[0,0];track.arc_phase=0
	track.arc_amplitude=-8 if destination.y<track.root.position.y else 8
	track.segment_age=0

static func _leaf_advance(track: Dictionary, context: BattleAnimationContext) -> void:
	if bool(track.source_task_finished):return
	if int(track.hold)>0:
		track.hold-=1
		return
	if bool(track.get("setup_pending",false)):
		track.setup_pending=false;track.segment+=1;_leaf_frame(track,context)
		_leaf_begin(track,track.endpoints[int(track.segment)+1])
		return
	var segment: int=int(track.segment)
	var settings: Dictionary=track.settings
	var trail_settings: Dictionary=settings.child.duplicate(true);trail_settings.frame_program=settings.frame_programs[segment]
	var trail: Dictionary=_sprite(track,trail_settings,track.root.position,18,true,track.spawned.size()%2)
	trail.node.z_index=track.root.z_index
	var ticks: int=int(settings.segment_ticks)
	if int(track.segment_age)>=ticks:
		if segment==6:track.root.visible=false;track.source_task_finished=true
		else:track.hold=int(settings.hold_ticks);track.setup_pending=true
		return
	track.segment_age+=1
	var offset:=Vector2.ZERO
	for axis in 2:
		track.arc_accumulators[axis]=(int(track.arc_accumulators[axis])+int(track.arc_deltas[axis]))&65535
		offset[axis]=(int(track.arc_accumulators[axis])>>8)*(-1 if int(track.arc_deltas[axis])&1 else 1)
	track.arc_phase+=32768/ticks
	offset.y+=BattleSourceTrig.sine(int(track.arc_phase)>>8,int(track.arc_amplitude))
	track.root.position=track.arc_start+offset

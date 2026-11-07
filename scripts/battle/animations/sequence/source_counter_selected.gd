extends RefCounted
class_name BattleCounterSelected
## Accepted context inputs write execution-local VM args, not gameplay counters.
## Source task destroys itself synchronously; no actor, particle or barrier owner.
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

static func create(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Array[Dictionary]:
	var mode: String=str(step.mode)
	if mode in ["monbg","clear_monbg","alpha","blend_off","monbg_priority"]:return _command_create(step,context,owner)
	if mode=="rollout_actor":return _roll_create(step,context,owner)
	if mode in ["fury_slice","ice_ball","ice_scatter","frustration_anger","frustration_ballistic"]:return _particle_create(step,context,owner)
	if mode in ["return_clones","frustration_affine"]:return _owned_create(step,context,owner)
	var index: int=7
	var value: int=0
	match mode:
		"return_band":
			var friendship: int=clampi(int(context.get_meta("source_friendship",0)),0,255)
			# Source has separate strict comparisons: exactly60 retains default0.
			if friendship>60 and friendship<92:value=1
			elif friendship>91 and friendship<201:value=2
			elif friendship>200:value=3
		"frustration_band":
			var friendship: int=clampi(int(context.get_meta("source_friendship",0)),0,255)
			value=0 if friendship<=30 else 1 if friendship<=100 else 2 if friendship<=200 else 3
		"fury_direction":value=int(context.get_meta("source_fury_count",0))&1
		"fury_count":value=int(context.get_meta("source_fury_count",0))
		"ice_count":
			index=int(step.source_args[0]);value=int(context.get_meta("source_roll_count",1))-1
		_:return []
	owner._source_args[index]=value&65535
	return []

static func _command_create(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Array[Dictionary]:
	var mode: String=str(step.mode)
	if mode=="monbg_priority":
		var selected: Array[BattleAnimationActor]=context.resolve("target" if int(step.source_args[0])!=0 else "attacker")
		if context.contest:return []
		if not bool(step.get("source_force_priority",false)) and (selected.is_empty() or context.source_position(selected[0].id) not in [0,3]):return []
		for track: Dictionary in owner.get_meta("source_counter_monbg",[]):
			for clone: Dictionary in track.clones:
				# BG1 priority1 precedes BG2 priority2. Project within the owned
				# native sprite band, never below the opaque field.
				if int(clone.bg_plane)==1:clone.node.z_index=int(clone.base_z)+1
		return []
	if mode in ["alpha","blend_off"]:
		var pair: Array=step.get("blend_pair",[16,0])
		owner.set_meta("source_counter_alpha",pair.duplicate())
		for item: Dictionary in owner.get_meta("source_counter_blend_nodes",[]):
			if is_instance_valid(item.node) and item.node.material==item.material:
				if mode=="blend_off":item.node.material=null
				else:
					item.material.set_shader_parameter("eva",float(pair[0])/16)
					item.material.set_shader_parameter("evb",float(pair[1])/16)
		return []
	if mode=="clear_monbg":
		for track: Dictionary in owner.get_meta("source_counter_monbg",[]):
			for clone: Dictionary in track.clones:
				clone.actor.apply_source_state("hidden",false)
			track.ticks=int(track.age)+2
		return []
	var role: int=int(step.source_args[0])
	var selected: Array[BattleAnimationActor]=context.resolve("attacker" if role in [0,2] else "target")
	if selected.is_empty():return []
	var actors: Array[BattleAnimationActor]=[selected[0]]
	var partner_position: int=context.source_position(selected[0].id)^2
	if context.source_position(selected[0].id)>=0:
		for candidate: BattleAnimationActor in context.actors.values():
			if candidate.id!=selected[0].id and context.source_position(candidate.id)==partner_position:actors.append(candidate)
	var track: Dictionary={"kind":"source_counter_monbg","domain":"maintenance","owner":owner,"age":0,"ticks":4096,"clones":[],"update":_bg_update}
	for actor: BattleAnimationActor in actors:
		if not actor.is_present() or not actor.sprite.is_visible_in_tree() or (context.contest and actor.id!=context.attacker_id):continue
		var node: Sprite2D=BattleIdentityCopy.clone_sprite(actor,owner);owner.add_child(node)
		node.z_index=BattleSourcePriority.relative_layer(actor,1,context,owner)
		node.modulate=actor.sprite.modulate
		track.clones.append({"actor":actor,"node":node,"base_z":node.z_index,"bg_plane":1 if context.contest or context.source_position(actor.id) in [1,2] else 2})
		actor.apply_source_state("hidden",true)
	if track.clones.is_empty():return []
	track.cleanup=_bg_cleanup.bind(track)
	var backgrounds: Array=owner.get_meta("source_counter_monbg",[]);backgrounds.append(track);owner.set_meta("source_counter_monbg",backgrounds)
	return [track]

static func _bg_update(track: Dictionary, _context: BattleAnimationContext) -> void:
	for clone: Dictionary in track.clones:
		var actor: BattleAnimationActor=clone.actor
		if not actor.is_present():clone.node.visible=false;continue
		var node: Sprite2D=clone.node;var source: Sprite2D=actor.sprite
		node.position=actor.anchor(track.owner,"origin");node.scale=source.global_scale/track.owner.global_scale
		node.rotation=source.global_rotation-track.owner.global_rotation;node.modulate=source.modulate
		node.frame=source.frame;node.region_rect=source.region_rect;node.flip_h=source.flip_h;node.flip_v=source.flip_v

static func _bg_cleanup(track: Dictionary) -> void:
	track.erase("cleanup") # Break the self-bound Dictionary/Callable cycle.
	for clone: Dictionary in track.clones:
		clone.actor.apply_source_state("hidden",false)
		if is_instance_valid(clone.node):clone.node.queue_free()
	track.clones.clear()

static func _blend_node(node: Sprite2D, owner: Node2D) -> void:
	var pair: Array=owner.get_meta("source_counter_alpha",[16,0])
	var material: ShaderMaterial=BattleIdentityCopy.blend_material(false)
	material.set_shader_parameter("eva",float(pair[0])/16);material.set_shader_parameter("evb",float(pair[1])/16);node.material=material
	var nodes: Array=owner.get_meta("source_counter_blend_nodes",[]);nodes.append({"node":node,"material":material});owner.set_meta("source_counter_blend_nodes",nodes)

static func _owned_create(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Array[Dictionary]:
	var actors: Array[BattleAnimationActor]=context.resolve(str(step.selector))
	if actors.is_empty():return []
	var actor: BattleAnimationActor=actors[0]
	var track: Dictionary={"kind":"source_counter_actor" if str(step.mode)=="frustration_affine" else "source_counter_children","actor_owner":actor,"owner":owner,"settings":step.duplicate(true),"age":0,"ticks":4096,"children":[],"update":advance_owned,"pose":{},"wait":0,"state":0,"feet":actor.sprite.get_rect().end.y*actor.sprite.scale.y}
	if str(step.mode)=="frustration_affine":track.actor=actor;track.pose={"scale":Vector2.ONE,"offset":Vector2.ZERO}
	else:track.remaining=int(step.source_args[3]);track.cleanup=_roll_cleanup.bind(track)
	return [track]

static func advance_owned(track: Dictionary, context: BattleAnimationContext) -> void:
	var actor: BattleAnimationActor=track.actor_owner
	if not actor.is_present():
		_roll_cleanup(track);track.ticks=int(track.age);return
	if str(track.settings.mode)=="frustration_affine":
		var affine: Dictionary=BattleSourceCommandProgram.evaluate(track.settings.affine_program,int(track.age),true)
		var scale:=Vector2(256.0/maxf(1,affine.matrix.x),256.0/maxf(1,affine.matrix.y))
		track.pose={"scale":scale,"offset":Vector2(0,float(track.feet)*(1-scale.y))}
		if affine.ended:track.pose={"scale":Vector2.ONE,"offset":Vector2.ZERO};track.ticks=int(track.age)
		return
	for child: Dictionary in track.children.duplicate():
		if int(child.left)>0:child.left-=1
		else:child.node.queue_free();track.children.erase(child)
	if int(track.remaining)>0:
		if int(track.wait)>0:track.wait-=1
		else:
			var node: Sprite2D=BattleIdentityCopy.clone_sprite(actor,track.owner)
			track.owner.add_child(node)
			# Source duplicate OBJ_BLEND: own material, selected texture unchanged.
			_blend_node(node,track.owner)
			node.z_index=BattleSourcePriority.relative_layer(actor,1,context,track.owner)
			track.children.append({"node":node,"left":int(track.settings.source_args[2])})
			track.remaining-=1;track.wait=int(track.settings.source_args[1])
	elif track.children.is_empty():track.ticks=int(track.age)

static func _particle_create(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Array[Dictionary]:
	var attackers: Array[BattleAnimationActor]=context.resolve("attacker")
	var targets: Array[BattleAnimationActor]=context.resolve("target")
	if attackers.is_empty() or targets.is_empty():return []
	var attacker: BattleAnimationActor=attackers[0];var target: BattleAnimationActor=targets[0]
	var mode: String=str(step.mode);var args: Array=step.source_args
	var node:=Sprite2D.new();owner.add_child(node);node.texture=load(str(step.texture));node.region_enabled=true
	var track: Dictionary={"kind":"source_counter_particle","settings":step.duplicate(true),"source_callback":str(step.source_callback),"owner":owner,"actor_owner":attacker,"target_owner":target,"node":node,"age":0,"ticks":4096,"origin":Vector2.ZERO,"state":0,"frame_age":0,"update":advance_particle}
	BattleSourcePriority.initialize(track,context,owner)
	var side: int=1 if attacker.side==0 else -1
	if mode=="fury_slice":
		track.origin=owner.to_local(context.field.to_global(BattleElectricContract.source_anchor(target,context,"origin")))+Vector2(int(args[0])*(1 if int(args[2])==0 else -1),int(args[1])+(8 if target.side==0 else 0))
		track.velocity=Vector2(-1024 if int(args[2])==0 else 1024,1024);track.accumulator=Vector2.ZERO;track.ticks=25
		_blend_node(node,owner)
	elif mode=="ice_ball":
		var count: int=clampi(int(context.get_meta("source_roll_count",1))-1,0,4)
		track.settings.affine_program=step.count_affine_programs[str(count)]
		track.origin=owner.to_local(context.field.to_global(BattleElectricContract.source_anchor(attacker,context)))+Vector2(int(args[0])*BattleSoundOwnership.origin_offset_direction(context),int(args[1]))
		track.destination=owner.to_local(context.field.to_global(BattleElectricContract.source_anchor(target,context)))+Vector2(int(args[2])*side,int(args[3]))
		track.settings.travel_ticks=int(args[4]);track.settings.arc=int(args[5])
	elif mode=="ice_scatter":
		track.origin=owner.to_local(context.field.to_global(BattleElectricContract.source_anchor(target,context)))+Vector2(int(args[0])*BattleSoundOwnership.origin_offset_direction(context),int(args[1]))
		var rng:=RandomNumberGenerator.new();rng.seed=context.seed_value+owner.elapsed_ticks+int(step.get("source_line",0))+owner.get_child_count()
		var a: int=(rng.randi()&255)+256;var b: int=rng.randi()&511
		if b>255:b=256-b
		track.velocity=Vector2(a,b);track.accumulator=Vector2.ZERO;track.ticks=21
	elif mode=="frustration_anger":
		var selected: BattleAnimationActor=attacker if int(args[0])==0 else target
		track.origin=owner.to_local(context.field.to_global(BattleElectricContract.source_anchor(selected,context)))+Vector2(int(args[1])*(1 if selected.side==0 else -1),int(args[2]))
		track.origin.y=maxf(8,track.origin.y)
	else:
		track.origin=owner.to_local(context.field.to_global(BattleElectricContract.source_anchor(attacker,context,"origin")))+Vector2(int(args[0])*BattleSoundOwnership.origin_offset_direction(context),int(args[1]))
		track.ballistic_x=0;track.ballistic_y=0;track.y2=0
	node.position=track.origin;_particle_frame(track)
	return [track]

static func _particle_frame(track: Dictionary) -> void:
	var mode: String=str(track.settings.mode)
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(track.settings.frame_program,int(track.frame_age)).frame
	var rect: Array=track.settings.frame_rects[str(int(frame.tile))]
	track.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);track.node.flip_h=bool(frame.get("flip_h",false));track.node.flip_v=bool(frame.get("flip_v",false))
	if mode=="fury_slice":track.node.flip_h=int(track.settings.source_args[2])==1
	if not track.settings.get("affine_program",[]).is_empty():
		var affine: Dictionary=BattleSourceCommandProgram.evaluate(track.settings.affine_program,int(track.age),true)
		track.node.scale=Vector2(256.0/maxf(1,affine.matrix.x),256.0/maxf(1,affine.matrix.y));track.node.rotation=float(affine.rotation)*TAU/256
		if mode=="frustration_anger" and affine.ended:track.ticks=int(track.age)

static func advance_particle(track: Dictionary, _context: BattleAnimationContext) -> void:
	if not track.actor_owner.is_present() or not track.target_owner.is_present():track.node.visible=false;track.ticks=int(track.age);return
	var mode: String=str(track.settings.mode);var age: int=int(track.age)
	track.frame_age+=1
	if mode=="fury_slice" and age<=20:
		track.accumulator+=track.velocity
		track.velocity+=Vector2(24 if int(track.settings.source_args[2])==0 else -24,-24)
		track.node.position=track.origin+Vector2(int(track.accumulator.x)>>8,int(track.accumulator.y)>>8)
	elif mode=="ice_ball":
		if int(track.state)==0:
			track.node.position=BattleSourceParticle.source_arc(track,age)
			if age>int(track.settings.travel_ticks):track.state=1;track.frame_age=0;track.settings.frame_program=track.settings.impact_frame_program
		elif BattleSourceCommandProgram.evaluate(track.settings.frame_program,int(track.frame_age)).ended:track.ticks=age
	elif mode=="ice_scatter":
		track.accumulator+=track.velocity
		track.node.position=track.origin+Vector2((int(track.accumulator.x)>>8)*(-1 if int(track.velocity.x)&1 else 1),int(track.accumulator.y)>>8)
	elif mode=="frustration_ballistic" and age>20:
		track.ballistic_x+=160;track.ballistic_y+=128;track.y2+=int(track.ballistic_y)>>8
		track.node.position=track.origin+Vector2((int(track.ballistic_x)>>8)*(1 if track.actor_owner.side==0 else -1),track.y2)
		if int(track.y2)>64:track.ticks=age
	_particle_frame(track)

static func _roll_create(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Array[Dictionary]:
	var attackers: Array[BattleAnimationActor]=context.resolve("attacker")
	var targets: Array[BattleAnimationActor]=context.resolve("target")
	if attackers.is_empty() or targets.is_empty():return []
	var actor: BattleAnimationActor=attackers[0]
	var target: BattleAnimationActor=targets[0]
	var count: int=int(context.get_meta("source_roll_count",1))
	if count<1 or count>5:count=1 # Source unsigned underflow/range fallback.
	var duration: int=32 if count==1 else 48-count*8
	var start: Vector2=Vector2(BattleElectricContract.source_anchor(actor,context).x,BattleElectricContract.source_anchor(actor,context,"origin").y+24)
	var end: Vector2=Vector2(BattleElectricContract.source_anchor(target,context).x,BattleElectricContract.source_anchor(target,context,"origin").y+24)
	if (context.source_position(actor.id)^2)==context.source_position(target.id):end.y=start.y
	var delta:=Vector2(int((end.x-start.x)*8/duration),int((end.y-start.y)*8/duration))
	var track: Dictionary={"kind":"source_counter_actor","source_callback":"sub_80DD4D4","settings":step.duplicate(true),"actor":actor,"target_owner":target,"owner":owner,"age":0,"ticks":4096,"state":0,"count":count,"travel_left":duration,"delta_q3":delta,"position_q3":start*8,"recoil_q3":Vector2.ZERO,"counter":0,"wait":0,"cadence":(duration>>3)-1,"direction":1,"pan":-64,"pan_step":127/duration,"children":[],"child_records":[],"pose":{"offset":Vector2.ZERO},"update":advance}
	track.pan=adjust_panning(-64,context)
	track.pan_step=int(float(adjust_panning(63,context)-int(track.pan))/duration)
	track.cleanup=_roll_cleanup.bind(track)
	return [track]

static func advance(track: Dictionary, context: BattleAnimationContext) -> void:
	if not track.actor.is_present() or not track.target_owner.is_present():
		_roll_cleanup(track);track.ticks=int(track.age);return
	for child: Dictionary in track.children.duplicate():
		child.age+=1
		child.node.position=BattleSourceParticle.source_arc(child,int(child.age))
		if int(child.age)>18:
			child.node.queue_free();track.children.erase(child)
	match int(track.state):
		0:
			track.recoil_q3-=track.delta_q3;track.counter+=1
			track.pose.offset=Vector2(int(track.recoil_q3.x)>>3,int(track.recoil_q3.y)>>3)
			if int(track.counter)==10:track.wait=20;track.state=1
			_roll_sound(track,"headbutt")
		1:
			track.wait-=1
			if int(track.wait)==0:track.state=2
		2:
			track.counter-=1
			if int(track.counter)!=0:track.recoil_q3+=track.delta_q3
			else:track.recoil_q3=Vector2.ZERO;track.state=3
			track.pose.offset=Vector2(int(track.recoil_q3.x)>>3,int(track.recoil_q3.y)>>3)
		3:
			track.position_q3+=track.delta_q3;track.counter+=1
			if int(track.counter)>=int(track.cadence):
				track.counter=0;_roll_child(track,context);track.pan+=int(track.pan_step);_roll_sound(track,"dig")
			track.travel_left-=1
			if int(track.travel_left)==0:track.state=4
		4:
			if track.children.is_empty():track.ticks=int(track.age)

static func _roll_sound(track: Dictionary, cue: String) -> void:
	var path: String=str(track.settings.get("private_audio",{}).get(cue,""))
	if not path.is_empty():track.owner._play_sound(path,"",float(track.pan)/64.0,true)

static func adjust_panning(pan: int, context: BattleAnimationContext) -> int:
	# battle_anim.c BattleAnimAdjustPanning, scoped to these candidate callbacks.
	var actor: BattleAnimationActor=context.actors[context.attacker_id]
	var target: BattleAnimationActor=context.resolve("target")[0]
	if not context.contest and bool(context.get_meta("source_status_anim_active",false)):
		pan=-64 if actor.side==0 else 63
	elif context.contest:
		if actor.id!=target.id or context.source_position(actor.id)!=2 or pan!=63:pan=-pan
	elif actor.side==0:
		if target.side==0:
			if pan==63:pan=-64
			elif pan!=-64:pan=-pan
	elif target.side!=0:
		if pan==-64:pan=63
	else:pan=-pan
	return clampi(pan,-64,63)

static func _roll_child(track: Dictionary, context: BattleAnimationContext) -> void:
	var origin_field:=Vector2((int(track.position_q3.x)>>3)+int(track.direction)*4,int(track.position_q3.y)>>3)
	var origin: Vector2=track.owner.to_local(context.field.to_global(origin_field))
	var destination: Vector2=origin+Vector2(int(track.direction)*20+int(track.count)*3,0)
	var tile: int=int(track.settings.get("tile_offsets",[0,80,80,64,48])[int(track.count)-1])
	track.child_records.append({"origin":origin,"destination":destination,"tile":tile,"direction":int(track.direction),"spawn_age":int(track.age)})
	if track.settings.has("children"):
		var settings: Dictionary=track.settings.children[0 if int(track.count)==1 else 1].duplicate(true)
		var node:=Sprite2D.new();track.owner.add_child(node);node.texture=load(str(settings.texture));node.region_enabled=true
		var rect: Array=settings.frame_rects[str(tile)];node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);node.position=origin
		# Source raw child subpriority35: project inside its native sprite plane.
		node.z_index=BattleSourcePriority.relative_layer(track.actor,35-BattleElectricContract.source_subpriority(track.actor,context),context,track.owner)
		track.children.append({"node":node,"age":0,"origin":origin,"destination":destination,"settings":{"travel_ticks":18,"arc":-16-int(track.count)*2}})
	track.direction=-int(track.direction)

static func _roll_cleanup(track: Dictionary) -> void:
	track.erase("cleanup")
	for child: Dictionary in track.children:
		if is_instance_valid(child.node):child.node.queue_free()
	track.children.clear()

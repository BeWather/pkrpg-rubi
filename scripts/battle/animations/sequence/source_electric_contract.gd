extends RefCounted
class_name BattleElectricContract
## Ruby-selected constructors, task-owned children and execution-bound actor phases.
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

const SHOCK_TABLES = [[-1,-1,0,1,1,0,0,-1,-1,1,1,0,0,-1,0,1],[-1,0,1,0,-1,1,0,-1,0,1,0,-1,0,1,0,1]]

static func source_anchor(actor: BattleAnimationActor, context: BattleAnimationContext, name: String = "center") -> Vector2:
	# GetBattlerSpriteCoord reads field coordinates, not the source-owned x2/y2.
	# Retain native layout/rect/transform while removing only this actor's offset.
	var point := Vector2.ZERO if name=="origin" else actor.sprite.get_rect().get_center()
	var parent := actor.sprite.get_parent() as Node2D
	return context.field.to_local(parent.to_global(actor.sprite.transform*point-actor._offset)) if parent!=null else actor.anchor(context.field,name)

static func source_offset_direction(context: BattleAnimationContext, attacker: BattleAnimationActor, target: BattleAnimationActor) -> int:
	var x := source_anchor(attacker,context,"origin").x
	var target_x := source_anchor(target,context,"origin").x
	return 1 if x<target_x else -1 if x>target_x else 1 if attacker.side==0 else -1

static func anchor_pose(step: Dictionary, context: BattleAnimationContext, origin: Vector2, destination: Vector2) -> Dictionary:
	if str(step.get("source_module",""))!="electric_contract":return {"origin":origin,"destination":destination}
	if step.has("absolute_origin"):
		return {"origin":Vector2(step.absolute_origin[0],step.absolute_origin[1]),"destination":Vector2(step.absolute_destination[0],step.absolute_destination[1]) if step.has("absolute_destination") else Vector2(step.absolute_origin[0],step.absolute_origin[1])}
	var attackers := context.resolve("attacker")
	var targets := context.resolve("target")
	if attackers.is_empty() or targets.is_empty():return {"origin":origin,"destination":destination}
	var attacker: BattleAnimationActor = attackers[0]
	var target: BattleAnimationActor = targets[0]
	var side := 1 if attacker.side==0 else -1
	var args: Array = step.get("source_args",[])
	var offset := Vector2(args[0],args[1]) if args.size()>1 else Vector2.ZERO
	match str(step.get("mode","")):
		"hydro_charge_orb":origin=source_anchor(attacker,context,"origin")+Vector2(-10 if context.contest else side*10,-10);destination=origin
		"hydro_stream","zap_ball":
			var x := int(args[0])
			if str(step.mode)=="hydro_stream" and attacker.side==target.side and context.source_position(attacker.id) not in [BattleAnimationContext.SourcePosition.PLAYER_LEFT,BattleAnimationContext.SourcePosition.OPPONENT_LEFT]:x *= -1
			origin=source_anchor(attacker,context,str(step.get("from_anchor","center")))+Vector2(x*source_offset_direction(context,attacker,target),args[1])
			destination=source_anchor(target,context,str(step.get("to_anchor","center")))+Vector2(int(args[2])*side,args[3])
		"eye_sparkle":origin=source_anchor(attacker,context)+Vector2(offset.x*source_offset_direction(context,attacker,target),offset.y);destination=origin
		"fire_plume":origin=source_anchor(attacker,context)+Vector2(offset.x*side,offset.y);destination=origin
		"fire_scatter","thunder_bolt":origin=source_anchor(target,context)+Vector2(offset.x*side,offset.y);destination=origin
		"tri_force","zap_spark":
			origin=source_anchor(attacker,context,"origin" if str(step.mode)=="tri_force" else "center")+Vector2(offset.x*source_offset_direction(context,attacker,target),offset.y)
			destination=source_anchor(target,context)
		"charge_ring","charge_bolt","volt_exit_ring","shock_ring":
			var actor: BattleAnimationActor = target if not args.is_empty() and int(args[0])!=0 else attacker
			origin=source_anchor(actor,context)
			if str(step.mode)=="charge_bolt":origin+=Vector2(args[1],args[2])
			destination=origin
	return {"origin":origin,"destination":destination}

static func source_subpriority(actor: BattleAnimationActor, context: BattleAnimationContext) -> int:
	if context.contest:
		# Explicit source-bank metadata takes precedence. Native contexts have no
		# hardware bank allocator: the partner role is an honest semantic fallback.
		if actor.sprite.has_meta("animation_source_bank"):
			return 30 if int(actor.sprite.get_meta("animation_source_bank"))==2 else 40
		return 30 if actor in context.resolve("attacker_partner") else 40
	return int({0:30,1:40,2:20,3:50}.get(context.source_position(actor.id),40))

static func effective_layer(node: CanvasItem) -> int:
	var value := 0
	var current: CanvasItem = node
	while current!=null:
		value+=current.z_index
		if not current.z_as_relative:break
		current=current.get_parent() as CanvasItem
	return value

static func actor_layer(actor: BattleAnimationActor, parent: CanvasItem) -> int:
	return effective_layer(actor.sprite)-effective_layer(parent)

static func absolute_priority_layer(priority: int, context: BattleAnimationContext, parent: CanvasItem) -> int:
	var nearest: BattleAnimationActor
	var nearest_priority := -1
	var front := -4096
	for actor: BattleAnimationActor in context.resolve("all"):
		front=maxi(front,actor_layer(actor,parent))
		var value := source_subpriority(actor,context)
		if value<=priority and value>nearest_priority:
			nearest=actor
			nearest_priority=value
	if nearest==null:return clampi(front+1,-4096,4096)
	return clampi(actor_layer(nearest,parent)-(0 if nearest_priority==priority else 1),-4096,4096)

static func behind_actor_plane(priority: int, actor: BattleAnimationActor, context: BattleAnimationContext, parent: CanvasItem) -> int:
	# OAM subpriority orders sprites within a plane; it is not a global Z delta.
	# Keep the native field opaque BG below the particle and its selected actor above.
	# When there is only one integer lane, distinct source back-depths share that lane.
	var floor := effective_layer(context.field)-effective_layer(parent)
	var ceiling := maxi(floor,actor_layer(actor,parent)-1)
	return clampi(absolute_priority_layer(priority,context,parent),floor,ceiling)

static func initialize_particle(track: Dictionary, context: BattleAnimationContext, owner: Node2D) -> void:
	if str(track.settings.get("source_module","")) not in ["electric_contract","charge_contract"]:return
	track.source_context=context
	track.source_owner=owner
	track.source_contest=context.contest
	if track.settings.has("source_priority_arg") and not track.settings.has("source_command_priority"):
		var basis: Array = context.resolve(str(track.settings.get("source_priority_basis","attacker")))
		if not basis.is_empty() and basis[0].is_present():
			var operand := int(track.settings.source_priority_arg)&127
			var delta := operand-64 if operand>=64 else -operand
			var base := source_subpriority(basis[0],context)
			delta=maxi(3,base+delta)-base
			track.node.z_index=clampi(actor_layer(basis[0],owner)-delta,-4096,4096)
	if track.settings.has("source_absolute_priority"):
		track.node.z_index=absolute_priority_layer(int(track.settings.source_absolute_priority),context,owner)
	var attackers := context.resolve("attacker")
	var targets := context.resolve("target")
	if str(track.settings.get("mode",""))=="volt_exit_ring" and not attackers.is_empty():track.source_bound_attacker=attackers[0]
	if str(track.settings.get("mode",""))=="tri_force" and not targets.is_empty():track.source_bound_target=targets[0]
	if str(track.settings.get("mode",""))=="hydro_charge_orb" and not attackers.is_empty():track.node.z_index=actor_layer(attackers[0],owner)+(2 if not context.contest and attackers[0].side!=0 else -2)

static func bound_identity_present(track: Dictionary) -> bool:
	for key in ["source_bound_target","source_bound_attacker"]:
		if not track.has(key):continue
		var actor: BattleAnimationActor = track[key]
		if actor.is_present():continue
		track.node.visible=false
		track.ticks=track.age
		if key=="source_bound_attacker":track.source_owner._held_offsets.erase(actor.id)
		return false
	return true

static func frame_pose(track: Dictionary, selected: Dictionary) -> Dictionary:
	if str(track.settings.get("mode",""))=="charge_orb_child" and int(track.age)>=4:
		return BattleSourceCommandProgram.evaluate(track.settings.replacement_frame_program,int(track.age)-4).frame
	if track.settings.has("source_fixed_tile"):return {"tile":int(track.settings.source_fixed_tile),"ticks":1}
	return selected

static func particle_pose(track: Dictionary) -> void:
	if str(track.settings.get("source_module",""))!="electric_contract":return
	var s: Dictionary = track.settings
	var age := maxi(0,int(track.age))
	var node: Sprite2D = track.node
	var side := 1 if int(track.source_side)==0 else -1
	match str(s.get("mode","")):
		"fire_plume","fire_scatter":
			var count := mini(age+1,maxi(0,int(s.motion_window)-1))
			node.position=track.origin+Vector2(int(s.velocity[0])*side*(1 if str(s.mode)=="fire_plume" else -1),s.velocity[1])*count
		"zap_spark":
			var angle := (int(s.angle)+age*int(s.angle_step))&255
			node.position=BattleGhostContract._linear_translation(track.origin,track.destination,age+1,int(s.travel_ticks))+Vector2(BattleSourceTrig.sine(angle,int(s.radius)),BattleSourceTrig.cosine(angle,int(s.radius)))
			var hidden := false
			for sample in age+1:
				if ((int(s.angle)+(sample+1)*int(s.angle_step))&255)%3==0:hidden=not hidden
			node.visible=not hidden
		"hydro_stream","zap_ball":node.position=BattleGhostContract._linear_translation(track.origin,track.destination,age+1,int(s.travel_ticks))
		"tri_force":
			node.visible=age+1>30 or (age+1)%2==1
			if age>=61:
				if not track.has("source_release_destination"):track.source_release_destination=source_anchor(track.source_bound_target,track.source_context)
				node.position=BattleGhostContract._linear_translation(track.origin,track.source_release_destination,age-60,int(s.travel_ticks))
			else:node.position=track.origin
		"volt_exit_ring":
			var displacement := maxi(0,age-40)*16*side
			node.position=track.origin+Vector2(displacement,0)
			var actor: BattleAnimationActor = track.source_bound_attacker
			track.source_owner._held_offsets[actor.id]=Vector2(displacement,0)
			actor.apply(Vector2(displacement,0),Color.WHITE)
			if node.position.x< -80 or node.position.x>320:track.ticks=age
		"tri_ice":node.visible=age<int(s.source_affine_ticks) or (age-int(s.source_affine_ticks))%2!=0
		"charge_orb_child":node.position=BattleGhostContract._linear_translation(track.origin,track.destination,maxi(0,age-4),int(s.travel_ticks))

static func create_control(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Array[Dictionary]:
	var mode := str(step.task_mode)
	var args: Array = step.get("source_args",[])
	var actors := context.resolve("attacker")
	var targets := context.resolve("target")
	if actors.is_empty() or targets.is_empty():return []
	var attacker: BattleAnimationActor = actors[0]
	var target: BattleAnimationActor = targets[0]
	var track := {"kind":"source_electric_task","age":0,"ticks":4096,"phase":0,"settings":step.duplicate(true),"owner":owner,"source_context":context,"attacker":attacker,"target":target,"pending_nodes":[],"update":update_control,"last_age":-1,"counter":0,"scheduled_done":false}
	match mode:
		"invert":
			if (int(args[0])&256)!=0:
				var active := not bool(owner._source_palette_banks.get("electric:bg_invert",false))
				owner._source_palette_banks["electric:bg_invert"]=active
				if active:
					var node := ColorRect.new()
					node.name="SourceFieldInvert"
					node.size=context.field_size
					var actor_layer := 4096
					for selected in context.actors.values():
						if selected.is_present():actor_layer=mini(actor_layer,BattleElectricContract.actor_layer(selected,owner))
					node.z_index=clampi(actor_layer-1,-4096,4096)
					var material := ShaderMaterial.new()
					material.shader=load("res://scripts/battle/animations/sequence/field_invert.gdshader")
					node.material=material
					owner.add_child(node)
				elif owner.has_node("SourceFieldInvert"):owner.get_node("SourceFieldInvert").queue_free()
			for pair in [[attacker,args[1]],[target,args[2]]]:
				var actor: BattleAnimationActor = pair[0]
				if (int(pair[1])&256)!=0:actor.apply_source_state("invert",not actor._owned_invert)
			track.ticks=1
		"target_shock":
			track.ticks=int(args[0])
			track.shock_variant=int(args[3]) if args.size()>3 else int(owner._source_args.get(3,0))
		"charge_orbs":
			track.center=source_anchor(attacker if int(args[0])==0 else target,context)
			track.remaining_children=int(args[1]);track.generation_delay=int(args[2]);track.spawn_interval_count=int(args[3]);track.spawned=0
		"volt_return":
			track.ticks=52
			owner._held_offsets[attacker.id]=Vector2(-32 if attacker.side==0 else 32,0)
			attacker.apply(owner._held_offsets[attacker.id],Color.WHITE)
		"volt_trail":
			var phase := int(args[0])
			var side := 1 if attacker.side==0 else -1
			track.route_y=source_anchor(attacker,context).y
			if phase==0:track.route_start=source_anchor(attacker,context).x;track.route_end=120+side*128
			elif phase==4:track.route_start=120-side*128;track.route_end=source_anchor(target,context).x-side*32;track.route_y=source_anchor(target,context).y
			else:
				track.route_start=256 if phase%2==1 else -16;track.route_end=-16 if phase%2==1 else 256
				track.route_y=80-phase*10 if side==1 else phase*10+40
				if side==-1:
					var swap: float = track.route_start;track.route_start=track.route_end;track.route_end=swap
			track.route_cursor=track.route_start;track.route_direction=1 if track.route_start<track.route_end else -1
		"shock_serpentine":
			track.columns=5;track.source_child_lifetime=13;track.column=0;track.route_x=source_anchor(attacker,context).x;track.route_dx=int((source_anchor(target,context).x-track.route_x)/5);track.route_y=source_anchor(attacker,context).y;track.route_end=4;track.route_direction=-1;track.tile=7;track.cooldown=0;track.next_column_age=0;track.source_pan=-64
		"shock_column":
			track.column_end=source_anchor(target,context,"origin").y+32
			track.column_y=track.column_end
			while track.column_y>16:track.column_y-=32
			track.column_x=source_anchor(target,context).x;track.column_layer=actor_layer(target,owner)+2
		"glare_eyes":
			var bounds := attacker.sprite.get_rect().size*attacker.sprite.global_scale.abs()
			track.eye_start=source_anchor(attacker,context)+Vector2((1 if attacker.side==0 else -1)*bounds.y/4,-bounds.y/4)
			track.eye_target=source_anchor(target,context);track.source_eye_steps=8 if context.contest else 12;track.spawned=0
		"scary_face":
			track.ticks=78;track.alpha_hold=21
			var face := Sprite2D.new()
			face.centered=false;face.z_index=30
			var textures: Dictionary = step.get("face_textures",{})
			if not textures.is_empty():face.texture=load(str(textures["contest" if context.contest else "player" if target.side==1 else "opponent"]))
			face.modulate.a=0
			owner.add_child(face);track.node=face
	if mode=="target_shock":update_control(track,context)
	return [track]

static func _spawn(track: Dictionary, values: Dictionary) -> void:
	var binding: Dictionary = track.settings.get("child_binding",{})
	if binding.is_empty():return
	var step := binding.duplicate(true)
	step.merge(values,true)
	step["source_module"]="electric_contract"
	step["mirror_offset"]=false
	step["offset"]=[0,0]
	var children: Array = BattleEffectBehaviorRegistry.factories().source_particle.call(step,track.source_context,track.owner)
	for child in children:
		track.owner._tracks.append(child)
		track.pending_nodes.append(child.node)

static func _pending(track: Dictionary) -> int:
	var count := 0
	for node in track.pending_nodes:
		if is_instance_valid(node) and not node.is_queued_for_deletion():count+=1
	return count

static func update_control(track: Dictionary, context: BattleAnimationContext) -> void:
	var age := int(track.age)
	if age==int(track.last_age):return
	track.last_age=age
	var mode := str(track.settings.task_mode)
	var args: Array = track.settings.get("source_args",[])
	var attacker: BattleAnimationActor = track.attacker
	var target: BattleAnimationActor = track.target
	var side := 1 if attacker.side==0 else -1
	if mode in ["target_shock","volt_return"]:
		var actor: BattleAnimationActor = target if mode=="target_shock" else attacker
		if not actor.is_present():track.owner._held_offsets.erase(actor.id);track.ticks=age;return
	match mode:
		"target_shock":
			var amount := int(track.owner._source_args.get(1,int(args[1])))
			if amount>=32768:amount-=65536
			var count := age+1
			var offset := int(SHOCK_TABLES[1 if int(track.shock_variant)!=0 else 0][count%10])*amount
			var value := Vector2(0,absi(offset)) if int(args[2])==1 else Vector2(offset,0)
			if count>=int(args[0]):value=Vector2.ZERO;track.ticks=age
			track.owner._held_offsets[target.id]=value;target.apply(value,Color.WHITE)
		"volt_return":
			var toggles := age/2
			var value := Vector2((-32+mini(toggles,16)*2)*side,0)
			track.owner._held_offsets[attacker.id]=value;attacker.apply(value,Color.WHITE)
			attacker.apply_source_state("visible",true if age>=51 else toggles%2==0)
			if age>=51:track.ticks=age
		"scary_face":
			track.phase=0 if age<=28 else 1 if age<=49 else 2 if age<=77 else 3
			var alpha := mini(14,age/2) if age<=28 else 14 if age<=49 else maxi(0,14-(age-49)/2)
			track.node.modulate.a=alpha/16.0
		"charge_orbs":
			if age>0 and int(track.remaining_children)>0:
				track.counter+=1
				if int(track.counter)>int(track.generation_delay):
					track.counter=0
					var index := int(track.spawned)
					var tier := mini(6,index/maxi(1,int(track.spawn_interval_count)))
					var offsets: Array = track.settings.get("spawn_offsets",[])
					var offset := Vector2(offsets[index%16][0],offsets[index%16][1]) if not offsets.is_empty() else Vector2.ZERO
					var origin: Vector2 = track.center+offset
					var duration := 40-tier*5
					_spawn(track,{"mode":"charge_orb_child","absolute_origin":[origin.x,origin.y],"absolute_destination":[track.center.x,track.center.y],"travel_ticks":duration,"ticks":duration+5})
					track.spawned+=1;track.remaining_children-=1
			track.scheduled_done=int(track.remaining_children)==0
		"volt_trail":
			if age>0 and not bool(track.scheduled_done):
				for attempt in 2:
					_spawn(track,{"mode":"volt_trail_child","absolute_origin":[track.route_cursor,track.route_y],"ticks":13})
					track.route_cursor+=int(track.route_direction)*16
					if (int(track.route_direction)==1 and track.route_cursor>=track.route_end) or (int(track.route_direction)==-1 and track.route_cursor<=track.route_end):track.scheduled_done=true;break
		"shock_serpentine":
			if age>0 and not bool(track.scheduled_done) and age>=int(track.next_column_age):
				_spawn(track,{"mode":"shock_segment","absolute_origin":[track.route_x,track.route_y],"ticks":13,"source_fixed_tile":int(track.tile)})
				track.tile=(int(track.tile)+int(track.route_direction)+8)%8
				if int(track.tile)==0 and int(track.route_direction)>0:
					track.source_pan+=42
					if track.settings.has("callback_cue_path"):track.owner._play_sound(str(track.settings.callback_cue_path),"",float(track.source_pan)/64.0)
				if (int(track.route_direction)<0 and track.route_y<=track.route_end) or (int(track.route_direction)>0 and track.route_y>=track.route_end):
					track.column+=1;track.route_x+=int(track.route_dx)
					track.scheduled_done=int(track.column)==5
					track.route_y=4 if int(track.column)%2==1 else 68
					track.route_end=68 if int(track.column)%2==1 else 4
					track.route_direction=1 if int(track.column)%2==1 else -1
					track.tile=0 if int(track.route_direction)>0 else 7
					track.next_column_age=maxi(age+5,int(track.column)*12+1)
				else:track.route_y+=int(track.route_direction)*8
		"shock_column":
			if age>0 and age%2==0 and not bool(track.scheduled_done):
				_spawn(track,{"mode":"shock_column_bolt","absolute_origin":[track.column_x,track.column_y],"ticks":29,"source_z_index":int(track.column_layer)})
				if track.column_y>=track.column_end:track.scheduled_done=true
				else:track.column_y+=32
		"glare_eyes":
			if age>0 and age%4==0 and not bool(track.scheduled_done):
				var index := int(track.spawned)
				var steps := int(track.source_eye_steps)
				var position: Vector2 = track.eye_target if index>=steps else Vector2(floorf(track.eye_start.x+index*int((track.eye_target.x-track.eye_start.x)*256/(steps-1))/256.0),floorf(track.eye_start.y+index*int((track.eye_target.y-track.eye_start.y)*256/(steps-1))/256.0))
				for sign_value in [-1,1]:
					var origin := position+Vector2(sign_value*3,sign_value*3*(-1 if context.contest else 1))
					_spawn(track,{"mode":"glare_eye_child","absolute_origin":[origin.x,origin.y],"ticks":37})
				track.spawned+=1
				track.scheduled_done=index==steps
	if mode in ["charge_orbs","volt_trail","shock_serpentine","shock_column","glare_eyes"] and bool(track.scheduled_done) and _pending(track)==0:track.ticks=age

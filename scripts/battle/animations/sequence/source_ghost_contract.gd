extends RefCounted
class_name BattleGhostContract
## Selected ghost private callbacks; native actors remain independent of species art.
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

class ParentLink extends RefCounted:
	# Dictionary.duplicate(true) must keep the one live task, not copy its state.
	var task: Dictionary

static func initialize_particle(track: Dictionary, context: BattleAnimationContext, owner: Node2D = null) -> void:
	track.source_owner = owner
	track.source_contest = context.contest
	if str(track.settings.get("mode","")) in ["shadow_ball","wisp_orb"]:
		track.source_context = context
		track.source_target = context.resolve("target")[0]
	if str(track.settings.get("mode","")) == "confuse_ball":
		track.source_travel_ticks = maxi(1,int(absf(track.destination.x-track.origin.x)*256/int(track.settings.travel_speed)))
	if owner!=null:track.source_layer_floor=BattleSourcePriority.effective_layer(context.field)-BattleSourcePriority.effective_layer(owner)
	if not context.resolve("target").is_empty():track.target_layer = BattleSourcePriority.actor_layer(context.resolve("target")[0],owner) if owner!=null else context.resolve("target")[0].sprite.z_index

static func bound_identity_present(track: Dictionary) -> bool:
	if str(track.settings.get("mode","")) not in ["shadow_ball","wisp_orb"]:return true
	# The execution-bound occupant may disappear during travel OR the hold.
	# Do not resolve the role again: that could silently bind a replacement occupant.
	var actor: BattleAnimationActor = track.get("source_target")
	if actor != null and actor.is_present():return true
	track.node.visible = false
	track.ticks = int(track.age)
	return false

static func particle_pose(track: Dictionary) -> void:
	var settings: Dictionary = track.settings
	var age := maxi(0,int(track.age))
	var node: Sprite2D = track.node
	match str(settings.get("mode","")):
		"confuse_ball":_confuse_pose(track,age)
		"confuse_target_orbit":
			var angle := (age*19)&255
			node.position = track.origin+Vector2(BattleSourceTrig.sine(angle,32),BattleSourceTrig.cosine(angle,8)+(age+1)*80/256)
			node.z_index = maxi(int(track.get("source_layer_floor",-4096)),int(track.get("target_layer",20))+(-1 if angle>=65 and angle<=195 else 1))
		"wisp_orb":_wisp_orb_pose(track,age)
		"wisp_fire":
			var count := age+1
			var angle := (int(settings.source_angle)+age*7)&255
			node.position = track.origin+Vector2(BattleSourceTrig.sine(angle,count*384/256),BattleSourceTrig.cosine(angle,count*160/256))
			var next_angle := (angle+7)&255
			var back := next_angle>=64 and next_angle<=195
			node.z_index = maxi(int(track.get("source_layer_floor",-4096)),(29 if not back else 27) if bool(track.source_contest) else int(track.get("target_layer",20))+(-1 if back else 1))
			node.visible = count<=20 or (count-20)%2==0
		"destiny_child":
			node.position = _q4_translation(track.origin,track.destination,mini(age,int(settings.travel_ticks)),int(settings.travel_ticks))
			node.modulate.a = float(settings.ghost_parent.task.alpha_a)/16.0
			if settings.ghost_parent.task.fade_done:node.visible=false;track.ticks=age
		"grudge_flame":
			var angle := (int(settings.source_angle)+(age+1)*(-2 if track.source_side==0 else 2))&255
			node.position = track.origin+Vector2(BattleSourceTrig.sine(angle,int(settings.radius)),BattleSourceTrig.sine(((int(settings.child_phase)+age+1)*8)&255,7))
			node.z_index = maxi(int(track.get("source_layer_floor",-4096)),int(settings.actor_layer)+(-1 if angle>=65 and angle<192 else 2))
			node.modulate.a = float(settings.ghost_parent.task.alpha_a)/16.0
			if settings.ghost_parent.task.fade_done:node.visible=false;track.ticks=age
		"lick_pulse":
			var elapsed := age-int(settings.frame_end_ticks)
			if elapsed >= 0:
				node.visible = (elapsed<15 and elapsed%3==2) or (elapsed>=15 and elapsed<40 and (elapsed-15)%5==4)
		"shadow_ball":
			var args: Array = settings.source_args
			var first := int(args[0])
			var hold := int(args[1])
			var release := int(args[2])
			var delta: Vector2 = track.destination-track.origin
			var velocity := Vector2(int(delta.x*16/(first*2)),int(delta.y*16/(first*2)))
			var middle: Vector2 = track.origin+Vector2(floorf(velocity.x*first/16),floorf(velocity.y*first/16))
			if age <= first:
				node.position = track.origin+Vector2(floorf(velocity.x*age/16),floorf(velocity.y*age/16))
			elif age < first+hold:
				node.position = middle
			else:
				# Ruby samples target again at the hold transition, and once more at landing.
				var actor: BattleAnimationActor = track.source_target
				var context: BattleAnimationContext = track.source_context
				if not track.has("release_target"):
					track.release_target = actor.anchor(context.field)
				var destination: Vector2 = track.release_target
				var count := mini(age-first-hold,release)
				velocity = Vector2(int((destination.x-middle.x)*16/release),int((destination.y-middle.y)*16/release))
				node.position = middle+Vector2(floorf(velocity.x*count/16),floorf(velocity.y*count/16))
				if count == release:node.position = actor.anchor(context.field)

static func actor_pose(track: Dictionary) -> Dictionary:
	var settings: Dictionary = track.settings
	var age := maxi(0,int(track.age))
	var ramp := int(settings.alpha_interval)*int(settings.alpha_limit)
	var matrix := mini(256,int(settings.matrix_initial)+maxi(0,age-ramp-int(settings.hold_ticks))*int(settings.matrix_delta))
	var alpha := mini(int(settings.alpha_limit),age/int(settings.alpha_interval))
	return {"offset":Vector2.ZERO,"scale":Vector2.ONE*256.0/matrix,"rotation":0.0,"tint":Color(1,1,1,alpha/16.0)}

static func _q4_translation(origin: Vector2, destination: Vector2, count: int, duration: int) -> Vector2:
	var velocity := Vector2(int((destination.x-origin.x)*16/maxi(1,duration)),int((destination.y-origin.y)*16/maxi(1,duration)))
	return origin+Vector2(floorf(velocity.x*count/16),floorf(velocity.y*count/16))

static func _linear_translation(origin: Vector2, destination: Vector2, count: int, duration: int) -> Vector2:
	var delta := destination-origin
	var sx := int(absf(delta.x)*256)/maxi(1,duration)
	var sy := int(absf(delta.y)*256)/maxi(1,duration)
	sx = (sx|1) if delta.x<0 else sx&~1
	sy = (sy|1) if delta.y<0 else sy&~1
	return origin+Vector2((count*sx>>8)*(-1 if delta.x<0 else 1),(count*sy>>8)*(-1 if delta.y<0 else 1))

static func _confuse_pose(track: Dictionary, age: int) -> void:
	var duration := int(track.source_travel_ticks)
	var amount := 16
	var direction := -1
	var low := 0
	var completed := false
	for tick in age:
		if tick>duration and amount==0:completed=true;break
		if amount>255:
			amount+=1
			if amount==269:amount=0
		else:
			var old := low
			low = (low+1)&255
			if old==0:
				low=0;amount+=direction
				if amount in [0,16]:direction*=-1
				if amount==0:amount=256
	var orbit_age := maxi(0,age-1-(1 if age>duration else 0))
	var angle := (orbit_age*5)&255
	track.node.position = _linear_translation(track.origin,track.destination,age if age<=duration else age-1,duration)+Vector2(BattleSourceTrig.sine(angle,10),BattleSourceTrig.cosine(angle,15))
	track.node.modulate.a = (0 if amount>255 else amount)/16.0
	if completed:track.node.visible=false;track.ticks=age;return
	if age>0 and age!=duration+1 and (angle==0 or angle>196) and ((angle+5)&255)>0:_cue(track,age,age<=duration)

static func _wisp_orb_pose(track: Dictionary, age: int) -> void:
	var direction := -1 if track.source_side==0 else 1
	if age<=32:
		track.node.position = track.origin+Vector2(BattleSourceTrig.sine((maxi(0,age-1)*4)&255,4*direction),0)
		return
	if not track.has("wisp_release_origin"):
		track.wisp_release_origin = track.origin+Vector2(BattleSourceTrig.sine(124,4*direction),0)
		track.wisp_destination = track.source_target.anchor(track.source_context.field)
		track.source_travel_ticks = maxi(1,int(absf(track.wisp_destination.x-track.wisp_release_origin.x)*256/int(track.settings.travel_speed)))
	var count := age-32
	var angle := ((count-1)*4)&255
	track.node.position = _linear_translation(track.wisp_release_origin,track.wisp_destination,count,int(track.source_travel_ticks))+Vector2(BattleSourceTrig.sine(angle,16),0)
	if count>int(track.source_travel_ticks):track.node.visible=false;track.ticks=age;return
	if int(track.settings.source_args[2])==0 and (angle==0 or angle>196) and ((angle+4)&255)>0:_cue(track,age,true)

static func _cue(track: Dictionary, age: int, panned: bool) -> void:
	if not track.settings.has("callback_cue_path") or track.get("last_cue_age",-1)==age:return
	var owner: Node2D = track.source_owner
	if not is_instance_valid(owner):return
	track.last_cue_age=age
	owner._play_sound(str(track.settings.callback_cue_path),"0" if panned else "",float(owner.get_meta("source_ghost_pan",-64))/64.0)

static func create_control(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Array[Dictionary]:
	var track := {"kind":str(step.behavior),"age":0,"ticks":int(step.ticks),"settings":step.duplicate(true),"owner":owner,"update":update_control}
	update_control(track,context)
	return [track]

static func update_control(track: Dictionary, _context: BattleAnimationContext) -> void:
	var settings: Dictionary = track.settings
	var owner: Node2D = track.owner
	if track.kind=="source_ghost_pan":
		var a: Array = settings.source_args
		var pan: int = int(a[0])+signi(int(a[1])-int(a[0]))*absi(int(a[2]))*((int(track.age)/(int(a[3])+1))+1)
		owner.set_meta("source_ghost_pan",clampi(pan,mini(int(a[0]),int(a[1])),maxi(int(a[0]),int(a[1]))))
		return
	var remaining := int(track.age)
	var coefficient := 0
	var color := Color.WHITE
	for segment in settings.blend_segments:
		coefficient=int(segment.start)+signi(int(segment.end)-int(segment.start))*mini(absi(int(segment.end)-int(segment.start)),remaining/int(segment.delay))
		color=Color(str(segment.color))
		if remaining<int(segment.ticks):break
		remaining-=int(segment.ticks)
	owner._source_palette_banks["ghost:"+str(settings.source_palette_tag)]={"color":color,"amount":coefficient/16.0}
	for particle in owner._tracks:
		if particle.get("settings",{}).get("source_palette_tag","")==settings.source_palette_tag and particle.has("node"):
			var material: ShaderMaterial = particle.node.material as ShaderMaterial
			if material==null:
				material=ShaderMaterial.new();material.shader=load("res://scripts/battle/animations/sequence/palette_blend.gdshader");particle.node.material=material
			material.set_shader_parameter("blend_color",color);material.set_shader_parameter("blend_amount",coefficient/16.0)

static func create_clone(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for actor in context.resolve(str(step.selector)):
		var clone := Sprite2D.new()
		clone.texture=actor.sprite.texture;clone.hframes=actor.sprite.hframes;clone.vframes=actor.sprite.vframes;clone.frame=actor.sprite.frame
		clone.region_enabled=actor.sprite.region_enabled;clone.region_rect=actor.sprite.region_rect
		clone.flip_h=actor.sprite.flip_h;clone.flip_v=actor.sprite.flip_v
		clone.modulate=actor._base_color
		clone.material=actor._previous_material if actor._blend_material!=null else actor.sprite.material
		clone.scale=actor.sprite.global_scale/context.field.global_scale
		clone.position=actor.anchor(context.field);clone.z_index=actor.sprite.z_index+(-1 if step.clone_mode=="spite" else 1)
		owner.add_child(clone)
		var track := {"kind":"source_ghost_clone","age":0,"ticks":int(step.ticks),"settings":step.duplicate(true),"node":clone,"origin":clone.position,"bound_actor":actor,"owner":owner,"update":update_clone,"source_side":actor.side,"clone_base_alpha":clone.modulate.a}
		update_clone(track,context)
		result.append(track)
	return result

static func update_clone(track: Dictionary, _context: BattleAnimationContext) -> void:
	var age := int(track.age)
	var node: Sprite2D = track.node
	if track.settings.clone_mode=="nightmare":
		var count := mini(age,int(track.settings.travel_ticks))
		var direction := -1 if int(track.source_side)==0 else 1
		node.position=track.origin+Vector2(floorf(count*144.0*direction/256),floorf(count*-112.0*direction/256))
		node.modulate.a=float(track.clone_base_alpha)*maxi(0,15-(age+3)/4)/16.0
		if age>80:node.visible=false
	else:
		var actor: BattleAnimationActor = track.bound_actor
		if not actor.is_present():
			# Remove only this clone's held write, never a later independent blend.
			if int(track.owner._held_blends.get(actor.id,{}).get("ghost_bound",-1))==actor.get_instance_id():track.owner._held_blends.erase(actor.id)
			node.visible=false;track.ticks=age;return
		var count := clampi(age-5,0,128)
		var alpha := int(BattleSourceTrig.VALUES[count])/18
		track.source_alpha=alpha/16.0
		node.modulate.a=float(track.clone_base_alpha) # Unfaded duplicate behind target BG.
		var context: BattleAnimationContext = track.owner.context
		var origin_y := actor.anchor(context.field,"origin").y
		if not track.has("wave_field_start") and age>=3:track.wave_field_start=maxf(0.0,origin_y-32)
		var field_start: float = track.get("wave_field_start",maxf(0.0,origin_y-32))
		track.owner._held_blends[actor.id]={"ghost_bound":actor.get_instance_id(),"color":Color(13.0/31,0,15.0/31),"amount":10.0/16.0 if age<134 else 0.0,"opacity":track.source_alpha if age<134 else 1.0,"wave_amplitude":6.0 if age>=3 and age<134 else 0.0,"wave_phase":float(age),"wave_height":actor.sprite.get_rect().size.y,"wave_start":field_start-origin_y,"wave_end":field_start+64-origin_y,"wave_scale_x":absf(actor.sprite.global_scale.x/context.field.global_scale.x),"wave_scale_y":absf(actor.sprite.global_scale.y/context.field.global_scale.y)}
		if age>=135:actor.apply_source_state("hidden",true);node.visible=false

static func create_children(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var attackers := context.resolve("attacker")
	if attackers.is_empty():return result
	var actor: BattleAnimationActor = attackers[0]
	var parent := {"kind":"source_ghost_task","age":0,"ticks":2147483647,"phase":0,"counter":16 if step.child_mode=="grudge" else 0,"subcounter":0,"alpha_a":0,"alpha_b":16,"hold":int(step.hold_ticks),"fade_done":false,"entrance_done":false,"mode":str(step.child_mode),"nodes":[],"owner":owner,"settings":step.duplicate(true),"update":update_parent}
	parent.palette_key="ghost-task:%s:%d:%d" % [step.child_mode,owner.elapsed_ticks,owner.get_child_count()]
	var link := ParentLink.new()
	link.task=parent
	result.append(parent)
	var destinations: Array[Vector2] = []
	if step.child_mode=="destiny":
		if context.contest:destinations.append(Vector2(48,40))
		else:
			for target in context.actors.values():
				if target.side!=actor.side and target.is_present() and target.sprite.is_visible_in_tree():destinations.append(target.anchor(context.field,"feet"))
	else:
		for index in 6:destinations.append(actor.anchor(context.field,"feet"))
	for index in destinations.size():
		var binding: Dictionary = step.child_binding.duplicate(true)
		binding.merge({"mode":"destiny_child" if step.child_mode=="destiny" else "grudge_flame","selector":"attacker","anchor":"feet","offset":[0,0],"mirror_offset":false,"ticks":int(step.ticks),"travel_ticks":int(step.travel_ticks),"hold_ticks":int(step.hold_ticks),"source_parent":"sub_80DE918" if step.child_mode=="destiny" else "sub_80DF1A4","ghost_parent":link},true)
		if step.child_mode=="grudge":binding.merge({"source_angle":int(step.child_angles[index]),"child_phase":int(step.child_phases[index]),"radius":int(actor.sprite.get_rect().size.y/2)+8,"actor_layer":BattleSourcePriority.actor_layer(actor,owner)},true)
		var children: Array[Dictionary] = BattleEffectBehaviorRegistry.factories().source_particle.call(binding,context,owner)
		for child in children:
			child.destination=destinations[index]
			child.node.modulate.a=0.0
			parent.nodes.append(child.node)
			result.append(child)
	return result

static func update_parent(track: Dictionary, _context: BattleAnimationContext) -> void:
	if track.mode=="destiny":
		match int(track.phase):
			0:
				if not track.entrance_done:
					track.counter+=1
					if track.counter>1:
						track.counter=0;track.subcounter+=1
						if int(track.subcounter)&1:track.alpha_a=mini(16,int(track.alpha_a)+1)
						else:track.alpha_b=maxi(0,int(track.alpha_b)-1)
						if track.subcounter>=24:track.subcounter=0;track.entrance_done=true
				if track.hold>0:track.hold-=1
				elif track.entrance_done:track.phase=1
			1:
				track.counter+=1
				if track.counter>1:
					track.counter=0;track.subcounter+=1
					if int(track.subcounter)&1:track.alpha_a=maxi(0,int(track.alpha_a)-1)
					else:track.alpha_b=mini(16,int(track.alpha_b)+1)
					if track.alpha_a==0 and track.alpha_b==16:
						track.fade_done=true;track.phase=2
			2:track.phase=3
			3:track.ticks=int(track.age)
	else:
		match int(track.phase):
			0:track.phase=1
			1:
				track.counter+=1
				if int(track.counter)&1:track.alpha_a=mini(14,int(track.alpha_a)+1)
				else:track.alpha_b=maxi(4,int(track.alpha_b)-1)
				if track.alpha_a==14 and track.alpha_b==4:track.counter=0;track.phase=2
			2:
				track.counter+=1
				if track.counter>30:track.counter=0;track.phase=3
			3:
				track.counter+=1
				if int(track.counter)&1:track.alpha_a=maxi(0,int(track.alpha_a)-1)
				else:track.alpha_b=mini(16,int(track.alpha_b)+1)
				if track.alpha_a==0 and track.alpha_b==16:track.fade_done=true;track.phase=4
			4:
				var pending := 0
				for node in track.nodes:
					if is_instance_valid(node) and not node.is_queued_for_deletion():pending+=1
				if pending==0:track.phase=5
			5:track.ticks=int(track.age)
	track.owner._source_palette_banks[track.palette_key]={"alpha_a":track.alpha_a,"alpha_b":track.alpha_b,"phase":track.phase}
	if track.age>=track.ticks:track.owner._source_palette_banks.erase(track.palette_key)

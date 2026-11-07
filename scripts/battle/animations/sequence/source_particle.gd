extends RefCounted
class_name BattleSourceParticle
## Source-identified reusable arc, directed linear, orbit and affine-sheet poses.
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

static func update(track: Dictionary) -> void:
	# Drop invalid execution-bound ghost targets before any pose/frame/affine write.
	# The normal runner owns removal and barrier advancement; no global cancellation.
	if not BattleGhostContract.bound_identity_present(track):return
	if not BattleElectricContract.bound_identity_present(track):return
	if not BattleStateProps.bound_identity_present(track):return
	var node: Sprite2D = track.node
	var settings: Dictionary = track.settings
	var age := maxi(0, int(track.age))
	if track.age < 0:
		node.visible = false
		return
	node.visible = true
	var commands: Array = settings.frame_commands
	var remaining := maxi(0,age-int(settings.get("frame_pause_ticks",0)))
	if bool(settings.get("frame_loop", false)):
		var length := 0
		for command in commands: length += int(command.ticks)
		remaining %= maxi(1,length)
	var selected: Dictionary = commands.back()
	for command in commands:
		selected = command
		if remaining < int(command.ticks): break
		remaining -= int(command.ticks)
	if settings.has("frame_program"):
		var program: Array = settings.frame_program
		if settings.has("side_frame_programs"):
			program = settings.side_frame_programs["player" if track.source_side==0 else "opponent"]
		selected = BattleSourceCommandProgram.evaluate(program,age).frame
	selected = BattlePlantActor.frame_pose(track, selected)
	selected = BattleElectricContract.frame_pose(track, selected)
	selected = BattleChargeContract.frame_pose(track, selected)
	selected = BattleStateProps.frame_pose(track, selected)
	selected = BattleContactSelected.frame_pose(track, selected)
	var rect: Array = settings.frame_rects[str(int(selected.tile))]
	node.region_rect = Rect2(rect[0],rect[1],rect[2],rect[3])
	node.flip_h = bool(settings.get("flip_h",false)) != bool(selected.get("flip_h",false))
	node.flip_v = bool(settings.get("flip_v",false)) != bool(selected.get("flip_v",false))
	var progress := clampf(float(age-int(settings.get("travel_delay",0)))/maxi(1,int(settings.get("travel_ticks",track.ticks))),0,1)
	node.rotation = float(settings.get("initial_rotation",0.0))
	BattlePostPsychic.particle_pose(track)
	match str(settings.get("mode","static")):
		"stomp":
			var phase := clampf(float(age-int(settings.hold_ticks))/int(settings.travel_ticks),0,1)
			node.position = track.origin.lerp(track.destination,phase)
		"brace_flame":
			var rise := 0
			var counter := 0
			for tick in age:
				counter += 1
				if counter>int(settings.rise_interval):
					counter = 0
					rise += 1
				rise += counter
			node.position = track.origin+Vector2(0,-rise)
		"glitter":
			node.position = track.origin+Vector2(floorf(age*float(settings.x_speed)/256.0),floorf(age*float(settings.y_speed)/256.0))
		"palette_wall":
			var amount := mini(age+1,13) if age<14 else 13 if age<46 else maxi(0,13-(age-46))
			node.modulate.a = amount/16.0
			var cycle := ((clampi(age-14,0,32)/int(settings.palette_cycle_interval))%int(settings.palette_cycle_count))
			node.region_rect.position.y += cycle*int(settings.palette_cycle_height)
		"single_sine_crossing":
			node.position = source_arc(track,age,true)
			var phase := ((age*(32768/int(settings.travel_ticks)))>>8)&255
			if bool(track.get("ally_crossing",false)) and age>=2*int(settings.travel_ticks):
				node.visible = age%2==0
				if age>=2*int(settings.travel_ticks)+29:track.ticks = age
			if node.position.x>track.field_size.x+16 or node.position.x< -16 or node.position.y>track.field_size.y or node.position.y< -16:
				track.ticks = age
		"source_beam":
			var phase := int(settings.get("source_phase",0))
			var amplitude := float(settings.amplitude)
			if phase > 127:
				phase -= 127
				amplitude *= -1
			var accumulated := phase + age * (210.0/30.0)
			node.position = track.origin.lerp(track.destination,progress)
			node.position.y += sin(accumulated*TAU/256.0)*amplitude
		"ellipse_bubble":
			var initial := float(settings.angle)*TAU/256.0
			var phase := initial + mini(age,int(settings.travel_ticks))*float(settings.angle_step)*TAU/256.0
			var radius: Array = settings.ellipse
			var direction := 1.0 if track.source_side==0 else -1.0
			node.position = track.origin.lerp(track.destination,progress) + Vector2((sin(phase)-sin(initial))*radius[0]*direction,(cos(phase)-cos(initial))*radius[1])
		"powder_drift":
			var direction := 1.0 if track.source_side==0 else -1.0
			var phase := (maxi(0,age-1)*int(settings.angle_step)) & 255
			node.position = track.origin + Vector2(floorf(sin(phase*TAU/256.0)*float(settings.amplitude)*direction),floorf(maxi(0,age-1)*float(settings.vertical_speed)/256.0))
		"jaw":
			var half := int(settings.half_ticks)
			var count := mini(age,half) if age<=half else maxi(0,half-(age-half))
			var velocity: Array = settings.velocity
			node.position = track.origin + Vector2(floorf(count*float(velocity[0])/256.0),floorf(count*float(velocity[1])/256.0))
		"falling_rock":
			# Source helper executes immediately, holds at callback transition, then
			# starts phase192 with a shifted base; it is NOT a gravity parabola.
			var phase_age := mini(age,15)
			var phase := phase_age*4
			if age<17:
				node.position = track.origin+Vector2(0,cos(phase*TAU/256.0)*-70)
			else:
				phase = 192+mini(age-17,31)*4
				node.position = track.origin+Vector2(float(settings.rock_shift)+sin(phase*TAU/256.0)*float(settings.rock_shift),cos(phase*TAU/256.0)*-24)
		"spiral_rise":
			node.position = track.origin + Vector2(sin(age*float(settings.angle_step)*TAU/256.0)*float(settings.amplitude),-floorf((age+(1 if settings.get("source_rise_initial_tick",false) else 0))*float(settings.rise)))
		"snow_swirl":
			var values: Array = settings.snow_direction
			var direction := Vector2(float(values[0]),float(values[1]))
			var entrance: Vector2 = track.origin-direction*90
			var arrival := int(settings.arrival_ticks)
			if age < arrival:
				node.position = entrance.lerp(track.destination,float(age)/arrival)
			elif age <= arrival+32:
				var phase := (age-arrival)*16*TAU/256.0
				node.position = track.destination+Vector2(sin(phase)*20*(1 if track.source_side==0 else -1),(1-cos(phase))*15)
			else:
				node.position = track.destination+direction*(age-arrival-32)*float(settings.speed)
		"snow_crossing":
			var direction: Vector2 = (track.destination-track.origin).normalized()
			var entrance: Vector2 = track.origin-direction*90
			node.position = entrance+direction*age*float(settings.speed)
			node.position.y += sin(age*float(settings.angle_step)*TAU/256.0)*float(settings.amplitude)
		"pulse_spray":
			var direction: Vector2 = track.destination-track.origin
			var center: Vector2 = track.origin.lerp(track.destination,float(settings.pulse_fraction))
			var perpendicular := Vector2(-direction.y,direction.x).normalized()*float(settings.spread_sign)
			node.position = center+perpendicular*(float(settings.spread)+age*2)
		"hail":
			node.position = track.destination if age>=int(track.ticks) else track.origin+Vector2(4,8)*age
		"arc", "missile_arc", "linear", "dirt_scatter":
			node.position = track.origin.lerp(track.destination,progress)
			if settings.mode in ["arc","missile_arc"]:
				if bool(settings.get("source_fixed_arc",false)):
					node.position = source_arc(track,age)
				else: node.position.y += sin(progress*PI)*float(settings.arc)
			if settings.mode=="missile_arc":
				node.visible = age>0
				var tangent := source_arc(track,mini(age+1,int(settings.travel_ticks)))-node.position
				if not tangent.is_zero_approx():node.rotation = tangent.angle()+PI/2
		"bubble_rise":
			node.position = track.origin + Vector2(sin(((age*11)&255)*TAU/256.0)*4,-floorf(age*48.0/256.0))
		"orbit":
			var angle := (int(settings.angle)+age*int(settings.angle_step)) & 255
			var radians := angle * TAU / 256.0
			node.position = track.origin + Vector2(sin(radians),cos(radians))*float(settings.radius)
			var divisor := int(settings.blink_divisor)
			if divisor > 0:
				# Source toggles only when the NEXT angle is divisible, not every frame.
				var toggles := 0
				for index in age+1:
					if ((int(settings.angle)+(index+1)*int(settings.angle_step)) & 255) % divisor == 0: toggles += 1
				node.visible = toggles % 2 == 0
	BattlePlantActor.particle_pose(track)
	BattleSoundOwnership.particle_pose(track)
	BattleGhostContract.particle_pose(track)
	BattleElectricContract.particle_pose(track)
	BattleChargeContract.particle_pose(track)
	if settings.has("rotation_step"):
		node.rotation = float(age*int(settings.rotation_step))*TAU/256.0
	var matrix := Vector2(256,256)
	match str(settings.get("affine","")):
		"bubble_squish":
			var phase := age%12
			var delta := mini(phase,12-phase)*16
			matrix = Vector2(256-delta,256+delta)
		"ice_growth":
			matrix = Vector2.ONE*(206+mini(age,10)*5)
		"whirlpool_squish":
			var phase := age%10
			matrix = Vector2(192+mini(phase,10-phase)*2,192-mini(phase,10-phase)*3)
		"shock_pulse":
			var phase := age%20
			matrix = Vector2.ONE*(232-mini(phase,20-phase)*8)
	if settings.has("affine_commands"):
		var affine_remaining := age
		var angle := 0.0
		for command in settings.affine_commands:
			var duration := int(command.ticks)
			if duration == 0:
				matrix = Vector2(command.x,command.y)
				angle = float(command.rotation)
			else:
				var applied := mini(affine_remaining,duration)
				matrix += Vector2(command.x,command.y)*applied
				angle += float(command.rotation)*applied
				affine_remaining -= applied
				if affine_remaining <= 0: break
		node.rotation = angle*TAU/256.0
	if settings.has("affine_program") and (not settings.affine_program.is_empty() or settings.has("replacement_affine_program")):
		var affine: Array = settings.affine_program
		if settings.has("side_affine_programs"):affine = settings.side_affine_programs["player" if track.source_side==0 else "opponent"]
		var affine_age := age
		if bool(settings.get("pause_affine_during_travel", false)):
			affine_age = maxi(0, age - int(settings.travel_ticks) - 1)
		if settings.has("replacement_affine_program") and age>=int(settings.frame_transition_ticks):
			affine = settings.replacement_affine_program
			affine_age -= int(settings.frame_transition_ticks)
		var pose := BattleSourceCommandProgram.evaluate(affine,affine_age,true)
		matrix = pose.matrix
		if not bool(settings.get("tangent_rotation",false)) and str(settings.get("mode",""))!="horn_approach":
			node.rotation = float(pose.rotation)*TAU/256.0
	if settings.get("affine_parameter_units","")=="source_scale":
		var converted: Dictionary=BattleSourceCommandProgram.source_scale_pose_to_oam({"matrix":matrix,"rotation":node.rotation*256.0/TAU})
		if converted.is_empty():
			node.visible=false;track.ticks=age # Unsupported explicit units fail closed.
			return
		matrix=converted.matrix
	node.scale = Vector2(256.0/(matrix.x if absf(matrix.x)>0.001 else 1.0),256.0/(matrix.y if absf(matrix.y)>0.001 else 1.0))*float(settings.get("scale_factor",1.0))
	if settings.has("blink_interval") and age >= int(settings.get("blink_after",0)):
		node.visible = ((age-int(settings.get("blink_after",0)))/maxi(1,int(settings.blink_interval)))%2 == 0
	BattleStateProps.particle_pose(track)
	BattleContactSelected.particle_pose(track)

static func source_arc(track: Dictionary, age: int, continue_motion: bool = false) -> Vector2:
	var duration := maxi(1,int(track.settings.travel_ticks))
	var count := age if continue_motion else mini(age,duration)
	var delta: Vector2 = track.destination-track.origin
	# Ruby encodes sign in bit0 of the unsigned 8.8 step.
	var x_step := int(absf(delta.x)*256)/duration
	var y_step := int(absf(delta.y)*256)/duration
	x_step = (x_step | 1) if delta.x<0 else (x_step & ~1)
	y_step = (y_step | 1) if delta.y<0 else (y_step & ~1)
	var offset := Vector2(floorf(count*x_step/256.0)*( -1 if delta.x<0 else 1),floorf(count*y_step/256.0)*(-1 if delta.y<0 else 1))
	var phase := ((count*(32768/duration)) >> 8) & 255
	offset.y += floorf(sin(phase*TAU/256.0)*float(track.settings.arc))
	return track.origin+offset

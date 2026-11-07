extends RefCounted
class_name BattleSourceChoreography
## Explicit source actor callback continuations; no gameplay mutation.
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

static func actor_pose(track: Dictionary) -> Dictionary:
	var settings: Dictionary = track.settings
	var age := int(track.age)
	var direction := 1.0 if track.actor.side==0 else -1.0
	var result := {"offset":Vector2.ZERO,"scale":Vector2.ONE,"rotation":0.0,"hold_rotation":false}
	match str(settings.motion):
		"roar_exit":
			var speed := int(settings.exit_speed) * (1 if int(settings.target_side) != 0 else -1)
			result.offset = track.initial + Vector2(age * speed,0)
			result.hold_offset = true
			var x := int(settings.source_base_x) + int(result.offset.x)
			if ((x + 32) & 65535) > int(settings.get("exit_limit",304)): track.ticks = age
		"howl_affine":
			var pose := BattleSourceCommandProgram.evaluate(settings.affine_program,age,true)
			result.scale = Vector2(256.0/pose.matrix.x,256.0/pose.matrix.y)
			# Native track age1 is the first private callback (source counter0).
			if age >= 21 and age < 44:
				var changes := (age - 20) / 2
				result.offset.x = 0.0 if changes == 0 else 1.0 if changes % 2 else -1.0
		"headbutt":
			var phase := int(settings.headbutt_phase)
			if phase==0:
				result.offset = Vector2(-2*mini(age,6)*direction,0)
				result.rotation = -mini(maxi(age-7,0),4)*768*direction*TAU/65536.0
			elif phase==1:
				result.offset = track.initial+Vector2(3*mini(age,4)*direction,0)
				result.rotation = -3072*direction*TAU/65536.0
			else:
				result.offset = track.initial
				result.rotation = (-3072+mini(maxi(age-9,0),3)*1024)*direction*TAU/65536.0
			result.hold_rotation = true
		"source_heart_tilt":
			var args: Array=settings.source_args
			var half: int=8-2*int(args[2]);var duration: int=4*half*int(args[1])
			if age<=duration:
				var phase: int=(age-1)%(4*half)+1
				var count: int=phase if phase<=half else 2*half-phase if phase<=3*half else phase-4*half
				var angle: int=-count*(256+128*int(args[2]))*int(direction)
				result.offset=Vector2(track.initial.x+count*(int(args[2])+2)*direction,absi(BattleSourceTrig.sine((angle&65535)>>8,256))>>3)
				result.rotation=-angle*TAU/65536.0
			else:result.offset=Vector2(track.initial.x,0)
		"source_tilt":
			var half := int(settings.tilt_ticks)
			var count := mini(age,half)
			if int(settings.tilt_mode)==1:count += half
			elif int(settings.tilt_mode)==2 and age>half:count = maxi(0,2*half-age)
			result.rotation = -count*int(settings.rotation_step)*direction*TAU/65536.0
			if int(settings.tilt_mode)==1 and age>=half:result.rotation = 0.0
			result.offset = track.initial
			result.hold_rotation = true
		"shadow_dash":
			var count := mini(age,5) if age<=5 else 10-age if age<9 else 0
			result.offset = Vector2(count*8*direction,0)
		"teleport":
			var pose := BattleSourceCommandProgram.evaluate(settings.affine_program,mini(age,20),true)
			result.scale = Vector2(256.0/pose.matrix.x,256.0/pose.matrix.y)
			var rises := 8 if track.actor.side==0 else 4
			result.offset = Vector2(0,-8*clampi(age-20,0,rises))
			result.hidden = age>20+rises
		"source_affine_repeat":
			var pose := BattleSourceCommandProgram.evaluate(settings.affine_program,age%int(settings.cycle_ticks),true)
			result.scale = Vector2(256.0/pose.matrix.x,256.0/pose.matrix.y)
		"source_startle":
			if age<=20:
				var count: int=age if age<=10 else 20-age
				var matrix:=Vector2(256+10*count,256-13*count)
				result.scale=Vector2(256.0/matrix.x,256.0/matrix.y)
				var height: int=int(settings.source_height)
				result.offset=Vector2(-4 if age%2 else 4,int((height-mini(128,int(height*256/matrix.y)))/2))
		"source_affine":
			var pose := BattleSourceCommandProgram.evaluate(settings.affine_program,age,true)
			result.scale = Vector2(256.0/pose.matrix.x,256.0/pose.matrix.y)
			if str(settings.get("source_pivot", "")) == "feet":
				result.offset.y = (1.0 - result.scale.y) * track.actor.sprite.get_rect().end.y
		"power_shake":
			var args: Array = settings.source_args
			var magnitude := int(settings.get("source_magnitude",12))/12
			magnitude = clampi(magnitude,1,16)
			var count := age/(int(args[1])+1)
			if age<int(track.ticks):
				result.offset = Vector2((ceili(magnitude/2.0) if count%2 else -floori(magnitude/2.0)) if int(args[3]) else 0,magnitude if int(args[4]) and count%2 else 0)
		"decaying_quake":
			var args: Array = settings.source_args
			var amplitude := int(args[1])+3 if int(args[1]) else 13
			var beat := age/2
			if beat<int(args[2]):
				result.offset.x = (amplitude if beat%2==0 else -amplitude) if settings.field_shake else (ceili(amplitude/2.0) if beat%2==0 else -floori(amplitude/2.0))
			else:
				amplitude = maxi(0,amplitude-1-(beat-int(args[2]))/4)
				var parity := (beat-int(args[2]))%2
				result.offset.x = (amplitude if parity==0 else -amplitude) if settings.field_shake else (ceili(amplitude/2.0) if parity==0 else -floori(amplitude/2.0))
	return result

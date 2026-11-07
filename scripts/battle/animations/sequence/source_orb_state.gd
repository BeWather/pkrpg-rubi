extends RefCounted
class_name BattleOrbState
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

static func create(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Array[Dictionary]:
	var resolved: Array[BattleAnimationActor]=context.resolve("attacker")
	if resolved.is_empty():return []
	var binding: Dictionary=step.duplicate(true)
	binding.behavior="source_particle"
	# Callback pauses the selected affine after its initial half-size matrix.
	if bool(binding.affine_paused):binding.affine_program=binding.affine_program.slice(0,1)
	var tracks: Array[Dictionary]=BattleEffectBehaviorRegistry.factories().source_particle.call(binding,context,owner)
	for track: Dictionary in tracks:
		track.bound_actor=resolved[0]
		track.source_owner=owner
		track.source_context=context
		track.actor_center=resolved[0].anchor(owner,"center")
		if str(binding.mode)=="stockpile_inhale":track.destination=track.actor_center
		if str(binding.mode)=="spit_out":
			track.source_duration=int(owner._source_args.get(1,binding.source_args[1] if binding.source_args.size()>1 else 0))
			track.ticks=track.source_duration+1
		track.update=update
		update(track,context)
	return tracks

static func update(track: Dictionary, _context: BattleAnimationContext) -> void:
	var age: int=maxi(0,int(track.age))
	var actor: BattleAnimationActor=track.bound_actor
	if not actor.is_present():track.node.visible=false;track.ticks=age;return
	BattleSourceParticle.update(track)
	var settings: Dictionary=track.settings
	var args: Array=settings.source_args
	if str(settings.mode)=="hidden_fast":
		var duration: int=int(args[0])
		var count: int=mini(age,duration)-clampi(age-duration,0,duration)
		var phase: int=(int(args[1])+age*9)&255
		track.node.position=track.origin+Vector2(BattleSourceTrig.sine(phase,count*4),BattleSourceTrig.cosine(phase,count))
		track.radius_x=(mini(age+1,duration)-clampi(age+1-duration,0,duration))*1024
		track.radius_y=int(track.radius_x)/4
		track.node.z_index=BattleSourcePriority.relative_layer(actor,1 if phase>=64 and phase<=191 else -1,track.source_context,track.source_owner)
		# The contracting-phase transition returns before checking mutable ARG7.
		if age!=duration*2-1 and int(track.source_owner._source_args.get(7,0))==65535:track.ticks=age
	elif str(settings.mode) in ["hidden_scatter","spit_out"]:
		var velocity:=Vector2(BattleSourceTrig.sine(int(args[0]),10),BattleSourceTrig.cosine(int(args[0]),7))
		track.node.position=track.origin+velocity*age
		if str(settings.mode)=="hidden_scatter":
			var position: Vector2=track.node.position
			var bounds: Vector2=track.field_size
			if position.x< -16 or position.x>bounds.x+16 or position.y< -16 or position.y>bounds.y:track.ticks=age
	elif str(settings.mode)=="stockpile_inhale":
		track.node.position=BattleGhostContract._linear_translation(track.origin,track.destination,age+1,int(settings.travel_ticks))
	elif str(settings.mode)=="swallow_bounce":
		var displacement:=0
		for index in age:displacement-=(int(settings.vertical_velocity)+index*int(settings.vertical_acceleration))>>8
		track.node.position=track.origin+Vector2(0,displacement)
		if track.node.position.y>track.actor_center.y:track.ticks=age

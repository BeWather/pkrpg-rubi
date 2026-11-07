extends RefCounted
class_name BattleContactSelected
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Source H1 particle snapshots. No combat state or actor property writes.
static func prepare(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Dictionary:
	if str(step.get("source_module",""))!="contact_selected":return step
	var settings: Dictionary=step.duplicate(true)
	var args: Array=settings.source_args
	if str(settings.mode)=="h_revenge":
		# Createsprite writes only the supplied operands. ARG2 is a live source ABI
		# value left by the previous task, not an invented missing-argument zero.
		var mode: int=int(owner._source_args.get(2,0)) if owner is BattleAnimationSequenceRunner else 0
		settings.selector="attacker" if mode==0 else "target"
		var selected: Array[BattleAnimationActor]=context.resolve("attacker")
		if not selected.is_empty():
			var key: String="contest" if context.contest else "player" if selected[0].side==0 else "opponent"
			settings.frame_program=settings.h_frame_programs[key]
	elif str(settings.mode)=="h_knock_off":
		var targets: Array[BattleAnimationActor]=context.resolve("target")
		if not targets.is_empty():
			settings.offset=[-int(args[0]) if targets[0].side==0 else int(args[0]),int(args[1])]
			if settings.has("h_affine_programs"):settings.affine_program=settings.h_affine_programs["player" if targets[0].side==0 else "opponent"]
	return settings

static func initialize(track: Dictionary, context: BattleAnimationContext) -> void:
	if str(track.settings.get("source_module",""))!="contact_selected":return
	var targets: Array[BattleAnimationActor]=context.resolve("target")
	track.h_target_side=targets[0].side if not targets.is_empty() else 1
	if str(track.settings.mode)=="h_waves":
		track.settings.frame_loop=true
		# frame_program evaluation has no implicit repeat: source callback restarts it.
		track.h_cycle_ticks=0
		for command: Dictionary in track.settings.frame_commands:track.h_cycle_ticks+=int(command.ticks)

static func frame_pose(track: Dictionary, selected: Dictionary) -> Dictionary:
	if str(track.settings.get("source_module",""))!="contact_selected":return selected
	if str(track.settings.mode)=="h_waves":return BattleSourceCommandProgram.evaluate(track.settings.frame_program,int(track.age)%maxi(1,int(track.h_cycle_ticks))).frame
	return selected

static func particle_pose(track: Dictionary) -> void:
	if str(track.settings.get("source_module",""))!="contact_selected":return
	var age: int=maxi(0,int(track.age))
	var settings: Dictionary=track.settings
	var args: Array=settings.source_args
	var node: Sprite2D=track.node
	match str(settings.mode):
		"h_dizzy":
			var count: int=maxi(0,age-1)
			var phase: int=count*3
			node.position=track.origin+Vector2(floorf(age*float(args[2])/256.0),BattleSourceTrig.sine(phase,int(args[3]))) if age>0 else track.origin
			if age*3>100:node.visible=(age*3)%2==0
		"h_cross_chop":
			var direction: int=-1 if int(args[2])==0 else 1
			var progress: float=float(mini(age,30))/30.0 if age<=41 else 1.0-float(mini(age-41,8))/8.0
			node.position=track.origin+Vector2(direction*20,-20)*progress
		"h_knock_off":
			if age>0:
				var phase: int=(192+age*(-11 if int(track.get("h_target_side",1))==0 else 11))&255
				node.position=track.origin+Vector2(BattleSourceTrig.sine(phase+64,20),BattleSourceTrig.sine(phase,20))

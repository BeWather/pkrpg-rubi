extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Exact shared IMPACT/ShakeMon; Tackle alone has the hidden horizontal control sprite.
const Bird=preload("res://scripts/battle/animations/sequence/source_bird_horn_owned.gd")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if s.behavior=="source_pound_tackle_lunge":
		var actors: Array[BattleAnimationActor]=c.resolve("attacker")
		if actors.is_empty():return []
		var actor: BattleAnimationActor=actors[0];var initial: Vector2=owner.get_actor_offset(actor.id)
		return [{"kind":"source_pound_tackle_lunge","settings":s,"original_actor":actor,"owner":owner,"age":0,"ticks":12,"remaining":4,"direction":4 if actor.side==0 else -4,"offset":initial,"phase":0,"update":advance_lunge}]
	var tracks: Array[Dictionary]=Bird.create(s,c,owner)
	for t: Dictionary in tracks:
		if s.behavior=="source_pound_tackle_hit":
			# CreateSpriteAndAnimate immediately runs BeginAffineAnim: variant2
			# command176 becomes ConvertScaleParam(65536/176) before ObjAffineSet.
			# Native logical scale176/256 projects that inverse hardware matrix.
			var pose: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.affine_program,0,true);t.scale=Vector2(float(pose.matrix.x)/256,float(pose.matrix.y)/256);t.rotation=-float(pose.rotation)*TAU/256;Bird._paint(t,c);BattleCounterSelected._blend_node(t.node,owner)
		else:
			# ShakeMon writes its initial x2/y2 BEFORE synchronous Step decrements
			# delay1. Keep that real first pose, not only its later toggles.
			Bird._offset(t,t.offset);t.update=advance_shake;_project_shake(t,c)
	return tracks
static func _project_shake(t: Dictionary,c: BattleAnimationContext) -> void:
	if not t.selected.is_present():return
	# Shared maintenance sees the previous actor pose. This source task must
	# project its new x2/y2 into the ACTUAL opaque BG copy during this callback.
	var base: Vector2=t.owner.to_local(c.field.to_global(BattleElectricContract.source_anchor(t.selected,c,"origin")))
	for bg: Dictionary in t.owner.get_meta("source_counter_monbg",[]):
		for clone: Dictionary in bg.clones:
			if clone.actor==t.selected and is_instance_valid(clone.node):clone.node.position=base+t.offset
static func advance_shake(t: Dictionary,c: BattleAnimationContext) -> void:
	Bird.advance(t,c);_project_shake(t,c)
static func advance_lunge(t: Dictionary,_c: BattleAnimationContext) -> void:
	if not t.original_actor.is_present():t.ticks=int(t.age);return
	if int(t.remaining)>0:
		t.remaining=int(t.remaining)-1;t.offset+=Vector2(int(t.direction),0);t.owner._held_offsets[t.original_actor.id]=t.offset
	elif int(t.phase)==0:t.phase=1 # stored callback transfer, no displacement
	elif int(t.phase)==1:t.phase=2;t.direction=-int(t.direction);t.remaining=4 # Reverse callback, also no displacement
	elif int(t.phase)==2:t.phase=3 # stored Destroy transfer
	else:t.ticks=int(t.age)

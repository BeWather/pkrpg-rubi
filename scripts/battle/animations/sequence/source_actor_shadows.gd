extends RefCounted
class_name BattleActorShadows
## Execution-owned source clones and actor matrices; never domain state.
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

static func create(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Array[Dictionary]:
	var resolved: Array[BattleAnimationActor]=context.resolve(str(step.get("selector","attacker")))
	# Identity may disappear during a scheduling gap before the first callback.
	# No child/controller exists yet: let the real program barrier drain normally.
	if resolved.is_empty():return []
	var actor: BattleAnimationActor=resolved[0]
	var container:=Node2D.new()
	owner.add_child(container)
	var track: Dictionary={"kind":"source_actor_shadows","age":0,"ticks":int(step.ticks),"actor":actor,"node":container,"settings":step.duplicate(true),"owner":owner,"clones":[],"matrix":256,"phase":0,"count":0,"cycles":0,"source_subpriority":0,"base_scale":actor.sprite.global_scale/owner.global_scale,"base_origin":actor.anchor(owner,"origin"),"feet":actor.sprite.get_rect().end.y*actor.sprite.scale.y,"angle":0,"hold":0}
	if str(step.mode)=="double_team":
		for phase in [0,128]:_clone(track,phase,256,0)
		actor.apply_source_state("hidden",true)
	return [track]

static func identity_present(track: Dictionary) -> bool:
	if track.actor.is_present():return true
	track.node.visible=false
	track.ticks=int(track.age)
	return false

static func _clone(track: Dictionary, phase: int, matrix: int, rank: int) -> void:
	var actor: BattleAnimationActor=track.actor
	var node:=Sprite2D.new()
	node.texture=actor.sprite.texture
	node.centered=actor.sprite.centered
	node.offset=actor.sprite.offset
	node.hframes=actor.sprite.hframes
	node.vframes=actor.sprite.vframes
	node.frame=actor.sprite.frame
	node.region_enabled=actor.sprite.region_enabled
	node.region_rect=actor.sprite.region_rect
	node.flip_h=actor.sprite.flip_h
	node.flip_v=actor.sprite.flip_v
	node.position=actor.anchor(track.owner,"origin")
	node.scale=track.base_scale*256.0/matrix
	node.rotation=actor.sprite.global_rotation-track.owner.global_rotation
	node.z_index=BattleSourcePriority.actor_layer(actor,track.owner)+rank
	var material:=ShaderMaterial.new()
	material.shader=load("res://scripts/battle/animations/sequence/source_local_ab.gdshader")
	var double_team:=str(track.settings.mode)=="double_team"
	material.set_shader_parameter("eva",12.0/16 if double_team else 10.0/16)
	material.set_shader_parameter("evb",8.0/16)
	material.set_shader_parameter("first_tint",Vector3.ONE*(5.0/16 if double_team else 1.0))
	node.material=material
	track.node.add_child(node)
	track.clones.append({"node":node,"phase":phase,"born":int(track.age),"matrix":matrix})

static func pose(track: Dictionary) -> Dictionary:
	var age:=int(track.age)
	var mode:=str(track.settings.mode)
	var scale:=1.0
	var offset:=Vector2.ZERO
	var rotation:=0.0
	if mode=="double_team":
		var index:=age/2
		for clone: Dictionary in track.clones:
			if index>64:clone.node.visible=false;continue
			var table:=BattleSourceTrig.sine(index,256)
			clone.phase=(int(clone.phase)+table/13)&255
			clone.node.position=track.base_origin+Vector2(BattleSourceTrig.sine(clone.phase,table/6),0)
		if index>64:
			track.actor.apply_source_state("hidden",false)
			track.ticks=age
	elif mode=="minimize":
		for clone: Dictionary in track.clones.duplicate():
			if age-int(clone.born)>=16:clone.node.queue_free();track.clones.erase(clone)
		match int(track.phase):
			0:
				if int(track.count) in [0,3,6]:_clone(track,0,int(track.matrix),int(track.source_subpriority));track.source_subpriority+=1
				track.count+=1
				track.matrix+=40
				if int(track.count)==32:track.cycles+=1;track.phase=1
			1:
				if track.clones.is_empty():
					track.count=0
					if int(track.cycles)==3:track.phase=3
					else:track.matrix=256;track.source_subpriority=0;track.phase=2
			2:track.phase=0
			3:
				track.count+=1
				if int(track.count)>32:track.count=0;track.phase=4
			4:
				track.count+=2
				track.matrix-=80
				if int(track.count)==32:track.phase=5
			5:track.matrix=256;track.ticks=age
		scale=256.0/int(track.matrix)
		offset.y=float(track.feet)*(1.0-scale)
	else:
		rotation=float(track.angle)*(1 if track.actor.side==1 else -1)*TAU/65536.0
		if int(track.phase)==0:
			track.angle+=176
			if int(track.angle)==3872:track.phase=1
		elif int(track.phase)==1:
			track.hold+=1
			if int(track.hold)==30:track.phase=2
		else:
			track.angle-=176
			if int(track.angle)==0:track.ticks=age;rotation=0.0
		offset.y=floorf(absf(sin(rotation))*32.0)
	return {"scale":Vector2.ONE*scale,"offset":offset,"rotation":rotation}

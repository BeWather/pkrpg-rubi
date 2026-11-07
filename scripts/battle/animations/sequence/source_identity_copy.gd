extends RefCounted
class_name BattleIdentityCopy
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Bound appearance copies and task matrices; no party/database mutations.
static func create(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Array[Dictionary]:
	var mode: String=str(step.mode)
	if mode in ["mimic_bg_alpha","mimic_bg_clear"]:
		var bg: Dictionary=owner.get_meta("source_mimic_bg",{})
		if mode=="mimic_bg_clear" and not bg.is_empty():bg.ticks=int(bg.age)+2
		if mode=="mimic_bg_alpha":
			owner.set_meta("source_mimic_alpha",step.blend_pair.duplicate())
			for active: Dictionary in owner._tracks:
				if active.has("material_lease") and active.material_lease.owns_current():
					active.material_lease.material.set_shader_parameter("eva",float(step.blend_pair[0])/16)
					active.material_lease.material.set_shader_parameter("evb",float(step.blend_pair[1])/16)
		return [{"kind":"source_identity_copy","age":0,"ticks":int(step.ticks),"settings":step,"update":update}]
	if mode=="mimic_bg":
		var bg_actors: Array[BattleAnimationActor]=[]
		for actor: BattleAnimationActor in context.resolve("source_target_and_partner_visual_center"):
			# IsAnimBankSpriteVisible: contest exposes only its attacker bank;
			# normal battles independently test the primary and its partner.
			if actor.sprite.is_visible_in_tree() and (not context.contest or actor.id==context.attacker_id):bg_actors.append(actor)
		if bg_actors.is_empty():return []
		var container:=Node2D.new()
		owner.add_child(container)
		var track: Dictionary={"kind":"source_identity_copy","domain":"maintenance","age":0,"ticks":int(step.ticks),"node":container,"settings":step.duplicate(true),"clones":[],"update":update}
		for actor: BattleAnimationActor in bg_actors:
			var node: Sprite2D=clone_sprite(actor,owner)
			node.z_index=BattleSourcePriority.relative_layer(actor,1,context,owner)
			container.add_child(node)
			track.clones.append({"node":node,"actor":actor})
		owner.set_meta("source_mimic_bg",track)
		return [track]
	var targets: Array[BattleAnimationActor]=context.resolve("target")
	if targets.is_empty():return []
	var target: BattleAnimationActor=targets[0]
	if mode=="mimic_target":
		if not target.sprite.is_visible_in_tree():return []
		# PrepareBattlerSpriteForRotScale(...,1) sets OBJ_BLEND. Static monBG
		# copies are opaque second targets, not the first alpha consumers.
		var material: ShaderMaterial=blend_material(false)
		var pair: Array=owner.get_meta("source_mimic_alpha",[16,0])
		material.set_shader_parameter("eva",float(pair[0])/16)
		material.set_shader_parameter("evb",float(pair[1])/16)
		var lease: BattleOwnedMaterialLease=BattleOwnedMaterialLease.attach(target,material)
		return [{"kind":"source_copy_actor","age":0,"ticks":int(step.ticks),"actor":target,"settings":step.duplicate(true),"owner":owner,"released":-1,"feet":target.sprite.get_rect().end.y*target.sprite.scale.y,"material_lease":lease,"cleanup":lease.release}]
	var attackers: Array[BattleAnimationActor]=context.resolve("attacker")
	if attackers.is_empty():return []
	var attacker: BattleAnimationActor=attackers[0]
	if mode=="mimic_orb":
		var binding: Dictionary=step.duplicate(true)
		binding.behavior="source_particle"
		binding.offset=[-int(step.offset[0]) if target.side==0 else int(step.offset[0]),int(step.offset[1])]
		if target.side==0:owner._source_args[0]=binding.offset[0]
		var tracks: Array[Dictionary]=BattleEffectBehaviorRegistry.factories().source_particle.call(binding,context,owner)
		for track: Dictionary in tracks:
			track.bound_attacker=attacker;track.bound_target=target;track.copy_owner=owner;track.released=false
			track.update=update
			update(track,context)
		return tracks
	if mode=="role_silhouette":
		var node: Sprite2D=clone_sprite(target,owner)
		var view: String="back" if attacker.side==0 or context.contest else "front"
		var views: Dictionary=context.source_appearance_views.get(target.id,{})
		if views.get(view) is Texture2D:
			node.texture=views[view];node.hframes=1;node.vframes=1;node.frame=0;node.region_enabled=false
		var offset: int=20 if attacker.side==1 or context.contest else -20
		node.position=attacker.anchor(owner,"origin")+Vector2(offset,0)
		node.z_index=BattleSourcePriority.actor_layer(attacker,owner)
		node.material=blend_material(true)
		owner.add_child(node)
		var track: Dictionary={"kind":"source_identity_copy","age":0,"ticks":int(step.ticks),"node":node,"settings":step.duplicate(true),"bound_attacker":attacker,"bound_target":target,"base_scale":node.scale,"material":node.material,"update":update}
		update(track,context)
		return [track]
	return []

static func clone_sprite(actor: BattleAnimationActor, owner: Node2D) -> Sprite2D:
	var node:=Sprite2D.new()
	var source: Sprite2D=actor.sprite
	node.texture=source.texture;node.centered=source.centered;node.offset=source.offset
	node.hframes=source.hframes;node.vframes=source.vframes;node.frame=source.frame
	node.region_enabled=source.region_enabled;node.region_rect=source.region_rect
	node.flip_h=source.flip_h;node.flip_v=source.flip_v
	node.position=actor.anchor(owner,"origin")
	node.scale=source.global_scale/owner.global_scale
	node.rotation=source.global_rotation-owner.global_rotation
	return node

static func blend_material(white: bool) -> ShaderMaterial:
	var material:=ShaderMaterial.new()
	material.shader=load("res://scripts/battle/animations/sequence/source_identity_silhouette.gdshader" if white else "res://scripts/battle/animations/sequence/source_local_ab.gdshader")
	material.set_shader_parameter("eva",0.0 if white else 1.0)
	material.set_shader_parameter("evb",1.0 if white else 0.0)
	return material

static func identity_present(track: Dictionary) -> bool:
	if track.actor.is_present():return true
	track.ticks=int(track.age)
	return false

static func pose(track: Dictionary) -> Dictionary:
	var age: int=int(track.age)
	var scale: float=256.0/(256+mini(age,int(track.settings.source_args[1]))*int(track.settings.matrix_delta))
	var offset:=Vector2(floorf(mini(age,int(track.settings.source_args[1]))*float(track.settings.source_args[0])/256)*(1 if track.actor.side==0 else -1),float(track.feet)*(1-scale))
	if age>int(track.settings.source_args[1]) and int(track.owner._source_args.get(int(track.settings.termination_arg),0))==65535:
		if int(track.released)<0:track.released=age
		track.material_lease.release()
		scale=1;offset=Vector2.ZERO
		if age-int(track.released)>=2:track.ticks=age
	return {"scale":Vector2.ONE*scale,"offset":offset}

static func update(track: Dictionary, _context: BattleAnimationContext) -> void:
	var mode: String=str(track.settings.mode)
	var age: int=int(track.age)
	if mode=="mimic_bg":
		for clone: Dictionary in track.clones:
			if not clone.actor.is_present():clone.node.visible=false
		return
	if mode in ["mimic_bg_alpha","mimic_bg_clear"]:return
	if not track.bound_attacker.is_present() or not track.bound_target.is_present():
		track.node.visible=false;track.ticks=age;return
	if mode=="mimic_orb":
		BattleSourceParticle.update(track)
		track.node.visible=age>0
		if age>=int(track.settings.travel_delay):
			if not bool(track.released):
				track.destination=track.bound_attacker.anchor(track.copy_owner,"center")
				track.released=true
			track.node.position=BattleGhostContract._linear_translation(track.origin,track.destination,age-int(track.settings.travel_delay),int(track.settings.travel_ticks))
	elif mode=="role_silhouette":
		if track.node.material==track.material:
			var eva: int=mini(age/3,10)
			track.material.set_shader_parameter("eva",eva/16.0)
			track.material.set_shader_parameter("evb",(16-eva)/16.0)
		var count: int=clampi(age-30,0,9)
		track.node.scale=track.base_scale*Vector2(256.0/(256-16*count),256.0/(256+128*count))

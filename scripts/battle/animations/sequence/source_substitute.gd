extends RefCounted
class_name BattleSourceSubstitute
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Source doll jump/bounces are presentation, never party/HP authority.
static func create(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Array[Dictionary]:
	var resolved: Array[BattleAnimationActor]=context.resolve("attacker")
	if resolved.is_empty():return []
	var actor: BattleAnimationActor=resolved[0]
	# Native acceptance owns the original appearance, before this deferred
	# factory. A stale/null native guard must not become a new acquisition.
	var native_guard: BattleOwnedAppearanceLease=null
	if bool(owner.get_meta("source_substitute_guard_required",false)) and not owner.has_meta("source_substitute_guard"):return []
	if owner.has_meta("source_substitute_guard"):
		var captured: Variant=owner.get_meta("source_substitute_guard")
		if not captured is BattleOwnedAppearanceLease:return []
		native_guard=captured
		if native_guard.actor.sprite!=actor.sprite or not native_guard.still_bound():return []
	var lease: BattleOwnedAppearanceLease=BattleOwnedAppearanceLease.capture(actor)
	lease.commit_guard=native_guard
	owner._appearance_leases.append(lease)
	var node: Sprite2D=BattleIdentityCopy.clone_sprite(actor,owner)
	node.z_index=BattleSourcePriority.actor_layer(actor,owner);owner.add_child(node)
	actor.apply_source_state("hidden",true)
	return [{"kind":"source_substitute","age":0,"ticks":int(step.ticks),"bound_actor":actor,"node":node,"lease":lease,"owner":owner,"settings":step.duplicate(true),"phase":0,"count":0,"matrix_x":256,"matrix_y":256,"base_scale":node.scale,"gravity":112,"velocity":0,"displacement":Vector2.ZERO,"impacts":0,"selected_view":"","update":update}]

static func update(track: Dictionary, context: BattleAnimationContext) -> void:
	var actor: BattleAnimationActor=track.bound_actor
	if not actor.is_present() or not track.lease.still_bound():
		track.node.visible=false;track.ticks=int(track.age);return
	var node: Sprite2D=track.node
	match int(track.phase):
		0:track.phase=1
		1:
			track.matrix_x+=96;track.matrix_y-=13;track.count+=1
			node.scale=track.base_scale*Vector2(256.0/float(track.matrix_x),256.0/float(track.matrix_y))
			if int(track.count)==9:
				node.scale=track.base_scale;node.visible=false;track.phase=2
		2:
			track.selected_view="back" if actor.side==0 or context.contest else "front"
			node.texture=load(str(track.settings.back_texture if track.selected_view=="back" else track.settings.front_texture))
			node.hframes=1;node.vframes=1;node.frame=0;node.region_enabled=false
			track.lease.replacement={"texture":node.texture,"species":str(actor.sprite.get_meta("animation_species",context.source_appearance_species.get(actor.id,""))),"kind":"substitute","flip_h":node.flip_h}
			track.phase=3
		3:
			track.displacement=Vector2(200,-200);node.visible=true;track.phase=4
		4:
			track.velocity+=int(track.gravity)
			track.displacement.y+=int(track.velocity)>>8
			# Source checks battler origin + y2, not target center/width.
			if actor.anchor(context.field,"origin").y+track.displacement.y>=-32:track.displacement.x=0
			track.displacement.y=minf(0,track.displacement.y)
			if track.displacement.y==0:
				_impact(track);track.velocity-=2048;track.phase=5
		5:
			track.velocity=maxi(0,int(track.velocity)-int(track.gravity))
			track.displacement.y-=int(track.velocity)>>8
			if int(track.velocity)==0:track.phase=6
		6:
			track.velocity+=int(track.gravity);track.displacement.y+=int(track.velocity)>>8
			track.displacement.y=minf(0,track.displacement.y)
			if track.displacement.y==0:
				_impact(track);track.lease.ready=true;track.phase=7;track.count=0;track.domain="maintenance"
		7:
			# Preview survives source end/audio drain until atomic presentation commit.
			track.count+=1
			if int(track.count)>=90 or not track.owner._sounds.any(func(player):return is_instance_valid(player) and player.playing):track.ticks=int(track.age)
	var local_feet: Vector2=Vector2(0,actor.sprite.get_rect().end.y-node.get_rect().end.y)
	node.position=track.owner.to_local(actor.sprite.to_global(local_feet))+track.displacement

static func _impact(track: Dictionary) -> void:
	track.impacts+=1
	track.owner._play_sound(str(track.settings.sound_path),"SOUND_PAN_ATTACKER")

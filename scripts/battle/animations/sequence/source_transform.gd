extends RefCounted
class_name BattleSourceTransform
## Compartida: buffer() lo usan AparienciaNativa y BattleTransformPresentation en producción; la pista de la VM
## legada (create()/update()) está obsoleta. Ver scripts/battle/animations/sequence/README.md.

## Mosaic buffer transition with bound party identity, not copied gameplay data.
## @deprecated: camino de la VM legada; las animaciones nativas no lo usan. Se conserva como referencia y fallback de configuración. Ver scripts/battle/animations/sequence/README.md.
static func create(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Array[Dictionary]:
	var attackers: Array[BattleAnimationActor]=context.resolve("attacker")
	if attackers.is_empty():return []
	var actor: BattleAnimationActor=attackers[0]
	var targets: Array[BattleAnimationActor]=context.resolve("target")
	var restoring: bool=int(step.source_args[0])!=0
	if not restoring and targets.is_empty():return []
	var target: BattleAnimationActor=actor if restoring else targets[0]
	var required: bool=bool(owner.get_meta("source_transform_guard_required",false))
	var guard: BattleOwnedAppearanceLease=owner.get_meta("source_transform_guard") if owner.has_meta("source_transform_guard") else null
	if required and (guard==null or guard.actor.sprite!=actor.sprite or not guard.still_bound()):return []
	var lease: BattleOwnedAppearanceLease=BattleOwnedAppearanceLease.capture(actor)
	if required:
		lease.commit_guard=guard
		if guard.before.has("shadow"):lease.before.shadow=guard.before.shadow
	owner._appearance_leases.append(lease)
	var node: Sprite2D=BattleIdentityCopy.clone_sprite(actor,owner)
	owner.add_child(node)
	node.z_index=BattleSourcePriority.actor_layer(actor,owner)
	var material:=ShaderMaterial.new();material.shader=load("res://scripts/battle/animations/sequence/source_transform_mosaic.gdshader")
	node.material=material
	_frame_window(node,material)
	actor.apply_source_state("hidden",true)
	return [{"kind":"source_transform","age":0,"ticks":int(step.ticks),"bound_actor":actor,"bound_target":target,"node":node,"material":material,"lease":lease,"owner":owner,"settings":step.duplicate(true),"phase":0,"count":0,"mosaic":0,"selected_species":"","selected_view":"","update":update}]

static func _frame_window(node: Sprite2D, material: ShaderMaterial) -> void:
	var size: Vector2=node.texture.get_size()
	var region: Rect2=node.region_rect if node.region_enabled else Rect2(Vector2.ZERO,size)
	var frame_size: Vector2=region.size/Vector2(node.hframes,node.vframes)
	material.set_shader_parameter("frame_uv_origin",(region.position+Vector2(node.frame_coords)*frame_size)/size)
	material.set_shader_parameter("frame_uv_size",frame_size/size)

## @deprecated: camino de la VM legada; las animaciones nativas no lo usan. Se conserva como referencia y fallback de configuración. Ver scripts/battle/animations/sequence/README.md.
static func update(track: Dictionary, context: BattleAnimationContext) -> void:
	var actor: BattleAnimationActor=track.bound_actor
	if not actor.is_present() or (int(track.phase)<2 and not track.bound_target.is_present()):
		track.node.visible=false;track.ticks=int(track.age);return
	var node: Sprite2D=track.node
	node.position=track.owner.to_local(actor.sprite.to_global(Vector2(0,actor.sprite.get_rect().end.y-node.get_rect().end.y)))
	match int(track.phase):
		0:
			track.count+=1
			if int(track.count)==3:
				track.count=0;track.mosaic+=1
				if int(track.mosaic)==15:track.phase=1
		1:
			_capture_buffer(track,context)
			track.phase=2
		2:
			track.count+=1
			if int(track.count)==3:
				track.count=0;track.mosaic-=1
				if int(track.mosaic)==0:track.phase=3
		3:
			track.lease.ready=true
			track.domain="maintenance";track.phase=4;track.count=0
			if not track.owner._sounds.any(func(player):return is_instance_valid(player) and player.playing):track.ticks=int(track.age)
		4:
			# Keep the new buffer visible during bounded source sound drain; the
			# old actor stays hidden until the successful atomic texture commit.
			track.count+=1
			if int(track.count)>=90 or not track.owner._sounds.any(func(player):return is_instance_valid(player) and player.playing):track.ticks=int(track.age)
	if node.material==track.material:track.material.set_shader_parameter("mosaic",float(track.mosaic))

static func _capture_buffer(track: Dictionary, context: BattleAnimationContext) -> void:
	var actor: BattleAnimationActor=track.bound_actor
	var target: BattleAnimationActor=track.bound_target
	var restoring: bool=int(track.settings.source_args[0])!=0
	var selected: Dictionary=buffer(context,actor,target,restoring)
	if not restoring and context.has_meta("source_transform_buffer"):
		selected=context.get_meta("source_transform_buffer").duplicate(true)
	track.node.texture=selected.texture
	track.node.hframes=1;track.node.vframes=1;track.node.frame=0;track.node.region_enabled=false
	track.node.flip_h=selected.flip_h
	track.selected_view=selected.selected_view;track.selected_species=selected.species
	track.resource_fallback=selected.resource_fallback
	_frame_window(track.node,track.material)
	track.lease.replacement=selected
	if bool(track.owner.get_meta("source_transform_guard_required",false)):
		track.lease.replacement.presentation_state=BattleTransformPresentation.transform_state(track.lease,context.action_id)

static func buffer(context: BattleAnimationContext, actor: BattleAnimationActor, target: BattleAnimationActor, restoring: bool=false) -> Dictionary:
	if not context.source_party_views.has(target.id):context.snapshot_party_views(target.id)
	var species: String=str(context.source_party_species.get(target.id,""))
	var state: Dictionary=actor.sprite.get_meta("source_presentation_state",{})
	var transformed: bool=str(state.get("kind",""))=="transform"
	if restoring:species=str(actor.sprite.get_meta("animation_species",context.source_appearance_species.get(actor.id,species)))
	var view: String="back" if actor.side==0 or context.contest else "front"
	if context.contest and species.to_upper()=="UNOWN":view="front"
	var views: Dictionary=context.source_form_views.get(actor.id,{}) if restoring else context.source_party_views.get(target.id,{})
	var texture: Texture2D=views.get(view)
	var resource_fallback: bool=false
	if texture==null:
		texture=context.source_party_views.get(target.id,{}).get(view)
	if texture==null:
		# Honest custom-party art fallback: actual bound visual, never fixture species.
		texture=target.sprite.texture
		resource_fallback=true
	var image: Image=_selected_image(target.sprite) if resource_fallback else texture.get_image().duplicate()
	var raw_selected_image: Image=image.duplicate()
	# sub_8031FC4 copies the new palette blended six-sixteenths toward white.
	for y in image.get_height():
		for x in image.get_width():
			var color: Color=image.get_pixel(x,y)
			var white: Color=Color(1,1,1,color.a)
			image.set_pixel(x,y,color.lerp(white,6.0/16 if not restoring or transformed else 0.0))
	var flip: bool=actor.sprite.flip_h
	if context.contest:
		var prior: String=str(context.source_appearance_species.get(actor.id,""))
		if (prior.to_upper()=="UNOWN")!=(species.to_upper()=="UNOWN"):flip=not flip
	var selected: Dictionary={"texture":ImageTexture.create_from_image(image),"species":species,"kind":"transform" if not restoring or transformed else "form","flip_h":flip,"selected_view":view,"resource_fallback":resource_fallback}
	preload("res://scripts/battle/animations/sequence/transform_pixel_receipt.gd").attach(selected.texture,raw_selected_image,actor,target.sprite,context,selected,6.0/16 if not restoring or transformed else 0.0)
	# sub_8032984 refreshes only the opponent's shadow callback after mode0.
	# Native species profiles replace GBA elevation flags, without touching DB.
	var shadows: Dictionary=context.get_meta("source_shadow_profiles",{})
	if not restoring and actor.side==1 and not context.contest and shadows.has(species):selected.shadow=bool(shadows[species])
	return selected

static func _selected_image(sprite: Sprite2D) -> Image:
	var image: Image=sprite.texture.get_image()
	var region: Rect2=sprite.region_rect if sprite.region_enabled else Rect2(Vector2.ZERO,sprite.texture.get_size())
	var size: Vector2=region.size/Vector2(sprite.hframes,sprite.vframes)
	var origin: Vector2=region.position+Vector2(sprite.frame_coords)*size
	return image.get_region(Rect2i(Vector2i(origin.floor()),Vector2i(size.ceil())))

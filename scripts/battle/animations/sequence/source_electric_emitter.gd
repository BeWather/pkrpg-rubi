extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Ruby sub_80D681C: one counted visual parent, five raw uncounted children.
const Coordinates = preload("res://scripts/battle/animations/sequence/source_coordinate_contract.gd")

static func create(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Array[Dictionary]:
	var targets := context.resolve("target")
	if targets.is_empty(): return []
	var target: BattleAnimationActor = targets[0]
	var nominal := Coordinates.nominal(target,context)
	if nominal.state == "invalid": return []
	# Missing optional layout metadata keeps the historical native anchor fallback.
	var base: Vector2 = nominal.point if nominal.state == "valid" else BattleElectricContract.source_anchor(target,context)
	var args: Array = step.source_args
	var root := Node2D.new()
	root.name = "SourceElectricEmitter"
	owner.add_child(root)
	var bindings: Array = step.children.duplicate(true)
	var textures: Array[Texture2D] = []
	for binding: Dictionary in bindings: textures.append(load(str(binding.texture)) as Texture2D)
	return [{"kind":"source_electric_emitter","age":0,"ticks":24,"domain":"visual",
		"node":root,"owner":owner,"field":context.field,"target":target,
		"base":base+Vector2(args[0],args[1]),"bindings":bindings,"textures":textures,
		"children":[],"counter":-1,"spawned":0,"retired":false,
		"update":update,"cleanup":cleanup.bind(root)}]

static func cleanup(root: Node2D) -> void:
	if is_instance_valid(root) and not root.is_queued_for_deletion(): root.queue_free()

static func update(track: Dictionary, context: BattleAnimationContext) -> void:
	# Child callback runs immediately at birth (data[1]=1), then once per tick.
	# DestroySprite is callback 15, not 15 extra callbacks after construction.
	for child: Dictionary in track.children.duplicate():
		child.callbacks += 1
		if child.callbacks == 15:
			if is_instance_valid(child.node): child.node.free()
			track.children.erase(child)
	if not track.retired:
		track.counter += 1
		if track.counter == 10:
			track.retired = true
			track.domain = "electric_child_tail"
		elif track.counter % 2 == 0 and track.counter < 10:
			# Cached source geometry is not recomputed from live species ART.
			if not track.target.is_present():
				track.retired = true; track.domain = "electric_child_tail"
			else:
				var index: int = track.spawned
				var binding: Dictionary = track.bindings[index]
				var tile: int = binding.frame_commands[0].tile
				var rect: Array = binding.frame_rects[str(tile)]
				var node := Sprite2D.new()
				node.texture = track.textures[index]
				node.region_enabled = true
				node.region_rect = Rect2(rect[0],rect[1],rect[2],rect[3])
				node.z_index = BattleElectricContract.absolute_priority_layer(2,context,track.node)
				track.node.add_child(node)
				track.children.append({"node":node,"callbacks":1,"tile":tile,"field_point":track.base+Vector2(0,16*(index+1))})
				track.spawned += 1
	for child: Dictionary in track.children:
		# Project the full source pixel basis, not just its anchor. An owner
		# rotation/nonuniform scale must not stretch the fixed 8x16/16x16 OAM.
		child.node.transform = track.node.global_transform.affine_inverse() * track.field.global_transform * Transform2D(0.0,child.field_point)
	if track.retired and track.children.is_empty(): track.ticks = track.age

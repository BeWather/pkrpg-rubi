extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Hail258 only: one counted task, live-born raw shards and conditional raw impacts.
const Coordinates=preload("res://scripts/battle/animations/sequence/source_coordinate_contract.gd")

static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var root: Node2D=Node2D.new()
	root.name="SourceHailTask"
	owner.add_child(root)
	var children: Array[Dictionary]=[]
	return [{"kind":"source_hail_task","settings":step.duplicate(true),"node":root,"owner":owner,"age":0,"ticks":4096,"domain":"visual",
		"task_callbacks":0,"stage":0,"delay":0,"idle":0,"row":0,"variant":0,"pending":0,"children":children,"events":[],
		"bounds":JSON.parse_string(FileAccess.get_file_as_string(str(step.source_bounds))),"update":advance,"cleanup":cleanup.bind(children,root)}]

static func cleanup(children: Array[Dictionary],root: Node2D) -> void:
	children.clear()
	if is_instance_valid(root) and not root.is_queued_for_deletion():root.queue_free()

static func destination(row: Dictionary,c: BattleAnimationContext,bounds: Dictionary) -> Dictionary:
	var fallback: Dictionary={"point":Vector2(row.target[0],row.target[1]),"hit":false,"actor_id":-1,"geometry":"row"}
	if int(row.variant)==2:return fallback
	for actor: BattleAnimationActor in c.actors.values():
		if c.source_position(actor.id)!=int(row.source_position):continue
		if not actor.is_present() or not actor.sprite.is_visible_in_tree() or (c.contest and actor.id!=c.attacker_id):return fallback
		var visual: Dictionary=Coordinates.visual(actor,c)
		if str(visual.state)=="invalid":return fallback
		# BODY is a native projection of X_2/Y_PIC_OFFSET, not the nominal slot.
		# Only missing optional BODY metadata uses the legacy custom-layout anchor.
		var center: Vector2=visual.point if str(visual.state)=="valid" else BattleElectricContract.source_anchor(actor,c)
		var species: String=str(c.source_appearance_species.get(actor.id,c.source_party_species.get(actor.id,"NONE"))).to_upper()
		var picture: Dictionary=bounds.by_species.get(species,bounds.by_species.NONE)
		var side: String="back" if c.contest or (int(row.source_position)&1)==0 else "front"
		var size: Array=picture[side]
		var sign_value: int=-1 if int(row.variant)==0 else 1
		# Species picture attributes, never texture canvas, ART offset or ART scale.
		return {"point":Vector2(int(center.x)+sign_value*(int(size[0])/6),int(center.y)+sign_value*(int(size[1])/6)),"hit":true,"actor_id":actor.id,"geometry":"body" if str(visual.state)=="valid" else "legacy_anchor"}
	return fallback

static func _particle(t: Dictionary,c: BattleAnimationContext,binding: Dictionary,point: Vector2) -> Dictionary:
	# The general factory requires a live attacker and runner-owner API. Raw Hail
	# children require neither: source weather keeps emitting after a bank vanishes.
	# Reuse the shared frame/affine renderer below, not actor-bound constructors.
	if not ResourceLoader.exists(str(binding.texture)):return {}
	var texture: Texture2D=load(str(binding.texture)) as Texture2D
	if texture==null:return {}
	var node: Sprite2D=Sprite2D.new()
	node.texture=texture
	node.region_enabled=true
	t.node.add_child(node)
	node.z_index=BattleElectricContract.absolute_priority_layer(2,c,t.node)
	return {"kind":"source_particle","settings":binding.duplicate(true),"node":node,"origin":point,"destination":point,
		"age":0,"ticks":4096,"callbacks":0,"birth_callback":int(t.task_callbacks),"source_side":0,"field_size":c.field_size}

static func _pose(t: Dictionary,child: Dictionary,c: BattleAnimationContext) -> void:
	if str(child.role)=="impact":
		# Relative source commands accumulate FIRST. Convert the resulting absolute
		# scale exactly once, matching sprite.c; never invert individual increments.
		var pose: Dictionary=BattleSourceCommandProgram.evaluate(child.settings.source_affine_commands,int(child.callbacks),true)
		child.settings.affine_commands=[{"x":65536/int(pose.matrix.x),"y":65536/int(pose.matrix.y),"rotation":int(pose.rotation),"ticks":0}]
	child.age=int(child.callbacks)
	BattleSourceParticle.update(child)
	var point: Vector2=child.origin+Vector2(t.settings.shard_velocity[0],t.settings.shard_velocity[1])*int(child.callbacks) if str(child.role)=="shard" else child.origin
	# Keep field-pixel motion and OAM dimensions independent of owner transforms.
	child.node.transform=t.node.global_transform.affine_inverse()*c.field.global_transform*Transform2D(child.node.rotation,child.node.scale,0.0,point)

static func _event(t: Dictionary,kind: String,child: Dictionary) -> void:
	t.events.append({"event":kind,"task_callback":int(t.task_callbacks),"row":int(child.row),"variant":int(child.variant),"hit":bool(child.hit),"point":child.destination,"callbacks":int(child.callbacks),"pending":int(t.pending)})

static func _birth(t: Dictionary,c: BattleAnimationContext) -> void:
	var row: Dictionary=t.settings.source_rows[int(t.row)]
	var landing: Dictionary=destination(row,c,t.bounds)
	var point: Vector2=landing.point
	var origin: Vector2=Vector2(point.x-int((int(point.y)+8)/2),-8)
	var child: Dictionary=_particle(t,c,t.settings.shards[int(t.variant)],origin)
	if child.is_empty():return
	child.merge({"role":"shard","row":int(t.row),"variant":int(t.variant),"hit":bool(landing.hit),"geometry":landing.geometry,"actor_id":int(landing.actor_id)},true)
	child.destination=point
	t.pending=int(t.pending)+1
	t.children.append(child)
	_pose(t,child,c)
	_event(t,"shard_birth",child)

static func _children(t: Dictionary,c: BattleAnimationContext) -> void:
	# BattleMainCB2 runs AnimateSprites before RunTasks: a task-born shard's
	# first movement callback occurs next worker tick. New impacts likewise start
	# Continue next tick; same-frame global sprite-slot iteration is not emulated.
	for child: Dictionary in t.children.duplicate():
		child.callbacks=int(child.callbacks)+1
		if str(child.role)=="impact":
			if int(child.callbacks)==int(t.settings.impact_callbacks):
				t.pending=int(t.pending)-1
				_event(t,"impact_retire",child)
				t.children.erase(child)
				child.node.free()
			else:_pose(t,child,c)
			continue
		var point: Vector2=child.origin+Vector2(t.settings.shard_velocity[0],t.settings.shard_velocity[1])*int(child.callbacks)
		if point.x<child.destination.x and point.y<child.destination.y:
			_pose(t,child,c)
			continue
		_event(t,"shard_land",child)
		t.children.erase(child)
		child.node.free()
		if bool(child.hit) and int(child.variant)==0:
			var impact: Dictionary=_particle(t,c,t.settings.impact,child.destination)
			if not impact.is_empty():
				impact.merge({"role":"impact","row":int(child.row),"variant":0,"hit":true},true)
				t.children.append(impact)
				_pose(t,impact,c)
				_event(t,"impact_birth",impact)
				continue # Transfer the same pending unit; no decrement/increment pair.
		# Native constructor failure drains ownership instead of emulating the GBA
		# allocation-failure hang. No global MAX_SPRITES allocator is introduced.
		t.pending=int(t.pending)-1

static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	t.task_callbacks=int(t.task_callbacks)+1
	_children(t,c)
	match int(t.stage):
		0:
			t.delay=int(t.delay)+1
			if int(t.delay)==int(t.settings.group_delay_callbacks):
				t.delay=0;t.idle=0;t.variant=0;t.stage=1
		1:
			if int(t.idle)>0:t.idle=int(t.idle)-1
			else:
				_birth(t,c)
				t.variant=int(t.variant)+1
				if int(t.variant)==3:
					t.row=int(t.row)+1
					t.stage=2 if int(t.row)==t.settings.source_rows.size() else 0
				else:t.idle=int(t.settings.variant_idle_callbacks)
		2:
			if int(t.pending)==0:t.ticks=int(t.age)

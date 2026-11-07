extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Water Pulse352 only: counted moving rings, raw bubble children and finite tails.
const Coordinates=preload("res://scripts/battle/animations/sequence/source_coordinate_contract.gd")

static func _body(actor: BattleAnimationActor,c: BattleAnimationContext) -> Dictionary:
	var body: Dictionary=Coordinates.visual(actor,c)
	if str(body.state)=="invalid":return body
	var point: Vector2=body.point if str(body.state)=="valid" else BattleElectricContract.source_anchor(actor,c)
	return {"state":"valid","point":Vector2(int(point.x),int(point.y))} if point.is_finite() else {"state":"invalid"}

static func _logical_x(actor: BattleAnimationActor,c: BattleAnimationContext,body: Vector2) -> Dictionary:
	var nominal: Dictionary=Coordinates.nominal(actor,c)
	if str(nominal.state)=="invalid":return nominal
	return {"state":"valid","x":float(nominal.point.x) if str(nominal.state)=="valid" else body.x}

static func _sprite(binding: Dictionary,root: Node2D,side: int) -> Dictionary:
	if not ResourceLoader.exists(str(binding.texture)):return {}
	var texture: Texture2D=load(str(binding.texture)) as Texture2D
	if texture==null:return {}
	var node: Sprite2D=Sprite2D.new()
	node.texture=texture
	node.region_enabled=true
	root.add_child(node)
	return {"kind":"source_particle","settings":binding.duplicate(true),"node":node,"origin":Vector2.ZERO,"destination":Vector2.ZERO,"source_side":side,"age":0,"ticks":4096,"callbacks":0}

static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var attackers: Array[BattleAnimationActor]=c.resolve("attacker")
	var targets: Array[BattleAnimationActor]=c.resolve("target")
	if attackers.is_empty() or targets.is_empty():return []
	var from: Dictionary=_body(attackers[0],c)
	var to: Dictionary=_body(targets[0],c)
	if str(from.state)!="valid" or str(to.state)!="valid":return []
	var from_x: Dictionary=_logical_x(attackers[0],c,from.point)
	var to_x: Dictionary=_logical_x(targets[0],c,to.point)
	if str(from_x.state)!="valid" or str(to_x.state)!="valid":return []
	# sub_807867C mirrors initial X by logical attacker/target ordering, side on ties.
	var direction: int=1 if float(from_x.x)<float(to_x.x) else -1 if float(from_x.x)>float(to_x.x) else 1 if attackers[0].side==0 else -1
	var args: Array=step.source_args
	var origin: Vector2=from.point+Vector2(int(args[0])*direction,int(args[1]))
	var root: Node2D=Node2D.new()
	root.name="SourceWaterPulseRing"
	owner.add_child(root)
	var parent: Dictionary=_sprite(step,root,attackers[0].side)
	if parent.is_empty():root.free();return []
	parent.node.z_index=BattleElectricContract.absolute_priority_layer(2,c,root)
	var children: Array[Dictionary]=[]
	var random: RandomNumberGenerator=RandomNumberGenerator.new()
	random.seed=c.seed_value+int(step.source_line)*977 # Stable per ring, not global GBA RNG parity.
	var group: Dictionary={"kind":"source_water_pulse_ring","domain":"visual","settings":step.duplicate(true),"node":root,"owner":owner,"field":c.field,
		"origin":origin,"destination":to.point,"delta":to.point-origin,"side":attackers[0].side,"child_layer":BattleSourcePriority.relative_layer(attackers[0],-1,c,root),
		"parent":parent,"callbacks":0,"parent_age":-1,"retired":false,"children":children,"events":[],"random":random,"age":0,"ticks":int(args[2])+int(step.child_callbacks)+2,
		"update":advance,"cleanup":cleanup.bind(children,root)}
	_pose(group,parent,origin,int(step.parent_affine_visit_offset))
	return [group]

static func cleanup(children: Array[Dictionary],root: Node2D) -> void:
	children.clear()
	if is_instance_valid(root) and not root.is_queued_for_deletion():root.queue_free()

static func _pose(group: Dictionary,particle: Dictionary,point: Vector2,affine_age: int) -> void:
	# Source scale increments accumulate before ConvertScaleParam. The generic
	# renderer accepts raw OAM coefficients, not the original source scale values.
	var pose: Dictionary=BattleSourceCommandProgram.evaluate(particle.settings.source_affine_commands,maxi(0,affine_age),true)
	particle.settings.affine_commands=[{"x":65536/int(pose.matrix.x),"y":65536/int(pose.matrix.y),"rotation":int(pose.rotation),"ticks":0}]
	particle.age=maxi(0,affine_age)
	BattleSourceParticle.update(particle)
	particle.node.transform=group.node.global_transform.affine_inverse()*group.field.global_transform*Transform2D(particle.node.rotation,particle.node.scale,0.0,point)

static func _signed16(value: int) -> int:
	return ((value+32768)&65535)-32768

static func _children(group: Dictionary) -> void:
	# Explicit local projection: a raw child has no constructor AnimateSprite;
	# first movement/absolute-affine visit is next tick, not global slot-ID order.
	for child: Dictionary in group.children.duplicate():
		child.callbacks=int(child.callbacks)+1
		child.x_acc=_signed16(int(child.x_acc)+int(child.vx))
		child.y_acc=_signed16(int(child.y_acc)+int(child.vy))
		if int(child.callbacks)==int(group.settings.child_callbacks):
			group.events.append({"event":"child_retire","clock":int(group.age),"birth_clock":int(child.birth_clock),"callbacks":int(child.callbacks)})
			group.children.erase(child)
			child.node.free()
		else:
			var point: Vector2=child.birth_origin+Vector2(int(child.x_acc)>>7,int(child.y_acc)>>7)
			_pose(group,child,point,int(child.callbacks)+int(group.settings.child_affine_visit_offset))

static func _emit(group: Dictionary,point: Vector2) -> void:
	var noise_y: int=group.random.randi_range(-5,4)
	var noise_x: int=group.random.randi_range(-5,4)
	var vx: int=_signed16(int(group.delta.y)+noise_y)
	var speed_y: int=absi(_signed16(-int(group.delta.x)+noise_x))
	var offset: int=int(group.parent_age)/2
	for sign_value: int in [1,-1]:
		var child: Dictionary=_sprite(group.settings.child,group.node,int(group.side))
		if child.is_empty():continue # Native allocation failure is not a global SpriteID emulator.
		child.merge({"callbacks":0,"x_acc":0,"y_acc":0,"vx":vx,"vy":_signed16(sign_value*speed_y),"birth_origin":point+Vector2(0,sign_value*offset),
			"birth_clock":int(group.age),"parent_age":int(group.parent_age),"noise_x":noise_x,"noise_y":noise_y,"sign":sign_value},true)
		child.node.z_index=int(group.child_layer)
		group.children.append(child)
		_pose(group,child,child.birth_origin,0)
		group.events.append({"event":"child_birth","clock":int(group.age),"parent_age":int(group.parent_age),"parent_callback":int(group.callbacks),"point":child.birth_origin,"ring_point":point,"vx":vx,"vy":int(child.vy),"noise_x":noise_x,"noise_y":noise_y,"sign":sign_value})

static func advance(group: Dictionary,c: BattleAnimationContext) -> void:
	_children(group)
	if not bool(group.retired):
		group.callbacks=int(group.callbacks)+1
		group.parent_age=int(group.callbacks)-1
		var duration: int=int(group.settings.source_args[2])
		var point: Vector2=group.origin+Vector2(int(int(group.parent_age)*int(group.delta.x)/duration),int(int(group.parent_age)*int(group.delta.y)/duration))
		if int(group.parent_age)==duration:
			group.parent.node.free()
			group.retired=true
			group.domain="water_pulse_child_tail" # Raw children never hold waitforvisualfinish.
			group.events.append({"event":"parent_retire","clock":int(group.age),"parent_age":int(group.parent_age),"point":point})
		else:
			_pose(group,group.parent,point,int(group.callbacks)+int(group.settings.parent_affine_visit_offset))
			if int(group.callbacks)%int(group.settings.source_args[3])==0:_emit(group,point)
	if bool(group.retired) and group.children.is_empty():group.ticks=int(group.age)

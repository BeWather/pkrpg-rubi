extends RefCounted
class_name BattleChargeContract
## Source-selected strikes and bounded, execution-owned Solar/Meteor children.
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

static func anchor_pose(step: Dictionary, context: BattleAnimationContext, origin: Vector2, destination: Vector2) -> Dictionary:
	if str(step.get("source_module",""))!="charge_contract":return {"origin":origin,"destination":destination}
	if step.has("absolute_origin"):
		origin=Vector2(step.absolute_origin[0],step.absolute_origin[1])
		return {"origin":origin,"destination":origin}
	var attackers: Array = context.resolve("attacker")
	var targets: Array = context.resolve("target")
	if attackers.is_empty() or targets.is_empty():return {"origin":origin,"destination":destination}
	var attacker: BattleAnimationActor = attackers[0]
	var target: BattleAnimationActor = targets[0]
	var a: Array = step.get("source_args",[])
	var mode := str(step.get("mode",""))
	var center := BattleElectricContract.source_anchor(target,context)
	match mode:
		"spinning_strike","blaze_scatter":
			origin=center+Vector2(int(a[0])*BattleElectricContract.source_offset_direction(context,attacker,target),a[1])
			destination=origin
		"fang_sheet","focus_fist":origin=center;destination=center
		"solar_charge_orb","solar_release_orb","solar_orbit_child":
			origin=BattleElectricContract.source_anchor(attacker,context)+Vector2(int(a[0])*BattleElectricContract.source_offset_direction(context,attacker,target),a[1])
			destination=BattleElectricContract.source_anchor(attacker,context) if mode=="solar_charge_orb" else center
		"meteor_star":
			var direction := -1 if target.side==0 or context.contest else 1
			origin=center+Vector2(int(a[0])*direction,a[1])
			destination=center+Vector2(int(a[2])*direction,a[3])
	return {"origin":origin,"destination":destination}

static func frozen_context(context: BattleAnimationContext) -> BattleAnimationContext:
	var snapshot := BattleAnimationContext.new()
	snapshot.field=context.field
	snapshot.field_size=context.field_size
	snapshot.actors=context.actors.duplicate()
	snapshot.attacker_id=context.attacker_id
	snapshot.target_ids=context.target_ids.duplicate()
	snapshot.source_positions=context.source_positions.duplicate()
	snapshot.contest=context.contest
	snapshot.seed_value=context.seed_value
	return snapshot

static func initialize_particle(track: Dictionary, context: BattleAnimationContext, owner: Node2D) -> void:
	if str(track.settings.get("source_module",""))!="charge_contract":return
	BattleElectricContract.initialize_particle(track,context,owner)
	track.source_context=frozen_context(context)
	track.source_owner=owner
	track.last_spawn_age=-1
	if str(track.settings.mode)=="solar_orbit_child":
		var targets: Array = context.resolve("target")
		if not targets.is_empty():track.source_bound_target=targets[0]
	if str(track.settings.mode)=="meteor_trail":
		var rng := RandomNumberGenerator.new()
		rng.seed=context.seed_value+owner.elapsed_ticks*977+owner.get_child_count()*37
		track.source_fixed_tile=4 if (rng.randi()&3)==0 else 5
		var y := int(rng.randi())&7
		track.origin.y+=-y if y>3 else y

static func frame_pose(track: Dictionary, selected: Dictionary) -> Dictionary:
	return {"tile":track.source_fixed_tile,"ticks":1} if track.has("source_fixed_tile") else selected

static func spawn_child(owner: Node2D, context: BattleAnimationContext, binding: Dictionary, values: Dictionary, domain: String = "visual", solar_open: Callable=Callable(), solar_close: Callable=Callable()) -> void:
	var step := binding.duplicate(true)
	step.merge(values,true)
	# Only the finite Solar initializer supplies these paired source-child hooks.
	var solar_scope: bool=solar_open.is_valid() and solar_open.call(owner,context,step)
	var children: Array = BattleEffectBehaviorRegistry.factories().source_particle.call(step,context,owner)
	if solar_scope and solar_close.is_valid():solar_close.call(owner)
	for child: Dictionary in children:
		child.domain=domain
		owner._tracks.append(child)

static func particle_pose(track: Dictionary) -> void:
	if str(track.settings.get("source_module",""))!="charge_contract":return
	var s: Dictionary = track.settings
	var age := maxi(0,int(track.age))
	var node: Sprite2D = track.node
	match str(s.mode):
		"solar_charge_orb","solar_release_orb","solar_orbit_child":
			node.position=BattleGhostContract._linear_translation(track.origin,track.destination,age+1,int(s.travel_ticks))
			if str(s.mode)=="solar_orbit_child":
				var angle := (int(s.source_args[3])+age*15)&255
				node.position+=Vector2(BattleSourceTrig.sine(angle,5),BattleSourceTrig.cosine(angle,14))
				track.source_oam_subpriority=BattleElectricContract.source_subpriority(track.source_bound_target,track.source_context)+(6 if angle<=127 else 1)
				node.z_index=BattleElectricContract.behind_actor_plane(int(track.source_oam_subpriority),track.source_bound_target,track.source_context,track.source_owner)
		"focus_fist":
			var count := maxi(0,age-int(s.source_affine_ticks)+1)
			node.position=track.origin+Vector2(BattleSourceTrig.sine(count*int(s.oscillation_step),2),0)
		"blaze_scatter":
			var count := mini(age,int(s.get("motion_ticks",40)))
			node.position=track.origin+Vector2(floorf(count*float(s.velocity[0])/256.0),floorf(count*float(s.velocity[1])/256.0))
		"meteor_star":
			var count := mini(age,int(s.travel_ticks))
			var delta: Vector2 = track.destination-track.origin
			node.position=track.origin+Vector2(int(delta.x*count/int(s.travel_ticks)),int(delta.y*count/int(s.travel_ticks)))
			if s.has("child_binding") and age!=int(track.last_spawn_age) and age%2==0 and age<int(s.travel_ticks):
				track.last_spawn_age=age
				spawn_child(track.source_owner,track.source_context,s.child_binding,{"absolute_origin":[node.position.x,node.position.y]},"maintenance")
		"meteor_trail":
			node.position=track.origin
			node.visible=(age/2)%2==0 if age<30 else (age%4)!=3

static func create_control(step: Dictionary, context: BattleAnimationContext, owner: Node2D, solar_initializer: Callable=Callable()) -> Array[Dictionary]:
	var attackers: Array = context.resolve("attacker")
	var targets: Array = context.resolve("target")
	if attackers.is_empty() or targets.is_empty():return []
	var track := {"kind":"source_charge_task","age":0,"ticks":int(step.ticks),"settings":step.duplicate(true),"owner":owner,"source_context":frozen_context(context),"attacker":attackers[0],"target":targets[0],"last_age":-1,"spawned":0,"update":update_control}
	if not solar_initializer.is_valid() or not solar_initializer.call(track,step,context,owner):update_control(track,context)
	return [track]

static func update_control(track: Dictionary, _context: BattleAnimationContext) -> void:
	var age := int(track.age)
	if age==int(track.last_age):return
	track.last_age=age
	var attacker: BattleAnimationActor = track.attacker
	var target: BattleAnimationActor = track.target
	if not attacker.is_present() or not target.is_present():track.ticks=age;return
	if age%int(track.settings.spawn_interval)!=0 or int(track.spawned)>=int(track.settings.spawn_count):return
	var args: Array = track.settings.child_args
	for index in args.size():track.owner._source_args[index]=int(args[index])&65535
	spawn_child(track.owner,track.source_context,track.settings.child_binding,{},"visual",track.get("solar_child_open",Callable()),track.get("solar_child_close",Callable()))
	track.spawned+=1

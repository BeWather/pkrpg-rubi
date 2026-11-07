extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Actual task-owned 12 children/direction; parent18-callback hold drains them.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
const PackedMotion=preload("res://scripts/battle/animations/sequence/source_sports.gd")
static func _corner(actor: BattleAnimationActor,upper: bool,c: BattleAnimationContext,owner: Node2D,data: Dictionary) -> Vector2:
	var species: String=str(c.source_appearance_species.get(actor.id,c.source_party_species.get(actor.id,""))).to_upper()
	var side: String="back" if c.contest or actor.side==0 else "front"
	var sizes: Dictionary=data.by_species.get(species,{})
	if not sizes.has(side):owner.error_message="Missing source Skill Swap picture dimensions: "+species;owner.finish("failed");return Vector2.ZERO
	var size: Array=sizes[side];var half:=Vector2(size[0],size[1])/2.0
	var x: float=(-half.x+8 if upper else half.x-8)*(-1 if c.contest else 1)
	return Geometry._anchor(actor,c,owner,"center")+Vector2(x,-half.y+8 if upper else half.y-8)
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var attackers: Array[BattleAnimationActor]=c.resolve("attacker");var targets: Array[BattleAnimationActor]=c.resolve("target")
	if attackers.is_empty() or targets.is_empty():return []
	var direction: int=int(step.source_args[0]);var upper: bool=direction==1
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(step.source_bounds)))
	var source: BattleAnimationActor=targets[0] if upper else attackers[0];var target: BattleAnimationActor=attackers[0] if upper else targets[0]
	var origin: Vector2=_corner(source,upper,c,owner,data);var destination: Vector2=_corner(target,upper,c,owner,data)
	return [{"kind":"source_skill_swap_task","settings":step.duplicate(true),"owner":owner,"original_actor":attackers[0],"original_target":targets[0],"direction":direction,"amplitude":-10 if upper else 10,"origin":origin,"destination":destination,"age":0,"ticks":4096,"counter":6,"created":0,"children":[],"update":advance}]
static func _pose(child: Dictionary,settings: Dictionary) -> void:
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(settings.frame_program,int(child.age)).frame
	var rect: Array=settings.frame_rects[str(int(frame.tile))];child.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3])
	var pose: Dictionary=BattleSourceCommandProgram.evaluate(settings.source_affine_variants[str(int(child.variant))],int(child.age),true)
	child.node.scale=Vector2(256.0/pose.matrix.x,256.0/pose.matrix.y)
static func _advance_child(child: Dictionary,settings: Dictionary) -> bool:
	child.age=int(child.age)+1
	if PackedMotion._translate(child):return true
	child.node.position=child.origin+child.offset;_pose(child,settings);return false
static func _emit(t: Dictionary,c: BattleAnimationContext) -> void:
	var node:=Sprite2D.new();node.texture=load(str(t.settings.texture));node.region_enabled=true;node.position=t.origin;t.owner.add_child(node)
	var child: Dictionary={"node":node,"origin":t.origin,"offset":Vector2.ZERO,"age":0,"variant":int(t.created)&3,"source_oam_subpriority":0}
	PackedMotion._arc(child,t.destination,16,int(t.amplitude))
	node.z_index=BattleSourcePriority.relative_layer(t.original_actor,-BattleElectricContract.source_subpriority(t.original_actor,c),c,t.owner)
	# Plain task CreateSprite is animated later in this same source frame.
	_advance_child(child,t.settings);t.children.append(child);t.created=int(t.created)+1
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	for child: Dictionary in t.children.duplicate():
		if _advance_child(child,t.settings):child.node.queue_free();t.children.erase(child)
	if int(t.created)<12:
		t.counter=int(t.counter)+1
		if int(t.counter)>6:t.counter=0;_emit(t,c)
	else:
		t.counter=int(t.counter)+1
		if int(t.counter)>17:t.ticks=int(t.age)

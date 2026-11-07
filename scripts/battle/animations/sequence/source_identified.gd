extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Literal source lens waypoint machine and two owned Odor Sleuth clone callbacks.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
const Motion=preload("res://scripts/battle/animations/sequence/source_sports.gd")
const Identity=preload("res://scripts/battle/animations/sequence/source_identity_copy.gd")
static func _target(c: BattleAnimationContext) -> BattleAnimationActor:
	var actors: Array[BattleAnimationActor]=c.resolve("target")
	return actors[0] if not actors.is_empty() else null
static func create_lens(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var target: BattleAnimationActor=_target(c)
	if target==null or not target.is_present():return []
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(step.source_bounds)))
	var species: String=str(c.source_appearance_species.get(target.id,c.source_party_species.get(target.id,""))).to_upper()
	var side: String="back" if c.contest or target.side==0 else "front"
	var sizes: Dictionary=data.by_species.get(species,{})
	if not sizes.has(side):owner.error_message="Missing source Foresight picture dimensions: "+species;owner.finish("failed");return []
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;owner.add_child(node)
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(step.frame_program,0).frame
	var rect: Array=step.frame_rects[str(int(frame.tile))];node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);node.flip_h=target.side==1
	BattleCounterSelected._blend_node(node,owner)
	var center: Vector2=Geometry._anchor(target,c,owner,"center")
	var t: Dictionary={"kind":"source_foresight_lens","settings":step.duplicate(true),"owner":owner,"original_target":target,"node":node,"center":center,"picture_size":Vector2(sizes[side][0],sizes[side][1]),"origin":center,"offset":Vector2.ZERO,"destination":center,"waypoint":0,"stage":0,"counter":0,"fade_count":0,"eva":16,"evb":0,"age":0,"ticks":4096,"update":advance_lens}
	node.position=center;BattleSourcePriority.initialize(t,c,owner)
	t.source_oam_priority=2 if c.contest or c.source_position(target.id) in [0,3] else 1
	return [t]
static func advance_lens(t: Dictionary,c: BattleAnimationContext) -> void:
	if c.actors.get(t.original_target.id)!=t.original_target or not t.original_target.is_present():t.ticks=int(t.age);return
	match int(t.stage):
		0:
			var half: Vector2=t.picture_size/2
			var points: Array[Vector2]=[Vector2(half.x-4,half.y-4),Vector2(half.x-4,-half.y+4),Vector2(-half.x+4,half.y-4),Vector2(-half.x+4,-half.y-4),Vector2(half.x-4,half.y-4),Vector2.ZERO]
			t.destination=t.center+points[int(t.waypoint)];t.remaining=12 if int(t.waypoint)<4 else (24 if int(t.waypoint)==4 else 6)
			t.vx=Motion._delta(int(t.destination.x-t.origin.x),int(t.remaining));t.vy=Motion._delta(int(t.destination.y-t.origin.y),int(t.remaining));t.acc_x=0;t.acc_y=0;t.stage=1
		1:
			if int(t.remaining)==0:
				if int(t.waypoint)==5:t.stage=3;t.fade_count=0
				else:
					t.origin+=t.offset;t.offset=Vector2.ZERO;t.counter=0;t.stage=0 if int(t.waypoint)==4 else 2;t.waypoint=int(t.waypoint)+1
			else:
				t.acc_x=(int(t.acc_x)+int(t.vx))&65535;t.acc_y=(int(t.acc_y)+int(t.vy))&65535;t.remaining=int(t.remaining)-1
				t.offset=Vector2((int(t.acc_x)>>8)*(-1 if int(t.vx)&1 else 1),(int(t.acc_y)>>8)*(-1 if int(t.vy)&1 else 1));t.node.position=t.origin+t.offset
		2:
			t.counter=int(t.counter)+1
			if int(t.counter)==4:t.stage=0
		3:
			if int(t.fade_count)%2==0:t.eva=int(t.eva)-1
			else:t.evb=int(t.evb)+1
			t.node.material.set_shader_parameter("eva",float(t.eva)/16.0);t.node.material.set_shader_parameter("evb",float(t.evb)/16.0);t.fade_count=int(t.fade_count)+1
			if int(t.fade_count)==32:t.node.visible=false;t.stage=4
		4:t.ticks=int(t.age)
static func create_odor(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if c.contest:return []
	var target: BattleAnimationActor=_target(c)
	if target==null or not target.is_present():return []
	var t: Dictionary={"kind":"source_odor_sleuth","settings":step.duplicate(true),"owner":owner,"original_target":target,"children":[],"age":0,"ticks":4096,"update":advance_odor}
	for direction: int in [16,-16]:
		var node: Sprite2D=Identity.clone_sprite(target,owner);owner.add_child(node)
		var origin: Vector2=node.position;node.position+=Vector2(24 if direction>0 else -24,0);node.visible=direction>0;node.z_index=BattleSourcePriority.actor_layer(target,owner)
		t.children.append({"node":node,"origin":origin,"phase":0 if direction>0 else 128,"direction":direction,"radius":24,"stage":0,"counter":0,"blink":0})
	t.cleanup=_cleanup.bind(t)
	return [t]
static func _cleanup(t: Dictionary) -> void:
	t.erase("cleanup")
	for child: Dictionary in t.children:
		if is_instance_valid(child.node):child.node.queue_free()
	t.children.clear()
static func advance_odor(t: Dictionary,c: BattleAnimationContext) -> void:
	if t.children.is_empty() or c.actors.get(t.original_target.id)!=t.original_target or not t.original_target.is_present():t.ticks=int(t.age);return
	for child: Dictionary in t.children.duplicate():
		child.blink=int(child.blink)+1
		if int(child.blink)>1:child.blink=0;child.node.visible=not child.node.visible
		child.phase=(int(child.phase)+int(child.direction))&255;child.node.position=child.origin+Vector2(BattleSourceTrig.cosine(int(child.phase),int(child.radius)),0)
		child.counter=int(child.counter)+1
		if int(child.stage)==0:
			if int(child.counter)==60:child.counter=0;child.stage=1
		else:
			child.counter=0;child.radius=int(child.radius)-2
			if int(child.radius)<0:child.node.queue_free();t.children.erase(child)

extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## ground.c dirt continuations and water.c task/owned two-stage arc children.
static func create_dirt(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var actors: Array[BattleAnimationActor]=c.resolve("attacker");var a: Array=step.get("source_args",[])
	if actors.is_empty() or a.size()!=3 or str(step.get("source_callback",""))!="AnimMudSportDirt":return []
	var actor: BattleAnimationActor=actors[0];var falling: bool=int(a[0])!=0
	var origin: Vector2=Vector2(a[1],a[2]) if falling else BattleElectricContract.source_anchor(actor,c,"center")+Vector2(a[1],a[2])
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;owner.add_child(node)
	var t: Dictionary={"kind":"source_sport_dirt","settings":step.duplicate(true),"owner":owner,"original_actor":actor,"node":node,"origin":origin,"falling":falling,"direction":1 if int(a[1])>0 else -1,"age":0,"ticks":4096,"offset_y":-int(a[2]) if falling else 0,"stage":0,"flickers":0,"update":advance_dirt}
	BattleSourcePriority.initialize(t,c,owner);node.position=origin+Vector2(0,int(t.offset_y));_pose(node,step,0)
	return [t]
static func _pose(node: Sprite2D,step: Dictionary,age: int) -> void:
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(step.frame_program,age).frame
	var rect: Array=step.frame_rects[str(int(frame.tile))]
	node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);node.flip_h=bool(frame.get("flip_h",false));node.flip_v=bool(frame.get("flip_v",false))
static func advance_dirt(t: Dictionary,c: BattleAnimationContext) -> void:
	if c.actors.get(t.original_actor.id)!=t.original_actor or not t.original_actor.is_present():t.ticks=int(t.age);return
	if not t.falling:
		t.node.position=t.origin+Vector2(int(int(t.age)/2)*int(t.direction),-4*int(t.age))
		if t.node.position.y< -4:t.ticks=int(t.age)
	elif int(t.stage)==0:
		t.offset_y=int(t.offset_y)+4
		if int(t.offset_y)>=0:t.offset_y=0;t.stage=1
		t.node.position=t.origin+Vector2(0,int(t.offset_y))
	else:
		t.flickers=int(t.flickers)+1;t.node.visible=not t.node.visible
		if int(t.flickers)==10:t.ticks=int(t.age)
	_pose(t.node,t.settings,int(t.age))
static func create_water(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var actors: Array[BattleAnimationActor]=c.resolve("attacker")
	if actors.is_empty() or str(step.get("source_callback",""))!="sub_80D48F4":return []
	var actor: BattleAnimationActor=actors[0];var origin: Vector2=BattleElectricContract.source_anchor(actor,c,"center")
	var direction: int=(1 if actor.side==0 else -1)*(-1 if c.contest else 1)
	var t: Dictionary={"kind":"source_sport_water_task","settings":step.duplicate(true),"owner":owner,"original_actor":actor,"origin":origin,"direction":direction,"destination":origin+Vector2(direction*8,-direction*8),"age":0,"ticks":4096,"stage":0,"counter":0,"emit_counter":0,"crossings":0,"has_completed":false,"created":0,"completed":0,"children":[],"rng_state":c.seed_value&4294967295,"update":advance_water}
	t.cleanup=_cleanup.bind(t)
	return [t]
static func _word(t: Dictionary) -> int:
	t.rng_state=(1103515245*int(t.rng_state)+24691)&4294967295
	return int(t.rng_state)>>16
static func _delta(distance: int,duration: int) -> int:
	return (int(((absi(distance)<<8)&65535)/duration)&65534)|(1 if distance<0 else 0)
static func _arc(child: Dictionary,destination: Vector2,duration: int,amplitude: int) -> void:
	child.remaining=duration;child.acc_x=0;child.acc_y=0;child.phase=0;child.phase_step=int(32768/duration);child.amplitude=amplitude
	child.vx=_delta(int(destination.x-child.origin.x),duration);child.vy=_delta(int(destination.y-child.origin.y),duration)
static func _translate(child: Dictionary) -> bool:
	if int(child.remaining)==0:return true
	child.acc_x=(int(child.acc_x)+int(child.vx))&65535;child.acc_y=(int(child.acc_y)+int(child.vy))&65535
	child.phase=(int(child.phase)+int(child.phase_step))&65535
	child.offset=Vector2((int(child.acc_x)>>8)*(-1 if int(child.vx)&1 else 1),(int(child.acc_y)>>8)*(-1 if int(child.vy)&1 else 1)+BattleSourceTrig.sine((int(child.phase)>>8)&255,int(child.amplitude)))
	child.remaining=int(child.remaining)-1;return false
static func _emit(t: Dictionary,c: BattleAnimationContext) -> void:
	t.emit_counter=int(t.emit_counter)+1
	if int(t.emit_counter)<=1:return
	t.emit_counter=0
	var node:=Sprite2D.new();node.texture=load(str(t.settings.texture));node.region_enabled=true;node.position=t.origin;t.owner.add_child(node)
	var child: Dictionary={"node":node,"origin":t.origin,"offset":Vector2.ZERO,"age":0,"stage":0}
	_arc(child,t.destination,16,-32);_pose(node,t.settings,0)
	child.source_oam_subpriority=10;node.z_index=BattleSourcePriority.relative_layer(t.original_actor,10-BattleElectricContract.source_subpriority(t.original_actor,c),c,t.owner)
	child["serial"]=int(t.created)
	t.children.append(child);t.created=int(t.created)+1
static func _children(t: Dictionary) -> void:
	for child: Dictionary in t.children.duplicate():
		child.age=int(child.age)+1
		if _translate(child):
			if int(child.stage)==0:
				child.origin+=child.offset;child.stage=1
				var destination: Vector2=child.origin+Vector2((_word(t)&31)-16,(_word(t)&31)-16)
				_arc(child,destination,6,~(_word(t)&7))
			else:
				t.has_completed=true;t.completed=int(t.completed)+1
				child.node.queue_free();t.children.erase(child);continue
		child.node.position=child.origin+child.offset;_pose(child.node,t.settings,int(child.age))
static func advance_water(t: Dictionary,c: BattleAnimationContext) -> void:
	if c.actors.get(t.original_actor.id)!=t.original_actor or not t.original_actor.is_present():t.ticks=int(t.age);return
	var stage: int=int(t.stage)
	if stage<=5:_emit(t,c)
	match stage:
		0:
			if t.has_completed:t.stage=1
		1:
			t.counter=int(t.counter)+1
			if int(t.counter)>16:t.counter=0;t.stage=2
		2:
			t.destination.x+=int(t.direction)*6
			if t.destination.x< -16 or t.destination.x>256:
				t.crossings=int(t.crossings)+1;t.counter=0;t.stage=6 if int(t.crossings)>2 else 3
		3:
			t.destination.y-=int(t.direction)*2;t.counter=int(t.counter)+1
			if int(t.counter)>7:t.stage=4
		4:
			t.destination.x-=int(t.direction)*6
			if t.destination.x< -16 or t.destination.x>256:t.crossings=int(t.crossings)+1;t.counter=0;t.stage=5
		5:
			t.destination.y-=int(t.direction)*2;t.counter=int(t.counter)+1
			if int(t.counter)>7:t.stage=2
		6:
			if t.children.is_empty():t.stage=7
		_:t.ticks=int(t.age)
	_children(t)
static func _cleanup(t: Dictionary) -> void:
	t.erase("cleanup")
	for child: Dictionary in t.children:
		if is_instance_valid(child.node):child.node.queue_free()
	t.children.clear()

extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Literal fountain/angel/blow/rise private callbacks and actual love_bg.c task.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
const Motion=preload("res://scripts/battle/animations/sequence/source_sports.gd")
static func _node(step: Dictionary,owner: Node2D) -> Sprite2D:
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;owner.add_child(node)
	return node
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var attackers: Array[BattleAnimationActor]=c.resolve("attacker");var targets: Array[BattleAnimationActor]=c.resolve("target")
	if attackers.is_empty() or targets.is_empty():return []
	var kind: String=str(step.behavior);var a: Array=step.source_args
	var origin: Vector2=Geometry._anchor(targets[0],c,owner,"center")
	if kind=="source_kiss_angel":origin+=Vector2(a[0],a[1])
	elif kind=="source_kiss_travel":origin=Geometry._anchor(attackers[0],c,owner,"center")+Vector2(int(a[0])*BattleElectricContract.source_offset_direction(c,attackers[0],targets[0]),int(a[1]))
	elif kind=="source_kiss_rise":origin=Vector2(a[0],160)
	var node: Sprite2D=_node(step,owner);node.position=origin
	var t: Dictionary={"kind":kind,"settings":step.duplicate(true),"owner":owner,"node":node,"original_actor":attackers[0],"original_target":targets[0],"origin":origin,"age":0,"ticks":4096,"phase":0,"counter":0,"qx":0,"qy":0,"rises":0,"stage":"wait","remaining":int(a[2]) if kind=="source_kiss_rise" else 0,"update":advance}
	if kind=="source_kiss_angel":_angel(t) # CreateSpriteAndAnimate calls the initial sprite callback immediately.
	elif kind=="source_kiss_travel":
		t.destination=Geometry._anchor(targets[0],c,owner,"center");t.offset=Vector2.ZERO;t.wave_phase=0;Motion._arc(t,t.destination,95,0)
	BattleSourcePriority.initialize(t,c,owner);_pose(t)
	return [t]
static func _pose(t: Dictionary) -> void:
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.frame_program,int(t.age)).frame
	var rect: Array=t.settings.frame_rects[str(int(frame.tile))];t.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3])
static func _angel(t: Dictionary) -> void:
	t.counter=int(t.counter)+1
	var count: int=int(t.counter);var phase: int=(count*10)&255
	var x: int=BattleSourceTrig.sine(phase,80)>>8
	if count<=79:t.qy=int(count/2)+(BattleSourceTrig.cosine(phase,80)>>8)
	if count>90:x-=int((count-90)/2)
	t.node.position=t.origin+Vector2(x,int(t.qy))
	if count>100:t.ticks=int(t.age)
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if c.actors.get(t.original_actor.id)!=t.original_actor or c.actors.get(t.original_target.id)!=t.original_target or not t.original_actor.is_present() or not t.original_target.is_present():t.ticks=int(t.age);return
	var a: Array=t.settings.source_args
	match str(t.kind):
		"source_kiss_fountain":
			t.qx=((int(t.qx)+int(a[0])+32768)&65535)-32768
			t.node.position=t.origin+Vector2(int(t.qx)>>8,BattleSourceTrig.sine(int(t.phase),int(a[1])))
			t.phase=(int(t.phase)+3)&255
			if int(t.phase)>100:t.node.visible=int(t.phase)%2==0
			if int(t.phase)>120:t.ticks=int(t.age)
		"source_kiss_angel":_angel(t)
		"source_kiss_travel":
			if Motion._translate(t):t.ticks=int(t.age);return
			t.node.position=t.origin+t.offset+Vector2(0,BattleSourceTrig.sine(int(t.wave_phase),14));t.wave_phase=(int(t.wave_phase)+4)&255
		"source_kiss_rise":
			if t.stage=="wait":
				if int(t.remaining)>0:t.remaining=int(t.remaining)-1
				else:t.stage="rise"
			else:
				t.qy=(int(t.qy)+int(a[1]))&65535;t.rises=int(t.rises)+1
				t.node.position=t.origin+Vector2(BattleSourceTrig.sine(int(t.phase),4),-(int(t.qy)>>8));t.phase=(int(t.phase)+3)&255
				if t.node.position.y<=72:
					t.node.visible=int(t.phase)%2==0
					if t.node.position.y<=64:t.ticks=int(t.age)
	_pose(t)
static func create_background(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var node: Sprite2D=_node(step,owner);node.centered=false;node.region_rect=Rect2(Vector2.ZERO,c.field_size);node.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED;node.z_index=0
	BattleCounterSelected._blend_node(node,owner)
	node.material.set_shader_parameter("eva",0.0);node.material.set_shader_parameter("evb",1.0)
	return [{"kind":"source_kiss_background","settings":step.duplicate(true),"owner":owner,"node":node,"stage":0,"counter":0,"alpha":0,"age":0,"ticks":4096,"update":advance_background}]
static func advance_background(t: Dictionary,_c: BattleAnimationContext) -> void:
	match int(t.stage):
		0,2:
			t.counter=int(t.counter)+1
			if int(t.counter)==4:
				t.counter=0;t.alpha=int(t.alpha)+(1 if int(t.stage)==0 else -1)
				if int(t.alpha)==16 or int(t.alpha)==0:t.stage=int(t.stage)+1
		1:
			t.counter=int(t.counter)+1
			if int(t.counter)==141:t.counter=0;t.stage=2
		3:t.ticks=int(t.age)
	t.node.material.set_shader_parameter("eva",float(t.alpha)/16.0);t.node.material.set_shader_parameter("evb",float(16-int(t.alpha))/16.0)

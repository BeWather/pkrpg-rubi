extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## ice.c:1204–1356: packed-Q8 approach, target orbit/drift, speed-derived exit.
static func _delta(distance: int,duration: int) -> int:
	return (int(((absi(distance)<<8)&65535)/duration)&65534)|(1 if distance<0 else 0)
static func _setup(t: Dictionary,destination: Vector2,duration: int) -> void:
	t.remaining=maxi(1,duration);t.acc_x=0;t.acc_y=0
	t.vx=_delta(int(destination.x-t.origin.x),int(t.remaining));t.vy=_delta(int(destination.y-t.origin.y),int(t.remaining))
	t.sign_x=-1 if int(t.vx)&1 else 1;t.sign_y=-1 if int(t.vy)&1 else 1
static func _linear(t: Dictionary) -> bool:
	if int(t.remaining)==0:return true
	t.acc_x=(int(t.acc_x)+int(t.vx))&65535;t.acc_y=(int(t.acc_y)+int(t.vy))&65535
	t.offset=Vector2((int(t.acc_x)>>8)*int(t.sign_x),(int(t.acc_y)>>8)*int(t.sign_y))
	t.remaining=int(t.remaining)-1;return false
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var attackers: Array[BattleAnimationActor]=c.resolve("attacker");var targets: Array[BattleAnimationActor]=c.resolve("target")
	var a: Array=step.get("source_args",[]).duplicate()
	if attackers.is_empty() or targets.is_empty() or a.size()!=8 or str(step.get("source_callback",""))!="InitPoisonGasCloudAnim":return []
	var attacker: BattleAnimationActor=attackers[0];var target: BattleAnimationActor=targets[0]
	var origin: Vector2=BattleElectricContract.source_anchor(attacker,c,"center")
	if target.side==0:
		a[1]=-int(a[1]);a[3]=-int(a[3]);owner._source_args[1]=int(a[1])&65535;owner._source_args[3]=int(a[3])&65535
	var destination: Vector2=BattleElectricContract.source_anchor(target,c,"center" if int(a[7]) else "origin")+Vector2(int(a[3]),int(a[4]))
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;owner.add_child(node)
	var t: Dictionary={"kind":"source_poison_gas","settings":step.duplicate(true),"owner":owner,"node":node,"attacker":attacker,"target":target,"origin":origin,"offset":Vector2.ZERO,"age":0,"ticks":4096,"update":advance,"stage":0,"phase":0,"phase_reverse":target.side==0 or c.contest,"bg_priority":2 if c.contest or c.source_position(target.id) in [0,3] else 1}
	_setup(t,destination,int(a[0]));BattleSourcePriority.initialize(t,c,owner)
	if target.side==0 and origin.x<BattleElectricContract.source_anchor(target,c,"center").x and attacker.side==0:node.z_index=BattleSourcePriority.relative_layer(target,1,c,owner)
	if c.contest:t.source_oam_subpriority=128
	BattleCounterSelected._blend_node(node,owner);node.position=origin;_pose(t)
	return [t]
static func _pose(t: Dictionary) -> void:
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.frame_program,int(t.age)).frame
	var rect: Array=t.settings.frame_rects[str(int(frame.tile))]
	t.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);t.node.flip_h=bool(frame.get("flip_h",false));t.node.flip_v=bool(frame.get("flip_v",false))
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if c.actors.get(t.attacker.id)!=t.attacker or c.actors.get(t.target.id)!=t.target or not t.attacker.is_present() or not t.target.is_present():t.ticks=int(t.age);return
	match int(t.stage):
		0:
			_linear(t);t.offset.x+=BattleSourceTrig.sine(int(t.phase),256)>>4
			t.phase=(int(t.phase)+(-8 if t.phase_reverse else 8))&255
			if int(t.remaining)<=0:
				t.origin=Vector2(BattleElectricContract.source_anchor(t.target,c,"origin").x,t.origin.y+t.offset.y)
				t.stage=1;t.phase=80 if c.contest or t.target.side==0 else 204
				t.offset=Vector2(BattleSourceTrig.sine(int(t.phase),256)>>3,0);t.phase=(int(t.phase)+2)&255
				_setup(t,t.origin+Vector2(0,29),80)
		1:
			_linear(t);t.offset.x+=BattleSourceTrig.sine(int(t.phase),256)>>3
			t.offset.y+=(BattleSourceTrig.cosine(int(t.phase),256)*-3)>>8
			var front: bool=(((int(t.phase)-64)&65535)<=127)
			t.source_oam_priority=int(t.bg_priority)+(0 if front else 1)
			if c.contest:t.source_oam_subpriority=128 if front else 140
			t.node.z_index=BattleSourcePriority.relative_layer(t.target,1 if front else -1,c,t.owner)
			t.phase=(int(t.phase)+(-4 if c.contest else 4))&255
			if int(t.remaining)<=0:
				t.origin+=t.offset;t.offset=Vector2.ZERO;t.stage=2
				var destination: Vector2=Vector2(-16 if c.contest or t.target.side==0 else 256,t.origin.y+4)
				_setup(t,destination,int((absi(int(destination.x-t.origin.x))<<8)/768))
		2:
			if _linear(t):t.ticks=int(t.age)
	t.node.position=t.origin+t.offset;_pose(t)

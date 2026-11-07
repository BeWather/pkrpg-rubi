extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Ruby normal.c duck orbit and fire_2.c delayed burn helper; native OAM projection.
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var attackers: Array[BattleAnimationActor]=c.resolve("attacker");var targets: Array[BattleAnimationActor]=c.resolve("target")
	if attackers.is_empty() or targets.is_empty():return []
	var mode: String=str(step.get("mode",""));var a: Array=step.get("source_args",[]).duplicate()
	if mode not in ["duck","burn"] or a.size()!=(5 if mode=="duck" else 7):return []
	if str(step.get("source_callback",""))!=("AnimConfusionDuck" if mode=="duck" else "sub_80D5210"):return []
	var attacker: BattleAnimationActor=attackers[0];var target: BattleAnimationActor=targets[0]
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;owner.add_child(node)
	var origin: Vector2=BattleElectricContract.source_anchor(target,c,"center")
	var t: Dictionary={"kind":"source_status_aux","settings":step.duplicate(true),"owner":owner,"node":node,"attacker":attacker,"target":target,"origin":origin,"args":a,"age":0,"ticks":4096,"update":advance,"phase":int(a[2]) if mode=="duck" else 0,"count":0,"stage":0,"remaining":int(a[4]),"qx":0,"qy":0}
	BattleSourcePriority.initialize(t,c,owner)
	if mode=="duck":
		t.origin=origin+Vector2(a[0],a[1]);t.direction=1 if attacker.side==0 else -1
		t.frames=step.source_side_frames["0" if attacker.side==0 else "1"];_duck(t,c)
	else:
		a[0]=-int(a[0]);a[2]=-int(a[2]);node.position=origin
		owner._source_args[0]=int(a[0])&65535;owner._source_args[2]=int(a[2])&65535
	_pose(t)
	return [t]
static func _duck(t: Dictionary,c: BattleAnimationContext) -> void:
	var angle: int=int(t.phase)
	t.node.position=t.origin+Vector2(BattleSourceTrig.cosine(angle,30),BattleSourceTrig.sine(angle,10))
	t.source_oam_priority=1 if angle<128 else 3
	t.node.z_index=BattleSourcePriority.relative_layer(t.target,-1 if angle<128 else 1,c,t.owner)
	t.phase=(angle+int(t.args[3])*int(t.direction))&255;t.count=int(t.count)+1
	if int(t.count)==int(t.args[4]):t.ticks=int(t.age)
static func _delta(distance: int,duration: int) -> int:
	return ((int((absi(distance)<<8)/duration)&65534)|(1 if distance<0 else 0))&65535
static func _burn_setup(t: Dictionary,c: BattleAnimationContext) -> void:
	var a: Array=t.args
	var base: Vector2=BattleElectricContract.source_anchor(t.target,c,"origin")
	var direction: int=BattleElectricContract.source_offset_direction(c,t.attacker,t.target)
	t.origin=base+Vector2(int(a[0])*direction,int(a[1]))
	if t.attacker.side!=0:
		a[2]=-int(a[2]);t.owner._source_args[2]=int(a[2])&65535
	var x: int=int(a[2])
	var destination: Vector2=Vector2(BattleElectricContract.source_anchor(t.target,c,"center").x+x,base.y+int(a[3]))
	t.destination=destination;t.vx=_delta(int(destination.x-t.origin.x),int(t.remaining));t.vy=_delta(int(destination.y-t.origin.y),int(t.remaining))
	t.node.position=t.origin;t.stage=1
static func _linear(t: Dictionary) -> void:
	if int(t.remaining)==0:t.stage=3;return
	t.qx=(int(t.qx)+int(t.vx))&65535;t.qy=(int(t.qy)+int(t.vy))&65535
	t.node.position=t.origin+Vector2((int(t.qx)>>8)*(-1 if int(t.vx)&1 else 1),(int(t.qy)>>8)*(-1 if int(t.vy)&1 else 1))
	t.remaining=int(t.remaining)-1
static func _pose(t: Dictionary) -> void:
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(t.get("frames",t.settings.frame_program),int(t.age)).frame
	var rect: Array=t.settings.frame_rects[str(int(frame.tile))]
	t.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);t.node.flip_h=bool(frame.get("flip_h",false));t.node.flip_v=bool(frame.get("flip_v",false))
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if c.actors.get(t.attacker.id)!=t.attacker or c.actors.get(t.target.id)!=t.target or not t.attacker.is_present() or not t.target.is_present():t.node.visible=false;t.ticks=int(t.age);return
	if str(t.settings.mode)=="duck":_duck(t,c)
	elif int(t.stage)==0:_burn_setup(t,c)
	elif int(t.stage)==1:t.stage=2;_linear(t)
	elif int(t.stage)==2:_linear(t)
	else:t.ticks=int(t.age)
	_pose(t)

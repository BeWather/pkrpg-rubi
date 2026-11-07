extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Execution-local palette transform buffers feed the real owned material/BG.
## Empty chains mean that bank's original native palette, not a fabricated color.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func _state(owner: Node,c: BattleAnimationContext) -> Dictionary:
	if not owner.has_meta("source_overheat_state"):
		var banks: Dictionary={}
		for key: String in ["bg:1","bg:2","bg:3"]:banks[key]={"u":[],"f":[]}
		for actor: BattleAnimationActor in c.actors.values():banks["actor:"+str(actor.id)]={"u":[],"f":[]}
		owner.set_meta("source_overheat_state",{"banks":banks,"backups":{},"events":[]})
	return owner.get_meta("source_overheat_state")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if s.behavior=="source_overheat_monbg":return BattleCounterSelected.create(s,c,owner)
	if s.behavior=="source_overheat_impact":
		var result: Array[Dictionary]=BattleFieldOwned.create(s,c,owner)
		for t: Dictionary in result:BattleCounterSelected._blend_node(t.node,owner)
		return result
	var state: Dictionary=_state(owner,c)
	if s.behavior=="source_overheat_bank":
		var key: String="bg:1" if int(s.source_args[0])==0 else "actor:"+str(c.attacker_id)
		var bank: Dictionary=state.banks[key]
		if s.mode=="backup":state.backups[int(s.source_args[1])]={"bank":key,"ops":bank.u.duplicate(true)}
		elif s.mode=="restore_u":bank.u=state.backups[int(s.source_args[1])].ops.duplicate(true)
		else:bank.u=bank.f.duplicate(true)
		state.events.append(str(s.mode)+":"+key);return []
	var t: Dictionary={"kind":str(s.behavior),"settings":s,"owner":owner,"age":0,"ticks":int(s.ticks),"update":advance}
	if s.behavior=="source_overheat_fade":
		t.keys=["bg:1"] if c.contest else ["bg:1","bg:2","bg:3"]
		if int(s.source_args[0])==2:t.keys=["actor:"+str(c.attacker_id)]
		t.amount=int(s.source_args[2]);t.destination=int(s.source_args[3]);t.delta=2+maxi(0,-int(s.source_args[1]));t.delay=maxi(0,int(s.source_args[1]));t.counter=0;t.obj_half=true;t.finishing=-1
		var packed: int=int(s.source_args[4]);t.color=Color(float(packed&31)/31.0,float((packed>>5)&31)/31.0,float((packed>>10)&31)/31.0);_paint(t,c,false);return [t]
	var actors: Array[BattleAnimationActor]=c.resolve("attacker")
	if actors.is_empty():return []
	var a: Array=s.source_args;var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;owner.add_child(node)
	t.node=node;t.original_actor=actors[0];t.velocity=Vector2(BattleSourceTrig.cosine(int(a[1]),int(a[2])),BattleSourceTrig.sine(int(a[1]),int(a[2])*3/5));t.origin=Geometry._anchor(actors[0],c,owner,"center")+Vector2(0,int(a[4]))+t.velocity*int(a[0]);node.position=t.origin;BattleSourcePriority.initialize(t,c,owner);_frame(t,0);return [t]
static func _compose(ops: Array) -> Dictionary:
	var amount: float=0.0;var sum: Vector3=Vector3.ZERO
	for op: Dictionary in ops:
		var a: float=float(op.amount)/16.0;var color: Color=op.color
		sum=sum*(1.0-a)+Vector3(color.r,color.g,color.b)*a;amount=amount*(1.0-a)+a
	return {"color":Color(sum.x/amount,sum.y/amount,sum.z/amount) if amount>0 else Color.WHITE,"amount":amount}
static func _paint(t: Dictionary,c: BattleAnimationContext,obj: bool) -> void:
	var st: Dictionary=_state(t.owner,c)
	for key: String in t.keys:
		if key.begins_with("actor:")!=obj:continue
		var bank: Dictionary=st.banks[key];bank.f=bank.u.duplicate(true)
		if int(t.amount)>0:bank.f.append({"color":t.color,"amount":int(t.amount)})
		if obj:
			var id: int=int(key.trim_prefix("actor:"));var actor: BattleAnimationActor=c.actors[id];var blend: Dictionary=_compose(bank.f);blend.source_actor=actor;t.owner._held_blends[id]=blend
	if not obj and "bg:1" in t.keys:
		var blend: Dictionary=_compose(st.banks["bg:1"].f);var owner: Node2D=t.owner
		if not is_instance_valid(owner._background_blend):owner._background_blend=Polygon2D.new();owner._background_blend.polygon=PackedVector2Array([Vector2.ZERO,Vector2(240,0),Vector2(240,160),Vector2(0,160)]);owner.add_child(owner._background_blend)
		owner._background_blend.color=Color(blend.color,blend.amount)
static func _frame(t: Dictionary,age: int) -> void:
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.frame_program,age).frame;var r: Array=t.settings.frame_rects[str(int(frame.tile))];t.node.region_rect=Rect2(r[0],r[1],r[2],r[3])
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if t.kind=="source_overheat_ember":
		t.node.position=t.origin+Vector2(int(int(t.age)*int(t.velocity.x)/10.0),int(int(t.age)*int(t.velocity.y)/10.0));_frame(t,int(t.age));return
	if int(t.finishing)>=0:t.finishing=int(t.finishing)+1;return
	if not bool(t.obj_half):
		if int(t.counter)<int(t.delay):t.counter=int(t.counter)+1;return
		t.counter=0;_paint(t,c,false)
	else:_paint(t,c,true)
	t.obj_half=not bool(t.obj_half)
	if not bool(t.obj_half):
		if int(t.amount)==int(t.destination):t.finishing=0
		else:t.amount=mini(int(t.amount)+int(t.delta),int(t.destination)) if int(t.amount)<int(t.destination) else maxi(int(t.amount)-int(t.delta),int(t.destination))

extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

const SourceCoordinates = preload("res://scripts/battle/animations/sequence/source_coordinate_contract.gd")
## bug.c source callbacks. Hardware alpha is projected onto the owned web only.
static func _average(actor: BattleAnimationActor,c: BattleAnimationContext,mode: String) -> Vector2:
	var point: Vector2=BattleElectricContract.source_anchor(actor,c,mode)
	var partners: Array[BattleAnimationActor]=c.resolve("target_partner")
	if not c.contest and not partners.is_empty() and partners[0].is_present() and partners[0].sprite.is_visible_in_tree():
		point=(point+BattleElectricContract.source_anchor(partners[0],c,mode))/2.0
	return point
static func _nominal_average(actor: BattleAnimationActor, c: BattleAnimationContext) -> Dictionary:
	var operands: Array[Dictionary] = [SourceCoordinates.nominal(actor, c)]
	var partners: Array[BattleAnimationActor] = c.resolve("target_partner")
	# Retain native visible/present partner policy; not unconditional Ruby doubles.
	if not c.contest and not partners.is_empty() and partners[0].is_present() and partners[0].sprite.is_visible_in_tree():
		operands.append(SourceCoordinates.nominal(partners[0], c))
	# Resolve all participating operands before a missing entry can select legacy.
	var missing := false
	for operand: Dictionary in operands:
		if operand.state == "invalid": return operand
		if operand.state == "missing": missing = true
	if missing: return {"state":"missing"}
	var nominal: Dictionary = operands[0]
	if operands.size() == 2:
		var sum: Vector2 = nominal.point + operands[1].point
		nominal.point = Vector2(int(sum.x / 2.0), int(sum.y / 2.0))
	return nominal
static func _delta(distance: int,duration: int) -> int:
	return (int(((absi(distance)<<8)&65535)/duration)&65534)|(1 if distance<0 else 0)
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var attackers: Array[BattleAnimationActor]=c.resolve("attacker");var targets: Array[BattleAnimationActor]=c.resolve("target")
	if attackers.is_empty() or targets.is_empty():return []
	var a: Array=step.get("source_args",[]);var mode: String=str(step.get("mode",""))
	if mode not in ["dot","string","web"] or a.size()!={"dot":5,"string":2,"web":0}[mode]:return []
	var attacker: BattleAnimationActor=attackers[0];var target: BattleAnimationActor=targets[0]
	var nominal: Dictionary = {"state":"missing"}
	if mode == "string" and owner.definition != null and owner.definition.key == "ruby:move/81":
		nominal = _nominal_average(target, c)
		if nominal.state == "invalid": return []
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;owner.add_child(node)
	var origin: Vector2=BattleElectricContract.source_anchor(target,c,"center")
	var t: Dictionary={"kind":"source_string_web","mode":mode,"settings":step.duplicate(true),"owner":owner,"node":node,"attacker":attacker,"target":target,"origin":origin,"age":0,"ticks":4096,"update":advance,"phase":0,"acc_x":0,"acc_y":0,"remaining":0,"sign_x":1,"sign_y":1}
	if mode=="dot":
		t.origin=BattleElectricContract.source_anchor(attacker,c,"center")+Vector2(int(a[0])*(1 if attacker.side==0 else -1),int(a[1]))
		var destination: Vector2=_average(target,c,"center") if int(a[4])!=0 else origin
		var speed: int=int(a[2])/2 if c.contest else int(a[2])
		if c.contest:owner._source_args[2]=speed
		t.remaining=maxi(1,int((absi(int(destination.x-t.origin.x))<<8)/speed))
		t.vx=_delta(int(destination.x-t.origin.x),int(t.remaining));t.vy=_delta(int(destination.y-t.origin.y),int(t.remaining))
		t.sign_x=-1 if int(t.vx)&1 else 1;t.sign_y=-1 if int(t.vy)&1 else 1;t.amplitude=int(a[3])
	elif mode=="string":
		t.origin=(nominal.point if nominal.state == "valid" else _average(target,c,"origin"))+Vector2(int(a[0])*(1 if attacker.side==0 else -1),int(a[1])+(8 if target.side==0 else 0))
		if nominal.state == "valid": t.source_nominal_field = weakref(c.field)
	node.position=SourceCoordinates.to_owner(c.field,owner,t.origin) if t.has("source_nominal_field") else t.origin
	BattleSourcePriority.initialize(t,c,owner);_pose(t)
	return [t]
static func _pose(t: Dictionary) -> void:
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.frame_program,int(t.age)).frame
	var rect: Array=t.settings.frame_rects[str(int(frame.tile))]
	t.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);t.node.flip_h=bool(frame.get("flip_h",false));t.node.flip_v=bool(frame.get("flip_v",false))
	if t.mode=="web":
		var pose: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.affine_program,int(t.age),true)
		t.node.scale=Vector2(256.0/float(pose.matrix.x),256.0/float(pose.matrix.y))
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if c.actors.get(t.attacker.id)!=t.attacker or c.actors.get(t.target.id)!=t.target or not t.attacker.is_present() or not t.target.is_present():t.ticks=int(t.age);return
	if t.mode=="dot":
		if int(t.remaining)==0:t.ticks=int(t.age);return
		t.acc_x=(int(t.acc_x)+int(t.vx))&65535;t.acc_y=(int(t.acc_y)+int(t.vy))&65535
		t.node.position=t.origin+Vector2((int(t.acc_x)>>8)*int(t.sign_x)+BattleSourceTrig.sine(int(t.phase),int(t.amplitude)),(int(t.acc_y)>>8)*int(t.sign_y))
		t.phase=(int(t.phase)+13)&255;t.remaining=int(t.remaining)-1
	elif t.mode=="string":
		if t.has("source_nominal_field"):
			var field: Node2D = t.source_nominal_field.get_ref() as Node2D
			if not is_instance_valid(field) or not field.is_inside_tree():
				t.node.visible = false; t.ticks = int(t.age); return
			t.node.position = SourceCoordinates.to_owner(field, t.owner, t.origin)
		if int(t.age)%3==0:t.node.visible=not t.node.visible
		if int(t.age)==51:t.ticks=int(t.age)
	else:
		var eva: int=16-maxi(0,int((int(t.age)-20)/2))
		t.node.modulate.a=clampf(float(eva)/16.0,0.0,1.0)
		if int(t.age)>=52:t.node.visible=false
		if int(t.age)>=53:t.ticks=int(t.age)
	_pose(t)

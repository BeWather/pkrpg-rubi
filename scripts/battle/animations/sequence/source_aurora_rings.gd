extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## aurora.c:62–127. Tag0x279C is the ring palette, not the comment's attacker.
static func create_palette(step: Dictionary,_c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if str(step.get("source_callback",""))!="AnimTask_RotateMonPalette1":return []
	return [{"kind":"source_aurora_palette","settings":step.duplicate(true),"owner":owner,"age":0,"ticks":130,"cycle":0,"update":advance_palette}]
static func advance_palette(t: Dictionary,_c: BattleAnimationContext) -> void:
	t.cycle=int(int(t.age)/3)%8
static func create_ring(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var attackers: Array[BattleAnimationActor]=c.resolve("attacker");var targets: Array[BattleAnimationActor]=c.resolve("target");var a: Array=step.get("source_args",[])
	if attackers.is_empty() or targets.is_empty() or a.size()!=5 or str(step.get("source_callback",""))!="AnimAuroraRings":return []
	var actor: BattleAnimationActor=attackers[0];var target: BattleAnimationActor=targets[0]
	var direction: int=1 if actor.side==0 else -1
	var origin: Vector2=BattleElectricContract.source_anchor(actor,c,"center")+Vector2(int(a[0])*direction,int(a[1]))
	var destination: Vector2=BattleElectricContract.source_anchor(target,c,"center")+Vector2(int(a[2])*direction,int(a[3]))
	var vx: int=preload("res://scripts/battle/animations/sequence/source_sports.gd")._delta(int(destination.x-origin.x),int(a[4]));var vy: int=preload("res://scripts/battle/animations/sequence/source_sports.gd")._delta(int(destination.y-origin.y),int(a[4]))
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;owner.add_child(node)
	var t: Dictionary={"kind":"source_aurora_ring","settings":step.duplicate(true),"owner":owner,"node":node,"original_actor":actor,"original_target":target,"origin":origin,"age":0,"ticks":4096,"remaining":int(a[4]),"vx":vx,"vy":vy,"sign_x":-1 if vx&1 else 1,"sign_y":-1 if vy&1 else 1,"acc_x":0,"acc_y":0,"waiting":true,"affine_age":0,"tile":0,"palette_cycle":0,"update":advance_ring}
	BattleSourcePriority.initialize(t,c,owner);_callback(t);_pose(t)
	return [t]
static func _callback(t: Dictionary) -> void:
	if (int(t.owner._source_args.get(7,0))&65535)==65535:t.waiting=false;t.tile=4
	if not t.waiting:t.affine_age=int(t.affine_age)+1
	if int(t.remaining)==0:t.ticks=int(t.age);return
	t.acc_x=(int(t.acc_x)+int(t.vx))&65535;t.acc_y=(int(t.acc_y)+int(t.vy))&65535;t.remaining=int(t.remaining)-1
	t.node.position=t.origin+Vector2((int(t.acc_x)>>8)*int(t.sign_x),(int(t.acc_y)>>8)*int(t.sign_y))
static func _pose(t: Dictionary) -> void:
	for track: Dictionary in t.owner._tracks:
		if track.kind=="source_aurora_palette":t.palette_cycle=int(track.cycle);break
	var rect: Array=t.settings.frame_rects[str(int(t.tile))]
	t.node.region_rect=Rect2(rect[0],int(rect[1])+int(t.palette_cycle)*int(t.settings.source_palette_cycle_height),rect[2],rect[3])
	var pose: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.affine_program,int(t.affine_age),true)
	t.node.scale=Vector2(256.0/float(pose.matrix.x),256.0/float(pose.matrix.y))
static func advance_ring(t: Dictionary,c: BattleAnimationContext) -> void:
	if c.actors.get(t.original_actor.id)!=t.original_actor or c.actors.get(t.original_target.id)!=t.original_target or not t.original_actor.is_present() or not t.original_target.is_present():t.ticks=int(t.age);return
	_callback(t);_pose(t)

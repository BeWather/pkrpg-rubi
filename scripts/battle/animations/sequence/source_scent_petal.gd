extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## battle_anim_effects_3.c:2810–2853: independent petal crossing, not a projectile.
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var attackers: Array[BattleAnimationActor]=c.resolve("attacker");var targets: Array[BattleAnimationActor]=c.resolve("target")
	var a: Array=step.get("source_args",[])
	if attackers.is_empty() or targets.is_empty() or a.size() not in [2,3] or str(step.get("source_callback",""))!="sub_812E7A0":return []
	var attacker: BattleAnimationActor=attackers[0]
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;owner.add_child(node)
	var direction: int=1 if attacker.side==0 else -1
	var base_y: int=int(a[0])-(30 if attacker.side!=0 else 0)
	var t: Dictionary={"kind":"source_scent_petal","settings":step.duplicate(true),"owner":owner,"node":node,"attacker":attacker,"target":targets[0],"direction":direction,"base_x":0 if attacker.side==0 else 240,"base_y":base_y,"unused_data2":int(owner._source_args.get(2,0)),"phase":0,"age":0,"ticks":4096,"update":advance}
	node.position=Vector2(int(t.base_x),base_y);BattleSourcePriority.initialize(t,c,owner);_pose(t)
	return [t]
static func _pose(t: Dictionary) -> void:
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.frame_program,int(t.age)).frame
	var rect: Array=t.settings.frame_rects[str(int(frame.tile))]
	t.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);t.node.flip_h=bool(frame.get("flip_h",false));t.node.flip_v=bool(frame.get("flip_v",false))
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if c.actors.get(t.attacker.id)!=t.attacker or c.actors.get(t.target.id)!=t.target or not t.attacker.is_present() or not t.target.is_present():t.ticks=int(t.age);return
	t.phase=(int(t.phase)+3)&255
	var x: int=int(t.base_x)+5*int(t.age)*int(t.direction)
	var wave: int=BattleSourceTrig.sine(int(t.phase),16) if int(t.direction)==1 else BattleSourceTrig.cosine(int(t.phase),16)
	t.node.position=Vector2(x,int(t.base_y)-int(t.age)*int(t.direction)+wave)
	if x>240 or x<0:t.ticks=int(t.age)
	_pose(t)

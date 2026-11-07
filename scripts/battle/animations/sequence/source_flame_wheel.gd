extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Distinct source expanding orbits; palette task selects target OBJ only.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if s.behavior=="source_flame_monbg":
		if s.get("source_priority_side_guard",false):
			var attackers: Array[BattleAnimationActor]=c.resolve("attacker");var targets: Array[BattleAnimationActor]=c.resolve("target")
			if attackers.is_empty() or targets.is_empty() or attackers[0].side==targets[0].side:return []
		return BattleCounterSelected.create(s,c,owner)
	var t: Dictionary={"kind":str(s.behavior),"settings":s,"owner":owner,"age":0,"ticks":int(s.ticks),"update":advance}
	var actors: Array[BattleAnimationActor]=c.resolve("target" if s.behavior=="source_flame_palette" else "attacker")
	if actors.is_empty():return []
	t.original_actor=actors[0]
	if s.behavior=="source_flame_palette":
		t.amount=0;t.clones=[]
		for bg: Dictionary in owner.get_meta("source_counter_monbg",[]):
			for clone: Dictionary in bg.clones:
				if clone.actor!=actors[0]:continue
				var material:=ShaderMaterial.new();material.shader=load("res://scripts/battle/animations/sequence/palette_blend.gdshader");material.set_shader_parameter("blend_color",Color.RED)
				t.clones.append({"node":clone.node,"previous":clone.node.material,"material":material});clone.node.material=material
		t.cleanup=_cleanup.bind(t);return [t]
	var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;node.visible=false;owner.add_child(node)
	t.node=node;t.origin=Geometry._anchor(actors[0],c,owner,"center");node.position=t.origin;t.radius_q8=0;t.phase=0;t.delay=int(s.source_args[3]);t.remaining=56;t.stage="wait";BattleSourcePriority.initialize(t,c,owner);_frame(t);return [t]
static func _frame(t: Dictionary) -> void:
	var pose: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.frame_program,int(t.age));var rect: Array=t.settings.frame_rects[str(int(pose.frame.tile))]
	t.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);t.node.flip_h=bool(pose.frame.get("flip_h",false));t.node.flip_v=bool(pose.frame.get("flip_v",false))
static func _cleanup(t: Dictionary) -> void:
	t.erase("cleanup")
	for clone: Dictionary in t.clones:
		if is_instance_valid(clone.node) and clone.node.material==clone.material:clone.node.material=clone.previous
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if not t.original_actor.is_present():t.ticks=int(t.age);return
	if t.kind=="source_flame_palette":
		t.amount=int(t.age) if int(t.age)<=12 else 24-int(t.age)
		t.owner._held_blends[t.original_actor.id]={"color":Color.RED,"amount":float(t.amount)/16.0,"source_actor":t.original_actor}
		# Ruby monbg maintenance copies the selected faded OBJ palette to its BG.
		# Local owned clone projection, never a global BG/palette/alpha repair.
		for clone: Dictionary in t.clones:
			if is_instance_valid(clone.node) and clone.node.material==clone.material:clone.material.set_shader_parameter("blend_amount",float(t.amount)/16.0)
		return
	if t.stage=="wait":
		if int(t.delay)>0:t.delay=int(t.delay)-1
		else:t.stage="start"
	else:
		if t.stage=="start":t.node.visible=true;t.stage="orbit"
		t.node.position=t.origin+Vector2(BattleSourceTrig.sine(int(t.phase),int(t.radius_q8)>>8),BattleSourceTrig.cosine(int(t.phase),int(t.radius_q8)>>8));t.phase=(int(t.phase)+10)&255;t.radius_q8=int(t.radius_q8)+208;t.remaining=int(t.remaining)-1
		if int(t.remaining)==-1:t.ticks=int(t.age)
	_frame(t)

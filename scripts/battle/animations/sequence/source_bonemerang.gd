extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## ground.c155–187: packed20-update outgoing/return arcs; opaque affine OBJ.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
const Packed=preload("res://scripts/battle/animations/sequence/source_sports.gd")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if s.behavior=="source_bonemerang_command":return BattleCounterSelected.create(s,c,owner)
	var actor: BattleAnimationActor=c.resolve("attacker")[0];var target: BattleAnimationActor=c.resolve("target")[0]
	var t: Dictionary={"kind":s.behavior,"settings":s,"owner":owner,"original_actor":actor,"original_target":target,"age":0,"ticks":int(s.ticks),"stage":0,"offset":Vector2.ZERO,"update":advance}
	if s.behavior=="source_bonemerang_lunge":t.cleanup=_restore.bind(t);return [t]
	var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;var rect: Array=s.frame_rects["0"];node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);owner.add_child(node);var material:=ShaderMaterial.new();material.shader=load("res://scripts/battle/animations/sequence/source_bonemerang.gdshader");node.material=material;t.node=node;t.origin=Geometry._anchor(actor,c,owner,"center");t.destination=Geometry._anchor(target,c,owner,"center");Packed._arc(t,t.destination,20,-40);node.position=t.origin;BattleSourcePriority.initialize(t,c,owner);return [t]
static func _restore(t: Dictionary) -> void:
	if t.owner._held_offsets.get(t.original_actor.id,Vector2.ZERO)==t.offset:t.owner._held_offsets[t.original_actor.id]=Vector2.ZERO
	t.erase("cleanup")
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if not t.original_actor.is_present() or not t.original_target.is_present():t.ticks=int(t.age);return
	if t.kind=="source_bonemerang_lunge":
		var n: int=int(t.age)-1
		# Init; six updates; stored reverse callback; six updates; destroy.
		var count: int=mini(n,6) if n<=7 else maxi(0,14-n)
		t.offset=Vector2(count*(-4 if t.original_actor.side==0 else 4),0);t.owner._held_offsets[t.original_actor.id]=t.offset
		if n==16:_restore(t)
		return
	var pose: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.affine_program,int(t.age),true);t.node.rotation=float(pose.rotation)*TAU/256.0;t.node.material.set_shader_parameter("source_rotation",t.node.rotation)
	if int(t.age)==1:return
	if Packed._translate(t):
		if int(t.stage)==1:t.ticks=int(t.age);return
		t.origin+=t.offset;t.offset=Vector2.ZERO;t.stage=1;t.destination=Geometry._anchor(t.original_actor,c, t.owner,"center");Packed._arc(t,t.destination,20,40)
	t.node.position=t.origin+t.offset

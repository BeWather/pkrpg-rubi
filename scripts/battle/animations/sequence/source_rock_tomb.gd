extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Actual source acceleration then hold; final y2 is deliberately NOT snapped.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var targets: Array[BattleAnimationActor]=c.resolve("target")
	if targets.is_empty():return []
	var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;node.visible=false;owner.add_child(node)
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(s.frame_program,0).frame;var rect: Array=s.frame_rects[str(int(frame.tile))];node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3])
	var t: Dictionary={"kind":"source_tomb_rock","settings":s,"owner":owner,"node":node,"original_actor":targets[0],"origin":Geometry._anchor(targets[0],c,owner,"center"),"height":-int(s.source_args[2]),"velocity":3,"remaining":int(s.source_args[3]),"age":0,"ticks":int(s.ticks),"update":advance}
	node.position=t.origin+Vector2(int(s.source_args[0]),0);BattleSourcePriority.initialize(t,c,owner);return [t]
static func advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	if not t.original_actor.is_present():t.ticks=int(t.age);return
	t.node.visible=true
	if int(t.height)!=0:
		t.node.position=t.origin+Vector2(int(t.settings.source_args[0]),int(t.settings.source_args[1])+int(t.height));t.height=int(t.height)+int(t.velocity);t.velocity=int(t.velocity)+1
		if int(t.height)>0:t.height=0
	else:
		t.remaining=int(t.remaining)-1
		if int(t.remaining)==0:t.ticks=int(t.age)

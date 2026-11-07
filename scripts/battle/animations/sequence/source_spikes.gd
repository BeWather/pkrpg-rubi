extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Actual sub_812C720 arc -> 30 callback wait -> 16 callback blink.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
const Packed=preload("res://scripts/battle/animations/sequence/source_sports.gd")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var actors: Array[BattleAnimationActor]=c.resolve("attacker");var targets: Array[BattleAnimationActor]=c.resolve("target")
	if actors.is_empty() or targets.is_empty():return []
	var actor: BattleAnimationActor=actors[0];var target: BattleAnimationActor=targets[0];var a: Array=s.source_args;var direction: int=1 if actor.side==0 else -1
	var origin: Vector2=Geometry._anchor(actor,c,owner,"center")+Vector2(int(a[0])*BattleElectricContract.source_offset_direction(c,actor,target),int(a[1]))
	var destination: Vector2=Geometry._average(target,c,owner,"origin","air_wave")+Vector2(int(a[2])*direction,int(a[3]))
	var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;var rect: Array=s.frame_rects["0"];node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);node.position=origin;owner.add_child(node)
	var t: Dictionary={"kind":"source_spikes","settings":s,"node":node,"owner":owner,"original_actor":actor,"original_target":target,"origin":origin,"destination":destination,"offset":Vector2.ZERO,"stage":0,"wait":0,"blink":0,"age":0,"ticks":78,"update":advance}
	Packed._arc(t,destination,int(a[4]),-50);BattleSourcePriority.initialize(t,c,owner);return [t]
static func advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	if not t.original_actor.is_present() or not t.original_target.is_present():t.ticks=int(t.age);return
	match int(t.stage):
		0:
			if Packed._translate(t):t.stage=1;t.wait=30
			else:t.node.position=t.origin+t.offset
		1:
			if int(t.wait)>0:t.wait=int(t.wait)-1
			else:t.stage=2
		2:
			if int(t.blink)&1:t.node.visible=not t.node.visible
			t.blink=int(t.blink)+1
			if int(t.blink)==16:t.ticks=int(t.age)

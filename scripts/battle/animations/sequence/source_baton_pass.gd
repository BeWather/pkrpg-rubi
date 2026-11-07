extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Departure is visual only. Source task selector31 includes BG1/2/3 and visible battler OBJ, never the ball palette.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var t: Dictionary={"kind":str(s.behavior),"settings":s,"owner":owner,"age":0,"ticks":int(s.ticks),"update":advance}
	if s.behavior=="source_baton_pulse":
		t.members=[]
		for actor: BattleAnimationActor in c.actors.values():
			if actor.is_present():t.members.append(actor)
		t.color=Color(31.0/31.0,22.0/31.0,30.0/31.0);t.cycles=2;_fade(t,0,11);return [t]
	var actors: Array[BattleAnimationActor]=c.resolve("attacker")
	if actors.is_empty():return []
	var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;var rect: Array=s.frame_rects["0"];node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);owner.add_child(node)
	t.node=node;t.actor=actors[0];t.original_actor=actors[0];t.origin=Geometry._anchor(actors[0],c,owner,"center");node.position=t.origin;t.matrix=Vector2(256,256);t.stage=1;t.counter=0;t.scale_pose=Vector2.ONE
	BattleSourcePriority.initialize(t,c,owner);return [t]
static func _fade(t: Dictionary,start: int,target: int) -> void:
	t.amount=start;t.destination=target;t.obj_half=true;t.delay_counter=0;t.finishing=-1;_bg(t)
static func _bg(t: Dictionary) -> void:
	var owner: Node2D=t.owner
	if not is_instance_valid(owner._background_blend):
		owner._background_blend=Polygon2D.new();owner._background_blend.polygon=PackedVector2Array([Vector2.ZERO,Vector2(240,0),Vector2(240,160),Vector2(0,160)]);owner.add_child(owner._background_blend)
	owner._background_blend.color=Color(t.color,float(t.amount)/16.0)
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if t.kind=="source_baton_ball":
		if int(t.stage)==1:
			t.matrix+=Vector2(96,-26);t.counter=int(t.counter)+1
			if int(t.counter)==5:t.stage=2
		# Deliberate C switch fallthrough: both branches run on early frames.
		if int(t.stage) in [1,2]:
			t.matrix+=Vector2(96,48);t.counter=int(t.counter)+1;t.scale_pose=Vector2(256.0/t.matrix.x,256.0/t.matrix.y)
			if int(t.counter)==9:t.stage=3;t.scale_pose=Vector2.ONE;t.original_actor.apply_source_state("hidden",true)
		else:
			t.node.position.y-=6
			if t.node.position.y< -32:t.ticks=int(t.age)
		return
	if int(t.finishing)>=0:
		t.finishing=int(t.finishing)+1
		if int(t.finishing)==6:
			t.cycles=int(t.cycles)-1
			if int(t.cycles)==0:t.ticks=int(t.age)
			else:_fade(t,11,0)
		return
	if not bool(t.obj_half):
		if int(t.delay_counter)<1:t.delay_counter=int(t.delay_counter)+1;return
		t.delay_counter=0;_bg(t)
	else:
		for actor: BattleAnimationActor in t.members:
			if c.actors.get(actor.id)==actor and actor.is_present():t.owner._held_blends[actor.id]={"color":t.color,"amount":float(t.amount)/16.0,"source_actor":actor}
	t.obj_half=not bool(t.obj_half)
	if not bool(t.obj_half):
		if int(t.amount)==int(t.destination):t.finishing=0
		else:t.amount=mini(int(t.amount)+2,int(t.destination)) if int(t.amount)<int(t.destination) else maxi(int(t.amount)-2,int(t.destination))

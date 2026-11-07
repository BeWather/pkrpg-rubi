extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Source odd normal fades retain separate BG/OBJ updates and clamped endpoints.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var t: Dictionary={"kind":str(s.behavior),"settings":s,"owner":owner,"age":0,"ticks":int(s.ticks),"update":advance}
	if s.behavior=="source_outrage_palette":
		t.members=c.resolve("attacker")+c.resolve("target");t.phase=0;t.elapsed=0;t.color=Color(14.0/31.0,13.0/31.0,0);_fade(t,0,8);return [t]
	var actors: Array[BattleAnimationActor]=c.resolve("attacker")
	if actors.is_empty():return []
	t.original_actor=actors[0]
	if s.behavior=="source_outrage_ellipse":t.offset=Vector2.ZERO;t.cleanup=_cleanup.bind(t);owner._held_offsets[actors[0].id]=Vector2.ZERO;return [t]
	var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;owner.add_child(node);node.visible=false
	t.node=node;t.origin=Geometry._anchor(actors[0],c,owner,"center")+Vector2(int(s.source_args[0])*(-1 if actors[0].side!=0 else 1),int(s.source_args[1]));node.position=t.origin;t.velocity=Vector2(int(s.source_args[3]),int(s.source_args[4]))*(-1 if actors[0].side!=0 else 1);t.hidden=true;BattleSourcePriority.initialize(t,c,owner);_frame(t,0);return [t]
static func _frame(t: Dictionary,age: int) -> void:
	var pose: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.frame_program,age)
	var rect: Array=t.settings.frame_rects[str(int(pose.frame.tile))];t.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3])
static func _fade(t: Dictionary,start: int,target: int) -> void:
	t.amount=start;t.destination=target;t.obj_half=true;t.delay_counter=0;t.finishing=-1;_paint_bg(t)
static func _paint_bg(t: Dictionary) -> void:
	var owner: Node2D=t.owner
	if not is_instance_valid(owner._background_blend):
		owner._background_blend=Polygon2D.new();owner._background_blend.polygon=PackedVector2Array([Vector2.ZERO,Vector2(240,0),Vector2(240,160),Vector2(0,160)]);owner.add_child(owner._background_blend)
	owner._background_blend.color=Color(t.color,float(t.amount)/16.0)
static func _paint_obj(t: Dictionary,c: BattleAnimationContext) -> void:
	for actor: BattleAnimationActor in t.members:
		if c.actors.get(actor.id)==actor and actor.is_present():t.owner._held_blends[actor.id]={"color":t.color,"amount":float(t.amount)/16.0,"source_actor":actor}
static func _cleanup(t: Dictionary) -> void:
	t.erase("cleanup")
	if t.owner._held_offsets.get(t.original_actor.id)==t.offset:t.owner._held_offsets.erase(t.original_actor.id)
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	var age: int=int(t.age)
	if t.kind=="source_outrage_ember":
		if age<=30:
			t.node.position=t.origin+Vector2(((age-1)*int(t.velocity.x))>>8,((age-1)*int(t.velocity.y))>>8)
			if (30-age)%3==0:t.hidden=not bool(t.hidden)
			t.node.visible=not bool(t.hidden);_frame(t,age)
		return
	if t.kind=="source_outrage_ellipse":
		var actor: BattleAnimationActor=t.original_actor
		if c.actors.get(actor.id)!=actor or not actor.is_present():t.ticks=age;return
		t.offset=Vector2(BattleSourceTrig.sine((age*16)&255,12 if actor.side==0 else -12),6-BattleSourceTrig.cosine((age*16)&255,6)) if age<79 else Vector2.ZERO
		t.owner._held_offsets[actor.id]=t.offset;return
	t.elapsed=int(t.elapsed)+1
	if int(t.finishing)>=0:
		t.finishing=int(t.finishing)+1
		if int(t.finishing)==6:
			t.phase=int(t.phase)+1;t.elapsed=0
			if int(t.phase)<5:_fade(t,8 if int(t.phase)%2 else 3,0 if int(t.phase)==4 else 3 if int(t.phase)%2 else 8)
		return
	if not bool(t.obj_half):
		if int(t.delay_counter)<2:t.delay_counter=int(t.delay_counter)+1;return
		t.delay_counter=0;_paint_bg(t)
	else:_paint_obj(t,c)
	t.obj_half=not bool(t.obj_half)
	if not bool(t.obj_half):
		if int(t.amount)==int(t.destination):t.finishing=0
		else:t.amount=mini(int(t.amount)+2,int(t.destination)) if int(t.amount)<int(t.destination) else maxi(int(t.amount)-2,int(t.destination))

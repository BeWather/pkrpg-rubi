extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Source gift uses the exact packed-hop/tail helpers, distinct initial roles.
const Affine=preload("res://scripts/battle/animations/sequence/source_self_heal.gd")
const Bag=preload("res://scripts/battle/animations/sequence/source_item_bag.gd")
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if s.behavior=="source_present_branch":owner._source_args[7]=0 if c.source_damage>0 else 1;return []
	var actor: BattleAnimationActor=c.resolve("attacker")[0];var target: BattleAnimationActor=c.resolve("target")[0];var a: Array=s.source_args
	if s.behavior=="source_present_gift":
		var tracks: Array[Dictionary]=Bag.create(s,c,owner)
		for t: Dictionary in tracks:
			var origin: Vector2=Geometry._anchor(actor,c,owner,"origin")+Vector2(0,-5);var destination: Vector2=Geometry._anchor(target,c,owner,"origin")+Vector2(0,10)
			t.origin=Vector2(int(origin.x)&255,int(origin.y)&255);t.destination=Vector2(int(destination.x)&255,int(destination.y)&255);t.duration=60;t.frequency=1 if (c.source_position(actor.id)^2)==c.source_position(target.id) else 3;t.node.position=t.origin;t.update=_gift_advance
			t.settings=t.settings.duplicate(true);t.settings.source_affine_variants=[s.affine_program,s.source_tail_affine];Affine._start_affine(t,0);_gift_pose(t)
		return tracks
	var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;owner.add_child(node)
	var t: Dictionary={"kind":"source_present_sparkle","settings":s,"owner":owner,"node":node,"age":0,"ticks":17,"update":advance,"counter":0,"origin":Geometry._anchor(target,c,owner,"origin")+Vector2(int(a[0])*BattleElectricContract.source_offset_direction(c,actor,target),int(a[1]))}
	BattleSourcePriority.initialize(t,c,owner);advance(t,c);return [t]
static func advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	t.counter=int(t.counter)+1;t.node.position=t.origin+Vector2(0,int(t.settings.source_args[2])*int(t.counter))
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.frame_program,int(t.age)).frame;var rect: Array=t.settings.frame_rects[str(int(frame.tile))];t.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3])

static func _gift_advance(t: Dictionary,c: BattleAnimationContext) -> void:
	var tail_before: bool=t.tail_affine
	Bag.advance(t,c)
	# Present always stores sub_80CB8B8 after60, unlike opponent knockoff.
	if int(t.age)==int(t.duration) and t.stage=="hop":t.ticks=4096;t.stage="tail";t.tail_count=0

	# AnimateSprites calls the callback, then Begin/ContinueAffineAnim.
	if t.tail_affine and not tail_before:Affine._start_affine(t,1)
	else:Affine._affine(t)
	_gift_pose(t)
static func _gift_pose(t: Dictionary) -> void:
	t.node.rotation=-float(t.affine.rotation)*TAU/256;t.node.scale=Vector2(256.0/t.affine.matrix.x,256.0/t.affine.matrix.y)

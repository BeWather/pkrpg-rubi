extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Actual independent bounce callback and direct OAM matrix task, no HP authority.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func _restore(t: Dictionary) -> void:
	t.erase("cleanup")
	if not t.original_actor.is_present():return
	var actor: BattleAnimationActor=t.original_actor
	if actor._base_scale==t.owned_base_scale and actor.sprite.scale==actor._expected_scale:
		actor._base_scale=t.base_scale;actor._expected_scale=t.base_scale*actor._scale_factor;actor.sprite.scale=actor._expected_scale
	else:actor.multiply_layout_scale(Vector2.ONE/t.factor)
	actor.add_layout_rotation(-float(t.angle))
	if t.owner._held_offsets.get(actor.id)==t.offset:t.owner._held_offsets[actor.id]=Vector2.ZERO
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var role: int=int(s.source_args[0] if s.behavior=="source_pain_split_actor" else s.source_args[2]);var actor: BattleAnimationActor=c.resolve("attacker" if role==0 else "target")[0]
	var t: Dictionary={"kind":s.behavior,"settings":s,"original_actor":actor,"owner":owner,"age":0,"ticks":int(s.ticks),"update":advance}
	if s.behavior=="source_pain_split_actor":
		var species: String=str(c.source_appearance_species.get(actor.id,c.source_party_species.get(actor.id,""))).to_upper();var side: String="back" if c.contest or actor.side==0 else "front";var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(s.source_offsets)));var row: Dictionary=data.by_species.get(species,{})
		if not row.has(side):owner.error_message="Missing PainSplit source picture offset: "+species;owner.finish("failed");return []
		t.height=64-2*int(row[side]);t.base_scale=actor._base_scale;t.owned_base_scale=actor._base_scale;t.factor=Vector2.ONE;t.angle=0.0;t.offset=Vector2.ZERO;t.cleanup=_restore.bind(t);return [t]
	var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;owner.add_child(node);t.node=node;t.base=Geometry._anchor(actor,c,owner,"center")+Vector2(int(s.source_args[0]),int(s.source_args[1]));t.offset=Vector2.ZERO;t.xacc=128;t.velocity=768;t.bounced=false;t.tile=0;node.position=t.base;var rect: Array=s.frame_rects["0"];node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);BattleSourcePriority.initialize(t,c,owner);return [t]
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if not t.original_actor.is_present():t.ticks=int(t.age);return
	if t.kind=="source_pain_split_bounce":
		if int(t.age)>1:
			t.offset.x=int(t.xacc)>>8;t.offset.y+=int(t.velocity)>>8
			if not t.bounced and t.offset.y>42:t.bounced=true;t.velocity=(-int(t.velocity)/3)*2
			t.xacc=int(t.xacc)+192;t.velocity=int(t.velocity)+128;t.node.position=t.base+t.offset
		var frame: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.frame_program,int(t.age)-1).frame;t.tile=int(frame.tile);var rect: Array=t.settings.frame_rects[str(t.tile)];t.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);return
	var actor: BattleAnimationActor=t.original_actor
	if int(t.age)==1:
		var variant: int=t.settings.source_args[1];t.raw_matrix=Vector2(224,320) if variant==0 else Vector2(208,304);t.factor=Vector2(256.0/t.raw_matrix.x,256.0/t.raw_matrix.y);actor.multiply_layout_scale(t.factor);t.owned_base_scale=actor._base_scale;t.angle=0.0 if variant==0 else (-1 if variant==1 else 1)*3840.0/65536*TAU;actor.add_layout_rotation(t.angle);t.extra_y=16 if variant>0 and (c.contest or actor.side==0) else 0;t.matrix_d=int(float(t.raw_matrix.y)*cos(float(t.angle)));var projected: int=mini(128,int(t.height*256)/int(t.matrix_d));t.offset=Vector2(2,(int(t.height)-projected)/2+int(t.extra_y))
	elif int(t.age)==14:_restore(t)
	elif (int(t.age)-1)%3==0:t.offset.x=-t.offset.x
	if int(t.age)<14:t.owner._held_offsets[actor.id]=t.offset

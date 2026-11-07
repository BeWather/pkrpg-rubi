extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Distinct source edge-hand state machine, raw two-cycle squeeze, and top blinking symbol.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
const PainSplit=preload("res://scripts/battle/animations/sequence/source_pain_split.gd")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var actor: BattleAnimationActor=c.resolve("target")[0];var species: String=str(c.source_appearance_species.get(actor.id,c.source_party_species.get(actor.id,""))).to_upper();var side: String="back" if c.contest or actor.side==0 else "front";var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(s.source_coords)));var row: Dictionary=data.by_species.get(species,{}).get(side,{})
	if row.is_empty():owner.error_message="Missing SmellingSalt source picture coords: "+species;owner.finish("failed");return []
	var t: Dictionary={"kind":s.behavior,"settings":s,"original_actor":actor,"owner":owner,"age":0,"ticks":int(s.ticks),"update":advance,"picture_width":(int(row.packed)>>4)*8,"picture_height":(int(row.packed)&15)*8,"bottom_height":64-2*int(row.y_offset),"offset":Vector2.ZERO}
	if s.behavior=="source_smelling_salt_actor":t.base_scale=actor._base_scale;t.owned_base_scale=actor._base_scale;t.factor=Vector2.ONE;t.angle=0.0;t.raw_matrix=Vector2(256,256);t.cleanup=PainSplit._restore.bind(t);return [t]
	var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;owner.add_child(node);t.node=node;t.base=Geometry._anchor(actor,c,owner,"center");t.phase=0;t.counter=0;t.steps=0
	if s.behavior=="source_smelling_salt_hand":
		t.direction=-1 if int(s.source_args[1])==0 else 1;t.base.x+=int(t.direction)*(int(t.picture_width)/2+8);t.offset=0;t.remaining=2;t.tile=16;node.flip_h=int(t.direction)==-1
	else:t.base.y=maxf(8,t.base.y-int(t.picture_height)/2);t.tile=0;t.remaining=3;t.shown=true
	var rect: Array=s.frame_rects[str(t.tile)];node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);node.position=t.base;BattleSourcePriority.initialize(t,c,owner);return [t]
static func advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	if not t.original_actor.is_present():t.ticks=int(t.age);return
	if t.kind=="source_smelling_salt_actor":
		if int(t.age)==1:return
		var n: int=(int(t.age)-2)%13
		if n==12:
			PainSplit._restore(t);t.raw_matrix=Vector2(256,256);t.factor=Vector2.ONE;t.owned_base_scale=t.original_actor._base_scale;t.offset=Vector2.ZERO
			if int(t.age)<27:t.cleanup=PainSplit._restore.bind(t)
			return
		t.raw_matrix=Vector2(256,256-16*(n+1) if n<6 else 160+16*(n-5));var factor:=Vector2(1,256.0/t.raw_matrix.y);t.original_actor.multiply_layout_scale(factor/t.factor);t.factor=factor;t.owned_base_scale=t.original_actor._base_scale
		if (n+1)%2==0:t.offset.x=2
		var projected: int=mini(128,int(t.bottom_height*256)/int(t.raw_matrix.y));t.offset.y=(int(t.bottom_height)-projected)/2;t.owner._held_offsets[t.original_actor.id]=t.offset;return
	if int(t.age)==1:return
	t.counter=int(t.counter)+1
	if t.kind=="source_smelling_salt_effect":
		if int(t.counter)>=8:
			t.counter=0;t.shown=not t.shown;t.node.visible=t.shown
			if not t.shown:t.remaining=int(t.remaining)-1
			if int(t.remaining)==0:t.ticks=int(t.age)
		return
	match int(t.phase):
		0:
			if int(t.counter)>1:
				t.counter=0;t.offset=int(t.offset)+int(t.direction);t.steps=int(t.steps)+1
				if int(t.steps)==12:t.phase=1
		1:
			if int(t.counter)==8:t.counter=0;t.phase=2
		2:
			t.offset=int(t.offset)-int(t.direction)*4
			if int(t.counter)==6:t.counter=0;t.phase=3
		3:
			t.offset=int(t.offset)+int(t.direction)*3
			if int(t.counter)==8:
				t.remaining=int(t.remaining)-1
				if int(t.remaining)>0:t.counter=0;t.phase=2
				else:t.ticks=int(t.age)
	t.node.position=t.base+Vector2(int(t.offset),0)

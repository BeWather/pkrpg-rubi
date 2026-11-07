extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Raw actor task and logical sprite affine are intentionally distinct source conventions.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
const Affine=preload("res://scripts/battle/animations/sequence/source_self_heal.gd")
const PainSplit=preload("res://scripts/battle/animations/sequence/source_pain_split.gd")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var actor: BattleAnimationActor=c.resolve("attacker" if s.behavior=="source_yawn_cloud" or int(s.source_args[0])==0 else "target")[0]
	var t: Dictionary={"kind":s.behavior,"settings":s,"original_actor":actor,"owner":owner,"age":0,"ticks":int(s.ticks),"update":advance}
	if s.behavior=="source_yawn_actor":
		var species: String=str(c.source_appearance_species.get(actor.id,c.source_party_species.get(actor.id,""))).to_upper();var side: String="back" if c.contest or actor.side==0 else "front";var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(s.source_offsets)));var row: Dictionary=data.by_species.get(species,{})
		if not row.has(side):owner.error_message="Missing Yawn source picture offset: "+species;owner.finish("failed");return []
		t.height=64-2*int(row[side]);t.base_scale=actor._base_scale;t.owned_base_scale=actor._base_scale;t.factor=Vector2.ONE;t.angle=0.0;t.offset=Vector2.ZERO;t.counter=0;t.flips=0;t.raw_matrix=Vector2(256,256);t.cleanup=PainSplit._restore.bind(t);return [t]
	var target: BattleAnimationActor=c.resolve("target")[0];var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;owner.add_child(node);var rect: Array=s.frame_rects["0"];node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);t.node=node;t.origin=Geometry._anchor(actor,c,owner,"center");t.destination=Geometry._anchor(target,c,owner,"center");t.qx=int(t.origin.x)*16;t.qy=int(t.origin.y)*16;t.dx=int((t.destination.x-t.origin.x)*16)/64;t.dy=int((t.destination.y-t.origin.y)*16)/64;t.blinks=0;t.counter=0;node.position=t.origin
	var material:=ShaderMaterial.new();material.shader=load("res://scripts/battle/animations/sequence/source_yawn.gdshader");node.material=material;Affine._start_affine(t,int(s.source_args[0]));material.set_shader_parameter("source_scale",node.scale);BattleSourcePriority.initialize(t,c,owner);return [t]
static func advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	if not t.original_actor.is_present():t.ticks=int(t.age);return
	if t.kind=="source_yawn_actor":
		if int(t.age)==1:return
		if int(t.age)==66:PainSplit._restore(t);return
		var clock: int=int(t.age)-2
		if clock>=20 and clock<43:
			t.counter=int(t.counter)+1
			if int(t.counter)>1:t.counter=0;t.flips=int(t.flips)+1;t.offset.x=1 if int(t.flips)%2 else -1
		else:t.offset.x=0
		t.raw_matrix=BattleSourceCommandProgram.evaluate(t.settings.source_affine_program,int(t.age)-1,true).matrix;var factor:=Vector2(256.0/t.raw_matrix.x,256.0/t.raw_matrix.y);t.original_actor.multiply_layout_scale(factor/t.factor);t.factor=factor;t.owned_base_scale=t.original_actor._base_scale;var projected: int=mini(128,int(t.height*256)/int(t.raw_matrix.y));t.offset.y=(int(t.height)-projected)/2;t.owner._held_offsets[t.original_actor.id]=t.offset;return
	if int(t.age)==1:return
	var n: int=int(t.age)-1;t.qx=int(t.qx)+int(t.dx);t.qy=int(t.qy)+int(t.dy);t.node.position=Vector2(int(t.qx)>>4,(int(t.qy)>>4)+BattleSourceTrig.sine((n*8)&255,8))
	if n>58:
		t.counter=int(t.counter)+1
		if int(t.counter)>1:t.counter=0;t.blinks=int(t.blinks)+1;t.node.visible=int(t.blinks)%2==0
		if int(t.blinks)>3:t.ticks=int(t.age)
	Affine._affine(t);t.node.material.set_shader_parameter("source_scale",t.node.scale)

extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## uproar.c/noise.c/ring.c335: distinct raw task, palette-tag ring and Q3 note.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
const HpBursts=preload("res://scripts/battle/animations/sequence/source_hp_bursts.gd")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if s.behavior=="source_uproar_command":return BattleCounterSelected.create(s,c,owner)
	var actor: BattleAnimationActor=c.resolve("attacker")[0];var t: Dictionary={"kind":s.behavior,"settings":s,"original_actor":actor,"owner":owner,"age":0,"ticks":int(s.ticks),"created_tick":owner.elapsed_ticks,"update":advance}
	if s.behavior=="source_uproar_actor":
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(s.source_offsets)));var species: String=str(c.source_appearance_species.get(actor.id,""));var side: String="back" if c.contest or actor.side==0 else "front"
		if species.is_empty():species=str(c.source_party_species.get(actor.id,""))
		if not data.by_species.has(species):owner.error_message="Missing Uproar source picture offset: "+species;owner.finish("failed");return []
		t.height=64-2*int(data.by_species[species][side]);t.raw_matrix=Vector2(256,256);t.base_scale=actor._base_scale;t.owned_base_scale=actor._base_scale;t.factor=Vector2.ONE;t.cleanup=HpBursts._restore.bind(t);return [t]
	var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;owner.add_child(node);t.node=node;var tile: int=int(s.source_args[3])*16 if s.behavior=="source_uproar_note" else 0;var rect: Array=s.frame_rects[str(tile)];node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);var center: Vector2=Geometry._anchor(actor,c,owner,"center");center=Vector2(int(center.x),int(center.y))
	if s.behavior=="source_uproar_note":
		var x: int=int(s.source_args[1])*(-1 if actor.side!=0 else 1);var y: int=int(s.source_args[2]);owner._source_args[1]=x&65535;t.origin=center+Vector2(x,y);t.velocity=Vector2(x,y);t.position_q=t.origin*8;node.position=t.origin
	else:
		t.origin=center;node.position=center;node.scale=Vector2(16,16)/256.0
		var material:=ShaderMaterial.new();material.shader=load("res://scripts/battle/animations/sequence/source_celestial_heal.gdshader");material.set_shader_parameter("color5",Vector3(31,0,0));material.set_shader_parameter("amount",8.0);material.set_shader_parameter("eva",1.0);material.set_shader_parameter("evb",0.0);node.material=material
	BattleSourcePriority.initialize(t,c,owner);return [t]
static func advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	if not t.original_actor.is_present():t.ticks=int(t.age);return
	if t.kind=="source_uproar_actor":
		if int(t.age)>=13:HpBursts._restore(t);t.ticks=int(t.age);return
		var tick: int=int(t.age);t.raw_matrix=Vector2(256-12*tick,256+8*tick) if tick<=4 else Vector2(208+20*(tick-4),288-20*(tick-4)) if tick<=8 else Vector2(288-8*(tick-8),208+12*(tick-8))
		var actor: BattleAnimationActor=t.original_actor;var factor:=Vector2(256.0/t.raw_matrix.x,256.0/t.raw_matrix.y)
		if actor._base_scale==t.owned_base_scale and actor.sprite.scale==actor._expected_scale:actor._base_scale=t.base_scale*factor;actor._expected_scale=actor._base_scale*actor._scale_factor;actor.sprite.scale=actor._expected_scale
		else:actor.multiply_layout_scale(factor/t.factor)
		t.factor=factor;t.owned_base_scale=actor._base_scale;t.owner._held_offsets[actor.id]=Vector2(0,(int(t.height)-mini(128,int(int(t.height)*256)/int(t.raw_matrix.y)))/2);return
	if t.kind=="source_uproar_ring":t.node.scale=Vector2(16+32*mini(15,int(t.age)),16+32*mini(15,int(t.age)))/256.0;return
	t.position_q+=t.velocity;t.node.position=Vector2(int(t.position_q.x)>>3,int(t.position_q.y)>>3)

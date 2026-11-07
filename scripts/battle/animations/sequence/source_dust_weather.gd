extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## rock.c source BG1 compositor and two subsprites; wisp_fire.c actual palette/shove extras.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var mode: String=str(step.behavior)
	if mode=="source_dust_palette":
		if step.mode=="obj":owner.set_meta("source_dust_obj_tint",true)
		else:
			var found: bool=false
			for track: Dictionary in owner._tracks:
				if track.kind=="source_dust_bg":track.node.texture=load(str(track.settings.source_red_texture));track.tinted=true;found=true
			if not found:owner.error_message="Heat Wave BG palette task has no actual dust BG";owner.finish("failed")
		return []
	if mode=="source_heat_shove":
		var targets: Array[BattleAnimationActor]=c.resolve("target");var attackers: Array[BattleAnimationActor]=c.resolve("attacker")
		if targets.is_empty() or attackers.is_empty():return []
		var partner: BattleAnimationActor=Geometry._partner(targets[0],c)
		if partner!=null and partner not in targets:targets.append(partner)
		var t: Dictionary={"kind":mode,"settings":step,"owner":owner,"originals":targets,"age":0,"ticks":4096,"stage":0,"stage_age":0,"base":0,"offset":0,"pulse":0,"toggles":0,"shake":0,"direction":1 if attackers[0].side==0 else -1,"update":advance}
		t.cleanup=_cleanup_shove.bind(t);return [t]
	if mode=="source_dust_bg":
		var node:=Sprite2D.new();node.texture=load(str(step.texture));node.centered=false;node.region_enabled=true;node.region_rect=Rect2(Vector2.ZERO,c.field_size);node.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED;owner.add_child(node);BattleCounterSelected._blend_node(node,owner)
		for actor: BattleAnimationActor in c.actors.values():node.z_index=maxi(node.z_index,BattleSourcePriority.actor_layer(actor,owner)+1)
		var actors: Array[BattleAnimationActor]=c.resolve("attacker");var direction: int=6 if int(step.source_args[0])!=0 and not actors.is_empty() and actors[0].side!=0 else -6
		var t: Dictionary={"kind":mode,"settings":step.duplicate(true),"owner":owner,"node":node,"age":0,"ticks":4096,"stage":"in","counter":0,"eva":0,"evb":16,"scroll":Vector2.ZERO,"direction":direction,"tinted":false,"update":advance}
		_alpha(t);return [t]
	var actors: Array[BattleAnimationActor]=c.resolve("attacker")
	if actors.is_empty():return []
	var args: Array=step.source_args;var mirror: bool=int(args[3])!=0 and actors[0].side!=0
	var root:=Node2D.new();owner.add_child(root);root.position=Vector2(304 if mirror else -64,int(args[0]))
	if mirror:root.scale.x=-1
	var texture: String=str(step.source_red_texture) if bool(owner.get_meta("source_dust_obj_tint",false)) else str(step.texture)
	for piece: Array in step.source_subsprites:
		var node:=Sprite2D.new();node.texture=load(texture);node.centered=false;node.region_enabled=true;var rect: Array=step.frame_rects[str(int(piece[2]))];node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);node.position=Vector2(piece[0],piece[1]);root.add_child(node)
	var t: Dictionary={"kind":mode,"settings":step.duplicate(true),"owner":owner,"node":root,"age":0,"ticks":4096,"stage":"travel","qx":0,"qy":0,"vx":-int(args[1]) if mirror else int(args[1]),"vy":int(args[2]),"mirrored":mirror,"update":advance}
	BattleSourcePriority.initialize(t,c,owner);t.source_oam_priority=1;return [t]
static func _alpha(t: Dictionary) -> void:
	t.node.material.set_shader_parameter("eva",float(t.eva)/16.0);t.node.material.set_shader_parameter("evb",float(t.evb)/16.0)
static func _offset(t: Dictionary,value: int) -> void:
	t.offset=value
	for actor: BattleAnimationActor in t.originals:
		if not actor.is_present():continue
		var offset:=Vector2(value,0);t.owner._held_offsets[actor.id]=offset
		var leases: Dictionary=t.owner.get_meta("i5_offset_owners",{});leases[actor.id]={"actor":actor,"value":offset};t.owner.set_meta("i5_offset_owners",leases)
static func _cleanup_shove(t: Dictionary) -> void:
	t.erase("cleanup")
	for actor: BattleAnimationActor in t.originals:
		if t.owner._held_offsets.get(actor.id)==Vector2(t.offset,0):t.owner._held_offsets.erase(actor.id)
static func advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	if t.kind=="source_dust_particle":
		if t.stage=="cleanup":t.ticks=int(t.age);return
		t.qx=int(t.qx)+int(t.vx);t.qy=int(t.qy)+int(t.vy);t.node.position+=Vector2(int(t.qx)>>8,int(t.qy)>>8);t.qx=int(t.qx)&255;t.qy=int(t.qy)&255
		if (not t.mirrored and t.node.position.x>272) or (t.mirrored and t.node.position.x< -32):t.stage="cleanup"
	elif t.kind=="source_dust_bg":
		t.scroll+=Vector2(t.direction,-1);t.counter=int(t.counter)+1
		match str(t.stage):
			"in":
				if int(t.counter)==4:
					t.counter=0;t.eva=int(t.eva)+1;t.evb=16-int(t.eva)
					if int(t.eva)==7:t.stage="hold"
			"hold":
				if int(t.counter)==101:t.counter=0;t.stage="out"
			"out":
				if int(t.counter)==4:
					t.counter=0;t.eva=int(t.eva)-1;t.evb=16-int(t.eva)
					if int(t.eva)==0:t.stage="cleanup"
			"cleanup":t.scroll=Vector2.ZERO;t.ticks=int(t.age)
		t.node.region_rect.position=t.scroll;_alpha(t)
	elif t.kind=="source_heat_shove":
		if int(t.stage)==3:_offset(t,0);t.ticks=int(t.age);return
		if int(t.stage)==0:t.base=int(t.base)+int(t.direction)*2
		elif int(t.stage)==2:t.base=int(t.base)-int(t.direction)*2
		t.pulse=int(t.pulse)+1
		if int(t.pulse)>=(5 if int(t.stage)==1 else 2):t.pulse=0;t.toggles=int(t.toggles)+1;t.shake=2 if int(t.toggles)&1 else -2
		_offset(t,int(t.base)+int(t.shake));t.stage_age=int(t.stage_age)+1
		if int(t.stage_age)>=(96 if int(t.stage)==1 else 16):t.stage_age=0;t.stage=int(t.stage)+1

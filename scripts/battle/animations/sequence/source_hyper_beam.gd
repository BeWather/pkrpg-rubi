extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Opaque8px ORBS share only their own OBJ palette, never battler/BG palettes.
const Bird=preload("res://scripts/battle/animations/sequence/source_bird_horn_owned.gd")
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if s.behavior=="source_hyper_shake":
		var result: Array[Dictionary]=Bird.create(s,c,owner)
		# Source constructor writes x2/y2 BEFORE its synchronous delayed step.
		for track: Dictionary in result:owner._held_offsets[track.selected.id]=track.offset
		return result
	var t: Dictionary={"kind":str(s.behavior),"settings":s,"owner":owner,"age":0,"ticks":int(s.ticks),"update":advance}
	if s.behavior=="source_hyper_palette":t.amount=16;t.color_value=31;t.switches=0;owner.set_meta("source_hyper_palette",t);return [t]
	var tile: int=randi()&7;var attacker: BattleAnimationActor=c.resolve("attacker")[0];var target: BattleAnimationActor=c.resolve("target")[0];t.tile=tile;t.origin=Geometry._anchor(attacker,c,owner,"center")+Vector2(20 if attacker.side==0 else -20,0);t.destination=Geometry._anchor(target,c,owner,"center");t.speed=(randi()&31)+64;t.duration=absi(int(t.destination.x-t.origin.x))*16/int(t.speed)
	if int(t.duration)==0:return [] # Degenerate geometry deferred; no invented zero-divisor flight.
	t.remaining=t.duration;t.vx=(absi(int(t.destination.x-t.origin.x))*16/int(t.duration))&65535;t.vy=(absi(int(t.destination.y-t.origin.y))*16/int(t.duration))&65535;t.vx=(int(t.vx)|1) if t.destination.x<t.origin.x else (int(t.vx)&65534);t.vy=(int(t.vy)|1) if t.destination.y<t.origin.y else (int(t.vy)&65534);t.qx=0;t.qy=0;t.phase=randi()&255;t.initial_phase=t.phase;t.samples=0;t.original_actor=attacker;t.priority_actor=target
	var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;var rect: Array=s.frame_rects[str(tile)];node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);owner.add_child(node);t.node=node;t.material=ShaderMaterial.new();t.material.shader=load("res://scripts/battle/animations/sequence/palette_blend.gdshader");node.material=t.material;BattleSourcePriority.initialize(t,c,owner);t.base_subpriority=int(t.get("source_oam_subpriority",0));_orb(t,c);_color(t);return [t]
static func _color(t: Dictionary) -> void:
	var palette: Dictionary=t.owner.get_meta("source_hyper_palette",{});t.material.set_shader_parameter("blend_color",Color.RED if int(palette.get("color_value",0))==31 else Color.BLACK);t.material.set_shader_parameter("blend_amount",float(palette.get("amount",0))/16)
static func _orb(t: Dictionary,c: BattleAnimationContext) -> void:
	if int(t.remaining)==0:t.ticks=int(t.age);return
	t.qx=(int(t.qx)+int(t.vx))&65535;t.qy=(int(t.qy)+int(t.vy))&65535;t.draw_phase=t.phase;t.node.position=t.origin+Vector2((int(t.qx)>>4)*(-1 if int(t.vx)&1 else 1),(int(t.qy)>>4)*(-1 if int(t.vy)&1 else 1)+BattleSourceTrig.cosine(int(t.phase),12));t.source_oam_subpriority=int(t.base_subpriority)+(0 if int(t.phase)<=126 else 1);t.node.z_index=BattleSourcePriority.relative_layer(t.priority_actor,2 if int(t.phase)<=126 else 3,c,t.owner);t.phase=(int(t.phase)+24)&255;t.samples=int(t.samples)+1;t.remaining=int(t.remaining)-1
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if t.kind=="source_hyper_orb":_orb(t,c);_color(t);return
	if int(t.age)%7==0 and int(t.switches)<12:t.switches=int(t.switches)+1;t.amount=0 if int(t.switches)%2==1 else 16;t.color_value=0 if int(t.switches)%2==1 else 31
	if int(t.age)==92:t.amount=0;t.color_value=0
	for other: Dictionary in t.owner._tracks:
		if other.kind=="source_hyper_orb":_color(other)

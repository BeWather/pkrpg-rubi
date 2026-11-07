extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Distinct Flatter hold-only OBJ window and integer confetti ballistics; shared hardware compositor.
const Encore=preload("res://scripts/battle/animations/sequence/source_encore.gd")
const Affine=preload("res://scripts/battle/animations/sequence/source_self_heal.gd")
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var t: Dictionary={"kind":s.behavior,"settings":s,"owner":owner,"age":0,"ticks":4096,"update":advance,"start_tick":owner.elapsed_ticks}
	if s.behavior=="source_flatter_dip":
		t.original_actor=c.resolve("target")[0];t.phase=0;t.counter=5;t.offset=0;t.speed=2;t.ticks=14;return [t]
	var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;var initial: Array=s.frame_rects["0"];node.region_rect=Rect2(initial[0],initial[1],initial[2],initial[3]);owner.add_child(node);t.node=node;t.position=Vector2.ZERO
	if s.behavior=="source_flatter_confetti":
		t.tile=randi()%12;var a: int=randi()&511;var b: int=randi()&255;t.vx=1504+(a if a&1 else -a);t.vy=1152+(b if b&1 else -b);t.vx_initial=t.vx;t.vy_initial=t.vy;t.state=Encore._state(c,owner);node.material=Encore._material();t.state.materials.append(node.material);t.side=int(s.source_args[0]);t.base=Vector2(-8 if int(t.side)==0 else 248,104);t.offset=Vector2.ZERO;t.ticks=31
	else:
		var result: Array[Dictionary]=Encore.create({"behavior":"source_encore_command","mode":"prepare"},c,owner);t.state=Encore._state(c,owner);t.original_actor=c.resolve("target")[0];t.base=Geometry._anchor(t.original_actor,c,owner,"origin")+Vector2(0,-8);t.logical=Vector2(0,384);t.phase=0;t.remaining=80;t.tile=0;t.window_data={"kind":"source_encore_spotlight","node":node,"window_enabled":true,"shown":false,"position":t.base,"logical":t.logical};t.state.windows.append(t.window_data);t.state.enabled=true;Affine._start_affine(t,0);node.hide();t.position=t.base;node.position=t.base
		BattleSourcePriority.initialize(t,c,owner);result.append(t);return result
	var rect: Array=s.frame_rects[str(t.tile)];node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);node.position=t.base;BattleSourcePriority.initialize(t,c,owner);return [t]
static func advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	if t.kind=="source_flatter_confetti":
		t.offset+=Vector2((int(t.vx)>>8)*(1 if int(t.side)==0 else -1),-(int(t.vy)>>8));t.vx=maxi(0,int(t.vx)-22);t.vy=int(t.vy)-48;t.position=t.base+t.offset;t.node.position=t.position;return
	if t.kind=="source_flatter_dip":
		if int(t.phase) in [0,2]:
			if int(t.counter)>0:
				t.offset=int(t.offset)+int(t.speed);t.counter=int(t.counter)-1;t.owner._held_offsets[t.original_actor.id]=t.owner._held_offsets.get(t.original_actor.id,Vector2.ZERO)+Vector2(0,t.speed)
			else:t.phase=int(t.phase)+1
		elif int(t.phase)==1:t.counter=5;t.speed=-2;t.phase=2
		else:t.ticks=int(t.age)
		return
	var restarted: bool=false
	match int(t.phase):
		0:
			t.window_data.shown=true
			if t.affine.ended:t.phase=1
		1:
			t.remaining=int(t.remaining)-1
			if int(t.remaining)==0:Affine._start_affine(t,1);restarted=true;t.phase=2
		2:
			if t.affine.ended:t.window_data.shown=false;t.phase=3
		3:t.window_data.window_enabled=false;t.state.enabled=false;t.ticks=int(t.age)
	if not restarted:Affine._affine(t)
	t.logical=t.affine.matrix;t.window_data.logical=t.logical;Encore._sync(t.state)

extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Source OBJ-window geometry drives local BG3/OBJ brightness, never an opaque white spotlight.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
const Affine=preload("res://scripts/battle/animations/sequence/source_self_heal.gd")
static func _material(overlay: bool=false) -> ShaderMaterial:
	var m:=ShaderMaterial.new();m.shader=load("res://scripts/battle/animations/sequence/source_encore.gdshader");m.set_shader_parameter("overlay",overlay);m.set_shader_parameter("brightness",0.0);m.set_shader_parameter("window_on",false);return m
static func _state(c: BattleAnimationContext,owner: Node2D) -> Dictionary:
	if owner.has_meta("source_encore_state"):return owner.get_meta("source_encore_state")
	var overlay:=ColorRect.new();overlay.size=c.field_size;overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.material=_material(true);overlay.z_index=0;owner.add_child(overlay)
	var state: Dictionary={"owner":owner,"overlay":overlay,"materials":[overlay.material],"leases":[],"windows":[],"enabled":false,"brightness":0.0}
	for actor: BattleAnimationActor in c.resolve("all"):
		if not actor.is_present() or not actor.sprite.visible:continue
		var m: ShaderMaterial=_material();state.leases.append(BattleOwnedMaterialLease.attach(actor,m));state.materials.append(m)
	owner.set_meta("source_encore_state",state);_sync(state);return state
static func _cleanup(t: Dictionary) -> void:
	t.erase("cleanup");t.state.windows.clear()
	for lease: BattleOwnedMaterialLease in t.state.leases:lease.release()
	if is_instance_valid(t.state.overlay):t.state.overlay.queue_free()
static func _owner_advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	if t.state.owner._pc>=t.state.owner._steps.size():t.ticks=int(t.age)
static func _sync(state: Dictionary) -> void:
	var rects: Array=[Vector4.ZERO,Vector4.ZERO,Vector4.ZERO];var spot_texture: Texture2D;var hand_texture: Texture2D
	for window: Dictionary in state.windows:
		if not is_instance_valid(window.node):continue
		if window.kind=="source_encore_spotlight":
			spot_texture=window.node.texture
			if window.window_enabled and window.shown:rects[0]=Vector4(window.position.x,window.position.y,window.logical.x/256*64,window.logical.y/256*64)
		else:
			hand_texture=window.node.texture
			if window.window_enabled:rects[1+int(window.settings.source_args[2])]=Vector4(window.position.x,window.position.y,32,32)
	for m: ShaderMaterial in state.materials:
		m.set_shader_parameter("brightness",state.brightness);m.set_shader_parameter("window_on",state.enabled);m.set_shader_parameter("owner_inverse",state.owner.get_global_transform_with_canvas().affine_inverse());m.set_shader_parameter("spot_rect",rects[0]);m.set_shader_parameter("hand0_rect",rects[1]);m.set_shader_parameter("hand1_rect",rects[2])
		if spot_texture!=null:m.set_shader_parameter("spot_texture",spot_texture)
		if hand_texture!=null:m.set_shader_parameter("hand_texture",hand_texture)
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var fresh: bool=not owner.has_meta("source_encore_state");var state: Dictionary=_state(c,owner);var result: Array[Dictionary]=[]
	if fresh:
		var maintenance: Dictionary={"kind":"source_encore_owner","domain":"maintenance","state":state,"age":0,"ticks":2147483647,"update":_owner_advance};maintenance.cleanup=_cleanup.bind(maintenance);result.append(maintenance)
	if s.behavior=="source_encore_command":
		# Ordinary CC44/CCA8 are no-ops; contest WIN1 rectangle is separately disclosed.
		state.contest_window_prepared=s.mode=="prepare" and c.contest;return result
	var t: Dictionary={"kind":str(s.behavior),"settings":s,"state":state,"owner":owner,"age":0,"ticks":int(s.ticks),"counter":0,"phase":0,"update":advance}
	if s.behavior=="source_encore_hardware":
		# First global hardware update uses delayCounter=delay and changes BLDY immediately.
		t.amount=int(s.source_args[2])+signi(int(s.source_args[3])-int(s.source_args[2]));state.brightness=float(t.amount)/16;_sync(state);result.append(t);return result
	var actor: BattleAnimationActor=c.resolve("target" if s.behavior=="source_encore_spotlight" else "attacker")[0];var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;owner.add_child(node);t.node=node;t.original_actor=actor;t.window=bool(s.source_obj_window);t.window_enabled=bool(t.window);t.tile=0;t.offset=0;t.accumulator=0;t.shown=false;t.remaining=9
	var rect: Array=s.frame_rects["0" if s.behavior=="source_encore_spotlight" else "16"];node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);t.tile=0 if s.behavior=="source_encore_spotlight" else 16
	t.base=Geometry._anchor(actor,c,owner,"origin")+Vector2(int(s.source_args[0]),int(s.source_args[1]));t.position=t.base;node.position=t.position
	if s.behavior=="source_encore_spotlight":
		t.logical=Vector2(0,384);state.enabled=true;state.windows.append(t);Affine._start_affine(t,0);node.hide()
	else:
		t.direction=2 if int(s.source_args[2])==0 else -2;t.offset=-12 if int(t.direction)==2 else 12;t.position=t.base+Vector2(t.offset,0);node.position=t.position;node.flip_h=int(s.source_args[2])==0
		if t.window:state.windows.append(t);node.hide()
		else:node.material=_material();state.materials.append(node.material)
	BattleSourcePriority.initialize(t,c,owner);_sync(state);result.append(t);return result
static func advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	if t.kind=="source_encore_hardware":
		t.counter=int(t.counter)+1
		if int(t.counter)==4:
			t.counter=0;var target: int=t.settings.source_args[3];var direction: int=signi(target-int(t.settings.source_args[2]))
			if int(t.amount)==target:
				if int(t.settings.source_args[4])!=0:t.amount=0
				t.ticks=int(t.age)+1
			else:t.amount=int(t.amount)+direction
		t.state.brightness=float(t.amount)/16;_sync(t.state);return
	if t.kind=="source_encore_hand":
		if int(t.phase)==0:
			t.offset=int(t.offset)+int(t.direction)
			if int(t.offset)==0:
				t.phase=1
				if not t.window and int(t.settings.source_args[2])==0:t.owner._play_sound(str(t.settings.source_sound_path),"SOUND_PAN_ATTACKER")
		else:
			t.offset=int(t.offset)-int(t.direction)
			if absi(int(t.offset))==12:t.remaining=int(t.remaining)-1;t.phase=0
		t.position=t.base+Vector2(t.offset,0);t.node.position=t.position
		if int(t.remaining)==0:t.window_enabled=false;t.node.hide();t.ticks=int(t.age)
		_sync(t.state);return
	var restarted: bool=false
	match int(t.phase):
		0:
			t.shown=true
			if t.affine.ended:t.phase=1
		1,3:
			t.accumulator=int(t.accumulator)+117;t.offset=int(t.accumulator)>>8;t.counter=int(t.counter)+1
			if int(t.counter)==21:t.counter=0;t.phase=int(t.phase)+1
		2:
			t.accumulator=int(t.accumulator)-117;t.offset=int(t.accumulator)>>8;t.counter=int(t.counter)+1
			if int(t.counter)==41:t.counter=0;t.phase=3
		4:Affine._start_affine(t,1);restarted=true;t.phase=5
		5:
			if t.affine.ended:t.shown=false;t.phase=6
		6:t.window_enabled=false;t.state.enabled=false;t.ticks=int(t.age)
	t.position=t.base+Vector2(t.offset,0);t.node.position=t.position
	if not restarted:Affine._affine(t)
	t.logical=t.affine.matrix;_sync(t.state)

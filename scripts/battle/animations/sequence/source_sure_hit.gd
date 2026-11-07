extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Distinct literal scan.c and battle_anim_effects_3.c callbacks; no generic reticle.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
const PackedMotion=preload("res://scripts/battle/animations/sequence/source_sports.gd")
const SCAN=[Vector2(64,64),Vector2(0,-64),Vector2(-64,64),Vector2(32,-32)]
const CORNERS=[Vector2.ZERO,Vector2(-24,-24),Vector2(-24,24),Vector2(24,-24),Vector2(24,24)]
const CLOSE=[Vector2.ZERO,Vector2(-8,-8),Vector2(-8,8),Vector2(8,-8),Vector2(8,8)]
static func _actors(c: BattleAnimationContext) -> Array:
	var a: Array[BattleAnimationActor]=c.resolve("attacker");var b: Array[BattleAnimationActor]=c.resolve("target")
	return [a[0],b[0]] if not a.is_empty() and not b.is_empty() else []
static func _present(t: Dictionary,c: BattleAnimationContext) -> bool:
	return c.actors.get(t.original_actor.id)==t.original_actor and c.actors.get(t.original_target.id)==t.original_target and t.original_actor.is_present() and t.original_target.is_present()
static func _node(step: Dictionary,owner: Node2D) -> Sprite2D:
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;owner.add_child(node);return node
static func _frame(t: Dictionary,tile_override: int=-1,palette_row: int=0) -> void:
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.frame_program,int(t.age)).frame
	var rect: Array=t.settings.frame_rects[str(tile_override if tile_override>=0 else int(frame.tile))]
	t.node.region_rect=Rect2(rect[0],int(rect[1])+palette_row*int(t.settings.get("source_palette_cycle_height",0)),rect[2],rect[3])
static func _linear(t: Dictionary,destination: Vector2,duration: int,next: String) -> void:
	t.origin+=t.offset;t.offset=Vector2.ZERO;t.remaining=duration;t.acc_x=0;t.acc_y=0
	t.vx=PackedMotion._delta(int(destination.x-t.origin.x),duration);t.vy=PackedMotion._delta(int(destination.y-t.origin.y),duration);t.next=next;t.callback="linear"
static func _translate(t: Dictionary) -> bool:
	if int(t.remaining)==0:return true
	t.acc_x=(int(t.acc_x)+int(t.vx))&65535;t.acc_y=(int(t.acc_y)+int(t.vy))&65535;t.remaining=int(t.remaining)-1
	t.offset=Vector2((int(t.acc_x)>>8)*(-1 if int(t.vx)&1 else 1),(int(t.acc_y)>>8)*(-1 if int(t.vy)&1 else 1));return false
static func create_mind(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var actors: Array=_actors(c);var a: Array=step.get("source_args",[]);var mode: String=str(step.mode)
	if actors.is_empty():return []
	var origin: Vector2=Geometry._anchor(actors[1],c,owner,"center")
	var node: Sprite2D=_node(step,owner)
	var t: Dictionary={"kind":"source_mind_reader","mode":mode,"settings":step.duplicate(true),"owner":owner,"node":node,"original_actor":actors[0],"original_target":actors[1],"origin":origin,"age":0,"ticks":4096,"remaining":90,"callback":"wait","alpha":7,"alpha_counter":7,"offset":Vector2.ZERO,"update":advance_mind}
	if mode=="eye":t.ticks=int(step.source_frame_ticks)+1
	elif mode=="halo":BattleCounterSelected._blend_node(node,owner)
	elif mode=="alert":
		var direction: float=BattleElectricContract.source_offset_direction(c,actors[0],actors[1]);t.origin+=Vector2(int(a[0])*direction,int(a[1]));t.remaining=int(a[2]);t.callback="linear";t.next="destroy"
		t.vx=PackedMotion._delta(int(origin.x-t.origin.x),int(a[2]));t.vy=PackedMotion._delta(int(origin.y-t.origin.y),int(a[2]));t.acc_x=0;t.acc_y=0
		var delta: Vector2=t.origin-origin
		var angle: int=(preload("res://scripts/battle/animations/sequence/source_bird_horn_owned.gd").geometric_angle(int(delta.x),int(delta.y))-0x6000+(0x4000 if c.contest else 0))&65535
		node.rotation=-float(angle)*TAU/65536.0
	node.position=t.origin;BattleSourcePriority.initialize(t,c,owner);_mind_pose(t)
	return [t]
static func _mind_pose(t: Dictionary) -> void:
	_frame(t)
	if t.mode=="halo":
		t.node.material.set_shader_parameter("eva",float(t.alpha)/16.0);t.node.material.set_shader_parameter("evb",float(16-int(t.alpha))/16.0)
static func advance_mind(t: Dictionary,c: BattleAnimationContext) -> void:
	if not _present(t,c):t.ticks=int(t.age);return
	if t.mode=="halo":
		match str(t.callback):
			"wait":
				if int(t.remaining)>0:t.remaining=int(t.remaining)-1
				else:t.callback="fade"
			"fade":
				t.alpha=int(t.alpha_counter);t.alpha_counter=int(t.alpha_counter)-1
				if int(t.alpha_counter)<0:t.node.visible=false;t.callback="destroy"
			"destroy":t.ticks=int(t.age)
	elif t.mode=="alert":
		if t.callback=="destroy":t.ticks=int(t.age)
		elif _translate(t):t.callback="destroy"
		else:t.node.position=t.origin+t.offset
	_mind_pose(t)
static func create_scan(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var actors: Array=_actors(c)
	if actors.is_empty():return []
	for path: String in step.sound_paths:
		if not ResourceLoader.exists(path) or not load(path) is AudioStream:owner.error_message="Missing Lock-On cue: "+path;owner.finish("failed");return []
	var part: int=int(step.source_part);var center: Vector2=Geometry._anchor(actors[1],c,owner,"center");var origin: Vector2=center+CORNERS[part]-Vector2(32,32)
	var node: Sprite2D=_node(step,owner);node.position=origin;node.flip_h=part in [3,4];node.flip_v=part in [2,4]
	var t: Dictionary={"kind":"source_lock_scan","settings":step.duplicate(true),"owner":owner,"node":node,"original_actor":actors[0],"original_target":actors[1],"target_center":center,"part_offset":CORNERS[part],"part":part,"origin":origin,"offset":Vector2.ZERO,"age":0,"ticks":4096,"callback":"wait","next":"scan","remaining":20,"scan_index":0,"scan_toggle":false,"flash_amount":0,"flash_down":false,"palette_swapped":false,"flicker_counter":0,"flicker_count":0,"update":advance_scan}
	BattleSourcePriority.initialize(t,c,owner);_scan_pose(t)
	return [t]
static func _scan_pose(t: Dictionary) -> void:
	var swapped: bool=bool(t.palette_swapped)
	for track: Dictionary in t.owner._tracks:
		if track.kind=="source_lock_scan" and int(track.part)==0:swapped=bool(track.palette_swapped);break
	_frame(t,16 if int(t.part)>0 else 0,1 if swapped else 0)
static func _cue(t: Dictionary,index: int,c: BattleAnimationContext) -> void:
	var pan: int=BattleCounterSelected.adjust_panning(63,c)
	t.owner._play_sound(str(t.settings.sound_paths[index]),"",float(pan)/64.0,true)
static func _flash(t: Dictionary,c: BattleAnimationContext) -> void:
	for actor: BattleAnimationActor in c.actors.values():
		if not actor.is_present() or (c.contest and actor.id!=c.attacker_id):continue
		var held: Dictionary={"color":Color.WHITE,"amount":float(t.flash_amount)/16.0,"source_actor":actor};t.owner._held_blends[actor.id]=held;actor.apply_blend(held.color,held.amount)
	t.owner._source_palette({"age":0,"settings":{"blend_start":int(t.flash_amount),"blend_end":int(t.flash_amount),"blend_delay":1,"color":"ffffff"}})
static func advance_scan(t: Dictionary,c: BattleAnimationContext) -> void:
	if not _present(t,c):t.ticks=int(t.age);return
	match str(t.callback):
		"wait":
			if int(t.remaining)>0:t.remaining=int(t.remaining)-1
			else:t.callback=t.next
		"scan":
			if not t.scan_toggle:t.remaining=1;t.next="scan";t.callback="wait"
			else:
				_linear(t,t.origin+t.offset+SCAN[int(t.scan_index)],8,"after_scan");t.scan_index=int(t.scan_index)+1;_cue(t,0,c)
			t.scan_toggle=not t.scan_toggle
		"linear":
			if _translate(t):t.callback=t.next
			else:t.node.position=t.origin+t.offset
		"after_scan":
			if int(t.scan_index)==4:t.remaining=10;t.next="assemble";t.callback="wait"
			else:t.callback="scan"
		"assemble":
			if int(t.part)==0:t.remaining=3;t.next="flash";t.callback="wait"
			else:_linear(t,Geometry._anchor(t.original_target,c,t.owner,"center")+CLOSE[int(t.part)],6,"hold")
		"flash":
			t.flash_amount=clampi(int(t.flash_amount)+(-3 if t.flash_down else 3),0,16)
			_flash(t,c)
			if int(t.flash_amount)==16:t.flash_down=true;t.palette_swapped=true;_cue(t,1,c)
			elif int(t.flash_amount)==0:t.callback="hold"
		"hold":
			if (int(t.owner._source_args.get(7,0))&65535)==65535:t.callback="flicker";t.flicker_counter=0;t.flicker_count=0
		"flicker":
			if int(t.flicker_counter)%3==0:t.flicker_count=int(t.flicker_count)+1;t.node.visible=not t.node.visible
			t.flicker_counter=int(t.flicker_counter)+1
			if int(t.flicker_count)==8:t.ticks=int(t.age)
	_scan_pose(t)

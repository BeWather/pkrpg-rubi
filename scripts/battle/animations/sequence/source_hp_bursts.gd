extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## fire_2.c344–642 / water.c530–841: separate owned children, raw actor affine and rain.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
const Fissure=preload("res://scripts/battle/animations/sequence/source_fissure.gd")
const Overheat=preload("res://scripts/battle/animations/sequence/source_overheat.gd")
static func _band(c: BattleAnimationContext) -> int:
	var hp: Array=c.get_meta("source_hp_inputs",{}).get(c.attacker_id,[100,100]);var quarter: int=int(hp[1])/4
	for i: int in 3:
		if int(hp[0])<quarter*(i+1):return i
	return 3
static func _quake(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var args: Array=s.source_args;var result: Array[Dictionary]=[]
	if int(args[0])==5:
		var field_settings: Dictionary={"behavior":"source_fissure_quake","source_args":args,"ticks":4096}
		if s.get("source_field_projection","")=="draw_offset":field_settings.source_field_projection="draw_offset"
		result=Fissure.create(field_settings,c,owner)
	else:
		var actors: Array[BattleAnimationActor]=c.resolve("all" if int(args[0])==4 else "target_partner" if int(args[0])==3 else "target")
		for actor: BattleAnimationActor in actors:
			var item: Dictionary=Fissure.create({"behavior":"source_fissure_quake","source_args":[1,args[1],args[2]],"ticks":4096},c,owner)[0];item.original_actor=actor;result.append(item)
	for t: Dictionary in result:t.magnitude=(int(args[1]) if int(args[1])!=0 else c.source_power/10)+3;t.initial_count=int(args[2]);t.update=_quake_advance
	return result
static func _quake_advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	# Same source register/actor projection as Fissure, distinct task counters.
	if int(t.stage)==2:Fissure._restore(t);t.ticks=int(t.age);return
	t.counter=int(t.counter)+1
	if int(t.counter)<=1:return
	t.counter=0
	var x: int=int(t.magnitude)*(1 if int(t.toggles)%2==0 else -1) if t.has("nodes") else (int(t.magnitude)/2+(int(t.magnitude)&1) if int(t.toggles)%2==0 else -(int(t.magnitude)/2))
	if t.has("nodes"):Fissure._field(t,x)
	else:t.offset=Vector2(x,0);t.owner._held_offsets[t.original_actor.id]=t.offset
	t.toggles=int(t.toggles)+1
	if int(t.toggles)==(int(t.initial_count) if int(t.stage)==0 else 4):
		t.toggles=0;t.magnitude=int(t.magnitude)-1
		if int(t.stage)==0:t.stage=1
		elif int(t.magnitude)==0:t.stage=2
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if s.behavior=="source_hp_burst_command":return BattleCounterSelected.create(s,c,owner)
	if s.behavior=="source_hp_burst_quake":return _quake(s,c,owner)
	if s.behavior=="source_hp_burst_palette":
		var copy: Dictionary=s.duplicate(true);copy.behavior="source_overheat_fade";var tracks: Array[Dictionary]=Overheat.create(copy,c,owner)
		for t: Dictionary in tracks:
			for actor: BattleAnimationActor in c.resolve("all"):
				if actor.id==c.attacker_id or actor.id in c.target_ids or actor.sprite.visible or (actor._owned_hidden and actor._base_visible):t.keys.append("actor:"+str(actor.id))
		return tracks
	var actor: BattleAnimationActor=c.resolve("attacker")[0]
	var t: Dictionary={"kind":str(s.behavior),"settings":s,"owner":owner,"original_actor":actor,"age":0,"ticks":int(s.ticks),"update":advance,"phase":0,"counter":0,"toggles":0,"children":[],"created":0,"band":_band(c),"origin":Geometry._anchor(actor,c,owner,"origin")}
	t.origin=Vector2(int(t.origin.x),int(t.origin.y))
	if s.behavior=="source_hp_burst_fall":
		var args: Array=s.source_args;var node: Sprite2D=_sprite(s,owner,int(args[4])*16);node.position=Vector2(int(args[0]),int(args[1]));t.node=node;t.delay=int(args[2]);t.counter=0;t.toggles=0;BattleSourcePriority.initialize(t,c,owner);return [t]
	if s.behavior=="source_hp_burst_rain":t.x=136 if actor.side==0 else 16;t.y=40 if actor.side==0 else 80;t.next_x=int(t.x)+49;t.angle=0;t.impacted=false;t.quaked=false;return [t]
	t.raw_matrix=Vector2(256,256);t.factor=Vector2.ONE;t.base_scale=actor._base_scale;t.owned_base_scale=actor._base_scale;t.base_y=0;t.y2=0;t.x2=0;t.remaining=0;t.cleanup=_restore.bind(t)
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(s.source_offsets)));var species: String=str(c.source_appearance_species.get(actor.id,"")).to_upper()
	if species.is_empty():species=str(c.source_party_species.get(actor.id,"")).to_upper()
	var side: String="back" if c.contest or actor.side==0 else "front"
	if not data.by_species.has(species):owner.error_message="Missing source HP-burst picture offset: "+species;owner.finish("failed");return []
	t.height=64-2*int(data.by_species[species][side]);return [t]
static func _sprite(s: Dictionary,owner: Node2D,tile: int=0) -> Sprite2D:
	var n:=Sprite2D.new();n.texture=load(str(s.texture));n.region_enabled=true;var r: Array=s.frame_rects[str(tile)];n.region_rect=Rect2(r[0],r[1],r[2],r[3]);owner.add_child(n);return n
static func _restore(t: Dictionary) -> void:
	var actor: BattleAnimationActor=t.original_actor
	if actor.is_present():
		if actor._base_scale==t.owned_base_scale and actor.sprite.scale==actor._expected_scale:actor._base_scale=t.base_scale;actor._expected_scale=t.base_scale*actor._scale_factor;actor.sprite.scale=actor._expected_scale
		else:actor.multiply_layout_scale(Vector2.ONE/t.factor)
	t.factor=Vector2.ONE;t.owner._held_offsets[actor.id]=Vector2.ZERO;t.erase("cleanup")
static func _start(t: Dictionary,from: Vector2,to: Vector2,duration: int) -> void:
	t.raw_matrix=from;t.destination=to;t.delta=Vector2(int(to.x-from.x)/duration,int(to.y-from.y)/duration);t.remaining=duration
static func _bottom(t: Dictionary) -> void:t.y2=(int(t.height)-mini(128,int(int(t.height)*256)/int(t.raw_matrix.y)))/2
static func _tween(t: Dictionary) -> bool:
	t.remaining=int(t.remaining)-1
	if int(t.remaining)>0:t.raw_matrix+=t.delta;_bottom(t)
	else:t.raw_matrix=t.destination;t.y2=0
	return int(t.remaining)==0
static func _pose(t: Dictionary) -> void:
	var factor:=Vector2(256.0/t.raw_matrix.x,256.0/t.raw_matrix.y);t.original_actor.multiply_layout_scale(factor/t.factor);t.factor=factor;t.owned_base_scale=t.original_actor._base_scale;t.owner._held_offsets[t.original_actor.id]=Vector2(t.x2,int(t.base_y)+int(t.y2))
static func _outgoing(t: Dictionary,c: BattleAnimationContext) -> void:
	var eruption: bool=t.settings.mode=="eruption";var velocities: Array=[Vector2(-2,-5),Vector2(-1,-1),Vector2(3,-6),Vector2(4,-2),Vector2(2,-8),Vector2(-5,-5),Vector2(4,-7)];var sign_x: int=1 if t.original_actor.side==0 else -1
	var origin: Vector2=t.origin+Vector2(-12 if sign_x==1 else 16,int(t.base_y)+int(t.y2)-32+(74 if sign_x==1 else 44)) if eruption else Geometry._anchor(t.original_actor,c,t.owner,"center")
	origin=Vector2(int(origin.x),int(origin.y))
	var increment: int=1 if eruption else 4-int(t.band);var angle: int=172
	for index: int in range(0,7 if eruption else 20,increment):
		var node: Sprite2D=_sprite(t.settings.child,t.owner,64+(index%5)*4 if eruption else 0);node.position=origin;node.z_index=BattleSourcePriority.relative_layer(t.original_actor,2-BattleElectricContract.source_subpriority(t.original_actor,c) if eruption else -1,c,t.owner)
		var velocity: Vector2=velocities[index]*Vector2(sign_x*8,8) if eruption else Vector2(BattleSourceTrig.cosine(angle,64)+(index%6)*3,BattleSourceTrig.sine(angle,64)+(index%3)*3)
		var child: Dictionary={"node":node,"mode":"rock" if eruption else "jet","age":0,"position_q":origin*(8 if eruption else 16),"velocity":velocity,"gravity_counter":0,"gravity":0}
		# Source CreateSprite runs newly-created children later in the same frame;
		# alternating jet children are explicitly pre-stepped by the parent as well.
		if not eruption and int(t.created)&1:_advance_child(child,t,c)
		_advance_child(child,t,c);t.children.append(child);t.created=int(t.created)+1;angle=(angle+increment*2)&255
static func _advance_child(child: Dictionary,t: Dictionary,_c: BattleAnimationContext) -> bool:
	child.age=int(child.age)+1
	if child.mode=="rock":
		child.gravity_counter=int(child.gravity_counter)+1
		if int(child.gravity_counter)>2:child.gravity_counter=0;child.gravity=int(child.gravity)+1;child.position_q.y+=int(child.gravity)*int(child.gravity)
	if child.mode in ["rock","jet"]:
		child.position_q+=child.velocity;var divisor: int=8 if child.mode=="rock" else 16;child.node.position=Vector2(int(child.position_q.x)>>3,int(child.position_q.y)>>3) if divisor==8 else Vector2(int(child.position_q.x)>>4,int(child.position_q.y)>>4)
		return child.node.position.x< -8 or child.node.position.x>248 or child.node.position.y< -8 or child.node.position.y>120
	if child.mode=="drop":
		child.node.position.y+=8
		if child.node.position.y>=int(child.target_y):
			t.impacted=true;var position: Vector2=child.node.position;child.node.queue_free();child.node=_sprite(t.settings.impact,t.owner);child.node.position=position;child.node.z_index=1;child.mode="impact";child.age=0;child.blinks=0;child.counter=0;child.node.scale=Vector2(0.5,0.5)
			var pair: Array=t.owner.get_meta("source_counter_alpha",[16,0])
			if pair!=[16,0]:
				var material:=ShaderMaterial.new();material.shader=load("res://scripts/battle/animations/sequence/source_self_heal.gdshader");material.set_shader_parameter("eva",float(pair[0])/16);material.set_shader_parameter("evb",float(pair[1])/16);child.node.material=material
			# The newly allocated impact is visited later by AnimateSprites this frame.
			child.counter=1
		return false
	child.counter=int(child.counter)+1
	if int(child.counter)>1:child.counter=0;child.node.visible=not child.node.visible;child.blinks=int(child.blinks)+1
	return int(child.blinks)==12
static func _rain_emit(t: Dictionary) -> void:
	var n: Sprite2D=_sprite(t.settings.child,t.owner);n.position=Vector2(int(t.next_x),0);n.z_index=0
	var child: Dictionary={"node":n,"mode":"drop","target_y":((BattleSourceTrig.sine(int(t.angle),256)+3)>>4)+int(t.y),"age":0};_advance_child(child,t,null);t.children.append(child);t.created=int(t.created)+1;t.angle=(int(t.angle)+39)&255
	# Unsigned source multiplication truncates before modulus.
	t.next_x=((int(t.next_x)*0x41c64e6d+0x3039)&0xffffffff)%98+int(t.x)
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if t.kind=="source_hp_burst_fall":
		if int(t.phase)==0:
			if int(t.delay)>0:t.delay=int(t.delay)-1;return
			t.phase=1
		if int(t.phase)==1:
			t.node.position.y+=8
			if t.node.position.y>=int(t.settings.source_args[3]):t.node.position.y=int(t.settings.source_args[3]);t.phase=2
		else:
			t.counter=int(t.counter)+1
			if int(t.counter)>1:t.counter=0;t.toggles=int(t.toggles)+1;t.node.position.y=int(t.settings.source_args[3])+(-3 if int(t.toggles)&1 else 3)
			t.delay=int(t.delay)+1
			if int(t.delay)>16:t.ticks=int(t.age)
		return
	for child: Dictionary in t.children.duplicate():
		if _advance_child(child,t,c):child.node.queue_free();t.children.erase(child)
	if t.kind=="source_hp_burst_rain":
		if int(t.created)<int(t.band)*5+5:
			t.counter=int(t.counter)+1
			if int(t.counter)>2:t.counter=0;_rain_emit(t)
		if t.impacted and not t.quaked:
			t.quaked=true
			for role: int in [1,3]:
				for quake: Dictionary in _quake({"source_args":[role,0,12]},c,t.owner):t.owner._tracks.append(quake)
		if int(t.created)==int(t.band)*5+5 and t.children.is_empty():t.ticks=int(t.age)
		return
	var eruption: bool=t.settings.mode=="eruption"
	match int(t.phase):
		0:_start(t,Vector2(256,256),Vector2(224,512),32);t.phase=1;_actor_first(t,eruption)
		1:_actor_first(t,eruption)
		2:
			t.counter=int(t.counter)+1
			if int(t.counter)>4:_start(t,Vector2(224,512),Vector2(384,240 if eruption and t.original_actor.side!=0 else 192 if eruption else 224),6 if eruption else 8);t.counter=0;t.phase=3
		3:
			if _tween(t):
				if eruption:_outgoing(t,c)
				t.phase=4;t.counter=0;t.toggles=0;t.wait=0
		4:
			if not eruption:_outgoing(t,c);t.phase=5
			_actor_hold(t,eruption)
		5:_actor_hold(t,eruption)
		6:
			if t.original_actor.side!=0 or not eruption:t.base_y=int(t.base_y)-1
			if _tween(t):_restore(t);t.phase=7
		7:
			if t.children.is_empty():t.ticks=int(t.age)
	if int(t.phase)<7:_pose(t)
static func _actor_first(t: Dictionary,eruption: bool) -> void:
	t.counter=int(t.counter)+1
	if int(t.counter)>1:
		t.counter=0;t.toggles=int(t.toggles)+1;t.x2=3 if int(t.toggles)&1 else -3
		if not eruption and int(t.toggles)&1:t.base_y=int(t.base_y)+1
	if eruption and t.original_actor.side!=0:
		t.base_counter=int(t.get("base_counter",0))+1
		if int(t.base_counter)>4:t.base_counter=0;t.base_y=int(t.base_y)+1
	if _tween(t):_bottom(t);t.x2=0;t.counter=0;t.toggles=0;t.phase=2
static func _actor_hold(t: Dictionary,eruption: bool) -> void:
	t.counter=int(t.counter)+1
	if int(t.counter)>1:t.counter=0;t.toggles=int(t.toggles)+1;t.y2=int(t.y2)+(3 if eruption else 2)*(1 if int(t.toggles)&1 else -1)
	var finished: bool=false
	if eruption:t.wait=int(t.wait)+1;finished=int(t.wait)>24
	else:finished=int(t.toggles)==10
	if finished:
		if eruption and int(t.toggles)&1:t.y2=int(t.y2)-3
		_start(t,t.raw_matrix,Vector2(256,256),8);t.counter=0;t.phase=6

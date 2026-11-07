extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Exact local source clocks and ownership; no healing authority or shared renderer edits.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func _material() -> ShaderMaterial:
	var m:=ShaderMaterial.new();m.shader=load("res://scripts/battle/animations/sequence/source_celestial_heal.gdshader");m.set_shader_parameter("color5",Vector3(31,31,31));m.set_shader_parameter("amount",0.0);m.set_shader_parameter("eva",1.0);m.set_shader_parameter("evb",0.0);return m
static func _expanded(v: Vector3) -> Color:
	return Color((v.x*8+floorf(v.x/4))/255,(v.y*8+floorf(v.y/4))/255,(v.z*8+floorf(v.z/4))/255,1)
static func _state(c: BattleAnimationContext,owner: Node2D) -> Dictionary:
	if owner.has_meta("source_celestial_state"):return owner.get_meta("source_celestial_state")
	var rect:=ColorRect.new();rect.size=c.field_size;rect.color=Color.TRANSPARENT;rect.mouse_filter=Control.MOUSE_FILTER_IGNORE;rect.z_index=0;owner.add_child(rect)
	var state: Dictionary={"owner":owner,"materials":[],"leases":[],"rect":rect,"pair":[0,16],"release":false,"moon_amount":0,"moon_color":Vector3(27,29,31)}
	for actor: BattleAnimationActor in c.resolve("all"):
		if not actor.is_present() or not actor.sprite.visible:continue
		var m: ShaderMaterial=_material();state.materials.append(m);state.leases.append(BattleOwnedMaterialLease.attach(actor,m))
	owner.set_meta("source_celestial_state",state);return state
static func _owner_advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	if t.state.owner._pc>=t.state.owner._steps.size():t.ticks=int(t.age)
static func _cleanup(t: Dictionary) -> void:
	t.erase("cleanup")
	for lease: BattleOwnedMaterialLease in t.state.leases:lease.release()
	if is_instance_valid(t.state.rect):t.state.rect.queue_free()
static func _bg_palette(state: Dictionary,color: Vector3,amount: int) -> void:
	state.rect.color=_expanded(color);state.rect.color.a=float(amount)/16
static func _obj_palette(state: Dictionary,color: Vector3,amount: int) -> void:
	for m: ShaderMaterial in state.materials:m.set_shader_parameter("color5",color);m.set_shader_parameter("amount",float(amount))
static func _normal(start: int,target: int,delay: int=0) -> Dictionary:
	# BeginNormalPaletteFade immediately writes the BG half; OBJ half follows.
	return {"bg":start,"obj":0,"y":start,"target":target,"delay":delay,"counter":0,"toggle":1,"finish":0,"active":true}
static func _normal_update(v: Dictionary) -> void:
	if not v.active:return
	if int(v.finish)>0:
		v.finish=int(v.finish)+1
		if int(v.finish)==6:v.active=false
		return
	if int(v.toggle)==0 and int(v.counter)<int(v.delay):v.counter=int(v.counter)+1;return
	v.counter=0
	if int(v.toggle)==0:v.bg=int(v.y)
	else:v.obj=int(v.y)
	v.toggle=1-int(v.toggle)
	if int(v.toggle)==0:
		if int(v.y)==int(v.target):v.finish=1
		else:v.y=int(v.y)+signi(int(v.target)-int(v.y))*mini(2,absi(int(v.target)-int(v.y)))
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var fresh: bool=not owner.has_meta("source_celestial_state");var state: Dictionary=_state(c,owner);var result: Array[Dictionary]=[]
	if fresh:
		var maintenance: Dictionary={"kind":"source_celestial_owner","domain":"maintenance","state":state,"age":0,"ticks":2147483647,"update":_owner_advance};maintenance.cleanup=_cleanup.bind(maintenance);result.append(maintenance)
	if s.behavior=="source_celestial_command":state.pair=s.source_args.duplicate();return result
	var t: Dictionary={"kind":str(s.behavior),"settings":s,"state":state,"owner":owner,"age":0,"ticks":int(s.ticks),"phase":0,"counter":0,"update":advance}
	match str(s.behavior):
		"source_celestial_bg":
			var node:=Sprite2D.new();node.texture=load(str(s.texture));node.centered=false;node.region_enabled=true;node.region_rect=Rect2(Vector2(-56 if c.contest else -10 if c.actors[c.attacker_id].side==0 else -135,0),c.field_size);node.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED;node.material=_material();node.material.set_shader_parameter("eva",0.0);node.material.set_shader_parameter("evb",1.0);owner.add_child(node)
			for actor: BattleAnimationActor in c.actors.values():node.z_index=maxi(node.z_index,BattleSourcePriority.actor_layer(actor,owner)+1)
			t.node=node;t.eva=0;t.evb=16;t.pulse=0;t.initial_x=node.region_rect.position.x;t.phase=1;_cue(t)
		"source_celestial_dark":t.fade=_normal(0,16,1);_bg_palette(state,Vector3.ZERO,0)
		"source_celestial_palette":t.amount=int(s.source_args[2]);t.applied=t.amount;t.counter=1
		"source_celestial_alpha":t.pair=[0,16];t.writes=0
		"source_celestial_flash":
			t.fade=_normal(0,16);t.fill5=Vector3(1,1,1);t.released=false;t.hold=0;_bg_palette(state,t.fill5,16)
		_:
			var actor: BattleAnimationActor=c.actors[c.attacker_id];var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;owner.add_child(node);t.node=node;t.original_actor=actor;t.tile=0;t.material=_material();t.children=[]
			if s.behavior=="source_celestial_moon":node.position=Vector2(48,40) if c.contest else Vector2(s.source_args[0],s.source_args[1]);node.material=t.material;node.material.set_shader_parameter("eva",float(state.pair[0])/16);node.material.set_shader_parameter("evb",float(state.pair[1])/16)
			elif s.behavior=="source_celestial_twinkle":node.position=Vector2(Geometry._anchor(actor,c,owner,"center").x+int(s.source_args[0]),int(s.source_args[1]));node.material=t.material;t.fallen=0
			else:
				var draw: int=randi()&63
				if draw>31:draw=32-draw
				node.position=Geometry._anchor(actor,c,owner,"origin")+Vector2(draw,32);t.base=node.position;t.remaining=int(s.source_args[0]);t.speed=int(s.source_args[1]);t.fraction=0;t.offset=0;t.child_stage=0
				for index: int in 2:
					var child:=Sprite2D.new();child.texture=node.texture;child.region_enabled=true;child.position=t.base;child.hide();owner.add_child(child);child.z_index=node.z_index-1
					t.children.append({"node":child,"remaining":int(t.remaining),"fraction":0,"offset":0,"done":false,"program":s.source_child_programs[index]});_frame(t.children[index],s,0)
				t.cleanup=_green_cleanup.bind(t)
			_frame(t,s,0);BattleSourcePriority.initialize(t,c,owner)
			for child: Dictionary in t.children:child.node.z_index=node.z_index-1
	result.append(t);return result
static func _frame(t: Dictionary,s: Dictionary,age: int) -> void:
	var p: Array=t.get("program",s.frame_program);var frame: Dictionary=BattleSourceCommandProgram.evaluate(p,age).frame;t.tile=int(frame.tile);var r: Array=s.frame_rects[str(t.tile)];t.node.region_rect=Rect2(r[0],r[1],r[2],r[3])
static func _green_cleanup(t: Dictionary) -> void:
	t.erase("cleanup")
	for child: Dictionary in t.children:
		if is_instance_valid(child.node):child.node.queue_free()
static func _cue(t: Dictionary) -> void:t.owner._play_sound(str(t.settings.source_sound_path),"SOUND_PAN_ATTACKER")
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	match str(t.kind):
		"source_celestial_bg":
			match int(t.phase):
				1:
					t.counter=int(t.counter)+1
					if int(t.counter)==2:t.counter=0;t.eva=mini(12,int(t.eva)+1)
					if int(t.eva)==12:t.phase=2
				2:
					t.eva=maxi(0,int(t.eva)-1)
					if int(t.eva)==0:
						t.node.region_rect.position.x=float(t.initial_x)+float(t.settings.source_offsets[int(t.pulse)]);t.pulse=int(t.pulse)+1;t.phase=4 if int(t.pulse)==4 else 3
				3:
					t.counter=int(t.counter)+1
					if int(t.counter)==4:t.counter=0;t.phase=1;_cue(t)
				4:t.node.region_rect.position=Vector2.ZERO;t.node.hide();t.ticks=int(t.age)
			t.evb=16-int(t.eva);t.node.material.set_shader_parameter("eva",float(t.eva)/16);t.node.material.set_shader_parameter("evb",float(t.evb)/16)
		"source_celestial_dark":_normal_update(t.fade);_bg_palette(t.state,Vector3.ZERO,int(t.fade.bg))
		"source_celestial_palette":
			var a: Array=t.settings.source_args
			if int(t.counter)==int(a[1]):
				t.counter=0;t.applied=int(t.amount);_obj_palette(t.state,Vector3(31,31,31),int(t.applied));_bg_palette(t.state,Vector3(31,31,31),int(t.applied))
				if int(t.amount)==int(a[3]):t.ticks=int(t.age)
				else:t.amount=int(t.amount)+signi(int(a[3])-int(t.amount))
			else:t.counter=int(t.counter)+1
		"source_celestial_alpha":
			t.counter=int(t.counter)+1
			if int(t.counter)==2:
				t.counter=0;t.writes=int(t.writes)+1
				if int(t.writes)%2:t.pair[0]=mini(16,int(t.pair[0])+1)
				else:t.pair[1]=maxi(0,int(t.pair[1])-1)
				t.state.pair=t.pair.duplicate();_moon_materials(t.state,t.owner)
		"source_celestial_flash":_flash(t)
		"source_celestial_moon","source_celestial_twinkle":
			if t.state.release:t.ticks=int(t.age);return
			if t.kind=="source_celestial_moon":t.node.material.set_shader_parameter("eva",float(t.state.pair[0])/16);t.node.material.set_shader_parameter("evb",float(t.state.pair[1])/16)
			else:
				if int(t.age)%2==0 and int(t.fallen)<=119:t.node.position.y+=1;t.fallen=int(t.fallen)+1
				_frame(t,t.settings,int(t.age))
			t.node.material.set_shader_parameter("color5",t.state.moon_color);t.node.material.set_shader_parameter("amount",float(t.state.moon_amount))
		"source_celestial_green":_green(t)
static func _green(t: Dictionary) -> void:
	if int(t.phase)==0:
		var value: int=int(t.speed)+int(t.fraction);t.offset=int(t.offset)-(value>>8);t.fraction=value&255;t.node.position=t.base+Vector2(0,int(t.offset));_frame(t,t.settings,int(t.age))
		if int(t.child_stage)==0 and int(t.offset)<-8:t.children[0].node.show();t.child_stage=1
		if int(t.child_stage)==1 and int(t.offset)<-16:t.children[1].node.show();t.child_stage=2
		t.remaining=int(t.remaining)-1
		if int(t.remaining)==-1:t.node.hide();t.phase=1
	elif bool(t.children[0].done) and bool(t.children[1].done):t.ticks=int(t.age)
	for child: Dictionary in t.children:
		if not child.node.visible or child.done:continue
		child.fraction=int(child.fraction)+int(t.speed);child.offset=int(child.offset)-(int(child.fraction)>>8);child.fraction=int(child.fraction)&255;child.node.position=t.base+Vector2(0,int(child.offset))
		if int(child.remaining)==0:child.node.hide();child.done=true
		child.remaining=int(child.remaining)-1
static func _moon_materials(state: Dictionary,owner: Node2D) -> void:
	# Source RunTasks writes registers/palettes before AnimateSprites, independent of creation order.
	for other: Dictionary in owner._tracks:
		if other.kind not in ["source_celestial_moon","source_celestial_twinkle"] or not is_instance_valid(other.node):continue
		other.node.material.set_shader_parameter("color5",state.moon_color);other.node.material.set_shader_parameter("amount",float(state.moon_amount))
		if other.kind=="source_celestial_moon":other.node.material.set_shader_parameter("eva",float(state.pair[0])/16);other.node.material.set_shader_parameter("evb",float(state.pair[1])/16)
static func _flash(t: Dictionary) -> void:
	var white: Vector3=Vector3(27,29,31)
	if int(t.phase)==0:
		_normal_update(t.fade);t.state.moon_amount=int(t.fade.obj);_obj_palette(t.state,white,int(t.fade.obj));_moon_materials(t.state,t.owner)
		if int(t.age)<=14:t.fill5=Vector3((13*(int(t.age)+1))>>3,(14*(int(t.age)+1))>>3,(15*(int(t.age)+1))>>3)
		else:t.fill5=white
		_bg_palette(t.state,t.fill5,16)
		if not t.fade.active:t.released=true;t.state.release=true;t.phase=1;t.hold=0
	elif int(t.phase)==1:
		t.hold=int(t.hold)+1
		if int(t.hold)>30:t.fade=_normal(16,0);t.phase=2;_bg_palette(t.state,white,16)
	else:
		_normal_update(t.fade);_bg_palette(t.state,white,int(t.fade.bg));_obj_palette(t.state,white,int(t.fade.obj))
		if not t.fade.active:t.ticks=int(t.age)

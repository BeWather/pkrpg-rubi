extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Local source callbacks; semitransparent egg/bottle OBJ never fade opaque monBG/rings.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func _material() -> ShaderMaterial:
	var m:=ShaderMaterial.new();m.shader=load("res://scripts/battle/animations/sequence/source_self_heal.gdshader");m.set_shader_parameter("eva",1.0);m.set_shader_parameter("evb",0.0);m.set_shader_parameter("amount",0.0);m.set_shader_parameter("bottle_clip",false);m.set_shader_parameter("angle",0.0);return m
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if s.behavior=="source_self_heal_command":return _command(s,c,owner)
	if s.behavior=="source_self_heal_palette":return _palette(s,c,owner)
	var actors: Array[BattleAnimationActor]=c.resolve(str(s.selector));var attackers: Array[BattleAnimationActor]=c.resolve("attacker");var targets: Array[BattleAnimationActor]=c.resolve("target")
	if actors.is_empty() or attackers.is_empty() or targets.is_empty():return []
	var actor: BattleAnimationActor=actors[0];var a: Array=s.source_args;var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;owner.add_child(node)
	var anchor: String="origin" if s.behavior=="source_self_heal_egg" or (s.behavior=="source_self_heal_ring" and int(a[3])!=0) else "center"
	var offset: Vector2=Vector2(0,-24) if s.behavior=="source_self_heal_bottle" else Vector2(int(a[0])*BattleElectricContract.source_offset_direction(c,attackers[0],targets[0]),int(a[1]))
	node.position=Geometry._anchor(actor,c,owner,anchor)+offset
	var t: Dictionary={"kind":str(s.behavior),"settings":s,"node":node,"owner":owner,"original_actor":actor,"base":node.position,"age":0,"ticks":int(s.ticks),"phase":0,"counter":0,"tile":0,"rise":0,"velocity":896,"xacc":160 if attackers[0].side==0 else -160,"xstep":160 if attackers[0].side==0 else -160,"offset":Vector2.ZERO,"eva":0 if s.behavior=="source_self_heal_bottle" else 16,"evb":16 if s.behavior=="source_self_heal_bottle" else 0,"wphase":0,"wvalue":0,"drift":0,"update":advance}
	if s.behavior!="source_self_heal_ring":node.material=_material();node.material.set_shader_parameter("eva",float(t.eva)/16);node.material.set_shader_parameter("evb",float(t.evb)/16)
	if s.behavior=="source_self_heal_bottle":node.material.set_shader_parameter("bottle_clip",true)
	_frame(t,0);_start_affine(t,0);BattleSourcePriority.initialize(t,c,owner);return [t]
static func _frame(t: Dictionary,tile: int) -> void:
	t.tile=tile;var r: Array=t.settings.frame_rects[str(tile)];t.node.region_rect=Rect2(r[0],r[1],r[2],r[3])
static func _start_affine(t: Dictionary,index: int) -> void:
	t.affine={"program":t.settings.source_affine_variants[index] if t.settings.has("source_affine_variants") else t.settings.affine_program,"pc":-1,"left":0,"loop":0,"matrix":Vector2(256,256),"rotation":0,"ended":false};_affine(t)
static func _affine(t: Dictionary) -> void:
	var v: Dictionary=t.affine
	if v.ended:return
	if int(v.left)>0:
		v.left=int(v.left)-1
		var cmd: Dictionary=v.program[int(v.pc)];v.matrix+=Vector2(cmd.x,cmd.y);v.rotation=int(v.rotation)+int(cmd.rotation)
	else:
		for _guard: int in 64:
			v.pc=int(v.pc)+1
			var cmd: Dictionary=v.program[int(v.pc)]
			match str(cmd.op):
				"end":v.ended=true;break
				"jump":v.pc=int(cmd.target)-1;continue
				"loop":
					if int(cmd.count)==0:continue
					if int(v.loop)==0:v.loop=int(cmd.count)
					else:v.loop=int(v.loop)-1
					if int(v.loop)>0:
						v.pc=int(v.pc)-1
						while int(v.pc)>0 and str(v.program[int(v.pc)-1].op)!="loop":v.pc=int(v.pc)-1
						v.pc=int(v.pc)-1
					continue
				"frame":
					if int(cmd.ticks)==0:v.matrix=Vector2(cmd.x,cmd.y);v.rotation=int(cmd.rotation)
					else:v.matrix+=Vector2(cmd.x,cmd.y);v.rotation=int(v.rotation)+int(cmd.rotation)
					v.left=maxi(0,int(cmd.ticks)-1);break
	t.node.scale=v.matrix/256.0;t.node.rotation=-float(v.rotation)*TAU/256
	if t.kind=="source_self_heal_bottle":t.node.material.set_shader_parameter("angle",t.node.rotation)
static func _alpha(t: Dictionary,eva: int,evb: int) -> void:
	t.eva=eva;t.evb=evb;t.owner.set_meta("source_self_heal_alpha",[eva,evb])
	# Both egg halves share the registers, not the opaque BG copies or ring palettes.
	for other: Dictionary in t.owner._tracks:
		if other.kind=="source_self_heal_egg" or other.kind=="source_self_heal_bottle":other.node.material.set_shader_parameter("eva",float(eva)/16);other.node.material.set_shader_parameter("evb",float(evb)/16)
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if t.kind=="source_self_heal_bg":
		for e: Dictionary in t.clones:
			if e.actor.is_present():e.node.position=Geometry._anchor(e.actor,c,t.owner,"origin")
		return
	if t.kind=="source_self_heal_palette":
		# BeginNormalPaletteFade performs BG at creation, then alternates OBJ/BG;
		# only BG half waits delay3, each completed pair decrements coefficient by2.
		if int(t.age)<=26:
			if int(t.toggle)==0 and int(t.delay)<3:t.delay=int(t.delay)+1
			else:
				t.delay=0
				if int(t.toggle)==0:t.bg_amount=int(t.y)
				else:t.amount=int(t.y);t.y=maxi(0,int(t.y)-2)
				t.toggle=1-int(t.toggle)
		_apply_palette(t);return
	if not t.original_actor.is_present():t.ticks=int(t.age);return
	if t.kind=="source_self_heal_ring":
		if t.affine.ended:t.ticks=int(t.age);return
		_affine(t);return
	var restarted: bool=false
	if t.kind=="source_self_heal_bottle":
		match int(t.phase):
			0:
				t.counter=int(t.counter)+1
				if int(t.counter)%2:_alpha(t,mini(16,int(t.eva)+1),int(t.evb))
				else:_alpha(t,int(t.eva),maxi(0,int(t.evb)-1))
				if int(t.eva)==16 and int(t.evb)==0:t.phase=1;t.counter=0
			1:
				t.counter=int(t.counter)+1
				if int(t.counter)>8:t.phase=2;t.counter=0;_start_affine(t,1);restarted=true
			2:
				if int(t.wphase)<=11:t.wvalue=int(t.wvalue)+2
				if int(t.wphase)>=18 and int(t.wphase)<=41:t.wvalue=int(t.wvalue)-2
				if int(t.wphase)>47:t.wvalue=int(t.wvalue)+2
				t.wphase=(int(t.wphase)+1)%60;t.counter=int(t.counter)+1
				if int(t.counter)%3==0:t.drift=int(t.drift)+1
				t.node.position=t.base+Vector2(int(t.wvalue)/9,absi(int(t.wvalue)/14)+int(t.drift))
				if int(t.counter)>29:
					if int(t.counter)%2:_alpha(t,maxi(0,int(t.eva)-1),int(t.evb))
					else:_alpha(t,int(t.eva),mini(16,int(t.evb)+1))
					if int(t.eva)==0 and int(t.evb)==16:t.phase=3
			3:t.node.hide();t.phase=4
			4:t.owner.set_meta("source_self_heal_alpha",[0,0]);t.ticks=int(t.age)
	else:
		match int(t.phase):
			0:
				t.offset.y-=int(t.velocity)>>8;t.offset.x=int(t.xacc)>>8;t.velocity=int(t.velocity)-32;t.xacc=int(t.xacc)+int(t.xstep);t.node.position=t.base+t.offset
				if t.offset.y>0:t.base=t.node.position;t.offset=Vector2.ZERO;t.phase=1;t.counter=0;_start_affine(t,1);restarted=true
			1:
				var previous: int=t.counter;t.counter=previous+1
				if previous>19:t.phase=2;_start_affine(t,2);restarted=true
			2:
				if t.affine.ended:
					_start_affine(t,1);restarted=true
					if int(t.settings.source_args[2])==0:_frame(t,16);t.phase=3
					else:_frame(t,32);t.phase=5
			3:
				t.rise=int(t.rise)+1;t.offset.y-=2;t.node.position=t.base+t.offset
				if int(t.rise)==9:_alpha(t,16,0);t.phase=4;t.counter=0
			4:
				if int(t.counter)%3==0:
					_alpha(t,int(t.eva)-1,17-int(t.eva))
					if int(t.eva)==0:t.phase=5
				t.counter=int(t.counter)+1
			5:
				if (int(t.owner._source_args.get(7,0))&65535)==65535:t.node.hide();t.phase=6
			6:
				if int(t.settings.source_args[2])==0:t.owner.set_meta("source_self_heal_alpha",[0,0])
				t.ticks=int(t.age)
	if not restarted:_affine(t)
static func _bg_cleanup(t: Dictionary) -> void:
	t.erase("cleanup")
	for e: Dictionary in t.clones:
		e.actor.apply_source_state("hidden",false)
		if is_instance_valid(e.node):e.node.queue_free()
	t.clones.clear()
static func _command(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var bg: Dictionary=owner.get_meta("source_self_heal_bg",{})
	if s.mode=="clearmonbg":
		if not bg.is_empty():_bg_cleanup(bg);bg.ticks=int(bg.age)
		return []
	# Source monbg TARGET maps to defender+partner; ATK_PARTNER to attacker+partner.
	var role: String="target" if int(s.source_args[0])==1 else "attacker";var selected: Array[BattleAnimationActor]=c.resolve(role)
	if selected.is_empty():return []
	var partner: BattleAnimationActor=Geometry._partner(selected[0],c)
	if partner!=null:selected.append(partner)
	var t: Dictionary={"kind":"source_self_heal_bg","domain":"maintenance","owner":owner,"clones":[],"age":0,"ticks":2147483647,"update":advance}
	for actor: BattleAnimationActor in selected:
		if not actor.is_present() or not actor.sprite.visible or (c.contest and actor.id!=c.attacker_id):continue
		var node: Sprite2D=BattleIdentityCopy.clone_sprite(actor,owner);owner.add_child(node);node.z_index=BattleSourcePriority.relative_layer(actor,1,c,owner);node.material=_material();t.clones.append({"actor":actor,"node":node});actor.apply_source_state("hidden",true)
	t.cleanup=_bg_cleanup.bind(t);owner.set_meta("source_self_heal_bg",t);return [t]
static func _palette(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var t: Dictionary={"kind":"source_self_heal_palette","settings":s,"owner":owner,"age":0,"ticks":int(s.ticks),"amount":0,"bg_amount":10,"y":10,"toggle":1,"delay":0,"leases":[],"materials":[],"update":advance}
	for actor: BattleAnimationActor in c.actors.values():
		if not actor.is_present():continue
		var m: ShaderMaterial=_material();t.leases.append(BattleOwnedMaterialLease.attach(actor,m));t.materials.append(m)
	for e: Dictionary in owner.get_meta("source_self_heal_bg",{}).get("clones",[]):t.materials.append(e.node.material)
	# Projection of the selected battle BG1/2/3 plane only; not OBJ palettes or extra BG8/9.
	var rect:=ColorRect.new();rect.size=c.field_size;rect.color=Color(99.0/255,198.0/255,247.0/255,10.0/16);rect.mouse_filter=Control.MOUSE_FILTER_IGNORE;rect.z_index=0;owner.add_child(rect);t.node=rect;t.cleanup=_palette_cleanup.bind(t);_apply_palette(t);return [t]
static func _apply_palette(t: Dictionary) -> void:
	for m: ShaderMaterial in t.materials:m.set_shader_parameter("amount",float(t.amount))
	t.node.color.a=float(t.bg_amount)/16
static func _palette_cleanup(t: Dictionary) -> void:
	t.erase("cleanup");t.amount=0;t.bg_amount=0;_apply_palette(t)
	for lease: BattleOwnedMaterialLease in t.leases:lease.release()

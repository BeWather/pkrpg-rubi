extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## I5 source callbacks. Rotation is the reviewed native geometric adapter, NOT BIOS parity.
const ProgramGuard=preload("res://scripts/battle/animations/sequence/source_hidden_actor_emergence.gd")
const ROOTS={"bird":"sub_80DB5E4","horn":"sub_80DC824","slide":"SlideMonToOffset","return":"SlideMonToOriginalPos","hit":"sub_80E27A0","pulse":"sub_80E1E2C","palette":"sub_80E2A38","excluded_palette":"sub_80E2A7C","quake":"sub_80E1864","hide":"sub_80DFC24","reveal":"sub_80DFD24","scroll":"sub_80E3A58","shake":"AnimTask_ShakeMon","shake2":"AnimTask_ShakeMon2","shake_in_place":"AnimTask_ShakeMonInPlace"}
const ARITIES={"bird":0,"horn":5,"slide":5,"return":3,"hit":4,"pulse":7,"palette":5,"excluded_palette":5,"quake":3,"hide":1,"reveal":1,"scroll":4,"shake":5,"shake2":5,"shake_in_place":5}
const ASSETS={"bird":["res://graficos/batalla/animaciones/i5_candidate_bird_tile0.png",[64,64]],"horn":["res://graficos/batalla/animaciones/i5_candidate_horn_tile0.png",[32,16]],"hit":["res://graficos/batalla/animaciones/i5_candidate_hit_tile0.png",[32,32]]}
const AFFINE_TABLES={"bird":"gDummySpriteAffineAnimTable","horn":"gSpriteAffineAnimTable_83DAAB0","slide":"gDummySpriteAffineAnimTable","return":"gDummySpriteAffineAnimTable","hit":"gSpriteAffineAnimTable_83DB498","pulse":"gDummySpriteAffineAnimTable"}
const TEMPLATES={"bird":"gBattleAnimSpriteTemplate_83DA65C","horn":"gBattleAnimSpriteTemplate_83DAABC","slide":"gSlideMonToOffsetSpriteTemplate","return":"gSlideMonToOriginalPosSpriteTemplate","hit":"gBasicHitSplatSpriteTemplate","pulse":"gBattleAnimSpriteTemplate_83DB3DC"}
static func s16(v: int) -> int:return ((v+32768)&65535)-32768
static func s8(v: int) -> int:return ((v+128)&255)-128
static func geometric_angle(dx: int,dy: int) -> int:
	var x: int=s16(dx);var y: int=s16(dy)
	var q: int=0 if x==0 and y==0 else int(floor(fposmod(atan2(float(y),float(x)),TAU)*65536.0/TAU+0.5))&65535
	return (-q+49152)&65535
static func _integer(v: Variant) -> bool:return (v is int or v is float) and is_finite(float(v)) and float(v)==int(v) and int(v)>=-32768 and int(v)<=32767
static func _present(t: Dictionary,c: BattleAnimationContext) -> bool:
	if not is_instance_valid(t.owner) or t.owner.context!=c or not t.owner.is_inside_tree():return false
	for actor: BattleAnimationActor in t.originals:
		if c.actors.get(actor.id)!=actor or not actor.is_present():return false
	return true
static func _anchor(actor: BattleAnimationActor,c: BattleAnimationContext,origin: bool=false) -> Vector2:
	var p: Vector2=BattleElectricContract.source_anchor(actor,c,"origin" if origin else "center")
	return Vector2(int(p.x),int(p.y))
static func _color(raw: int) -> Color:return Color(float(raw&31)/31.0,float((raw>>5)&31)/31.0,float((raw>>10)&31)/31.0)
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var mode: String=str(step.get("mode",""));var a: Array=step.get("source_args",[]).duplicate()
	if mode in ["monbg","clear_monbg","alpha","blend_off"]:return _monbg(step,c,owner)
	if mode=="background":return _background(step,c,owner)
	if not ROOTS.has(mode) or a.size()!=int(ARITIES[mode]) or str(step.get("source_callback",""))!=ROOTS[mode]:return []
	for value: Variant in a:
		if not _integer(value):return []
	if mode in ["slide","return","shake","shake2","shake_in_place","quake"] and int(a[0]) not in [0,1]:return []
	if mode=="excluded_palette" and int(a[0]) not in [1,4]:return []
	if mode in ["palette","pulse"] and int(a[0]) not in range(32):return []
	if mode=="scroll" and (int(a[2]) not in [0,1] or int(a[3])!=-1):return []
	if mode in ["horn","slide","return"] and int(a[4] if mode!="return" else a[2])<=0:return []
	if mode=="slide" and int(a[3]) not in [0,1]:return []
	if mode=="return" and int(a[1]) not in [0,1,2]:return []
	if mode=="hit" and (int(a[2]) not in [0,1] or int(a[3]) not in [0,1,2,3]):return []
	if mode in ["hide","reveal"] and int(a[0]) not in [0,1]:return []
	var attackers: Array[BattleAnimationActor]=c.resolve("attacker");var targets: Array[BattleAnimationActor]=c.resolve("target")
	if attackers.is_empty() or targets.is_empty() or not is_instance_valid(owner) or owner.context!=c:return []
	var attacker: BattleAnimationActor=attackers[0];var target: BattleAnimationActor=targets[0]
	var actor: BattleAnimationActor=target if mode in ["horn","hit"] else attacker
	if mode in ["slide","return","quake","shake","shake2","shake_in_place"]:actor=attacker if int(a[0])==0 else target
	if mode=="hit":actor=attacker if int(a[2])==0 else target
	if TEMPLATES.has(mode):
		if str(step.get("source_affine_table",""))!=AFFINE_TABLES[mode]:return []
		if step.get("source_template","")!=TEMPLATES[mode] or step.get("frame_program",[])!=[{"op":"end"}]:return []
		var tag: String="ANIM_TAG_BIRD" if mode=="bird" else "ANIM_TAG_HORN_HIT_2" if mode=="horn" else "ANIM_TAG_IMPACT" if mode=="hit" else "0"
		if str(step.get("source_tile_tag",""))!=tag or str(step.get("source_palette_tag",""))!=tag:return []
		if not ProgramGuard._program_valid(step.get("affine_program",[]),true):return []
		if mode=="horn":
			for index: String in ["0","1","2"]:
				if not ProgramGuard._program_valid(step.get("source_affine_variants",{}).get(index,[]),true):return []
	if ASSETS.has(mode):
		var dimensions: Variant=step.get("frame_size",[])
		if str(step.get("texture",""))!=ASSETS[mode][0] or not dimensions is Array or dimensions.size()!=2:return []
		for axis: int in range(2):
			if not _integer(dimensions[axis]) or int(dimensions[axis])!=int(ASSETS[mode][1][axis]):return []
	var t: Dictionary={"kind":"source_bird_horn_owned","settings":step.duplicate(true),"args":a,"owner":owner,"originals":[attacker,target],"selected":actor,"age":0,"ticks":2147483647,"update":advance,"mode":mode,"remaining":0,"wait":0,"counter":0,"state":0,"qx":0,"qy":0,"x2":0,"y2":0,"retired":false,"matrix_live":false}
	t.cleanup=_cleanup.bind(t)
	if mode in ["bird","horn","hit"]:
		if not step.has("texture") or not ResourceLoader.exists(str(step.texture)):return []
		var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;node.region_rect=Rect2(0,0,int(step.frame_size[0]),int(step.frame_size[1]));owner.add_child(node);t.node=node;t.matrix_live=true
		var p: Vector2=_anchor(attacker if mode=="bird" else target,c);t.x=int(p.x);t.y=int(p.y);t.rotation=0.0;t.scale=Vector2.ONE
		BattleSourcePriority.initialize(t,c,owner)
	match mode:
		"bird":
			var destination: Vector2=_anchor(target,c);t.qx=s16(int(t.x)<<4);t.qy=s16(int(t.y)<<4)
			t.vx=s16((int(destination.x)-int(t.x))*16/12);t.vy=s16((int(destination.y)-int(t.y))*16/12)
			t.angle=geometric_angle(int(destination.x)-int(t.x),int(destination.y)-int(t.y));t.rotation=-float(t.angle)*TAU/65536.0
			t.scale=Vector2(-1 if c.contest and str(c.source_appearance_species.get(attacker.id,""))!="UNOWN" else 1,1)
		"horn":
			var variant: String="2" if c.contest else "1" if target.side==0 else "0"
			for index: int in ([0,2] if c.contest else [0,1,2,3] if target.side==0 else []):a[index]=s16(-int(a[index]))
			# Appearance center is captured independently from party identity.
			var visual: Vector2=target.anchor(c.field);t.x=s16(int(visual.x)+int(a[0]));t.y=s16(int(visual.y)+int(a[1]))
			var destination: Vector2=_anchor(target,c)+Vector2(a[2],a[3]);t.remaining=int(a[4]);t.vx=(((absi(int(destination.x)-int(t.x))<<8)&65535)/int(t.remaining))&65534;t.vy=(((absi(int(destination.y)-int(t.y))<<8)&65535)/int(t.remaining))&65534
			if destination.x<t.x:t.vx=int(t.vx)|1
			if destination.y<t.y:t.vy=int(t.vy)|1
			t.settings.affine_program=t.settings.source_affine_variants[variant];t.affine_index=int(variant)
			var pose: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.affine_program,0,true);t.scale=Vector2(float(pose.matrix.x)/256.0,float(pose.matrix.y)/256.0);t.rotation=-float(pose.rotation)*TAU/256.0
			_linear(t) # StartAnimLinearTranslation calls TranslateAnimLinear synchronously.
		"hit":
			var p: Vector2=_anchor(actor,c);t.x=int(p.x)+int(a[0])*BattleElectricContract.source_offset_direction(c,attacker,target);t.y=int(p.y)+int(a[1])
		"slide","return":
			t.initial=owner.get_actor_offset(actor.id);t.remaining=int(a[4] if mode=="slide" else a[2]);var delta: Vector2
			if mode=="slide":delta=Vector2(int(a[1])*(-1 if actor.side!=0 else 1),int(a[2])*(-1 if actor.side!=0 and int(a[3])==1 else 1))
			else:delta=-t.initial
			t.vx=s16(int(delta.x)<<8)/int(t.remaining);t.vy=s16(int(delta.y)<<8)/int(t.remaining)
			if mode=="return" and int(a[1])==1:t.vy=0
			if mode=="return" and int(a[1])==2:t.vx=0
		"hide","reveal":t.eva=16 if mode=="hide" else 0;t.evb=0 if mode=="hide" else 16;_alpha(t,c)
		"scroll":
			t.domain="maintenance";t.bg_x=0;t.bg_y=0;t.vx=int(a[0]);t.vy=int(a[1])
			if int(a[2])==1 and attacker.side!=0:t.vx=s16(-int(t.vx));t.vy=s16(-int(t.vy))
		"palette","excluded_palette","pulse":
			t.members=[];t.background_selected=mode=="excluded_palette" or (int(a[0])&1)!=0
			var roles: Array[String]=["attacker","target","attacker_partner","target_partner"]
			for role_index: int in range(4):
				for member: BattleAnimationActor in c.resolve(roles[role_index]):
					var admitted: bool=mode=="excluded_palette" and member.sprite.is_visible_in_tree() and member.id!=target.id and (int(a[0])!=4 or member.id!=attacker.id)
					if mode!="excluded_palette":admitted=(int(a[0])&(2<<role_index))!=0
					if admitted and member not in t.members:t.members.append(member);t.originals.append(member)
			if mode=="pulse":t.amount=int(a[4]);t.color=_color(int(a[3]));t.remaining=int(a[2]);t.wait=int(a[1]);_palette(t,c)
			else:
				if int(a[1])<0 or int(a[2]) not in range(17) or int(a[3]) not in range(17):return []
				t.amount=int(a[2]);t.color=_color(int(a[4]));_palette_step(t,c) # synchronous Step1 -> Step2
		"quake":t.magnitude=(int(a[1]) if int(a[1])!=0 else c.source_power/10)+3;t.remaining=int(a[2])
		"shake","shake2","shake_in_place":
			if int(a[3])<=0 or int(a[4])<0:return []
			t.initial=owner.get_actor_offset(actor.id);t.offset=Vector2(a[1],a[2]) if mode!="shake_in_place" else t.initial+Vector2(a[1],a[2]);t.remaining=int(a[3]);t.wait=0 if mode=="shake_in_place" else int(a[4]);_shake(t)
	if t.has("node"):_paint(t,c)
	return [t]
static func _cleanup(t: Dictionary) -> void:
	t.erase("cleanup")
	if t.has("node") and is_instance_valid(t.node):t.node.queue_free()
	t.matrix_live=false
	if t.has("clones"):
		for item: Dictionary in t.clones:
			item.actor.apply_source_state("hidden",false)
			if is_instance_valid(item.node):item.node.queue_free()
	if t.mode=="scroll" and is_instance_valid(t.owner) and is_instance_valid(t.owner._source_background):t.owner._source_background.region_rect.position=Vector2.ZERO
static func _retire(t: Dictionary) -> void:
	if t.retired:return
	t.retired=true;t.ticks=int(t.age)
	if t.get("cleanup") is Callable:t.cleanup.call()
static func _offset(t: Dictionary,v: Vector2) -> void:
	t.offset=v;t.owner._held_offsets[t.selected.id]=v
	var leases: Dictionary=t.owner.get_meta("i5_offset_owners",{});leases[t.selected.id]={"actor":t.selected,"value":v};t.owner.set_meta("i5_offset_owners",leases)
static func _linear(t: Dictionary) -> void:
	t.qx=(int(t.qx)+int(t.vx))&65535;t.qy=(int(t.qy)+int(t.vy))&65535;t.x2=(int(t.qx)>>8)*(-1 if (int(t.vx)&1)!=0 else 1);t.y2=(int(t.qy)>>8)*(-1 if (int(t.vy)&1)!=0 else 1);t.remaining-=1
static func _paint(t: Dictionary,c: BattleAnimationContext) -> void:
	t.node.transform=t.owner.global_transform.affine_inverse()*c.field.global_transform*Transform2D(float(t.rotation),t.scale,0.0,Vector2(int(t.x)+int(t.x2),int(t.y)+int(t.y2)))
static func _alpha(t: Dictionary,c: BattleAnimationContext) -> void:
	t.owner.set_meta("source_counter_alpha",[t.eva,t.evb])
	for item: Dictionary in t.owner.get_meta("source_counter_blend_nodes",[]):
		if is_instance_valid(item.node) and item.node.material==item.material:item.material.set_shader_parameter("eva",float(t.eva)/16.0);item.material.set_shader_parameter("evb",float(t.evb)/16.0)
static func _palette(t: Dictionary,c: BattleAnimationContext) -> void:
	for member: BattleAnimationActor in t.members:
		if c.actors.get(member.id)==member and member.is_present():t.owner._held_blends[member.id]={"color":t.color,"amount":float(t.amount)/16.0,"source_actor":member}
	if t.background_selected:
		if not is_instance_valid(t.owner._background_blend):
			t.owner._background_blend=Polygon2D.new();t.owner._background_blend.polygon=PackedVector2Array([Vector2.ZERO,Vector2(240,0),Vector2(240,160),Vector2(0,160)]);t.owner.add_child(t.owner._background_blend)
		var color: Color=t.color;color.a=float(t.amount)/16.0;t.owner._background_blend.color=color
static func _palette_step(t: Dictionary,c: BattleAnimationContext) -> void:
	if int(t.wait)==int(t.args[1]):
		t.wait=0;_palette(t,c)
		if int(t.amount)==int(t.args[3]):_retire(t)
		else:t.amount+=1 if int(t.amount)<int(t.args[3]) else -1
	else:t.wait+=1
static func _shake(t: Dictionary) -> void:
	if int(t.wait)>0:t.wait-=1;return
	var a: Array=t.args
	if t.mode=="shake":t.offset=Vector2(0 if t.offset.x==int(a[1]) else int(a[1]),0 if t.offset.y==int(a[2]) else int(a[2]))
	elif t.mode=="shake2":t.offset=Vector2(-int(a[1]) if t.offset.x==int(a[1]) else int(a[1]),-int(a[2]) if t.offset.y==int(a[2]) else int(a[2]))
	else:t.offset+=Vector2(a[1],a[2])*(2 if int(t.counter)&1 else -2);t.counter+=1
	t.remaining-=1;t.wait=int(a[4])
	if int(t.remaining)==0:
		if t.mode=="shake_in_place":t.offset+=Vector2(a[1],a[2])*(1 if int(t.counter)&1 else -1)
		else:t.offset=Vector2.ZERO
		_retire(t)
	_offset(t,t.offset)
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if t.retired:return
	if not _present(t,c):
		if t.has("offset") and t.owner._held_offsets.get(t.selected.id)==t.offset:t.owner._held_offsets.erase(t.selected.id)
		_retire(t);return
	var a: Array=t.args
	match t.mode:
		"bird":
			t.qx=s16(int(t.qx)+int(t.vx));t.qy=s16(int(t.qy)+int(t.vy));t.x=int(t.qx)>>4;t.y=int(t.qy)>>4
			if ((int(t.x)+45)&65535)>330 or int(t.y)>157 or int(t.y)<-45:_retire(t)
		"horn":
			if int(t.remaining)>0:_linear(t)
			elif int(t.state)==0:t.state=1
			else:_retire(t)
		"hit":
			if int(t.state)==1:_retire(t)
			else:
				var pose: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.affine_program,maxi(0,int(t.age)-1),true);t.scale=Vector2(float(pose.matrix.x)/256.0,float(pose.matrix.y)/256.0);t.rotation=-float(pose.rotation)*TAU/256.0
				if pose.ended:t.state=1 # Stored callback transfer; destroy runs on the next callback.
		"slide","return":
			if int(t.remaining)>0:
				t.remaining-=1;t.qx=s16(int(t.qx)+int(t.vx));t.qy=s16(int(t.qy)+int(t.vy));var v:=Vector2(int(t.qx)>>8,int(t.qy)>>8)
				if t.mode=="return":v=Vector2(s8(int(v.x)),s8(int(v.y)))+t.initial
				_offset(t,v)
			elif t.mode=="return":
				var v: Vector2=t.offset
				if int(a[1])<2:v.x=0
				if int(a[1]) in [0,2]:v.y=0
				_offset(t,v);_retire(t)
			elif int(t.state)==0:t.state=1
			else:_retire(t)
		"shake","shake2","shake_in_place":_shake(t)
		"quake":
			if int(t.state)==2:_offset(t,Vector2.ZERO);_retire(t)
			else:
				t.wait+=1
				if int(t.wait)>1:
					t.wait=0;_offset(t,Vector2(int(t.magnitude)/2+(int(t.magnitude)&1) if int(t.counter)%2==0 else -(int(t.magnitude)/2),0));t.counter+=1
					if int(t.counter)==(int(t.remaining) if int(t.state)==0 else 4):
						t.counter=0;t.magnitude-=1
						if int(t.state)==0:t.state=1
						elif int(t.magnitude)==0:t.state=2
		"hide","reveal":
			if int(t.wait)==int(a[0]):
				t.wait=0;t.eva+=-1 if t.mode=="hide" else 1;t.evb+=1 if t.mode=="hide" else -1;_alpha(t,c)
				if int(t.evb)==(16 if t.mode=="hide" else 0):
					if t.mode=="hide":t.originals[0].apply_source_state("visible",false)
					_retire(t)
			else:t.wait+=1
		"palette","excluded_palette":_palette_step(t,c)
		"pulse":
			if int(t.state)==2:t.amount=0;t.color=Color.BLACK;_palette(t,c);_retire(t)
			elif int(t.wait)>0:t.wait-=1
			elif int(t.remaining)==0:t.state=2
			else:
				t.amount=int(a[6] if int(t.counter)%2==0 else a[4]);t.color=_color(int(a[5] if int(t.counter)%2==0 else a[3]));_palette(t,c);t.counter+=1;t.remaining-=1;t.wait=int(a[1])&255
		"scroll":
			t.qx=s16(int(t.qx)+int(t.vx));t.qy=s16(int(t.qy)+int(t.vy));t.bg_x=s16(int(t.bg_x)+(int(t.qx)>>8));t.bg_y=s16(int(t.bg_y)+(int(t.qy)>>8));t.qx=int(t.qx)&255;t.qy=int(t.qy)&255
			if is_instance_valid(t.owner._source_background):t.owner._source_background.region_rect.position=Vector2(t.bg_x,t.bg_y)
			if (int(t.owner._source_args.get(7,0))&65535)==65535:_retire(t)
		"monbg":
			for item: Dictionary in t.clones:
				item.node.transform=t.owner.global_transform.affine_inverse()*item.actor.sprite.global_transform
				item.node.modulate=item.actor.sprite.modulate
		"background":_background_tick(t,c)
	if t.has("node") and is_instance_valid(t.node) and not t.retired:_paint(t,c)
static func _monbg(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var mode: String=str(step.mode)
	if mode in ["alpha","blend_off"]:return BattleCounterSelected._command_create(step,c,owner)
	var role: int=int(step.get("source_args",[-1])[0])
	if role not in [0,1,2,3]:return []
	var selected: Array[BattleAnimationActor]=c.resolve("attacker" if role in [0,2] else "target")
	if selected.is_empty():return []
	if mode=="clear_monbg":
		for t: Dictionary in owner.get_meta("i5_monbg",[]):
			if t.primary==selected[0]:
				for item: Dictionary in t.clones:item.actor.apply_source_state("hidden",false)
				t.ticks=int(t.age)+2 # Source sub_807672C skips its first task invocation.
		return []
	var actors: Array[BattleAnimationActor]=[selected[0]];var position: int=c.source_position(selected[0].id)
	if position not in [0,1,2,3]:return []
	for actor: BattleAnimationActor in c.actors.values():
		if actor!=selected[0] and c.source_position(actor.id)==(position^2) and actor.is_present() and actor.sprite.is_visible_in_tree():actors.append(actor)
	var t: Dictionary={"kind":"source_bird_horn_owned","mode":"monbg","primary":selected[0],"originals":actors,"owner":owner,"clones":[],"age":0,"ticks":2147483647,"args":[],"domain":"maintenance","retired":false,"update":advance};t.cleanup=_cleanup.bind(t)
	for actor: BattleAnimationActor in actors:
		if not actor.sprite.is_visible_in_tree() or (c.contest and actor.id!=c.attacker_id):continue
		var node: Sprite2D=BattleIdentityCopy.clone_sprite(actor,owner);owner.add_child(node);BattleCounterSelected._blend_node(node,owner);t.clones.append({"actor":actor,"node":node});actor.apply_source_state("hidden",true)
	if t.clones.is_empty():t.erase("cleanup");return []
	var tracks: Array=owner.get_meta("i5_monbg",[]);tracks.append(t);owner.set_meta("i5_monbg",tracks);return [t]
static func _background(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if not bool(step.get("restore",false)) and (int(step.get("source_background_id",-1)) not in [7,8,18,19] or not ResourceLoader.exists(str(step.get("texture","")))):return []
	var t: Dictionary={"kind":"source_bird_horn_owned","mode":"background","domain":"background","settings":step.duplicate(true),"owner":owner,"originals":c.resolve("attacker"),"args":[],"age":0,"ticks":32,"retired":false,"update":advance};return [t]
static func _background_tick(t: Dictionary,c: BattleAnimationContext) -> void:
	if not is_instance_valid(t.owner._source_blackout):
		t.owner._source_blackout=Polygon2D.new();t.owner._source_blackout.polygon=PackedVector2Array([Vector2.ZERO,Vector2(240,0),Vector2(240,160),Vector2(0,160)]);t.owner.add_child(t.owner._source_blackout)
	t.owner._source_blackout.color=Color(0,0,0,float(t.age)/16.0 if int(t.age)<=16 else float(32-int(t.age))/16.0)
	if int(t.age)==16:
		if not is_instance_valid(t.owner._source_background):
			t.owner._source_background=Sprite2D.new();t.owner._source_background.centered=false;t.owner._source_background.region_enabled=true;t.owner._source_background.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED;t.owner.add_child(t.owner._source_background)
		if bool(t.settings.restore):t.owner._source_background.visible=false
		else:t.owner._source_background.texture=load(str(t.settings.texture));t.owner._source_background.region_rect=Rect2(0,0,240,160);t.owner._source_background.visible=true

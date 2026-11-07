extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Candidate source PREVIEW only. Native persistent hidden admission/handoff is separate.
const ARITIES={"fly_charge":4,"fly_hit":1,"bounce_charge":2,"bounce_hit":0,"dive_charge":4,"dive_splash":1,"dive_sweat":2,"water_bubble":2,"water_impact":4}
const ROOTS={"fly_charge":"sub_80DA300","fly_hit":"sub_80DA38C","bounce_charge":"sub_80DB194","bounce_hit":"sub_80DB1F4","dive_charge":"sub_80DB288","dive_splash":"sub_80DB374","dive_sweat":"sub_80DB458","water_bubble":"sub_80D4044","water_impact":"sub_80E27A0"}
static func _s16(value: int) -> int:return ((value+32768)&65535)-32768
static func _anchor(actor: BattleAnimationActor,c: BattleAnimationContext,origin: bool=false) -> Vector2:
	var p: Vector2=BattleElectricContract.source_anchor(actor,c,"origin" if origin else "center")
	return Vector2(int(p.x),int(p.y))
static func _live(t: Dictionary,c: BattleAnimationContext) -> bool:
	return is_instance_valid(t.owner) and t.owner.is_inside_tree() and t.owner.context==c and c.actors.get(t.attacker.id)==t.attacker and c.actors.get(t.target.id)==t.target and t.attacker.is_present() and t.target.is_present()
static func _words(owner: Node2D,c: BattleAnimationContext) -> Array[int]:
	var rng: RandomNumberGenerator
	if owner.has_meta("i4_source_rng"):rng=owner.get_meta("i4_source_rng")
	else:
		rng=RandomNumberGenerator.new();rng.seed=c.seed_value;owner.set_meta("i4_source_rng",rng)
	var result: Array[int]=[rng.randi()&65535,rng.randi()&65535]
	var count: int=int(owner.get_meta("i4_source_rng_draws",0));owner.set_meta("i4_source_rng_draws",count+2)
	return result
static func _integer(value: Variant,low: int,high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==int(value) and int(value)>=low and int(value)<=high
static func _program_valid(program: Array,affine: bool=false) -> bool:
	if program.is_empty():return false
	for value: Variant in program:
		if not value is Dictionary:return false
		match str(value.get("op","")):
			"end":pass
			"jump":
				if not _integer(value.get("target"),0,program.size()-1):return false
			"loop":
				if not _integer(value.get("count"),0,65535):return false
			"frame":
				if not _integer(value.get("ticks"),0,65535):return false
				if affine:
					for key: String in ["x","y","rotation"]:
						if not _integer(value.get(key),-32768,32767):return false
				elif not _integer(value.get("tile"),0,65535):return false
			_:return false
	return true
static func _constructor_valid(step: Dictionary,mode: String) -> bool:
	var names: Dictionary={"fly_charge":["gBattleAnimSpriteTemplate_83DA450"],"fly_hit":["gBattleAnimSpriteTemplate_83DA468"],"bounce_charge":["gBattleAnimSpriteTemplate_83DA568"],"bounce_hit":["gBattleAnimSpriteTemplate_83DA594"],"dive_charge":["gBattleAnimSpriteTemplate_83DA5D8"],"dive_splash":["gBattleAnimSpriteTemplate_83DA614"],"dive_sweat":["gBattleAnimSpriteTemplate_83DA62C"],"water_impact":["gBattleAnimSpriteTemplate_83DB4D8","gBasicHitSplatSpriteTemplate"],"water_bubble":["gBattleAnimSpriteTemplate_83D9360"]}
	if str(step.get("source_template","")) not in names.get(mode,[]):return false
	if not _program_valid(step.get("frame_program",[])):return false
	var affine: Array=step.get("affine_program",[])
	if not affine.is_empty() and not _program_valid(affine,true):return false
	if mode in ["dive_splash","dive_sweat"] and not affine.is_empty():return false
	if mode=="fly_hit":
		for key: String in ["0","1"]:
			if not _program_valid(step.get("source_affine_variants",{}).get(key,[]),true):return false
	return true
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var mode: String=str(step.get("mode",""));var args: Array=step.get("source_args",[])
	if mode=="show_actor":
		var originals: Array[BattleAnimationActor]=c.resolve("attacker")
		if not originals.is_empty() and owner.get("context")==c:originals[0].apply_source_state("visible",true)
		return []
	if not ARITIES.has(mode) or args.size()!=int(ARITIES[mode]) or str(step.get("source_callback",""))!=str(ROOTS[mode]):return []
	if not _constructor_valid(step,mode):return []
	var expected_tag: String="ANIM_TAG_SPLASH" if mode=="dive_splash" else "ANIM_TAG_SWEAT_BEAD" if mode=="dive_sweat" else "ANIM_TAG_SMALL_BUBBLES" if mode=="water_bubble" else "ANIM_TAG_WATER_IMPACT" if mode=="water_impact" and str(step.get("source_template",""))=="gBattleAnimSpriteTemplate_83DB4D8" else "ANIM_TAG_IMPACT" if mode=="water_impact" else "ANIM_TAG_ROUND_SHADOW"
	if step.get("source_tile_tag","")!=expected_tag or step.get("source_palette_tag","")!=expected_tag:return []
	for value: Variant in args:
		if not _integer(value,-32768,32767):return []
	var attackers: Array[BattleAnimationActor]=c.resolve("attacker");var targets: Array[BattleAnimationActor]=c.resolve("target")
	if attackers.is_empty() or targets.is_empty() or not is_instance_valid(owner) or owner.get("context")!=c:return []
	var attacker: BattleAnimationActor=attackers[0];var target: BattleAnimationActor=targets[0]
	# Only a currently visible original or THIS execution's existing hidden claim.
	# This does not admit an arbitrary hidden native actor or a replacement.
	if not attacker.sprite.visible and not (attacker._owned_hidden and not attacker._expected_visible) and not (attacker.hidden_projection!=null and attacker.hidden_projection.visual_live()):return []
	if not step.has("texture") or not ResourceLoader.exists(str(step.texture)):return []
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;node.region_rect=Rect2(0,0,int(step.frame_size[0]),int(step.frame_size[1]));owner.add_child(node)
	var t: Dictionary={"kind":"source_hidden_actor_emergence","settings":step.duplicate(true),"args":args.duplicate(),"owner":owner,"node":node,"attacker":attacker,"target":target,"age":0,"ticks":4096,"update":advance,"state":0,"counter":0,"accumulator":0,"x2":0,"y2":0,"retired":false,"matrix_y":256,"source_scale":Vector2.ONE,"source_rotation":0.0}
	var origin: Vector2=_anchor(attacker,c);var target_center: Vector2=_anchor(target,c);var target_origin: Vector2=_anchor(target,c,true)
	t.x=int(origin.x);t.y=int(origin.y)
	match mode:
		"fly_charge","dive_charge","bounce_charge":
			var direction: int=BattleElectricContract.source_offset_direction(c,attacker,target)
			t.x=_s16(t.x+direction*int(args[0]));t.y=_s16(t.y+int(args[1]));attacker.apply_source_state("hidden",true)
			if mode!="bounce_charge":t.countdown=int(args[2]);t.acceleration=int(args[3])
		"fly_hit":
			if int(args[0])<=0:node.queue_free();return []
			t.x=-32 if attacker.side==0 else 272;t.y=-32
			var dx: int=int(target_center.x)-int(t.x);var dy: int=int(target_center.y)-int(t.y)
			t.vx=(((absi(dx)<<8)&65535)/int(args[0]))&65534;t.vy=(((absi(dy)<<8)&65535)/int(args[0]))&65534
			if dx<0:t.vx=int(t.vx)|1
			if dy<0:t.vy=int(t.vy)|1
			t.qx=0;t.qy=0;t.settings.affine_program=t.settings.source_affine_variants["0" if attacker.side==0 else "1"]
		"bounce_hit":
			t.x=int(target_center.x);t.y=int(target_origin.y);t.y2=_s16(-int(t.y)-32)
		"dive_splash":
			var actor: BattleAnimationActor=attacker if int(args[0])==0 else target
			var p: Vector2=_anchor(actor,c,true);t.x=int(p.x);t.y=int(p.y);t.matrix_y=512;t.matrix_x=-256 if c.contest and str(c.source_appearance_species.get(attacker.id,""))!="UNOWN" else 256
		"water_impact","water_bubble":
			var actor: BattleAnimationActor=target if mode=="water_bubble" or int(args[2])!=0 else attacker
			var p: Vector2=_anchor(actor,c);var direction: int=BattleElectricContract.source_offset_direction(c,attacker,target)
			t.x=_s16(int(p.x)+direction*int(args[0]));t.y=_s16(int(p.y)+int(args[1]))
			if mode=="water_bubble":
				t.rng_words=_words(owner,c);t.vx=(int(t.rng_words[0])&255)|256;t.vy=int(t.rng_words[1])&511
				if int(t.vy)>255:t.vy=256-int(t.vy)
				t.qx=0;t.qy=0
		"dive_sweat":
			var actor: BattleAnimationActor=attacker if int(args[1])==0 else target
			var p: Vector2=_anchor(actor,c,true);t.x=int(p.x);t.y=int(p.y)+32;t.rng_words=_words(owner,c)
			var a: int=int(t.rng_words[0])&511;var b: int=int(t.rng_words[1])&127
			t.vx=736+(a if (a&1)!=0 else -a);t.vy=896+(b if (b&1)!=0 else -b);node.flip_h=int(args[0])!=0
	var counts: Dictionary=owner.get_meta("i4_source_spawn_counts",{});counts[mode]=int(counts.get(mode,0))+1;owner.set_meta("i4_source_spawn_counts",counts)
	BattleSourcePriority.initialize(t,c,owner)
	t.cleanup=func() -> void:
		if is_instance_valid(node):node.queue_free()
	_pose(t,c);return [t]
static func _retire(t: Dictionary) -> void:
	if t.retired:return
	t.retired=true;t.ticks=int(t.age);t.cleanup.call()
static func _pose(t: Dictionary,c: BattleAnimationContext) -> void:
	var mode: String=str(t.settings.mode)
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.frame_program,maxi(0,int(t.age)-1)).frame
	var rect: Array=t.settings.frame_rects[str(int(frame.tile))];t.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3])
	if mode=="dive_splash":
		t.source_scale=Vector2(256.0/float(t.matrix_x),256.0/float(t.matrix_y))
	elif not t.settings.affine_program.is_empty():
		var pose: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.affine_program,maxi(0,int(t.age)-1),true)
		# Ruby table scales pass ConvertScaleParam before ObjAffineSet; displayed basis is source/256.
		t.source_scale=Vector2(float(pose.matrix.x)/256.0,float(pose.matrix.y)/256.0);t.source_rotation=float(pose.rotation)*TAU/256.0
	var transform:=Transform2D(float(t.source_rotation),t.source_scale,0.0,Vector2(int(t.x)+int(t.x2),int(t.y)+int(t.y2)))
	t.node.transform=t.owner.global_transform.affine_inverse()*c.field.global_transform*transform
	if t.has("source_priority_actor_id"):
		var actor: BattleAnimationActor=c.actors[int(t.source_priority_actor_id)]
		t.node.z_index=BattleSourcePriority.relative_layer(actor,int(t.source_oam_subpriority)-BattleElectricContract.source_subpriority(actor,c),c,t.owner)
	else:t.node.z_index=BattleSourcePriority.relative_layer(t.attacker,-1,c,t.owner)
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if t.retired:return
	if not is_instance_valid(t.node) or not _live(t,c):_retire(t);return
	var mode: String=str(t.settings.mode)
	match mode:
		"fly_charge":
			if int(t.countdown)>0:t.countdown-=1
			else:t.accumulator=_s16(int(t.accumulator)+int(t.acceleration));t.y2=_s16(int(t.y2)-(int(t.accumulator)>>8))
			if int(t.y)+int(t.y2)<-32:_retire(t)
		"fly_hit":
			t.qx=(int(t.qx)+int(t.vx))&65535;t.qy=(int(t.qy)+int(t.vy))&65535;t.x2=(int(t.qx)>>8)*(-1 if (int(t.vx)&1)!=0 else 1);t.y2=(int(t.qy)>>8)*(-1 if (int(t.vy)&1)!=0 else 1)
			if (int(t.qx)>>8)>200:t.x=_s16(int(t.x)+int(t.x2));t.x2=0;t.qx=int(t.qx)&255
			if ((int(t.x)+int(t.x2)+32)&4294967295)>304 or int(t.y)+int(t.y2)>160:t.attacker.apply_source_state("visible",true);_retire(t)
		"bounce_charge":
			if bool(BattleSourceCommandProgram.evaluate(t.settings.affine_program,maxi(0,int(t.age)-1),true).ended):_retire(t)
		"bounce_hit":
			if int(t.state)==0:
				t.y2=_s16(int(t.y2)+10)
				if int(t.y2)>=0:t.state=1
			else:
				t.y2=_s16(int(t.y2)-10)
				if int(t.y)+int(t.y2)<-32:t.attacker.apply_source_state("visible",true);_retire(t)
		"dive_charge":
			if int(t.state)==0:
				if int(t.countdown)>0:t.countdown-=1
				elif int(t.y)+int(t.y2)>-32:t.accumulator=_s16(int(t.accumulator)+int(t.acceleration));t.y2=_s16(int(t.y2)-(int(t.accumulator)>>8))
				else:
					t.node.visible=false;var previous: int=int(t.counter);t.counter=_s16(previous+1)
					if previous>20:t.state=1
			else:
				t.y2=_s16(int(t.y2)+(int(t.accumulator)>>8))
				if int(t.y)+int(t.y2)>-32:t.node.visible=true
				if int(t.y2)>0:_retire(t)
		"dive_splash":
			t.matrix_y-=40 if int(t.counter)<=11 else -40;t.counter+=1
			var correction: int=mini(128,int(15616/int(t.matrix_y))+1);t.y2=int((64-correction)/2)
			if int(t.counter)==24:t.matrix_y=256;t.source_scale=Vector2(256.0/float(t.matrix_x),1.0);_pose(t,c);_retire(t)
		"water_impact":
			if int(t.state)==1:_retire(t)
			elif bool(BattleSourceCommandProgram.evaluate(t.settings.affine_program,maxi(0,int(t.age)-1),true).ended):t.state=1
		"water_bubble":
			t.qx=_s16(int(t.qx)+int(t.vx));t.qy=_s16(int(t.qy)+int(t.vy));t.x2=(int(t.qx)>>8)*(-1 if (int(t.vx)&1)!=0 else 1);t.y2=int(t.qy)>>8;t.counter+=1
			if int(t.counter)==21:_retire(t)
		"dive_sweat":
			t.x2=_s16(int(t.x2)+(int(t.vx)>>8)*(-1 if int(t.args[0])!=0 else 1));t.y2=_s16(int(t.y2)-(int(t.vy)>>8));t.vy=_s16(int(t.vy)-32);t.counter+=1
			if int(t.counter)==31:_retire(t)
	if not t.retired:_pose(t,c)

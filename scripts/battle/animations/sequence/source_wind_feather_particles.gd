extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Three source-specific private state machines; coordinates stay in FIELD space.
static func create(step: Dictionary,context: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var attackers: Array[BattleAnimationActor]=context.resolve("attacker")
	var targets: Array[BattleAnimationActor]=context.resolve("target")
	if attackers.is_empty() or targets.is_empty():return []
	var attacker: BattleAnimationActor=attackers[0];var target: BattleAnimationActor=targets[0]
	var args: Array=step.source_args.duplicate()
	if step.mode=="excluded_palette":return _palette(step,args,context,target)
	var actor: BattleAnimationActor=attacker if step.mode=="falling_feather" and (int(args[7])&256)!=0 else target
	if step.mode=="flying_sparkle":actor=attacker if int(args[6])==0 else target
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;owner.add_child(node)
	var track: Dictionary={"kind":"source_wind_feather_particle","settings":step.duplicate(true),"args":args,"owner":owner,"node":node,"attacker":attacker,"target":target,"selected":actor,"age":0,"ticks":4096,"update":advance,"phase":0,"source_rotation":0.0,"source_scale":Vector2.ONE,"behind":false}
	BattleSourcePriority.initialize(track,context,owner)
	match str(step.mode):
		"twister_particle":
			var origin: Vector2=BattleElectricContract.source_anchor(target,context)
			if _double(context) and not context.contest:
				var partner: BattleAnimationActor=_partner(target,context)
				if partner!=null:
					var other: Vector2=BattleElectricContract.source_anchor(partner,context)
					origin=Vector2((int(origin.x)+int(other.x))/2,(int(origin.y)+int(other.y))/2)
			track.origin_field=Vector2(int(origin.x),int(origin.y)+32)
			track.position_field=track.origin_field;track.remaining=int(args[0]);track.rise=int(args[1]);track.radius=int(args[3])
		"falling_feather":
			var origin: Vector2=BattleElectricContract.source_anchor(actor,context,"origin")
			if actor.side==0:args[0]=-int(args[0])
			track.origin_field=Vector2(int(origin.x)+int(args[0]),int(origin.y)+int(args[1]))
			track.position_field=track.origin_field;track.y_q8=(int(track.origin_field.y)<<8)&65535
			track.cutoff=(int(origin.y)+int(args[6]))&32767;track.phase=int(args[2])&255
			track.matrix_offset=(int(args[2])>>8)&255;track.amplitudes=[int(args[5])&255,(int(args[5])>>8)&255]
			track.amplitude_index=0;track.quadrant=int(track.phase)/64;track.waiting=false;track.wait=0;track.pending_flip=false;track.flip=false;track.terminal_pending=false
			track.behind=int(track.phase)>=64 and int(track.phase)<192
			if bool(track.behind) and (int(args[3])&32768)==0:track.flip=true
			elif not bool(track.behind) and (int(args[3])&32768)!=0:track.flip=true
			_feather_pose(track)
		"flying_sparkle":
			track.direction=1 if actor.side!=0 else -1
			track.origin_field=Vector2(-16 if actor.side!=0 else 256,int(args[0]))
			if int(args[5])==2:track.origin_field.y=int(BattleElectricContract.source_anchor(actor,context).y)+int(args[0])
			elif int(args[5])==3:track.origin_field.y=int(BattleElectricContract.source_anchor(target,context).y)+int(args[0])
			track.behind=int(args[5]) in [1,3];track.position_field=track.origin_field;track.phase=int(args[2]);track.counter=0
	_frame(track,0);_paint(track,context)
	return [track]

static func _double(context: BattleAnimationContext) -> bool:
	if context.has_meta("source_double_battle"):return bool(context.get_meta("source_double_battle"))
	for actor: BattleAnimationActor in context.actors.values():
		if actor.is_present() and context.source_position(actor.id) in [2,3]:return true
	return false
static func _partner(actor: BattleAnimationActor,context: BattleAnimationContext) -> BattleAnimationActor:
	for candidate: BattleAnimationActor in context.actors.values():
		if candidate.is_present() and context.source_position(candidate.id)==(context.source_position(actor.id)^2):return candidate
	return null
static func _palette(step: Dictionary,args: Array,context: BattleAnimationContext,target: BattleAnimationActor) -> Array[Dictionary]:
	var settings: Dictionary={"blend_start":int(args[2]),"blend_end":int(args[3]),"blend_delay":maxi(1,int(args[1])+1),"color":"%02x%02x%02x"%[((int(args[4])&31)*255)/31,(((int(args[4])>>5)&31)*255)/31,(((int(args[4])>>10)&31)*255)/31]}
	var ticks: int=(absi(int(args[3])-int(args[2]))+1)*maxi(1,int(args[1])+1)
	var tracks: Array[Dictionary]=[{"kind":"source_palette","settings":settings.duplicate(true),"age":0,"ticks":ticks}]
	for actor: BattleAnimationActor in context.actors.values():
		if actor.id!=target.id and actor.is_present() and (actor.sprite.visible or (actor._owned_hidden and actor._base_visible)):
			tracks.append({"kind":"source_palette","settings":settings.duplicate(true),"age":0,"ticks":ticks,"actor":actor})
	return tracks
static func _frame(track: Dictionary,age: int) -> void:
	var program: Array=track.settings.frame_program
	if track.settings.mode=="falling_feather":program=track.settings.source_frame_variants["1" if bool(track.flip) else "0"]
	var command: Dictionary=BattleSourceCommandProgram.evaluate(program,maxi(0,age)).frame
	var rect: Array=track.settings.frame_rects[str(int(command.tile))]
	track.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);track.node.flip_h=bool(command.get("flip_h",false));track.node.flip_v=bool(command.get("flip_v",false))
	if track.settings.mode!="falling_feather" and not track.settings.get("affine_program",[]).is_empty():
		var affine: Dictionary=BattleSourceCommandProgram.evaluate(track.settings.affine_program,maxi(0,age),true)
		track.source_scale=Vector2(256.0/maxf(1,affine.matrix.x),256.0/maxf(1,affine.matrix.y));track.source_rotation=float(affine.rotation)*TAU/256
static func _paint(track: Dictionary,context: BattleAnimationContext) -> void:
	var source:=Transform2D(float(track.source_rotation),track.source_scale,0.0,track.position_field)
	track.node.transform=track.owner.global_transform.affine_inverse()*context.field.global_transform*source
	track.node.z_index=BattleSourcePriority.relative_layer(track.selected,1 if bool(track.behind) else -1,context,track.owner)
static func _feather_pose(track: Dictionary) -> void:
	track.x2=BattleSourceTrig.sine(int(track.phase),int(track.amplitudes[int(track.amplitude_index)]))
	track.matrix_angle=(((-int(track.x2))>>1)+int(track.matrix_offset))&255
	track.source_rotation=float(track.matrix_angle)*TAU/256
	track.source_matrix=[BattleSourceTrig.VALUES[int(track.matrix_angle)+64],BattleSourceTrig.VALUES[int(track.matrix_angle)],-BattleSourceTrig.VALUES[int(track.matrix_angle)],BattleSourceTrig.VALUES[int(track.matrix_angle)+64]]
	track.position_field=Vector2(track.origin_field.x+int(track.x2),int(track.y_q8)>>8)
static func _feather(track: Dictionary) -> void:
	if bool(track.terminal_pending):track.ticks=int(track.age);return
	if bool(track.waiting):
		var previous: int=int(track.wait);track.wait=previous-1
		if previous>0:return
		track.waiting=false;track.wait=0;return
	var quadrant: int=int(track.phase)/64;var previous_quadrant: int=int(track.quadrant)
	if (quadrant==0 and previous_quadrant==1) or (quadrant==1 and previous_quadrant==0) or (quadrant==2 and previous_quadrant==3) or (quadrant==3 and previous_quadrant==2):
		track.pending_flip=true
		if quadrant!=3:track.waiting=true;track.wait=0
	elif (quadrant==0 and previous_quadrant==3) or (quadrant==3 and previous_quadrant==0):
		track.amplitude_index=int(track.amplitude_index)^1;track.waiting=true;track.wait=0
	elif (quadrant==1 and previous_quadrant==2) or (quadrant==2 and previous_quadrant==1):track.waiting=true;track.wait=0
	elif bool(track.pending_flip):track.flip=not bool(track.flip);track.behind=not bool(track.behind);track.pending_flip=false
	track.quadrant=quadrant
	# Source paints using the PRE-increment phase, then advances packed baseY/angle.
	_feather_pose(track)
	track.y_q8=(int(track.y_q8)+(int(track.args[4])&65535))&65535
	track.position_field.y=int(track.y_q8)>>8
	track.phase=(int(track.phase)+(-1 if (int(track.args[3])&32768)!=0 else 1)*(int(track.args[3])&32767))&255
	if int(track.position_field.y)>=int(track.cutoff):track.terminal_pending=true
static func advance(track: Dictionary,context: BattleAnimationContext) -> void:
	if not is_instance_valid(track.node):track.ticks=int(track.age);return
	if not track.attacker.is_present() or not track.target.is_present() or not track.selected.is_present():track.node.visible=false;track.ticks=int(track.age);return
	match str(track.settings.mode):
		"twister_particle":
			if int(track.rise)==255 or int(track.rise)>0:
				track.origin_field.y-=2
				if int(track.rise)!=255:track.rise-=2
			track.phase=(int(track.phase)+int(track.args[2])*(2 if int(track.remaining)<int(track.args[4]) else 1))&255
			track.position_field=track.origin_field+Vector2(BattleSourceTrig.cosine(int(track.phase),int(track.radius)),BattleSourceTrig.sine(int(track.phase),5))
			track.behind=int(track.phase)>127;track.remaining-=1
			if int(track.remaining)==0:track.ticks=int(track.age)
		"falling_feather":_feather(track)
		"flying_sparkle":
			track.position_field=track.origin_field+Vector2(int(track.direction)*int(track.args[3])*int(track.counter),BattleSourceTrig.sine(int(track.phase),int(track.args[1])))
			track.phase=(int(track.args[4])*int(track.counter))&255;track.counter+=1
			if (int(track.direction)==1 and track.position_field.x>247) or (int(track.direction)==-1 and track.position_field.x<=-16):track.ticks=int(track.age)
	_frame(track,maxi(0,int(track.age)-1));_paint(track,context)

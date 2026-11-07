extends RefCounted
class_name BattleFieldOwned
## Separate source task state, actor contributions, and persistent row-buffer lifetime.
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

static func create(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Array[Dictionary]:
	if str(step.mode)=="packed_drain_roles":
		var packed: int=int(context.get_meta("source_general_argument",-1))
		if packed<0:
			packed=context.source_position(context.attacker_id)|(context.source_position(context.target_ids[0])<<8) if not context.target_ids.is_empty() else -1
		var resolved: Array[int]=[]
		for bank: int in [packed&255,(packed>>8)&255]:
			var matches: Array[int]=[]
			for id: Variant in context.actors:
				var bound: BattleAnimationActor=context.actors[id]
				if context.source_position(int(id))==bank and bound.is_present():matches.append(int(id))
			if packed<0 or matches.size()!=1:
				owner.lifecycle_aborted=true;owner.finish("failed");return []
			resolved.append(matches[0])
		context.attacker_id=resolved[0];context.target_ids.assign([resolved[1]])
		return [] # Source task is destroyed synchronously; no particle or barrier owner.
	var selected: Array[BattleAnimationActor]=context.resolve(str(step.selector))
	if selected.is_empty():return []
	var actor: BattleAnimationActor=selected[0]
	var mode: String=str(step.mode)
	var track: Dictionary={"kind":"source_field_owned","source_callback":str(step.source_callback),"settings":step.duplicate(true),"actor_owner":actor,"owner":owner,"age":0,"ticks":4096,"update":advance}
	if mode=="flail_actor":
		track.kind="source_field_actor";track.actor=actor;track.angle=0;track.state=0;track.counter=0;track.decay=32;track.amplitude=2048;track.pose={"offset":Vector2.ZERO,"rotation":0.0}
	elif mode=="rapid_rows":return _rows_create(track,context)
	elif mode=="sky_scroll":
		track.domain="maintenance";track.state=0;track.counter=0;track.x_fraction=0;track.y_fraction=0;track.scroll=Vector2.ZERO
		track.background=null;track.cleanup=_sky_cleanup.bind(track)
		advance(track,context) # ScriptCmd_createvisualtask invokes this initializer/update.
	else:
		var node:=Sprite2D.new();owner.add_child(node);track.node=node
		BattleSourcePriority.initialize(track,context,owner)
		node.texture=load(str(step.get("texture","res://graficos/batalla/animaciones/blue_orb_pal_236_8x8_0.png")))
		node.region_enabled=true
		track.origin=actor.anchor(owner,"origin" if mode=="rapid_wave" else "center")
		if mode=="reversal_orbit":
			track.angle=int(step.source_args[1]);track.radius_x=0;track.radius_y=0;track.counter=0;track.state=0
			advance(track,context)
		elif mode=="rapid_wave":
			track.origin.x+=int(step.source_args[1]);track.y=int(step.source_args[2]);track.angle=0
		elif mode=="sky_impact":
			var attackers: Array[BattleAnimationActor]=context.resolve("attacker")
			var targets: Array[BattleAnimationActor]=context.resolve("target")
			if attackers.is_empty() or targets.is_empty():node.queue_free();return []
			var direction: int=BattleElectricContract.source_offset_direction(context,attackers[0],targets[0])
			# Removing float-valued native x2 can leave roundoff at equal origins;
			# Ruby's integer coordinate equality instead takes the attacker side.
			if is_equal_approx(BattleElectricContract.source_anchor(attackers[0],context,"origin").x,BattleElectricContract.source_anchor(targets[0],context,"origin").x):direction=1 if attackers[0].side==0 else -1
			track.origin=owner.to_local(context.field.to_global(BattleElectricContract.source_anchor(actor,context)))+Vector2(int(step.source_args[0])*direction,int(step.source_args[1]))
			track.affine_wait=false
		elif mode=="flail_impact":
			var rng:=RandomNumberGenerator.new();rng.seed=context.seed_value+owner.elapsed_ticks+int(step.get("source_line",0))
			var args: Array=track.settings.source_args
			if int(args[1])==-1:
				args[1]=rng.randi()&3;owner._source_args[1]=int(args[1])
				track.settings.affine_program=track.settings.random_affine_programs[str(args[1])]
			var attackers: Array[BattleAnimationActor]=context.resolve("attacker")
			var targets: Array[BattleAnimationActor]=context.resolve("target")
			if attackers.is_empty() or targets.is_empty():node.queue_free();return []
			var direction: int=BattleElectricContract.source_offset_direction(context,attackers[0],targets[0])
			track.origin=owner.to_local(context.field.to_global(BattleElectricContract.source_anchor(actor,context,"origin")))+Vector2(int(args[0])*direction,int(args[1]))
			track.origin+=Vector2(rng.randi()%48-24,rng.randi()%24-12)
			track.affine_wait=false
		_frame(track)
		if mode!="reversal_orbit":node.position=track.origin+Vector2(0,int(track.get("y",0)))
	return [track]

static func _frame(track: Dictionary) -> void:
	var settings: Dictionary=track.settings
	if not settings.has("frame_program"):return
	var result: Dictionary=BattleSourceCommandProgram.evaluate(settings.frame_program,int(track.age))
	var rect: Array=settings.frame_rects[str(int(result.frame.tile))]
	track.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3])
	track.node.flip_h=bool(result.frame.get("flip_h",false));track.node.flip_v=bool(result.frame.get("flip_v",false))
	if not settings.get("affine_program",[]).is_empty():
		var affine: Dictionary=BattleSourceCommandProgram.evaluate(settings.affine_program,int(track.age),true)
		track.node.scale=Vector2(256.0/maxf(1,affine.matrix.x),256.0/maxf(1,affine.matrix.y))
		track.node.rotation=float(affine.rotation)*TAU/256
		if affine.ended:
			if bool(track.get("affine_wait",false)):track.ticks=int(track.age)
			else:track.affine_wait=true

static func advance(track: Dictionary, context: BattleAnimationContext) -> void:
	var actor: BattleAnimationActor=track.actor_owner
	if not actor.is_present():
		if track.has("node") and is_instance_valid(track.node):track.node.visible=false
		track.ticks=int(track.age);return
	var mode: String=str(track.settings.mode)
	if mode=="flail_actor":
		if int(track.state)==2:
			track.pose={"offset":Vector2.ZERO,"rotation":0.0};track.ticks=int(track.age);return
		track.angle+=512 if int(track.state)==0 else -512
		var amplitude: int=int(track.amplitude)
		if (int(track.state)==0 and int(track.angle)>=amplitude) or (int(track.state)==1 and int(track.angle)<=-amplitude):
			var difference: int=amplitude-int(track.angle)
			var quotient: int=int(float(difference)/(amplitude*2))
			var remainder: int=difference-quotient*amplitude*2
			if int(track.state)==0:
				track.angle=amplitude-remainder if (quotient&1)==0 else remainder-amplitude
				if (quotient&1)==0:track.state=1
			else:
				track.angle=remainder-amplitude if (quotient&1)==0 else amplitude-remainder
				if (quotient&1)==0:track.state=0
		var matrix_c: int=BattleSourceTrig.sine((int(track.angle)&65535)>>8,256)
		track.pose={"offset":Vector2(-int(float(track.angle)/64),absi(matrix_c)>>3),"rotation":float(track.angle)*TAU/65536}
		track.counter+=1
		if int(track.counter)>8:
			if int(track.decay)>0:track.decay-=1;track.amplitude=maxi(16,int(track.amplitude)-64)
			else:track.state=2
	elif mode=="reversal_orbit":
		track.node.position=track.origin+Vector2(BattleSourceTrig.sine(int(track.angle),int(track.radius_x)>>8),BattleSourceTrig.sine(int(track.angle)+64,int(track.radius_y)>>8))
		track.angle=(int(track.angle)+9)&255
		track.node.z_index=BattleSourcePriority.relative_layer(actor,-1 if int(track.angle)<64 or int(track.angle)>195 else 1,context,track.owner)
		var sign: int=1 if int(track.state)==0 else -1
		track.radius_x+=1024*sign;track.radius_y+=256*sign;track.counter+=1
		if int(track.counter)==int(track.settings.source_args[0]):
			if int(track.state)==0:track.state=1;track.counter=0
			else:track.ticks=int(track.age)
		_frame(track)
	elif mode=="rapid_wave":
		track.angle=(int(track.angle)+int(track.settings.source_args[4]))&255
		track.y+=int(track.settings.source_args[5])
		track.node.position=track.origin+Vector2(BattleSourceTrig.sine(int(track.angle),256)>>4,int(track.y))
		var destination: int=int(track.settings.source_args[3])
		if (int(track.settings.source_args[2])>destination and int(track.y)<destination) or (int(track.settings.source_args[2])<=destination and int(track.y)>destination):track.ticks=int(track.age)
		_frame(track)
	elif mode in ["flail_impact","sky_impact"]:_frame(track)
	elif mode=="rapid_rows":_rows_advance(track)
	elif mode=="rapid_buffer":
		if not is_instance_valid(track.node):track.ticks=int(track.age)
	elif mode=="sky_scroll":_sky_advance(track)

static func _rows_create(track: Dictionary, context: BattleAnimationContext) -> Array[Dictionary]:
	var actor: BattleAnimationActor=track.actor_owner
	var owner: Node2D=track.owner
	var key: String="source_rapid_buffer_%s"%actor.id
	var buffer: Dictionary=owner.get_meta(key,{})
	var created: bool=buffer.is_empty() or not is_instance_valid(buffer.get("node"))
	if created:
		var node: Sprite2D=BattleIdentityCopy.clone_sprite(actor,owner);owner.add_child(node)
		var material:=ShaderMaterial.new();material.shader=load("res://scripts/battle/animations/sequence/source_rapid_rows.gdshader")
		node.material=material;node.z_index=BattleSourcePriority.actor_layer(actor,owner)
		var source: Sprite2D=actor.sprite
		var uv_origin:=Vector2.ZERO;var uv_size:=Vector2.ONE
		if source.region_enabled:
			uv_origin=source.region_rect.position/source.texture.get_size();uv_size=source.region_rect.size/source.texture.get_size()
		else:
			uv_size=Vector2(1.0/source.hframes,1.0/source.vframes);uv_origin=Vector2(source.frame_coords)*uv_size
		material.set_shader_parameter("frame_uv_origin",uv_origin);material.set_shader_parameter("frame_uv_size",uv_size)
		buffer={"kind":"source_field_owned","source_callback":"sub_812CDC8_buffer","settings":{"mode":"rapid_buffer"},"actor_owner":actor,"owner":owner,"node":node,"owned_material":material,"age":0,"ticks":2147483647,"domain":"maintenance","update":advance,"key":key,"released":false}
		buffer.cleanup=_rows_cleanup.bind(buffer);buffer.abandon=_rows_retire.bind(buffer,false)
		if owner is BattleAnimationSequenceRunner and not owner.register_provisional_cleanup(buffer):
			# The constructor lost authority before publishing metadata or hide.
			_rows_retire(buffer,false);return []
		owner.set_meta(key,buffer);actor.apply_source_state("hidden",true)
		if buffer.released:return [] # A hide signal may synchronously cancel.
	track.buffer=buffer;track.owned_material=buffer.owned_material
	# Source sub_8077FC0 includes species-specific OAM offsets. For arbitrary
	# aesthetic actors use their bound raw origin; never infer a party species.
	var source_y: int=int(actor.anchor(owner,"origin").y)
	track.top=maxi(0,source_y-33);track.bottom=source_y+36;track.front=track.bottom;track.back=track.bottom;track.boundary_lag=8;track.toggle=0;track.timer=0;track.band=0
	buffer.owned_material.set_shader_parameter("source_row_origin",float(source_y-33))
	track.final_displacement=240 if int(track.settings.source_args[2])==0 else 0
	track.initial_displacement=0 if int(track.settings.source_args[2])==0 else 240
	_rows_material(track)
	var result: Array[Dictionary]=[track]
	if created:result.append(buffer)
	return result

static func _rows_material(track: Dictionary) -> void:
	var buffer: Dictionary=track.buffer
	if not is_instance_valid(buffer.node) or buffer.node.material!=buffer.owned_material:return
	for key: String in ["front","back","band","initial_displacement","final_displacement"]:
		buffer.owned_material.set_shader_parameter(key,float(track[key]))

static func _rows_advance(track: Dictionary) -> void:
	track.front=maxi(int(track.top),int(track.front)-int(track.settings.source_args[1]))
	var ended: bool=false
	if int(track.boundary_lag)>0:track.boundary_lag-=1
	else:
		track.back-=int(track.settings.source_args[1])
		if int(track.back)<int(track.top):track.back=track.top;ended=true
	track.timer+=1
	if int(track.timer)>1:track.timer=0;track.toggle=1-int(track.toggle);track.band=0 if int(track.toggle)==1 else 240
	_rows_material(track)
	if ended:
		track.ticks=int(track.age)
		if int(track.settings.source_args[2])!=0:
			_rows_cleanup(track.buffer);track.buffer.ticks=int(track.buffer.age)

static func _rows_cleanup(buffer: Dictionary) -> void:
	_rows_retire(buffer,true)

static func _rows_retire(buffer: Dictionary,restore_authority: bool) -> void:
	if bool(buffer.released):return
	buffer.released=true
	# Both callbacks bind this Dictionary: erase both before any actor signal.
	buffer.erase("cleanup");buffer.erase("abandon")
	if restore_authority:buffer.actor_owner.apply_source_state("hidden",false)
	# This exact clone remains ours only while parented to its captured owner.
	if is_instance_valid(buffer.node) and buffer.node.get_parent()==buffer.owner:buffer.node.queue_free()
	if is_instance_valid(buffer.owner) and is_same(buffer.owner.get_meta(str(buffer.key),{}),buffer):buffer.owner.remove_meta(str(buffer.key))

static func _sky_advance(track: Dictionary) -> void:
	if int(track.state)==0:track.counter=int(track.settings.source_args[0]);track.state=1
	elif int(track.state)==1:
		track.counter-=1
		if int(track.counter)==-1:track.state=2
	else:track.x_fraction+=1280
	track.y_fraction+=2816
	track.scroll+=Vector2((int(track.x_fraction)>>8)*(1 if track.actor_owner.side==0 else -1),int(track.y_fraction)>>8)
	track.x_fraction=int(track.x_fraction)&255;track.y_fraction=int(track.y_fraction)&255
	var background: Sprite2D=track.owner._source_background
	if is_instance_valid(background):
		if track.background==null:
			track.background=background;track.base_region=background.region_rect;track.expected_region=background.region_rect
		if background==track.background and background.region_rect==track.expected_region:
			var rect: Rect2=track.base_region;rect.position+=track.scroll;background.region_rect=rect;track.expected_region=rect
	if int(track.owner._source_args.get(7,0))==65535:
		_sky_cleanup(track);track.scroll=Vector2.ZERO;track.ticks=int(track.age)

static func _sky_cleanup(track: Dictionary) -> void:
	if is_instance_valid(track.background) and track.background.region_rect==track.expected_region:track.background.region_rect=track.base_region
	track.erase("cleanup")

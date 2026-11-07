extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## General17 source-bound roles, victim sway, and distinct run-past versus partner motion.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
const Data=preload("res://scripts/battle/animations/sequence/source_snatch_data.gd")
const Same=preload("res://scripts/battle/animations/sequence/source_cutting_slice.gd")
const Owned=preload("res://scripts/battle/animations/sequence/source_owned_composition.gd")
const Pixels=preload("res://scripts/battle/animations/sequence/transform_pixel_receipt.gd")
const STATE="i167_snatch_session"
static var _calls: Dictionary={}

class Call extends RefCounted:
	var incoming: Dictionary
	var context: BattleAnimationContext
	var definition: BattleAnimationDefinition
	var pc: int
	var claimed: bool=false

class Session extends RefCounted:
	var owner: Node2D
	var context: BattleAnimationContext
	var definition: BattleAnimationDefinition
	var program: Array
	var attacker: int
	var targets: Array
	var contest: bool
	var valid: bool=true
	var bindings: Dictionary={}
	var tracks: Array=[]
	var items: Array=[]
	var proxy: Dictionary={}
	var channels: Dictionary={}
	var lost_offsets: Dictionary={}
	var foreign_offsets: Dictionary={}
	var foreign_palettes: Dictionary={}
	var swap_hidden: bool=false
	var underlying_recipe: Dictionary={}
	var underlying_active: bool=false

static func matches(owner: Node2D) -> bool:
	return owner is BattleAnimationSequenceRunner and owner.definition!=null and is_same(owner.definition,BattleAnimationSequenceRegistry._builtin_source_definitions.get("ruby:general/17"))

static func _whole(owner: Node2D) -> bool:
	return matches(owner) and owner.definition.key==Data.PROGRAM.key and owner.definition.coverage==Data.PROGRAM.coverage and owner.definition.source_script==Data.PROGRAM.source_script and Same._same(owner.definition.steps,Data.PROGRAM.steps) and Same._same(owner._steps,Data.PROGRAM.steps)

static func open_dispatch(owner: Node2D,s: Dictionary) -> Call:
	if not matches(owner) or _calls.has(owner.get_instance_id()):return null
	var call:=Call.new();call.incoming=s;call.context=owner.context;call.definition=owner.definition;call.pc=owner._pc
	_calls[owner.get_instance_id()]=call;return call

static func close_dispatch(owner: Node2D,call: Call) -> void:
	if call!=null and is_same(_calls.get(owner.get_instance_id()),call):_calls.erase(owner.get_instance_id())

static func _group(owner: Node2D) -> Session:
	return owner.get_meta(STATE) as Session if owner.has_meta(STATE) else null

static func _valid(g: Session) -> bool:
	if not g.valid:return false
	if not is_same(g.owner.definition,g.definition) or not is_same(g.owner.context,g.context) or not _whole(g.owner) or not Same._same(g.program,g.owner._steps) or g.context.attacker_id!=g.attacker or not Same._same(g.context.target_ids,g.targets) or g.context.contest!=g.contest:g.valid=false
	return g.valid

static func _capture(actor: BattleAnimationActor,c: BattleAnimationContext) -> Dictionary:
	var frame: Array=[]
	for key: String in ["centered","offset","hframes","vframes","frame","region_enabled","region_rect","flip_h","flip_v"]:frame.append(actor.sprite.get(key))
	return {"actor":actor,"sprite":actor.sprite,"parent":actor.sprite.get_parent(),"texture":actor.sprite.texture,"generation":actor._generation,"slot":actor.slot,"side":actor.side,"frame":frame,"source_position":c.source_position(actor.id),"explicit_position":c.source_positions.has(actor.id),"lost":false,"field_origin":c.field.to_local(actor.sprite.global_position),"field_basis":c.field.global_transform.affine_inverse()*actor.sprite.global_transform}

static func _bound(b: Dictionary,c: BattleAnimationContext) -> bool:
	if b.is_empty() or b.lost:return false
	var occupant: Variant=c.actors.get(b.actor.id)
	if not occupant is BattleAnimationActor:
		b.lost=true;Pixels.revoke(b.sprite);return false
	if occupant!=b.actor or b.actor.sprite!=b.sprite or not b.actor.is_present() or b.sprite.get_parent()!=b.parent or b.sprite.texture!=b.texture or b.actor._generation!=b.generation or b.actor.slot!=b.slot or b.actor.side!=b.side or c.source_positions.has(b.actor.id)!=b.explicit_position or c.source_position(b.actor.id)!=b.source_position:b.lost=true;Pixels.revoke(b.sprite);return false
	var frame: Array=[]
	for key: String in ["centered","offset","hframes","vframes","frame","region_enabled","region_rect","flip_h","flip_v"]:frame.append(b.sprite.get(key))
	if frame!=b.frame:b.lost=true;Pixels.revoke(b.sprite);return false
	return true

static func _session(owner: Node2D,c: BattleAnimationContext) -> Session:
	var g: Session=_group(owner)
	if g!=null:return g
	g=Session.new();g.owner=owner;g.context=c;g.definition=owner.definition;g.program=owner._steps.duplicate(true);g.attacker=c.attacker_id;g.targets=c.target_ids.duplicate();g.contest=c.contest
	for candidate: Variant in c.actors.values():
		if not candidate is BattleAnimationActor:g.valid=false;continue
		var actor: BattleAnimationActor=candidate
		if actor.is_present():g.bindings[actor.id]=_capture(actor,c)
	owner.set_meta(STATE,g);return g

static func _admit(owner: Node2D,c: BattleAnimationContext,s: Dictionary,kind: String) -> bool:
	var call: Call=_calls.get(owner.get_instance_id()) as Call
	if call==null or call.claimed or not owner._i159_dispatch_live or not is_same(call.incoming,s) or not is_same(call.context,c) or not is_same(owner.context,c) or not is_same(call.definition,owner.definition) or call.pc!=owner._pc or not _whole(owner):return false
	if call.pc<=0 or call.pc>=Data.PROGRAM.steps.size():return false
	var canonical: Dictionary=Data.PROGRAM.steps[call.pc]
	if canonical.get("op")!="effect" or canonical.get("behavior")!=kind:return false
	var original: Dictionary=s.duplicate(true)
	if not canonical.has("source_command_priority"):
		var priority: Dictionary=BattleSourcePriority.command_metadata(Data.PROGRAM.steps[call.pc-1])
		if not priority.is_empty():
			if not Same._same(original.get("source_command_priority"),priority):return false
			original.erase("source_command_priority")
		elif original.has("source_command_priority"):return false
	if not Same._same(original,canonical) or not owner.claim_effect_dispatch(s):return false
	call.claimed=true;return true

static func effect(s: Dictionary,c: BattleAnimationContext,owner: Node2D,kind: String) -> Variant:
	var captured: Session=_group(owner)
	if captured!=null and (not is_same(c,captured.context) or not is_same(owner.definition,captured.definition) or not _valid(captured)):return []
	if not matches(owner):return null
	if not _admit(owner,c,s,kind):return []
	var g: Session=_session(owner,c)
	if kind=="source_snatch_roles":
		var next_actor: Variant=c.get_meta("source_snatcher_id",c.attacker_id);var next_target: Variant=c.get_meta("source_snatch_original_id",c.target_ids[0] if not c.target_ids.is_empty() else -1)
		for id: Variant in [next_actor,next_target]:
			if typeof(id) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(id)) or float(id)!=floorf(float(id)) or not c.actors.has(int(id)):g.valid=false;return []
		c.attacker_id=int(next_actor);c.target_ids.assign([int(next_target)]);g.attacker=c.attacker_id;g.targets=c.target_ids.duplicate();return []
	var a: Dictionary=g.bindings.get(g.attacker,{});var b: Dictionary=g.bindings.get(g.targets[0] if not g.targets.is_empty() else -1,{})
	if not _bound(a,c) or not _bound(b,c):return []
	if kind=="source_snatch_side":owner._source_args[7]=1 if a.actor.side==b.actor.side else 0;return []
	if kind=="source_snatch_substitute":owner._source_args[7]=1 if str(a.sprite.get_meta("source_presentation_state",{}).get("kind",""))=="substitute" else 0;return []
	if kind=="source_identity_transition":return _swap_create(s,c,owner,g,a)
	var sway: bool=kind=="source_snatch_sway";var moving: Dictionary=b if sway else a
	var t: Dictionary={"kind":"source_snatch_actor","actor":moving.actor,"original_actor":a.actor,"original_target":b.actor,"settings":s.duplicate(true),"owner":owner,"age":0,"ticks":int(s.ticks),"offset":Vector2.ZERO,"phase":0,"counter":0,"node":null,"update":finite_advance,"moving_binding":moving,"source_actor":a,"source_target":b,"origin":a.field_origin,"destination":b.field_origin,"direction":1 if a.actor.side==0 else -1,"partner":kind=="source_snatch_partner","sway":sway,"retired":false}
	t.cleanup=_finite_cleanup.bind(t);g.tracks.append(t)
	if not sway:
		_finite_motion(t,c,g);_birth_pose(t,g)
	return [t]

static func _field_vector(b: Dictionary,c: BattleAnimationContext,v: Vector2) -> Vector2:
	return b.parent.global_transform.affine_inverse().basis_xform(c.field.global_transform.basis_xform(v))

static func _birth_pose(t: Dictionary,g: Session) -> void:
	var actor: BattleAnimationActor=t.actor
	if not _bound(t.moving_binding,g.context):return
	actor.apply(g.owner._held_offsets.get(actor.id,Vector2.ZERO)+g.owner._held_approach_corrections.get(actor.id,Vector2.ZERO)+_field_vector(t.moving_binding,g.context,t.offset),Color.WHITE)

static func actor_offset(t: Dictionary,c: BattleAnimationContext) -> Vector2:
	BattleEffectBehaviorRegistry.update_track(t,c)
	var g: Session=_group(t.owner)
	return _field_vector(t.moving_binding,c,t.offset) if g!=null and g.tracks.any(func(actual):return is_same(actual,t)) and _valid(g) and _bound(t.moving_binding,c) and not g.lost_offsets.has(t.actor.id) else Vector2.ZERO

static func resolve_offset(owner: Node2D,actor: BattleAnimationActor,offset: Vector2) -> Vector2:
	var g: Session=_group(owner)
	return offset if g!=null and _valid(g) and not g.lost_offsets.has(actor.id) and _bound(g.bindings.get(actor.id,{}),g.context) else Vector2.ZERO

static func note_held_write(owner: Node2D,t: Dictionary,value: Vector2) -> void:
	var g: Session=_group(owner)
	if g==null or not t.has("actor") or not is_same(owner._i159_actor_callback_track,t) or not owner._tracks.any(func(actual):return is_same(actual,t)):return
	if g.bindings.has(t.actor.id) and _bound(g.bindings[t.actor.id],g.context) and g.bindings[t.actor.id].actor==t.actor and not g.tracks.any(func(actual):return is_same(actual,t)):
		g.lost_offsets[t.actor.id]=true
		g.foreign_offsets[t.actor.id]={"value":value}

static func note_palette_write(owner: Node2D,t: Dictionary,receipt: Dictionary) -> void:
	var g: Session=_group(owner)
	if g==null or not t.has("actor") or not is_same(owner._i159_actor_callback_track,t) or not owner._tracks.any(func(actual):return is_same(actual,t)):return
	if g.bindings.has(t.actor.id) and g.bindings[t.actor.id].actor==t.actor and _bound(g.bindings[t.actor.id],g.context):
		# Keep the genuine published dictionary identity, not merely equal values.
		g.foreign_palettes[t.actor.id]={"receipt":receipt,"material":null,"lost":false}

static func observe_palette_application(owner: Node2D) -> void:
	var g: Session=_group(owner)
	if g==null:return
	for id: int in g.foreign_palettes:
		var lease: Dictionary=g.foreign_palettes[id];var b: Dictionary=g.bindings[id]
		if lease.lost:continue
		if not _bound(b,g.context) or not is_same(g.owner._held_blends.get(id),lease.receipt):lease.lost=true;continue
		var material: ShaderMaterial=b.actor._blend_material
		if lease.material==null:
			if material!=null and b.sprite.material==material and material.get_shader_parameter("blend_color")==lease.receipt.color and material.get_shader_parameter("blend_amount")==lease.receipt.amount:lease.material=weakref(material)
		elif lease.material.get_ref()!=b.sprite.material:lease.lost=true

static func _cleanup_bound(b: Dictionary,g: Session) -> bool:
	if not _bound(b,g.context):return false
	# The old map cannot disprove a new wrapper owning this Sprite in the live map.
	# Different IDs still alias the same visual; different Sprites do not block cleanup.
	for candidate: Variant in g.owner.context.actors.values():
		if not candidate is BattleAnimationActor:
			b.lost=true
			return false
		var current: BattleAnimationActor=candidate
		if current!=b.actor and current.sprite==b.sprite:
			b.lost=true
			return false
	return true

static func terminal_actor_shape_allowed(owner: Node2D,candidate: Variant) -> bool:
	# Only this finite session owns the conservative malformed-map policy.
	return _group(owner)==null or candidate is BattleAnimationActor

static func release_actor(owner: Node2D,actor: Variant) -> bool:
	var g: Session=_group(owner)
	if g==null:return false
	if not actor is BattleAnimationActor:return true
	if not g.bindings.has(actor.id):return false
	var b: Dictionary=g.bindings[actor.id]
	# A successor under the same ID is not this execution's visual occupant.
	if b.actor!=actor or not _cleanup_bound(b,g):return true
	var held: Dictionary=g.foreign_offsets.get(actor.id,{})
	var keep_offset: bool=not held.is_empty() and owner._held_offsets.get(actor.id)==held.value and b.sprite.position==actor._expected_position
	var palette: Dictionary=g.foreign_palettes.get(actor.id,{})
	var keep_material: bool=not palette.is_empty() and not palette.lost and palette.material is WeakRef and is_same(owner._held_blends.get(actor.id),palette.receipt) and palette.material.get_ref()==b.sprite.material
	var material: Material=b.sprite.material if keep_material else null
	# Release every ordinary channel, then retain only proven winning fields.
	actor.release()
	if keep_offset:actor.add_layout_offset(held.value)
	if keep_material:b.sprite.material=material
	return true

static func actor_allowed(owner: Node2D,actor: BattleAnimationActor) -> bool:
	var g: Session=_group(owner)
	return g==null or not g.bindings.has(actor.id) or _bound(g.bindings[actor.id],g.context)

static func before_track(owner: Node2D,t: Dictionary) -> bool:
	var g: Session=_group(owner)
	if g==null:return true
	var owned: bool=g.tracks.any(func(actual):return is_same(actual,t))
	if not owned:return true
	# This boundary runs BEFORE the runner's actor.is_present guard. A vanished
	# original cannot strand a visible clone behind a4096tick barrier.
	var valid: bool=_valid(g)
	for b: Dictionary in g.bindings.values():_bound(b,g.context)
	for finite: Dictionary in g.tracks:
		if not valid or not _bound(finite.source_actor,g.context) or not _bound(finite.source_target,g.context):
			finite.offset=Vector2.ZERO;finite.ticks=int(finite.age);_retire_track(finite,g.context);finite.erase("cleanup");owner._tracks.erase(finite)
	if not g.proxy.is_empty() and (not valid or not _bound(g.proxy.binding,g.context)):_retire_item(g.proxy)
	return owner._tracks.any(func(actual):return is_same(actual,t))

static func finite_advance(t: Dictionary,c: BattleAnimationContext) -> void:
	var g: Session=_group(t.owner)
	if g==null or not _valid(g) or not _bound(t.source_actor,c) or not _bound(t.source_target,c):
		t.offset=Vector2.ZERO;t.ticks=int(t.age);_retire_track(t,c);return
	if not g.tracks.any(func(actual):return is_same(actual,t)) or not is_same(t.owner._i159_actor_callback_track,t) or not t.owner._tracks.any(func(actual):return is_same(actual,t)):return
	if t.actor.sprite.position!=t.actor._expected_position:g.lost_offsets[t.actor.id]=true
	if t.sway:
		t.offset=Vector2(BattleSourceTrig.sine((int(t.age)*20)&255,5 if t.original_actor.side==0 else -5),0) if int(t.age)<26 else Vector2.ZERO
	else:_finite_motion(t,c,g)

static func _finite_motion(t: Dictionary,c: BattleAnimationContext,g: Session) -> void:
	if t.partner:
		match int(t.phase):
			0:t.velocity=-6 if t.origin.x>t.destination.x else 6;t.phase=1
			1:
				t.offset.x+=int(t.velocity)
				if (t.origin.x+t.offset.x-t.destination.x)*int(t.velocity)>=0:t.phase=2
			2:t.velocity=-int(t.velocity);t.phase=3
			3:
				t.offset.x+=int(t.velocity)
				if t.offset.x*int(t.velocity)>=0:t.phase=4
			4:t.offset=Vector2.ZERO;t.ticks=int(t.age)
		return
	match int(t.phase):
		0:
			t.offset.x+=8*int(t.direction)
			if ((int(t.origin.x+t.offset.x)+32)&65535)>304:t.phase=1
		1:
			# Only this registered controller's genuine scheduled phase1 callback can allocate.
			if not is_same(t.owner._i159_actor_callback_track,t) or not t.owner._tracks.any(func(actual):return is_same(actual,t)):return
			t.item=_new_visual(g,t.source_actor,g.underlying_recipe if g.underlying_active else {});t.node=t.item.node;t.clone_x=-32 if c.contest or int(t.direction)==-1 else 272
			t.clone_y=c.field.to_local(t.source_target.sprite.global_position).y;t.phase=2
			t.item.base.origin=Vector2(int(t.clone_x),t.clone_y)
			_select_runpast(t,c)
		2:
			t.clone_x=int(t.clone_x)-8*int(t.direction)
			var victim_x: float=c.field.to_local(t.source_target.sprite.global_position).x
			if int(t.counter)==0 and (int(t.clone_x)-victim_x)*int(t.direction)<0:t.counter=1;t.owner._source_args[7]=65535
			if ((int(t.clone_x)+32)&65535)>304:t.phase=3
		3:
			_retire_item(t.item);t.node=null;t.offset.x=(-32-t.origin.x) if int(t.direction)==1 else (272-t.origin.x);t.phase=4
		4:
			t.offset.x+=8*int(t.direction)
			if t.offset.x*int(t.direction)>=0:t.offset=Vector2.ZERO;t.ticks=int(t.age)
	if t.has("item") and not t.item.retired:
		t.item.base.origin=Vector2(int(t.clone_x),t.clone_y);_project(t.item,g)

static func _new_visual(g: Session,b: Dictionary,recipe: Dictionary={}) -> Dictionary:
	var node:=Sprite2D.new();g.owner.add_child(node)
	var item: Dictionary={"node":node,"parent":g.owner,"binding":b,"base":b.field_basis,"writes":{},"lost":{},"retired":false}
	for key: String in Owned.FOLLOW:Owned.write(item,key,recipe.get(key,b.sprite.get(key)))
	Owned.write(item,"visible",true);g.items.append(item);return item

static func _project(item: Dictionary,g: Session) -> void:
	if item.retired:return
	if not _valid(g) or not _bound(item.binding,g.context):_retire_item(item);return
	Owned.write(item,"transform",g.owner.global_transform.affine_inverse()*g.context.field.global_transform*item.base)

static func _white6(texture: Texture2D) -> Texture2D:
	var source: Image=texture.get_image()
	if source==null:return texture
	var image: Image=source.duplicate()
	image.convert(Image.FORMAT_RGBA8)
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color: Color=image.get_pixel(x,y)
			if color.a8==0:continue
			image.set_pixel(x,y,Color8((color.r8*10+1530)/16,(color.g8*10+1530)/16,(color.b8*10+1530)/16,color.a8))
	return ImageTexture.create_from_image(image)

static func _select_runpast(t: Dictionary,c: BattleAnimationContext) -> void:
	var b: Dictionary=t.source_actor;var item: Dictionary=t.item
	var g: Session=_group(t.owner)
	var view: String="front" if c.contest or int(t.direction)==1 else "back"
	var selected: Variant=c.source_appearance_views.get(b.actor.id,{}).get(view)
	var texture: Texture2D=selected if selected is Texture2D else g.underlying_recipe.get("texture",b.texture) if g.underlying_active else b.texture
	var region: Rect2=item.node.region_rect if item.node.region_enabled else Rect2(Vector2.ZERO,texture.get_size())
	if texture.get_width()<=0 or texture.get_height()<=0 or not Rect2(Vector2.ZERO,texture.get_size()).encloses(region):texture=g.underlying_recipe.get("texture",b.texture) if g.underlying_active else b.texture;selected=null
	# ASM tests the snatcher's Transform, not the victim. Proven prewhite input is
	# reused once; unknown fallback stays literal instead of guessed unwhitening.
	var provenance: Dictionary=Pixels.presentation(b.actor,c)
	if not provenance.is_empty() and texture!=provenance.texture and selected is Texture2D and not texture.has_meta(Pixels.KEY):texture=_white6(texture)
	Owned.write(item,"texture",texture)
	if c.contest:
		var mirrored: Transform2D=item.base;mirrored.x=-mirrored.x;item.base=mirrored
	Owned.write(item,"z_index",BattleSourcePriority.actor_layer(b.actor,t.owner) if c.contest else BattleSourcePriority.relative_layer(t.original_target,-1 if int(t.direction)==1 else 1,c,t.owner))
	t.source_oam_priority=2;t.source_oam_subpriority=BattleElectricContract.source_subpriority(b.actor if c.contest else t.original_target,c)+(0 if c.contest else (1 if int(t.direction)==1 else -1))
	_project(item,_group(t.owner))

static func _retire_item(item: Dictionary) -> void:
	if item.is_empty() or item.retired:return
	Owned.write(item,"visible",false)
	if Owned.node(item):item.node.queue_free()
	item.retired=true

static func _retire_track(t: Dictionary,c: BattleAnimationContext) -> void:
	if t.get("retired",false):return
	if t.has("item"):_retire_item(t.item)
	t.retired=true

static func _finite_cleanup(t: Dictionary) -> void:
	t.erase("cleanup");_retire_track(t,t.owner.context)

static func _swap_create(s: Dictionary,c: BattleAnimationContext,owner: Node2D,g: Session,b: Dictionary) -> Array[Dictionary]:
	var state: Dictionary=b.sprite.get_meta("source_presentation_state",{})
	if state.get("kind")!="substitute" or not state.get("previous") is Dictionary:return []
	if g.proxy.is_empty():
		g.proxy=_new_visual(g,b);Owned.write(g.proxy,"z_index",BattleSourcePriority.actor_layer(b.actor,owner))
		b.actor.apply_source_state("hidden",true);g.swap_hidden=true
		_project(g.proxy,g)
	var t: Dictionary={"kind":"source_snatch_swap","owner":owner,"settings":s.duplicate(true),"age":0,"ticks":int(s.ticks),"source_actor":b,"source_target":b,"phase":0,"swap_offset":0,"update":swap_advance,"retired":false}
	g.tracks.append(t);return [t]

static func swap_advance(t: Dictionary,c: BattleAnimationContext) -> void:
	var g: Session=_group(t.owner)
	if g==null or not _valid(g) or not _bound(t.source_actor,c):t.ticks=int(t.age);return
	if not g.tracks.any(func(actual):return is_same(actual,t)) or not is_same(t.owner._i161_control_callback_track,t) or not t.owner._tracks.any(func(actual):return is_same(actual,t)):return
	var direction: int=-1 if t.source_actor.actor.side==0 else 1
	match int(t.phase):
		0:
			t.swap_offset+=5*direction
			if ((int(t.source_actor.field_origin.x)+int(t.swap_offset)+32)&0xffffffff)>304:t.phase=1
		1:
			var state: Dictionary=t.source_actor.sprite.get_meta("source_presentation_state",{})
			var chosen: Dictionary=state.get("previous",{}) if int(t.settings.source_args[0])==1 else state
			if chosen.get("texture") is Texture2D:
				var frame_values: Variant=chosen if int(t.settings.source_args[0])==1 else chosen.get("frame_properties",{})
				if not frame_values is Dictionary:t.ticks=int(t.age);return
				g.underlying_recipe={}
				for key: String in Owned.FOLLOW:g.underlying_recipe[key]=t.source_actor.sprite.get(key)
				g.underlying_recipe.texture=chosen.texture
				Owned.write(g.proxy,"texture",chosen.texture)
				for key: String in ["hframes","vframes","frame","region_enabled","region_rect","flip_h","flip_v"]:
					var value: Variant=frame_values.get(key,1 if key in ["hframes","vframes"] else 0 if key=="frame" else false if key in ["region_enabled","flip_h","flip_v"] else Rect2())
					g.underlying_recipe[key]=value;Owned.write(g.proxy,key,value)
				g.underlying_active=int(t.settings.source_args[0])==1
			t.phase=2
		2:
			t.swap_offset-=5*direction
			if int(t.swap_offset)*direction<=0:t.swap_offset=0;t.ticks=int(t.age)
	g.proxy.base=t.source_actor.field_basis;g.proxy.base.origin=t.source_actor.field_origin+Vector2(int(t.swap_offset),0);_project(g.proxy,g)

static func after_pose(owner: Node2D,c: BattleAnimationContext) -> void:
	var g: Session=_group(owner)
	if g==null:return
	if not g.proxy.is_empty() and not g.proxy.retired:
		var active_swap: bool=owner._tracks.any(func(t):return t.kind=="source_snatch_swap")
		if not active_swap:
			var b: Dictionary=g.proxy.binding
			if _bound(b,c):g.proxy.base=c.field.global_transform.affine_inverse()*b.sprite.global_transform
			_project(g.proxy,g)

static func terminal(owner: Node2D) -> Array:
	var g: Session=_group(owner);var invalid: Array=[]
	if g==null:return invalid
	for b: Dictionary in g.bindings.values():
		if not _cleanup_bound(b,g):invalid.append(b.actor)
	for item: Dictionary in g.items:_retire_item(item)
	if g.swap_hidden:
		var b: Dictionary=g.bindings.get(g.attacker,{})
		if _cleanup_bound(b,g):b.actor.apply_source_state("hidden",false)
	return invalid

static func release_missing_actors(owner: Node2D) -> void:
	var g: Session=_group(owner)
	if g==null:return
	# finish() may have entered before before_track because live context lost its field.
	# Run after track cleanup; release authority remains on captured originals only.
	for b: Dictionary in g.bindings.values():
		var current: Variant=owner.context.actors.get(b.actor.id)
		if not current is BattleAnimationActor:
			# Empty map may release; a malformed entry is rejected by _cleanup_bound.
			release_actor(owner,b.actor)
			continue
		if current!=b.actor:release_actor(owner,b.actor)

static func release(owner: Node2D) -> void:
	var g: Session=_group(owner)
	if g==null:return
	for t: Dictionary in g.tracks:t.erase("cleanup")
	g.tracks=[];g.items=[];g.bindings={};g.proxy={};g.channels={};g.owner=null;g.context=null;g.definition=null
	g.underlying_recipe={};g.foreign_offsets={};g.foreign_palettes={}
	owner.remove_meta(STATE)

static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var actor: BattleAnimationActor=c.resolve("attacker")[0];var target: BattleAnimationActor=c.resolve("target")[0]
	match str(s.behavior):
		"source_snatch_roles":
			c.attacker_id=int(c.get_meta("source_snatcher_id",c.attacker_id));c.target_ids.assign([int(c.get_meta("source_snatch_original_id",c.target_ids[0]))]);return []
		"source_snatch_side":owner._source_args[7]=1 if actor.side==target.side else 0;return []
		"source_snatch_substitute":owner._source_args[7]=1 if str(actor.sprite.get_meta("source_presentation_state",{}).get("kind",""))=="substitute" else 0;return []
	var sway: bool=str(s.behavior)=="source_snatch_sway"
	var t: Dictionary={"kind":"source_snatch_sway" if sway else "source_snatch_motion","settings":s,"owner":owner,"original_actor":actor,"original_target":target,"age":0,"ticks":int(s.ticks),"offset":Vector2.ZERO,"phase":0,"counter":0,"node":null,"update":advance}
	t.moving=target if sway else actor;t.origin=Geometry._anchor(actor,c,owner,"origin");t.destination=Geometry._anchor(target,c,owner,"origin");t.direction=1 if actor.side==0 else -1;t.partner=str(s.behavior)=="source_snatch_partner";t.cleanup=_cleanup.bind(t)
	if not sway:_motion(t,c) # ScriptCmd_createvisualtask calls task synchronously.
	return [t]
static func _pose(t: Dictionary) -> void:
	t.owner._held_offsets[t.moving.id]=t.offset;t.moving.apply(t.offset,Color.WHITE)
static func _cleanup(t: Dictionary) -> void:
	if t.owner._held_offsets.get(t.moving.id,Vector2.ZERO)==t.offset:t.owner._held_offsets[t.moving.id]=Vector2.ZERO
	if is_instance_valid(t.node):t.node.queue_free()
	t.erase("cleanup")
static func _motion(t: Dictionary,c: BattleAnimationContext) -> void:
	if t.partner:
		match int(t.phase):
			0:t.velocity=6 if t.origin.x<t.destination.x else -6;t.phase=1
			1:
				t.offset.x+=int(t.velocity)
				if (t.origin.x+t.offset.x-t.destination.x)*int(t.velocity)>=0:t.phase=2
			2:t.velocity=-int(t.velocity);t.phase=3
			3:
				t.offset.x+=int(t.velocity)
				if t.offset.x*int(t.velocity)>=0:t.phase=4
			4:t.offset=Vector2.ZERO;t.ticks=int(t.age)
		_pose(t);return
	match int(t.phase):
		0:
			t.offset.x+=8*int(t.direction)
			if ((int(t.origin.x+t.offset.x)+32)&65535)>304:t.phase=1
		1:
			var node:=Sprite2D.new();var view: String="front" if int(t.direction)==1 else "back";var views: Dictionary=c.source_appearance_views.get(t.original_actor.id,{})
			node.texture=views.get(view,t.original_actor.sprite.texture);node.centered=true;t.owner.add_child(node);t.node=node;t.clone_x=272 if int(t.direction)==1 else -32
			node.position=Vector2(int(t.clone_x),t.destination.y);node.z_index=BattleSourcePriority.relative_layer(t.original_target,-1 if int(t.direction)==1 else 1,c,t.owner);t.phase=2
		2:
			t.clone_x=int(t.clone_x)-8*int(t.direction);t.node.position=Vector2(int(t.clone_x),t.destination.y)
			if int(t.counter)==0 and (int(t.clone_x)-t.destination.x)*int(t.direction)<0:t.counter=1;t.owner._source_args[7]=65535
			if ((int(t.clone_x)+32)&65535)>304:t.phase=3
		3:
			t.node.queue_free();t.node=null;t.offset.x=(-32-t.origin.x) if int(t.direction)==1 else (272-t.origin.x);t.phase=4
		4:
			t.offset.x+=8*int(t.direction)
			if t.offset.x*int(t.direction)>=0:t.offset=Vector2.ZERO;t.ticks=int(t.age)
	_pose(t)
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if not t.original_actor.is_present() or not t.original_target.is_present():t.ticks=int(t.age);return
	if t.kind=="source_snatch_sway":
		t.offset=Vector2(BattleSourceTrig.sine((int(t.age)*20)&255,5 if t.original_actor.side==0 else -5),0) if int(t.age)<int(t.ticks) else Vector2.ZERO;_pose(t);return
	_motion(t,c)

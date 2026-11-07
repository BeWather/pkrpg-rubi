extends Node2D
class_name BattleAnimationSequenceRunner
## One owner per battlefield, concurrent finite tracks within the execution.
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

signal marker_reached(record: Dictionary)
var lifecycle_aborted := false
signal terminated(state: String)

const MetallicPreparation=preload("res://scripts/battle/animations/sequence/source_metallic_preparation.gd")
const TICK_SECONDS := 1.0 / 60.0
const MAX_CATCH_UP_TICKS: int=16
const CATCH_UP_BUDGET_USEC: int=8000
var context: BattleAnimationContext
var definition: BattleAnimationDefinition
var state := "running"
var markers: Array[Dictionary] = []
var speed := 1.0
var paused := false
var elapsed_ticks := 0
var error_message := ""
var _steps: Array[Dictionary] = []
var _tracks: Array[Dictionary] = []
var _provisional_cleanups: Array[Dictionary] = []
var _appearance_leases: Array[BattleOwnedAppearanceLease] = []
var _sounds: Array[AudioStreamPlayer2D] = []
var _factories: Dictionary
var _source_spinning_invocation: RefCounted
var _effect_dispatch_step: Dictionary = {}
var _effect_dispatch_pc := -1
var _i159_dispatch_live: bool=false
var _i159_actor_callback_track: Dictionary={}
var _i159_actor_apply_actor: BattleAnimationActor
var _i159_palette_callback_track: Dictionary={}
var _pc := 0
var _wait := 0
var _accumulator := 0.0
var _audio_ticks := 0
var _held_offsets: Dictionary = {}
var sound_events: Array[Dictionary] = []
var sound_pan_events: Array[Dictionary] = []
var _held_blends: Dictionary = {}
var _background_blend: Polygon2D
var _source_args := {}
var _source_returns: Array[int] = []
var _held_rotations := {}
var _held_approach_corrections: Dictionary = {}
var _source_blackout: Polygon2D
var _source_background: Sprite2D
var _i161_control_callback_track: Dictionary={}
var _sound_barrier_ticks := 0
var _source_phase_started := 0
var _source_phase_duration := 0
var _source_palette_banks := {}
var _i171_palette_callback: Dictionary={}
var _i171_post_pose: bool=false
var source_bank_events: Array[Dictionary] = []
var _pending_sprite_priority: Dictionary = {}

func _source_palette(track: Dictionary) -> void:
	BattleEffectBehaviorRegistry.LegacyImpact.Frenzy.before_scene_palette(self,track)
	BattleEffectBehaviorRegistry.LegacyImpact.Stockpile.before_palette_writer(self,track)
	BattleEffectBehaviorRegistry.LegacyImpact.Solar.before_palette_writer(self,track)
	if not BattleEffectBehaviorRegistry.LegacyImpact.Spinning.palette_callback_allowed(self,context,track):return
	var settings: Dictionary = track.settings
	var coefficient := 0
	var color := Color.BLACK
	if settings.has("palette_states"):
		var remaining := maxi(0,int(track.age)-1)
		for pose in settings.palette_states:
			color = Color(str(pose.color))
			coefficient = int(pose.amount)
			if remaining < int(pose.ticks): break
			remaining -= int(pose.ticks)
	elif settings.has("blend_segments"):
		var remaining := maxi(0,int(track.age)-1)
		for segment in settings.blend_segments:
			var phase := mini(remaining,int(segment.ticks)-1)/maxi(1,int(segment.delay))
			coefficient = int(segment.start)+signi(int(segment.end)-int(segment.start))*mini(absi(int(segment.end)-int(segment.start)),phase)
			color = Color(str(segment.color))
			if remaining < int(segment.ticks): break
			remaining -= int(segment.ticks)
	else:
		var start_value := int(settings.blend_start)
		var end_value := int(settings.blend_end)
		var phase := int(track.age) / maxi(1,int(settings.blend_delay))
		coefficient = start_value + signi(end_value-start_value)*mini(absi(end_value-start_value),phase)
		color = Color(str(settings.color))
	if track.has("actor"):
		_held_blends[track.actor.id] = {"color":color,"amount":coefficient/16.0}
		BattleEffectBehaviorRegistry.Snatch.note_palette_write(self,track,_held_blends[track.actor.id])
		BattleEffectBehaviorRegistry.LegacyImpact.AgilityAerial.note_palette_write(self,track,_held_blends[track.actor.id])
		BattleEffectBehaviorRegistry.LegacyImpact.CrossImpact.note_palette_write(self,track,_held_blends[track.actor.id])
		BattleEffectBehaviorRegistry.LegacyImpact.Spinning.note_palette_write(self,track,_held_blends[track.actor.id])
		BattleEffectBehaviorRegistry.LegacyImpact.Solar.after_palette_writer(self,track)
		BattleEffectBehaviorRegistry.LegacyImpact.Stockpile.after_palette_writer(self,track)
		BattleEffectBehaviorRegistry.LegacyImpact.Waterfall.after_palette_writer(self,track)
		BattleEffectBehaviorRegistry.LegacyImpact.Petal.after_palette_writer(self,track)
		BattleEffectBehaviorRegistry.LegacyImpact.Blizzard.after_palette_writer(self,track)
		BattleEffectBehaviorRegistry.LegacyImpact.Frenzy.after_palette_writer(self,track)
	else:
		if not is_instance_valid(_background_blend):
			_background_blend = Polygon2D.new()
			_background_blend.polygon = PackedVector2Array([Vector2.ZERO,Vector2(context.field_size.x,0),context.field_size,Vector2(0,context.field_size.y)])
			_background_blend.z_index = 0
			add_child(_background_blend)
		color.a = coefficient/16.0
		_background_blend.color = color

func get_actor_offset(actor_id: int) -> Vector2:
	return _held_offsets.get(actor_id, Vector2.ZERO)

func get_actor_approach_correction(actor_id: int) -> Vector2:
	# Read-only composition input; get_actor_offset remains held-only.
	return _held_approach_corrections.get(actor_id, Vector2.ZERO)

func start(data: BattleAnimationDefinition, visual_context: BattleAnimationContext) -> void:
	if has_meta("source_lovely_rng"):remove_meta("source_lovely_rng")
	if has_meta("source_startle_rng"):remove_meta("source_startle_rng")
	set_meta("source_tag_palette_states",{})
	definition = data
	context = visual_context
	_factories = BattleEffectBehaviorRegistry.factories()
	error_message = data.validation_error(_factories)
	if not error_message.is_empty():
		finish("failed")
		return
	_steps = data.steps.duplicate(true)

# Native construction owns cleanup before an external factory observer can
# cancel. Enrollment transfers that exact lease without running its callback.
func register_provisional_cleanup(track: Dictionary) -> bool:
	if state!="running" or track.get("owner")!=self or not track.get("cleanup") is Callable or not track.get("abandon") is Callable:return false
	for receipt: Dictionary in _provisional_cleanups:
		if is_same(receipt.track,track):return true
	_provisional_cleanups.append({"track":track,"context":context,"definition":definition,"program":_steps,"cleanup":track.cleanup,"abandon":track.abandon})
	return true

func _enroll_provisional_cleanup(track: Dictionary) -> void:
	for index: int in range(_provisional_cleanups.size()-1,-1,-1):
		if is_same(_provisional_cleanups[index].track,track):_provisional_cleanups.remove_at(index)

func _drain_provisional_cleanups() -> void:
	# Detach before invoking native code: reentrant finish cannot drain twice,
	# and any later execution's registrations must never be cleared here.
	var pending: Array[Dictionary]=_provisional_cleanups
	_provisional_cleanups=[]
	for receipt: Dictionary in pending:
		var restore_authority: bool=context==receipt.context and definition==receipt.definition and is_same(_steps,receipt.program)
		# Lost presentation authority still owns resource-only retirement. Use
		# captured native callbacks, never a mutable replacement on the track.
		if restore_authority:receipt.cleanup.call()
		else:receipt.abandon.call()

func _process(delta: float) -> void:
	for player in _sounds:
		if is_instance_valid(player) and BattleEffectBehaviorRegistry.LegacyImpact.Dizzy.audio_allowed(self,player) and BattleEffectBehaviorRegistry.LegacyImpact.Confuse.audio_allowed(self,player) and BattleEffectBehaviorRegistry.LegacyImpact.NightShade.audio_allowed(self,player):
			player.stream_paused = paused
			player.pitch_scale = clampf(speed, 0.1, 8.0) * float(player.get_meta("source_pitch",1.0))
			BattleEffectBehaviorRegistry.LegacyImpact.Dizzy.note_audio_write(self,player)
			BattleEffectBehaviorRegistry.LegacyImpact.Confuse.note_audio_write(self,player)
			BattleEffectBehaviorRegistry.LegacyImpact.NightShade.note_audio_write(self,player)
	if paused or state != "running":
		return
	# Discard excess wall-time debt, never logical source ticks. Otherwise one
	# expensive tick can create an ever-growing catch-up loop that freezes UI.
	_accumulator=minf(_accumulator+delta*clampf(speed,0.1,8.0),TICK_SECONDS*MAX_CATCH_UP_TICKS)
	var catch_up_ticks: int=0
	var catch_up_started: int=Time.get_ticks_usec()
	while _accumulator >= TICK_SECONDS and state == "running" and catch_up_ticks<MAX_CATCH_UP_TICKS:
		_accumulator -= TICK_SECONDS
		step_tick()
		catch_up_ticks+=1
		# A synchronous tick cannot be preempted. Yield before starting another
		# once this frame's catch-up budget is spent; manual step_tick is unchanged.
		if Time.get_ticks_usec()-catch_up_started>=CATCH_UP_BUDGET_USEC:break

## One synchronous claim, never authority from a parked PC or copied Dictionary.
func claim_effect_dispatch(step: Dictionary) -> bool:
	if state!="running" or _effect_dispatch_pc!=_pc or not is_same(_effect_dispatch_step,step):return false
	_effect_dispatch_step={};_effect_dispatch_pc=-1
	return true

func step_tick() -> void:
	_step_tick_impl()
	_i171_post_pose=true
	if state=="running":BattleEffectBehaviorRegistry.LegacyImpact.after_actor_pose(self,context)
	_i171_post_pose=false
	if state=="running":BattleEffectBehaviorRegistry.ChargeOwned.after_pose(self,context)
	if state=="running":BattleEffectBehaviorRegistry.Snatch.after_pose(self,context)
	if state=="running":BattleEffectBehaviorRegistry.LegacyImpact.Waterfall.after_pose(self,context)
	if state=="running":BattleEffectBehaviorRegistry.LegacyImpact.Blizzard.after_pose(self,context)

func _step_tick_impl() -> void:
	if state != "running":
		return
	if not BattleEffectBehaviorRegistry.LegacyImpact.NightShade.tick_allowed(self):return
	if BattleEffectBehaviorRegistry.LegacyImpact.NightShade.finish_context_loss(self):return
	if not BattleEffectBehaviorRegistry.LegacyImpact.Confuse.tick_allowed(self):return
	if BattleEffectBehaviorRegistry.LegacyImpact.Confuse.finish_context_loss(self):return
	if BattleEffectBehaviorRegistry.LegacyImpact.Dizzy.finish_context_loss(self):return
	if BattleEffectBehaviorRegistry.LegacyImpact.Crab.finish_context_loss(self):return
	if BattleEffectBehaviorRegistry.LegacyImpact.Hydro.finish_context_loss(self):return
	if BattleEffectBehaviorRegistry.LegacyImpact.Frenzy.finish_context_loss(self):return
	if BattleEffectBehaviorRegistry.LegacyImpact.Blizzard.finish_context_loss(self):return
	if not is_instance_valid(context.field) or not context.field.is_inside_tree():
		finish("cancelled")
		return
	BattleEffectBehaviorRegistry.LegacyImpact.NightShade.begin_tick(self,context)
	if state!="running":return
	BattleEffectBehaviorRegistry.LegacyImpact.Confuse.begin_tick(self,context)
	if state!="running":return
	BattleEffectBehaviorRegistry.LegacyImpact.Dizzy.begin_tick(self,context)
	BattleEffectBehaviorRegistry.LegacyImpact.Stinger.begin_tick(self,context)
	BattleEffectBehaviorRegistry.LegacyImpact.Wing.begin_tick(self,context)
	BattleEffectBehaviorRegistry.LegacyImpact.AgilityAerial.begin_tick(self,context)
	BattleEffectBehaviorRegistry.LegacyImpact.CrossImpact.begin_tick(self,context)
	BattleEffectBehaviorRegistry.LegacyImpact.MetallicTail.begin_tick(self,context)
	BattleEffectBehaviorRegistry.LegacyImpact.Secret.begin_tick(self,context)
	BattleEffectBehaviorRegistry.LegacyImpact.Musical.begin_tick(self,context)
	BattleEffectBehaviorRegistry.LegacyImpact.Swords.begin_tick(self,context)
	BattleEffectBehaviorRegistry.LegacyImpact.Spinning.begin_tick(self,context)
	BattleEffectBehaviorRegistry.LegacyImpact.Solar.begin_tick(self,context)
	BattleEffectBehaviorRegistry.LegacyImpact.Stockpile.begin_tick(self,context)
	BattleEffectBehaviorRegistry.LegacyImpact.Waterfall.begin_tick(self,context)
	BattleEffectBehaviorRegistry.LegacyImpact.Petal.begin_tick(self,context)
	BattleEffectBehaviorRegistry.LegacyImpact.Blizzard.begin_tick(self,context)
	elapsed_ticks += 1
	_update_tracks()
	if _wait > 0:
		_wait -= 1
		return
	var budget := 256
	while _pc < _steps.size() and budget > 0 and state == "running":
		budget -= 1
		var step := _steps[_pc]
		if MetallicPreparation.consume(step,self):
			_pc+=1
			continue
		match str(step.get("op", "")):
			"source_label":
				_pending_sprite_priority=BattleSourcePriority.command_metadata(step)
				for index in step.get("source_args",[]).size():_source_args[index] = int(step.source_args[index])&65535
			"source_arg_context":
				var blizzard_query_before: int=int(_source_args.get(int(step.index),0))
				match str(step.property):
					"environment":
						var environment: Variant=BattleEffectBehaviorRegistry.LegacyImpact.Secret.environment(self,context.environment)
						if environment==null:error_message="Invalid finite source environment";finish("failed");return
						_source_args[int(step.index)]=environment
					"contest":_source_args[int(step.index)]=1 if context.contest else 0
					"attacker_side":
						var blizzard_side: Variant=BattleEffectBehaviorRegistry.LegacyImpact.Blizzard.query_side(self)
						if blizzard_side==null:_source_args[int(step.index)]=context.actors[context.attacker_id].side
						elif int(blizzard_side)>=0:_source_args[int(step.index)]=int(blizzard_side)
						else:error_message="Invalid original Blizzard side";finish("failed");return
					"target_side":
						if bool(step.get("source_raw_side",false)):
							_source_args[int(step.index)]=context.resolve("target")[0].side if not context.resolve("target").is_empty() else 0
						else:_source_args[int(step.index)]=0 if not context.resolve("target").is_empty() and context.resolve("target")[0].side!=0 else 1
					"target_is_attacker_partner":
						var originals: Array[BattleAnimationActor]=context.resolve("attacker")
						var targets: Array[BattleAnimationActor]=context.resolve("target")
						if originals.is_empty() or targets.is_empty():
							error_message="Missing original source partner operands";finish("failed");return
						var source_attacker: int=context.source_position(originals[0].id)
						var source_target: int=context.source_position(targets[0].id)
						if source_attacker not in [0,1,2,3] or source_target not in [0,1,2,3]:
							error_message="Invalid explicit source partner positions";finish("failed");return
						_source_args[int(step.index)]=1 if (source_attacker^2)==source_target else 0
					_:_source_args[int(step.index)]=context.actors[context.attacker_id].side
				BattleEffectBehaviorRegistry.LegacyImpact.Blizzard.query_publication(self,step,blizzard_query_before)
			"source_actor_state":
				for actor in context.resolve(str(step.selector)):
					if str(step.property)=="grayscale":_held_blends.erase(actor.id)
					actor.apply_source_state(str(step.property),bool(step.value))
			"source_control":
				var condition := str(step.condition)
				var jump := false
				var target := int(step.get("target",-1))
				match condition:
					"always":jump = true
					"call":
						_source_returns.append(int(step.return_target))
						jump = true
					"return":
						if not _source_returns.is_empty():
							target = _source_returns.pop_back()
							jump = true
						else:_pc = _steps.size()-3;continue
					"end":_pc = _steps.size()-3;continue
					"turn_eq":jump = context.move_turn==int(step.value)
					"turn_parity":
						target = int(step.target) if context.move_turn%2==0 else int(step.alternate)
						jump = true
					"charge_release":
						target=int(step.target) if context.presentation_variant()=="charge" else int(step.alternate)
						jump=true
					"arg_eq":jump = int(_source_args.get(int(step.index),0))==(int(step.value)&65535)
					"contest":jump = context.contest
				if jump:
					var destination := -1
					for index in _steps.size():
						if str(_steps[index].op)=="source_label" and int(_steps[index].source_pc)==target:
							destination = index
							break
					if destination<0:
						error_message = "Unresolved source control target %d" % target
						finish("failed")
						return
					_pc = destination
					continue
			"source_arg":
				_source_args[int(step.index)] = int(step.value)&65535
			"effect":
				# Consume once; repeat expansion below carries this command's own copy.
				if not step.has("source_command_priority") and not _pending_sprite_priority.is_empty():
					step=step.duplicate(true)
					step.source_command_priority=_pending_sprite_priority.duplicate(true)
				_pending_sprite_priority={}
				var factory: Callable = _factories[str(step.behavior)]
				_effect_dispatch_step=step;_effect_dispatch_pc=_pc
				_i159_dispatch_live=true
				var dizzy_invocation=BattleEffectBehaviorRegistry.LegacyImpact.Dizzy.open_dispatch(self,step)
				var crab_invocation=BattleEffectBehaviorRegistry.LegacyImpact.Crab.open_dispatch(self,step)
				var hydro_invocation=BattleEffectBehaviorRegistry.LegacyImpact.Hydro.open_dispatch(self,step)
				var frenzy_invocation=BattleEffectBehaviorRegistry.LegacyImpact.Frenzy.open_dispatch(self,step)
				var secret_invocation=BattleEffectBehaviorRegistry.LegacyImpact.Secret.open_dispatch(self,step)
				var musical_invocation=BattleEffectBehaviorRegistry.LegacyImpact.Musical.open_dispatch(self,step)
				var swords_invocation=BattleEffectBehaviorRegistry.LegacyImpact.Swords.open_dispatch(self,step)
				var spinning_invocation=BattleEffectBehaviorRegistry.LegacyImpact.Spinning.open_dispatch(self,step)
				var solar_invocation=BattleEffectBehaviorRegistry.LegacyImpact.Solar.open_dispatch(self,step)
				var stockpile_invocation=BattleEffectBehaviorRegistry.LegacyImpact.Stockpile.open_dispatch(self,step)
				var waterfall_invocation=BattleEffectBehaviorRegistry.LegacyImpact.Waterfall.open_dispatch(self,step)
				var petal_invocation=BattleEffectBehaviorRegistry.LegacyImpact.Petal.open_dispatch(self,step)
				var blizzard_invocation=BattleEffectBehaviorRegistry.LegacyImpact.Blizzard.open_dispatch(self,step)
				var snatch_invocation=BattleEffectBehaviorRegistry.Snatch.open_dispatch(self,step)
				# A synchronous factory observer may end or replace this execution.
				var dispatch_context: BattleAnimationContext=context
				var dispatch_definition: BattleAnimationDefinition=definition
				var dispatch_program: Array[Dictionary]=_steps
				var created: Variant=factory.call(step, context, self)
				BattleEffectBehaviorRegistry.LegacyImpact.Dizzy.close_dispatch(self,dizzy_invocation)
				BattleEffectBehaviorRegistry.LegacyImpact.Crab.close_dispatch(self,crab_invocation)
				BattleEffectBehaviorRegistry.LegacyImpact.Hydro.close_dispatch(self,hydro_invocation)
				BattleEffectBehaviorRegistry.LegacyImpact.Frenzy.close_dispatch(self,frenzy_invocation)
				BattleEffectBehaviorRegistry.LegacyImpact.Secret.close_dispatch(self,secret_invocation)
				BattleEffectBehaviorRegistry.LegacyImpact.Musical.close_dispatch(self,musical_invocation)
				BattleEffectBehaviorRegistry.LegacyImpact.Swords.close_dispatch(self,swords_invocation)
				BattleEffectBehaviorRegistry.LegacyImpact.Spinning.close_dispatch(self,spinning_invocation)
				BattleEffectBehaviorRegistry.LegacyImpact.Solar.close_dispatch(self,solar_invocation)
				BattleEffectBehaviorRegistry.LegacyImpact.Stockpile.close_dispatch(self,stockpile_invocation)
				BattleEffectBehaviorRegistry.Snatch.close_dispatch(self,snatch_invocation)
				BattleEffectBehaviorRegistry.LegacyImpact.Waterfall.close_dispatch(self,waterfall_invocation)
				BattleEffectBehaviorRegistry.LegacyImpact.Petal.close_dispatch(self,petal_invocation)
				BattleEffectBehaviorRegistry.LegacyImpact.Blizzard.close_dispatch(self,blizzard_invocation)
				_i159_dispatch_live=false
				_effect_dispatch_step={};_effect_dispatch_pc=-1
				# Never republish returned work after terminal cleanup, or invoke
				# returned cleanup against a possibly replaced execution.
				if state!="running" or context!=dispatch_context or definition!=dispatch_definition or not is_same(_steps,dispatch_program):return
				for track: Dictionary in created:_enroll_provisional_cleanup(track)
				_tracks.append_array(created)
				var count := clampi(int(step.get("repeat", 1)), 1, 128)
				# Expand finite emitters into normal wait/spawn steps; barriers
				# account for every particle, including the tail after emission.
				if count > 1:
					var single := step.duplicate(true)
					single.erase("repeat")
					single.erase("arrival_marker")
					for index in range(count - 1):
						_steps.insert(_pc + 1 + index * 2, {"op": "wait", "ticks": maxi(1, int(step.get("interval", 2)))})
						var particle := single.duplicate(true)
						particle["phase"] = float(step.get("phase", 0)) + index * 0.3
						_steps.insert(_pc + 2 + index * 2, particle)
			"wait":
				_wait = maxi(1, int(step.get("ticks", 1))) - 1
				_pc += 1
				return
			"source_variant":
				var source_turn := maxi(0,context.move_turn)
				var case_key := str(source_turn if source_turn < 2 else 2+(source_turn&1))
				var branch: Array = step.cases.get(case_key,[])
				for index in range(branch.size()-1,-1,-1):
					_steps.insert(_pc+1,branch[index].duplicate(true))
			"background_barrier":
				if _tracks.any(func(track):return str(track.get("domain","visual")) == "background" and (str(step.get("phase","in"))!="out" or int(track.age)<int(track.settings.get("source_fade_out_ticks",track.ticks)))):return
			"sound_barrier":
				if _tracks.any(func(track):return str(track.get("domain","visual")) == "sound"):return
				if _sounds.any(func(player):return is_instance_valid(player) and player.playing) and _sound_barrier_ticks < 90:
					_sound_barrier_ticks += 1
					return
				_sound_barrier_ticks = 0
			"barrier":
				if _tracks.any(func(track): return str(track.get("domain", "visual")) == "visual"):
					return
			"marker":
				_emit_marker(str(step.get("variant_names",{}).get(context.presentation_variant(),step.get("name","impact"))))
			"variant":
				var branch: Array = step.get(context.variant, [])
				for index in range(branch.size() - 1, -1, -1):
					_steps.insert(_pc + 1, branch[index].duplicate(true))
			"source_sound_pan":
				_repan_owned_sounds(int(step.value))
			"sound":
				var original_sound_side: Variant=BattleEffectBehaviorRegistry.LegacyImpact.Blizzard.sound_side(self,step)
				if original_sound_side!=null and int(original_sound_side) not in [0,1]:
					error_message="Invalid original Blizzard sound side";finish("failed");return
				var count := clampi(int(step.get("repeat", 1)), 1, 128)
				var interval := maxi(1,int(step.get("interval",1)))
				var delay := maxi(0,int(step.get("sound_delay",0)))
				if count > 1 or delay > 0:
					_tracks.append({"kind":"sound_loop","domain":"sound","source_pan":str(step.get("source_pan","")),"age":0,"ticks":delay+(count-1)*interval+1,"interval":interval,"delay":delay,"path":str(step.path),"sweep_pan":step.get("sweep_pan",[])})
					if original_sound_side!=null:_tracks[-1].source_original_side=int(original_sound_side)
				if delay == 0:
					var counter_pan: bool=step.has("source_counter_pan")
					var pan: float=float(BattleCounterSelected.adjust_panning(int(step.source_counter_pan),context))/64.0 if counter_pan else float(step.explicit_pan) if step.has("explicit_pan") else _sweep_pan(step.get("sweep_pan",[]),0)
					var player := _play_sound(str(step.get("path", "")),str(step.get("source_pan","")),pan,counter_pan or bool(step.get("source_pan_raw",false)),int(original_sound_side) if original_sound_side!=null else -1)
					if step.has("pan_motion") and is_instance_valid(player):
						var values: Array = step.pan_motion
						var pan_ticks := ceili(absf(float(values[1])-float(values[0]))/maxf(1,absf(float(values[2]))))*maxi(1,int(values[3]))+1
						_tracks.append({"kind":"sound_pan","domain":"sound","age":0,"ticks":pan_ticks,"player":player,"sweep_pan":values,"source_pan_raw":bool(step.get("source_pan_raw",false))})
						if original_sound_side!=null:_tracks[-1].source_original_side=int(original_sound_side)
			"end":
				_pc = _steps.size()
				break
		_pc += 1
	if _pc >= _steps.size() and _tracks.is_empty():
		# Finite audio drain, matching Ruby's bounded SE tail policy.
		if (BattleEffectBehaviorRegistry.LegacyImpact.NightShade.audio_playing(self) if BattleEffectBehaviorRegistry.LegacyImpact.NightShade.group(self)!=null else BattleEffectBehaviorRegistry.LegacyImpact.Confuse.audio_playing(self) if BattleEffectBehaviorRegistry.LegacyImpact.Confuse.group(self)!=null else BattleEffectBehaviorRegistry.LegacyImpact.Dizzy.audio_playing(self)) and _audio_ticks < 90:
			_audio_ticks += 1
			return
		finish("completed")

func _publish_held(actor_id: int,value: Vector2,track: Dictionary) -> void:
	_held_offsets[actor_id]=value
	BattleEffectBehaviorRegistry.LegacyImpact.Crab.note_held_write(self,track,value)
	BattleEffectBehaviorRegistry.LegacyImpact.Hydro.note_held_write(self,track,value)
	BattleEffectBehaviorRegistry.LegacyImpact.Frenzy.note_held_write(self,track,value)
	BattleEffectBehaviorRegistry.LegacyImpact.Secret.note_held_write(self,track,value)
	BattleEffectBehaviorRegistry.LegacyImpact.Stockpile.note_held_write(self,track,value)
	BattleEffectBehaviorRegistry.Snatch.note_held_write(self,track,value)
	BattleEffectBehaviorRegistry.LegacyImpact.Waterfall.note_held_write(self,track,value)
	BattleEffectBehaviorRegistry.LegacyImpact.Petal.note_held_write(self,track,value)
	BattleEffectBehaviorRegistry.LegacyImpact.Blizzard.note_held_write(self,track,value)

func _update_tracks() -> void:
	MetallicPreparation.observe(self)
	var offsets := {}
	var stockpile_offsets: Dictionary={}
	var snatch_offsets: Dictionary={}
	var tints := {}
	var scales := {}
	var blends := {}
	var rotations := {}
	for track in BattleEffectBehaviorRegistry.LegacyImpact.Crab.tracks_for_tick(self,_tracks):
		_i159_actor_callback_track={}
		if not BattleEffectBehaviorRegistry.LegacyImpact.Dizzy.before_track(self,track):continue
		if not BattleEffectBehaviorRegistry.LegacyImpact.Crab.before_track(self,track):continue
		if not BattleEffectBehaviorRegistry.LegacyImpact.Hydro.before_track(self,track):continue
		if not BattleEffectBehaviorRegistry.LegacyImpact.Frenzy.before_track(self,track):continue
		if not BattleEffectBehaviorRegistry.LegacyImpact.Waterfall.scheduled_track_shape_allowed(self,track):
			BattleEffectBehaviorRegistry.LegacyImpact.Waterfall.retire_scheduled(self,track);continue
		if not BattleEffectBehaviorRegistry.LegacyImpact.Blizzard.before_track(self,track):continue
		if not BattleEffectBehaviorRegistry.Snatch.before_track(self,track):continue
		if not BattleEffectBehaviorRegistry.LegacyImpact.Waterfall.before_track(self,track):continue
		if not BattleEffectBehaviorRegistry.LegacyImpact.Petal.before_track(self,track):continue
		if track.kind=="source_solar_actor" and not BattleEffectBehaviorRegistry.LegacyImpact.Solar.actor_allowed(self,track.actor):
			_tracks.erase(track);continue
		if track.has("actor"):
			_i159_actor_callback_track=track
			if not BattleEffectBehaviorRegistry.LegacyImpact.Secret.before_actor_track(self,track):
				_i159_actor_callback_track={};continue
		if not BattleEffectBehaviorRegistry.LegacyImpact.Stockpile.before_actor_track(self,track):
			_i159_actor_callback_track={};continue
		track.age += 1
		if track.kind in ["source_approach_actor","source_field_actor","source_counter_actor","source_phase_screen_actor"] and not track.actor.is_present():
			if track.has("node"):track.node.visible=false
			track.ticks=int(track.age)
		if track.kind=="source_actor_shadows":BattleActorShadows.identity_present(track)
		if track.kind=="source_copy_actor":BattleIdentityCopy.identity_present(track)
		if track.has("actor"):
			var actor: BattleAnimationActor = track.actor
			if actor.is_present():
				var progress := float(track.age) / float(track.ticks)
				var offset := Vector2.ZERO
				if track.kind=="source_dizzy_actor":
					BattleEffectBehaviorRegistry.LegacyImpact.Dizzy.actor_step(track,context)
				elif track.kind=="source_hydro_actor":
					BattleEffectBehaviorRegistry.update_track(track,context)
				elif track.kind=="source_frenzy_actor":
					BattleEffectBehaviorRegistry.LegacyImpact.Frenzy.actor_step(track,context)
				elif track.kind=="source_waterfall_actor":
					BattleEffectBehaviorRegistry.LegacyImpact.Waterfall.actor_step(track,context)
				elif track.kind=="source_petal_actor":
					BattleEffectBehaviorRegistry.LegacyImpact.Petal.actor_step(track,context)
				elif track.kind=="source_snatch_actor":
					var snatch_offset: Vector2=BattleEffectBehaviorRegistry.Snatch.actor_offset(track,context)
					snatch_offsets[actor.id]=snatch_offsets.get(actor.id,Vector2.ZERO)+snatch_offset
				elif track.kind=="source_stockpile_actor":
					var stockpile_pose: Dictionary=BattleEffectBehaviorRegistry.LegacyImpact.Stockpile.actor_pose(track,context)
					offset=stockpile_pose.offset;scales[actor.id]=stockpile_pose.scale
				elif track.kind in ["source_stockpile_shake","source_stockpile_power"]:
					offset=BattleEffectBehaviorRegistry.LegacyImpact.Stockpile.actor_offset(track,context)
				elif track.kind=="source_stockpile_palette":
					BattleEffectBehaviorRegistry.LegacyImpact.Stockpile.advance_palette(track,context)
				elif track.kind=="source_solar_actor":
					offset=BattleEffectBehaviorRegistry.LegacyImpact.Solar.actor_offset(track,context)
				elif track.kind=="source_secret_actor":
					if not BattleEffectBehaviorRegistry.LegacyImpact.Secret.advance_actor(track,context):
						_i159_actor_callback_track={};continue
					if track.pose.get("hold_offset",false):_publish_held(actor.id,track.pose.offset,track)
					else:offset=track.pose.offset
				elif track.kind=="source_baton_ball":
					BattleEffectBehaviorRegistry.update_track(track,context)
					scales[actor.id]=track.scale_pose
				elif track.kind == "source_palette":
					_source_palette(track)
				elif track.kind=="source_counter_actor":
					BattleEffectBehaviorRegistry.update_track(track,context)
					offset=track.pose.get("offset",Vector2.ZERO)
					if track.pose.has("scale"):scales[actor.id]=track.pose.scale
				elif track.kind=="source_field_actor":
					BattleFieldOwned.advance(track,context)
					var pose: Dictionary=track.pose
					offset=pose.get("offset",Vector2.ZERO)
					rotations[actor.id]=pose.get("rotation",0.0)
				elif track.kind=="source_phase_screen_actor":
					BattlePhaseScreenHit.advance(track,context)
					var pose: Dictionary=track.pose
					if pose.has("offset"):
						if bool(pose.get("hold_offset",false)):_publish_held(actor.id,pose.offset,track)
						else:offset=pose.offset
					if pose.has("matrix_correction"):_held_approach_corrections[actor.id]=pose.matrix_correction
					if pose.has("rotation"):
						rotations[actor.id]=pose.rotation
						if bool(pose.get("hold_rotation",false)):_held_rotations[actor.id]=pose.rotation
				elif track.kind=="source_approach_actor":
					BattleApproachChildren.advance(track,context)
					var pose: Dictionary=track.pose
					if bool(pose.get("hold_offset",false)):_publish_held(actor.id,pose.offset,track)
					else:offset=pose.get("offset",Vector2.ZERO)
					if pose.has("matrix_correction"):_held_approach_corrections[actor.id]=pose.matrix_correction
					if pose.has("scale"):scales[actor.id]=pose.scale
					if pose.has("rotation"):
						rotations[actor.id]=pose.rotation
						if bool(pose.get("hold_rotation",false)):_held_rotations[actor.id]=pose.rotation
				elif track.kind=="source_actor_shadows":
					var pose: Dictionary=BattleActorShadows.pose(track)
					offset=pose.offset
					scales[actor.id]=pose.scale
					rotations[actor.id]=pose.rotation
				elif track.kind=="source_copy_actor":
					var pose: Dictionary=BattleIdentityCopy.pose(track)
					offset=pose.offset
					scales[actor.id]=pose.scale
				elif track.kind == "source_actor":
					BattleSourceActorMotion.advance(track)
					_publish_held(actor.id,track.displacement,track)
					scales[actor.id] = track.scale_pose
				elif track.kind == "source_legacy_dummy_shake":
					BattleEffectBehaviorRegistry.LegacyDummyShake.advance(track,context)
					offset=track.pose
				elif track.kind == "shake":
					offset = track.amplitude * (1 if (int(track.age) / 2) % 2 == 0 else -1)
				elif track.kind == "lunge":
					offset = track.destination * sin(progress * PI)
				elif track.kind == "actor_motion":
					var settings: Dictionary = track.settings
					var cycles := float(settings.get("cycles", 1))
					var side: int = actor.side
					if settings.get("mirror_source", "") == "attacker" and context.actors.has(context.attacker_id):
						side = context.actors[context.attacker_id].side
					var direction := 1.0 if side == 0 else -1.0
					var motion := str(settings.get("motion", "ellipse"))
					if motion in ["headbutt","source_tilt","source_heart_tilt","source_startle","source_affine","power_shake","decaying_quake","teleport","source_affine_repeat","shadow_dash","roar_exit","howl_affine"]:
						var pose := BattleSourceChoreography.actor_pose(track)
						if motion in ["headbutt","source_tilt"] or bool(pose.get("hold_offset",false)):
							_publish_held(actor.id,pose.offset,track)
						else:offset = pose.offset
						scales[actor.id] = pose.scale
						if pose.get("hidden",false):actor.apply_source_state("hidden",true)
						rotations[actor.id] = pose.rotation
						if pose.hold_rotation:_held_rotations[actor.id] = pose.rotation
					elif motion == "night_shade":
						var pose := BattleGhostContract.actor_pose(track)
						scales[actor.id] = pose.scale
						tints[actor.id] = pose.tint
					elif motion == "ellipse":
						if settings.has("mirror") and not settings.mirror:direction = 1.0
						offset = Vector2(sin(progress * TAU * cycles) * track.amplitude.x * direction, (1.0 - cos(progress * TAU * cycles)) * track.amplitude.y)
					elif motion == "wind_up_lunge":
						var back_ticks := int(settings.back_ticks)
						var back_age := mini(int(track.age),back_ticks)
						var back_step := int(int(settings.back_delta)*direction)*256/back_ticks
						var back_x := floorf(back_age*back_step/256.0)
						var wave_age := mini(maxi(0,int(track.age)-1),back_ticks-1)
						var phase := (wave_age*(32768/back_ticks)) >> 8
						var y := floorf(sin(phase*TAU/256.0)*float(settings.sine_height))
						var front_age := clampi(int(track.age)-back_ticks-int(settings.hold_ticks)-1,0,int(settings.front_ticks))
						var front_step := int(int(settings.front_delta)*direction)*256/int(settings.front_ticks)
						_publish_held(actor.id,Vector2(back_x+floorf(front_age*front_step/256.0),y),track)
					elif motion == "source_sway":
						var phase := (int(track.age)*int(settings.phase_advance)) & 65535
						var value: float = sin(float(phase >> 8) * TAU / 256.0) * float(track.amplitude.x) * direction
						if int(settings.axis)==0:offset.x = value
						else:offset.y = absf(value)*(1 if actor.side==0 else -1)
						if track.age>=track.ticks:offset = Vector2.ZERO
					elif motion == "triangle":
						var amplitude: Vector2 = track.amplitude
						if bool(settings.get("mirror", false)):
							amplitude.x *= direction
						offset = amplitude * (1.0 - absf(2.0 * progress - 1.0))
					elif motion == "slide_to" or motion == "return":
						var destination := Vector2(track.amplitude.x * direction, track.amplitude.y)
						if bool(settings.get("mirror_vertical", false)):
							destination.y *= direction
						if motion == "return":
							destination = Vector2.ZERO
							if int(settings.get("axis", 0)) == 1:
								destination.y = track.initial.y
							elif int(settings.get("axis", 0)) == 2:
								destination.x = track.initial.x
						_publish_held(actor.id,track.initial.lerp(destination, clampf(progress, 0, 1)),track)
					elif motion == "shake_sink":
						var interval := maxi(1, int(settings.get("shake_delay", 0)) + 1)
						_publish_held(actor.id,Vector2(track.amplitude.x if (int(track.age) / interval) % 2 == 0 else 0.0, floorf(float(track.age) * float(settings.get("sink_rate", 0)))),track)
					elif motion == "sink":
						offset = Vector2(sin(progress * TAU * cycles) * track.amplitude.x, track.amplitude.y * sin(progress * PI))
				elif track.kind == "actor_scale":
					var settings: Dictionary = track.settings
					if settings.has("delta_x"):
						var phase := mini(int(track.age), maxi(0, int(track.ticks) - int(track.age)))
						scales[actor.id] = Vector2(256.0 / (256.0 + float(settings.delta_x) * phase), 256.0 / (256.0 + float(settings.delta_y) * phase))
					else:
						scales[actor.id] = Vector2.ONE + track.amplitude * sin(progress * PI)
				elif track.kind == "palette_blend":
					var settings: Dictionary = track.settings
					var peak := int(settings.get("blend_peak", 8))
					var phase := int(track.age) / maxi(1, int(settings.get("blend_delay", 1)))
					var coefficient := mini(peak, phase) if phase <= peak + 1 else maxi(0, peak * 2 + 1 - phase)
					blends[actor.id] = {"color":track.color, "amount":coefficient / 16.0}
				elif track.kind == "flash":
					tints[actor.id] = Color.WHITE.lerp(track.color, sin(progress * PI))
				if BattleEffectBehaviorRegistry.LegacyImpact.Stockpile.owns_offset(self,track):
					stockpile_offsets[actor.id]=stockpile_offsets.get(actor.id,Vector2.ZERO)+offset
				else:
					offsets[actor.id] = offsets.get(actor.id, Vector2.ZERO) + offset
		elif track.kind in ["source_scroll","source_particle_palette"]:
			_i159_palette_callback_track=track
			BattleEffectBehaviorRegistry.LegacyImpact.Secret.before_palette_writer(self,track)
			BattlePostPsychic.update_owned(track,self)
			_i159_palette_callback_track={}
		elif track.kind == "source_field_offset":
			BattleSoundOwnership.update_field_offset(track)
		elif track.kind == "source_note_grayscale":
			BattleSoundOwnership.update_note_grayscale(track,self)
		elif track.kind == "source_species_cry":
			BattleSoundOwnership.update_cry(track)
		elif track.kind == "source_maintenance":
			if int(_source_args.get(int(track.settings.termination_arg),0))==int(track.settings.termination_value):
				track.ticks = track.age
			elif is_instance_valid(_source_background):
				_source_background.region_rect.position.y = ((int(track.age)/int(track.settings.cycle_interval))%11)*160
		elif track.kind == "source_background" and BattleEffectBehaviorRegistry.LegacyImpact.Blizzard.is_background(self,track):
			_i161_control_callback_track=track
			BattleEffectBehaviorRegistry.LegacyImpact.Blizzard.advance_background(track,context)
			_i161_control_callback_track={}
		elif track.kind == "source_background":
			if not is_instance_valid(_source_background):
				_source_background = Sprite2D.new()
				_source_background.centered = false
				_source_background.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
				_source_background.region_enabled = true
				_source_background.region_rect = Rect2(Vector2.ZERO,context.field_size)
				_source_background.texture = load(str(track.settings.texture))
				_source_background.z_index = 0
				add_child(_source_background)
			var half := int(track.settings.get("source_fade_out_ticks",16))
			if not is_instance_valid(_source_blackout):
				_source_blackout = Polygon2D.new()
				_source_blackout.polygon = PackedVector2Array([Vector2.ZERO,Vector2(context.field_size.x,0),context.field_size,Vector2(0,context.field_size.y)])
				_source_blackout.z_index = 0
				add_child(_source_blackout)
			var darkness := 0.0 if half==0 else float(track.age)/half if track.age<=half else float(track.ticks-track.age)/half
			_source_blackout.color = Color(0,0,0,clampf(darkness,0,1))
			if int(track.age)==half or bool(track.settings.get("immediate",false)):
				if not bool(track.settings.restore):
					BattleEffectBehaviorRegistry.LegacyImpact.Solar.background_write(self,"texture",load(str(track.settings.texture)))
					var source_region: Rect2=_source_background.region_rect;source_region.position=Vector2.ZERO
					BattleEffectBehaviorRegistry.LegacyImpact.Solar.background_write(self,"region_rect",source_region)
				var source_modulate: Color=_source_background.modulate;source_modulate.a=0.0 if bool(track.settings.restore) else 1.0
				BattleEffectBehaviorRegistry.LegacyImpact.Solar.background_write(self,"modulate",source_modulate)
			elif int(track.age)<half and not bool(track.settings.restore):
				var source_fade: Color=_source_background.modulate;source_fade.a=0.0
				BattleEffectBehaviorRegistry.LegacyImpact.Solar.background_write(self,"modulate",source_fade)
		elif track.kind == "sound_pan":
			if is_instance_valid(track.player):
				var pan := _sweep_pan(track.sweep_pan,int(track.age))
				if not bool(track.get("source_pan_raw",false)):
					if track.has("source_original_side"):
						if int(track.source_original_side)!=0:pan *= -1
					else:
						var sound_actor: Variant=context.actors.get(context.attacker_id)
						if typeof(sound_actor)==TYPE_OBJECT and is_instance_valid(sound_actor) and sound_actor is BattleAnimationActor and sound_actor.side!=0:pan *= -1
				track.player.position.x = context.field_size.x*(0.5+pan*0.5)
		elif track.kind == "source_palette":
			_i171_palette_callback=track
			_source_palette(track)
			_i171_palette_callback={}
		elif track.kind == "sound_loop":
			var sound_age := int(track.age)-int(track.get("delay",0))
			if sound_age >= 0 and sound_age % int(track.interval) == 0 and track.age < track.ticks:
				_play_sound(track.path,str(track.get("source_pan","")),_sweep_pan(track.get("sweep_pan",[]),int(track.age)),false,int(track.get("source_original_side",-1)))
		else:
			_i161_control_callback_track=track
			var solar_control: bool=BattleEffectBehaviorRegistry.LegacyImpact.Solar.open_control(self,track)
			BattleEffectBehaviorRegistry.update_track(track, context)
			if solar_control:BattleEffectBehaviorRegistry.LegacyImpact.Solar.close_control(self,track)
			_i161_control_callback_track={}
		_i159_actor_callback_track={}
		if track.age >= track.ticks:
			if track.get("cleanup") is Callable:track.cleanup.call()
			if not str(track.get("arrival_marker", "")).is_empty():
				_emit_marker(str(track.arrival_marker))
				if state != "running":
					return
			if track.has("node") and is_instance_valid(track.node) and BattleEffectBehaviorRegistry.LegacyImpact.Dizzy.release_track_node_allowed(self,track) and BattleEffectBehaviorRegistry.LegacyImpact.Confuse.release_track_node_allowed(self,track):
				track.node.queue_free()
			if track.kind=="source_field_offset":BattleSoundOwnership.update_field_offset(track,true)
			_tracks.erase(track)
	# Candidate palette endpoints persist, but their original visual occupant does not migrate.
	var candidate_offsets: Dictionary=get_meta("i5_offset_owners",{})
	for actor_id: int in candidate_offsets.keys():
		var lease: Dictionary=candidate_offsets[actor_id]
		if context.actors.get(actor_id)!=lease.actor or not lease.actor.is_present():
			if _held_offsets.get(actor_id)==lease.value:_held_offsets.erase(actor_id)
			lease.actor.release();candidate_offsets.erase(actor_id)
	for actor_id: int in _held_blends.keys():
		var held: Dictionary=_held_blends[actor_id]
		if held.has("source_actor"):
			var original: BattleAnimationActor=held.source_actor
			if context.actors.get(actor_id)!=original or not original.is_present():
				original.release();_held_blends.erase(actor_id)
	BattleEffectBehaviorRegistry.LegacyImpact.CrossImpact.begin_tick(self,context,blends)
	for actor in context.actors.values():
		if not BattleEffectBehaviorRegistry.LegacyImpact.NightShade.actor_allowed(self,actor):continue
		if not BattleEffectBehaviorRegistry.LegacyImpact.Crab.actor_allowed(self,actor):continue
		if not BattleEffectBehaviorRegistry.LegacyImpact.Dizzy.actor_allowed(self,actor):continue
		if not BattleEffectBehaviorRegistry.LegacyImpact.Hydro.actor_allowed(self,actor):continue
		if not BattleEffectBehaviorRegistry.LegacyImpact.Frenzy.actor_allowed(self,actor):continue
		if not BattleEffectBehaviorRegistry.LegacyImpact.Blizzard.actor_allowed(self,actor):continue
		if not BattleEffectBehaviorRegistry.LegacyImpact.Waterfall.scheduled_actor_shape_allowed(self,actor):continue
		if not BattleEffectBehaviorRegistry.Snatch.actor_allowed(self,actor):continue
		if not BattleEffectBehaviorRegistry.LegacyImpact.Secret.actor_apply_allowed(self,actor):continue
		if not BattleEffectBehaviorRegistry.LegacyImpact.Solar.actor_allowed(self,actor):continue
		if not BattleEffectBehaviorRegistry.LegacyImpact.Stockpile.actor_allowed(self,actor):continue
		if not BattleEffectBehaviorRegistry.LegacyImpact.Waterfall.actor_allowed(self,actor):continue
		if not BattleEffectBehaviorRegistry.LegacyImpact.Petal.actor_allowed(self,actor):continue
		var actor_offset: Vector2=BattleEffectBehaviorRegistry.LegacyImpact.Dizzy.resolve_offset(self,actor)+BattleEffectBehaviorRegistry.LegacyImpact.Crab.resolve_offset(self,actor)+BattleEffectBehaviorRegistry.LegacyImpact.Hydro.resolve_offset(self,actor)+BattleEffectBehaviorRegistry.LegacyImpact.Frenzy.resolve_offset(self,actor)+BattleEffectBehaviorRegistry.LegacyImpact.Waterfall.resolve_offset(self,actor)+BattleEffectBehaviorRegistry.LegacyImpact.Petal.resolve_offset(self,actor)+offsets.get(actor.id,Vector2.ZERO)+BattleEffectBehaviorRegistry.LegacyImpact.Stockpile.resolve_offset(self,actor,stockpile_offsets.get(actor.id,Vector2.ZERO))+BattleEffectBehaviorRegistry.Snatch.resolve_offset(self,actor,snatch_offsets.get(actor.id,Vector2.ZERO))
		_i159_actor_apply_actor=actor
		actor.apply(_held_offsets.get(actor.id, Vector2.ZERO) + _held_approach_corrections.get(actor.id,Vector2.ZERO) + actor_offset, tints.get(actor.id, Color.WHITE)*Color(1,1,1,float(_held_blends.get(actor.id,{}).get("opacity",1.0))))
		BattleEffectBehaviorRegistry.LegacyImpact.Dizzy.note_application(self,actor)
		BattleEffectBehaviorRegistry.LegacyImpact.Crab.note_application(self,actor)
		BattleEffectBehaviorRegistry.LegacyImpact.Hydro.note_application(self,actor)
		BattleEffectBehaviorRegistry.LegacyImpact.Frenzy.note_application(self,actor,_held_offsets.get(actor.id,Vector2.ZERO),_held_approach_corrections.get(actor.id,Vector2.ZERO),actor_offset)
		BattleEffectBehaviorRegistry.LegacyImpact.Secret.note_actor_application(self,actor,_held_offsets.get(actor.id,Vector2.ZERO),_held_approach_corrections.get(actor.id,Vector2.ZERO),actor_offset)
		BattleEffectBehaviorRegistry.LegacyImpact.Waterfall.note_application(self,actor,_held_offsets.get(actor.id,Vector2.ZERO),_held_approach_corrections.get(actor.id,Vector2.ZERO),actor_offset)
		BattleEffectBehaviorRegistry.LegacyImpact.Petal.note_application(self,actor,_held_offsets.get(actor.id,Vector2.ZERO),_held_approach_corrections.get(actor.id,Vector2.ZERO),actor_offset)
		BattleEffectBehaviorRegistry.LegacyImpact.Blizzard.note_application(self,actor,_held_offsets.get(actor.id,Vector2.ZERO),_held_approach_corrections.get(actor.id,Vector2.ZERO),actor_offset)
		_i159_actor_apply_actor=null
		actor.apply_transform(scales.get(actor.id, Vector2.ONE),rotations.get(actor.id,_held_rotations.get(actor.id,0.0)))
		var blend: Dictionary = blends.get(actor.id, _held_blends.get(actor.id, {"color":Color.WHITE,"amount":0.0}))
		if not BattleEffectBehaviorRegistry.LegacyImpact.Frenzy.handle_palette(self,actor,blend,blends.has(actor.id)) and not BattleEffectBehaviorRegistry.LegacyImpact.Blizzard.handle_palette(self,context,actor,blend,blends.has(actor.id)) and not BattleEffectBehaviorRegistry.LegacyImpact.Waterfall.handle_palette(self,context,actor,blend,blends.has(actor.id)) and not BattleEffectBehaviorRegistry.LegacyImpact.Stockpile.handle_palette(self,context,actor,blend) and not BattleEffectBehaviorRegistry.LegacyImpact.Solar.handle_palette(self,context,actor,blend) and not BattleEffectBehaviorRegistry.LegacyImpact.Spinning.handle_palette(self,context,actor,blend,blends.has(actor.id)):
			actor.apply_blend(blend.color, blend.amount)
			if actor.is_present() and actor._blend_material != null:
				for parameter in ["wave_amplitude","wave_phase","wave_height","wave_start","wave_end","wave_scale_x","wave_scale_y"]:
					actor._blend_material.set_shader_parameter(parameter,float(blend.get(parameter,0.0 if parameter!="wave_height" else 64.0)))
		BattleEffectBehaviorRegistry.LegacyImpact.AgilityAerial.confirm_final(self,context,actor,blend,blends.has(actor.id))
	BattleEffectBehaviorRegistry.PairComposition.sync(self)
	BattleEffectBehaviorRegistry.Snatch.observe_palette_application(self)
	BattleEffectBehaviorRegistry.LegacyImpact.Waterfall.observe_palette_application(self)
	BattleEffectBehaviorRegistry.LegacyImpact.Petal.observe_palette_application(self)
	if has_meta(BattleEffectBehaviorRegistry.LegacyImpact.Frenzy.STATE):
		for frenzy_candidate: Variant in context.actors.values():
			if BattleEffectBehaviorRegistry.LegacyImpact.Frenzy.actor_allowed(self,frenzy_candidate):BattleEffectBehaviorRegistry.LegacyImpact.Frenzy.observe_palette_application(self,frenzy_candidate,blends.has(frenzy_candidate.id))
	# Snapshots see the pose applied by this tick, not the previous rendered pose.
	for track in _tracks:
		if track.kind == "afterimage" and track.age >= 0 and bool(track.get("snapshot_pending", false)):
			var actor: BattleAnimationActor = track.actor_snapshot
			if actor.is_present() and is_instance_valid(track.node):
				track.node.position = actor.anchor(context.field)
				track.node.scale = actor.sprite.global_scale / context.field.global_scale
				track.node.visible = true
			track.snapshot_pending = false

func _emit_marker(marker_name: String) -> void:
	var record := {"action_id":context.action_id, "phase":context.phase, "name": marker_name, "tick": elapsed_ticks, "targets": context.target_ids.duplicate(),"move_turn":context.move_turn,"hit_index":context.hit_index}
	markers.append(record)
	marker_reached.emit(record)

func _sweep_pan(values: Array, age: int) -> float:
	if values.is_empty(): return NAN
	var start_value := int(values[0])
	var end_value := int(values[1])
	var delta := absi(int(values[2]))*signi(end_value-start_value)
	var value := start_value+delta*(age/maxi(1,int(values[3])))
	return clampf(value,mini(start_value,end_value),maxi(start_value,end_value))/64.0

func _repan_owned_sounds(value: int) -> void:
	# ScriptCmd_setpan -> SE12PanpotControl affects active SE channels, not a
	# default for future notes. Native projection touches this runner's live SEs.
	var signed_byte: int=((value+128)&255)-128
	var pan: float=float(BattleCounterSelected.adjust_panning(signed_byte,context))/64.0
	var changed: int=0
	for player: AudioStreamPlayer2D in _sounds:
		if not is_instance_valid(player) or not player.playing:continue
		player.position=Vector2(context.field_size.x*(0.5+pan*0.5),context.field_size.y*0.5)
		player.panning_strength=2.0;changed+=1
	sound_pan_events.append({"tick":elapsed_ticks,"source_value":signed_byte,"pan":pan,"live_players":changed})

func _play_sound(path: String, source_pan: String = "", explicit_pan: float = NAN, source_adjusted: bool = false, original_side: int = -1) -> AudioStreamPlayer2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var player := AudioStreamPlayer2D.new()
	player.stream = load(path)
	player.max_distance = 2000
	player.volume_db = -8
	BattleEffectBehaviorRegistry.LegacyImpact.Dizzy.note_sound(self,player)
	BattleEffectBehaviorRegistry.LegacyImpact.NightShade.note_sound(self,player)
	BattleEffectBehaviorRegistry.LegacyImpact.Confuse.note_sound(self,player)
	BattleEffectBehaviorRegistry.LegacyImpact.Hydro.note_sound(self,player)
	add_child(player)
	if not BattleEffectBehaviorRegistry.LegacyImpact.Dizzy.audio_allowed(self,player):return player
	var sources: Array[BattleAnimationActor]=[]
	if original_side<0:sources=context.resolve("attacker")
	player.position = sources[0].anchor(context.field) if not sources.is_empty() else context.field_size / 2
	if not source_pan.is_empty() or not is_nan(explicit_pan):
		# Source +/-63 is adapted to a normalized battlefield stereo position.
		# This preserves direction independent of arbitrary lab target roles.
		var side: int=original_side if original_side>=0 else 0
		if original_side<0:
			var sound_actor: Variant=context.actors.get(context.attacker_id)
			if typeof(sound_actor)==TYPE_OBJECT and is_instance_valid(sound_actor) and sound_actor is BattleAnimationActor:side=sound_actor.side
		var pan := -1.0 if source_pan == "SOUND_PAN_ATTACKER" else 1.0 if source_pan == "SOUND_PAN_TARGET" else 0.0 if source_pan.is_empty() else float(source_pan)/64.0
		if not is_nan(explicit_pan): pan = explicit_pan
		if not source_adjusted:
			if not context.contest and bool(context.get_meta("source_status_anim_active",false)):pan=-1.0
			pan *= 1.0 if side == 0 else -1.0
		player.position = Vector2(context.field_size.x * (0.5 + pan * 0.5), context.field_size.y * 0.5)
		player.panning_strength = 2.0
		sound_events.append({"tick":elapsed_ticks,"path":path,"source_pan":source_pan,"pan":pan})
	else:
		sound_events.append({"tick":elapsed_ticks,"path":path,"source_pan":"","pan":0.0})
	player.play()
	_sounds.append(player)
	return player

func finish(terminal_state: String) -> void:
	if state != "running":
		return
	if BattleEffectBehaviorRegistry.LegacyImpact.NightShade.finish(self,terminal_state):return
	if BattleEffectBehaviorRegistry.LegacyImpact.Confuse.finish(self,terminal_state):return
	if BattleEffectBehaviorRegistry.LegacyImpact.Dizzy.finish(self,terminal_state):return
	if BattleEffectBehaviorRegistry.LegacyImpact.Crab.finish_context_loss(self,terminal_state):return
	if BattleEffectBehaviorRegistry.LegacyImpact.Hydro.finish_context_loss(self,terminal_state):return
	if BattleEffectBehaviorRegistry.LegacyImpact.Frenzy.finish_context_loss(self,terminal_state):return
	if BattleEffectBehaviorRegistry.LegacyImpact.Blizzard.finish_context_loss(self,terminal_state):return
	if has_meta("source_lovely_rng"):remove_meta("source_lovely_rng")
	if has_meta("source_startle_rng"):remove_meta("source_startle_rng")
	if has_meta("source_tag_palette_states"):remove_meta("source_tag_palette_states")
	var frenzy_invalid: Array=BattleEffectBehaviorRegistry.LegacyImpact.Frenzy.terminal(self)
	var secret_terminal_actors: Variant=BattleEffectBehaviorRegistry.LegacyImpact.Secret.terminal_actors(self)
	var musical_foreign_banks: Dictionary=BattleEffectBehaviorRegistry.LegacyImpact.Musical.foreign_terminal_banks(self)
	var solar_terminal: Dictionary=BattleEffectBehaviorRegistry.LegacyImpact.Solar.terminal(self)
	var stockpile_invalid: Array=BattleEffectBehaviorRegistry.LegacyImpact.Stockpile.terminal(self)
	var snatch_invalid: Array=BattleEffectBehaviorRegistry.Snatch.terminal(self)
	var waterfall_invalid: Array=BattleEffectBehaviorRegistry.LegacyImpact.Waterfall.terminal(self)
	var petal_invalid: Array=BattleEffectBehaviorRegistry.LegacyImpact.Petal.terminal(self)
	var blizzard_invalid: Array=BattleEffectBehaviorRegistry.LegacyImpact.Blizzard.terminal(self)
	state = terminal_state
	_drain_provisional_cleanups()
	BattleEffectBehaviorRegistry.LegacyImpact.Crab.begin_terminal(self)
	BattleEffectBehaviorRegistry.LegacyImpact.Hydro.begin_terminal(self)
	MetallicPreparation.release(self)
	for track: Dictionary in _tracks:
		if track.get("cleanup") is Callable:track.cleanup.call()
	BattleEffectBehaviorRegistry.LegacyImpact.Secret.release(self)
	BattleEffectBehaviorRegistry.LegacyImpact.Musical.release(self)
	BattleEffectBehaviorRegistry.LegacyImpact.Swords.release(self)
	BattleEffectBehaviorRegistry.LegacyImpact.Spinning.release(self)
	BattleEffectBehaviorRegistry.LegacyImpact.Solar.release(self)
	BattleEffectBehaviorRegistry.LegacyImpact.Stockpile.release(self)
	BattleEffectBehaviorRegistry.Snatch.release_missing_actors(self)
	BattleEffectBehaviorRegistry.LegacyImpact.Waterfall.release_missing_actors(self)
	BattleEffectBehaviorRegistry.LegacyImpact.Petal.release_missing_actors(self)
	for actor in context.actors.values():
		if not BattleEffectBehaviorRegistry.LegacyImpact.Crab.actor_allowed(self,actor):continue
		if not BattleEffectBehaviorRegistry.LegacyImpact.Dizzy.actor_allowed(self,actor):continue
		if not BattleEffectBehaviorRegistry.LegacyImpact.Hydro.actor_allowed(self,actor):continue
		if not BattleEffectBehaviorRegistry.LegacyImpact.Frenzy.actor_allowed(self,actor):continue
		if not BattleEffectBehaviorRegistry.LegacyImpact.Blizzard.terminal_actor_allowed(self,actor):continue
		if not BattleEffectBehaviorRegistry.Snatch.terminal_actor_shape_allowed(self,actor):continue
		if not BattleEffectBehaviorRegistry.LegacyImpact.Waterfall.terminal_shape_allowed(self,actor):continue
		if not BattleEffectBehaviorRegistry.LegacyImpact.Petal.terminal_shape_allowed(self,actor):continue
		# Appearance commit and transient properties have separate ownership.
		# Actor release checks bound identity and each expected property write;
		# a new appearance tag must not strand this execution's hide/displacement.
		if not frenzy_invalid.has(actor) and not blizzard_invalid.has(actor) and not waterfall_invalid.has(actor) and not petal_invalid.has(actor) and not snatch_invalid.has(actor) and not stockpile_invalid.has(actor) and not solar_terminal.invalid.has(actor) and BattleEffectBehaviorRegistry.LegacyImpact.Secret.release_actor_allowed(secret_terminal_actors,actor):
			if not BattleEffectBehaviorRegistry.LegacyImpact.Crab.release_actor(self,actor) and not BattleEffectBehaviorRegistry.LegacyImpact.Hydro.release_actor(self,actor) and not BattleEffectBehaviorRegistry.LegacyImpact.Frenzy.release_actor(self,actor) and not BattleEffectBehaviorRegistry.LegacyImpact.Blizzard.release_actor(self,actor) and not BattleEffectBehaviorRegistry.LegacyImpact.Waterfall.release_actor(self,actor) and not BattleEffectBehaviorRegistry.LegacyImpact.Petal.release_actor(self,actor) and not BattleEffectBehaviorRegistry.Snatch.release_actor(self,actor):actor.release()
	BattleEffectBehaviorRegistry.Snatch.release(self)
	BattleEffectBehaviorRegistry.LegacyImpact.Waterfall.release(self)
	BattleEffectBehaviorRegistry.LegacyImpact.Petal.release(self)
	BattleEffectBehaviorRegistry.LegacyImpact.Blizzard.release(self)
	BattleEffectBehaviorRegistry.LegacyImpact.Crab.release(self)
	BattleEffectBehaviorRegistry.LegacyImpact.Hydro.release(self)
	BattleEffectBehaviorRegistry.LegacyImpact.Frenzy.release(self)
	# Source-owned texture swaps commit only after all transient actor state is
	# restored and the actual program completes, never on skip/cancel mid-task.
	for lease: BattleOwnedAppearanceLease in _appearance_leases:
		lease.finalize(terminal_state=="completed" and context.source_presentation_commit)
	_appearance_leases.clear()
	for child in get_children():
		if not BattleEffectBehaviorRegistry.LegacyImpact.Crab.release_child_allowed(self,child):continue
		if not BattleEffectBehaviorRegistry.LegacyImpact.Hydro.release_child_allowed(self,child):continue
		if child is AudioStreamPlayer2D:
			child.stop()
		child.queue_free()
	for track in _tracks:
		if track.kind=="source_field_offset":BattleSoundOwnership.update_field_offset(track,true)
	_tracks.clear()
	_source_palette_banks.clear()
	# Only admitted musical executions preserve separately owned public receipts.
	_source_palette_banks.merge(musical_foreign_banks)
	terminated.emit(state)
	if BattleEffectBehaviorRegistry.LegacyImpact.Crab.release_owner_allowed(self) and BattleEffectBehaviorRegistry.LegacyImpact.Hydro.release_owner_allowed(self):queue_free()

func _exit_tree() -> void:
	if state == "running":
		lifecycle_aborted = true
		finish("cancelled")

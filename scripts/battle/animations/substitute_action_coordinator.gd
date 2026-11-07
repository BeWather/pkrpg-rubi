extends RefCounted
class_name BattleSubstituteActionCoordinator
## One source controller lifecycle shared by every hit/recipient of an action.
signal startup_finished
var battle: BattleSceneController
var attacker: BasePokemon
var slot: BattleSlot
var expected: BattleOwnedAppearanceLease
var startup_pending: bool=false
var prepared: bool=false
var opened: bool=false
var finished: bool=false
var aborted: bool=false

func _init(scene: BattleSceneController, actor: BasePokemon) -> void:
	battle=scene;attacker=actor

func _live() -> bool:
	return is_instance_valid(battle) and battle.is_inside_tree() and battle.fase!=battle.FIN_BATALLA and is_instance_valid(slot) and battle.hud._obtener_slot_de_pokemon(attacker)==slot

func _owned_state() -> Dictionary:
	if not _live() or not is_instance_valid(slot.sprite_pokemon):return {}
	return BattleSubstitutePresentation.owned_state(slot)

func _capture() -> BattleOwnedAppearanceLease:
	var actor:=BattleAnimationActor.new(int(slot.posicion_batalla),0 if battle.poke_jugador==attacker or battle.pokemones_activos_jugador.has(attacker) else 1,slot.sprite_pokemon,slot)
	var domain: PokemonEnCombate=battle._obtener_combatiente(attacker)
	if domain!=null and domain.hidden_projection!=null:domain.hidden_projection.bind_actor(actor)
	return BattleOwnedAppearanceLease.capture(actor)

func allows_effects() -> bool:
	if aborted:return false
	# While the primary is live, retain the exact temporary-mon lease captured
	# after Special5. A replacement never becomes this action's new occupant.
	if opened and not startup_pending and not finished:
		if not _live() or expected==null or not expected.still_bound():
			aborted=true;return false
	return true

func prepare() -> void:
	if startup_pending:
		await startup_finished;return
	if prepared:return
	prepared=true
	slot=battle.hud._obtener_slot_de_pokemon(attacker)
	var domain: PokemonEnCombate=battle._obtener_combatiente(attacker)
	var state: Dictionary=_owned_state()
	if domain==null or domain.substitute_hp<=0 or str(state.get("kind",""))!="substitute":return
	expected=_capture();opened=true;startup_pending=true
	var original_token: String=str(state.token)
	var animation: BattleSequenceAnimation=_play("ruby:special/5")
	await animation.esperar_finalizada()
	if animation.lifecycle_aborted or not _live():aborted=true
	elif expected.still_bound():
		# A skipped/canceled visual does not revoke an accepted barrier. Commit
		# only the original bound lease; never acquire a replacement occupant.
		_commit_mon(state)
	else:
		var current: Dictionary=_owned_state()
		if str(current.get("kind",""))!="substitute_mon" or str(current.get("substitute_state",{}).get("token",""))!=original_token:aborted=true
	if not aborted:expected=_capture()
	startup_pending=false;startup_finished.emit()

func _play(key: String) -> BattleSequenceAnimation:
	var context: BattleAnimationContext=BattleAnimationContext.from_legacy(MoveAnimationContext.nueva(battle,slot,slot))
	var animation: BattleSequenceAnimation=BattleAnimationDirector.play_key(key,context,true)
	# Runner.start does not advance the script. Bind ownership before the first
	# synchronous factory, rather than acquiring a later external owner's tag.
	if is_instance_valid(animation.runner) and expected!=null:animation.runner.set_meta("source_substitute_guard",expected)
	return animation

func accept_transform_handoff(action_id: int, transformed: Dictionary) -> void:
	if not opened or aborted or not _live() or int(transformed.get("transform_action_id",-1))!=action_id:return
	var old: Dictionary=expected.actor.sprite.get_meta("source_presentation_state",{})
	# The original temporary-mon guard is retained through the source commit;
	# only its approved transformation token can update the coordinator lease.
	if BattleSubstitutePresentation.owned_state(slot)!=transformed:return
	var original_doll: Dictionary={}
	# expected.before describes the pre-Transform mon; its nested doll was
	# captured during Special5 and retained separately for this handoff.
	if not has_meta("transform_original_mon"):return
	var mon: Dictionary=get_meta("transform_original_mon")
	if mon.get("kind")!="substitute_mon":return
	original_doll=mon.substitute_state.duplicate(true)
	var frame: Dictionary={"texture":slot.sprite_pokemon.texture,"species":str(transformed.species),"presentation_state":transformed.duplicate(true)}
	for property: String in ["hframes","vframes","frame","region_enabled","region_rect","flip_h","flip_v"]:frame[property]=slot.sprite_pokemon.get(property)
	original_doll.previous=frame
	var wrapped: Dictionary=transformed.duplicate(true)
	wrapped.kind="substitute_mon";wrapped.underlying_presentation=transformed.duplicate(true);wrapped.substitute_state=original_doll
	slot.sprite_pokemon.set_meta("source_presentation_state",wrapped)
	expected=_capture()

func _commit(chosen: Dictionary, state: Dictionary) -> void:
	if expected==null or not expected.still_bound():return
	expected.replacement={"texture":chosen.texture,"species":str(chosen.get("species","")),"kind":str(state.get("kind","form")),"frame_properties":BattleSubstituteLifecycle._frame_properties(chosen),"presentation_state":state}
	expected.ready=true;expected.finalize(true)

func _commit_mon(doll: Dictionary) -> void:
	var chosen: Dictionary=doll.previous.duplicate(true)
	_commit(chosen,{"kind":"substitute_mon","underlying_presentation":chosen.get("presentation_state",{}).duplicate(true),"substitute_state":doll.duplicate(true)})

func finish() -> void:
	if startup_pending:await startup_finished
	if finished or not opened or aborted:return
	finished=true
	if not _live() or expected==null or not expected.still_bound():return
	var domain: PokemonEnCombate=battle._obtener_combatiente(attacker)
	var state: Dictionary=_owned_state()
	if str(state.get("kind",""))!="substitute_mon":return
	if domain==null or domain.substitute_hp<=0 or attacker.estad_ps_actual<=0:
		# Contact can KO the owner or remove its barrier between real hits.
		var chosen: Dictionary=state.substitute_state.previous.duplicate(true)
		var underlying: Dictionary=chosen.get("presentation_state",{}).duplicate(true)
		if underlying.is_empty():underlying={"kind":"form"}
		_commit(chosen,underlying);return
	var animation: BattleSequenceAnimation=_play("ruby:special/6")
	await animation.esperar_finalizada()
	if animation.lifecycle_aborted or not _live():aborted=true;return
	if expected.still_bound():
		var doll: Dictionary=state.substitute_state.duplicate(true)
		_commit(doll,doll)
	else:
		var current: Dictionary=_owned_state()
		# A successful source swap owns the new token; external substitutions do not.
		if str(current.get("kind",""))!="substitute" or current.get("texture")!=state.substitute_state.texture or current.get("previous",{}).get("texture")!=state.substitute_state.previous.texture:aborted=true

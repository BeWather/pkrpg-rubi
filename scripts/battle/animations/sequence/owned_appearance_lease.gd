extends RefCounted
class_name BattleOwnedAppearanceLease
## Atomic deferred presentation commit, never a party/domain mutation.
var actor: BattleAnimationActor
var before: Dictionary
var replacement: Dictionary={}
var ready: bool=false
var active: bool=true
var commit_guard: BattleOwnedAppearanceLease=null

static func capture(bound_actor: BattleAnimationActor) -> BattleOwnedAppearanceLease:
	var lease:=BattleOwnedAppearanceLease.new();lease.actor=bound_actor
	var sprite: Sprite2D=bound_actor.sprite
	lease.before={"texture":sprite.texture,"hframes":sprite.hframes,"vframes":sprite.vframes,"frame":sprite.frame,"region_enabled":sprite.region_enabled,"region_rect":sprite.region_rect,"flip_h":sprite.flip_h,"flip_v":sprite.flip_v,"tag":sprite.get_meta("source_appearance_owner",""),"species":sprite.get_meta("animation_species","")}
	if is_instance_valid(bound_actor.slot):lease.before.shadow=bound_actor.slot._sombra_activa
	return lease

func still_bound(detached: bool=false) -> bool:
	if not active or not is_instance_valid(actor.sprite):return false
	if not detached and not actor.is_present():return false
	if detached:
		var generation: int=actor.slot.animation_generation if is_instance_valid(actor.slot) else int(actor.sprite.get_meta("animation_generation",0))
		if actor.sprite.texture!=actor._texture or generation!=actor._generation:return false
	var sprite: Sprite2D=actor.sprite
	for property: String in ["texture","hframes","vframes","frame","region_enabled","region_rect","flip_h","flip_v"]:
		if sprite.get(property)!=before[property]:return false
	return sprite.get_meta("source_appearance_owner","")==before.tag and sprite.get_meta("animation_species","")==before.species

func finalize(completed: bool, detached: bool=false) -> void:
	if completed and ready and still_bound(detached) and (commit_guard==null or commit_guard.still_bound(detached)):
		var sprite: Sprite2D=actor.sprite
		var old_bottom: float=sprite.get_rect().end.y
		var prior_state: Dictionary={"texture":sprite.texture,"hframes":sprite.hframes,"vframes":sprite.vframes,"frame":sprite.frame,"region_enabled":sprite.region_enabled,"region_rect":sprite.region_rect,"flip_h":sprite.flip_h,"flip_v":sprite.flip_v,"species":sprite.get_meta("animation_species",""),"presentation_state":sprite.get_meta("source_presentation_state",{}).duplicate(true)}
		sprite.texture=replacement.texture
		sprite.hframes=1;sprite.vframes=1;sprite.frame=0;sprite.region_enabled=false
		for property: String in replacement.get("frame_properties",{}):sprite.set(property,replacement.frame_properties[property])
		# Preserve the actual visual feet, including external layout/scale changes.
		sprite.position+=sprite.transform.basis_xform(Vector2(0,old_bottom-sprite.get_rect().end.y))
		if replacement.has("flip_h"):sprite.flip_h=replacement.flip_h
		sprite.set_meta("animation_species",replacement.species)
		var token: String="presentation:%d"%get_instance_id()
		sprite.set_meta("source_appearance_owner",token)
		var presentation: Dictionary=replacement.get("presentation_state",{"kind":replacement.kind,"previous":prior_state}).duplicate(true)
		presentation.merge({"texture":sprite.texture,"species":replacement.species,"generation":actor._generation,"token":token},true)
		presentation.frame_properties={}
		for property: String in ["hframes","vframes","frame","region_enabled","region_rect","flip_h","flip_v"]:presentation.frame_properties[property]=sprite.get(property)
		sprite.set_meta("source_presentation_state",presentation)
		if replacement.has("shadow") and is_instance_valid(actor.slot) and actor.slot._sombra_activa==before.get("shadow"):
			actor.slot.fijar_sombra_activa(bool(replacement.shadow))
		if actor.hidden_projection!=null:actor.hidden_projection.accept_appearance_commit(self)
	active=false

static func appearance_species(sprite: Sprite2D, generation: int) -> String:
	var fallback: String=sprite.texture.resource_path.get_file().get_basename()
	var species: String=str(sprite.get_meta("animation_species",fallback))
	var state: Dictionary=sprite.get_meta("source_presentation_state",{})
	# Only distrust OUR stale metadata. External appearance providers retain
	# their own species overrides even if an old presentation record remains.
	if state.has("token") and str(sprite.get_meta("source_appearance_owner",""))==str(state.token) and species==str(state.species):
		if sprite.texture!=state.texture or generation!=int(state.generation):return fallback
	return species

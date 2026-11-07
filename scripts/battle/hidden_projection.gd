extends RefCounted
class_name BattleHiddenProjection
## Explicit visibility transaction: source view -> original-bank semi -> release.
## Uninstrumented same-value external writes remain indistinguishable.
var _lease: BattleHiddenActorRules
var _sprite: WeakRef
var _slot: WeakRef
var _texture: Texture2D
var _generation: int
var _baseline: bool
var _expected: bool
var _owned:=false
var _enrolled:=false
var _retired:=false
var releasing:=false

func _init(lease: BattleHiddenActorRules) -> void:_lease=lease
func live() -> bool:
	if _retired or not _lease.live():return false
	var state: PokemonEnCombate=_lease.original_state()
	return state!=null and state.hidden_projection==self
func visual_live() -> bool:
	if not live() or not _enrolled:return false
	var sprite: Sprite2D=_sprite.get_ref();var slot: BattleSlot=_slot.get_ref()
	return is_instance_valid(sprite) and sprite.is_inside_tree() and is_instance_valid(slot) and slot.sprite_pokemon==sprite and slot.animation_generation==_generation and sprite.texture==_texture
func admits(slot: BattleSlot) -> bool:
	return visual_live() and _slot.get_ref()==slot
func bind_actor(actor: BattleAnimationActor) -> bool:
	if not _enroll(actor.sprite,actor.slot):return false
	actor.hidden_projection=self;return true
## Native scene animations (AnimacionEscenaNativa, opt-in): same enrollment as
## bind_actor() without a VM actor. The scene only writes through write().
func bind_slot(slot: BattleSlot) -> bool:
	return is_instance_valid(slot) and _enroll(slot.sprite_pokemon,slot)
func _enroll(sprite: Sprite2D,slot: BattleSlot) -> bool:
	if not live() or slot!=_lease.original_slot():return false
	if not _enrolled:
		_sprite=weakref(sprite);_slot=weakref(slot);_texture=sprite.texture
		_generation=slot.animation_generation;_baseline=sprite.visible;_expected=_baseline;_enrolled=true
	return visual_live() and sprite==_sprite.get_ref()
func write(value: bool) -> void:
	if not visual_live():return
	var sprite: Sprite2D=_sprite.get_ref()
	# Differing uninstrumented writes revoke our property claim, not domain PP.
	if _owned and sprite.visible!=_expected:
		_owned=false;return
	if not _owned and sprite.visible!=_baseline:return
	_owned=true;_expected=value;sprite.visible=value
func release_view() -> void:
	# View cleanup cannot undo an accepted or in-flight domain handoff.
	pass
func accept_charge() -> void:write(false)
func begin_release() -> void:releasing=true
func retire() -> void:
	if _retired:return
	if visual_live() and _owned:
		var sprite: Sprite2D=_sprite.get_ref()
		if sprite.visible==_expected:sprite.visible=_baseline
	_retired=true;_owned=false
func accept_appearance_commit(appearance: BattleOwnedAppearanceLease) -> void:
	# Called only INSIDE a successfully bound production appearance commit.
	if not live() or not _enrolled or appearance.actor.sprite!=_sprite.get_ref() or appearance.actor.slot!=_slot.get_ref():return
	if appearance.before.texture!=_texture or appearance.actor._generation!=_generation:return
	var sprite: Sprite2D=_sprite.get_ref()
	if sprite.get_meta("source_appearance_owner","")!="presentation:%d"%appearance.get_instance_id():return
	if sprite.texture!=appearance.replacement.texture:return
	_texture=sprite.texture
static func for_slot(battle: Node,slot: BattleSlot) -> BattleHiddenProjection:
	if not is_instance_valid(battle) or not battle.has_method("_pokemon_de_slot") or not battle.has_method("_obtener_combatiente"):return null
	var actor: BasePokemon=battle._pokemon_de_slot(slot)
	var state: PokemonEnCombate=battle._obtener_combatiente(actor) if actor!=null else null
	var token: BattleHiddenProjection=state.hidden_projection if state!=null else null
	return token if token!=null and token.admits(slot) else null

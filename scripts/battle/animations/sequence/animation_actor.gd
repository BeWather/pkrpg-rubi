extends RefCounted
class_name BattleAnimationActor
## An execution-bound visual occupant, not a domain Pokemon or a HUD.

var hidden_projection: BattleHiddenProjection
var id: int
var side: int
var sprite: Sprite2D
var slot: BattleSlot
var _texture: Texture2D
var _generation: int
var _offset := Vector2.ZERO
var _base_position := Vector2.ZERO
var _expected_position := Vector2.ZERO
var _base_scale := Vector2.ONE
var _expected_scale := Vector2.ONE
var _tint := Color.WHITE
var _base_color := Color.WHITE
var _expected_color := Color.WHITE
var _scale_factor := Vector2.ONE
var _rotation_delta := 0.0
var _base_rotation := 0.0
var _expected_rotation := 0.0
var _previous_material: Material
var _owned_grayscale := false
var _owned_invert := false
var _owned_hidden := false
var _base_visible := true
var _expected_visible := true
var _blend_material: ShaderMaterial
var _blend_shader: Shader
var _blend_values: Dictionary = {}
var _owned_layer := false
var _previous_layer := 0
var _expected_layer := 0

func _init(actor_id: int, actor_side: int, visual: Sprite2D, battle_slot: BattleSlot = null) -> void:
	id = actor_id
	side = actor_side
	sprite = visual
	slot = battle_slot
	_base_visible = visual.visible
	_expected_visible = visual.visible
	_texture = visual.texture
	_base_position = visual.position
	_expected_position = visual.position
	_base_scale = visual.scale
	_expected_scale = visual.scale
	_base_rotation = visual.rotation
	_expected_rotation = visual.rotation
	_generation = battle_slot.animation_generation if battle_slot else int(visual.get_meta("animation_generation", 0))
	_base_color = visual.modulate
	_expected_color = _base_color

func is_present() -> bool:
	if not is_instance_valid(sprite) or not sprite.is_inside_tree() or sprite.texture != _texture:
		return false
	var generation := slot.animation_generation if is_instance_valid(slot) else int(sprite.get_meta("animation_generation", 0))
	return generation == _generation

func anchor(field: Node2D, name: String = "center") -> Vector2:
	var rect := sprite.get_rect()
	var local := Vector2.ZERO if name == "origin" else rect.get_center()
	if name == "head":
		local.y = rect.position.y
	elif name == "feet":
		local.y = rect.end.y
	return field.to_local(sprite.to_global(local))

func apply(offset: Vector2, tint: Color) -> void:
	if not is_present():
		return
	# Remove only our additive displacement: layout/other deltas survive.
	if sprite.position != _expected_position:
		_base_position += sprite.position - _expected_position
	_expected_position = _base_position + offset
	sprite.position = _expected_position
	_offset = offset
	if sprite.modulate != _expected_color:
		_base_color = sprite.modulate
	_tint = tint
	_expected_color = _base_color * _tint
	sprite.modulate = _expected_color

## Persistent geometry changes while THIS actor wrapper owns transient motion.
## Independent wrappers must not compete; absolute native layout remains literal.
func add_layout_offset(delta: Vector2) -> void:
	if not is_present():return
	if sprite.position!=_expected_position:_base_position+=sprite.position-_expected_position
	_base_position+=delta
	_expected_position=_base_position+_offset
	sprite.position=_expected_position

func _merge_external_scale() -> void:
	if sprite.scale==_expected_scale:return
	for axis in 2:
		# An observed replacement of a collapsed axis has no recoverable ratio.
		# Treat that axis as a new baseline, never divide by zero / emit NaN.
		_base_scale[axis]=_base_scale[axis]*sprite.scale[axis]/_expected_scale[axis] if _expected_scale[axis]!=0 else sprite.scale[axis]

func multiply_layout_scale(factor: Vector2) -> void:
	if not is_present():return
	_merge_external_scale()
	_base_scale*=factor
	_expected_scale=_base_scale*_scale_factor
	sprite.scale=_expected_scale
	# Node2D normalizes zero components: retain its actual stored write so a
	# subsequent update does not mistake that normalization for external layout.
	_expected_scale=sprite.scale

func add_layout_rotation(delta: float) -> void:
	if not is_present():return
	if sprite.rotation!=_expected_rotation:_base_rotation+=sprite.rotation-_expected_rotation
	_base_rotation+=delta
	sprite.rotation=_base_rotation+_rotation_delta
	_expected_rotation=sprite.rotation

func apply_transform(scale_factor: Vector2, rotation_delta: float = 0.0) -> void:
	if not is_present():
		return
	# Multiplicative ownership preserves external scaling/layout changes.
	_merge_external_scale()
	_expected_scale = _base_scale * scale_factor
	sprite.scale = _expected_scale
	_expected_scale = sprite.scale
	_scale_factor = scale_factor
	if sprite.rotation != _expected_rotation:
		_base_rotation += sprite.rotation - _expected_rotation
	sprite.rotation = _base_rotation + rotation_delta
	# CanvasItem stores real_t; retain the actual written value for final ownership.
	_expected_rotation = sprite.rotation
	_rotation_delta = rotation_delta

## Cleanup authority is per explicit field, not every uniform on this shared Shader.
func _owns_blend_cleanup() -> bool:
	if not is_present() or _blend_material == null or sprite.material != _blend_material or _blend_shader == null or _blend_material.shader != _blend_shader:
		return false
	for name: String in ["grayscale","invert","blend_color","blend_amount"]:
		if not _blend_values.has(name) or _blend_material.get_shader_parameter(name) != _blend_values[name]:return false
	return true

func _release_blend() -> void:
	if _owns_blend_cleanup():sprite.material = _previous_material
	# A foreign current winner survives; discard only our restore authority.
	_blend_material = null;_blend_shader = null;_blend_values.clear();_previous_material = null

func apply_blend(color: Color, amount: float) -> void:
	if not is_present():
		return
	if amount <= 0 and not _owned_grayscale and not _owned_invert:
		_release_blend()
		return
	if _blend_material == null:
		_previous_material = sprite.material
		_blend_material = ShaderMaterial.new()
		_blend_material.shader = load("res://scripts/battle/animations/sequence/palette_blend.gdshader")
		_blend_shader = _blend_material.shader # Assigned by us only here, never adopted on later apply.
	if sprite.material != _blend_material:
		_previous_material = sprite.material
		sprite.material = _blend_material
	_blend_material.set_shader_parameter("grayscale",_owned_grayscale)
	_blend_material.set_shader_parameter("invert",_owned_invert)
	_blend_material.set_shader_parameter("blend_color", color)
	_blend_material.set_shader_parameter("blend_amount", clampf(amount, 0, 1))
	# Store actual post-write values, including real_t uniform rounding.
	_blend_values = {"grayscale":_blend_material.get_shader_parameter("grayscale"),"invert":_blend_material.get_shader_parameter("invert"),"blend_color":_blend_material.get_shader_parameter("blend_color"),"blend_amount":_blend_material.get_shader_parameter("blend_amount")}

func apply_source_state(property: String, value: bool) -> void:
	if not is_present():return
	if hidden_projection!=null and property in ["visible","hidden"]:
		if property=="hidden" and not value:hidden_projection.release_view()
		else:hidden_projection.write(value if property=="visible" else false)
		return
	if property=="grayscale":
		_owned_grayscale = value
		apply_blend(Color.WHITE,0.0)
	elif property=="invert":
		_owned_invert = value
		apply_blend(Color.WHITE,0.0)
	elif property=="visible":
		# Explicit source show/hide owns a write; unlike hidden=false (release).
		if not _owned_hidden or sprite.visible != _expected_visible:
			_base_visible = sprite.visible
		_owned_hidden = true
		_expected_visible = value
		sprite.visible = value
	elif property=="hidden":
		if not value:
			_release_source_visibility()
			return
		# Visibility is captured at the first owned mutation, not construction.
		# Repeated source writes preserve any intervening external value as base.
		if not _owned_hidden or sprite.visible != _expected_visible:
			_base_visible = sprite.visible
		_owned_hidden = true
		_expected_visible = false
		sprite.visible = _expected_visible

func _release_source_visibility() -> void:
	if hidden_projection!=null:hidden_projection.release_view();return
	if not _owned_hidden: return
	# Restore only a value this owner still controls. Unowned visibility and
	# differing external replacements survive completion, cancellation and exit.
	if is_present() and sprite.visible == _expected_visible:
		sprite.visible = _base_visible
	_owned_hidden = false

func release() -> void:
	if _owned_layer and is_present() and sprite.z_index == _expected_layer:
		sprite.z_index = _previous_layer
	_owned_layer = false
	_release_source_visibility()
	# Apply-time contribution merging remains additive/multiplicative. Final
	# release is different: a last external literal is not our owned delta.
	# Same-value external writes cannot be distinguished without a writer token.
	if is_present():
		if sprite.position==_expected_position:sprite.position=_base_position
		if sprite.scale==_expected_scale:sprite.scale=_base_scale
		if sprite.rotation==_expected_rotation:sprite.rotation=_base_rotation
		if sprite.modulate==_expected_color:sprite.modulate=_base_color
		_base_position=sprite.position;_expected_position=sprite.position
		_base_scale=sprite.scale;_expected_scale=sprite.scale
		_base_rotation=sprite.rotation;_expected_rotation=sprite.rotation
		_base_color=sprite.modulate;_expected_color=sprite.modulate
	_offset=Vector2.ZERO;_scale_factor=Vector2.ONE;_rotation_delta=0.0;_tint=Color.WHITE
	_owned_grayscale=false;_owned_invert=false
	_release_blend()

func apply_source_layer(layer: int) -> void:
	if not is_present(): return
	if not _owned_layer or sprite.z_index != _expected_layer:
		_previous_layer = sprite.z_index
	_owned_layer = true
	_expected_layer = layer
	sprite.z_index = layer

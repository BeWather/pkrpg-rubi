extends RefCounted
class_name BattleSourceCoordinateContract
## Optional native logical-layout projection, returned in FIELD coordinates.
## No render-origin, Electric or species-visual anchor semantics are redefined.

static func bind(actor: BattleAnimationActor, field: Node2D, layout: Node2D, point: Vector2) -> Dictionary:
	return {"actor":weakref(actor), "sprite":weakref(actor.sprite), "sprite_parent":weakref(actor.sprite.get_parent()), "field":weakref(field), "layout":weakref(layout), "point":point}

static func nominal(actor: BattleAnimationActor, context) -> Dictionary:
	# Untyped context avoids a preload cycle with the provider-owning Context.
	if not is_instance_valid(actor): return {"state":"invalid"}
	if not context.source_nominal.has(actor.id): return {"state":"missing"}
	var binding: Variant = context.source_nominal[actor.id]
	if not binding is Dictionary: return {"state":"invalid"}
	for key: String in ["actor", "sprite", "sprite_parent", "field", "layout"]:
		if not binding.get(key) is WeakRef: return {"state":"invalid"}
	if context.actors.get(actor.id) != actor or binding.actor.get_ref() != actor or not actor.is_present():
		return {"state":"invalid"}
	if binding.sprite.get_ref() != actor.sprite or binding.sprite_parent.get_ref() != actor.sprite.get_parent():
		return {"state":"invalid"}
	var field: Node2D = binding.field.get_ref() as Node2D
	var layout: Node2D = binding.layout.get_ref() as Node2D
	if not is_instance_valid(field) or field != context.field or not field.is_inside_tree() or not is_instance_valid(layout) or not layout.is_inside_tree():
		return {"state":"invalid"}
	if layout != field and not field.is_ancestor_of(layout): return {"state":"invalid"}
	if not binding.get("point") is Vector2: return {"state":"invalid"}
	var point: Vector2 = field.to_local(layout.to_global(binding.point))
	if not point.is_finite(): return {"state":"invalid"}
	return {"state":"valid", "point":point}

static func to_owner(field: Node2D, owner: Node2D, point: Vector2) -> Vector2:
	# Build source offsets AND motion in FIELD units before this single conversion.
	return owner.to_local(field.to_global(point))

## Optional BODY baseline, distinct from nominal and texture/render centers.
## Callers supply a layout point before playback; ART scale/pivot/offset never
## participates in resolving it. Live layout ancestors still participate.
static func bind_visual(actor: BattleAnimationActor, field: Node2D, layout: Node2D, point: Vector2) -> Dictionary:
	var binding: Dictionary = bind(actor,field,layout,point)
	binding.slot = weakref(actor.slot) if is_instance_valid(actor.slot) else null
	binding.had_slot = is_instance_valid(actor.slot)
	binding.generation = actor.slot.animation_generation if binding.had_slot else int(actor.sprite.get_meta("animation_generation",0))
	binding.texture = weakref(actor.sprite.texture) if actor.sprite.texture!=null else null
	binding.frame = _visual_frame(actor.sprite)
	return binding

static func _visual_frame(sprite: Sprite2D) -> Array:
	return [sprite.centered,sprite.offset,sprite.hframes,sprite.vframes,sprite.frame,sprite.region_enabled,sprite.region_rect,sprite.flip_h,sprite.flip_v]

static func visual(actor: BattleAnimationActor, context) -> Dictionary:
	if not is_instance_valid(actor):return {"state":"invalid"}
	if not context.source_visual.has(actor.id):return {"state":"missing"}
	var binding: Variant = context.source_visual[actor.id]
	if not binding is Dictionary:return {"state":"invalid"}
	for key: String in ["actor","sprite","sprite_parent","field","layout","texture"]:
		if not binding.get(key) is WeakRef:return {"state":"invalid"}
	if context.actors.get(actor.id)!=actor or binding.actor.get_ref()!=actor or not actor.is_present():return {"state":"invalid"}
	if binding.sprite.get_ref()!=actor.sprite or binding.sprite_parent.get_ref()!=actor.sprite.get_parent() or binding.texture.get_ref()!=actor.sprite.texture:return {"state":"invalid"}
	if _visual_frame(actor.sprite)!=binding.get("frame"):return {"state":"invalid"}
	if bool(binding.get("had_slot",false)):
		if not binding.get("slot") is WeakRef:return {"state":"invalid"}
		var slot: Variant = binding.slot.get_ref()
		if not is_instance_valid(slot) or actor.slot!=slot or slot.sprite_pokemon!=actor.sprite or slot.animation_generation!=binding.generation:return {"state":"invalid"}
	elif actor.slot!=null or int(actor.sprite.get_meta("animation_generation",0))!=int(binding.get("generation",-1)):
		return {"state":"invalid"}
	var field: Node2D = binding.field.get_ref() as Node2D
	var layout: Node2D = binding.layout.get_ref() as Node2D
	if not is_instance_valid(field) or field!=context.field or not field.is_inside_tree() or not is_instance_valid(layout) or not layout.is_inside_tree():return {"state":"invalid"}
	if layout!=field and not field.is_ancestor_of(layout):return {"state":"invalid"}
	if not binding.get("point") is Vector2:return {"state":"invalid"}
	var point: Vector2 = field.to_local(layout.to_global(binding.point))
	return {"state":"valid","point":point} if point.is_finite() else {"state":"invalid"}

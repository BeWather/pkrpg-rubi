extends RefCounted
## Producer pixel provenance, not source-command or appearance authority.
const KEY="source_transform_pixel_receipt"
const FRAME=["hframes","vframes","frame","region_enabled","region_rect","flip_h","flip_v"]

class Record extends RefCounted:
	var processed: WeakRef
	var recipient: WeakRef
	var parent: WeakRef
	var donor: WeakRef
	var slot: WeakRef
	var raw: Image
	var dimensions: Vector2i
	var format: int
	var digest: String
	var raw_digest: String
	var amount: float
	var selected_view: String
	var recipient_id: int
	var side: int
	var source_position: int
	var generation: int
	var post_frame: Dictionary
	var committed_token: String=""
	var revoked: bool=false

static func _digest(image: Image) -> String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(image.get_data())
	return hash.finish().hex_encode()

static func revoke(sprite: Sprite2D) -> void:
	if not is_instance_valid(sprite):return
	var candidates: Array=[sprite.texture]
	var state: Variant=sprite.get_meta("source_presentation_state",{})
	if state is Dictionary:
		if state.get("previous") is Dictionary:candidates.append(state.previous.get("texture"))
		if state.get("substitute_state") is Dictionary and state.substitute_state.get("previous") is Dictionary:candidates.append(state.substitute_state.previous.get("texture"))
	for texture: Variant in candidates:
		if not texture is Texture2D or not texture.has_meta(KEY):continue
		var receipt: Variant=texture.get_meta(KEY)
		if receipt is Record and receipt.recipient.get_ref()==sprite:receipt.revoked=true

static func attach(texture: Texture2D,image: Image,actor: BattleAnimationActor,donor: Sprite2D,c: BattleAnimationContext,selected: Dictionary,coefficient: float) -> void:
	var receipt:=Record.new();receipt.processed=weakref(texture);receipt.recipient=weakref(actor.sprite);receipt.parent=weakref(actor.sprite.get_parent());receipt.donor=weakref(donor)
	if is_instance_valid(actor.slot):receipt.slot=weakref(actor.slot)
	receipt.raw=image;receipt.raw_digest=_digest(image);receipt.amount=coefficient;receipt.selected_view=str(selected.selected_view)
	var processed_image: Image=texture.get_image();receipt.dimensions=processed_image.get_size();receipt.format=processed_image.get_format();receipt.digest=_digest(processed_image)
	receipt.recipient_id=actor.id;receipt.side=actor.side;receipt.source_position=c.source_position(actor.id);receipt.generation=actor._generation
	receipt.post_frame={"hframes":1,"vframes":1,"frame":0,"region_enabled":false,"region_rect":actor.sprite.region_rect,"flip_h":bool(selected.flip_h),"flip_v":actor.sprite.flip_v}
	texture.set_meta(KEY,receipt)

static func _frame_matches(frame: Dictionary,expected: Dictionary) -> bool:
	for key: String in FRAME:
		if not frame.has(key) or not expected.has(key) or frame[key]!=expected[key]:return false
	return true

static func _outer(sprite: Sprite2D,actor: BattleAnimationActor,state: Dictionary) -> bool:
	if not state.get("texture") is Texture2D or state.texture!=sprite.texture or not state.get("token") is String or state.token.is_empty() or sprite.get_meta("source_appearance_owner","")!=state.token:return false
	if typeof(state.get("generation")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(state.generation)) or float(state.generation)!=float(actor._generation):return false
	var fields: Dictionary={}
	for key: String in FRAME:fields[key]=sprite.get(key)
	return state.get("frame_properties") is Dictionary and _frame_matches(state.frame_properties,fields)

static func _selected_state(sprite: Sprite2D,actor: BattleAnimationActor) -> Dictionary:
	var state: Variant=sprite.get_meta("source_presentation_state",{})
	if not state is Dictionary or not _outer(sprite,actor,state):return {}
	match str(state.get("kind","")):
		"transform":return {"state":state,"frame":state.frame_properties,"texture":state.texture}
		"substitute":
			var previous: Variant=state.get("previous")
			if not previous is Dictionary or not previous.get("presentation_state") is Dictionary:return {}
			var inner: Dictionary=previous.presentation_state
			if inner.get("kind")!="transform" or not inner.get("texture") is Texture2D or inner.texture!=previous.get("texture") or not inner.get("frame_properties") is Dictionary or not _frame_matches(previous,inner.frame_properties):return {}
			# A new outer doll token does not replace its paired Transform token.
			return {"state":inner,"frame":inner.frame_properties,"texture":previous.texture}
		"substitute_mon":
			var underlying: Variant=state.get("underlying_presentation");var doll: Variant=state.get("substitute_state")
			if not underlying is Dictionary or not doll is Dictionary or underlying.get("kind")!="transform" or not doll.get("previous") is Dictionary:return {}
			var paired: Dictionary=doll.previous
			if not paired.get("presentation_state") is Dictionary or paired.presentation_state.get("token")!=underlying.get("token") or paired.get("texture")!=underlying.get("texture") or state.texture!=underlying.get("texture"):return {}
			return {"state":underlying,"frame":state.frame_properties,"texture":state.texture}
	return {}

static func presentation(actor: BattleAnimationActor,c: BattleAnimationContext) -> Dictionary:
	if not actor.is_present() or c.actors.get(actor.id)!=actor:return {}
	var selected: Dictionary=_selected_state(actor.sprite,actor)
	if selected.is_empty():revoke(actor.sprite);return {}
	if not selected.texture.has_meta(KEY):return {}
	var receipt: Variant=selected.texture.get_meta(KEY)
	if not receipt is Record or receipt.revoked:return {}
	var state: Dictionary=selected.state
	var image: Image=selected.texture.get_image()
	var generation: int=actor.slot.animation_generation if is_instance_valid(actor.slot) else int(actor.sprite.get_meta("animation_generation",0))
	var bound: bool=receipt.processed.get_ref()==selected.texture and receipt.recipient.get_ref()==actor.sprite and receipt.parent.get_ref()==actor.sprite.get_parent() and receipt.recipient_id==actor.id and receipt.side==actor.side and receipt.source_position==c.source_position(actor.id) and receipt.generation==generation and (receipt.slot.get_ref()==actor.slot if receipt.slot!=null else actor.slot==null)
	var pixels: bool=image!=null and receipt.raw!=null and image.get_size()==receipt.dimensions and receipt.raw.get_size()==receipt.dimensions and image.get_format()==receipt.format and _digest(image)==receipt.digest and _digest(receipt.raw)==receipt.raw_digest and receipt.amount==6.0/16.0 and receipt.selected_view in ["front","back"]
	var token: Variant=state.get("token")
	var stage: bool=token is String and not token.is_empty() and typeof(state.get("generation")) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(state.generation)) and float(state.generation)==float(receipt.generation) and _frame_matches(selected.frame,receipt.post_frame) and (receipt.committed_token.is_empty() or receipt.committed_token==token)
	if not bound or not pixels or not stage:receipt.revoked=true;return {}
	receipt.committed_token=token
	# Selection is transient; no Texture/Actor/state/context is kept in Record.
	return {"texture":selected.texture,"raw":receipt.raw,"producer_view":receipt.selected_view}

extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Shared fast path for admitted whole-program proofs of the source compositions.
## The canonical shape scan stays the authority: this only proves, cheaply, that the live
## program still equals the one a session already admitted. Any mismatch falls back to it.
class Proof extends RefCounted:
	var keys: Array=[]
	var rect_keys: Dictionary={}
	var guards: Array=[]
# Nobody else holds step textures, so ResourceCache drops them and every load(path) in a
# shape scan re-decoded the PNG from disk (~1 ms each).
static var _textures: Dictionary={}
static func texture(raw: Variant) -> Texture2D:
	if raw is Texture2D:return raw
	if typeof(raw)!=TYPE_STRING or not ResourceLoader.exists(raw):return null
	var cached: Variant=_textures.get(raw)
	if cached is Texture2D and is_instance_valid(cached):return cached
	var loaded: Texture2D=load(raw) as Texture2D
	if loaded!=null:_textures[raw]=loaded
	return loaded
static func _size(raw: Variant) -> Vector2:
	var t: Texture2D=texture(raw)
	return t.get_size() if t!=null else Vector2.ZERO
## Captures key order/type and texture dimensions of a program already proven canonical.
static func capture(program: Array) -> Proof:
	var proof:=Proof.new();var by_raw: Dictionary={}
	for pc: int in program.size():
		var step: Dictionary=program[pc]
		proof.keys.append(step.keys())
		if step.get("frame_rects") is Dictionary:proof.rect_keys[pc]=step.frame_rects.keys()
		var raw: Variant=step.get("texture")
		if raw==null:continue
		if not by_raw.has(raw):
			var guard: Dictionary={"raw":raw,"size":_size(raw),"pcs":[]}
			by_raw[raw]=guard;proof.guards.append(guard)
		by_raw[raw].pcs.append(pc)
	return proof
## True only when steps, definition and the admitted snapshot are natively equal, key
## order/types are unchanged and every texture keeps its dimensions (or its steps still
## pass rects_ok(pc,step)). False means "ask the full scan", never "invalid".
static func holds(steps: Array,definition_steps: Array,program: Array,proof: Proof,rects_ok: Callable) -> bool:
	if proof==null or steps.size()!=program.size() or proof.keys.size()!=steps.size() or steps!=definition_steps or steps!=program:return false
	for pc: int in steps.size():
		var step: Variant=steps[pc]
		if not step is Dictionary or step.keys()!=proof.keys[pc]:return false
		if proof.rect_keys.has(pc) and (not step.get("frame_rects") is Dictionary or step.frame_rects.keys()!=proof.rect_keys[pc]):return false
	for guard: Dictionary in proof.guards:
		var size: Vector2=_size(guard.raw)
		if size.x<=0 or size.y<=0:return false
		if size==guard.size:continue
		for pc: int in guard.pcs:
			if not rects_ok.call(pc,steps[pc]):return false
		guard.size=size
	return true

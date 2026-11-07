extends RefCounted
class_name BattleAnimationSequenceRegistry
## Stable Ruby IDs + aliases from real DB data, explicit custom overrides.
## Compartida: key_for_move() (clave de animación del movimiento) y get_definition() (metadatos como
## source_script) se usan en producción y por las animaciones nativas. Crear y registrar animaciones de la VM
## legada (animation_for_key(), register_definition()) está obsoleto. Ver scripts/battle/animations/sequence/README.md.

static var _definitions: Dictionary = {}
static var _catalog: Array = []
static var _aliases: Dictionary = {}
static var _overrides: Dictionary = {}
static var _loaded := false
static var _builtin_source_definitions: Dictionary = {}

static func _load_data() -> void:
	if _loaded:
		return
	_loaded = true
	_builtin_source_definitions.clear()
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://recursos/animaciones/move_catalog.json"))
	_catalog = catalog.get("moves", [])
	for entry in _catalog:
		_aliases[str(entry.internal).to_upper()] = "ruby:move/%d" % int(entry.id)
		if not str(entry.ruby_name).is_empty():
			_aliases[str(entry.ruby_name)] = "ruby:move/%d" % int(entry.id)
	var entries: Array = []
	for path in ["res://recursos/animaciones/pilots.json", "res://recursos/animaciones/contact_slice.json", "res://recursos/animaciones/auxiliary_phases.json"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		entries.append_array(data.get("definitions", []))
	for entry in entries:
		var definition := BattleAnimationDefinition.new()
		definition.key = entry.key
		definition.coverage = entry.coverage
		definition.source_script = entry.source_script
		definition.steps.assign(entry.steps)
		if definition.key=="ruby:move/99":
			definition.steps.push_front({"op":"effect","behavior":"source_counter_selected","mode":"alpha","blend_pair":[12,8],"source_args":[],"ticks":1})
			definition.steps.push_front({"op":"effect","behavior":"source_counter_selected","mode":"monbg","source_args":[1],"ticks":1})
			definition.steps.append({"op":"effect","behavior":"source_counter_selected","mode":"clear_monbg","source_args":[1],"ticks":1})
			definition.steps.append({"op":"wait","ticks":2})
		_definitions[definition.key] = definition
		_builtin_source_definitions.erase(definition.key)
		if definition.key.begins_with("ruby:") and definition.coverage == "source-derived-unreviewed":
			_builtin_source_definitions[definition.key] = definition

## @deprecated: camino de la VM legada; las animaciones nativas no lo usan. Se conserva como referencia y fallback de configuración. Ver scripts/battle/animations/sequence/README.md.
static func is_builtin_source_definition(definition: BattleAnimationDefinition) -> bool:
	_load_data()
	return definition != null and _builtin_source_definitions.get(definition.key) == definition

## @deprecated: camino de la VM legada; las animaciones nativas no lo usan. Se conserva como referencia y fallback de configuración. Ver scripts/battle/animations/sequence/README.md.
static func phase_catalog() -> Array:
	_load_data()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://recursos/animaciones/auxiliary_phases.json"))
	return data.get("phases", []).duplicate(true)

static func catalog() -> Array:
	_load_data()
	return _catalog.duplicate(true)

## @deprecated: camino de la VM legada; las animaciones nativas no lo usan. Se conserva como referencia y fallback de configuración. Ver scripts/battle/animations/sequence/README.md.
static func register_definition(definition: BattleAnimationDefinition, override_key: String = "") -> String:
	_load_data()
	var error := definition.validation_error(BattleEffectBehaviorRegistry.factories())
	if not error.is_empty():
		return error
	# Public registration expresses literal custom intent, even for the same Resource.
	_builtin_source_definitions.erase(definition.key)
	_definitions[definition.key] = definition
	if not override_key.is_empty():
		_overrides[override_key] = definition.key
	return ""

static func key_for_move(move: Movimiento) -> String:
	_load_data()
	if move == null:
		return ""
	var explicit: String = move.datos.get("animation_key", "")
	if not explicit.is_empty():
		return explicit
	return str(_aliases.get(move.get_nombre_interno().to_upper(), ""))

static func get_definition(key: String, status: bool = false) -> BattleAnimationDefinition:
	_load_data()
	var resolved: String = _overrides.get(key, key)
	if _definitions.has(resolved):
		return _definitions[resolved]
	var fallback := BattleAnimationDefinition.new()
	fallback.key = key if not key.is_empty() else "fallback:unknown"
	fallback.coverage = "fallback"
	fallback.steps.assign([
		{"op": "effect", "behavior": "ring" if status else "impact", "selector": "target", "ticks": 18},
		{"op": "marker", "name": "presented" if status else "impact"},
		{"op": "barrier"},
	])
	return fallback

## @deprecated: crea la animación de la VM legada. Solo se llega aquí por fallback de configuración (opción batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion) o fuera de producción (MoveAnimationRegistry.obtener_animacion() sin contexto, play_key() en laboratorio, comparador y tests). Ver scripts/battle/animations/sequence/README.md.
static func animation_for_key(key: String, status: bool = false) -> BattleSequenceAnimation:
	var animation := BattleSequenceAnimation.new()
	animation.definition = get_definition(key, status)
	return animation

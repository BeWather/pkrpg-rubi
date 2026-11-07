extends MoveAnimation
class_name BattleSequenceAnimation
## Legacy-compatible handle, also usable without battle/domain dependencies.
## Compartida: AnimacionAuxiliarNativa la extiende y los llamadores esperan esta API (state, definition, markers,
## wait_marker(), cancel()/skip()). Solo la reproducción con BattleAnimationSequenceRunner es de la VM legada
## (obsoleta). Ver scripts/battle/animations/sequence/README.md.

signal marker(record: Dictionary)
var definition: BattleAnimationDefinition
var runner: BattleAnimationSequenceRunner
var state := "pending"
var markers: Array[Dictionary] = []
var diagnostic := ""
var lifecycle_aborted := false

## @deprecated: camino de la VM legada; las animaciones nativas no lo usan. Se conserva como referencia y fallback de configuración. Ver scripts/battle/animations/sequence/README.md.
func reproducir(legacy: MoveAnimationContext, resultado: ResultadoMovimiento) -> void:
	var context:=BattleAnimationContext.from_legacy(legacy)
	context.source_presentation_commit=resultado==null or (resultado.hit and resultado.effectiveness>0)
	play_context(context)

## @deprecated: reproducción con la VM legada (crea un BattleAnimationSequenceRunner). AnimacionAuxiliarNativa la sobrescribe con la escena nativa; se conserva como fallback de configuración, laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.
func play_context(context: BattleAnimationContext) -> void:
	if definition!=null and definition.key.begins_with("ruby:status/"):context.set_meta("source_status_anim_active",true)
	if state != "pending":
		return
	if not is_instance_valid(context.field) or not context.field.is_inside_tree():
		_complete("failed")
		return
	var previous: Variant = context.field.get_meta("active_move_animation") if context.field.has_meta("active_move_animation") else null
	if previous is WeakRef:
		var active = previous.get_ref()
		if is_instance_valid(active):
			active.cancel()
	context.field.set_meta("active_move_animation", weakref(self))
	state = "running"
	runner = BattleAnimationSequenceRunner.new()
	if has_meta("source_transform_guard_required"):
		runner.set_meta("source_transform_guard_required",true)
		var snapshot: Dictionary=get_meta("source_transform_snapshot",{})
		if snapshot.get("guard")!=null:runner.set_meta("source_transform_guard",snapshot.guard)
		if snapshot.has("buffer"):context.set_meta("source_transform_buffer",snapshot.buffer)
	# Native primary playback is deferred by the director. Carry only this
	# command's accepted appearance guard into its newly constructed runner.
	if has_meta("source_substitute_guard_required"):
		runner.set_meta("source_substitute_guard_required",get_meta("source_substitute_guard_required"))
		if has_meta("source_substitute_guard"):runner.set_meta("source_substitute_guard",get_meta("source_substitute_guard"))
	context.field.add_child(runner)
	runner.marker_reached.connect(_on_marker)
	runner.terminated.connect(_complete)
	runner.start(definition, context)

func _on_marker(record: Dictionary) -> void:
	markers.append(record)
	if record.name == "impact" and not _impacto_emitido:
		_emitir_impacto()
	marker.emit(record)

func _complete(terminal_state: String) -> void:
	if state in ["completed", "cancelled", "failed"]:
		return
	# Lock terminal state before compatibility impact can invoke user callbacks.
	state = terminal_state
	if is_instance_valid(runner):
		diagnostic = runner.error_message
		lifecycle_aborted = runner.lifecycle_aborted
	# Compatibility: a skipped/non-damaging/failed presentation must never
	# strand the old turn controller. This signal never mutates domain state.
	if not _impacto_emitido:
		_emitir_impacto()
	_emitir_finalizada()

func cancel() -> void:
	if is_instance_valid(runner) and runner.state == "running":
		runner.finish("cancelled")
	else:
		_complete("cancelled")

func skip() -> void:
	if is_instance_valid(runner) and runner.state == "running":
		runner.finish("completed")
	else:
		_complete("completed")

func wait_marker(marker_name: String) -> Dictionary:
	while not _finalizada_emitida:
		for record in markers:
			if record.name == marker_name:
				return record
		await marker_or_finished()
	for record in markers:
		if record.name == marker_name:
			return record
	return {"name": marker_name, "state": state, "missing": true}

func marker_or_finished() -> void:
	# Both marker and terminal events wake the same waiter.
	if not _finalizada_emitida:
		await _progress

signal _progress

func _init() -> void:
	marker.connect(_notify_marker)
	finalizada.connect(_notify_finished)

func _notify_marker(_record: Dictionary) -> void:
	_progress.emit()

func _notify_finished() -> void:
	_progress.emit()

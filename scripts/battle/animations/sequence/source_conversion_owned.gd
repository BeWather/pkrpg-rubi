extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Local OBJ first-target alpha plus literal five-bit tagged-palette blend.
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if s.behavior=="source_conversion_task":
		var tasks: Array[Dictionary]=BattleStateProps.create_control(s,c,owner)
		for t: Dictionary in tasks:
			t.update=update_control.bind(owner)
			# Shared construction applies opacity immediately; restore OBJ blending
			# in the creation tick too, not only on subsequent task updates.
			update_control(t,c,owner)
		return tasks
	var binding: Dictionary=s.duplicate(true);binding.behavior="source_particle"
	var tracks: Array[Dictionary]=BattleEffectBehaviorRegistry.factories().source_particle.call(binding,c,owner)
	for t: Dictionary in tracks:
		BattleCounterSelected._blend_node(t.node,owner);t.node.material.shader=load("res://scripts/battle/animations/sequence/source_conversion_blend.gdshader");t.update=update_particle;t.node.modulate.a=1.0
	return tracks
static func update_particle(t: Dictionary,_context: BattleAnimationContext) -> void:
	BattleSourceParticle.update(t)
	t.node.modulate.a=1.0
static func update_control(t: Dictionary,c: BattleAnimationContext,owner: Node2D) -> void:
	BattleStateProps.update_control(t,c,owner)
	if t.settings.task_mode!="conversion_alpha":return
	var alpha: int=int(owner.get_meta("source_prop_alpha",{}).get(str(t.settings.source_palette_tag),16))
	owner.set_meta("source_counter_alpha",[alpha,16-alpha])
	for item: Dictionary in owner.get_meta("source_counter_blend_nodes",[]):
		if is_instance_valid(item.node) and item.node.material==item.material:
			item.node.modulate.a=1.0;item.material.set_shader_parameter("eva",float(alpha)/16);item.material.set_shader_parameter("evb",float(16-alpha)/16)

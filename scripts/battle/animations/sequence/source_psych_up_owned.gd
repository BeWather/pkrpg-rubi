extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Local Psych Up commands, objMode1 spiral and faded OBJ→opaque monbg palette maintenance.
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if s.behavior=="source_psych_up_command":return BattleCounterSelected.create(s,c,owner)
	if s.behavior=="source_psych_up_spiral":
		var tracks: Array[Dictionary]=BattleEffectBehaviorRegistry._create(s,c,owner,"source_particle")
		for t: Dictionary in tracks:BattleCounterSelected._blend_node(t.node,owner)
		return tracks
	var tracks: Array[Dictionary]=BattleEffectBehaviorRegistry._create(s,c,owner,"source_palette")
	for t: Dictionary in tracks:t.kind="source_psych_up_palette";t.original_actor=t.actor;t.erase("actor");t.owner=owner;t.update=advance
	return tracks
static func advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	var palette: Dictionary=t.duplicate();palette.actor=t.original_actor;t.owner._source_palette(palette)
	var held: Dictionary=t.owner._held_blends.get(t.original_actor.id,{})
	for bg: Dictionary in t.owner.get_meta("source_counter_monbg",[]):
		for entry: Dictionary in bg.clones:
			if entry.actor!=t.original_actor:continue
			if not entry.has("psych_up_palette"):
				var material:=ShaderMaterial.new();material.shader=load("res://scripts/battle/animations/sequence/palette_blend.gdshader");entry.psych_up_palette=material;entry.node.material=material
			entry.psych_up_palette.set_shader_parameter("blend_color",held.get("color",Color.WHITE));entry.psych_up_palette.set_shader_parameter("blend_amount",float(held.get("amount",0.0)))

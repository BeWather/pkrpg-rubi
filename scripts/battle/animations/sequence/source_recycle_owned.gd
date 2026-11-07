extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Move278-only command/palette projection; existing arrow owns local EVA/EVB.
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if s.behavior=="source_recycle_command":return BattleCounterSelected.create(s,c,owner)
	var actors: Array[BattleAnimationActor]=c.resolve("attacker")
	if actors.is_empty():return []
	var actor: BattleAnimationActor=actors[0]
	var t: Dictionary={"kind":"source_recycle_palette","settings":s,"owner":owner,"original_actor":actor,"age":0,"ticks":49,"update":advance,"clones":[]}
	var material:=ShaderMaterial.new();material.shader=load("res://scripts/battle/animations/sequence/source_celestial_heal.gdshader");material.set_shader_parameter("color5",Vector3(31,31,31));material.set_shader_parameter("amount",0.0);material.set_shader_parameter("eva",1.0);material.set_shader_parameter("evb",0.0)
	t.material=material;t.lease=BattleOwnedMaterialLease.attach(actor,material)
	# monbg maintenance copies the original OBJ palette into its opaque BG.
	for bg: Dictionary in owner.get_meta("source_counter_monbg",[]):
		for clone: Dictionary in bg.clones:
			if clone.actor==actor:t.clones.append({"node":clone.node,"previous":clone.node.material});clone.node.material=material
	t.cleanup=cleanup.bind(t)
	return [t]
static func advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	if not t.original_actor.is_present():t.ticks=int(t.age);return
	var changes: int=int(t.age)/2
	t.material.set_shader_parameter("amount",float(changes if changes<=12 else maxi(0,24-changes)))
static func cleanup(t: Dictionary) -> void:
	t.erase("cleanup");t.lease.release()
	for clone: Dictionary in t.clones:
		if is_instance_valid(clone.node) and clone.node.material==t.material:clone.node.material=clone.previous

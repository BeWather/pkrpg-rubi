extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## atk277's actual orange wall callback promotes fixed opposing banks, not its target.
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if s.behavior=="source_magic_coat_command":return BattleCounterSelected.create(s,c,owner)
	var binding: Dictionary=s.duplicate(true);binding.behavior="source_particle"
	var tracks: Array[Dictionary]=BattleEffectBehaviorRegistry.factories().source_particle.call(binding,c,owner)
	for track: Dictionary in tracks:
		track.update=_wall_update
		_wall_update(track,c) # Source synchronous creation pose; age stays0.
	var bg: Dictionary={"kind":"source_magic_coat_bg","domain":"maintenance","owner":owner,"age":0,"ticks":int(s.ticks),"clones":[],"update":BattleCounterSelected._bg_update}
	for actor: BattleAnimationActor in c.actors.values():
		if c.contest or actor.side!=1 or not actor.is_present() or not actor.sprite.is_visible_in_tree():continue
		var node: Sprite2D=BattleIdentityCopy.clone_sprite(actor,owner);owner.add_child(node)
		node.z_index=BattleSourcePriority.relative_layer(actor,1,c,owner);node.modulate=actor.sprite.modulate
		bg.clones.append({"actor":actor,"node":node});actor.apply_source_state("hidden",true)
	if not bg.clones.is_empty():bg.cleanup=BattleCounterSelected._bg_cleanup.bind(bg);tracks.append(bg)
	return tracks

static func _wall_update(track: Dictionary,_context: BattleAnimationContext) -> void:
	BattleSourceParticle.update(track)
	# Creation invokes DB88C with coefficient0; subsequent source ticks1..13.
	if int(track.age)>=0 and int(track.age)<14:track.node.modulate.a=mini(int(track.age),13)/16.0

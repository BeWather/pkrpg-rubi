extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Residual source selector is actual stored moveID; all bound roles are the victim.
const Bird=preload("res://scripts/battle/animations/sequence/source_bird_horn_owned.gd")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if s.behavior=="source_turn_trap_stop_sound":
		for player: AudioStreamPlayer2D in owner._sounds:
			if is_instance_valid(player):player.stop()
		return []
	if s.behavior=="source_turn_trap_selector":
		owner._source_args[0]={83:1,250:2,128:3,328:4}.get(int(c.get_meta("source_general_argument",0)),0);return []
	if s.behavior=="source_turn_trap_palette":
		var palette: Array[Dictionary]=BattleEffectBehaviorRegistry._create(s,c,owner,"source_palette")
		for t: Dictionary in palette:
			t.palette_actor=t.actor;t.erase("actor");t.owner=owner;t.kind="source_turn_trap_palette";t.update=advance
		return palette
	if s.behavior=="source_turn_trap_command":
		var command: Array[Dictionary]=BattleCounterSelected.create(s,c,owner)
		for t: Dictionary in command:t.kind="source_turn_trap_monbg";t.update=advance
		return command
	if s.behavior=="source_turn_trap_hit":
		var hits: Array[Dictionary]=Bird.create(s,c,owner)
		for t: Dictionary in hits:BattleCounterSelected._blend_node(t.node,owner)
		return hits
	var tracks: Array[Dictionary]=BattleEffectBehaviorRegistry._create(s,c,owner,"source_particle")
	for t: Dictionary in tracks:
		t.kind="source_turn_trap_particle";t.update=advance
		if bool(s.source_obj_mode1):BattleCounterSelected._blend_node(t.node,owner)
	return tracks
static func advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	if t.kind=="source_turn_trap_monbg":
		BattleCounterSelected._bg_update(t,_c);_sync_palette(t.owner);return
	if t.kind=="source_turn_trap_palette":
		if not t.palette_actor.is_present():return
		t.actor=t.palette_actor;t.owner._source_palette(t);t.erase("actor");_sync_palette(t.owner);return
	BattleSourceParticle.update(t)
	if t.settings.mode=="spiral_rise":
		var a: Array=t.settings.source_args;var age: int=maxi(0,int(t.age))
		# Callback samples initial angle0, then advances; rise accumulator advances first.
		var angle: int=((age-1)*int(a[4]))&255
		t.node.position=t.origin+Vector2(BattleSourceTrig.sine(angle,int(a[5])) if age>0 else 0,-((age*int(a[2]))>>8))

static func _sync_palette(owner: Node2D) -> void:
	# Source monbg maintenance copies the victim faded OBJ palette into its BG clone.
	# The clone stays opaque: only the selected color blend, never OBJ12/8 alpha.
	for bg: Dictionary in owner.get_meta("source_counter_monbg",[]):
		for clone: Dictionary in bg.clones:
			if not clone.actor.is_present():continue
			var held: Dictionary=owner._held_blends.get(clone.actor.id,{"color":Color.WHITE,"amount":0.0})
			clone.actor.apply_blend(held.color,float(held.amount));clone.node.material=clone.actor.sprite.material

extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Local Recover palette/OBJ alpha and Slack Off callback closure; no HP authority.
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if s.behavior=="source_recover_command":return BattleCounterSelected.create(s,c,owner)
	if s.behavior=="source_recover_orb":
		var tracks: Array[Dictionary]=BattleEffectBehaviorRegistry._create(s,c,owner,"source_particle")
		for t: Dictionary in tracks:BattleCounterSelected._blend_node(t.node,owner)
		return tracks
	var actor: BattleAnimationActor=c.resolve("attacker")[0]
	if s.behavior=="source_slack_squish":
		var motion: Dictionary=s.duplicate(true);motion.behavior="actor_motion";motion.motion="source_affine"
		var tracks: Array[Dictionary]=BattleEffectBehaviorRegistry._create(motion,c,owner,"actor_motion")
		var shake: Dictionary={"kind":"source_slack_shake","settings":s,"original_actor":actor,"owner":owner,"age":0,"ticks":56,"counter":0,"flips":0,"offset":Vector2.ZERO,"update":advance};shake.cleanup=_cleanup.bind(shake);tracks.append(shake);return tracks
	return [{"kind":"source_recover_palette","settings":s,"original_actor":actor,"owner":owner,"age":0,"ticks":4096,"amount":0,"destination":11,"obj_half":true,"finishing":-1,"cycles":6,"applied":0,"update":advance}]
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if c.actors.get(t.original_actor.id)!=t.original_actor or not t.original_actor.is_present():t.ticks=int(t.age);return
	if t.kind=="source_slack_shake":
		if int(t.age)>16 and int(t.age)<40:
			t.counter=int(t.counter)+1
			if int(t.counter)>2:t.counter=0;t.flips=int(t.flips)+1;t.offset.x=1 if int(t.flips)%2 else -1
		else:t.offset.x=0
		t.owner._held_offsets[t.original_actor.id]=t.offset;return
	# sub_80E1F8C[2,0,6,0,11,12287]: alternating halves, zero BG delay.
	# No BG bit is selected; only the attacker OBJ receives the normal fade.
	if int(t.finishing)>=0:
		t.finishing=int(t.finishing)+1
		if int(t.finishing)==6:
			t.cycles=int(t.cycles)-1
			if int(t.cycles)==0:t.ticks=int(t.age)
			else:t.destination=0 if int(t.destination)==11 else 11;t.obj_half=true;t.finishing=-1
		return
	if bool(t.obj_half):
		t.applied=int(t.amount);t.owner._held_blends[t.original_actor.id]={"color":Color8(255,255,90),"amount":float(t.applied)/16,"source_actor":t.original_actor}
		# Monbg maintenance copies the faded attacker OBJ palette to its BG copy.
		# ScriptCmd_setalpha has NO BG TGT1 bits: copies stay opaque, unlike OBJ orbs.
		for background: Dictionary in t.owner.get_meta("source_counter_monbg",[]):
			for clone: Dictionary in background.clones:
				if clone.actor!=t.original_actor:continue
				if not clone.has("restore_palette"):
					var material:=ShaderMaterial.new();material.shader=load("res://scripts/battle/animations/sequence/palette_blend.gdshader");clone.restore_palette=material;clone.node.material=material
				clone.restore_palette.set_shader_parameter("blend_color",Color8(255,255,90));clone.restore_palette.set_shader_parameter("blend_amount",float(t.applied)/16)
	t.obj_half=not bool(t.obj_half)
	if not bool(t.obj_half):
		if int(t.amount)==int(t.destination):t.finishing=0
		else:t.amount=mini(int(t.amount)+2,int(t.destination)) if int(t.amount)<int(t.destination) else maxi(int(t.amount)-2,int(t.destination))
static func _cleanup(t: Dictionary) -> void:
	t.erase("cleanup")
	if t.owner._held_offsets.get(t.original_actor.id)==t.offset:t.owner._held_offsets[t.original_actor.id]=Vector2.ZERO

extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Local Mist commands/cloud OBJ alpha and actual two-half normal palette fade.
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if s.behavior=="source_mist_command":return BattleCounterSelected.create(s,c,owner)
	if s.behavior=="source_mist_cloud":
		var tracks: Array[Dictionary]=BattleEffectBehaviorRegistry._create(s,c,owner,"source_particle")
		for t: Dictionary in tracks:BattleCounterSelected._blend_node(t.node,owner)
		return tracks
	return [{"kind":"source_mist_side_palette","settings":s,"owner":owner,"actors":c.resolve("attacker")+c.resolve("attacker_partner"),"age":0,"ticks":4096,"amount":0,"target":14,"obj_half":true,"delay_counter":0,"finishing":-1,"cycles":2,"update":advance}]
static func advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	# BeginNormalPaletteFade consumed its BG half synchronously. OBJ follows,
	# then eight delay frames, BG, OBJ: actual OBJ coefficients every ten ticks.
	if int(t.finishing)>=0:
		t.finishing=int(t.finishing)+1
		if int(t.finishing)==6:
			t.cycles=int(t.cycles)-1
			if int(t.cycles)==0:t.ticks=int(t.age)
			else:t.target=0;t.obj_half=true;t.delay_counter=0;t.finishing=-1
		return
	if not bool(t.obj_half):
		if int(t.delay_counter)<8:t.delay_counter=int(t.delay_counter)+1;return
		t.delay_counter=0;t.obj_half=true;return
	for actor: BattleAnimationActor in t.actors:
		if not actor.is_present():continue
		t.owner._held_blends[actor.id]={"color":Color.WHITE,"amount":float(t.amount)/16,"source_actor":actor}
		for bg: Dictionary in t.owner.get_meta("source_counter_monbg",[]):
			for entry: Dictionary in bg.clones:
				if entry.actor!=actor:continue
				if not entry.has("mist_palette"):
					var material:=ShaderMaterial.new();material.shader=load("res://scripts/battle/animations/sequence/palette_blend.gdshader");entry.mist_palette=material;entry.node.material=material
				entry.mist_palette.set_shader_parameter("blend_color",Color.WHITE);entry.mist_palette.set_shader_parameter("blend_amount",float(t.amount)/16)
	t.obj_half=false
	if int(t.amount)==int(t.target):t.finishing=0
	else:t.amount=int(t.amount)+(1 if int(t.amount)<int(t.target) else -1)

extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Local palette/BLDCNT composition: attacker OBJ tint reaches its maintained monBG.
static func _state(owner: Node2D) -> Dictionary:
	if not owner.has_meta("source_camouflage_state"):owner.set_meta("source_camouflage_state",{"amount":0,"tint5":Vector3(31,31,31),"mask":0,"eva":16,"evb":0})
	return owner.get_meta("source_camouflage_state")
static func _sync(owner: Node2D,c: BattleAnimationContext) -> void:
	var st: Dictionary=_state(owner)
	for bg: Dictionary in owner.get_meta("source_counter_monbg",[]):
		for item: Dictionary in bg.clones:
			if not is_instance_valid(item.node):continue
			if not item.has("camouflage_material"):
				var material:=ShaderMaterial.new();material.shader=load("res://scripts/battle/animations/sequence/source_camouflage.gdshader");item.camouflage_material=material;item.node.material=material
			var m: ShaderMaterial=item.camouflage_material;var selected: bool=(int(st.mask)&(1<<int(item.bg_plane)))!=0
			m.set_shader_parameter("eva",float(st.eva)/16 if selected else 1.0);m.set_shader_parameter("evb",float(st.evb)/16 if selected else 0.0);m.set_shader_parameter("amount",float(st.amount) if item.actor.id==c.attacker_id else 0.0);m.set_shader_parameter("tint5",st.tint5)
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var st: Dictionary=_state(owner)
	if s.behavior=="source_camouflage_command":
		var result: Array[Dictionary]=BattleCounterSelected.create(s,c,owner)
		if s.mode in ["alpha","blend_off"]:st.mask=0;st.eva=16;st.evb=0
		_sync(owner,c);return result
	var actor: BattleAnimationActor=c.resolve("attacker")[0]
	var t: Dictionary={"kind":s.behavior,"settings":s,"owner":owner,"original_actor":actor,"age":0,"ticks":4096,"update":advance,"counter":0}
	if s.behavior=="source_camouflage_palette":
		var packed: int=int(s.source_colors[int(c.get_meta("source_environment",c.environment))]);t.color=Color(float(packed&31)/31,float((packed>>5)&31)/31,float((packed>>10)&31)/31);t.current=int(s.source_args[2]);t.destination=int(s.source_args[3]);t.amount=t.current;st.tint5=Vector3(packed&31,(packed>>5)&31,(packed>>10)&31);_palette(t,c)
	else:
		t.eva=16 if s.mode=="hide" else 0;t.evb=16-int(t.eva)
		if s.mode=="hide":st.mask=1<<(1 if c.contest or c.source_position(actor.id) in [1,2] else 2)
		st.eva=t.eva;st.evb=t.evb;_sync(owner,c)
	if int(t.ticks)==0:return []
	return [t]
static func _palette(t: Dictionary,c: BattleAnimationContext) -> void:
	if int(t.counter)==int(t.settings.source_args[1]):
		t.counter=0;t.amount=int(t.current);var st: Dictionary=_state(t.owner);st.amount=t.amount;t.owner._held_blends[t.original_actor.id]={"color":t.color,"amount":float(t.amount)/16,"source_actor":t.original_actor};_sync(t.owner,c)
		if int(t.current)==int(t.destination):t.ticks=int(t.age)
		else:t.current=int(t.current)+signi(int(t.destination)-int(t.current))
	else:t.counter=int(t.counter)+1
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if t.kind=="source_camouflage_palette":_palette(t,c);return
	if int(t.counter)==int(t.settings.source_args[0]):
		t.counter=0;var hide: bool=t.settings.mode=="hide";t.eva=int(t.eva)+(-1 if hide else 1);t.evb=16-int(t.eva);var st: Dictionary=_state(t.owner);st.eva=t.eva;st.evb=t.evb;_sync(t.owner,c)
		if int(t.eva)==(0 if hide else 16):
			if hide:t.original_actor.apply_source_state("hidden",true)
			else:st.mask=0;st.eva=0;st.evb=0;_sync(t.owner,c)
			t.ticks=int(t.age)
	else:t.counter=int(t.counter)+1

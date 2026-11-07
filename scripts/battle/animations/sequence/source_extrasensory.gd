extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Exact finite source task clocks; local scanline projection, no global renderer changes.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
const Rows=preload("res://scripts/battle/animations/sequence/source_dragon_dance.gd")
static func _species(actor: BattleAnimationActor,c: BattleAnimationContext) -> String:
	var name: String=str(c.source_appearance_species.get(actor.id,""))
	return (str(c.source_party_species.get(actor.id,"")) if name.is_empty() else name).to_upper()
static func _restore_rows(t: Dictionary) -> void:
	for entry: Dictionary in t.nodes:
		if is_instance_valid(entry.node) and entry.node.material==entry.material:entry.node.material=entry.previous
static func _cleanup_rows(t: Dictionary) -> void:t.erase("cleanup");_restore_rows(t)
static func _cleanup_palette(t: Dictionary) -> void:t.erase("cleanup");t.lease.release()
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if s.behavior=="source_extrasensory_command":
		# ScriptCmd_setalpha has no BG first-target bit. Its pair belongs to
		# semitransparent OBJ only; the target monBG remains opaque.
		if s.mode in ["alpha","blend_off"]:owner.set_meta("source_counter_alpha",s.get("blend_pair",[16,0]));return []
		return BattleCounterSelected.create(s,c,owner)
	var actor: BattleAnimationActor=c.resolve("target" if s.behavior=="source_extrasensory_wave" else "attacker")[0]
	var t: Dictionary={"kind":s.behavior,"settings":s,"owner":owner,"original_actor":actor,"age":0,"ticks":int(s.ticks),"update":advance,"start_tick":owner.elapsed_ticks}
	if s.behavior=="source_extrasensory_palette":
		var material:=ShaderMaterial.new();material.shader=load("res://scripts/battle/animations/sequence/source_celestial_heal.gdshader");material.set_shader_parameter("color5",Vector3(27,27,0));material.set_shader_parameter("amount",0.0);material.set_shader_parameter("eva",1.0);material.set_shader_parameter("evb",0.0);t.material=material;t.lease=BattleOwnedMaterialLease.attach(actor,material);t.cleanup=_cleanup_palette.bind(t);return [t]
	if s.behavior=="source_extrasensory_wave":
		var center: int=int(Geometry._anchor(actor,c,owner,"origin").y)
		if actor.side!=0 and not c.contest:
			var species: String=_species(actor,c);var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(s.source_elevations)));center-=int(data.castform_forms[clampi(int(c.get_meta("source_castform_form",0)),0,3)]) if species=="CASTFORM" else int(data.by_species.get(species,0))
		t.source_top=maxi(0,center-32);t.source_bottom=center+32;t.bg_plane=1 if c.contest or c.source_position(actor.id) in [1,2] else 2;t.rows=[];t.nodes=[]
		for index: int in 65:t.rows.append(0)
		for bg: Dictionary in owner.get_meta("source_counter_monbg",[]):
			for clone: Dictionary in bg.clones:
				if int(clone.bg_plane)!=int(t.bg_plane):continue
				var material:=ShaderMaterial.new();material.shader=load("res://scripts/battle/animations/sequence/source_extrasensory_wave.gdshader");t.nodes.append({"node":clone.node,"material":material,"previous":clone.node.material});clone.node.material=material
		t.cleanup=_cleanup_rows.bind(t);Rows._project(t);return [t]
	var offsets: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(s.source_offsets)));var species: String=_species(actor,c);var side: String="back" if c.contest or actor.side==0 else "front"
	if not offsets.by_species.has(species):owner.error_message="Missing Extrasensory picture offset: "+species;owner.finish("failed");return []
	var node: Sprite2D=BattleIdentityCopy.clone_sprite(actor,owner);owner.add_child(node);node.material=BattleIdentityCopy.blend_material(false);var pair: Array=owner.get_meta("source_counter_alpha",[16,0]);node.material.set_shader_parameter("eva",float(pair[0])/16);node.material.set_shader_parameter("evb",float(pair[1])/16);node.z_index=BattleSourcePriority.relative_layer(actor,1,c,owner)
	t.node=node;t.origin=node.position;t.base_scale=node.scale;t.raw_matrix=256;t.height=64-2*int(offsets.by_species[species][side]);return [t]
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if t.kind=="source_extrasensory_palette":t.material.set_shader_parameter("amount",float(int(t.age) if int(t.age)<=12 else 24-int(t.age)));return
	if t.kind=="source_extrasensory_wave":
		if int(t.age)<=24:
			var mode: int=int(t.settings.source_args[0]);var params: Array=t.settings.source_wave_parameters[mode];var angle: int=int(params[2]);var counter: int=(int(t.age)-1)&3
			for index: int in mini(65,int(t.source_bottom)-int(t.source_top)+1):
				# Case1's final row addresses index320 outside the declared source
				# table. Zero is a bounded native projection, not verified ROM adjacency.
				var sample: int=BattleSourceTrig.VALUES[angle] if angle<320 else 0;var v: int=sample>>int(params[1]);t.rows[index]=v+(counter if v>0 else -counter if v<0 else 0);angle+=int(params[0])
			Rows._project(t)
		elif int(t.age)==25:_restore_rows(t)
		return
	if int(t.age)<=24:
		var phase: int=int(t.age)*4 if int(t.age)<=12 else (24-int(t.age))*4;t.raw_matrix=256-(BattleSourceTrig.VALUES[phase]>>1);var projected: int=mini(128,int(t.height)*256/int(t.raw_matrix));t.node.scale=t.base_scale*(256.0/float(t.raw_matrix));t.node.position=t.origin+Vector2(0,(int(t.height)-projected)/2)
	elif int(t.age)==25:t.node.queue_free()

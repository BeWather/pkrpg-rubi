extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## General1 uses a BG1 image inside an actor OBJ-window silhouette, not OBJ recoloring.
static func _cleanup(t: Dictionary) -> void:
	t.erase("cleanup")
	if t.has("partner") and t.partner.is_present() and t.partner.sprite.z_index==int(t.partner_owned_z):t.partner.sprite.z_index=int(t.partner_previous_z)
	if t.has("node") and is_instance_valid(t.node):t.node.queue_free()
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var id: int=int(c.get_meta("source_general_argument",0));var down: bool=false;var large: bool=false;var stat: int=-1
	if id>=15 and id<=21:stat=id-15
	elif id>=22 and id<=28:stat=id-22;down=true
	elif id>=39 and id<=45:stat=id-39;large=true
	elif id>=46 and id<=52:stat=id-46;down=true;large=true
	elif id in [55,56,57,58]:down=id>=57;large=id in [56,58];stat=7
	else:return [] # Ruby destroys the task for unsupported arguments.
	var actors: Array[BattleAnimationActor]=c.resolve("attacker")
	if actors.is_empty():return []
	var t: Dictionary={"kind":"source_stat_mask","settings":s,"owner":owner,"original_actor":actors[0],"age":0,"ticks":4096,"update":advance,"argument":id,"down":down,"large":large,"palette":[2,1,4,7,8,3,6,5][stat],"peak":13 if large else 10,"hold":30 if large else 20,"phase":0,"counter":0,"amount":0,"scroll":Vector2(64 if down else 0,0),"cleanup":Callable()}
	t.cleanup=_cleanup.bind(t);return [t]
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if int(t.age)==1:
		var node: Sprite2D=BattleIdentityCopy.clone_sprite(t.original_actor,t.owner);t.owner.add_child(node);t.node=node;t.mask=load(str(t.settings.textures["%d:%d"%[2 if t.down else 1,int(t.palette)]]));t.material=ShaderMaterial.new();t.material.shader=load("res://scripts/battle/animations/sequence/source_stat_mask.gdshader");node.material=t.material;t.material.set_shader_parameter("mask_texture",t.mask);t.material.set_shader_parameter("mask_size",Vector2(t.mask.get_size()));t.material.set_shader_parameter("scroll",t.scroll);t.material.set_shader_parameter("owner_inverse",t.owner.get_global_transform_with_canvas().affine_inverse());t.material.set_shader_parameter("eva",0.0);t.material.set_shader_parameter("evb",1.0)
		# The literal BG1/OBJ-window compositor is projected locally above the
		# affected body; no field BG plane or underlying actor material is edited.
		node.z_index=clampi(BattleSourcePriority.actor_layer(t.original_actor,t.owner)+1,-4096,4096);t.source_bg_priority=0
		var partners: Array[BattleAnimationActor]=c.resolve("attacker_partner")
		if not c.contest and c.source_position(t.original_actor.id) in [0,3] and not partners.is_empty() and partners[0].sprite.is_visible_in_tree():
			# Source temporarily lowers partner OAM priority and BG1 becomes1.
			# Project that ordering locally without changing shared field planes.
			t.source_bg_priority=1;t.partner=partners[0];t.partner_previous_z=t.partner.sprite.z_index
			var parent_layer: int=BattleSourcePriority.effective_layer(t.partner.sprite.get_parent()) if t.partner.sprite.z_as_relative else 0
			t.partner_owned_z=clampi(maxi(int(t.partner_previous_z),BattleSourcePriority.effective_layer(t.owner)+node.z_index+1-parent_layer),-4096,4096);t.partner.sprite.z_index=int(t.partner_owned_z)
		t.owner._play_sound(str(t.settings.source_decrease_sound if t.down else t.settings.source_increase_sound),"SOUND_PAN_ATTACKER");return
	t.scroll.y+=-3 if bool(t.down) else 3;t.material.set_shader_parameter("scroll",t.scroll)
	t.counter=int(t.counter)+1
	if int(t.phase)==1:
		if int(t.counter)==int(t.hold):t.phase=2;t.counter=0
	elif int(t.counter)==2:
		t.counter=0;t.amount=int(t.amount)+(1 if int(t.phase)==0 else -1)
		if int(t.phase)==0 and int(t.amount)==int(t.peak):t.phase=1
		elif int(t.phase)==2 and int(t.amount)==0:t.ticks=int(t.age)
	t.material.set_shader_parameter("eva",float(t.amount)/16);t.material.set_shader_parameter("evb",float(16-int(t.amount))/16)

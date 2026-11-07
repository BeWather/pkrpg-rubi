extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Local source task clocks. Normal OBJ and target BG are opaque; impact OBJ alone blends.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func _cleanup(t: Dictionary) -> void:
	t.erase("cleanup")
	if t.kind=="source_extreme_compress" and t.original_actor.is_present():t.original_actor.sprite.scale=t.base_scale;t.original_actor._base_scale=t.owned_base;t.original_actor._expected_scale=t.base_scale;t.owner._held_offsets[t.original_actor.id]=Vector2.ZERO
	if t.kind=="source_extreme_dust":
		for child: Dictionary in t.children:
			if is_instance_valid(child.node):child.node.queue_free()
		t.children.clear()
static func _frame(node: Sprite2D,s: Dictionary,tile: int) -> void:
	var rect: Array=s.frame_rects[str(tile)];node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3])
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var actor: BattleAnimationActor=c.resolve("target" if s.behavior in ["source_extreme_recoil","source_extreme_impact"] else "attacker")[0]
	var t: Dictionary={"kind":s.behavior,"settings":s,"owner":owner,"original_actor":actor,"age":0,"ticks":int(s.ticks),"phase":0,"counter":0,"count":0,"offset":Vector2.ZERO,"update":advance}
	if s.behavior=="source_extreme_compress":
		var offsets: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(s.source_offsets)));var species: String=str(c.source_appearance_species.get(actor.id,""));species=(str(c.source_party_species.get(actor.id,"")) if species.is_empty() else species).to_upper();t.height=64-2*int(offsets.by_species[species]["back" if c.contest or actor.side==0 else "front"]);t.base_scale=actor.sprite.scale;t.owned_base=actor._base_scale;t.raw=Vector2(256,256);t.cleanup=_cleanup.bind(t)
	elif s.behavior=="source_extreme_recoil":t.shove=8 if actor.side==0 else -8;t.return_step=-1 if actor.side==0 else 1;t.repeat=3;t.toggles=0
	elif s.behavior=="source_extreme_dust":t.base=Geometry._anchor(actor,c,owner,"origin");t.children=[];t.emitted=0;t.emit_timer=4;t.hidden=0;t.toggle_timer=0;t.pass_done=false;t.cleanup=_cleanup.bind(t)
	elif s.behavior=="source_extreme_impact":
		var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;owner.add_child(node);_frame(node,s,0);node.scale=Vector2(0.5,0.5);t.base=Geometry._anchor(actor,c,owner,"origin")+owner._held_offsets.get(actor.id,Vector2.ZERO)+Vector2(int(s.source_args[1]),int(s.source_args[2]));node.position=t.base;t.node=node;node.material=BattleIdentityCopy.blend_material(false);var pair: Array=owner.get_meta("source_faint_pair",[16,0]);node.material.set_shader_parameter("eva",float(pair[0])/16);node.material.set_shader_parameter("evb",float(pair[1])/16);BattleSourcePriority.initialize(t,c,owner)
	return [t]
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	var actor: BattleAnimationActor=t.original_actor
	match str(t.kind):
		"source_extreme_compress":
			if int(t.age)<=8:
				t.raw+=Vector2(96,-13);actor._base_scale=t.base_scale*Vector2(256.0/t.raw.x,256.0/t.raw.y);actor.sprite.scale=actor._base_scale;actor._expected_scale=actor.sprite.scale;var projected: int=mini(128,int(t.height)*256/int(t.raw.y));t.owner._held_offsets[actor.id]=Vector2(0,(int(t.height)-projected)/2)
			else:_cleanup(t);actor.apply_source_state("hidden",true)
		"source_extreme_recoil":
			match int(t.phase):
				0:t.offset.x+=int(t.shove);t.counter=0;t.toggles=0;t.phase=1
				1:
					t.counter=int(t.counter)+1
					if int(t.counter)>1:
						t.counter=0;t.toggles=int(t.toggles)+1;t.offset.x+=6 if int(t.toggles)%2 else -6
						if int(t.toggles)>4:t.offset.x-=6;t.phase=2
				2:t.repeat=int(t.repeat)-1;t.phase=0 if int(t.repeat)>0 else 3
				3:
					t.offset.x+=int(t.return_step)
					if is_zero_approx(t.offset.x):t.ticks=int(t.age)
			t.owner._held_offsets[actor.id]=t.offset
			for bg: Dictionary in t.owner.get_meta("source_faint_backgrounds",[]):preload("res://scripts/battle/animations/sequence/source_faint_attack.gd").copy_update(bg,c)
		"source_extreme_reentry":
			if int(t.age)%2==0:actor.apply_source_state("hidden",int(t.age)%4==0 and int(t.age)<28)
		"source_extreme_dust":_dust(t,c)
static func _dust(t: Dictionary,c: BattleAnimationContext) -> void:
	match int(t.phase):
		0:
			t.toggle_timer=int(t.toggle_timer)+1
			if int(t.toggle_timer)>1:
				t.toggle_timer=0;t.hidden=1-int(t.hidden);t.count=int(t.count)+1
				if int(t.count)>20:t.count=0;t.phase=2 if t.pass_done else 1
		1:
			t.hidden=0;t.toggle_timer=int(t.toggle_timer)+1
			if int(t.toggle_timer)>20:t.pass_done=true;t.phase=0
		2:t.hidden=1
	if int(t.emitted)<24:
		t.emit_timer=int(t.emit_timer)+1
		if int(t.emit_timer)>4:
			t.emit_timer=0;var node:=Sprite2D.new();var s: Dictionary=t.settings.child;node.texture=load(str(s.texture));node.region_enabled=true;t.owner.add_child(node);node.z_index=BattleElectricContract.absolute_priority_layer(0,c,t.owner);var offset: Array=t.settings.source_child_offsets[int(t.emitted)%4];node.position=t.base+Vector2(offset[0],offset[1]);t.children.append({"node":node,"age":0,"tile":0,"index":t.emitted});t.emitted=int(t.emitted)+1
	for index: int in range(t.children.size()-1,-1,-1):
		var child: Dictionary=t.children[index];child.age=int(child.age)+1
		if int(child.age)>15:child.node.queue_free();t.children.remove_at(index);continue
		child.tile=[0,4,8,4,0][(int(child.age)-1)/3];_frame(child.node,t.settings.child,int(child.tile));child.node.visible=int(t.hidden)==0
	if int(t.emitted)==24 and t.children.is_empty() and int(t.ticks)==1000:t.ticks=int(t.age)+1

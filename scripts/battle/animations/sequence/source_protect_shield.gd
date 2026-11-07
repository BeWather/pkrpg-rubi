extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## shield.c:29–106: palette1..7 cycle, signed-Q8 drift and source alpha lifecycle.
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var actors: Array[BattleAnimationActor]=c.resolve("attacker");var a: Array=step.get("source_args",[])
	if actors.is_empty() or a.size()!=3 or str(step.get("source_callback",""))!="sub_80CCD24":return []
	var original: BattleAnimationActor=actors[0]
	var origin: Vector2=BattleElectricContract.source_anchor(original,c,"origin")+Vector2(int(a[0]),int(a[1])+(8 if c.contest else 0))
	if c.contest:owner._source_args[1]=(int(a[1])+8)&65535
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;node.position=origin;owner.add_child(node)
	var t: Dictionary={"kind":"source_protect_shield","settings":step.duplicate(true),"owner":owner,"original_actor":original,"node":node,"origin":origin,"age":0,"ticks":4096,"remaining":int(a[2]),"drift":0,"palette_counter":0,"palette_cycle":0,"alpha_counter":0,"evb":16,"stage":0,"update":advance}
	BattleSourcePriority.initialize(t,c,owner)
	var behind: bool=original.side==0 or c.contest
	t.source_oam_priority=(2 if c.contest or c.source_position(original.id) in [0,3] else 1)+(1 if behind else 0)
	node.z_index=BattleSourcePriority.relative_layer(original,-1 if behind else 1,c,owner)
	BattleCounterSelected._blend_node(node,owner);_pose(t)
	return [t]
static func _pose(t: Dictionary) -> void:
	t.node.region_rect=Rect2(0,int(t.palette_cycle)*int(t.settings.source_palette_cycle_height),64,64)
	t.node.material.set_shader_parameter("eva",float(16-int(t.evb))/16.0)
	t.node.material.set_shader_parameter("evb",float(t.evb)/16.0)
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if c.actors.get(t.original_actor.id)!=t.original_actor or not t.original_actor.is_present():t.ticks=int(t.age);return
	if int(t.stage)==1:t.ticks=int(t.age);return # sub_807861C owns the next cleanup callback.
	t.drift=(int(t.drift)+96)&65535;t.node.position=t.origin+Vector2(-(int(t.drift)>>8),0)
	t.palette_counter=int(t.palette_counter)+1
	if int(t.palette_counter)>1:t.palette_counter=0;t.palette_cycle=(int(t.palette_cycle)+1)%7
	if int(t.evb)>6 and int(t.remaining)>0:
		t.alpha_counter=int(t.alpha_counter)+1
		if int(t.alpha_counter)>1:t.alpha_counter=0;t.evb=int(t.evb)-1
	if int(t.remaining)>0:t.remaining=int(t.remaining)-1
	else:
		t.alpha_counter=int(t.alpha_counter)+1
		if int(t.alpha_counter)>1:
			t.alpha_counter=0;t.evb=int(t.evb)+1
			if int(t.evb)==16:t.node.visible=false;t.stage=1
	_pose(t)

extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Source BG1 and OBJ fades have separate palette ownership and clocks.
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if step.behavior=="source_haze_palette":
		var members: Array[BattleAnimationActor]=[]
		for actor: BattleAnimationActor in c.resolve("all"):
			if actor.sprite.visible:members.append(actor)
		# Step1 calls Step2 immediately; nonzero delay increments its counter.
		return [{"kind":"source_haze_palette","settings":step,"owner":owner,"members":members,"counter":1,"amount":int(step.source_args[2]),"applied":int(step.source_args[2]),"age":0,"ticks":int(step.ticks),"update":advance}]
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.centered=false;node.region_enabled=true;node.region_rect=Rect2(Vector2.ZERO,c.field_size);node.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED;owner.add_child(node);BattleCounterSelected._blend_node(node,owner)
	for actor: BattleAnimationActor in c.actors.values():node.z_index=maxi(node.z_index,BattleSourcePriority.actor_layer(actor,owner)+1)
	var t: Dictionary={"kind":"source_haze_bg","settings":step,"owner":owner,"node":node,"age":0,"ticks":194,"stage":"in","counter":0,"ramp_index":0,"eva":0,"evb":16,"scroll":Vector2.ZERO,"update":advance}
	_alpha(t);return [t]
static func _alpha(t: Dictionary) -> void:
	t.node.material.set_shader_parameter("eva",float(t.eva)/16.0);t.node.material.set_shader_parameter("evb",float(t.evb)/16.0)
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if t.kind=="source_haze_palette":
		var s: Dictionary=t.settings
		if int(t.counter)==int(s.source_args[1]):
			t.counter=0;t.applied=int(t.amount)
			for member: BattleAnimationActor in t.members:
				if c.actors.get(member.id)==member and member.is_present():t.owner._held_blends[member.id]={"color":Color.BLACK,"amount":float(t.applied)/16.0,"source_actor":member}
			if int(t.amount)==int(s.source_args[3]):t.ticks=int(t.age)
			else:t.amount=int(t.amount)+signi(int(s.source_args[3])-int(t.amount))
		else:t.counter=int(t.counter)+1
		return
	t.scroll.x-=1;t.counter=int(t.counter)+1
	match str(t.stage):
		"in":
			if int(t.counter)==4:
				t.counter=0;t.ramp_index=int(t.ramp_index)+1;t.eva=int(t.settings.source_ramp[int(t.ramp_index)])
				if int(t.eva)==9:t.stage="hold"
		"hold":
			if int(t.counter)==81:t.counter=0;t.stage="out"
		"out":
			if int(t.counter)==4:
				t.counter=0;t.eva=int(t.eva)-1
				if int(t.eva)==0:t.stage="cleanup"
		"cleanup":t.scroll=Vector2.ZERO;t.eva=0;t.node.visible=false
	t.evb=16-int(t.eva);t.node.region_rect.position=t.scroll;_alpha(t)

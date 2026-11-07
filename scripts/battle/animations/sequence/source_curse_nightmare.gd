extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Source-only window, nail callback chain, rising spirit and actual Curse mask.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func _frame(t: Dictionary,tile: int=0) -> void:
	var rect: Array=t.settings.frame_rects[str(tile)];t.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3])
static func _alpha(t: Dictionary) -> void:
	t.node.material.set_shader_parameter("eva",float(t.eva)/16.0);t.node.material.set_shader_parameter("evb",float(t.evb)/16.0)
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var actors: Array[BattleAnimationActor]=c.resolve("attacker");var targets: Array[BattleAnimationActor]=c.resolve("target")
	if actors.is_empty() or targets.is_empty():return []
	var kind: String=str(step.behavior);var actor: BattleAnimationActor=actors[0]
	if kind=="source_curse_window":
		var node:=Polygon2D.new();node.color=Color.BLACK;node.z_index=0;owner.add_child(node)
		return [{"kind":kind,"settings":step,"owner":owner,"node":node,"age":0,"ticks":4096,"x":200 if actor.side==0 and not c.contest else 40,"left":0,"right":0,"top":0,"bottom":0,"update":advance}]
	if kind=="source_curse_mask":
		var node: Sprite2D=BattleIdentityCopy.clone_sprite(actor,owner);owner.add_child(node);node.z_index=BattleSourcePriority.actor_layer(actor,owner)+1
		var material:=ShaderMaterial.new();material.shader=load("res://scripts/battle/animations/sequence/source_curse_mask.gdshader");material.set_shader_parameter("source_mask",load(str(step.source_mask)));node.material=material
		return [{"kind":kind,"settings":step.duplicate(true),"owner":owner,"node":node,"age":0,"ticks":64,"scroll":0,"update":advance}]
	var origin: Vector2=Geometry._anchor(actor if kind=="source_curse_nail" else targets[0],c,owner,"center")
	var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;owner.add_child(node)
	var t: Dictionary={"kind":kind,"settings":step.duplicate(true),"owner":owner,"node":node,"origin":origin,"original_actor":actor,"age":0,"ticks":4096,"counter":0,"phase":0,"eva":16,"evb":0,"tile":0,"dx":-2 if actor.side==0 else 2,"offset":0,"remaining":60,"stage":"wait","fade_wait":0,"update":advance}
	BattleSourcePriority.initialize(t,c,owner);_frame(t)
	if kind=="source_curse_nail":t.origin.x+=24 if actor.side==0 else -24;node.flip_h=actor.side==0
	BattleCounterSelected._blend_node(node,owner);_alpha(t);node.position=t.origin
	if kind=="source_curse_spirit":_spirit(t,c) # Immediate source constructor callback.
	return [t]
static func _spirit(t: Dictionary,c: BattleAnimationContext) -> void:
	if str(t.stage)=="cleanup":t.ticks=int(t.age);return
	t.node.position=t.origin+Vector2(BattleSourceTrig.sine(int(t.phase),12)*(1 if t.original_actor.side==0 else -1),-int(t.counter)-1)
	t.phase=(int(t.phase)+6)&255;t.counter=int(t.counter)+1
	if int(t.counter)==1:t.eva=11;t.evb=5
	elif int(t.counter)>30:
		t.eva=maxi(0,int(t.eva)-1);t.evb=mini(16,int(t.evb)+1)
		if int(t.eva)==0 and int(t.evb)==16:t.node.visible=false;t.stage="cleanup"
	_alpha(t)
static func _nail(t: Dictionary) -> void:
	match str(t.stage):
		"wait":
			if int(t.remaining)>0:t.remaining=int(t.remaining)-1
			else:
				t.offset=int(t.offset)+int(t.dx)
				if absi(int(t.offset))>7:
					t.origin.x+=int(t.offset);t.offset=0;t.tile=int(t.tile)+8
					if int(t.tile)==24:t.remaining=30;t.stage="duration"
					else:t.remaining=40
		"duration":
			if int(t.remaining)>0:t.remaining=int(t.remaining)-1
			else:t.stage="fade_init"
		"fade_init":t.eva=16;t.evb=0;t.fade_wait=0;t.stage="fade"
		"fade":
			if int(t.fade_wait)<2:t.fade_wait=int(t.fade_wait)+1
			else:
				t.fade_wait=0;t.evb=int(t.evb)+1;t.eva=16-int(t.evb)
				if int(t.evb)==16:t.node.visible=false;t.stage="cleanup"
		"cleanup":t.ticks=int(t.age)
	t.node.position=t.origin+Vector2(t.offset,0);_frame(t,int(t.tile));_alpha(t)
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	match str(t.kind):
		"source_curse_spirit":_spirit(t,c)
		"source_curse_nail":_nail(t)
		"source_curse_mask":t.scroll=(int(t.age)*4)%64;t.node.material.set_shader_parameter("source_scroll",float(t.scroll))
		"source_curse_window":
			var step: int=int(t.age)-1
			if step<16:
				t.left=int(int(t.x)-(int(t.x)/16.0)*step);t.right=int(int(t.x)+((240-int(t.x))/16.0)*step);t.top=int(40-2.5*step);t.bottom=int(40+4.5*step)
				var a:=Vector2(t.left/240.0,t.top/112.0)*c.field_size;var b:=Vector2(t.right/240.0,t.bottom/112.0)*c.field_size
				t.node.polygon=PackedVector2Array([a,Vector2(b.x,a.y),b,Vector2(a.x,b.y)])
			elif step==16:t.owner._source_palette({"age":0,"settings":{"blend_start":16,"blend_end":16,"blend_delay":1,"color":"000000"}})
			else:t.ticks=int(t.age)

extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Actual Mist Ball: shared fog pixels, but independent source clocks and palettes.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var t: Dictionary={"kind":str(s.behavior),"settings":s,"owner":owner,"age":0,"ticks":int(s.ticks),"update":advance}
	match str(s.behavior):
		"source_mist_palette":t.members=c.resolve("target");t.counter=1;t.amount=int(s.source_args[2]);t.applied=int(s.source_args[2])
		"source_mist_pulse":_pulse(t,32279)
		"source_mist_bg":
			var node:=Sprite2D.new();node.texture=load(str(s.texture));node.centered=false;node.region_enabled=true;node.region_rect=Rect2(Vector2.ZERO,c.field_size);node.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED;owner.add_child(node);BattleCounterSelected._blend_node(node,owner)
			for actor: BattleAnimationActor in c.actors.values():node.z_index=maxi(node.z_index,BattleSourcePriority.actor_layer(actor,owner)+1)
			t.node=node;t.eva=0;t.evb=16;t.stage="in";t.counter=0;t.ramp_index=0;t.scroll=Vector2.ZERO;_alpha(t)
		"source_mist_projectile":
			var actors: Array[BattleAnimationActor]=c.resolve("attacker");var targets: Array[BattleAnimationActor]=c.resolve("target")
			if actors.is_empty() or targets.is_empty():return []
			var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;var rect: Array=s.frame_rects["0"];node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);owner.add_child(node)
			t.node=node;t.original_actor=actors[0];t.origin=Geometry._anchor(actors[0],c,owner,"center");t.destination=Geometry._anchor(targets[0],c,owner,"center");node.position=t.origin;BattleSourcePriority.initialize(t,c,owner)
	return [t]
static func _pulse(t: Dictionary,packed: int) -> void:
	var owner: Node2D=t.owner
	if not is_instance_valid(owner._background_blend):
		owner._background_blend=Polygon2D.new();owner._background_blend.polygon=PackedVector2Array([Vector2.ZERO,Vector2(240,0),Vector2(240,160),Vector2(0,160)]);owner.add_child(owner._background_blend)
	owner._background_blend.color=Color(float(packed&31)/31,float((packed>>5)&31)/31,float((packed>>10)&31)/31,0.0 if packed==0 else 1.0)
	# Selector1 selects ordinary BG banks1/2/3, NOT the fog palette in bank8.
static func _alpha(t: Dictionary) -> void:
	t.node.material.set_shader_parameter("eva",float(t.eva)/16.0);t.node.material.set_shader_parameter("evb",float(t.evb)/16.0)
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	match str(t.kind):
		"source_mist_pulse":
			if int(t.age)==2:_pulse(t,32767)
			elif int(t.age)==5:_pulse(t,0)
		"source_mist_palette":
			var s: Dictionary=t.settings
			if int(t.counter)==int(s.source_args[1]):
				t.counter=0;t.applied=int(t.amount)
				for member: BattleAnimationActor in t.members:
					if c.actors.get(member.id)==member and member.is_present():t.owner._held_blends[member.id]={"color":Color.WHITE,"amount":float(t.applied)/16.0,"source_actor":member}
				if int(t.amount)==int(s.source_args[3]):t.ticks=int(t.age)
				else:t.amount=int(t.amount)+signi(int(s.source_args[3])-int(t.amount))
			else:t.counter=int(t.counter)+1
		"source_mist_projectile":
			var sample: int=clampi(int(t.age)-1,0,30);var delta: Vector2=t.destination-t.origin
			var vx: int=int(absf(delta.x)*256)/30;var vy: int=int(absf(delta.y)*256)/30;vx=(vx|1) if delta.x<0 else (vx&~1);vy=(vy|1) if delta.y<0 else (vy&~1)
			t.node.position=t.origin+Vector2(((sample*vx)&65535)>>8,((sample*vy)&65535)>>8)*Vector2(-1 if delta.x<0 else 1,-1 if delta.y<0 else 1)
		"source_mist_bg":
			t.scroll.x-=1;t.counter=int(t.counter)+1
			match str(t.stage):
				"in":
					t.ramp_index=int(t.ramp_index)+1;t.eva=int(t.settings.source_ramp[int(t.ramp_index)]);t.evb=17-int(t.eva)
					if int(t.eva)==5:t.stage="hold";t.counter=0
				"hold":
					if int(t.counter)==81:t.stage="out";t.counter=0
				"out":
					if int(t.counter)==4:
						t.counter=0;t.eva=int(t.eva)-1;t.evb=16-int(t.eva)
						if int(t.eva)==0:t.stage="cleanup"
				"cleanup":t.scroll=Vector2.ZERO;t.eva=0;t.evb=0;t.node.visible=false
			t.node.region_rect.position=t.scroll;_alpha(t)

extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Literal fixed-screen hands and independent attacker/partner tasks; no gameplay writes.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func _cleanup_pose(t: Dictionary) -> void:t.erase("cleanup");t.owner._held_offsets[t.original_actor.id]=Vector2.ZERO
static func _cleanup_palette(t: Dictionary) -> void:t.erase("cleanup");t.lease.release()
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var t: Dictionary={"kind":s.behavior,"settings":s,"owner":owner,"age":0,"ticks":int(s.ticks),"phase":0,"counter":0,"update":advance}
	if s.behavior=="source_helping_hand_sprite":
		var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;owner.add_child(node);t.node=node;t.direction=1 if int(s.source_args[0])==0 else -1;t.x=100 if int(t.direction)==1 else 140;t.y=56;t.x2=0;t.tile=0;node.flip_h=int(t.direction)==1;t.original_actor=c.resolve("attacker")[0];BattleSourcePriority.initialize(t,c,owner);_hand_pose(t);return [t]
	var actors: Array[BattleAnimationActor]=c.resolve("attacker" if s.behavior=="source_helping_hand_actor" else "attacker_partner")
	if actors.is_empty():return []
	t.original_actor=actors[0]
	if s.behavior=="source_helping_hand_palette":
		var material:=ShaderMaterial.new();material.shader=load("res://scripts/battle/animations/sequence/source_celestial_heal.gdshader");material.set_shader_parameter("color5",Vector3(31,31,0));material.set_shader_parameter("amount",0.0);material.set_shader_parameter("eva",1.0);material.set_shader_parameter("evb",0.0);t.material=material;t.lease=BattleOwnedMaterialLease.attach(actors[0],material);t.cleanup=_cleanup_palette.bind(t);return [t]
	t.offset=Vector2.ZERO;t.cleanup=_cleanup_pose.bind(t)
	if s.behavior=="source_helping_hand_shake":
		t.offset=Vector2(int(s.source_args[1]),int(s.source_args[2]));t.remaining=int(s.source_args[3]);t.delay=int(s.source_args[4])-1;owner._held_offsets[actors[0].id]=t.offset;actors[0].apply(t.offset,Color.WHITE)
	else:
		var partners: Array[BattleAnimationActor]=c.resolve("attacker_partner");t.direction=1 if c.contest or actors[0].side!=0 else -1
		if not c.contest and not partners.is_empty():t.direction=1 if Geometry._anchor(actors[0],c,owner,"origin").x>Geometry._anchor(partners[0],c,owner,"origin").x else -1
		t.loops=0
	return [t]
static func _hand_pose(t: Dictionary) -> void:
	var rect: Array=t.settings.frame_rects[str(t.tile)];t.node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);t.node.position=Vector2(int(t.x)+int(t.x2),int(t.y))
static func advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	if t.kind=="source_helping_hand_palette":t.material.set_shader_parameter("amount",float(int(t.age) if int(t.age)<=12 else 24-int(t.age)));return
	if t.kind=="source_helping_hand_shake":
		if int(t.delay)==0:
			t.offset=-t.offset;t.delay=int(t.settings.source_args[4]);t.remaining=int(t.remaining)-1
			if int(t.remaining)==0:t.offset=Vector2.ZERO;t.ticks=int(t.age)
		else:t.delay=int(t.delay)-1
		t.owner._held_offsets[t.original_actor.id]=t.offset;return
	var dir: int=int(t.direction)
	if t.kind=="source_helping_hand_sprite":
		var phase: int=int(t.phase)
		if phase==0:
			t.y=int(t.y)-dir*2
			if int(t.counter)&1:t.x=int(t.x)-dir*2
		elif phase in [2,4,5]:
			t.y=int(t.y)+(dir*3 if phase!=4 else -dir*3);t.x2=dir*(BattleSourceTrig.VALUES[(int(t.counter)+1)*10]>>3)
		elif phase==6:t.x=int(t.x)+dir*6
		elif phase==7:t.x=int(t.x)+dir*2
		elif phase==8:t.x=int(t.x)-dir*3
		t.counter=int(t.counter)+1
		if phase==5 and int(t.counter)==15:t.tile=16
		var duration: int=[9,4,12,2,12,18,9,1,5][phase]
		if int(t.counter)==duration:
			t.phase=phase+1
			if phase!=4:t.counter=0
		_hand_pose(t);return
	var phase: int=int(t.phase)
	if phase==1:t.offset.x-=dir*3
	elif phase==2:t.offset.x+=dir*3
	elif phase==4:t.offset.x+=dir
	elif phase==6:t.offset.x-=dir*4
	elif phase==7:t.offset.x+=dir*4
	elif phase==8:t.offset=Vector2.ZERO
	t.counter=int(t.counter)+1
	if int(t.counter)==[13,6,6,2,3,6,5,5,1][phase]:
		t.counter=0;t.phase=phase+1
		if phase==3 and int(t.loops)==0:t.loops=1;t.phase=1
	t.owner._held_offsets[t.original_actor.id]=t.offset

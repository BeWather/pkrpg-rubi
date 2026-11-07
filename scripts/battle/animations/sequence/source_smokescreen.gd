extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Source distinct ball/opaque clouds and non-animation four-child parent.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
const Packed=preload("res://scripts/battle/animations/sequence/source_sports.gd")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var actors: Array[BattleAnimationActor]=c.resolve("attacker");var targets: Array[BattleAnimationActor]=c.resolve("target")
	if actors.is_empty() or targets.is_empty():return []
	var actor: BattleAnimationActor=actors[0];var target: BattleAnimationActor=targets[0];var kind: String=str(s.behavior);var node: Node2D
	if kind=="source_smoke_impact":node=Node2D.new()
	else:
		node=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;var rect: Array=s.frame_rects["0"];node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3])
	owner.add_child(node)
	var t: Dictionary={"kind":kind,"settings":s,"node":node,"owner":owner,"original_actor":actor,"original_target":target,"age":0,"ticks":int(s.ticks),"update":advance}
	match kind:
		"source_smoke_ball":
			var a: Array=s.source_args;t.origin=Geometry._anchor(actor,c,owner,"center")+Vector2(int(a[0])*BattleElectricContract.source_offset_direction(c,actor,target),int(a[1]));t.destination=Geometry._anchor(target,c,owner,"center")+Vector2(int(a[2])*(1 if actor.side==0 else -1),int(a[3]));t.offset=Vector2.ZERO;Packed._arc(t,t.destination,int(a[4]),int(a[5]));node.position=t.origin;BattleSourcePriority.initialize(t,c,owner)
		"source_smoke_cloud":
			var a: Array=s.source_args;t.origin=Geometry._anchor(target,c,owner,"center")+Vector2(int(a[0]),int(a[1]));t.velocity=int(a[2])*(1 if int(a[3])==0 else -1);t.acc=0;t.remaining=int(a[4]);node.position=t.origin;BattleSourcePriority.initialize(t,c,owner)
		"source_smoke_impact":
			# DestroyAnimVisualTask happens in the constructor; these ordinary
			# sprite children are NOT gAnimVisualTaskCount/gAnimVisualSpriteCount.
			t.domain="owned_child";t.children=[];t.live_children=4;t.private_assets_live=true
			node.position=Geometry._anchor(target,c,owner,"center")+Vector2(8,8);node.z_index=BattleElectricContract.absolute_priority_layer(2,c,owner)
			for index: int in 4:
				var child:=Sprite2D.new();child.texture=load(str(s.texture));child.region_enabled=true;child.position=[Vector2(-16,-16),Vector2(0,-16),Vector2(-16,0),Vector2(0,0)][index];node.add_child(child);t.children.append(child);_impact_pose(t,index,0)
	return [t]
static func _impact_pose(t: Dictionary,index: int,age: int) -> void:
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(t.settings.source_frame_variants[index],age).frame;var rect: Array=t.settings.frame_rects[str(int(frame.tile))];var child: Sprite2D=t.children[index]
	child.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);child.flip_h=bool(frame.get("flip_h",false));child.flip_v=bool(frame.get("flip_v",false))
static func advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	if not t.original_actor.is_present() or not t.original_target.is_present():t.ticks=int(t.age);return
	match str(t.kind):
		"source_smoke_ball":
			if Packed._translate(t):t.ticks=int(t.age)
			else:t.node.position=t.origin+t.offset
		"source_smoke_cloud":
			if int(t.remaining)<=0:t.ticks=int(t.age);return
			t.node.position=t.origin+Vector2(int(t.acc)>>8,0);t.acc=(int(t.acc)+int(t.velocity))&65535
			if int(t.acc)&32768:t.acc=int(t.acc)-65536
			t.node.visible=not t.node.visible;t.remaining=int(t.remaining)-1
		"source_smoke_impact":
			if int(t.age)<=12:
				for index: int in 4:_impact_pose(t,index,int(t.age))
			elif int(t.age)==13:
				for child: Sprite2D in t.children:child.hide();child.queue_free();t.live_children=int(t.live_children)-1
			else:t.private_assets_live=false;t.ticks=int(t.age)

extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Actual task owns a SpriteCallbackDummy child, arc and matrix lifetime separately.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static var _bounds: Dictionary={}
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var attackers: Array[BattleAnimationActor]=c.resolve("attacker");var targets: Array[BattleAnimationActor]=c.resolve("target")
	if attackers.is_empty() or targets.is_empty():return []
	var target: BattleAnimationActor=targets[0];var species: String=str(c.source_appearance_species.get(target.id,c.source_party_species.get(target.id,""))).to_upper();var side: String="back" if c.contest or target.side==0 else "front"
	if _bounds.is_empty():_bounds=JSON.parse_string(FileAccess.get_file_as_string(str(s.source_bounds)))
	if not _bounds.by_species.has(species) or not _bounds.by_species[species].has(side):owner.error_message="Missing source Barrage target picture bounds: "+species;owner.finish("failed");return []
	var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;var rect: Array=s.frame_rects["0"];node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);owner.add_child(node)
	var origin: Vector2=Geometry._anchor(attackers[0],c,owner,"center");var destination: Vector2=Geometry._anchor(target,c,owner,"center")+Vector2(0,int(_bounds.by_species[species][side][0])/4)
	var dx: int=int(destination.x-origin.x);var dy: int=int(destination.y-origin.y);var vx: int=int((absi(dx)<<8)&65535)/16;var vy: int=int((absi(dy)<<8)&65535)/16
	vx=(vx|1) if dx<0 else (vx&~1);vy=(vy|1) if dy<0 else (vy&~1)
	var t: Dictionary={"kind":"source_barrage_ball","settings":s,"owner":owner,"node":node,"original_actor":attackers[0],"target":target,"origin":origin,"destination":destination,"vx":vx,"vy":vy,"qx":0,"qy":0,"phase":0,"arc_samples":0,"remaining":16,"stage":0,"counter":0,"blink":0,"matrix_live":true,"age":0,"ticks":58,"affine":s.source_affine_variants[0 if attackers[0].side==0 else 1],"update":advance,"source_oam_subpriority":BattleElectricContract.source_subpriority(target,c)-5,"source_oam_priority":2}
	node.position=origin;node.z_index=BattleSourcePriority.relative_layer(target,-5,c,owner);_pose(t);return [t]
static func _pose(t: Dictionary) -> void:
	var pose: Dictionary=BattleSourceCommandProgram.evaluate(t.affine,mini(int(t.age),24),true)
	t.node.scale=pose.matrix/256.0;t.node.rotation=-float(pose.rotation)*TAU/256.0
static func _arc(t: Dictionary) -> bool:
	if int(t.remaining)==0:return true
	t.qx=(int(t.qx)+int(t.vx))&65535;t.qy=(int(t.qy)+int(t.vy))&65535;t.phase=(int(t.phase)+2048)&65535;t.remaining=int(t.remaining)-1;t.arc_samples=int(t.arc_samples)+1
	t.node.position=t.origin+Vector2((int(t.qx)>>8)*(-1 if int(t.vx)&1 else 1),(int(t.qy)>>8)*(-1 if int(t.vy)&1 else 1)+BattleSourceTrig.sine((int(t.phase)>>8)&255,-32));return false
static func advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	if not t.original_actor.is_present() or not t.target.is_present():t.ticks=int(t.age);return
	if int(t.stage)<3:_pose(t)
	match int(t.stage):
		0:
			t.counter=int(t.counter)+1
			if int(t.counter)>1:
				t.counter=0;_arc(t)
				if int(t.arc_samples)>7:t.stage=1
		1:
			if _arc(t):t.counter=0;t.stage=2
		2:
			t.counter=int(t.counter)+1
			if int(t.counter)>1:
				t.counter=0;t.blink=int(t.blink)+1;t.node.visible=int(t.blink)%2==0
				if int(t.blink)==16:t.matrix_live=false;t.node.visible=false;t.node.queue_free();t.stage=3
		3:t.ticks=int(t.age)

extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Source packed linear deltas retain the sign bit in their Q8 magnitude.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var musical: Dictionary=BattleEffectBehaviorRegistry.LegacyImpact.Musical.drum_admit(step,c,owner)
	if musical.get("handled",false) and not musical.get("admitted",false):return []
	var actors: Array[BattleAnimationActor]=c.resolve("attacker")
	if actors.is_empty():return []
	var actor: BattleAnimationActor=actors[0];var node:=Sprite2D.new();node.texture=load(str(step.texture));node.region_enabled=true;owner.add_child(node)
	var t: Dictionary={"kind":str(step.behavior),"settings":step,"owner":owner,"original_actor":actor,"node":node,"origin":Geometry._anchor(actor,c,owner,"center"),"phase":int(step.source_args[3]) if step.behavior=="source_drum_note" else 0,"age":0,"ticks":int(step.ticks),"update":advance}
	BattleSourcePriority.initialize(t,c,owner)
	if t.kind=="source_drum_note":t.origin+=Vector2(0,8)
	_pose(t,0)
	if musical.get("admitted",false):BattleEffectBehaviorRegistry.LegacyImpact.Musical.bind_drum(t,c,owner)
	return [t]
static func _pose(t: Dictionary,sample: int) -> void:
	var s: Dictionary=t.settings;var node: Sprite2D=t.node
	var frame: Dictionary=BattleSourceCommandProgram.evaluate(s.frame_program,sample).frame;var rect: Array=s.frame_rects[str(int(frame.tile))]
	node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3])
	if t.kind=="source_drum_hand":
		node.flip_h=int(s.source_args[0])==1;node.position=t.origin+Vector2(16 if node.flip_h else -16,8);return
	node.region_rect.position.y+=int(s.note_palette)*int(s.palette_bank_height)
	var pose: Dictionary=BattleSourceCommandProgram.evaluate(s.affine_program,sample,true);node.scale=Vector2(256.0/pose.matrix.x,256.0/pose.matrix.y)
	if sample==0:node.position=t.origin;return
	var left: bool=int(s.source_args[0])==0;var dx: int=(204|1) if left else (204&~1);var x: int=(sample*dx)>>8;var y: int=(sample*257)>>8
	var phase: int=(int(s.source_args[3])+(sample-1)*8)&255;var wave: int=BattleSourceTrig.sine(phase,8)
	node.position=t.origin+Vector2((-x-wave) if left and x>0 else x+wave,BattleSourceTrig.sine(phase,4)-y)
static func advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	if t.kind=="source_drum_note":
		if int(t.age)>40:return
		t.phase=(int(t.phase)+8)&255
	_pose(t,int(t.age))

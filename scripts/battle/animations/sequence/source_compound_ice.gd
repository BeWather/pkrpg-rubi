extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Exact task-owned four source subsprites, palette13–15 rotations and alpha chain.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var targets: Array[BattleAnimationActor]=c.resolve("target")
	if targets.is_empty():return []
	var actor: BattleAnimationActor=targets[0];var root:=Node2D.new();owner.add_child(root)
	var origin: Vector2=Geometry._anchor(actor,c,owner,"center")+Vector2(-38 if c.contest else -32,-36);root.position=origin
	root.z_index=BattleSourcePriority.relative_layer(actor,4-BattleElectricContract.source_subpriority(actor,c),c,owner)
	for piece: Dictionary in step.source_subsprites:
		var node:=Sprite2D.new();node.texture=load(str(step.texture));node.centered=false;node.region_enabled=true;node.position=Vector2(piece.offset[0],piece.offset[1]);root.add_child(node);BattleCounterSelected._blend_node(node,owner)
	var t: Dictionary={"kind":"source_compound_ice","settings":step.duplicate(true),"owner":owner,"node":root,"origin":origin,"age":0,"ticks":4096,"source_oam_subpriority":4,"source_oam_priority":2,"stage":"fade_in","counter":0,"cycle_wait":0,"rotations":0,"rounds":0,"rotation":0,"eva":0,"evb":16,"update":advance}
	_project(t);return [t]
static func _project(t: Dictionary) -> void:
	for i: int in t.node.get_child_count():
		var node: Sprite2D=t.node.get_child(i);var rect: Array=t.settings.source_subsprites[i].rect
		node.region_rect=Rect2(rect[0],int(rect[1])+int(t.rotation)*192,rect[2],rect[3]);node.material.set_shader_parameter("eva",float(t.eva)/16.0);node.material.set_shader_parameter("evb",float(t.evb)/16.0)
static func advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	match str(t.stage):
		"fade_in":
			t.counter=int(t.counter)+1
			if int(t.counter)==10:t.stage="palette";t.counter=0
			else:t.eva=int(t.counter);t.evb=16-int(t.counter)
		"palette":
			var previous: int=int(t.counter);t.counter=previous+1
			if previous>13:
				t.cycle_wait=int(t.cycle_wait)+1
				if int(t.cycle_wait)==3:
					t.rotation=(int(t.rotation)+1)%3;t.cycle_wait=0;t.rotations=int(t.rotations)+1
					if int(t.rotations)==3:
						t.rotations=0;t.counter=0;t.rounds=int(t.rounds)+1
						if int(t.rounds)==2:t.counter=9;t.stage="fade_out"
		"fade_out":
			t.counter=int(t.counter)-1
			if int(t.counter)==-1:t.stage="hold";t.counter=0
			else:t.eva=int(t.counter);t.evb=16-int(t.counter)
		"hold":
			t.counter=int(t.counter)+1
			if int(t.counter)==37:
				for child: Node in t.node.get_children():child.free()
			elif int(t.counter)==39:t.ticks=int(t.age)
	_project(t)

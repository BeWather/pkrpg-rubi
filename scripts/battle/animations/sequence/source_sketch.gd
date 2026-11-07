extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## draw.c: actual BG row reveal and pencil callbacks; no gameplay writes.
const Geometry=preload("res://scripts/battle/animations/sequence/source_wind_air_children.gd")
const Wave=preload("res://scripts/battle/animations/sequence/source_dragon_dance.gd")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var targets: Array[BattleAnimationActor]=c.resolve("target")
	if targets.is_empty():return []
	var actor: BattleAnimationActor=targets[0];var species: String=str(c.source_appearance_species.get(actor.id,c.source_party_species.get(actor.id,""))).to_upper();var side: String="back" if c.contest or actor.side==0 else "front";var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(s.source_coords)));var row: Dictionary=data.by_species.get(species,{}).get(side,{})
	if row.is_empty():owner.error_message="Missing Sketch picture coords: "+species;owner.finish("failed");return []
	var origin: Vector2=Geometry._anchor(actor,c,owner,"origin");var elevation: int=0
	if actor.side!=0 and not c.contest:
		var values: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(s.source_elevations)))
		elevation=int(values.castform_forms[clampi(int(c.get_meta("source_castform_form",0)),0,3)]) if species=="CASTFORM" else int(values.by_species.get(species,0))
	var t: Dictionary={"kind":s.behavior,"settings":s,"owner":owner,"original_actor":actor,"picture_height":(int(row.packed)&15)*8,"age":0,"ticks":4096,"update":advance,"stage":0,"counter":0,"blink":0,"rise":0}
	if s.behavior=="source_sketch_reveal":
		t.source_bottom=int(origin.y)-elevation+32;t.source_top=int(t.source_bottom)-64;t.rows=[];t.nodes=[];t.counter=4;t.wait=0
		for index: int in 65:t.rows.append(240.0 if int(t.source_top)+index>=0 else 0.0)
		var plane: int=1 if c.source_position(actor.id)==1 else 2
		for bg: Dictionary in owner.get_meta("source_counter_monbg",[]):
			for clone: Dictionary in bg.clones:
				if int(clone.bg_plane)!=plane:continue
				var material:=ShaderMaterial.new();material.shader=load("res://scripts/battle/animations/sequence/source_dragon_wave.gdshader");t.nodes.append({"node":clone.node,"material":material,"previous":clone.node.material});clone.node.material=material
		t.cleanup=Wave._cleanup.bind(t);Wave._project(t);return [t]
	var node:=Sprite2D.new();node.texture=load(str(s.texture));node.region_enabled=true;var rect: Array=s.frame_rects["0"];node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3]);owner.add_child(node);t.node=node;t.origin=Vector2(origin.x-16,origin.y-elevation+16);t.vx=16;t.x2=0;node.position=t.origin;BattleSourcePriority.initialize(t,c,owner);return [t]
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if not t.original_actor.is_present():t.ticks=int(t.age);return
	if t.kind=="source_sketch_reveal":
		if int(t.stage)==0:
			t.wait=int(t.wait)+1
			if int(t.wait)>20:t.stage=1
		else:
			t.counter=int(t.counter)+1
			if int(t.counter)>3:
				t.counter=0;var i: int=int(t.rise);var y: int=int(t.source_bottom)-i+int([0,-2,1,1][i&3])
				if y>=0 and y>=int(t.source_top) and y<=int(t.source_bottom):t.rows[y-int(t.source_top)]=0.0
				t.rise=i+1
				if int(t.rise)>=int(t.picture_height):t.ticks=int(t.age)
		Wave._project(t);return
	match int(t.stage):
		0,2:
			t.blink=int(t.blink)+1
			if int(t.blink)>1:t.blink=0;t.node.visible=not t.node.visible
			t.counter=int(t.counter)+1
			if int(t.counter)>16:
				t.node.visible=true
				if int(t.stage)==0:t.stage=1
				else:t.ticks=int(t.age)
		1:
			t.counter=int(t.counter)+1
			if int(t.counter)>3 and int(t.blink)<int(t.picture_height)+2:
				t.counter=0;t.rise=int(t.rise)+1;t.blink=int(t.blink)+1
				if int(t.blink)%10==0:
					var pan: int=BattleCounterSelected.adjust_panning(63,c);var player: AudioStreamPlayer2D=t.owner._play_sound(str(t.settings.sound_path),"SOUND_PAN_TARGET",float(pan)/64.0,true)
					if is_instance_valid(player):t.owner.sound_events.back().merge({"source_callback":"sub_80D0E8C","source_sound":"SE_M_SKETCH","source_pan_value":pan,"source_task_age":int(t.age)})
			t.x2=int(t.x2)+int(t.vx)
			if int(t.x2)>31:t.x2=64-int(t.x2);t.vx=-int(t.vx)
			elif int(t.x2)<=-32:t.x2=-64-int(t.x2);t.vx=-int(t.vx)
			t.node.position=t.origin+Vector2(int(t.x2),-int(t.rise))
			if int(t.blink)==int(t.picture_height)+2:t.counter=0;t.blink=0;t.stage=2

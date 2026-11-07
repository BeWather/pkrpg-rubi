extends RefCounted
class_name BattleWindDirect
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Actual I1 callbacks; snapshot particles and palette-bank ownership are distinct.
const PaletteCycle=preload("res://scripts/battle/animations/sequence/source_palette_cycle.gdshader")

static func create(step: Dictionary, context: BattleAnimationContext, owner: Node2D) -> Array[Dictionary]:
	if str(step.mode)=="gust_palette":return [_palette_create(step,owner)]
	var attackers: Array[BattleAnimationActor]=context.resolve("attacker")
	var targets: Array[BattleAnimationActor]=context.resolve("target")
	if attackers.is_empty() or targets.is_empty():return []
	var attacker: BattleAnimationActor=attackers[0]
	var target: BattleAnimationActor=targets[0]
	var a: Array=step.source_args.duplicate()
	var track: Dictionary={"kind":"source_wind_particle","settings":step.duplicate(true),"owner":owner,"age":0,"ticks":4096,"update":advance,"args":a,"attacker":attacker,"target":target,"counter":0,"state":0}
	var node:=Sprite2D.new()
	node.texture=load(str(step.texture))
	node.region_enabled=true
	var rect: Array=step.frame_rects["0"]
	node.region_rect=Rect2(rect[0],rect[1],rect[2],rect[3])
	owner.add_child(node)
	track.node=node
	BattleSourcePriority.initialize(track,context,owner)
	var origin: Vector2
	if str(step.mode)=="gust":
		origin=_anchor(target,context,owner,"origin")+Vector2(int(a[0])*BattleElectricContract.source_offset_direction(context,attacker,target),int(a[1])+20)
		track.origin=origin
		track.phase=191
		_gust(track) # The initializer calls its continuation synchronously.
		var gusts: Array=owner.get_meta("source_wind_gusts",[])
		gusts.append(track)
		owner.set_meta("source_wind_gusts",gusts)
	else:
		if context.contest:a[2]=-int(a[2])
		elif attacker.side!=0:a[2]=-int(a[2]);a[1]=-int(a[1]);a[3]=-int(a[3])
		for index: int in range(a.size()):owner._source_args[index]=int(a[index])&65535
		# Keep the private copy signed; the source VM argument store is u16.
		origin=_anchor(attacker,context,owner,"center")+Vector2(int(a[0])*BattleElectricContract.source_offset_direction(context,attacker,target),int(a[1]))
		var destination: Vector2=_anchor(target,context,owner,"center")+Vector2(a[2],a[3])
		track.origin=origin
		track.destination=destination
		track.remaining=int(a[4])
		track.delta_x=_delta_q8(int(destination.x-origin.x),int(a[4]))
		track.delta_y=_delta_q8(int(destination.y-origin.y),int(a[4]))
		track.x_q8=0;track.y_q8=0
		var rotation: float=-atan2(destination.y-origin.y,destination.x-origin.x)-TAU/16
		if context.contest:rotation-=3*TAU/8
		# Ruby stores the inverse OAM matrix; Node2D rotation is its inverse.
		node.rotation=-rotation
		node.position=origin
		if bool(step.get("source_obj_blend",false)):BattleCounterSelected._blend_node(node,owner)
	return [track]

static func _anchor(actor: BattleAnimationActor, context: BattleAnimationContext, owner: Node2D, mode: String) -> Vector2:
	return owner.to_local(context.field.to_global(BattleElectricContract.source_anchor(actor,context,mode)))

static func _delta_q8(distance: int, duration: int) -> int:
	var delta: int=(absi(distance)<<8)/maxi(1,duration)
	return (delta|1) if distance<0 else (delta&~1)

static func _gust(track: Dictionary) -> void:
	track.node.position=track.origin+Vector2(BattleSourceTrig.sine(int(track.phase),32),BattleSourceTrig.cosine(int(track.phase),8))
	track.phase=(int(track.phase)+5)&255
	track.counter+=1
	if int(track.counter)==71:track.ticks=int(track.age)

static func advance(track: Dictionary, _context: BattleAnimationContext) -> void:
	if not track.attacker.is_present() or not track.target.is_present():
		track.node.visible=false;track.ticks=int(track.age);return
	if str(track.settings.mode)=="gust":_gust(track);return
	if int(track.remaining)>0:
		track.x_q8=(int(track.x_q8)+int(track.delta_x))&65535
		track.y_q8=(int(track.y_q8)+int(track.delta_y))&65535
		track.node.position=track.origin+Vector2((int(track.x_q8)>>8)*(-1 if int(track.delta_x)&1 else 1),(int(track.y_q8)>>8)*(-1 if int(track.delta_y)&1 else 1))
		track.remaining-=1
	elif int(track.state)==0:track.state=1 # Stored callback transfer, not invocation.
	else:track.ticks=int(track.age)

static func _palette_create(step: Dictionary, owner: Node2D) -> Dictionary:
	var track: Dictionary={"kind":"source_wind_palette","settings":step.duplicate(true),"owner":owner,"age":0,"ticks":int(step.source_args[1]),"counter":0,"shift":0,"nodes":[],"update":_palette_advance}
	var material:=ShaderMaterial.new();material.shader=PaletteCycle
	track.material=material
	for gust: Dictionary in owner.get_meta("source_wind_gusts",[]):
		if not is_instance_valid(gust.node) or str(gust.settings.source_palette_tag)!=str(step.source_palette_tag):continue
		var colors:=PackedColorArray()
		for value: String in gust.settings.source_palette_colors:colors.append(Color(value))
		material.set_shader_parameter("source_palette",colors)
		track.nodes.append({"node":gust.node,"original":gust.node.material})
		gust.node.material=material
	material.set_shader_parameter("palette_shift",0)
	track.cleanup=_palette_cleanup.bind(track)
	return track

static func _palette_advance(track: Dictionary, _context: BattleAnimationContext) -> void:
	if int(track.counter)==int(track.settings.source_args[0]):
		track.counter=0;track.shift=(int(track.shift)+1)%8
		track.material.set_shader_parameter("palette_shift",int(track.shift))
	else:track.counter+=1

static func _palette_cleanup(track: Dictionary) -> void:
	track.erase("cleanup") # Break Dictionary/Callable self-retention.
	for item: Dictionary in track.nodes:
		if is_instance_valid(item.node) and item.node.material==track.material:item.node.material=item.original

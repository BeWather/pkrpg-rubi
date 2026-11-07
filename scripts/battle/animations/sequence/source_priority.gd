extends RefCounted
class_name BattleSourcePriority
## Source OAM ordering metadata and bounded native sprite-plane projection.
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

static var _planes: Dictionary = {}

static func command_metadata(label: Dictionary) -> Dictionary:
	var command := str(label.get("source_command","")).strip_edges()
	if not command.begins_with("createsprite "):return {}
	var operands := command.trim_prefix("createsprite ").split(",")
	if operands.size()<3:return {}
	var numeric := operands[2].strip_edges()
	if not numeric.is_valid_int() and not numeric.begins_with("0x"):return {}
	var raw := numeric.hex_to_int() if numeric.begins_with("0x") else int(numeric)
	var operand := raw&127
	var role := operands[1].strip_edges()
	var target := role in ["ANIM_BATTLER_TARGET","1"]
	return {"template":operands[0].strip_edges(),"raw_offset":raw,"encoded_byte":operand|(128 if target else 0),"basis":"target" if target else "attacker","raw_role":role,"delta":operand-64 if operand>=64 else -operand,"source_pc":int(label.get("source_pc",-1)),"source_line":int(label.get("source_line",-1)),"source_command":command}

static func effective_layer(node: CanvasItem) -> int:
	var value := 0
	var current: Node = node
	while current!=null:
		if current is CanvasItem:
			value+=current.z_index
			if not current.z_as_relative:break
		current=current.get_parent()
	return clampi(value,-4096,4096)

static func actor_layer(actor: BattleAnimationActor, owner: CanvasItem) -> int:
	return effective_layer(actor.sprite)-effective_layer(owner)

static func tree_before(left: CanvasItem, right: CanvasItem) -> bool:
	# Equal-Z is meaningful only in an ordinary, non-Y-sorted canvas tree.
	var paths: Array=[]
	for start: Node in [left,right]:
		var path: Array[Node]=[];var current: Node=start
		while current!=null:
			if current is CanvasItem and (current.is_set_as_top_level() or current.show_behind_parent or current is Node2D and current.y_sort_enabled):return false
			path.push_front(current);current=current.get_parent()
		paths.append(path)
	while not paths[0].is_empty() and not paths[1].is_empty() and paths[0][0]==paths[1][0]:paths[0].pop_front();paths[1].pop_front()
	return not paths[0].is_empty() and not paths[1].is_empty() and paths[0][0].get_index()<paths[1][0].get_index()

static func relative_layer(actor: BattleAnimationActor, delta: int, context: BattleAnimationContext, owner: CanvasItem) -> int:
	var layer := actor_layer(actor,owner)
	var floor := effective_layer(context.field)-effective_layer(owner)
	# Source subpriority acts inside OAM/BG planes, not a global Godot Z delta.
	# Compress distant offsets; preserve foreground increments and behind polarity.
	return clampi(maxi(floor,layer-clampi(delta,-32,32)),-4096,4096)

static func initialize(track: Dictionary, context: BattleAnimationContext, owner: Node2D) -> void:
	var settings: Dictionary = track.settings
	if settings.has("source_command_priority"):
		var metadata: Dictionary = settings.source_command_priority
		var basis: Array[BattleAnimationActor] = context.resolve(str(metadata.basis))
		if not basis.is_empty() and basis[0].is_present():
			var actor: BattleAnimationActor = basis[0]
			var base := BattleElectricContract.source_subpriority(actor,context)
			var priority := maxi(3,base+int(metadata.delta))
			if _planes.is_empty():
				_planes=JSON.parse_string(FileAccess.get_file_as_string("res://recursos/animaciones/source_priority_planes.json"))
			track.source_priority_actor_id=actor.id
			track.source_oam_subpriority=priority
			track.source_oam_priority=int(_planes.get(str(metadata.template),{}).get("priority",2))
			if not settings.has("source_z_index"):
				track.node.z_index=relative_layer(actor,priority-base,context,owner)

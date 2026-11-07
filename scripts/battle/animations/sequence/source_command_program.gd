extends RefCounted
class_name BattleSourceCommandProgram
## Bounded replay of selected Ruby FRAME/JUMP/LOOP/END programs.
## Programs remain source data; callback lifetime owns looping animation teardown.
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

static func evaluate(program: Array, age: int, affine: bool = false) -> Dictionary:
	var pc := 0
	var remaining := maxi(0,age)
	var matrix := Vector2(256,256)
	var rotation := 0.0
	var selected := {"tile":0,"flip_h":false,"flip_v":false}
	var loops := {}
	var loop_start := 0
	for instruction in range(65536):
		if pc < 0 or pc >= program.size(): break
		var command: Dictionary = program[pc]
		match str(command.op):
			"end":
				return {"frame":selected,"matrix":matrix,"rotation":rotation,"ended":true}
			"jump":
				pc = int(command.target)
				continue
			"loop":
				var count := int(command.count)
				if count == 0:
					loop_start = pc+1
				else:
					var left := int(loops.get(pc,count))
					if left > 0:
						loops[pc] = left-1
						pc = loop_start
						continue
					loops.erase(pc)
			"frame":
				var duration := int(command.ticks)
				if affine:
					if duration == 0:
						matrix = Vector2(command.x,command.y)
						rotation = float(command.rotation)
					else:
						var applied := mini(remaining,duration)
						matrix += Vector2(command.x,command.y)*applied
						rotation += float(command.rotation)*applied
						if remaining < duration: break
						remaining -= duration
				else:
					selected = command
					if remaining < maxi(1,duration): break
					remaining -= maxi(1,duration)
		pc += 1
	return {"frame":selected,"matrix":matrix,"rotation":rotation,"ended":false}

## Explicit opt-in adapter for evaluated logical source scales, never increments.
## Positive integral s16, zero-rotation poses only; raw OAM remains the default.
static func source_scale_pose_to_oam(pose: Dictionary) -> Dictionary:
	var logical: Variant=pose.get("matrix")
	if not logical is Vector2 or not logical.is_finite() or float(pose.get("rotation",0.0))!=0.0:return {}
	var raw:=Vector2.ZERO
	for axis: int in 2:
		var value: float=logical[axis]
		if value<=0.0 or value!=floorf(value) or value>32767.0:return {}
		var coefficient: int=65536/int(value) # Ruby ConvertScaleParam integer division.
		if coefficient<=0 or coefficient>32767:return {}
		raw[axis]=coefficient
	var converted: Dictionary=pose.duplicate()
	converted.matrix=raw
	return converted

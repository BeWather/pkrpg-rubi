@tool
extends RefCounted
## Existing v1 save fields shared by runtime and tools; no scene/DB dependencies.
static func integral(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))

static func encode_fields(name: String, current: int, bonus: int, total: int, data: Dictionary) -> Dictionary:
	var keys: Array = []
	for key: String in data:
		if typeof(data[key]) == TYPE_INT: keys.append(key)
	keys.sort()
	return {"move_record_version":1,"name":name,"pp_act":current,"pp_mas":bonus,"pp_tot":total,"data":data.duplicate(true),"integer_keys":keys}

static func decode_fields(record: Dictionary) -> Dictionary:
	var result: Dictionary = record.duplicate(true)
	var data: Dictionary = result.data
	for field: String in result.get("integer_keys", []):
		if data.get(field) is float or data.get(field) is int: data[field] = int(data[field])
	return result

static func valid(record: Variant) -> bool:
	if not record is Dictionary or not integral(record.get("move_record_version")) or record.move_record_version != 1: return false
	if not record.get("name") is String or str(record.name).is_empty() or not record.get("data") is Dictionary or not record.get("integer_keys") is Array: return false
	for key: String in ["pp_act", "pp_mas", "pp_tot"]:
		if not integral(record.get(key)): return false
	if record.pp_mas < 0 or record.pp_mas > 3 or record.pp_tot <= 0 or record.pp_act < 0 or record.pp_act > record.pp_tot: return false
	if not record.data.get("nombre_interno") is String or record.data.nombre_interno.is_empty(): return false
	if not integral(record.data.get("max_pp")) or record.data.max_pp <= 0: return false
	for field: Variant in record.integer_keys:
		if not field is String or not integral(record.data.get(field)): return false
	return true

static func valid_slots(moves: Variant) -> bool:
	return moves is Array and moves.size() <= 4

static func valid_form_moves(moves: Variant) -> bool:
	if not valid_slots(moves): return false
	for move: Variant in moves:
		if move == null: continue
		if not move is Dictionary or move.is_empty(): return false
		if move.has("move_record"):
			if not valid(move.move_record): return false
			if str(move.get("nombre_interno", "")).to_upper() != str(move.move_record.data.nombre_interno).to_upper(): return false
		if move.has("reset_move_origin") and not move.reset_move_origin is bool: return false
		if move.has("movimiento_id") and not integral(move.movimiento_id): return false
		if not move.get("nombre_interno", "") is String or str(move.get("nombre_interno", "")).is_empty(): return false
		for key: String in ["pp_act", "pp_mas", "pp_tot"]:
			if move.has(key) and not integral(move[key]): return false
	return true

static func total(base: int, bonus: int) -> int:
	return base + base * clampi(bonus, 0, 3) / 5

extends RefCounted
class_name BattleWindAirRules
## Ruby I2 gameplay facts: presentation/aesthetic selectors are not authority.
const IDS=[13,177,314]
static func gameplay_id(move: Movimiento) -> int:
	if move==null:return 0
	if move.datos.has("numero_movimiento"):return int(move.datos.numero_movimiento)
	# Native party moves normally retain the complete database row. Legacy
	# callers may carry only its internal name; resolve the same gameplay row.
	var name: String=move.get_nombre_interno()
	if name not in ["VCORTANTE","AEROCHORRO","AIREAFILADO"]:return 0
	var data: Dictionary=DatabaseManager.obtener_datos_movimiento(name)
	return int(data.get("numero_movimiento",0))
static func supports(move: Movimiento) -> bool:
	return gameplay_id(move) in IDS
static func bind_power(action: BattleMoveAction,move: Movimiento) -> void:
	if gameplay_id(move)==314:action.accepted_power=55

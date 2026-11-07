extends RefCounted
## ProtectStruct numeric BANK lifetime, not SpecialStatus first receipt or Bide sum.
const TYPES=["NORMAL","LUCHA","VOLADOR","VENENO","TIERRA","ROCA","BICHO","FANTASMA","ACERO","???","FUEGO","AGUA","PLANTA","ELECTRICO","PSIQUICO","HIELO","DRAGON","SINIESTRO"]
class Admission extends RefCounted:
	var _owner: WeakRef
	var _flow: Dictionary
	func _init(battle: Node) -> void:
		_owner=weakref(battle);_flow=battle.field_rules.capture_flow()
	func valid(actor: BasePokemon,target: BasePokemon) -> bool:
		var battle: Node=_owner.get_ref()
		if battle==null or _flow.is_empty():return false
		var records: Array[Dictionary]=[];var actor_found: bool=false;var target_found: bool=false
		for record: Dictionary in _flow.records:
			if record.pokemon==actor:actor_found=true
			if record.pokemon==target:target_found=true
			if record.pokemon==actor or record.pokemon==target:records.append(record)
		if not actor_found or not target_found:return false
		# A spread hit may have already retired another bank; that is not this pair.
		var pair_flow: Dictionary=_flow.duplicate();pair_flow.records=records
		return battle.field_rules.valid_flow(pair_flow)
var _owner: WeakRef
var _banks: Dictionary={}
func _init(battle: Node) -> void:_owner=weakref(battle)
static func source_receipt_type(table_type: String,dynamic_type: int) -> String:
	if dynamic_type==0 or dynamic_type&0x40:return table_type
	var index: int=dynamic_type&0x3F
	return TYPES[index] if index<TYPES.size() else ""
static func capture(move: Movimiento,phase: Dictionary) -> Dictionary:
	if move==null:return {}
	var id: int=int(move.datos.get("numero_movimiento",0))
	var rows: Array=preload("res://scripts/battle/conversion_rules.gd").source().move_types
	var table_type: String=str(rows[id]) if id>0 and id<rows.size() else move.get_tipo()
	var dynamic_type: int=0
	if id==237:dynamic_type=int(phase.get("source_hidden_power",{}).get("source_dynamic_type",0xC0)) #0x40 keeps the source table receipt.
	elif phase.has("source_weather_ball"):
		dynamic_type=int(phase.source_weather_ball.source_dynamic_type)
	var receipt_type: String=source_receipt_type(table_type,dynamic_type)
	return {"table_power":preload("res://scripts/battle/rage_rules.gd").table_power(move),"table_type":table_type,"dynamic_type":dynamic_type,"type":receipt_type,"category":1 if TYPES.find(receipt_type)>=0 and TYPES.find(receipt_type)<=8 else 2,"effect":move.get_efecto()}
func admit() -> RefCounted:return Admission.new(_owner.get_ref())
func snapshot(bank: int) -> Dictionary:return _banks.get(bank,{}).duplicate(true)
func receipt(bank: int,category: int) -> Dictionary:return _banks.get(bank,{}).get(category,{}).duplicate(true)
func any_damage(bank: int) -> bool:
	for item: Dictionary in _banks.get(bank,{}).values():
		if int(item.damage)>0:return true
	return false
func record(bank: int,category: int,damage: int,origin_bank: int) -> void:
	if bank<0 or bank>3 or origin_bank<0 or origin_bank>3 or category not in [1,2] or damage<0:return
	if not _banks.has(bank):_banks[bank]={}
	_banks[bank][category]={"damage":damage,"position":origin_bank}
func commit(cause: Dictionary,damage: int) -> void:
	var battle: Node=_owner.get_ref()
	if cause.is_empty() or battle==null or not battle.turno._proveniencia_ataque_vigente(cause):return
	var admission: RefCounted=cause.get("admission")
	if admission==null or not admission.valid(cause.states[1].pokemon,cause.states[0].pokemon):return
	var fact: Dictionary=cause.get("receipt",{})
	if fact.is_empty() or (int(fact.category)==1 and str(fact.effect)=="EFFECT_PAIN_SPLIT"):return
	var victim: Dictionary=cause.states[0];var origin: Dictionary=cause.states[1]
	record(int(victim.position),int(fact.category),damage,int(origin.position))
	var state: PokemonEnCombate=victim.state.get_ref()
	state.show_body_attack_view()
func clear() -> void:_banks.clear()

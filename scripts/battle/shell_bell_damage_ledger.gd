extends RefCounted
## Ruby SpecialStatus.dmg: first capped body/Substitute loss, not Bide history.
const StatusItems=preload("res://scripts/battle/held_status_berry_rules.gd")
static func bind(battle: Node,action: BattleMoveAction) -> void:
	if action.has_meta("source_shell_bell_origin"):return
	# Ownership begins before primary presentation. Item/profile do NOT: source
	# resolves them only at stage9. Never accept a late same-party combat state.
	action.set_meta("source_shell_bell_origin",battle.field_rules.capture_flow())
static func capture(battle: Node,action: BattleMoveAction,actor: BasePokemon,target: BasePokemon,self_ko: bool=false) -> Dictionary:
	if action==null:return {}
	var records: Dictionary=action.get_meta("source_shell_bell_damage",{})
	var key: int=target.get_instance_id()
	if records.has(key):return records[key] if valid(battle,records[key]) else {}
	var flow: Dictionary=action.get_meta("source_shell_bell_origin",{})
	if not battle.field_rules.valid_flow(flow):return {}
	var actor_lease: Dictionary={};var target_lease: Dictionary={}
	for lease: Dictionary in flow.records:
		if lease.pokemon==actor:actor_lease=lease
		if lease.pokemon==target:target_lease=lease
	if not battle.field_rules.valid(actor_lease) or not battle.field_rules.valid(target_lease) or not battle.field_rules.valid_flow(flow):return {}
	var receipt: Dictionary={"actor":actor_lease,"target":target_lease,"flow":flow,"damage":0,"nonzero":false,"self_ko":self_ko,"before_hp":target.estad_ps_actual,"status_items":StatusItems.admission(battle)}
	records[key]=receipt;action.set_meta("source_shell_bell_damage",records);return receipt
static func valid(battle: Node,receipt: Dictionary) -> bool:
	return not receipt.is_empty() and battle.field_rules.valid_flow(receipt.flow) and battle.field_rules.valid(receipt.actor) and battle.field_rules.valid(receipt.target)
static func record(battle: Node,receipt: Dictionary,committed: Dictionary,requested: int) -> void:
	if receipt.is_empty():return
	var target: BasePokemon=receipt.target.pokemon
	# Only this accepted HP operation may retire its original victim once.
	if target.estad_ps_actual==0 and int(committed.get("damage",0))>=int(receipt.before_hp):
		var state: PokemonEnCombate=receipt.target.state.get_ref()
		if state!=null and battle._obtener_combatiente(target)==state and state.body_attack_epoch==int(receipt.target.epoch)+1:
			receipt.target.epoch=state.body_attack_epoch
			for lease: Dictionary in receipt.flow.records:
				if lease.pokemon==target:lease.epoch=state.body_attack_epoch
	if not valid(battle,receipt):return
	receipt.nonzero=requested!=0
	if int(receipt.damage)==0:receipt.damage=int(committed.get("damage",0))
	receipt.before_hp=target.estad_ps_actual

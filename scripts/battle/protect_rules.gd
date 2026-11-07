extends RefCounted
class_name BattleProtectRules
## Ruby939/6087 producer arithmetic and a separate positional projection.
## This helper owns neither PP nor UI. Native lifecycle callers supply ownership.
const FAMILY: Array[int]=[182,197,203]
const THRESHOLDS: Array[int]=[65535,32767,16383,8191]
static func mode(move: Movimiento) -> String:
	if move==null or move.get_prioridad() not in [3,4]:return "" # Ruby3 or imported modern DB4.
	var id: int=int(move.datos.get("numero_movimiento",0))
	if id in [182,197] and move.get_efecto()=="EFFECT_PROTECT":return "protect"
	if id==203 and move.get_efecto()=="EFFECT_ENDURE":return "endure"
	return ""
static func source_priority(move: Movimiento) -> int:
	if move!=null and int(move.datos.get("numero_movimiento",0))==264:return -3 # Ruby Focus Punch, separate before-turn setup.
	if move!=null and int(move.datos.get("numero_movimiento",0)) in [277,289]:return 4 # Ruby Snatch.
	if move!=null and int(move.datos.get("numero_movimiento",0))==270:return 5
	if move!=null and int(move.datos.get("numero_movimiento",0))==245:return 1 # Ruby ExtremeSpeed, not modern+2.
	if move!=null and int(move.datos.get("numero_movimiento",0))==266:return 3 # Ruby Follow Me, not modern+2.
	if move!=null and int(move.datos.get("numero_movimiento",0))==252:return 1 # Ruby Fake Out, not modern+3.
	return 3 if not mode(move).is_empty() else move.get_prioridad() if move!=null else -999
static func capture(move: Movimiento) -> Dictionary:
	if mode(move).is_empty():return {}
	var id: int=int(move.datos.get("numero_movimiento",0));var data: Dictionary=move.datos.duplicate(true)
	data.prioridad=3;data.precision=0;data.objetivo_id=7;data.potencia=0;data.max_pp=5 if id==197 else 10
	return {"id":id,"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_protect"):return move
	var fact: Dictionary=phase.source_protect
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
static func evaluate(state: PokemonEnCombate,move: Movimiento,last: bool,draw: Callable=Callable()) -> Dictionary:
	var kind: String=mode(move)
	if state==null or kind.is_empty():return {"accepted":false,"overflow_adaptation":false,"supported":false}
	if state.source_last_result_move not in FAMILY:state.source_protect_uses=0
	var uses: int=state.source_protect_uses
	# Actual Random() operand evaluates before the not-last condition.
	var value: int=(int(draw.call()) if draw.is_valid() else randi())&65535
	var overflow: bool=uses>=THRESHOLDS.size()
	var accepted: bool=not overflow and uses>=0 and THRESHOLDS[uses]>value and not last
	state.source_protect_uses=uses+1 if accepted else 0
	if accepted:
		if kind=="protect":state.protegido_este_turno=true
		else:state.aguante_este_turno=true
	return {"accepted":accepted,"supported":true,"overflow_adaptation":overflow,"draw":value,"uses_before":uses,"uses_after":state.source_protect_uses}
static func project(slots: Array[Dictionary]) -> Array[Dictionary]:
	if slots.size() not in [2,4]:return []
	var result: Array[Dictionary]=[]
	var banks: Dictionary={}
	for slot: Dictionary in slots:
		var bank: int=int(slot.get("bank",-1))
		if bank<0 or bank>=slots.size() or banks.has(bank):return []
		banks[bank]=true
		var entry: Dictionary=slot.duplicate(true)
		var move: Movimiento=entry.get("move",null)
		entry.priority=source_priority(move) if move!=null else int(entry.get("priority",0))
		entry.selected_id=int(move.datos.get("numero_movimiento",0)) if move!=null else int(entry.get("selected_id",0))
		entry.selected_effect=move.get_efecto() if move!=null else str(entry.get("selected_effect",""))
		entry.erase("move")
		entry.prefix=str(entry.get("kind","move")) in ["item","switch"]
		entry.speed_known=entry.get("speed",null)!=null
		entry.speed_policy="captured-native-speed" if entry.speed_known else "unknown-speed-stable-bank-native-adaptation"
		result.append(entry)
	result.sort_custom(_before)
	for index: int in range(result.size()):
		result[index].index=index;result[index].count=result.size();result[index].last=index==result.size()-1
	return result

## Separate positional facts, never added to the executable queue. Tie ranks
## consume existing sorted order; this capture does not consume any RNG.
static func native_slots(battle: Node,actions: Array[Dictionary]=[],player_nonmove: String="") -> Array[Dictionary]:
	var double: bool=battle.formato_batalla==Singleton.FormatoBatalla.DOBLE
	var slots: Array[Dictionary]=[]
	for bank: int in range(4 if double else 2):
		var player: bool=bank%2==0
		var flank: int=bank/2
		var actor: BasePokemon=null
		var move: Movimiento=null
		var kind: String="move"
		var tie: int=bank
		if double:
			var side: Array=battle.pokemones_activos_jugador if player else battle.pokemones_activos_enemigo
			if flank<side.size():actor=side[flank]
			for index: int in range(actions.size()):
				var action: Dictionary=actions[index]
				if actor==null or action.get("actor",null)!=actor:continue
				move=action.get("movimiento",null);tie=index
				kind={"objeto":"item","cambio":"switch"}.get(str(action.get("tipo","")),"move")
		else:
			actor=battle.poke_jugador if player else battle.poke_enemigo
			move=battle.movimiento_jugador if player else battle.movimiento_enemigo
			if player and player_nonmove in ["item","switch"]:kind=player_nonmove;move=null
			if not player:kind=str(battle.accion_enemiga.get("type","attack"))
			if kind in ["item","switch","flee"]:move=null
			# Native SINGLE equal-speed execution chooses the enemy first.
			tie=1 if player else 0
		var speed: Variant=battle.habilidades.velocidad_de(actor) if actor!=null else null
		slots.append({"bank":bank,"move":move,"kind":kind,"speed":speed,"tie":tie,"order":tie,"dead":actor!=null and actor.estad_ps_actual<=0})
	return project(slots)
static func capture_result(battle: Node,actor: BasePokemon,move: Movimiento) -> Dictionary:
	var original: Dictionary=battle.field_rules.capture(actor)
	if original.is_empty() or move==null:return {}
	var result: Dictionary=ticket(original.state.get_ref(),move.get_efecto())
	result.merge({"owner":weakref(battle),"actor":original,"flow":battle.field_rules.capture_flow(),"selected_id":int(move.datos.get("numero_movimiento",0)),"attempt":RefCounted.new()})
	return result
static func result_live(record: Dictionary) -> bool:
	if record.is_empty():return false
	var battle: Node=record.owner.get_ref()
	return is_instance_valid(battle) and battle.field_rules.valid_flow(record.flow) and battle.field_rules.valid(record.actor)
static func finish_result(record: Dictionary,category: String,action: BattleMoveAction=null) -> bool:
	if record.is_empty():return false
	var battle: Node=record.owner.get_ref()
	# A source-qualified action can reconcile only its proven owned KO epoch,
	# never a replacement state or an arbitrary caller-supplied ownership bit.
	if is_instance_valid(battle) and action!=null and action.has_meta("source_screen_phase_guard"):
		var guard: Dictionary=action.get_meta("source_screen_phase_guard")
		if battle.field_rules.valid_flow(guard.flow):
			for captured: Dictionary in guard.flow.records:
				if captured.pokemon==record.actor.pokemon and captured.state.get_ref()==record.state.get_ref():
					record.flow=guard.flow.duplicate(true);record.actor=captured.duplicate(true)
					if record.actor.pokemon.estad_ps_actual<=0:category="owned_fainted"
	# Sketch needs Ruby's separate MoveEnd printed history, not result history.
	# Ordinary obeying moves write their CHOSEN ID; successful BatonPass keeps
	# the former entry (effect0x7F). Complex called/disobedient history is deferred.
	var failed_pass: bool=action!=null and record.chosen_effect=="EFFECT_BATON_PASS" and action.outcomes.any(func(row: Dictionary)->bool:return str(row.kind)=="failed")
	if result_live(record) and category=="obeying" and (record.chosen_effect!="EFFECT_BATON_PASS" or failed_pass):
		var state: PokemonEnCombate=record.state.get_ref()
		state.source_last_printed_move=65535 if action!=null and action.has_meta("source_sketch_attempt") else int(record.selected_id)
	if result_live(record) and category=="obeying":
		preload("res://scripts/battle/mirror_move_rules.gd").observe(record,action)
		# atkCC's inner script already recorded actual incoming type/outcomes.
		# Its outer chosen267 wrapper must not overwrite those with NORMAL.
		if record.chosen_effect!="EFFECT_BATON_PASS" and not (action!=null and action.has_meta("source_nature_power_called_id")):preload("res://scripts/battle/conversion_rules.gd").observe(battle,action)
	if result_live(record):preload("res://scripts/battle/choice_band_rules.gd").finish(record,category,action)
	var current_id: int=int(action.get_meta("source_nature_power_called_id")) if action!=null and action.has_meta("source_nature_power_called_id") else int(record.selected_id)
	if action!=null and action.has_meta("source_magic_coat_current_id"):current_id=int(action.get_meta("source_magic_coat_current_id"))
	return commit(record,category,current_id,result_live(record))
static func reconcile_damage(action: BattleMoveAction,target: BasePokemon,result: Dictionary,before_hp: int) -> void:
	if not action.has_meta("source_result_ticket") or before_hp<=0 or target.estad_ps_actual!=0 or int(result.get("damage",0))<before_hp:return
	var ticket_record: Dictionary=action.get_meta("source_result_ticket")
	if ticket_record.is_empty():return
	var battle: Node=ticket_record.owner.get_ref()
	if not is_instance_valid(battle):return
	var flow: Dictionary=ticket_record.flow.duplicate(true)
	for record: Dictionary in flow.records:
		var state: PokemonEnCombate=record.state.get_ref()
		if record.pokemon==target and state!=null and battle._obtener_combatiente(target)==state and state.body_attack_epoch==int(record.epoch)+1:record.epoch=state.body_attack_epoch
	if battle.field_rules.valid_flow(flow):ticket_record.flow=flow
static func capture_contact_result(action: BattleMoveAction) -> Dictionary:
	var record: Dictionary=action.get_meta("source_result_ticket",{})
	if not result_live(record):return {}
	return {"record":record,"flow":record.flow.duplicate(true),"hp":action.attacker.estad_ps_actual}
static func complete_contact_result(action: BattleMoveAction,accepted: Dictionary) -> void:
	if accepted.is_empty() or int(accepted.hp)<=0 or action.attacker.estad_ps_actual!=0:return
	var record: Dictionary=accepted.record
	var battle: Node=record.owner.get_ref()
	if not is_instance_valid(battle):return
	var flow: Dictionary=accepted.flow.duplicate(true)
	for actor: Dictionary in flow.records:
		var state: PokemonEnCombate=actor.state.get_ref()
		if actor.pokemon==action.attacker and state==record.state.get_ref() and battle._obtener_combatiente(action.attacker)==state and state.body_attack_epoch==int(actor.epoch)+1:
			actor.epoch=state.body_attack_epoch
			if battle.field_rules.valid_flow(flow):record.flow=flow;record.actor=actor.duplicate(true);record["owned_fainted"]=true
static func _before(a: Dictionary,b: Dictionary) -> bool:
	if bool(a.prefix)!=bool(b.prefix):return bool(a.prefix)
	if a.prefix:return int(a.get("order",a.bank))<int(b.get("order",b.bank))
	if int(a.priority)!=int(b.priority):return int(a.priority)>int(b.priority)
	# Unknown absent-bank speed is not a Ruby speed claim. Keep known captured
	# order first and unknown entries stable; no additional RNG is consumed.
	if bool(a.speed_known)!=bool(b.speed_known):return bool(a.speed_known)
	if a.speed_known and int(a.speed)!=int(b.speed):return int(a.speed)>int(b.speed)
	if a.has("tie") and b.has("tie") and float(a.tie)!=float(b.tie):return float(a.tie)<float(b.tie)
	return int(a.bank)<int(b.bank)
static func ticket(state: PokemonEnCombate,chosen_effect: String="") -> Dictionary:
	return {"state":weakref(state),"chosen_effect":chosen_effect,"committed":false}
static func commit(record: Dictionary,category: String,current_id: int,owned: bool) -> bool:
	if record.is_empty() or bool(record.committed):return false
	record.committed=true
	var state: PokemonEnCombate=record.state.get_ref()
	if not owned or state==null or record.chosen_effect=="EFFECT_BATON_PASS":return false
	if category in ["absent","shared_absent","aborted","non_move"]:return false
	if category in ["unable","exhausted_pp","soundproof","owned_fainted"]:
		state.source_last_chosen_move=65535;state.source_last_result_move=65535
	elif category=="obeying":
		# Ruby MoveEnd stores gChosenMove even on Protect/miss, independently
		# from gCurrentMove and from Sketch's exceptional printed history.
		state.source_last_chosen_move=int(record.get("selected_id",current_id))
		state.source_last_result_move=current_id
	else:return false
	return true

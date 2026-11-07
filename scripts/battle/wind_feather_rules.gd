extends RefCounted
class_name BattleWindFeatherRules
## Candidate-local Ruby acceptance. Visual ARG7 never selects gameplay targets.
const IDS=[239,297,318]
const STATS=["ataque","defensa","velocidad","ataque_especial","defensa_especial"]
static func gameplay_id(move: Movimiento) -> int:
	if move==null:return 0
	if move.datos.has("numero_movimiento"):return int(move.datos.numero_movimiento)
	var name: String=move.get_nombre_interno()
	if name not in ["CICLON","DANZAPLUMA","VIENTOPLATA"]:return 0
	return int(DatabaseManager.obtener_datos_movimiento(name).get("numero_movimiento",0))
static func supports(move: Movimiento) -> bool:return gameplay_id(move) in IDS
static func capture(move: Movimiento) -> Dictionary:
	if not supports(move):return {}
	return {"id":gameplay_id(move),"name":move.nombre,"data":move.datos.duplicate(true),"chance":20 if gameplay_id(move)==239 else 10 if gameplay_id(move)==318 else 0}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_i3"):return move
	var fact: Dictionary=phase.source_i3
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
static func facts(action: BattleMoveAction) -> Dictionary:
	if not action.has_meta("source_screen_phase_guard"):return {}
	return action.get_meta("source_screen_phase_guard").get("source_i3",{})
static func reached_secondary(action: BattleMoveAction,target: BasePokemon,word: int,no_effect: bool,substitute_hit: bool,already_acted: bool,battle: BattleSceneController) -> Array[AccionHabilidad]:
	var result: Array[AccionHabilidad]=[]
	var fact: Dictionary=facts(action)
	if fact.is_empty() or int(fact.id) not in [239,318]:return result
	var records: Array[Dictionary]=[]
	records.assign(action.get_meta("source_i3_secondary",[]))
	for prior: Dictionary in records:
		if prior.target==target:return result
	# Ruby atk15 evaluates one u16 Random()%100 BEFORE NO_EFFECT and SetMoveEffect guards.
	var chance: int=HabilidadesCombate.probabilidad_efecto_secundario(action.attacker,int(fact.chance))
	var roll: int=(word&65535)%100
	var trace: Dictionary={"id":int(fact.id),"target":target,"word":word&65535,"roll":roll,"chance":chance,"no_effect":no_effect,"substitute":substitute_hit,"applied":false}
	records.append(trace);action.set_meta("source_i3_secondary",records)
	if no_effect or roll>chance or not BattleScreenRules.action_live(action):return result
	if int(fact.id)==239:
		if target.estad_ps_actual<=0 or substitute_hit or already_acted or HabilidadesCombate.ignora_efecto_secundario(target) or HabilidadesCombate.evita_retroceso(target):return result
		var state: PokemonEnCombate=battle._obtener_combatiente(target)
		if state!=null:state.retrocede=true;trace.applied=true
	else:
		# Source USER effect bypasses victim Substitute/ShieldDust/KO, not USER death.
		if action.attacker.estad_ps_actual<=0:return result
		# BattleScript_AllStatsUp changes one stat, then awaits its message.
		trace.user_stats_pending=true
	return result
static func take_user_stats(action: BattleMoveAction,target: BasePokemon) -> Array[String]:
	var result: Array[String]=[]
	for trace: Dictionary in action.get_meta("source_i3_secondary",[]):
		if trace.target==target and bool(trace.get("user_stats_pending",false)):
			trace.user_stats_pending=false;result.assign(STATS);return result
	return result
static func claim_user_stat(action: BattleMoveAction,target: BasePokemon,stat: String,battle: BattleSceneController) -> Array[AccionHabilidad]:
	if not BattleScreenRules.action_live(action) or action.attacker.estad_ps_actual<=0:return []
	var state: PokemonEnCombate=battle._obtener_combatiente(action.attacker)
	var result: Array[AccionHabilidad]=EfectosGolpe.cambiar_estadistica(action.attacker,state,stat,1,false)
	if not result.is_empty():
		for trace: Dictionary in action.get_meta("source_i3_secondary",[]):
			if trace.target==target:trace.applied=true
	return result

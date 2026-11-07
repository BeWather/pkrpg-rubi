extends RefCounted
class_name BattleHiddenSecondaryRules
## Ruby Bounce atk15 / SetMoveEffect only. Other moves retain legacy chance.
static func reached(action: BattleMoveAction,target: BasePokemon,word: int,no_effect: bool,substitute_hit: bool,battle: BattleSceneController) -> Array[AccionHabilidad]:
	var result: Array[AccionHabilidad]=[]
	var fact: BattleHiddenActorRules=BattleHiddenActorRules.facts(action)
	if fact==null or fact.source_id()!=340 or not BattleScreenRules.action_live(action):return result
	var traces: Array=action.get_meta("source_i4_secondary",[])
	for prior: Dictionary in traces:
		if prior.target==target:return result
	var chance: int=HabilidadesCombate.probabilidad_efecto_secundario(action.attacker,30)
	var trace: Dictionary={"target":target,"word":word&65535,"roll":(word&65535)%100,"chance":chance,"reason":"chance","applied":false}
	traces.append(trace);action.set_meta("source_i4_secondary",traces)
	# Random() is evaluated before NO_EFFECT, including zero body-HP delta.
	if int(trace.roll)>chance:return result
	trace.reason="no_effect"
	if no_effect:return result
	trace.reason="shield_dust"
	if HabilidadesCombate.ignora_efecto_secundario(target):return result
	var record: Dictionary={}
	for original: Dictionary in action.get_meta("source_screen_phase_guard").flow.records:
		if original.pokemon==target:record=original;break
	if not battle.field_rules.valid(record):trace.reason="stale";return result
	trace.reason="safeguard"
	if battle.safeguard_rules.active_for_original_bank(record):return result
	trace.reason="ko"
	if target.estad_ps_actual<=0:return result
	trace.reason="substitute"
	if substitute_hit:return result # Breaking the original barrier still hit it.
	trace.reason="limber"
	if HabilidadesCombate.tiene(target,HabilidadesCombate.FLEXIBILIDAD):return result
	trace.reason="status"
	if target.estado!=Singleton.ProblemaEstado.NORMAL:return result
	result=EfectosGolpe.aplicar_estado(target,Singleton.ProblemaEstado.PARALIZADO,action.attacker,battle.habilidades.resolutor_combatientes())
	trace.applied=target.estado==Singleton.ProblemaEstado.PARALIZADO
	trace.reason="applied" if bool(trace.applied) else "rejected"
	return result

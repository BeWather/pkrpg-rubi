extends RefCounted
## Ruby Rage: holder volatile, ORIGINAL round choice, persistent Protect BANK read.
## TABLE_POWER from pokeruby5784633 src/data/battle_moves.c, IDs0..354 (NONE0).
const TABLE_POWER=[0, 40, 50, 15, 18, 80, 40, 75, 75, 75, 40, 55, 1, 80, 0, 50, 40, 60, 0, 70, 15, 80, 35, 65, 30, 120, 70, 60, 0, 70, 65, 15, 1, 35, 85, 15, 90, 90, 120, 0, 15, 25, 14, 0, 60, 0, 0, 0, 0, 1, 0, 40, 40, 95, 0, 40, 120, 95, 95, 120, 65, 65, 65, 150, 35, 80, 80, 1, 1, 1, 80, 20, 40, 0, 0, 55, 120, 0, 0, 0, 70, 0, 1, 15, 40, 95, 0, 120, 50, 100, 1, 60, 0, 50, 90, 0, 0, 0, 40, 20, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 200, 100, 20, 20, 65, 65, 120, 80, 35, 60, 100, 20, 10, 0, 0, 0, 85, 0, 100, 0, 15, 20, 0, 140, 0, 20, 70, 0, 0, 1, 0, 0, 90, 250, 18, 50, 0, 75, 80, 0, 0, 80, 1, 70, 0, 50, 0, 10, 40, 0, 0, 0, 60, 40, 0, 1, 0, 100, 0, 1, 0, 40, 0, 40, 0, 60, 0, 0, 90, 20, 65, 0, 100, 0, 0, 0, 55, 0, 25, 0, 90, 0, 60, 0, 0, 30, 40, 0, 0, 65, 10, 70, 0, 0, 0, 0, 1, 1, 1, 0, 0, 100, 1, 100, 120, 60, 0, 0, 40, 20, 0, 100, 50, 70, 0, 0, 0, 1, 100, 40, 0, 0, 80, 1, 0, 80, 60, 80, 80, 20, 15, 10, 40, 50, 0, 100, 0, 100, 0, 0, 0, 0, 0, 70, 150, 60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 120, 0, 0, 60, 75, 0, 20, 1, 150, 0, 0, 0, 0, 0, 70, 60, 15, 0, 0, 70, 70, 0, 0, 85, 0, 30, 60, 0, 90, 50, 75, 150, 150, 100, 30, 50, 0, 0, 55, 140, 0, 50, 60, 0, 0, 0, 0, 150, 75, 60, 80, 85, 15, 1, 95, 10, 60, 10, 0, 0, 0, 80, 150, 0, 85, 55, 50, 40, 120, 60, 0, 0, 70, 0, 25, 60, 60, 120, 140]
static func table_power(move: Movimiento) -> int:
	var id: int=int(move.datos.get("numero_movimiento",0)) if move!=null else 0
	return int(TABLE_POWER[id]) if id>=0 and id<TABLE_POWER.size() else 0
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==99
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true)
	data.numero_movimiento=99;data.tipo="NORMAL";data.categoria_dano_id=1;data.potencia=20;data.precision=100;data.pp=20;data.max_pp=20;data.prioridad=0;data.contacto=1;data.prob_secundario=0;data.efecto="EFFECT_RAGE";data.objetivo_id=10
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_rage"):return move
	if not phase.has("source_rage_admitted"):
		phase.source_rage_admitted=Movimiento.new(str(phase.source_rage.name),move.pp_act,move.pp_mas,move.pp_tot,phase.source_rage.data.duplicate(true))
	return phase.source_rage_admitted
static func choices(battle: Node,actions: Array) -> Array:
	var result: Array=[]
	for lease: Dictionary in battle.field_rules.capture_flow().get("records",[]):
		var id: int=0
		for action: Dictionary in actions:
			if action.get("actor")==lease.pokemon:
				var move: Movimiento=action.get("movimiento")
				id=int(move.datos.get("numero_movimiento",0)) if move!=null else 0
		result.append({"lease":lease,"id":id})
	return result
static func reconcile_choices(battle: Node,selected: Array) -> void:
	for choice: Dictionary in selected:
		if int(choice.id)!=99 and battle.field_rules.valid(choice.lease):choice.lease.state.get_ref().source_rage=false
static func primary(controller: RefCounted,battle: Node,move: Movimiento,phase: Dictionary,actor: BasePokemon,targets: Array) -> void:
	if not supports(move) or phase.has("source_rage_primary") or targets.size()!=1:return
	var redirected: Array[BasePokemon]=preload("res://scripts/battle/thought_finger_rules.gd").redirect(battle,actor,move,targets)
	if redirected.size()!=1:return
	targets.assign(redirected)
	var target: BasePokemon=targets[0]
	var own: Dictionary=battle.field_rules.capture(actor);var other: Dictionary=battle.field_rules.capture(target)
	var fact: Dictionary={"actor":own,"target":other,"hit":false}
	phase.source_rage_primary=fact
	if not battle.field_rules.valid_flow(phase.get("source_rage_flow",{})) or not battle.field_rules.valid(own) or not battle.field_rules.valid(other):return
	fact.hit=not controller._movimiento_bloqueado_por_proteccion(move,actor,target) and controller._movimiento_acierta(move,own.state.get_ref(),other.state.get_ref(),battle.habilidades.crear_campo())
	# EFFECT_RAGE has no AFFECTS_USER bit: target's HP/Substitute gate primary.
	# RageMiss clearstatusfromeffect uses zero mask at0x1E; preserve old flag.
	if bool(fact.hit) and target.estad_ps_actual>0 and other.state.get_ref().substitute_hp<=0:own.state.get_ref().source_rage=true
static func bind(battle: Node,action: BattleMoveAction,phase: Dictionary={}) -> void:
	if not action.has_meta("source_rage_flow"):action.set_meta("source_rage_flow",phase.get("source_rage_flow",battle.field_rules.capture_flow()))
	if phase.has("source_rage_primary"):action.set_meta("source_rage_primary",phase.source_rage_primary)
static func capture_user_faint(battle: Node,action: BattleMoveAction,effects: Array) -> Dictionary:
	var flow: Dictionary=action.get_meta("source_rage_flow",{})
	if not battle.field_rules.valid_flow(flow) or action.attacker.estad_ps_actual<=0:return {}
	for effect: AccionHabilidad in effects:
		if effect.tipo==AccionHabilidad.Tipo.DANO and effect.objetivo==action.attacker and effect.cantidad>=action.attacker.estad_ps_actual:return {"flow":flow.duplicate(true)}
	return {}
static func complete_user_faint(battle: Node,action: BattleMoveAction,fact: Dictionary) -> void:
	if fact.is_empty() or action.attacker.estad_ps_actual!=0:return
	var flow: Dictionary=fact.flow
	var owned: bool=false
	for record: Dictionary in flow.records:
		if record.pokemon!=action.attacker:continue
		var original: PokemonEnCombate=record.state.get_ref()
		# Only this accepted lethal USER effect's one retirement. Never follow a
		# callback replacement, extra epoch, slot generation, round or FIN.
		if original!=null and battle._obtener_combatiente(action.attacker)==original and original.body_attack_epoch==int(record.epoch)+1:record.epoch=original.body_attack_epoch;owned=true
	if owned and battle.field_rules.valid_flow(flow):action.set_meta("source_rage_flow",flow)
static func grow(battle: Node,action: BattleMoveAction,target: BasePokemon) -> bool:
	if action==null or target==null:return true
	var flow: Dictionary=action.get_meta("source_rage_flow",{})
	if not battle.field_rules.valid_flow(flow):return true
	var defender: Dictionary={};var actor: Dictionary={}
	for lease: Dictionary in flow.get("records",[]):
		if lease.pokemon==target:defender=lease
		if lease.pokemon==action.attacker:actor=lease
	if not battle.field_rules.valid(defender) or not battle.field_rules.valid(actor):return true
	if target==action.attacker or bool(defender.bank.player)==bool(actor.bank.player) or target.estad_ps_actual<=0:return true
	var state: PokemonEnCombate=defender.state.get_ref()
	if not state.source_rage or state.mod_ataque>=6:return true
	if int(action.get_meta("source_rage_result_flags",0))&0x29:return true
	var receipt: Dictionary=action.get_meta("source_protect_receipt",{})
	if int(receipt.get("table_power",0))<=0 or not battle.bank_damage_history.any_damage(battle.field_rules.source_bank(defender.bank)):return true
	# Calls reach this seam only after a successful source hit/MoveEnd0. Claim
	# per selected holder/strike; the multihit final stage2/4 cannot replay0.
	var token: String="source_rage_stage0_%d_%d"%[target.get_instance_id(),action.hit_index]
	var stages: Dictionary=action.get_meta("source_rage_stages",{})
	if stages.has(token):return true
	stages[token]=true;action.set_meta("source_rage_stages",stages)
	state.mod_ataque+=1
	await battle.mostrar_texto_batalla("¡La FURIA de %s está creciendo!"%target.get_nombre_combate())
	return battle.field_rules.valid_flow(flow)

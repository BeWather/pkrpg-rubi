extends RefCounted
## Ruby Whirlwind has priority−6 AND a normal accuracy check after its special gate.
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))in [18,46]
static func capture(move: Movimiento,actor: BasePokemon=null,battle: Node=null) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true);data.categoria_dano_id=3;data.potencia=0;data.tipo="NORMAL";data.precision=100;data.max_pp=20;data.pp=20;data.contacto=0;data.objetivo_id=10;data.prioridad=-6;data.prob_secundario=0;data.efecto="EFFECT_ROAR";data.sonido=1 if int(data.get("numero_movimiento",0))==46 else 0
	var levels: Dictionary={}
	if battle!=null:
		for record: Dictionary in battle.field_rules.capture_flow().get("records",[]):levels[record.pokemon]=int(record.pokemon.nivel)
	return {"name":move.nombre,"data":data,"actor_level":int(actor.nivel) if actor!=null else 0,"levels":levels}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_whirlwind"):return move
	var fact: Dictionary=phase.source_whirlwind
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

## Original physical slots, not a compact random pool. Empty slots consume draws.
static func eligible(mon: BasePokemon) -> bool:
	return mon!=null and not mon.nombre_interno.is_empty() and not mon.huevo and mon.estad_ps_actual>0
static func select(party: Array[BasePokemon],active: Array,actor_level: int,target_level: int,double: bool,draw: Callable) -> Dictionary:
	var valid: int=0
	for index: int in 6:
		if index<party.size() and eligible(party[index]):valid+=1
	if valid<(3 if double else 2):return {}
	if not level_passes(actor_level,target_level,draw):return {}
	while true:
		var index: int=(int(draw.call())&65535)%6
		if index<party.size() and eligible(party[index]) and not active.has(party[index]):return {"pokemon":party[index],"index":index}
	return {}
static func level_passes(actor_level: int,target_level: int,draw: Callable) -> bool:
	if actor_level>=target_level:return true
	return (((int(draw.call())&255)*(actor_level+target_level)>>8)+1)>target_level/4

## An accepted switch alone can replace a full-field record in the caller chain.
static func handoff(battle: Node,action: BattleMoveAction,old: Dictionary,entry: Dictionary,flow: Dictionary) -> bool:
	if not battle.field_rules.valid_flow(flow) or not battle.field_rules.valid(entry) or entry.bank!=old.bank:return false
	action.set_meta("source_forced_switch_successor",{"original":old.pokemon,"entry":entry.duplicate(true)})
	var current: BattleMoveAction=action
	while current!=null:
		var guard: Dictionary=current.get_meta("source_screen_phase_guard",{})
		if not guard.is_empty():
			# Every other original occupant must still match before the substitution.
			var replaced: Dictionary=guard.flow.duplicate(true)
			var found: bool=false
			for index: int in replaced.records.size():
				if replaced.records[index].pokemon==old.pokemon and replaced.records[index].state.get_ref()==old.state.get_ref() and int(replaced.records[index].generation)==int(old.generation):replaced.records[index]=entry.duplicate(true);found=true
			if not found or not battle.field_rules.valid_flow(replaced):return false
			guard.flow=replaced
		var parent: WeakRef=guard.get("source_magic_coat_parent_action")
		current=parent.get_ref() if parent!=null else null
	return true

## GetMoveTarget(SELECTED): raw source BANK rejection, before caller animation.
static func called_targets(battle: Node,actor: BasePokemon,draw: Callable) -> Array[BasePokemon]:
	var player: bool=bool(battle.field_rules.position(actor).player)
	var living: Array[BasePokemon]=[]
	var count: int=4 if battle.formato_batalla==Singleton.FormatoBatalla.DOBLE else 2
	for bank: int in count:
		var candidate: BasePokemon=battle.turno._future_occupant(bank)
		if candidate==null or candidate.estad_ps_actual<=0 or bank%2==(0 if player else 1):continue
		living.append(candidate)
		if battle._obtener_combatiente(candidate).source_follow_me:return [candidate]
	if living.is_empty():return []
	while true:
		var candidate: BasePokemon=battle.turno._future_occupant((int(draw.call())&65535)%count)
		if living.has(candidate):return [candidate]
	return []

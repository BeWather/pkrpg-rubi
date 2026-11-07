extends RefCounted
## Ruby ATK49_MIRROR_MOVE incoming CHOSEN history, distinct from last printed/result.
static var _compatible: Array=[]
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==119
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true);data.categoria_dano_id=3;data.potencia=0;data.tipo="VOLADOR";data.precision=0;data.max_pp=20;data.pp=20;data.contacto=0;data.objetivo_id=1;data.source_target_mask=16;data.prioridad=0;data.prob_secundario=0;data.efecto="EFFECT_MIRROR_MOVE"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_mirror_move"):return move
	if phase.has("source_mirror_admitted"):return phase.source_mirror_admitted
	var fact: Dictionary=phase.source_mirror_move;var accepted:=Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true));phase.source_mirror_admitted=accepted;return accepted
static func observe(record: Dictionary,action: BattleMoveAction) -> void:
	var battle: Node=record.owner.get_ref()
	if not is_instance_valid(battle) or action==null:return
	if _compatible.is_empty():
		for id: Variant in JSON.parse_string(FileAccess.get_file_as_string("res://recursos/animaciones/mirror_move_compatible.json")).ids:_compatible.append(int(id))
	var chosen: int=int(record.selected_id);var position: Dictionary=battle.field_rules.position(action.attacker)
	if position.is_empty():return
	var row: int=battle.field_rules.source_bank(position)/2
	for target: BasePokemon in action.targets:
		if target==null or target==action.attacker:continue
		var state: PokemonEnCombate=battle._obtener_combatiente(target)
		# Ruby MoveEnd writes target BANK after the owned replacement, not the
		# withdrawn object's now-retired combat state. This grants no action.
		var successor: Dictionary=action.get_meta("source_forced_switch_successor",{})
		if successor.get("original")==target and battle.field_rules.valid(successor.get("entry",{})):
			target=successor.entry.pokemon;state=successor.entry.state.get_ref()
		if state==null:continue
		var accepted: bool=false
		for outcome: Dictionary in action.outcomes:
			if (outcome.target==target or (successor.get("original")==outcome.target and successor.get("entry",{}).get("pokemon")==target)) and bool(outcome.eligible):accepted=true
		var id: int=chosen if chosen in _compatible and accepted and target.estad_ps_actual>0 else 0
		state.source_last_taken_move=id;state.source_last_taken_from[row]=id
static func select_id(state: PokemonEnCombate,draw: Callable) -> int:
	if state.source_last_taken_move not in [0,65535]:return state.source_last_taken_move
	var first: int=int(state.source_last_taken_from.get(0,0));var second: int=int(state.source_last_taken_from.get(1,0));var a: bool=first not in [0,65535];var b: bool=second not in [0,65535]
	if a and b:return first if int(draw.call())&1 else second
	return first if a else second if b else 0

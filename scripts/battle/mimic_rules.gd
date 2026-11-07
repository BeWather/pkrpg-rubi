extends RefCounted
## Ruby atk9D copies gLastMoves into the current COMBAT slot; never party data.
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==102
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true);data.categoria_dano_id=3;data.potencia=0;data.tipo="NORMAL";data.precision=100;data.max_pp=10;data.pp=10;data.contacto=0;data.objetivo_id=10;data.prioridad=0;data.prob_secundario=0;data.efecto="EFFECT_MIMIC"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_mimic"):return move
	if not phase.has("source_mimic_admitted"):
		var fact: Dictionary=phase.source_mimic;phase.source_mimic_admitted=Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
	return phase.source_mimic_admitted
static func produce(battle: BattleSceneController,actor: BasePokemon,target: BasePokemon,fact: Dictionary) -> bool:
	var own: PokemonEnCombate=battle._obtener_combatiente(actor);var other: PokemonEnCombate=battle._obtener_combatiente(target)
	if own==null or other==null or own.has_meta("transform_domain"):return false
	var id: int=other.source_last_result_move
	if id in [0,65535,118,165,166,102]:return false
	var moves: Array=own.get_movimientos().duplicate();var slot: int=int(fact.get("slot",-1));var original: Movimiento=fact.get("original")
	if slot<0 or slot>=mini(4,moves.size()) or moves[slot]!=original:return false
	for current: Movimiento in moves.slice(0,4):
		if current!=null and int(current.datos.get("numero_movimiento",0))==id:return false
	var copied: Movimiento=preload("res://scripts/battle/thought_finger_rules.gd").called_move(id)
	if copied==null:return false
	var base_pp: Array=JSON.parse_string(FileAccess.get_file_as_string("res://recursos/animaciones/sketch_base_pp.json"))
	copied.datos.max_pp=int(base_pp[id]);copied.datos.pp=int(base_pp[id]);copied.pp_mas=original.pp_mas;copied.calcular_pp_totales();copied.pp_act=mini(5,int(base_pp[id]));moves[slot]=copied
	BattleTransformRules.bind_moves(battle,own,moves)
	return true

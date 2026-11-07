extends RefCounted
## Ruby atkA8 permanently replaces the CURRENT party slot, never the donor object.
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==166
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true);data.categoria_dano_id=3;data.potencia=0;data.tipo="NORMAL";data.precision=0;data.max_pp=1;data.pp=1;data.contacto=0;data.objetivo_id=10;data.prioridad=0;data.prob_secundario=0;data.efecto="EFFECT_SKETCH"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_sketch"):return move
	if phase.has("source_sketch_admitted"):return phase.source_sketch_admitted
	var fact: Dictionary=phase.source_sketch;var accepted:=Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true));phase.source_sketch_admitted=accepted;return accepted
static func produce(battle: Node,actor: BasePokemon,target: BasePokemon,fact: Dictionary) -> bool:
	var own: PokemonEnCombate=battle._obtener_combatiente(actor);var other: PokemonEnCombate=battle._obtener_combatiente(target)
	if own==null or other==null or own.has_meta("transform_domain"):return false
	var id: int=other.source_last_printed_move
	if id in [0,65535,165,166]:return false
	var slot: int=int(fact.get("slot",-1));var original: Movimiento=fact.get("original")
	if slot<0 or slot>=mini(4,actor.movimientos.size()) or actor.movimientos[slot]!=original:return false
	for move: Movimiento in own.get_movimientos().slice(0,4):
		if move!=null and int(move.datos.get("numero_movimiento",0))==id:return false
	var copied: Movimiento=preload("res://scripts/battle/thought_finger_rules.gd").called_move(id)
	if copied==null:return false
	var pp: Array=JSON.parse_string(FileAccess.get_file_as_string("res://recursos/animaciones/sketch_base_pp.json"))
	copied.datos.max_pp=int(pp[id]);copied.datos.pp=int(pp[id]);copied.pp_act=int(pp[id]);copied.pp_mas=original.pp_mas;copied.calcular_pp_totales()
	actor.movimientos[slot]=copied;return true

extends RefCounted
## Ruby ProtectStruct stealMove is a one-use current-round interception, not a party flag.
const KEY="source_snatch_ready"
static var _eligible: Array=[]
static var _self_ids: Array=[]
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==289
static func capture(move: Movimiento) -> Dictionary:
	var d: Dictionary=move.datos.duplicate(true);d.potencia=0;d.precision=100;d.tipo="SINIESTRO";d.categoria_dano_id=3;d.max_pp=10;d.pp=10;d.contacto=0;d.objetivo_id=1;d.source_target_mask=16;d.prioridad=4;d.prob_secundario=0;d.efecto="EFFECT_SNATCH"
	return {"name":move.nombre,"data":d}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_snatch"):return move
	if phase.has("source_snatch_admitted"):return phase.source_snatch_admitted
	var fact: Dictionary=phase.source_snatch;var admitted:=Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true));phase.source_snatch_admitted=admitted;return admitted
static func produce(battle: Node,actor: BasePokemon,fact: Dictionary) -> bool:
	if fact.is_empty() or bool(fact.last):return false
	var state: PokemonEnCombate=battle._obtener_combatiente(actor)
	state.set_meta(KEY,int(battle.contador_turnos));return true
static func self_target(move: Movimiento) -> bool:
	if _self_ids.is_empty():
		for id: Variant in JSON.parse_string(FileAccess.get_file_as_string("res://recursos/animaciones/snatch_eligible.json")).self_ids:_self_ids.append(int(id))
	return int(move.datos.get("numero_movimiento",0)) in _self_ids
static func receiver(battle: Node,move: Movimiento,projection: Array) -> BasePokemon:
	if _eligible.is_empty():
		for id: Variant in JSON.parse_string(FileAccess.get_file_as_string("res://recursos/animaciones/snatch_eligible.json")).ids:_eligible.append(int(id))
	if int(move.datos.get("numero_movimiento",0)) not in _eligible:return null
	for fact: Dictionary in projection:
		for p: BasePokemon in battle.habilidades.crear_campo().todos():
			if p==null or p.estad_ps_actual<=0:continue
			if battle.field_rules.source_bank(battle.field_rules.position(p))!=int(fact.bank):continue
			var state: PokemonEnCombate=battle._obtener_combatiente(p)
			if state!=null and int(state.get_meta(KEY,-1))==int(battle.contador_turnos):state.remove_meta(KEY);return p
	return null
static func present(battle: Node,snatcher: BasePokemon,original: BasePokemon) -> bool:
	var guard: Dictionary=battle.field_rules.capture(snatcher);var donor: Dictionary=battle.field_rules.capture(original)
	if guard.is_empty() or donor.is_empty():return false
	var context:=BattleAnimationContext.from_legacy(MoveAnimationContext.nueva(battle,guard.slot.get_ref(),donor.slot.get_ref()))
	context.set_meta("source_snatcher_id",context.attacker_id);context.set_meta("source_snatch_original_id",context.target_ids[0])
	var animation:=BattleAnimationDirector.play_key("ruby:general/17",context,true);await animation.esperar_finalizada()
	return animation.state=="completed" and battle.field_rules.valid(guard) and battle.field_rules.valid(donor)

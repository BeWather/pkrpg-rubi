extends RefCounted
## Holder-held Ruby volatile, consulted against CURRENT effective moves each time.
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0))==286
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true)
	data.categoria_dano_id=3;data.potencia=0;data.tipo="PSIQUICO";data.precision=100;data.max_pp=10;data.pp=10;data.contacto=0;data.objetivo_id=7;data.prioridad=0;data.prob_secundario=0;data.efecto="EFFECT_IMPRISON"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_imprison"):return move
	var fact: Dictionary=phase.source_imprison
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
static func _id(move: Movimiento) -> int:
	return int(move.datos.get("numero_movimiento",0)) if move!=null else 0
static func _has(pokemon: BasePokemon,id: int) -> bool:
	if id<=0:return false
	for move: Movimiento in BattleTransformRules.moves(pokemon).slice(0,4):
		if _id(move)==id:return true
	return false
static func sealed(battle: Node,actor: BasePokemon,move: Movimiento) -> bool:
	if actor==null or move==null:return false
	var position: Dictionary=battle.field_rules.position(actor)
	if position.is_empty():return false
	for bank: int in range(4 if battle.formato_batalla==Singleton.FormatoBatalla.DOBLE else 2):
		if bank%2==(0 if bool(position.player) else 1):continue
		var holder: BasePokemon=battle.turno._future_occupant(bank)
		if holder==null or holder.estad_ps_actual<=0:continue
		var state: PokemonEnCombate=battle._obtener_combatiente(holder)
		if state!=null and state.source_imprison_active and _has(holder,_id(move)):return true
	return false
static func produce(battle: Node,actor: BasePokemon,admitted: Movimiento) -> bool:
	var state: PokemonEnCombate=battle._obtener_combatiente(actor)
	if state==null or state.source_imprison_active:return false
	# Ruby charges extra Pressure to the current Imprison slot in atkDB,
	# after ordinary PP deduction, including a fresh failed establishment.
	for move: Movimiento in BattleTransformRules.moves(actor).slice(0,4):
		if _id(move)==286:
			move.pp_act=maxi(0,move.pp_act-battle.field_rules.pressure(actor));admitted.pp_act=move.pp_act;break
	# Preserve actual Ruby r8=0 establishment quirk: side1 banks are scanned
	# even for an enemy holder. IsImprisoned itself uses opposing holders.
	for bank: int in range(1,4 if battle.formato_batalla==Singleton.FormatoBatalla.DOBLE else 2,2):
		var candidate: BasePokemon=battle.turno._future_occupant(bank)
		if candidate==null:continue
		for move: Movimiento in BattleTransformRules.moves(actor).slice(0,4):
			if _has(candidate,_id(move)):state.source_imprison_active=true;return true
	return false

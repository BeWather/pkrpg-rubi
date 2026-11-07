extends RefCounted
## Ruby atkA1/A2: latest body category receipt, bank target, immutable pre-PP fact.
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0)) in [68,243]
static func capture(move: Movimiento) -> Dictionary:
	var physical: bool=int(move.datos.numero_movimiento)==68
	var data: Dictionary=move.datos.duplicate(true)
	data.categoria_dano_id=1 if physical else 2;data.potencia=1;data.tipo="LUCHA" if physical else "PSIQUICO";data.precision=100;data.max_pp=20;data.pp=20;data.contacto=1 if physical else 0;data.objetivo_id=10;data.prioridad=-5;data.prob_secundario=0;data.efecto="EFFECT_COUNTER" if physical else "EFFECT_MIRROR_COAT"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_retaliation"):return move
	var policy: Dictionary=phase.source_retaliation
	return Movimiento.new(str(policy.name),move.pp_act,move.pp_mas,move.pp_tot,policy.data.duplicate(true))
static func prepare(battle: Node,actor: BasePokemon,move: Movimiento,phase: Dictionary) -> Dictionary:
	if phase.has("source_retaliation_fact"):return phase.source_retaliation_fact
	var fact: Dictionary={"holder":battle.field_rules.capture(actor),"target":{},"damage":0,"eligible":false}
	phase.source_retaliation_fact=fact
	if not battle.field_rules.valid(fact.holder):return fact
	var state: PokemonEnCombate=fact.holder.state.get_ref()
	var category: int=1 if int(move.datos.numero_movimiento)==68 else 2
	var receipt: Dictionary=battle.bank_damage_history.receipt(battle.turno._future_position(actor),category)
	if int(receipt.get("damage",0))<=0:return fact
	# Ruby records BANK identity, intentionally not original origin's state lease.
	var origin: BasePokemon=battle.turno._future_occupant(int(receipt.position))
	if origin==null or origin.estad_ps_actual<=0:return fact
	var own: Dictionary=battle.field_rules.position(actor);var other: Dictionary=battle.field_rules.position(origin)
	if own.is_empty() or other.is_empty() or bool(own.player)==bool(other.player):return fact
	var target: BasePokemon=origin
	var side: Array=battle.pokemones_activos_jugador if bool(other.player) else battle.pokemones_activos_enemigo
	for pokemon: BasePokemon in side:
		var candidate: PokemonEnCombate=battle._obtener_combatiente(pokemon)
		if pokemon!=null and pokemon.estad_ps_actual>0 and candidate!=null and candidate.source_follow_me:target=pokemon;break
	fact.target=battle.field_rules.capture(target)
	fact.eligible=battle.field_rules.valid(fact.target);fact.damage=2*int(receipt.damage)
	return fact
static func targets(fact: Dictionary,actor: BasePokemon) -> Array[BasePokemon]:
	var result: Array[BasePokemon]=[fact.target.pokemon if bool(fact.eligible) else actor]
	return result
static func live(battle: Node,fact: Dictionary) -> bool:
	return not fact.is_empty() and battle.field_rules.valid(fact.holder) and (not bool(fact.eligible) or battle.field_rules.valid(fact.target))
static func result(move: Movimiento,target: BasePokemon,state: PokemonEnCombate,damage: int) -> ResultadoMovimiento:
	var answer:=ResultadoMovimiento.new()
	var effectiveness: float=MoveResolver.calc_efectividad(move,target,state)
	if effectiveness==0.0 or (HabilidadesCombate.tiene(target,HabilidadesCombate.SUPERGUARDA) and effectiveness<=1.0):
		answer.effectiveness=0.0;answer.message="No afecta a\n%s..."%target.get_nombre_combate()
	else:answer.damage=damage
	return answer

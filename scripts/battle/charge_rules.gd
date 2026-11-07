extends RefCounted
## Ruby atkCB + ENDTURN_CHARGE, separate from two-turn charging continuations.
## atk05 checks gBattleMoves[gCurrentMove].type, NOT dynamicMoveType.
const ELECTRIC_SOURCE_MOVES=[9,84,85,86,87,192,209,268,344,351]
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==268
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true);data.tipo="ELECTRICO";data.categoria_dano_id=3;data.potencia=0;data.precision=100;data.max_pp=20;data.pp=20;data.contacto=0;data.objetivo_id=7;data.prioridad=0;data.prob_secundario=0;data.efecto="EFFECT_CHARGE"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_charge"):return move
	var fact: Dictionary=phase.source_charge
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
static func boosted(move: Movimiento,state: PokemonEnCombate) -> bool:
	return state!=null and state.pokemon_base.estad_ps_actual>0 and state.source_charge_turns>0 and int(move.datos.get("numero_movimiento",0)) in ELECTRIC_SOURCE_MOVES

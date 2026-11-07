class_name BattleIdentifiedRules
extends RefCounted
## Ruby STATUS2_FORESIGHT belongs to the identified target, without a timer.
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0)) in [193,316]
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true)
	data.categoria_dano_id=3;data.potencia=0;data.tipo="NORMAL";data.precision=100;data.max_pp=40;data.pp=40;data.objetivo_id=10;data.contacto=0;data.prob_secundario=0;data.efecto="EFFECT_FORESIGHT"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_identified"):return move
	var fact: Dictionary=phase.source_identified
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
static func produce(target: PokemonEnCombate) -> bool:
	if target==null or target.pokemon_base.estad_ps_actual<=0:return false
	target.source_identified=true;return true

extends RefCounted
## Ruby atkBD copies statStages before animation, even when stages are equal.
## Seven live modifiers represent the source's battle-relevant stages; unused HP stage has no domain field.
const STAGES=["mod_ataque","mod_defensa","mod_ataque_especial","mod_defensa_especial","mod_velocidad","mod_precision","mod_evasion"]
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==244
static func capture(move: Movimiento) -> Dictionary:
	var d: Dictionary=move.datos.duplicate(true);d.tipo="NORMAL";d.categoria_dano_id=3;d.potencia=0;d.precision=0;d.max_pp=10;d.pp=10;d.objetivo_id=10;d.prioridad=0;d.contacto=0;d.prob_secundario=0;d.efecto="EFFECT_PSYCH_UP"
	return {"name":move.nombre,"data":d}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_psych_up"):return move
	if not phase.has("source_psych_up_admitted"):
		var fact: Dictionary=phase.source_psych_up;phase.source_psych_up_admitted=Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
	return phase.source_psych_up_admitted
static func produce(user: PokemonEnCombate,target: PokemonEnCombate) -> bool:
	if user==null or target==null:return false
	for property: String in STAGES:user.set(property,target.get(property))
	return true

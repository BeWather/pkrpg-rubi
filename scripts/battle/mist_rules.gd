extends RefCounted
## Mist is side-held, not a transferable combatant flag. Certain user drops/Curse bypass it.
static func supports(m: Movimiento) -> bool:return m!=null and int(m.datos.get("numero_movimiento",0))==54
static func capture(m: Movimiento) -> Dictionary:
	var d: Dictionary=m.datos.duplicate(true);d.tipo="HIELO";d.categoria_dano_id=3;d.potencia=0;d.precision=0;d.max_pp=30;d.pp=30;d.objetivo_id=7;d.prioridad=0;d.contacto=0;d.prob_secundario=0;d.efecto="EFFECT_MIST"
	return {"name":m.nombre,"data":d}
static func accepted_move(phase: Dictionary,m: Movimiento) -> Movimiento:
	if not phase.has("source_mist"):return m
	if not phase.has("source_mist_admitted"):
		var f: Dictionary=phase.source_mist;phase.source_mist_admitted=Movimiento.new(str(f.name),m.pp_act,m.pp_mas,m.pp_tot,f.data.duplicate(true))
	return phase.source_mist_admitted
static func blocks(state: PokemonEnCombate) -> bool:
	if state==null or not state.has_meta("source_mist_authority"):return false
	var fact: Dictionary=state.get_meta("source_mist_authority");var authority: BattleScreenRules=fact.authority.get_ref()
	return authority!=null and authority.remaining(int(fact.side),"EFFECT_MIST")>0

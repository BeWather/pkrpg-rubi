extends RefCounted
## Ruby Focus Energy: combat-only +2 critical stages, no round timer.
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==116
static func capture(move: Movimiento) -> Dictionary:
	var d: Dictionary=move.datos.duplicate(true);d.tipo="NORMAL";d.categoria_dano_id=3;d.potencia=0;d.precision=0;d.max_pp=30;d.pp=30;d.objetivo_id=7;d.prioridad=0;d.contacto=0;d.prob_secundario=0;d.efecto="EFFECT_FOCUS_ENERGY"
	return {"name":move.nombre,"data":d}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_focus_energy"):return move
	if not phase.has("source_focus_energy_admitted"):
		var fact: Dictionary=phase.source_focus_energy;phase.source_focus_energy_admitted=Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
	return phase.source_focus_energy_admitted
static func produce(state: PokemonEnCombate) -> ResultadoEstado:
	var result:=ResultadoEstado.new()
	if state==null or state.source_focus_energy:result.mensaje="¡Pero falló!";return result
	state.source_focus_energy=true;result.aplicado=true;result.mensaje="¡%s está reuniendo su concentración!"%state.pokemon_base.get_nombre_combate();return result

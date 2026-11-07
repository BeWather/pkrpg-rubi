extends RefCounted
## Ruby atkCD clears eligible status1 before animation; status2/3 are untouched.
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==287
static func capture(move: Movimiento) -> Dictionary:
	var d: Dictionary=move.datos.duplicate(true);d.tipo="NORMAL";d.categoria_dano_id=3;d.potencia=0;d.precision=100;d.max_pp=20;d.pp=20;d.objetivo_id=7;d.prioridad=0;d.contacto=0;d.prob_secundario=0;d.efecto="EFFECT_REFRESH"
	return {"name":move.nombre,"data":d}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_refresh_move"):return move
	if not phase.has("source_refresh_admitted"):
		var fact: Dictionary=phase.source_refresh_move;phase.source_refresh_admitted=Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
	return phase.source_refresh_admitted
static func produce(pokemon: BasePokemon,state: PokemonEnCombate) -> bool:
	if pokemon==null or state==null or pokemon.estad_ps_actual<=0 or pokemon.estado not in [Singleton.ProblemaEstado.ENVENENADO,Singleton.ProblemaEstado.QUEMADO,Singleton.ProblemaEstado.PARALIZADO]:return false
	pokemon.estado=Singleton.ProblemaEstado.NORMAL;state.envenenamiento_grave=false;state.contador_veneno_grave=0;return true

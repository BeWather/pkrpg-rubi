extends RefCounted
## Ruby doubles complete base (+2 included), then removes paralysis after a real body hit.
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==265
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true);data.categoria_dano_id=1;data.potencia=60;data.tipo="NORMAL";data.precision=100;data.max_pp=10;data.pp=10;data.contacto=1;data.objetivo_id=10;data.prioridad=0;data.prob_secundario=0;data.efecto="EFFECT_SMELLINGSALT"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_smelling_salt"):return move
	var fact: Dictionary=phase.source_smelling_salt
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
static func multiplier(target: BasePokemon,state: PokemonEnCombate) -> int:
	return 2 if target!=null and target.estado==Singleton.ProblemaEstado.PARALIZADO and state!=null and state.substitute_hp==0 else 1
static func cure(target: BasePokemon,substitute_hit: bool) -> bool:
	if target==null or substitute_hit or target.estad_ps_actual<=0 or target.estado!=Singleton.ProblemaEstado.PARALIZADO:return false
	target.estado=Singleton.ProblemaEstado.NORMAL;return true

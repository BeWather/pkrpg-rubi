extends RefCounted
## Ruby environment→temporary combat type; never rewrite the saved party identity.
const TYPES=["PLANTA","PLANTA","TIERRA","AGUA","AGUA","AGUA","ROCA","ROCA","NORMAL","NORMAL"]
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==293
static func capture(move: Movimiento) -> Dictionary:
	var d: Dictionary=move.datos.duplicate(true);d.tipo="NORMAL";d.categoria_dano_id=3;d.potencia=0;d.precision=100;d.max_pp=20;d.pp=20;d.objetivo_id=7;d.contacto=0;d.prioridad=0;d.prob_secundario=0;d.efecto="EFFECT_CAMOUFLAGE"
	return {"name":move.nombre,"data":d}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_camouflage"):return move
	var fact: Dictionary=phase.source_camouflage
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
static func produce(battle: BattleSceneController,actor: BasePokemon) -> bool:
	var type: String=TYPES[int(battle.obtener_terreno_batalla())]
	if type in BattleTransformRules.types(actor):return false
	BattleTransformRules.bind_types(battle,battle._obtener_combatiente(actor),type,type);return true

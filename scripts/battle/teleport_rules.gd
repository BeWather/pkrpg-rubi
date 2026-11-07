extends RefCounted
## Ruby Teleport calls CanRunFromBattle, not the menu's random/speed flee formula.
static func supports(m: Movimiento) -> bool:return m!=null and int(m.datos.get("numero_movimiento",0))==100
static func capture(m: Movimiento) -> Dictionary:
	var d: Dictionary=m.datos.duplicate(true);d.tipo="PSIQUICO";d.categoria_dano_id=3;d.potencia=0;d.precision=0;d.max_pp=20;d.pp=20;d.objetivo_id=7;d.prioridad=0;d.contacto=0;d.prob_secundario=0;d.efecto="EFFECT_TELEPORT"
	return {"name":m.nombre,"data":d}
static func accepted_move(phase: Dictionary,m: Movimiento) -> Movimiento:
	if not phase.has("source_teleport"):return m
	if not phase.has("source_teleport_admitted"):
		var f: Dictionary=phase.source_teleport;phase.source_teleport_admitted=Movimiento.new(str(f.name),m.pp_act,m.pp_mas,m.pp_tot,f.data.duplicate(true))
	return phase.source_teleport_admitted
static func restriction(battle: Node,actor: BasePokemon) -> Dictionary:
	if battle.tipo_batalla==Singleton.TipoBatalla.ENTRENADOR:return {"reason":"trainer"}
	# CanRunFromBattle: held effect / Run Away precede abilities and volatile traps.
	if BattleHeldItemRules.held(actor)=="BOLADEHUMO" or HabilidadesCombate.tiene(actor,HabilidadesCombate.FUGA):return {}
	var field: CampoCombate=battle.habilidades.crear_campo();var types: Array[String]=BattleTransformRules.types(actor)
	for foe: BasePokemon in field.rivales_de(actor):
		var ability: String=HabilidadesCombate.de(foe)
		if ability==HabilidadesCombate.SOMBRATRAMPA or (ability==HabilidadesCombate.TRAMPAARENA and not HabilidadesCombate.tiene(actor,HabilidadesCombate.LEVITACION) and not types.has("VOLADOR")):
			return {"reason":"ability","bloqueador":foe,"habilidad":ability}
	for foe: BasePokemon in field.rivales_de(actor):
		if HabilidadesCombate.tiene(foe,HabilidadesCombate.IMAN) and types.has("ACERO"):return {"reason":"ability","bloqueador":foe,"habilidad":HabilidadesCombate.IMAN}
	var state: PokemonEnCombate=battle._obtener_combatiente(actor)
	if state!=null and (state.esta_atrapado or state.source_ingrain_rooted or not preload("res://scripts/battle/escape_prevention_rules.gd").blocked(actor,field).is_empty()):return {"reason":"volatile"}
	if battle.primer_combate:return {"reason":"first_battle"}
	return {}

extends RefCounted
## Ruby Uproar shares the existing user-held multi-turn lock, never a second timer.
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==253
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true);data.categoria_dano_id=1;data.potencia=50;data.tipo="NORMAL";data.precision=100;data.max_pp=10;data.pp=10;data.contacto=0;data.sonido=1;data.objetivo_id=8;data.prioridad=0;data.prob_secundario=100;data.efecto="EFFECT_UPROAR"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_uproar"):return move
	var owner: Node=phase.owner.get_ref() if phase.has("owner") else null;var actor: BasePokemon=phase.get("actor",{}).get("pokemon",null)
	if owner!=null and actor!=null and BattleRampageRules.move(owner,actor)==move:return move
	var fact: Dictionary=phase.source_uproar
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
static func blocks_sleep(owner: Node,recipient: BasePokemon) -> bool:
	if recipient==null or HabilidadesCombate.tiene(recipient,HabilidadesCombate.INSONORIZAR):return false
	for actor: BasePokemon in owner.habilidades.crear_campo().todos():
		var locked: Movimiento=BattleRampageRules.move(owner,actor)
		if locked!=null and locked.get_efecto()=="EFFECT_UPROAR":return true
	return false
static func wake(owner: Node,recipient: BasePokemon) -> bool:
	if recipient==null or recipient.estado!=Singleton.ProblemaEstado.DORMIDO or not blocks_sleep(owner,recipient):return false
	var state: PokemonEnCombate=owner._obtener_combatiente(recipient)
	recipient.estado=Singleton.ProblemaEstado.NORMAL
	if state!=null:state.turnos_dormido=0;state.source_nightmare=false
	if owner.hud!=null:owner.hud._actualizar_estado_visual_pokemon(recipient)
	return true
static func end_round(owner: Node,actor: BasePokemon,state: PokemonEnCombate) -> void:
	var locked: Movimiento=BattleRampageRules.move(owner,actor)
	if locked==null or locked.get_efecto()!="EFFECT_UPROAR" or state.rampage_last_round==int(owner.contador_turnos):return
	for sleeper: BasePokemon in owner.habilidades.crear_campo().todos():
		if wake(owner,sleeper):await owner.mostrar_texto_batalla("¡El alboroto despertó a %s!"%sleeper.get_nombre_combate())
	BattleRampageRules.finish_round(owner,state,int(owner.contador_turnos))
	await owner.mostrar_texto_batalla("¡%s se calmó!"%actor.get_nombre_combate() if state.rampage_turns==0 else "¡%s sigue causando\nalboroto!"%actor.get_nombre_combate())

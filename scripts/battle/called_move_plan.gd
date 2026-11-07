extends RefCounted
## Shared called-action target planning; receives an unowned immutable move policy.
static func capture(battle: BattleSceneController,actor: BasePokemon,move: Movimiento,self_target: bool) -> Dictionary:
	var pos: Dictionary=battle.field_rules.position(actor)
	if pos.is_empty() or move==null:return {}
	var allies: Array[BasePokemon]=battle.pokemones_activos_jugador if bool(pos.player) else battle.pokemones_activos_enemigo
	var rivals: Array[BasePokemon]=battle.pokemones_activos_enemigo if bool(pos.player) else battle.pokemones_activos_jugador
	if battle.formato_batalla==Singleton.FormatoBatalla.SIMPLE:
		allies=[actor];rivals=[battle.poke_enemigo if actor==battle.poke_jugador else battle.poke_jugador]
	var scope: int=AlcanceMovimientoGen3.tipo(move,self_target)
	var targets: Array[BasePokemon]=AlcanceMovimientoGen3.objetivos(scope,actor,null,allies,rivals)
	if preload("res://scripts/battle/whirlwind_rules.gd").supports(move):
		targets=preload("res://scripts/battle/whirlwind_rules.gd").called_targets(battle,actor,battle.turno._sortear_objetivo_arrastre_llamado_source.bind(actor))
	elif scope==AlcanceMovimientoGen3.SELECCIONADO and rivals.size()>1:
		var living: Array[BasePokemon]=[]
		for rival: BasePokemon in rivals:
			if rival!=null and rival.estad_ps_actual>0:living.append(rival)
		if not living.is_empty():targets=[living[randi()%living.size()]]
	return {"move":move,"targets":targets,"spread":scope==AlcanceMovimientoGen3.AMBOS_RIVALES and rivals.size()==2}

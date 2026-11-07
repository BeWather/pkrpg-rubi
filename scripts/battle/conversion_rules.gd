extends RefCounted
## Ruby battle-only type producers, ordered move-slot and raw effectiveness pools.
static var _source: Dictionary={}
static func source() -> Dictionary:
	if _source.is_empty():_source=JSON.parse_string(FileAccess.get_file_as_string("res://recursos/animaciones/conversion_source_tables.json"))
	return _source
static func supports(m: Movimiento) -> bool:return m!=null and int(m.datos.get("numero_movimiento",0)) in [160,176]
static func capture(m: Movimiento) -> Dictionary:
	var d: Dictionary=m.datos.duplicate(true);d.tipo="NORMAL";d.categoria_dano_id=3;d.potencia=0;d.precision=0 if int(d.numero_movimiento)==160 else 100;d.max_pp=30;d.pp=30;d.objetivo_id=7;d.prioridad=0;d.contacto=0;d.prob_secundario=0;d.efecto="EFFECT_CONVERSION" if int(d.numero_movimiento)==160 else "EFFECT_CONVERSION_2"
	return {"name":m.nombre,"data":d}
static func accepted_move(phase: Dictionary,m: Movimiento) -> Movimiento:
	if not phase.has("source_conversion"):return m
	if not phase.has("source_conversion_admitted"):
		var f: Dictionary=phase.source_conversion;phase.source_conversion_admitted=Movimiento.new(str(f.name),m.pp_act,m.pp_mas,m.pp_tot,f.data.duplicate(true))
	return phase.source_conversion_admitted
static func observe(battle: Node,action: BattleMoveAction) -> void:
	if action==null or not action.has_meta("source_landed_policy"):return
	var fact: Dictionary=action.get_meta("source_landed_policy")
	for victim: BasePokemon in action.targets:
		var state: PokemonEnCombate=battle._obtener_combatiente(victim)
		if state==null:continue
		var accepted: bool=false
		for result: Dictionary in action.outcomes:
			if result.target==victim and bool(result.eligible):accepted=true
		# atk49: gLastHitBy se escribe salvo si el objetivo ya cayó, con o sin efecto.
		if victim.estad_ps_actual>0 and action.attacker!=null:
			state.source_last_hit_by=battle.turno._posicion_pokemon(action.attacker);state.source_last_hit_by_pokemon=action.attacker
		state.source_last_landed_move=int(fact.id) if accepted else 65535
		if accepted:state.source_last_hit_type=str(fact.type)
static func produce(battle: BattleSceneController,actor: BasePokemon,id: int,draw: Callable) -> bool:
	var state: PokemonEnCombate=battle._obtener_combatiente(actor);var current: Array[String]=BattleTransformRules.types(actor);var chosen: String=""
	if id==160:
		var pool: Array[String]=[]
		for m: Movimiento in state.get_movimientos().slice(0,4):
			if m==null or int(m.datos.get("numero_movimiento",0))==0:break
			var type: String=str(source().move_types[int(m.datos.numero_movimiento)])
			if type=="???":type="FANTASMA" if current.has("FANTASMA") else "NORMAL"
			pool.append(type)
		var valid: bool=false
		for type: String in pool:
			if not current.has(type):valid=true
		if not valid:return false
		while chosen.is_empty():
			var index: int=int(draw.call())&3
			if index<pool.size() and not current.has(pool[index]):chosen=pool[index]
	else:
		if state.source_last_landed_move in [0,65535]:return false
		if state.source_last_landed_move in source().two_turn_ids and not state.has_body_damage():return false
		var rows: Array=source().effectiveness;var last: int=0
		for attempt: int in 1000:
			last=int(draw.call())&127
			# Ruby accepts index112 beyond its112-triple table. Do not emulate
			# adjacent-ROM reads; bounded rejection is a disclosed EDGE limit.
			while last>=rows.size():last=int(draw.call())&127
			var row: Array=rows[last]
			if str(row[0])==state.source_last_hit_type and int(row[2])<=5 and not current.has(str(row[1])):chosen=str(row[1]);break
		if chosen.is_empty():
			# Preserve source's stale sampled-index type test in the linear fallback.
			for row: Array in rows:
				if str(row[0]) not in ["0xFE","0xFF"] and str(row[0])==state.source_last_hit_type and int(row[2])<=5 and not current.has(str(rows[last][1])):chosen=str(row[1]);break
	if chosen.is_empty():return false
	BattleTransformRules.bind_types(battle,state,chosen,chosen);return true

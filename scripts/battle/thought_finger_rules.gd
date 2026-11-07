extends RefCounted
## Ruby Metronome selection, Taunt power restriction and Follow Me live side holder.
## Actual Ruby table power0 IDs; null modern OHKO/Counter power must not seal them.
const ZERO_POWER: Array[int]=[14, 18, 28, 39, 43, 45, 46, 47, 48, 50, 54, 73, 74, 77, 78, 79, 81, 86, 92, 95, 96, 97, 100, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 118, 119, 133, 134, 135, 137, 139, 142, 144, 147, 148, 150, 151, 156, 159, 160, 164, 166, 169, 170, 171, 174, 176, 178, 180, 182, 184, 186, 187, 191, 193, 194, 195, 197, 199, 201, 203, 204, 207, 208, 212, 213, 214, 215, 219, 220, 226, 227, 230, 234, 235, 236, 240, 241, 244, 254, 256, 258, 259, 260, 261, 262, 266, 267, 268, 269, 270, 271, 272, 273, 274, 275, 277, 278, 281, 285, 286, 287, 288, 289, 293, 294, 297, 298, 300, 303, 312, 313, 316, 319, 320, 321, 322, 334, 335, 336, 339, 346, 347, 349]
const FORBIDDEN: Array[int]=[118,165,166,102,68,243,182,197,203,194,214,168,266,289,270,343,271,264]
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0)) in [118,269,266]
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true);var id: int=int(data.numero_movimiento)
	data.categoria_dano_id=3;data.potencia=0;data.tipo="SINIESTRO" if id==269 else "NORMAL";data.precision=0 if id==118 else 100;data.max_pp=10 if id==118 else 20;data.pp=data.max_pp;data.contacto=0;data.prioridad=3 if id==266 else 0;data.prob_secundario=0;data.objetivo_id=10 if id==269 else 7 if id==266 else 1;data.source_target_mask=0 if id==269 else 16 if id==118 else 2
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_thought_finger"):return move
	var fact: Dictionary=phase.source_thought_finger
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
static func blocked(battle: Node,actor: BasePokemon,move: Movimiento) -> bool:
	var state: PokemonEnCombate=battle._obtener_combatiente(actor) if actor!=null else null
	if state==null or state.source_taunt_turns<=0 or move==null:return false
	var id: int=int(move.datos.get("numero_movimiento",0))
	return id in ZERO_POWER if id>=1 and id<=354 else move.get_potencia()==0
static func taunt(state: PokemonEnCombate) -> bool:
	if state==null or state.source_taunt_turns>0:return false
	state.source_taunt_turns=2;return true
static func follow(battle: Node,actor: BasePokemon) -> bool:
	var position: Dictionary=battle.field_rules.position(actor)
	if position.is_empty():return false
	for pokemon: BasePokemon in battle.pokemones_activos_jugador if bool(position.player) else battle.pokemones_activos_enemigo:
		var other: PokemonEnCombate=battle._obtener_combatiente(pokemon)
		if other!=null:other.source_follow_me=false
	var state: PokemonEnCombate=battle._obtener_combatiente(actor)
	if state==null:return false
	state.source_follow_me=true;return true
static func redirect(battle: Node,actor: BasePokemon,move: Movimiento,targets: Array[BasePokemon]) -> Array[BasePokemon]:
	if move==null or move.get_objetivo_id()!=10 or targets.size()!=1 or targets[0]==actor:return targets
	var position: Dictionary=battle.field_rules.position(actor)
	if position.is_empty():return targets
	for pokemon: BasePokemon in battle.pokemones_activos_enemigo if bool(position.player) else battle.pokemones_activos_jugador:
		var state: PokemonEnCombate=battle._obtener_combatiente(pokemon)
		if pokemon!=null and pokemon.estad_ps_actual>0 and state!=null and state.source_follow_me:return [pokemon]
	return targets
static func select_id(draw: Callable) -> int:
	while true:
		var id: int=(int(draw.call())&511)+1
		if id<=354 and id not in FORBIDDEN:return id
	return 0
static func called_move(id: int) -> Movimiento:
	if not DatabaseManager.ejecutar_consulta("SELECT m.*,t.nombre AS tipo_nombre FROM Movimientos m LEFT JOIN Tipos t ON m.tipo_id=t.id WHERE m.numero_movimiento=%d"%id):return null
	var rows: Array=DatabaseManager.obtener_resultados()
	if rows.is_empty():return null
	var data: Dictionary=rows[0].duplicate(true);data.potencia=0 if data.poder==null else int(data.poder);data.tipo=str(data.tipo_nombre)
	return Movimiento.new(str(data.nombre_interno),int(data.pp),0,int(data.pp),data)

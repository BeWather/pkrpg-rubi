extends RefCounted
## Explicit represented subset of Ruby SwitchInClearSetData, never a combat-state clone.
const FIELDS=["source_perish_song","source_perish_count","source_focus_energy","mod_ataque","mod_defensa","mod_ataque_especial","mod_defensa_especial","mod_velocidad","mod_precision","mod_evasion","esta_confuso","turnos_confuso","substitute_hp","source_cursed","source_ingrain_rooted","source_sure_hit_turns","source_sure_hit_attacker","leech_seed_position"]
const METADATA=["EFFECT_MUD_SPORT","EFFECT_WATER_SPORT","source_prevent_escape"]
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==226
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true)
	data.categoria_dano_id=3;data.potencia=0;data.tipo="NORMAL";data.precision=0;data.max_pp=40;data.pp=40;data.objetivo_id=7;data.contacto=0;data.prob_secundario=0;data.efecto="EFFECT_BATON_PASS";data.prioridad=0
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_baton_pass"):return move
	var fact: Dictionary=phase.source_baton_pass
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
static func transfer_fact(state: PokemonEnCombate) -> Dictionary:
	var fact: Dictionary={"old":state,"fields":{},"metadata":{}}
	for field: String in FIELDS:
		var value=state.get(field);fact.fields[field]=value.duplicate(true) if value is Dictionary else value
	for key: String in METADATA:
		if state.has_meta(key):fact.metadata[key]=state.get_meta(key)
	return fact
static func apply(battle: Node,incoming: PokemonEnCombate,fact: Dictionary) -> void:
	if fact.is_empty():return
	var old: PokemonEnCombate=fact.old
	for field: String in FIELDS:
		incoming.set(field,fact.fields[field]);old.set(field,{} if field=="leech_seed_position" else null if field=="source_sure_hit_attacker" else false if old.get(field) is bool else 0)
	for key: String in METADATA:
		if fact.metadata.has(key):incoming.set_meta(key,fact.metadata[key])
		if old.has_meta(key):old.remove_meta(key)
	# Source-bank relations survive this particular switch. Rebind native references
	# to the new occupant, rather than leaving WeakRefs to a retired combat state.
	for pokemon: BasePokemon in battle.habilidades.crear_campo().todos():
		var state: PokemonEnCombate=battle._obtener_combatiente(pokemon)
		if state==null:continue
		if state.source_sure_hit_attacker!=null and state.source_sure_hit_attacker.get_ref()==old:
			state.source_sure_hit_attacker=weakref(incoming)
			if battle.field_rules.position(pokemon).get("player",false)!=battle.field_rules.position(incoming.pokemon_base).get("player",false):state.source_sure_hit_turns=2
		if state.has_meta("source_prevent_escape"):
			var trap: Dictionary=state.get_meta("source_prevent_escape")
			if trap.state.get_ref()==old:state.set_meta("source_prevent_escape",{"state":weakref(incoming),"pokemon":weakref(incoming.pokemon_base),"move_id":int(trap.move_id)})
		if state.target_enamorado==old.pokemon_base:state.esta_enamorado=false;state.target_enamorado=null
		var wrap: Dictionary=state.get_meta("source_turn_trap",{})
		if not wrap.is_empty() and wrap.state.get_ref()==old:preload("res://scripts/battle/turn_trap_rules.gd").clear(state)

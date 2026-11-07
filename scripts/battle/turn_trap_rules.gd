extends RefCounted
## Ruby wrapped status: victim counter plus actual caster identity, separate from MeanLook.
const KEY="source_turn_trap"
const IDS: Array[int]=[20,35,83,128,250,328]
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0)) in IDS
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true);var id: int=int(data.numero_movimiento)
	data.potencia=35 if id==128 else 15;data.precision=75 if id in [20,128] else 85 if id==35 else 70;data.tipo="NORMAL" if id in [20,35] else "FUEGO" if id==83 else "TIERRA" if id==328 else "AGUA";data.categoria_dano_id=1 if id in [20,35,328] else 2;data.max_pp=20 if id in [20,35] else 10 if id==128 else 15;data.pp=data.max_pp;data.contacto=1 if id in [20,35,128] else 0;data.objetivo_id=10;data.prioridad=0;data.prob_secundario=100;data.efecto="EFFECT_TRAP"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_turn_trap"):return move
	if phase.has("source_turn_trap_admitted"):return phase.source_turn_trap_admitted
	var fact: Dictionary=phase.source_turn_trap;var accepted:=Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true));phase.source_turn_trap_admitted=accepted;return accepted
static func clear(state: PokemonEnCombate) -> void:
	state.esta_atrapado=false;state.turnos_atrapado=0
	if state.has_meta(KEY):state.remove_meta(KEY)
static func holder(state: PokemonEnCombate,field: CampoCombate) -> BasePokemon:
	if state==null or not state.esta_atrapado or state.turnos_atrapado<=0 or not state.has_meta(KEY):return null
	var fact: Dictionary=state.get_meta(KEY);var source: BasePokemon=fact.pokemon.get_ref();var source_state: PokemonEnCombate=fact.state.get_ref()
	if source==null or source_state==null or source.estad_ps_actual<=0 or not field.todos().has(source) or not field.combatiente_de.is_valid() or field.combatiente_de.call(source)!=source_state:clear(state);return null
	return source
static func apply(battle: Node,actor: BasePokemon,target: BasePokemon,move: Movimiento,draw: Callable) -> bool:
	var state: PokemonEnCombate=battle._obtener_combatiente(target);var caster: PokemonEnCombate=battle._obtener_combatiente(actor)
	if state==null or caster==null or actor.estad_ps_actual<=0 or target.estad_ps_actual<=0 or state.substitute_hp>0:return false
	if state.esta_atrapado and holder(state,battle.habilidades.crear_campo())!=null:return false
	state.esta_atrapado=true;state.turnos_atrapado=(int(draw.call())&3)+3;state.set_meta(KEY,{"pokemon":weakref(actor),"state":weakref(caster),"move":int(move.datos.numero_movimiento),"name":move.nombre,"last_round":-1});return true
static func blocked(pokemon: BasePokemon,field: CampoCombate) -> Dictionary:
	if not field.combatiente_de.is_valid():return {}
	var state: PokemonEnCombate=field.combatiente_de.call(pokemon);var source: BasePokemon=holder(state,field)
	return {} if source==null else {"bloqueador":source,"source_move":int(state.get_meta(KEY).move),"source_turn_trap":true}
static func residual(battle: Node,pokemon: BasePokemon,state: PokemonEnCombate) -> bool:
	if state==null or pokemon.estad_ps_actual<=0 or holder(state,battle.habilidades.crear_campo())==null:return true
	var fact: Dictionary=state.get_meta(KEY)
	if int(fact.last_round)==int(battle.contador_turnos):return true
	fact.last_round=int(battle.contador_turnos);state.turnos_atrapado-=1
	var record: Dictionary=battle.field_rules.capture(pokemon)
	if record.is_empty():return true
	if state.turnos_atrapado==0:
		clear(state);await battle.mostrar_texto_batalla("¡%s se liberó de %s!"%[pokemon.get_nombre_combate(),str(fact.name)]);return battle.field_rules.valid(record)
	var damage: int=maxi(1,pokemon.estad_ps/16);var definition: BattleAnimationDefinition=BattleAnimationSequenceRegistry.get_definition("ruby:general/6",true)
	if definition==null or definition.source_script!="General_TurnTrap":return false
	var legacy: MoveAnimationContext=MoveAnimationContext.nueva(battle,record.slot.get_ref(),record.slot.get_ref());var context: BattleAnimationContext=BattleAnimationContext.from_legacy(legacy);context.set_meta("source_general_argument",int(fact.move))
	var animation: BattleSequenceAnimation=BattleAnimationDirector.play_key("ruby:general/6",context,true) # §32: nativa si la política lo permite
	if animation.state=="running":await animation.finalizada
	if animation.state!="completed" or not battle.field_rules.valid(record):return false
	await battle.mostrar_texto_batalla("¡%s sufrió daño por %s!"%[pokemon.get_nombre_combate(),str(fact.name)])
	if not battle.field_rules.valid(record):return false
	await battle.field_rules.passive_hp(record,damage)
	return battle.field_rules.valid(record)

extends RefCounted
class_name BattleDustWeatherRules
## Field-held Ruby manual weather, independent of holder-held Mud/Water Sport.
var _owner: WeakRef
var turns: int=0
var manual: bool=false
func _init(battle: Node) -> void:_owner=weakref(battle)
func clear() -> void:turns=0;manual=false
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0)) in [201,257,240,241,258]
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true);var number: int=int(data.numero_movimiento);var heat: bool=number==257
	data.tipo={201:"ROCA",257:"FUEGO",240:"AGUA",241:"FUEGO",258:"HIELO"}[number];data.categoria_dano_id=2 if heat else 3;data.potencia=100 if heat else 0;data.precision=90 if heat else 0;data.max_pp=5 if number in [240,241] else 10;data.pp=data.max_pp;data.objetivo_id=11 if heat else 7;data.prioridad=0;data.contacto=0;data.prob_secundario=10 if heat else 0;data.efecto={201:"EFFECT_SANDSTORM",257:"EFFECT_BURN_HIT",240:"EFFECT_RAIN_DANCE",241:"EFFECT_SUNNY_DAY",258:"EFFECT_HAIL"}[number]
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_dust_weather"):return move
	var fact: Dictionary=phase.source_dust_weather
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
func produce(weather: int=Singleton.ClimaBatalla.TORMENTA_ARENA) -> bool:
	var battle: Node=_owner.get_ref()
	if battle.clima_activo==weather:return false
	battle.clima_activo=weather;turns=5;manual=true;return true
func external(climate: int) -> void:
	# Ability/configured weather is untimed here, never a new manual5turn cast.
	clear();_owner.get_ref().clima_activo=climate
func announce_start() -> void:
	# Overworld weather is permanent (untimed); a later manual cast replaces it for
	# 5 turns and then the field stays clear: the overworld weather never returns.
	var battle: Node=_owner.get_ref();var weather: int=battle.clima_inicial
	battle.clima_inicial=Singleton.ClimaBatalla.NINGUNO
	if weather==Singleton.ClimaBatalla.NINGUNO or battle.clima_activo!=weather:return
	var visual: BasePokemon=null
	for actor: BasePokemon in [battle.poke_jugador]+battle.habilidades.activos_por_velocidad():
		if actor!=null and actor.estad_ps_actual>0:visual=actor;break
	await battle.mostrar_texto_batalla({1:"¡El sol pega fuerte!",2:"¡Está lloviendo!",3:"¡Hay una tormenta de arena!",4:"¡Está granizando!"}[weather])
	var slot: BattleSlot=battle.hud._obtener_slot_de_pokemon(visual) if visual!=null else null
	if slot==null:return
	var legacy:=MoveAnimationContext.nueva(battle,slot,slot);var context:=BattleAnimationContext.from_legacy(legacy);context.phase="weather"
	var animation:=BattleAnimationDirector.play_key("ruby:general/%d"%{1:11,2:10,3:12,4:13}[weather],context,true);await animation.esperar_finalizada()
func _ordered() -> Array[BasePokemon]:
	var battle: Node=_owner.get_ref();var result: Array[BasePokemon]=[]
	# Source weatherdamage iterates the actual SAVED action order, not new speed.
	for entry: Dictionary in battle.turno.get_meta("source_protect_projection",[]):
		var actor: BasePokemon=battle.turno._future_occupant(int(entry.bank))
		if actor!=null and actor not in result:result.append(actor)
	for actor: BasePokemon in battle.habilidades.activos_por_velocidad():
		if actor!=null and actor not in result:result.append(actor)
	return result
func end_round() -> bool:
	var battle: Node=_owner.get_ref()
	var weather: int=battle.clima_activo
	if weather not in [Singleton.ClimaBatalla.TORMENTA_ARENA,Singleton.ClimaBatalla.LLUVIA,Singleton.ClimaBatalla.SOLEADO,Singleton.ClimaBatalla.GRANIZO]:clear();return true
	if manual:
		turns-=1
		if turns==0:
			clear();battle.clima_activo=Singleton.ClimaBatalla.NINGUNO
			await battle.mostrar_texto_batalla({1:"¡El sol dejó de brillar!",2:"¡Dejó de llover!",3:"¡La tormenta de arena amainó!",4:"¡Dejó de granizar!"}[weather]);return true
	var flow: Dictionary=battle.field_rules.capture_flow();var ordered: Array[BasePokemon]=_ordered();var records: Array[Dictionary]=[]
	var visual: BasePokemon=null
	for actor: BasePokemon in ordered:
		var record: Dictionary=battle.field_rules.capture(actor)
		if not record.is_empty():records.append(record)
		if visual==null and actor.estad_ps_actual>0:visual=actor
	if visual==null:return true
	await battle.mostrar_texto_batalla({1:"¡El sol sigue brillando!",2:"¡La lluvia continúa!",3:"¡La tormenta de arena continúa!",4:"¡El granizo continúa!"}[weather])
	if not battle.field_rules.valid_flow(flow):return false
	var slot: BattleSlot=battle.hud._obtener_slot_de_pokemon(visual)
	var legacy:=MoveAnimationContext.nueva(battle,slot,slot);var context:=BattleAnimationContext.from_legacy(legacy);context.phase="weather"
	var animation:=BattleAnimationDirector.play_key("ruby:general/%d"%{1:11,2:10,3:12,4:13}[weather],context,true);await animation.esperar_finalizada()
	if not battle.field_rules.valid_flow(flow):return false
	if weather in [Singleton.ClimaBatalla.SOLEADO,Singleton.ClimaBatalla.LLUVIA]:return true
	for record: Dictionary in records:
		if not battle.field_rules.valid(record):continue
		var actor: BasePokemon=record.pokemon;var state: PokemonEnCombate=record.state.get_ref()
		if actor.estad_ps_actual<=0 or battle.habilidades.crear_campo().clima_efectivo()!=weather:continue
		var immune: bool=false
		for type: String in BattleTransformRules.types(actor):
			if type in (["HIELO"] if weather==Singleton.ClimaBatalla.GRANIZO else ["ROCA","TIERRA","ACERO"]):immune=true
		if immune or (weather==Singleton.ClimaBatalla.TORMENTA_ARENA and HabilidadesCombate.tiene(actor,HabilidadesCombate.VELOARENA)) or state.semi_invulnerable in ["underground","underwater"]:continue
		await battle.mostrar_texto_batalla(("¡El granizo golpea a %s!" if weather==Singleton.ClimaBatalla.GRANIZO else "¡La arena golpea a %s!")%actor.get_nombre_combate())
		if not battle.field_rules.valid_flow(flow):return false
		await battle.field_rules.passive_hp(record,maxi(1,int(actor.estad_ps/16)))
	return true

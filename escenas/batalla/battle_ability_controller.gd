## Puente entre la lógica pura de habilidades (`HabilidadesCombate`) y la escena
## de batalla: construye el `CampoCombate`, llama a los ganchos en los momentos
## del turno (entrada, fin de ronda, salida...) y presenta las
## `AccionHabilidad` resultantes (texto, animaciones, barras de PS, clima).
##
## Sigue el patrón de los demás controladores de batalla: guarda la referencia
## a `batalla.gd` en `_b` y no mantiene estado propio salvo las entradas
## pendientes de presentar.
extends RefCounted
class_name BattleAbilityController

## HOLD_EFFECT_QUICK_CLAW: parámetro 20 sobre 0xFFFF.
const UMBRAL_GARRA_RAPIDA: int = 20 * 0xFFFF / 100
const VELOCIDAD_GARRA_RAPIDA: int = 0xFFFFFFFF

var _b: BattleSceneController
var _numero_turno: int = 0xFFFF
## Pokémon que han entrado al campo sin que se haya podido presentar su
## habilidad (reposición síncrona de huecos en DOBLE).
## Registros de relevos con INTIMIDACIÓN/RASTRO por resolver.
var entradas_diferidas: Array[Dictionary] = []


func _init(batalla: BattleSceneController) -> void:
	_b = batalla


# ─── Contexto ────────────────────────────────────────────────────────────────

## Clima, activos de cada lado. En SIMPLE usa `poke_jugador`/`poke_enemigo`,
## que son los que cambian al sustituir al Pokémon.
func crear_campo() -> CampoCombate:
	var jugador: Array = []
	var enemigo: Array = []
	if _b.formato_batalla == Singleton.FormatoBatalla.DOBLE:
		jugador = _b.pokemones_activos_jugador
		enemigo = _b.pokemones_activos_enemigo
	else:
		jugador = [_b.poke_jugador]
		enemigo = [_b.poke_enemigo]
	var field: CampoCombate=CampoCombate.nuevo(int(_b.clima_activo), jugador, enemigo)
	field.screen_timers=_b.screen_rules.snapshot()
	field.combatiente_de=resolutor_combatientes()
	return field


func resolutor_combatientes() -> Callable:
	return Callable(_b, "_obtener_combatiente")


## gRandomTurnNumber: una tirada por turno que comparten todas las Garras Rápidas.
func sortear_numero_turno() -> void:
	_numero_turno = 0xFFFF
	for pokemon in crear_campo().todos():
		if pokemon != null and BattleHeldItemRules.held(pokemon) == "GARRARAPIDA":
			_numero_turno = randi() & 0xFFFF
			return


## GetWhoStrikesFirst: prioridad, luego velocidad, y un empate se decide al 50 %.
func golpea_primero(primero: BasePokemon, segundo: BasePokemon, prioridad_primero: int, prioridad_segundo: int) -> bool:
	if prioridad_primero != prioridad_segundo:
		return prioridad_primero > prioridad_segundo
	var velocidad_primero := velocidad_de(primero)
	var velocidad_segundo := velocidad_de(segundo)
	if velocidad_primero != velocidad_segundo:
		return velocidad_primero > velocidad_segundo
	return randi() & 1 == 0


## Velocidad con la que se ordena a los Pokémon en el campo.
func velocidad_de(pokemon: BasePokemon) -> int:
	if _numero_turno < UMBRAL_GARRA_RAPIDA and BattleHeldItemRules.held(pokemon) == "GARRARAPIDA":
		return VELOCIDAD_GARRA_RAPIDA
	var combatiente: PokemonEnCombate = _b._obtener_combatiente(pokemon)
	var clima_efectivo := crear_campo().clima_efectivo()
	if combatiente != null:
		return combatiente.get_velocidad_combate(clima_efectivo)
	return pokemon.estad_velocidad


## Activos del campo de más rápido a más lento (empates al azar).
func activos_por_velocidad() -> Array[BasePokemon]:
	var campo := crear_campo()
	var activos: Array[BasePokemon] = []
	for p in campo.todos():
		if p != null and p.estad_ps_actual > 0:
			activos.append(p)
	var claves := {}
	for p in activos:
		claves[p] = Vector2(velocidad_de(p), randf())
	activos.sort_custom(func(a: BasePokemon, b: BasePokemon) -> bool:
		var ka: Vector2 = claves[a]
		var kb: Vector2 = claves[b]
		if ka.x != kb.x:
			return ka.x > kb.x
		return ka.y > kb.y)
	return activos


# ─── Ganchos ─────────────────────────────────────────────────────────────────

## Habilidades de entrada de todos los Pokémon del campo al empezar la batalla.
## Antes, el clima inicial (BattleScript_OverworldWeatherStarts), como en
## BattleBeginFirstTurn.
func al_iniciar_batalla() -> bool:
	sortear_numero_turno()
	await _b.dust_weather_rules.announce_start()
	return await _presentar_entradas(activos_por_velocidad())


## ABILITYEFFECT_ON_SWITCHIN para `pokemon` recién llegado.
## diferir: atk52 de un relevo tras K.O.; deja INTIMIDACIÓN y RASTRO para `presentar_entradas_diferidas`.
func al_entrar(pokemon: BasePokemon, durante_combate: bool = true, entry: Dictionary = {}, defer_item: bool = false, diferir: bool = false) -> bool:
	if pokemon == null or pokemon.estad_ps_actual <= 0:
		return false
	# Retain the accepted occupant across hazard HUD and message awaits.
	var rules: BattleFieldEffects=_b.field_rules
	if entry.is_empty():entry=rules.capture(pokemon)
	var item: Dictionary=preload("res://scripts/battle/held_item_transaction.gd").capture(_b,entry,rules.capture_flow())
	var original_flow: Dictionary=entry.get("source_baton_unaffected_flow",{})
	if not original_flow.is_empty() and not rules.valid_flow(original_flow):return false
	if not await rules.enter(pokemon,entry):return false
	if not original_flow.is_empty() and not rules.valid_flow(original_flow):return false
	# Accepted hazard KO updates only this record's owned retirement epoch. It
	# is a valid entry result requiring faint settlement, not a stale callback.
	if pokemon.estad_ps_actual<=0:return true
	var campo := crear_campo()
	var acciones := HabilidadesCombate.al_entrar(pokemon, campo, resolutor_combatientes(), Callable(), durante_combate, false, diferir)
	if diferir:entradas_diferidas.append(entry)
	if original_flow.is_empty():await presentar(acciones)
	elif not await _presentar_entrada_baton(acciones,entry,original_flow):return false
	if not rules.valid(entry) or (not original_flow.is_empty() and not rules.valid_flow(original_flow)):return false
	if not defer_item:await preload("res://scripts/battle/held_herb_rules.gd").entry(_b,item)
	return rules.valid(entry) and rules.valid_flow(item.get("flow",{}))


## HandleFaintedMonActions caso 6: todas las INTIMIDACIÓN y luego todos los RASTRO de
## los relevos, por número de banco. False si se perdió el flujo.
func presentar_entradas_diferidas(flujos: Array[Dictionary]) -> bool:
	var rules: BattleFieldEffects=_b.field_rules
	var entradas: Array[Dictionary]=entradas_diferidas.duplicate()
	entradas_diferidas.clear()
	entradas.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return rules.source_bank(a.bank)<rules.source_bank(b.bank))
	for clave: String in [HabilidadesCombate.INTIMIDACION,HabilidadesCombate.RASTRO]:
		for entry: Dictionary in entradas:
			if not rules.valid(entry) or HabilidadesCombate.de(entry.pokemon)!=clave:continue
			await presentar(HabilidadesCombate.al_entrar_diferidas(entry.pokemon,crear_campo(),resolutor_combatientes(),Callable(),true))
			if not _b.resultado._flujos_validos(rules,flujos):return false
	return true


func _presentar_entradas(pokemones: Array) -> bool:
	var rules: BattleFieldEffects=_b.field_rules
	var flow: Dictionary=rules.capture_flow(pokemones)
	var entries: Array[Dictionary]=[]
	# Bind EVERY queued bank before the first presentation yield.
	for pokemon: BasePokemon in pokemones:entries.append(rules.capture(pokemon))
	var items: Array[Dictionary]=[]
	for entry: Dictionary in entries:items.append(preload("res://scripts/battle/held_item_transaction.gd").capture(_b,entry,rules.capture_flow()))
	for entry: Dictionary in entries:
		if not rules.valid_flow(flow) or not rules.valid(entry):return false
		if not await al_entrar(entry.pokemon,false,entry,true):return false
		if not rules.valid_flow(flow):return false
		for original: Dictionary in entries:
			if not rules.valid(original):return false
	# BattleBeginFirstTurn finishes ALL initial abilities before its item sweep.
	for item: Dictionary in items:
		if not rules.valid_flow(flow):return false
		await preload("res://scripts/battle/held_herb_rules.gd").entry(_b,item)
		for original: Dictionary in entries:
			if not rules.valid(original):return false
	return rules.valid_flow(flow)


## Salida voluntaria o forzada: CURA NATURAL y limpieza de lo temporal.
func al_salir(pokemon: BasePokemon) -> void:
	var state := _b._obtener_combatiente(pokemon) if pokemon != null else null
	if state != null: state.cancelar_continuacion()
	BattleCounterRules.retire(state)
	_b.field_rules.retire(state)
	HabilidadesCombate.al_salir(pokemon)
	BattleTransformRules.retire(state) # Copied exit ability runs before retirement.
	if pokemon != null:
		_b.hud._actualizar_estado_visual_pokemon(pokemon)


## Habilidades de fin de ronda de todos los activos, en orden de velocidad.
func fin_de_ronda() -> void:
	for pokemon in activos_por_velocidad():
		await fin_de_turno(pokemon)

func fin_de_turno(pokemon: BasePokemon) -> void:
	var acciones := HabilidadesCombate.fin_de_turno(pokemon, crear_campo(), _b._obtener_combatiente(pokemon))
	await presentar(acciones)


## BattleScript_WeatherFormChanges: PREDICCIÓN de todos los del campo tras un movimiento de clima.
func actualizar_predicciones() -> void:
	var campo := crear_campo()
	for pokemon: BasePokemon in campo.todos():
		await presentar(HabilidadesCombate.actualizar_prediccion(pokemon, campo))


## Al acabar la batalla: nada de lo temporal sobrevive en los equipos.
func limpiar_equipos() -> void:
	for state in _b.combatientes_activos.values():
		if state is PokemonEnCombate: state.cancelar_continuacion()
	for pokemon in _b.equipo_jugador_pokemones:
		HabilidadesCombate.limpiar_combate(pokemon)
	for pokemon in _b.equipo_enemigo_pokemones:
		HabilidadesCombate.limpiar_combate(pokemon)
		# Salvaguarda: la etiqueta "salvaje"/"enemigo" no sale de la batalla (un
		# capturado ya la perdió en _finalizar_captura).
		if pokemon != null:
			pokemon.limpiar_etiqueta_combate()


# ─── Presentación ────────────────────────────────────────────────────────────

func presentar(acciones: Array) -> void:
	for accion in acciones:await _presentar_una(accion as AccionHabilidad)

func _presentar_entrada_baton(acciones: Array,entry: Dictionary,flow: Dictionary) -> bool:
	for accion: AccionHabilidad in acciones:
		if not _b.field_rules.valid(entry) or not _b.field_rules.valid_flow(flow):return false
		await _presentar_una(accion)
		if not _b.field_rules.valid(entry) or not _b.field_rules.valid_flow(flow):return false
	return true


func _presentar_una(accion: AccionHabilidad) -> void:
	match accion.tipo:
		AccionHabilidad.Tipo.STAT_GROUP:
			await _presentar_grupo_estadisticas(accion)
		AccionHabilidad.Tipo.ITEM_PHASE:
			await BattleHeldItemRules.present(_b,accion.source_actor,accion.objetivo,accion.cantidad)
		AccionHabilidad.Tipo.CLIMA:
			_b.dust_weather_rules.external(accion.cantidad)
		AccionHabilidad.Tipo.ESTADISTICA:
			await _b.turno._reproducir_cambio_estadistica(accion.objetivo, accion.sube, accion.source_stat_animation)
		AccionHabilidad.Tipo.ESTADO:
			_b.hud._actualizar_estado_visual_pokemon(accion.objetivo)
		AccionHabilidad.Tipo.DANO:
			await _b._aplicar_danio_a_pokemon(accion.objetivo, _b.hud._obtener_cuadro_ps_de_pokemon(accion.objetivo), accion.cantidad)
		AccionHabilidad.Tipo.CURAR:
			await _curar(accion.objetivo, accion.cantidad)
		AccionHabilidad.Tipo.CAMBIO_FORMA:
			await _presentar_cambio_forma(accion)
	if not accion.source_status_key.is_empty() and accion.objetivo != null:
		await _b.turno.presentar_fase_estado(accion.source_status_key, accion.objetivo)
	if not accion.texto.is_empty():
		await _b.mostrar_texto_batalla(accion.texto)


## General_CastformChange: con el sprite oculto (Vuelo, Buceo...) cambia sin animación
## (sub_812DB58). Con Sustituto o Transformación la imagen del slot no es la de su forma.
func _presentar_cambio_forma(accion: AccionHabilidad) -> void:
	var slot: BattleSlot = _b.hud._obtener_slot_de_pokemon(accion.objetivo)
	if slot == null or slot.sprite_pokemon.has_meta(&"source_presentation_state"):
		return
	var aplicar: Callable = _b.aplicar_forma_a_slot.bind(slot, accion.objetivo, accion.cantidad)
	if slot.sprite_pokemon.visible:
		await slot.animar_cambio_forma(aplicar)
	else:
		aplicar.call()


## Native producer transaction: preview source argument, present, then commit
## each requested change once in script order through the existing stat authority.
func _grupo_vigente(action: AccionHabilidad,record: Dictionary) -> bool:
	return _b.field_rules.valid(record) and _b._obtener_combatiente(action.objetivo)==action.source_stat_state and (action.source_stat_parent==null or BattleScreenRules.action_live(action.source_stat_parent))
func _presentar_grupo_estadisticas(action: AccionHabilidad) -> void:
	if action.source_stat_committed:return
	action.source_stat_committed=true
	var record: Dictionary=_b.field_rules.capture(action.objetivo)
	if record.is_empty() or not _grupo_vigente(action,record):return
	var eligible: Array=[]
	for change: Array in action.source_stat_changes:
		if EfectosGolpe.puede_cambiar_estadistica(action.objetivo,action.source_stat_state,str(change[0]),int(change[1]),action.source_stat_rival):eligible.append(change)
	var argument: int=preload("res://scripts/battle/stat_animation_rules.gd").argument(eligible)
	if argument<0:return
	await _b.turno._reproducir_cambio_estadistica(action.objetivo,int(eligible[0][1])>0,argument)
	if not _grupo_vigente(action,record):return
	for change: Array in action.source_stat_changes:
		if not _grupo_vigente(action,record):return
		var effects: Array[AccionHabilidad]=EfectosGolpe.cambiar_estadistica(action.objetivo,action.source_stat_state,str(change[0]),int(change[1]),action.source_stat_rival)
		if not effects.is_empty() and action.source_stat_parent!=null:
			for trace: Dictionary in action.source_stat_parent.get_meta("source_i3_secondary",[]):
				if trace.target==action.source_stat_trace_target:trace.applied=true
		for effect: AccionHabilidad in effects:
			# The group's source animation was already played. Text follows each
			# native commit; never replay per-stat colored animation here.
			if not effect.texto.is_empty():await _b.mostrar_texto_batalla(effect.texto)


func _curar(pokemon: BasePokemon, cantidad: int) -> void:
	if pokemon == null or pokemon.estad_ps_actual <= 0:
		return
	pokemon.estad_ps_actual = mini(pokemon.estad_ps, pokemon.estad_ps_actual + cantidad)
	var cuadro: Node = _b.hud._obtener_cuadro_ps_de_pokemon(pokemon)
	if cuadro != null:
		await _b.hud.animar_dano(cuadro, pokemon.estad_ps, pokemon.estad_ps_actual)

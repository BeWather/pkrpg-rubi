extends RefCounted

## ============================================================================
## INTEGRADOR DE IA CON EL SISTEMA DE BATALLA EXISTENTE
## ============================================================================
## Conecta el nuevo sistema de IA con el sistema de batalla actual
## Reemplaza la función seguir_estrategia() con decisiones inteligentes

# Referencias al sistema de IA
const BattleAIScript = preload("res://scripts/battle_ai/BattleAI.gd")
const ActionComparatorScript = preload("res://scripts/battle_ai/ActionComparator.gd")

const MOVE_CATEGORY_LABELS := {
	1: "físico",
	2: "especial",
	3: "estado"
}

# Instancia de IA para el enemigo
var enemy_ai: BattleAI
var objetos_entrenador: ObjetosEntrenadorIA = null
var battle_node: Node  # Referencia al nodo de batalla
const ShouldSwitchRules = preload("res://scripts/battle_ai/should_switch_rules.gd")
## nombre_interno → numero_movimiento, para movimientos sin ese dato en `datos`.
var _ids_movimiento: Dictionary = {}

func _init(battle_reference: Node):
	"""Inicializa el integrador con referencia al sistema de batalla"""
	battle_node = battle_reference

func _get_battle_property(property_name: String, default_value = null):
	if not battle_node:
		return default_value
	return battle_node.get(property_name) if battle_node.get(property_name) != null else default_value

func _get_current_enemy_pokemon():
	if battle_node and battle_node.has_method("get_enemy_pokemon"):
		return battle_node.get_enemy_pokemon()
	return _get_battle_property("poke_enemigo")

func _get_current_player_pokemon():
	if battle_node and battle_node.has_method("get_player_pokemon"):
		return battle_node.get_player_pokemon()
	return _get_battle_property("poke_jugador")

func _get_enemy_team() -> Array:
	if battle_node and battle_node.has_method("get_enemy_team"):
		return battle_node.get_enemy_team()
	return _get_battle_property("equipo_enemigo_pokemones", [])

func _get_move_category_label(move: Movimiento) -> String:
	return MOVE_CATEGORY_LABELS.get(move.get_categoria_dano_id(), "estado")

func _get_status_name(status: int) -> String:
	match status:
		Singleton.ProblemaEstado.ENVENENADO:
			return "envenenado"
		Singleton.ProblemaEstado.CONGELADO:
			return "congelado"
		Singleton.ProblemaEstado.QUEMADO:
			return "quemado"
		Singleton.ProblemaEstado.PARALIZADO:
			return "paralizado"
		Singleton.ProblemaEstado.DORMIDO:
			return "dormido"
		Singleton.ProblemaEstado.DEBILITADO:
			return "debilitado"
		_:
			return ""

func _normalizar_precision_movimiento(precision_value) -> int:
	if precision_value == null:
		return 100
	var precision_type = typeof(precision_value)
	if precision_type == TYPE_INT or precision_type == TYPE_FLOAT:
		return clampi(int(precision_value), 0, 100)
	var precision_texto := str(precision_value).strip_edges()
	if precision_texto.is_valid_float():
		return clampi(int(precision_texto.to_float()), 0, 100)
	return 100

func _build_move_snapshot(move: Movimiento) -> Dictionary:
	if move == null:
		return {}

	var move_data = move.datos.duplicate(true)
	move_data["precision"] = _normalizar_precision_movimiento(move_data.get("precision"))
	move_data["categoria"] = _get_move_category_label(move)
	move_data["pp"] = move.get_max_pp()
	move_data["prioridad"] = move.get_prioridad()

	return {
		"nombre": move.nombre,
		"nombre_interno": move.get_nombre_interno(),
		"tipo": move.get_tipo(),
		"pp_act": move.pp_act,
		"datos": move_data
	}

func format_pokemon_data(pokemon, active: bool=true) -> Dictionary:
	"""Formatea datos de Pokémon para el sistema de IA"""

	if pokemon == null:
		return {}
	var state: PokemonEnCombate=BattleTransformRules.state_for(pokemon) if active else null
	var copy: Dictionary=state.get_meta("transform_domain",{}) if state!=null else {}
	var native_moves: Array=state.get_movimientos() if not copy.is_empty() else pokemon.movimientos
	var native_types: Array=[copy.type_1,copy.type_2] if not copy.is_empty() else [pokemon.tipo_1,pokemon.tipo_2]
	var type_names: Array=native_types.filter(func(type):return not str(type).is_empty()) if not copy.is_empty() else pokemon.obtener_nombres_tipos()

	var movimientos: Array = []
	for index: int in mini(4,native_moves.size()):
		var move: Movimiento=native_moves[index]
		if move is Movimiento:
			if active and preload("res://scripts/battle/move_availability_rules.gd").blocked(battle_node,pokemon,move):continue
			var snapshot: Dictionary=_build_move_snapshot(move);snapshot.source_slot=index
			movimientos.append(snapshot)

	return {
		"nombre": pokemon.get_nombre_mostrar(),
		"nombre_interno": copy.get("species",pokemon.nombre_interno),
		"habilidad": HabilidadesCombate.de(pokemon) if active else pokemon.habilidad,
		"nivel": pokemon.nivel,
		"felicidad": pokemon.felicidad,
		"tipo_primario": native_types[0],
		"tipo_secundario": native_types[1],
		"tipos": type_names,
		"estad_ps": pokemon.estad_ps,
		"estad_ps_actual": pokemon.estad_ps_actual,
		"hp_actual": pokemon.estad_ps_actual,
		"hp_maximo": pokemon.estad_ps,
		"estad_ataque": state.get_ataque_combate() if not copy.is_empty() else pokemon.estad_ataque,
		"estad_defensa": state.get_defensa_combate() if not copy.is_empty() else pokemon.estad_defensa,
		"estad_ataque_especial": state.get_ataque_especial_combate() if not copy.is_empty() else pokemon.estad_ataque_especial,
		"estad_defensa_especial": state.get_defensa_especial_combate() if not copy.is_empty() else pokemon.estad_defensa_especial,
		"estad_velocidad": state.get_velocidad_combate() if not copy.is_empty() else pokemon.estad_velocidad,
		"movimientos": movimientos,
		"estado": _get_status_name(pokemon.estado)
	}

func initialize_enemy_ai(trainer_class: String, trainer_items: Dictionary = {}, difficulty: int = 3):
	"""Inicializa la IA del entrenador enemigo"""
	
	print("🔗 [BattleIntegration] Inicializando IA para entrenador: %s" % trainer_class)
	
	# Crear instancia de IA
	enemy_ai = BattleAIScript.new(trainer_class, trainer_items, difficulty)
	
	print("✅ [BattleIntegration] IA inicializada correctamente")

## Objetos del rival: los decide ShouldUseItem, no la puntuación de BattleAI.
func configurar_objetos_entrenador(objetos: Array[String]) -> void:
	objetos_entrenador = ObjetosEntrenadorIA.new(objetos)

func get_enemy_action() -> Dictionary:
	"""Reemplazo inteligente para seguir_estrategia()"""
	
	if not enemy_ai:
		print("⚠️ [BattleIntegration] IA no inicializada, usando decisión aleatoria")
		return get_fallback_action()
	
	# Obtener información del estado actual de batalla
	var battle_context = extract_battle_context()
	var ally_pokemon = get_enemy_pokemon_data()  # El "aliado" de la IA es nuestro enemigo
	var enemy_pokemon = get_player_pokemon_data()  # El "enemigo" de la IA es nuestro Pokémon
	var team_status = get_enemy_team_status()
	
	if not ally_pokemon or not enemy_pokemon:
		print("⚠️ [BattleIntegration] Datos de Pokémon no disponibles")
		return get_fallback_action()
	
	# Obtener decisión de la IA
	var ai_decision = enemy_ai.choose_action(ally_pokemon, enemy_pokemon, team_status, battle_context)
	
	# Convertir decisión de IA a formato del sistema de batalla
	return convert_ai_decision_to_battle_action(ai_decision)

func extract_battle_context() -> Dictionary:
	"""Extrae información del contexto de batalla actual"""
	
	var context = {}
	
	if battle_node:
		# Información del clima/weather si existe
		if battle_node.has_method("get_weather"):
			context["weather"] = battle_node.get_weather()
		
		# Información de efectos de campo
		if battle_node.has_method("get_field_effects"):
			context["field_effects"] = battle_node.get_field_effects()
		
		# Contador de turnos
		if battle_node.has_method("get_turn_count"):
			context["turn_count"] = battle_node.get_turn_count()
		else:
			context["turn_count"] = int(_get_battle_property("contador_turnos", 0))

		var battle_type_value = _get_battle_property("tipo_batalla", Singleton.TipoBatalla.ENTRENADOR)
		context["battle_type"] = "trainer" if battle_type_value == Singleton.TipoBatalla.ENTRENADOR else "wild"
		
		# Estado de la batalla
		if battle_node.has_method("get_battle_state"):
			context["battle_state"] = battle_node.get_battle_state()
	
	return context

func get_enemy_pokemon_data() -> Dictionary:
	"""Obtiene datos del Pokémon enemigo actual"""
	
	return format_pokemon_data(_get_current_enemy_pokemon())

func get_player_pokemon_data() -> Dictionary:
	"""Obtiene datos del Pokémon del jugador actual"""
	
	return format_pokemon_data(_get_current_player_pokemon())

func get_enemy_team_status() -> Dictionary:
	"""Obtiene estado del equipo enemigo"""
	
	var team_status = {
		"total_pokemon": 1,
		"active_pokemon": 1,
		"fainted_pokemon": [],
		"available_pokemon": [],
		"available_switches": []
	}
	
	if not battle_node:
		return team_status
	
	var team = _get_enemy_team()
	if team and team.size() > 0:
		var active_pokemon = _get_current_enemy_pokemon()
		var available_alive_count := 0
		team_status["total_pokemon"] = team.size()
		for i in range(team.size()):
			var pokemon = team[i]
			var snapshot = format_pokemon_data(pokemon,false)
			if snapshot.is_empty():
				continue
			snapshot["team_index"] = i
			if snapshot.get("estad_ps_actual", 0) <= 0:
				team_status["fainted_pokemon"].append(snapshot)
				continue
			available_alive_count += 1
			if pokemon != active_pokemon:
				team_status["available_pokemon"].append(snapshot)
				team_status["available_switches"].append(snapshot)
		team_status["active_pokemon"] = available_alive_count
	
	return team_status

func convert_ai_decision_to_battle_action(ai_decision: Dictionary) -> Dictionary:
	"""Convierte la decisión de IA al formato esperado por batalla.gd"""
	
	var best_action = ai_decision.get("best_action", null)
	if best_action == null:
		return get_fallback_action()
	
	var action = best_action
	var battle_action = {}
	
	match int(action.get("type", -1)):
		ActionComparatorScript.ActionType.MOVE:
			battle_action = {
				"type": "attack",
				"move": action.get("action", {}),
				"reasoning": ai_decision.get("reasoning", "Ataque seleccionado por IA")
			}
		
		ActionComparatorScript.ActionType.ITEM:
			battle_action = {
				"type": "item",
				"item_name": action.get("action", ""),
				"reasoning": ai_decision.get("reasoning", "Objeto seleccionado por IA")
			}
		
		ActionComparatorScript.ActionType.SWITCH_POKEMON:
			battle_action = {
				"type": "switch",
				"target_pokemon": action.get("action", {}),
				"reasoning": ai_decision.get("reasoning", "Cambio seleccionado por IA")
			}
		
		_:
			battle_action = get_fallback_action()
	
	print("🎯 [BattleIntegration] Acción convertida: %s" % battle_action.get("reasoning", ""))
	
	return battle_action

func get_intelligent_battle_action(available_moves: Array) -> Dictionary:
	"""Retorna la acción enemiga ya adaptada al runtime de batalla"""

	if not enemy_ai:
		return {
			"type": "attack",
			"move": _get_first_usable_move(available_moves),
			"reasoning": "Sin IA - selección automática"
		}

	var action = get_enemy_action()
	match str(action.get("type", "attack")):
		"attack":
			var selected_move = _find_matching_move(action.get("move", {}), available_moves)
			if selected_move:
				return {
					"type": "attack",
					"move": selected_move,
					"reasoning": action.get("reasoning", "Selección inteligente")
				}
		"item", "switch":
			return action

	return {
		"type": "attack",
		"move": _get_first_usable_move(available_moves),
		"reasoning": action.get("reasoning", "Acción de respaldo - selección automática")
	}

## AI_TrySwitchOrUseItem, rama de cambio, para `actor`: acción "switch" o {} si no cambia.
## Solo entrenadores. `reservado`: relevo ya elegido por el compañero esta ronda.
func decidir_cambio_rival(actor: BasePokemon, reservado: BasePokemon = null) -> Dictionary:
	if actor == null or _get_battle_property("tipo_batalla", Singleton.TipoBatalla.ENTRENADOR) != Singleton.TipoBatalla.ENTRENADOR:
		return {}
	var estado: PokemonEnCombate = battle_node._obtener_combatiente(actor)
	if estado == null or _cambio_bloqueado(actor, estado):
		return {}
	var indice: int = ShouldSwitchRules.decidir(_contexto_cambio(actor, estado, reservado, _objetivo_en_seleccion(actor)))
	if indice < 0:
		return {}
	var equipo: Array = _get_enemy_team()
	return {"type": "switch", "target_pokemon": {"team_index": indice}, "pokemon_cambio": equipo[indice], "indice_equipo": indice, "reasoning": "ShouldSwitch"}


## OpponentHandlecmd22: relevo de `saliente` tras K.O. o Relevo. null si no queda ninguno.
## HandleFaintedMonActions caso 4 deja gBattlerTarget en el puesto del que cayó.
func elegir_relevo_rival(saliente: BasePokemon) -> BasePokemon:
	if saliente == null:
		return null
	var estado: PokemonEnCombate = battle_node._obtener_combatiente(saliente)
	if estado == null:
		estado = PokemonEnCombate.new(saliente)
	var indice: int = ShouldSwitchRules.relevo_mas_adecuado(_contexto_cambio(saliente, estado, null, saliente))
	return _get_enemy_team()[indice] if indice >= 0 else null


## gBattlerTarget al elegir acción. HandleFaintedMonActions lo deja en el último puesto al
## final de cada ronda, y en el primer turno sigue en 0. En dobles, R1 elige cuando R0 ya
## eligió: si R0 atacó, BattleAI_SetupAIData lo cambió por su objetivo. Aproximaciones: ese
## objetivo es el del motor, no el sorteo de la IA, y un R1 caído sin relevo se sustituye
## por el propio actor, aunque gBattleMons[3] conserva su tipo.
func _objetivo_en_seleccion(actor: BasePokemon) -> BasePokemon:
	var primer_turno: bool = int(battle_node.contador_turnos) == 0
	if battle_node.formato_batalla != Singleton.FormatoBatalla.DOBLE:
		return battle_node.poke_jugador if primer_turno else actor
	var activos: Array = battle_node.pokemones_activos_enemigo
	if activos.size() > 1 and activos[1] == actor:
		var companero: BasePokemon = activos[0]
		var accion: Dictionary = battle_node.accion_enemiga
		if companero != null and str(accion.get("type", "")) == "attack" and accion.get("target", null) != null \
				and not BattleLockedMoveRules.recharging(battle_node, companero) and BattleLockedMoveRules.multi_turn(battle_node, companero) == null:
			return accion.target
	elif primer_turno:
		return battle_node.poke_jugador
	elif activos.size() > 1 and activos[1] != null:
		return activos[1]
	return battle_node.poke_jugador if primer_turno else actor


func _activos_de_lado(jugador: bool) -> Array:
	if battle_node.formato_batalla == Singleton.FormatoBatalla.DOBLE:
		return battle_node.pokemones_activos_jugador if jugador else battle_node.pokemones_activos_enemigo
	return [battle_node.poke_jugador if jugador else battle_node.poke_enemigo]


## Bloqueos iniciales de ShouldSwitch. No equivalen a HabilidadesCombate.impide_huida:
## Trampa Arena aquí no mira Volador ni Levitación, e Imán cuenta a cualquier Pokémon en
## campo, también al propio o a su compañero. Un banco vacío no se cuenta: atk23_getexp
## borra la habilidad del que cae (salvo si givenExpMons ya marca su número de equipo).
func _cambio_bloqueado(actor: BasePokemon, estado: PokemonEnCombate) -> bool:
	var campo: CampoCombate = battle_node.habilidades.crear_campo()
	if not preload("res://scripts/battle/turn_trap_rules.gd").blocked(actor, campo).is_empty():
		return true
	if not preload("res://scripts/battle/escape_prevention_rules.gd").blocked(actor, campo).is_empty():
		return true
	if estado.source_ingrain_rooted:
		return true
	for rival in _activos_de_lado(true):
		if rival != null and HabilidadesCombate.de(rival) in [HabilidadesCombate.SOMBRATRAMPA, HabilidadesCombate.TRAMPAARENA]:
			return true
	if BattleTransformRules.types(actor).has("ACERO"):
		for pokemon in _activos_de_lado(true) + _activos_de_lado(false):
			if pokemon != null and HabilidadesCombate.de(pokemon) == HabilidadesCombate.IMAN:
				return true
	return false


func _id_movimiento(movimiento: Movimiento) -> int:
	if movimiento == null:
		return 0
	if movimiento.datos.has("numero_movimiento"):
		return int(movimiento.datos.numero_movimiento)
	var nombre: String = movimiento.get_nombre_interno()
	if not _ids_movimiento.has(nombre):
		_ids_movimiento[nombre] = int(DatabaseManager.obtener_datos_movimiento(nombre).get("numero_movimiento", 0))
	return _ids_movimiento[nombre]


func _ids_movimientos(movimientos: Array) -> Array[int]:
	var ids: Array[int] = []
	for movimiento in movimientos.slice(0, 4):
		ids.append(_id_movimiento(movimiento))
	return ids


## [tipo1, tipo2] con el segundo igual al primero si solo tiene uno, como gBaseStats.
func _par_tipos(tipos: Array) -> Array:
	var primero: String = str(tipos[0])
	var segundo: String = str(tipos[1]) if tipos.size() > 1 else ""
	return [primero, primero if segundo.is_empty() else segundo]


## Tipos de la especie (AI_TypeCalc): ignoran Conversión; Transformación copia la especie.
func _tipos_especie(pokemon: BasePokemon) -> Array:
	var copia: Dictionary = BattleTransformRules.data(pokemon)
	return _par_tipos([copia.get("type_1", pokemon.tipo_1), copia.get("type_2", pokemon.tipo_2)])


## Último objetivo (gBattlerTarget) al elegir: tipo primario actual de su banco.
func _tipo_primario(pokemon: BasePokemon) -> String:
	return str(_par_tipos(BattleTransformRules.types(pokemon))[0]) if pokemon != null else ""


## AI_CalcDmg(gActiveBattler, rival) con gCurrentMove: CalculateBaseDamage con crítico y
## multiplicador 1, Carga y Refuerzo. ??? (Maldición) da 0 + 2.
func _dano_base_ia(actor: BasePokemon, estado: PokemonEnCombate, rival: BasePokemon) -> int:
	var actual: Movimiento = battle_node.turno._source_current_move
	var id: int = _id_movimiento(actual)
	var tipo: String = ShouldSwitchRules.tipo(id)
	if tipo == "???":
		return 2
	var estado_rival: PokemonEnCombate = battle_node._obtener_combatiente(rival)
	var campo: CampoCombate = battle_node.habilidades.crear_campo()
	var especial: bool = ShouldSwitchRules.es_especial(tipo)
	var pantallas: int = MoveResolver._pantallas_activas(campo, rival, 2 if especial else 1)
	var vivos: Array = _activos_de_lado(true).filter(func(p: BasePokemon) -> bool: return p != null and p.estad_ps_actual > 0)
	var a_dos: bool = battle_node.formato_batalla == Singleton.FormatoBatalla.DOBLE and ShouldSwitchRules.objetivo(id) == 8 and vivos.size() == 2
	var contexto = preload("res://scripts/battle/source_damage_context.gd")
	var dano: int
	if especial:
		dano = contexto.special_base(actor, rival, estado, estado_rival, ShouldSwitchRules.poder(id), tipo, false, pantallas, a_dos, campo.clima_efectivo(), false, campo)
	else:
		dano = contexto.physical_base(actor, rival, estado, estado_rival, ShouldSwitchRules.poder(id), contexto.describe(battle_node, actor, estado), false, pantallas, a_dos)
	if actual != null and preload("res://scripts/battle/charge_rules.gd").boosted(actual, estado):
		dano *= 2
	if estado.source_helping_hand:
		dano = dano * 15 / 10
	return dano


func _ficha_rival_cambio(rival: BasePokemon, actor: BasePokemon, estado: PokemonEnCombate) -> Dictionary:
	if rival == null:
		return {"ausente": true, "ability": "", "tipos_especie": ["", ""], "tipos": ["", ""], "identificado": false, "dano_base": 0}
	var estado_rival: PokemonEnCombate = battle_node._obtener_combatiente(rival)
	return {
		"ausente": rival.estad_ps_actual <= 0,
		"ability": HabilidadesCombate.de(rival),
		"tipos_especie": _tipos_especie(rival),
		"tipos": _par_tipos(BattleTransformRules.types(rival)),
		"identificado": estado_rival != null and estado_rival.source_identified,
		"dano_base": _dano_base_ia(actor, estado, rival)
	}


func _ficha_ultimo_atacante(estado: PokemonEnCombate, reservado: BasePokemon, equipo: Array) -> Dictionary:
	if estado.source_last_hit_by.is_empty():
		return {}
	var banco: Dictionary = estado.source_last_hit_by
	var atacante: BasePokemon = battle_node.field_rules.occupant(banco)
	if atacante == null:
		atacante = estado.source_last_hit_by_pokemon
	if atacante == null:
		return {}
	var lado: Array = battle_node.equipo_jugador_pokemones if bool(banco.player) else equipo
	# La selección del rival se resuelve antes que la del jugador: sus cambios aún son 6.
	var cambio: int = equipo.find(reservado) if reservado != null and not bool(banco.player) else ShouldSwitchRules.SIN_MON
	return {"tipos_especie": _tipos_especie(atacante), "ability": HabilidadesCombate.de(atacante), "party_index": lado.find(atacante), "cambio": cambio}


func _contexto_cambio(actor: BasePokemon, estado: PokemonEnCombate, reservado: BasePokemon, objetivo: BasePokemon) -> Dictionary:
	var equipo: Array = _get_enemy_team()
	var doble: bool = battle_node.formato_batalla == Singleton.FormatoBatalla.DOBLE
	var companero_index: int = -1
	if doble:
		for otro in battle_node.pokemones_activos_enemigo:
			if otro != null and otro != actor and otro.estad_ps_actual > 0:
				companero_index = equipo.find(otro)
	var miembros: Array = []
	for pokemon in equipo:
		if pokemon == null:
			miembros.append(null)
			continue
		miembros.append({"ps": pokemon.estad_ps_actual, "ability": pokemon.habilidad, "tipos": _par_tipos([pokemon.tipo_1, pokemon.tipo_2]), "moves": _ids_movimientos(pokemon.movimientos)})
	var rivales: Array = []
	for rival in _activos_de_lado(true):
		rivales.append(_ficha_rival_cambio(rival, actor, estado))
	# El jugador con un solo Pokémon deja su segundo banco ausente.
	while doble and rivales.size() < 2:
		rivales.append(_ficha_rival_cambio(null, actor, estado))
	return {
		"doble": doble,
		"tabla": Singleton.tabla_tipos,
		"draw": battle_node.turno._sortear_ia_cambio,
		"gt1": _tipo_primario(objetivo),
		"actor": {
			"ability": HabilidadesCombate.de(actor),
			"dormido": actor.estado == Singleton.ProblemaEstado.DORMIDO,
			"ps": actor.estad_ps_actual,
			"ps_max": actor.estad_ps,
			"moves": _ids_movimientos(BattleTransformRules.moves(actor)),
			"perish": estado.source_perish_song,
			"perish_count": estado.source_perish_count,
			"mods": [estado.mod_ataque, estado.mod_defensa, estado.mod_velocidad, estado.mod_ataque_especial, estado.mod_defensa_especial, estado.mod_precision, estado.mod_evasion],
			"landed": estado.source_last_landed_move,
			"party_index": equipo.find(actor),
			"tipos": _par_tipos(BattleTransformRules.types(actor))
		},
		"companero_index": companero_index,
		"companero_cambio": equipo.find(reservado) if reservado != null else ShouldSwitchRules.SIN_MON,
		"hit_by": _ficha_ultimo_atacante(estado, reservado, equipo),
		"party": miembros,
		"rivales": rivales
	}

func get_fallback_action() -> Dictionary:
	"""Acción de respaldo cuando la IA falla"""
	
	print("🎲 [BattleIntegration] Usando acción de respaldo")
	
	return {
		"type": "attack",
		"move": null,  # Se seleccionará el primer movimiento disponible
		"reasoning": "Acción de respaldo - selección automática"
	}

# ============================================================================
# FUNCIONES DE UTILIDAD PARA INTEGRACIÓN
# ============================================================================

func add_items_to_enemy_ai(items: Dictionary):
	"""Añade objetos a la IA del enemigo durante la batalla"""
	if enemy_ai:
		enemy_ai.add_items(items)

func get_ai_statistics() -> Dictionary:
	"""Obtiene estadísticas de la IA para debugging"""
	if enemy_ai:
		return enemy_ai.get_battle_statistics()
	return {}

func reset_ai_for_new_battle():
	"""Reinicia la IA para una nueva batalla"""
	if enemy_ai:
		enemy_ai.reset_battle_memory()

func is_ai_initialized() -> bool:
	"""Verifica si la IA está inicializada"""
	return enemy_ai != null

func get_ai_personality_info() -> String:
	"""Obtiene información de personalidad de la IA"""
	if enemy_ai:
		return enemy_ai.get_personality_type_name()
	return "Sin IA"

func debug_print_ai_state():
	"""Imprime estado de la IA para debugging"""
	if enemy_ai:
		enemy_ai.debug_print_state()
	else:
		print("❌ [BattleIntegration] IA no inicializada")

# ============================================================================
# FUNCIONES ESPECÍFICAS PARA SISTEMA DE BATALLA
# ============================================================================

func get_intelligent_move_selection(available_moves: Array) -> Dictionary:
	"""Selección inteligente de movimientos cuando solo se necesita eso"""

	var action = get_intelligent_battle_action(available_moves)
	return {
		"move": action.get("move", _get_first_usable_move(available_moves)),
		"reasoning": action.get("reasoning", "Selección automática")
	}

func _find_matching_move(move_snapshot, available_moves: Array):
	if typeof(move_snapshot) != TYPE_DICTIONARY:
		return null
	if move_snapshot.is_empty():
		return null

	var nombre_interno = str(move_snapshot.get("nombre_interno", ""))
	var nombre_visible = str(move_snapshot.get("nombre", ""))
	for move in available_moves:
		if not (move is Movimiento):
			continue
		if not move.tiene_pp():
			continue
		if move_snapshot.has("source_slot") and available_moves.find(move)!=int(move_snapshot.source_slot):continue
		if preload("res://scripts/battle/move_availability_rules.gd").blocked(battle_node,_get_current_enemy_pokemon(),move):continue
		if nombre_interno != "" and move.get_nombre_interno() == nombre_interno:
			return move
		if nombre_visible != "" and move.nombre == nombre_visible:
			return move
	return null

func _get_first_usable_move(available_moves: Array):
	var actor: BasePokemon=_get_current_enemy_pokemon()
	var slots: Array[int]=preload("res://scripts/battle/move_availability_rules.gd").slots(battle_node,actor)
	if slots.is_empty():return preload("res://scripts/battle/move_availability_rules.gd").struggle()
	return BattleTransformRules.moves(actor)[slots[0]]

func should_use_item() -> Dictionary:
	"""Determina si el enemigo debe usar un objeto"""
	
	if not enemy_ai or not enemy_ai.has_healing_items():
		return {"use_item": false}
	
	var action = get_enemy_action()
	
	if action.get("type", "") == "item":
		return {
			"use_item": true,
			"item_name": action.get("item_name", ""),
			"reasoning": action.get("reasoning", "")
		}
	
	return {"use_item": false}


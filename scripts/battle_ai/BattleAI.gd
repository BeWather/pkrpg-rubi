class_name BattleAI
extends RefCounted

## ============================================================================
## SISTEMA DE INTELIGENCIA ARTIFICIAL DE BATALLA
## ============================================================================
## Controlador principal que coordina todos los componentes de IA
## Toma decisiones inteligentes sobre movimientos, objetos y cambios

# Referencias a componentes del sistema de IA
const CombatAnalyzer = preload("res://scripts/battle_ai/CombatAnalyzer.gd")
const TrainerPersonality = preload("res://scripts/battle_ai/TrainerPersonality.gd")
const ActionComparator = preload("res://scripts/battle_ai/ActionComparator.gd")
const ItemEvaluator = preload("res://scripts/battle_ai/ItemEvaluator.gd")

var personality: TrainerPersonality
var difficulty_level: int = 1  # 1-5 escalas de dificultad
var available_items: Dictionary = {}  # {"POCION": 2, "REVIVIR": 1, etc.}
var items_used_count: Dictionary = {}  # Control de uso de objetos
var battle_memory: Dictionary = {}  # Memoria de la batalla actual

func _init(trainer_class: String, trainer_items: Dictionary = {}, difficulty: int = 1):
	"""Inicializa el sistema de IA para un entrenador específico"""
	
	personality = TrainerPersonality.create_personality(trainer_class)
	difficulty_level = difficulty
	available_items = trainer_items.duplicate()
	
	# Inicializar contador de objetos usados
	items_used_count = {}
	for item in available_items.keys():
		items_used_count[item] = 0
	
	# Inicializar memoria de batalla
	battle_memory = {
		"turn_count": 0,
		"moves_used": [],
		"items_used": [],
		"switches_made": 0,
		"damage_taken": 0,
		"damage_dealt": 0
	}
	
	print("🧠 [BattleAI] IA inicializada - Clase: %s, Dificultad: %d, Objetos: %d" % [
		trainer_class, difficulty, available_items.size()
	])
	print("🎭 [BattleAI] Personalidad: %s" % personality.get_personality_description())

func choose_action(ally_pokemon, enemy_pokemon, team_status: Dictionary, battle_context: Dictionary) -> Dictionary:
	"""Elige la mejor acción entre movimientos, objetos y cambios de Pokémon"""
	
	# Incrementar contador de turnos
	battle_memory.turn_count += 1
	
	# Análisis completo de la situación actual
	var battle_state = CombatAnalyzer.analyze_battle_state(ally_pokemon, enemy_pokemon, battle_context)
	battle_state["ally_pokemon"] = ally_pokemon
	battle_state["enemy_pokemon"] = enemy_pokemon
	battle_state["available_items"] = available_items
	battle_state["items_used"] = items_used_count
	battle_state["battle_memory"] = battle_memory
	battle_state["turn_count"] = battle_memory.turn_count
	battle_state["ai_difficulty"] = difficulty_level

	print("🔍 [BattleAI] Turno %d - Analizando situación..." % battle_memory.turn_count)
	
	# Comparar todas las acciones posibles
	var decision = ActionComparator.compare_all_actions(
		ally_pokemon, 
		enemy_pokemon, 
		available_items, 
		team_status, 
		battle_state, 
		personality
	)
	
	# Aplicar filtros basados en dificultad y restricciones
	decision = apply_ai_restrictions(decision, battle_state)
	
	# Registrar la decisión en memoria
	if decision.best_action:
		record_action_in_memory(decision.best_action)
		
		# Procesar uso de objeto si se selecciona
		if decision.best_action.type == ActionComparator.ActionType.ITEM:
			process_item_usage(decision.best_action.action)
	
	print("🎯 [BattleAI] Decisión final: %s" % decision.reasoning)
	
	return decision

func apply_ai_restrictions(decision: Dictionary, battle_state: Dictionary) -> Dictionary:
	"""Aplica restricciones basadas en dificultad y personalidad"""
	
	if not decision.best_action:
		return decision
	
	var action = decision.best_action
	
	# Restricciones por dificultad para uso de objetos
	if action.type == ActionComparator.ActionType.ITEM:
		var restriction_result = apply_item_usage_restrictions(action, decision.all_actions)
		if restriction_result:
			return restriction_result
	
	# Restricciones por personalidad
	var personality_result = apply_personality_restrictions(action, decision.all_actions, battle_state)
	if personality_result:
		return personality_result
	
	return decision

func apply_item_usage_restrictions(action: Dictionary, all_actions: Array) -> Dictionary:
	"""Aplica restricciones específicas para uso de objetos"""
	
	var item_name = action.action
	var times_used = items_used_count.get(item_name, 0)
	var total_items_used = 0
	
	for count in items_used_count.values():
		total_items_used += count
	
	match difficulty_level:
		1, 2:  # Fácil - Uso muy limitado de objetos
			if times_used >= 1:
				print("🚫 [BattleAI] Restricción de dificultad: %s ya usado" % item_name)
				return get_alternative_action(all_actions, ActionComparator.ActionType.ITEM)
		
		3:     # Normal - Uso moderado
			if total_items_used >= 2:
				print("🚫 [BattleAI] Restricción de dificultad: máximo 2 objetos por batalla")
				return get_alternative_action(all_actions, ActionComparator.ActionType.ITEM)
		
		4, 5:  # Difícil/Experto - Sin restricciones importantes
			if total_items_used >= 5:  # Límite muy alto para evitar spam
				return get_alternative_action(all_actions, ActionComparator.ActionType.ITEM)
	
	return {}  # Sin restricciones aplicadas

func apply_personality_restrictions(action: Dictionary, all_actions: Array, battle_state: Dictionary) -> Dictionary:
	"""Aplica restricciones basadas en personalidad"""
	
	match personality.personality_type:
		TrainerPersonality.PersonalityType.AGGRESSIVE:
			# Los agresivos evitan objetos defensivos temprano
			if action.type == ActionComparator.ActionType.ITEM and battle_state.get("turn_count", 0) < 3:
				if action.category == "healing":
					print("🚫 [BattleAI] Restricción de personalidad: agresivo evita curación temprana")
					return get_alternative_action(all_actions, ActionComparator.ActionType.ITEM)
		
		TrainerPersonality.PersonalityType.DEFENSIVE:
			# Los defensivos evitan ataques arriesgados cuando están débiles
			if action.type == ActionComparator.ActionType.MOVE and battle_state.get("hp_ratio_ally", 1.0) < 0.3:
				var move = action.action
				var move_data = move.get("datos", {})
				var accuracy = move_data.get("precision")
				if accuracy == null or (typeof(accuracy) != TYPE_INT and typeof(accuracy) != TYPE_FLOAT):
					accuracy = 100
				if accuracy < 90:
					print("🚫 [BattleAI] Restricción de personalidad: defensivo evita ataques arriesgados")
					return get_alternative_action(all_actions, ActionComparator.ActionType.MOVE)
		
		TrainerPersonality.PersonalityType.RANDOM:
			# Los aleatorios a veces toman decisiones subóptimas
			if randf() < 0.15:  # 15% chance de hacer algo random
				var random_actions = all_actions.filter(func(a): return a.score > 0)
				if random_actions.size() > 1:
					var random_action = random_actions[randi() % random_actions.size()]
					print("🎲 [BattleAI] Decisión aleatoria por personalidad")
					return {"best_action": random_action, "reasoning": "Decisión impredecible"}
	
	return {}  # Sin restricciones aplicadas

func get_alternative_action(all_actions: Array, excluded_type) -> Dictionary:
	"""Encuentra una acción alternativa excluyendo un tipo específico"""
	
	var alternatives = []
	for action_data in all_actions:
		if action_data.type != excluded_type and action_data.score > 0:
			alternatives.append(action_data)
	
	if alternatives.size() > 0:
		# Ordenar alternativas por puntuación
		alternatives.sort_custom(func(a, b): return a.score > b.score)
		return {
			"best_action": alternatives[0], 
			"reasoning": "Acción alternativa por restricciones"
		}
	
	# Si no hay alternativas, usar la primera acción disponible
	if all_actions.size() > 0:
		var fallback = all_actions[0]
		return {
			"best_action": fallback, 
			"reasoning": "Última opción disponible"
		}
	
	return {"best_action": null, "reasoning": "Sin acciones disponibles"}

func process_item_usage(item_name: String):
	"""Procesa el uso de un objeto y actualiza el inventario"""
	
	if available_items.has(item_name) and available_items[item_name] > 0:
		available_items[item_name] -= 1
		items_used_count[item_name] = items_used_count.get(item_name, 0) + 1
		
		# Eliminar item si se agota
		if available_items[item_name] <= 0:
			available_items.erase(item_name)
		
		print("🎒 [BattleAI] Objeto usado: %s (Restantes: %d)" % [
			item_name, available_items.get(item_name, 0)
		])

func record_action_in_memory(action: Dictionary):
	"""Registra una acción en la memoria de batalla"""
	
	match action.type:
		ActionComparator.ActionType.MOVE:
			battle_memory.moves_used.append(str(action.action.get("nombre", "")))
		ActionComparator.ActionType.ITEM:
			battle_memory.items_used.append(action.action)
		ActionComparator.ActionType.SWITCH_POKEMON:
			battle_memory.switches_made += 1

# ============================================================================
# FUNCIONES DE CONSULTA Y ESTADO
# ============================================================================

func get_available_items() -> Dictionary:
	"""Retorna los objetos disponibles actualmente"""
	return available_items.duplicate()

func add_items(new_items: Dictionary):
	"""Añade objetos al inventario del entrenador"""
	for item_name in new_items.keys():
		var quantity = new_items[item_name]
		if available_items.has(item_name):
			available_items[item_name] += quantity
		else:
			available_items[item_name] = quantity
			items_used_count[item_name] = 0

func has_healing_items() -> bool:
	"""Verifica si el entrenador tiene objetos de curación"""
	for item_name in available_items.keys():
		if ItemEvaluator.is_healing_item(item_name):
			return true
	return false

func has_revival_items() -> bool:
	"""Verifica si el entrenador tiene objetos de revivir"""
	for item_name in available_items.keys():
		var item_data = ItemEvaluator.get_item_data(item_name)
		if item_data.get("type") == ItemEvaluator.ItemType.REVIVAL:
			return true
	return false

func has_battle_items() -> bool:
	"""Verifica si el entrenador tiene objetos de batalla"""
	for item_name in available_items.keys():
		if ItemEvaluator.is_battle_item(item_name):
			return true
	return false

func get_battle_statistics() -> Dictionary:
	"""Retorna estadísticas de la batalla actual"""
	return {
		"turn_count": battle_memory.turn_count,
		"moves_used": battle_memory.moves_used.size(),
		"items_used": battle_memory.items_used.size(),
		"switches_made": battle_memory.switches_made,
		"total_item_types": available_items.size(),
		"personality": personality.get_personality_description()
	}

func reset_battle_memory():
	"""Reinicia la memoria para una nueva batalla"""
	battle_memory = {
		"turn_count": 0,
		"moves_used": [],
		"items_used": [],
		"switches_made": 0,
		"damage_taken": 0,
		"damage_dealt": 0
	}

	# Reiniciar contador de objetos usados
	for item in available_items.keys():
		items_used_count[item] = 0

func get_ai_difficulty_description() -> String:
	"""Retorna descripción de la dificultad de IA"""
	match difficulty_level:
		1:
			return "Principiante (Decisiones simples, uso mínimo de objetos)"
		2:
			return "Fácil (Algunas decisiones aleatorias, uso limitado de objetos)"
		3:
			return "Normal (Decisiones mayormente óptimas, uso moderado de objetos)"
		4:
			return "Difícil (Decisiones casi perfectas, uso estratégico de objetos)"
		5:
			return "Experto (Decisiones perfectas, uso óptimo de todos los recursos)"
		_:
			return "Desconocido"

func should_make_suboptimal_choice() -> bool:
	"""Determina si la IA debe hacer una elección subóptima basada en dificultad"""
	match difficulty_level:
		1:
			return randf() < 0.4  # 40% de decisiones subóptimas
		2:
			return randf() < 0.25  # 25% de decisiones subóptimas
		3:
			return randf() < 0.1   # 10% de decisiones subóptimas
		4:
			return randf() < 0.05  # 5% de decisiones subóptimas
		5:
			return false           # Siempre decisiones óptimas
		_:
			return randf() < 0.2

func get_personality_type_name() -> String:
	"""Retorna el nombre del tipo de personalidad"""
	return TrainerPersonality.PersonalityType.keys()[personality.personality_type]

# ============================================================================
# FUNCIONES DE DEBUG Y ANÁLISIS
# ============================================================================

func debug_print_state():
	"""Imprime estado completo de la IA para debugging"""
	print("=" + "=".repeat(49))
	print("🧠 [BattleAI] ESTADO COMPLETO DE IA")
	print("Personalidad: %s" % get_personality_type_name())
	print("Dificultad: %s" % get_ai_difficulty_description())
	print("Objetos disponibles: %s" % str(available_items))
	print("Objetos usados: %s" % str(items_used_count))
	print("Estadísticas: %s" % str(get_battle_statistics()))
	print("=" + "=".repeat(49))

class_name ActionComparator
extends RefCounted

## ============================================================================
## COMPARADOR DE ACCIONES DE BATALLA
## ============================================================================
## Compara y evalúa todas las acciones disponibles: movimientos, objetos, cambios
## Selecciona la mejor acción basándose en puntuaciones estratégicas

# Referencias a otras clases del sistema de IA
const MoveEvaluatorClass = preload("res://scripts/battle_ai/MoveEvaluator.gd")
const ItemEvaluatorClass = preload("res://scripts/battle_ai/ItemEvaluator.gd")

enum ActionType {
	MOVE,
	ITEM,
	SWITCH_POKEMON,
	RUN_AWAY
}

## Función principal para comparar todas las acciones disponibles y seleccionar la mejor
static func compare_all_actions(ally_pokemon, enemy_pokemon, available_items: Dictionary, team_status: Dictionary, battle_state: Dictionary, personality) -> Dictionary:
	
	var actions = []
	
	print("⚖️ [ActionComparator] Evaluando todas las acciones disponibles...")
	
	# Evaluar movimientos disponibles
	actions.append_array(evaluate_available_moves(ally_pokemon, enemy_pokemon, battle_state, personality))
	
	# Evaluar objetos disponibles
	actions.append_array(evaluate_available_items(ally_pokemon, enemy_pokemon, available_items, team_status, battle_state, personality))

	# El cambio de Pokémon no se puntúa: lo decide ShouldSwitch (should_switch_rules.gd).

	# Ordenar acciones por puntuación (mayor a menor)
	actions.sort_custom(func(a, b): return a.score > b.score)
	
	# Generar explicación de la decisión
	var reasoning = generate_decision_reasoning(actions, battle_state)
	
	var result = {
		"best_action": actions[0] if actions.size() > 0 else null,
		"all_actions": actions,
		"reasoning": reasoning
	}
	
	if result.best_action:
		print("🎯 [ActionComparator] Mejor acción: %s (%.1f pts)" % [
			result.best_action.description, result.best_action.score
		])
	
	return result

## Función para evaluar movimientos disponibles
static func evaluate_available_moves(ally_pokemon, enemy_pokemon, battle_state: Dictionary, personality) -> Array:
	
	var move_actions = []
	
	if not ally_pokemon.movimientos:
		return move_actions
	
	for move in ally_pokemon.movimientos:
		if move.get("pp_act", 0) > 0:
			var score = MoveEvaluatorClass.evaluate_move(move, ally_pokemon, enemy_pokemon, battle_state, personality)
			
			move_actions.append({
				"type": ActionType.MOVE,
				"action": move,
				"score": score,
				"description": "Usar %s" % move.nombre,
				"category": "offensive"
			})
	
	return move_actions

## Función para evaluar todos los objetos disponibles
static func evaluate_available_items(ally_pokemon, enemy_pokemon, available_items: Dictionary, team_status: Dictionary, battle_state: Dictionary, personality) -> Array:
	
	var item_actions = []
	
	for item_name in available_items.keys():
		var quantity = available_items[item_name]
		if quantity > 0:
			var score = ItemEvaluatorClass.evaluate_item_usage(
				item_name, ally_pokemon, enemy_pokemon, team_status, battle_state, personality
			)
			
			if score > 0:  # Solo considerar objetos con puntuación positiva
				item_actions.append({
					"type": ActionType.ITEM,
					"action": item_name,
					"score": score,
					"description": "Usar %s" % item_name,
					"category": ItemEvaluatorClass.get_item_category(item_name)
				})
	
	return item_actions

## Función para generar explicación del razonamiento de la decisión
static func generate_decision_reasoning(actions: Array, battle_state: Dictionary) -> String:
	
	if actions.size() == 0:
		return "Sin acciones disponibles"
	
	var best = actions[0]
	var hp_ratio = battle_state.get("hp_ratio_ally", 1.0)
	var threat_level = battle_state.get("threat_level", 0.0)
	
	match best.type:
		ActionType.MOVE:
			if hp_ratio < 0.3 and threat_level > 1.0:
				return "Ataque desesperado con HP crítico"
			elif threat_level > 1.2:
				return "Ataque para contrarrestar amenaza alta"
			else:
				return "Mejor movimiento ofensivo disponible"
		
		ActionType.ITEM:
			match best.category:
				"healing":
					if hp_ratio < 0.3:
						return "Curación crítica necesaria"
					else:
						return "Curación preventiva estratégica"
				"battle_item":
					return "Setup para mejorar capacidades"
				"status_cure":
					return "Cura estado alterado perjudicial"
				"revival":
					return "Revivir para recuperar ventaja numérica"
				_:
					return "Uso de objeto estratégico"
		
		ActionType.SWITCH_POKEMON:
			if hp_ratio < 0.2:
				return "Cambio de emergencia por HP crítico"
			else:
				return "Cambio estratégico para mejor matchup"
		
		ActionType.RUN_AWAY:
			return "Huida táctica por situación desesperada"
	
	return "Decisión óptima calculada"

## Función que retorna el nombre legible del tipo de acción
static func get_action_type_name(action_type: ActionType) -> String:
	return ActionType.keys()[action_type]

## Función para filtrar acciones por tipo específico
static func filter_actions_by_type(actions: Array, action_type: ActionType) -> Array:
	var filtered = []
	for action in actions:
		if action.type == action_type:
			filtered.append(action)
	return filtered

## Función para obtener la mejor acción de un tipo específico
static func get_best_action_of_type(actions: Array, action_type: ActionType) -> Dictionary:
	var filtered = filter_actions_by_type(actions, action_type)
	if filtered.size() > 0:
		filtered.sort_custom(func(a, b): return a.score > b.score)
		return filtered[0]
	return {}

## Función para verificar si hay alternativas viables excluyendo un tipo específico
static func has_viable_alternatives(actions: Array, excluded_type: ActionType) -> bool:
	for action in actions:
		if action.type != excluded_type and action.score > 0:
			return true
	return false

## Función para calcular la urgencia de una acción específica
static func calculate_action_urgency(action: Dictionary, battle_state: Dictionary) -> float:
	var urgency = 0.0
	var hp_ratio = battle_state.get("hp_ratio_ally", 1.0)
	var threat_level = battle_state.get("threat_level", 0.0)
	
	match action.type:
		ActionType.ITEM:
			if action.category == "healing" and hp_ratio < 0.25:
				urgency = 0.9  # Muy urgente
			elif action.category == "status_cure":
				urgency = 0.7  # Moderadamente urgente
		
		ActionType.MOVE:
			if threat_level > 1.5:
				urgency = 0.8  # Urgente si hay amenaza alta
		
		ActionType.SWITCH_POKEMON:
			if hp_ratio < 0.15:
				urgency = 0.85  # Muy urgente cambiar
	
	return urgency

## Función para evaluar el nivel de riesgo de una acción específica
static func get_action_risk_level(action: Dictionary) -> float:
	match action.type:
		ActionType.MOVE:
			var move = action.action
			var move_data = move.get("datos", {})
			var accuracy = move_data.get("precision")
			if accuracy == null or (typeof(accuracy) != TYPE_INT and typeof(accuracy) != TYPE_FLOAT):
				accuracy = 100
			return (100 - accuracy) / 100.0  # Mayor riesgo = menor precisión
		
		ActionType.ITEM:
			return 0.1  # Los objetos son generalmente seguros
		
		ActionType.SWITCH_POKEMON:
			return 0.3  # Cambio tiene riesgo moderado
		
		ActionType.RUN_AWAY:
			return 0.0  # Huir no tiene riesgo de daño
	
	return 0.5  # Riesgo por defecto

## Función para determinar si se debe priorizar un tipo de acción específico
static func should_prioritize_action_type(action_type: ActionType, battle_state: Dictionary, personality) -> bool:
	var hp_ratio = battle_state.get("hp_ratio_ally", 1.0)
	var threat_level = battle_state.get("threat_level", 0.0)
	
	match action_type:
		ActionType.ITEM:
			# Priorizar objetos si HP está bajo o personalidad defensiva
			if hp_ratio < 0.4:
				return true
			if personality.item_usage_frequency > 0.7:
				return true
		
		ActionType.MOVE:
			# Priorizar ataques si amenaza es alta o personalidad agresiva
			if threat_level > 1.0:
				return true
			if personality.aggression_level > 0.7:
				return true
		
		ActionType.SWITCH_POKEMON:
			# Priorizar cambio si HP crítico o personalidad estratégica
			if hp_ratio < 0.2:
				return true
			if personality.switch_tendency > 0.6:
				return true
	
	return false

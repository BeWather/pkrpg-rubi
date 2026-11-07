class_name TrainerPersonality
extends RefCounted

## ============================================================================
## PERSONALIDAD DE ENTRENADORES
## ============================================================================
## Define personalidades únicas para diferentes tipos de entrenadores
## Afecta decisiones de IA, uso de objetos y estrategias

enum PersonalityType {
	AGGRESSIVE,     # Prefiere ataques de alto daño
	DEFENSIVE,      # Prioriza movimientos de estado y curación
	STRATEGIC,      # Balancea ofensa y defensa
	RANDOM,         # Comportamiento impredecible
	SPECIALIST,     # Se enfoca en un tipo específico
	TECHNICAL       # Usa movimientos complejos y combos
}

var personality_type: PersonalityType
var aggression_level: float      # 0.0 - 1.0
var risk_tolerance: float        # 0.0 - 1.0
var item_usage_frequency: float  # 0.0 - 1.0
var switch_tendency: float       # 0.0 - 1.0
var type_preference: String      # Tipo favorito si es especialista
var setup_preference: float      # 0.0 - 1.0

func _init():
	# Valores por defecto
	personality_type = PersonalityType.STRATEGIC
	aggression_level = 0.5
	risk_tolerance = 0.5
	item_usage_frequency = 0.5
	switch_tendency = 0.3
	type_preference = ""
	setup_preference = 0.3

static func create_personality(trainer_class: String) -> TrainerPersonality:
	"""Crea una personalidad basada en la clase de entrenador"""
	var personality = TrainerPersonality.new()
	
	match trainer_class.to_lower():
		"joven", "youngster":
			personality.personality_type = PersonalityType.AGGRESSIVE
			personality.aggression_level = 0.8
			personality.risk_tolerance = 0.7
			personality.item_usage_frequency = 0.3
			personality.switch_tendency = 0.2
			personality.setup_preference = 0.1
		
		"montanista", "hiker":
			personality.personality_type = PersonalityType.DEFENSIVE
			personality.aggression_level = 0.3
			personality.risk_tolerance = 0.3
			personality.item_usage_frequency = 0.7
			personality.switch_tendency = 0.2
			personality.setup_preference = 0.4
		
		"as", "ace_trainer":
			personality.personality_type = PersonalityType.STRATEGIC
			personality.aggression_level = 0.6
			personality.risk_tolerance = 0.4
			personality.item_usage_frequency = 0.6
			personality.switch_tendency = 0.5
			personality.setup_preference = 0.5
		
		"lider_gimnasio", "gym_leader":
			personality.personality_type = PersonalityType.SPECIALIST
			personality.aggression_level = 0.7
			personality.risk_tolerance = 0.4
			personality.item_usage_frequency = 0.8
			personality.switch_tendency = 0.4
			personality.setup_preference = 0.6
		
		"alto_mando", "elite_four":
			personality.personality_type = PersonalityType.TECHNICAL
			personality.aggression_level = 0.6
			personality.risk_tolerance = 0.3
			personality.item_usage_frequency = 0.9
			personality.switch_tendency = 0.7
			personality.setup_preference = 0.8
		
		"campeon", "champion":
			personality.personality_type = PersonalityType.STRATEGIC
			personality.aggression_level = 0.8
			personality.risk_tolerance = 0.2
			personality.item_usage_frequency = 1.0
			personality.switch_tendency = 0.8
			personality.setup_preference = 0.7
		
		"pesca", "fisherman":
			personality.personality_type = PersonalityType.SPECIALIST
			personality.aggression_level = 0.4
			personality.risk_tolerance = 0.6
			personality.item_usage_frequency = 0.4
			personality.switch_tendency = 0.3
			personality.setup_preference = 0.3
			personality.type_preference = "AGUA"
		
		"nadador", "swimmer":
			personality.personality_type = PersonalityType.AGGRESSIVE
			personality.aggression_level = 0.7
			personality.risk_tolerance = 0.6
			personality.item_usage_frequency = 0.3
			personality.switch_tendency = 0.3
			personality.setup_preference = 0.2
			personality.type_preference = "AGUA"
		
		"entrenador_pokemon", "pokemon_trainer":
			personality.personality_type = PersonalityType.STRATEGIC
			personality.aggression_level = 0.5
			personality.risk_tolerance = 0.5
			personality.item_usage_frequency = 0.5
			personality.switch_tendency = 0.4
			personality.setup_preference = 0.4
		
		_:  # Valor por defecto para clases no reconocidas
			personality.personality_type = PersonalityType.RANDOM
			personality.aggression_level = randf_range(0.3, 0.8)
			personality.risk_tolerance = randf_range(0.3, 0.7)
			personality.item_usage_frequency = randf_range(0.2, 0.6)
			personality.switch_tendency = randf_range(0.2, 0.5)
			personality.setup_preference = randf_range(0.1, 0.5)
	
	print("🎭 [TrainerPersonality] Creada personalidad %s para clase %s" % [
		PersonalityType.keys()[personality.personality_type], trainer_class
	])
	
	return personality

func get_move_preference_modifier(move_category: String) -> float:
	"""Retorna un modificador basado en preferencias de movimiento"""
	match personality_type:
		PersonalityType.AGGRESSIVE:
			match move_category:
				"físico", "especial":
					return 1.2  # Bonus a ataques
				"estado":
					return 0.8  # Penalización a movimientos de estado
		
		PersonalityType.DEFENSIVE:
			match move_category:
				"estado":
					return 1.3  # Bonus a movimientos de estado
				"físico", "especial":
					return 0.9  # Leve penalización a ataques
		
		PersonalityType.STRATEGIC:
			return 1.0  # Sin modificadores, evalúa todo por igual
		
		PersonalityType.TECHNICAL:
			match move_category:
				"estado":
					return 1.1  # Leve bonus a movimientos técnicos
				_:
					return 1.0
		
		PersonalityType.SPECIALIST:
			# Bonus si el movimiento coincide con el tipo preferido
			return 1.0  # Se implementa en el evaluador de movimientos
		
		PersonalityType.RANDOM:
			return randf_range(0.8, 1.2)  # Variación aleatoria
	
	return 1.0

func should_use_item_early(item_type: String, hp_ratio: float) -> bool:
	"""Determina si se debe usar un objeto temprano en la batalla"""
	match personality_type:
		PersonalityType.DEFENSIVE:
			# Los defensivos usan objetos preventivamente
			if item_type == "healing" and hp_ratio < 0.7:
				return true
			if item_type == "battle_item":
				return true  # Siempre setup preventivo
		
		PersonalityType.AGGRESSIVE:
			# Los agresivos solo usan objetos en emergencias
			if item_type == "healing" and hp_ratio < 0.2:
				return true
			if item_type == "battle_item" and hp_ratio > 0.8:
				return true  # Solo si están sanos
		
		PersonalityType.STRATEGIC:
			# Los estratégicos evalúan la situación
			if item_type == "healing" and hp_ratio < 0.4:
				return true
			if item_type == "battle_item" and hp_ratio > 0.5:
				return true
		
		PersonalityType.TECHNICAL:
			# Los técnicos priorizan setup
			if item_type == "battle_item":
				return true
			if item_type == "healing" and hp_ratio < 0.3:
				return true
	
	return false

func get_risk_assessment_modifier() -> float:
	"""Retorna modificador para evaluación de riesgo"""
	return risk_tolerance

func prefers_setup_moves() -> bool:
	"""Determina si este entrenador prefiere movimientos de setup"""
	return setup_preference > 0.5

func get_personality_description() -> String:
	"""Retorna descripción de la personalidad para debug"""
	var desc = PersonalityType.keys()[personality_type]
	desc += " (Agr:%.1f, Risk:%.1f, Items:%.1f)" % [aggression_level, risk_tolerance, item_usage_frequency]
	return desc

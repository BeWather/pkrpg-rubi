class_name MoveEvaluator
extends RefCounted

## ============================================================================
## EVALUADOR DE MOVIMIENTOS INTELIGENTE
## ============================================================================
## Evalúa y puntúa movimientos basándose en múltiples factores estratégicos
## Considera daño, tipos, efectos secundarios, situación y personalidad

# Referencias a otras clases del sistema de IA
const CombatAnalyzer = preload("res://scripts/battle_ai/CombatAnalyzer.gd")
const TrainerPersonality = preload("res://scripts/battle_ai/TrainerPersonality.gd")

static func evaluate_move(move, ally_pokemon, enemy_pokemon, battle_state, personality) -> float:
	"""Evalúa un movimiento y retorna una puntuación estratégica"""
	
	var score = 0.0
	
	# Verificar si el movimiento es válido
	if not move or move.get("pp_act", 0) <= 0:
		return 0.0
	move = with_estimated_power(move, ally_pokemon, enemy_pokemon, battle_state.get("ai_difficulty", 1))

	# Evaluación base del potencial de daño
	score += evaluate_damage_potential(move, ally_pokemon, enemy_pokemon)
	
	# Efectividad de tipos (factor más importante)
	score += evaluate_type_effectiveness(move, enemy_pokemon) * 30.0
	
	# Evaluación de la situación de salud
	score += evaluate_health_situation(move, ally_pokemon, enemy_pokemon, battle_state)
	
	# Evaluación de efectos secundarios
	score += evaluate_secondary_effects(move, enemy_pokemon, battle_state)
	
	# Evaluación de precisión y PP
	score += evaluate_reliability(move)
	
	# Ajustes por personalidad del entrenador
	score = apply_personality_modifiers(score, move, personality)
	
	# Bonus/penalizaciones por situación específica
	score += evaluate_situational_factors(move, ally_pokemon, enemy_pokemon, battle_state)
	
	print("📊 [MoveEvaluator] %s: %.1f pts (Daño: %.1f, Tipo: %.1f)" % [
		move.nombre, score, 
		evaluate_damage_potential(move, ally_pokemon, enemy_pokemon),
		evaluate_type_effectiveness(move, enemy_pokemon) * 30.0
	])
	
	return max(score, 0.0)

## Potencia media de los movimientos de potencia variable (tablas del decomp).
const VARIABLE_POWER_AVERAGE := {
	"EFFECT_LOW_KICK": 70,     # media de 20/40/60/80/100/120 por peso
	"EFFECT_FLAIL": 98,        # media de 200/150/100/80/40/20 por PS restantes
	"EFFECT_RETURN": 51,       # mitad del máximo 102 por amistad
	"EFFECT_FRUSTRATION": 51,
}

## Copia del snapshot con `datos.potencia` estimada para Patada Baja, Azote,
## Inversión, Retroceso y Frustración (en la BD tienen `poder` NULL).
## Dificultad 1 usa la media; 5, la potencia real del momento; entre medio, interpola.
static func with_estimated_power(move, ally_pokemon, enemy_pokemon, difficulty: int):
	var move_data = move.get("datos", {})
	var effect: String = str(move_data.get("efecto", ""))
	if not VARIABLE_POWER_AVERAGE.has(effect):
		return move
	var average: int = VARIABLE_POWER_AVERAGE[effect]
	var certainty: float = clampf(float(difficulty - 1) / 4.0, 0.0, 1.0)
	var estimated: int = average
	if certainty > 0.0:
		estimated = roundi(lerpf(float(average), float(exact_variable_power(effect, ally_pokemon, enemy_pokemon, average)), certainty))
	var copy: Dictionary = move.duplicate(true)
	copy.datos.potencia = estimated
	return copy

## Potencia real que tendría el golpe ahora; `fallback` si faltan datos.
static func exact_variable_power(effect: String, ally_pokemon, enemy_pokemon, fallback: int) -> int:
	match effect:
		"EFFECT_LOW_KICK":
			var target := BasePokemon.new()
			target.nombre_interno = str(enemy_pokemon.get("nombre_interno", ""))
			return preload("res://scripts/battle/variable_power_rules.gd").low_kick_power(target) if not target.nombre_interno.is_empty() else fallback
		"EFFECT_FLAIL":
			var actor := BasePokemon.new()
			actor.estad_ps = int(ally_pokemon.get("estad_ps", 0))
			actor.estad_ps_actual = int(ally_pokemon.get("estad_ps_actual", 0))
			return MoveResolver.source_hp_power(actor) if actor.estad_ps > 0 else fallback
		"EFFECT_RETURN", "EFFECT_FRUSTRATION":
			return MoveResolver.source_friendship_power(effect, int(ally_pokemon.get("felicidad", 0))) if ally_pokemon.has("felicidad") else fallback
	return fallback

static func evaluate_damage_potential(move, ally_pokemon, enemy_pokemon) -> float:
	"""Evalúa el potencial de daño de un movimiento"""
	
	var move_data = move.get("datos", {})
	var category = move_data.get("categoria", "estado")
	var base_power = move_data.get("potencia", 0)
	
	if category == "estado":
		return 5.0  # Valor base para movimientos de estado
	
	# Calcular estadísticas relevantes
	var attack_stat: int
	var defense_stat: int
	
	if category == "físico":
		attack_stat = ally_pokemon.get("estad_ataque", 50)
		defense_stat = enemy_pokemon.get("estad_defensa", 50)
	else:  # especial
		attack_stat = ally_pokemon.get("estad_ataque_especial", 50)
		defense_stat = enemy_pokemon.get("estad_defensa_especial", 50)
	
	# Cálculo básico de daño relativo
	var damage_ratio = float(attack_stat) / max(defense_stat, 1)
	var damage_score = (base_power * damage_ratio) / 15.0
	
	# Bonus por STAB (Same Type Attack Bonus)
	if is_stab_move(move, ally_pokemon):
		damage_score *= 1.5
	
	return damage_score

static func evaluate_type_effectiveness(move, enemy_pokemon) -> float:
	"""Evalúa la efectividad de tipos de un movimiento"""
	
	var move_type = move.get("tipo", "NORMAL")
	var effectiveness = CombatAnalyzer.get_type_effectiveness(move_type, enemy_pokemon)
	
	# Convertir efectividad a puntuación
	if effectiveness >= 2.0:
		return 25.0  # Super efectivo
	elif effectiveness > 1.0:
		return 10.0  # Efectivo
	elif effectiveness == 1.0:
		return 0.0   # Daño normal
	elif effectiveness > 0.0:
		return -15.0 # No muy efectivo
	else:
		return -50.0 # Sin efecto (inmune)

static func evaluate_health_situation(move, ally_pokemon, enemy_pokemon, battle_state) -> float:
	"""Evalúa el movimiento basándose en la situación de HP"""
	
	var ally_hp_ratio = battle_state.get("hp_ratio_ally", 1.0)
	var enemy_hp_ratio = battle_state.get("hp_ratio_enemy", 1.0)
	var score = 0.0
	
	var move_data = move.get("datos", {})
	var category = move_data.get("categoria", "estado")
	
	# Si el aliado está en peligro
	if ally_hp_ratio < 0.3:
		# Priorizar movimientos de curación si los tiene
		if is_healing_move(move):
			score += 40.0
		# Priorizar ataques de alta prioridad para intentar atacar primero
		elif move_data.get("prioridad", 0) > 0:
			score += 20.0
	
	# Si el enemigo está débil, priorizar finalizarlo
	if enemy_hp_ratio < 0.25:
		if category in ["físico", "especial"]:
			score += 30.0  # Bonus por finalizar
		# Evitar movimientos de estado cuando el enemigo está casi derrotado
		elif category == "estado":
			score -= 15.0
	
	# Si ambos están sanos, considerar setup
	if ally_hp_ratio > 0.7 and enemy_hp_ratio > 0.7:
		if is_setup_move(move):
			score += 15.0
	
	return score

static func evaluate_secondary_effects(move, enemy_pokemon, battle_state) -> float:
	"""Evalúa efectos secundarios de movimientos"""
	
	var move_data = move.get("datos", {})
	var secondary_effect = move_data.get("efecto_secundario", "")
	var effect_chance = move_data.get("probabilidad_efecto", 0)
	var score = 0.0
	
	if secondary_effect != "" and effect_chance > 0:
		var effect_value = 0.0
		
		match secondary_effect.to_lower():
			"paralizar":
				effect_value = 15.0  # Muy útil para control de velocidad
			"envenenar", "envenenamiento_grave":
				effect_value = 12.0  # Daño por turnos
			"dormir":
				effect_value = 20.0  # Muy poderoso
			"confundir":
				effect_value = 10.0  # Útil pero inconsistente
			"amedrentar":
				effect_value = 8.0   # Reduce ataque
			"quemar":
				effect_value = 14.0  # Daño + reduce ataque físico
			"congelar":
				effect_value = 18.0  # Muy poderoso pero raro
		
		# Ajustar por probabilidad
		score += effect_value * (effect_chance / 100.0)
		
		# Bonus si el enemigo no tiene estado
		var enemy_status = battle_state.get("status_effects", {}).get("enemy_status", "")
		if enemy_status == "":
			score *= 1.2  # 20% bonus si puede aplicar estado
	
	return score

static func evaluate_reliability(move) -> float:
	"""Evalúa la confiabilidad del movimiento (precisión y PP)"""
	
	var move_data = move.get("datos", {})
	var accuracy = move_data.get("precision")
	if accuracy == null or (typeof(accuracy) != TYPE_INT and typeof(accuracy) != TYPE_FLOAT):
		accuracy = 100
	var current_pp = move.get("pp_act", 0)
	var max_pp = move_data.get("pp", 1)
	var score = 0.0
	
	# Penalización por baja precisión
	if accuracy < 100:
		var accuracy_penalty = (100 - accuracy) * 0.3
		score -= accuracy_penalty
	
	# Penalización por PP bajo
	var pp_ratio = float(current_pp) / max_pp
	if pp_ratio < 0.3:
		score -= 10.0  # Conservar PP cuando está bajo
	elif pp_ratio < 0.5:
		score -= 5.0
	
	return score

static func apply_personality_modifiers(base_score: float, move, personality) -> float:
	"""Aplica modificadores basados en personalidad del entrenador"""
	
	var modified_score = base_score
	var move_data = move.get("datos", {})
	var category = move_data.get("categoria", "estado")
	
	# Modificador por categoría de movimiento
	var category_modifier = personality.get_move_preference_modifier(category)
	modified_score *= category_modifier
	
	# Modificadores específicos por tipo de personalidad
	match personality.personality_type:
		TrainerPersonality.PersonalityType.AGGRESSIVE:
			# Bonus a movimientos de alta potencia
			var power = move_data.get("potencia", 0)
			if power >= 80:
				modified_score += 10.0
			# Penalización a movimientos defensivos
			if is_defensive_move(move):
				modified_score -= 15.0
		
		TrainerPersonality.PersonalityType.DEFENSIVE:
			# Bonus a movimientos de estado y curación
			if is_status_move(move) or is_healing_move(move):
				modified_score += 15.0
			# Bonus a movimientos con efectos defensivos
			if is_defensive_move(move):
				modified_score += 10.0
		
		TrainerPersonality.PersonalityType.STRATEGIC:
			# Evaluación balanceada, pequeño bonus a movimientos versátiles
			if has_secondary_effect(move):
				modified_score += 5.0
		
		TrainerPersonality.PersonalityType.SPECIALIST:
			# Bonus si el movimiento coincide con tipo preferido
			if personality.type_preference != "" and move.get("tipo", "") == personality.type_preference:
				modified_score += 20.0
		
		TrainerPersonality.PersonalityType.TECHNICAL:
			# Bonus a movimientos complejos
			if is_setup_move(move) or has_unique_effect(move):
				modified_score += 12.0
		
		TrainerPersonality.PersonalityType.RANDOM:
			# Variación aleatoria
			modified_score += randf_range(-10.0, 10.0)
	
	return modified_score

static func evaluate_situational_factors(move, ally_pokemon, enemy_pokemon, battle_state) -> float:
	"""Evalúa factores situacionales específicos"""
	
	var score = 0.0
	var move_data = move.get("datos", {})
	
	# Factor de velocidad
	var speed_advantage = battle_state.get("speed_advantage", false)
	var priority = move_data.get("prioridad", 0)
	
	if not speed_advantage and priority > 0:
		score += 15.0  # Bonus por movimiento de prioridad cuando es más lento
	
	# Factor de amenaza
	var threat_level = battle_state.get("threat_level", 0.0)
	if threat_level > 1.2:
		# En situaciones de alta amenaza, priorizar daño inmediato
		if move_data.get("categoria", "") in ["físico", "especial"]:
			score += 10.0
		elif is_status_move(move):
			score -= 10.0
	
	# Factor de fase de batalla
	var turn_count = battle_state.get("turn_count", 0)
	if turn_count <= 2 and is_setup_move(move):
		score += 8.0  # Bonus por setup temprano
	elif turn_count > 6 and is_setup_move(move):
		score -= 12.0  # Penalización por setup tardío
	
	return score

# ============================================================================
# FUNCIONES DE UTILIDAD PARA CLASIFICAR MOVIMIENTOS
# ============================================================================

static func is_stab_move(move, pokemon) -> bool:
	"""Verifica si el movimiento recibe STAB"""
	var move_type = move.get("tipo", "")
	return move_type == pokemon.get("tipo_primario", "") or move_type == pokemon.get("tipo_secundario", "")

static func is_healing_move(move) -> bool:
	"""Verifica si es un movimiento de curación"""
	var move_name = move.get("nombre", "").to_lower()
	var healing_moves = ["recuperacion", "descanso", "sintesis", "luz_lunar", "absorber", "drenadoras"]
	
	for healing_move in healing_moves:
		if healing_move in move_name:
			return true
	
	return false

static func is_status_move(move) -> bool:
	"""Verifica si es un movimiento de estado"""
	var move_data = move.get("datos", {})
	return move_data.get("categoria", "") == "estado"

static func is_setup_move(move) -> bool:
	"""Verifica si es un movimiento de setup (aumenta estadísticas)"""
	var move_name = move.get("nombre", "").to_lower()
	var setup_moves = ["danza_espada", "amnesia", "agilidad", "fortaleza", "defensa_ferrea", "resplandor"]
	
	for setup_move in setup_moves:
		if setup_move in move_name:
			return true
	
	return false

static func is_defensive_move(move) -> bool:
	"""Verifica si es un movimiento defensivo"""
	var move_name = move.get("nombre", "").to_lower()
	var defensive_moves = ["proteccion", "detectar", "resistencia", "aguante", "sustituto"]
	
	for defensive_move in defensive_moves:
		if defensive_move in move_name:
			return true
	
	return is_healing_move(move)

static func has_secondary_effect(move) -> bool:
	"""Verifica si el movimiento tiene efecto secundario"""
	var move_data = move.get("datos", {})
	return move_data.get("efecto_secundario", "") != ""

static func has_unique_effect(move) -> bool:
	"""Verifica si el movimiento tiene un efecto único o complejo"""
	var move_name = move.get("nombre", "").to_lower()
	var unique_moves = ["truco", "intercambio", "transformacion", "metronomo", "espejo", "mimico"]
	
	for unique_move in unique_moves:
		if unique_move in move_name:
			return true
	
	return false

static func is_high_damage_move(move) -> bool:
	"""Verifica si es un movimiento de alto daño"""
	var move_data = move.get("datos", {})
	var power = move_data.get("potencia", 0)
	return power >= 80

static func get_move_priority(move) -> int:
	"""Obtiene la prioridad del movimiento"""
	var move_data = move.get("datos", {})
	return move_data.get("prioridad", 0)

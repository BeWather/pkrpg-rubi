class_name CombatAnalyzer
extends RefCounted

static func _type_effectiveness_against_defender(move_type: String, defender_type: String) -> float:
	if move_type == "" or defender_type == "":
		return 1.0
	if Singleton.tabla_tipos == null or not Singleton.tabla_tipos.has(move_type):
		return 1.0
	return float(Singleton.tabla_tipos[move_type].get(defender_type, 1.0))

## ============================================================================
## ANALIZADOR DE COMBATE INTELIGENTE
## ============================================================================
## Analiza la situación actual de batalla para tomar decisiones estratégicas
## Evalúa HP, tipos, velocidad, amenazas y contexto de batalla

static func analyze_battle_state(ally_pokemon, enemy_pokemon, battle_context) -> Dictionary:
	"""Analiza el estado completo de la batalla actual"""
	
	var analysis = {}
	
	# Análisis básico de HP
	analysis["hp_ratio_ally"] = calculate_hp_ratio(ally_pokemon)
	analysis["hp_ratio_enemy"] = calculate_hp_ratio(enemy_pokemon)
	
	# Análisis de velocidad
	analysis["speed_advantage"] = ally_pokemon.estad_velocidad > enemy_pokemon.estad_velocidad
	analysis["speed_ratio"] = float(ally_pokemon.estad_velocidad) / max(enemy_pokemon.estad_velocidad, 1)
	
	# Análisis de tipos
	analysis["type_advantages"] = calculate_type_advantages(ally_pokemon, enemy_pokemon)
	
	# Análisis de efectos de estado
	analysis["status_effects"] = analyze_status_effects(ally_pokemon, enemy_pokemon)
	
	# Análisis de amenaza
	analysis["threat_level"] = calculate_threat_level(ally_pokemon, enemy_pokemon)
	analysis["enemy_threat_level"] = calculate_threat_level(enemy_pokemon, ally_pokemon)
	
	# Contexto de batalla
	analysis["turn_count"] = battle_context.get("turn_count", 0)
	analysis["battle_type"] = battle_context.get("battle_type", "trainer")
	
	print("🔍 [CombatAnalyzer] Estado analizado - HP: %.1f/%.1f, Amenaza: %.1f" % [
		analysis.hp_ratio_ally, analysis.hp_ratio_enemy, analysis.threat_level
	])
	
	return analysis

static func calculate_hp_ratio(pokemon) -> float:
	"""Calcula la proporción de HP actual"""
	if not pokemon or pokemon.estad_ps <= 0:
		return 0.0
	return float(pokemon.estad_ps_actual) / pokemon.estad_ps

static func calculate_type_advantages(ally_pokemon, enemy_pokemon) -> Dictionary:
	"""Calcula ventajas y desventajas de tipos"""
	var advantages = {
		"offensive": [],  # Movimientos super efectivos del aliado
		"defensive": [],  # Resistencias del aliado
		"vulnerabilities": []  # Debilidades del aliado
	}
	
	# Analizar movimientos ofensivos
	if ally_pokemon.movimientos:
		for move in ally_pokemon.movimientos:
			if move.pp_act > 0:
				var effectiveness = get_type_effectiveness(move.tipo, enemy_pokemon)
				if effectiveness > 1.0:
					advantages.offensive.append({
						"move": move,
						"effectiveness": effectiveness
					})
	
	# Analizar defensas del aliado
	var ally_types = [ally_pokemon.tipo_primario]
	if ally_pokemon.get("tipo_secundario") and ally_pokemon.tipo_secundario != "":
		ally_types.append(ally_pokemon.tipo_secundario)
	
	# Analizar movimientos del enemigo para calcular resistencias/debilidades
	if enemy_pokemon.movimientos:
		for move in enemy_pokemon.movimientos:
			var effectiveness = 1.0
			for ally_type in ally_types:
				effectiveness *= _type_effectiveness_against_defender(str(move.tipo), str(ally_type))
			
			if effectiveness > 1.0:
				advantages.vulnerabilities.append({
					"move": move,
					"effectiveness": effectiveness
				})
			elif effectiveness < 1.0:
				advantages.defensive.append({
					"move": move,
					"effectiveness": effectiveness
				})
	
	return advantages

static func get_type_effectiveness(move_type: String, target_pokemon) -> float:
	"""Calcula la efectividad de un tipo de movimiento contra un Pokémon"""
	var effectiveness = _type_effectiveness_against_defender(move_type, str(target_pokemon.tipo_primario))
	
	if target_pokemon.get("tipo_secundario") and target_pokemon.tipo_secundario != "":
		effectiveness *= _type_effectiveness_against_defender(move_type, str(target_pokemon.tipo_secundario))
	
	return effectiveness

static func analyze_status_effects(ally_pokemon, enemy_pokemon) -> Dictionary:
	"""Analiza efectos de estado actuales"""
	return {
		"ally_status": ally_pokemon.get("estado", ""),
		"enemy_status": enemy_pokemon.get("estado", ""),
		"ally_affected": ally_pokemon.get("estado", "") != "",
		"enemy_affected": enemy_pokemon.get("estado", "") != ""
	}

static func calculate_threat_level(attacker, defender) -> float:
	"""Calcula el nivel de amenaza que representa un Pokémon para otro"""
	var threat = 0.0
	
	# Factor base por estadísticas
	var attack_power = max(attacker.estad_ataque, attacker.estad_ataque_especial)
	var defense_power = max(defender.estad_defensa, defender.estad_defensa_especial)
	var stat_ratio = float(attack_power) / max(defense_power, 1)
	
	threat += stat_ratio * 0.3  # 30% basado en estadísticas
	
	# Factor por movimientos efectivos
	if attacker.movimientos:
		var max_effectiveness = 1.0
		for move in attacker.movimientos:
			if move.pp_act > 0:
				var effectiveness = get_type_effectiveness(move.tipo, defender)
				max_effectiveness = max(max_effectiveness, effectiveness)
		
		threat += max_effectiveness * 0.4  # 40% basado en efectividad
	
	# Factor por HP del defensor
	var defender_hp_ratio = calculate_hp_ratio(defender)
	if defender_hp_ratio < 0.5:
		threat += 0.3  # 30% adicional si el defensor está débil
	
	return min(threat, 2.0)  # Máximo 2.0

static func get_battle_phase(battle_context) -> String:
	"""Determina la fase actual de la batalla"""
	var turn_count = battle_context.get("turn_count", 0)
	
	if turn_count <= 2:
		return "early"
	elif turn_count <= 6:
		return "mid"
	else:
		return "late"

static func is_critical_situation(ally_pokemon, enemy_pokemon) -> bool:
	"""Determina si la situación es crítica para el aliado"""
	var ally_hp = calculate_hp_ratio(ally_pokemon)
	var threat = calculate_threat_level(enemy_pokemon, ally_pokemon)
	
	return ally_hp < 0.25 or (ally_hp < 0.5 and threat > 1.2)

static func should_prioritize_defense(ally_pokemon, enemy_pokemon, battle_context) -> bool:
	"""Determina si se debe priorizar la defensa"""
	var threat = calculate_threat_level(enemy_pokemon, ally_pokemon)
	var ally_hp = calculate_hp_ratio(ally_pokemon)
	var phase = get_battle_phase(battle_context)
	
	return threat > 1.0 and ally_hp < 0.6 and phase != "late"

static func can_likely_survive_turn(ally_pokemon, enemy_pokemon) -> bool:
	"""Estima si el Pokémon aliado puede sobrevivir el siguiente turno"""
	var ally_hp = calculate_hp_ratio(ally_pokemon)
	var threat = calculate_threat_level(enemy_pokemon, ally_pokemon)
	
	# Estimación simple: si la amenaza es muy alta y el HP es bajo, probablemente no sobreviva
	if threat > 1.5 and ally_hp < 0.3:
		return false
	elif threat > 1.2 and ally_hp < 0.2:
		return false
	
	return true

static func estimate_turns_to_victory(ally_pokemon, enemy_pokemon) -> int:
	"""Estima cuántos turnos tomaría derrotar al enemigo"""
	var enemy_hp = enemy_pokemon.estad_ps_actual
	var ally_attack = max(ally_pokemon.estad_ataque, ally_pokemon.estad_ataque_especial)
	
	# Estimación muy básica
	var estimated_damage = ally_attack * 0.4  # Factor conservador
	
	if estimated_damage <= 0:
		return 99  # No puede ganar
	
	return ceil(enemy_hp / estimated_damage)

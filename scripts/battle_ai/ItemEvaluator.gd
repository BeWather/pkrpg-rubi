class_name ItemEvaluator
extends RefCounted

## ============================================================================
## EVALUADOR DE OBJETOS INTELIGENTE
## ============================================================================
## Evalúa el uso estratégico de objetos durante la batalla
## Considera curación, revivir, objetos de batalla y situación actual

# Referencias a otras clases del sistema de IA
const CombatAnalyzer = preload("res://scripts/battle_ai/CombatAnalyzer.gd")
const TrainerPersonality = preload("res://scripts/battle_ai/TrainerPersonality.gd")

enum ItemType {
	HEALING,        # Pociones, bayas curativas
	REVIVAL,        # Revivir, Revivir Máximo
	STATUS_CURE,    # Antídoto, Despertar, etc.
	BATTLE_ITEM,    # Ataque X, Defensa X, etc.
	ESCAPE_ITEM     # Muñeco Escape
}

## Evalúa si usar un objeto específico en la situación actual
static func evaluate_item_usage(item_name: String, ally_pokemon, enemy_pokemon, team_status, battle_state, personality) -> float:

	var item_data = get_item_data(item_name)
	if not item_data:
		return 0.0

	var score = 0.0
	var item_type = item_data.get("type", ItemType.HEALING)

	match item_type:
		ItemType.HEALING:
			score = evaluate_healing_item(item_data, ally_pokemon, battle_state, personality)
		ItemType.REVIVAL:
			score = evaluate_revival_item(item_data, ally_pokemon, team_status, battle_state, personality)
		ItemType.STATUS_CURE:
			score = evaluate_status_cure_item(item_data, ally_pokemon, battle_state)
		ItemType.BATTLE_ITEM:
			score = evaluate_battle_item(item_data, ally_pokemon, enemy_pokemon, battle_state, personality)
		ItemType.ESCAPE_ITEM:
			score = evaluate_escape_item(ally_pokemon, enemy_pokemon, battle_state, personality)

	print("🎒 [ItemEvaluator] %s: %.1f pts (Tipo: %s)" % [
		item_name, score, ItemType.keys()[item_type]
	])

	return score

## Evalúa objetos de curación
static func evaluate_healing_item(item_data: Dictionary, pokemon, battle_state: Dictionary, personality) -> float:

	var current_hp_ratio = float(pokemon.estad_ps_actual) / pokemon.estad_ps
	var heal_amount = item_data.get("heal_amount", 0)
	var heal_ratio = item_data.get("heal_ratio", 0.0)

	# Calcular HP después de usar el objeto
	var heal_value = heal_amount
	if heal_ratio > 0:
		heal_value = pokemon.estad_ps * heal_ratio

	var hp_after_heal = min(pokemon.estad_ps, pokemon.estad_ps_actual + heal_value)
	var hp_ratio_after = float(hp_after_heal) / pokemon.estad_ps

	var score = 0.0

	# Puntuación base según urgencia de curación
	if current_hp_ratio < 0.2:
		score += 80.0  # Crítico
	elif current_hp_ratio < 0.4:
		score += 50.0  # Urgente
	elif current_hp_ratio < 0.6:
		score += 20.0  # Preventivo
	else:
		score -= 10.0  # Innecesario si HP alto

	# Eficiencia del objeto (no desperdiciar curación)
	var hp_missing = pokemon.estad_ps - pokemon.estad_ps_actual
	if hp_missing > 0:
		var heal_efficiency = min(1.0, heal_value / hp_missing)
		score += heal_efficiency * 20.0
	else:
		score -= 30.0  # Penalización severa por usar en HP completo

	# Modificador por personalidad
	if personality.personality_type == TrainerPersonality.PersonalityType.DEFENSIVE:
		score += 15.0  # Los defensivos usan objetos más frecuentemente
	elif personality.personality_type == TrainerPersonality.PersonalityType.AGGRESSIVE:
		score -= 10.0  # Los agresivos prefieren atacar

	# Evaluar si debe usar objeto temprano según personalidad
	if personality.should_use_item_early("healing", current_hp_ratio):
		score += 20.0

	# Penalización si hay amenaza inmediata muy alta
	var threat_level = battle_state.get("threat_level", 0.0)
	if threat_level > 1.5 and current_hp_ratio > 0.3:
		score -= 20.0  # Mejor atacar que curar ante amenaza extrema

	return max(score, 0.0)

## Evalúa objetos de revivir
static func evaluate_revival_item(item_data: Dictionary, current_pokemon, team_status: Dictionary, battle_state: Dictionary, personality) -> float:

	var fainted_pokemon = team_status.get("fainted_pokemon", [])
	if fainted_pokemon.size() == 0:
		return 0.0  # No hay Pokémon debilitados

	var score = 0.0
	var current_hp_ratio = float(current_pokemon.estad_ps_actual) / current_pokemon.estad_ps

	# Solo considerar revivir si la situación es desesperada
	if current_hp_ratio < 0.3 and fainted_pokemon.size() > 0:
		score += 60.0

		# Bonus si hay un Pokémon debilitado que tenga ventaja de tipo
		var enemy_pokemon = battle_state.get("enemy_pokemon")
		if enemy_pokemon:
			var best_revival = find_best_revival_candidate(fainted_pokemon, enemy_pokemon)
			if best_revival:
				score += 25.0

	# Considerar el costo de oportunidad (perder un turno)
	var enemy_threat_level = battle_state.get("enemy_threat_level", 0.0)
	if enemy_threat_level > 0.7:
		score -= 30.0  # Demasiado peligroso perder un turno

	# Personalidad conservadora prefiere tener respaldo
	if personality.risk_tolerance < 0.4:
		score += 10.0

	# Si solo queda un Pokémon activo, priorizar revivir
	var active_pokemon = team_status.get("available_pokemon", [])
	if active_pokemon.size() <= 1:
		score += 40.0

	return max(score, 0.0)

## Evalúa objetos que curan estados alterados
static func evaluate_status_cure_item(item_data: Dictionary, pokemon, battle_state: Dictionary) -> float:

	var current_status = pokemon.get("estado", "")
	if current_status == "":
		return 0.0  # No tiene estado que curar

	var cures = item_data.get("cures", [])
	if not current_status.to_lower() in cures:
		return 0.0  # El objeto no cura este estado

	var score = 0.0

	# Puntuación según gravedad del estado
	match current_status.to_lower():
		"paralizado":
			score += 25.0  # Muy importante curar (afecta velocidad)
		"dormido":
			score += 30.0  # Crítico curar (no puede atacar)
		"congelado":
			score += 35.0  # Extremadamente importante
		"envenenado":
			score += 15.0  # Importante pero no crítico
		"envenenamiento_grave":
			score += 25.0  # Más urgente que envenenamiento normal
		"quemado":
			score += 20.0  # Moderadamente importante
		"confundido":
			score += 12.0  # Menos crítico

	# Bonus si puede sobrevivir más turnos sin el estado
	if CombatAnalyzer.can_likely_survive_turn(pokemon, battle_state.get("enemy_pokemon")):
		score += 10.0

	return score

## Evalúa objetos de batalla (potenciadores de estadísticas)
static func evaluate_battle_item(item_data: Dictionary, ally_pokemon, enemy_pokemon, battle_state: Dictionary, personality) -> float:

	var stat_boost = item_data.get("stat_boost", {})
	var boost_stages = item_data.get("boost_stages", 1)
	var score = 0.0

	# Evaluar utilidad del boost por estadística
	for stat in stat_boost.keys():
		match stat:
			"ataque":
				if has_physical_moves(ally_pokemon):
					score += 30.0 * boost_stages
			"ataque_especial":
				if has_special_moves(ally_pokemon):
					score += 30.0 * boost_stages
			"defensa":
				var expected_turns = battle_state.get("expected_survival_turns", 1)
				if expected_turns > 2:
					score += 20.0 * boost_stages
			"defensa_especial":
				if enemy_has_special_moves(enemy_pokemon):
					score += 20.0 * boost_stages
			"velocidad":
				if ally_pokemon.estad_velocidad <= enemy_pokemon.estad_velocidad:
					score += 25.0 * boost_stages  # Muy valioso si es más lento

	# Modificadores por personalidad
	match personality.personality_type:
		TrainerPersonality.PersonalityType.AGGRESSIVE:
			# Los agresivos prefieren boosts ofensivos
			if "ataque" in stat_boost or "ataque_especial" in stat_boost:
				score += 15.0
			else:
				score -= 10.0  # Penalización por boosts defensivos

		TrainerPersonality.PersonalityType.DEFENSIVE:
			# Los defensivos prefieren boosts defensivos
			if "defensa" in stat_boost or "defensa_especial" in stat_boost:
				score += 15.0

		TrainerPersonality.PersonalityType.STRATEGIC:
			# Los estratégicos evalúan según situación
			var hp_ratio = battle_state.get("hp_ratio_ally", 1.0)
			if hp_ratio > 0.7:  # Solo si está sano
				score += 10.0

		TrainerPersonality.PersonalityType.TECHNICAL:
			# Los técnicos aman el setup
			score += 20.0

	# Penalización si la situación es demasiado urgente
	var threat_level = battle_state.get("threat_level", 0.0)
	if threat_level > 1.2:
		score -= 25.0  # Mejor atacar que hacer setup ante amenaza alta

	# Bonus por setup temprano
	var turn_count = battle_state.get("turn_count", 0)
	if turn_count <= 2:
		score += 15.0
	elif turn_count > 5:
		score -= 20.0  # Setup tardío es menos efectivo

	return max(score, 0.0)

## Evalúa objetos de escape (muy raro de usar)
static func evaluate_escape_item(_ally_pokemon, _enemy_pokemon, _battle_state: Dictionary, personality) -> float:

	# Solo personalidades muy conservadoras o al azar considerarían escapar
	if personality.risk_tolerance < 0.2:
		return 10.0

	return 0.0  # Generalmente no se usa en batallas de entrenadores

## Base de datos de objetos del juego
static func get_item_data(item_name: String) -> Dictionary:

	var items_db = {
		"POCION": {
			"type": ItemType.HEALING,
			"heal_amount": 20
		},
		"SUPERPOCION": {
			"type": ItemType.HEALING,
			"heal_amount": 50
		},
		"HIPERPOCION": {
			"type": ItemType.HEALING,
			"heal_amount": 200
		},
		"POCION_COMPLETA": {
			"type": ItemType.HEALING,
			"heal_ratio": 1.0
		},
		"REVIVIR": {
			"type": ItemType.REVIVAL,
			"heal_ratio": 0.5
		},
		"REVIVIR_MAXIMO": {
			"type": ItemType.REVIVAL,
			"heal_ratio": 1.0
		},
		"ANTIDOTO": {
			"type": ItemType.STATUS_CURE,
			"cures": ["envenenado", "envenenamiento_grave"]
		},
		"DESPERTAR": {
			"type": ItemType.STATUS_CURE,
			"cures": ["dormido"]
		},
		"ANTIPARALIZ": {
			"type": ItemType.STATUS_CURE,
			"cures": ["paralizado"]
		},
		"ANTIHIELO": {
			"type": ItemType.STATUS_CURE,
			"cures": ["congelado"]
		},
		"ANTIQUEMAR": {
			"type": ItemType.STATUS_CURE,
			"cures": ["quemado"]
		},
		"ATAQUE_X": {
			"type": ItemType.BATTLE_ITEM,
			"stat_boost": {"ataque": true},
			"boost_stages": 1
		},
		"DEFENSA_X": {
			"type": ItemType.BATTLE_ITEM,
			"stat_boost": {"defensa": true},
			"boost_stages": 1
		},
		"VELOCIDAD_X": {
			"type": ItemType.BATTLE_ITEM,
			"stat_boost": {"velocidad": true},
			"boost_stages": 1
		},
		"ESPECIAL_X": {
			"type": ItemType.BATTLE_ITEM,
			"stat_boost": {"ataque_especial": true},
			"boost_stages": 1
		},
		"PRECISION_X": {
			"type": ItemType.BATTLE_ITEM,
			"stat_boost": {"precision": true},
			"boost_stages": 1
		}
	}

	return items_db.get(item_name.to_upper(), {})

# ============================================================================
# FUNCIONES DE UTILIDAD
# ============================================================================

## Encuentra el mejor candidato para revivir
static func find_best_revival_candidate(fainted_pokemon: Array, enemy_pokemon) -> Dictionary:

	var best_candidate = null
	var best_score = 0.0

	for pokemon in fainted_pokemon:
		var score = 0.0

		# Evaluar ventaja de tipo
		if pokemon.movimientos:
			for move in pokemon.movimientos:
				var effectiveness = CombatAnalyzer.get_type_effectiveness(move.tipo, enemy_pokemon)
				if effectiveness > 1.0:
					score += effectiveness * 20.0

		# Preferir Pokémon con más HP base
		score += pokemon.estad_ps * 0.1

		if score > best_score:
			best_score = score
			best_candidate = pokemon

	return best_candidate

## Verifica si un Pokémon tiene movimientos físicos
static func has_physical_moves(pokemon) -> bool:

	if not pokemon.movimientos:
		return false

	for move in pokemon.movimientos:
		var move_data = move.get("datos", {})
		if move_data.get("categoria", "") == "físico":
			return true

	return false

## Verifica si un Pokémon tiene movimientos especiales
static func has_special_moves(pokemon) -> bool:

	if not pokemon.movimientos:
		return false

	for move in pokemon.movimientos:
		var move_data = move.get("datos", {})
		if move_data.get("categoria", "") == "especial":
			return true

	return false

## Verifica si el enemigo tiene movimientos especiales
static func enemy_has_special_moves(enemy_pokemon) -> bool:
	return has_special_moves(enemy_pokemon)

## Obtiene la categoría de un objeto
static func get_item_category(item_name: String) -> String:

	var item_data = get_item_data(item_name)
	if not item_data:
		return "unknown"

	var item_type = item_data.get("type", ItemType.HEALING)
	return ItemType.keys()[item_type].to_lower()

## Verifica si un objeto es de curación
static func is_healing_item(item_name: String) -> bool:
	return get_item_category(item_name) == "healing"

## Verifica si un objeto es de batalla
static func is_battle_item(item_name: String) -> bool:
	return get_item_category(item_name) == "battle_item"

## Calcula cuánto HP curaría un objeto
static func calculate_heal_value(item_name: String, pokemon) -> int:

	var item_data = get_item_data(item_name)
	if not item_data or item_data.get("type") != ItemType.HEALING:
		return 0

	var heal_amount = item_data.get("heal_amount", 0)
	var heal_ratio = item_data.get("heal_ratio", 0.0)

	if heal_ratio > 0:
		return int(pokemon.estad_ps * heal_ratio)
	else:
		return heal_amount

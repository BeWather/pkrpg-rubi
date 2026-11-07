extends RefCounted
class_name BattleFutureAttackQueue
## Ruby WishFutureKnock: target battler positions own counters, not actors.

class Event extends RefCounted:
	var target_position: int
	var attacker_position: int
	var move_id: int
	var base_damage: int
	var counter := 3
	var move: Movimiento
	var setup_actor: BasePokemon
	var _claimed := false
	func animation_key() -> String:
		return "ruby:general/18" if move_id == 248 else "ruby:general/19"
	func claim() -> bool:
		if _claimed: return false
		_claimed = true
		return true

var _events: Dictionary = {}

func schedule(target: int, attacker: int, id: int, damage: int, move: Movimiento = null, actor: BasePokemon = null) -> bool:
	if _events.has(target) or id not in [248,353]: return false
	var event := Event.new()
	event.target_position = target
	event.attacker_position = attacker
	event.move_id = id
	event.base_damage = damage
	event.move = Movimiento.new(move.nombre,0,0,0,move.datos.duplicate(true)) if move != null else null
	event.setup_actor = actor
	_events[target] = event
	return true

func advance(present_positions: Array) -> Array[Event]:
	var due: Array[Event] = []
	# Source battler order: player-left, opponent-left, player-right, opponent-right.
	for position in range(4):
		if not present_positions.has(position) or not _events.has(position): continue
		var event: Event = _events[position]
		event.counter -= 1
		if event.counter == 0:
			_events.erase(position) # Consume before presentation yields, including miss/KO.
			due.append(event)
	return due

func clear() -> void:
	_events.clear()

func size() -> int:
	return _events.size()

static func move_id(move: Movimiento) -> int:
	match move.get_nombre_interno().to_upper():
		"PREMONICION", "FUTURE_SIGHT": return 248
		"DESEOOCULTO", "DOOM_DESIRE": return 353
	return 0

static func base_damage(move: Movimiento, actor: BasePokemon, target: BasePokemon, actor_state: PokemonEnCombate, target_state: PokemonEnCombate, field: CampoCombate, descriptor: Dictionary={}) -> int:
	# CalculateBaseDamage only: no STAB, type multiplier, critical or random draw.
	var category := 2 if move_id(move) == 248 else 1
	if category==1 and preload("res://scripts/battle/held_damage_rules.gd").choice(descriptor):
		return preload("res://scripts/battle/source_damage_context.gd").physical_base(actor,target,actor_state,target_state,move.get_potencia(),descriptor)
	var attack_property: String="estad_ataque_especial" if category==2 else "estad_ataque"
	var defense_property: String="estad_defensa_especial" if category==2 else "estad_defensa"
	# Source snapshots raw BattlePokemon stats; existing held effects and stages
	# below must still run exactly once, not through final combat-stat getters.
	var attack: float=float(BattleTransformRules.stat(actor_state,attack_property,int(actor.get(attack_property))) if actor_state!=null else actor.get(attack_property))
	var defense: float=float(BattleTransformRules.stat(target_state,defense_property,int(target.get(defense_property))) if target_state!=null else target.get(defense_property))
	var actor_species: String=str(BattleTransformRules.data(actor).get("species",actor.nombre_interno))
	var target_species: String=str(BattleTransformRules.data(target).get("species",target.nombre_interno))
	var held := ObjetosLlevados.en_combate(actor)
	var target_held := ObjetosLlevados.en_combate(target)
	# These source-held effects are calculated NOW, never read again at impact.
	if category == 1 and (HabilidadesCombate.tiene(actor,HabilidadesCombate.POTENCIA) or HabilidadesCombate.tiene(actor,HabilidadesCombate.ENERGIAPURA)): attack *= 2
	if held == ("CUCHARATORCIDA" if category == 2 else "REVESTMETALICO"): attack = floorf(attack * 110 / 100)
	if category == 2 and held == "ROCIOBONDAD" and actor_species in ["LATIAS","LATIOS"]: attack = floorf(attack * 150 / 100)
	if category == 2 and target_held == "ROCIOBONDAD" and target_species in ["LATIAS","LATIOS"]: defense = floorf(defense * 150 / 100)
	if category == 2 and held == "DIENTEMARINO" and actor_species == "CLAMPERL": attack *= 2
	if category == 2 and target_held == "ESCAMAMARINA" and target_species == "CLAMPERL": defense *= 2
	if category == 2 and held == "BOLALUMINOSA" and actor_species == "PIKACHU": attack *= 2
	if category == 1 and target_held == "POLVOMETALICO" and target_species == "DITTO": defense *= 2
	if category == 1 and held == "HUESOGRUESO" and actor_species in ["CUBONE","MAROWAK"]: attack *= 2
	# Huge/Pure Power already ran before held effects in the Ruby source.
	if category == 1:
		if HabilidadesCombate.tiene(actor,HabilidadesCombate.ENTUSIASMO) or (HabilidadesCombate.tiene(actor,HabilidadesCombate.AGALLAS) and actor.estado != Singleton.ProblemaEstado.NORMAL): attack = floorf(attack * 150 / 100)
	elif field != null and ((HabilidadesCombate.tiene(actor,HabilidadesCombate.MAS) and field.hay_habilidad(HabilidadesCombate.MENOS)) or (HabilidadesCombate.tiene(actor,HabilidadesCombate.MENOS) and field.hay_habilidad(HabilidadesCombate.MAS))): attack = floorf(attack * 150 / 100)
	defense = HabilidadesCombate.defensa_modificada(target,category,defense)
	if actor_state != null: attack = actor_state.aplicar_modificador(int(attack),actor_state.mod_ataque_especial if category == 2 else actor_state.mod_ataque)
	if target_state != null: defense = target_state.aplicar_modificador(int(defense),target_state.mod_defensa_especial if category == 2 else target_state.mod_defensa)
	var damage: int = int(attack) * move.get_potencia() * (2 * actor.nivel / 5 + 2)
	damage /= maxi(1,int(defense))
	damage /= 50
	if category == 1 and actor.estado == Singleton.ProblemaEstado.QUEMADO and not HabilidadesCombate.tiene(actor,HabilidadesCombate.AGALLAS): damage /= 2
	return maxi(1,damage) + 2 if category == 1 else damage + 2

static func adjusted_damage(snapshot: int, random_word: int) -> int:
	return maxi(1,snapshot * (100 - (random_word % 16)) / 100) if snapshot != 0 else 0

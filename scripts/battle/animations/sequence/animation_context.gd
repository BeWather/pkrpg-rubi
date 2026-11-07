extends RefCounted
class_name BattleAnimationContext
const SourceCoordinates = preload("res://scripts/battle/animations/sequence/source_coordinate_contract.gd")
## Roles are resolved independently of screen position, species and movesets.

var field: Node2D
var actors: Dictionary = {}
var attacker_id: int = 0
var target_ids: Array[int] = [2]
var action_id: int = 0
var phase: String = "hit"
var variant: String = "release"
var move_turn: int = 0
var hit_index: int = 0
var seed_value: int = 0
var source_power: int = 0
var source_damage: int = 0
var environment: int = 9
var contest: bool = false
## Presentation identity sources stay separate from actor geometry and movesets.
var source_party_species: Dictionary = {}
var source_appearance_species: Dictionary = {}
## Optional front/back textures for the bound appearance, never party species.
## Unknown custom art falls back to the actor's actual selected texture.
var source_appearance_views: Dictionary = {}
## Transform's party buffer is not Role Play's appearance buffer.
var source_party_views: Dictionary = {}
## Optional explicit form frames for private restore-mode providers.
var source_form_views: Dictionary = {}
## Accepted presentation outcome only; never recomputes gameplay success.
var source_presentation_commit: bool = true
enum SourcePosition { PLAYER_LEFT = 0, OPPONENT_LEFT = 1, PLAYER_RIGHT = 2, OPPONENT_RIGHT = 3 }
## Explicit source-position provider; actor IDs are native field keys, not Ruby positions.
var source_positions: Dictionary = {}
## Optional actor-bound logical layout providers. Legacy anchors are unchanged.
var source_nominal: Dictionary = {}
## Opt-in pre-play BODY baseline; never aliases nominal/render-origin semantics.
var source_visual: Dictionary = {}
var field_size := Vector2(240, 112)

func snapshot_appearance_views(actor_id: int, shiny: bool=false) -> void:
	var appearance: String=str(source_appearance_species.get(actor_id,""))
	var views: Dictionary={}
	for view: String in ["front","back"]:
		var side: StringName=PosicionesBattlersJSON.LADO_ENEMIGO if view=="front" else PosicionesBattlersJSON.LADO_JUGADOR
		var path: String=LienzoBattlers.ruta_sprite(appearance,side,shiny)
		if ResourceLoader.exists(path):views[view]=load(path)
	source_appearance_views[actor_id]=views

func snapshot_party_views(actor_id: int, shiny: bool=false) -> void:
	var species: String=str(source_party_species.get(actor_id,""))
	var views: Dictionary={}
	for view: String in ["front","back"]:
		var side: StringName=PosicionesBattlersJSON.LADO_ENEMIGO if view=="front" else PosicionesBattlersJSON.LADO_JUGADOR
		var path: String=LienzoBattlers.ruta_sprite(species,side,shiny)
		if ResourceLoader.exists(path):views[view]=load(path)
	source_party_views[actor_id]=views

func presentation_variant() -> String:
	# Native explicit phases win; lab variants remain selectable without domain turns.
	return phase if phase in ["charge","release"] else variant

static func source_position_for_slot(position: int) -> int:
	match position:
		BattleSlot.Posicion.JUGADOR_IZQUIERDA:return SourcePosition.PLAYER_LEFT
		BattleSlot.Posicion.JUGADOR_DERECHA:return SourcePosition.PLAYER_RIGHT
		BattleSlot.Posicion.RIVAL_IZQUIERDA:return SourcePosition.OPPONENT_LEFT
		BattleSlot.Posicion.RIVAL_DERECHA:return SourcePosition.OPPONENT_RIGHT
	return -1

func source_position(actor_id: int) -> int:
	if source_positions.has(actor_id):return int(source_positions[actor_id])
	# Explicit standard lab/native slot provider, not an identity conversion.
	return source_position_for_slot(actor_id) if actor_id in [0,1,2,3] else -1

func resolve(selector: String) -> Array[BattleAnimationActor]:
	var ids: Array = []
	match selector:
		"attacker": ids = [attacker_id]
		"target": ids = target_ids.slice(0, 1)
		"targets": ids = target_ids
		"source_target_position_pair_body":
			# Opt-in196 coordinate2/3 pair. Native IDs are not source bank positions.
			ids=target_ids.slice(0,1)
			if not contest and not ids.is_empty() and actors.has(ids[0]):
				var target: BattleAnimationActor=actors[ids[0]]
				var position: int=source_position(target.id)
				if position in [0,1,2,3]:
					for candidate: BattleAnimationActor in actors.values():
						if candidate.id!=target.id and candidate.side==target.side and candidate.is_present() and source_position(candidate.id)==(position^2):
							ids.append(candidate.id)
							break # Source averaging does not test sprite visibility.
		"source_attacker_and_partner_visual_center", "source_target_and_partner_visual_center":
			# Source SetAverageBattlerPositions targets the visual same-side pair,
			# not the action's damage recipients. Missing single-battle partners
			# leave the selected target as the sole center operand.
			ids = [attacker_id] if selector=="source_attacker_and_partner_visual_center" else target_ids.slice(0, 1)
			if not ids.is_empty() and actors.has(ids[0]):
				var partner_id := _partner(int(ids[0]))
				if actors.has(partner_id):
					var partner: BattleAnimationActor = actors[partner_id]
					if partner.side == actors[ids[0]].side and partner.is_present() and partner.sprite.is_visible_in_tree():
						ids.append(partner_id)
		"attacker_partner": ids = [_partner(attacker_id)]
		"target_partner": ids = [_partner(target_ids[0])] if not target_ids.is_empty() else []
		"attacker_side":
			if actors.has(attacker_id):
				for actor_id in actors:
					if actors[actor_id].side == actors[attacker_id].side:
						ids.append(actor_id)
		"all": ids = actors.keys()
		"except_attacker", "except_target", "except_attacker_and_target", "except_attacker_partner", "except_target_partner":
			var excluded: Array = []
			if selector in ["except_attacker", "except_attacker_and_target"]: excluded.append(attacker_id)
			if selector in ["except_target", "except_attacker_and_target"]: excluded.append_array(target_ids.slice(0, 1))
			if selector == "except_attacker_partner": excluded.append(_partner(attacker_id))
			if selector == "except_target_partner" and not target_ids.is_empty(): excluded.append(_partner(target_ids[0]))
			for actor_id in actors:
				if actor_id not in excluded: ids.append(actor_id)
		_:
			if selector.begins_with("actor:"):
				ids = [int(selector.trim_prefix("actor:"))]
	var result: Array[BattleAnimationActor] = []
	for actor_id in ids:
		if actors.has(actor_id) and actors[actor_id].is_present():
			result.append(actors[actor_id])
	return result

## @deprecated: camino de la VM legada; las animaciones nativas no lo usan. Se conserva como referencia y fallback de configuración. Ver scripts/battle/animations/sequence/README.md.
func source_position_pair_body_center() -> Dictionary:
	if resolve("target").is_empty():return {"state":"invalid"}
	var selected: Array[BattleAnimationActor]=resolve("source_target_position_pair_body")
	if selected.is_empty():return {"state":"invalid"}
	var value: Vector2=Vector2.ZERO
	var count: int=0
	for actor: BattleAnimationActor in selected:
		var body: Dictionary=SourceCoordinates.visual(actor,self)
		if str(body.state)=="invalid":
			if count==0:return {"state":"invalid"}
			continue # Unavailable partner coordinates project to the target only.
		# BODY is the native coordinate2/3 projection, independent of nominal/ART.
		# Missing optional metadata preserves the established lab/layout fallback.
		var point: Vector2=body.point if str(body.state)=="valid" else BattleElectricContract.source_anchor(actor,self)
		value+=Vector2(int(point.x),int(point.y))
		count+=1
	return {"state":"valid","point":Vector2(int(value.x/count),int(value.y/count))}

func _partner(actor_id: int) -> int:
	# Godot BattleSlot enum is player-left/right, opponent-left/right.
	return actor_id + 1 if actor_id % 2 == 0 else actor_id - 1

static func from_legacy(legacy: MoveAnimationContext) -> BattleAnimationContext:
	var context := BattleAnimationContext.new()
	context.action_id = legacy.action_id
	context.phase = legacy.phase
	context.variant = "charge" if legacy.phase == "charge" else "release"
	context.move_turn = legacy.source_move_turn
	context.hit_index = legacy.source_hit_index
	context.source_power = legacy.source_power
	for property: String in legacy.source_counter_inputs:context.set_meta(property,legacy.source_counter_inputs[property])
	context.source_damage = legacy.source_damage
	for property in legacy.batalla.get_property_list():
		if str(property.name)=="datos_batalla":
			var battle_data: Dictionary = legacy.batalla.get("datos_batalla")
			# Ruby environment dispatch is presentation metadata from the real field.
			var theme := int(battle_data.get("tema_grafico",0))
			context.environment = {1:0,2:1,3:2,4:4,5:4,6:3,7:5,8:6,9:7,10:7,11:8,12:8,13:8}.get(theme,9)
			break
	context.field = legacy.batalla.get_node_or_null("Campo") as Node2D
	if context.field == null:
		context.field = legacy.batalla as Node2D
	var slots: Array[BattleSlot] = [legacy.slot_atacante, legacy.slot_defensor]
	var shadow_profiles: Dictionary={}
	for node in context.field.find_children("*", "", true, false):
		if node is BattleSlot and node not in slots:
			slots.append(node)
	for battle_slot in slots:
		if not is_instance_valid(battle_slot) or not is_instance_valid(battle_slot.sprite_pokemon):
			continue
		var target_lease: Dictionary=legacy.source_counter_inputs.get("source_forced_target_lease",{})
		var owned_target: bool=not target_lease.is_empty() and legacy.batalla.field_rules.valid(target_lease) and target_lease.slot.get_ref()==battle_slot
		var hidden: BattleHiddenProjection=BattleHiddenProjection.for_slot(legacy.batalla,battle_slot) if battle_slot==legacy.slot_atacante or owned_target else null
		if not battle_slot.visible or (not battle_slot.sprite_pokemon.visible and hidden==null):
			continue
		var actor_id := int(battle_slot.posicion_batalla)
		context.actors[actor_id] = BattleAnimationActor.new(actor_id, 0 if battle_slot.es_jugador else 1, battle_slot.sprite_pokemon, battle_slot)
		if battle_slot==legacy.slot_atacante or owned_target:
			var state: PokemonEnCombate=legacy.batalla._obtener_combatiente(legacy.batalla._pokemon_de_slot(battle_slot)) if legacy.batalla.has_method("_obtener_combatiente") and legacy.batalla.has_method("_pokemon_de_slot") else null
			if state!=null and state.hidden_projection!=null:state.hidden_projection.bind_actor(context.actors[actor_id])
		context.source_positions[actor_id] = source_position_for_slot(battle_slot.posicion_batalla)
		context.source_nominal[actor_id] = SourceCoordinates.bind(context.actors[actor_id], context.field, battle_slot, BattleLayout.SOURCE_NOMINAL_CANVAS_REFERENCE)
		context.source_visual[actor_id] = SourceCoordinates.bind_visual(context.actors[actor_id], context.field, battle_slot, battle_slot.sprite_pokemon.position + BattleLayout.SOURCE_NOMINAL_CANVAS_REFERENCE)
		if legacy.batalla.has_method("_pokemon_de_slot"):
			var party_pokemon: BasePokemon = legacy.batalla.call("_pokemon_de_slot",battle_slot)
			if party_pokemon != null:
				context.source_party_species[actor_id] = party_pokemon.nombre_interno
				var hp_inputs: Dictionary=context.get_meta("source_hp_inputs",{});hp_inputs[actor_id]=[party_pokemon.estad_ps_actual,party_pokemon.estad_ps];context.set_meta("source_hp_inputs",hp_inputs)
			if party_pokemon!=null and legacy.batalla.has_method("obtener_sombra_pokemon"):
				shadow_profiles[party_pokemon.nombre_interno]=bool(legacy.batalla.call("obtener_sombra_pokemon",party_pokemon.nombre_interno))
		context.source_appearance_species[actor_id] = BattleOwnedAppearanceLease.appearance_species(battle_slot.sprite_pokemon,battle_slot.animation_generation)
		context.snapshot_appearance_views(actor_id,"-shiny/" in battle_slot.sprite_pokemon.texture.resource_path)
		context.snapshot_party_views(actor_id,"-shiny/" in battle_slot.sprite_pokemon.texture.resource_path)
	context.set_meta("source_shadow_profiles",shadow_profiles)
	if is_instance_valid(legacy.slot_atacante):
		context.attacker_id = int(legacy.slot_atacante.posicion_batalla)
	context.target_ids.clear()
	var targets: Array[BattleSlot] = legacy.target_slots.duplicate()
	if targets.is_empty() and is_instance_valid(legacy.slot_defensor):
		targets.append(legacy.slot_defensor)
	for target in targets:
		if is_instance_valid(target) and int(target.posicion_batalla) not in context.target_ids:
			context.target_ids.append(int(target.posicion_batalla))
	return context

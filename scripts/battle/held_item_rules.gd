extends RefCounted
class_name BattleHeldItemRules
## Knock Off suppresses battle ownership for the party member, not saved inventory.
static var _knocked: Dictionary={}
static func held(pokemon: BasePokemon) -> String:
	if pokemon==null:return ""
	if _knocked.has(pokemon.get_instance_id()):
		var record: Dictionary=_knocked[pokemon.get_instance_id()];var owner: Node=record.owner.get_ref()
		if owner!=null and owner.is_inside_tree() and owner.fase!=owner.FIN_BATALLA and record.pokemon.get_ref()==pokemon:return ""
		_knocked.erase(pokemon.get_instance_id())
	return pokemon.objeto.strip_edges().to_upper()
static func clear(battle: Node) -> void:
	for id: int in _knocked.keys():
		if _knocked[id].owner.get_ref()==battle:_knocked.erase(id)
static func knock_off(battle: Node,target: BasePokemon) -> bool:
	if held(target).is_empty() or HabilidadesCombate.evita_robo_objeto(target):return false
	preload("res://scripts/battle/choice_band_rules.gd").clear_state(battle._obtener_combatiente(target))
	_knocked[target.get_instance_id()]={"owner":weakref(battle),"pokemon":weakref(target)};return true
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0)) in [168,282]
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true);var thief: bool=int(data.numero_movimiento)==168
	data.tipo="SINIESTRO";data.categoria_dano_id=2;data.potencia=40 if thief else 20;data.precision=100;data.max_pp=10 if thief else 20;data.pp=data.max_pp;data.objetivo_id=10;data.prioridad=0;data.contacto=1;data.prob_secundario=100;data.efecto="EFFECT_THIEF" if thief else "EFFECT_KNOCK_OFF"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_held_item"):return move
	var fact: Dictionary=phase.source_held_item
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
static func present(battle: Node,receiver: BasePokemon,donor: BasePokemon,phase: int) -> void:
	var actor_guard: Dictionary=battle.field_rules.capture(receiver);var target_guard: Dictionary=battle.field_rules.capture(donor)
	if actor_guard.is_empty() or target_guard.is_empty():return
	if phase==5 and not knock_off(battle,donor):return
	# Transfer16 was already committed ONCE by EfectosGolpe._robar; art never steals.
	var context:=BattleAnimationContext.from_legacy(MoveAnimationContext.nueva(battle,battle.hud._obtener_slot_de_pokemon(receiver),battle.hud._obtener_slot_de_pokemon(donor)))
	context.phase="item";context.set_meta("source_item_receiver_id",context.attacker_id);context.set_meta("source_item_donor_id",context.target_ids[0])
	var animation:=BattleAnimationDirector.play_key("ruby:general/%d"%phase,context,true);await animation.esperar_finalizada()
	if not battle.field_rules.valid(actor_guard) or not battle.field_rules.valid(target_guard):return
	if phase==5:await battle.mostrar_texto_batalla("¡%s perdió el uso de su objeto!"%donor.get_nombre_combate())

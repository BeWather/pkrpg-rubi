extends RefCounted
class_name BattleHealingStreamRules
## Gen3 Wish belongs to a bank; Ingrain belongs to the active rooted combatant.
var _owner: WeakRef
var wishes: Dictionary={}
func _init(battle: Node) -> void:_owner=weakref(battle)
func clear() -> void:wishes.clear()
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0)) in [273,275]
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true);var wish: bool=int(data.numero_movimiento)==273
	data.tipo="NORMAL" if wish else "PLANTA";data.categoria_dano_id=3;data.potencia=0;data.precision=100;data.max_pp=10 if wish else 20;data.pp=data.max_pp;data.objetivo_id=7;data.prioridad=0;data.contacto=0;data.prob_secundario=0;data.efecto="EFFECT_WISH" if wish else "EFFECT_INGRAIN"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_healing_stream"):return move
	var fact: Dictionary=phase.source_healing_stream
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
func produce(actor: BasePokemon,wish: bool) -> bool:
	var battle: Node=_owner.get_ref()
	if wish:
		var position: Dictionary=battle.turno._posicion_pokemon(actor)
		var bank: int=int(position.flank)*2+(0 if bool(position.player) else 1)
		if wishes.has(bank):return false
		wishes[bank]={"turns":2,"name":actor.get_nombre_combate()};return true
	var state: PokemonEnCombate=battle._obtener_combatiente(actor)
	if state.source_ingrain_rooted:return false
	state.source_ingrain_rooted=true;return true
func _heal(actor: BasePokemon,phase: int,amount: int) -> bool:
	var battle: Node=_owner.get_ref();var flow: Dictionary=battle.field_rules.capture_flow();var record: Dictionary=battle.field_rules.capture(actor)
	if record.is_empty():return false
	var slot: BattleSlot=battle.hud._obtener_slot_de_pokemon(actor)
	var context:=BattleAnimationContext.from_legacy(MoveAnimationContext.nueva(battle,slot,slot));context.phase="healing"
	var animation:=BattleAnimationDirector.play_key("ruby:general/%d"%phase,context,true);await animation.esperar_finalizada()
	if not battle.field_rules.valid_flow(flow) or not battle.field_rules.valid(record):return false
	await battle.field_rules.passive_hp(record,-amount)
	return battle.field_rules.valid_flow(flow)
func wish_end_round() -> bool:
	var battle: Node=_owner.get_ref();var order: Array[int]=[]
	for entry: Dictionary in battle.turno.get_meta("source_protect_projection",[]):
		if int(entry.bank) not in order:order.append(int(entry.bank))
	for bank: int in range(4):
		if bank not in order:order.append(bank)
	for bank: int in order:
		if not wishes.has(bank):continue
		wishes[bank].turns=int(wishes[bank].turns)-1
		if int(wishes[bank].turns)>0:continue
		wishes.erase(bank)
		var receiver: BasePokemon=battle.turno._future_occupant(bank)
		if receiver==null or receiver.estad_ps_actual<=0 or receiver.estad_ps_actual>=receiver.estad_ps:continue
		# Source trywish(1) reads the RECEIVER maxHP at due time, not caster HP.
		if not await _heal(receiver,22,maxi(1,int(receiver.estad_ps/2))):return false
	return true
func ingrain(actor: BasePokemon) -> bool:
	var battle: Node=_owner.get_ref();var state: PokemonEnCombate=battle._obtener_combatiente(actor)
	if state==null or not state.source_ingrain_rooted or actor.estad_ps_actual<=0 or actor.estad_ps_actual>=actor.estad_ps:return true
	return await _heal(actor,21,maxi(1,int(actor.estad_ps/16)))

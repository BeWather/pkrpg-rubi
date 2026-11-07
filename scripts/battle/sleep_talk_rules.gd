extends RefCounted
## Ruby atkA9: four current combat slots; ignore called PP, not source restrictions.
const FORBIDDEN: Array[int]=[0,214,274,119,118,264,253,13,19,76,91,117,130,143,291,340]
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==214
## atkcanceller case1: solo RONQUIDO y SONÁMBULO se usan dormido.
static func usable_asleep(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0)) in [173,214]
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true);data.categoria_dano_id=3;data.potencia=0;data.tipo="NORMAL";data.precision=0;data.max_pp=10;data.pp=10;data.contacto=0;data.objetivo_id=1;data.source_target_mask=16;data.prioridad=0;data.prob_secundario=0;data.efecto="EFFECT_SLEEP_TALK"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_sleep_talk"):return move
	var fact: Dictionary=phase.source_sleep_talk
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
static func select_slot(battle: Node,actor: BasePokemon,draw: Callable) -> Movimiento:
	var slots: Array[Movimiento]=BattleTransformRules.moves(actor).slice(0,4);var allowed: Array[int]=[]
	for index: int in slots.size():
		var move: Movimiento=slots[index]
		if move==null or int(move.datos.get("numero_movimiento",0)) in FORBIDDEN:continue
		# CheckMoveLimitations0xFD excludes ONLY the PP flag; a 0PP slot is legal.
		if preload("res://scripts/battle/move_availability_rules.gd").blocked(battle,actor,move,253):continue
		allowed.append(index)
	if allowed.is_empty():return null
	while true:
		var index: int=int(draw.call())&3
		if index in allowed:return slots[index]
	return null

## Ruby TARGET_SPECIAL initial bank prices selected214 BEFORE choosing its call.
static func pp_target(battle: Node,actor: BasePokemon) -> BasePokemon:
	var position: Dictionary=battle.field_rules.position(actor)
	if position.is_empty():return null
	var bank: int=1 if bool(position.player) else 0
	var target: BasePokemon=battle.turno._future_occupant(bank)
	if (target==null or target.estad_ps_actual<=0) and battle.formato_batalla==Singleton.FormatoBatalla.DOBLE:target=battle.turno._future_occupant(bank+2)
	return target if target!=null and target.estad_ps_actual>0 else null

extends RefCounted
## Ruby resultmessage/HangedOnMsg only; confusion deliberately has no caller.
const Rules=preload("res://scripts/battle/attack_survival_rules.gd")
static func settle(battle: Node,receipt: Dictionary) -> bool:
	if receipt.is_empty() or bool(receipt.presented):return true
	receipt.presented=true
	if not bool(receipt.get("endured",false)) and not bool(receipt.get("hung_on",false)):return true
	if not bool(receipt.get("committed",false)) or not Rules.valid(battle,receipt):return false
	var pokemon: BasePokemon=receipt.pokemon
	if bool(receipt.endured):
		await battle.mostrar_texto_batalla("¡%s aguantó con 1 PS!"%pokemon.get_nombre_combate())
	elif bool(receipt.hung_on):
		var slot: BattleSlot=receipt.lease.slot.get_ref()
		var context:=BattleAnimationContext.from_legacy(MoveAnimationContext.nueva(battle,slot,slot));context.phase="item"
		var animation:=BattleAnimationDirector.play_key("ruby:general/9",context,true)
		await animation.esperar_finalizada()
		if not Rules.valid(battle,receipt):return false
		await battle.mostrar_texto_batalla("¡%s resistió usando su %s!"%[pokemon.get_nombre_combate(),ObjetosLlevados.nombre_objeto(str(receipt.item))])
	return Rules.valid(battle,receipt)

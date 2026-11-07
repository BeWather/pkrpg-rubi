extends RefCounted
class_name BattleStockpileRules
## Ruby atk85/86/87 domain authority. Animation consumes an action snapshot,
## never the already-reset volatile counter or a laboratory turn override.

static func accept(state: PokemonEnCombate, action: BattleMoveAction, effect: String, protected: bool=false) -> Dictionary:
	if not action.stockpile_resolution.is_empty():return action.stockpile_resolution
	var result: Dictionary={"accepted":false,"count":0,"heal":0,"effect":effect}
	action.stockpile_resolution=result
	if state==null:return result
	var count: int=state.stockpile_count
	if effect=="EFFECT_STOCKPILE":
		if count<3:
			state.stockpile_count=count+1;result.count=count+1;result.accepted=true
		return result # atk85 does not modify animTurn or defensive stages.
	if count<=0:return result
	result.count=count
	if effect=="EFFECT_SWALLOW":
		if state.pokemon_base.estad_ps_actual>=state.pokemon_base.estad_ps:
			state.stockpile_count=0
			return result # Full-HP failure still consumes the accumulated count.
		result.heal=maxi(1,state.pokemon_base.estad_ps/(1<<(3-count)))
	# atk86/87 write the presentation operand BEFORE consuming the counter.
	if not protected:action.move_turn=count
	state.stockpile_count=0
	result.accepted=not protected
	return result

static func retire(state: PokemonEnCombate) -> void:
	if state!=null:state.stockpile_count=0

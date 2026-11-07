extends RefCounted
class_name BattleHiddenActorRules
## Original-bank continuation authority; source policy never owns party PP.
const POWERS={19:70,91:60,291:60,340:85}
var _owner: WeakRef
var _record: Dictionary
var _lifetime: int
var _moves: Array
var _index: int
var _original: Movimiento
var _name: String
var _data: PackedByteArray
var _id: int

static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0)) in POWERS

static func capture(battle: BattleSceneController,actor: BasePokemon,move: Movimiento) -> BattleHiddenActorRules:
	if not supports(move):return null
	var lease:=BattleHiddenActorRules.new()
	lease._owner=weakref(battle);lease._record=battle.field_rules.capture(actor)
	lease._lifetime=battle.field_rules._lifetime;lease._original=move
	var state: PokemonEnCombate=battle._obtener_combatiente(actor)
	lease._moves=state.get_movimientos();lease._index=lease._moves.find(move)
	lease._name=move.nombre;lease._id=int(move.datos.numero_movimiento)
	var data: Dictionary=move.datos.duplicate(true)
	data.potencia=int(POWERS[lease._id]);data.categoria_dano_id=2 if lease._id==291 else 1
	data.tipo="TIERRA" if lease._id==91 else "AGUA" if lease._id==291 else "VOLADOR"
	data.efecto="EFFECT_FLY";data.precision={19:95,91:100,291:100,340:85}[lease._id]
	data.prob_secundario=30 if lease._id==340 else 0
	if lease._id==91:data.max_pp=10;data.pp=10;data.contacto=1;data.objetivo_id=10;data.prioridad=0
	lease._data=var_to_bytes(data)
	return lease

func live() -> bool:
	var battle: BattleSceneController=_owner.get_ref()
	if not is_instance_valid(battle) or battle.field_rules._lifetime!=_lifetime or not battle.field_rules.valid(_record):return false
	var state: PokemonEnCombate=_record.state.get_ref()
	var moves: Array=state.get_movimientos()
	return is_same(moves,_moves) and _index>=0 and _index<moves.size() and moves[_index]==_original

func policy() -> Movimiento:
	return Movimiento.new(_name,_original.pp_act,_original.pp_mas,_original.pp_tot,bytes_to_var(_data))
func original() -> Movimiento:return _original
func source_id() -> int:return _id
func prepare_round_retirement(state: PokemonEnCombate) -> void:
	# Only this validated original round cleanup owns exactly one epoch advance.
	if live() and _record.state.get_ref()==state:_record.epoch=state.body_attack_epoch+1
func complete_owned_contact_ko(record: Dictionary) -> void:
	# The caller already verified the whole accepted contact flow. Adopt only
	# its one original-body retirement, never a replacement or later epoch.
	var battle: BattleSceneController=_owner.get_ref()
	if not is_instance_valid(battle) or battle.field_rules._lifetime!=_lifetime:return
	if record.get("pokemon")!=_record.get("pokemon") or record.state.get_ref()!=_record.state.get_ref():return
	if record.pokemon.estad_ps_actual!=0 or int(record.epoch)!=int(_record.epoch)+1:return
	var advanced: Dictionary=_record.duplicate(true);advanced.epoch=int(record.epoch)
	if not battle.field_rules.valid(advanced):return
	var moves: Array=record.state.get_ref().get_movimientos()
	if not is_same(moves,_moves) or _index<0 or _index>=moves.size() or moves[_index]!=_original:return
	_record.epoch=advanced.epoch
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	var lease: BattleHiddenActorRules=phase.get("source_i4")
	return lease.policy() if lease!=null else move

func original_state() -> PokemonEnCombate:return _record.state.get_ref()
func original_slot() -> BattleSlot:return _record.slot.get_ref()

static func facts(action: BattleMoveAction) -> BattleHiddenActorRules:
	return action.get_meta("source_screen_phase_guard",{}).get("source_i4")

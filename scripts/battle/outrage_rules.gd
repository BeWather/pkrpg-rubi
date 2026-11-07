extends RefCounted
## Ruby Outrage uses Dragon SPECIAL90 and source user-held lock/confusion.
static func supports(move: Movimiento) -> bool:
	return move!=null and int(move.datos.get("numero_movimiento",0))==200
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true)
	data.categoria_dano_id=2;data.potencia=90;data.tipo="DRAGON";data.precision=100;data.max_pp=15;data.pp=15;data.objetivo_id=8;data.contacto=1;data.prob_secundario=100;data.efecto="EFFECT_RAMPAGE"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_outrage"):return move
	# A valid rampage lock already owns the immutable accepted policy and PP.
	# Preserve its identity: the shared consumer exempts that exact object.
	var owner: Node=phase.owner.get_ref() if phase.has("owner") else null
	var actor: BasePokemon=phase.get("actor",{}).get("pokemon",null)
	if owner!=null and actor!=null and BattleRampageRules.move(owner,actor)==move:return move
	var fact: Dictionary=phase.source_outrage
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

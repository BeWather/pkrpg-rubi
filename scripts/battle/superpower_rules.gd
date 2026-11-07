extends RefCounted
## Source admission only: certain user Attack/Defense drops follow committed damage.
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==276
static func capture(move: Movimiento) -> Dictionary:
	var d: Dictionary=move.datos.duplicate(true);d.tipo="LUCHA";d.categoria_dano_id=1;d.potencia=120;d.precision=100;d.max_pp=5;d.pp=5;d.contacto=1;d.objetivo_id=10;d.prioridad=0;d.prob_secundario=0;d.efecto="EFFECT_SUPERPOWER"
	return {"name":move.nombre,"data":d}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_superpower"):return move
	var fact: Dictionary=phase.source_superpower
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))

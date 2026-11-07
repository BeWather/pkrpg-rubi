extends RefCounted
## Ruby Assist scans raw same-side party slots; PP/HP are not donor restrictions.
const FORBIDDEN: Array[int]=[0,118,165,166,102,68,243,182,197,203,194,214,168,266,289,270,343,271,264,274,119]
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==274
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true);data.categoria_dano_id=3;data.potencia=0;data.tipo="NORMAL";data.precision=100;data.max_pp=20;data.pp=20;data.contacto=0;data.objetivo_id=1;data.source_target_mask=16;data.prioridad=0;data.prob_secundario=0;data.efecto="EFFECT_ASSIST"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_assist"):return move
	# Payment is after the own animation. Admission and the queued resolver must
	# therefore share exactly this accepted owner, never another policy clone.
	if phase.has("source_assist_admitted"):return phase.source_assist_admitted
	var fact: Dictionary=phase.source_assist
	var accepted:=Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true));phase.source_assist_admitted=accepted;return accepted
static func select_id(battle: Node,actor: BasePokemon,draw: Callable) -> int:
	var position: Dictionary=battle.field_rules.position(actor)
	var party: Array[BasePokemon]=battle.equipo_jugador_pokemones if bool(position.player) else battle.equipo_enemigo_pokemones
	var pool: Array[int]=[]
	for member: BasePokemon in party.slice(0,6):
		if member==null or member==actor or member.nombre_interno.is_empty() or member.huevo:continue
		for move: Movimiento in member.movimientos.slice(0,4):
			var id: int=int(move.datos.get("numero_movimiento",0)) if move!=null else 0
			if id>0 and id<=354 and id not in FORBIDDEN:pool.append(id)
	if pool.is_empty():return 0
	return pool[((int(draw.call())&255)*pool.size())>>8]

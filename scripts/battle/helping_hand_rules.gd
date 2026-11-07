extends RefCounted
## Ruby partner-held ProtectStruct flag: current round only, never a party mutation.
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==270
static func capture(move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true);data.potencia=0;data.precision=100;data.tipo="NORMAL";data.categoria_dano_id=3;data.max_pp=20;data.pp=20;data.contacto=0;data.objetivo_id=7;data.source_target_mask=2;data.prioridad=5;data.prob_secundario=0;data.efecto="EFFECT_HELPING_HAND"
	return {"name":move.nombre,"data":data}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_helping_hand"):return move
	if phase.has("source_helping_hand_admitted"):return phase.source_helping_hand_admitted
	var fact: Dictionary=phase.source_helping_hand;var accepted:=Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true));phase.source_helping_hand_admitted=accepted;return accepted
static func produce(battle: Node,actor: BasePokemon) -> BasePokemon:
	if battle.formato_batalla!=Singleton.FormatoBatalla.DOBLE:return null
	var position: Dictionary=battle.field_rules.position(actor)
	if position.is_empty():return null
	var state: PokemonEnCombate=battle._obtener_combatiente(actor)
	if state==null or state.source_helping_hand:return null
	var partners: Array[BasePokemon]=battle.pokemones_activos_jugador if bool(position.player) else battle.pokemones_activos_enemigo
	var index: int=int(position.flank)^1
	if index>=partners.size():return null
	var partner: BasePokemon=partners[index]
	if partner==null or partner.estad_ps_actual<=0:return null
	var other: PokemonEnCombate=battle._obtener_combatiente(partner)
	if other==null or other.source_helping_hand:return null
	other.source_helping_hand=true;return partner

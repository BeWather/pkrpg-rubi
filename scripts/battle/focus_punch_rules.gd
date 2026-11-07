extends RefCounted
## Before-turn announcement is not a charge/lock or a PP-consuming move action.
const KEY="source_focus_setup_round"
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==264
static func capture(move: Movimiento) -> Dictionary:
	var d: Dictionary=move.datos.duplicate(true);d.potencia=150;d.precision=100;d.tipo="LUCHA";d.categoria_dano_id=1;d.max_pp=20;d.pp=20;d.contacto=1;d.objetivo_id=10;d.prioridad=-3;d.prob_secundario=0;d.efecto="EFFECT_FOCUS_PUNCH"
	return {"name":move.nombre,"data":d}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_focus_punch"):return move
	if phase.has("source_focus_admitted"):return phase.source_focus_admitted
	var fact: Dictionary=phase.source_focus_punch;var admitted:=Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true));phase.source_focus_admitted=admitted;return admitted
static func interrupted(state: PokemonEnCombate) -> bool:
	return state!=null and state.has_body_damage()

static func failed(battle: Node,actor: BasePokemon,move: Movimiento) -> bool:return supports(move) and interrupted(battle._obtener_combatiente(actor))
static func prepare(battle: Node,actions: Array) -> bool:
	# Ruby CheckFocusPunch scans battler banks, independently of action priority.
	for bank: int in range(4 if battle.formato_batalla==Singleton.FormatoBatalla.DOBLE else 2):
		for action: Dictionary in actions:
			var actor: BasePokemon=action.get("actor");var move: Movimiento=action.get("movimiento")
			if actor==null or actor.estad_ps_actual<=0 or not supports(move):continue
			if battle.field_rules.source_bank(battle.field_rules.position(actor))!=bank:continue
			var state: PokemonEnCombate=battle._obtener_combatiente(actor)
			if state==null or actor.estado==Singleton.ProblemaEstado.DORMIDO or HabilidadesCombate.holgazanea(actor,state) or not move.tiene_pp():continue
			if int(state.get_meta(KEY,-1))==int(battle.contador_turnos):continue
			var guard: Dictionary=battle.field_rules.capture(actor)
			if guard.is_empty():return false
			state.set_meta(KEY,int(battle.contador_turnos))
			var context:=BattleAnimationContext.from_legacy(MoveAnimationContext.nueva(battle,guard.slot.get_ref(),guard.slot.get_ref()))
			var animation:=BattleAnimationDirector.play_key("ruby:general/20",context,true);await animation.esperar_finalizada()
			if animation.state!="completed" or not battle.field_rules.valid(guard):return false
			await battle.mostrar_texto_batalla("¡%s está reuniendo su concentración!"%actor.get_nombre_combate())
			if not battle.field_rules.valid(guard):return false
	return true

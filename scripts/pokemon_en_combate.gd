extends RefCounted
class_name PokemonEnCombate

# Referencia a la instancia original del Pokémon
var pokemon_base: BasePokemon

# Modificadores de estadísticas en combate (van de -6 a +6)
var mod_ataque: int = 0
var mod_defensa: int = 0
var mod_ataque_especial: int = 0
var mod_defensa_especial: int = 0
var mod_velocidad: int = 0
## Imprison belongs to the current holder; shared moves are queried live.
var source_taunt_turns: int=0
## Source Encore retains the current party/transform slot and independent 3–6 turn timer.
var source_tormented: bool=false
var source_encore_move: int=0
var source_encore_slot: int=-1
var source_encore_turns: int=0
var source_disabled_move: int=0
var source_disable_turns: int=0
var source_disable_start_turns: int=0
var source_helping_hand: bool=false
var source_follow_me: bool=false
var source_imprison_active: bool = false
## Target-held recurring status2 effects, separate from primary sleep status.
var source_cursed: bool = false
var source_nightmare: bool = false
var source_perish_song: bool = false
var source_perish_count: int = 0
var source_focus_energy: bool = false
var source_ingrain_rooted: bool = false
## Target-held source relation; weak combatant identity does not survive replacement.
var source_identified: bool = false
var source_sure_hit_turns: int = 0
var source_sure_hit_attacker: WeakRef

var mod_precision: int = 0
var mod_evasion: int = 0

# Estados volátiles (solo duran en batalla)
var esta_confuso: bool = false
var turnos_confuso: int = 0

var protegido_este_turno: bool = false
var aguante_este_turno: bool = false
var turnos_bostezo: int = 0
# status1 vive en el equipo: el sueño y el Tóxico sobreviven al cambio (ver BasePokemon).
var turnos_dormido: int = 0:
	set(valor):
		turnos_dormido = valor
		if pokemon_base != null: pokemon_base.turnos_sueno_guardados = maxi(valor, 0)
var envenenamiento_grave: bool = false:
	set(valor):
		envenenamiento_grave = valor
		if pokemon_base != null: pokemon_base.veneno_grave_guardado = valor
var contador_veneno_grave: int = 0
var factor_proteccion: int = 1
var uso_proteccion_exitoso_este_turno: bool = false
## Independent Ruby producer state; legacy protection characterization stays intact.
var source_last_taken_move: int=0 # Ruby incoming mirror-compatible CHOSEN move.
var source_last_taken_from: Dictionary={} # Source attacker bank/2, cleared by fresh bank state.
var source_last_printed_move: int=0 # Separate Ruby gLastPrintedMoves, used by permanent Sketch.
var source_last_landed_move: int=0 # Ruby gLastLandedMoves, separate from chosen history.
var source_last_hit_type: String=""
var source_last_hit_by: Dictionary={} # Ruby gLastHitBy: banco del último atacante; vacío = 0xFF.
var source_last_hit_by_pokemon: BasePokemon=null # gBattleMons conserva su ficha si el banco queda vacío.
var source_charge_turns: int = 0
var source_destiny_bond: bool = false
var source_rage: bool = false
var source_grudge: bool = false
var source_last_chosen_move: int = 0 # Ruby gLastMoves; distinct from printed/resulting history.
var source_last_result_move: int = 0
var source_protect_uses: int = 0

var esta_enamorado: bool = false
var target_enamorado = null # Referencia al Pokémon que le enamoró

var esta_atrapado: bool = false # Atadura, Tenaza, etc.
var turnos_atrapado: int = 0
## Source receiver bank, resolved at each accepted residual tick.
var leech_seed_position: Dictionary={}

# Otros estados y contadores de batalla
var turnos_en_campo: int = 0
var ultimo_movimiento_usado = null
var ha_recibido_danio_este_turno: bool = false

# Estado de habilidades (ver HabilidadesCombate)
## Rondas completas que lleva en el campo (IMPULSO no actúa la primera).
var rondas_en_campo: int = 0
## Entró con la ronda en marcha (cambio o RELEVO): isFirstTurn sigue activo en la
## selección siguiente, con una ronda ya contada.
var entro_a_mitad_de_ronda: bool = false
## Ruby STATUS2_RECHARGE/rechargeCounter, independent of charge/rampage locks.
var source_recharge_turns: int=0
## AUSENTE: true cuando le toca holgazanear este turno (truantCounter).
var holgazaneando: bool = false
## ABSORBE FUEGO: ya absorbió un ataque de fuego y potencia los suyos ×1.5.
var absorbe_fuego: bool = false
## Retroceso: un ataque con efecto de retroceso le impide actuar este turno.
var retrocede: bool = false
var semi_invulnerable := ""
var hidden_projection: BattleHiddenProjection
var pending_move: PendingMoveContinuation
## Generation3 Substitute barrier authority, independent of sprite presentation.
var substitute_hp: int=0
## Generation3 Stockpile counter; actor-local volatile domain state.
var stockpile_count: int=0
var rampage_turns: int=0
var rampage_move: Movimiento
var rampage_guard: Dictionary={}
var rampage_last_round: int=-1
var fury_cutter_count: int=0
var roll_turns: int=0
var roll_move: Movimiento
var roll_guard: Dictionary={}
var roll_target: Dictionary={}
## ProtectStruct physical/special records; Bide requested damage is separate.
var _body_attack_owner: WeakRef
var _body_attack_view_retired: bool=false
var received_body_attacks: Dictionary:
	get:
		var owner: Node=_body_attack_owner.get_ref() if _body_attack_owner!=null else null
		if _body_attack_view_retired or owner==null or not owner.field_rules.live() or owner._obtener_combatiente(pokemon_base)!=self:return {}
		return owner.bank_damage_history.snapshot(owner.turno._future_position(pokemon_base))
var body_attack_epoch: int=0

func bind_body_attack_owner(owner: Node) -> void:
	if _body_attack_owner==null:_body_attack_owner=weakref(owner)
func show_body_attack_view() -> void:_body_attack_view_retired=false
func has_body_damage() -> bool:
	var owner: Node=_body_attack_owner.get_ref() if _body_attack_owner!=null else null
	return owner!=null and owner.field_rules.live() and owner._obtener_combatiente(pokemon_base)==self and owner.bank_damage_history.any_damage(owner.turno._future_position(pokemon_base))
func record_body_attack(origin: BasePokemon, damage: int, category: int, owner: Node, source_position: int) -> void:
	if damage<0 or origin==null or owner==null or not owner.is_inside_tree() or owner.fase==owner.FIN_BATALLA or pokemon_base.estad_ps_actual<=0:return
	if owner._obtener_combatiente(pokemon_base)!=self or owner.turno._future_occupant(source_position)!=origin:return
	bind_body_attack_owner(owner);show_body_attack_view()
	owner.bank_damage_history.record(owner.turno._future_position(pokemon_base),category,damage,source_position)

func revenge_multiplier(target: BasePokemon, owner: Node) -> int:
	if owner==null or not owner.field_rules.live() or owner._obtener_combatiente(pokemon_base)!=self or pokemon_base.estad_ps_actual<=0 or target==null:return 1
	var position: Dictionary=owner.turno._posicion_pokemon(target)
	if position.is_empty() or owner.field_rules.occupant(position)!=target:return 1
	var bank: int=owner.turno._future_position(target)
	for record: Dictionary in owner.bank_damage_history.snapshot(owner.turno._future_position(pokemon_base)).values():
		if int(record.damage)>0 and int(record.position)==bank:return 2
	return 1

func retire_body_attacks() -> void:
	if pokemon_base.estad_ps_actual<=0:source_charge_turns=0
	body_attack_epoch+=1
	_body_attack_view_retired=true

func cancelar_continuacion() -> void:
	if hidden_projection!=null:hidden_projection.retire();hidden_projection=null
	pending_move = null
	semi_invulnerable = ""
	BattleRampageRules.retire(self)



func _init(pokemon: BasePokemon):
	self.pokemon_base = pokemon
	if pokemon_base != null and pokemon_base.estado == Singleton.ProblemaEstado.DORMIDO:
		iniciar_sueno(pokemon_base.turnos_sueno_guardados if pokemon_base.turnos_sueno_guardados > 0 else 2)
	# La cuenta de Tóxico solo se sube en gBattleMons, sin escribirla al equipo: al
	# volver sigue gravemente envenenado, pero la cuenta empieza de nuevo.
	if pokemon_base != null and pokemon_base.estado == Singleton.ProblemaEstado.ENVENENADO and pokemon_base.veneno_grave_guardado:
		envenenamiento_grave = true
		contador_veneno_grave = 1

# --- FUNCIONES PARA CALCULAR ESTADÍSTICAS EN COMBATE ---

func get_ataque_combate() -> int:
	var ataque := aplicar_modificador(BattleTransformRules.stat(self,"estad_ataque",pokemon_base.estad_ataque), mod_ataque)
	# AGALLAS ignora la reducción por quemadura.
	if HabilidadesCombate.reduce_ataque_por_quemadura(pokemon_base):
		ataque = int(ataque * 0.5)
	return ataque

func get_defensa_combate() -> int:
	return aplicar_modificador(BattleTransformRules.stat(self,"estad_defensa",pokemon_base.estad_defensa), mod_defensa)

func get_ataque_especial_combate() -> int:
	return aplicar_modificador(BattleTransformRules.stat(self,"estad_ataque_especial",pokemon_base.estad_ataque_especial), mod_ataque_especial)

func get_defensa_especial_combate() -> int:
	return aplicar_modificador(BattleTransformRules.stat(self,"estad_defensa_especial",pokemon_base.estad_defensa_especial), mod_defensa_especial)

## `clima_efectivo`: clima que se aplica de verdad (NADO RÁPIDO y CLOROFILA lo
## duplican con lluvia / sol). 0 si no se conoce.
func get_velocidad_combate(clima_efectivo: int = 0) -> int:
	# GetWhoStrikesFirst: el clima multiplica antes de la etapa; luego Brazal Firme y parálisis.
	var velocidad: int = HabilidadesCombate.velocidad_modificada(pokemon_base, BattleTransformRules.stat(self,"estad_velocidad",pokemon_base.estad_velocidad), clima_efectivo)
	velocidad = aplicar_modificador(velocidad, mod_velocidad)
	if BattleHeldItemRules.held(pokemon_base) == "BRAZALFIRME":
		velocidad /= 2
	# Aplicar parálisis si es el caso
	if pokemon_base.estado == Singleton.ProblemaEstado.PARALIZADO:
		velocidad /= 4
	return velocidad

# --- LÓGICA DE MODIFICADORES ---

# Calcula el multiplicador basado en el nivel del modificador (-6 a +6)
func calcular_multiplicador(modificador: int) -> float:
	if modificador >= 0:
		return (2.0 + float(modificador)) / 2.0
	else:
		return 2.0 / (2.0 - float(modificador))

# Aplica el modificador a una estadística base
func aplicar_modificador(stat_base: int, modificador: int) -> int:
	# gStatStageRatios con enteros: el decimal podía quedarse una unidad corto.
	if modificador >= 0:
		return stat_base * (2 + modificador) / 2
	return stat_base * 2 / (2 - modificador)

# Cambia un modificador, asegurando que no pase de -6 o +6
func cambiar_modificador(stat: String, cambio: int):
	match stat:
		"ataque":
			mod_ataque = clamp(mod_ataque + cambio, -6, 6)
		"defensa":
			mod_defensa = clamp(mod_defensa + cambio, -6, 6)
		"ataque_especial":
			mod_ataque_especial = clamp(mod_ataque_especial + cambio, -6, 6)
		"defensa_especial":
			mod_defensa_especial = clamp(mod_defensa_especial + cambio, -6, 6)
		"velocidad":
			mod_velocidad = clamp(mod_velocidad + cambio, -6, 6)
		"precision":
			mod_precision = clamp(mod_precision + cambio, -6, 6)
		"evasion":
			mod_evasion = clamp(mod_evasion + cambio, -6, 6)

func obtener_modificador(stat: String) -> int:
	match stat:
		"ataque":
			return mod_ataque
		"defensa":
			return mod_defensa
		"ataque_especial":
			return mod_ataque_especial
		"defensa_especial":
			return mod_defensa_especial
		"velocidad":
			return mod_velocidad
		"precision":
			return mod_precision
		"evasion":
			return mod_evasion
	return 0

# --- FUNCIONES DE ACCESO DIRECTO ---
# Para facilitar el acceso a los datos del Pokémon base

func get_nombre() -> String:
	return pokemon_base.nombre_interno

func get_nivel() -> int:
	return pokemon_base.nivel

func get_hp_actual() -> int:
	return pokemon_base.estad_ps_actual

func get_hp_max() -> int:
	return pokemon_base.estad_ps

func get_movimientos() -> Array:
	if has_meta("transform_domain"):return get_meta("transform_domain").moves
	if has_meta("mimic_moves"):return get_meta("mimic_moves")
	return pokemon_base.movimientos

func esta_debilitado() -> bool:
	return pokemon_base.estad_ps_actual <= 0

func recibir_danio(danio: int):
	pokemon_base.estad_ps_actual = max(0, pokemon_base.estad_ps_actual - danio)
	ha_recibido_danio_este_turno = true

func restaurar_hp(cantidad: int):
	pokemon_base.estad_ps_actual = min(pokemon_base.estad_ps, pokemon_base.estad_ps_actual + cantidad)

func iniciar_sueno(turnos: int = 0) -> void:
	# Ruby SetMoveEffect STATUS1_SLEEP cancels multi-turn USER state immediately,
	# before ENDTHRASH can decrement the final lock and apply natural confusion.
	cancelar_continuacion()
	BattleCounterRules.cancel_multi(self)
	if turnos <= 0:
		turnos = 2 + (randi() & 3) # Ruby STATUS1_SLEEP_TURN:2–5, not modulo3.
	turnos_dormido = turnos

func supera_chequeo_proteccion() -> bool:
	if factor_proteccion <= 1:
		return true
	return randi() % factor_proteccion == 0

func registrar_proteccion_exitosa() -> void:
	uso_proteccion_exitoso_este_turno = true
	factor_proteccion = max(2, factor_proteccion * 2)

func reiniciar_cadena_proteccion() -> void:
	factor_proteccion = 1
	uso_proteccion_exitoso_este_turno = false

func finalizar_ronda() -> void:
	if source_charge_turns>0:source_charge_turns-=1
	if has_meta("source_snatch_ready"):remove_meta("source_snatch_ready")
	if has_meta("source_magic_coat_ready"):remove_meta("source_magic_coat_ready")
	if source_recharge_turns>0:source_recharge_turns-=1
	if source_taunt_turns>0:source_taunt_turns-=1
	source_helping_hand=false
	source_follow_me=false
	if source_sure_hit_turns>0:
		source_sure_hit_turns-=1
		if source_sure_hit_turns==0:source_sure_hit_attacker=null
	if pokemon_base.estad_ps_actual <= 0 or pokemon_base.estado == Singleton.ProblemaEstado.DORMIDO:
		cancelar_continuacion()
	rondas_en_campo += 1
	retrocede = false
	protegido_este_turno = false
	aguante_este_turno = false
	ha_recibido_danio_este_turno = false
	if pending_move!=null and pending_move.source_i4!=null:pending_move.source_i4.prepare_round_retirement(self)
	retire_body_attacks()
	if not uso_proteccion_exitoso_este_turno:
		factor_proteccion = 1
	uso_proteccion_exitoso_este_turno = false
	if pokemon_base.estado != Singleton.ProblemaEstado.ENVENENADO:
		envenenamiento_grave = false
		contador_veneno_grave = 0

# --- LÓGICA DE FIN DE TURNO ---

func al_finalizar_turno():
	finalizar_ronda()

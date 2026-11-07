## Etapa 5.2 del rediseño de arquitectura (SDD 2026-09-14-battle-architecture-split):
## dueño de la resolución de turno a turno — selección de acción, orden por
## prioridad/velocidad, ejecución de ataques (simple y doble), IA de
## selección de movimiento enemigo, uso de objetos/cambios de la IA enemiga
## durante su turno, y el ciclo revisar_ronda() que decide qué sigue.
##
## Deliberadamente NO incluye: victoria/derrota, EXP/subida de nivel, ni la
## selección forzada de Pokémon al debilitarse (`verificar_fin_batalla()` y
## todo lo que cuelga de ella) — eso vive en `_b.resultado`
## (`BattleResultController`, Etapa 5.3). Tampoco incluye
## `_reponer_slots_dobles()` (gestión visual de slots/equipo) ni
## `fase_input()` (compartida por mochila/cambio de Pokémon/etc.), que se
## invocan de vuelta en `_b`.
extends RefCounted
class_name BattleTurnController

## Explicit battle-script waitmessage 64, after printing (not input confirmation).
const SOURCE_MESSAGE_READ_SECONDS := 64.0 / 60.0

const SE_SUBIDA_ESTADISTICA: AudioStream = preload("res://Audio/SE/increase.wav")
const SE_BAJADA_ESTADISTICA: AudioStream = preload("res://Audio/SE/decrease.wav")

var _b: BattleSceneController
var _acciones_restantes_dobles: Array[Dictionary] = []
var _acciones_jugador_no_movimiento: Dictionary = {}
enum AttackProvenance { ORDINARY, FUTURE }
const OBEDIENCE=preload("res://scripts/battle/obedience_rules.gd")
var _source_objetivos_chequeo: Array[BasePokemon]=[]
var _source_current_move: Movimiento
## gBattlerTarget: banco y Pokémon del último objetivo de un movimiento. Lo lee la IA de
## cambio; no se actualiza con los efectos residuales que también lo escriben en Ruby.
var _source_protect_receipt: Dictionary={}
## Persistent gMoveResultFlags NO_EFFECT subset; ActionFinished does not clear it.
var _source_no_effect_flags: int=0
var _source_result_generation: int=0
## Baton owns only its departing bank; recursive successors retain the other banks.
var _baton_entry_flow: Dictionary={}
var end_round_replacement_pending := false
var future_attacks := BattleFutureAttackQueue.new()


func _init(batalla: BattleSceneController) -> void:
	_b = batalla


## Call only where the source script emits waitmessage 64. Empty MSG_DISPLAY skips.
## The caller's original receipt remains the authority across BOTH awaits.
func _mostrar_mensaje_source_64(text: String, live: Callable) -> bool:
	if not is_instance_valid(_b) or not _b.is_inside_tree():return false
	if not live.call():return false
	if text.is_empty():return true
	var flow: Dictionary=_b.field_rules.capture_flow()
	if not _b.field_rules.valid_flow(flow):return false
	await _b.mostrar_texto_batalla(text)
	if not is_instance_valid(_b) or not _b.is_inside_tree():return false
	if not live.call() or not _b.field_rules.valid_flow(flow):return false
	await _esperar_lectura_source_64()
	return is_instance_valid(_b) and _b.is_inside_tree() and _b.field_rules.valid_flow(flow) and bool(live.call())

## Separate from printing/confirmation so tests can gate the same await boundary.
func _esperar_lectura_source_64() -> void:
	var tree: SceneTree=_b.get_tree()
	# Native adaptation: do not credit a timer's pre-creation frame delta as reading.
	# Preserve SceneTree pause/time-scale policy; only correct an early timeout.
	var deadline_usec: int=Time.get_ticks_usec()+ceili(SOURCE_MESSAGE_READ_SECONDS*1000000.0)
	var remaining: float=SOURCE_MESSAGE_READ_SECONDS
	while remaining>0.0:
		await tree.create_timer(remaining).timeout
		remaining=maxf(0.0,float(deadline_usec-Time.get_ticks_usec())/1000000.0)


func _pendiente(actor: BasePokemon) -> PendingMoveContinuation:
	var state := _b._obtener_combatiente(actor) if actor != null else null
	if state!=null and state.pending_move!=null and state.pending_move.source_i4!=null and not state.pending_move.source_i4.live():
		var original: Movimiento=state.pending_move.move
		state.cancelar_continuacion()
		if _b.movimiento_jugador==original:_b.movimiento_jugador=null
		if _b.movimiento_enemigo==original:_b.movimiento_enemigo=null
	return state.pending_move if state != null else null

func _movimientos_en_campo(actor: BasePokemon) -> Array[Movimiento]:
	return BattleTransformRules.moves(actor) if actor!=null else []


func _posicion_pokemon(pokemon: BasePokemon) -> Dictionary:
	if _b.formato_batalla == Singleton.FormatoBatalla.SIMPLE:
		return {"player":pokemon == _b.poke_jugador, "flank":0}
	return {"player":_b.pokemones_activos_jugador.has(pokemon), "flank":maxi(0, _b.pokemones_activos_jugador.find(pokemon) if _b.pokemones_activos_jugador.has(pokemon) else _b.pokemones_activos_enemigo.find(pokemon))}


func _ocupante_posicion(position: Dictionary, actor: BasePokemon) -> BasePokemon:
	if _b.formato_batalla == Singleton.FormatoBatalla.SIMPLE:
		return _b.poke_jugador if bool(position.get("player", false)) else _b.poke_enemigo
	var side: Array[BasePokemon] = _b.pokemones_activos_jugador if bool(position.get("player", false)) else _b.pokemones_activos_enemigo
	var flank := int(position.get("flank", 0))
	if flank < side.size() and side[flank] != null and side[flank].estad_ps_actual > 0: return side[flank]
	return _obtener_objetivo_doble(actor)


## Returns true only when this input slot has been auto-queued.
## Venganza en curso: el canceller de la ROM salta el `attackstring`, así que los turnos
## de acumulación y de liberación no repiten «¡X usó Venganza!».
func _turno_bide_pendiente(actor: BasePokemon) -> bool:
	var pending := _pendiente(actor)
	return pending != null and pending.mode == "bide"


func continuar_movimiento_pendiente(actor: BasePokemon, lucha_elegida: bool=false) -> bool:
	if BattleLockedMoveRules.recharging(_b,actor):
		var relleno: Movimiento=preload("res://scripts/battle/move_availability_rules.gd").struggle()
		if _b.formato_batalla == Singleton.FormatoBatalla.DOBLE:
			var slot_recarga := _b.slot_jugador_seleccionado
			if slot_recarga == 0: _b.movimiento_jugador_primario_doble = relleno
			else: _b.movimiento_jugador_secundario = relleno
			_confirmar_objetivo_doble(_obtener_objetivo_doble(actor),slot_recarga)
		else:
			_on_batalla_movimiento_seleccionado(_b.MOV1,relleno)
		return true
	var pending := _pendiente(actor)
	var locked_move: Movimiento=BattleLockedMoveRules.move(_b,actor) if lucha_elegida else BattleLockedMoveRules.multi_turn(_b,actor)
	if pending == null and locked_move==null: return false
	var continuation: Movimiento=pending.move if pending!=null else locked_move
	if _b.formato_batalla == Singleton.FormatoBatalla.DOBLE:
		var slot := _b.slot_jugador_seleccionado
		if slot == 0: _b.movimiento_jugador_primario_doble = continuation
		else: _b.movimiento_jugador_secundario = continuation
		if pending!=null:_confirmar_objetivo_doble(_ocupante_posicion(pending.target_position, actor), slot)
		elif locked_move.get_efecto()=="EFFECT_ROLLOUT":_confirmar_objetivo_doble(BattleCounterRules.target(_b,actor),slot)
		else:_iniciar_objetivo_o_siguiente_slot(continuation,slot)
	else:
		_on_batalla_movimiento_seleccionado(_movimientos_en_campo(actor).find(continuation))
	return true


func _on_batalla_movimiento_seleccionado(opcion: int,forced: Movimiento=null) -> void:
	_b.movimiento_jugador = null
	_b.movimiento_enemigo = null
	_b.movimiento_jugador_secundario = null if _b.formato_batalla == Singleton.FormatoBatalla.SIMPLE else _b.movimiento_jugador_secundario
	_b.accion_enemiga = {}

	var pokemon_seleccionado: BasePokemon = _b.poke_jugador
	if _b.formato_batalla == Singleton.FormatoBatalla.DOBLE and _b.slot_jugador_seleccionado == 1 and _b.pokemones_activos_jugador.size() > 1:
		pokemon_seleccionado = _b.pokemones_activos_jugador[1]

	# Verificar que el Pokémon tiene movimientos
	var selected_moves: Array[Movimiento]=_movimientos_en_campo(pokemon_seleccionado)
	if forced!=null:selected_moves=[forced]
	if selected_moves.is_empty():
		print("❌ Error: El Pokémon jugador no tiene movimientos")
		_b.fase_input()
		return

	match opcion:
		_b.MOV1:
			if selected_moves.size() > 0:
				_b.movimiento_jugador = selected_moves[0]
		_b.MOV2:
			if selected_moves.size() > 1:
				_b.movimiento_jugador = selected_moves[1]
		_b.MOV3:
			if selected_moves.size() > 2:
				_b.movimiento_jugador = selected_moves[2]
		_b.MOV4:
			if selected_moves.size() > 3:
				_b.movimiento_jugador = selected_moves[3]
		-1: # Cancelar
			if _b.formato_batalla == Singleton.FormatoBatalla.DOBLE and _b.slot_jugador_seleccionado == 1:
				_b.slot_jugador_seleccionado = 0
				_b.iniciar_cuadro_movimientos(_b.poke_jugador)
				_b.presentacion.mostrar_menu_movimientos()
				return
			_b.presentacion.mostrar_menu_principal()
			return
		_:
			print("Error: opción no válida")
			_b.presentacion.mostrar_menu_principal()
			return

	var locked := _pendiente(pokemon_seleccionado)
	if locked != null: _b.movimiento_jugador = locked.move
	var rampage_move: Movimiento=null if forced!=null else BattleLockedMoveRules.move(_b,pokemon_seleccionado)
	if rampage_move!=null:_b.movimiento_jugador=rampage_move

	# Verificar que se seleccionó un movimiento válido
	if _b.movimiento_jugador == null:
		print("❌ Error: No se pudo seleccionar movimiento válido")
		_b.fase_input()
		return

	var availability=preload("res://scripts/battle/move_availability_rules.gd")
	if forced==null and rampage_move==null and locked==null and availability.blocked(_b,pokemon_seleccionado,_b.movimiento_jugador):
		var rejected: Movimiento=_b.movimiento_jugador;_b.movimiento_jugador=null
		var nombre: String=pokemon_seleccionado.get_nombre_combate()
		# REGLA (decomp, TrySetCantSelectMoveBattleScript): cada restricción tiene su texto
		# (ROM española) y gana la última que se comprueba: ANULACIÓN < TORMENTO < MOFA <
		# sellado < CINTA ELECCIÓN < sin PP. printselectionstring termina en \p: espera a A.
		var paginas: Array[String]=["¡Ese movimiento está restringido!"]
		if preload("res://scripts/battle/disable_rules.gd").blocked(_b,pokemon_seleccionado,rejected):
			paginas=["¡%s no puede usar\n%s por culpa de ANULACIÓN!"%[nombre,rejected.nombre]]
		if preload("res://scripts/battle/torment_rules.gd").blocked(_b,pokemon_seleccionado,rejected):
			# El \l de la ROM desplaza una línea; aquí se emula con una segunda página.
			paginas=["¡%s no puede usar el\nmismo movimiento dos veces"%nombre,"mismo movimiento dos veces\nseguidas debido a TORMENTO!"]
		if preload("res://scripts/battle/thought_finger_rules.gd").blocked(_b,pokemon_seleccionado,rejected):
			paginas=["¡%s no puede usar\n%s debido a MOFA!"%[nombre,rejected.nombre]]
		if preload("res://scripts/battle/imprison_rules.gd").sealed(_b,pokemon_seleccionado,rejected):
			paginas=["¡%s no puede usar\n%s porque está sellado!"%[nombre,rejected.nombre]]
		if preload("res://scripts/battle/choice_band_rules.gd").blocked(_b,pokemon_seleccionado,rejected):
			var state: PokemonEnCombate=_b._obtener_combatiente(pokemon_seleccionado)
			var locked_name: String=""
			for move: Movimiento in selected_moves.slice(0,4):
				if move!=null and int(move.datos.get("numero_movimiento",0))==int(state.get_meta("source_choice_move",0)):locked_name=move.nombre;break
			paginas=["%s only permits %s."%[ObjetosLlevados.nombre_objeto(ObjetosLlevados.en_combate(pokemon_seleccionado)),locked_name]]
		if not rejected.tiene_pp():paginas=["¡No quedan PP para\neste movimiento!"]
		var original: Dictionary=_b.field_rules.capture(pokemon_seleccionado)
		for i: int in paginas.size():
			if i<paginas.size()-1:await _b.mostrar_texto_batalla(paginas[i])
			else:await _b._mostrar_texto_y_esperar_confirmacion(paginas[i])
			if not _b.field_rules.valid(original):return
		_b.presentacion.mostrar_menu_movimientos()
		return

	if _b.formato_batalla == Singleton.FormatoBatalla.DOBLE:
		if _b.slot_jugador_seleccionado == 0:
			_b.movimiento_jugador_primario_doble = _b.movimiento_jugador
			_iniciar_objetivo_o_siguiente_slot(_b.movimiento_jugador_primario_doble, 0)
			return
		if _b.slot_jugador_seleccionado == 1:
			_b.movimiento_jugador_secundario = _b.movimiento_jugador
			_iniciar_objetivo_o_siguiente_slot(_b.movimiento_jugador_secundario, 1)
			return
	else:
		_establecer_accion_enemiga_seleccionada(seguir_estrategia())

	# Ejecutar el turno
	_b.fases.cambiar_fase(_b.RONDA)

	_b.spr_pokemon_jugador.offset.y = 0
	_b.hud.cuadro_ps_jugador.set_offset_y(0)
	_b.timer_pkm_actual.stop()
	_b.hud.detener_timer_ps()

	_b.turno_jugador_pasado = false
	_b.turno_enemigo_pasado = false
	ejecutar_ronda()


func _iniciar_objetivo_o_siguiente_slot(movimiento: Movimiento, slot_indice: int) -> void:
	if movimiento!=null and movimiento.has_meta("source_forced_struggle"):
		_confirmar_objetivo_doble(_objetivo_struggle_source(_b.pokemones_activos_jugador[slot_indice]),slot_indice);return
	if movimiento != null:
		var alcance := AlcanceMovimientoGen3.tipo(movimiento, _movimiento_apunta_al_usuario(movimiento))
		if movimiento.get_efecto() in ["EFFECT_RAMPAGE","EFFECT_UPROAR"]:alcance=AlcanceMovimientoGen3.RIVAL_ALEATORIO
		if not AlcanceMovimientoGen3.soportado(alcance):
			push_warning("[BATALLA] Objetivo de movimiento no soportado en DOBLE: %s (%d)" % [movimiento.get_nombre_interno(), alcance])
			_b.iniciar_cuadro_movimientos(_b.pokemones_activos_jugador[slot_indice])
			_b.presentacion.mostrar_menu_movimientos()
			return
		var actor: BasePokemon = _b.pokemones_activos_jugador[slot_indice]
		if preload("res://scripts/battle/retaliation_rules.gd").supports(movimiento):
			# CONTADOR/MANTO ESPEJO son MOVE_TARGET_DEPENDS en Ruby: sin cursor
			# (HandleAction_ChooseMove, r4 & 0x7D); igual que la acción rival.
			_confirmar_objetivo_doble(_obtener_objetivo_doble(actor), slot_indice)
			return
		# Cursor del jugador: MOVE_TARGET_SELECTED incluye al compañero.
		_b.objetivos_doble = AlcanceMovimientoGen3.elegibles_cursor(alcance, actor, _b.pokemones_activos_jugador, _b.pokemones_activos_enemigo)
		if AlcanceMovimientoGen3.necesita_selector(alcance) and _b.objetivos_doble.is_empty():
			_b.presentacion.set_texto_instantaneo("No hay un objetivo válido")
			return
		if alcance == AlcanceMovimientoGen3.SELECCIONADO and _b.objetivos_doble.size() == 1:
			# Ruby: CountAliveMons(0) <= 1 → objetivo automático, sin cursor.
			_confirmar_objetivo_doble(_b.objetivos_doble[0], slot_indice)
			return
		if AlcanceMovimientoGen3.necesita_selector(alcance) and preload("res://scripts/battle/encore_rules.gd").move(_b,actor)==movimiento:
			# Ruby: Otra Vez no abre cursor; HandleAction_UseMove usa GetMoveTarget(move, 0).
			_confirmar_objetivo_doble(_obtener_objetivo_doble(actor), slot_indice)
			return
		if AlcanceMovimientoGen3.necesita_selector(alcance):
			_b.seleccionando_objetivo_doble = true
			_b.bloquear_confirmacion_objetivo_doble = true
			call_deferred("_desbloquear_confirmacion_objetivo_doble")
			_b.indice_objetivo_doble = AlcanceMovimientoGen3.indice_inicial_cursor(_b.objetivos_doble, _b.pokemones_activos_enemigo) if alcance == AlcanceMovimientoGen3.SELECCIONADO else 0
			_actualizar_marcadores_objetivo_doble()
			_b.presentacion.set_texto_instantaneo("Elige un objetivo")
			return
	_confirmar_objetivo_doble(_b.objetivos_doble[0] if not _b.objetivos_doble.is_empty() else null, slot_indice)


func _confirmar_objetivo_doble(objetivo: BasePokemon, slot_indice: int) -> void:
	_b.seleccionando_objetivo_doble = false
	_b.objetivos_doble.clear()
	_b.slot_rival.marcar_objetivo(false)
	_b.slot_rival_secundario.marcar_objetivo(false)
	_b.slot_jugador.marcar_objetivo(false)
	_b.slot_jugador_secundario.marcar_objetivo(false)
	if slot_indice == 0:
		_b.objetivo_jugador_primario_doble = objetivo
	else:
		_b.objetivo_jugador_secundario_doble = objetivo
	_continuar_decisiones_dobles(slot_indice)


func registrar_cambio_doble(indice_equipo: int) -> bool:
	if indice_equipo < 0 or indice_equipo >= _b.equipo_jugador_pokemones.size():
		return false
	var nuevo: BasePokemon = _b.equipo_jugador_pokemones[indice_equipo]
	if nuevo == null or not nuevo.puede_combatir() or _b.pokemones_activos_jugador.has(nuevo):
		return false
	var slot := _b.slot_jugador_seleccionado
	_acciones_jugador_no_movimiento[slot] = {"tipo": "cambio", "indice_equipo": indice_equipo}
	_continuar_decisiones_dobles(slot)
	return true


func registrar_objeto_doble() -> void:
	var slot := _b.slot_jugador_seleccionado
	_acciones_jugador_no_movimiento[slot] = {"tipo": "objeto"}
	_continuar_decisiones_dobles(slot)


func _continuar_decisiones_dobles(slot_indice: int) -> void:
	if slot_indice == 0 and _b.pokemones_activos_jugador.size() > 1 and _b.pokemones_activos_jugador[1] != null and _b.pokemones_activos_jugador[1].estad_ps_actual > 0:
		_b.slot_jugador_seleccionado = 1
		_b.fase_input(false)
		return
	_b.slot_jugador_seleccionado = 0
	_establecer_acciones_dobles()
	_b.fases.cambiar_fase(_b.RONDA)
	_b.spr_pokemon_jugador.offset.y = 0
	_b.hud.cuadro_ps_jugador.set_offset_y(0)
	_b.timer_pkm_actual.stop()
	_b.hud.detener_timer_ps()
	_b.turno_jugador_pasado = false
	_b.turno_enemigo_pasado = false
	ejecutar_ronda()


func _desbloquear_confirmacion_objetivo_doble() -> void:
	_b.bloquear_confirmacion_objetivo_doble = false


func _actualizar_marcadores_objetivo_doble() -> void:
	_b.slot_rival.marcar_objetivo(false)
	_b.slot_rival_secundario.marcar_objetivo(false)
	_b.slot_jugador.marcar_objetivo(false)
	_b.slot_jugador_secundario.marcar_objetivo(false)
	if _b.objetivos_doble.is_empty():
		return
	var objetivo: BasePokemon = _b.objetivos_doble[_b.indice_objetivo_doble]
	if objetivo == _b.poke_enemigo:
		_b.slot_rival.marcar_objetivo(true)
	elif _b.pokemones_activos_enemigo.size() > 1 and objetivo == _b.pokemones_activos_enemigo[1]:
		_b.slot_rival_secundario.marcar_objetivo(true)
	elif objetivo == _b.poke_jugador:
		_b.slot_jugador.marcar_objetivo(true)
	elif _b.pokemones_activos_jugador.size() > 1 and objetivo == _b.pokemones_activos_jugador[1]:
		_b.slot_jugador_secundario.marcar_objetivo(true)


## El jugador gastó su acción en algo que no es un movimiento (cambio de
## Pokémon, objeto, POKé BALL fallida o bloqueada): solo actúa el rival.
## En DOBLE `ejecutar_ronda()` solo avanza desde PRIORIDADES y descarta las
## acciones sin movimiento, así que la ronda arranca ahí con los movimientos
## del jugador vacíos; en SIMPLE se salta directo a TURNO_ENEMIGO.
func ceder_turno_al_rival() -> void:
	var source_nonmove: String=str(get_meta("source_next_nonmove_kind","item"))
	if has_meta("source_next_nonmove_kind"):remove_meta("source_next_nonmove_kind")
	_b.fases.cambiar_fase(_b.RONDA)
	if _b.formato_batalla == Singleton.FormatoBatalla.DOBLE:
		_b.movimiento_jugador = null
		_b.movimiento_jugador_primario_doble = null
		_b.movimiento_jugador_secundario = null
		_acciones_jugador_no_movimiento.clear()
		_establecer_acciones_dobles()
		ejecutar_ronda()
		return
	# Acción ya elegida antes del cambio del jugador (preseleccionar_accion_enemiga).
	var preseleccionada: bool=int(get_meta("source_enemy_action_preselected",-1))==_b.contador_turnos
	if has_meta("source_enemy_action_preselected"):remove_meta("source_enemy_action_preselected")
	if not preseleccionada:_establecer_accion_enemiga_seleccionada(seguir_estrategia())
	_publicar_proyeccion_protect([],source_nonmove)
	_b.turno_jugador_pasado = true
	# PERSECUCIÓN ya golpeó al que se retiraba: el rival no vuelve a actuar (acción 11).
	if has_meta("source_enemy_pursuit_done"):
		remove_meta("source_enemy_pursuit_done")
		_b.turno_enemigo_pasado = true
		_b.fases.cambiar_fase_ronda(MaquinaEstadosBatalla.FaseRonda.REVISAR_RONDA)
	else:
		_b.turno_enemigo_pasado = false
		_b.fases.cambiar_fase_ronda(MaquinaEstadosBatalla.FaseRonda.TURNO_ENEMIGO)
	ejecutar_ronda()


func _establecer_acciones_dobles() -> void:
	var primaria: Dictionary = _crear_accion_enemiga_para(_b.poke_enemigo)
	_establecer_accion_enemiga_seleccionada(primaria)
	if _b.pokemones_activos_enemigo.size() > 1:
		_b.accion_enemiga_secundaria = _crear_accion_enemiga_para(_b.pokemones_activos_enemigo[1], primaria.get("pokemon_cambio", null))
	else:
		_b.accion_enemiga_secundaria = {}


## `reservado`: relevo ya elegido por el compañero (monToSwitchIntoId). Slot vacío: sin acción.
func _crear_accion_enemiga_para(pokemon: BasePokemon, reservado: BasePokemon = null) -> Dictionary:
	if pokemon == null:
		return {}
	var cambio: Dictionary = _accion_cambio_rival_doble(pokemon, reservado)
	if not cambio.is_empty():
		return cambio
	# ShouldUseItem por slot: elegir() gasta el objeto al decidir, el compañero ya no lo ve.
	if _b.ai_integrador != null and not _rival_con_accion_fijada(pokemon):
		var objeto: String = _elegir_objeto_rival(pokemon)
		if not objeto.is_empty():
			return {"type": "item", "item_name": objeto, "reasoning": "ShouldUseItem"}
	var movimiento: Movimiento=preload("res://scripts/battle/move_availability_rules.gd").struggle() if BattleLockedMoveRules.recharging(_b,pokemon) else BattleLockedMoveRules.selection(_b,pokemon)
	var locked: PendingMoveContinuation=_pendiente(pokemon)
	if movimiento==null:movimiento=locked.move if locked!=null else _seleccionar_movimiento_enemigo_para(pokemon)
	var selected: BasePokemon=null
	if locked!=null:selected=_ocupante_posicion(locked.target_position,pokemon)
	elif movimiento!=null and movimiento.has_meta("source_forced_struggle"):selected=_objetivo_struggle_source(pokemon)
	elif movimiento!=null:
		var scope: int=AlcanceMovimientoGen3.tipo(movimiento,_movimiento_apunta_al_usuario(movimiento))
		var choices: Array[BasePokemon]=AlcanceMovimientoGen3.elegibles(scope,pokemon,_b.pokemones_activos_enemigo,_b.pokemones_activos_jugador)
		if scope==AlcanceMovimientoGen3.USUARIO:selected=pokemon
		if preload("res://scripts/battle/retaliation_rules.gd").supports(movimiento):selected=_obtener_objetivo_doble(pokemon)
		elif scope==AlcanceMovimientoGen3.SELECCIONADO and not choices.is_empty():
			# Source selected-target random bank rejection; the accepted queue keeps BANK.
			while selected==null:
				var candidate: BasePokemon=_future_occupant((_sortear_objetivo_source()&65535)%4)
				if choices.has(candidate):selected=candidate
		elif not choices.is_empty():selected=choices[0]
	return {"type":"attack","move":movimiento,"target":selected,"reasoning":"Double action selection"}

func _rival_con_accion_fijada(pokemon: BasePokemon) -> bool:
	return BattleLockedMoveRules.recharging(_b,pokemon) or BattleLockedMoveRules.multi_turn(_b,pokemon) != null or _pendiente(pokemon) != null


## AI_TrySwitchOrUseItem de un slot en dobles: atrapado o con la acción bloqueada no
## cambia, y excluye a los dos activos y al relevo que eligió su compañero.
func _accion_cambio_rival_doble(pokemon: BasePokemon, reservado: BasePokemon) -> Dictionary:
	if _b.ai_integrador == null or _rival_con_accion_fijada(pokemon):
		return {}
	var excluidos: Array[BasePokemon] = _b.pokemones_activos_enemigo.duplicate()
	if reservado != null:
		excluidos.append(reservado)
	var accion: Dictionary = _b.ai_integrador.decidir_cambio_rival(pokemon, reservado)
	if str(accion.get("type", "")) != "switch":
		return {}
	var target = accion.get("target_pokemon", {})
	var indice: int = int(target.get("team_index", -1)) if typeof(target) == TYPE_DICTIONARY else -1
	if indice < 0 or indice >= _b.equipo_enemigo_pokemones.size():
		return {}
	var nuevo: BasePokemon = _b.equipo_enemigo_pokemones[indice]
	if nuevo == null or not nuevo.puede_combatir() or excluidos.has(nuevo):
		return {}
	accion["pokemon_cambio"] = nuevo
	accion["indice_equipo"] = indice
	return accion


func _sortear_objetivo_source() -> int:return randi()&65535
func _sortear_ia_cambio() -> int:return randi()&65535
func _objetivo_struggle_source(actor: BasePokemon) -> BasePokemon:
	# AreAllMovesUnusable uses OR, retaining a right battler's flank bit.
	var bank: int=(_future_position(actor)^1)|(_sortear_objetivo_source()&2)
	var target: BasePokemon=_future_occupant(bank)
	return target if target!=null and target.estad_ps_actual>0 else _future_occupant(bank^2)


func seguir_estrategia() -> Dictionary:
	if BattleLockedMoveRules.recharging(_b,_b.poke_enemigo):
		return {"type":"attack","move":preload("res://scripts/battle/move_availability_rules.gd").struggle()}
	var rampage_move: Movimiento=BattleLockedMoveRules.multi_turn(_b,_b.poke_enemigo)
	if rampage_move!=null:return {"type":"attack","move":rampage_move}
	var locked := _pendiente(_b.poke_enemigo)
	if locked != null: return {"type":"attack", "move":locked.move}
	# Otra Vez no quita la acción: la IA aún puede cambiar o usar un objeto, y solo se
	# salta la elección de movimiento, donde también viven las huidas de la IA.
	var encore_move: Movimiento=BattleLockedMoveRules.selection(_b,_b.poke_enemigo)
	if encore_move==null and _salvaje_huye_del_primer_combate():
		return {"type": "flee", "reasoning": "AI_GoEasy"}
	if encore_move==null and _errante_huye():
		return {"type": "flee", "reasoning": "AI_Roaming"}
	if _b.ai_integrador != null:
		# AI_TrySwitchOrUseItem: primero ShouldSwitch, luego ShouldUseItem y si no, movimiento.
		var cambio: Dictionary = _b.ai_integrador.decidir_cambio_rival(_b.poke_enemigo)
		if not cambio.is_empty():
			return cambio
		var objeto: String = _elegir_objeto_rival()
		if not objeto.is_empty():
			return {"type": "item", "item_name": objeto, "reasoning": "ShouldUseItem"}
		if encore_move==null:
			var accion_ia = _b.ai_integrador.get_intelligent_battle_action(_movimientos_en_campo(_b.poke_enemigo))
			if _accion_enemiga_es_valida(accion_ia):
				return accion_ia

	if encore_move!=null:return {"type":"attack","move":encore_move}
	return _crear_accion_enemiga_respaldo()


func _elegir_objeto_rival(actor: BasePokemon = null) -> String:
	var objetos: ObjetosEntrenadorIA = _b.ai_integrador.objetos_entrenador
	if objetos == null:
		return ""
	var usuario: BasePokemon = actor if actor != null else _b.poke_enemigo
	var vivos := 0
	for pokemon: BasePokemon in _b.equipo_enemigo_pokemones:
		if pokemon != null and pokemon.estad_ps_actual > 0:
			vivos += 1
	return objetos.elegir(usuario.estad_ps_actual, usuario.estad_ps, vivos, _rival_en_primer_turno(usuario), _b.screen_rules.remaining(1, "EFFECT_MIST") > 0)


## isFirstTurn al elegir: 2 al entrar y baja al terminar cada turno (y una vez antes del
## primero). Quien sale al empezar o en el relevo tras debilitarse lo tiene activo un
## turno; quien entra con la ronda en marcha, en la selección siguiente.
func _rival_en_primer_turno(actor: BasePokemon = null) -> bool:
	var state: PokemonEnCombate = _b._obtener_combatiente(actor if actor != null else _b.poke_enemigo)
	if state == null:
		return false
	return state.rondas_en_campo == 0 or (state.entro_a_mitad_de_ronda and state.rondas_en_campo == 1)


## AI_GoEasy (POOCHYENA del primer combate): if_hp_equal / if_hp_less_than TARGET 20
## → flee. El porcentaje es el entero de PS * 100 / PS máximos del objetivo.
func _salvaje_huye_del_primer_combate() -> bool:
	if not _b.primer_combate or _b.poke_jugador == null:
		return false
	var maximos: int = maxi(int(_b.poke_jugador.estad_ps), 1)
	return int(_b.poke_jugador.estad_ps_actual) * 100 / maximos <= 20


## AI_Roaming (BATTLE_TYPE_ROAMER): el errante huye salvo que esté atrapado
## (S_TEMP_TRAP: Atadura y similares; S_MEAN_LOOK: Mal de Ojo, Telaraña, Bloqueo),
## que el rival tenga SOMBRATRAMPA o, si el errante no tiene LEVITACIÓN,
## TRAMPAARENA.
func _errante_huye() -> bool:
	if not _b.errante or _b.poke_enemigo == null:
		return false
	var estado: PokemonEnCombate = _b._obtener_combatiente(_b.poke_enemigo)
	if estado != null and estado.esta_atrapado:
		return false
	if not preload("res://scripts/battle/escape_prevention_rules.gd").blocked(_b.poke_enemigo, _b.habilidades.crear_campo()).is_empty():
		return false
	if _b.poke_jugador == null:
		return true
	var habilidad_rival := HabilidadesCombate.de(_b.poke_jugador)
	if habilidad_rival == HabilidadesCombate.SOMBRATRAMPA:
		return false
	if HabilidadesCombate.tiene(_b.poke_enemigo, HabilidadesCombate.LEVITACION):
		return true
	return habilidad_rival != HabilidadesCombate.TRAMPAARENA


func _crear_accion_enemiga_respaldo() -> Dictionary:
	return {
		"type": "attack",
		"move": _seleccionar_movimiento_enemigo_aleatorio(),
		"reasoning": "Selección automática de respaldo"
	}


func _accion_enemiga_es_valida(accion: Dictionary) -> bool:
	if accion.is_empty():
		return false

	match str(accion.get("type", "")):
		"attack":
			return accion.get("move", null) is Movimiento and preload("res://scripts/battle/move_availability_rules.gd").legal(_b,_b.poke_enemigo,accion.move)
		"flee":
			return true
		"item":
			return not str(accion.get("item_name", "")).is_empty()

	return false


func _establecer_accion_enemiga_seleccionada(accion: Dictionary) -> void:
	_b.accion_enemiga = accion
	var movimiento = _b.accion_enemiga.get("move", null)
	_b.movimiento_enemigo = movimiento if movimiento is Movimiento else null


func _seleccionar_movimiento_enemigo_aleatorio() -> Movimiento:
	return _seleccionar_movimiento_enemigo_para(_b.poke_enemigo)


func _seleccionar_movimiento_enemigo_para(pokemon: BasePokemon) -> Movimiento:
	if pokemon == null:
		return null
	var forced: Movimiento=BattleLockedMoveRules.selection(_b,pokemon)
	if forced!=null:return forced
	var pending: PendingMoveContinuation=_pendiente(pokemon)
	if pending!=null:return pending.move
	var slots: Array[int]=preload("res://scripts/battle/move_availability_rules.gd").slots(_b,pokemon)
	if slots.is_empty():return preload("res://scripts/battle/move_availability_rules.gd").struggle()
	return _movimientos_en_campo(pokemon)[slots[randi()%slots.size()]]


func ejecutar_ronda():
	if _b.formato_batalla == Singleton.FormatoBatalla.DOBLE:
		if _b.fase_ronda == MaquinaEstadosBatalla.FaseRonda.PRIORIDADES:
			_ejecutar_ronda_doble()
		return
	match _b.fase_ronda:
		MaquinaEstadosBatalla.FaseRonda.PRIORIDADES:
			verificar_prioridad()
		MaquinaEstadosBatalla.FaseRonda.TURNO_JUGADOR:
			turno_jugador()
		MaquinaEstadosBatalla.FaseRonda.TURNO_ENEMIGO:
			turno_enemigo()
		MaquinaEstadosBatalla.FaseRonda.REVISAR_RONDA:
			revisar_ronda()


func _ejecutar_ronda_doble() -> void:
	var acciones: Array[Dictionary] = []
	for slot_indice in _acciones_jugador_no_movimiento:
		if slot_indice >= _b.pokemones_activos_jugador.size():
			continue
		var no_mov: Dictionary = _acciones_jugador_no_movimiento[slot_indice]
		acciones.append({"actor": _b.pokemones_activos_jugador[slot_indice], "tipo": no_mov.get("tipo", "objeto"), "indice_equipo": no_mov.get("indice_equipo", -1), "es_jugador": true})
	if _b.movimiento_jugador_primario_doble != null and not _b.pokemones_activos_jugador.is_empty():
		acciones.append({"actor": _b.pokemones_activos_jugador[0], "movimiento": _b.movimiento_jugador_primario_doble, "objetivo": _b.objetivo_jugador_primario_doble, "es_jugador": true})
	if _b.movimiento_jugador_secundario != null and _b.pokemones_activos_jugador.size() > 1:
		acciones.append({"actor": _b.pokemones_activos_jugador[1], "movimiento": _b.movimiento_jugador_secundario, "objetivo": _b.objetivo_jugador_secundario_doble, "es_jugador": true})
	if _b.movimiento_enemigo != null and not _b.pokemones_activos_enemigo.is_empty():
		acciones.append({"actor": _b.pokemones_activos_enemigo[0], "movimiento": _b.movimiento_enemigo, "objetivo": _b.accion_enemiga.get("target", null), "es_jugador": false})
	var movimiento_enemigo_secundario_elegido: Movimiento = _b.accion_enemiga_secundaria.get("move", null)
	if movimiento_enemigo_secundario_elegido is Movimiento and _b.pokemones_activos_enemigo.size() > 1:
		acciones.append({"actor": _b.pokemones_activos_enemigo[1], "movimiento": movimiento_enemigo_secundario_elegido, "objetivo": _b.accion_enemiga_secundaria.get("target", null), "es_jugador": false})
	# Cambios y objetos elegidos por la IA: sin movimiento, ese slot no ataca esta ronda.
	var acciones_rival: Array[Dictionary] = [_b.accion_enemiga, _b.accion_enemiga_secundaria]
	for slot_rival: int in mini(_b.pokemones_activos_enemigo.size(), 2):
		if str(acciones_rival[slot_rival].get("type", "")) == "switch" and acciones_rival[slot_rival].has("indice_equipo"):
			acciones.append({"actor": _b.pokemones_activos_enemigo[slot_rival], "tipo": "cambio", "indice_equipo": acciones_rival[slot_rival].indice_equipo, "es_jugador": false})
		elif str(acciones_rival[slot_rival].get("type", "")) == "item":
			acciones.append({"actor": _b.pokemones_activos_enemigo[slot_rival], "tipo": "objeto", "item_name": acciones_rival[slot_rival].item_name, "es_jugador": false})

	var rage_choices: Array=preload("res://scripts/battle/rage_rules.gd").choices(_b,acciones)
	# Pending actor permission is incarnation-bound; a selected target is BANK-bound.
	for accion in acciones:
		accion["source_actor_lease"]=_b.field_rules.capture(accion.get("actor",null))
		var selected: BasePokemon=accion.get("objetivo",null)
		if selected!=null:
			var selected_lease: Dictionary=_b.field_rules.capture(selected)
			if not selected_lease.is_empty():accion["source_target_bank"]=selected_lease.bank.duplicate(true)
		var rampage_move: Movimiento=BattleLockedMoveRules.at_use(_b,accion.get("actor",null),accion.get("movimiento",null))
		if rampage_move!=null and accion.has("movimiento"):accion["movimiento"]=rampage_move
		accion["desempate"] = randf()
	_b.habilidades.sortear_numero_turno()
	acciones.sort_custom(Callable(self, "_comparar_acciones_dobles"))
	_publicar_proyeccion_protect(acciones)
	if not await preload("res://scripts/battle/focus_punch_rules.gd").prepare(_b,acciones):return
	preload("res://scripts/battle/rage_rules.gd").reconcile_choices(_b,rage_choices)
	for indice_accion in range(acciones.size()):
		_acciones_restantes_dobles = acciones.slice(indice_accion + 1)
		for perseguida: Dictionary in acciones:
			if bool(perseguida.get("source_persecucion_consumida",false)):_acciones_restantes_dobles.erase(perseguida)
		var accion: Dictionary = acciones[indice_accion]
		var atacante: BasePokemon = accion.get("actor", null)
		var movimiento: Movimiento = accion.get("movimiento", null)
		if movimiento!=null:
			var forced_encore: Movimiento=preload("res://scripts/battle/encore_rules.gd").move(_b,atacante)
			if forced_encore!=null and not movimiento.has_meta("source_forced_struggle"):movimiento=forced_encore
		if bool(accion.get("source_persecucion_consumida",false)):
			continue
		if atacante == null or atacante.estad_ps_actual <= 0 or not _b.field_rules.valid(accion.get("source_actor_lease",{})):
			continue
		if str(accion.get("tipo", "")) == "objeto":
			# El del jugador ya se aplicó al confirmar; consume solo la acción de este slot.
			if accion.has("item_name"):await _ejecutar_accion_objeto_enemigo(accion,atacante)
			continue
		if str(accion.get("tipo", "")) == "cambio":
			var de_rival: bool=not bool(accion.get("es_jugador",false))
			var entry: Dictionary=await _b.resultado.cambiar_slot_doble(atacante, int(accion.get("indice_equipo", -1)))
			if entry.is_empty():return
			if de_rival:_marcar_rival_entro_a_mitad_de_ronda(entry.pokemon)
			continue
		if movimiento == null:
			continue
		var aliados: Array[BasePokemon] = _b.pokemones_activos_jugador if bool(accion.get("es_jugador", false)) else _b.pokemones_activos_enemigo
		var rivales: Array[BasePokemon] = _b.pokemones_activos_enemigo if bool(accion.get("es_jugador", false)) else _b.pokemones_activos_jugador
		var alcance := AlcanceMovimientoGen3.tipo(movimiento, _movimiento_apunta_al_usuario(movimiento))
		if movimiento.get_efecto() in ["EFFECT_RAMPAGE","EFFECT_UPROAR"]:alcance=AlcanceMovimientoGen3.RIVAL_ALEATORIO
		if not AlcanceMovimientoGen3.soportado(alcance):
			push_warning("[BATALLA] Movimiento sin objetivo doble soportado: %s" % movimiento.get_nombre_interno())
			continue
		var seleccion: BasePokemon = accion.get("objetivo", null)
		if accion.has("source_target_bank"):
			# Resolve once on admission, before policy/PP. Never follow during awaits.
			seleccion=_b.field_rules.occupant(accion.source_target_bank)
		var objetivos := AlcanceMovimientoGen3.objetivos(alcance, atacante, seleccion, aliados, rivales)
		if objetivos.is_empty():
			continue
		if preload("res://scripts/battle/torment_rules.gd").blocked(_b,atacante,movimiento):
			await _b.mostrar_texto_batalla("¡El tormento impide repetir ese movimiento!");continue
		if await _consumir_recarga_source(atacante):continue
		var rampage_phase: Dictionary=_capturar_fase_movimiento(atacante,movimiento)
		var original_pp_move: Movimiento=movimiento
		movimiento=_movimiento_admitido(rampage_phase,movimiento)
		objetivos=preload("res://scripts/battle/thought_finger_rules.gd").redirect(_b,atacante,movimiento,objetivos)
		_source_objetivos_chequeo=objetivos
		var chequeo_estado := _evaluar_accion_antes_de_moverse(atacante,movimiento)
		await _presentar_chequeo(chequeo_estado, atacante)
		var check_outcome: Dictionary=chequeo_estado.get("source_check_outcome",{})
		if str(check_outcome.get("status","aborted"))=="aborted":return
		if str(check_outcome.status)=="owned_self_ko":
			if not _consume_owned_self_ko(check_outcome,rampage_phase):return
			if not await _presentar_debilitados_dobles():return
			continue
		if _fase_protegida(movimiento,rampage_phase) and not _fase_rampage_vigente(movimiento,rampage_phase):return
		if not bool(chequeo_estado.get("puede_actuar", true)):
			_finalizar_turno_no_actuado(rampage_phase,chequeo_estado)
			continue
		if not _fase_rampage_vigente(movimiento,rampage_phase):
			if _fase_protegida(movimiento,rampage_phase):return
			continue
		if chequeo_estado.has("source_movimiento_desobediente"):
			# GetMoveTarget(gRandomMove,0): the ordered target does not carry over.
			var aleatorio: Movimiento=chequeo_estado.source_movimiento_desobediente
			var elegido: Movimiento=movimiento
			original_pp_move=aleatorio
			rampage_phase=_fase_movimiento_desobediente(atacante,elegido,aleatorio)
			movimiento=_movimiento_admitido(rampage_phase,aleatorio)
			alcance=AlcanceMovimientoGen3.tipo(movimiento,_movimiento_apunta_al_usuario(movimiento))
			if movimiento.get_efecto() in ["EFFECT_RAMPAGE","EFFECT_UPROAR"]:alcance=AlcanceMovimientoGen3.RIVAL_ALEATORIO
			objetivos=AlcanceMovimientoGen3.objetivos(alcance,atacante,null,aliados,rivales) if AlcanceMovimientoGen3.soportado(alcance) else [] as Array[BasePokemon]
			objetivos=preload("res://scripts/battle/thought_finger_rules.gd").redirect(_b,atacante,movimiento,objetivos)
			if objetivos.is_empty():
				_finalizar_resultado_source(rampage_phase,"unable")
				continue
		if not _consumir_pp_fase_i3(movimiento,original_pp_move,rampage_phase,atacante,objetivos):
			await _b.mostrar_texto_batalla("¡No quedan PP para este movimiento!")
			_finalizar_resultado_source(rampage_phase,"exhausted_pp")
			if _fase_protegida(movimiento,rampage_phase) and not _fase_rampage_vigente(movimiento,rampage_phase):return
			continue
		if not _turno_bide_pendiente(atacante) and not preload("res://scripts/battle/focus_punch_rules.gd").failed(_b,atacante,movimiento):await _b.mostrar_texto_batalla("¡%s usó\n%s!" % [atacante.get_nombre_combate(), movimiento.nombre])
		if not _fase_rampage_vigente(movimiento,rampage_phase):
			if _fase_protegida(movimiento,rampage_phase):return
			continue
		# PARARRAYOS desvía los movimientos eléctricos de un solo objetivo.
		if objetivos.size() == 1:
			var desvio := HabilidadesCombate.redirigir_ataque_electrico(atacante, objetivos[0], movimiento, _b.habilidades.crear_campo())
			if desvio != null:
				objetivos.clear()
				objetivos.append(desvio)
				await _b.mostrar_texto_batalla(HabilidadesCombate.mensaje_pararrayos(desvio))
		var dos_rivales := 0
		for rival in rivales:
			if rival != null and rival.estad_ps_actual > 0:
				dos_rivales += 1
		var resolved: BattleMoveAction=await _resolver_accion_objetivos(movimiento, atacante, objetivos, alcance == AlcanceMovimientoGen3.AMBOS_RIVALES and dos_rivales == 2,true,rampage_phase)
		if resolved.phase in ["entry_aborted","counter_aborted"]:return
		if not await _presentar_debilitados_dobles():return

	_b.contador_turnos += 1
	if not await _b._procesar_fin_de_ronda(): return
	if await _verificar_fin_batalla_doble():
		return
	_movimientos_dobles_limpieza()
	_b.fase_input()


func _comparar_acciones_dobles(a: Dictionary, b: Dictionary) -> bool:
	var clase_a := 0 if a.has("tipo") else 1
	var clase_b := 0 if b.has("tipo") else 1
	if clase_a != clase_b:
		return clase_a < clase_b
	var movimiento_a: Movimiento = a.get("movimiento", null)
	var movimiento_b: Movimiento = b.get("movimiento", null)
	var prioridad_a := BattleProtectRules.source_priority(movimiento_a)
	var prioridad_b := BattleProtectRules.source_priority(movimiento_b)
	if prioridad_a != prioridad_b:
		return prioridad_a > prioridad_b
	var actor_a: BasePokemon = a.get("actor", null)
	var actor_b: BasePokemon = b.get("actor", null)
	var velocidad_a: int = _b.habilidades.velocidad_de(actor_a)
	var velocidad_b: int = _b.habilidades.velocidad_de(actor_b)
	if velocidad_a != velocidad_b:
		return velocidad_a > velocidad_b
	return float(a.get("desempate", 0.0)) < float(b.get("desempate", 0.0))


func _obtener_objetivo_doble(atacante: BasePokemon) -> BasePokemon:
	var objetivos: Array[BasePokemon] = _b.pokemones_activos_enemigo if _b.pokemones_activos_jugador.has(atacante) else _b.pokemones_activos_jugador
	for objetivo in objetivos:
		if objetivo != null and objetivo.estad_ps_actual > 0:
			return objetivo
	return null


## Gasta 1 PP, más 1 por cada objetivo con PRESIÓN (PressurePPLose / ppToDeduct);
## los movimientos que apuntan al usuario no se ven afectados.
func _consumir_pp_movimiento(movimiento: Movimiento, atacante: BasePokemon = null, objetivos: Array = []) -> bool:
	if movimiento == null:
		return false
	# Ruby attackcanceler excludes Struggle and already accepted multiple-turn
	# actions. A visual key is not authority to bypass exhausted gameplay PP.
	if int(movimiento.datos.get("numero_movimiento",0))==165:return true
	if _pendiente(atacante) != null: return true
	if BattleLockedMoveRules.move(_b,atacante)==movimiento:return true
	if movimiento.pp_act<=0 and movimiento.get_nombre_interno() not in ["COMBATE","STRUGGLE"]:return false
	var coste := 1
	if atacante!=null and movimiento.get_efecto()=="EFFECT_SPIKES":
		coste+=_b.field_rules.pressure(atacante)
	elif atacante!=null and preload("res://scripts/battle/sleep_talk_rules.gd").supports(movimiento):
		# Sleep Talk pays at its initial SPECIAL bank, not its later called target.
		var initial: BasePokemon=preload("res://scripts/battle/sleep_talk_rules.gd").pp_target(_b,atacante)
		if initial!=null:coste+=HabilidadesCombate.pp_extra_por_presion(atacante,[initial])
	elif atacante != null and not _movimiento_apunta_al_usuario(movimiento):
		coste += HabilidadesCombate.pp_extra_por_presion(atacante, objetivos)
	movimiento.pp_act = maxi(0, movimiento.pp_act - coste)
	return true


func _movimientos_dobles_limpieza() -> void:
	_b.movimiento_jugador = null
	_b.movimiento_jugador_primario_doble = null
	_b.movimiento_jugador_secundario = null
	_b.movimiento_enemigo = null
	_b.accion_enemiga = {}
	_b.accion_enemiga_secundaria = {}
	_b.slot_jugador_seleccionado = 0
	_b.objetivo_jugador_primario_doble = null
	_b.objetivo_jugador_secundario_doble = null
	_b.seleccionando_objetivo_doble = false
	_b.objetivos_doble.clear()
	_acciones_jugador_no_movimiento.clear()
	_acciones_restantes_dobles.clear()
	_b.slot_rival.marcar_objetivo(false)
	_b.slot_rival_secundario.marcar_objetivo(false)


## Lifetime context only: never carry the first entrant's transfer snapshot here.
func verificar_entradas_baton(flow: Dictionary) -> bool:
	_baton_entry_flow=flow
	return await _verificar_fin_batalla_doble()


## tryfaintmon dentro del turno: caída y mensaje. EXP, atk24 y relevos esperan a
## HandleFaintedMonActions, tras los residuales (settle_end_round_faints).
func _presentar_debilitados_dobles() -> bool:
	var rules: BattleFieldEffects=_b.field_rules
	var retiring: Array=[]
	for pokemon: BasePokemon in _b.pokemones_activos_jugador+_b.pokemones_activos_enemigo:
		if pokemon!=null and pokemon.estad_ps_actual<=0:retiring.append(pokemon)
	var flow: Dictionary=rules.capture_flow(retiring)
	if not rules.valid_flow(flow):return false
	_b.resultado.registrar_debilitados_jugador()
	await _b.resultado.presentar_debilitados_dobles()
	return rules.valid_flow(flow)


func _verificar_fin_batalla_doble() -> bool:
	return await _resolver_relevos_dobles(false)


## anidado: BattleScript_SpikesOngBank1Fainted reentra en HandleFaintedMon por ese banco;
## el caso 6 de HandleFaintedMonActions (diferidas y objeto del banco 0) queda para quien llamó.
func _resolver_relevos_dobles(anidado: bool) -> bool:
	var rules: BattleFieldEffects=_b.field_rules
	if not _baton_entry_flow.is_empty() and not rules.valid_flow(_baton_entry_flow):return true
	var retiring: Array=[]
	for pokemon: BasePokemon in _b.pokemones_activos_jugador+_b.pokemones_activos_enemigo:
		if pokemon!=null and pokemon.estad_ps_actual<=0:retiring.append(pokemon)
	var flow: Dictionary=rules.capture_flow(retiring)
	if not rules.valid_flow(flow):return true
	_b.resultado.registrar_debilitados_jugador()
	# Procesar KOs antes de reponer: sin esto los residuales y los golpes en
	# área descartan la EXP de secundarios. El estado DEBILITADO evita duplicados.
	for rival in _b.pokemones_activos_enemigo:
		if rival != null and rival.estad_ps_actual <= 0 and _b.resultado._enemigo_sin_procesar(rival):
			await _b.resultado._procesar_pokemon_enemigo_debilitado(rival)
			if not rules.valid_flow(flow) or (not _baton_entry_flow.is_empty() and not rules.valid_flow(_baton_entry_flow)):return true
	if not _equipo_tiene_pokemon_utilizable(_b.equipo_jugador_pokemones):
		await _b.resultado.mostrar_resultado_derrota()
		return true
	if not _equipo_tiene_pokemon_utilizable(_b.equipo_enemigo_pokemones):
		await _b.resultado.mostrar_resultado_victoria()
		return true
	var elecciones: Dictionary = await _b.resultado.elegir_relevos_dobles_jugador(flow)
	if not rules.valid_flow(flow) or (not _baton_entry_flow.is_empty() and not rules.valid_flow(_baton_entry_flow)):return true
	if not is_instance_valid(_b) or not _b.is_inside_tree() or _b.fase==_b.FIN_BATALLA:return true
	_b._reponer_slots_dobles(elecciones)
	# Synchronous ownership transfer: bind every successor before entry yields.
	var successor_flow: Dictionary=_capturar_flujo_relevos()
	var item_tail: Dictionary=preload("res://scripts/battle/held_status_berry_rules.gd").capture_tail(_b,successor_flow)
	var flujos: Array[Dictionary]=_flujos_relevos(flow,successor_flow)
	var envios: Array[Dictionary]=_b.envios_dobles_pendientes.duplicate()
	_b.envios_dobles_pendientes.clear()
	# HandleFaintedMonActions caso 4: ball y switchineffects de un banco antes del siguiente.
	for envio: Dictionary in envios:
		if not await _b.resultado.presentar_envio_doble(envio,flujos):return true
		var pokemon_envio: BasePokemon=envio.pokemon
		var entry: Dictionary=_registro_de(successor_flow,pokemon_envio)
		if not await _b.habilidades.al_entrar(pokemon_envio,true,entry,false,true):return true
		if not rules.valid_flow(flow) or not rules.valid_flow(successor_flow) or (not _baton_entry_flow.is_empty() and not rules.valid_flow(_baton_entry_flow)):return true
		if not is_instance_valid(_b) or not _b.is_inside_tree() or _b.fase==_b.FIN_BATALLA:return true
		if pokemon_envio.estad_ps_actual>0:continue
		# tryfaintmon y HandleFaintedMon de este banco, antes de pasar al siguiente.
		if not await _presentar_debilitados_dobles():return true
		if await _resolver_relevos_dobles(true):return true
		flow=rules.capture_flow()
		successor_flow=_capturar_flujo_relevos()
		item_tail=preload("res://scripts/battle/held_status_berry_rules.gd").capture_tail(_b,successor_flow)
		flujos=_flujos_relevos(flow,successor_flow)
	if anidado:return false
	if not await _b.habilidades.presentar_entradas_diferidas(flujos):return true
	if not is_instance_valid(_b) or not _b.is_inside_tree() or _b.fase==_b.FIN_BATALLA:return true
	# The pre-entry party check cannot authorize INPUT after a lethal hazard.
	# Each recursive pass consumes a finite reserve or reaches a final result.
	for pokemon: BasePokemon in _b.pokemones_activos_jugador+_b.pokemones_activos_enemigo:
		if pokemon!=null and pokemon.estad_ps_actual<=0:return await _verificar_fin_batalla_doble()
	return not await preload("res://scripts/battle/held_status_berry_rules.gd").settle_tail(_b,item_tail)


## Every freshly accepted recursive entry carries ownership, not transferred state.
func _capturar_flujo_relevos() -> Dictionary:
	var successor_flow: Dictionary=_b.field_rules.capture_flow()
	if not _baton_entry_flow.is_empty():
		for entry: Dictionary in successor_flow.records:entry["source_baton_unaffected_flow"]=_baton_entry_flow
	return successor_flow


func _flujos_relevos(flow: Dictionary,successor_flow: Dictionary) -> Array[Dictionary]:
	var flujos: Array[Dictionary]=[flow,successor_flow]
	if not _baton_entry_flow.is_empty():flujos.append(_baton_entry_flow)
	return flujos


func _registro_de(flow: Dictionary,pokemon: BasePokemon) -> Dictionary:
	for record: Dictionary in flow.records:
		if record.pokemon==pokemon:return record
	return {}


func _equipo_tiene_pokemon_utilizable(equipo: Array[BasePokemon]) -> bool:
	for pokemon in equipo:
		if pokemon != null and pokemon.puede_combatir():
			return true
	return false


func verificar_prioridad():
	var rage_choices: Array=preload("res://scripts/battle/rage_rules.gd").choices(_b,[{"actor":_b.poke_jugador,"movimiento":_b.movimiento_jugador},{"actor":_b.poke_enemigo,"movimiento":_b.movimiento_enemigo if str(_b.accion_enemiga.get("type","attack"))=="attack" else null}])
	var player_lock: Movimiento=BattleLockedMoveRules.at_use(_b,_b.poke_jugador,_b.movimiento_jugador)
	if player_lock!=null:_b.movimiento_jugador=player_lock
	_aplicar_bloqueo_enemigo()
	_publicar_proyeccion_protect()
	if not await preload("res://scripts/battle/focus_punch_rules.gd").prepare(_b,[{"actor":_b.poke_jugador,"movimiento":_b.movimiento_jugador},{"actor":_b.poke_enemigo,"movimiento":_b.movimiento_enemigo}]):return
	preload("res://scripts/battle/rage_rules.gd").reconcile_choices(_b,rage_choices)
	_b.habilidades.sortear_numero_turno()
	if _b.habilidades.golpea_primero(_b.poke_jugador,_b.poke_enemigo,BattleProtectRules.source_priority(_b.movimiento_jugador),_get_prioridad_accion_enemiga()):
		# El jugador ataca primero
		_b.fases.cambiar_fase_ronda(MaquinaEstadosBatalla.FaseRonda.TURNO_JUGADOR)
	else:
		# El enemigo ataca primero
		_b.fases.cambiar_fase_ronda(MaquinaEstadosBatalla.FaseRonda.TURNO_ENEMIGO)
	ejecutar_ronda()


## Un bloqueo de varios turnos sustituye cualquier acción; Otra Vez, solo el movimiento.
func _aplicar_bloqueo_enemigo() -> void:
	var locked_move: Movimiento=BattleLockedMoveRules.at_use(_b,_b.poke_enemigo,_b.movimiento_enemigo)
	if locked_move==null:return
	if str(_b.accion_enemiga.get("type","attack"))!="attack" and preload("res://scripts/battle/encore_rules.gd").move(_b,_b.poke_enemigo)==locked_move:return
	_b.movimiento_enemigo=locked_move
	_b.accion_enemiga={"type":"attack","move":locked_move}


func _get_prioridad_accion_enemiga() -> int:
	match str(_b.accion_enemiga.get("type", "attack")):
		"switch":
			return 6
		"item":
			return 5
		"flee":
			return 0  # B_ACTION_RUN de la IA: sin prioridad de movimiento, por velocidad
		_:
			return BattleProtectRules.source_priority(_b.movimiento_enemigo)


func turno_jugador():
	var actor: BasePokemon=_b.poke_jugador
	if await _consumir_recarga_source(actor):
		_b.turno_jugador_pasado=true;_b.fases.cambiar_fase_ronda(MaquinaEstadosBatalla.FaseRonda.REVISAR_RONDA);ejecutar_ronda();return
	var locked_move: Movimiento=BattleLockedMoveRules.at_use(_b,actor,_b.movimiento_jugador)
	if locked_move!=null:_b.movimiento_jugador=locked_move
	var accepted_move: Movimiento=_b.movimiento_jugador
	# Selection rejection is NOT an attempted action: preserve gLastMoves and PP.
	if preload("res://scripts/battle/torment_rules.gd").blocked(_b,actor,accepted_move):
		await _b.mostrar_texto_batalla("¡El tormento impide repetir ese movimiento!")
		_b.turno_jugador_pasado=true;_b.fases.cambiar_fase_ronda(MaquinaEstadosBatalla.FaseRonda.REVISAR_RONDA);ejecutar_ronda();return
	var rampage_phase: Dictionary=_capturar_fase_movimiento(actor,accepted_move)
	var original_pp_move: Movimiento=accepted_move
	accepted_move=_movimiento_admitido(rampage_phase,accepted_move)
	_source_objetivos_chequeo=[_b.poke_enemigo]
	var chequeo_estado = _evaluar_accion_antes_de_moverse(actor,accepted_move)
	await _presentar_chequeo(chequeo_estado, actor)
	var check_outcome: Dictionary=chequeo_estado.get("source_check_outcome",{})
	if str(check_outcome.get("status","aborted"))=="aborted":return
	if str(check_outcome.status)=="owned_self_ko":
		if _consume_owned_self_ko(check_outcome,rampage_phase):_close_single_self_ko()
		return
	if _fase_protegida(accepted_move,rampage_phase) and not _fase_rampage_vigente(accepted_move,rampage_phase):return
	if not bool(chequeo_estado.get("puede_actuar", true)) or not _fase_rampage_vigente(accepted_move,rampage_phase):
		_finalizar_turno_no_actuado(rampage_phase,chequeo_estado)
		_b.turno_jugador_pasado = true
		_b.fases.cambiar_fase_ronda(MaquinaEstadosBatalla.FaseRonda.REVISAR_RONDA)
		ejecutar_ronda()
		return
	if chequeo_estado.has("source_movimiento_desobediente"):
		var aleatorio: Movimiento=chequeo_estado.source_movimiento_desobediente
		var elegido: Movimiento=accepted_move
		original_pp_move=aleatorio
		rampage_phase=_fase_movimiento_desobediente(actor,elegido,aleatorio)
		accepted_move=_movimiento_admitido(rampage_phase,aleatorio)

	# Restar PP al movimiento seleccionado (PRESIÓN del rival cuesta 1 más)
	var targets: Array[BasePokemon]=_objetivos_rampage(accepted_move,actor,[_b.poke_enemigo])
	if not _consumir_pp_fase_i3(accepted_move,original_pp_move,rampage_phase,actor,targets):
		await _b.mostrar_texto_batalla("¡No quedan PP para este movimiento!")
		_finalizar_resultado_source(rampage_phase,"exhausted_pp")
		if _fase_protegida(accepted_move,rampage_phase) and not _fase_rampage_vigente(accepted_move,rampage_phase):return
		_b.turno_jugador_pasado = true
		_b.fases.cambiar_fase_ronda(MaquinaEstadosBatalla.FaseRonda.REVISAR_RONDA)
		ejecutar_ronda()
		return
	_b.presentacion.menu_movs.set_movs(_movimientos_en_campo(_b.poke_jugador))

	# Mostrar mensaje de movimiento usando el sistema de velocidad
	if not _turno_bide_pendiente(actor) and not preload("res://scripts/battle/focus_punch_rules.gd").failed(_b,actor,accepted_move):await _b.mostrar_texto_batalla("¡%s usó\n%s!" % [actor.get_nombre_combate(), accepted_move.nombre])
	if _fase_protegida(accepted_move,rampage_phase) and not _fase_rampage_vigente(accepted_move,rampage_phase):return
	if _fase_rampage_vigente(accepted_move,rampage_phase):
		var resolved: BattleMoveAction=await _resolver_accion_objetivos(accepted_move, actor, targets,false,true,rampage_phase)
		if resolved.phase in ["entry_aborted","counter_aborted"]:return
	if _b.fase == _b.FIN_BATALLA:
		return  # REMOLINO / RUGIDO echaron al salvaje: la batalla ya terminó

	_b.turno_jugador_pasado = true
	_b.fases.cambiar_fase_ronda(MaquinaEstadosBatalla.FaseRonda.REVISAR_RONDA)
	ejecutar_ronda()


func turno_enemigo():
	var actor: BasePokemon=_b.poke_enemigo
	_aplicar_bloqueo_enemigo()
	match str(_b.accion_enemiga.get("type", "attack")):
		"flee":
			await _b.huida_rival_salvaje()
			return
		"item":
			if await _ejecutar_accion_objeto_enemigo(_b.accion_enemiga):
				_finalizar_turno_enemigo()
				return
			_establecer_accion_enemiga_seleccionada(_crear_accion_enemiga_respaldo())
		"switch":
			var switched: Dictionary=await _ejecutar_accion_cambio_enemigo(_b.accion_enemiga)
			if switched.is_empty():return # Aborted, not an unavailable AI choice.
			if not switched.has("unavailable"):
				_finalizar_turno_enemigo()
				return
			_establecer_accion_enemiga_seleccionada(_crear_accion_enemiga_respaldo())

	# Verificar que el movimiento enemigo sea válido
	if _b.movimiento_enemigo == null:
		print("❌ Error: No hay movimiento enemigo válido")
		_finalizar_turno_enemigo()
		return

	if await _consumir_recarga_source(actor):_finalizar_turno_enemigo();return
	var accepted_move: Movimiento=_b.movimiento_enemigo
	if preload("res://scripts/battle/torment_rules.gd").blocked(_b,actor,accepted_move):
		await _b.mostrar_texto_batalla("¡El tormento impide repetir ese movimiento!")
		_finalizar_turno_enemigo();return
	var rampage_phase: Dictionary=_capturar_fase_movimiento(actor,accepted_move)
	var original_pp_move: Movimiento=accepted_move
	accepted_move=_movimiento_admitido(rampage_phase,accepted_move)
	var chequeo_estado = _evaluar_accion_antes_de_moverse(actor,accepted_move)
	await _presentar_chequeo(chequeo_estado, actor)
	var check_outcome: Dictionary=chequeo_estado.get("source_check_outcome",{})
	if str(check_outcome.get("status","aborted"))=="aborted":return
	if str(check_outcome.status)=="owned_self_ko":
		if _consume_owned_self_ko(check_outcome,rampage_phase):_close_single_self_ko()
		return
	if _fase_protegida(accepted_move,rampage_phase) and not _fase_rampage_vigente(accepted_move,rampage_phase):return
	if not bool(chequeo_estado.get("puede_actuar", true)) or not _fase_rampage_vigente(accepted_move,rampage_phase):
		_finalizar_resultado_source(rampage_phase,"unable")
		_finalizar_turno_enemigo()
		return

	# Restar PP al movimiento seleccionado (PRESIÓN del rival cuesta 1 más)
	var targets: Array[BasePokemon]=_objetivos_rampage(accepted_move,actor,[_b.poke_jugador])
	if not _consumir_pp_fase_i3(accepted_move,original_pp_move,rampage_phase,actor,targets):
		await _b.mostrar_texto_batalla("¡No quedan PP para este movimiento!")
		_finalizar_resultado_source(rampage_phase,"exhausted_pp")
		if _fase_protegida(accepted_move,rampage_phase) and not _fase_rampage_vigente(accepted_move,rampage_phase):return
		_finalizar_turno_enemigo()
		return

	if not _turno_bide_pendiente(actor) and not preload("res://scripts/battle/focus_punch_rules.gd").failed(_b,actor,accepted_move):await _b.mostrar_texto_batalla("¡%s usó\n%s!" % [actor.get_nombre_combate(), accepted_move.nombre])
	if _fase_protegida(accepted_move,rampage_phase) and not _fase_rampage_vigente(accepted_move,rampage_phase):return
	if _fase_rampage_vigente(accepted_move,rampage_phase):
		var resolved: BattleMoveAction=await _resolver_accion_objetivos(accepted_move, actor, targets,false,true,rampage_phase)
		if resolved.phase in ["entry_aborted","counter_aborted"]:return
	if _b.fase == _b.FIN_BATALLA:
		return

	_finalizar_turno_enemigo()


func _sortear_spite() -> int:return randi()
func _sortear_conversion() -> int:return randi()

func _movimiento_admitido(phase: Dictionary,move: Movimiento) -> Movimiento:
	move=preload("res://scripts/battle/fixed_damage_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/doom_desire_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/rage_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/hidden_power_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/retaliation_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/grudge_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/magic_coat_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/role_play_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/recycle_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/destiny_bond_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/charge_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/spite_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/conversion_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/mimic_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/teleport_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/mist_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/psych_up_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/refresh_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/perish_song_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/focus_energy_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/focus_punch_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/snatch_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/turn_trap_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/helping_hand_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/mirror_move_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/pound_tackle_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/sketch_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/memento_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/superpower_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/extreme_speed_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/extrasensory_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/camouflage_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/weather_ball_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/uproar_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/whirlwind_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/pay_day_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/sleep_talk_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/assist_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/nature_power_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/present_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/magnitude_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/hp_burst_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/variable_power_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/faint_attack_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/seismic_toss_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/recharge_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/guillotine_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/fissure_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/bonemerang_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/yawn_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/smelling_salt_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/pain_split_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/party_status_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/flatter_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/dragon_dance_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/torment_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/encore_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/celestial_heal_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/self_heal_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/kinesis_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/disable_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/smokescreen_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/spikes_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/barrage_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/rock_tomb_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/flame_wheel_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/baton_pass_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/overheat_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/outrage_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/psycho_boost_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/tail_glow_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/cosmic_power_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/belly_drum_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/teeter_dance_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/haze_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/mist_ball_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/luster_purge_rules.gd").accepted_move(phase,move)
	move=BattleHeldItemRules.accepted_move(phase,move)
	move=BattleHealingStreamRules.accepted_move(phase,move)
	move=BattleDustWeatherRules.accepted_move(phase,move)
	move=preload("res://scripts/battle/thought_finger_rules.gd").accepted_move(phase,move)
	move=preload("res://scripts/battle/ice_rules.gd").accepted_move(phase,move)
	var accepted: Movimiento=BattleWindFeatherRules.accepted_move(phase,move)
	accepted=BattleSafeguardRules.accepted_move(phase,accepted)
	accepted=BattleHiddenActorRules.accepted_move(phase,accepted)
	accepted=preload("res://scripts/battle/elemental_punch_rules.gd").accepted_move(phase,accepted)
	accepted=preload("res://scripts/battle/poison_gas_rules.gd").accepted_move(phase,accepted)
	accepted=preload("res://scripts/battle/flash_rules.gd").accepted_move(phase,accepted)
	accepted=BattleSureHitRules.accepted_move(phase,accepted)
	accepted=BattleIdentifiedRules.accepted_move(phase,accepted)
	accepted=preload("res://scripts/battle/heart_rules.gd").accepted_move(phase,accepted)
	accepted=preload("res://scripts/battle/tears_tickle_rules.gd").accepted_move(phase,accepted)
	accepted=preload("res://scripts/battle/kiss_attract_rules.gd").accepted_move(phase,accepted)
	accepted=preload("res://scripts/battle/curse_nightmare_rules.gd").accepted_move(phase,accepted)
	accepted=preload("res://scripts/battle/imprison_rules.gd").accepted_move(phase,accepted)
	accepted=preload("res://scripts/battle/skill_swap_rules.gd").accepted_move(phase,accepted)
	accepted=preload("res://scripts/battle/trick_rules.gd").accepted_move(phase,accepted)
	accepted=preload("res://scripts/battle/startle_rules.gd").accepted_move(phase,accepted)
	accepted=preload("res://scripts/battle/lovely_kiss_rules.gd").accepted_move(phase,accepted)
	accepted=preload("res://scripts/battle/fire_blast_rules.gd").accepted_move(phase,accepted)
	accepted=preload("res://scripts/battle/sludge_rules.gd").accepted_move(phase,accepted)
	accepted=preload("res://scripts/battle/acid_rules.gd").accepted_move(phase,accepted)
	accepted=preload("res://scripts/battle/aurora_rules.gd").accepted_move(phase,accepted)
	accepted=BattleProtectRules.accepted_move(phase,accepted)
	return BattleSportRules.accepted_move(phase,accepted)

func _consumir_pp_fase_i3(move: Movimiento,original: Movimiento,phase: Dictionary,actor: BasePokemon,targets: Array[BasePokemon]) -> bool:
	if move.pp_act>0:preload("res://scripts/battle/rage_rules.gd").primary(self,_b,move,phase,actor,targets)
	if preload("res://scripts/battle/whirlwind_rules.gd").supports(move) and targets.size()==1:phase.source_forced_target=_b.field_rules.capture(targets[0])
	if phase.has("source_nature_power"):
		phase.source_nature_power_pp_owner=original;return original.pp_act>0
	if phase.has("source_mirror_move"):
		phase.source_mirror_pp_owner=original;return original.pp_act>0
	if phase.has("source_assist"):
		# Assist chooses/animates first; the called script pays this original slot.
		phase.source_assist_pp_owner=original
		return original.pp_act>0
	if preload("res://scripts/battle/retaliation_rules.gd").supports(move):
		var fact: Dictionary=preload("res://scripts/battle/retaliation_rules.gd").prepare(_b,actor,move,phase)
		if not preload("res://scripts/battle/retaliation_rules.gd").live(_b,fact):return false
		targets.assign(preload("res://scripts/battle/retaliation_rules.gd").targets(fact,actor))
	var accepted: bool=_consumir_pp_movimiento(move,actor,targets)
	# A forced hidden continuation pays/synchronizes its captured party move,
	# never the alternative move the caller selected for this locked turn.
	if phase.has("source_i4"):original=phase.source_i4.original()
	# Policy reads the immutable admitted move; the party move owns accepted PP.
	if phase.has("source_fixed_damage") or phase.has("source_doom_desire") or phase.has("source_rage") or phase.has("source_hidden_power") or phase.has("source_retaliation") or phase.has("source_grudge") or phase.has("source_recycle") or phase.has("source_magic_coat_policy") or phase.has("source_role_play") or phase.has("source_charge") or phase.has("source_destiny_bond") or phase.has("source_spite") or phase.has("source_conversion") or phase.has("source_mimic") or phase.has("source_teleport") or phase.has("source_mist") or phase.has("source_psych_up") or phase.has("source_refresh_move") or phase.has("source_perish_song") or phase.has("source_focus_energy") or phase.has("source_focus_punch") or phase.has("source_snatch") or phase.has("source_turn_trap") or phase.has("source_helping_hand") or phase.has("source_pound_tackle") or phase.has("source_sketch") or phase.has("source_sleep_talk") or phase.has("source_pay_day") or phase.has("source_whirlwind") or phase.has("source_present") or phase.has("source_variable_power") or phase.has("source_magnitude") or phase.has("source_seismic_toss") or phase.has("source_recharge") or phase.has("source_guillotine") or phase.has("source_party_cure") or phase.has("source_memento") or phase.has("source_superpower") or phase.has("source_extreme_speed") or phase.has("source_extrasensory") or phase.has("source_camouflage") or phase.has("source_weather_ball") or phase.has("source_uproar") or phase.has("source_hp_burst") or phase.has("source_faint_attack") or phase.has("source_fissure") or phase.has("source_bonemerang") or phase.has("source_yawn") or phase.has("source_smelling_salt") or phase.has("source_pain_split") or phase.has("source_flatter") or phase.has("source_torment") or phase.has("source_encore") or phase.has("source_celestial_heal") or phase.has("source_self_heal") or phase.has("source_kinesis") or phase.has("source_disable") or phase.has("source_smokescreen") or phase.has("source_spikes") or phase.has("source_barrage") or phase.has("source_rock_tomb") or phase.has("source_flame_wheel") or phase.has("source_baton_pass") or phase.has("source_i3") or phase.has("source_i4") or phase.has("source_safeguard") or phase.has("source_elemental_punch") or phase.has("source_poison_gas") or phase.has("source_flash") or phase.has("source_protect") or phase.has("source_sport") or phase.has("source_aurora") or phase.has("source_acid") or phase.has("source_sludge") or phase.has("source_fire_blast") or phase.has("source_sure_hit") or phase.has("source_identified") or phase.has("source_heart") or phase.has("source_tears_tickle") or phase.has("source_kiss_attract") or phase.has("source_lovely_kiss") or phase.has("source_startle") or phase.has("source_trick") or phase.has("source_skill_swap") or phase.has("source_imprison") or phase.has("source_curse_nightmare") or phase.has("source_ice") or phase.has("source_thought_finger") or phase.has("source_luster_purge") or phase.has("source_mist_ball") or phase.has("source_haze") or phase.has("source_teeter_dance") or phase.has("source_belly_drum") or phase.has("source_overheat") or phase.has("source_outrage") or phase.has("source_psycho_boost") or phase.has("source_tail_glow") or phase.has("source_cosmic_power") or phase.has("source_dragon_dance") or phase.has("source_held_item") or phase.has("source_healing_stream") or phase.has("source_dust_weather"):original.pp_act=move.pp_act
	return accepted

func _capturar_fase_movimiento(actor: BasePokemon,movimiento: Movimiento) -> Dictionary:
	var phase: Dictionary={}
	var pending: PendingMoveContinuation=_pendiente(actor)
	if (pending!=null and pending.source_i4!=null) or BattleScreenRules.phase_supported(movimiento):phase=BattleScreenRules.capture_phase(_b,actor,movimiento)
	elif movimiento!=null and movimiento.get_efecto() in ["EFFECT_RAMPAGE","EFFECT_UPROAR"]:phase=BattleRampageRules.capture(_b,actor)
	else:phase=BattleCounterRules.capture_phase(_b,actor,movimiento)
	if phase.has("source_mimic"):
		phase.source_mimic.slot=_movimientos_en_campo(actor).find(movimiento);phase.source_mimic.original=movimiento
	if phase.has("source_sketch"):
		phase.source_sketch.slot=actor.movimientos.find(movimiento);phase.source_sketch.original=movimiento
	phase["source_rage_flow"]=_b.field_rules.capture_flow()
	phase["source_body_admission"]=_b.bank_damage_history.admit()
	# Receipt follows the same immutable actual policy as execution, not its PP owner.
	var receipt_move: Movimiento=_movimiento_admitido(phase,movimiento)
	phase["source_protect_receipt"]=preload("res://scripts/battle/bank_damage_history.gd").capture(receipt_move,phase)
	phase["source_grudge_selected_slot"]=preload("res://scripts/battle/grudge_rules.gd").selected_slot(_b,actor,movimiento)
	phase["source_status_items"]=preload("res://scripts/battle/held_status_berry_rules.gd").admission(_b)
	phase["source_result_ticket"]=BattleProtectRules.capture_result(_b,actor,movimiento)
	if preload("res://scripts/battle/magic_coat_rules.gd").supports(movimiento) or preload("res://scripts/battle/snatch_rules.gd").supports(movimiento) or not BattleProtectRules.mode(movimiento).is_empty():
		_asegurar_proyeccion_protect()
		var bank: int=_b.field_rules.source_bank(_b.field_rules.position(actor))
		for fact: Dictionary in get_meta("source_protect_projection",[]):
			if int(fact.bank)==bank:phase["source_protect_fact"]=fact.duplicate(true)
	return phase

func _publicar_proyeccion_protect(actions: Array[Dictionary]=[],player_nonmove: String="") -> void:
	set_meta("source_protect_projection",BattleProtectRules.native_slots(_b,actions,player_nonmove))
	set_meta("source_protect_projection_flow",_b.field_rules.capture_flow())
func _asegurar_proyeccion_protect() -> void:
	# Positional facts survive operation-owned KO/switches. Occupant permission
	# belongs to the separate before-await action lease, never this scalar ledger.
	var original: Dictionary=get_meta("source_protect_projection_flow",{})
	var current: Dictionary=_b.field_rules.capture_flow()
	if original.is_empty() or current.is_empty() or original.round!=current.round or original.lifetime!=current.lifetime:_publicar_proyeccion_protect()
func _begin_source_move_results() -> int:
	# HandleAction_UseMove / per-target movevaluescleanup, not ActionFinished.
	_source_result_generation+=1
	_source_no_effect_flags=0
	return _source_result_generation

func _record_source_move_results(action: BattleMoveAction) -> void:
	var flags: int=int(action.get_meta("source_rage_result_flags",0))&0x29
	# Consume actual native outcomes, not chosen/caller history or damage freshness.
	# Last target/strike wins. A called script publishes its own current result;
	# its parent's older generation cannot overwrite that result on return.
	for index: int in range(action.outcomes.size()-1,-1,-1):
		var outcome: Dictionary=action.outcomes[index]
		var kind: String=str(outcome.kind)
		if kind in ["miss","protected","semi_invulnerable"]:flags=1;break
		if kind in ["immune","no_effect"]:flags=8;break
		if kind in ["retaliation_failed","not_first_field_turn","future_queue_occupied","failed"]:flags=32;break
		if kind=="ohko":flags=0 if bool(outcome.eligible) else 1;break
		if kind in ["damage","ability_block"]:break
	# Ruby LostFocus prints and goes straight to MoveEnd: NO FAILED bit.
	_source_no_effect_flags=flags

func _finalizar_resultado_source(phase: Dictionary,category: String,action: BattleMoveAction=null) -> void:
	BattleProtectRules.finish_result(phase.get("source_result_ticket",{}),category,action)
	if category=="unable" and phase.has("source_i4"):
		var hidden: BattleHiddenActorRules=phase.source_i4
		if hidden.live():hidden.original_state().cancelar_continuacion()

func _fase_protegida(movimiento: Movimiento, original: Dictionary={}) -> bool:
	return original.has("source_screen_phase") or BattleCounterRules.supported(movimiento) or BattleScreenRules.phase_supported(movimiento)

func _fase_rampage_vigente(movimiento: Movimiento, guard: Dictionary) -> bool:
	if guard.has("source_screen_phase") or BattleScreenRules.phase_supported(movimiento):return BattleScreenRules.phase_live(guard)
	if BattleCounterRules.supported(movimiento):
		if BattleCounterRules.phase_live(guard):return true
		if not guard.is_empty():BattleCounterRules.cancel_multi(guard.state.get_ref())
		return false
	if movimiento==null or movimiento.get_efecto() not in ["EFFECT_RAMPAGE","EFFECT_UPROAR"]:return true
	BattleRampageRules.reconcile(guard)
	return BattleRampageRules.can_start(guard)

## Choose once before PP/Pressure and retain that accepted target for dispatch.
func _objetivos_rampage(movimiento: Movimiento, atacante: BasePokemon, objetivos: Array[BasePokemon]) -> Array[BasePokemon]:
	if movimiento!=null and movimiento.get_efecto()=="EFFECT_REST":return [atacante]
	if not BattleProtectRules.mode(movimiento).is_empty():return [atacante]
	if movimiento!=null and movimiento.get_efecto() in ["EFFECT_RAMPAGE","EFFECT_UPROAR"]:
		if _b.formato_batalla==Singleton.FormatoBatalla.DOBLE:
			var allies: Array[BasePokemon]=_b.pokemones_activos_jugador if _b.pokemones_activos_jugador.has(atacante) else _b.pokemones_activos_enemigo
			var opponents: Array[BasePokemon]=_b.pokemones_activos_enemigo if _b.pokemones_activos_jugador.has(atacante) else _b.pokemones_activos_jugador
			objetivos=AlcanceMovimientoGen3.objetivos(AlcanceMovimientoGen3.RIVAL_ALEATORIO,atacante,null,allies,opponents)
		else:objetivos.assign([_b.poke_enemigo if atacante==_b.poke_jugador else _b.poke_jugador])
	return objetivos

## Resolve each original target lazily, sharing one action presentation.
func _resolver_accion_objetivos(movimiento: Movimiento, atacante: BasePokemon, objetivos: Array[BasePokemon], area_dos_rivales: bool = false, rampage_target_selected: bool=false, accepted_phase: Dictionary={}) -> BattleMoveAction:
	var result_generation: int=_begin_source_move_results()
	var original: Dictionary=accepted_phase if accepted_phase.has("source_result_ticket") else _capturar_fase_movimiento(atacante,movimiento)
	var action: BattleMoveAction=await _resolver_accion_objetivos_source_core(movimiento,atacante,objetivos,area_dos_rivales,rampage_target_selected,original)
	if result_generation==_source_result_generation:_record_source_move_results(action)
	if original.has("source_magic_coat_current_id"):action.set_meta("source_magic_coat_current_id",original.source_magic_coat_current_id)
	var category: String="aborted" if action.phase in ["entry_aborted","counter_aborted"] else "soundproof" if action.has_meta("source_pre_obedience_soundproof") else "obeying"
	if bool(original.get("source_result_ticket",{}).get("owned_fainted",false)):category="owned_fainted"
	if not bool(original.get("source_snatch_skip_history",false)) and not action.has_meta("source_snatch_skip_history"):_finalizar_resultado_source(original,category,action)
	# HandleAction_ActionFinished borra gLastLandedMoves de quien acaba de actuar. El golpe
	# de Persecución no cuenta: esa acción es del que cambia, no del perseguidor.
	var acting: PokemonEnCombate=_b._obtener_combatiente(atacante) if atacante!=null else null
	if acting!=null and not has_meta("source_pursuit_switch_target"):
		acting.source_last_landed_move=0;acting.source_last_hit_type=""
	return action

func _resolver_accion_objetivos_source_core(movimiento: Movimiento, atacante: BasePokemon, objetivos: Array[BasePokemon], area_dos_rivales: bool, rampage_target_selected: bool, accepted_phase: Dictionary) -> BattleMoveAction:
	movimiento=_movimiento_admitido(accepted_phase,movimiento)
	if not accepted_phase.has("source_magic_coat_resume"):
		var locked_move: Movimiento=BattleLockedMoveRules.at_use(_b,atacante,movimiento)
		# Encore constrains the selected action, never the called child script.
		if locked_move!=null and not accepted_phase.has("source_magic_coat_parent_action"):movimiento=locked_move
		# HandleAction_UseMove: gBattleResults.lastUsedMove del lado del jugador.
		if movimiento!=null and not accepted_phase.has("source_magic_coat_parent_action") and _b.equipo_jugador_pokemones.has(atacante):ResultadosCombate.registrar_movimiento(movimiento.get_nombre_interno())
		var rolling_target: BasePokemon=BattleCounterRules.target(_b,atacante)
		if rolling_target!=null:objetivos=[rolling_target]
		if not rampage_target_selected:objetivos=_objetivos_rampage(movimiento,atacante,objetivos)
		if preload("res://scripts/battle/whirlwind_rules.gd").supports(movimiento) and accepted_phase.has("source_forced_target"):
			if not _b.field_rules.valid(accepted_phase.source_forced_target):return BattleMoveAction.new(atacante,objetivos,"entry_aborted")
			objetivos=[accepted_phase.source_forced_target.pokemon]
		elif not preload("res://scripts/battle/retaliation_rules.gd").supports(movimiento):objetivos=preload("res://scripts/battle/thought_finger_rules.gd").redirect(_b,atacante,movimiento,objetivos)
	if preload("res://scripts/battle/retaliation_rules.gd").supports(movimiento):
		var fact: Dictionary=preload("res://scripts/battle/retaliation_rules.gd").prepare(_b,atacante,movimiento,accepted_phase)
		objetivos=preload("res://scripts/battle/retaliation_rules.gd").targets(fact,atacante)
	if movimiento.get_efecto() in ["EFFECT_TEETER_DANCE","EFFECT_MAGNITUDE"]:
		# Ruby loops source battler banks0..3, excluding only the caster.
		objetivos=[]
		if _b.formato_batalla==Singleton.FormatoBatalla.DOBLE:
			for index: int in 2:
				for side: Array[BasePokemon] in [_b.pokemones_activos_jugador,_b.pokemones_activos_enemigo]:
					if index<side.size() and side[index]!=null and side[index]!=atacante and side[index].estad_ps_actual>0:objetivos.append(side[index])
		else:objetivos.assign([_b.poke_enemigo if atacante==_b.poke_jugador else _b.poke_jugador])
	preload("res://scripts/battle/rage_rules.gd").primary(self,_b,movimiento,accepted_phase,atacante,objetivos)
	if accepted_phase.has("source_rage_primary"):
		var rage_target: Dictionary=accepted_phase.source_rage_primary.target
		if not _b.field_rules.valid(rage_target):return BattleMoveAction.new(atacante,objetivos,"entry_aborted")
		objetivos=[rage_target.pokemon]
	_source_current_move=movimiento
	_source_protect_receipt=accepted_phase.get("source_protect_receipt",{}).duplicate(true)
	# Ruby EffectSubstitute targets USER, independent of the opposing occupant.
	# Normalize before action targets/presentation and all opposing-target gates.
	if preload("res://scripts/battle/curse_nightmare_rules.gd").self_branch(movimiento,atacante) or preload("res://scripts/battle/imprison_rules.gd").supports(movimiento) or BattleSportRules.supports(movimiento) or BattleSafeguardRules.supports(movimiento) or not BattleProtectRules.mode(movimiento).is_empty() or (movimiento!=null and movimiento.get_efecto() in ["EFFECT_GRUDGE","EFFECT_RECYCLE","EFFECT_MAGIC_COAT","EFFECT_CHARGE","EFFECT_DESTINY_BOND","EFFECT_CONVERSION","EFFECT_CONVERSION_2","EFFECT_TELEPORT","EFFECT_MIST","EFFECT_REFRESH","EFFECT_RESTORE_HP","EFFECT_PERISH_SONG","EFFECT_FOCUS_ENERGY","EFFECT_SNATCH","EFFECT_MIRROR_MOVE","EFFECT_NATURE_POWER","EFFECT_ASSIST","EFFECT_SLEEP_TALK","EFFECT_HEAL_BELL","EFFECT_CAMOUFLAGE","EFFECT_BATON_PASS","EFFECT_HAZE","EFFECT_RAIN_DANCE","EFFECT_SUNNY_DAY","EFFECT_HAIL","EFFECT_WISH","EFFECT_INGRAIN","EFFECT_SANDSTORM","EFFECT_FOLLOW_ME","EFFECT_REST","EFFECT_SUBSTITUTE","EFFECT_STOCKPILE","EFFECT_SWALLOW","EFFECT_DEFENSE_CURL","EFFECT_REFLECT","EFFECT_LIGHT_SCREEN"]):
		objetivos=[atacante]
	# Status/move-message HUD work can yield before this dispatch. Revalidate
	# actor identity BEFORE establishing a lock or committing a charge boost.
	var acceptance := BattleMoveAction.new(atacante, objetivos)
	BattleScreenRules.bind_action(_b,acceptance,movimiento,accepted_phase)
	if not BattleScreenRules.action_live(acceptance):return acceptance
	if atacante == null or atacante.estad_ps_actual <= 0 or not _crear_presentador(acceptance).live():
		var stale := _b._obtener_combatiente(atacante) if atacante != null else null
		if stale != null: stale.cancelar_continuacion()
		acceptance.record(atacante, "aborted", false)
		return acceptance
	var reflected: BattleMoveAction=await preload("res://scripts/battle/magic_coat_rules.gd").reflect(self,_b,movimiento,atacante,objetivos,accepted_phase)
	if reflected!=null:return reflected
	# Ruby intercepts after ordinary admission/PP owner payment, before move effects.
	_asegurar_proyeccion_protect()
	var snatcher: BasePokemon=preload("res://scripts/battle/snatch_rules.gd").receiver(_b,movimiento,get_meta("source_protect_projection",[]))
	if snatcher!=null:
		acceptance.record(atacante,"snatched",true,true)
		if not await preload("res://scripts/battle/snatch_rules.gd").present(_b,snatcher,atacante):return acceptance
		await _b.mostrar_texto_batalla("¡%s robó el movimiento!"%snatcher.get_nombre_combate())
		if not BattleScreenRules.action_live(acceptance):return acceptance
		# atkEF then atk5F: self scripts set both banks to snatcher; Psych Up
		# swaps the snatcher into attacker and the original caster into target.
		var self_move: bool=preload("res://scripts/battle/snatch_rules.gd").self_target(movimiento)
		var stolen_phase: Dictionary=_capturar_fase_movimiento(snatcher,movimiento)
		# ATK49 swaps equal banks for self scripts: only snatcher history updates.
		# Psych Up swaps distinct banks back: only original caster history updates.
		if self_move:acceptance.set_meta("source_snatch_skip_history",true)
		else:stolen_phase.source_snatch_skip_history=true
		await _resolver_accion_objetivos(movimiento,snatcher,[snatcher if self_move else atacante],false,true,stolen_phase)
		return acceptance
	var state := _b._obtener_combatiente(atacante)
	if movimiento.get_efecto() == "EFFECT_FUTURE_SIGHT":
		return await _setup_future_attack(movimiento, atacante, objetivos)
	var pending := _pendiente(atacante)
	var phase := "hit"
	var source_turn := 0
	if pending != null and pending.mode == "bide":
		pending.bide_ticks -= 1
		if pending.bide_ticks > 0:
			await _b.mostrar_texto_batalla("¡%s está acumulando energía!" % atacante.get_nombre_combate())
			return BattleMoveAction.new(atacante, objetivos, "storing")
		state.cancelar_continuacion()
		var retaliation := _ocupante_posicion(pending.last_attacker_position, atacante) if not pending.last_attacker_position.is_empty() else _obtener_objetivo_doble(atacante)
		if _b.formato_batalla == Singleton.FormatoBatalla.SIMPLE and pending.last_attacker_position.is_empty(): retaliation = _b.poke_enemigo if atacante == _b.poke_jugador else _b.poke_jugador
		return await _resolver_bide(pending, retaliation,accepted_phase)
	if pending == null and movimiento.get_efecto() == "EFFECT_BIDE":
		state.pending_move = PendingMoveContinuation.new(movimiento, atacante, _posicion_pokemon(atacante))
		state.pending_move.mode = "bide"
		var storing := BattleMoveAction.new(atacante, [atacante], "charge", 0)
		var charge := _crear_presentador(storing)
		charge.start(movimiento, ResultadoMovimiento.new())
		await charge.wait_finished()
		if not charge.live(): state.cancelar_continuacion()
		return storing
	if pending != null:
		movimiento = pending.source_i4.policy() if pending.source_i4!=null else pending.move
		if movimiento.get_efecto() != "EFFECT_RAZOR_WIND":
			objetivos = []
			var current := _ocupante_posicion(pending.target_position, atacante)
			if current != null: objetivos.append(current)
		if pending.source_i4!=null:
			state.pending_move=null;state.semi_invulnerable=""
			if state.hidden_projection!=null:state.hidden_projection.begin_release()
		else:
			state.cancelar_continuacion() # Consume before asynchronous release; never replay.
			_proyectar_semi(atacante)
		phase = "release"
		source_turn = 1
	elif BattleMoveSchedule.es_carga(movimiento):
		if BattleMoveSchedule.carga_necesaria(movimiento, _b.habilidades.crear_campo()):
			if state == null or objetivos.is_empty(): return BattleMoveAction.new(atacante, objetivos)
			var hidden: BattleHiddenActorRules=accepted_phase.get("source_i4")
			state.pending_move = PendingMoveContinuation.new(hidden.original() if hidden!=null else movimiento, atacante, _posicion_pokemon(objetivos[0]))
			state.pending_move.source_i4=hidden
			if hidden!=null:state.hidden_projection=BattleHiddenProjection.new(hidden)
			else:state.semi_invulnerable = BattleMoveSchedule.semi_estado(movimiento)
			phase = "charge"
		else:
			phase = "release"
			source_turn = 1
	var action := BattleMoveAction.new(atacante, objetivos, phase, source_turn)
	if accepted_phase.has("source_protect_fact"):action.set_meta("source_protect_fact",accepted_phase.source_protect_fact)
	action.set_meta("source_result_ticket",accepted_phase.get("source_result_ticket",{}))
	if movimiento.get_efecto()=="EFFECT_MAGNITUDE":
		var choice: Dictionary=preload("res://scripts/battle/magnitude_rules.gd").selection(_sortear_magnitud())
		action.accepted_power=int(choice.power);action.set_meta("source_magnitude_level",int(choice.level))
		await _b.mostrar_texto_batalla("¡Magnitud %d!"%int(choice.level))
	BattleScreenRules.bind_action(_b,action,movimiento,accepted_phase)
	BattleWindAirRules.bind_power(action,movimiento)
	var presenter := _crear_presentador(action)
	if phase == "charge":
		presenter.start(movimiento, ResultadoMovimiento.new())
		await presenter.wait_finished()
		if not presenter.live():state.cancelar_continuacion();return action
		# BattleScript_EffectSkullBash: charging animation first, then USER boost.
		if movimiento.get_efecto() == "EFFECT_SKULL_BASH":
			await _b.habilidades.presentar(EfectosGolpe.cambiar_estadistica(atacante, state, "defensa", 1, false))
			if not presenter.live():state.cancelar_continuacion();return action
		if state.pending_move!=null and state.pending_move.source_i4!=null:
			var hidden: BattleHiddenActorRules=state.pending_move.source_i4
			var text: String={19:"¡%s voló muy alto!",91:"¡%s se escondió bajo tierra!",291:"¡%s se sumergió!",340:"¡%s saltó muy alto!"}[hidden.source_id()]
			await _b.mostrar_texto_batalla(text%atacante.get_nombre_combate())
			if not presenter.live():state.cancelar_continuacion();return action
			state.semi_invulnerable=BattleMoveSchedule.semi_estado(hidden.policy())
			state.hidden_projection.accept_charge()
		else:_proyectar_semi(atacante)
		return action
	action.defer_substitute_restore=true
	for defensor in objetivos:
		if not presenter.live(defensor):
			continue
		await _resolver_movimiento_en_turno(movimiento, atacante, defensor, _b.hud._obtener_cuadro_ps_de_pokemon(defensor), area_dos_rivales, presenter)
		if action.phase in ["entry_aborted","counter_aborted"]:break
	if action.has_meta("source_baton_completed"):return action
	# Explosion is action-scoped, after all target outcomes, not per defender.
	if EfectosGolpe.es_autodestruccion(movimiento) and presenter.animation != null and presenter.live(atacante):
		var outcome := action.record(atacante, "self_ko", true)
		if presenter.claim(outcome):
			await _b.habilidades.presentar([AccionHabilidad.dano(atacante, atacante.estad_ps_actual, "")])
	if action.phase not in ["entry_aborted","counter_aborted"] and not action.has_meta("source_item_moveend_reached"):await preload("res://scripts/battle/held_status_berry_rules.gd").settle(_b,accepted_phase.get("source_status_items",{}))
	await presenter.finish_action()
	if state.hidden_projection!=null and state.hidden_projection.releasing:
		state.hidden_projection.retire();state.hidden_projection=null
	return action


func _resolver_movimiento_en_turno(movimiento: Movimiento, atacante: BasePokemon, defensor: BasePokemon, cuadro_ps_objetivo: Node, area_dos_rivales: bool = false, shared_presenter: BattleMoveActionPresenter = null) -> void:
	# Keep the direct native resolver seam consistent with normal action dispatch.
	if preload("res://scripts/battle/curse_nightmare_rules.gd").self_branch(movimiento,atacante) or preload("res://scripts/battle/imprison_rules.gd").supports(movimiento) or BattleSportRules.supports(movimiento) or BattleSafeguardRules.supports(movimiento) or not BattleProtectRules.mode(movimiento).is_empty() or (movimiento!=null and movimiento.get_efecto() in ["EFFECT_GRUDGE","EFFECT_RECYCLE","EFFECT_MAGIC_COAT","EFFECT_CHARGE","EFFECT_DESTINY_BOND","EFFECT_CONVERSION","EFFECT_CONVERSION_2","EFFECT_TELEPORT","EFFECT_MIST","EFFECT_REFRESH","EFFECT_RESTORE_HP","EFFECT_PERISH_SONG","EFFECT_FOCUS_ENERGY","EFFECT_SNATCH","EFFECT_MIRROR_MOVE","EFFECT_NATURE_POWER","EFFECT_ASSIST","EFFECT_SLEEP_TALK","EFFECT_HEAL_BELL","EFFECT_CAMOUFLAGE","EFFECT_BATON_PASS","EFFECT_HAZE","EFFECT_RAIN_DANCE","EFFECT_SUNNY_DAY","EFFECT_HAIL","EFFECT_WISH","EFFECT_INGRAIN","EFFECT_SANDSTORM","EFFECT_FOLLOW_ME","EFFECT_REST","EFFECT_SUBSTITUTE","EFFECT_STOCKPILE","EFFECT_SWALLOW","EFFECT_DEFENSE_CURL","EFFECT_REFLECT","EFFECT_LIGHT_SCREEN"]):
		defensor=atacante
		cuadro_ps_objetivo=_b.hud._obtener_cuadro_ps_de_pokemon(atacante)
	var presenter := shared_presenter
	var direct_phase: Dictionary={}
	var result_generation: int=-1
	if presenter == null:
		result_generation=_begin_source_move_results()
		direct_phase=_capturar_fase_movimiento(atacante,movimiento)
		if preload("res://scripts/battle/retaliation_rules.gd").supports(movimiento):
			var fact: Dictionary=preload("res://scripts/battle/retaliation_rules.gd").prepare(_b,atacante,movimiento,direct_phase)
			defensor=preload("res://scripts/battle/retaliation_rules.gd").targets(fact,atacante)[0]
			cuadro_ps_objetivo=_b.hud._obtener_cuadro_ps_de_pokemon(defensor)
		var targets: Array[BasePokemon] = [defensor]
		presenter = _crear_presentador(BattleMoveAction.new(atacante, targets))
		movimiento=_movimiento_admitido(direct_phase,movimiento)
		BattleScreenRules.bind_action(_b,presenter.action,movimiento,direct_phase)
		presenter.action.set_meta("source_result_ticket",direct_phase.get("source_result_ticket",{}))
		if direct_phase.has("source_protect_fact"):presenter.action.set_meta("source_protect_fact",direct_phase.source_protect_fact)
		presenter.action.defer_substitute_restore=true
	movimiento=_movimiento_admitido(direct_phase,movimiento)
	await _resolver_movimiento_objetivo(movimiento,atacante,defensor,cuadro_ps_objetivo,area_dos_rivales,presenter,shared_presenter!=null)
	# Direct dispatch owns the same final boundary as the scheduled target
	# loop, including contact reactions after its last hit and early returns.
	if shared_presenter==null:
		if result_generation==_source_result_generation:_record_source_move_results(presenter.action)
		if presenter.action.phase not in ["entry_aborted","counter_aborted"] and not presenter.action.has_meta("source_item_moveend_reached"):await preload("res://scripts/battle/held_status_berry_rules.gd").settle(_b,direct_phase.get("source_status_items",{}))
		await presenter.finish_action()
		_finalizar_resultado_source(direct_phase,"aborted" if presenter.action.phase in ["entry_aborted","counter_aborted"] else "soundproof" if presenter.action.has_meta("source_pre_obedience_soundproof") else "obeying",presenter.action)

func _resolver_movimiento_objetivo(movimiento: Movimiento, atacante: BasePokemon, defensor: BasePokemon, cuadro_ps_objetivo: Node, area_dos_rivales: bool, presenter: BattleMoveActionPresenter, spread_action: bool) -> void:
	_source_current_move=movimiento # Ruby retains this context through delayed due hits.
	_source_protect_receipt=presenter.action.get_meta("source_protect_receipt",{}).duplicate(true)
	var action := presenter.action
	action.remove_meta("source_focus_type_block")
	BattleScreenRules.bind_action(_b,action,movimiento)
	if not presenter.live(defensor) or not action.begin_target(defensor): return
	_source_no_effect_flags=0 # Source movevaluescleanup for this selected target.
	if preload("res://scripts/battle/retaliation_rules.gd").supports(movimiento):
		var fact: Dictionary=action.get_meta("source_screen_phase_guard",{}).get("source_retaliation_fact",{})
		if not preload("res://scripts/battle/retaliation_rules.gd").live(_b,fact):return
		if not bool(fact.eligible):
			action.record(atacante,"retaliation_failed",false);await _b.mostrar_texto_batalla("¡Pero falló!");return
	if preload("res://scripts/battle/focus_punch_rules.gd").failed(_b,atacante,movimiento):
		action.record(atacante,"lost_focus",false);await _b.mostrar_texto_batalla("¡%s perdió la concentración!"%atacante.get_nombre_combate());return
	if movimiento.get_efecto()=="EFFECT_MAGIC_COAT":
		if action.has_meta("source_magic_coat_setup"):return
		action.set_meta("source_magic_coat_setup",true)
		var accepted: bool=preload("res://scripts/battle/magic_coat_rules.gd").produce(_b,atacante,action.get_meta("source_protect_fact",{}))
		action.record(atacante,"magic_coat_setup",accepted,true)
		if accepted:action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if presenter.live():await _b.mostrar_texto_batalla("¡%s se cubrió\ncon %s!"%[atacante.get_nombre_combate(),movimiento.nombre] if accepted else "¡Pero falló!")
		return
	if movimiento.get_efecto()=="EFFECT_SNATCH":
		if action.has_meta("source_snatch_setup"):return
		action.set_meta("source_snatch_setup",true)
		var accepted: bool=preload("res://scripts/battle/snatch_rules.gd").produce(_b,atacante,action.get_meta("source_protect_fact",{}))
		action.record(atacante,"snatch_setup",accepted,true)
		if accepted:action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if presenter.live():await _b.mostrar_texto_batalla("¡%s espera robar un movimiento!"%atacante.get_nombre_combate() if accepted else "¡Pero falló!")
		return
	if movimiento.get_efecto()=="EFFECT_RECYCLE":
		if action.has_meta("source_recycle_produced"):return
		action.set_meta("source_recycle_produced",true)
		var recovered: String=preload("res://scripts/battle/recycle_rules.gd").produce(_b,atacante)
		action.record(atacante,"recycle",not recovered.is_empty(),true)
		if not recovered.is_empty():action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if presenter.live():await _b.mostrar_texto_batalla("¡%s encontró una\nunidad de %s!"%[atacante.get_nombre_combate(),ObjetosLlevados.nombre_objeto(recovered)] if not recovered.is_empty() else "¡Pero falló!")
		return
	if movimiento.get_efecto()=="EFFECT_ROLE_PLAY":
		if action.has_meta("source_role_play_produced"):return
		action.set_meta("source_role_play_produced",true)
		var own: PokemonEnCombate=_b._obtener_combatiente(atacante);var other: PokemonEnCombate=_b._obtener_combatiente(defensor)
		var copied: String=""
		# NO_ACC_CALC_CHECK_LOCK_ON: no numerical roll; Lock On precedes
		# semi-hidden checks. Source flags0 bypass Protect and Substitute.
		if other!=null and (BattleSureHitRules.guarantees(own,other) or other.semi_invulnerable.is_empty()):
			copied=preload("res://scripts/battle/role_play_rules.gd").produce(atacante,defensor)
		action.record(defensor,"role_play",not copied.is_empty(),true)
		if not copied.is_empty():action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		# Message uses the producer's immutable ability, never a post-await donor.
		if presenter.live():await _b.mostrar_texto_batalla("¡%s copió %s!"%[atacante.get_nombre_combate(),HabilidadesCombate.nombre(copied)] if not copied.is_empty() else "¡Pero falló!")
		return
	if movimiento.get_efecto()=="EFFECT_CHARGE":
		if action.has_meta("source_charge_produced"):return
		action.set_meta("source_charge_produced",true)
		# The accepted actor/flow lease was checked above, before any mutation.
		_b._obtener_combatiente(atacante).source_charge_turns=2
		action.record(atacante,"charge_power",true,true);action.phase="status"
		presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if presenter.live():await _b.mostrar_texto_batalla("¡%s está cargando energía!"%atacante.get_nombre_combate())
		return
	if movimiento.get_efecto()=="EFFECT_GRUDGE":
		if action.has_meta("source_grudge_produced"):return
		action.set_meta("source_grudge_produced",true)
		if _b._obtener_combatiente(atacante).source_grudge:
			action.record(atacante,"grudge",false,true);await _b.mostrar_texto_batalla("¡Pero falló!");return
		_b._obtener_combatiente(atacante).source_grudge=true
		action.record(atacante,"grudge",true,true);action.phase="status"
		presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		return
	if movimiento.get_efecto()=="EFFECT_DESTINY_BOND":
		if action.has_meta("source_destiny_bond_produced"):return
		action.set_meta("source_destiny_bond_produced",true)
		_b._obtener_combatiente(atacante).source_destiny_bond=true
		action.record(atacante,"destiny_bond",true,true);action.phase="status"
		presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		return
	if movimiento.get_efecto()=="EFFECT_SPITE":
		if action.has_meta("source_spite_produced"):return
		action.set_meta("source_spite_produced",true)
		var own: PokemonEnCombate=_b._obtener_combatiente(atacante);var other: PokemonEnCombate=_b._obtener_combatiente(defensor)
		var result: Dictionary={}
		if other!=null and other.semi_invulnerable.is_empty() and not _movimiento_bloqueado_por_proteccion(movimiento,atacante,defensor) and _movimiento_acierta(movimiento,own,other,_b.habilidades.crear_campo()):
			result=preload("res://scripts/battle/spite_rules.gd").produce(_b,defensor,_sortear_spite)
		action.record(defensor,"spite_pp",not result.is_empty(),true)
		if not result.is_empty():action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if presenter.live(defensor):await _b.mostrar_texto_batalla("¡Los PP de %s se redujeron en %s!"%[result.name,result.lost] if not result.is_empty() else "¡Pero falló!")
		return
	if movimiento.get_efecto()=="EFFECT_MIMIC":
		if action.has_meta("source_mimic_produced"):return
		action.set_meta("source_mimic_produced",true)
		var own: PokemonEnCombate=_b._obtener_combatiente(atacante);var other: PokemonEnCombate=_b._obtener_combatiente(defensor)
		var accepted: bool=false
		# Ruby special accuracy sentinel: no stage/RNG roll, Lock On precedes
		# semi-hidden/Protect, but Substitute is rejected before that sentinel.
		if other!=null and other.substitute_hp<=0 and (BattleSureHitRules.guarantees(own,other) or (other.semi_invulnerable.is_empty() and not _movimiento_bloqueado_por_proteccion(movimiento,atacante,defensor))):
			accepted=preload("res://scripts/battle/mimic_rules.gd").produce(_b,atacante,defensor,action.get_meta("source_screen_phase_guard",{}).get("source_mimic",{}))
		action.record(defensor,"mimic",accepted,true)
		if accepted:action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if presenter.live():await _b.mostrar_texto_batalla("¡%s copió el movimiento!"%atacante.get_nombre_combate() if accepted else "¡Pero falló!")
		return
	if movimiento.get_efecto()=="EFFECT_SKETCH":
		if action.has_meta("source_sketch_produced"):return
		action.set_meta("source_sketch_produced",true)
		var substitute: bool=_b._obtener_combatiente(defensor).substitute_hp>0
		var accepted: bool=false
		if not substitute:
			action.set_meta("source_sketch_attempt",true)
			accepted=preload("res://scripts/battle/sketch_rules.gd").produce(_b,atacante,defensor,action.get_meta("source_screen_phase_guard",{}).get("source_sketch",{}))
		action.record(defensor,"sketch",accepted,true)
		if accepted:action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if presenter.live():await _b.mostrar_texto_batalla("¡%s copió el movimiento!"%atacante.get_nombre_combate() if accepted else "¡Pero falló!")
		return
	# Ruby jumpifnotfirstturn fails after attackstring/PP reduction, before hit gates.
	if movimiento.get_efecto()=="EFFECT_FAKE_OUT" and _b._obtener_combatiente(atacante).rondas_en_campo>0:
		action.record(defensor,"not_first_field_turn",false)
		await _b.mostrar_texto_batalla("¡Pero falló!")
		return
	if movimiento.get_efecto()=="EFFECT_HEAL_BELL":
		if action.has_meta("source_party_cured"):return
		action.set_meta("source_party_cured",true)
		preload("res://scripts/battle/party_status_rules.gd").produce(_b,atacante,movimiento)
		action.record(atacante,"party_status_cure",true,true);action.phase="status"
		presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		return
	if movimiento.get_efecto()=="EFFECT_MEMENTO":
		await _resolver_memento(movimiento,atacante,defensor,presenter)
		return
	if movimiento.get_efecto() in ["EFFECT_CURSE","EFFECT_NIGHTMARE"]:
		await _resolver_maldicion_pesadilla(movimiento,atacante,defensor,presenter)
		return
	if movimiento.get_efecto() in ["EFFECT_CONVERSION","EFFECT_CONVERSION_2"]:
		if action.has_meta("source_conversion_resolved"):return
		action.set_meta("source_conversion_resolved",true)
		var accepted: bool=preload("res://scripts/battle/conversion_rules.gd").produce(_b,atacante,int(movimiento.datos.numero_movimiento),_sortear_conversion)
		action.record(atacante,"conversion",accepted,true)
		if accepted:action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if presenter.live():await _b.mostrar_texto_batalla("¡%s cambió de tipo!"%atacante.get_nombre_combate() if accepted else "¡Pero falló!")
		return
	if movimiento.get_efecto()=="EFFECT_CAMOUFLAGE":
		if action.has_meta("source_camouflage_resolved"):return
		action.set_meta("source_camouflage_resolved",true)
		var accepted: bool=preload("res://scripts/battle/camouflage_rules.gd").produce(_b,atacante);action.record(atacante,"camouflage",accepted,true)
		if accepted:action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if presenter.live():await _b.mostrar_texto_batalla("¡%s cambió de tipo!"%atacante.get_nombre_combate() if accepted else "¡Pero falló!")
		return
	if movimiento.get_efecto() in ["EFFECT_RESTORE_HP","EFFECT_SOFTBOILED","EFFECT_MORNING_SUN","EFFECT_SYNTHESIS","EFFECT_MOONLIGHT"]:
		if action.has_meta("source_self_heal_resolved"):return
		action.set_meta("source_self_heal_resolved",true)
		var accepted: bool=atacante.estad_ps_actual>0 and atacante.estad_ps_actual<atacante.estad_ps
		action.record(atacante,"self_heal",accepted,true)
		if accepted:
			# Source tryhealhalfhealth fixes the amount before presentation; datahpupdate follows it.
			var amount: int=maxi(1,atacante.estad_ps/2) if movimiento.get_efecto() in ["EFFECT_RESTORE_HP","EFFECT_SOFTBOILED"] else preload("res://scripts/battle/celestial_heal_rules.gd").amount(atacante.estad_ps,_b.habilidades.crear_campo())
			action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
			if presenter.live():await _b.habilidades._curar(atacante,amount)
		if presenter.live():await _b.mostrar_texto_batalla("¡%s recuperó salud!"%atacante.get_nombre_combate() if accepted else "¡Pero falló!")
		return
	if movimiento.get_efecto() in ["EFFECT_WISH","EFFECT_INGRAIN"]:
		if action.has_meta("source_healing_produced"):return
		action.set_meta("source_healing_produced",true)
		var accepted: bool=_b.healing_stream_rules.produce(atacante,movimiento.get_efecto()=="EFFECT_WISH");action.record(atacante,"wish" if movimiento.get_efecto()=="EFFECT_WISH" else "ingrain",accepted,true)
		if accepted:action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if presenter.live():await _b.mostrar_texto_batalla("¡%s pidió un deseo!"%atacante.get_nombre_combate() if accepted and movimiento.get_efecto()=="EFFECT_WISH" else "¡%s echó raíces!"%atacante.get_nombre_combate() if accepted else "¡Pero falló!")
		return
	if movimiento.get_efecto() in ["EFFECT_SANDSTORM","EFFECT_RAIN_DANCE","EFFECT_SUNNY_DAY","EFFECT_HAIL"]:
		if action.has_meta("source_sandstorm_produced"):return
		action.set_meta("source_sandstorm_produced",true)
		var climate: int={"EFFECT_SANDSTORM":3,"EFFECT_RAIN_DANCE":2,"EFFECT_SUNNY_DAY":1,"EFFECT_HAIL":4}[movimiento.get_efecto()]
		var accepted: bool=_b.dust_weather_rules.produce(climate);action.record(atacante,"manual_weather",accepted,true)
		if accepted:action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if presenter.live():await _b.mostrar_texto_batalla({1:"¡El sol comenzó a brillar!",2:"¡Comenzó a llover!",3:"¡Se levantó una tormenta de arena!",4:"¡Comenzó a granizar!"}[climate] if accepted else "¡Pero falló!")
		if accepted and presenter.live():await _b.habilidades.actualizar_predicciones()  # BattleScript_WeatherFormChanges
		return
	if movimiento.get_efecto()=="EFFECT_MIRROR_MOVE":
		if action.has_meta("source_mirror_produced"):return
		action.set_meta("source_mirror_produced",true);action.targets.assign([atacante])
		var id: int=preload("res://scripts/battle/mirror_move_rules.gd").select_id(_b._obtener_combatiente(atacante),_sortear_espejo)
		if id==0:
			if _pagar_pp_espejo(action,movimiento,null,[atacante]):action.record(atacante,"mirror_failed",false,true);await _b.mostrar_texto_batalla("¡Pero falló!")
			return
		var called: Movimiento=preload("res://scripts/battle/thought_finger_rules.gd").called_move(id)
		if called==null:return
		var pos: Dictionary=_posicion_pokemon(atacante)
		var allies: Array[BasePokemon]=_b.pokemones_activos_jugador if bool(pos.player) else _b.pokemones_activos_enemigo
		var rivals: Array[BasePokemon]=_b.pokemones_activos_enemigo if bool(pos.player) else _b.pokemones_activos_jugador
		if _b.formato_batalla==Singleton.FormatoBatalla.SIMPLE:allies=[atacante];rivals=[_b.poke_enemigo if atacante==_b.poke_jugador else _b.poke_jugador]
		var scope: int=AlcanceMovimientoGen3.tipo(called,_movimiento_apunta_al_usuario(called))
		var targets: Array[BasePokemon]=[]
		var called_phase: Dictionary={}
		if preload("res://scripts/battle/retaliation_rules.gd").supports(called):
			# TARGET_SPECIAL resolves deterministically: never draw a discarded target.
			called_phase=preload("res://scripts/battle/magic_coat_rules.gd").called_phase(self,atacante,called,action)
			var fact: Dictionary=preload("res://scripts/battle/retaliation_rules.gd").prepare(_b,atacante,called,called_phase)
			if not preload("res://scripts/battle/retaliation_rules.gd").live(_b,fact):return
			targets=preload("res://scripts/battle/retaliation_rules.gd").targets(fact,atacante)
		else:
			targets=AlcanceMovimientoGen3.objetivos(scope,atacante,null,allies,rivals)
			if scope==AlcanceMovimientoGen3.SELECCIONADO and rivals.size()>1 and not preload("res://scripts/battle/whirlwind_rules.gd").supports(called):
				var living: Array[BasePokemon]=[]
				for rival: BasePokemon in rivals:
					if rival!=null and rival.estad_ps_actual>0:living.append(rival)
				if not living.is_empty():targets=[living[_sortear_objetivo_llamado(living.size())]]
			if preload("res://scripts/battle/whirlwind_rules.gd").supports(called):targets=preload("res://scripts/battle/whirlwind_rules.gd").called_targets(_b,atacante,_sortear_objetivo_arrastre_llamado_source.bind(atacante))
			called_phase=preload("res://scripts/battle/magic_coat_rules.gd").called_phase(self,atacante,called,action)
			if preload("res://scripts/battle/whirlwind_rules.gd").supports(called) and targets.size()==1:called_phase.source_forced_target=_b.field_rules.capture(targets[0])
		preload("res://scripts/battle/rage_rules.gd").primary(self,_b,called,called_phase,atacante,targets)
		if targets.is_empty() or not _pagar_pp_espejo(action,movimiento,called,targets):return
		action.targets=targets;action.record(atacante,"mirror_call",true,true)
		# atk7C jumps directly to the called script; no119/Pound animation here.
		await _b.mostrar_texto_batalla("¡%s usó\n%s!"%[atacante.get_nombre_combate(),called.nombre])
		if presenter.live():await _resolver_accion_objetivos(called,atacante,targets,scope==AlcanceMovimientoGen3.AMBOS_RIVALES and rivals.size()==2,true,called_phase)
		return
	if movimiento.get_efecto()=="EFFECT_NATURE_POWER":
		if action.has_meta("source_nature_power_produced"):return
		action.set_meta("source_nature_power_produced",true)
		var guard: Dictionary=action.get_meta("source_screen_phase_guard",{})
		var called: Movimiento=guard.get("source_nature_power",{}).get("called")
		if called==null:return
		var plan: Dictionary=preload("res://scripts/battle/called_move_plan.gd").capture(_b,atacante,called,_movimiento_apunta_al_usuario(called))
		if plan.is_empty() or plan.targets.is_empty():return
		var called_phase: Dictionary=preload("res://scripts/battle/magic_coat_rules.gd").called_phase(self,atacante,called,action)
		if guard.has("source_nature_power_pp_owner"):
			# Called ppreduce uses selected267 slot with the called target/Pressure.
			var original: Movimiento=guard.source_nature_power_pp_owner
			var payment:=Movimiento.new(called.nombre,movimiento.pp_act,movimiento.pp_mas,movimiento.pp_tot,called.datos.duplicate(true))
			if not _consumir_pp_movimiento(payment,atacante,plan.targets):return
			movimiento.pp_act=payment.pp_act;original.pp_act=payment.pp_act
			_b.presentacion.menu_movs.set_movs(_movimientos_en_campo(_b.poke_jugador))
		action.set_meta("source_nature_power_called_id",int(called.datos.numero_movimiento))
		action.targets=plan.targets;action.record(atacante,"nature_power",true,true)
		# Source root has no attackanimation; the called script owns presentation.
		await _b.mostrar_texto_batalla("¡%s usó\n%s!"%[atacante.get_nombre_combate(),called.nombre])
		if presenter.live():await _resolver_accion_objetivos(called,atacante,plan.targets,bool(plan.spread),true,called_phase)
		return
	if movimiento.get_efecto()=="EFFECT_ASSIST":
		if action.has_meta("source_assist_produced"):return
		action.set_meta("source_assist_produced",true)
		var id: int=preload("res://scripts/battle/assist_rules.gd").select_id(_b,atacante,_sortear_ayuda)
		if id==0:
			if not _pagar_pp_asistencia(action,movimiento,atacante,[atacante]):return
			action.record(atacante,"assist",false,true);await _b.mostrar_texto_batalla("¡Pero falló!");return
		var called: Movimiento=preload("res://scripts/battle/thought_finger_rules.gd").called_move(id)
		if called==null:return
		var pos: Dictionary=_posicion_pokemon(atacante)
		var allies: Array[BasePokemon]=_b.pokemones_activos_jugador if bool(pos.player) else _b.pokemones_activos_enemigo
		var rivals: Array[BasePokemon]=_b.pokemones_activos_enemigo if bool(pos.player) else _b.pokemones_activos_jugador
		if _b.formato_batalla==Singleton.FormatoBatalla.SIMPLE:allies=[atacante];rivals=[_b.poke_enemigo if atacante==_b.poke_jugador else _b.poke_jugador]
		var scope: int=AlcanceMovimientoGen3.tipo(called,_movimiento_apunta_al_usuario(called))
		var targets: Array[BasePokemon]=AlcanceMovimientoGen3.objetivos(scope,atacante,null,allies,rivals)
		if scope==AlcanceMovimientoGen3.SELECCIONADO and rivals.size()>1 and not preload("res://scripts/battle/whirlwind_rules.gd").supports(called):
			var living: Array[BasePokemon]=[]
			for rival: BasePokemon in rivals:
				if rival!=null and rival.estad_ps_actual>0:living.append(rival)
			if not living.is_empty():targets=[living[randi()%living.size()]]
		if preload("res://scripts/battle/whirlwind_rules.gd").supports(called):targets=preload("res://scripts/battle/whirlwind_rules.gd").called_targets(_b,atacante,_sortear_objetivo_arrastre_llamado_source.bind(atacante))
		if targets.is_empty():return
		var called_phase: Dictionary={}
		if preload("res://scripts/battle/whirlwind_rules.gd").supports(called):
			called_phase=preload("res://scripts/battle/magic_coat_rules.gd").called_phase(self,atacante,called,action)
			called_phase.source_forced_target=_b.field_rules.capture(targets[0])
		action.targets=targets;action.record(atacante,"assist",true,true);action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if not presenter.live():return
		if preload("res://scripts/battle/rage_rules.gd").supports(called):
			if called_phase.is_empty():called_phase=preload("res://scripts/battle/magic_coat_rules.gd").called_phase(self,atacante,called,action)
			preload("res://scripts/battle/rage_rules.gd").primary(self,_b,called,called_phase,atacante,targets)
		if not _pagar_pp_asistencia(action,movimiento,atacante,targets):return
		await _b.mostrar_texto_batalla("¡%s usó\n%s!"%[atacante.get_nombre_combate(),called.nombre])
		if presenter.live():
			if called_phase.is_empty():called_phase=preload("res://scripts/battle/magic_coat_rules.gd").called_phase(self,atacante,called,action)
			await _resolver_accion_objetivos(called,atacante,targets,scope==AlcanceMovimientoGen3.AMBOS_RIVALES and rivals.size()==2,true,called_phase)
		return
	# BattleScript_EffectSnore: despierto gasta PP y falla.
	if movimiento.get_efecto()=="EFFECT_SNORE" and atacante.estado!=Singleton.ProblemaEstado.DORMIDO:
		action.record(atacante,"snore",false,true);await _b.mostrar_texto_batalla("¡Pero falló!");return
	if movimiento.get_efecto()=="EFFECT_SLEEP_TALK":
		if action.has_meta("source_sleep_talk_produced"):return
		action.set_meta("source_sleep_talk_produced",true)
		if atacante.estado!=Singleton.ProblemaEstado.DORMIDO:
			action.record(atacante,"sleep_talk",false,true);await _b.mostrar_texto_batalla("¡Pero falló!");return
		var owned: Movimiento=preload("res://scripts/battle/sleep_talk_rules.gd").select_slot(_b,atacante,_sortear_sonambulo)
		if owned==null:
			action.record(atacante,"sleep_talk",false,true);await _b.mostrar_texto_batalla("¡Pero falló!");return
		var called: Movimiento=preload("res://scripts/battle/thought_finger_rules.gd").called_move(int(owned.datos.numero_movimiento))
		if called==null:return
		var pos: Dictionary=_posicion_pokemon(atacante)
		var allies: Array[BasePokemon]=_b.pokemones_activos_jugador if bool(pos.player) else _b.pokemones_activos_enemigo
		var rivals: Array[BasePokemon]=_b.pokemones_activos_enemigo if bool(pos.player) else _b.pokemones_activos_jugador
		if _b.formato_batalla==Singleton.FormatoBatalla.SIMPLE:allies=[atacante];rivals=[_b.poke_enemigo if atacante==_b.poke_jugador else _b.poke_jugador]
		var scope: int=AlcanceMovimientoGen3.tipo(called,_movimiento_apunta_al_usuario(called))
		var targets: Array[BasePokemon]=[]
		var called_phase: Dictionary={}
		if preload("res://scripts/battle/retaliation_rules.gd").supports(called):
			called_phase=preload("res://scripts/battle/magic_coat_rules.gd").called_phase(self,atacante,called,action)
			var fact: Dictionary=preload("res://scripts/battle/retaliation_rules.gd").prepare(_b,atacante,called,called_phase)
			if not preload("res://scripts/battle/retaliation_rules.gd").live(_b,fact):return
			targets=preload("res://scripts/battle/retaliation_rules.gd").targets(fact,atacante)
		else:
			targets=AlcanceMovimientoGen3.objetivos(scope,atacante,null,allies,rivals)
			if scope==AlcanceMovimientoGen3.SELECCIONADO and rivals.size()>1 and not preload("res://scripts/battle/whirlwind_rules.gd").supports(called):
				var living: Array[BasePokemon]=[]
				for rival: BasePokemon in rivals:
					if rival!=null and rival.estad_ps_actual>0:living.append(rival)
				if not living.is_empty():targets=[living[_sortear_objetivo_llamado(living.size())]]
		if preload("res://scripts/battle/whirlwind_rules.gd").supports(called):targets=preload("res://scripts/battle/whirlwind_rules.gd").called_targets(_b,atacante,_sortear_objetivo_arrastre_llamado_source.bind(atacante))
		if targets.is_empty():return
		if called_phase.is_empty():called_phase=preload("res://scripts/battle/magic_coat_rules.gd").called_phase(self,atacante,called,action)
		if preload("res://scripts/battle/whirlwind_rules.gd").supports(called) and targets.size()==1:called_phase.source_forced_target=_b.field_rules.capture(targets[0])
		# Source GetMoveTarget precedes SleepTalk's own animation priority context.
		action.targets=targets;action.record(atacante,"sleep_talk",true,true);action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if not presenter.live():return
		if preload("res://scripts/battle/rage_rules.gd").supports(called):
			if called_phase.is_empty():called_phase=preload("res://scripts/battle/magic_coat_rules.gd").called_phase(self,atacante,called,action)
			preload("res://scripts/battle/rage_rules.gd").primary(self,_b,called,called_phase,atacante,targets)
		await _b.mostrar_texto_batalla("¡%s usó\n%s!"%[atacante.get_nombre_combate(),called.nombre])
		if presenter.live():
			if called_phase.is_empty():called_phase=preload("res://scripts/battle/magic_coat_rules.gd").called_phase(self,atacante,called,action)
			if preload("res://scripts/battle/whirlwind_rules.gd").supports(called) and targets.size()==1:called_phase.source_forced_target=_b.field_rules.capture(targets[0])
			await _resolver_accion_objetivos(called,atacante,targets,scope==AlcanceMovimientoGen3.AMBOS_RIVALES and rivals.size()==2,true,called_phase)
		return
	if movimiento.get_efecto()=="EFFECT_METRONOME":
		if action.has_meta("source_metronome_produced"):return
		action.set_meta("source_metronome_produced",true);action.record(atacante,"metronome",true,true)
		action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if not presenter.live():return
		var called_id: int=preload("res://scripts/battle/thought_finger_rules.gd").select_id(_sortear_metronomo)
		set_meta("source_metronome_id",called_id)
		var called: Movimiento=preload("res://scripts/battle/thought_finger_rules.gd").called_move(called_id)
		if called==null:return
		var pos: Dictionary=_posicion_pokemon(atacante)
		var allies: Array[BasePokemon]=_b.pokemones_activos_jugador if bool(pos.player) else _b.pokemones_activos_enemigo
		var rivals: Array[BasePokemon]=_b.pokemones_activos_enemigo if bool(pos.player) else _b.pokemones_activos_jugador
		if _b.formato_batalla==Singleton.FormatoBatalla.SIMPLE:
			allies=[atacante];rivals=[_b.poke_enemigo if atacante==_b.poke_jugador else _b.poke_jugador]
		var scope: int=AlcanceMovimientoGen3.tipo(called,_movimiento_apunta_al_usuario(called))
		var targets: Array[BasePokemon]=AlcanceMovimientoGen3.objetivos(scope,atacante,null,allies,rivals)
		# Ruby GetMoveTarget randomizes the opposing selected target for a called move.
		if scope==AlcanceMovimientoGen3.SELECCIONADO and rivals.size()>1:
			var living: Array[BasePokemon]=[]
			for rival: BasePokemon in rivals:
				if rival!=null and rival.estad_ps_actual>0:living.append(rival)
			if not living.is_empty():targets=[living[randi()%living.size()]]
		if targets.is_empty():return
		var called_phase: Dictionary=preload("res://scripts/battle/magic_coat_rules.gd").called_phase(self,atacante,called,action)
		preload("res://scripts/battle/rage_rules.gd").primary(self,_b,called,called_phase,atacante,targets)
		await _b.mostrar_texto_batalla("¡%s usó\n%s!"%[atacante.get_nombre_combate(),called.nombre])
		# Already paid the original slot. Do not enqueue/spend any called party PP.
		await _resolver_accion_objetivos(called,atacante,targets,scope==AlcanceMovimientoGen3.AMBOS_RIVALES and rivals.size()==2,true,called_phase)
		return
	if movimiento.get_efecto()=="EFFECT_HELPING_HAND":
		if action.has_meta("source_helping_hand_produced"):return
		action.set_meta("source_helping_hand_produced",true)
		var partner: BasePokemon=preload("res://scripts/battle/helping_hand_rules.gd").produce(_b,atacante)
		if partner!=null:
			action.targets.assign([partner]);action.record(partner,"helping_hand",true,true);action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		else:
			action.record(atacante,"helping_hand",false,true)
			if presenter.live():await _b.mostrar_texto_batalla("¡Pero falló!")
		return
	if movimiento.get_efecto()=="EFFECT_FOLLOW_ME":
		if action.has_meta("source_follow_me_produced"):return
		action.set_meta("source_follow_me_produced",true)
		var accepted: bool=preload("res://scripts/battle/thought_finger_rules.gd").follow(_b,atacante)
		action.record(atacante,"follow_me",accepted,true)
		if accepted:action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		return
	if movimiento.get_efecto()=="EFFECT_IMPRISON":
		if action.has_meta("source_imprison_produced"):return
		action.set_meta("source_imprison_produced",true)
		var accepted: bool=preload("res://scripts/battle/imprison_rules.gd").produce(_b,atacante,movimiento)
		action.record(atacante,"imprison_holder",accepted,true)
		if accepted:
			action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if presenter.live():await _b.mostrar_texto_batalla("¡Se sellaron los movimientos compartidos!" if accepted else "¡Pero falló!")
		return
	if not BattleProtectRules.mode(movimiento).is_empty():
		if action.has_meta("source_protect_produced"):return
		action.set_meta("source_protect_produced",true)
		var fact: Dictionary=action.get_meta("source_protect_fact",{})
		if fact.is_empty() or int(fact.selected_id)!=int(movimiento.datos.get("numero_movimiento",0)):action.phase="entry_aborted";return
		var result: Dictionary=BattleProtectRules.evaluate(_b._obtener_combatiente(atacante),movimiento,bool(fact.last))
		action.record(atacante,"source_protect",bool(result.accepted),true)
		if result.accepted:
			action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if presenter.live():await _b.mostrar_texto_batalla("¡%s se protegió!"%atacante.get_nombre_combate() if result.accepted else "¡Pero falló!")
		return
	if BattleSportRules.supports(movimiento):
		if action.has_meta("source_sport_produced"):return
		action.set_meta("source_sport_produced",true)
		var accepted: bool=BattleSportRules.produce(_b,action,movimiento)
		action.record(atacante,"sport",accepted,true)
		if accepted:
			action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if presenter.live():await _b.mostrar_texto_batalla(("¡Se debilitó la electricidad!" if movimiento.get_efecto()=="EFFECT_MUD_SPORT" else "¡Se debilitó el fuego!") if accepted else "¡Pero falló!")
		return
	# Source atkB8 accepts own-side state BEFORE its source presentation.
	var safeguard_fact: Dictionary=action.get_meta("source_screen_phase_guard",{}).get("source_safeguard",{})
	if not safeguard_fact.is_empty():
		if action.has_meta("source_safeguard_produced"):return
		var accepted: bool=_b.safeguard_rules.produce(action)
		action.record(atacante,"safeguard",accepted,true)
		action.phase="status"
		presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if presenter.live():await _b.mostrar_texto_batalla("¡El equipo se protegió con Velo Sagrado!" if accepted else "¡Pero falló!")
		return
	# Source opponent-side producer has no accuracy, Protect or semi-invulnerable gate.
	if movimiento.get_efecto()=="EFFECT_SPIKES":
		if action.has_meta("source_spikes_resolved"):return
		action.set_meta("source_spikes_resolved",true)
		var accepted: bool=_b.field_rules.add_spikes(atacante)
		action.record(defensor,"spikes",accepted,true)
		if accepted:
			action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if presenter.live():await _b.mostrar_texto_batalla("¡Púas esparcidas en el campo rival!" if accepted else "¡Pero falló!")
		return
	# REMOLINO / RUGIDO: cambio forzado (VENTOSAS lo impide).
	if EfectosGolpe.efecto_de(movimiento) == "EFFECT_ROAR" and atacante != defensor:
		await _resolver_arrastre(atacante, defensor, movimiento, presenter)
		return

	# Ruby atkD8: Esfuerzo falla antes de accuracycheck (y de Protección) si el objetivo no tiene más PS.
	if movimiento.get_efecto()=="EFFECT_ENDEAVOR" and defensor.estad_ps_actual<=atacante.estad_ps_actual:
		action.record(defensor,"endeavor",false,true)
		BattleCounterRules.no_effect(_b._obtener_combatiente(atacante),movimiento.get_efecto())
		if presenter.live():await _b.mostrar_texto_batalla("¡Pero falló!")
		return

	if _movimiento_bloqueado_por_proteccion(movimiento, atacante, defensor):
		BattleCounterRules.cancel_multi(_b._obtener_combatiente(atacante))
		if movimiento.get_efecto()=="EFFECT_SPIT_UP":
			BattleStockpileRules.accept(_b._obtener_combatiente(atacante),action,"EFFECT_SPIT_UP",true)
		action.record(defensor, "protected", false)
		# attackcanceler solo marca MISSED y el guion de Explosión sigue: anima y
		# debilita al usuario aunque PROTECCIÓN anule el daño (salvo HUMEDAD).
		if EfectosGolpe.es_autodestruccion(movimiento) and presenter.animation == null \
				and EfectosGolpe.mensaje_bloqueo_autodestruccion(atacante, movimiento, _b.habilidades.crear_campo()).is_empty():
			presenter.start(movimiento, ResultadoMovimiento.new())
			await presenter.wait_finished()
		await _b.mostrar_texto_batalla("¡%s se protegió!" % defensor.get_nombre_combate())
		return

	var combatiente_atacante: PokemonEnCombate = _b._obtener_combatiente(atacante)
	var combatiente_defensor: PokemonEnCombate = _b._obtener_combatiente(defensor)
	var campo: CampoCombate = _b.habilidades.crear_campo()
	if atacante != defensor and BattleMoveSchedule.multiplicador_semi(movimiento, combatiente_defensor) == 0.0 and not (preload("res://scripts/battle/retaliation_rules.gd").supports(movimiento) and BattleSureHitRules.guarantees(combatiente_atacante,combatiente_defensor)):
		BattleCounterRules.no_effect(combatiente_atacante,movimiento.get_efecto())
		action.record(defensor, "semi_invulnerable", false)
		await _b.mostrar_texto_batalla("¡El ataque de\n%s falló!" % atacante.get_nombre_combate())
		return
	if movimiento.get_efecto() in ["EFFECT_STOCKPILE","EFFECT_SPIT_UP","EFFECT_SWALLOW"]:
		await _resolver_stockpile_family(movimiento,atacante,defensor,cuadro_ps_objetivo,presenter,combatiente_atacante,combatiente_defensor,campo,area_dos_rivales)
		return
	if movimiento.get_efecto()=="EFFECT_TRANSFORM":
		await _resolver_transform(movimiento,atacante,defensor,presenter,combatiente_atacante,combatiente_defensor)
		return

	# HUMEDAD de cualquiera en el campo impide AUTODESTRUCCIÓN / EXPLOSIÓN.
	var bloqueo_explosion := EfectosGolpe.mensaje_bloqueo_autodestruccion(atacante, movimiento, campo)
	if not bloqueo_explosion.is_empty():
		action.record(defensor, "damp", false)
		await _b.mostrar_texto_batalla(bloqueo_explosion)
		return

	# Habilidades del defensor que anulan el movimiento (INSONORIZAR, LEVITACIÓN,
	# ABSORBE ELEC/AGUA/FUEGO, SUPERGUARDA): ocurre antes de la precisión.
	# Ruby atk06 skips the entire type/defender-ability path for Struggle.
	var hidden: BattleHiddenActorRules=BattleHiddenActorRules.facts(action)
	var source_bounce: bool=hidden!=null and hidden.source_id()==340
	var source_struggle: bool=movimiento.get_nombre_interno() in ["COMBATE","STRUGGLE"]
	if atacante != defensor and not source_struggle and not _movimiento_apunta_al_usuario(movimiento) and movimiento.get_efecto() not in ["EFFECT_BEAT_UP","EFFECT_BRICK_BREAK","EFFECT_COUNTER","EFFECT_MIRROR_COAT"] and not (source_bounce and HabilidadesCombate.tiene(defensor,HabilidadesCombate.SUPERGUARDA)):
		var efectividad_tipo := 1.0
		if HabilidadesCombate.tiene(defensor, HabilidadesCombate.SUPERGUARDA):
			efectividad_tipo = MoveResolver.calc_efectividad(movimiento, defensor,combatiente_defensor)
		var bloqueo := HabilidadesCombate.bloquear_movimiento(atacante, defensor, movimiento, efectividad_tipo, combatiente_defensor)
		if not bloqueo.is_empty():
			if HabilidadesCombate.tiene(defensor,HabilidadesCombate.INSONORIZAR) and movimiento.es_sonoro():action.set_meta("source_pre_obedience_soundproof",true)
			BattleCounterRules.no_effect(combatiente_atacante,movimiento.get_efecto())
			# atk06: Levitate sets MISSED|DOESNT_AFFECT, WonderGuard MISSED;
			# Soundproof/absorption scripts do not set NO_EFFECT flags.
			action.set_meta("source_rage_result_flags",9 if HabilidadesCombate.tiene(defensor,HabilidadesCombate.LEVITACION) else 1 if HabilidadesCombate.tiene(defensor,HabilidadesCombate.SUPERGUARDA) else 0)
			# Only source39 typecalc admissions defer these two abilities through
			# the existing accuracy/calculation producer; never roll accuracy twice.
			var held: Dictionary=_b.held_item_effects.resolve(_b,defensor,_b.field_rules.capture(defensor))
			var focus_typecalc: bool=int(held.get("source_effect",0))==39 or bool(action.get_meta("source_focus_latches",{}).get(int(held.get("bank",-1)),false))
			if (focus_typecalc or preload("res://scripts/battle/fixed_damage_rules.gd").supports(movimiento)) and not MoveResolver.es_movimiento_estado(movimiento) and not EfectosGolpe.es_ko_directo(movimiento) and (HabilidadesCombate.tiene(defensor,HabilidadesCombate.LEVITACION) or HabilidadesCombate.tiene(defensor,HabilidadesCombate.SUPERGUARDA)):
				action.set_meta("source_focus_type_block",bloqueo)
			else:
				action.record(defensor, "ability_block", false, true)
				await _b.habilidades.presentar(bloqueo)
				return

	# K.O. de un golpe (Fisura, Guillotina...): no usa la precisión normal.
	if EfectosGolpe.es_ko_directo(movimiento) and atacante != defensor:
		if MoveResolver.calc_efectividad(movimiento, defensor,combatiente_defensor) == 0.0:
			action.record(defensor, "immune", false)
			await _b.mostrar_texto_batalla("No afecta a\n%s..." % defensor.get_nombre_combate())
			return
		var survival: Dictionary=BattleAttackSurvivalRules.prepare(_b,action,defensor,defensor.estad_ps_actual,93,movimiento)
		if survival.is_empty():return
		action.set_meta("source_survival_receipt",survival)
		var ohko_actions := EfectosGolpe.resolver_ko_directo(atacante, defensor, movimiento,Callable(),bool(survival.strict_ohko),BattleSureHitRules.guarantees(combatiente_atacante,combatiente_defensor))
		var authorized := false
		for effect in ohko_actions:
			if effect.tipo == AccionHabilidad.Tipo.DANO: authorized = true
		var ohko_outcome := action.record(defensor, "ohko", authorized)
		var ohko_substitute_broken: bool=false
		if authorized:
			action.phase = "ohko"
			presenter.start(movimiento, ResultadoMovimiento.new())
			await presenter.wait_impact()
			if not presenter.claim(ohko_outcome): return
		for effect in ohko_actions:
			if effect.tipo == AccionHabilidad.Tipo.DANO:
				var ohko_damage: Dictionary=await _aplicar_dano_ataque(defensor, atacante, cuadro_ps_objetivo, effect.cantidad,AttackProvenance.ORDINARY,action)
				ohko_substitute_broken=bool(ohko_damage.get("substitute_broken",false))
				if ohko_damage.has("source_destiny_bond"):await preload("res://scripts/battle/destiny_bond_rules.gd").settle(ohko_damage.source_destiny_bond,ohko_damage)
				await presenter.wait_finished()
				if not presenter.live(defensor):return
				if not bool(ohko_damage.get("aborted",false)):
					await preload("res://scripts/battle/held_survival_presentation.gd").settle(_b,survival)
					if not bool(survival.hung_on) and not bool(survival.endured) and not effect.texto.is_empty() and presenter.live(defensor):await _b.mostrar_texto_batalla(effect.texto)
			else:
				await _b.habilidades.presentar([effect])
		await presenter.wait_finished()
		if ohko_substitute_broken and presenter.live(defensor):
			await _presentar_rotura_sustituto(defensor)
		if authorized and not await preload("res://scripts/battle/rage_rules.gd").grow(_b,action,defensor):return
		await preload("res://scripts/battle/held_shell_bell_rules.gd").settle_hit(_b,action,defensor)
		return


	# Gen 3 (accuracycheck): solo los movimientos que apuntan a otro Pokémon.
	# Source Leech Seed, Trick and sure-hit producers reject the doll BEFORE accuracy/RNG.
	if (movimiento.get_efecto() in ["EFFECT_LEECH_SEED","EFFECT_TRICK"] or BattleSureHitRules.supports(movimiento)) and combatiente_defensor!=null and combatiente_defensor.substitute_hp>0:
		action.record(defensor,"held_item_swap" if movimiento.get_efecto()=="EFFECT_TRICK" else "leech_seed",false,true)
		if presenter.live():await _b.mostrar_texto_batalla("¡Pero falló!")
		return
	if atacante != defensor and not _movimiento_apunta_al_usuario(movimiento) \
			and EfectosGolpe.efecto_de(movimiento) != "EFFECT_TRIPLE_KICK" \
			and not (bool(action.get_meta("source_rage_primary").hit) if action.has_meta("source_rage_primary") else _movimiento_acierta(movimiento, combatiente_atacante, combatiente_defensor, campo)):
		action.record(defensor, "miss", false)
		BattleCounterRules.no_effect(combatiente_atacante,movimiento.get_efecto())
		# Source miss reporting can credit these abilities without reaching07.
		if action.has_meta("source_focus_type_block"):await _b.habilidades.presentar(action.get_meta("source_focus_type_block"))
		else:await _b.mostrar_texto_batalla("¡El ataque de\n%s falló!" % atacante.get_nombre_combate())
		return

	if preload("res://scripts/battle/retaliation_rules.gd").supports(movimiento):
		var fact: Dictionary=action.get_meta("source_screen_phase_guard",{}).get("source_retaliation_fact",{})
		if not preload("res://scripts/battle/retaliation_rules.gd").live(_b,fact):return
		var fixed: ResultadoMovimiento=preload("res://scripts/battle/retaliation_rules.gd").result(movimiento,defensor,combatiente_defensor,int(fact.damage))
		await _ejecutar_golpe_autorizado(movimiento,atacante,defensor,cuadro_ps_objetivo,fixed,presenter,false,spread_action)
		return
	if movimiento.get_efecto()=="EFFECT_PRESENT":
		if not action.has_meta("source_present_outcome"):
			var choice: Dictionary=preload("res://scripts/battle/present_rules.gd").selection(_sortear_regalo())
			action.set_meta("source_present_outcome",choice)
			if not bool(choice.heal):action.accepted_power=int(choice.power)
		var choice: Dictionary=action.get_meta("source_present_outcome")
		if bool(choice.heal):
			var amount: int=maxi(1,defensor.estad_ps/4)
			var accepted: bool=defensor.estad_ps_actual<defensor.estad_ps
			action.record(defensor,"present_heal",accepted,true)
			if accepted:
				# Zero presentation damage selects the source nonpositive heal branch.
				presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
				# Ruby preserves typecalc NO_EFFECT here (unlike Emerald).
				if presenter.live(defensor) and MoveResolver.calc_efectividad(movimiento,defensor,combatiente_defensor)!=0.0:await _b.habilidades._curar(defensor,amount)
			return
	if movimiento.get_efecto()=="EFFECT_TORMENT":
		if action.has_meta("source_torment_produced"):return
		action.set_meta("source_torment_produced",true)
		var accepted: bool=preload("res://scripts/battle/torment_rules.gd").produce(_b,defensor)
		action.record(defensor,"tormented",accepted,true)
		if accepted:action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if presenter.live():await _b.mostrar_texto_batalla("¡%s fue atormentado!"%defensor.get_nombre_combate() if accepted else "¡Pero falló!")
		return
	if movimiento.get_efecto()=="EFFECT_ENCORE":
		if action.has_meta("source_encore_produced"):return
		action.set_meta("source_encore_produced",true)
		var accepted: bool=preload("res://scripts/battle/encore_rules.gd").produce(_b,defensor)
		action.record(defensor,"encored_slot",accepted,true)
		if accepted:action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if presenter.live():await _b.mostrar_texto_batalla("¡%s debe repetir su movimiento!"%defensor.get_nombre_combate() if accepted else "¡Pero falló!")
		return
	if movimiento.get_efecto()=="EFFECT_DISABLE":
		if action.has_meta("source_disable_produced"):return
		action.set_meta("source_disable_produced",true)
		var accepted: bool=preload("res://scripts/battle/disable_rules.gd").produce(_b,defensor)
		action.record(defensor,"disabled_move",accepted,true)
		if accepted:action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if presenter.live():await _b.mostrar_texto_batalla("¡Se anuló el último movimiento de %s!"%defensor.get_nombre_combate() if accepted else "¡Pero falló!")
		return
	if movimiento.get_efecto()=="EFFECT_SKILL_SWAP":
		if action.has_meta("source_skill_swap_produced"):return
		action.set_meta("source_skill_swap_produced",true)
		var accepted: bool=HabilidadesCombate.intercambiar_habilidades_combate(atacante,defensor)
		action.record(defensor,"combat_ability_swap",accepted,true)
		if accepted:
			action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if presenter.live():await _b.mostrar_texto_batalla("¡Se intercambiaron las habilidades!" if accepted else "¡Pero falló!")
		return
	if movimiento.get_efecto()=="EFFECT_TAUNT":
		if action.has_meta("source_taunt_produced"):return
		action.set_meta("source_taunt_produced",true)
		var accepted: bool=preload("res://scripts/battle/thought_finger_rules.gd").taunt(combatiente_defensor)
		action.record(defensor,"taunt",accepted,true)
		if accepted:action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if presenter.live():await _b.mostrar_texto_batalla("¡%s cayó en la mofa!"%defensor.get_nombre_combate() if accepted else "¡Pero falló!")
		return
	if movimiento.get_efecto()=="EFFECT_TRICK":
		if action.has_meta("source_trick_produced"):return
		action.set_meta("source_trick_produced",true)
		var accepted: bool=combatiente_defensor.substitute_hp<=0 and preload("res://scripts/battle/trick_rules.gd").produce(_b,atacante,defensor)
		if accepted:preload("res://scripts/battle/choice_band_rules.gd").defer_received_item(action)
		action.record(defensor,"held_item_swap",accepted,true)
		if accepted:
			action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if presenter.live():await _b.mostrar_texto_batalla("¡Se intercambiaron los objetos!" if accepted else "¡Pero falló!")
		return
	if BattleIdentifiedRules.supports(movimiento):
		if action.has_meta("source_identified_produced"):return
		action.set_meta("source_identified_produced",true)
		var accepted: bool=BattleIdentifiedRules.produce(combatiente_defensor)
		action.record(defensor,"identified",accepted,true)
		if accepted:
			action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if presenter.live():await _b.mostrar_texto_batalla("¡%s fue identificado!"%defensor.get_nombre_combate() if accepted else "¡Pero falló!")
		return
	if BattleSureHitRules.supports(movimiento):
		if action.has_meta("source_sure_hit_produced"):return
		action.set_meta("source_sure_hit_produced",true)
		var accepted: bool=BattleSureHitRules.produce(combatiente_atacante,combatiente_defensor)
		action.record(defensor,"sure_hit",accepted,true)
		if accepted:
			action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if presenter.live():await _b.mostrar_texto_batalla("¡%s fijó el objetivo!"%atacante.get_nombre_combate() if accepted else "¡Pero falló!")
		return
	if movimiento.get_efecto() in BattleScreenRules.EFFECTS:
		if action.has_meta("source_screen_produced"):return
		action.set_meta("source_screen_produced",true)
		var accepted: bool=_b.screen_rules.produce(atacante,movimiento.get_efecto())
		action.record(atacante,"side_screen",accepted,true)
		if accepted:
			action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if presenter.live():await _b.mostrar_texto_batalla("¡%s protegió a su equipo!"%atacante.get_nombre_combate() if accepted else "¡Pero falló!")
		return
	if movimiento.get_efecto()=="EFFECT_BRICK_BREAK" and not action.has_meta("source_screen_removed"):
		if not presenter.live():return
		action.move_turn=_b.screen_rules.remove_opposite(atacante)
		action.set_meta("source_screen_removed",true)
		action.set_meta("source_screen_targets_hit",action.move_turn)
		campo=_b.habilidades.crear_campo() # Calculation sees accepted removal, not pre-accuracy snapshot.
	if movimiento.get_efecto()=="EFFECT_TELEPORT":
		if action.has_meta("source_teleport_resolved"):return
		action.set_meta("source_teleport_resolved",true)
		var blocked: Dictionary=preload("res://scripts/battle/teleport_rules.gd").restriction(_b,atacante)
		action.record(atacante,"teleport_exit",blocked.is_empty(),true)
		if not blocked.is_empty():
			if presenter.live():await _b.mostrar_texto_batalla(HabilidadesCombate.mensaje_impide_huida(blocked) if blocked.get("reason","")=="ability" else "¡Pero falló!")
			return
		action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if not presenter.live():return
		# REGLA (decomp, sub_80DBCFC): el actor desaparece con Teletransporte y no vuelve antes del
		# cierre del combate. La sombra sigue a Pokemon.visible (BattleSlot._sincronizar_sombra).
		var slot_teleport: BattleSlot=_b.hud._obtener_slot_de_pokemon(atacante)
		if is_instance_valid(slot_teleport) and is_instance_valid(slot_teleport.sprite_pokemon):slot_teleport.sprite_pokemon.visible=false
		await _b.mostrar_texto_batalla("¡%s huyó del combate!"%atacante.get_nombre_combate())
		if presenter.live():await _b.resultado.finish_teleport_exit()
		return
	if movimiento.get_efecto()=="EFFECT_PSYCH_UP":
		if action.has_meta("source_psych_up_produced"):return
		action.set_meta("source_psych_up_produced",true)
		var applied: bool=preload("res://scripts/battle/psych_up_rules.gd").produce(combatiente_atacante,combatiente_defensor)
		action.record(atacante,"psych_up",applied,true)
		if applied:
			action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if presenter.live():await _b.mostrar_texto_batalla("¡%s copió los cambios de características de %s!"%[atacante.get_nombre_combate(),defensor.get_nombre_combate()] if applied else "¡Pero falló!")
		return
	if movimiento.get_efecto()=="EFFECT_REFRESH":
		if action.has_meta("source_refresh_produced"):return
		action.set_meta("source_refresh_produced",true)
		var applied: bool=preload("res://scripts/battle/refresh_rules.gd").produce(atacante,combatiente_atacante)
		action.record(atacante,"refresh",applied,true)
		if applied:
			action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if not presenter.live():return
		await _b.mostrar_texto_batalla("¡%s recuperó su estado normal!"%atacante.get_nombre_combate() if applied else "¡Pero falló!")
		if applied and presenter.live():_b.hud._actualizar_estado_visual_pokemon(atacante)
		return
	if movimiento.get_efecto()=="EFFECT_PERISH_SONG":
		if action.has_meta("source_perish_produced"):return
		action.set_meta("source_perish_produced",true)
		var applied: bool=preload("res://scripts/battle/perish_song_rules.gd").produce(_b)
		action.record(atacante,"perish_song",applied,true)
		if applied:
			action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if presenter.live():await _b.mostrar_texto_batalla("¡Los Pokémon que oyeron el canto caerán en tres turnos!" if applied else "¡Pero falló!")
		return
	if movimiento.get_efecto()=="EFFECT_BATON_PASS":
		if action.has_meta("source_baton_resolved"):return
		action.set_meta("source_baton_resolved",true)
		var eligible: bool=_b.resultado.baton_has_replacement(atacante)
		action.record(atacante,"baton_pass",eligible,true)
		if not eligible:
			action.record(atacante,"failed",false) # Ruby ButItFailed publishes FAILED32.
			await _b.mostrar_texto_batalla("¡Pero falló!");return
		var transfer: Dictionary=preload("res://scripts/battle/baton_pass_rules.gd").transfer_fact(_b._obtener_combatiente(atacante))
		var bank_ticket: Dictionary=action.get_meta("source_screen_phase_guard",{}).get("source_baton_bank",{})
		if not bank_ticket.is_empty():bank_ticket.transfer=transfer # After synchronous inability/confusion; before visual/exit yields.
		action.phase="baton_pass";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if _b.formato_batalla==Singleton.FormatoBatalla.DOBLE:
			var ticket: Dictionary=action.get_meta("source_screen_phase_guard",{}).get("source_baton_bank",{})
			if presenter.action.substitute_coordinator!=null:await presenter.action.substitute_coordinator.finish()
			var entry: Dictionary=await preload("res://scripts/battle/baton_bank_transaction.gd").run(_b,action,ticket)
			if entry.is_empty():action.phase="entry_aborted"
		elif presenter.live(atacante):await _b.resultado.baton_pass(atacante,transfer)
		return
	if movimiento.get_efecto()=="EFFECT_HAZE":
		await _resolver_niebla(movimiento,atacante,presenter)
		return
	if movimiento.get_efecto()=="EFFECT_BELLY_DRUM":
		await _resolver_tambor(movimiento,atacante,presenter)
		return
	if movimiento.get_efecto()=="EFFECT_PAIN_SPLIT":
		await _resolver_divide_dolor(movimiento,atacante,defensor,presenter)
		return
	if movimiento.get_efecto()=="EFFECT_REST":
		await _resolver_descanso(movimiento,atacante,presenter)
		return
	if movimiento.get_efecto()=="EFFECT_SUBSTITUTE":
		await _resolver_sustituto(movimiento,atacante,presenter)
		return
	if movimiento.get_efecto()=="EFFECT_LEECH_SEED":
		var accepted: bool=_b.field_rules.seed(atacante,defensor)
		action.record(defensor,"leech_seed",accepted,true)
		if accepted:
			action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
		if presenter.live():await _b.mostrar_texto_batalla("¡%s fue infectado por Drenadoras!"%defensor.get_nombre_combate() if accepted else "¡Pero falló!")
		return
	if MoveResolver.es_movimiento_estado(movimiento):
		# The admitted source identity survives mutable move metadata and yields.
		var source_feather: bool=int(BattleWindFeatherRules.facts(action).get("id",0))==297
		if movimiento.get_efecto()=="EFFECT_DEFENSE_CURL" and combatiente_atacante!=null:combatiente_atacante.set_meta("source_defense_curl",true)
		var es_ultimo_en_actuar := _es_ultimo_en_actuar(atacante)
		if _b.safeguard_rules.blocks_status(movimiento,atacante,defensor):
			action.record(defensor,"safeguard_block",false,true)
			if presenter.live(defensor):await _b.mostrar_texto_batalla("¡Velo Sagrado protege a %s!"%defensor.get_nombre_combate())
			return
		# Source TeeterDance animates once before the first eligible confusion.
		if movimiento.get_efecto()=="EFFECT_TEETER_DANCE" and combatiente_defensor!=null and not combatiente_defensor.esta_confuso and not HabilidadesCombate.evita_confusion(defensor):
			action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
			if not presenter.live(defensor):return
		# Ruby Flatter animates before its ordered SpAtk/confusion producer.
		var source_flatter_presented: bool=movimiento.get_efecto()=="EFFECT_FLATTER" and int(movimiento.datos.get("numero_movimiento",0))==260
		if source_flatter_presented:
			action.phase="status";presenter.start(movimiento,ResultadoMovimiento.new());await presenter.wait_finished()
			if not presenter.live(defensor):return
		if movimiento.get_efecto()=="EFFECT_SLEEP" and preload("res://scripts/battle/uproar_rules.gd").blocks_sleep(_b,defensor):
			action.record(defensor,"uproar_sleep_block",false,true)
			if presenter.live(defensor):await _b.mostrar_texto_batalla("¡El alboroto impide dormir a %s!"%defensor.get_nombre_combate())
			return
		var resultado_estado := StatusEffectResolver.resolver(movimiento, atacante, defensor, combatiente_atacante, combatiente_defensor, es_ultimo_en_actuar)
		action.record(defensor, "status", resultado_estado.aplicado, true)
		if resultado_estado.should_present_animation() and not source_flatter_presented:
			action.phase = "status"
			presenter.start(movimiento, ResultadoMovimiento.new())
			await presenter.wait_finished()
		if not presenter.live(defensor): return
		if resultado_estado.pokemon_a_refrescar_visual != null:
			_b.hud._actualizar_estado_visual_pokemon(resultado_estado.pokemon_a_refrescar_visual)
		for extra in resultado_estado.pokemones_a_refrescar_extra:
			_b.hud._actualizar_estado_visual_pokemon(extra)
		if resultado_estado.pokemon_cambio_estadistica != null:
			await _reproducir_cambio_estadistica(resultado_estado.pokemon_cambio_estadistica, resultado_estado.cambio_estadistica_sube, resultado_estado.source_stat_animation)
		if source_feather and not presenter.live(defensor):return
		# Bounded to audited successful MoveEffect status scripts, not all status moves.
		var source_status_wait: bool=resultado_estado.aplicado and (StatusEffectResolver.ESTADO_POR_EFECTO.has(movimiento.get_efecto()) or StatusEffectResolver.EFECTOS_CONFUSION.has(movimiento.get_efecto()))
		var status_live: Callable=func() -> bool:return presenter.live(defensor)
		# BattleScript_MoveEffectConfusion: chosenstatus2animation antes de «¡X está confuso!».
		var animar_estado: Callable=func(indice: int) -> bool:
			if indice!=resultado_estado.estado_animado_indice or resultado_estado.estado_animado_pokemon==null:return true
			await presentar_fase_estado(resultado_estado.estado_animado_clave,resultado_estado.estado_animado_pokemon)
			return presenter.live(defensor)
		if not await animar_estado.call(0):return
		if source_status_wait:
			if not await _mostrar_mensaje_source_64(resultado_estado.mensaje,status_live):return
		else:await _b.mostrar_texto_batalla(resultado_estado.mensaje)
		var indice_mensaje: int=0
		for mensaje in resultado_estado.mensajes_adicionales:
			indice_mensaje+=1
			if not await animar_estado.call(indice_mensaje):return
			if source_status_wait:
				if not await _mostrar_mensaje_source_64(mensaje,status_live):return
			else:
				if source_feather and not presenter.live(defensor):return
				await _b.mostrar_texto_batalla(mensaje)
		return

	if movimiento.get_efecto() == "EFFECT_BEAT_UP":
		await _resolver_beatup(movimiento, atacante, defensor, cuadro_ps_objetivo, presenter)
		return
	if BattleMoveSchedule.es_multigolpe(movimiento):
		await _resolver_multigolpe(movimiento, atacante, defensor, cuadro_ps_objetivo, area_dos_rivales, presenter, combatiente_atacante, combatiente_defensor, campo)
		return
	if movimiento.get_efecto()=="EFFECT_ERUPTION" and action.accepted_power<0:action.accepted_power=preload("res://scripts/battle/hp_burst_rules.gd").power(atacante)
	if movimiento.get_efecto()=="EFFECT_FLAIL":action.accepted_power=MoveResolver.source_hp_power(atacante)
	if movimiento.get_efecto()=="EFFECT_LOW_KICK":action.accepted_power=preload("res://scripts/battle/variable_power_rules.gd").low_kick_power(defensor)
	BattleCounterRules.bind_action(_b,atacante,defensor,movimiento,action)
	BattleCounterRules.prepare(_b,atacante,defensor,movimiento,action)
	if movimiento.get_efecto() in ["EFFECT_RETURN","EFFECT_FRUSTRATION"] and action.accepted_power<0:
		var friendship: int=clampi(atacante.felicidad,0,255)
		action.set_meta("source_friendship",friendship)
		action.accepted_power=MoveResolver.source_friendship_power(movimiento.get_efecto(),friendship)
	var resultado := _calcular_resultado_golpe(movimiento, atacante, defensor, combatiente_atacante, combatiente_defensor, area_dos_rivales, campo,action.accepted_power)
	if (movimiento.get_efecto()=="EFFECT_BRICK_BREAK" or source_bounce) and HabilidadesCombate.tiene(defensor,HabilidadesCombate.SUPERGUARDA) and resultado.effectiveness<=1.0:
		resultado.effectiveness=0.0;resultado.damage=0;resultado.message="No afecta a\n%s..."%defensor.get_nombre_combate()
	await _ejecutar_golpe_autorizado(movimiento, atacante, defensor, cuadro_ps_objetivo, resultado, presenter, false, spread_action)


func _proyectar_semi(actor: BasePokemon) -> void:
	var slot := _b.hud._obtener_slot_de_pokemon(actor)
	var state := _b._obtener_combatiente(actor)
	if slot != null and state != null and state.hidden_projection==null:
		slot.sprite_pokemon.visible = actor.estad_ps_actual > 0 and state.semi_invulnerable.is_empty()


func _crear_presentador(action: BattleMoveAction) -> BattleMoveActionPresenter:
	if not action.has_meta("source_body_admission"):action.set_meta("source_body_admission",_b.bank_damage_history.admit())
	preload("res://scripts/battle/shell_bell_damage_ledger.gd").bind(_b,action)
	return BattleMoveActionPresenter.new(_b, action)


func _movimiento_acierta(move: Movimiento, actor: PokemonEnCombate, target: PokemonEnCombate, field: CampoCombate) -> bool:
	if move.get_efecto()=="EFFECT_METRONOME":return true
	# Ruby SkillSwap accuracycheck0xFFFF: outer Protect/hidden gates remain,
	# but no numeric accuracy/stage/item roll is consumed.
	if move.get_efecto() in ["EFFECT_SKILL_SWAP","EFFECT_PAIN_SPLIT","EFFECT_YAWN"]:return true
	if move.get_efecto() == "EFFECT_FUTURE_SIGHT" and target != null:
		if BattleMoveSchedule.multiplicador_semi(move,target) == 0.0: return false
		var accuracy := MoveResolver.calcular_precision_efectiva(move,actor,target,field)
		var held := ObjetosLlevados.en_combate(target.pokemon_base)
		var penalty := 10 if held in ["POLVOBRILLO","BRIGHTPOWDER"] else 5 if held == "INCIENSOSUAVE" else 0
		accuracy = accuracy * (100-penalty) / 100
		return randi()%100+1 <= accuracy
	return MoveResolver.movimiento_acierta(move, actor, target, -1, field)


func _sortear_conteo_golpes() -> int:
	return randi()


func _sortear_critico_source(n: int) -> int:
	return randi()%n


func _calcular_resultado_golpe(move: Movimiento, actor: BasePokemon, target: BasePokemon, actor_state: PokemonEnCombate, target_state: PokemonEnCombate, spread: bool, field: CampoCombate, power: int = -1) -> ResultadoMovimiento:
	var source_multiplier: int=actor_state.revenge_multiplier(target,_b) if move.get_efecto()=="EFFECT_REVENGE" and actor_state!=null else 1
	if preload("res://scripts/battle/smelling_salt_rules.gd").supports(move):source_multiplier=preload("res://scripts/battle/smelling_salt_rules.gd").multiplier(target,target_state)
	if preload("res://scripts/battle/weather_ball_rules.gd").supports(move):source_multiplier=2 if field.clima_efectivo()!=0 else 1
	# BattleScript_ActionSwitch: setbyte sDMG_MULTIPLIER, 2 para PERSECUCIÓN contra el que se retira.
	if move.get_efecto()=="EFFECT_PURSUIT" and get_meta("source_pursuit_switch_target",null)==target:source_multiplier=2
	return MoveResolver.calcular_dano(move, actor, target, actor_state, target_state, _b.clima_activo, spread, field, true, _sortear_critico_source, power,0,source_multiplier,preload("res://scripts/battle/source_damage_context.gd").describe(_b,actor,actor_state))


## Initial target gates have already run. Only Triple Kick rolls per attempt.
## Each step reads fresh combat stats AFTER the previous contact reactions.
func _resolver_multigolpe(move: Movimiento, actor: BasePokemon, target: BasePokemon, bar: Node, spread: bool, initial: BattleMoveActionPresenter, actor_state: PokemonEnCombate, target_state: PokemonEnCombate, field: CampoCombate) -> void:
	var action := initial.action
	var restore_deferred: bool=action.defer_substitute_restore
	action.defer_substitute_restore=true
	var count := BattleMoveSchedule.conteo(move, Callable(self, "_sortear_conteo_golpes"))
	var total_damage := 0
	var hits := 0
	var aborted := false
	var last_substitute_hit: bool=false
	for index in count:
		if not initial.live(target) or actor.estad_ps_actual <= 0 or actor.estado == Singleton.ProblemaEstado.DORMIDO:
			break
		action.hit_index = index
		action.move_turn = index
		if move.get_efecto() == "EFFECT_TRIPLE_KICK" and not _movimiento_acierta(move, actor_state, target_state, field):
			action.record(target, "miss", false)
			if hits == 0: await _b.mostrar_texto_batalla("¡El ataque de\n%s falló!" % actor.get_nombre_combate())
			break
		var result := _calcular_resultado_golpe(move, actor, target, actor_state, target_state, spread, field, BattleMoveSchedule.potencia(move, index))
		if result.damage <= 0:
			BattleAttackSurvivalRules.prepare(_b,action,target,int(result.damage),BattleAttackSurvivalRules.command(move),move)
			action.record(target, "immune", false)
			await _b.mostrar_texto_batalla(result.message)
			break
		var step := _crear_presentador(action)
		var committed := await _ejecutar_golpe_autorizado(move, actor, target, bar, result, step, true)
		if not bool(committed.get("committed", false)):
			aborted = not step.live()
			break
		hits += 1
		last_substitute_hit=bool(committed.get("substitute",false))
		total_damage += int(committed.get("damage", 0))
		if not step.live():
			aborted = true
			break
		# Source Endure/Focus can accept the next strike at HP1 too.
	if not aborted and total_damage > 0 and initial.live(target):
		await _presentar_secundario_accion(actor, target, move,last_substitute_hit)
	if not aborted and hits > 0 and initial.live():
		await _b.mostrar_texto_batalla("¡Golpeó %d veces!" % hits)
		# Source final MoveEnd follows final secondary; case3 must still cure it.
		# An already claimed Bell damage receipt is zero, so no duplicate heal.
		await preload("res://scripts/battle/held_shell_bell_rules.gd").settle_hit(_b,action,target)
	action.defer_substitute_restore=restore_deferred
	if not restore_deferred:await initial.finish_action()


## HP and contact are per real hit; generic drain/recoil/status wrappers are
## NOT repeated for a multihit. Outcome is claimed before the asynchronous HUD.
func _ejecutar_golpe_autorizado(movimiento: Movimiento, atacante: BasePokemon, defensor: BasePokemon, cuadro_ps_objetivo: Node, resultado: ResultadoMovimiento, presenter: BattleMoveActionPresenter, multigolpe: bool, spread_action: bool = false) -> Dictionary:
	_source_current_move=movimiento
	_source_protect_receipt=presenter.action.get_meta("source_protect_receipt",{}).duplicate(true)
	presenter.action.set_meta("source_rage_result_flags",8 if resultado.effectiveness==0.0 else 1 if not resultado.hit else 0)
	# atk09 emits no ordinary command for MOVE_RESULT_NO_EFFECT. Native hit /
	# effectiveness encode the calculated miss/immunity; failed status gates
	# already return before this seam. Zero damage alone is NOT this predicate.
	# Explosion's source script emits before target typecalc, so preserve that
	# earlier command and its independent self-KO even for a later immune result.
	# A reached source adjustment can draw even when typecalc suppresses HP.
	if presenter.action.has_meta("source_focus_type_block"):
		presenter.action.set_meta("source_rage_result_flags",9 if HabilidadesCombate.tiene(defensor,HabilidadesCombate.LEVITACION) or (preload("res://scripts/battle/fixed_damage_rules.gd").supports(movimiento) and resultado.effectiveness==0.0) else 1)
		if resultado.hit:presenter.action.set_meta("source_survival_receipt",BattleAttackSurvivalRules.prepare(_b,presenter.action,defensor,int(resultado.damage) if preload("res://scripts/battle/fixed_damage_rules.gd").supports(movimiento) else 0,BattleAttackSurvivalRules.command(movimiento),movimiento))
		presenter.action.record(defensor,"ability_block",false,true)
		await _b.habilidades.presentar(presenter.action.get_meta("source_focus_type_block"))
		return {"committed":false,"damage":0,"no_effect":true}
	var source_damage_requested: bool=resultado.damage>0
	var survival: Dictionary={}
	if resultado.hit:
		survival=BattleAttackSurvivalRules.prepare(_b,presenter.action,defensor,int(resultado.damage),BattleAttackSurvivalRules.command(movimiento),movimiento)
		if survival.is_empty():return {}
		presenter.action.set_meta("source_survival_receipt",survival)
		resultado.damage=int(survival.requested)
	if not EfectosGolpe.es_autodestruccion(movimiento) and (not resultado.hit or resultado.effectiveness==0.0):
		# atkEE's accepted screen-present branch animates before typecalc2.
		# It never grants damage or a generic no-effect presentation exception.
		if movimiento.get_efecto()=="EFFECT_BRICK_BREAK" and presenter.action.move_turn==1 and resultado.hit and presenter.live():
			presenter.start(movimiento,resultado);await presenter.wait_finished()
		if resultado.effectiveness==0.0 and movimiento.get_efecto() in ["EFFECT_RAMPAGE","EFFECT_UPROAR"]:BattleRampageRules.retire(_b._obtener_combatiente(atacante))
		if resultado.hit and BattleHiddenActorRules.facts(presenter.action)!=null:await _presentar_secundario_i4(presenter,defensor,true,false)
		presenter.action.record(defensor,"no_effect",false)
		BattleCounterRules.no_effect(_b._obtener_combatiente(atacante),movimiento.get_efecto())
		await _mostrar_mensaje_source_64(resultado.message,func() -> bool:return presenter.live(defensor))
		return {"committed":false,"damage":0,"no_effect":true}
	var damage_outcome := presenter.action.record(defensor, "damage", source_damage_requested)
	var rampage_acceptance: Dictionary=BattleRampageRules.capture(_b,atacante) if movimiento.get_efecto() in ["EFFECT_RAMPAGE","EFFECT_UPROAR"] else {}
	var rapid_user: Dictionary=_b.field_rules.capture(atacante) if movimiento.get_efecto()=="EFFECT_RAPID_SPIN" else {}
	presenter.start(movimiento, resultado)
	await presenter.wait_impact()
	if not presenter.live(defensor): return {}
	var committed := false
	var resultado_dano: Dictionary = {}
	var dano_infligido := 0
	if presenter.claim(damage_outcome):
		committed = true
		# Source USER effect after accepted hit, before asynchronous HP HUD.
		# Never reacquire a new state on resume or initialize a continuation twice.
		BattleRampageRules.accept(rampage_acceptance,movimiento)
		var before_hp: int=defensor.estad_ps_actual
		resultado_dano = await _aplicar_dano_ataque(defensor, atacante, cuadro_ps_objetivo, resultado.damage,AttackProvenance.ORDINARY,presenter.action)
		BattleProtectRules.reconcile_damage(presenter.action,defensor,resultado_dano,before_hp)
		if not BattleScreenRules.reconcile_ko(presenter.action,defensor,resultado_dano,before_hp):return {"committed":true,"damage":int(resultado_dano.get("damage",0)),"aborted":true}
		if not BattleCounterRules.reconcile(presenter.action,defensor,resultado_dano):return {"committed":true,"damage":int(resultado_dano.get("damage",0)),"aborted":true}
		if resultado_dano.has("source_destiny_bond"):
			var contact: Dictionary=BattleScreenRules.capture_contact(presenter.action)
			var history: Dictionary=BattleProtectRules.capture_contact_result(presenter.action)
			if await preload("res://scripts/battle/destiny_bond_rules.gd").settle(resultado_dano.source_destiny_bond,resultado_dano):
				BattleScreenRules.complete_contact(presenter.action,contact)
				BattleProtectRules.complete_contact_result(presenter.action,history)
				return {"committed":true,"damage":int(resultado_dano.get("damage",0))}
		if not rapid_user.is_empty() and not bool(resultado_dano.get("substitute",false)) and defensor.estad_ps_actual>0 and presenter.live(defensor):_b.field_rules.clear_user(rapid_user)
		BattleRampageRules.reconcile(rampage_acceptance)
		dano_infligido = int(resultado_dano.get("damage", 0))
	await presenter.wait_finished()
	if not presenter.live():return {"committed":committed,"damage":dano_infligido,"aborted":true}
	var substitute_hit: bool=bool(resultado_dano.get("substitute",false))
	if bool(resultado_dano.get("substitute_broken",false)) and presenter.live(defensor):
		await _presentar_rotura_sustituto(defensor)
	if not presenter.live(): return {"committed":committed, "damage":dano_infligido}
	if resultado.critico and source_damage_requested:
		if not await _mostrar_mensaje_source_64("¡Un golpe crítico!",presenter.live):return {"committed":committed,"damage":dano_infligido,"aborted":true}
	if not survival.is_empty() and bool(survival.committed):
		if not await preload("res://scripts/battle/held_survival_presentation.gd").settle(_b,survival):return {"committed":committed,"damage":dano_infligido,"aborted":true}
	if not await _mostrar_mensaje_source_64(resultado.message,presenter.live):return {"committed":committed,"damage":dano_infligido,"aborted":true}
	if not multigolpe and BattleHiddenActorRules.facts(presenter.action)!=null:
		await _presentar_secundario_i4(presenter,defensor,false,substitute_hit)
		if not presenter.live():return {"committed":committed,"damage":dano_infligido,"aborted":true}
	elif not multigolpe and not BattleWindFeatherRules.facts(presenter.action).is_empty():
		await _presentar_secundario_i3(presenter,defensor,false,substitute_hit)
		if not presenter.live():return {"committed":committed,"damage":dano_infligido,"aborted":true}
	elif not multigolpe and preload("res://scripts/battle/smelling_salt_rules.gd").supports(movimiento):
		if not presenter.action.has_meta("source_smelling_salt_secondary"):
			presenter.action.set_meta("source_smelling_salt_secondary",true)
			await _presentar_secundario_accion(atacante,defensor,movimiento,substitute_hit)
		if not presenter.live():return {"committed":committed,"damage":dano_infligido,"aborted":true}
	elif not multigolpe:
		var reactions := EfectosGolpe.tras_dano(atacante, defensor, movimiento, dano_infligido, _b.habilidades.resolutor_combatientes(), _ya_actuo(defensor),Callable(),substitute_hit,presenter.action)
		if spread_action and EfectosGolpe.es_autodestruccion(movimiento):
			reactions = reactions.filter(func(effect: AccionHabilidad) -> bool: return not (effect.tipo == AccionHabilidad.Tipo.DANO and effect.objetivo == atacante))
		var rage_user_faint: Dictionary=preload("res://scripts/battle/rage_rules.gd").capture_user_faint(_b,presenter.action,reactions)
		await _b.habilidades.presentar(reactions)
		preload("res://scripts/battle/rage_rules.gd").complete_user_faint(_b,presenter.action,rage_user_faint)
		if not presenter.live():return {"committed":committed,"damage":dano_infligido,"aborted":true}
	if committed and not substitute_hit and preload("res://scripts/battle/turn_trap_rules.gd").supports(movimiento) and presenter.live(defensor):
		if not presenter.action.has_meta("source_turn_trap_produced"):
			presenter.action.set_meta("source_turn_trap_produced",true)
			var trapped: bool=preload("res://scripts/battle/turn_trap_rules.gd").apply(_b,atacante,defensor,movimiento,_sortear_duracion_atadura)
			presenter.action.record(defensor,"turn_trap",trapped,true)
	if movimiento.get_efecto()=="EFFECT_PAY_DAY" and dano_infligido>0 and not substitute_hit and presenter.live():
		if not presenter.action.has_meta("source_pay_day_scattered"):
			presenter.action.set_meta("source_pay_day_scattered",true)
			_b.resultado.scatter_pay_day(atacante)
			await _b.mostrar_texto_batalla("¡Se esparcieron monedas por todas partes!")
	if committed and presenter.live() and not await preload("res://scripts/battle/rage_rules.gd").grow(_b,presenter.action,defensor):return {"committed":committed,"damage":dano_infligido,"aborted":true}
	if dano_infligido > 0 and not substitute_hit and presenter.live():
		var contact_acceptance: Dictionary=BattleScreenRules.capture_contact(presenter.action)
		var source_result_contact: Dictionary=BattleProtectRules.capture_contact_result(presenter.action)
		await _presentar_reaccion_golpe(atacante, defensor, movimiento, dano_infligido)
		BattleScreenRules.complete_contact(presenter.action,contact_acceptance)
		BattleProtectRules.complete_contact_result(presenter.action,source_result_contact)
		if not presenter.live():return {"committed":committed,"damage":dano_infligido,"aborted":true}
	await preload("res://scripts/battle/held_shell_bell_rules.gd").settle_hit(_b,presenter.action,defensor)
	return {"committed":committed, "damage":dano_infligido, "endured":bool(resultado_dano.get("endured", false)),"substitute":substitute_hit}


func _sortear_secundario_i3() -> int:
	return randi()&65535 # Native RNG adapter, not Ruby global-LCG parity.

func _presentar_secundario_i3(presenter: BattleMoveActionPresenter,target: BasePokemon,no_effect: bool,substitute_hit: bool) -> void:
	if not presenter.live():return
	var fact: Dictionary=BattleWindFeatherRules.facts(presenter.action)
	if fact.is_empty() or int(fact.id) not in [239,318]:return
	var reactions: Array[AccionHabilidad]=BattleWindFeatherRules.reached_secondary(presenter.action,target,_sortear_secundario_i3(),no_effect,substitute_hit,_ya_actuo(target),_b)
	for reaction: AccionHabilidad in reactions:
		if not presenter.live():return
		await _b.habilidades.presentar([reaction])
		if not presenter.live():return
	var pending_stats: Array[String]=BattleWindFeatherRules.take_user_stats(presenter.action,target)
	if not pending_stats.is_empty():
		if not presenter.live():return
		var changes: Array=[]
		for stat: String in pending_stats:changes.append([stat,1])
		var group: AccionHabilidad=AccionHabilidad.stat_group(presenter.action.attacker,_b._obtener_combatiente(presenter.action.attacker),changes,false)
		group.source_stat_parent=presenter.action;group.source_stat_trace_target=target
		await _b.habilidades.presentar([group])
		if not presenter.live():return


## Attack provenance excludes residual/contact damage. Ruby datahpupdate stores
## adjusted move damage BEFORE HP clamp; Endure first adjusts it to HP minus 1.
func _capturar_proveniencia_ataque(target: BasePokemon, actor: BasePokemon, action: BattleMoveAction=null) -> Dictionary:
	var snapshot: Dictionary={"move":_source_current_move,"receipt":_source_protect_receipt.duplicate(true),"effect":_source_current_move.get_efecto() if _source_current_move!=null else "","states":[],"slots":[],"flow":_b.field_rules.capture_flow()}
	for pokemon: BasePokemon in [target,actor]:
		var state: PokemonEnCombate=_b._obtener_combatiente(pokemon)
		if state==null:return {}
		snapshot.states.append({"pokemon":pokemon,"state":weakref(state),"epoch":state.body_attack_epoch,"position":_future_position(pokemon)})
		var slot: BattleSlot=_b.hud._obtener_slot_de_pokemon(pokemon)
		if is_instance_valid(slot):snapshot.slots.append({"pokemon":pokemon,"slot":weakref(slot),"generation":slot.animation_generation})
	snapshot["admission"]=action.get_meta("source_body_admission",null) if action!=null else _b.bank_damage_history.admit()
	if action!=null:snapshot.receipt=action.get_meta("source_protect_receipt",{}).duplicate(true)
	return snapshot

func _proveniencia_ataque_vigente(snapshot: Dictionary) -> bool:
	if not _future_battle_live() or not _b.field_rules.valid_flow(snapshot.get("flow",{})):return false
	for entry: Dictionary in snapshot.get("states",[]):
		var state: PokemonEnCombate=entry.state.get_ref()
		if state==null or _b._obtener_combatiente(entry.pokemon)!=state or state.body_attack_epoch!=int(entry.epoch) or _future_occupant(int(entry.position))!=entry.pokemon:return false
	for entry: Dictionary in snapshot.get("slots",[]):
		var slot: BattleSlot=entry.slot.get_ref()
		if not is_instance_valid(slot) or _b.hud._obtener_slot_de_pokemon(entry.pokemon)!=slot or slot.animation_generation!=int(entry.generation):return false
	return true

func _registrar_dano_ataque(target: BasePokemon, actor: BasePokemon, requested: int, committed: Dictionary, source_position: Dictionary = {}, provenance: AttackProvenance = AttackProvenance.ORDINARY, accepted: Dictionary={}) -> void:
	# A suspended HUD is not permission to adopt a new battle state/occupant.
	if not _proveniencia_ataque_vigente(accepted):return
	var state := _b._obtener_combatiente(target)
	if state == null: return
	if target.estad_ps_actual <= 0:
		state.cancelar_continuacion()
		state.retire_body_attacks()
		return
	# Protect numeric receipt already committed synchronously, including lethal HP.
	# HITMARKER_IGNORE_BIDE excludes future damage and attacker provenance only.
	# Native HP diagnostics and lethal continuation cancellation remain unchanged.
	if provenance == AttackProvenance.FUTURE: return
	var pending := state.pending_move
	if pending != null and pending.mode == "bide" and int(committed.get("damage", 0)) > 0:
		pending.stored_damage += int(committed.get("damage", 0)) if bool(committed.get("endured", false)) else requested
		pending.last_attacker_position = source_position.duplicate() if not source_position.is_empty() else _posicion_pokemon(actor)


func _aplicar_dano_ataque(target: BasePokemon, actor: BasePokemon, bar: Node, requested: int, provenance: AttackProvenance=AttackProvenance.ORDINARY,action: BattleMoveAction=null) -> Dictionary:
	var source_position := _posicion_pokemon(actor) # Provenance precedes the asynchronous HUD.
	var accepted: Dictionary=_capturar_proveniencia_ataque(target,actor,action)
	var flow: Dictionary=_b.field_rules.capture_flow()
	var target_record: Dictionary=_b.field_rules.capture(target)
	if not _b.field_rules.valid_flow(flow) or not _b.field_rules.valid(target_record) or not _proveniencia_ataque_vigente(accepted):
		return {"aborted":true,"damage":0,"endured":false,"hung_on":false}
	var survival: Dictionary=action.get_meta("source_survival_receipt",{}) if action!=null else {}
	if not survival.is_empty():
		if survival.pokemon!=target or (survival.get("action")!=null and survival.action.get_ref()!=action) or bool(survival.committed) or not BattleAttackSurvivalRules.valid(_b,survival):return {"aborted":true,"damage":0}
		requested=int(survival.requested)
	elif provenance==AttackProvenance.ORDINARY:
		survival=BattleAttackSurvivalRules.prepare(_b,action,target,requested,BattleAttackSurvivalRules.command(_source_current_move),_source_current_move)
		if survival.is_empty():return {"aborted":true,"damage":0}
		requested=int(survival.requested)
	if not survival.is_empty():survival.committed=true # Claim body AND doll before any asynchronous HUD.
	var bell_receipt: Dictionary=preload("res://scripts/battle/shell_bell_damage_ledger.gd").capture(_b,action,actor,target,EfectosGolpe.es_autodestruccion(_source_current_move)) if provenance==AttackProvenance.ORDINARY else {}
	var barrier: Dictionary=BattleSubstituteRules.absorb(_b._obtener_combatiente(target),requested)
	if bool(barrier.get("substitute",false)):
		preload("res://scripts/battle/shell_bell_damage_ledger.gd").record(_b,bell_receipt,barrier,requested)
		return barrier
	var bond: Dictionary=preload("res://scripts/battle/destiny_bond_rules.gd").capture_hit(_b,target,actor) if provenance==AttackProvenance.ORDINARY else {}
	var grudge: Dictionary=preload("res://scripts/battle/grudge_rules.gd").capture_hit(_b,target,actor,action) if provenance==AttackProvenance.ORDINARY else {}
	# Bind the bypass to this accepted move/command, never generic passive metadata.
	var bypass: Dictionary=preload("res://scripts/battle/fixed_damage_rules.gd").endure_bypass(action,accepted.move,survival)
	if not bypass.is_empty():accepted["source_super_fang_bypass"]=bypass
	var committed := await _b._aplicar_danio_a_pokemon(target, bar, requested,accepted)
	# Source atk19 pushes Grudge after Destiny Bond: its PP command runs first.
	if not grudge.is_empty():await preload("res://scripts/battle/grudge_rules.gd").settle(grudge,committed)
	if not bond.is_empty():committed.source_destiny_bond=bond
	committed["hung_on"]=bool(survival.get("hung_on",false))
	if not survival.is_empty():
		survival.committed=true
		committed["endured"]=bool(survival.get("endured",false)) or bool(committed.get("endured",false))
	preload("res://scripts/battle/shell_bell_damage_ledger.gd").record(_b,bell_receipt,committed,requested)
	if not accepted.is_empty():_registrar_dano_ataque(target, actor, requested, committed, source_position,provenance,accepted)
	return committed


## Ruby normalisebuffs executes only after the actual source animation.
func _resolver_niebla(move: Movimiento,actor: BasePokemon,presenter: BattleMoveActionPresenter) -> void:
	var action: BattleMoveAction=presenter.action
	if action.has_meta("source_haze_resolved"):return
	action.set_meta("source_haze_resolved",true)
	action.phase="status";presenter.start(move,ResultadoMovimiento.new());await presenter.wait_finished()
	if not presenter.live(actor):return
	var banks: Array[BasePokemon]=[]
	if _b.formato_batalla==Singleton.FormatoBatalla.DOBLE:
		for index: int in 2:
			for side: Array[BasePokemon] in [_b.pokemones_activos_jugador,_b.pokemones_activos_enemigo]:
				if index<side.size():banks.append(side[index])
	else:banks.assign([_b.poke_jugador,_b.poke_enemigo])
	for pokemon: BasePokemon in banks:
		if pokemon==null:continue
		var state: PokemonEnCombate=_b._obtener_combatiente(pokemon)
		if state==null:continue
		# Ruby's eighth (HP) stage slot is unused; native has seven stages.
		for field: String in ["mod_ataque","mod_defensa","mod_ataque_especial","mod_defensa_especial","mod_velocidad","mod_precision","mod_evasion"]:state.set(field,0)
		action.record(pokemon,"haze",true,true)
	if presenter.live(actor):await _b.mostrar_texto_batalla("¡Se eliminaron los cambios de características!")


## Ruby maxattackhalvehp establishes Attack before animation, HP afterward.
func _resolver_tambor(move: Movimiento,actor: BasePokemon,presenter: BattleMoveActionPresenter) -> void:
	var action: BattleMoveAction=presenter.action
	if action.has_meta("source_drum_resolved"):return
	action.set_meta("source_drum_resolved",true)
	var state: PokemonEnCombate=_b._obtener_combatiente(actor);var cost: int=maxi(1,actor.estad_ps/2)
	var accepted: bool=state!=null and state.mod_ataque<6 and actor.estad_ps_actual>cost
	action.record(actor,"belly_drum",accepted,true)
	if not accepted:
		if presenter.live(actor):await _b.mostrar_texto_batalla("¡Pero falló!")
		return
	state.mod_ataque=6
	action.phase="status";presenter.start(move,ResultadoMovimiento.new());await presenter.wait_finished()
	if not presenter.live(actor):return
	await _b._aplicar_danio_a_pokemon(actor,_b.hud._obtener_cuadro_ps_de_pokemon(actor),cost)
	if presenter.live(actor):await _b.mostrar_texto_batalla("¡%s redujo sus PS y maximizó su ATAQUE!"%actor.get_nombre_combate())


func _resolver_descanso(move: Movimiento,actor: BasePokemon,presenter: BattleMoveActionPresenter) -> void:
	var action: BattleMoveAction=presenter.action
	if action.has_meta("source_rest_resolved"):return
	action.set_meta("source_rest_resolved",true)
	var accepted: Dictionary={"accepted":false} if preload("res://scripts/battle/uproar_rules.gd").blocks_sleep(_b,actor) else preload("res://scripts/battle/rest_rules.gd").accept(_b._obtener_combatiente(actor))
	action.record(actor,"rest",bool(accepted.accepted),true)
	if not bool(accepted.accepted):
		if presenter.live(actor):await _b.mostrar_texto_batalla("¡Pero falló!")
		return
	_b.hud._actualizar_estado_visual_pokemon(actor)
	action.phase="status";presenter.start(move,ResultadoMovimiento.new());await presenter.wait_finished()
	if not presenter.live(actor):return
	await _b.habilidades._curar(actor,int(accepted.heal))
	if presenter.live(actor):await _b.mostrar_texto_batalla("¡%s durmió y recuperó salud!"%actor.get_nombre_combate())


func _resolver_sustituto(move: Movimiento, actor: BasePokemon, presenter: BattleMoveActionPresenter) -> void:
	var state: PokemonEnCombate=_b._obtener_combatiente(actor)
	var outcome: Dictionary=presenter.action.record(actor,"substitute_cost",state!=null and state.substitute_hp==0 and actor.estad_ps_actual>maxi(1,actor.estad_ps/4))
	if not presenter.claim(outcome):
		await _b.mostrar_texto_batalla("¡Pero falló!");return
	var accepted: Dictionary=BattleSubstituteRules.accept(state)
	if not bool(accepted.accepted):return
	var slot: BattleSlot=_b.hud._obtener_slot_de_pokemon(actor)
	var expected: BattleOwnedAppearanceLease=BattleSubstitutePresentation.capture(slot)
	presenter.bind_substitute_guard(expected)
	presenter.action.phase="status";presenter.start(move,ResultadoMovimiento.new())
	await presenter.wait_finished()
	if not presenter.live(actor):return
	if state.substitute_hp>0:BattleSubstitutePresentation.ensure_doll(expected)
	var bar: Node=_b.hud._obtener_cuadro_ps_de_pokemon(actor)
	if bar!=null:await _b.hud.animar_dano(bar,actor.estad_ps,actor.estad_ps_actual)
	if presenter.live(actor):await _b.mostrar_texto_batalla("¡%s creó un sustituto!"%actor.get_nombre_combate())

func _resolver_transform(move: Movimiento, actor: BasePokemon, target: BasePokemon, presenter: BattleMoveActionPresenter, actor_state: PokemonEnCombate, target_state: PokemonEnCombate) -> void:
	var snapshot: Dictionary=BattleTransformPresentation.capture(_b,actor,target,presenter.action)
	var accepted: Dictionary=BattleTransformRules.accept(_b,actor_state,target_state,presenter.action)
	if not bool(accepted.accepted):
		presenter.action.record(actor,"transform_failed",false)
		await _b.mostrar_texto_batalla("¡Pero falló!");return
	var outcome: Dictionary=presenter.action.record(actor,"transform_accepted",true)
	if not presenter.claim(outcome):return
	presenter.action.transform_presentation=snapshot
	presenter.action.phase="status";presenter.start(move,ResultadoMovimiento.new())
	await presenter.wait_finished()
	# A successful source commit changes the coordinator's mon token. Approve
	# that exact handoff BEFORE its normal live/restore predicate observes it.
	BattleTransformPresentation.reconcile(presenter)
	if presenter.live(actor):await _b.mostrar_texto_batalla("¡%s se transformó en %s!"%[actor.get_nombre_combate(),str(accepted.snapshot.species)])


func _resolver_stockpile_family(move: Movimiento, actor: BasePokemon, target: BasePokemon, bar: Node, presenter: BattleMoveActionPresenter, actor_state: PokemonEnCombate, target_state: PokemonEnCombate, field: CampoCombate, spread: bool) -> void:
	var effect: String=move.get_efecto()
	if effect=="EFFECT_SPIT_UP":
		# Source table255 power100 admits the EXISTING ability/base×count producer.
		# Own this local policy; never mutate the chosen slot or imported DB row.
		var data: Dictionary=move.datos.duplicate(true);data.potencia=100
		move=Movimiento.new(move.nombre,move.pp_act,move.pp_mas,move.pp_tot,data)
	# Ordinary accuracy/semi misses branch BEFORE atk86, preserving the count.
	if effect=="EFFECT_SPIT_UP" and not _movimiento_acierta(move,actor_state,target_state,field):
		presenter.action.record(target,"miss",false)
		await _b.mostrar_texto_batalla("¡El ataque de\n%s falló!"%actor.get_nombre_combate());return
	var accepted: Dictionary=BattleStockpileRules.accept(actor_state,presenter.action,effect)
	if not bool(accepted.accepted):
		presenter.action.record(actor,"stockpile_failed",false)
		await _b.mostrar_texto_batalla("¡Pero falló!");return
	if effect=="EFFECT_SPIT_UP":
		# Type/ability no-effect outcomes follow the irreversible source consume.
		var blocking: Array=HabilidadesCombate.bloquear_movimiento(actor,target,move,MoveResolver.calc_efectividad(move,target,target_state),target_state)
		# Ruby table255 supplies power100 even when the imported DB power is NULL.
		var result: ResultadoMovimiento=MoveResolver.calcular_dano(move,actor,target,actor_state,target_state,_b.clima_activo,spread,field,false,Callable(),-1,int(accepted.count),1,preload("res://scripts/battle/source_damage_context.gd").describe(_b,actor,actor_state))
		if not blocking.is_empty():
			# Wonder Guard's typecalc marks NO_EFFECT but still reaches69.
			if HabilidadesCombate.tiene(target,HabilidadesCombate.SUPERGUARDA):presenter.action.set_meta("source_survival_receipt",BattleAttackSurvivalRules.prepare(_b,presenter.action,target,0,69,move))
			presenter.action.record(target,"ability_block",false,true)
			await _b.habilidades.presentar(blocking);return
		await _ejecutar_golpe_autorizado(move,actor,target,bar,result,presenter,false)
		return
	var outcome: Dictionary=presenter.action.record(actor,"stockpile_success",true)
	if not presenter.claim(outcome):return
	presenter.action.phase="status";presenter.start(move,ResultadoMovimiento.new())
	await presenter.wait_finished()
	if not presenter.live(actor):return
	if effect=="EFFECT_SWALLOW":
		await _b.habilidades._curar(actor,int(accepted.heal)) # HITMARKER_IGNORE_SUBSTITUTE.
		if presenter.live(actor):await _b.mostrar_texto_batalla("¡%s recuperó PS!"%actor.get_nombre_combate())
	else:
		await _b.mostrar_texto_batalla("¡%s acumuló energía %d veces!"%[actor.get_nombre_combate(),int(accepted.count)])


func _presentar_rotura_sustituto(target: BasePokemon) -> void:
	if not _future_battle_live():return
	var slot: BattleSlot=_b.hud._obtener_slot_de_pokemon(target)
	if slot==null:return
	var generation: int=slot.animation_generation
	var state: Dictionary=BattleSubstitutePresentation.owned_state(slot).duplicate(true)
	var expected: BattleOwnedAppearanceLease=BattleSubstitutePresentation.capture(slot)
	var context: BattleAnimationContext=BattleAnimationContext.from_legacy(MoveAnimationContext.nueva(_b,slot,slot))
	var animation: BattleSequenceAnimation=BattleAnimationDirector.play_key("ruby:general/2",context,true)
	if is_instance_valid(animation.runner):animation.runner.set_meta("source_substitute_guard",expected)
	await animation.esperar_finalizada()
	if _future_battle_live() and _b.hud._obtener_slot_de_pokemon(target)==slot and slot.animation_generation==generation:
		var domain: PokemonEnCombate=_b._obtener_combatiente(target)
		if domain!=null and domain.substitute_hp<=0:BattleSubstitutePresentation.restore_bound(expected,state)
		await _b.mostrar_texto_batalla("¡El sustituto de %s se desvaneció!"%target.get_nombre_combate())


func _resolver_bide(pending: PendingMoveContinuation, target: BasePokemon,accepted_phase: Dictionary={}) -> BattleMoveAction:
	var targets: Array[BasePokemon] = []
	if target != null: targets.append(target)
	var action := BattleMoveAction.new(pending.actor, targets, "release", 1)
	BattleScreenRules.bind_action(_b,action,pending.move,accepted_phase)
	var presenter := _crear_presentador(action)
	if pending.stored_damage <= 0 or target == null or not presenter.live(target):
		action.record(target, "failed", false)
		await _b.mostrar_texto_batalla("¡Pero falló!")
		return action
	var actor_state := _b._obtener_combatiente(pending.actor)
	var target_state := _b._obtener_combatiente(target)
	if target_state != null and target_state.protegido_este_turno:
		action.record(target, "protected", false)
		await _b.mostrar_texto_batalla("¡%s se protegió!" % target.get_nombre_combate())
		return action
	if BattleMoveSchedule.multiplicador_semi(pending.move, target_state) == 0.0 or not _movimiento_acierta(pending.move, actor_state, target_state, _b.habilidades.crear_campo()):
		action.record(target, "miss", false)
		await _b.mostrar_texto_batalla("¡El ataque de\n%s falló!" % pending.actor.get_nombre_combate())
		return action
	if MoveResolver.calc_efectividad(pending.move, target,target_state) == 0.0:
		BattleAttackSurvivalRules.prepare(_b,action,target,pending.stored_damage*2,69,pending.move)
		action.record(target, "immune", false)
		await _b.mostrar_texto_batalla("No afecta a\n%s..." % target.get_nombre_combate())
		return action
	var result := ResultadoMovimiento.new()
	result.damage = pending.stored_damage * 2
	await _ejecutar_golpe_autorizado(pending.move, pending.actor, target, _b.hud._obtener_cuadro_ps_de_pokemon(target), result, presenter, true)
	return action


func _resolver_beatup(move: Movimiento, actor: BasePokemon, target: BasePokemon, bar: Node, initial: BattleMoveActionPresenter) -> void:
	var party: Array[BasePokemon] = _b.equipo_jugador_pokemones if actor == _b.poke_jugador or _b.pokemones_activos_jugador.has(actor) else _b.equipo_enemigo_pokemones
	var target_species := DatabaseManager.obtener_datos_pokemon(target.nombre_interno)
	var defense := int(target_species.get("base_def", 0))
	if defense <= 0:
		initial.action.record(target, "missing_species", false)
		await _b.mostrar_texto_batalla("¡Pero falló!")
		return
	var restore_deferred: bool=initial.action.defer_substitute_restore
	initial.action.defer_substitute_restore=true
	var hits := 0
	for contributor in party:
		if not initial.live(target): break
		if not BattleMoveSchedule.contribuye_beatup(contributor): continue
		var species := DatabaseManager.obtener_datos_pokemon(contributor.nombre_interno)
		if int(species.get("base_atq", 0)) <= 0: continue
		initial.action.move_turn = hits
		initial.action.hit_index = hits
		var result := ResultadoMovimiento.new()
		result.damage = BattleMoveSchedule.dano_beatup(int(species.base_atq), contributor.nivel, defense)
		result.critico = EfectosGolpe.golpe_critico(actor, target, move, _sortear_critico_source, _b._obtener_combatiente(actor))
		if result.critico: result.damage *= 2
		result.damage = maxi(1, result.damage * (100 - randi() % 16) / 100)
		await _b.mostrar_texto_batalla("¡%s ataca!" % contributor.get_nombre_combate())
		var step := _crear_presentador(initial.action)
		var committed := await _ejecutar_golpe_autorizado(move, actor, target, bar, result, step, true)
		if not bool(committed.get("committed", false)) or not step.live(): break
		hits += 1
	if hits == 0 and initial.live():
		initial.action.record(target, "failed", false)
		await _b.mostrar_texto_batalla("¡Pero falló!")
	elif initial.live():
		await preload("res://scripts/battle/held_shell_bell_rules.gd").settle_hit(_b,initial.action,target)
	initial.action.defer_substitute_restore=restore_deferred
	if not restore_deferred:await initial.finish_action()


func _presentar_secundario_accion(actor: BasePokemon, target: BasePokemon, move: Movimiento, substitute_hit: bool=false) -> void:
	if preload("res://scripts/battle/smelling_salt_rules.gd").supports(move):
		if preload("res://scripts/battle/smelling_salt_rules.gd").cure(target,substitute_hit):
			_b.hud._actualizar_estado_visual_pokemon(target)
			await _b.mostrar_texto_batalla("¡%s se recuperó de la parálisis!"%target.get_nombre_combate())
		return
	await _b.habilidades.presentar(EfectosGolpe.efecto_secundario(actor, target, move, _b.habilidades.resolutor_combatientes(), _ya_actuo(target),Callable(),substitute_hit))


func _presentar_reaccion_golpe(actor: BasePokemon, target: BasePokemon, move: Movimiento, damage: int) -> void:
	await _b.habilidades.presentar(HabilidadesCombate.tras_golpe(actor, target, move, damage, _b.habilidades.resolutor_combatientes()))


## Ruby EFFECT_ROAR owns one selected bank, never the entire DOUBLE side.
func _sortear_arrastre_source() -> int:return randi()&65535

func _resolver_arrastre(atacante: BasePokemon, defensor: BasePokemon, movimiento: Movimiento, presenter: BattleMoveActionPresenter) -> void:
	var source: Script=preload("res://scripts/battle/whirlwind_rules.gd")
	var rules: BattleFieldEffects=_b.field_rules
	var original: Dictionary=rules.capture(defensor)
	var flow: Dictionary=rules.capture_flow([defensor])
	if original.is_empty() or defensor.estad_ps_actual<=0 or not presenter.live(defensor):return
	if movimiento.es_sonoro() and HabilidadesCombate.tiene(defensor,HabilidadesCombate.INSONORIZAR):
		presenter.action.set_meta("source_pre_obedience_soundproof",true)
		presenter.action.record(defensor,"ability_block",false,true)
		await _b.habilidades.presentar(HabilidadesCombate.bloquear_movimiento(atacante,defensor,movimiento,1.0,_b._obtener_combatiente(defensor)))
		return
	if HabilidadesCombate.evita_cambio_forzado(defensor):
		presenter.action.record(defensor,"forced_switch",false)
		await _b.mostrar_texto_batalla("¡%s se aferra\nal suelo con %s!"%[defensor.get_nombre_combate(),HabilidadesCombate.nombre(HabilidadesCombate.de(defensor))]);return
	var actor_state: PokemonEnCombate=_b._obtener_combatiente(atacante)
	var target_state: PokemonEnCombate=original.state.get_ref()
	if target_state.source_ingrain_rooted:
		presenter.action.record(defensor,"rooted",false)
		await _b.mostrar_texto_batalla("¡%s se ancló\ncon las raíces!"%defensor.get_nombre_combate());return
	var sure: bool=BattleSureHitRules.guarantees(actor_state,target_state)
	if not sure and (not target_state.semi_invulnerable.is_empty() or _movimiento_bloqueado_por_proteccion(movimiento,atacante,defensor)):
		presenter.action.record(defensor,"forced_switch_blocked",false)
		await _b.mostrar_texto_batalla("¡Pero falló!");return
	if _movimiento_bloqueado_por_proteccion(movimiento,atacante,defensor):
		presenter.action.record(defensor,"protected",false)
		await _b.mostrar_texto_batalla("¡%s\nse ha protegido!"%defensor.get_nombre_combate());return
	if not _movimiento_acierta(movimiento,actor_state,target_state,_b.habilidades.crear_campo()):
		presenter.action.record(defensor,"miss",false)
		await _b.mostrar_texto_batalla("¡El ataque de\n%s falló!"%atacante.get_nombre_combate());return
	var fact: Dictionary=presenter.action.get_meta("source_screen_phase_guard",{}).get("source_whirlwind",{})
	var actor_level: int=int(fact.get("actor_level",atacante.nivel))
	var target_level: int=int(fact.get("levels",{}).get(defensor,defensor.nivel))
	if _b.tipo_batalla in [Singleton.TipoBatalla.SALVAJE,Singleton.TipoBatalla.SALVAJE_TEST]:
		if not source.level_passes(actor_level,target_level,_sortear_arrastre_source):
			presenter.action.record(defensor,"forced_switch",false)
			await _b.mostrar_texto_batalla("¡Pero falló!")
			return
		if await _presentar_arrastre(movimiento,defensor,presenter):
			# REGLA (decomp, Move_ROAR/Move_WHIRLWIND → sub_80A8B3C): el sprite arrastrado sale de
			# la pantalla y no se restaura; contra un salvaje el combate termina sin que vuelva.
			var slot: BattleSlot=_b.hud._obtener_slot_de_pokemon(defensor)
			if is_instance_valid(slot) and is_instance_valid(slot.sprite_pokemon):slot.sprite_pokemon.visible=false
			await _b.huida_rival_salvaje(defensor)
		return
	var player: bool=bool(original.bank.player)
	var party: Array[BasePokemon]=_b.equipo_jugador_pokemones if player else _b.equipo_enemigo_pokemones
	var double: bool=_b.formato_batalla==Singleton.FormatoBatalla.DOBLE
	var active: Array=(_b.pokemones_activos_jugador if player else _b.pokemones_activos_enemigo).duplicate() if double else [defensor]
	var chosen: Dictionary=source.select(party,active,actor_level,target_level,double,_sortear_arrastre_source)
	if chosen.is_empty():
		presenter.action.record(defensor,"forced_switch",false)
		await _b.mostrar_texto_batalla("¡Pero falló!");return
	if not await _presentar_arrastre(movimiento,defensor,presenter):return
	if not rules.valid(original) or not rules.valid_flow(flow):presenter.action.phase="entry_aborted";return
	var entry: Dictionary
	if double:entry=await _b.resultado.cambiar_slot_forzado_doble(original,chosen.pokemon,int(chosen.index))
	elif player:entry=await _b.resultado._ejecutar_cambio_pokemon_animado(defensor,chosen.pokemon,int(chosen.index),{},false,true);_b.turno_jugador_pasado=true
	else:entry=await _b.resultado._cambiar_pokemon_enemigo(chosen.pokemon,{},true);_marcar_rival_entro_a_mitad_de_ronda();_b.turno_enemigo_pasado=true
	if not source.handoff(_b,presenter.action,original,entry,flow):presenter.action.phase="entry_aborted";return
	# The switch owns source HandleFaintedMonActions' bank0 TRUE item tail.
	var tail: Dictionary=preload("res://scripts/battle/held_status_berry_rules.gd").capture_tail(_b,rules.capture_flow())
	if not await preload("res://scripts/battle/held_status_berry_rules.gd").settle_tail(_b,tail):presenter.action.phase="entry_aborted"


func _presentar_arrastre(movimiento: Movimiento, defensor: BasePokemon, presenter: BattleMoveActionPresenter) -> bool:
	presenter.action.phase = "forced_switch"
	var outcome := presenter.action.record(defensor, "forced_switch", true)
	presenter.start(movimiento, ResultadoMovimiento.new())
	await presenter.wait_finished()
	return presenter.claim(outcome)


func _reproducir_cambio_estadistica(pokemon: BasePokemon, sube: bool, source_argument: int=-1) -> void:
	if source_argument>=0:
		await preload("res://scripts/battle/stat_animation_rules.gd").present(_b,pokemon,source_argument);return
	_b._reproducir_efecto(SE_SUBIDA_ESTADISTICA if sube else SE_BAJADA_ESTADISTICA)
	var slot: BattleSlot = _b.hud._obtener_slot_de_pokemon(pokemon)
	if slot != null:
		await slot.animar_cambio_estadistica(sube)


func _movimiento_apunta_al_usuario(movimiento: Movimiento) -> bool:
	if movimiento!=null and movimiento.get_efecto() in ["EFFECT_GRUDGE","EFFECT_RECYCLE","EFFECT_MAGIC_COAT","EFFECT_CHARGE","EFFECT_DESTINY_BOND","EFFECT_CONVERSION","EFFECT_CONVERSION_2","EFFECT_TELEPORT","EFFECT_MIST","EFFECT_REFRESH","EFFECT_RESTORE_HP","EFFECT_PERISH_SONG","EFFECT_FOCUS_ENERGY","EFFECT_SNATCH","EFFECT_MIRROR_MOVE","EFFECT_NATURE_POWER","EFFECT_ASSIST","EFFECT_SLEEP_TALK","EFFECT_HEAL_BELL","EFFECT_CAMOUFLAGE","EFFECT_BATON_PASS","EFFECT_HAZE","EFFECT_RAIN_DANCE","EFFECT_SUNNY_DAY","EFFECT_HAIL","EFFECT_WISH","EFFECT_INGRAIN","EFFECT_SANDSTORM"]:return true
	if preload("res://scripts/battle/curse_nightmare_rules.gd").self_branch(movimiento):return true
	if movimiento.get_efecto()=="EFFECT_HELPING_HAND":return true
	if movimiento.get_efecto()=="EFFECT_FOLLOW_ME":return true
	if preload("res://scripts/battle/imprison_rules.gd").supports(movimiento):return true
	if BattleSafeguardRules.supports(movimiento):return true
	if not BattleProtectRules.mode(movimiento).is_empty():return true
	if movimiento!=null and movimiento.get_efecto() in ["EFFECT_SUBSTITUTE","EFFECT_STOCKPILE","EFFECT_SWALLOW","EFFECT_REFLECT","EFFECT_LIGHT_SCREEN"]:return true
	var handler = StatusEffectResolver.obtener_definicion_handler_movimiento(movimiento.get_nombre_interno())
	if not handler.is_empty():
		return bool(handler.get("target_self", false))
	return CambioEstadisticaGen3.apunta_al_usuario(movimiento)


func _movimiento_bloqueado_por_proteccion(movimiento: Movimiento, atacante: BasePokemon, defensor: BasePokemon) -> bool:
	if movimiento == null or atacante == null or defensor == null:
		return false
	if movimiento.get_efecto() in ["EFFECT_COUNTER","EFFECT_MIRROR_COAT"]:return false
	if movimiento.get_efecto()=="EFFECT_TRANSFORM":return false # MOVE_TRANSFORM flags=0.
	if atacante == defensor or _movimiento_apunta_al_usuario(movimiento):
		return false
	var combatiente_defensor = _b._obtener_combatiente(defensor)
	if combatiente_defensor == null:
		return false
	return combatiente_defensor.protegido_este_turno


func _evaluar_accion_antes_de_moverse(pokemon: BasePokemon,selected_move: Movimiento=null) -> Dictionary:
	_begin_source_move_results() # HandleAction_UseMove clears flags before attackcanceler.
	_source_current_move=selected_move
	_source_protect_receipt=preload("res://scripts/battle/bank_damage_history.gd").capture(selected_move,{})
	var resultado := {
		"puede_actuar": true,
		"mensaje": "",
		"source_check_outcome": _capture_pre_action_outcome(pokemon)
	}
	if pokemon == null or pokemon.estad_ps_actual <= 0:
		resultado["puede_actuar"] = false
		return resultado

	if preload("res://scripts/battle/choice_band_rules.gd").blocked(_b,pokemon,selected_move):
		resultado.puede_actuar=false;resultado.mensaje="Choice Band prevents selecting another move.";return resultado
	var combatiente = _b._obtener_combatiente(pokemon)
	if combatiente!=null:
		combatiente.source_destiny_bond=false # Ruby attackcanceller case 0, before inability.
		combatiente.source_grudge=false
	if preload("res://scripts/battle/uproar_rules.gd").wake(_b,pokemon):resultado.mensaje="¡El alboroto despertó a %s!"%pokemon.get_nombre_combate()
	if pokemon.estado == Singleton.ProblemaEstado.DORMIDO and combatiente != null:
		if combatiente.turnos_dormido <= 0:
			combatiente.iniciar_sueno(2)
		combatiente.turnos_dormido -= HabilidadesCombate.reduccion_sueno(pokemon)  # MADRUGAR descuenta 2
		if combatiente.turnos_dormido > 0:
			if not preload("res://scripts/battle/sleep_talk_rules.gd").usable_asleep(selected_move):
				resultado.puede_actuar=false;resultado.mensaje="¡%s está dormido!"%pokemon.get_nombre_combate();resultado.source_status_key="ruby:status/4";return resultado
		else:
			pokemon.estado=Singleton.ProblemaEstado.NORMAL;combatiente.source_nightmare=false
			if _b.hud!=null:_b.hud._actualizar_estado_visual_pokemon(pokemon)
			resultado.mensaje="¡%s se despertó!"%pokemon.get_nombre_combate()
	elif pokemon.estado == Singleton.ProblemaEstado.CONGELADO:
		# Ruby case2 still draws Random()%5 for a thawing move. A nonzero
		# result defers self-thaw to case13, after other inability checks.
		if randi()%5!=0:
			if selected_move==null or selected_move.get_efecto()!="EFFECT_THAW_HIT":
				resultado.puede_actuar=false
				resultado.mensaje="¡%s está congelado!" % pokemon.get_nombre_combate()
				resultado.source_status_key="ruby:status/6"
				return resultado
		else:
			pokemon.estado=Singleton.ProblemaEstado.NORMAL
			if _b.hud!=null:_b.hud._actualizar_estado_visual_pokemon(pokemon)
			resultado.mensaje="¡%s se descongeló!" % pokemon.get_nombre_combate()

	# AUSENTE: holgazanea un turno de cada dos (atkCanceler, caso 3).
	if HabilidadesCombate.holgazanea(pokemon, combatiente):
		_source_no_effect_flags=1 # Ruby attackcanceler case3 explicitly sets MISSED.
		resultado["source_cancel_multi"]=true
		resultado["puede_actuar"] = false
		resultado["mensaje"] = "¡%s está\nholgazaneando!" % pokemon.get_nombre_combate()
		return resultado

	# Recarga (caso 4): solo llega aquí quien despertó o se descongeló este turno.
	if combatiente != null and combatiente.source_recharge_turns > 0:
		combatiente.source_recharge_turns = 0
		resultado["source_cancel_multi"]=true
		resultado["puede_actuar"] = false
		var aviso_recarga := "¡%s debe recargar energía!" % pokemon.get_nombre_combate()
		resultado["mensaje"] = aviso_recarga if str(resultado["mensaje"]).is_empty() else str(resultado["mensaje"]) + "\n" + aviso_recarga
		return resultado

	# Retroceso: un ataque con ese efecto le impide actuar este turno.
	if combatiente != null and combatiente.retrocede:
		resultado["source_cancel_multi"]=true
		combatiente.retrocede = false
		resultado["puede_actuar"] = false
		resultado["mensaje"] = "¡%s retrocedió!" % pokemon.get_nombre_combate()
		return resultado

	# Confusión: puede golpearse a sí mismo (EfectosGolpe.chequeo_confusion).
	if preload("res://scripts/battle/disable_rules.gd").blocked(_b,pokemon,selected_move):
		resultado.puede_actuar=false;resultado.mensaje="¡Ese movimiento está anulado!";resultado.source_cancel_multi=true
		return resultado

	if preload("res://scripts/battle/thought_finger_rules.gd").blocked(_b,pokemon,selected_move):
		resultado.puede_actuar=false;resultado.mensaje="¡La mofa impide ese movimiento!";resultado.source_cancel_multi=true
		return resultado

	if preload("res://scripts/battle/imprison_rules.gd").sealed(_b,pokemon,selected_move):
		resultado.puede_actuar=false;resultado.mensaje="¡El movimiento está sellado!";resultado.source_cancel_multi=true
		return resultado

	var confusion := EfectosGolpe.chequeo_confusion(pokemon, combatiente,Callable(),preload("res://scripts/battle/source_damage_context.gd").describe(_b,pokemon,combatiente))
	if not (confusion["mensajes"] as PackedStringArray).is_empty():
		resultado["source_read_wait_64"]=true
		if combatiente!=null and combatiente.esta_confuso:resultado["source_status_key"]="ruby:status/1"
		var mensajes: PackedStringArray = confusion["mensajes"]
		var previo_confusion := str(resultado["mensaje"])
		resultado["mensaje"] = mensajes[0] if previo_confusion.is_empty() else previo_confusion + "\n" + mensajes[0]
		resultado["mensajes_extra"] = mensajes.slice(1)
		resultado["dano_propio"] = int(confusion["dano_propio"])
		if int(resultado.dano_propio)>0:
			var confusion_action:=BattleMoveAction.new(pokemon,[pokemon],"confusion")
			resultado["source_confusion_action"]=confusion_action # Keep the original receipt owner alive through status/HUD awaits.
			resultado["source_confusion_survival"]=BattleAttackSurvivalRules.prepare(_b,confusion_action,pokemon,int(resultado.dano_propio),8,selected_move)
		if not bool(confusion["puede_actuar"]):
			resultado["source_cancel_multi"]=true
			resultado["puede_actuar"] = false
			return resultado

	# Parálisis (atkCanceller, caso 10): tras la confusión y antes del enamoramiento.
	if pokemon.estado == Singleton.ProblemaEstado.PARALIZADO and randi() % 4 == 0:
		resultado["source_cancel_multi"]=true
		resultado["puede_actuar"] = false
		var aviso_paralisis := "¡%s está paralizado!\n¡No puede moverse!" % pokemon.get_nombre_combate()
		if str(resultado["mensaje"]).is_empty():
			resultado["mensaje"] = aviso_paralisis
			resultado["source_status_key"] = "ruby:status/5"
		else:
			# Confuso sin golpearse: ambos mensajes y ambas animaciones, en ese orden.
			var extra_paralisis: PackedStringArray = resultado.get("mensajes_extra", PackedStringArray())
			extra_paralisis.append(aviso_paralisis)
			resultado["mensajes_extra"] = extra_paralisis
			resultado["source_status_key_final"] = "ruby:status/5"
		return resultado

	# Debilitado en este turno y aún sin presentar: ya no enamora (cleareffectsonfaint).
	if combatiente != null and combatiente.target_enamorado is BasePokemon and combatiente.target_enamorado.estad_ps_actual <= 0:
		_b._liberar_enamorados_de(combatiente.target_enamorado)
	# GRAN ENCANTO: el enamorado se queda inmóvil la mitad de las veces.
	if combatiente != null and combatiente.esta_enamorado:
		resultado["source_status_key"]="ruby:status/3"
		var objeto_amor = combatiente.target_enamorado
		var nombre_amor: String = objeto_amor.get_nombre_combate() if objeto_amor is BasePokemon else "su rival"
		var aviso := "¡%s está enamorado\nde %s!" % [pokemon.get_nombre_combate(), nombre_amor]
		if randi() % 2 == 0:
			resultado["source_cancel_multi"]=true
			resultado["puede_actuar"] = false
			aviso += "\n¡Está inmóvil por el amor!"
		var previo := str(resultado["mensaje"])
		resultado["mensaje"] = aviso if previo.is_empty() else previo + "\n" + aviso

	# Ruby atkCanceller case13, only after the action survives earlier checks.
	if bool(resultado.puede_actuar) and pokemon.estado==Singleton.ProblemaEstado.CONGELADO and selected_move!=null and selected_move.get_efecto()=="EFFECT_THAW_HIT":
		pokemon.estado=Singleton.ProblemaEstado.NORMAL
		if _b.hud!=null:_b.hud._actualizar_estado_visual_pokemon(pokemon)
		var thaw_text: String="¡%s se descongeló!"%pokemon.get_nombre_combate()
		resultado.mensaje=thaw_text if str(resultado.mensaje).is_empty() else str(resultado.mensaje)+"\n"+thaw_text
	if bool(resultado.puede_actuar) and pokemon.estado==Singleton.ProblemaEstado.DORMIDO and preload("res://scripts/battle/sleep_talk_rules.gd").usable_asleep(selected_move):
		resultado.mensaje="¡%s está dormido!"%pokemon.get_nombre_combate();resultado.source_status_key="ruby:status/4"
	if bool(resultado.puede_actuar):_aplicar_desobediencia(resultado,pokemon,selected_move,combatiente)
	return resultado


func _sortear_obediencia() -> int:return randi()&255

## attackcanceler: after UnableToUseMove, Soundproof and the no-PP check, before
## ppreduce. Only the loafing/nap/self-hit scripts skip attackstring and PP.
func _aplicar_desobediencia(resultado: Dictionary,pokemon: BasePokemon,move: Movimiento,combatiente: PokemonEnCombate) -> void:
	var objetivos: Array[BasePokemon]=_source_objetivos_chequeo
	_source_objetivos_chequeo=[]
	if move==null or combatiente==null:return
	if pokemon!=_b.poke_jugador and not _b.pokemones_activos_jugador.has(pokemon):return
	if not OBEDIENCE.traded(pokemon):return
	# STATUS2_MULTIPLETURNS bypasses the check; Encore is not a multiple-turn lock.
	if BattleRampageRules.move(_b,pokemon)!=null or BattleCounterRules.move(_b,pokemon)!=null or _pendiente(pokemon)!=null:return
	if not move.tiene_pp() and OBEDIENCE.move_id(move)!=OBEDIENCE.STRUGGLE:return
	for objetivo: BasePokemon in objetivos:
		if objetivo!=null and move.es_sonoro() and HabilidadesCombate.tiene(objetivo,HabilidadesCombate.INSONORIZAR):return
	var roll: Callable=_sortear_obediencia
	var asleep: bool=pokemon.estado==Singleton.ProblemaEstado.DORMIDO and OBEDIENCE.move_id(move) in [OBEDIENCE.SNORE,OBEDIENCE.SLEEP_TALK]
	var can_nap: Callable=func() -> bool:
		return pokemon.estado==Singleton.ProblemaEstado.NORMAL and not HabilidadesCombate.tiene(pokemon,HabilidadesCombate.ESPIRITUVITAL) and not HabilidadesCombate.tiene(pokemon,HabilidadesCombate.INSOMNIO) and not _alboroto_activo()
	var decision: Dictionary=OBEDIENCE.decide(pokemon.nivel,OBEDIENCE.level_limit(),asleep,can_nap,roll)
	if str(decision.kind)=="obey":return
	if OBEDIENCE.move_id(move)==OBEDIENCE.RAGE:combatiente.source_rage=false
	var nombre: String=pokemon.get_nombre_combate()
	if str(decision.kind)=="random":
		var campo: Array=_movimientos_en_campo(pokemon)
		var slot: int=OBEDIENCE.random_slot(preload("res://scripts/battle/move_availability_rules.gd").slots(_b,pokemon),_slot_de_movimiento(campo,move),roll)
		if slot>=0:
			resultado.source_movimiento_desobediente=campo[slot]
			resultado.source_desobediencia={"mensaje":OBEDIENCE.IGNORED%nombre}
			return
		decision=OBEDIENCE.loaf(roll)
	resultado.puede_actuar=false
	match str(decision.kind):
		"asleep":
			_source_no_effect_flags=1
			resultado.source_desobediencia={"mensaje":OBEDIENCE.IGNORED_ASLEEP%nombre}
		"nap":
			_source_no_effect_flags=1
			resultado.source_desobediencia={"mensaje":OBEDIENCE.NAP%nombre,"dormir":true}
		"hit":
			# gUnknown_081D99A0 -> BattleScript_DoSelfConfusionDmg, same 40-power hit.
			resultado.source_desobediencia={"mensaje":OBEDIENCE.WONT_OBEY%nombre,"extra":OBEDIENCE.HURT_ITSELF,"golpe":true}
			resultado.source_cancel_multi=true
			resultado.mensajes_extra=PackedStringArray()
			resultado.dano_propio=EfectosGolpe.dano_por_confusion(pokemon,combatiente,Callable(),preload("res://scripts/battle/source_damage_context.gd").describe(_b,pokemon,combatiente))
			var confusion_action:=BattleMoveAction.new(pokemon,[pokemon],"confusion")
			resultado.source_confusion_action=confusion_action
			resultado.source_confusion_survival=BattleAttackSurvivalRules.prepare(_b,confusion_action,pokemon,int(resultado.dano_propio),8,move)
		_:
			_source_no_effect_flags=1
			resultado.source_desobediencia={"mensaje":str(decision.text)%nombre}


func _alboroto_activo() -> bool:
	for actor: BasePokemon in _b.habilidades.crear_campo().todos():
		var locked: Movimiento=BattleRampageRules.move(_b,actor)
		if locked!=null and locked.get_efecto()=="EFFECT_UPROAR":return true
	return false


func _slot_de_movimiento(campo: Array,move: Movimiento) -> int:
	var slot: int=campo.find(move)
	if slot>=0:return slot
	for index: int in campo.size():
		if OBEDIENCE.move_id(campo[index])==OBEDIENCE.move_id(move):return index
	return -1


## New action phase for the random move, keeping gChosenMove for history.
func _fase_movimiento_desobediente(actor: BasePokemon,elegido: Movimiento,aleatorio: Movimiento) -> Dictionary:
	var phase: Dictionary=_capturar_fase_movimiento(actor,aleatorio)
	OBEDIENCE.bind_random_phase(phase,elegido,aleatorio)
	return phase


## An unable turn writes 0xFFFF. The self-hit script set HITMARKER_OBEYS, so its
## MoveEnd keeps gChosenMove/gCurrentMove instead.
func _finalizar_turno_no_actuado(phase: Dictionary,chequeo: Dictionary) -> void:
	if bool(chequeo.get("source_desobediencia",{}).get("golpe",false)):
		var ticket: Dictionary=phase.get("source_result_ticket",{})
		if not ticket.is_empty():BattleProtectRules.commit(ticket,"obeying",int(ticket.selected_id),BattleProtectRules.result_live(ticket))
		return
	_finalizar_resultado_source(phase,"unable")


## BattleScript_IgnoresAndFallsAsleep / the other disobedience text, inside the
## original pre-action receipt so a nap cannot outlive the admitted body.
func _presentar_desobediencia(desobediencia: Dictionary,pokemon: BasePokemon,check_live: Callable) -> bool:
	if not await _mostrar_mensaje_source_64(str(desobediencia.mensaje),check_live):return false
	if desobediencia.has("extra") and not await _mostrar_mensaje_source_64(str(desobediencia.extra),check_live):return false
	if not bool(desobediencia.get("dormir",false)):return true
	pokemon.estado=Singleton.ProblemaEstado.DORMIDO
	_b._obtener_combatiente(pokemon).iniciar_sueno()
	if not await presentar_fase_estado("ruby:status/4",pokemon) or not check_live.call():return false
	if _b.hud!=null:_b.hud._actualizar_estado_visual_pokemon(pokemon)
	return await _mostrar_mensaje_source_64("¡%s se quedó dormido!"%pokemon.get_nombre_combate(),check_live)


## Capture before evaluation returns to any presentation override.
func _capture_pre_action_outcome(pokemon: BasePokemon) -> Dictionary:
	return {"status":"aborted","actor":_b.field_rules.capture(pokemon),"original_flow":_b.field_rules.capture_flow(),"before_hp":pokemon.estad_ps_actual if pokemon!=null else 0,"presented":false,"claimed":false,"consumed":false}

func _pre_action_live(outcome: Dictionary) -> bool:
	return not outcome.is_empty() and _b.field_rules.valid(outcome.actor) and _b.field_rules.valid_flow(outcome.original_flow)

## Reconcile exactly one owned retirement in an ORIGINAL flow, never the current banks.
## This grants faint settlement only; it never repairs a chosen move's action lease.
func _owned_self_ko_flow(flow: Dictionary,actor: Dictionary,before_hp: int,damage: int) -> Dictionary:
	if actor.is_empty() or before_hp<=0 or damage<before_hp:return {}
	var pokemon: BasePokemon=actor.pokemon
	var state: PokemonEnCombate=actor.state.get_ref()
	if pokemon.estad_ps_actual!=0 or state==null or _b._obtener_combatiente(pokemon)!=state or state.body_attack_epoch!=int(actor.epoch)+1:return {}
	var original: Dictionary=flow.duplicate(true)
	var owned: bool=false
	for record: Dictionary in original.get("records",[]):
		if record.pokemon!=pokemon:continue
		if record.state.get_ref()!=state or int(record.epoch)!=int(actor.epoch) or record.bank!=actor.bank or record.slot.get_ref()!=actor.slot.get_ref() or int(record.generation)!=int(actor.generation):return {}
		record.epoch=int(actor.epoch)+1;owned=true
	return original if owned and _b.field_rules.valid_flow(original) else {}

func _consume_owned_self_ko(outcome: Dictionary,phase: Dictionary) -> bool:
	if str(outcome.get("status","aborted"))!="owned_self_ko" or bool(outcome.consumed) or not bool(outcome.claimed):return false
	if not _b.field_rules.valid_flow(outcome.flow):return false
	# Rebase ONLY the original attempted-result ticket, not the move phase or a new action.
	var ticket: Dictionary=phase.get("source_result_ticket",{})
	if ticket.is_empty() or bool(ticket.committed):return false
	var actor: Dictionary=outcome.actor
	var captured: Dictionary=ticket.actor
	if captured.pokemon!=actor.pokemon or captured.state.get_ref()!=actor.state.get_ref() or int(captured.epoch)!=int(actor.epoch) or captured.bank!=actor.bank or captured.slot.get_ref()!=actor.slot.get_ref() or int(captured.generation)!=int(actor.generation):return false
	var flow: Dictionary=_owned_self_ko_flow(ticket.flow,captured,int(outcome.before_hp),int(outcome.damage))
	if flow.is_empty():return false
	outcome.consumed=true
	for record: Dictionary in flow.records:
		if record.pokemon==actor.pokemon:ticket.actor=record.duplicate(true)
	ticket.flow=flow
	_finalizar_resultado_source(phase,"unable")
	return _b.field_rules.valid_flow(outcome.flow)

func _close_single_self_ko() -> void:
	# No remaining action may target the already-dead active body. Ordinary
	# review/result remains the sole replacement/defeat and next-input authority.
	_b.turno_jugador_pasado=true;_b.turno_enemigo_pasado=true
	_b.fases.cambiar_fase_ronda(MaquinaEstadosBatalla.FaseRonda.REVISAR_RONDA)
	ejecutar_ronda()

## Present the original pre-action check without granting a new move/action lease.
func _presentar_chequeo(chequeo: Dictionary, pokemon: BasePokemon) -> void:
	# Legacy direct presentation callers retain their synchronous seam. Whole-turn
	# callers already captured this receipt in evaluation, before any override yields.
	if not chequeo.has("source_check_outcome"):chequeo.source_check_outcome=_capture_pre_action_outcome(pokemon)
	var outcome: Dictionary=chequeo.source_check_outcome
	if bool(outcome.presented):outcome.status="aborted";return
	outcome.presented=true
	if not _pre_action_live(outcome) or outcome.actor.pokemon!=pokemon or int(outcome.before_hp)<=0:return
	if not bool(chequeo.get("puede_actuar", true)):
		var state := _b._obtener_combatiente(pokemon)
		if state != null: state.cancelar_continuacion()
		if bool(chequeo.get("source_cancel_multi",false)):BattleCounterRules.cancel_multi(state)
		_proyectar_semi(pokemon)
	var mensaje := str(chequeo.get("mensaje", ""))
	var status_key: String=str(chequeo.get("source_status_key",""))
	var source_read_wait: bool=bool(chequeo.get("source_read_wait_64",false)) or status_key in ["ruby:status/1","ruby:status/3","ruby:status/4","ruby:status/5","ruby:status/6"]
	var check_live: Callable=func() -> bool:return _pre_action_live(outcome)
	if not mensaje.is_empty():
		if source_read_wait:
			if not await _mostrar_mensaje_source_64(mensaje,check_live):return
		else:await _b.mostrar_texto_batalla(mensaje)
		if not _pre_action_live(outcome):return
	if not status_key.is_empty():
		if not await presentar_fase_estado(status_key,pokemon) or not _pre_action_live(outcome):return
	for extra in chequeo.get("mensajes_extra", PackedStringArray()):
		if source_read_wait:
			if not await _mostrar_mensaje_source_64(str(extra),check_live):return
		else:await _b.mostrar_texto_batalla(str(extra))
		if not _pre_action_live(outcome):return
	var status_key_final: String=str(chequeo.get("source_status_key_final",""))
	if not status_key_final.is_empty():
		if not await presentar_fase_estado(status_key_final,pokemon) or not _pre_action_live(outcome):return
	if chequeo.has("source_desobediencia") and not await _presentar_desobediencia(chequeo.source_desobediencia,pokemon,check_live):return
	var dano_propio := int(chequeo.get("dano_propio", 0))
	if dano_propio > 0 and pokemon != null:
		var survival: Dictionary=chequeo.get("source_confusion_survival",{})
		if not survival.is_empty():
			if not BattleAttackSurvivalRules.valid(_b,survival):return
			dano_propio=int(survival.requested)
		if bool(outcome.claimed) or not _pre_action_live(outcome) or pokemon.estad_ps_actual!=int(outcome.before_hp):return
		outcome.claimed=true # Claim before the HP/HUD await; never replay selfdamage.
		var committed: Dictionary=await _b._aplicar_danio_a_pokemon(pokemon, _b.hud._obtener_cuadro_ps_de_pokemon(pokemon), dano_propio)
		outcome.damage=int(committed.get("damage",0))
		if pokemon.estad_ps_actual==0:
			var flow: Dictionary=_owned_self_ko_flow(outcome.original_flow,outcome.actor,int(outcome.before_hp),int(outcome.damage))
			if flow.is_empty():return
			outcome.flow=flow;outcome.status="owned_self_ko";return
		if pokemon.estad_ps_actual!=int(outcome.before_hp)-int(outcome.damage):return
	if not bool(outcome.claimed) and pokemon.estad_ps_actual!=int(outcome.before_hp):return
	if _pre_action_live(outcome):outcome.status="live"


## Source status pacing only. Callers retain sole authority for PP and HP.
func presentar_fase_estado(key: String,pokemon: BasePokemon) -> bool:
	if key not in ["ruby:status/0","ruby:status/1","ruby:status/2","ruby:status/3","ruby:status/4","ruby:status/5","ruby:status/6","ruby:status/7","ruby:status/8"] or pokemon==null or pokemon.estad_ps_actual<=0:return false
	var slot: BattleSlot=_b.hud._obtener_slot_de_pokemon(pokemon)
	if slot==null:return false
	var guard: Dictionary=_b.field_rules.capture(pokemon)
	var flow: Dictionary=_b.field_rules.capture_flow()
	var legacy:=MoveAnimationContext.nueva(_b,slot,slot)
	var context:=BattleAnimationContext.from_legacy(legacy);context.phase="status"
	context.set_meta("source_status_anim_active",true)
	var animation:=BattleAnimationDirector.play_key(key,context,true)
	await animation.esperar_finalizada()
	return _b.field_rules.valid(guard) and _b.field_rules.valid_flow(flow)


## ¿Ya ha actuado `pokemon` en la ronda en curso? (el retroceso solo afecta a
## quien aún no ha actuado).
func _ya_actuo(pokemon: BasePokemon) -> bool:
	if _b.formato_batalla == Singleton.FormatoBatalla.DOBLE:
		for accion in _acciones_restantes_dobles:
			if accion.get("actor", null) == pokemon:
				return false
		return true
	if pokemon == _b.poke_jugador:
		return _b.turno_jugador_pasado
	if pokemon == _b.poke_enemigo:
		return _b.turno_enemigo_pasado
	return false


func _es_ultimo_en_actuar(pokemon: BasePokemon) -> bool:
	if _b.formato_batalla == Singleton.FormatoBatalla.DOBLE:
		for accion in _acciones_restantes_dobles:
			var siguiente: BasePokemon = accion.get("actor", null)
			if siguiente != null and siguiente.estad_ps_actual > 0:
				return false
		return true
	if pokemon == _b.poke_jugador:
		return _b.turno_enemigo_pasado
	if pokemon == _b.poke_enemigo:
		return _b.turno_jugador_pasado
	return false


func _finalizar_turno_enemigo() -> void:
	_b.turno_enemigo_pasado = true
	_b.fases.cambiar_fase_ronda(MaquinaEstadosBatalla.FaseRonda.REVISAR_RONDA)
	ejecutar_ronda()


func _ejecutar_accion_objeto_enemigo(accion: Dictionary, actor: BasePokemon = null) -> bool:
	var poke: BasePokemon = actor if actor != null else _b.poke_enemigo
	# Ruby HandleAction_UseItem clears Fury before dispatch/validation.
	var state: PokemonEnCombate=_b._obtener_combatiente(poke)
	if state!=null:state.fury_cutter_count=0;state.source_last_landed_move=0;state.source_last_hit_type="" # ActionFinished.
	var item_name = str(accion.get("item_name", "")).to_upper()
	if item_name.is_empty():
		return false

	var datos: Dictionary = ObjetosEntrenadorIA.DATOS.get(item_name, {})
	if datos.is_empty():
		return false

	# BattleScript_OpponentUses*: pause 48 + SE_USE_ITEM + «{clase} {nombre} usó {objeto}».
	var nombre_objeto := _formatear_nombre_objeto(item_name)
	await _b.get_tree().create_timer(48.0 / 60.0).timeout
	Singleton.play_sound.emit("SE_USE_ITEM_KAIFUKU")
	await _b.mostrar_texto_batalla("¡%s usó %s!" % [_nombre_entrenador_rival(), nombre_objeto])
	match int(datos.tipo):
		ObjetosEntrenadorIA.Tipo.RESTAURAR_TODO:
			if state != null:
				state.esta_confuso = false
				state.turnos_confuso = 0
			poke.estado = Singleton.ProblemaEstado.NORMAL
			_b.hud._obtener_slot_de_pokemon(poke).actualizar_estado(_b.hud._estadoE2S(poke.estado))
			await _curar_rival_con_objeto(poke.estad_ps, nombre_objeto, poke)
		ObjetosEntrenadorIA.Tipo.CURAR_PS:
			await _curar_rival_con_objeto(int(datos.ps), nombre_objeto, poke)
		ObjetosEntrenadorIA.Tipo.ESTADISTICA:
			if state != null:
				state.cambiar_modificador(str(datos.stat), 1)
			await _b.mostrar_texto_batalla(CambioEstadisticaGen3.construir_mensaje_cambio(poke.get_nombre_combate(), str(datos.stat), 1))
		ObjetosEntrenadorIA.Tipo.DIRECTO:
			if state != null:
				state.source_focus_energy = true
			await _b.mostrar_texto_batalla("¡%s usó %s para entusiasmar!" % [poke.get_nombre_combate(), nombre_objeto])
		ObjetosEntrenadorIA.Tipo.PROTECCION:
			_b.screen_rules.produce(poke, "EFFECT_MIST")
			await _b.mostrar_texto_batalla("¡El equipo rival está envuelto en NEBLINA!")
	return true


func _curar_rival_con_objeto(cantidad: int, nombre_objeto: String, poke: BasePokemon) -> void:
	poke.estad_ps_actual = mini(poke.estad_ps, poke.estad_ps_actual + cantidad)
	var tween_curacion = _b.get_tree().create_tween()
	_b.hud._obtener_slot_de_pokemon(poke).actualizar_salud(poke.estad_ps, poke.estad_ps_actual, tween_curacion)
	await tween_curacion.finished
	await _b.mostrar_texto_batalla("¡%s de %s restauró su salud!" % [nombre_objeto, poke.get_nombre_combate()])


func _nombre_entrenador_rival() -> String:
	var entrenador: DatosEntrenador = _b.datos_batalla.get("entrenador", null)
	if entrenador == null:
		return "El entrenador rival"
	return "%s %s" % [entrenador.clase_entrenador, entrenador.nombre]


## Nombre visible del objeto (tabla Objetos, en mayúsculas como en el resto del
## juego); si no existe en la BD cae al nombre interno con «_» por espacios.
func _formatear_nombre_objeto(item_name: String) -> String:
	var datos: Dictionary = SistemaGuardado.obtener_datos_objeto_completos(item_name)
	var nombre: String = str(datos.get("nombre", ""))
	if nombre.is_empty():
		nombre = item_name
	return nombre.replace("_", " ")


## BattleScript_ActionSwitch + atkBA_jumpifnopursuitswitchdmg: si el jugador eligió
## PERSECUCIÓN, aún no actuó y no está dormido, congelado ni holgazaneando, golpea al rival
## que se retira (sin attackcanceler ni accuracycheck) con daño x2 y pierde su turno
## (acción 11). Devuelve true si lo hizo.
func _persecucion_antes_de_cambio_rival() -> bool:
	var move: Movimiento=_b.movimiento_jugador
	if _b.turno_jugador_pasado or not _puede_perseguir(_b.poke_jugador,move,_b.poke_enemigo):return false
	_b.turno_jugador_pasado=true
	await _golpe_persecucion(_b.poke_jugador,move,_b.poke_enemigo)
	return true


## Mismo caso con los bandos cambiados: el rival eligió PERSECUCIÓN en la selección
## (preseleccionar_accion_enemiga) y el jugador se retira. Su turno queda gastado:
## ceder_turno_al_rival() lo salta (source_enemy_pursuit_done).
func persecucion_rival_antes_de_cambio_jugador(objetivo: BasePokemon) -> bool:
	if int(get_meta("source_enemy_action_preselected",-1))!=_b.contador_turnos or str(_b.accion_enemiga.get("type",""))!="attack":return false
	var move: Movimiento=_b.movimiento_enemigo
	if not _puede_perseguir(_b.poke_enemigo,move,objetivo):return false
	set_meta("source_enemy_pursuit_done",true)
	await _golpe_persecucion(_b.poke_enemigo,move,objetivo)
	return true


## BattleScript_ActionSwitch en dobles (setmultihit 2): primero el flanco derecho rival y
## luego el izquierdo. Solo persigue quien eligió PERSECUCIÓN contra el banco de `saliente`
## (moveTarget); pierde su acción (acción 11) y `saliente` debe seguir en pie.
func persecuciones_antes_de_cambio_doble(saliente: BasePokemon) -> bool:
	var opuestos: Array[BasePokemon]=_b.pokemones_activos_enemigo if _b.pokemones_activos_jugador.has(saliente) else _b.pokemones_activos_jugador
	var golpeo: bool=false
	for flanco: int in [1,0]:
		if saliente.estad_ps_actual<=0 or flanco>=opuestos.size():continue
		var perseguidor: BasePokemon=opuestos[flanco]
		for accion: Dictionary in _acciones_restantes_dobles:
			if accion.get("actor",null)!=perseguidor or not accion.has("source_target_bank"):continue
			var move: Movimiento=accion.get("movimiento",null)
			if _b.field_rules.occupant(accion.source_target_bank)!=saliente or not _puede_perseguir(perseguidor,move,saliente):continue
			accion["source_persecucion_consumida"]=true
			_acciones_restantes_dobles.erase(accion)
			await _golpe_persecucion(perseguidor,move,saliente)
			await _presentar_debilitados_dobles()
			golpeo=true
			break
	return golpeo


## atkBA_jumpifnopursuitswitchdmg: eligió PERSECUCIÓN, sigue en pie y no está dormido,
## congelado ni holgazaneando (truantCounter). Un movimiento fijado no es la elección.
func _puede_perseguir(actor: BasePokemon, move: Movimiento, objetivo: BasePokemon) -> bool:
	if move==null or move.get_efecto()!="EFFECT_PURSUIT":return false
	if actor==null or objetivo==null or actor.estad_ps_actual<=0 or objetivo.estad_ps_actual<=0:return false
	if actor.estado in [Singleton.ProblemaEstado.DORMIDO,Singleton.ProblemaEstado.CONGELADO]:return false
	if HabilidadesCombate.holgazanea(actor,_b._obtener_combatiente(actor)):return false
	return BattleLockedMoveRules.move(_b,actor)==null


## BattleScript_PursuitDmgOnSwitchOut: attackstring, ppreduce y el golpe con daño x2
## (ver _calcular_resultado_golpe). En la ROM no hay accuracycheck; aquí el golpe usa la
## resolución normal, así que con precisión/evasión alteradas aún podría fallar.
func _golpe_persecucion(actor: BasePokemon, move: Movimiento, objetivo: BasePokemon) -> void:
	var phase: Dictionary=_capturar_fase_movimiento(actor,move)
	var targets: Array[BasePokemon]=[objetivo]
	await _b.mostrar_texto_batalla("¡%s usó\n%s!" % [actor.get_nombre_combate(), move.nombre])
	if not _consumir_pp_fase_i3(move,move,phase,actor,targets):return
	if actor==_b.poke_jugador:_b.presentacion.menu_movs.set_movs(_movimientos_en_campo(actor))
	set_meta("source_pursuit_switch_target",objetivo)
	await _resolver_accion_objetivos(move,actor,targets,false,true,phase)
	remove_meta("source_pursuit_switch_target")


## ROM: la IA elige su acción en la selección, sin saber que el jugador va a cambiar.
## El cambio voluntario la fija antes de retirar al Pokémon (necesario para PERSECUCIÓN);
## ceder_turno_al_rival() la usa en vez de volver a decidir.
func preseleccionar_accion_enemiga() -> void:
	_establecer_accion_enemiga_seleccionada(seguir_estrategia())
	# Ligada a la ronda: si el cambio se aborta, no se arrastra a otra.
	set_meta("source_enemy_action_preselected",_b.contador_turnos)


func _ejecutar_accion_cambio_enemigo(accion: Dictionary) -> Dictionary:
	var trap: Dictionary=HabilidadesCombate.impide_huida(_b.poke_enemigo,_b.habilidades.crear_campo(),true)
	if not trap.is_empty():
		await _b.mostrar_texto_batalla(HabilidadesCombate.mensaje_impide_huida(trap,true))
		return {"unavailable":true,"trapped":true}
	var pokemon_objetivo = _resolver_pokemon_enemigo_por_snapshot(accion.get("target_pokemon", {}))
	if pokemon_objetivo == null:
		return {"unavailable":true}

	var rules: BattleFieldEffects=_b.field_rules
	var original: Dictionary=rules.capture(_b.poke_enemigo)
	var flow: Dictionary=rules.capture_flow([_b.poke_enemigo])
	# ActionSwitch ends through action11 before advancing the next actor.
	# This operation, not an expired move, owns the original bank0 item.
	var item_tail: Dictionary=preload("res://scripts/battle/held_status_berry_rules.gd").capture_tail(_b,flow)
	await _b.mostrar_texto_batalla("¡El entrenador rival retiró a %s!" % _b.poke_enemigo.get_nombre_mostrar())
	if not rules.valid_flow(flow) or not rules.valid(original):return {}
	if await _persecucion_antes_de_cambio_rival():
		if _b.fase==_b.FIN_BATALLA or not is_instance_valid(_b):return {}
		# BattleScript_PursuitDmgOnSwitchOut: tryfaintmon + getexp; BattleScript_DoSwitchOut
		# sigue y sale el relevo ya elegido, sin returnatktoball porque ya cayó.
		if _b.poke_enemigo.estad_ps_actual<=0 and _b.resultado._enemigo_sin_procesar(_b.poke_enemigo):
			await _b.resultado._procesar_pokemon_enemigo_debilitado(_b.poke_enemigo)
			if _b.fase==_b.FIN_BATALLA or not is_instance_valid(_b):return {}
		# El golpe es otra operación: el cambio sigue con el registro posterior.
		original=rules.capture(_b.poke_enemigo);flow=rules.capture_flow([_b.poke_enemigo])
		if not rules.valid_flow(flow) or not rules.valid(original):return {}
	var entry: Dictionary=await _b.resultado._cambiar_pokemon_enemigo(pokemon_objetivo)
	_marcar_rival_entro_a_mitad_de_ronda()
	if not rules.valid_flow(flow) or not rules.valid(entry):return {}
	# Bind the actual producer's successor lease; never recapture a stranger
	# after the switch await. Both banks must survive item presentation.
	flow.records.append(entry)
	if not await preload("res://scripts/battle/held_status_berry_rules.gd").settle_tail(_b,item_tail):return {}
	return entry if rules.valid_flow(flow) and rules.valid(entry) else {}


func _marcar_rival_entro_a_mitad_de_ronda(pokemon: BasePokemon = null) -> void:
	var state: PokemonEnCombate = _b._obtener_combatiente(pokemon if pokemon != null else _b.poke_enemigo)
	if state != null:
		state.entro_a_mitad_de_ronda = true


func _resolver_pokemon_enemigo_por_snapshot(target_snapshot: Dictionary) -> BasePokemon:
	var team_index = int(target_snapshot.get("team_index", -1))
	if team_index >= 0 and team_index < _b.equipo_enemigo_pokemones.size():
		var pokemon_por_indice = _b.equipo_enemigo_pokemones[team_index]
		if pokemon_por_indice != _b.poke_enemigo and pokemon_por_indice.estad_ps_actual > 0:
			return pokemon_por_indice

	var nombre_interno = str(target_snapshot.get("nombre_interno", ""))
	for pokemon in _b.equipo_enemigo_pokemones:
		if pokemon == null or pokemon == _b.poke_enemigo or pokemon.estad_ps_actual <= 0:
			continue
		if nombre_interno != "" and pokemon.nombre_interno == nombre_interno:
			return pokemon

	return null


## Deja la ronda lista para la siguiente selección de movimiento. Debe llamarse
## en todo camino que cierre una ronda y devuelva el control al menú (también el
## cambio forzado por KO, que sale de revisar_ronda antes de llegar aquí).
func reiniciar_estado_ronda() -> void:
	if has_meta("source_protect_projection_flow"):remove_meta("source_protect_projection_flow")
	_b.accion_enemiga = {}
	_b.movimiento_jugador = null
	_b.movimiento_enemigo = null
	_b.turno_jugador_pasado = false
	_b.turno_enemigo_pasado = false
	_b.fases.cambiar_fase_ronda(MaquinaEstadosBatalla.FaseRonda.PRIORIDADES)


func revisar_ronda():
	if _b.turno_jugador_pasado == true and _b.turno_enemigo_pasado == false:
		# Si el enemigo ya se debilitó, saltar su turno y revisar fin
		if _b.poke_enemigo.estad_ps_actual <= 0:
			_b.turno_enemigo_pasado = true
			_b.fases.cambiar_fase_ronda(MaquinaEstadosBatalla.FaseRonda.REVISAR_RONDA)
			ejecutar_ronda()
			return
		_b.fases.cambiar_fase_ronda(MaquinaEstadosBatalla.FaseRonda.TURNO_ENEMIGO)
		ejecutar_ronda()
	elif _b.turno_jugador_pasado == false and _b.turno_enemigo_pasado == true:
		# Si el Pokémon del jugador ya se debilitó, saltar su turno y revisar fin
		if _b.poke_jugador.estad_ps_actual <= 0:
			_b.turno_jugador_pasado = true
			_b.fases.cambiar_fase_ronda(MaquinaEstadosBatalla.FaseRonda.REVISAR_RONDA)
			ejecutar_ronda()
			return
		_b.fases.cambiar_fase_ronda(MaquinaEstadosBatalla.FaseRonda.TURNO_JUGADOR)
		ejecutar_ronda()
	elif _b.turno_jugador_pasado == true and _b.turno_enemigo_pasado == true:
		if _b.poke_jugador.estad_ps_actual <= 0 or _b.poke_enemigo.estad_ps_actual <= 0:
			if _b.formato_batalla == Singleton.FormatoBatalla.DOBLE:
				if await _b.resultado.verificar_fin_batalla():
					return
			else:
				# BattleTurnPassed: TurnBasedEffects (veneno del que sigue en pie…)
				# antes de HandleFaintedMonActions; EXP y relevo llegan con
				# settle_end_round_faints dentro de _procesar_fin_de_ronda.
				await _b.resultado.presentar_debilitados_del_turno()
		_b.contador_turnos += 1
		if not await _b._procesar_fin_de_ronda(): return
		# Verificar fin de batalla después de cada ronda
		if await _b.resultado.verificar_fin_batalla():
			return  # Salir si la batalla terminó

		reiniciar_estado_ronda()
		# Reuse the real input boundary: source STATUS2_MULTIPLETURNS skips
		# action selection, including the ordinary SIMPLE completed-round path.
		_b.fase_input()


## Source HandleFaintedMonActions precedes the Wish/Future stage. Forced player
## selection suspends this same round; its callback must not open next-round input.
func settle_end_round_faints() -> bool:
	var item_tail: Dictionary=preload("res://scripts/battle/held_status_berry_rules.gd").capture_tail(_b,_b.field_rules.capture_flow())
	var settled_by_result: bool=false
	if _b.formato_batalla == Singleton.FormatoBatalla.DOBLE:
		var fainted := false
		for pokemon in _b.pokemones_activos_jugador + _b.pokemones_activos_enemigo:
			if pokemon != null and pokemon.estad_ps_actual <= 0: fainted = true
		settled_by_result=fainted
		if fainted and await _verificar_fin_batalla_doble():
			future_attacks.clear()
			return false
	else:
		while _future_battle_live() and ((_b.poke_jugador != null and _b.poke_jugador.estad_ps_actual <= 0) or (_b.poke_enemigo != null and _b.poke_enemigo.estad_ps_actual <= 0)):
			settled_by_result=true
			var previous_player := _b.poke_jugador
			var previous_enemy := _b.poke_enemigo
			var previous_player_hp := previous_player.estad_ps_actual if previous_player != null else -1
			var previous_enemy_hp := previous_enemy.estad_ps_actual if previous_enemy != null else -1
			end_round_replacement_pending = true
			var result: BattleResultController=_b.resultado
			var stopped := await result.verificar_fin_batalla()
			if result.entry_settlement_aborted:
				end_round_replacement_pending=false
				# Preserve pending source authority on a live occupant replacement;
				# genuine battle end/exit retains the existing queue retirement.
				if not _future_battle_live():future_attacks.clear()
				return false
			while _future_battle_live() and _b.fase == _b.CAMBIO_POKEMON:
				await _b.get_tree().process_frame
			end_round_replacement_pending = false
			if stopped and not _future_battle_live(): break
			if _future_battle_live() and _b.poke_jugador == previous_player and _b.poke_enemigo == previous_enemy and (_b.poke_jugador.estad_ps_actual if _b.poke_jugador != null else -1) == previous_player_hp and (_b.poke_enemigo.estad_ps_actual if _b.poke_enemigo != null else -1) == previous_enemy_hp:
				push_warning("[BATTLE] End-round faint replacement made no progress; preserving future queue and suspending round")
				return false
	if not _future_battle_live():
		future_attacks.clear()
		return false
	if not settled_by_result and not await preload("res://scripts/battle/held_status_berry_rules.gd").settle_tail(_b,item_tail):return false
	return true


func _future_position(actor: BasePokemon) -> int:
	var position := _posicion_pokemon(actor)
	return int(position.flank) * 2 + (0 if bool(position.player) else 1)

func _future_occupant(position: int) -> BasePokemon:
	if _b.formato_batalla == Singleton.FormatoBatalla.SIMPLE:
		return _b.poke_jugador if position == 0 else _b.poke_enemigo if position == 1 else null
	var side: Array[BasePokemon] = _b.pokemones_activos_jugador if position % 2 == 0 else _b.pokemones_activos_enemigo
	return side[position / 2] if position / 2 < side.size() else null

func _setup_future_attack(move: Movimiento, actor: BasePokemon, targets: Array[BasePokemon]) -> BattleMoveAction:
	var action := BattleMoveAction.new(actor, targets, "future_setup")
	if targets.is_empty(): return action
	var target := targets[0]
	var id := BattleFutureAttackQueue.move_id(move)
	if id == 0:
		action.record(target,"unsupported_future_move",false)
		return action
	var snapshot := BattleFutureAttackQueue.base_damage(move,actor,target,_b._obtener_combatiente(actor),_b._obtener_combatiente(target),_b.habilidades.crear_campo(),preload("res://scripts/battle/source_damage_context.gd").describe(_b,actor,_b._obtener_combatiente(actor)))
	if not future_attacks.schedule(_future_position(target),_future_position(actor),id,snapshot,move,actor):
		action.record(target,"future_queue_occupied",false)
		await _b.mostrar_texto_batalla("¡Pero falló!")
		return action
	action.record(target,"future_scheduled",true,true)
	var presenter := _crear_presentador(action)
	presenter.start(move,ResultadoMovimiento.new())
	await presenter.wait_finished()
	return action

func resolve_future_attacks() -> void:
	if not _future_battle_live():
		future_attacks.clear()
		return
	var positions: Array = []
	for index in range(4):
		if _future_occupant(index) != null: positions.append(index)
	for event in future_attacks.advance(positions):
		if not _future_battle_live():
			future_attacks.clear()
			return
		var target := _future_occupant(event.target_position)
		if target == null or target.estad_ps_actual <= 0: continue
		var actor := _future_occupant(event.attacker_position)
		# Ruby retains battler data when fainted; switched-in actor supplies due accuracy.
		if actor == null: actor = event.setup_actor
		if not _movimiento_acierta(event.move,_b._obtener_combatiente(actor),_b._obtener_combatiente(target),_b.habilidades.crear_campo()):
			_source_no_effect_flags=0 # BattleScript_FutureAttackMiss clears at its end.
			continue
		var target_slot := _b.hud._obtener_slot_de_pokemon(target)
		var attacker_slot: BattleSlot = [_b.slot_jugador,_b.slot_rival,_b.slot_jugador_secundario,_b.slot_rival_secundario][event.attacker_position]
		var legacy := MoveAnimationContext.nueva(_b,attacker_slot,target_slot)
		legacy.action_id = event.get_instance_id()
		legacy.phase = "future_hit"
		legacy.source_damage = BattleFutureAttackQueue.adjusted_damage(event.base_damage,randi())
		var context := BattleAnimationContext.from_legacy(legacy)
		# A fainted setup position can still supply side/pan metadata; never requires HP.
		if not context.actors.has(context.attacker_id) and attacker_slot != null:
			context.attacker_id = int(attacker_slot.posicion_batalla)
			context.actors[context.attacker_id] = BattleAnimationActor.new(context.attacker_id,0 if event.attacker_position%2==0 else 1,attacker_slot.sprite_pokemon,attacker_slot)
		# Due-time ownership starts before General18/19, never at setup or after it.
		# Ruby ActionFinished clears dynamicMoveType; Future retains ambient current move.
		var due_action:=BattleMoveAction.new(actor,[target],"future_due")
		var survival: Dictionary=_prepare_future_survival(due_action,target,int(legacy.source_damage),event.move)
		if survival.is_empty():continue
		legacy.source_damage=int(survival.requested);context.source_damage=legacy.source_damage
		due_action.set_meta("source_survival_receipt",survival)
		var due_result_generation: int=_source_result_generation
		due_action.set_meta("source_rage_result_flags",_source_no_effect_flags)
		preload("res://scripts/battle/rage_rules.gd").bind(_b,due_action)
		var due_receipt: Dictionary=_source_protect_receipt.duplicate(true)
		if not due_receipt.is_empty():
			due_receipt.dynamic_type=0;due_receipt.type=str(due_receipt.table_type)
			due_receipt.category=1 if str(due_receipt.type) in ["NORMAL","LUCHA","VOLADOR","VENENO","TIERRA","ROCA","BICHO","FANTASMA","ACERO"] else 2
		due_action.set_meta("source_protect_receipt",due_receipt)
		due_action.set_meta("source_body_admission",_b.bank_damage_history.admit())
		var animation := _play_future_animation(event.animation_key(),context)
		await animation.esperar_finalizada()
		if not _future_battle_live():
			future_attacks.clear()
			return
		if animation.lifecycle_aborted or _future_occupant(event.target_position) != target or target.estad_ps_actual <= 0: continue
		# Ruby native hitanimation follows General playback, before HP/faint adapters.
		await _future_hit_reaction(target_slot)
		if not _future_battle_live():
			future_attacks.clear()
			return
		if _future_occupant(event.target_position) != target or target.estad_ps_actual <= 0: continue
		# Eligibility is authoritative, not inferred from terminal compatibility impact.
		if event.claim():
			var committed := await _aplicar_dano_ataque(target,actor,_b.hud._obtener_cuadro_ps_de_pokemon(target),legacy.source_damage,AttackProvenance.FUTURE,due_action)
			if not bool(committed.get("aborted",false)) and not await preload("res://scripts/battle/held_survival_presentation.gd").settle(_b,survival):continue
			if bool(committed.get("substitute_broken",false)):await _presentar_rotura_sustituto(target)
			if not bool(committed.get("aborted",false)) and not await preload("res://scripts/battle/rage_rules.gd").grow(_b,due_action,target):continue
		# Source FutureAttackEnd clears only AFTER MoveEnd0 and8..13. An actual
		# newer action during a callback owns its newer result, not this old due.
		if due_result_generation==_source_result_generation:_source_no_effect_flags=0

func _prepare_future_survival(action: BattleMoveAction,target: BasePokemon,damage: int,move: Movimiento) -> Dictionary:
	return BattleAttackSurvivalRules.prepare(_b,action,target,damage,8,move)

func _future_battle_live() -> bool:
	return is_instance_valid(_b) and _b.is_inside_tree() and _b.fase != _b.FIN_BATALLA


func _play_future_animation(key: String, context: BattleAnimationContext) -> BattleSequenceAnimation:
	return BattleAnimationDirector.play_key(key,context,true)


func _future_hit_reaction(slot: BattleSlot) -> void:
	if not is_instance_valid(slot): return
	var sprite := slot.sprite_pokemon
	var generation := slot.animation_generation
	var original := sprite.modulate
	for cycle in 3:
		for alpha in [0.3,original.a]:
			if not _future_battle_live() or not is_instance_valid(slot) or slot.animation_generation != generation:
				if is_instance_valid(slot) and slot.animation_generation == generation and is_instance_valid(sprite): sprite.modulate = original
				return
			sprite.modulate.a = alpha
			await _b.get_tree().create_timer(0.025).timeout
	if is_instance_valid(slot) and slot.animation_generation == generation and is_instance_valid(sprite): sprite.modulate = original

func _sortear_secundario_i4() -> int:return randi()&65535
func _presentar_secundario_i4(presenter: BattleMoveActionPresenter,target: BasePokemon,no_effect: bool,substitute_hit: bool) -> void:
	var fact: BattleHiddenActorRules=BattleHiddenActorRules.facts(presenter.action)
	if fact==null or fact.source_id()!=340 or not presenter.live():return
	var actions: Array[AccionHabilidad]=BattleHiddenSecondaryRules.reached(presenter.action,target,_sortear_secundario_i4(),no_effect,substitute_hit,_b)
	for effect: AccionHabilidad in actions:
		if not presenter.live():return
		await _b.habilidades.presentar([effect])
		if not presenter.live():return


## Source producers deliberately precede generic accuracy/Protect/status gates.
func _resolver_maldicion_pesadilla(move: Movimiento,actor: BasePokemon,target: BasePokemon,presenter: BattleMoveActionPresenter) -> void:
	var action: BattleMoveAction=presenter.action
	if action.has_meta("source_curse_nightmare_produced"):return
	action.set_meta("source_curse_nightmare_produced",true)
	var own: PokemonEnCombate=_b._obtener_combatiente(actor);var victim: PokemonEnCombate=_b._obtener_combatiente(target)
	if move.get_efecto()=="EFFECT_NIGHTMARE":
		var accepted: bool=victim!=null and victim.substitute_hp<=0 and not victim.source_nightmare and target.estado==Singleton.ProblemaEstado.DORMIDO
		action.record(target,"nightmare",accepted,true)
		if accepted:
			action.phase="status";presenter.start(move,ResultadoMovimiento.new());await presenter.wait_finished()
			if not presenter.live(target):return
			victim.source_nightmare=true
		if presenter.live():await _b.mostrar_texto_batalla("¡Comenzó la pesadilla!" if accepted else "¡Pero falló!")
		return
	if preload("res://scripts/battle/curse_nightmare_rules.gd").self_branch(move,actor):
		var accepted: bool=own.mod_velocidad>-6 or own.mod_ataque<6 or own.mod_defensa<6
		action.record(actor,"curse_stats",accepted,true)
		if accepted:
			action.move_turn=1;action.phase="status";presenter.start(move,ResultadoMovimiento.new());await presenter.wait_finished()
			if not presenter.live(actor):return
			# REGLA (decomp, BattleScript_EffectCurse): tras la animación (sin la de cambio de
			# características), VELOCIDAD -1, ATAQUE +1 y DEFENSA +1 por separado, cada una con
			# su texto; statbuffchange con STAT_CHANGE_BS_PTR salta en silencio la que ya está al tope.
			for cambio: Array in [["velocidad",-1],["ataque",1],["defensa",1]]:
				var stat: String=cambio[0];var niveles: int=cambio[1]
				var nivel: int=own.obtener_modificador(stat)
				if (niveles>0 and nivel>=6) or (niveles<0 and nivel<=-6):continue
				own.cambiar_modificador(stat,niveles)
				if not presenter.live():return
				await _b.mostrar_texto_batalla(CambioEstadisticaGen3.construir_mensaje_cambio(actor.get_nombre_combate(),stat,niveles))
			return
		if presenter.live():await _b.mostrar_texto_batalla("¡Pero falló!")
		return
	var accepted: bool=victim!=null and victim.substitute_hp<=0 and not victim.source_cursed and victim.semi_invulnerable.is_empty()
	action.record(target,"curse_target",accepted,true)
	if accepted:
		victim.source_cursed=true
		var self_cost: int=maxi(1,actor.estad_ps/2);var guard: Dictionary=_b.field_rules.capture(actor)
		action.move_turn=0;action.phase="status";presenter.start(move,ResultadoMovimiento.new());await presenter.wait_finished()
		if not presenter.live(actor) or not _b.field_rules.valid(guard):return
		await _b.field_rules.passive_hp(guard,self_cost)
	if presenter.live():await _b.mostrar_texto_batalla("¡Se extendió la maldición!" if accepted else "¡Pero falló!")

func _sortear_ayuda() -> int:return randi()&255

func _pagar_pp_asistencia(action: BattleMoveAction,move: Movimiento,actor: BasePokemon,targets: Array[BasePokemon]) -> bool:
	if action.has_meta("source_assist_paid"):return true
	var guard: Dictionary=action.get_meta("source_screen_phase_guard",{})
	# Nested called dispatch has no selected Assist owner: its caller already
	# owns payment. Never acquire a donor or a fresh party slot on that path.
	if not guard.has("source_assist_pp_owner"):return true
	var original: Movimiento=guard.source_assist_pp_owner
	var paid: bool=_consumir_pp_movimiento(move,actor,targets)
	original.pp_act=move.pp_act
	if paid:action.set_meta("source_assist_paid",true)
	_b.presentacion.menu_movs.set_movs(_movimientos_en_campo(_b.poke_jugador))
	return paid


func _sortear_sonambulo() -> int:return randi()&3


func _sortear_metronomo() -> int:return randi()&65535

## Ruby A5 plans a common average before animation; no attack/heal side effects.
func _resolver_divide_dolor(move: Movimiento,actor: BasePokemon,target: BasePokemon,presenter: BattleMoveActionPresenter) -> void:
	var action: BattleMoveAction=presenter.action
	if action.has_meta("source_pain_split_resolved"):return
	action.set_meta("source_pain_split_resolved",true)
	var accepted: Dictionary=preload("res://scripts/battle/pain_split_rules.gd").plan(actor,target,_b._obtener_combatiente(target))
	action.record(target,"pain_split",not accepted.is_empty(),true)
	if accepted.is_empty():
		if presenter.live(target):await _b.mostrar_texto_batalla("¡Pero falló!")
		return
	action.phase="status";presenter.start(move,ResultadoMovimiento.new());await presenter.wait_finished()
	if not presenter.live(actor) or not presenter.live(target):return
	preload("res://scripts/battle/pain_split_rules.gd").commit(actor,target,accepted)
	for pokemon: BasePokemon in [actor,target]:
		var bar: Node=_b.hud._obtener_cuadro_ps_de_pokemon(pokemon)
		if bar!=null:await _b.hud.animar_dano(bar,pokemon.estad_ps,pokemon.estad_ps_actual)
		if not presenter.live(actor) or not presenter.live(target):return
	await _b.mostrar_texto_batalla("¡Los Pokémon compartieron su salud!")

func _resolver_memento(move: Movimiento,actor: BasePokemon,target: BasePokemon,presenter: BattleMoveActionPresenter) -> void:
	var action: BattleMoveAction=presenter.action
	if action.has_meta("source_memento_produced"):return
	action.set_meta("source_memento_produced",true)
	var victim: PokemonEnCombate=_b._obtener_combatiente(target)
	if victim==null or (victim.mod_ataque<=-6 and victim.mod_ataque_especial<=-6):
		action.record(target,"memento_failed",false);await _b.mostrar_texto_batalla("¡Pero falló!");return
	# atk79 sets actual party/battle HP BEFORE animation, without inventing an attack.
	# Normal round/result settlement owns faint messages, replacement and entry.
	actor.estad_ps_actual=0
	await _b.hud.animar_dano(_b.hud._obtener_cuadro_ps_de_pokemon(actor),actor.estad_ps,0)
	if not presenter.live(target):return
	action.phase="status";presenter.start(move,ResultadoMovimiento.new());await presenter.wait_finished()
	if not presenter.live(target):return
	if victim.substitute_hp<=0:
		await _b.habilidades.presentar([AccionHabilidad.stat_group(target,victim,[["ataque",-2],["ataque_especial",-2]],true)])
	action.record(target,"memento",true,true)


func _consumir_recarga_source(actor: BasePokemon) -> bool:
	if actor==null or actor.estad_ps_actual<=0:return false
	var state: PokemonEnCombate=_b._obtener_combatiente(actor)
	if state==null or state.source_recharge_turns<=0:return false
	# atkCanceller comprueba sueño, congelación y Ausente antes: los resuelve
	# _evaluar_accion_antes_de_moverse, que recarga si el Pokémon sigue pudiendo actuar.
	if actor.estado in [Singleton.ProblemaEstado.DORMIDO,Singleton.ProblemaEstado.CONGELADO] or HabilidadesCombate.holgazanea(actor,state):return false
	# No accepted action/result ticket or selected move PP belongs to this turn.
	state.source_recharge_turns=0
	await _b.mostrar_texto_batalla("¡%s debe recargar energía!"%actor.get_nombre_combate())
	return true


func _sortear_magnitud() -> int:
	return randi()%100


func _sortear_regalo() -> int:
	return randi()&255

func _sortear_espejo() -> int:return randi()
func _sortear_objetivo_arrastre_llamado_source(_actor: BasePokemon) -> int:return randi()&65535
func _sortear_objetivo_llamado(count: int) -> int:return randi()%count
func _pagar_pp_espejo(action: BattleMoveAction,move: Movimiento,called: Movimiento,targets: Array[BasePokemon]) -> bool:
	if action.has_meta("source_mirror_paid"):return true
	var guard: Dictionary=action.get_meta("source_screen_phase_guard",{})
	if not guard.has("source_mirror_pp_owner"):return true
	var original: Movimiento=guard.source_mirror_pp_owner
	var policy: Movimiento=move if called==null else Movimiento.new(called.nombre,move.pp_act,move.pp_mas,move.pp_tot,called.datos.duplicate(true))
	var paid: bool=_consumir_pp_movimiento(policy,action.attacker,targets);move.pp_act=policy.pp_act;original.pp_act=move.pp_act
	if paid:action.set_meta("source_mirror_paid",true)
	_b.presentacion.menu_movs.set_movs(_movimientos_en_campo(_b.poke_jugador));return paid

func _sortear_duracion_atadura() -> int:return randi()&65535

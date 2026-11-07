## Etapa 5.3 del rediseño de arquitectura (SDD 2026-09-14-battle-architecture-split):
## dueño de "qué pasa cuando la batalla termina o un Pokémon cambia" —
## victoria/derrota/captura, debilitación del enemigo + ganancia de EXP y
## subida de nivel, y el cambio de Pokémon del jugador (voluntario y
## forzado) junto con el cambio automático del enemigo.
##
## Deliberadamente NO incluye: `intentar_huida()`/`_esperar_accion_cancelar()`
## (despachadores del menú principal, igual que `_on_batalla_menu_1_seleccionado`,
## que también se queda en `_b`); `_restaurar_orden_original_equipo()` (utilidad
## de equipo compartida por huida/captura/victoria/derrota/`_exit_tree()`, no
## exclusiva de este controlador); `_reproducir_musica_batalla_mapa_si_corresponde()`
## (concierne al INICIO de la batalla, no al final).
extends RefCounted
class_name BattleResultController

## Caja elegida (o -1 al cancelar) en la pantalla de equipo abierta por
## _ofrecer_cambio_antes_de_rival().
signal _cambio_antes_de_rival_resuelto(indice_visual: int)

## BATTLE_TEXT_WillSwitch, partido en sus dos páginas (\p).
const TEXTO_PROXIMO_POKEMON_RIVAL := "%s será el próximo POKéMON\nde %s %s."
const TEXTO_QUIERES_CAMBIAR := "¿Quieres cambiar\nde POKéMON?"
## BATTLE_TEXT_UseNext / BATTLE_TEXT_CantEscape.
const TEXTO_USAR_SIGUIENTE := "¿Usas el siguiente POKéMON?"
const TEXTO_NO_PUEDES_HUIR := "¡No puedes huir!"

## nombre_interno del REPARTIR EXP (HOLD_EFFECT_EXP_SHARE).
const OBJETO_REPARTIR_EXP := "REPARTIREXP"
## nombre_interno del HUEVO SUERTE (HOLD_EFFECT_LUCKY_EGG).
const OBJETO_HUEVO_SUERTE := "HUEVOSUERTE"

## Temas de temas_musicales.json que suenan al ganar la batalla.
const TEMA_VICTORIA_SALVAJE := "POKEMON_SALVAJE_DERROTADO"
const TEMA_VICTORIA_ENTRENADOR := "ENTRENADOR_DERROTADO"
## HandleEndTurn_BattleWon (battle_2.c): el tema de victoria sale de la clase
## del entrenador. MUS_KACHI5 (ALTO MANDO y CAMPEÓN) aún no está en
## temas_musicales.json, así que esas clases usan el tema normal.
const TEMAS_VICTORIA_POR_CLASE: Dictionary = {
	"EQUIPO AQUA": "EQUIPO_AQUA_MAGMA_DERROTADO",
	"EQUIPO MAGMA": "EQUIPO_AQUA_MAGMA_DERROTADO",
	"ADMIN. AQUA": "EQUIPO_AQUA_MAGMA_DERROTADO",
	"ADMIN. MAGMA": "EQUIPO_AQUA_MAGMA_DERROTADO",
	"LÍDER AQUA": "EQUIPO_AQUA_MAGMA_DERROTADO",
	"LÍDER MAGMA": "EQUIPO_AQUA_MAGMA_DERROTADO",
	"LÍDER": "LIDER_GIMNASIO_DERROTADO",
}
const SCN_PANTALLA_REGISTRO: PackedScene = preload("res://escenas/batalla/pantalla_registro_captura.tscn")

var _b: BattleSceneController
signal baton_party_chosen(index: int)
var baton_choice_pending: bool=false
var _baton_actor: BasePokemon
var _baton_transaction: Dictionary={}
## Elección del relevo de un slot doble caído (elegir_relevos_dobles_jugador).
var _relevo_doble_pendiente: bool = false
var _relevo_doble_candidatos: Array[int] = []
var _relevo_doble_eleccion: int = -1
func baton_has_replacement(actor: BasePokemon) -> bool:
	if _b.formato_batalla==Singleton.FormatoBatalla.DOBLE:return not preload("res://scripts/battle/baton_bank_transaction.gd").candidates(_b,actor).is_empty()
	if _b.formato_batalla!=Singleton.FormatoBatalla.SIMPLE:return false
	var team: Array[BasePokemon]=_b.equipo_jugador_pokemones if actor==_b.poke_jugador else _b.equipo_enemigo_pokemones
	for pokemon: BasePokemon in team:
		if pokemon!=null and pokemon!=actor and pokemon.puede_combatir():return true
	return false
func baton_pass(actor: BasePokemon,transfer: Dictionary) -> Dictionary:
	if not baton_has_replacement(actor):return {}
	var rules: BattleFieldEffects=_b.field_rules
	var original: Dictionary=rules.capture(actor)
	if not rules.valid(original):return {}
	# Source departing ball has already hidden the old actor. Keep it hidden
	# across the source menu boundary, without another visual gameplay command.
	_b.hud._obtener_slot_de_pokemon(actor).sprite_pokemon.visible=false
	if actor==_b.poke_enemigo:
		return await _cambiar_pokemon_enemigo(elegir_relevo_rival(actor),transfer)
	_baton_actor=actor
	await _b.mostrar_pantalla_equipo("Elegir un POKéMON.",Singleton.ModoPEquipo.BATALLA_CAMBIO_FORZADO)
	baton_choice_pending=true
	var index: int=await baton_party_chosen
	baton_choice_pending=false;_baton_actor=null
	_b.presentacion.pantalla_equipo.ocultar_pantalla_equipo()
	await _b.presentacion.aclarar()
	if not rules.valid(original):return {}
	return await _ejecutar_cambio_pokemon_animado(actor,_b.equipo_jugador_pokemones[index],index,transfer)
func _baton_substitute_view(pokemon: BasePokemon) -> void:
	var state: PokemonEnCombate=_b._obtener_combatiente(pokemon)
	if state!=null and state.substitute_hp>0:
		BattleSubstitutePresentation.ensure_doll(BattleSubstitutePresentation.capture(_b.hud._obtener_slot_de_pokemon(pokemon)))

var _musica_victoria_iniciada: bool = false
var pay_day_money: int=0
## gBattleStruct->moneyMultiplier: 2 si entró al campo alguien con MON. AMULETO.
var multiplicador_dinero: int=1
var _pay_day_awarded: bool=false
func scatter_pay_day(actor: BasePokemon) -> void:
	# Source MOVE_EFFECT_PAYDAY adds only PLAYER-side coins, even after targetKO.
	if bool(_b.field_rules.position(actor).get("player",false)):
		pay_day_money=mini(65535,pay_day_money+actor.nivel*5)
func _conceder_dinero_dia_pago() -> void:
	if _pay_day_awarded:return
	_pay_day_awarded=true
	if pay_day_money<=0:return
	# atk91_givepaydaymoney: el multiplicador va al dinero, no al texto.
	var amount: int=mini(pay_day_money*multiplicador_dinero,maxi(0,999999-SistemaGuardado.get_dinero_jugador()))
	if amount>0:SistemaGuardado.dar_dinero_jugador(amount)
	await _b.mostrar_texto_batalla("¡Recogiste %s$!"%pay_day_money)
var _premio_entrenador_concedido: bool = false
var _victoria_entrenador_presentada: bool = false
## HandleAction_ActionFinished must follow the whole accepted switch, including
## successive entry KOs. This is not an end-round replacement continuation.
var _manual_switch_continuation: Dictionary = {}
## Original non-replaced banks and round survive a suspended replacement menu.
## Never recapture these after an entry KO or a later party choice.
var _player_switch_flow: Dictionary = {}
var _player_switch_sequence: int=0
var _player_switch_entry_accepted: bool=false

func _acquire_player_switch_flow() -> Dictionary:
	if _player_switch_flow.is_empty():
		_player_switch_sequence+=1
		_player_switch_flow=_b.field_rules.capture_flow([_b.poke_jugador])
		if not _player_switch_flow.is_empty():_player_switch_flow["operation"]=_player_switch_sequence
		_player_switch_entry_accepted=false
	return _player_switch_flow

func _owns_player_switch_flow(flow: Dictionary) -> bool:
	return not flow.is_empty() and flow.has("operation") and int(flow.operation)==_player_switch_sequence and int(_player_switch_flow.get("operation",-1))==int(flow.operation)

func _valid_player_switch_flow(flow: Dictionary) -> bool:
	return _b.field_rules.valid_flow(flow) and (not flow.has("operation") or _owns_player_switch_flow(flow))

func _retire_player_switch_flow(flow: Dictionary) -> bool:
	if not _owns_player_switch_flow(flow):return false
	# Replace the owner reference; do not mutate the captured record of an old callback.
	_player_switch_flow={};_player_switch_entry_accepted=false
	return true
## bool settlement API means "stop", not "accepted". Keep abortion explicit
## for suspended end-round consumers that distinguish a player selection wait.
var entry_settlement_aborted: bool=false
## Pokémon del jugador ya penalizados en amistad por debilitarse (se quitan si
## los reviven, para que un nuevo debilitamiento vuelva a contar).
var _debilitados_amistad: Array[BasePokemon] = []
## Pokémon del jugador cuyo debilitamiento ya se mostró (se quitan si los reviven).
var _debilitados_presentados: Array[BasePokemon] = []
## Rivales cuyo «se debilitó» ya salió en el turno y esperan la EXP del fin de ronda.
var _exp_pendiente: Array[BasePokemon] = []
## HITMARKER_PLAYER_FAINTED con el rival también debilitado (Explosión, Mismo Destino…):
## el relevo del jugador no ofrece «¿Quieres cambiar?» y sus habilidades de entrada
## esperan a que salga el relevo rival.
var _relevo_doble: bool = false
var _entrada_jugador_diferida: Dictionary = {}
## Solo durante el cambio aceptado en _ofrecer_cambio_antes_de_rival.
var _diferir_entrada_jugador: bool = false
## Interfaz de DialogoAprendizaje para los movimientos aprendidos al subir de nivel
## (AprendizajeBatalla o un doble en las pruebas: `aprender(pokemon, nivel, datos)` y
## `tocar_fanfarria()`).
var aprendizaje_movimientos: Object
## Datos del learnset (DatosCrianza por defecto; las pruebas pueden inyectar un doble).
var datos_aprendizaje: Object = null


func _init(batalla: BattleSceneController) -> void:
	_b = batalla
	aprendizaje_movimientos = AprendizajeBatalla.new(batalla)


## `atk19_tryfaintmon`: FRIENDSHIP_EVENT_FAINT_SMALL / FAINT_LARGE para cada
## Pokémon activo del jugador que acaba de debilitarse, según el nivel del rival.
## TODO: el decomp compara con el atacante concreto; en dobles se usa el rival
## activo de más nivel.
func registrar_debilitados_jugador() -> void:
	var activos: Array = [_b.poke_jugador]
	var rivales: Array = [_b.poke_enemigo]
	if _b.formato_batalla == Singleton.FormatoBatalla.DOBLE:
		activos = _b.pokemones_activos_jugador
		rivales = _b.pokemones_activos_enemigo
	var nivel_rival := 0
	for rival in rivales:
		if rival is BasePokemon:
			nivel_rival = maxi(nivel_rival, (rival as BasePokemon).nivel)
	for poke in activos:
		if not (poke is BasePokemon):
			continue
		if poke.estad_ps_actual > 0:
			_debilitados_amistad.erase(poke)
		elif not _debilitados_amistad.has(poke):
			_debilitados_amistad.append(poke)
			# atk19_tryfaintmon: gBattleResults.playerFaintCounter.
			ResultadosCombate.registrar_debilitado_jugador()
			Amistad.aplicar_debilitado_en_combate(poke, nivel_rival)


## ============================================================================
## Fin de batalla: victoria / derrota / captura
## ============================================================================

func verificar_fin_batalla() -> bool:
	entry_settlement_aborted=false
	var rules: BattleFieldEffects=_b.field_rules
	var flow: Dictionary=rules.capture_flow([_b.poke_enemigo] if _b.poke_enemigo!=null and _b.poke_enemigo.estad_ps_actual<=0 else [])
	if not rules.valid_flow(flow):entry_settlement_aborted=true;return true
	var item_tail: Dictionary=preload("res://scripts/battle/held_status_berry_rules.gd").capture_tail(_b,flow)
	registrar_debilitados_jugador()
	if _b.poke_jugador.estad_ps_actual <= 0:
		await _procesar_pokemon_jugador_debilitado(_b.poke_jugador)
		if not rules.valid_flow(flow):entry_settlement_aborted=true;return true
	# Explosión / Mismo Destino debilitan a los dos: `tryfaintmon TARGET` y luego
	# `tryfaintmon USER`; getexp corre antes que atk24, que da la victoria si el
	# rival no tiene más, sin pedir relevo. Con más rivales, el relevo del jugador
	# va antes (HandleFaintedMonActions) y el del rival al terminar el cambio forzado.
	if _b.poke_jugador.estad_ps_actual <= 0 and _b.poke_enemigo.estad_ps_actual <= 0 \
			and _enemigo_sin_procesar(_b.poke_enemigo):
		await _procesar_pokemon_enemigo_debilitado(_b.poke_enemigo)
		if not rules.valid_flow(flow):entry_settlement_aborted=true;return true
		if obtener_siguiente_pokemon_jugador() != null and obtener_siguiente_pokemon_enemigo() == null:
			await mostrar_resultado_victoria()
			return true
	# Verificar si el Pokémon actual del jugador se debilitó
	if _b.poke_jugador.estad_ps_actual <= 0:
		var siguiente_jugador = obtener_siguiente_pokemon_jugador()
		if siguiente_jugador == null:
			# El jugador perdió
			await mostrar_resultado_derrota()
			return true
		else:
			if await _preguntar_usar_siguiente():
				return true
			# Rival también debilitado con relevo: ver _relevo_doble.
			_relevo_doble = _b.poke_enemigo != null and _b.poke_enemigo.estad_ps_actual <= 0
			# Forzar cambio de Pokémon
			iniciar_cambio_pokemon_forzado()
			return true

	# Verificar si el Pokémon actual del enemigo se debilitó
	if _b.poke_enemigo.estad_ps_actual <= 0:
		var pokemon_derrotado = _b.poke_enemigo
		if _enemigo_sin_procesar(pokemon_derrotado):
			await _procesar_pokemon_enemigo_debilitado(pokemon_derrotado)
		if not rules.valid_flow(flow):entry_settlement_aborted=true;return true
		# openpartyscreen: el rival elige antes de ofrecer «¿Quieres cambiar?».
		var siguiente_enemigo = elegir_relevo_rival(pokemon_derrotado)
		_relevo_rival_elegido = siguiente_enemigo
		if siguiente_enemigo == null:
			# El jugador ganó
			await mostrar_resultado_victoria()
			return true
		else:
			# REGLA (decomp, BattleScript_FaintedMonTryChooseAnother): con HITMARKER_PLAYER_FAINTED
			# no se pregunta «¿Quieres cambiar?»; el jugador ya eligió su relevo.
			var optional_entry: Dictionary = {} if _relevo_doble else await _ofrecer_cambio_antes_de_rival(siguiente_enemigo)
			if not optional_entry.is_empty():
				# Advance only the player bank accepted by the optional switch.
				if not rules.valid(optional_entry):entry_settlement_aborted=true;return true
				for index: int in range(flow.records.size() - 1, -1, -1):
					if flow.records[index].bank == optional_entry.bank:flow.records.remove_at(index)
				flow.records.append(optional_entry)
				item_tail = preload("res://scripts/battle/held_status_berry_rules.gd").capture_tail(_b, flow)
			if not rules.valid_flow(flow):entry_settlement_aborted=true;return true
			# El enemigo cambia automáticamente
			var entry: Dictionary=await cambiar_pokemon_enemigo_automatico()
			if not rules.valid_flow(flow) or not rules.valid(entry):entry_settlement_aborted=true;return true
			# Spikes may faint this replacement too. HandleFaintedMon settles
			# every accepted entry before returning control to action selection.
			if not is_instance_valid(_b) or not _b.is_inside_tree() or _b.fase==_b.FIN_BATALLA:return true
			# HandleFaintedMonActions caso 6: con los dos relevos en el campo, las habilidades
			# de entrada diferidas del jugador (Intimidación…) ya tienen rival.
			await _resolver_entrada_jugador_diferida()
			if _b.poke_enemigo.estad_ps_actual<=0:return await verificar_fin_batalla()
			# Bind the producer's accepted successor, not a current recapture.
			flow.records.append(entry)
			if not await preload("res://scripts/battle/held_status_berry_rules.gd").settle_tail(_b,item_tail):entry_settlement_aborted=true;return true
			return false  # La batalla continúa

	if not await preload("res://scripts/battle/held_status_berry_rules.gd").settle_tail(_b,item_tail):entry_settlement_aborted=true;return true
	return false


## Cierra el relevo doble: corre las habilidades de entrada que el relevo del jugador
## difirió (ver _relevo_doble). Si la entrada ya no vale, no hace nada.
func _resolver_entrada_jugador_diferida() -> void:
	_relevo_doble = false
	if _entrada_jugador_diferida.is_empty():
		return
	var entry: Dictionary = _entrada_jugador_diferida
	_entrada_jugador_diferida = {}
	if _b.field_rules.valid(entry):
		await _b.habilidades.al_entrar(entry.pokemon, true, entry)


## BattleScript_FaintedMonTryChooseAnother: solo en combates individuales contra
## entrenador, con el estilo de combate CAMBIAR, el Pokémon del jugador en pie
## y otro que pueda salir. Anuncia al siguiente del rival y, con SÍ, abre el
## equipo (se puede cancelar); el cambio no gasta turno.
func _ofrecer_cambio_antes_de_rival(siguiente: BasePokemon) -> Dictionary:
	if not _puede_ofrecer_cambio_antes_de_rival():
		return {}
	var entrenador: Dictionary = _b.intro_controller._presentacion_entrenador()
	await _b._mostrar_texto_y_esperar_confirmacion(TEXTO_PROXIMO_POKEMON_RIVAL % [
		siguiente.get_nombre_mostrar(), entrenador.clase, entrenador.nombre])
	await _b.mostrar_texto_batalla(TEXTO_QUIERES_CAMBIAR)
	if not await _b.presentacion.preguntar_si_no():
		return {}

	var pantalla: PantallaEquipoControlador = _b.presentacion.pantalla_equipo
	var al_elegir := Callable(self, "_on_cambio_antes_de_rival_elegido")
	var al_cancelar := Callable(self, "_on_cambio_antes_de_rival_cancelado")
	if pantalla.pokemon_elegido.is_connected(Callable(self, "_on_pokemon_seleccionado")):
		pantalla.pokemon_elegido.disconnect(Callable(self, "_on_pokemon_seleccionado"))
	if pantalla.seleccion_cancelada.is_connected(Callable(self, "_on_seleccion_cancelada")):
		pantalla.seleccion_cancelada.disconnect(Callable(self, "_on_seleccion_cancelada"))
	pantalla.pokemon_elegido.connect(al_elegir)
	pantalla.seleccion_cancelada.connect(al_cancelar)
	_b.mostrar_pantalla_equipo("Elegir un POKéMON.", Singleton.ModoPEquipo.BATALLA_CAMBIO_OPCIONAL)
	var indice_visual: int = await _cambio_antes_de_rival_resuelto
	pantalla.pokemon_elegido.disconnect(al_elegir)
	pantalla.seleccion_cancelada.disconnect(al_cancelar)
	_b._reconectar_pantalla_equipo_resultado()
	_b.ignorar_input_temporal = true
	if indice_visual < 0:
		pantalla.ocultar_pantalla_equipo()
		return {}
	return await _cambiar_antes_de_rival(_b.indice_equipo_desde_visual(indice_visual))


func _cambiar_antes_de_rival(indice: int) -> Dictionary:
	# REGLA (decomp, BattleScript_FaintedMonTryChooseAnother + HandleFaintedMonActions caso 6):
	# el switchineffects del jugador solo marca STATUS3_INTIMIDATE_POKES; Intimidación y Rastro
	# se resuelven después de que entra el relevo rival, así que aquí también se difieren.
	_diferir_entrada_jugador = true
	var entry: Dictionary = await _ejecutar_cambio_pokemon_animado(_b.poke_jugador, _b.equipo_jugador_pokemones[indice], indice)
	_diferir_entrada_jugador = false
	return entry


## BattleScript_HandleFaintedMon: en combate salvaje individual, al debilitarse
## el Pokémon del jugador se pregunta si se usa el siguiente. Con NO se intenta
## huir (jumpifplayerran); si falla, "¡No puedes huir!" y se elige igualmente.
## Devuelve true si el combate terminó por huida.
func _preguntar_usar_siguiente() -> bool:
	if _b.tipo_batalla != Singleton.TipoBatalla.SALVAJE \
			or _b.formato_batalla == Singleton.FormatoBatalla.DOBLE \
			or _b.poke_enemigo == null or _b.poke_enemigo.estad_ps_actual <= 0:
		return false
	await _b.mostrar_texto_batalla(TEXTO_USAR_SIGUIENTE)
	if await _b.presentacion.preguntar_si_no():
		return false
	if _b.intentar_huida_jugador():
		await _b.terminar_batalla_por_huida()
		return true
	await _b._mostrar_texto_y_esperar_confirmacion(TEXTO_NO_PUEDES_HUIR)
	return false


func _puede_ofrecer_cambio_antes_de_rival() -> bool:
	if _b.tipo_batalla != Singleton.TipoBatalla.ENTRENADOR:
		return false
	if _b.formato_batalla == Singleton.FormatoBatalla.DOBLE:
		return false
	if int(SistemaGuardado.datos_vivos.opciones.tipo_combate) != Singleton.TipoCombate.CAMBIAR:
		return false
	if _b.poke_jugador == null or _b.poke_jugador.estad_ps_actual <= 0:
		return false
	return obtener_siguiente_pokemon_jugador() != null


func _on_cambio_antes_de_rival_elegido(indice_visual: int) -> void:
	_cambio_antes_de_rival_resuelto.emit(indice_visual)


func _on_cambio_antes_de_rival_cancelado() -> void:
	_cambio_antes_de_rival_resuelto.emit(-1)


func obtener_siguiente_pokemon_jugador():
	for i in range(_b.equipo_jugador_pokemones.size()):
		if i != _b.indice_pokemon_jugador and _b.equipo_jugador_pokemones[i].puede_combatir():
			return _b.equipo_jugador_pokemones[i]
	return null


## Relevo del rival según OpponentHandlecmd22; sin IA, el siguiente por orden de equipo.
func elegir_relevo_rival(saliente: BasePokemon) -> BasePokemon:
	var elegido: BasePokemon = _b.ai_integrador.elegir_relevo_rival(saliente) if _b.ai_integrador != null else null
	return elegido if elegido != null else obtener_siguiente_pokemon_enemigo()


func obtener_siguiente_pokemon_enemigo():
	for i in range(_b.equipo_enemigo_pokemones.size()):
		if i != _b.indice_pokemon_enemigo and _b.equipo_enemigo_pokemones[i].estad_ps_actual > 0:
			return _b.equipo_enemigo_pokemones[i]
	return null


## Función para iniciar un cambio de pokémon forzado (cuando el actual se debilita).
func iniciar_cambio_pokemon_forzado():
	var flow: Dictionary=_acquire_player_switch_flow()
	if not _valid_player_switch_flow(flow):return
	_b.fases.cambiar_fase(_b.CAMBIO_POKEMON)
	# El «¡X se debilitó!» ya salió en la caja de combate (BattleScript_FaintTarget).
	_b.mostrar_pantalla_equipo("Elegir un POKéMON.", Singleton.ModoPEquipo.BATALLA_CAMBIO_FORZADO)


## atk50_openpartyscreen (caso 5, combate doble): por cada slot del jugador que
## cayó y tiene reservas se abre el equipo, sin cancelar, aunque solo quede una
## opción; primero el slot izquierdo y luego el derecho, que no puede repetir la
## elección anterior (monToSwitchIntoId). Devuelve {slot: BasePokemon}; los
## slots sin elección quedan para _reponer_slots_dobles().
func elegir_relevos_dobles_jugador(flow: Dictionary) -> Dictionary:
	var elecciones: Dictionary = {}
	var activos: Array[BasePokemon] = _b.pokemones_activos_jugador
	var equipo: Array[BasePokemon] = _b.equipo_jugador_pokemones
	var pantalla: PantallaEquipoControlador = _b.presentacion.pantalla_equipo
	if not is_instance_valid(pantalla):
		return elecciones
	for slot in range(mini(activos.size(), 2)):
		var caido: BasePokemon = activos[slot]
		if caido == null or caido.estad_ps_actual > 0:
			continue
		var bloqueados: Array[int] = []
		for pokemon: BasePokemon in activos:
			if pokemon != null:
				bloqueados.append(equipo.find(pokemon))
		for pokemon: BasePokemon in elecciones.values():
			bloqueados.append(equipo.find(pokemon))
		_relevo_doble_candidatos.clear()
		for i in range(equipo.size()):
			var candidato: BasePokemon = equipo[i]
			if candidato != null and candidato.puede_combatir() and not bloqueados.has(i):
				_relevo_doble_candidatos.append(i)
		if _relevo_doble_candidatos.is_empty():
			continue
		_relevo_doble_eleccion = -1
		_relevo_doble_pendiente = true
		pantalla.set_meta("relevo_doble_obligatorio", true)
		pantalla.set_meta("battle_blocked_party_indices", bloqueados)
		await _b.mostrar_pantalla_equipo("Elegir un POKéMON.", Singleton.ModoPEquipo.BATALLA_CAMBIO_FORZADO)
		while _relevo_doble_eleccion < 0 and is_instance_valid(_b) and _b.is_inside_tree() and _b.field_rules.valid_flow(flow):
			await _b.get_tree().process_frame
		_relevo_doble_pendiente = false
		if is_instance_valid(pantalla):
			pantalla.ocultar_pantalla_equipo()
			pantalla.remove_meta("relevo_doble_obligatorio")
			pantalla.remove_meta("battle_blocked_party_indices")
		if _relevo_doble_eleccion < 0:
			return elecciones
		elecciones[slot] = equipo[_relevo_doble_eleccion]
		_b.ignorar_input_temporal = true
		await _b.presentacion.aclarar()
	return elecciones


## Relevo ya elegido en `verificar_fin_batalla`.
var _relevo_rival_elegido: BasePokemon = null

func cambiar_pokemon_enemigo_automatico() -> Dictionary:
	var siguiente: BasePokemon = _relevo_rival_elegido
	_relevo_rival_elegido = null
	if siguiente:
		return await _cambiar_pokemon_enemigo(siguiente)
	return {}


func _cambiar_pokemon_enemigo(pokemon_nuevo: BasePokemon, baton: Dictionary={}, arrastre: bool=false) -> Dictionary:
	var rules: BattleFieldEffects=_b.field_rules
	var flow: Dictionary=rules.capture_flow([_b.poke_enemigo])
	var original: Dictionary=rules.capture(_b.poke_enemigo)
	if not rules.valid_flow(flow) or not rules.valid(original) or pokemon_nuevo==null or not _b.equipo_enemigo_pokemones.has(pokemon_nuevo):return {}
	# Antes de retirar el estado de combate: eso cambia la época de `original`.
	if arrastre:_quitar_de_campo_al_instante(_b.slot_rival)
	else:await _animar_retirada_pokemon_enemigo(_b.poke_enemigo)
	if not rules.valid_flow(flow) or not rules.valid(original):return {}
	_b._retirar_sustituto_de_pokemon(_b.poke_enemigo)
	_b.habilidades.al_salir(_b.poke_enemigo)
	for i in range(_b.equipo_enemigo_pokemones.size()):
		if _b.equipo_enemigo_pokemones[i] == pokemon_nuevo:
			# Como en _cambiar_pokemon_directo: sin estado viejo en combatientes_activos.
			_b.combatientes_activos.erase(_b.poke_enemigo)
			_b._liberar_enamorados_de(_b.poke_enemigo)
			_b.indice_pokemon_enemigo = i
			_b.poke_enemigo = pokemon_nuevo
			_b.combatiente_enemigo = _b.PokemonCombatState.new(pokemon_nuevo)
			_b.combatientes_activos[pokemon_nuevo] = _b.combatiente_enemigo
			preload("res://scripts/battle/baton_pass_rules.gd").apply(_b,_b.combatiente_enemigo,baton)
			_reiniciar_participantes_exp(0)
			break
	var entry: Dictionary=rules.capture(pokemon_nuevo)

	if not arrastre:
		await _b.mostrar_texto_batalla("¡El entrenador rival envía a %s!" % _b.poke_enemigo.get_nombre_mostrar())
		if not rules.valid_flow(flow) or not rules.valid(entry):return {}
	_preparar_envio_pokemon_enemigo()
	_b.iniciar_cuadro_enemigo(_b.poke_enemigo)
	_b.actualizar_sprite_pokemon_enemigo()
	# The validated render setup owns this slot's generation change.
	entry=rules.capture(pokemon_nuevo)
	# El grito lo dispara la aparición (BattleSlot.aparicion_iniciada).
	await _intro().enviar_pokemon_rival(pokemon_nuevo)
	if not rules.valid_flow(flow) or not rules.valid(entry):return {}
	if arrastre:
		await _b.mostrar_texto_batalla(_mensaje_arrastre(pokemon_nuevo))
		if not rules.valid_flow(flow) or not rules.valid(entry):return {}
	if not await _b.habilidades.al_entrar(pokemon_nuevo,true,entry):return {}
	if not baton.is_empty():_baton_substitute_view(pokemon_nuevo)
	return entry if rules.valid_flow(flow) else {}


func mostrar_resultado_victoria():
	_b.fases.cambiar_fase(_b.FIN_BATALLA)
	if _b.tipo_batalla == Singleton.TipoBatalla.ENTRENADOR:
		await _mostrar_victoria_entrenador()
	await _conceder_dinero_dia_pago()
	# Una fanfarria de subida de nivel aún sonando cuelga de la escena de batalla:
	# si esta se libera antes de que acabe, la música del mapa quedaría en pausa.
	await _esperar_fanfarria_nivel()
	await cerrar_batalla_con_oscurecimiento()
	_b._restaurar_orden_original_equipo()
	_b.loggear("Fin de batalla - Victoria")
	_b.notificar_resultado(ResultadoBatalla.Valor.VICTORIA_JUGADOR)


func finish_teleport_exit() -> void:
	# Source outcome5 projects to the existing HUIDA domain outcome. Admission
	# was already decided by Teleport, never rerun the menu flee probability.
	_b.fases.cambiar_fase(_b.FIN_BATALLA)
	await cerrar_batalla_con_oscurecimiento()
	_b._restaurar_orden_original_equipo()
	_b.loggear("Battle ended by Teleport")
	_b.notificar_resultado(ResultadoBatalla.Valor.HUIDA)


func mostrar_resultado_derrota():
	_b.fases.cambiar_fase(_b.FIN_BATALLA)
	# BattleScript_LocalBattleLost: la TORRE BATALLA no dice nada al perder.
	if not _b.torre_batalla:
		_b.presentacion.set_texto_instantaneo("Has perdido la batalla...")
		await _b.get_tree().create_timer(2.0).timeout
	# La batalla puede liberarse durante la espera (p. ej. al cerrarla desde fuera).
	if not is_instance_valid(_b):
		return
	# La vuelta al punto de curación arranca desde negro (CB2_WhiteOut).
	await cerrar_batalla_con_oscurecimiento()
	if not is_instance_valid(_b):
		return
	_b._restaurar_orden_original_equipo()
	_b.loggear("Fin de batalla - Derrota")
	_b.notificar_resultado(ResultadoBatalla.Valor.VICTORIA_ENEMIGO)


## Cierra la batalla tras atrapar a `_b.poke_enemigo`, en el orden de
## pokeruby (BattleScript_SuccessBallThrow): POKéDEX → mote → "enviado al PC"
## → fin. El Pokémon se guarda DESPUÉS de restaurar el orden del equipo: la
## restauración reescribe `SistemaGuardado.datos_vivos.equipo_pokemon` a
## partir del equipo de batalla (que puede ser una copia), así que añadirlo
## antes lo perdería.
func _finalizar_captura() -> void:
	_b.fases.cambiar_fase(_b.FIN_BATALLA)
	var capturado: BasePokemon = _b.poke_enemigo
	# Pasa a ser del jugador: deja de ser "salvaje" antes de que lo use nadie más.
	capturado.limpiar_etiqueta_combate()
	await _registrar_captura_en_pokedex(capturado)
	var nombre_abierto := await _ofrecer_mote(capturado)
	_b._restaurar_orden_original_equipo()
	var destino: Dictionary = SistemaGuardado.recibir_pokemon_capturado(capturado)
	var tipo_destino := int(destino.get("destino", SistemaGuardado.DestinoPokemon.SIN_ESPACIO))
	if tipo_destino == SistemaGuardado.DestinoPokemon.SIN_ESPACIO:
		# No debería ocurrir: _resolver_captura_pokeball() comprueba antes
		# almacenamiento_lleno() y no gasta la ball.
		push_warning("[BATALLA] %s atrapado sin espacio en equipo ni PC" % capturado.get_nombre_mostrar())
	elif tipo_destino == SistemaGuardado.DestinoPokemon.PC and not nombre_abierto:
		# Tras la pantalla de nombre trygivecaughtmonnick salta a
		# BattleScript_GiveCaughtMonEnd: ni se vuelve a la batalla ni se avisa.
		await _b._mostrar_texto_y_esperar_confirmacion(
			"¡%s ha sido\nenviado al PC!" % capturado.get_nombre_mostrar()
		)
		await _b._mostrar_texto_y_esperar_confirmacion(
			"Se ha guardado en\nla CAJA %d." % (int(destino.get("caja", 0)) + 1)
		)
	# La ball atenuada se queda en pantalla hasta aquí.
	_b.lanzamiento_ball.limpiar()
	# Tras la pantalla de nombre ya está en negro: se cierra sin fundido.
	await cerrar_batalla_con_oscurecimiento(nombre_abierto)
	_b.notificar_resultado(ResultadoBatalla.Valor.CAPTURA)


## pokeruby trysetcaughtmondexflags: la primera captura de la especie la marca
## como atrapada y lo anuncia.
func _registrar_captura_en_pokedex(capturado: BasePokemon) -> void:
	var especie_nueva := not SistemaGuardado.pokemon_atrapado(capturado.nombre_interno)
	# El primer SPINDA atrapado fija las manchas del de la POKéDEX (antes de
	# marcarlo como atrapado, que es lo que distingue la primera captura).
	SistemaGuardado.registrar_personalidad_spinda_capturado(capturado)
	SistemaGuardado.registrar_pokemon_atrapado(capturado.nombre_interno)
	if not especie_nueva or not PokedexPartida.obtenida():
		return
	await _b._mostrar_texto_y_esperar_confirmacion(
		"Los datos de %s se han\nañadido a la POKéDEX." % capturado.get_nombre_mostrar()
	)
	await _mostrar_ficha_pokedex(capturado)


func _mostrar_ficha_pokedex(capturado: BasePokemon) -> void:
	var registro: Dictionary = {}
	for especie in PokedexPartida.crear_registros():
		if especie["nombre_interno"] == capturado.nombre_interno:
			registro = especie
			break
	if registro.is_empty():
		push_warning("[BATALLA] Sin ficha de POKéDEX: " + capturado.nombre_interno)
		return
	registro["numero_mostrado"] = registro["nacional"] if PokedexPartida.nacional_disponible() else registro["numero"]
	await _b.presentacion.oscurecer()
	var ficha = preload("res://UI/pokedex/registro-pokedex.tscn").instantiate()
	ficha.z_index = 6
	var entradas: Array[Dictionary] = [registro]
	ficha.configurar(entradas, 0, str(SistemaGuardado.datos_vivos.jugador.get("sexo", "M")) == "F")
	_b.add_child(ficha)
	await _b.presentacion.aclarar()
	await ficha.pagina_cerrada
	# La ficha termina con el fondo en negro y el sprite a medio camino.
	var posicion: Vector2 = ficha.posicion_frente()
	ficha.queue_free()
	await _mostrar_pantalla_registro(capturado, posicion)


## sub_8090B8C + displaydexinfo caso 2: tras la ficha no se vuelve al campo
## (la POKéDEX borró los sprites de batalla), sino al fondo de edificio con el
## Pokémon deslizándose al centro y la caja de texto de batalla. Se queda
## hasta el cierre de la batalla.
func _mostrar_pantalla_registro(capturado: BasePokemon, posicion: Vector2) -> void:
	_b.presentacion.limpiar_texto()
	var ui: Node = _b.get_node("UI")
	for nodo in ui.get_children():
		if nodo is CanvasItem and nodo.name != "CajaDialogo":
			nodo.visible = false
	var pantalla := SCN_PANTALLA_REGISTRO.instantiate() as PantallaRegistroCaptura
	_b.add_child(pantalla)
	# Mismo z_index que la UI pero antes en el árbol: tapa el campo y deja la
	# caja de texto encima.
	_b.move_child(pantalla, ui.get_index())
	# La ficha usa la paleta normal; aquí se carga la del Pokémon atrapado.
	_b.cargar_sprite_pokemon_seguro(pantalla.pokemon, capturado.nombre_interno, true, capturado.es_shiny(), capturado.personalidad)
	await pantalla.iniciar(posicion)


## pokeruby trygivecaughtmonnick: pregunta si se le pone mote y, con SÍ, abre
## la pantalla de nombre. Vacío o cancelado deja el Pokémon sin mote. Devuelve
## si se abrió la pantalla de nombre (la batalla sigue en negro).
func _ofrecer_mote(capturado: BasePokemon) -> bool:
	await _b.mostrar_texto_batalla("¿Quieres ponerle un\nmote a %s?" % capturado.get_nombre_mostrar())
	var poner_mote: bool = await _b.presentacion.preguntar_si_no()
	if not poner_mote:
		return false
	var mote: String = await _b.presentacion.pedir_mote(capturado, false)
	if not mote.is_empty():
		capturado.mote = mote
	return true


func _mostrar_victoria_entrenador() -> void:
	if _victoria_entrenador_presentada:
		return
	_victoria_entrenador_presentada = true
	# HandleEndTurn_BattleWon: el tema KACHI de entrenador arranca justo antes
	# del texto de victoria, cuando ya terminaron EXP, niveles y aprendizajes.
	await _esperar_fanfarria_nivel()
	_reproducir_musica_victoria()
	var entrenador := _obtener_entrenador()
	var clase := "ENTRENADOR"
	var nombre := "DESCONOCIDO"
	var frase := "..."
	if entrenador != null:
		clase = entrenador.clase_entrenador.strip_edges().to_upper()
		nombre = entrenador.nombre.strip_edges().to_upper()
		frase = entrenador.frase_derrota if not entrenador.frase_derrota.is_empty() else "..."
	await _b._mostrar_texto_y_esperar_confirmacion(
		"¡Derrotaste a\\l%s!" % DatosEntrenador.nombre_con_clase(clase, nombre)
	)
	_b.presentacion.limpiar_texto()
	await _acercar_sprite_entrenador()
	# gUnknown_081D8E0D: en la TORRE BATALLA no hay frase de derrota ni dinero.
	if _b.torre_batalla:
		return
	await _mostrar_frase_derrota(frase)
	await _b.esperar_confirmacion_texto(false)
	var dinero := _conceder_premio_entrenador(entrenador)
	var jugador := SistemaGuardado.get_nombre_jugador()
	await _b._mostrar_texto_y_esperar_confirmacion(
		formatear_mensaje_premio(jugador, dinero)
	)


## Frase de derrota con los escapes de la ROM: `\p` pasa a una página nueva
## (espera y limpia la caja) y `\w` espera y desplaza una línea (conserva la
## última visible). `\n` literal es un salto de línea. La confirmación de la
## última página la hace quien llama.
func _mostrar_frase_derrota(frase: String) -> void:
	var paginas: PackedStringArray = frase.replace("\\n", "\n").split("\\p")
	var ultima: int = paginas.size() - 1
	while ultima > 0 and paginas[ultima].strip_edges().is_empty():
		ultima -= 1
	for i in range(ultima + 1):
		var tramos: PackedStringArray = paginas[i].split("\\w")
		var texto: String = tramos[0]
		for j in range(1, tramos.size()):
			await _b.mostrar_texto_batalla(texto)
			await _b.esperar_confirmacion_texto()
			var linea_previa: String = texto.split("\n")[-1]
			var siguiente: String = tramos[j]
			texto = linea_previa + (siguiente if siguiente.begins_with("\n") else "\n" + siguiente)
		await _b.mostrar_texto_batalla(texto)
		if i < ultima:
			await _b.esperar_confirmacion_texto()
			_b.presentacion.limpiar_texto()


## Espera a que termine la fanfarria de subida de nivel / movimiento aprendido (y la
## subida de volumen de la música) si aún suena.
func _esperar_fanfarria_nivel() -> void:
	if aprendizaje_movimientos != null and aprendizaje_movimientos.has_method("esperar_fanfarria"):
		await aprendizaje_movimientos.esperar_fanfarria()


func _acercar_sprite_entrenador() -> void:
	if not is_instance_valid(_b.sprite_rival):
		return
	if is_instance_valid(_b.slot_rival):
		_b.slot_rival.visible = false
	if _b.hud != null and is_instance_valid(_b.hud.cuadro_ps_rival):
		_b.hud.cuadro_ps_rival.visible = false
	_b.sprite_rival.position = _b.posiciones.get("sprite_rival_salida", _b.sprite_rival.position)
	_b.sprite_rival.visible = true
	var tween := _b.create_tween()
	tween.tween_property(
		_b.sprite_rival,
		"position",
		_b.posiciones.get("sprite_rival_final", _b.sprite_rival.position),
		0.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished


func _obtener_entrenador() -> DatosEntrenador:
	if _b.configuracion_batalla != null:
		return _b.configuracion_batalla.entrenador
	return _b.datos_batalla.get("entrenador", null) as DatosEntrenador


func _conceder_premio_entrenador(entrenador: DatosEntrenador) -> int:
	var premio := calcular_premio_entrenador(entrenador, _b.formato_batalla == Singleton.FormatoBatalla.DOBLE, multiplicador_dinero)
	if _premio_entrenador_concedido:
		return premio
	_premio_entrenador_concedido = true
	if premio > 0:
		SistemaGuardado.dar_dinero_jugador(premio)
	return premio


static func calcular_premio_entrenador(entrenador: DatosEntrenador, es_doble: bool = false, multiplicador: int = 1) -> int:
	if entrenador == null or entrenador.pokemon.is_empty():
		return 0
	var ultimo = entrenador.pokemon[entrenador.pokemon.size() - 1]
	if ultimo == null:
		return 0
	return maxi(entrenador.ratio_dinero, 0) * 4 * maxi(ultimo.nivel, 0) * multiplicador * (2 if es_doble else 1)


static func formatear_mensaje_premio(nombre_jugador: String, premio: int) -> String:
	return "¡%s ganó\\l%d$" % [nombre_jugador.strip_edges().to_upper(), maxi(premio, 0)]


## Fundido a negro de salida: toda batalla termina en negro y el overworld la
## releva desde ahí (OverworldBattleManager._finalizar_sesion).
func cerrar_batalla_con_oscurecimiento(instantaneo: bool = false) -> void:
	_detener_sirena_ps_bajos()
	if not is_instance_valid(_b) or not is_instance_valid(_b.overlay_fade_salida):
		return
	_b.overlay_fade_salida.visible = true
	if instantaneo:
		_b.overlay_fade_salida.modulate.a = 1.0
		return
	_b.overlay_fade_salida.modulate.a = 0.0
	var tween_fade = _b.get_tree().create_tween()
	tween_fade.tween_property(_b.overlay_fade_salida, "modulate:a", 1.0, _b.DURACION_FADE_SALIDA)
	await tween_fade.finished


## ============================================================================
## Debilitación del enemigo + ganancia de experiencia
## ============================================================================

## BattleTurnPassed: los KOs del turno se muestran al momento (tryfaintmon en el
## script del movimiento), pero EXP, atk24 y relevos esperan a HandleFaintedMonActions,
## después de DoFieldEndTurnEffects y TurnBasedEffects (veneno, quemadura, RESTOS…).
## Solo combate individual; el resto lo hace verificar_fin_batalla tras el fin de ronda.
func presentar_debilitados_del_turno() -> void:
	if _b.poke_jugador != null and _b.poke_jugador.estad_ps_actual <= 0:
		await _procesar_pokemon_jugador_debilitado(_b.poke_jugador)
	var rival: BasePokemon = _b.poke_enemigo
	if rival != null and rival.estad_ps_actual <= 0 and rival.estado != Singleton.ProblemaEstado.DEBILITADO:
		await _presentar_debilitamiento_enemigo(rival)
		_exp_pendiente.append(rival)


func presentar_debilitados_dobles() -> void:
	for pokemon: BasePokemon in _b.pokemones_activos_jugador:
		if pokemon != null and pokemon.estad_ps_actual <= 0:
			await _procesar_pokemon_jugador_debilitado(pokemon)
	for rival: BasePokemon in _b.pokemones_activos_enemigo:
		if rival != null and rival.estad_ps_actual <= 0 and rival.estado != Singleton.ProblemaEstado.DEBILITADO:
			await _presentar_debilitamiento_enemigo(rival)
			_exp_pendiente.append(rival)


## Falta presentarlo o repartir su EXP (presentado durante el turno).
func _enemigo_sin_procesar(pokemon: BasePokemon) -> bool:
	return pokemon.estado != Singleton.ProblemaEstado.DEBILITADO or _exp_pendiente.has(pokemon)


func _presentar_debilitamiento_enemigo(pokemon_derrotado: BasePokemon) -> void:
	pokemon_derrotado.estado = Singleton.ProblemaEstado.DEBILITADO
	_b._liberar_enamorados_de(pokemon_derrotado)
	if pokemon_derrotado == _b.poke_enemigo:
		await _animar_debilitacion_pokemon_enemigo(pokemon_derrotado)
	elif _b.formato_batalla == Singleton.FormatoBatalla.DOBLE:
		var slot: BattleSlot = _b.hud._obtener_slot_de_pokemon(pokemon_derrotado)
		if is_instance_valid(slot):
			await slot.animar_debilitamiento(_b.DESPLAZAMIENTO_CAIDA_DEBILITADO, _b.DURACION_CAIDA_DEBILITADO)
	await _b._mostrar_texto_y_esperar_confirmacion("¡%s\nse debilitó!" % pokemon_derrotado.get_nombre_combate())


func _procesar_pokemon_enemigo_debilitado(pokemon_derrotado: BasePokemon) -> void:
	if pokemon_derrotado == null:
		return
	if _exp_pendiente.has(pokemon_derrotado):
		_exp_pendiente.erase(pokemon_derrotado)
	else:
		await _presentar_debilitamiento_enemigo(pokemon_derrotado)
	# atk23_getexp: contra un salvaje la música de victoria entra aquí, tras el
	# mensaje de debilitamiento y antes de repartir EXP. Contra un entrenador
	# sigue la música de combate hasta "¡Derrotaste a...!" (_mostrar_victoria_entrenador).
	# Solo con el Pokémon del jugador en pie (`gBattleMons[0].hp`): tras una
	# Explosión que debilita a ambos no suena.
	if _b.tipo_batalla != Singleton.TipoBatalla.ENTRENADOR \
			and _b.poke_jugador != null and _b.poke_jugador.estad_ps_actual > 0:
		_reproducir_musica_victoria()
	await _procesar_ganancia_experiencia(pokemon_derrotado)
	_reiniciar_participantes_exp(_flanco_rival(pokemon_derrotado))


## BattleScript_FaintTarget / FaintAttacker del bando del jugador: grito, caída del
## sprite con su cuadro de PS y «¡X se debilitó!». No reparte EXP.
func _procesar_pokemon_jugador_debilitado(pokemon: BasePokemon) -> void:
	if pokemon == null:
		return
	if pokemon.estad_ps_actual > 0:
		_debilitados_presentados.erase(pokemon)
		return
	if _debilitados_presentados.has(pokemon):
		return
	_debilitados_presentados.append(pokemon)
	var slot: BattleSlot = _b.hud._obtener_slot_de_pokemon(pokemon)
	if is_instance_valid(slot):
		_reproducir_grito_pokemon(pokemon)
		await slot.animar_debilitamiento(_b.DESPLAZAMIENTO_CAIDA_DEBILITADO, _b.DURACION_CAIDA_DEBILITADO)
	# cleareffectsonfaint: status1 = 0 tras la animación; veneno o quemadura no sobreviven.
	pokemon.estado = Singleton.ProblemaEstado.DEBILITADO
	_b._liberar_enamorados_de(pokemon)
	await _b._mostrar_texto_y_esperar_confirmacion("¡%s\nse debilitó!" % pokemon.get_nombre_combate())


## pokeruby: música de victoria (MUS_KACHI1 / MUS_KACHI2). El momento depende del
## tipo de batalla y lo decide el llamador: contra un salvaje, tras el mensaje de
## debilitamiento y antes de repartir EXP (atk23_getexp); contra un entrenador, al
## empezar "¡Derrotaste a...!" (HandleEndTurn_BattleWon), con la música de combate
## sonando durante la EXP y los aprendizajes. Con rivales aún en pie no suena.
func _reproducir_musica_victoria() -> void:
	if _musica_victoria_iniciada:
		return
	for rival in _b.equipo_enemigo_pokemones:
		if rival != null and rival.estad_ps_actual > 0:
			return
	_musica_victoria_iniciada = true
	_detener_sirena_ps_bajos()
	var tema := TEMA_VICTORIA_SALVAJE
	if _b.tipo_batalla == Singleton.TipoBatalla.ENTRENADOR:
		var entrenador := _obtener_entrenador()
		tema = tema_victoria_entrenador(entrenador.clase_entrenador if entrenador != null else "")
	Singleton.reproducir_tema(tema)


## BattleStopLowHpSound: al ganar y al oscurecer la pantalla de salida.
func _detener_sirena_ps_bajos() -> void:
	if is_instance_valid(_b) and is_instance_valid(_b.sirena_ps_bajos):
		_b.sirena_ps_bajos.detener()


static func tema_victoria_entrenador(clase: String) -> String:
	return TEMAS_VICTORIA_POR_CLASE.get(clase.strip_edges().to_upper(), TEMA_VICTORIA_ENTRENADOR)


func _animar_debilitacion_pokemon_enemigo(pokemon_derrotado: BasePokemon) -> void:
	if not is_instance_valid(_b.slot_rival):
		return
	_reproducir_grito_pokemon(pokemon_derrotado)
	if _b.indice_pokemon_enemigo >= 0 and _b.indice_pokemon_enemigo < _b.iconos_rival.size():
		_b.iconos_rival[_b.indice_pokemon_enemigo].frame = 3
	await _b.slot_rival.animar_debilitamiento(_b.DESPLAZAMIENTO_CAIDA_DEBILITADO, _b.DURACION_CAIDA_DEBILITADO)


## returntoball (atk58, argumento 1): sprite y cuadro desaparecen sin animación.
func _quitar_de_campo_al_instante(slot: BattleSlot) -> void:
	slot.sprite_pokemon.visible = false
	if is_instance_valid(slot.cuadro_ps):
		slot.cuadro_ps.visible = false


## BattleText_DraggedOut de la ROM española.
func _mensaje_arrastre(pokemon: BasePokemon) -> String:
	return "¡%s fue\narrastrado al combate!" % pokemon.get_nombre_combate()


## Retirada del Pokémon rival que sigue en pie (cambio de la IA): vuelve
## a su ball con el mismo color y punto con los que sale (envío de la intro) y su
## cuadro de PS desaparece. Si ya no se ve (debilitado, Relevo) no hace nada.
func _animar_retirada_pokemon_enemigo(saliente: BasePokemon) -> void:
	await _animar_retirada_pokemon_slot(_b.slot_rival, saliente)


## Vuelta a la ball de cualquier slot, con el color y punto del lado que sale.
func _animar_retirada_pokemon_slot(slot: BattleSlot, saliente: BasePokemon) -> void:
	if not is_instance_valid(slot) or saliente == null or not slot.sprite_pokemon.visible:
		return
	var offset := _b.obtener_offset_pokemon(saliente.nombre_interno, slot.es_jugador)
	slot.configurar_pokeball(BattleIntroController.bola_de(saliente))
	var posicion_ball: Vector2 = slot.posicion_aterrizaje_ball() if slot.es_jugador else slot.pokeball.position
	await slot.animar_vuelta_a_pokeball(
		posicion_ball,
		posicion_ball + (BattleIntroController.OFFSET_APARICION_JUGADOR if slot.es_jugador else BattleIntroController.OFFSET_APARICION_RIVAL) + offset,
		BattleIntroController.COLOR_SILUETA_JUGADOR if slot.es_jugador else BattleIntroController.COLOR_SILUETA_RIVAL
	)
	if is_instance_valid(slot.cuadro_ps):
		slot.cuadro_ps.visible = false


## Deja el slot rival listo para `BattleIntroController.enviar_pokemon_rival`.
func _preparar_envio_pokemon_enemigo() -> void:
	preparar_envio_pokemon_slot(_b.slot_rival)


## Deja un slot listo para salir de la ball: anclaje en el suelo, sprite oculto
## hasta que salga y cuadro de PS fuera de pantalla, listo para entrar.
func preparar_envio_pokemon_slot(slot: BattleSlot) -> void:
	slot.fijar_posicion_relativa_al_suelo(_b.posicion_slot_rel_suelo(slot))
	slot.sprite_pokemon.visible = false
	slot.sprite_pokemon.modulate.a = 1.0
	slot.sprite_pokemon.scale = Vector2.ONE
	if is_instance_valid(slot.cuadro_ps):
		slot.cuadro_ps.visible = false
		slot.cuadro_ps.modulate.a = 1.0
		slot.cuadro_ps.position = _intro().posicion_inicial_cuadro_ps(slot)


## Controlador de la intro, dueño del envío desde la ball. Lo crea `_ready()`;
## las batallas armadas sin él (fixtures de test) usan uno propio.
func _intro() -> BattleIntroController:
	if _b.intro_controller == null:
		_b.intro_controller = BattleIntroController.new(_b)
	return _b.intro_controller


func _procesar_ganancia_experiencia(pokemon_derrotado: BasePokemon) -> void:
	# atk23_getexp: BATTLE_TYPE_BATTLE_TOWER va directo al último caso.
	if _b.torre_batalla:
		return
	var recompensas = calcular_experiencia_ganada(pokemon_derrotado)
	for recompensa in recompensas:
		var pokemon: BasePokemon = recompensa.get("pokemon", null)
		if pokemon == null:
			continue
		var exp_ganada = int(recompensa.get("exp_ganada", 0))
		if exp_ganada <= 0:
			continue
		# atk23_getexp: el intercambiado usa BattleText_BoostedExp en gBattleTextBuff2.
		var adicionales := " adicionales" if _pokemon_tiene_bonus_por_intercambio(pokemon) else ""
		await _b._mostrar_texto_y_esperar_confirmacion("¡%s ganó %d\npuntos de EXP.%s!" % [pokemon.get_nombre_mostrar(), exp_ganada, adicionales])
		if pokemon == _b.poke_jugador:
			await _animar_ganancia_experiencia_jugador(recompensa)
		else:
			# Repartir EXP. / participantes fuera del campo: mismo BattleScript_LevelUp.
			for subida in recompensa.get("subidas_nivel", []):
				await _anunciar_subida_nivel(pokemon, subida)


func calcular_experiencia_ganada(pokemon_derrotado: BasePokemon) -> Array[Dictionary]:
	var recompensas: Array[Dictionary] = []
	var participantes_exp := _obtener_participantes_experiencia(_flanco_rival(pokemon_derrotado))
	var portadores_repartir := _obtener_portadores_repartir_exp()
	if participantes_exp.is_empty() and portadores_repartir.is_empty():
		return recompensas

	var exp_total = calcular_exp_base(_b.poke_jugador, pokemon_derrotado)
	if exp_total <= 0:
		return recompensas

	# atk23_getexp: con algún REPARTIR EXP, la mitad va a los participantes y la
	# otra mitad a los portadores (mínimo 1 cada parte); sin él, todo a los participantes.
	var exp_participante := 0
	var exp_repartir := 0
	if portadores_repartir.is_empty():
		exp_participante = maxi(1, exp_total / participantes_exp.size())
	else:
		if not participantes_exp.is_empty():
			exp_participante = maxi(1, exp_total / 2 / participantes_exp.size())
		exp_repartir = maxi(1, exp_total / 2 / portadores_repartir.size())

	for pokemon in _ordenar_receptores_experiencia(participantes_exp, portadores_repartir):
		if pokemon == null or pokemon.nivel >= 100:
			continue
		var exp_base := 0
		if participantes_exp.has(pokemon):
			exp_base += exp_participante
		if portadores_repartir.has(pokemon):
			exp_base += exp_repartir
		var exp_ganada = _aplicar_bonus_experiencia_individual(pokemon, exp_base)
		if exp_ganada <= 0:
			continue
		var nivel_inicial = pokemon.nivel
		var exp_inicial = pokemon.experiencia
		var subidas_nivel: Array[Dictionary] = []
		pokemon.set_experiencia(pokemon.experiencia + exp_ganada)
		while pokemon.nivel < 100 and pokemon.experiencia >= pokemon.exp_sig_nivel:
			var stats_antes = _snapshot_stats_pokemon(pokemon)
			pokemon.subir_nivel()
			# atk5D_getexp: marca gLeveledUpInBattle y FRIENDSHIP_EVENT_GROW_LEVEL.
			if not _b.pokemon_subieron_nivel.has(pokemon):
				_b.pokemon_subieron_nivel.append(pokemon)
			Amistad.ajustar(pokemon, Amistad.Evento.SUBIR_NIVEL)
			subidas_nivel.append({
				"nivel": pokemon.nivel,
				"antes": stats_antes,
				"despues": _snapshot_stats_pokemon(pokemon)
			})
		# Al llegar al nivel 100 la experiencia se topa en la del nivel 100
		# (`TryIncrementMonLevel`), igual que la guarderia y la carga de partida.
		if pokemon.nivel >= 100:
			pokemon.experiencia = mini(pokemon.experiencia, _obtener_exp_inicio_nivel(pokemon, 100))
		recompensas.append({
			"pokemon": pokemon,
			"exp_ganada": exp_ganada,
			"exp_inicial": exp_inicial,
			"exp_final": pokemon.experiencia,
			"nivel_inicial": nivel_inicial,
			"nivel_final": pokemon.nivel,
			"subidas_nivel": subidas_nivel
		})

	return recompensas


func _registrar_participante_experiencia(pokemon: BasePokemon) -> void:
	if pokemon == null or pokemon.huevo:
		return
	# sub_80157C4: quien entra se apunta contra los dos flancos rivales.
	if not _b.equipo_jugador_participantes_exp.has(pokemon):
		_b.equipo_jugador_participantes_exp.append(pokemon)
	if not _b.equipo_jugador_participantes_exp_flanco2.has(pokemon):
		_b.equipo_jugador_participantes_exp_flanco2.append(pokemon)


## sub_8015740: tras repartir EXP o al entrar un rival, solo cuentan los que siguen en campo.
func _reiniciar_participantes_exp(flanco: int) -> void:
	var en_campo: Array[BasePokemon] = []
	var activos: Array = _b.pokemones_activos_jugador if _b.formato_batalla == Singleton.FormatoBatalla.DOBLE else [_b.poke_jugador]
	for pokemon: BasePokemon in activos:
		if pokemon != null and not pokemon.huevo and pokemon.estad_ps_actual > 0:
			en_campo.append(pokemon)
	if flanco == 1:
		_b.equipo_jugador_participantes_exp_flanco2 = en_campo
	else:
		_b.equipo_jugador_participantes_exp = en_campo


func _flanco_rival(pokemon: BasePokemon) -> int:
	if _b.formato_batalla != Singleton.FormatoBatalla.DOBLE:
		return 0
	return 1 if _b.pokemones_activos_enemigo.find(pokemon) == 1 else 0


func _obtener_participantes_experiencia(flanco: int = 0) -> Array[BasePokemon]:
	var participantes_validos: Array[BasePokemon] = []
	for pokemon in (_b.equipo_jugador_participantes_exp_flanco2 if flanco == 1 else _b.equipo_jugador_participantes_exp):
		# atk23_getexp: los debilitados (Explosión, Mismo Destino) no cuentan ni reciben;
		# los de nivel 100 cuentan para dividir (viaSentIn) aunque no reciben nada.
		if pokemon != null and not pokemon.huevo and pokemon.estad_ps_actual > 0:
			participantes_validos.append(pokemon)
	return participantes_validos


## Pokémon del equipo que llevan REPARTIR EXP. Como `atk23_getexp`, cuentan todos
## los vivos aunque estén al nivel 100 (diluyen la parte, pero no reciben nada) y se
## lee el objeto del equipo, no el de combate (DESARME no lo quita de `gPlayerParty`).
func _obtener_portadores_repartir_exp() -> Array[BasePokemon]:
	var portadores: Array[BasePokemon] = []
	for pokemon in _b.equipo_jugador_pokemones:
		if pokemon == null or pokemon.huevo or pokemon.estad_ps_actual <= 0:
			continue
		if pokemon.objeto.strip_edges().to_upper() == OBJETO_REPARTIR_EXP:
			portadores.append(pokemon)
	return portadores


## Receptores en el orden del equipo (`expGetterMonId` 0..5); los participantes que no
## estén en el equipo (fixtures) van al final en su orden de registro.
func _ordenar_receptores_experiencia(participantes: Array[BasePokemon], portadores: Array[BasePokemon]) -> Array[BasePokemon]:
	var receptores: Array[BasePokemon] = []
	for pokemon in _b.equipo_jugador_pokemones:
		if participantes.has(pokemon) or portadores.has(pokemon):
			receptores.append(pokemon)
	for pokemon in participantes:
		if not receptores.has(pokemon):
			receptores.append(pokemon)
	return receptores


## atk23_getexp: HUEVO SUERTE, combate contra entrenador y Pokémon intercambiado,
## cada uno ×150/100 con división entera y en ese orden.
func _aplicar_bonus_experiencia_individual(pokemon: BasePokemon, exp_base: int) -> int:
	var exp_ganada := exp_base
	if pokemon.objeto.strip_edges().to_upper() == OBJETO_HUEVO_SUERTE:
		exp_ganada = exp_ganada * 150 / 100
	if _b.tipo_batalla == Singleton.TipoBatalla.ENTRENADOR:
		exp_ganada = exp_ganada * 150 / 100
	if _pokemon_tiene_bonus_por_intercambio(pokemon):
		exp_ganada = exp_ganada * 150 / 100
	return exp_ganada


func _pokemon_tiene_bonus_por_intercambio(pokemon: BasePokemon) -> bool:
	return preload("res://scripts/battle/obedience_rules.gd").traded(pokemon)


func _snapshot_stats_pokemon(pokemon: BasePokemon) -> Dictionary:
	return {
		"nivel": pokemon.nivel,
		"ps": pokemon.estad_ps,
		"ps_actual": pokemon.estad_ps_actual,
		"ataque": pokemon.estad_ataque,
		"defensa": pokemon.estad_defensa,
		"ataque_especial": pokemon.estad_ataque_especial,
		"defensa_especial": pokemon.estad_defensa_especial,
		"velocidad": pokemon.estad_velocidad
	}


func _animar_ganancia_experiencia_jugador(recompensa: Dictionary) -> void:
	var pokemon: BasePokemon = recompensa.get("pokemon", null)
	if pokemon == null or not is_instance_valid(_b.hud.cuadro_ps_jugador):
		return

	var ratio_crecimiento = _obtener_ratio_crecimiento_pokemon(pokemon)
	var nivel_cursor = int(recompensa.get("nivel_inicial", pokemon.nivel))
	var exp_cursor = int(recompensa.get("exp_inicial", pokemon.experiencia))
	var subidas_nivel: Array[Dictionary] = recompensa.get("subidas_nivel", [])

	# Etapa 4 (D2): esta función sigue orquestando el bucle, los cursores
	# locales `exp_cursor`/`nivel_cursor` y las esperas de texto (territorio
	# de BattlePresentationController, sin cambios) — el cómputo no se mueve.
	# Solo los toques directos a `cuadro_ps_jugador` se disparan ahora vía
	# `_b.hud.*`.
	for subida in subidas_nivel:
		var exp_inicio_nivel = pokemon.get_exp_nivel(nivel_cursor, ratio_crecimiento)
		var exp_siguiente_nivel = pokemon.get_exp_nivel(nivel_cursor + 1, ratio_crecimiento)
		_b.hud.iniciar_barra_experiencia(exp_cursor, exp_inicio_nivel, exp_siguiente_nivel)
		await _b.hud.animar_barra_experiencia(exp_siguiente_nivel, exp_inicio_nivel, exp_siguiente_nivel)
		exp_cursor = exp_siguiente_nivel
		nivel_cursor += 1
		_actualizar_cuadro_ps_jugador_desde_snapshot(subida.get("despues", {}))
		_b.hud.reiniciar_porcentaje_barra_experiencia()
		await _anunciar_subida_nivel(pokemon, subida)

	var exp_final = int(recompensa.get("exp_final", pokemon.experiencia))
	var exp_inicio_final = pokemon.get_exp_nivel(nivel_cursor, ratio_crecimiento)
	_b.hud.iniciar_barra_experiencia(exp_cursor, exp_inicio_final, pokemon.exp_sig_nivel)
	if exp_final != exp_cursor:
		await _b.hud.animar_barra_experiencia(exp_final, exp_inicio_final, pokemon.exp_sig_nivel)
	_actualizar_cuadro_ps_jugador_desde_snapshot(_snapshot_stats_pokemon(pokemon))


## `BattleScript_LevelUp`: fanfarria, "¡X subió al nivel N!", ventana de estadísticas
## y, antes de seguir con la EXP o el siguiente nivel, los movimientos de ese nivel
## (`handlelearnnewmove` + `BattleScript_TryLearnMoveLoop`).
func _anunciar_subida_nivel(pokemon: BasePokemon, subida: Dictionary) -> void:
	var nivel := int(subida.get("nivel", pokemon.nivel))
	if aprendizaje_movimientos != null:
		aprendizaje_movimientos.tocar_fanfarria()
	await _b._mostrar_texto_y_esperar_confirmacion("¡%s subió al\nnivel %d!" % [pokemon.get_nombre_mostrar(), nivel])
	await _mostrar_panel_subida_nivel(subida.get("antes", {}), subida.get("despues", {}))
	await aprender_movimientos_nivel(pokemon, nivel)


## Movimientos que `pokemon` aprende en `nivel` (aunque ya haya subido más niveles con la
## misma EXP: el combate los recorre nivel a nivel).
func aprender_movimientos_nivel(pokemon: BasePokemon, nivel: int) -> void:
	if pokemon == null or pokemon.huevo or aprendizaje_movimientos == null:
		return
	await aprendizaje_movimientos.aprender(pokemon, nivel, datos_aprendizaje)


func _actualizar_cuadro_ps_jugador_desde_snapshot(snapshot: Dictionary) -> void:
	_b.hud.actualizar_cuadro_ps_jugador_desde_snapshot(snapshot)


func _mostrar_panel_subida_nivel(stats_antes: Dictionary, stats_despues: Dictionary) -> void:
	if not _b.hud.mostrar_panel_subida_nivel(stats_antes, stats_despues):
		return
	await _b.esperar_confirmacion_texto()
	if _b.hud.panel_subida_nivel_esta_activo():
		_b.hud.avanzar_panel_subida_nivel()
	await _b.esperar_confirmacion_texto()
	if _b.hud.panel_subida_nivel_esta_activo():
		_b.hud.avanzar_panel_subida_nivel()


func _obtener_ratio_crecimiento_pokemon(pokemon: BasePokemon) -> String:
	if pokemon == null:
		return "NORMAL"
	var datos_pokemon = DatabaseManager.obtener_datos_pokemon(pokemon.nombre_interno)
	if datos_pokemon.is_empty():
		return "NORMAL"
	return str(datos_pokemon.get("ratio_crecimiento", "NORMAL"))


func _obtener_exp_inicio_nivel(pokemon: BasePokemon, nivel_consulta: int = -1) -> int:
	if pokemon == null:
		return 0
	var nivel_objetivo = pokemon.nivel if nivel_consulta < 0 else nivel_consulta
	return pokemon.get_exp_nivel(nivel_objetivo, _obtener_ratio_crecimiento_pokemon(pokemon))


func _obtener_ruta_grito_pokemon(pokemon: BasePokemon) -> String:
	if pokemon == null or pokemon.numero_nacional <= 0:
		return ""
	return "%s%sCry.ogg" % [_b.CRY_BASE_PATH, str(pokemon.numero_nacional).pad_zeros(3)]


func _reproducir_grito_pokemon(pokemon: BasePokemon) -> void:
	if not is_instance_valid(_b.reproductor_grito):
		return
	var ruta_grito = _obtener_ruta_grito_pokemon(pokemon)
	if ruta_grito == "" or not ResourceLoader.exists(ruta_grito):
		return
	var stream = load(ruta_grito) as AudioStream
	if stream == null:
		return
	_b.reproductor_grito.stop()
	_b.reproductor_grito.stream = stream
	_b.reproductor_grito.play()


## `gBaseStats[species].expYield * level / 7` (atk23_getexp). `Pokemon.base_experiencia`
## guarda el expYield de Ruby.
func calcular_exp_base(_pokemon_ganador, pokemon_derrotado) -> int:
	var datos_pokemon := DatabaseManager.obtener_datos_pokemon(pokemon_derrotado.nombre_interno)
	var base_exp := int(datos_pokemon.get("base_experiencia", 0))
	return base_exp * int(pokemon_derrotado.nivel) / 7


## ============================================================================
## Cambio de Pokémon del jugador (voluntario y forzado)
## ============================================================================

func _on_pokemon_seleccionado(indice_visual: int):
	# La pantalla de equipo emite la caja (orden de batalla), no el índice del equipo.
	var indice := _b.indice_equipo_desde_visual(indice_visual)
	if not _baton_transaction.is_empty():
		preload("res://scripts/battle/baton_bank_transaction.gd").accept(_b,_baton_transaction,indice)
		if int(_baton_transaction.choice)<0 and preload("res://scripts/battle/baton_bank_transaction.gd").valid(_b,_baton_transaction):
			_b.presentacion.pantalla_equipo.visible=true;_b.presentacion.pantalla_equipo.activo=true
		return
	if _relevo_doble_pendiente:
		if _relevo_doble_candidatos.has(indice):
			_relevo_doble_eleccion=indice
		else:
			_b.presentacion.pantalla_equipo.visible=true;_b.presentacion.pantalla_equipo.activo=true
		return
	if _b.formato_batalla==Singleton.FormatoBatalla.DOBLE and _b.fase!=_b.INPUT:return
	if baton_choice_pending:
		if indice>=0 and indice<_b.equipo_jugador_pokemones.size():
			var chosen: BasePokemon=_b.equipo_jugador_pokemones[indice]
			if chosen!=null and chosen!=_baton_actor and chosen.puede_combatir():baton_choice_pending=false;baton_party_chosen.emit(indice)
		return
	print("Pokémon seleccionado: ", indice)
	if _b.formato_batalla == Singleton.FormatoBatalla.DOBLE and _b.fase == _b.INPUT:
		_b.presentacion.pantalla_equipo.ocultar_pantalla_equipo()
		await _b.presentacion.aclarar()
		var activo_doble: BasePokemon = _b.pokemones_activos_jugador[_b.slot_jugador_seleccionado] if _b.slot_jugador_seleccionado < _b.pokemones_activos_jugador.size() else null
		var trampa_doble := HabilidadesCombate.impide_huida(activo_doble, _b.habilidades.crear_campo(), true)
		if not trampa_doble.is_empty():
			await _b.mostrar_texto_batalla(HabilidadesCombate.mensaje_impide_huida(trampa_doble, true))
			_b.fase_input(false)
			return
		if not _b.turno.registrar_cambio_doble(indice):
			_b._mostrar_mensaje("Ese Pokémon no puede entrar ahora.", true)
			_b.fase_input(false)
		else:
			_b.presentacion.menu1.cursor_a_lucha()
		return

	# Activar control de input temporal para evitar input fantasma al regresar al menú
	var flow: Dictionary=_acquire_player_switch_flow()
	if not _valid_player_switch_flow(flow):
		_manual_switch_continuation.clear();return
	_b.ignorar_input_temporal = true

	var pokemon_anterior = _b.poke_jugador
	var pokemon_nuevo = _b.equipo_jugador_pokemones[indice]

	# SOMBRA TRAMPA, TRAMPA ARENA e IMÁN también impiden el cambio voluntario.
	if pokemon_anterior.estad_ps_actual > 0:
		var trampa := HabilidadesCombate.impide_huida(pokemon_anterior, _b.habilidades.crear_campo(), true)
		if not trampa.is_empty():
			var operation: int=int(flow.operation)
			# Rejection accepted no replacement. Retire before the message await,
			# but never retire a pending accepted entry/KO continuation.
			var rejected: bool=not _player_switch_entry_accepted and _retire_player_switch_flow(flow)
			_b.presentacion.pantalla_equipo.ocultar_pantalla_equipo()
			await _b.presentacion.aclarar()
			if not _b.field_rules.valid_flow(flow):return
			await _b.mostrar_texto_batalla(HabilidadesCombate.mensaje_impide_huida(trampa, true))
			if rejected and operation==_player_switch_sequence and _player_switch_flow.is_empty() and _b.field_rules.valid_flow(flow):_b.fase_input()
			return

	# El cambio sigue adelante: en el próximo turno el cursor vuelve a LUCHA en
	# lugar de quedarse en POKEMON.
	_b.presentacion.menu1.cursor_a_lucha()

	# Distinguir entre cambio desde INPUT (voluntario) vs CAMBIO_POKEMON (forzado)
	if _b.fase == _b.INPUT:
		# Cambio voluntario desde el menú principal - Animación completa
		_manual_switch_continuation.clear()
		# La IA elige antes de ver el cambio (también PERSECUCIÓN contra el que se retira).
		if _b.formato_batalla == Singleton.FormatoBatalla.SIMPLE:_b.turno.preseleccionar_accion_enemiga()
		var entry: Dictionary=await _ejecutar_cambio_pokemon_animado(pokemon_anterior,pokemon_nuevo,indice,{},true)
		if not _owns_player_switch_flow(flow):return
		await _complete_player_switch(entry,true)

	elif _b.fase == _b.CAMBIO_POKEMON:
		# Cambio desde pantalla de cambio (puede ser forzado o voluntario)
		if pokemon_anterior.estad_ps_actual > 0:
			# Era un cambio voluntario - Animación completa
			_manual_switch_continuation.clear()
			var entry: Dictionary=await _ejecutar_cambio_pokemon_animado(pokemon_anterior,pokemon_nuevo,indice)
			if not _owns_player_switch_flow(flow):return
			await _complete_player_switch(entry,true)
		else:
			# Era un cambio forzado - Solo salida del nuevo Pokémon
			var resume_manual: bool=not _manual_switch_continuation.is_empty()
			if resume_manual and not _b.field_rules.valid(_manual_switch_continuation):
				_manual_switch_continuation.clear();return
			var entry: Dictionary=await _ejecutar_cambio_pokemon_forzado(pokemon_nuevo,indice)
			if not _owns_player_switch_flow(flow):return
			await _complete_player_switch(entry,resume_manual)
	else:
		# Cambio directo sin animación (fallback)
		_cambiar_pokemon_directo(pokemon_nuevo, indice)
		if _valid_player_switch_flow(flow) and _retire_player_switch_flow(flow):_b.fase_input()


func _complete_player_switch(entry: Dictionary,respond: bool) -> void:
	# Never reacquire current occupancy after an await. The producer returns the
	# original accepted entry, including its own KO epoch, or no valid result.
	if not is_instance_valid(_b) or not _b.is_inside_tree():
		_manual_switch_continuation.clear();return
	var rules: BattleFieldEffects=_b.field_rules
	var flow: Dictionary=entry.get("flow",_player_switch_flow)
	if not rules.valid(entry) or not _valid_player_switch_flow(flow):
		if _owns_player_switch_flow(flow):
			_manual_switch_continuation={}
			if not _player_switch_entry_accepted:_retire_player_switch_flow(flow)
		return
	if respond:_manual_switch_continuation=entry
	if entry.pokemon.estad_ps_actual<=0:
		await verificar_fin_batalla()
		if _owns_player_switch_flow(flow) and (not rules.valid(entry) or not _valid_player_switch_flow(flow)):_manual_switch_continuation={}
		return
	# Only a forced replacement owns this tail; voluntary switch actions retain
	# their ordinary enemy-response sequencing. The successor ticket was bound
	# at the producer's synchronous ownership transfer, before its first yield.
	if entry.has("item_tail"):
		if not await preload("res://scripts/battle/held_status_berry_rules.gd").settle_tail(_b,entry.item_tail):return
		if not rules.valid(entry) or not _valid_player_switch_flow(flow):return
	if respond:
		_manual_switch_continuation.clear()
		_retire_player_switch_flow(flow)
		_iniciar_respuesta_enemiga_tras_cambio_jugador()
	elif _b.turno.end_round_replacement_pending:
		_retire_player_switch_flow(flow)
		_b.fases.cambiar_fase(_b.RONDA)
	else:
		_retire_player_switch_flow(flow)
		# Rival debilitado a la vez (Explosión): su relevo sale tras el del jugador.
		if _b.poke_enemigo != null and _b.poke_enemigo.estad_ps_actual <= 0:
			if await verificar_fin_batalla():return
		_b.turno.reiniciar_estado_ronda()
		_b.fase_input()


func _iniciar_respuesta_enemiga_tras_cambio_jugador() -> void:
	_b.turno.set_meta("source_next_nonmove_kind","switch")
	_b.turno.ceder_turno_al_rival()


## Ejecuta la animación completa de cambio de Pokémon (voluntario)
func _ejecutar_cambio_pokemon_animado(pokemon_anterior: BasePokemon, pokemon_nuevo: BasePokemon, indice: int, baton: Dictionary={}, persecucion: bool=false, arrastre: bool=false) -> Dictionary:
	var rules: BattleFieldEffects=_b.field_rules
	var flow: Dictionary=_player_switch_flow if not _player_switch_flow.is_empty() else rules.capture_flow([pokemon_anterior])
	var original: Dictionary=rules.capture(pokemon_anterior)
	if not rules.valid(original) or not _valid_player_switch_flow(flow):return {}
	# 1. Mensaje de recogida (BattleScript_SuccessForceOut no tiene ninguno)
	if arrastre:
		_quitar_de_campo_al_instante(_b.slot_jugador)
	else:
		_b.presentacion.set_texto_instantaneo("¡Vuelve, %s!" % pokemon_anterior.get_nombre_mostrar())
		await _b.get_tree().create_timer(1.0).timeout
	if not rules.valid(original) or not _valid_player_switch_flow(flow):return {}

	# REGLA (decomp, BattleScript_ActionSwitch): tras «¡Vuelve!», la PERSECUCIÓN que eligió el
	# rival golpea al que se retira con daño x2. Si lo debilita, el cambio sigue igual
	# (BattleScript_DoSwitchOut) y sale el elegido; no hay recogida porque ya cayó.
	var debilitado_por_persecucion: bool=false
	if persecucion and await _b.turno.persecucion_rival_antes_de_cambio_jugador(pokemon_anterior):
		if not is_instance_valid(_b) or _b.fase==_b.FIN_BATALLA:return {}
		debilitado_por_persecucion=pokemon_anterior.estad_ps_actual<=0
		if debilitado_por_persecucion:
			await _procesar_pokemon_jugador_debilitado(pokemon_anterior)
			if not _valid_player_switch_flow(flow):return {}
		elif not rules.valid(original) or not _valid_player_switch_flow(flow):return {}

	# 2. Animación de recogida (nueva función)
	if baton.is_empty() and not debilitado_por_persecucion and not arrastre:await _animar_recogida_pokemon_jugador(pokemon_anterior)
	if not debilitado_por_persecucion and (not rules.valid(original) or not _valid_player_switch_flow(flow)):return {}

	# 3. Cambiar el Pokémon activo (CURA NATURAL al retirarse)
	_b.habilidades.al_salir(pokemon_anterior)
	_cambiar_pokemon_directo(pokemon_nuevo, indice,baton)
	if _owns_player_switch_flow(flow):_player_switch_entry_accepted=true
	var entry: Dictionary=rules.capture(pokemon_nuevo)
	if entry.is_empty():return {}
	entry["flow"]=flow

	# 4. Mensaje de lanzamiento (en el arrastre va después de la salida)
	if arrastre:
		if is_instance_valid(_b.slot_jugador.cuadro_ps):_b.slot_jugador.cuadro_ps.visible=false
	else:
		_b.presentacion.set_texto_instantaneo("¡Adelante, %s!" % pokemon_nuevo.get_nombre_mostrar())
		await _b.get_tree().create_timer(0.8).timeout
		if not rules.valid(entry) or not _valid_player_switch_flow(flow):return {}

	# 5. Animación de lanzamiento y salida (reutilizar existentes)
	await _animar_lanzamiento_y_salida_pokemon_jugador(pokemon_nuevo)
	if not rules.valid(entry) or not _valid_player_switch_flow(flow):return {}
	if arrastre:
		if is_instance_valid(_b.slot_jugador.cuadro_ps):_b.slot_jugador.cuadro_ps.visible=true
		await _b.mostrar_texto_batalla(_mensaje_arrastre(pokemon_nuevo))
		if not rules.valid(entry) or not _valid_player_switch_flow(flow):return {}

	# 6. Habilidades de entrada del recién llegado
	# Cambio aceptado ante el próximo del rival: se difieren (ver _ofrecer_cambio_antes_de_rival).
	if _diferir_entrada_jugador:
		_diferir_entrada_jugador=false
		_entrada_jugador_diferida=entry
		return entry if _valid_player_switch_flow(flow) else {}
	if not await _b.habilidades.al_entrar(pokemon_nuevo,true,entry):return {}
	if not baton.is_empty():_baton_substitute_view(pokemon_nuevo)
	return entry if _valid_player_switch_flow(flow) else {}


## Ejecuta cambio forzado (solo salida del nuevo Pokémon)
func _ejecutar_cambio_pokemon_forzado(pokemon_nuevo: BasePokemon, indice: int) -> Dictionary:
	var rules: BattleFieldEffects=_b.field_rules
	var flow: Dictionary=_player_switch_flow if not _player_switch_flow.is_empty() else rules.capture_flow([_b.poke_jugador])
	if not _valid_player_switch_flow(flow):return {}
	# 1. Cambiar el Pokémon activo
	_cambiar_pokemon_directo(pokemon_nuevo, indice)
	if _owns_player_switch_flow(flow):_player_switch_entry_accepted=true
	var entry: Dictionary=rules.capture(pokemon_nuevo)
	if entry.is_empty():return {}
	entry["flow"]=flow
	entry["item_tail"]=preload("res://scripts/battle/held_status_berry_rules.gd").capture_tail(_b,rules.capture_flow())

	# 2. Mensaje de lanzamiento
	_b.presentacion.set_texto_instantaneo("¡Adelante, %s!" % pokemon_nuevo.get_nombre_mostrar())
	await _b.get_tree().create_timer(0.8).timeout
	if not rules.valid(entry) or not _valid_player_switch_flow(flow):return {}

	# 3. Solo animación de salida
	await _animar_lanzamiento_y_salida_pokemon_jugador(pokemon_nuevo)
	if not rules.valid(entry) or not _valid_player_switch_flow(flow):return {}

	# 4. Habilidades de entrada del recién llegado.
	# REGLA (decomp, HandleFaintedMonActions caso 6): con el rival también debilitado,
	# Intimidación/Rastro se resuelven con los dos relevos ya en el campo; si se
	# resolvieran aquí, no habría rival al que afectar. Se difieren hasta el relevo rival.
	if _relevo_doble:
		_entrada_jugador_diferida=entry
		return entry if _valid_player_switch_flow(flow) else {}
	if not await _b.habilidades.al_entrar(pokemon_nuevo,true,entry):return {}
	return entry if _valid_player_switch_flow(flow) else {}


## Cambio de un único slot en DOBLE. Nunca reutiliza el cambio SIMPLE, que
## reemplaza siempre J0 y terminaría consumiendo la acción del compañero.
## Vale para ambos lados: el del saliente decide equipo, slot y textos.
func cambiar_slot_doble(anterior: BasePokemon, indice: int) -> Dictionary:
	var es_jugador: bool = _b.pokemones_activos_jugador.has(anterior)
	var activos: Array[BasePokemon] = _b.pokemones_activos_jugador if es_jugador else _b.pokemones_activos_enemigo
	var equipo: Array[BasePokemon] = _b.equipo_jugador_pokemones if es_jugador else _b.equipo_enemigo_pokemones
	if indice < 0 or indice >= equipo.size():
		return {}
	var nuevo: BasePokemon = equipo[indice]
	if nuevo == null or not nuevo.puede_combatir() or activos.has(nuevo):
		return {}
	var slot_indice := activos.find(anterior)
	if slot_indice < 0:
		return {}
	var slot: BattleSlot
	if es_jugador:slot = _b.slot_jugador if slot_indice == 0 else _b.slot_jugador_secundario
	else:slot = _b.slot_rival if slot_indice == 0 else _b.slot_rival_secundario
	var rules: BattleFieldEffects=_b.field_rules
	var original: Dictionary=rules.capture(anterior)
	var flow: Dictionary=rules.capture_flow([anterior])
	await _b.mostrar_texto_batalla(("¡Vuelve, %s!" if es_jugador else "¡El entrenador rival retiró a %s!") % anterior.get_nombre_mostrar())
	if not rules.valid_flow(flow) or not rules.valid(original):return {}
	if await _b.turno.persecuciones_antes_de_cambio_doble(anterior):
		if not is_instance_valid(_b) or _b.fase==_b.FIN_BATALLA:return {}
		# getexp TARGET dentro de BattleScript_PursuitDmgOnSwitchOut, con el banco aún ocupado.
		if not es_jugador and anterior.estad_ps_actual<=0:await _procesar_pokemon_enemigo_debilitado(anterior)
		# El golpe es otra operación: el cambio sigue con el registro posterior.
		original=rules.capture(anterior);flow=rules.capture_flow([anterior])
		if not rules.valid_flow(flow) or not rules.valid(original):return {}
	# BattleScript_DoSwitchOut: returnatktoball, salvo que PERSECUCIÓN lo debilitara
	# (HITMARKER_FAINTED); el elegido sale igualmente. Antes de retirar el estado de combate.
	if anterior.estad_ps_actual>0:await _animar_retirada_pokemon_slot(slot, anterior)
	if not rules.valid_flow(flow) or not rules.valid(original):return {}
	_b._retirar_sustituto_de_pokemon(anterior)
	_b.habilidades.al_salir(anterior)
	activos[slot_indice] = nuevo
	_b.combatientes_activos.erase(anterior)
	_b._liberar_enamorados_de(anterior)
	_b.combatientes_activos[nuevo] = _b.PokemonCombatState.new(nuevo)
	if es_jugador:
		_registrar_participante_experiencia(nuevo)
	else:
		_b._registrar_rival_visto(nuevo)
		_reiniciar_participantes_exp(slot_indice)
	if slot_indice == 0:
		if es_jugador:
			_b.poke_jugador = nuevo
			_b.indice_pokemon_jugador = indice
			_b.combatiente_jugador = _b.combatientes_activos[nuevo]
		else:
			_b.poke_enemigo = nuevo
			_b.indice_pokemon_enemigo = indice
			_b.combatiente_enemigo = _b.combatientes_activos[nuevo]
	slot.configurar_pokemon(nuevo, es_jugador, _b.hud._estadoE2S(nuevo.estado), _obtener_exp_inicio_nivel(nuevo) if es_jugador else 0)
	if not es_jugador:
		_b._actualizar_indicador_capturado(slot, nuevo)
	_b.aplicar_offset_a_slot(slot, nuevo, es_jugador)
	_b.cargar_sprite_pokemon_seguro(slot.sprite_pokemon, nuevo.nombre_interno, not es_jugador, nuevo.es_shiny(), nuevo.personalidad)
	preparar_envio_pokemon_slot(slot)
	var entry: Dictionary=rules.capture(nuevo)
	await _b.mostrar_texto_batalla(_mensaje_envio_doble(nuevo, es_jugador))
	if not rules.valid_flow(flow) or not rules.valid(entry):return {}
	# Grito y destellos los disparan las señales de aparición del slot.
	await _intro().enviar_pokemon_slot(slot, nuevo, es_jugador)
	if not rules.valid_flow(flow) or not rules.valid(entry):return {}
	await _b.esperar_destellos_variocolor(slot, nuevo)
	if not rules.valid_flow(flow) or not rules.valid(entry):return {}
	if not await _b.habilidades.al_entrar(nuevo,true,entry):return {}
	return entry if rules.valid_flow(flow) else {}


## Relevo tras K.O. que `_reponer_slots_dobles` dejó preparado: printstring 3 y
## switchinanim de BattleScript_FaintedMonChooseAnother. False si se perdió el flujo.
func presentar_envio_doble(envio: Dictionary,flujos: Array[Dictionary]) -> bool:
	var rules: BattleFieldEffects=_b.field_rules
	var pokemon: BasePokemon=envio.pokemon
	var slot: BattleSlot=envio.slot
	var es_jugador: bool=slot.es_jugador
	await _b.mostrar_texto_batalla(_mensaje_envio_doble(pokemon, es_jugador))
	if not _flujos_validos(rules,flujos):return false
	await _intro().enviar_pokemon_slot(slot,pokemon,es_jugador)
	if not _flujos_validos(rules,flujos):return false
	await _b.esperar_destellos_variocolor(slot,pokemon)
	return _flujos_validos(rules,flujos)


## printstring 3 de un envío a mitad de combate.
func _mensaje_envio_doble(pokemon: BasePokemon, es_jugador: bool) -> String:
	return ("¡Adelante, %s!" if es_jugador else "¡El entrenador rival envía a %s!") % pokemon.get_nombre_mostrar()


func _flujos_validos(rules: BattleFieldEffects,flujos: Array[Dictionary]) -> bool:
	for flujo: Dictionary in flujos:
		if not rules.valid_flow(flujo):return false
	return true


## Forceout's exit already ran. Only this accepted bank may acquire a successor.
func cambiar_slot_forzado_doble(original: Dictionary,nuevo: BasePokemon,indice: int,baton: Dictionary={},baton_flow: Dictionary={}) -> Dictionary:
	var rules: BattleFieldEffects=_b.field_rules
	if not rules.valid(original):return {}
	var anterior: BasePokemon=original.pokemon
	var player: bool=bool(original.bank.player)
	var flank: int=int(original.bank.flank)
	var active: Array[BasePokemon]=_b.pokemones_activos_jugador if player else _b.pokemones_activos_enemigo
	var party: Array[BasePokemon]=_b.equipo_jugador_pokemones if player else _b.equipo_enemigo_pokemones
	if indice<0 or indice>=party.size() or party[indice]!=nuevo or not preload("res://scripts/battle/whirlwind_rules.gd").eligible(nuevo) or active.has(nuevo):return {}
	var flow: Dictionary=rules.capture_flow([anterior])
	var slot: BattleSlot=original.slot.get_ref()
	_b._retirar_sustituto_de_pokemon(anterior)
	_b.habilidades.al_salir(anterior)
	active[flank]=nuevo
	_b.combatientes_activos.erase(anterior)
	_b._liberar_enamorados_de(anterior)
	_b.combatientes_activos[nuevo]=_b.PokemonCombatState.new(nuevo)
	preload("res://scripts/battle/baton_pass_rules.gd").apply(_b,_b.combatientes_activos[nuevo],baton)
	if player:_registrar_participante_experiencia(nuevo)
	else:_b._registrar_rival_visto(nuevo);_reiniciar_participantes_exp(flank)
	if flank==0:
		if player:_b.poke_jugador=nuevo;_b.indice_pokemon_jugador=indice;_b.combatiente_jugador=_b.combatientes_activos[nuevo]
		else:_b.poke_enemigo=nuevo;_b.indice_pokemon_enemigo=indice;_b.combatiente_enemigo=_b.combatientes_activos[nuevo]
	slot.configurar_pokemon(nuevo,player,_b.hud._estadoE2S(nuevo.estado),_obtener_exp_inicio_nivel(nuevo) if player else 0)
	_b.aplicar_offset_a_slot(slot,nuevo,player)
	_b.cargar_sprite_pokemon_seguro(slot.sprite_pokemon,nuevo.nombre_interno,not player,nuevo.es_shiny(),nuevo.personalidad)
	# returntoball (atk58, argumento 1) quita sprite y cuadro al instante, sin
	# animar. Solo queda salir de la ball.
	preparar_envio_pokemon_slot(slot)
	var entry: Dictionary=rules.capture(nuevo)
	if not baton_flow.is_empty():entry["source_baton_unaffected_flow"]=baton_flow
	# Relevo: printstring antes de switchinanim. Arrastre: después (SuccessForceOut).
	if not baton.is_empty():
		await _b.mostrar_texto_batalla(_mensaje_envio_doble(nuevo,player))
		if not rules.valid_flow(flow) or not rules.valid(entry):return {}
	await _intro().enviar_pokemon_slot(slot,nuevo,player)
	if not rules.valid_flow(flow) or not rules.valid(entry):return {}
	if baton.is_empty():await _b.mostrar_texto_batalla(_mensaje_arrastre(nuevo))
	await _b.esperar_destellos_variocolor(slot,nuevo)
	if not rules.valid_flow(flow) or not rules.valid(entry):return {}
	if not await _b.habilidades.al_entrar(nuevo,true,entry):return {}
	if not baton.is_empty() and rules.valid(entry):_baton_substitute_view(nuevo)
	return entry if rules.valid_flow(flow) and rules.valid(entry) else {}


## Cambia las variables internas sin animación
func _cambiar_pokemon_directo(pokemon_nuevo: BasePokemon, indice: int, baton: Dictionary={}) -> void:
	var retiring: PokemonEnCombate=_b._obtener_combatiente(_b.poke_jugador)
	if retiring!=null and retiring.has_meta("transform_domain"):_b.habilidades.al_salir(_b.poke_jugador)
	_b._retirar_sustituto_de_pokemon(_b.poke_jugador)
	# SwitchInClearSetData: el que sale pierde niveles y estados volátiles; si queda en
	# combatientes_activos, _obtener_combatiente() lo devuelve al volver.
	_b.combatientes_activos.erase(_b.poke_jugador)
	_b._liberar_enamorados_de(_b.poke_jugador)
	# Cambiar el Pokémon activo
	_b.indice_pokemon_jugador = indice
	_b.poke_jugador = pokemon_nuevo
	_registrar_participante_experiencia(_b.poke_jugador)
	_b.combatiente_jugador = _b.PokemonCombatState.new(pokemon_nuevo)
	_b.combatientes_activos[pokemon_nuevo] = _b.combatiente_jugador
	preload("res://scripts/battle/baton_pass_rules.gd").apply(_b,_b.combatiente_jugador,baton)

	# Actualizar UI
	_b.iniciar_cuadro_jugador(pokemon_nuevo)
	# La caída por debilitamiento (BattleSlot.ocultar) se lleva también el cuadro de PS.
	if is_instance_valid(_b.slot_jugador.cuadro_ps):
		_b.slot_jugador.cuadro_ps.visible = true


## Nueva función: Anima la recogida del Pokémon actual
func _animar_recogida_pokemon_jugador(_pokemon_anterior: BasePokemon) -> void:
	await _b.slot_jugador.animar_recogida(Vector2(200, 130))


## Reutiliza las animaciones existentes para lanzamiento y salida
func _animar_lanzamiento_y_salida_pokemon_jugador(pokemon_nuevo: BasePokemon) -> void:
	_b.slot_jugador.pokeball.mostrar_pokeball(pokemon_nuevo.encuentro_bola)
	await _b.slot_jugador.animar_lanzamiento_y_salida(
		Vector2(160, 80),
		_b.posicion_campo_slot(_b.slot_jugador),
		Callable(_b, "actualizar_sprite_pokemon_jugador"),
		Callable(self, "_emitir_particulas_slot")
	)
	await _b.esperar_destellos_variocolor(_b.slot_jugador, pokemon_nuevo)


func _emitir_particulas_slot(posicion: Vector2) -> void:
	_b.emitir_particulas_pokeball({
		"posicion": posicion,
		"tiempo_emision": 0.3,
		"intervalo_emision": 0.02
	})


func _on_seleccion_cancelada():
	if not _baton_transaction.is_empty() or (_b.formato_batalla==Singleton.FormatoBatalla.DOBLE and _b.fase!=_b.INPUT):return
	if baton_choice_pending:return # Accepted source Baton Pass cannot cancel its party choice.
	_b.loggear("Selección cancelada")
	# Ocultar la pantalla del equipo
	_b.presentacion.pantalla_equipo.ocultar_pantalla_equipo()

	# Activar control de input temporal para evitar que las teclas presionadas
	# para salir de la pantalla del equipo vuelvan a activar el menú
	_b.ignorar_input_temporal = true

	if _b.fase == _b.CAMBIO_POKEMON:
		# Si era un cambio forzado (Pokémon debilitado), no se puede cancelar
		if _b.poke_jugador.estad_ps_actual <= 0:
			# Forzar selección de nuevo
			iniciar_cambio_pokemon_forzado()
		else:
			# Volver al menú principal
			_b.fase_input()
	else:
		_b.fase_input()

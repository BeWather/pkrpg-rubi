extends Node
class_name OverworldBattleManager

const DatosInicioBatallaScript = preload("res://escenas/batalla/datos_inicio_batalla.gd")
const DURACION_REVELAR_MAPA := 0.3

const RUTA_ESCENA_BATALLA := "res://escenas/batalla/batalla.tscn"

## Se carga en `_init()`, no con `preload`: un `preload` se resuelve al compilar
## la clase, y `batalla.gd` usa esta clase, así que compilar `battle_slot.gd`
## (que lleva a `batalla.gd`) cargaba `batalla.tscn` con `battle_slot.tscn` a
## medio cargar («referenced non-existent resource», uno por slot).
var packed_batalla: PackedScene = null
var batalla_activa: bool = false
var nodo_batalla: Node = null
var datos_batalla_actual: DatosInicioBatalla = null
var administrador_mapa: Node = null
var capa_batalla: CanvasLayer = null

var _lock: BattleOverworldLock = null
var _runner: BattleTransitionRunner = null
var _outcome_handler: BattleOutcomeHandler = null
var _defeat_coordinator: BattleDefeatCoordinator = null


func _init() -> void:
	packed_batalla = load(RUTA_ESCENA_BATALLA) as PackedScene


func _ready() -> void:
	administrador_mapa = get_node_or_null("/root/AdministradorMapa")
	if not is_instance_valid(administrador_mapa):
		administrador_mapa = Singleton.obtener_nodo("Admin")
	_recrear_colaboradores()
	capa_batalla = Singleton.obtener_nodo("CapaBatalla") as CanvasLayer


func _exit_tree() -> void:
	if _runner != null:
		_runner.cancelar()
	if _outcome_handler != null:
		_outcome_handler.cerrar(nodo_batalla)
	if _lock != null:
		_lock.cerrar()
	nodo_batalla = null
	datos_batalla_actual = null
	batalla_activa = false


func combatir_salvaje(
	especie: String,
	nivel: int = 25,
	ubicacion: String = "",
	opciones: OpcionesBatallaOverworld = null
) -> ResultadoEjecucionBatalla:
	if batalla_activa:
		return ResultadoEjecucionBatalla.rechazada(&"sesion_ocupada", "Ya hay una batalla en curso.")
	var datos: DatosInicioBatalla = DatosInicioBatallaScript.crear_salvaje(especie, nivel, ubicacion, Singleton.TemaBatalla.HIERBA_ALTA)
	_rellenar_escenario(datos)
	datos.equipo_rival = _construir_equipo_salvaje(especie, nivel)
	var opciones_efectivas := opciones if opciones != null else OpcionesBatallaOverworld.para_salvaje()
	if not opciones_efectivas.objeto_salvaje.is_empty():
		datos.equipo_rival[0].objeto = opciones_efectivas.objeto_salvaje
	return await _ejecutar_sesion(datos, opciones_efectivas)


## Combate salvaje contra un Pokémon ya construido: el errante
## (BattleSetup_StartRoamerBattle, `errante` = BATTLE_TYPE_ROAMER) o el de un brote
## masivo (SetUpMassOutbreakEncounter, con sus movimientos). El combate usa esta misma
## instancia, así que al acabar conserva sus PS y estado.
func combatir_pokemon_salvaje(
	pokemon: BasePokemon,
	ubicacion: String = "",
	errante: bool = false
) -> ResultadoEjecucionBatalla:
	if batalla_activa:
		return ResultadoEjecucionBatalla.rechazada(&"sesion_ocupada", "Ya hay una batalla en curso.")
	var datos: DatosInicioBatalla = DatosInicioBatallaScript.crear_salvaje(pokemon.nombre_interno, pokemon.nivel, ubicacion, Singleton.TemaBatalla.HIERBA_ALTA)
	_rellenar_escenario(datos)
	datos.equipo_rival = [pokemon] as Array[BasePokemon]
	if errante:
		datos.extras[DatosInicioBatallaScript.EXTRA_ERRANTE] = true
	return await _ejecutar_sesion(datos, OpcionesBatallaOverworld.para_salvaje())


## CB2_GiveStarter → CB2_StartFirstBattle: el primer combate, contra el salvaje que
## perseguía a ABEDUL. Con BATTLE_TYPE_FIRST_BATTLE no se puede huir, el salvaje
## huye si deja al Pokémon del jugador con un 20 % de PS o menos (AI_GoEasy) y una
## derrota no manda al último punto de curación (CB2_EndFirstBattle sigue el guion):
## el llamador decide qué hacer con el resultado.
func combatir_primer_salvaje(
	especie: String,
	nivel: int,
	ubicacion: String = "",
	opciones: OpcionesBatallaOverworld = null
) -> ResultadoEjecucionBatalla:
	if batalla_activa:
		return ResultadoEjecucionBatalla.rechazada(&"sesion_ocupada", "Ya hay una batalla en curso.")
	var datos: DatosInicioBatalla = DatosInicioBatallaScript.crear_primer_combate(especie, nivel, ubicacion, Singleton.TemaBatalla.HIERBA_ALTA)
	_rellenar_escenario(datos)
	datos.equipo_rival = _construir_equipo_salvaje(especie, nivel)
	return await _ejecutar_sesion(datos, opciones if opciones != null else OpcionesBatallaOverworld.para_salvaje())


## ScrSpecial_StartWallyTutorialBattle: BLASCO atrapa un RALTS macho de Nv. 5 con el
## ZIGZAGOON de NORMAN (PutZigzagoonInPlayerParty: Nv. 7, solo PLACAJE). El equipo
## del jugador no se toca: el de BLASCO se inyecta en los datos del combate.
func combatir_tutorial_blasco(ubicacion: String = "") -> ResultadoEjecucionBatalla:
	if batalla_activa:
		return ResultadoEjecucionBatalla.rechazada(&"sesion_ocupada", "Ya hay una batalla en curso.")
	var datos: DatosInicioBatalla = DatosInicioBatallaScript.crear_tutorial_blasco(ubicacion, Singleton.TemaBatalla.HIERBA_ALTA)
	_rellenar_escenario(datos)
	datos.equipo_jugador = equipo_tutorial_blasco()
	var ralts := BasePokemon.new("RALTS", 5, "salvaje")
	ralts.sexo = "M"  # CreateMaleMon
	datos.equipo_rival = [ralts] as Array[BasePokemon]
	# CreateBattleStartTask(B_TRANSITION_SLICE, 0).
	var opciones := OpcionesBatallaOverworld.para_salvaje()
	opciones.secuencia_transicion = PackedStringArray([CatalogoTransicionesBatalla.DESTELLOS, CatalogoTransicionesBatalla.CORTES])
	return await _ejecutar_sesion(datos, opciones)


static func equipo_tutorial_blasco() -> Array[BasePokemon]:
	var zigzagoon := BasePokemon.new("ZIGZAGOON", 7, "BLASCO")
	var placaje := DatosCrianza.new().crear_movimiento("PLACAJE")
	if placaje != null:
		zigzagoon.movimientos = [placaje] as Array[Movimiento]
	return [zigzagoon] as Array[BasePokemon]


func combatir_entrenador(
	entrenador_id: int,
	opciones: OpcionesBatallaOverworld = null
) -> ResultadoEjecucionBatalla:
	if batalla_activa:
		return ResultadoEjecucionBatalla.rechazada(&"sesion_ocupada", "Ya hay una batalla en curso.")
	if entrenador_id <= 0:
		return ResultadoEjecucionBatalla.rechazada(&"entrenador_id_invalido", "El ID del entrenador debe ser mayor que cero.")
	var entrenador: DatosEntrenador = DatabaseManager.get_entrenador(entrenador_id)
	if entrenador == null:
		return ResultadoEjecucionBatalla.rechazada(&"entrenador_no_encontrado", "No existe el entrenador solicitado.")
	var error_entrenador := _validar_entrenador(entrenador)
	if not error_entrenador.is_empty():
		return ResultadoEjecucionBatalla.rechazada(&"entrenador_invalido", error_entrenador)

	var opciones_efectivas := opciones if opciones != null else OpcionesBatallaOverworld.para_entrenador()
	var doble := opciones_efectivas.formato_doble or entrenador.tipo_batalla == "DOBLE"
	var datos: DatosInicioBatalla
	if doble:
		datos = DatosInicioBatallaScript.crear_entrenador_doble(entrenador, Singleton.TemaBatalla.EDIFICIO_1)
	else:
		datos = DatosInicioBatallaScript.crear_entrenador(entrenador, Singleton.TemaBatalla.EDIFICIO_1)
	_rellenar_escenario(datos, entrenador.clase_entrenador)
	datos.equipo_rival = _construir_equipo_entrenador(entrenador)
	if datos.equipo_rival.is_empty():
		return ResultadoEjecucionBatalla.rechazada(
			&"equipo_entrenador_invalido",
			"El entrenador no tiene ningún Pokémon válido en su equipo."
		)
	if doble:
		if not equipos_dobles_validos(SistemaGuardado.get_equipo(), datos.equipo_rival):
			return ResultadoEjecucionBatalla.rechazada(&"equipo_doble_invalido", "El combate doble requiere dos Pokémon utilizables por equipo.")
	return await _ejecutar_sesion(datos, opciones_efectivas, _transicion_entrenador(entrenador_id, entrenador, doble, datos))


## StartSpecialBattle 0 (TORRE BATALLA): entrenador y equipo generados por RetoTorreBatalla. Fondo de la torre y
## sin vuelta al punto de curación al perder: el guion de la sala decide.
func combatir_torre_batalla(entrenador: DatosEntrenador, rivales: Array[BasePokemon]) -> ResultadoEjecucionBatalla:
	if batalla_activa:
		return ResultadoEjecucionBatalla.rechazada(&"sesion_ocupada", "Ya hay una batalla en curso.")
	if rivales.is_empty():
		return ResultadoEjecucionBatalla.rechazada(&"equipo_entrenador_invalido", "El entrenador no tiene equipo.")
	var datos: DatosInicioBatalla = DatosInicioBatallaScript.crear_entrenador(entrenador, Singleton.TemaBatalla.EDIFICIO_1)
	_rellenar_escenario(datos, entrenador.clase_entrenador)
	datos.escenario = "torre_batalla"
	datos.equipo_rival = rivales
	datos.extras[DatosInicioBatallaScript.EXTRA_TORRE_BATALLA] = true
	var opciones := OpcionesBatallaOverworld.para_entrenador()
	return await _ejecutar_sesion(datos, opciones, _transicion_entrenador(0, entrenador, false, datos))


## sub_8135CFC: gBattleMons[0] y gBattleMons[1] al acabar.
func _anotar_final_torre(datos: DatosInicioBatalla, ejecucion: ResultadoEjecucionBatalla) -> void:
	var propio: Variant = nodo_batalla.get("poke_jugador")
	var enemigos: Variant = nodo_batalla.get("pokemones_activos_enemigo")
	var rival: Variant = (enemigos as Array)[0] if enemigos is Array and not (enemigos as Array).is_empty() else null
	RetoTorreBatalla.anotar_final_combate(
		datos.entrenador.nombre,
		(propio as BasePokemon).nombre_interno if propio is BasePokemon else "",
		(rival as BasePokemon).nombre_interno if rival is BasePokemon else "",
		ejecucion.resultado == ResultadoBatalla.Valor.VICTORIA_JUGADOR)


static func equipos_dobles_validos(jugadores: Array, rivales: Array) -> bool:
	var cantidades := [0, 0]
	for pokemon in jugadores:
		if pokemon is BasePokemon and pokemon.estad_ps_actual > 0:
			cantidades[0] += 1
	for pokemon in rivales:
		if pokemon is BasePokemon and pokemon.estad_ps_actual > 0:
			cantidades[1] += 1
	return cantidades[0] >= 2 and cantidades[1] >= 2


## `HasEnoughMonsForDoubleBattle`: el jugador tiene dos Pokémon que pueden combatir
## (sin contar huevos). Lo consulta el NPC antes de ofrecer una revancha doble.
static func jugador_puede_combate_doble(equipo: Array) -> bool:
	var aptos := 0
	for pokemon in equipo:
		if pokemon is BasePokemon and pokemon.puede_combatir():
			aptos += 1
	return aptos >= 2


func recuperar_derrota_estandar() -> bool:
	if _defeat_coordinator == null:
		_recrear_colaboradores()
	return _defeat_coordinator.recuperar_en_punto_curacion()


## `transicion_automatica`: fase 2 que sustituye a `automatica` en la secuencia
## (combates de entrenador); vacía, se elige como en un combate salvaje.
func _ejecutar_sesion(
	datos: DatosInicioBatalla,
	opciones: OpcionesBatallaOverworld,
	transicion_automatica: StringName = &""
) -> ResultadoEjecucionBatalla:
	if batalla_activa:
		return ResultadoEjecucionBatalla.rechazada(&"sesion_ocupada", "Ya hay una batalla en curso.")
	if datos == null:
		return ResultadoEjecucionBatalla.rechazada(&"datos_ausentes", "No se proporcionaron datos de batalla.")
	var errores := datos.obtener_errores_validacion()
	if not errores.is_empty():
		return ResultadoEjecucionBatalla.rechazada(&"datos_invalidos", ", ".join(errores))

	batalla_activa = true
	datos_batalla_actual = datos
	_lock.abrir()
	_reproducir_musica(datos, opciones)

	var secuencia := opciones.secuencia_transicion
	if secuencia.has(CatalogoTransicionesBatalla.AUTOMATICA):
		var fase2 := transicion_automatica if not transicion_automatica.is_empty() else _transicion_salvaje(datos)
		secuencia = resolver_secuencia(secuencia, fase2)
	var transicion_ok := await _runner.ejecutar(secuencia)
	if not transicion_ok:
		var fallo_transicion := ResultadoEjecucionBatalla.rechazada(&"transicion_fallida", "No pudo completarse la transición de batalla.")
		await _finalizar_sesion()
		return fallo_transicion

	# Task_BattleStart: al acabar la transición se llama a ClearPoisonStepCounter.
	VenenoCampo.reiniciar_contador()

	capa_batalla = _obtener_capa_batalla()
	if not is_instance_valid(capa_batalla) or not capa_batalla.is_inside_tree():
		var fallo_capa := ResultadoEjecucionBatalla.rechazada(&"capa_batalla_ausente", "No se encontró una CapaBatalla válida.")
		await _finalizar_sesion()
		return fallo_capa

	if packed_batalla == null:
		var fallo_packed := ResultadoEjecucionBatalla.rechazada(&"escena_batalla_ausente", "No hay una escena de batalla configurada.")
		await _finalizar_sesion()
		return fallo_packed
	nodo_batalla = packed_batalla.instantiate()
	if not is_instance_valid(nodo_batalla):
		var fallo_instancia := ResultadoEjecucionBatalla.rechazada(&"instanciacion_fallida", "No pudo instanciarse la escena de batalla.")
		await _finalizar_sesion()
		return fallo_instancia

	capa_batalla.add_child(nodo_batalla)
	# La última fase de la transición deja la pantalla en negro hasta aquí.
	_runner.liberar()
	var relay := BattleResultRelay.new()
	var callback_salida := Callable(relay, "escena_salida_inesperadamente")
	nodo_batalla.tree_exited.connect(callback_salida, CONNECT_ONE_SHOT)
	datos.extras["musica_gestionada_overworld"] = true
	var aceptada: bool = await nodo_batalla.iniciar_batalla_con_configuracion(
		datos,
		Callable(relay, "recibir_resultado")
	)
	if not aceptada:
		relay.rechazar(&"inicio_rechazado", "La escena de batalla rechazó la configuración.")
	elif datos.entrenador != null:
		# CB2_InitBattle: FRIENDSHIP_EVENT_LEAGUE_BATTLE (LÍDER, ALTO MANDO, CAMPEÓN).
		Amistad.aplicar_combate_liga(SistemaGuardado.get_equipo(), datos.entrenador.clase_entrenador)
	var ejecucion: ResultadoEjecucionBatalla = await relay.esperar()
	if is_instance_valid(nodo_batalla) and nodo_batalla.tree_exited.is_connected(callback_salida):
		nodo_batalla.tree_exited.disconnect(callback_salida)
	# FreeResetData_ReturnToOvOrDoEvolutions: solo tras ganar, con la batalla aún
	# en negro y antes de volver al mapa.
	# BattleScript_PayDayMoneyAndPickUpItems: RECOGIDA tras ganar. Si los datos
	# traen un equipo propio (tutorial de BLASCO) no se toca el equipo real.
	if ejecucion.fue_completada() and ejecucion.resultado == ResultadoBatalla.Valor.VICTORIA_JUGADOR \
			and datos.equipo_jugador.is_empty() and not datos.es_torre_batalla():
		EfectosHabilidad.aplicar_recogida(SistemaGuardado.get_equipo())
	# HandleEndTurn_FinishBattle: PutPokemonTodayCaughtOnAir salvo en el primer
	# combate, el tutorial de BLASCO y la ZONA SAFARI.
	if ejecucion.fue_completada() and not datos.es_primer_combate() and not datos.es_tutorial_blasco() \
			and not datos.es_torre_batalla() and not SesionSafari.activa():
		ProgramacionTV.tras_combate()
	if datos.es_torre_batalla() and ejecucion.fue_completada() and is_instance_valid(nodo_batalla):
		_anotar_final_torre(datos, ejecucion)
	if ejecucion.fue_completada() and ejecucion.resultado == ResultadoBatalla.Valor.VICTORIA_JUGADOR \
			and is_instance_valid(nodo_batalla):
		var subidos: Variant = nodo_batalla.get("pokemon_subieron_nivel")
		if subidos is Array:
			await evolucionar_tras_batalla(subidos)
	await _finalizar_sesion()
	return ejecucion


## `TryEvolvePokemon`: cada Pokémon que subió de nivel en el combate, en el
## orden del equipo, evoluciona si cumple `GetEvolutionTargetSpecies` (modo
## nivel); la escena se puede cancelar con B. SHEDINJA se añade al final del
## equipo y no se recorre.
func evolucionar_tras_batalla(subidos: Array) -> void:
	if subidos == null or subidos.is_empty() or not is_inside_tree():
		return
	var equipo: Array = SistemaGuardado.get_equipo()
	for poke in equipo.duplicate():
		if not (poke is BasePokemon) or not subidos.has(poke):
			continue
		var destino := EvolucionPokemon.especie_destino(poke, EvolucionPokemon.Modo.NIVEL)
		if destino.is_empty():
			continue
		await EscenaEvolucionAnim.ejecutar_en(get_tree(), poke, destino, true, equipo)


func _finalizar_sesion() -> void:
	if _runner != null:
		_runner.cancelar()
	# La batalla termina en negro: el telón del mapa (debajo de CapaBatalla) la
	# releva antes de liberarla para que no asome el mapa entre ambas.
	var telon: ColorRect = _obtener_telon_mapa() if is_instance_valid(nodo_batalla) else null
	var telon_ya_cubierto := telon != null and telon.visible and telon.color.a >= 1.0
	if telon != null:
		telon.call(&"cubrir")
	if _outcome_handler != null:
		_outcome_handler.cerrar(nodo_batalla)
	nodo_batalla = null
	datos_batalla_actual = null
	# La escena se elimina antes de soltar el lock. Así, en una derrota salvaje,
	# el llamador puede transferir el control al lock de derrota sin dejar un
	# frame jugable entre ambos.
	if is_inside_tree():
		await get_tree().process_frame
	if _lock != null:
		_lock.cerrar()
	batalla_activa = false
	if telon != null and not telon_ya_cubierto:
		_revelar_mapa_tras_batalla(telon)


## Sin esperar: el llamador recibe el resultado en este mismo frame y puede
## quedarse con la pantalla en negro (derrota → warp al punto de curación, guion
## que funde por su cuenta). Si nadie la reclama, el mapa aparece con fundido.
func _revelar_mapa_tras_batalla(telon: ColorRect) -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_instance_valid(telon) or bool(telon.get("en_transicion")):
		return
	telon.call(&"aclarar", DURACION_REVELAR_MAPA)


func _obtener_telon_mapa() -> ColorRect:
	if not is_instance_valid(administrador_mapa):
		return null
	var telon := administrador_mapa.get("telon") as ColorRect
	if telon == null or not telon.has_method("cubrir") or not telon.has_method("aclarar"):
		return null
	return telon


func _reproducir_musica(datos: DatosInicioBatalla, opciones: OpcionesBatallaOverworld) -> void:
	var musica_mapa := _obtener_musica_batalla_mapa()
	var tema := ""
	if datos.tipo == Singleton.TipoBatalla.ENTRENADOR:
		tema = BattleLaunchService.resolver_musica_entrenador(
			datos.entrenador,
			musica_mapa,
			opciones.musica_especifica)
	else:
		tema = BattleLaunchService.resolver_tema_musica_batalla(opciones.musica_especifica, musica_mapa)
	Singleton.reproducir_tema(tema)


## Rellena el escenario de batalla (fondo, suelo y entrada) y el terreno (animación
## de la tira de entrada) según el mapa y la celda del jugador, como en Rubí
## (EscenarioBatalla). Sin administrador de mapa válido los deja vacíos y
## batalla.gd usa el tema gráfico legado de los datos.
func _rellenar_escenario(datos: DatosInicioBatalla, clase_entrenador: String = "") -> void:
	if not is_instance_valid(administrador_mapa):
		return
	if administrador_mapa.has_method("obtener_escenario_batalla"):
		datos.escenario = str(administrador_mapa.obtener_escenario_batalla(clase_entrenador))
	if administrador_mapa.has_method("obtener_terreno_batalla"):
		datos.terreno = int(administrador_mapa.obtener_terreno_batalla())
	if administrador_mapa.has_method("obtener_clima_batalla"):
		datos.clima = int(administrador_mapa.obtener_clima_batalla())


## Sustituye `automatica` de la secuencia por la fase 2 elegida.
static func resolver_secuencia(secuencia: PackedStringArray, fase2: StringName) -> PackedStringArray:
	var resultado := PackedStringArray()
	for estilo in secuencia:
		resultado.append(String(fase2) if estilo == CatalogoTransicionesBatalla.AUTOMATICA else estilo)
	return resultado


## GetWildBattleTransition.
func _transicion_salvaje(datos: DatosInicioBatalla) -> StringName:
	var nivel_rival: int = datos.equipo_rival[0].nivel if not datos.equipo_rival.is_empty() else datos.pokemon_salvaje_nivel
	var nivel_jugador := SelectorTransicionBatalla.suma_niveles_jugador(_equipo_jugador(datos), 1)
	return SelectorTransicionBatalla.para_salvaje(_tipo_transicion_mapa(datos), nivel_rival, nivel_jugador)


## GetTrainerBattleTransition: N = 2 en combate doble.
func _transicion_entrenador(entrenador_id: int, entrenador: DatosEntrenador, doble: bool, datos: DatosInicioBatalla) -> StringName:
	var n := 2 if doble else 1
	return SelectorTransicionBatalla.para_entrenador(
		_tipo_transicion_mapa(datos),
		entrenador_id,
		entrenador.clase_entrenador,
		SelectorTransicionBatalla.suma_niveles_rival(datos.equipo_rival, n),
		SelectorTransicionBatalla.suma_niveles_jugador(_equipo_jugador(datos), n)
	)


## GetBattleTransitionTypeByMap. El agua sale del terreno ya resuelto en
## _rellenar_escenario (BattleSetup_GetTerrain mira la misma casilla); sin mapa,
## tipo normal.
func _tipo_transicion_mapa(datos: DatosInicioBatalla) -> int:
	if not is_instance_valid(administrador_mapa):
		return SelectorTransicionBatalla.TIPO_NORMAL
	var mapa := administrador_mapa.get("mapa_actual") as MapaConfiguracion
	if mapa == null:
		return SelectorTransicionBatalla.TIPO_NORMAL
	var tipo_mapa := mapa.obtener_tipo_mapa_batalla()
	return SelectorTransicionBatalla.tipo_por_mapa(
		EfectoOscuridadCueva.es_mapa_oscuro(mapa),
		SelectorTransicionBatalla.terreno_es_agua(datos.terreno),
		tipo_mapa == EscenarioBatalla.TipoMapa.SUBTERRANEO,
		tipo_mapa == EscenarioBatalla.TipoMapa.SUBMARINO
	)


func _equipo_jugador(datos: DatosInicioBatalla) -> Array:
	return datos.equipo_jugador if not datos.equipo_jugador.is_empty() else SistemaGuardado.get_equipo()


func _obtener_musica_batalla_mapa() -> String:
	if not is_instance_valid(administrador_mapa):
		return ""
	var mapa := administrador_mapa.get("mapa_actual") as MapaConfiguracion
	if mapa == null:
		return ""
	if mapa.has_method("obtener_musica_batalla_efectiva"):
		return mapa.obtener_musica_batalla_efectiva()
	return mapa.musica_batalla


func _obtener_capa_batalla() -> CanvasLayer:
	# La capa puede reemplazarse al cambiar de mapa y no siempre cuelga
	# directamente de root; se vuelve a resolver de forma recursiva por sesión.
	var capa := Singleton.obtener_nodo("CapaBatalla") as CanvasLayer
	if is_instance_valid(capa):
		return capa
	if is_instance_valid(capa_batalla) and capa_batalla.is_inside_tree():
		return capa_batalla
	return null


func _construir_equipo_salvaje(especie: String, nivel: int) -> Array[BasePokemon]:
	var equipo: Array[BasePokemon] = []
	var nombre := especie.strip_edges().to_upper()
	if not DatabaseManager.existe_pokemon(nombre):
		nombre = "RHYDON"
	equipo.append(BasePokemon.new(nombre, maxi(nivel, 1), "salvaje"))
	return equipo


func _construir_equipo_entrenador(entrenador: DatosEntrenador) -> Array[BasePokemon]:
	var equipo: Array[BasePokemon] = []
	# Movimientos por nivel + fijos del entrenador (ver MovimientosEntrenador).
	var datos_movimientos := DatosCrianza.new()
	for datos_pokemon in entrenador.pokemon:
		var nombre := datos_pokemon.nombre_interno.strip_edges().to_upper()
		if not DatabaseManager.existe_pokemon(nombre):
			continue
		var pokemon := BasePokemon.new(nombre, datos_pokemon.nivel, entrenador.clase_entrenador)
		pokemon.objeto = datos_pokemon.objeto
		MovimientosEntrenador.aplicar(pokemon, datos_pokemon.movimientos, datos_movimientos)
		equipo.append(pokemon)
	return equipo


func _validar_entrenador(entrenador: DatosEntrenador) -> String:
	if entrenador.nombre.strip_edges().is_empty():
		return "El entrenador no tiene nombre."
	if entrenador.pokemon.is_empty():
		return "El entrenador no tiene Pokémon."
	for datos_pokemon in entrenador.pokemon:
		if datos_pokemon.nombre_interno.strip_edges().is_empty() or datos_pokemon.nivel <= 0:
			return "El equipo del entrenador contiene datos inválidos."
	return ""


func _recrear_colaboradores() -> void:
	_lock = BattleOverworldLock.new(administrador_mapa)
	_runner = BattleTransitionRunner.new(self)
	_outcome_handler = BattleOutcomeHandler.new(administrador_mapa)
	_defeat_coordinator = BattleDefeatCoordinator.new(administrador_mapa)

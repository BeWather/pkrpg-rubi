## evento_vestibulo_torre.gd
## Vestíbulo de la TORRE BATALLA (pokeruby data/maps/BattleTower_Lobby/scripts.inc). La recepcionista (objeto 1, (6,5))
## inscribe en las SALAS BATALLA, al entrar resuelve el reto anterior (sub_8134548) y el DUEÑO (objeto 6, (7,6)) da los
## ESCUDOS a las 50 y 100 victorias seguidas.
##
## El equipo se elige en una sola pantalla (modo TORRE_BATALLA, como choose_party.c): ENTRAR marca PRIMERO / SEGUNDO /
## TERCERO sin salir y VALE termina. El hombre (objeto 2) cambia el saludo del jugador en PALABRAS FÁCILES y la reportera
## (objeto 5) le entrevista para el ENTRENADOR ESTRELLA de la tele.
class_name EventoVestibuloTorre
extends EventoTorreBatalla

const ESCENA_EQUIPO: String = "res://UI/equipo/pantalla-equipo.tscn"
const CELDA_RECEPCIONISTA: Vector2i = Vector2i(6, 5)
const CELDA_JUGADOR_ATENDIDO: Vector2i = Vector2i(6, 6)
const CELDA_DUENO: Vector2i = Vector2i(7, 6)
const CELDA_ASCENSOR: Vector2i = Vector2i(1, 6)
## FLAG_TEMP_2: ya entrevistado en esta visita al vestíbulo.
const TEMPORAL_ENTREVISTADO: String = "torre_batalla_reportera_entrevistado"

@export var recepcionista: NodePath
@export var dueno: NodePath
@export var hombre: NodePath
@export var reportera: NodePath
@export var cartel_records: NodePath
## Puerta del ascensor (warp 2, (6,1)): opendoor / closedoor de BattleTower_Lobby_EventScript_160664.
@export var puerta_ascensor: NodePath

## Sustituye a los menús de opciones y a la elección del equipo (tests).
## selector_equipo.call() -> índices elegidos en orden ([] = se sale).
var selector_equipo: Callable = Callable()
## Sustituye al guardado (tests).
var guardador: Callable = Callable()
## Sustituye a la pantalla de PALABRAS FÁCILES (tests): editor_palabras.call() -> palabras ([] = cancelada).
var editor_palabras: Callable = Callable()

signal _equipo_cerrado


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_conectar(recepcionista, "hablado", _on_recepcionista_hablada)
	_conectar(dueno, "hablado", _on_dueno_hablado)
	_conectar(hombre, "hablado", _on_hombre_hablado)
	_conectar(reportera, "hablado", _on_reportera_hablada)
	_conectar(cartel_records, "accionado", _on_cartel_records)
	super._ready()
	_comprobar_al_cargar()


## Al continuar una partida guardada en el vestíbulo el mapa no se «activa»: el reto se resuelve igual.
func _comprobar_al_cargar() -> void:
	for i in 120:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		var real := _administrador()
		if real == null:
			return
		if real.get("mapa_actual") == obtener_mapa() and real.get("jugador") != null and not _en_curso:
			await guion_entrada()
			return


func preparar() -> void:
	var npc_recepcionista := _npc(recepcionista)
	if npc_recepcionista != null:
		colocar(npc_recepcionista, CELDA_RECEPCIONISTA)
		npc_recepcionista.visible = true
		mirar(npc_recepcionista, Vector2.DOWN)
	var npc_dueno := _npc(dueno)
	if npc_dueno != null:
		colocar(npc_dueno, CELDA_DUENO)
		npc_dueno.visible = RetoTorreBatalla.dueno_presente()
	# OnResume (TryEnableBravoTrainerBattleTower) y OnTransition (1AE2ED).
	RetoTorreBatalla.revisar_bravo()
	var npc_reportera := _npc(reportera)
	if npc_reportera != null:
		npc_reportera.visible = RetoTorreBatalla.bravo_activo() \
			and ProgramasTV.antes_de_entrevista(ProgramasTV.Tipo.ENTRENADOR_ESTRELLA_TORRE) >= 0


## BattleTower_Lobby_MapScript2_160302.
func guion_entrada() -> void:
	var pendiente := RetoTorreBatalla.revisar_al_entrar()
	if pendiente == RetoTorreBatalla.Estado.SIN_RETO or not comenzar(_administrador()):
		return
	girar_jugador(Vector2.UP)
	var npc := _npc(recepcionista)
	match pendiente:
		RetoTorreBatalla.Estado.INSCRITO:
			await mensaje(P + "SIN_GUARDAR")
		RetoTorreBatalla.Estado.GANADO:
			await _felicitar()
		RetoTorreBatalla.Estado.PERDIDO:
			await _despedir_derrota()
		RetoTorreBatalla.Estado.PAUSADO:
			await _reanudar()
			return
	terminar(false, [npc] if npc != null else [])
	preparar()


## BattleTower_Lobby_EventScript_16049E.
func _on_recepcionista_hablada(npc: Node2D) -> void:
	if _en_curso or not comenzar(_administrador()):
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()
	if RetoTorreBatalla.estado() == RetoTorreBatalla.Estado.PREMIO_PENDIENTE:
		await _felicitar()
		terminar(false, [npc])
		return
	RetoTorreBatalla.guardar_copia_equipo()
	await mensaje(P + "VESTIBULO_RECEPCIONISTA")
	if await _inscribir():
		await _llevar_al_ascensor()
		return
	terminar(false, [npc])


## BattleTower_Lobby_EventScript_1604BE .. 160652. Devuelve true si el jugador entra en el reto.
func _inscribir() -> bool:
	while true:
		match await _elegir(P + "PREGUNTA_RETO", [P + "OPCION_ACEPTAR", P + "OPCION_INFO", P + "OPCION_SALIR"]):
			0:
				break
			1:
				await mensaje(P + "INFO")
			_:
				await _hasta_pronto()
				return false
	var tipo := await _elegir(P + "PREGUNTA_NIVEL", [P + "OPCION_NV50", P + "OPCION_NV100", P + "OPCION_SALIR"])
	if tipo != RetoTorreBatalla.NIVEL_50 and tipo != RetoTorreBatalla.NIVEL_100:
		await _hasta_pronto()
		return false
	if not RetoTorreBatalla.equipo_admitido(SistemaGuardado.get_equipo(), tipo):
		var clave := P + ("SIN_EQUIPO_50" if tipo == RetoTorreBatalla.NIVEL_50 else "SIN_EQUIPO_100")
		await mensaje(clave, true, {"{valor}": RetoTorreBatalla.texto_vetados()})
		return false
	RetoTorreBatalla.fijar_nivel(tipo)
	await mensaje(P + "SELECCIONA")
	var indices := await _elegir_equipo(tipo)
	if indices.is_empty() or not await preguntar_si_no(P + "AVISO_GUARDAR"):
		RetoTorreBatalla.cargar_copia_equipo()
		await _hasta_pronto()
		return false
	var estado_previo := RetoTorreBatalla.estado()
	RetoTorreBatalla.anotar_seleccion(indices)
	RetoTorreBatalla.fijar_estado(RetoTorreBatalla.Estado.INSCRITO)
	RetoTorreBatalla.fijar_ya_guardado(false)
	RetoTorreBatalla.cargar_copia_equipo()
	admin.cuadro_dialogo.cerrar()
	if not _guardar():
		# BattleTower_Lobby_EventScript_160642.
		RetoTorreBatalla.fijar_estado(estado_previo)
		await _hasta_pronto()
		return false
	RetoTorreBatalla.guardar_copia_equipo()
	RetoTorreBatalla.reducir_equipo()
	RetoTorreBatalla.activar_bravo()
	await mensaje(P + "TE_LLEVO")
	return true


## BattleTower_Lobby_EventScript_160652.
func _hasta_pronto() -> void:
	await mensaje(P + "HASTA_PRONTO")
	RetoTorreBatalla.cancelar_inscripcion()


## BattleTower_Lobby_EventScript_160664 + warp al ascensor.
func _llevar_al_ascensor() -> void:
	var npc := _npc(recepcionista)
	colocar_jugador(CELDA_JUGADOR_ATENDIDO, Vector2.UP)
	var arriba: Array = [Vector2.UP, Vector2.UP, Vector2.UP]
	var tareas: Array[Callable] = [recorrer_jugador.bind(arriba)]
	if npc != null:
		tareas.append(recorrer.bind(npc, arriba))
	await en_paralelo(tareas)
	var puerta := get_node_or_null(puerta_ascensor)
	Singleton.play_sound.emit("puerta_entrada")  # opendoor: SE_DOOR
	await abrir_puerta(puerta)
	var entrada: Array[Callable] = [_entrar_jugador]
	if npc != null:
		entrada.append(_entrar_y_ocultar.bind(npc))
	await en_paralelo(entrada)
	await cerrar_puerta(puerta)
	_ir_a(MAPA_ASCENSOR, CELDA_ASCENSOR, Vector2.UP, [npc] if npc != null else [])


## Movement_16069A: walk_up ×2 + set_invisible.
func _entrar_jugador() -> void:
	await recorrer_jugador([Vector2.UP, Vector2.UP])
	admin.jugador.visible = false


## Movement_160697: walk_up + set_invisible.
func _entrar_y_ocultar(npc: Node2D) -> void:
	await caminar(npc, Vector2.UP)
	npc.visible = false


## BattleTower_Lobby_EventScript_160342.
func _felicitar() -> void:
	await mensaje(P + "ENHORABUENA")
	RetoTorreBatalla.cargar_copia_equipo()
	if RetoTorreBatalla.estado() != RetoTorreBatalla.Estado.PREMIO_PENDIENTE and RetoTorreBatalla.conceder_cintas():
		await mensaje_con_fanfarria(P + "CINTAS")
		await mensaje(P + "CINTAS_PUESTAS")
	# BattleTower_Lobby_EventScript_16037D: el récord se guarda una sola vez.
	if not RetoTorreBatalla.ya_guardado():
		await mensaje(P + "GUARDA_RECORD")
		RetoTorreBatalla.anotar_ultima_racha()
		RetoTorreBatalla.determinar_premio(rng)
		_guardar_progreso()
	# BattleTower_Lobby_EventScript_1603AD.
	RetoTorreBatalla.fijar_estado(RetoTorreBatalla.Estado.PREMIADO)
	await mensaje(P + "PREMIO_INTRO")
	var objeto := RetoTorreBatalla.premio()
	var entrega: Dictionary = SistemaGuardado.dar_objeto_jugador(objeto, 1)
	if not bool(entrega.get("exito", false)):
		RetoTorreBatalla.fijar_estado(RetoTorreBatalla.Estado.PREMIO_PENDIENTE)
		await mensaje(P + "MOCHILA_LLENA")
		return
	var nombre := str(SistemaGuardado.obtener_datos_objeto_completos(objeto).get("nombre", objeto))
	await mensaje_con_fanfarria(P + "PREMIO_RECIBIDO", FANFARRIA_OBJETO, {"{valor}": nombre})
	if RetoTorreBatalla.racha_actual() == 49:
		await mensaje(P + "ENTRENADOR_50")
	await mensaje(P + "HASTA_PRONTO")


## BattleTower_Lobby_EventScript_160419.
func _despedir_derrota() -> void:
	await mensaje(P + "GRACIAS")
	await mensaje(P + "GUARDA_RECORD")
	RetoTorreBatalla.anotar_ultima_racha()
	RetoTorreBatalla.fijar_estado(RetoTorreBatalla.Estado.SIN_RETO)
	_guardar_progreso()
	await mensaje(P + "HASTA_PRONTO")


## BattleTower_Lobby_EventScript_16044B: el reto guardado sigue donde quedó.
func _reanudar() -> void:
	RetoTorreBatalla.activar_bravo()
	await mensaje(P + "TE_ESPERABAMOS")
	await mensaje(P + "VA_A_GUARDAR")
	RetoTorreBatalla.fijar_estado(RetoTorreBatalla.Estado.INSCRITO)
	_guardar_progreso()
	RetoTorreBatalla.fijar_ya_guardado(false)
	RetoTorreBatalla.guardar_copia_equipo()
	RetoTorreBatalla.reducir_equipo()
	await mensaje(P + "TE_LLEVO")
	await _llevar_al_ascensor()


## SaveBattleTowerProgress: unk_554 = 1 y escritura.
func _guardar_progreso() -> void:
	RetoTorreBatalla.fijar_ya_guardado(true)
	_guardar()


func _guardar() -> bool:
	if guardador.is_valid():
		return bool(guardador.call())
	return SistemaGuardado.guardar_partida()


## multichoice: pregunta con opciones; B o salir devuelve la última.
func _elegir(clave: String, opciones: Array) -> int:
	var dialogo: NinePatchRect = admin.cuadro_dialogo
	dialogo.cerrar()
	var textos := PackedStringArray()
	for opcion: String in opciones:
		textos.append(tr(opcion))
	dialogo.preguntaSiNo(_texto(clave, {}), textos)
	while true:
		var datos: Array = await dialogo.comando_ejecutado
		if datos.size() >= 2 and str(datos[0]) == "respuesta_confirmacion":
			var parametros: Array = datos[1]
			var respuesta := str(parametros[0]) if not parametros.is_empty() else ""
			if respuesta.is_valid_int():
				return int(respuesta)
			# Y/N de un cuadro de dos botones; B es la última opción.
			return 0 if respuesta == "Y" else opciones.size() - 1
	return opciones.size() - 1


## ChooseBattleTowerPlayerParty (sub_8121E34): una sola pantalla de equipo en modo TORRE_BATALLA,
## que marca PRIMERO / SEGUNDO / TERCERO y comprueba especie y objeto al pulsar VALE.
## Devuelve los índices en orden de entrada, o [] si se sale.
func _elegir_equipo(tipo: int) -> Array[int]:
	if selector_equipo.is_valid():
		var elegidos: Array[int] = []
		elegidos.assign(selector_equipo.call())
		return elegidos
	var capa := get_tree().root.get_node_or_null("AdministradorMapa/Menu")
	if capa == null:
		return []
	admin.cuadro_dialogo.cerrar()
	await Singleton.transicion("oscurecer")
	var equipo := EquipoPokemon.new()
	var admitidos: Array[bool] = []
	for poke: BasePokemon in SistemaGuardado.get_equipo():
		equipo.agregar_pokemon(poke)
		admitidos.append(RetoTorreBatalla.pokemon_admitido(poke, tipo))
	var pantalla := (load(ESCENA_EQUIPO) as PackedScene).instantiate() as PantallaEquipoControlador
	capa.add_child(pantalla)
	var eleccion := {"indices": [] as Array[int], "lista": false}
	pantalla.equipo_torre_elegido.connect(func(indices: Array[int]) -> void:
		eleccion["indices"] = indices
		eleccion["lista"] = true
		_equipo_cerrado.emit()
	)
	pantalla.seleccion_cancelada.connect(func() -> void:
		eleccion["lista"] = true
		_equipo_cerrado.emit()
	)
	pantalla.mostrar_equipo_torre(equipo, admitidos)
	await Singleton.transicion("aclarar")
	if not bool(eleccion["lista"]):
		await _equipo_cerrado
	pantalla.activo = false
	await Singleton.transicion("oscurecer")
	pantalla.ocultar_pantalla_equipo()
	pantalla.queue_free()
	await Singleton.transicion("aclarar")
	var resultado: Array[int] = []
	resultado.assign(eleccion["indices"])
	return resultado


## BattleTower_Lobby_EventScript_160733.
func _on_dueno_hablado(npc: Node2D) -> void:
	if _en_curso or not comenzar(_administrador()):
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()
	if SistemaGuardado.get_flag(RetoTorreBatalla.BANDERA_ESCUDO_ORO):
		await mensaje(P + "DUENO_SATISFECHO")
	elif SistemaGuardado.get_flag(RetoTorreBatalla.BANDERA_ESCUDO_PLATA):
		if RetoTorreBatalla.mejor_racha() < 100:
			await mensaje(P + "DUENO_SATISFECHO")
		else:
			await _dar_escudo(P + "DUENO_100", RetoTorreBatalla.DECORACION_ESCUDO_ORO, RetoTorreBatalla.BANDERA_ESCUDO_ORO)
	else:
		await _dar_escudo(P + "DUENO_50", RetoTorreBatalla.DECORACION_ESCUDO_PLATA, RetoTorreBatalla.BANDERA_ESCUDO_PLATA)
	terminar(false, [npc])


func _dar_escudo(clave: String, decoracion: int, bandera: String) -> void:
	await mensaje(clave)
	var sistema := SistemaGuardado.get_bases_secretas() as SistemaBasesSecretas
	if sistema == null or sistema.agregar_decoracion(decoracion) < 0:
		await mensaje(P + "SIN_SITIO_DECORACION", true, {"{decoracion}": DatosBasesSecretas.nombre_decoracion(decoracion)})
		await mensaje(P + "DUENO_SIN_SITIO")
		return
	SistemaGuardado.set_flag(bandera, true)
	await mensaje(P + "DUENO_EXPONLO")


## BattleTower_Lobby_EventScript_1606A5: Common_EventScript_ShowEasyChatScreen con VAR_0x8004 = 1.
func _on_hombre_hablado(npc: Node2D) -> void:
	if _en_curso or not comenzar(_administrador()):
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()
	if not await preguntar_si_no(P + "VESTIBULO_HOMBRE"):
		await mensaje(P + "VESTIBULO_HOMBRE_NO")
		terminar(false, [npc])
		return
	await mensaje(P + "VESTIBULO_HOMBRE_ACEPTA")
	var palabras := await _palabras_faciles(PantallaPalabrasFaciles.Modo.SALUDO_TORRE, RetoTorreBatalla.saludo(), 0)
	npc.mirar_jugador()
	if palabras.is_empty():
		await mensaje(P + "VESTIBULO_HOMBRE_CANCELA")
	else:
		RetoTorreBatalla.fijar_saludo(palabras)
		await mensaje(P + "VESTIBULO_HOMBRE_GRACIAS")
	terminar(false, [npc])


## BattleTower_Lobby_EventScript_1AE1FF.
func _on_reportera_hablada(npc: Node2D) -> void:
	if _en_curso or not comenzar(_administrador()):
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()
	await _entrevista(npc)
	terminar(false, [npc])


func _entrevista(npc: Node2D) -> void:
	var hueco := -1
	if not SistemaGuardado.get_flag_temporal(TEMPORAL_ENTREVISTADO):
		hueco = ProgramasTV.antes_de_entrevista(ProgramasTV.Tipo.ENTRENADOR_ESTRELLA_TORRE)
	if hueco < 0:
		await mensaje(P + "VESTIBULO_REPORTERA_FIN")
		return
	if not await preguntar_si_no(P + "VESTIBULO_REPORTERA_INVITA"):
		await mensaje(P + "VESTIBULO_REPORTERA_NO")
		return
	var opinion := await _elegir(P + "VESTIBULO_REPORTERA_ACEPTA",
		[P + "VESTIBULO_REPORTERA_OPCION_ALEGRE", P + "VESTIBULO_REPORTERA_OPCION_TRISTE"])
	await mensaje(P + ("VESTIBULO_REPORTERA_ALEGRE" if opinion == 0 else "VESTIBULO_REPORTERA_TRISTE"))
	await mensaje(P + "VESTIBULO_REPORTERA_PREGUNTA")
	var vacia: Array[int] = []
	var palabras := await _palabras_faciles(PantallaPalabrasFaciles.Modo.ENTREVISTA, vacia, 1)
	npc.mirar_jugador()
	if palabras.is_empty():
		await mensaje(P + "VESTIBULO_REPORTERA_CANCELA")
		return
	await mensaje(P + "VESTIBULO_REPORTERA_GRACIAS")
	SistemaGuardado.set_flag_temporal(TEMPORAL_ENTREVISTADO, true)
	ProgramasTV.grabar_entrenador_estrella_torre(hueco, palabras[0], opinion)  # InterviewAfter


func _palabras_faciles(modo: PantallaPalabrasFaciles.Modo, frase: Array[int], reportero: int) -> Array[int]:
	admin.cuadro_dialogo.cerrar()
	var palabras: Array[int] = []
	if editor_palabras.is_valid():
		palabras.assign(await editor_palabras.call())
	else:
		palabras = await PantallaPalabrasFaciles.escribir(self, modo, frase, reportero)
	return palabras


## ShowBattleTowerRecords (battle_records.c), en el cuadro de diálogo.
func _on_cartel_records(_cartel: Node) -> void:
	if _en_curso or not comenzar(_administrador()):
		return
	await mensaje(P + "RESULTADOS", false)
	for tipo: int in [RetoTorreBatalla.NIVEL_50, RetoTorreBatalla.NIVEL_100]:
		var etiqueta := "ETIQUETA_ACTUAL" if RetoTorreBatalla.racha_en_curso(tipo) else "ETIQUETA_ANTERIOR"
		await mensaje(P + "RECORDS_NIVEL", tipo == RetoTorreBatalla.NIVEL_100, {
			"{nivel}": tr(P + ("NIVEL_50" if tipo == RetoTorreBatalla.NIVEL_50 else "NIVEL_100")),
			"{etiqueta}": tr(P + etiqueta),
			"{ultima}": RetoTorreBatalla.ultima_racha(tipo),
			"{record}": RetoTorreBatalla.record(tipo),
		})
	terminar()

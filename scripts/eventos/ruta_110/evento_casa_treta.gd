## evento_casa_treta.gd
## ENTRADA, FINAL y PASILLO de la CASA TRETA (pokeruby data/maps/
## Route110_TrickHouse{Entrance,End,Corridor}/scripts.inc), las tres salas comunes de la
## escena `ruta_110_casa_treta.tscn`. Cada una de las 8 pruebas es otra escena y la
## controla ella sola (ver el contrato en documentacion/20261014-casa-treta-fase1.md).
##
## Subsala por celda (`HistoriaCasaTreta.subsala_por_celda`): `mapa_activado` se emite
## antes de colocar al jugador, así que se usa la celda de llegada del warp
## (`AdministradorMapa.coneccion_posicion`). Cada cambio de sala es un warp a la misma
## escena (se instancia otra copia), por lo que `OnTransition`/`OnWarp` de Rubí se
## reducen a `_on_mapa_activado`.
##
##   ENTRADA  OnTransition, OnWarp (MAESTRO escondido/junto a la cortina/ausente), OnFrame
##            (BeginChallenge), 4 disparadores «te estoy observando» + destello, cortina (5,1)
##            y MAESTRO: encontrarlo, recompensa pendiente, «sigo pensando» y TIENDA ROJA.
##   FINAL    puerta (29,1) que se cierra al llegar, MAESTRO (23,5): premio del nivel, o la
##            TIENDA ROJA en el 8; disparador (21,2) «¿me estás ignorando?».
##   PASILLO  VAR_TRICK_HOUSE_STATE = 1 (la entrada lo lee y deja al MAESTRO en REGRESO).
##
## Fallos de Rubí corregidos (ver HistoriaCasaTreta): sin warp (5,2) al acertijo 1, el
## MAESTRO no reaparece al volver del pasillo al FINAL y entra en la prueba del nivel real.
extends EventoGuionizado
class_name EventoCasaTreta

const MOTIVO_PAUSA: StringName = &"ruta_110_casa_treta"
const ID_OBSERVA: StringName = &"observa"
const ID_SALIDA_FINAL: StringName = &"salida_final"
const ESCENA_PRUEBA: String = "ruta_110_casa_treta_prueba%d"
## Llegada a cada prueba: (0,21), mirando al sur (la flecha de salida).
const LLEGADA_PRUEBA: Vector2 = Vector2(0, 21)

## Atlas de la capa Suelo (`tileset_edificios.tres`, fuente 0).
const FUENTE_ATLAS: int = 0
## METATILE_GenericBuilding_TrickHouse_Stairs_Down (0x219): el agujero tras la cortina.
const ATLAS_AGUJERO: Vector2i = Vector2i(1, 3)
## METATILE_GenericBuilding_TrickHouse_Door_Closed (0x21B).
const ATLAS_PUERTA_CERRADA: Vector2i = Vector2i(3, 3)

## SE_M_EXPLOSION (id 178 de songs.h), extraído del APU de la GBA.
const SONIDO_EXPLOSION: String = "SE_M_EXPLOSION"
const SONIDO_PIN: String = "SE_PIN"

const TEXTO_OBSERVANDO: String = "CASA_TRETA_ENTRADA_OBSERVANDO"
const TEXTO_PRESENTACION: String = "CASA_TRETA_ENTRADA_PRESENTACION"
const TEXTO_DESAFIO: String = "CASA_TRETA_ENTRADA_DESAFIO"
const TEXTO_CORTINA: String = "CASA_TRETA_ENTRADA_CORTINA"
const TEXTO_AGUJERO: String = "CASA_TRETA_ENTRADA_AGUJERO"
const TEXTO_NOTA: String = "CASA_TRETA_ENTRADA_NOTA"
const TEXTO_PROXIMO_TRUCO: String = "CASA_TRETA_ENTRADA_PROXIMO_TRUCO"
const TEXTO_IDEANDO: String = "CASA_TRETA_ENTRADA_IDEANDO"
const TEXTO_RECOMPENSA: String = "CASA_TRETA_ENTRADA_RECOMPENSA"
const TEXTO_RECOMPENSA_NO: String = "CASA_TRETA_ENTRADA_RECOMPENSA_NO"
const TEXTO_MECA5_TIENDA: String = "CASA_TRETA_ENTRADA_MECA5_TIENDA"
const TEXTO_MECA5_ADIOS: String = "CASA_TRETA_ENTRADA_MECA5_ADIOS"
const TEXTO_MECA5_PC_LLENO: String = "CASA_TRETA_ENTRADA_MECA5_PC_LLENO"
const TEXTO_FIN_LLEGASTE: String = "CASA_TRETA_FIN_LLEGASTE"
const TEXTO_FIN_RECOMPENSA: String = "CASA_TRETA_FIN_RECOMPENSA"
const TEXTO_FIN_NUEVOS_TRUCOS: String = "CASA_TRETA_FIN_NUEVOS_TRUCOS"
const TEXTO_FIN_MOCHILA_LLENA: String = "CASA_TRETA_FIN_MOCHILA_LLENA"
const TEXTO_FIN_SIN_IDEAS: String = "CASA_TRETA_FIN_SIN_IDEAS"
const TEXTO_FIN_TIENDA: String = "CASA_TRETA_FIN_TIENDA"
const TEXTO_FIN_PC_LLENO: String = "CASA_TRETA_FIN_PC_LLENO"
const TEXTO_FIN_VIAJE: String = "CASA_TRETA_FIN_VIAJE"
const TEXTO_FIN_IGNORAS: String = "CASA_TRETA_FIN_IGNORAS"
const TEXTO_MOCHILA_LLENA: String = "MOCHILA_LLENA_REGALO"
const TEXTO_DECOR_SIN_SITIO: String = "CASA_TRETA_DECOR_SIN_SITIO"
const TEXTO_DECOR_OBTENIDA: String = "CASA_TRETA_DECOR_OBTENIDA"
const TEXTO_DECOR_ENVIADA_PC: String = "CASA_TRETA_DECOR_ENVIADA_PC"

## NPC del MAESTRO de la ENTRADA (objeto 1 de Entrance) y del FINAL (objeto 1 de End).
@export var maestro: NodePath
@export var maestro_final: NodePath
## Cortina (bg_event (5,1), solo mirando al norte): CartelEvento.
@export var cortina: NodePath
## PEPITA oculta del FINAL (bg_hidden_item_event (4,5) de End): ItemOverworld.
@export var pepita: NodePath
## Capa `Suelo` (cortina y puerta del FINAL) y capa de colisiones.
@export var capa_suelo: NodePath
@export var datos_tiles: NodePath

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null
## false omite esperas, exclamaciones, destello y fundidos (tests).
var con_esperas: bool = true
## Subsala cargada (HistoriaCasaTreta.Subsala).
var subsala: int = HistoriaCasaTreta.Subsala.NINGUNA
## Celda de llegada del warp con la que se decidió la subsala.
var celda_llegada: Vector2i = Vector2i.ZERO
## VAR_TEMP_2 de End: el MAESTRO ya habló (se reinicia al cargar la escena).
var final_hablado: bool = false
## VAR_TEMP_1 de End: la puerta de llegada ya se cerró.
var puerta_final_cerrada: bool = false
## Último destello lanzado (tests).
var ultimo_destello: EfectoDestello = null
## Prueba a la que se entró con la cortina (tests).
var ultima_prueba: int = 0


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	for hijo in get_children():
		if hijo is DisparadorEventoPorTiles:
			hijo.evento_activado.connect(_on_disparador)
	var npc := _npc(maestro)
	if npc != null and npc.has_signal("hablado"):
		npc.hablado.connect(_on_maestro_hablado)
	var npc_final := _npc(maestro_final)
	if npc_final != null and npc_final.has_signal("hablado"):
		npc_final.hablado.connect(_on_maestro_final_hablado)
	var cartel := get_node_or_null(cortina)
	if cartel is CartelEvento:
		cartel.accionado.connect(_on_cortina)
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


func _npc(ruta: NodePath) -> Node2D:
	return get_node_or_null(ruta) as Node2D


## Se anula en tests (`con_esperas = false`).
func esperar_fotogramas(fotogramas: int) -> void:
	if con_esperas:
		await super.esperar_fotogramas(fotogramas)


func _fundido_a_negro() -> void:
	if con_esperas:
		await oscurecer_pantalla()


func _fundido_desde_negro() -> void:
	if con_esperas:
		await aclarar_pantalla()


func _sonido(clave: String) -> void:
	Singleton.play_sound.emit(clave)


## ============================================================================
## OnTransition / OnWarp / OnFrame
## ============================================================================

## Mapa cargado: decide la subsala por la celda de llegada y prepara el estado.
func _on_mapa_activado(por_warp: bool) -> void:
	var adm := _administrador()
	var celda := Vector2i.ZERO
	if por_warp and adm != null:
		celda = Vector2i((adm.get("coneccion_posicion") as Vector2).floor())
	elif adm != null and adm.get("jugador") != null:
		celda = Vector2i(adm.jugador.pos_celda_act)
	entrar_en_subsala(HistoriaCasaTreta.subsala_por_celda(celda), celda)


## Equivalente de OnTransition + OnWarp de la sala `sala` (HistoriaCasaTreta.Subsala).
func entrar_en_subsala(sala: int, celda: Vector2i = Vector2i.ZERO) -> void:
	subsala = sala
	celda_llegada = celda
	final_hablado = false
	puerta_final_cerrada = false
	_ocultar_todo()
	match sala:
		HistoriaCasaTreta.Subsala.ENTRADA:
			HistoriaCasaTreta.al_transicion_entrada()
			_colocar_maestro_entrada()
		HistoriaCasaTreta.Subsala.FINAL:
			_preparar_final()
		HistoriaCasaTreta.Subsala.PASILLO:
			HistoriaCasaTreta.al_transicion_pasillo()


func _ocultar_todo() -> void:
	for ruta in [maestro, maestro_final]:
		var npc := _npc(ruta)
		if npc != null:
			npc.visible = false
	var objeto := _npc(pepita)
	if objeto != null:
		objeto.visible = false


## OnWarp de Entrance: dónde está el MAESTRO según ENTRANCE_STATE_3.
func _colocar_maestro_entrada() -> void:
	var npc := _npc(maestro)
	if npc == null:
		return
	if HistoriaCasaTreta.reto_pendiente():  # MoveTrickMasterToDoor + TrickMasterFound
		_poner_maestro(npc, HistoriaCasaTreta.CELDA_MAESTRO_PUERTA, Vector2.RIGHT)
		return
	match HistoriaCasaTreta.estado_maestro():
		HistoriaCasaTreta.EstadoMaestro.ESCONDIDO:  # SetTrickMasterHidingSpot
			var celda := HistoriaCasaTreta.escondite(HistoriaCasaTreta.salas_completadas())
			_poner_maestro(npc, celda, Vector2.DOWN, true)
		HistoriaCasaTreta.EstadoMaestro.PREMIO_PENDIENTE, HistoriaCasaTreta.EstadoMaestro.PENSANDO:
			_poner_maestro(npc, HistoriaCasaTreta.CELDA_MAESTRO_PUERTA, Vector2.UP)  # FacingDoor
		HistoriaCasaTreta.EstadoMaestro.TIENDA_PENDIENTE:
			_poner_maestro(npc, HistoriaCasaTreta.CELDA_MAESTRO_PUERTA, Vector2.DOWN)  # InFrontOfDoor
		_:  # EN_ACERTIJO, FINALIZADO, REGRESO: removeobject
			npc.visible = false


## addobject + setobjectxy + turnobject. `invisible`: hideobjectat (el nodo sigue ocupando
## la celda y respondiendo a A, pero no se ve).
func _poner_maestro(npc: Node2D, celda: Vector2i, mirada: Vector2, invisible: bool = false) -> void:
	npc.visible = true
	npc.tipo_movimiento = NpcBase.TipoMovimientoNPC.INVISIBLE if invisible else _tipo_mirar(mirada)
	colocar(npc, celda)
	if not invisible:
		mirar(npc, mirada)


func _tipo_mirar(direccion: Vector2) -> int:
	var tipos: Dictionary = {
		Vector2.UP: NpcBase.TipoMovimientoNPC.MIRAR_ARRIBA,
		Vector2.DOWN: NpcBase.TipoMovimientoNPC.MIRAR_ABAJO,
		Vector2.LEFT: NpcBase.TipoMovimientoNPC.MIRAR_IZQUIERDA,
		Vector2.RIGHT: NpcBase.TipoMovimientoNPC.MIRAR_DERECHA,
	}
	return tipos.get(direccion, NpcBase.TipoMovimientoNPC.SIN_MOVIMIENTO)


## OnFrame: con el mapa ya en pantalla, las tareas pendientes de cada sala.
func _process(_delta: float) -> void:
	if _en_curso or not _mapa_listo():
		return
	match subsala:
		HistoriaCasaTreta.Subsala.ENTRADA:
			if HistoriaCasaTreta.reto_pendiente():
				presentar_reto_al_cargar()
		HistoriaCasaTreta.Subsala.FINAL:
			if not puerta_final_cerrada:
				cerrar_puerta_final()


func _mapa_listo() -> bool:
	var adm := _administrador()
	var mapa := obtener_mapa()
	if adm == null or mapa == null or adm.get("mapa_actual") != mapa:
		return false
	return int(adm.get("coneccion")) == 0


## `Route110_TrickHouseEnd_EventScript_CloseDoor`: la puerta por la que se llega se cierra
## detrás del jugador (0x21B y sólida).
func cerrar_puerta_final() -> void:
	puerta_final_cerrada = true
	var capa := get_node_or_null(capa_suelo) as TileMapLayer
	if capa != null:
		capa.set_cell(HistoriaCasaTreta.CELDA_PUERTA_FINAL, FUENTE_ATLAS, ATLAS_PUERTA_CERRADA)
	var datos := get_node_or_null(datos_tiles) as TPTileDataMap
	if datos != null:
		datos.set_flag(Vector2(HistoriaCasaTreta.CELDA_PUERTA_FINAL), TPTileDataMap.Flags.BLOQUEO)


## ============================================================================
## ENTRADA: disparadores, destello y MAESTRO
## ============================================================================

func _on_disparador(id_evento: StringName) -> void:
	match id_evento:
		ID_OBSERVA:
			await te_observan()
		ID_SALIDA_FINAL:
			await ignorar_al_maestro()


## `Route110_TrickHouseEntrance_EventScript_TrickMasterHiding`: «Te estoy observando...» y,
## con 0, 1 o 2 salas, el destello sobre el escondite. Solo con ENTRANCE_STATE == 0.
func te_observan() -> void:
	if _en_curso or subsala != HistoriaCasaTreta.Subsala.ENTRADA or HistoriaCasaTreta.entrada_observada() != 0:
		return
	if not comenzar(_administrador()):
		return
	await mensaje(TEXTO_OBSERVANDO)
	terminar()  # releaseall: el jugador queda libre durante el destello
	var nivel := HistoriaCasaTreta.salas_completadas()
	HistoriaCasaTreta.marcar_observado()  # el script en curso impide que se repita
	if HistoriaCasaTreta.hay_destello(nivel):
		await destello(HistoriaCasaTreta.celda_destello(nivel))
		await esperar_fotogramas(10)


## DoHidingSpotSparkle: espera a que termine el efecto (waitfieldeffect).
func destello(celda: Vector2i) -> void:
	var mapa := obtener_mapa()
	if mapa == null:
		return
	ultimo_destello = EfectoDestello.lanzar(mapa, celda)
	if con_esperas:
		await ultimo_destello.terminado


## `Route110_TrickHouseEntrance_EventScript_TrickMaster`: según ENTRANCE_STATE_3.
func _on_maestro_hablado(npc: Node2D) -> void:
	if _en_curso or subsala != HistoriaCasaTreta.Subsala.ENTRADA:
		_liberar_npc(npc)
		return
	match HistoriaCasaTreta.estado_maestro():
		HistoriaCasaTreta.EstadoMaestro.ESCONDIDO:
			await encontrar_maestro(npc)
		HistoriaCasaTreta.EstadoMaestro.PREMIO_PENDIENTE:
			await dar_recompensa_pendiente(npc)
		HistoriaCasaTreta.EstadoMaestro.PENSANDO:
			await seguir_pensando(npc)
		HistoriaCasaTreta.EstadoMaestro.TIENDA_PENDIENTE:
			await dar_tienda_pendiente(npc)
		_:
			_liberar_npc(npc)


func _liberar_npc(npc: Node2D) -> void:
	if is_instance_valid(npc) and npc.get("jugador") != null and npc.jugador.has_method("esperar_dialogo"):
		npc.jugador.esperar_dialogo(false)


## `FoundTrickMaster`: «!» sobre el jugador, el texto del mueble, y «warp» a (6,2) con el
## MAESTRO en (5,2). Se hace en sitio (fundido a negro, recolocar y aclarar) y sigue
## con BeginChallenge. ENTRANCE_STATE_2 queda en 1 hasta que el MAESTRO se va, por si la
## partida se guarda a medias.
func encontrar_maestro(npc: Node2D) -> void:
	if not comenzar(_administrador()):
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	_sonido(SONIDO_PIN)
	await _exclamacion_jugador()
	await esperar_fotogramas(48)  # Common_Movement_Delay48
	await mensaje(HistoriaCasaTreta.clave_hallazgo(HistoriaCasaTreta.salas_completadas()))
	HistoriaCasaTreta.marcar_hallado()
	await _fundido_a_negro()
	_poner_maestro(npc, HistoriaCasaTreta.CELDA_MAESTRO_PUERTA, Vector2.RIGHT)
	colocar_jugador(HistoriaCasaTreta.CELDA_JUGADOR_HALLAZGO, Vector2.LEFT)
	await _fundido_desde_negro()
	await _presentacion(npc)
	terminar(false, [npc])


## `Route110_TrickHouseEntrance_OnFrame`: BeginChallenge con ENTRANCE_STATE_2 == 1 al
## cargar la sala (depuración o partida guardada a medias).
func presentar_reto_al_cargar() -> void:
	var npc := _npc(maestro)
	if npc == null or not HistoriaCasaTreta.reto_pendiente() or not comenzar(_administrador()):
		return
	await _presentacion(npc)
	terminar(false, [npc])


## `Route110_TrickHouseEntrance_EventScript_BeginChallenge`.
func _presentacion(npc: Node2D) -> void:
	await esperar_fotogramas(20)
	if HistoriaCasaTreta.salas_completadas() == 0:
		await mensaje(TEXTO_PRESENTACION)  # MeetTrickMaster
	await mensaje(TEXTO_DESAFIO)
	await esperar_fotogramas(20)
	await _salir_volando(npc)
	HistoriaCasaTreta.terminar_presentacion()  # STATE_3 = 1, STATE_2 = 0


## Movement_TrickMasterSpin + SE_M_EXPLOSION + Movement_TrickMasterJumpAway + removeobject.
func _salir_volando(npc: Node2D) -> void:
	for direccion in [Vector2.UP, Vector2.LEFT, Vector2.DOWN, Vector2.RIGHT]:
		mirar(npc, direccion)
		await esperar_fotogramas(4)  # delay_4
	_sonido(SONIDO_EXPLOSION)
	mirar(npc, Vector2.UP)
	if con_esperas:
		await recorrer(npc, [Vector2.UP, Vector2.UP, Vector2.UP, Vector2.UP, Vector2.UP, Vector2.UP],
				VelocidadPaso.MUY_RAPIDO)  # 6 × slide_up
	npc.visible = false


## `StillMakingPuzzle` (ENTRANCE_STATE_3 == 3).
func seguir_pensando(npc: Node2D) -> void:
	if not comenzar(_administrador()):
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	await mensaje(TEXTO_PROXIMO_TRUCO)
	npc.mirar_jugador()
	_sonido(SONIDO_PIN)
	if con_esperas:
		await exclamacion(npc)
	await esperar_fotogramas(48)
	await mensaje(TEXTO_IDEANDO, false)
	mirar(npc, Vector2.UP)  # Common_Movement_WalkInPlaceFastestUp
	terminar(false, [npc])


## `GiveReward` (ENTRANCE_STATE_3 == 2): la recompensa del nivel que no cupo en el FINAL.
## `salas_completadas()` ya cuenta la sala hecha: el objeto es el del nivel anterior.
func dar_recompensa_pendiente(npc: Node2D) -> void:
	if not comenzar(_administrador()):
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()
	await mensaje(TEXTO_RECOMPENSA)
	var objeto := HistoriaCasaTreta.objeto_premio(HistoriaCasaTreta.salas_completadas() - 1)
	if not objeto.is_empty() and await dar_objeto(npc, objeto):
		HistoriaCasaTreta.recompensa_entregada()  # GotReward
		mirar(npc, Vector2.UP)
	else:
		await mensaje(TEXTO_MOCHILA_LLENA)  # Common_EventScript_BagIsFull
		await mensaje(TEXTO_RECOMPENSA_NO)
	terminar(false, [npc])


## `MechadollReward` (ENTRANCE_STATE_3 == 6): la TIENDA ROJA que no cupo en el PC.
func dar_tienda_pendiente(npc: Node2D) -> void:
	if not comenzar(_administrador()):
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()
	await mensaje(TEXTO_MECA5_TIENDA)
	if await _dar_tienda():
		await mensaje(TEXTO_MECA5_ADIOS)  # ReceivedTent
		await _sacudir(npc)
		await _salir_volando(npc)
		HistoriaCasaTreta.tienda_entregada()
	else:
		await mensaje(TEXTO_DECOR_SIN_SITIO, true, {"{decoracion}": _nombre_tienda()})
		await mensaje(TEXTO_MECA5_PC_LLENO)
	terminar(false, [npc])


## Movement_16309F (MechadollShake): cara izquierda y derecha con delay_2.
func _sacudir(npc: Node2D) -> void:
	for i in 10:
		mirar(npc, Vector2.LEFT if i % 2 == 0 else Vector2.RIGHT)
		await esperar_fotogramas(2)


## Cortina (5,1), bg_event mirando al norte (`Route110_TrickHouseEntrance_EventScript_Door`).
func _on_cortina(_cartel: CartelEvento) -> void:
	if _en_curso or subsala != HistoriaCasaTreta.Subsala.ENTRADA:
		return
	await usar_cortina()


func usar_cortina() -> void:
	var accion := HistoriaCasaTreta.accion_cortina()
	if accion == HistoriaCasaTreta.AccionCortina.NINGUNA or not comenzar(_administrador()):
		return
	match accion:
		HistoriaCasaTreta.AccionCortina.ES_UNA_CORTINA:
			await mensaje(TEXTO_CORTINA)
			terminar()
		HistoriaCasaTreta.AccionCortina.NOTA_VIAJE:
			await mensaje(TEXTO_NOTA)
			terminar()
		HistoriaCasaTreta.AccionCortina.PREGUNTAR_ENTRAR:
			if await preguntar_si_no(TEXTO_AGUJERO):
				await _entrar_en_prueba()
			else:
				terminar()


## `EnterPuzzleRoom`: la cortina se convierte en agujero, el jugador sube y desaparece, y
## `warp` a la prueba `ROOMS_COMPLETED + 1` en (0,21). Rubí elegía por ROOMS_COMPLETED;
## aquí también, pero con el nivel real (no hay otro warp al acertijo 1).
func _entrar_en_prueba() -> void:
	admin.cuadro_dialogo.cerrar()
	var capa := get_node_or_null(capa_suelo) as TileMapLayer
	if capa != null:
		capa.set_cell(HistoriaCasaTreta.CELDA_CORTINA, FUENTE_ATLAS, ATLAS_AGUJERO)
	var datos := get_node_or_null(datos_tiles) as TPTileDataMap
	if datos != null:
		datos.clear_flag(Vector2(HistoriaCasaTreta.CELDA_CORTINA), TPTileDataMap.Flags.BLOQUEO)
	await esperar_fotogramas(20)
	await recorrer_jugador([Vector2.UP])
	ultima_prueba = HistoriaCasaTreta.prueba_siguiente()
	terminar()
	admin.conectar_escalera(ESCENA_PRUEBA % ultima_prueba, LLEGADA_PRUEBA, Vector2.DOWN, false, true)


## ============================================================================
## FINAL
## ============================================================================

## OnTransition + OnWarp de End. El MAESTRO solo está si se llega por la puerta de una
## prueba (celda (29,1)); al volver del pasillo no reaparece (corrección de Rubí).
func _preparar_final() -> void:
	var llega_de_prueba := celda_llegada == HistoriaCasaTreta.CELDA_PUERTA_FINAL
	var npc := _npc(maestro_final)
	if npc != null and llega_de_prueba:
		npc.visible = true
		npc.tipo_movimiento = NpcBase.TipoMovimientoNPC.MIRAR_DERECHA
		colocar(npc, HistoriaCasaTreta.CELDA_MAESTRO_FINAL)
		mirar(npc, Vector2.RIGHT)
	# PEPITA oculta: recogible tras el 8.º acertijo (ResetTrickHouseEndRoomFlag) y mientras
	# el MAESTRO no esté en su celda.
	var objeto := _npc(pepita)
	if objeto != null:
		objeto.visible = HistoriaCasaTreta.terminada() and not (npc != null and npc.visible) \
				and not SistemaGuardado.get_flag("item_" + HistoriaCasaTreta.ID_ITEM_PEPITA)


## `Route110_TrickHouseEnd_EventScript_TrickMaster` (lock + faceplayer).
func _on_maestro_final_hablado(npc: Node2D) -> void:
	if _en_curso or subsala != HistoriaCasaTreta.Subsala.FINAL:
		_liberar_npc(npc)
		return
	await hablar_con_maestro_final(npc)


func hablar_con_maestro_final(npc: Node2D) -> void:
	if not comenzar(_administrador()):
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()
	await mensaje(TEXTO_FIN_LLEGASTE)
	final_hablado = true
	var nivel := HistoriaCasaTreta.salas_completadas()
	if nivel >= HistoriaCasaTreta.NIVEL_MAXIMO - 1:
		await _ultima_prueba(npc)
	else:
		await _premio_de_nivel(npc, nivel)
	terminar(false, [npc])


## CompletedPuzzle1..7: texto del nivel, objeto y «nuevos trucos».
func _premio_de_nivel(npc: Node2D, nivel: int) -> void:
	await mensaje(HistoriaCasaTreta.clave_texto_final(nivel))
	await mensaje(TEXTO_FIN_RECOMPENSA)
	HistoriaCasaTreta.fijar_premio_pendiente(false)
	var objeto := HistoriaCasaTreta.objeto_premio(nivel)
	if objeto.is_empty() or not await dar_objeto(npc, objeto):
		# BagFull: SistemaGuardado.dar_objeto_jugador no modela capacidad de mochila, así
		# que hoy esta rama no se alcanza; queda para cuando exista.
		await mensaje(TEXTO_MOCHILA_LLENA)
		await mensaje(TEXTO_FIN_MOCHILA_LLENA)
		HistoriaCasaTreta.fijar_premio_pendiente(true)
	await mensaje(TEXTO_FIN_NUEVOS_TRUCOS)
	await _irse_del_final(npc)


## CompletedPuzzle8: se vuelve de espaldas, «¿y ahora qué hago?», TIENDA ROJA y se va de
## viaje. La PEPITA oculta pasa a ser recogible.
func _ultima_prueba(npc: Node2D) -> void:
	await mensaje(HistoriaCasaTreta.clave_texto_final(HistoriaCasaTreta.NIVEL_MAXIMO - 1))
	var jugador: Node = admin.get("jugador")
	var hacia: Vector2 = jugador.facing_direction if jugador != null else Vector2.UP
	mirar(npc, hacia)  # VAR_FACING: de espaldas al jugador
	await esperar_fotogramas(30)
	await mensaje(TEXTO_FIN_SIN_IDEAS)
	npc.mirar_jugador()  # Common_Movement_FacePlayer
	await esperar_fotogramas(30)
	await mensaje(TEXTO_FIN_TIENDA)
	HistoriaCasaTreta.fijar_premio_pendiente(false)
	if not await _dar_tienda():
		await mensaje(TEXTO_DECOR_SIN_SITIO, true, {"{decoracion}": _nombre_tienda()})
		await mensaje(TEXTO_FIN_PC_LLENO)
		HistoriaCasaTreta.fijar_premio_pendiente(true)
	await mensaje(TEXTO_FIN_VIAJE)
	await _irse_del_final(npc)
	var objeto := _npc(pepita)
	if objeto != null:
		objeto.visible = not SistemaGuardado.get_flag("item_" + HistoriaCasaTreta.ID_ITEM_PEPITA)


## `TrickMasterExit`: gira, explosión, salta por la pared, desaparece y suma una sala.
func _irse_del_final(npc: Node2D) -> void:
	admin.cuadro_dialogo.cerrar()
	await _salir_volando(npc)
	HistoriaCasaTreta.completar_sala()


## `TrickMasterExitTrigger` (21,2) con VAR_TEMP_2 == 0: no se sale sin hablar con él.
func ignorar_al_maestro() -> void:
	var npc := _npc(maestro_final)
	if _en_curso or subsala != HistoriaCasaTreta.Subsala.FINAL or final_hablado \
			or npc == null or not npc.visible:
		return
	if not comenzar(_administrador()):
		return
	mirar(npc, Vector2.LEFT)
	_sonido(SONIDO_PIN)
	if con_esperas:
		await exclamacion(npc)
	await esperar_fotogramas(20)
	await saltar_en_sitio(npc, Vector2.LEFT)  # jump_in_place_left
	_sonido(SONIDO_EXPLOSION)
	girar_jugador(Vector2.DOWN)
	await mensaje(TEXTO_FIN_IGNORAS)
	admin.cuadro_dialogo.cerrar()
	await recorrer_jugador([Vector2.DOWN])  # KeepPlayerInRoom
	await esperar_fotogramas(4)
	mirar(npc, Vector2.RIGHT)
	terminar()


## ============================================================================
## DECORACIÓN, «!» DEL JUGADOR
## ============================================================================

## `givedecoration DECOR_RED_TENT`. true si cupo (también muestra los mensajes de
## obtención); false si la categoría ADORNOS está llena (único «PC lleno» real).
func _dar_tienda() -> bool:
	var inventario := SistemaGuardado.get_bases_secretas()
	if inventario.agregar_decoracion(HistoriaCasaTreta.DECORACION_TIENDA_ROJA) < 0:
		return false
	var nombre := _nombre_tienda()
	await mensaje(TEXTO_DECOR_OBTENIDA, false, {"{decoracion}": nombre})
	await mensaje(TEXTO_DECOR_ENVIADA_PC, false, {"{decoracion}": nombre})
	return true


func _nombre_tienda() -> String:
	return tr("BASES_DECOR_%03d_NOMBRE" % HistoriaCasaTreta.DECORACION_TIENDA_ROJA)


## Common_Movement_ExclamationMark sobre el jugador (no tiene método propio como los NPC).
func _exclamacion_jugador() -> void:
	if not con_esperas:
		return
	var jugador := admin.get("jugador") as Node2D
	if jugador == null:
		return
	var signo := Sprite2D.new()
	signo.texture = NpcBase.TEXTURA_EXCLAMACION
	signo.z_index = NpcBase.Z_INDEX_EXCLAMACION
	var y_base: float = NpcBase.OFFSETS_TAMANO_SPRITE[NpcBase.TamanoSprite.NORMAL_16X22].y - NpcBase.SEPARACION_EXCLAMACION
	signo.position = Vector2(0, y_base)
	jugador.add_child(signo)
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(signo, "position", Vector2(0, y_base - 10.0), 0.1)
	tween.tween_property(signo, "position", Vector2(0, y_base + 5.0), 0.2)
	tween.tween_interval(0.8)
	await tween.finished
	signo.queue_free()

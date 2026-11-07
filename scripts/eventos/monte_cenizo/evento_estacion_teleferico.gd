## evento_estacion_teleferico.gd
## Guion de las dos estaciones del TELEFÉRICO (pokeruby data/maps/Route112_CableCarStation y MtChimney_CableCarStation, que
## comparten diseño): la recepcionista (objeto 1, BEAUTY) y la escena de llegada. Las celdas de la escena son las de Rubí.
##
## Recepcionista (…_EventScript_15C08C / 15C14B): lock + faceplayer; «El TELEFÉRICO está listo para subir / bajar. ¿Quieres
## montarte?» (SÍ/NO). NO: «Esperamos que vuelvas a utilizar nuestros servicios». SÍ: «Pasa por aquí.»; ella sube dos celdas, da
## un paso al lado de la cabina (7,4 en la RUTA 112, 5,4 en el MONTE CENIZO) y se gira; el jugador sube tres celdas hasta (6,4)
## y espera 16 fotogramas; VAR_CABLE_CAR_STATION_STATE pasa a 1 (sube) o 2 (baja), cuenta GAME_STAT_RODE_CABLE_CAR y arranca el
## viaje (ViajeTeleferico: CableCarWarp + CableCar), que acaba en la otra estación, celda (6,4).
##
## Llegada (MAP_SCRIPT_ON_TRANSITION + MAP_SCRIPT_ON_FRAME_TABLE con VAR_CABLE_CAR_STATION_STATE == 1 en el MONTE CENIZO o 2 en la
## RUTA 112): la recepcionista aparece junto a la cabina (setobjectxyperm 1, 5, 4 / 7, 4, mirando al centro); ya con el mapa
## visible, el jugador baja tres celdas y ella, tras 16 fotogramas, da un paso hacia el centro y baja dos celdas hasta (6,6).
## La variable vuelve a 0.
extends EventoGuionizado
class_name EventoEstacionTeleferico

const MOTIVO_PAUSA: StringName = &"estacion_teleferico"

const TEXTO_SUBIR: String = "TELEFERICO_SUBIR"
const TEXTO_BAJAR: String = "TELEFERICO_BAJAR"
const TEXTO_PASE: String = "TELEFERICO_PASE"
const TEXTO_OTRA_VEZ: String = "TELEFERICO_OTRA_VEZ"

const L := Vector2.LEFT
const R := Vector2.RIGHT
const U := Vector2.UP
const D := Vector2.DOWN

## Celda de llegada del jugador en la otra estación (CableCarWarp: warp -1, x 6, y 4).
const CELDA_ANDEN := Vector2i(6, 4)
## Columna del pasillo de la estación.
const COLUMNA_CENTRAL: int = 6
## Fotogramas de espera de Common_Movement_Delay16 (delay_16).
const ESPERA_ANDEN: int = 16

## La recepcionista (objeto 1).
@export var recepcionista: NodePath = ^"../../NPCs/Recepcionista"
## Sentido del viaje que ofrece ESTA estación: SUBIR en la RUTA 112, BAJAR en el MONTE CENIZO.
@export var sentido: ViajeTeleferico.Sentido = ViajeTeleferico.Sentido.SUBIR
## VAR_CABLE_CAR_STATION_STATE con el que se llega a esta estación: 1 en el MONTE CENIZO, 2 en la RUTA 112.
@export var estado_llegada: int = 1
## Celda junto a la cabina donde espera la recepcionista (5,4 o 7,4).
@export var celda_llegada_recepcionista: Vector2i = Vector2i(5, 4)
## Clave de escena de la otra estación.
@export var estacion_destino: String = ""

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null
## Último viaje lanzado (tests).
var ultimo_viaje: ViajeTeleferico = null
## false evita lanzar el viaje real (tests): solo se deja constancia en `viaje_solicitado`.
var lanzar_viaje: bool = true
var viaje_solicitado: Dictionary = {}


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var npc := _npc()
	if npc != null and npc.has_signal("hablado"):
		npc.hablado.connect(_on_recepcionista)
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


func _npc() -> Node2D:
	return get_node_or_null(recepcionista) as Node2D


## Lado de la cabina en el que se coloca la recepcionista: derecha (7,4) o izquierda (5,4) del pasillo.
func _lado_cabina() -> Vector2:
	return R if celda_llegada_recepcionista.x > COLUMNA_CENTRAL else L


## ============================================================================
## LLEGADA (ON_TRANSITION + ON_FRAME)
## ============================================================================

func _on_mapa_activado(_por_warp: bool) -> void:
	if not llegada_pendiente() or _en_curso:
		return
	preparar_llegada()
	# Mientras dura el fundido nadie mueve al jugador (el AdministradorMapa le devuelve el control al aclarar).
	Singleton.mantener_pausa(MOTIVO_PAUSA, true)
	var adm := _administrador()
	await esperar_fin_warp(adm)
	await escena_llegada(adm)


func llegada_pendiente() -> bool:
	return HistoriaMonteCenizo.estado_estacion() == estado_llegada


## MAP_SCRIPT_ON_TRANSITION: setobjectxyperm 1, 5, 4 (o 7, 4) + setobjectmovementtype (FACE_RIGHT / FACE_LEFT).
func preparar_llegada() -> void:
	var npc := _npc()
	if npc == null:
		return
	colocar(npc, celda_llegada_recepcionista)
	mirar(npc, -_lado_cabina())


## MAP_SCRIPT_ON_FRAME_TABLE: baja el jugador y vuelve la recepcionista a su sitio.
func escena_llegada(adm: Node) -> void:
	if not comenzar(adm):  # lockall
		Singleton.mantener_pausa(MOTIVO_PAUSA, false)
		return
	var npc := _npc()
	var tareas: Array[Callable] = [_jugador_sale_del_anden]
	if npc != null:
		tareas.append(_recepcionista_vuelve.bind(npc))
	await en_paralelo(tareas)
	HistoriaMonteCenizo.fijar_estado_estacion(0)  # setvar VAR_CABLE_CAR_STATION_STATE, 0
	if npc != null:
		mirar(npc, D)  # setobjectxyperm 1, 6, 7 + setobjectmovementtype 1, 8 (FACE_DOWN)
	terminar(false, [npc] if npc != null else [])


## MtChimney_CableCarStation_Movement_15C1B4 / Route112_CableCarStation_Movement_15C0F5: walk_down x3 + delay_16.
func _jugador_sale_del_anden() -> void:
	await recorrer_jugador([D, D, D])
	await esperar_fotogramas(ESPERA_ANDEN)


## …_Movement_15C1AA / 15C0EB: delay_16, un paso hacia el centro y walk_down x2.
func _recepcionista_vuelve(npc: Node2D) -> void:
	await esperar_fotogramas(ESPERA_ANDEN)
	await recorrer(npc, [-_lado_cabina(), D, D])


## ============================================================================
## RECEPCIONISTA (…_EventScript_15C08C / 15C14B)
## ============================================================================

func _on_recepcionista(npc: Node2D) -> void:
	var adm: Node = npc.nodo_administrador if npc.nodo_administrador != null else _administrador()
	if _en_curso or not comenzar(adm):
		if not _en_curso and npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()  # faceplayer
	await embarcar(npc, adm)


## Todo el guion hasta lanzar el viaje (o rechazarlo).
func embarcar(npc: Node2D, adm: Node) -> void:
	var subiendo := sentido == ViajeTeleferico.Sentido.SUBIR
	if not await preguntar_si_no(TEXTO_SUBIR if subiendo else TEXTO_BAJAR):
		await mensaje(TEXTO_OTRA_VEZ)
		terminar(false, [npc])
		return
	await mensaje(TEXTO_PASE)
	admin.cuadro_dialogo.cerrar()  # closemessage
	await en_paralelo([_recepcionista_embarca.bind(npc), _jugador_embarca])
	SistemaGuardado.incrementar_contador(HistoriaMonteCenizo.CONTADOR_VIAJES)  # incrementgamestat GAME_STAT_RODE_CABLE_CAR
	# VAR_CABLE_CAR_STATION_STATE: la estación de destino lo lee al llegar (1 en el MONTE CENIZO, 2 en la RUTA 112).
	HistoriaMonteCenizo.fijar_estado_estacion(1 if subiendo else 2)
	viaje_solicitado = {"sentido": sentido, "destino": estacion_destino, "celda": CELDA_ANDEN}
	if lanzar_viaje:
		ultimo_viaje = ViajeTeleferico.iniciar(adm, sentido, estacion_destino, CELDA_ANDEN)  # CableCarWarp + CableCar
	terminar(false, [npc])


## …_Movement_15C0E6 / 15C1A5: walk_up x2, un paso al lado y walk_in_place_fastest hacia el pasillo.
func _recepcionista_embarca(npc: Node2D) -> void:
	await recorrer(npc, [U, U, _lado_cabina()])
	mirar(npc, -_lado_cabina())


## …_Movement_15C0F0 / 15C1AF: walk_up x3 + delay_16.
func _jugador_embarca() -> void:
	await recorrer_jugador([U, U, U])
	await esperar_fotogramas(ESPERA_ANDEN)

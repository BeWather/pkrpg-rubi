## evento_safari_zona.gd
## Guiones de la ZONA SAFARI SE (pokeruby data/maps/SafariZone_Southeast/scripts.inc), la que tiene la
## puerta de salida (32,33) y al CAMPISTA que la vigila (objeto 1, (32,34)).
##
## ON_TRANSITION (SafariZone_Southeast_MapScript1): con VAR_SAFARI_ZONE_STATE = 2 (el jugador acaba
##   de pagar) el CAMPISTA aparece apartado en (31,34); en cualquier otro caso está en (32,34), tapando
##   la puerta. Se reevalúa cada vez que la zona pasa a ser el mapa actual, como la recarga de Rubí.
## ON_FRAME con el estado 2 (EventScript_16004B): el jugador baja un paso y el CAMPISTA, que no
##   puede avanzar porque la celda está ocupada, solo mira abajo; el estado vuelve a 0.
## CAMPISTA (EventScript_1600A7): la primera vez que se le habla tras cargar la zona (VAR_TEMP_1 = 0)
##   solo desea suerte; después ofrece salir: SÍ → se aparta, el jugador sube hasta la puerta, se
##   ejecuta ExitSafariMode con VAR_SAFARI_ZONE_STATE = 1 y warp a la ENTRADA (2,5). El CAMPISTA se
##   aparta a la izquierda si el jugador le habla desde el sur (VAR_FACING 2) y hacia abajo si le habla
##   desde el oeste (VAR_FACING 4), que son las dos únicas celdas desde las que se le llega.
extends EventoGuionizado
class_name EventoSafariZona

const MOTIVO_PAUSA: StringName = &"safari_zona"

## Celdas del CAMPISTA: la de siempre y la de aparcado mientras entra el jugador.
const CELDA_CAMPISTA := Vector2i(32, 34)
const CELDA_CAMPISTA_APARTADO := Vector2i(31, 34)
## VAR_TEMP_1 (una variable temporal de Rubí = bandera temporal aquí).
const BANDERA_SALUDADO: String = "safari_campista_saludado"
## warpdoor MAP_ROUTE121_SAFARI_ZONE_ENTRANCE, 255, 2, 5.
const MAPA_ENTRADA: String = "zona_safari_entrada"
const CELDA_ENTRADA := Vector2(2, 5)

const TEXTO_SUERTE: String = "SAFARI_SE_CAMPISTA_SUERTE"
const TEXTO_SALIR: String = "SAFARI_SE_CAMPISTA_SALIR"
const TEXTO_SIGUE: String = "SAFARI_SE_CAMPISTA_SIGUE"
const TEXTO_ADIOS: String = "SAFARI_SE_CAMPISTA_ADIOS"

@export var campista: NodePath

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var npc := get_node_or_null(campista)
	if npc != null and npc.has_signal("hablado"):
		npc.hablado.connect(_on_campista)
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


func _npc() -> Node2D:
	return get_node_or_null(campista) as Node2D


## ============================================================================
## LLEGADA (ON_TRANSITION + ON_FRAME)
## ============================================================================

func _on_mapa_activado(_por_warp: bool) -> void:
	if _en_curso:
		return
	var entrando := SesionSafari.estado_zona() == SesionSafari.Estado.ENTRANDO
	preparar(entrando)
	if not entrando:
		return
	Singleton.mantener_pausa(MOTIVO_PAUSA, true)
	var adm := _administrador()
	await esperar_fin_warp(adm)
	await escena_entrada(adm)


## MAP_SCRIPT_ON_TRANSITION: setobjectxyperm 1, 31, 34 (solo con el estado 2).
func preparar(entrando: bool) -> void:
	var npc := _npc()
	if npc == null:
		return
	colocar(npc, CELDA_CAMPISTA_APARTADO if entrando else CELDA_CAMPISTA)
	mirar(npc, Vector2.DOWN)


## EventScript_16004B.
func escena_entrada(adm: Node) -> void:
	if not comenzar(adm):  # lockall
		Singleton.mantener_pausa(MOTIVO_PAUSA, false)
		return
	SistemaGuardado.set_flag_temporal(BANDERA_SALUDADO, false)  # setvar VAR_TEMP_1, 0
	await recorrer_jugador([Vector2.DOWN])
	var npc := _npc()
	if npc != null:
		mirar(npc, Vector2.DOWN)  # walk_right bloqueado por el jugador + walk_in_place_fastest_down
	SesionSafari.fijar_estado_zona(SesionSafari.Estado.NORMAL)
	terminar()


## ============================================================================
## CAMPISTA (EventScript_1600A7)
## ============================================================================

func _on_campista(npc: Node2D) -> void:
	var administrador_npc: Node = npc.nodo_administrador if npc.nodo_administrador != null else _administrador()
	if _en_curso or not comenzar(administrador_npc):  # lock
		if not _en_curso and npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	var mirada: Vector2 = admin.jugador.facing_direction  # VAR_FACING
	npc.mirar_jugador()  # faceplayer
	if not SistemaGuardado.get_flag_temporal(BANDERA_SALUDADO):
		SistemaGuardado.set_flag_temporal(BANDERA_SALUDADO, true)
		await mensaje(TEXTO_SUERTE)
		terminar(false, [npc])
		return
	if not await preguntar_si_no(TEXTO_SALIR):
		await mensaje(TEXTO_SIGUE)
		terminar(false, [npc])
		return
	await mensaje(TEXTO_ADIOS)
	admin.cuadro_dialogo.cerrar()  # closemessage
	await salir_por_la_puerta(npc, mirada)


## Se aparta, el jugador queda en (32,34), cierra la partida y cruza la puerta hacia la ENTRADA.
func salir_por_la_puerta(npc: Node2D, mirada: Vector2) -> void:
	if mirada == Vector2.RIGHT:
		await caminar(npc, Vector2.DOWN, VelocidadPaso.NORMAL, Vector2.UP)  # walk_down + face up
		await recorrer_jugador([Vector2.RIGHT])
		girar_jugador(Vector2.UP)
	else:
		await caminar(npc, Vector2.LEFT, VelocidadPaso.NORMAL, Vector2.RIGHT)  # walk_left + face right
		await recorrer_jugador([Vector2.UP])
	# EventScript_160139: VAR_SAFARI_ZONE_STATE = 1, ExitSafariMode y warpdoor.
	SesionSafari.fijar_estado_zona(SesionSafari.Estado.TERMINADA)
	SesionSafari.salir()
	await recorrer_jugador([Vector2.UP])  # entra por la puerta (32,33)
	var adm := admin
	terminar(false, [npc])
	adm.conectar_escalera(MAPA_ENTRADA, CELDA_ENTRADA, Vector2.UP)

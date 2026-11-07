## evento_safari_entrada.gd
## Guiones de la ENTRADA DE LA ZONA SAFARI (pokeruby data/maps/Route121_SafariZoneEntrance/scripts.inc):
##
## TAQUILLA (coord_event (8,4) con VAR_TEMP_1 = 0, EventScript_15C383): el pasillo hacia la zona se
##   cruza por una sola celda, así que todos los pasos del jugador pasan por el disparador. Pregunta
##   «¿Quieres jugar una partida SAFARI?» (500$, con el recuadro del dinero); NO o cualquier fallo le
##   empuja un paso a la derecha (walk_right) y puede volver a intentarlo. Con SÍ, las comprobaciones
##   van en este orden: TUBO de POKéCUBOS (si no lleva uno, se niega), PC lleno (equipo de 6 y ninguna
##   caja libre) y dinero. Si todo va bien cobra, entrega las 30 SAFARI BALLS («{PN} recibió 30 SAFARI
##   BALLS.» con la fanfarria de objeto), el jugador camina 6 pasos a la izquierda y 1 abajo, se
##   ejecuta EnterSafariMode (30 BALLS, 500 pasos), VAR_SAFARI_ZONE_STATE = 2 y warp a la ZONA SE (32,33).
## RECEPCIONISTA (objeto 2, (10,2)): «¿Es la primera vez que vienes?»: SÍ explica las reglas, NO solo
##   da la bienvenida. Los demás objetos (el de la ventanilla (17,9) y el CAMPISTA mudo (8,2)) son NPC
##   normales.
## VUELTA (MAP_SCRIPT_ON_FRAME con VAR_SAFARI_ZONE_STATE = 1, EventScript_15C333): al llegar tras el
##   final de la partida el jugador sube un paso y recorre 7 a la derecha, se ejecuta ExitSafariMode y
##   el estado vuelve a 0.
##
## Añadido a Rubí por seguridad: si el jugador llega a la ENTRADA con la partida SAFARI aún activa y el
## estado no es 1 (por la puerta de la ZONA SE antes de que el CAMPISTA se coloque), la partida se
## cierra sin avisos en vez de dejar un modo SAFARI colgado que la taquilla volvería a cobrar.
extends EventoGuionizado
class_name EventoSafariEntrada

const MOTIVO_PAUSA: StringName = &"safari_entrada"

## ITEM_POKEBLOCK_CASE (la CAJA POKéCUBOS del proyecto; el texto de la ROM dice «TUBO»).
const OBJETO_ESTUCHE: String = "CAJAPOKECUBOS"
## Route121_SafariZoneEntrance_Movement_15C47E: walk_left x6, walk_down y delay_16.
const RECORRIDO_A_LA_ZONA: Array = [Vector2.LEFT, Vector2.LEFT, Vector2.LEFT, Vector2.LEFT, Vector2.LEFT, Vector2.LEFT, Vector2.DOWN]
const FOTOGRAMAS_DELAY_16: int = 16
## ..._Movement_15C348: walk_up y walk_right x7.
const RECORRIDO_TRAS_LA_PARTIDA: Array = [Vector2.UP, Vector2.RIGHT, Vector2.RIGHT, Vector2.RIGHT, Vector2.RIGHT, Vector2.RIGHT, Vector2.RIGHT, Vector2.RIGHT]
## warp MAP_SAFARI_ZONE_SOUTHEAST, 255, 32, 33.
const MAPA_ZONA: String = "zona_safari_4"
const CELDA_ZONA := Vector2(32, 33)
const ID_TAQUILLA: StringName = &"taquilla"

const T := "SAFARI_TAQUILLA_"
const TEXTO_OFERTA: String = T + "OFERTA"
const TEXTO_RECHAZO: String = T + "RECHAZO"
const TEXTO_SIN_DINERO: String = T + "SIN_DINERO"
const TEXTO_COBRO: String = T + "COBRO"
const TEXTO_BALLS: String = T + "BALLS"
const TEXTO_RECIBIDO: String = T + "RECIBIDO"
const TEXTO_DESPEDIDA: String = T + "DESPEDIDA"
const TEXTO_PC_LLENO: String = T + "PC_LLENO"
const TEXTO_SIN_TUBO: String = T + "SIN_TUBO"
const TEXTO_PRIMERA_VEZ: String = "SAFARI_ENTRADA_PRIMERA_VEZ"
const TEXTO_REGLAS: String = "SAFARI_ENTRADA_REGLAS"
const TEXTO_VEN: String = "SAFARI_ENTRADA_VEN"

## La recepcionista (objeto 2).
@export var recepcionista: NodePath

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for hijo in get_children():
		if hijo is DisparadorEventoPorTiles:
			hijo.evento_activado.connect(_on_disparador)
	var npc := get_node_or_null(recepcionista)
	if npc != null and npc.has_signal("hablado"):
		npc.hablado.connect(_on_recepcionista)
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


## ============================================================================
## TAQUILLA
## ============================================================================

func _on_disparador(id_evento: StringName) -> void:
	# Con la partida SAFARI activa no se vende otra entrada (no se cobra dos veces).
	if id_evento != ID_TAQUILLA or _en_curso or SesionSafari.activa():
		return
	vender_entrada()


## Route121_SafariZoneEntrance_EventScript_15C383. Devuelve true si el jugador entra en la zona.
func vender_entrada() -> bool:
	if not comenzar(_administrador()):  # lockall
		return false
	girar_jugador(Vector2.UP)  # Common_Movement_WalkInPlaceFastestUp
	mostrar_cuadro_dinero()  # showmoneybox
	if not await preguntar_si_no(TEXTO_OFERTA):
		await mensaje(TEXTO_RECHAZO)
		await _echar_al_jugador()
		return false
	if not _tiene_estuche():  # checkitem ITEM_POKEBLOCK_CASE
		await mensaje(TEXTO_SIN_TUBO)
		await _echar_al_jugador()
		return false
	if SistemaGuardado.almacenamiento_lleno():  # getpartysize + CheckFreePokemonStorageSpace
		await mensaje(TEXTO_PC_LLENO)
		await _echar_al_jugador()
		return false
	if SistemaGuardado.get_dinero_jugador() < SesionSafari.PRECIO_ENTRADA:  # checkmoney 500
		await mensaje(TEXTO_SIN_DINERO)
		await _echar_al_jugador()
		return false
	await mensaje(TEXTO_COBRO)
	SistemaGuardado.quitar_dinero_jugador(SesionSafari.PRECIO_ENTRADA)  # removemoney + updatemoneybox
	actualizar_cuadro_dinero()
	await mensaje(TEXTO_BALLS)
	await mensaje_con_fanfarria(TEXTO_RECIBIDO)  # playfanfare MUS_OBTAIN_ITEM + message
	await mensaje(TEXTO_DESPEDIDA)
	admin.cuadro_dialogo.cerrar()  # closemessage
	ocultar_cuadro_dinero()  # hidemoneybox
	await recorrer_jugador(RECORRIDO_A_LA_ZONA)
	await esperar_fotogramas(FOTOGRAMAS_DELAY_16)
	SesionSafari.entrar()  # special EnterSafariMode
	SesionSafari.fijar_estado_zona(SesionSafari.Estado.ENTRANDO)  # setvar VAR_SAFARI_ZONE_STATE, 2
	var adm := admin
	terminar()
	adm.conectar_escalera(MAPA_ZONA, CELDA_ZONA, Vector2.DOWN)  # warp, sin puerta
	return true


func _tiene_estuche() -> bool:
	var datos: Dictionary = SistemaGuardado.obtener_datos_objeto_completos(OBJETO_ESTUCHE)
	return SistemaGuardado.tiene_objeto(OBJETO_ESTUCHE, 1, int(datos.get("bolsillo_id", 0)))


## Route121_SafariZoneEntrance_EventScript_15C46C: closemessage + hidemoneybox + walk_right + releaseall.
func _echar_al_jugador() -> void:
	admin.cuadro_dialogo.cerrar()
	ocultar_cuadro_dinero()
	await recorrer_jugador([Vector2.RIGHT])
	terminar()


## ============================================================================
## RECEPCIONISTA (EventScript_15C35A)
## ============================================================================

func _on_recepcionista(npc: Node2D) -> void:
	var administrador_npc: Node = npc.nodo_administrador if npc.nodo_administrador != null else _administrador()
	if _en_curso or not comenzar(administrador_npc):  # lock
		if not _en_curso and npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()  # faceplayer
	if await preguntar_si_no(TEXTO_PRIMERA_VEZ):
		await mensaje(TEXTO_REGLAS)
	else:
		await mensaje(TEXTO_VEN)
	terminar(false, [npc])


## ============================================================================
## VUELTA (ON_FRAME con VAR_SAFARI_ZONE_STATE = 1)
## ============================================================================

func _on_mapa_activado(_por_warp: bool) -> void:
	if _en_curso:
		return
	if SesionSafari.estado_zona() == SesionSafari.Estado.TERMINADA:
		# Mientras dura el fundido nadie mueve al jugador.
		Singleton.mantener_pausa(MOTIVO_PAUSA, true)
		var adm := _administrador()
		await esperar_fin_warp(adm)
		await escena_vuelta(adm)
	elif SesionSafari.activa():
		SesionSafari.salir()  # ver la nota de la cabecera


## EventScript_15C333: lockall, walk_up + walk_right x7, ExitSafariMode, VAR_SAFARI_ZONE_STATE = 0.
func escena_vuelta(adm: Node) -> void:
	if not comenzar(adm):
		Singleton.mantener_pausa(MOTIVO_PAUSA, false)
		return
	await recorrer_jugador(RECORRIDO_TRAS_LA_PARTIDA)
	SesionSafari.salir()
	SesionSafari.fijar_estado_zona(SesionSafari.Estado.NORMAL)
	terminar()

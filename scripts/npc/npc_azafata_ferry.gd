@tool
## npc_azafata_ferry.gd
## Azafata del ferry S.S. MAREA: PUERTO de CIUDAD PORTUAL (pokeruby SlateportCity_Harbor_EventScript_FerryAttendant),
## PUERTO de CIUDAD CALAGUA (LilycoveCity_Harbor_EventScript_FerryAttendant) y exterior de la TORRE BATALLA
## (BattleTower_Outside_EventScript_160168). lock + faceplayer en las tres. Los textos de los puertos son los mismos y
## cambian los destinos del menú (`destino_1_*`, `destino_2_*`).
## - Puertos (`requiere_juego_completado`): sin SYS_GAME_CLEAR, «el servicio de ferry todavía no está en
##   funcionamiento». La TORRE BATALLA no lo comprueba.
## - Pide el TICKET (ITEM_SS_TICKET). Sin él, «necesitas un TICKET».
## - Con él: «¿Adónde te gustaría ir?» y el menú destino 1 / destino 2 / SALIR (multichoicedefault; cancelar = SALIR).
##   Cada destino pide confirmación SÍ/NO: con NO vuelve a preguntar (`texto_otro_destino`); con SÍ, «Sube a bordo…».
## - Embarque: la azafata mira arriba (puertos) o abajo
##   (TORRE BATALLA, `embarque_isla`), delay 30 y se aparta; el jugador sube a bordo
##   (LilycoveCity_Harbor_Movement_PlayerBoardFerryNorth/East en los puertos, Common_EventScript_FerryDepartIsland
##   en la TORRE: un paso al sur, o al oeste y mira al sur), delay 30 y se oculta; el barco (`barco`, BarcoFerry) zarpa
##   (Common_EventScript_FerryDepart) y warp: entre PORTUAL y CALAGUA, al pasillo del barco (1,10) con el viaje de
##   CruceroSSMarea; el resto, al destino de DESTINOS_FERRY: los puertos llegan a (8,11) y la TORRE BATALLA a (19,23).
## - Un destino sin entrada en DESTINOS_FERRY solo emite `embarque_solicitado(destino)`.
## Bloqueo del jugador y diálogo: patrón de npc_dialogo_condicional.gd.
extends "res://scripts/npc/npc_dialogo_condicional.gd"

const TEXTO_NO_DISPONIBLE: String = "PORTUAL_PUERTO_AZAFATA_NO_DISPONIBLE"
const TEXTO_BILLETE: String = "PORTUAL_PUERTO_AZAFATA_BILLETE"
const TEXTO_SIN_BILLETE: String = "PORTUAL_PUERTO_AZAFATA_SIN_BILLETE"
const TEXTO_DESTINO: String = "PORTUAL_PUERTO_AZAFATA_DESTINO"
const TEXTO_OTRO_DESTINO: String = "PORTUAL_PUERTO_AZAFATA_OTRO_DESTINO"
const TEXTO_EMBARCAR: String = "PORTUAL_PUERTO_AZAFATA_EMBARCAR"
const TEXTO_OTRA_VEZ: String = "PORTUAL_PUERTO_AZAFATA_OTRA_VEZ"
const OPCION_TORRE: String = "PORTUAL_PUERTO_OPCION_TORRE"
const OPCION_SALIR: String = "PORTUAL_PUERTO_OPCION_SALIR"

## ITEM_SS_TICKET (en la ROM española «TICKET BARCO»).
const OBJETO_BILLETE: String = "TICKETBARCO"
const BANDERA_LIGA: String = "SYS_GAME_CLEAR"

const TEXTO_TORRE: String = "PORTUAL_PUERTO_AZAFATA_TORRE"

## Identificador del destino -> [escena, celda de llegada, dirección de llegada].
const DESTINOS_FERRY: Dictionary = {
	"CIUDAD_CALAGUA": ["ciudad_calagua_puerto", Vector2(8, 11), Vector2.DOWN],
	"CIUDAD_PORTUAL": ["ciudad_portual_puerto", Vector2(8, 11), Vector2.DOWN],
	"TORRE_BATALLA": ["torre_batalla_exterior", Vector2(19, 23), Vector2.UP],
	"ISLA_SUR": ["isla_del_sur_exterior", Vector2(13, 22), Vector2.UP],
}

## Primer destino del menú: etiqueta del menú, texto de confirmación e identificador del destino
## ("CIUDAD_CALAGUA" para PORTUAL; "CIUDAD_PORTUAL" para la azafata de CALAGUA y la de la TORRE).
@export var destino_1_opcion: String = "PORTUAL_PUERTO_OPCION_CALAGUA"
@export var destino_1_confirmar: String = "PORTUAL_PUERTO_AZAFATA_CALAGUA"
@export var destino_1_id: String = "CIUDAD_CALAGUA"

## Solo la azafata de CALAGUA (LilycoveCity_Harbor_EventScript_FerryAttendant: checkitem ITEM_EON_TICKET): con el
## TICKET EÓN, SYS_GAME_CLEAR, FLAG_SYS_HAS_EON_TICKET y sin haber encontrado aún a LATIAS, «Ese TICKET...», se aparta
## (walk_in_place_fastest_up + hideobjectat), aparece el MARINERO del S.S. MAREA (`marinero_ticket_eon`, objeto 4),
## lo explica y se va; el jugador sube a bordo, se cura el equipo, zarpa el barco y warp a la ISLA SUR (13,22). En
## cualquier otro caso, el guion normal.
@export var ruta_ticket_eon: bool = false
@export var marinero_ticket_eon: NodePath
## S.S. MAREA del mapa (BarcoFerry): zarpa antes del warp.
@export var barco: NodePath
## Los puertos solo atienden con SYS_GAME_CLEAR; la TORRE BATALLA, siempre.
@export var requiere_juego_completado: bool = true
## Segundo destino del menú (por defecto la TORRE BATALLA de los puertos).
@export var destino_2_opcion: String = OPCION_TORRE
@export var destino_2_confirmar: String = TEXTO_TORRE
@export var destino_2_id: String = "TORRE_BATALLA"
## Pregunta tras contestar NO a un destino (ChooseNewDestination).
@export var texto_otro_destino: String = TEXTO_OTRO_DESTINO
## Embarque de Common_EventScript_FerryDepartIsland (TORRE BATALLA): la azafata mira abajo y el jugador va al sur.
@export var embarque_isla: bool = false

const OBJETO_TICKET_EON: String = "TICKETEON"
const BANDERA_TICKET_EON: String = "SYS_HAS_EON_TICKET"
const BANDERA_LATIAS_ENCONTRADA: String = "isla_sur_latias_encontrada"
const TEXTO_TICKET_EON: String = "ISLA_SUR_AZAFATA_TICKET_EON"
const TEXTO_MARINERO_TICKET_EON: String = "ISLA_SUR_MARINERO_TICKET_EON"
const DESTINO_ISLA_SUR: String = "ISLA_SUR"

## Destino confirmado que no está en DESTINOS_FERRY (nadie lo escucha por ahora).
signal embarque_solicitado(destino: String)

## La azafata se apartó para el embarque: vuelve a su sitio cuando el mapa se activa de nuevo.
var _apartada: bool = false


func _on_mapa_activado(por_warp: bool) -> void:
	super._on_mapa_activado(por_warp)
	if _apartada:
		_apartada = false
		visible = true


func _procesar_interaccion() -> void:
	interrupcion_pendiente = false
	if _secuencia_activa:
		return
	if nodo_administrador == null or nodo_administrador.cuadro_dialogo == null:
		if jugador and jugador.has_method("esperar_dialogo"):
			jugador.esperar_dialogo(false)
		cambiar_estado(EstadoNPC.IDLE)
		return
	_conversar()


func _conversar() -> void:
	_secuencia_activa = true
	cambiar_estado(EstadoNPC.INTERACTING)
	mirar_jugador()  # faceplayer
	_bloquear_jugador(true)
	var destino := await _guion()
	nodo_administrador.cuadro_dialogo.cerrar()
	if _viaja_a_bordo(destino):
		CruceroSSMarea.embarcar(destino == "CIUDAD_CALAGUA")  # setvar VAR_PORTHOLE_STATE
		nodo_administrador.conectar_escalera(CruceroSSMarea.MAPA_PASILLO, Vector2(CruceroSSMarea.CELDA_EMBARQUE), Vector2.DOWN)
		destino = ""
	elif DESTINOS_FERRY.has(destino):
		var datos: Array = DESTINOS_FERRY[destino]
		nodo_administrador.conectar_escalera(str(datos[0]), datos[1], datos[2])
		destino = ""
	_bloquear_jugador(false)
	if not _apartada:
		_volver_a_direccion_base()
	_secuencia_activa = false
	cambiar_estado(EstadoNPC.IDLE)
	if not destino.is_empty():
		embarque_solicitado.emit(destino)


## Solo el viaje entre los dos puertos pasa por el interior del barco; desde la TORRE BATALLA se va directo.
func _viaja_a_bordo(destino: String) -> bool:
	return not embarque_isla and (destino == "CIUDAD_CALAGUA" or destino == "CIUDAD_PORTUAL")


## Devuelve el destino confirmado (ya embarcado si está en DESTINOS_FERRY) o "" si no se embarca.
func _guion() -> String:
	if ruta_ticket_eon and puede_ir_a_isla_sur():
		return await _guion_ticket_eon()
	if requiere_juego_completado and not SistemaGuardado.get_flag(BANDERA_LIGA):
		await _mensaje(TEXTO_NO_DISPONIBLE)
		return ""
	await _mensaje(TEXTO_BILLETE)
	if _cantidad_billetes() < 1:
		await _mensaje(TEXTO_SIN_BILLETE)  # NoTicket
		return ""
	var pregunta := TEXTO_DESTINO  # FlashedTicketWhereTo
	var opciones := PackedStringArray([tr(destino_1_opcion), tr(destino_2_opcion), tr(OPCION_SALIR)])
	# (texto de confirmación, destino) en el orden del menú.
	var destinos := [[destino_1_confirmar, destino_1_id], [destino_2_confirmar, destino_2_id]]
	while true:
		var eleccion := await _elegir_opcion(pregunta, opciones)
		if eleccion >= destinos.size():
			await _mensaje(TEXTO_OTRA_VEZ)  # CancelDestinationSelect
			return ""
		if await _preguntar_si_no(destinos[eleccion][0]):
			await _mensaje(TEXTO_EMBARCAR)  # BoardFerry
			var destino: String = destinos[eleccion][1]
			if DESTINOS_FERRY.has(destino):
				await _embarcar()
			return destino
		pregunta = texto_otro_destino  # ChooseNewDestination
	return ""


## LilycoveCity_Harbor_EventScript_BoardFerry / BattleTower_Outside_EventScript_160232.
func _embarcar() -> void:
	nodo_administrador.cuadro_dialogo.cerrar()
	update_direction(Vector2.DOWN if embarque_isla else Vector2.UP)
	await _esperar_fotogramas(30)
	_apartarse()
	await _subir_a_bordo()
	await _zarpar()


func _apartarse() -> void:
	visible = false  # hideobjectat VAR_LAST_TALKED
	_apartada = true


## LilycoveCity_Harbor_EventScript_FerryAttendantLocationAndBoarding: requisitos.
static func puede_ir_a_isla_sur() -> bool:
	var bolsillo := int(SistemaGuardado.obtener_datos_objeto_completos(OBJETO_TICKET_EON).get("bolsillo_id", 0))
	return SistemaGuardado.tiene_objeto(OBJETO_TICKET_EON, 1, bolsillo) and SistemaGuardado.get_flag(BANDERA_LIGA) \
			and SistemaGuardado.get_flag(BANDERA_TICKET_EON) and not SistemaGuardado.get_flag(BANDERA_LATIAS_ENCONTRADA)


## LilycoveCity_Harbor_EventScript_FerryAttendantLocationAndBoarding.
func _guion_ticket_eon() -> String:
	await _mensaje(TEXTO_TICKET_EON)
	nodo_administrador.cuadro_dialogo.cerrar()
	update_direction(Vector2.UP)
	await _esperar_fotogramas(30)
	_apartarse()
	await _esperar_fotogramas(60)
	var marinero := get_node_or_null(marinero_ticket_eon) as Node2D
	if marinero != null:
		marinero.visible = true  # addobject 4
		await _esperar_fotogramas(30)
		if marinero.has_method("mirar_jugador"):
			marinero.mirar_jugador()
		await _mensaje(TEXTO_MARINERO_TICKET_EON)
		nodo_administrador.cuadro_dialogo.cerrar()
		if marinero.has_method("update_direction"):
			marinero.update_direction(Vector2.UP)
		await _esperar_fotogramas(30)
		marinero.visible = false  # removeobject 4
	await _subir_a_bordo()
	SistemaGuardado.curar_equipo_completo()  # special ScrSpecial_HealPlayerParty
	await _zarpar()
	return DESTINO_ISLA_SUR


## Puertos: LilycoveCity_Harbor_EventScript_PlayerBoardFerryNorth / East (según hacia dónde mira el jugador al hablar).
## TORRE BATALLA (`embarque_isla`): Ferry_EventScript_DepartIslandSouth / West. Después, delay 30 y hideobjectat
## LOCALID_PLAYER; el warp siguiente vuelve a mostrar al jugador.
func _subir_a_bordo() -> void:
	if jugador == null or not jugador.has_method("caminar_guion"):
		return
	var mirada: Vector2 = jugador.get("facing_direction")
	if embarque_isla:
		if mirada == Vector2.DOWN:
			await jugador.caminar_guion(Vector2.DOWN)
		elif mirada == Vector2.LEFT:
			await jugador.caminar_guion(Vector2.LEFT)
			jugador.set("facing_direction", Vector2.DOWN)  # walk_in_place_fastest_down
	elif mirada == Vector2.UP:
		await jugador.caminar_guion(Vector2.UP)
	elif mirada == Vector2.RIGHT:
		await jugador.caminar_guion(Vector2.RIGHT)
		jugador.set("facing_direction", Vector2.UP)  # walk_in_place_fastest_up
	await _esperar_fotogramas(30)
	jugador.visible = false


## Common_EventScript_FerryDepart.
func _zarpar() -> void:
	var nave := get_node_or_null(barco) as BarcoFerry
	if nave != null and nave.visible:
		await nave.zarpar()


func _esperar_fotogramas(fotogramas: int) -> void:
	await get_tree().create_timer(fotogramas / 60.0).timeout


func _mensaje(clave: String) -> void:
	nodo_administrador.cuadro_dialogo.mostrar(tr(clave), true, false, _mensaje_terminado.emit)
	await _mensaje_terminado


func _cantidad_billetes() -> int:
	var datos: Dictionary = SistemaGuardado.obtener_datos_objeto_completos(OBJETO_BILLETE)
	return SistemaGuardado.get_cantidad_objeto(OBJETO_BILLETE, int(datos.get("bolsillo_id", 0)))

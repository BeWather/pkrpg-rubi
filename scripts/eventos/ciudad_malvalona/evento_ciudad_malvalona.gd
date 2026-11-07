## evento_ciudad_malvalona.gd
## Guiones del exterior de CIUDAD MALVALONA (pokeruby data/maps/MauvilleCity/scripts.inc).
## Las celdas de Godot son las de Rubí.
##
## BLASCO (objeto 6, MauvilleCity_EventScript_Wally) y su TÍO (objeto 7, solo habla; ver
## `npc_dialogo_condicional` en la escena): BLASCO quiere desafiar al GIMNASIO y su tío no le
## deja. Al hablarle (lockall): se gira a la derecha, discuten, te ve («!») y te pide un combate
## (SÍ/NO; con NO se queda con `malvalona_blasco_rechazado` y, la próxima vez, solo
## «porfa»). Con SÍ combate (BLASCO 2, id 656); pierda o gane no se mueve la historia salvo que
## ganes: da las gracias, se despide y se marcha con su tío por un camino que depende de hacia
## dónde mira el jugador (VAR_FACING: arriba → «Norte», derecha → «Este»), el tío se acerca a
## invitarte a VERDEGAL, y ambos desaparecen (FLAG_DEFEATED_WALLY_MAUVILLE).
##
## ERICO (objeto 8, MauvilleCity_EventScript_Wattson): sin la LLAVE SÓTANO te la da y te pide
## apagar el generador de MALVALANOVA; con `nueva_malvalona_completada` te da la MT24
## (RAYO) y desaparece de aquí (vuelve a su GIMNASIO).
extends EventoGuionizado
class_name EventoCiudadMalvalona

const MOTIVO_PAUSA: StringName = &"ciudad_malvalona"

## FLAG_DECLINED_WALLY_BATTLE_MAUVILLE / FLAG_DEFEATED_WALLY_MAUVILLE.
const BANDERA_BLASCO_RECHAZADO: String = "malvalona_blasco_rechazado"
const BANDERA_BLASCO_VENCIDO: String = "malvalona_blasco_vencido"
## TRAINER_WALLY_2.
const ENTRENADOR_BLASCO: int = 656
const SONIDO_EXCLAMACION: String = "SE_PIN"
## Common_Movement_Delay48.
const FOTOGRAMAS_EXCLAMACION: int = 48
## Common_Movement_Delay30 tras el primer tramo.
const FOTOGRAMAS_PAUSA: int = 30

const T := "MALVALONA_BLASCO_"
const TEXTO_DESAFIO: String = T + "DESAFIO"
const TEXTO_EXAGERAS: String = T + "TIO_EXAGERAS"
const TEXTO_NO_EXAGERO: String = T + "NO_EXAGERO"
const TEXTO_QUIERES_LUCHAR: String = T + "QUIERES_LUCHAR"
const TEXTO_PORFA: String = T + "PORFA"
const TEXTO_NO_SABRA: String = T + "NO_SABRA"
const TEXTO_ALLA_VAMOS: String = T + "ALLA_VAMOS"
const TEXTO_VUELVO: String = T + "VUELVO"
const TEXTO_GRACIAS: String = T + "GRACIAS"
const TEXTO_TIO_ANIMA: String = T + "TIO_ANIMA"
const TEXTO_VISITANOS: String = T + "TIO_VISITANOS"

## FLAG_RECEIVED_BASEMENT_KEY, ITEM_BASEMENT_KEY y VAR_NEW_MAUVILLE_STATE 2.
const BANDERA_LLAVE_SOTANO: String = "malvalona_llave_sotano_recibida"
const OBJETO_LLAVE: String = "LLAVESOTANO"
const BANDERA_NUEVA_MALVALONA: String = "nueva_malvalona_completada"
## FLAG_GOT_TM_THUNDERBOLT_FROM_WATTSON y ITEM_TM24_THUNDERBOLT.
const BANDERA_MT_RAYO: String = "malvalona_mt_rayo_recibida"
const OBJETO_MT_RAYO: String = "MT24"
const T_ERICO := "MALVALONA_ERICO_"
const TEXTO_LLAVE: String = T_ERICO + "LLAVE"
const TEXTO_SIN_RETO: String = T_ERICO + "SIN_RETO"
const TEXTO_MT: String = T_ERICO + "MT"
const TEXTO_JOVENES: String = T_ERICO + "JOVENES"
const TEXTO_MOCHILA_LLENA: String = "MOCHILA_LLENA_REGALO"

const L := Vector2.LEFT
const R := Vector2.RIGHT
const U := Vector2.UP
const D := Vector2.DOWN

## MauvilleCity_Movement_* (walk_* = paso normal; delay_16 = 16 fotogramas).
static var BLASCO_NORTE_1: Array = [L, L, D, D, L]
static var TIO_NORTE_1: Array = [L, L, L, D, D]
static var TIO_ACERCA_NORTE: Array = [R, R]
static var BLASCO_NORTE_2: Array = _repetir(L, 8)
static var TIO_NORTE_2: Array = _repetir(L, 8)
static var BLASCO_ESTE_1: Array = [D, D, L, L, L]
static var TIO_ESTE_1: Array = [L, D, D, L, L]
static var TIO_ACERCA_ESTE: Array = [R, U]
static var BLASCO_ESTE_2: Array = _repetir(L, 8)
static var TIO_ESTE_2: Array = [D] + _repetir(L, 8)
const FOTOGRAMAS_DELAY_16: int = 16

@export var blasco: NodePath
@export var erico: NodePath

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null
## Tío de BLASCO (objeto 7): solo se mueve en la despedida.
@export var tio: NodePath


static func _repetir(direccion: Vector2, veces: int) -> Array:
	var lista: Array = []
	for i in veces:
		lista.append(direccion)
	return lista


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var npc_blasco := get_node_or_null(blasco)
	if npc_blasco != null and npc_blasco.has_signal("hablado"):
		npc_blasco.hablado.connect(_on_blasco)
	var npc_erico := get_node_or_null(erico)
	if npc_erico != null and npc_erico.has_signal("hablado"):
		npc_erico.hablado.connect(_on_erico)


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


func _empezar(npc: Node2D, mirar_al_jugador: bool) -> bool:
	var administrador_npc: Node = npc.nodo_administrador if npc.nodo_administrador != null else _administrador()
	if _en_curso or not comenzar(administrador_npc):
		if not _en_curso and npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return false
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	if mirar_al_jugador:
		npc.mirar_jugador()
	return true


## ============================================================================
## BLASCO
## ============================================================================

## MauvilleCity_EventScript_Wally (lockall: no hace faceplayer al empezar).
func _on_blasco(npc: Node2D) -> void:
	if not _empezar(npc, false):
		return
	var direccion_jugador := _direccion_jugador()
	if SistemaGuardado.get_flag(BANDERA_BLASCO_RECHAZADO):
		npc.mirar_jugador()  # WallyRequestBattleAgain
		await _pedir_combate(npc, TEXTO_PORFA, direccion_jugador)
		return
	mirar(npc, R)
	await mensaje(TEXTO_DESAFIO)
	await mensaje(TEXTO_EXAGERAS)
	await mensaje(TEXTO_NO_EXAGERO)
	npc.mirar_jugador()
	Singleton.play_sound.emit(SONIDO_EXCLAMACION)
	await exclamacion(npc)
	await esperar_fotogramas(FOTOGRAMAS_EXCLAMACION)
	await _pedir_combate(npc, TEXTO_QUIERES_LUCHAR, direccion_jugador)


## BattleWallyPrompt: SÍ → combate y despedida; NO → bandera y «mi tío no sabrá».
func _pedir_combate(npc: Node2D, pregunta: String, direccion_jugador: Vector2) -> void:
	if not await preguntar_si_no(pregunta):
		SistemaGuardado.set_flag(BANDERA_BLASCO_RECHAZADO, true)  # DeclineWallyBattle
		await mensaje(TEXTO_NO_SABRA)
		terminar(false, [npc])
		return
	await mensaje(TEXTO_ALLA_VAMOS)  # BattleWally
	var resultado := await combatir(ENTRENADOR_BLASCO)
	if resultado != &"victoria":
		terminar(resultado == &"derrota_transferida", [npc])
		return
	mirar(npc, R)
	await mensaje(TEXTO_VUELVO)
	npc.mirar_jugador()
	await mensaje(TEXTO_GRACIAS)
	mirar(npc, R)
	await mensaje(TEXTO_TIO_ANIMA)
	admin.cuadro_dialogo.cerrar()  # closemessage
	await _despedida(npc, direccion_jugador)
	_ocultar(npc)
	_ocultar(get_node_or_null(tio))
	SistemaGuardado.set_flag(BANDERA_BLASCO_VENCIDO, true)  # DefeatedWally
	terminar(false, [npc])


## WallyAndUncleExitNorth / WallyAndUncleExitEast (VAR_FACING 2 y 4).
func _despedida(npc: Node2D, direccion_jugador: Vector2) -> void:
	var norte := direccion_jugador != R
	var tio_npc := get_node_or_null(tio) as Node2D
	var tramo_1_blasco: Array = BLASCO_NORTE_1 if norte else BLASCO_ESTE_1
	var tramo_1_tio: Array = TIO_NORTE_1 if norte else TIO_ESTE_1
	var acerca: Array = TIO_ACERCA_NORTE if norte else TIO_ACERCA_ESTE
	var tramo_2_blasco: Array = BLASCO_NORTE_2 if norte else BLASCO_ESTE_2
	var tramo_2_tio: Array = TIO_NORTE_2 if norte else TIO_ESTE_2
	await en_paralelo([_tramo.bind(npc, tramo_1_blasco, 0), _tramo.bind(tio_npc, tramo_1_tio, 0)])
	mirar(npc, R)
	await esperar_fotogramas(FOTOGRAMAS_PAUSA)
	await _tramo(tio_npc, acerca, 0)
	if tio_npc != null and norte:
		mirar(tio_npc, U)
	girar_jugador(D)  # walk_in_place_fastest_down
	await mensaje(TEXTO_VISITANOS)
	admin.cuadro_dialogo.cerrar()
	await en_paralelo([_tramo.bind(npc, tramo_2_blasco, FOTOGRAMAS_DELAY_16 * 2), _tramo.bind(tio_npc, tramo_2_tio, 0)])


## Los pasos de `npc` (si existe) tras una pausa opcional (delay_16 …).
func _tramo(npc: Node2D, direcciones: Array, demora: int) -> void:
	if demora > 0:
		await esperar_fotogramas(demora)
	if npc != null:
		await recorrer(npc, direcciones)


func _ocultar(npc: Node) -> void:
	if npc != null:
		npc.visible = false  # removeobject


func _direccion_jugador() -> Vector2:
	var jugador: Node = admin.get("jugador") if is_instance_valid(admin) else null
	return jugador.facing_direction if jugador != null else Vector2.UP


## ============================================================================
## ERICO (WATTSON)
## ============================================================================

## MauvilleCity_EventScript_Wattson.
func _on_erico(npc: Node2D) -> void:
	if not _empezar(npc, true):
		return
	if SistemaGuardado.get_flag(BANDERA_MT_RAYO):
		await mensaje(TEXTO_JOVENES)  # ReceivedThunderbolt
	elif SistemaGuardado.get_flag(BANDERA_NUEVA_MALVALONA):
		await _dar_mt_rayo(npc)  # CompletedNewMauville
	elif SistemaGuardado.get_flag(BANDERA_LLAVE_SOTANO):
		await mensaje(TEXTO_SIN_RETO)  # BegunNewMauville
	else:
		await mensaje(TEXTO_LLAVE, false)
		if await dar_objeto(npc, OBJETO_LLAVE):
			SistemaGuardado.set_flag(BANDERA_LLAVE_SOTANO, true)
			await mensaje(TEXTO_SIN_RETO)
		else:
			await mensaje(TEXTO_MOCHILA_LLENA)
	terminar(false, [npc])


func _dar_mt_rayo(npc: Node2D) -> void:
	await mensaje(TEXTO_MT, false)
	if not await dar_objeto(npc, OBJETO_MT_RAYO):
		await mensaje(TEXTO_MOCHILA_LLENA)  # Common_EventScript_ShowBagIsFull
		return
	SistemaGuardado.set_flag(BANDERA_MT_RAYO, true)
	await mensaje(TEXTO_JOVENES)

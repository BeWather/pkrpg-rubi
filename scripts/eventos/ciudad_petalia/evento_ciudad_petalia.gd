## evento_ciudad_petalia.gd
## Guiones del exterior de CIUDAD PETALIA (pokeruby data/maps/PetalburgCity/scripts.inc).
## La escena está desplazada dos filas hacia abajo respecto a Rubí: celda Godot =
## celda Rubí + (0, 2).
##
## Chico del GIMNASIO (objeto 9, GymBoy / ShowGymToPlayer0..3): con
## VAR_PETALBURG_STATE 0 espera en la entrada oeste (MoveGymBoyToWestEntrance).
## Al pisar (8,12..15) mira al jugador, se acerca con MUSICA_SIGUEME, lo lleva
## hasta el GIMNASIO, le enseña el letrero y vuelve a la entrada oeste. Como en
## Rubí, se repite cada vez mientras no cambie VAR_PETALBURG_STATE.
##
## BLASCO (objeto 2, WallyTutorial): con VAR_PETALBURG_STATE 2 (HistoriaBlasco
## TUTORIAL_PENDIENTE) espera junto a la puerta del GIMNASIO con MUSICA_SIGUEME de
## fondo. En cuanto el jugador sale del GIMNASIO con él, los dos caminan hasta la
## hierba alta de la RUTA 102, BLASCO atrapa un RALTS con el ZIGZAGOON de NORMAN
## (combate tutorial) y vuelven al GIMNASIO.
extends EventoGuionizado
class_name EventoCiudadPetalia

const MOTIVO_PAUSA: StringName = &"ciudad_petalia"

const TEXTO_NOVATO: String = "PETALIA_CHICO_GIMNASIO"
const TEXTO_ESTE_ES_GIMNASIO: String = "PETALIA_CHICO_ESTE_ES_GIMNASIO"
const TEXTO_LETRERO: String = "PETALIA_CHICO_LETRERO_GIMNASIO"
const MUSICA_SIGUEME: String = "SIGUEME"
const TEXTO_BLASCO_MIRA: String = "RUTA102_BLASCO_MIRA"
const TEXTO_BLASCO_LO_HE_HECHO: String = "RUTA102_BLASCO_LO_HE_HECHO"
const TEXTO_BLASCO_VOLVAMOS: String = "RUTA102_BLASCO_VOLVAMOS"

## Posición del objeto 9 en map.json: (12,15) de Rubí.
const CHICO_PASEA := Vector2i(12, 17)
## PetalburgCity_EventScript_MoveGymBoyToWestEntrance: setobjectxyperm 9, 5, 11.
const CHICO_ENTRADA_OESTE := Vector2i(5, 13)
## Posición del objeto 2 en map.json: (15,10) de Rubí.
const BLASCO_ESPERA := Vector2i(15, 12)
## Puerta del GIMNASIO: el warp desde dentro llega aquí y se sale con un paso abajo.
const PUERTA_GIMNASIO := Vector2i(15, 10)
## warp MAP_PETALBURG_CITY_GYM, 255, 4, 108 al acabar el tutorial.
const MAPA_GIMNASIO: String = "ciudad_petalia_gimnasio"
const LLEGADA_GIMNASIO := Vector2(4, 4)

const R := Vector2.RIGHT
const L := Vector2.LEFT
const U := Vector2.UP
const D := Vector2.DOWN

## ShowGymToPlayer0..3 (coord_events (8,10..13) de Rubí).
const CASOS := {&"gimnasio_0": 0, &"gimnasio_1": 1, &"gimnasio_2": 2, &"gimnasio_3": 3}
## BoyApproachPlayer0..3: pasos y mirada final (Vector2.ZERO = la del último paso).
const ACERCARSE := [[[R, R, R], U], [[R, R], Vector2.ZERO], [[R, R, R], D], [[D, R, R, R], D]]
## walk_in_place_fastest del jugador tras el acercamiento (ZERO = no gira).
const GIRO_JUGADOR := [D, Vector2.ZERO, U, U]
## BoyWalkToGym0..3 (acaba con walk_in_place_fastest_up).
const CHICO_AL_GIMNASIO := [
	[R, R, R, R, R, R, R, U, R],
	[D, R, R, R, R, R, R, R, R, U, U, R],
	[R, R, R, R, R, R, R, U, R],
	[R, R, R, R, R, R, R, U, U, R],
]
## PlayerWalkToGym0..3; el caso 1 empieza con delay_16 ×2.
const JUGADOR_AL_GIMNASIO := [
	[D, R, R, R, R, R, R, R, U],
	[D, R, R, R, R, R, R, R, U, U],
	[U, R, R, R, R, R, R, R, U],
	[U, R, R, R, R, R, R, R, U, U],
]
## PetalburgCity_Movement_BoyWalkAway.
const CHICO_SE_VA := [D, L, L, L, L, L, L, L, L, L, L, L]
## PetalburgCity_Movement_WallyTutorialPlayer / _WallyTutorialWally (tras delay_8):
## de la puerta del GIMNASIO a la hierba alta de la RUTA 102, que empieza en la
## columna 30 de la ciudad. El jugador acaba en (35,17) y BLASCO en (36,17).
static var JUGADOR_TUTORIAL: Array = _repetir(D, 8) + _repetir(R, 20) + _repetir(U, 2)
static var BLASCO_TUTORIAL: Array = _repetir(D, 7) + _repetir(R, 20) + _repetir(U, 2) + [R]

@export var chico_gimnasio: NodePath
@export var blasco: NodePath

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null
## musica_mapa de la escena (se sustituye por SIGUEME mientras BLASCO espera).
var _musica_mapa: String = ""


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for hijo in get_children():
		if hijo is DisparadorEventoPorTiles:
			hijo.evento_activado.connect(_on_disparador)
	var mapa := obtener_mapa()
	if mapa != null:
		_musica_mapa = mapa.musica_mapa
		mapa.mapa_activado.connect(_on_mapa_activado)
	preparar()


func _on_mapa_activado(_por_warp: bool) -> void:
	preparar()
	if HistoriaBlasco.en_la_ciudad():
		tutorial_blasco()  # PetalburgCity_OnFrame


func _npc(ruta: NodePath) -> Node2D:
	return get_node_or_null(ruta) as Node2D


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


## VAR_PETALBURG_STATE == 0.
static func ensenando_gimnasio() -> bool:
	return HistoriaBlasco.ciudad() == HistoriaBlasco.Ciudad.INICIAL


## PetalburgCity_OnTransition: coloca al chico del GIMNASIO y a BLASCO, y con
## VAR_PETALBURG_STATE 2 pone MUSICA_SIGUEME como tema del mapa (savebgm).
func preparar() -> void:
	if _en_curso:
		return
	var chico := _npc(chico_gimnasio)
	if chico != null:
		colocar(chico, CHICO_ENTRADA_OESTE if ensenando_gimnasio() else CHICO_PASEA)
	var npc_blasco := _npc(blasco)
	if npc_blasco != null:
		npc_blasco.tipo_movimiento = NpcBase.TipoMovimientoNPC.MIRAR_ARRIBA
		colocar(npc_blasco, BLASCO_ESPERA)
		npc_blasco.visible = HistoriaBlasco.en_la_ciudad()  # FLAG_HIDE_WALLY_PETALBURG
	_actualizar_musica_mapa()


## savebgm MUS_FOLLOW_ME mientras BLASCO espera. Hay que deshacerlo en cuanto acaba
## el tutorial: el AdministradorMapa elige la música al volver a la ciudad antes de
## avisar con mapa_activado, así que un SIGUEME pendiente sonaría al salir del GIMNASIO.
func _actualizar_musica_mapa() -> void:
	var mapa := obtener_mapa()
	if mapa != null and not _musica_mapa.is_empty():
		mapa.musica_mapa = MUSICA_SIGUEME if HistoriaBlasco.en_la_ciudad() else _musica_mapa


func _on_disparador(id_evento: StringName) -> void:
	if _en_curso or not CASOS.has(id_evento) or not ensenando_gimnasio():
		return
	_ensenar_gimnasio(CASOS[id_evento])


## PetalburgCity_EventScript_ShowGymToPlayer.
func _ensenar_gimnasio(caso: int) -> void:
	var chico := _npc(chico_gimnasio)
	if chico == null or not comenzar(_administrador()):
		return
	chico.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	mirar(chico, R)  # Common_Movement_FacePlayer: el jugador siempre está al este
	reproducir_musica(MUSICA_SIGUEME)
	Singleton.play_sound.emit("SE_PIN")
	await exclamacion(chico)
	await esperar_fotogramas(48)  # Common_Movement_Delay48
	await recorrer(chico, ACERCARSE[caso][0])
	if ACERCARSE[caso][1] != Vector2.ZERO:
		mirar(chico, ACERCARSE[caso][1])
	if GIRO_JUGADOR[caso] != Vector2.ZERO:
		girar_jugador(GIRO_JUGADOR[caso])
	await mensaje(TEXTO_NOVATO)
	await en_paralelo([
		_chico_al_gimnasio.bind(chico, caso),
		_jugador_al_gimnasio.bind(caso),
	])
	await mensaje(TEXTO_ESTE_ES_GIMNASIO, false)
	mirar(chico, R)
	girar_jugador(R)
	await mensaje(TEXTO_LETRERO)
	await recorrer(chico, CHICO_SE_VA)
	restaurar_musica_mapa()  # fadedefaultbgm
	terminar(false, [chico])


func _chico_al_gimnasio(chico: Node2D, caso: int) -> void:
	await recorrer(chico, CHICO_AL_GIMNASIO[caso])
	mirar(chico, U)


func _jugador_al_gimnasio(caso: int) -> void:
	if caso == 1:
		await esperar_fotogramas(32)
	await recorrer_jugador(JUGADOR_AL_GIMNASIO[caso])


## ============================================================================
## TUTORIAL DE CAPTURA DE BLASCO
## ============================================================================

## PetalburgCity_EventScript_WallyTutorial.
func tutorial_blasco() -> void:
	var npc := _npc(blasco)
	if npc == null or not comenzar(_administrador()):
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	await esperar_fin_warp(admin)
	await completar_salida_puerta(PUERTA_GIMNASIO, D)
	SistemaGuardado.set_flag(HistoriaVillaRaiz.BANDERA_OCULTAR_CARTEL, true)  # FLAG_HIDE_MAP_NAME_POPUP
	reproducir_musica(MUSICA_SIGUEME)
	await esperar_fotogramas(8)  # delay_8
	await en_paralelo([_blasco_a_la_hierba.bind(npc), recorrer_jugador.bind(JUGADOR_TUTORIAL)])
	girar_jugador(R)  # walk_in_place_fastest_right
	await mensaje(TEXTO_BLASCO_MIRA)  # Route102_Text_WatchMeCatchPokemon
	await combate_tutorial()
	await mensaje(TEXTO_BLASCO_LO_HE_HECHO, false)
	mirar(npc, L)  # Common_Movement_WalkInPlaceFastestLeft
	await mensaje(TEXTO_BLASCO_VOLVAMOS)
	SistemaGuardado.set_flag(HistoriaVillaRaiz.BANDERA_OCULTAR_CARTEL, false)
	HistoriaBlasco.terminar_tutorial()
	_actualizar_musica_mapa()  # fadedefaultbgm: el tema de la ciudad vuelve a ser el suyo
	terminar(false, [npc])
	admin.conectar_escalera(MAPA_GIMNASIO, LLEGADA_GIMNASIO, U)  # warp, sin puerta


## PetalburgCity_Movement_WallyTutorialWally: tras el último paso, delay_16,
## mira arriba, delay_16 ×2 y mira a la derecha.
func _blasco_a_la_hierba(npc: Node2D) -> void:
	await recorrer(npc, BLASCO_TUTORIAL)
	await esperar_fotogramas(16)
	mirar(npc, U)
	await esperar_fotogramas(32)
	mirar(npc, R)


## ScrSpecial_StartWallyTutorialBattle. En Rubí no se puede perder (BLASCO siempre
## atrapa al RALTS), así que el resultado no cambia el guion.
func combate_tutorial() -> void:
	admin.cuadro_dialogo.cerrar()
	var manager: Object = admin.get("battle_manager")
	if manager != null and manager.has_method("combatir_tutorial_blasco"):
		await manager.combatir_tutorial_blasco()


static func _repetir(direccion: Vector2, veces: int) -> Array:
	var lista: Array = []
	for i in veces:
		lista.append(direccion)
	return lista

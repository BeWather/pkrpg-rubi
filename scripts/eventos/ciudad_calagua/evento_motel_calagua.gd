## evento_motel_calagua.gd
## MOTEL de CIUDAD CALAGUA (pokeruby LilycoveCity_CoveLilyMotel_1F y _2F). Las dos plantas están en una
## sola escena, la 2F apilada encima de la 1F: **Godot (x, y) = Rubí (x, y) en la 1F y (x, y - 14) en la 2F**
## (la escalera (2,1) de la 1F lleva a (2,-13)).
##
## 1F
## - DUEÑO (objeto 1, MAN_1 en (10,3), FACE_UP): `lockall` sin faceplayer. Dice un texto, se gira hacia el
##   jugador, dice el segundo y vuelve a su dirección. Según el progreso: SYS_GAME_CLEAR («el POKéMON guardián
##   pilló a un ladrón» + los clientes de GAME FREAK), si no FLAG_BADGE07_GET (MEDALLA 7: «un POKéMON encontró
##   un objeto perdido» + guarida destrozada) y si no la primera pareja (la mascota y el EQUIPO MAGMA).
## - TELE (coord_event (10,2), VAR_TEMP_1 == 0): al pisar la celda del DUEÑO se sobresalta («!»), te dice que
##   le tapas la tele, te echa un paso a la izquierda y vuelve a su sitio. VAR_TEMP_1 nunca se pone a 1, así
##   que salta en cada paso por la celda.
## 2F (los seis, ocultos hasta superar la LIGA: FLAG_HIDE_LILYCOVE_MOTEL_PEOPLE ≡ SYS_GAME_CLEAR)
## - DISEÑADOR del JUEGO: «enséñame la POKéDEX completa». Si tienes los 200 de HOENN (CompletedHoennPokedex):
##   fanfarria, «¡Tu POKéDEX está llena del todo!», fanfarria de MEDALLA y el DIPLOMA (ScrSpecial_ShowDiploma,
##   que no existe aún: se emite `diploma_solicitado`). FLAG_TEMP_2 recuerda en esta visita que ya lo viste.
## - Los demás son msgbox (MSGBOX_NPC).
extends EventoInteriorMalvalona
class_name EventoMotelCalagua

const MOTIVO_PAUSA: StringName = &"motel_calagua"

const BANDERA_LIGA: String = "SYS_GAME_CLEAR"
## FLAG_TEMP_2: ya has enseñado la POKéDEX completa en esta visita.
const BANDERA_TEMP_DIPLOMA: String = "TEMP_2"
const FANFARRIA_MEDALLA: String = "OBTENIDA_MEDALLA"
const SONIDO_EXCLAMACION: String = "SE_PIN"

const TEXTO_PAREJA_NORMAL: Array[String] = ["CALAGUA_MOTEL_DUENO_MASCOTA", "CALAGUA_MOTEL_DUENO_SIN_HUESPEDES"]
const TEXTO_PAREJA_MEDALLA: Array[String] = ["CALAGUA_MOTEL_DUENO_OBJETO_PERDIDO", "CALAGUA_MOTEL_DUENO_GUARIDA"]
const TEXTO_PAREJA_LIGA: Array[String] = ["CALAGUA_MOTEL_DUENO_LADRON", "CALAGUA_MOTEL_DUENO_CENA"]
const TEXTO_TELE: String = "CALAGUA_MOTEL_TELE"
const TEXTO_DISENADOR_PIDE: String = "CALAGUA_MOTEL_DISENADOR_PIDE"
const TEXTO_DISENADOR_DIPLOMA: String = "CALAGUA_MOTEL_DISENADOR_DIPLOMA"

@export var dueno: NodePath
@export var disenador: NodePath
## DisparadorEventoPorTiles de la celda de la tele (10,2).
@export var disparador_tele: NodePath

## Sustituye a CompletedHoennPokedex (tests): devuelve true/false.
var pokedex_completa: Callable = Callable()

## ScrSpecial_ShowDiploma: el DIPLOMA aún no existe, quien lo implemente escucha esta señal.
signal diploma_solicitado


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	escuchar(dueno, _on_dueno)
	escuchar(disenador, _on_disenador)
	var disparador := get_node_or_null(disparador_tele)
	if disparador is DisparadorEventoPorTiles:
		(disparador as DisparadorEventoPorTiles).evento_activado.connect(func(_id: StringName) -> void: tele_tapada())


## MotelOwner: dos mensajes con un giro hacia el jugador entre medias.
func _on_dueno(npc: Node2D) -> void:
	if not empezar_con(npc, false):  # lockall: no mira al jugador hasta el segundo texto
		return
	var textos: Array[String] = TEXTO_PAREJA_NORMAL
	if SistemaGuardado.get_flag(BANDERA_LIGA):
		textos = TEXTO_PAREJA_LIGA
	elif SistemaGuardado.tiene_medalla(6):  # FLAG_BADGE07_GET
		textos = TEXTO_PAREJA_MEDALLA
	await mensaje(textos[0])
	npc.mirar_jugador()  # Common_Movement_FacePlayer
	await mensaje(textos[1], false)
	admin.cuadro_dialogo.cerrar()  # closemessage
	mirar(npc, npc.direccion_base)  # Common_Movement_FaceOriginalDirection
	terminar(false, [npc])


## BlockingTV (coord_event (10,2)): el DUEÑO empuja al jugador un paso a la izquierda.
func tele_tapada() -> void:
	var propietario := nodo(dueno)
	if propietario == null or not comenzar(_administrador()):
		return
	Singleton.play_sound.emit(SONIDO_EXCLAMACION)
	await exclamacion(propietario)
	await esperar_fotogramas(48)  # Common_Movement_Delay48
	girar_jugador(D)  # walk_in_place_fastest_down
	await mensaje(TEXTO_TELE, false)
	admin.cuadro_dialogo.cerrar()
	# PlayerPushFromTV (face_right, lock_facing_direction, walk_left) y OwnerPushPlayer (walk_up) a la vez.
	girar_jugador(R)
	await en_paralelo([_jugador_se_aparta, _propietario_empuja.bind(propietario)])
	# OwnerReturn: face_down, walk_down, face_up.
	mirar(propietario, D)
	await caminar(propietario, D)
	mirar(propietario, U)
	terminar(false, [propietario])


func _jugador_se_aparta() -> void:
	await retroceder_jugador(L)


func _propietario_empuja(propietario: Node2D) -> void:
	await caminar(propietario, U)


## GameDesigner (lock + faceplayer).
func _on_disenador(npc: Node2D) -> void:
	if not empezar_con(npc):
		return
	if not SistemaGuardado.get_flag_temporal(BANDERA_TEMP_DIPLOMA):
		await mensaje(TEXTO_DISENADOR_PIDE)  # ShowMeCompletedDex
	else:
		await _diploma()
	if _hoenn_completa():
		SistemaGuardado.set_flag_temporal(BANDERA_TEMP_DIPLOMA, true)
		await fanfarria(FANFARRIA_OBJETO)  # AllHoennMonsFanfare: MUS_OBTAIN_ITEM
		await _diploma()
	terminar(false, [npc])


## ShowDiploma: texto, fanfarria de MEDALLA (Common_EventScript_PlayGymBadgeFanfare) y el DIPLOMA.
func _diploma() -> void:
	await mensaje_con_fanfarria(TEXTO_DISENADOR_DIPLOMA, FANFARRIA_MEDALLA)
	admin.cuadro_dialogo.cerrar()
	diploma_solicitado.emit()


func _hoenn_completa() -> bool:
	if pokedex_completa.is_valid():
		return bool(pokedex_completa.call())
	return PokedexPartida.hoenn_completa()

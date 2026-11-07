## evento_isla_del_sur.gd
## Guiones de la ISLA SUR (pokeruby data/maps/SouthernIsland_Exterior y SouthernIsland_Interior/scripts.inc). Las
## escenas las genera herramientas/importar_isla_del_sur.py; las celdas de Godot son las de Rubí.
##
## Exterior (`marinero`, SouthernIsland_Exterior_EventScript_160AE0): el MARINERO del S.S. MAREA pregunta si volver a
## CIUDAD CALAGUA; con SÍ mira al barco, delay 30 y se aparta (hideobjectat 1); el jugador sube a bordo
## (Common_EventScript_FerryDepartIsland: un paso al sur, o al oeste y mira al sur), delay 30 y se oculta; el S.S. MAREA
## (`barco`, BarcoFerry) zarpa y warp al PUERTO de CALAGUA (8,11). El marinero vuelve a su sitio al activarse el mapa.
##
## Interior (`losa`, SouthernIsland_Interior_EventScript_160BA7): sin el TICKET EÓN (FLAG_SYS_HAS_EON_TICKET =
## `SYS_HAS_EON_TICKET`) o con LATIAS ya encontrada (FLAG_ENCOUNTERED_LATIAS_OR_LATIOS = `isla_sur_latias_encontrada`)
## la losa solo dice «Los sueños son un mundo aparte...». Si no: la cámara sube tres casillas (SpawnCameraDummy),
## grito de LATIAS, aparece en (13,2) y baja hasta la losa mientras la cámara vuelve; combate con LATIAS Nv. 50 con el
## ROCÍO BONDAD (setwildbattle SPECIES_LATIAS, 50, ITEM_SOUL_DEW; ScrSpecial_StartSouthernIslandBattle: transición y
## música de salvaje). LATIAS se va (FLAG_HIDE_LATIOS_OR_LATIAS_STATIONARY) gane, huya o pierda el jugador.
extends EventoInteriorMalvalona
class_name EventoIslaDelSur

const MOTIVO_PAUSA: StringName = &"isla_del_sur"
const T := "ISLA_SUR_"
const TEXTO_VOLVER: String = T + "MARINERO_VOLVER"
const TEXTO_SI: String = T + "MARINERO_SI"
const TEXTO_NO: String = T + "MARINERO_NO"
const TEXTO_LOSA: String = T + "LOSA"

## FLAG_SYS_HAS_EON_TICKET (Mystery Event: la carta de PAPÁ; aquí, el menú de depuración del laboratorio).
const BANDERA_TICKET_EON: String = "SYS_HAS_EON_TICKET"
## FLAG_ENCOUNTERED_LATIAS_OR_LATIOS.
const BANDERA_LATIAS_ENCONTRADA: String = "isla_sur_latias_encontrada"
const ESPECIE_LATIAS: String = "LATIAS"
const NUMERO_LATIAS: int = 380
const NIVEL_LATIAS: int = 50
const OBJETO_LATIAS: String = "ROCIOBONDAD"  # ITEM_SOUL_DEW

const MAPA_PUERTO: String = "ciudad_calagua_puerto"
const LLEGADA_PUERTO := Vector2(8, 11)

## Celdas de Rubí: LATIAS aparece en (13,2) y baja hasta la losa (13,11).
const CELDA_LATIAS := Vector2i(13, 2)
## SouthernIsland_Interior_Movement_160C22: cinco pasos abajo, delay_16 ×2 y cuatro más.
const PASOS_LATIAS_1: int = 5
const PASOS_LATIAS_2: int = 4
const CASILLAS_CAMARA: int = 3
const FOTOGRAMAS_PASO: int = 16
const FOTOGRAMAS_DELAY_30: int = 30
const FOTOGRAMAS_DELAY_50: int = 50

@export var marinero: NodePath
@export var losa: NodePath
@export var latias: NodePath
@export var barco: NodePath

## Sustituye al combate real (tests): Callable() -> ResultadoBatalla.Valor.
var combate_simulado: Callable = Callable()
## false omite el paneo, el grito y el warp (tests).
var con_efectos: bool = true


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	escuchar(marinero, _on_marinero)
	var cartel := get_node_or_null(losa) as CartelEvento
	if cartel != null:
		cartel.accionado.connect(_on_losa)
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)


## El marinero, apartado para el embarque, vuelve a su sitio.
func _on_mapa_activado(_por_warp: bool) -> void:
	var npc := nodo(marinero)
	if npc != null and not _en_curso:
		npc.visible = true


static func latias_disponible() -> bool:
	return SistemaGuardado.get_flag(BANDERA_TICKET_EON) and not SistemaGuardado.get_flag(BANDERA_LATIAS_ENCONTRADA)


## SouthernIsland_Exterior_EventScript_160AE0.
func _on_marinero(npc: Node2D) -> void:
	if not empezar_con(npc):
		return
	if not await preguntar_si_no(TEXTO_VOLVER):
		await mensaje(TEXTO_NO)
		terminar(false, [npc])
		return
	await mensaje(TEXTO_SI)
	admin.cuadro_dialogo.cerrar()  # closemessage
	mirar(npc, D)  # Common_Movement_WalkInPlaceFastestDown
	await esperar_fotogramas(FOTOGRAMAS_DELAY_30)
	npc.visible = false  # hideobjectat 1
	await _subir_a_bordo()
	var nave := get_node_or_null(barco) as BarcoFerry
	if nave != null and nave.visible:
		await nave.zarpar()  # Common_EventScript_FerryDepart (VAR_0x8004 = 2)
	if con_efectos:
		admin.conectar_escalera(MAPA_PUERTO, LLEGADA_PUERTO, D)
	terminar(false, [npc])


## Ferry_EventScript_DepartIslandSouth / West, delay 30 y hideobjectat LOCALID_PLAYER (el warp lo vuelve a mostrar).
func _subir_a_bordo() -> void:
	var jugador: Node = admin.get("jugador")
	if jugador == null:
		return
	var mirada: Vector2 = jugador.get("facing_direction")
	if mirada == D:
		await jugador.caminar_guion(D)
	elif mirada == L:
		await jugador.caminar_guion(L)
		jugador.set("facing_direction", D)  # walk_in_place_fastest_down
	await esperar_fotogramas(FOTOGRAMAS_DELAY_30)
	jugador.visible = false


## SouthernIsland_Interior_EventScript_160B9B / _160BA7.
func _on_losa(_cartel: CartelEvento) -> void:
	if _en_curso or not comenzar(_administrador()):
		return
	if not latias_disponible():
		await mensaje(TEXTO_LOSA)
		terminar()
		return
	SistemaGuardado.set_flag(BANDERA_LATIAS_ENCONTRADA, true)
	var sprite := get_node_or_null(latias) as Node2D
	var foco_previo: Node = Singleton.foco_camara
	var camara := _crear_camara_auxiliar()
	await _mover(camara, Vector2.UP, CASILLAS_CAMARA)
	await esperar_fotogramas(FOTOGRAMAS_DELAY_50)
	if con_efectos:
		await esperar_grito(grito(NUMERO_LATIAS))
	await esperar_fotogramas(FOTOGRAMAS_DELAY_30)
	if sprite != null:
		sprite.position = Vector2(CELDA_LATIAS.x * 16 + 8, CELDA_LATIAS.y * 16 + 16)
		sprite.visible = true  # addobject 2
	await esperar_fotogramas(FOTOGRAMAS_DELAY_30)
	# SouthernIsland_Interior_Movement_160C16 (cámara: 7 × delay_16 y tres pasos abajo) a la par que _160C22 (LATIAS).
	var tareas: Array[Callable] = [_volver_camara.bind(camara), _bajar_latias.bind(sprite)]
	await en_paralelo(tareas)
	await esperar_fotogramas(FOTOGRAMAS_DELAY_50)
	Singleton.foco_camara = foco_previo  # special RemoveCameraDummy
	if is_instance_valid(camara):
		camara.queue_free()
	if sprite != null:
		sprite.visible = false  # setflag FLAG_HIDE_LATIOS_OR_LATIAS_STATIONARY + removeobject en OnResume
	var resultado: int = await _combatir_latias()
	terminar(resultado != -1 and ResultadoBatalla.es_derrota_jugador(resultado))


## SpawnCameraDummy: un nodo en la posición del foco actual al que sigue la cámara.
func _crear_camara_auxiliar() -> Node2D:
	var camara := Node2D.new()
	camara.name = "CamaraAuxiliar"
	var foco := Singleton.foco_camara as Node2D
	var mapa := obtener_mapa()
	(mapa if mapa != null else self).add_child(camara)
	if is_instance_valid(foco):
		camara.global_position = foco.global_position
	if con_efectos:
		Singleton.foco_camara = camara
	return camara


func _mover(nodo2d: Node2D, direccion: Vector2, casillas: int) -> void:
	if nodo2d == null or casillas <= 0:
		return
	var tween := create_tween()
	tween.tween_property(nodo2d, "position", nodo2d.position + direccion * 16 * casillas,
			casillas * FOTOGRAMAS_PASO / FOTOGRAMAS_POR_SEGUNDO)
	await tween.finished


func _volver_camara(camara: Node2D) -> void:
	await esperar_fotogramas(FOTOGRAMAS_PASO * 7)
	await _mover(camara, Vector2.DOWN, CASILLAS_CAMARA)


func _bajar_latias(sprite: Node2D) -> void:
	await _mover(sprite, Vector2.DOWN, PASOS_LATIAS_1)
	await esperar_fotogramas(FOTOGRAMAS_PASO * 2)
	await _mover(sprite, Vector2.DOWN, PASOS_LATIAS_2)


## setwildbattle SPECIES_LATIAS, 50, ITEM_SOUL_DEW + ScrSpecial_StartSouthernIslandBattle. ResultadoBatalla.Valor, o -1
## si el combate no pudo empezar.
func _combatir_latias() -> int:
	admin.cuadro_dialogo.cerrar()
	if combate_simulado.is_valid():
		return int(combate_simulado.call())
	var manager := admin.get("battle_manager") as OverworldBattleManager
	if manager == null:
		push_warning("[IslaDelSur] Sin OverworldBattleManager")
		return -1
	var opciones := OpcionesBatallaOverworld.para_salvaje()
	opciones.objeto_salvaje = OBJETO_LATIAS
	var lugar: String = str(admin.obtener_seccion_lugar_actual()) if admin.has_method("obtener_seccion_lugar_actual") else ""
	var ejecucion: ResultadoEjecucionBatalla = await manager.combatir_salvaje(ESPECIE_LATIAS, NIVEL_LATIAS, lugar, opciones)
	if ejecucion.fue_rechazada():
		push_warning("[IslaDelSur] Combate rechazado: %s" % ejecucion.codigo_error)
		return -1
	if ResultadoBatalla.es_derrota_jugador(ejecucion.resultado) and not manager.recuperar_derrota_estandar():
		return -1
	return int(ejecucion.resultado)

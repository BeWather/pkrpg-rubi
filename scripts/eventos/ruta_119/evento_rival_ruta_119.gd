## evento_rival_ruta_119.gd
## Tercer combate contra el rival en la RUTA 119 (pokeruby Route119_EventScript_1511C5/_1511D0 →
## Route119_EventScript_1511DB, coord_events (25,31) y (26,31) con VAR_ROUTE119_STATE == 0):
## combate según el inicial y entrega de la MO02 (VUELO).
##
## El rival no está en el mapa hasta que se pisa el trigger (FLAG_HIDE_RIVAL_ROUTE119 y
## FLAG_HIDE_RIVAL_ROUTE119_ON_BIKE): llega en BICI (objeto 25, que parte de (17,33)) por la fila 33,
## sube hasta (x, 32) delante del jugador, se baja (objeto 16, a pie), charla, combate y le da la
## MO02. Después sube otra vez a la BICI y se va por el este. Perder no cambia nada (al volver al
## mapa no hay nadie y el trigger sigue activo). Al terminar queda VAR_ROUTE119_STATE = 1, aquí
## `bandera_completado` (ruta_119_rival_vencido).
extends EventoRival
class_name EventoRivalRuta119

const ID_DISPARADOR: StringName = &"rival"
const OBJETO_VUELO: String = "MO02"
const TEXTO_MOCHILA_LLENA: String = "MOCHILA_LLENA_REGALO"
## delay 65 tras addobject 25, delay 30 tras girar el jugador, delay 30 tras bajarse y delay 30
## antes de irse.
const FOTOGRAMAS_ANTES_DE_LLEGAR: int = 65
const FOTOGRAMAS_TRAS_GIRAR: int = 30
const FOTOGRAMAS_TRAS_BAJARSE: int = 30
const FOTOGRAMAS_ANTES_DE_IRSE: int = 30
## Fila donde está el rival delante del jugador (setobjectxyperm 16/25, x, 32).
const FILA_ENCUENTRO: int = 32
## Route119_Movement_1513F0 (x = 25: 8 pasos a la derecha) y _1513FA (x = 26: 9), y un paso arriba.
const PASOS_DE_LLEGADA: Dictionary[int, int] = {25: 8, 26: 9}

## npc_rival a pie (objeto 16), oculto hasta que se baja de la BICI.
@export var rival: NodePath
## npc_rival en BICI CARRERA (objeto 25), oculto hasta que llega.
@export var rival_en_bici: NodePath

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null
var _celda_inicial: Vector2i = Vector2i.ZERO
var _celda_inicial_bici: Vector2i = Vector2i.ZERO


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var npc := _rival()
	var bici := _rival_en_bici()
	if npc == null or bici == null:
		push_warning("[RIVAL_RUTA_119] Falta el NPC del rival (a pie o en bici)")
		return
	_celda_inicial = npc.coord
	_celda_inicial_bici = bici.coord
	for hijo in get_children():
		if hijo is DisparadorEventoPorTiles:
			hijo.evento_activado.connect(_on_disparador)
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(func(_por_warp: bool) -> void: preparar())
	preparar()


func _rival() -> Node2D:
	return get_node_or_null(rival) as Node2D


func _rival_en_bici() -> Node2D:
	return get_node_or_null(rival_en_bici) as Node2D


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


## Los dos rivales empiezan fuera del mapa (addobject 25 / addobject 16 los trae).
func preparar() -> void:
	if _en_curso:
		return
	var npc := _rival()
	if npc != null:
		colocar(npc, _celda_inicial)
		npc.visible = false
	var bici := _rival_en_bici()
	if bici != null:
		colocar(bici, _celda_inicial_bici)
		bici.visible = false


func _on_disparador(id_evento: StringName) -> void:
	if id_evento == ID_DISPARADOR:
		await iniciar_encuentro()


## Route119_EventScript_1511DB. La columna es la x del jugador (25 o 26).
func iniciar_encuentro() -> void:
	if _en_curso or completado():
		return
	var adm := _administrador()
	if not comenzar(adm):
		return
	var npc := _rival()
	var bici := _rival_en_bici()
	var columna: int = admin.jugador.pos_celda_act.x
	if not PASOS_DE_LLEGADA.has(columna):
		columna = 25

	bici.visible = true  # addobject 25
	reproducir_musica_encuentro()  # playbgm MUS_ENCOUNTER_MAY / MUS_ENCOUNTER_BRENDAN
	await esperar_fotogramas(FOTOGRAMAS_ANTES_DE_LLEGAR)
	await llegar_en_bici(bici, columna)
	girar_jugador(Vector2.DOWN)  # walk_in_place_fastest_down
	await esperar_fotogramas(FOTOGRAMAS_TRAS_GIRAR)
	bajarse(bici, npc, columna)  # setobjectxyperm 16/25 + removeobject 25 + addobject 16
	await esperar_fotogramas(FOTOGRAMAS_TRAS_BAJARSE)

	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	await mensaje(texto("SALUDO"))
	var resultado := await combatir_rival()
	if resultado != &"victoria":
		terminar(resultado == &"derrota_transferida", [npc])
		preparar()  # el mapa se recarga sin el rival
		return

	await mensaje(texto("ENTREGA"), false)
	if not await dar_objeto(npc, OBJETO_VUELO):  # giveitem ITEM_HM02_FLY
		await mensaje(TEXTO_MOCHILA_LLENA, false)  # Common_EventScript_ShowBagIsFull
	await mensaje(texto("DESPEDIDA"), false)
	admin.cuadro_dialogo.cerrar()  # closemessage
	subirse_a_la_bici(bici, npc, columna)
	await esperar_fotogramas(FOTOGRAMAS_ANTES_DE_IRSE)
	await marcharse_en_bici(bici, columna)
	marcar_completado()  # VAR_ROUTE119_STATE = 1
	restaurar_musica_mapa()  # savebgm 0 + fadedefaultbgm
	terminar(false, [npc])
	preparar()


## Route119_Movement_1513F0 / _1513FA: la BICI recorre la fila 33 desde (17,33) y sube un paso.
func llegar_en_bici(bici: Node2D, columna: int) -> void:
	var pasos: Array = []
	for i in int(PASOS_DE_LLEGADA[columna]):
		pasos.append(Vector2.RIGHT)
	pasos.append(Vector2.UP)
	await recorrer(bici, pasos, VelocidadPaso.RAPIDO)


## Route119_EventScript_1513D2 / _1513E1 + removeobject 25 + addobject 16.
func bajarse(bici: Node2D, npc: Node2D, columna: int) -> void:
	var celda := Vector2i(columna, FILA_ENCUENTRO)
	colocar(npc, celda)
	colocar(bici, celda)
	bici.visible = false
	npc.visible = true
	mirar(npc, Vector2.UP)


## removeobject 16 + addobject 25 en la misma casilla.
func subirse_a_la_bici(bici: Node2D, npc: Node2D, columna: int) -> void:
	var celda := Vector2i(columna, FILA_ENCUENTRO)
	colocar(npc, celda)
	colocar(bici, celda)
	npc.visible = false
	bici.visible = true
	mirar(bici, Vector2.UP)


## Route119_Movement_151405 (x = 25) y _15140F (x = 26), seguidos de removeobject 25.
func marcharse_en_bici(bici: Node2D, columna: int) -> void:
	var pasos: Array = [Vector2.RIGHT if columna == 25 else Vector2.LEFT]
	pasos.append_array([Vector2.UP, Vector2.UP, Vector2.UP])
	pasos.append_array([Vector2.RIGHT] if columna == 25 else [Vector2.RIGHT, Vector2.RIGHT])
	pasos.append_array([Vector2.UP, Vector2.UP, Vector2.UP, Vector2.UP])
	await recorrer(bici, pasos, VelocidadPaso.RAPIDO)
	bici.visible = false

## evento_rival_ruta_110.gd
## Segundo combate contra el rival (pokeruby Route110_EventScript_14FD13/_14FD1E/_14FD29 →
## Route110_EventScript_14FD34).
##
## El rival (objeto 28) espera en (34,54) mirando a izquierda y derecha. Al pisar la fila 56 del
## sendero (celdas (33,56), (34,56) o (35,56): VAR_ROUTE110_STATE == 0) suena su música, se vuelve
## hacia abajo, "!", espera y baja hasta quedar delante del jugador (según la columna). Charla,
## combate (equipo según el inicial), le da el BUSCAOBJETOS, se despide y se va en BICI
## (objeto 29) siete casillas hacia arriba por el sendero.
## Perder no cambia nada: el rival sigue esperando. Al terminar queda VAR_ROUTE110_STATE = 1,
## aquí `bandera_completado` (ruta_110_rival_vencido).
extends EventoRival
class_name EventoRivalRuta110

const ID_DISPARADOR: StringName = &"rival"
## Common_Movement_Delay48 y delay 30 antes de que baje; delay 45 antes de la bici.
const FOTOGRAMAS_TRAS_EXCLAMACION: int = 48
const FOTOGRAMAS_ANTES_DE_BAJAR: int = 30
const FOTOGRAMAS_ANTES_DE_LA_BICI: int = 45
const OBJETO_BUSCAOBJETOS: String = "BUSCAOBJETOS"
const TEXTO_MOCHILA_LLENA: String = "MOCHILA_LLENA_REGALO"
## Fila donde aparece la BICI (setobjectxyperm 29, x, 55).
const FILA_BICI: int = 55
## walk_fast_up ×7 (la columna central añade un walk_fast_down).
const PASOS_BICI: int = 7

## npc_rival a pie (objeto 28).
@export var rival: NodePath
## npc_rival en BICI CARRERA (objeto 29), oculto hasta que se va.
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
		push_warning("[RIVAL_RUTA_110] Falta el NPC del rival (a pie o en bici)")
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


## FLAG_HIDE_RIVAL_ROUTE110 y FLAG_HIDE_RIVAL_ON_BIKE_ROUTE110: a pie hasta vencerlo; en bici,
## nunca fuera del guion.
func preparar() -> void:
	if _en_curso:
		return
	var npc := _rival()
	if npc != null:
		colocar(npc, _celda_inicial)
		npc.visible = not completado()
	var bici := _rival_en_bici()
	if bici != null:
		colocar(bici, _celda_inicial_bici)
		bici.visible = false


func _on_disparador(id_evento: StringName) -> void:
	if id_evento == ID_DISPARADOR:
		await iniciar_encuentro()


## Route110_EventScript_14FD34. La columna es la x del jugador (33, 34 o 35).
func iniciar_encuentro() -> void:
	if _en_curso or completado():
		return
	var adm := _administrador()
	if not comenzar(adm):
		return
	var npc := _rival()
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	var columna: int = admin.jugador.pos_celda_act.x

	reproducir_musica_encuentro()  # playbgm MUS_ENCOUNTER_MAY / MUS_ENCOUNTER_BRENDAN
	mirar(npc, Vector2.DOWN)  # walk_in_place_fastest_down
	await exclamacion(npc)
	await esperar_fotogramas(FOTOGRAMAS_TRAS_EXCLAMACION)
	await esperar_fotogramas(FOTOGRAMAS_ANTES_DE_BAJAR)
	await acercarse(npc, columna)

	await mensaje(texto("SALUDO"))
	var resultado := await combatir_rival()
	if resultado != &"victoria":
		terminar(resultado == &"derrota_transferida", [npc])
		return

	await mensaje(texto("ENTREGA"), false)
	if not await dar_objeto(npc, OBJETO_BUSCAOBJETOS):  # giveitem ITEM_ITEMFINDER
		await mensaje(TEXTO_MOCHILA_LLENA, false)  # Common_EventScript_ShowBagIsFull
	await mensaje(texto("DESPEDIDA"), false)
	admin.cuadro_dialogo.cerrar()  # closemessage
	await marcharse_en_bici(npc, columna)
	marcar_completado()  # VAR_ROUTE110_STATE = 1
	restaurar_musica_mapa()  # savebgm 0 + fadedefaultbgm
	terminar(false, [npc])


## Route110_Movement_14FF6E (x = 33), _14FF72 (x = 34) y _14FF74 (x = 35): queda mirando abajo.
func acercarse(npc: Node2D, columna: int) -> void:
	match columna:
		33:
			await recorrer(npc, [Vector2.DOWN, Vector2.LEFT])
		35:
			await recorrer(npc, [Vector2.DOWN, Vector2.RIGHT])
		_:
			await recorrer(npc, [Vector2.DOWN])
	mirar(npc, Vector2.DOWN)


## removeobject 28 + setobjectxyperm 29 + addobject 29 + delay 45 + Route110_Movement_14FF78/80/89
## + removeobject 29.
func marcharse_en_bici(npc: Node2D, columna: int) -> void:
	var bici := _rival_en_bici()
	npc.visible = false
	colocar(bici, Vector2i(columna, FILA_BICI))
	bici.visible = true
	mirar(bici, Vector2.DOWN)
	await esperar_fotogramas(FOTOGRAMAS_ANTES_DE_LA_BICI)
	var pasos: Array = []
	for i in PASOS_BICI:
		pasos.append(Vector2.UP)
	if columna == 34:
		pasos.append(Vector2.DOWN)
	await recorrer(bici, pasos, VelocidadPaso.RAPIDO)
	bici.visible = false

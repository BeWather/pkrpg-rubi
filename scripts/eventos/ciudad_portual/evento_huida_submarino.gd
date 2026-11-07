## evento_huida_submarino.gd
## El EQUIPO MAGMA roba el submarino en el PUERTO de CIUDAD PORTUAL (pokeruby data/maps/SlateportCity_Harbor;
## Godot = Rubí + (0,0)). Con VAR_SLATEPORT_HARBOR_STATE == 1 (lo pone el robo del MONTE PÍRICO):
## OnTransition (ReadyEvilTeamEscapeScene): BABOR en (12,13) mirando a la izquierda, los trabajadores
##     ocultos (FLAG_HIDE_WORKERS_SLATEPORT_HARBOR; los devuelve el GIMNASIO de ALGARIA) y la música del
##     equipo (savebgm MUS_EVIL_TEAM). Se ven el soldado, MAGNO y la sombra del submarino.
## EvilTeamEscapeTrigger0..3: coord_events (8,11)..(8,14). MAGNO se burla, suben de un salto, el submarino
##     se va y BABOR se acerca al jugador. VAR_SLATEPORT_HARBOR_STATE pasa a 2 y se retiran los dos
##     soldados que tapan la GUARIDA (FLAG_HIDE_GRUNT_1/2_BLOCKING_HIDEOUT).
extends EventoGuionizado
class_name EventoHuidaSubmarino

const MOTIVO_PAUSA: StringName = &"huida_submarino"
const TipoMovimiento := NpcBase.TipoMovimientoNPC

## VAR_SLATEPORT_HARBOR_STATE.
const CONTADOR_ESTADO: String = "portual_puerto_estado"
const ESTADO_PENDIENTE: int = 1
const ESTADO_HECHO: int = 2
## FLAG_HIDE_WORKERS_SLATEPORT_HARBOR.
const BANDERA_TRABAJADORES: String = "portual_puerto_trabajadores_ocultos"

const MUSICA_MAGMA: String = "EQUIPO_MAGMA_APARECE"  # MUS_EVIL_TEAM
const TEXTO_MAGNO: String = "PORTUAL_PUERTO_MAGNO_HUIDA"
const TEXTO_BABOR: String = "PORTUAL_PUERTO_BABOR_POR_QUE"

const CELDA_BABOR_ESCENA := Vector2i(12, 13)
const FOTOGRAMAS_DELAY_16: int = 16
const FOTOGRAMAS_SALTO: int = 16
const TAMANO_CASILLA: int = 16
## Pose de dar un paso en las animaciones camina_*.
const FOTOGRAMA_PASO: int = 1
const SALPICADURA := preload("res://escenas/overworld/salpicadura_salto_mar.tscn")
const FOTOGRAMAS_POR_FRAME_SALPICADURA: int = 8
## De los pies del NPC (celda * 16 + (8,14)) al centro de su casilla.
const DESFASE_CENTRO_CELDA := Vector2(0, -6)

const L := Vector2.LEFT
const R := Vector2.RIGHT
const U := Vector2.UP
const D := Vector2.DOWN

## Disparador → [paso previo del jugador, recorrido de BABOR, giro final del jugador]
## (SternApproachPlayer0, SternApproachPlayer1, SternApproachPlayer).
static var CASOS: Dictionary = {
	&"disparador_0": [[], [L, L, L, L, U], D],
	&"disparador_1": [[], [L, L, U, L], R],
	&"disparador_2": [[], [L, L, L], R],
	&"disparador_3": [[U], [L, L, L], R],
}
## SlateportCity_Harbor_Movement_SubmarineExit tras cuatro delay_16.
static var SUBMARINO_NORMAL: Array = [R, R, R]
static var SUBMARINO_RAPIDO: Array = [R, R, R, R, R, R]

@export var babor: NodePath
@export var soldado: NodePath  # objeto 6
@export var magno: NodePath  # objeto 7
@export var submarino: NodePath  # objeto 8

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null

## [celda, tipo_movimiento] de BABOR en la escena.
var _sitio_babor: Array = []
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
		mapa.mapa_activado.connect(func(_por_warp: bool) -> void: preparar())
	preparar()


func _npc(ruta: NodePath) -> Node2D:
	return get_node_or_null(ruta) as Node2D


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


static func pendiente() -> bool:
	return SistemaGuardado.get_contador(CONTADOR_ESTADO) == ESTADO_PENDIENTE


## SlateportCity_Harbor_OnTransition.
func preparar() -> void:
	if _en_curso:
		return
	var hay_escena := pendiente()
	for ruta in [soldado, magno, submarino]:
		var actor := _npc(ruta)
		if actor != null:
			actor.visible = hay_escena
	var capitan := _npc(babor)
	if hay_escena:
		_preparar_escena(capitan)
	elif capitan != null and not _sitio_babor.is_empty():
		_recolocar_babor(capitan, _sitio_babor[0], _sitio_babor[1])
		_sitio_babor = []
	_actualizar_musica(hay_escena)


func _preparar_escena(capitan: Node2D) -> void:
	SistemaGuardado.set_flag(BANDERA_TRABAJADORES, true)
	if capitan == null:
		return
	if _sitio_babor.is_empty():
		_sitio_babor = [capitan.coord, capitan.tipo_movimiento]
	_recolocar_babor(capitan, CELDA_BABOR_ESCENA, TipoMovimiento.MIRAR_IZQUIERDA)
	for npc in capitan.get_parent().get_children():
		if npc.has_method(&"aplicar_bandera_ocultar"):
			npc.aplicar_bandera_ocultar()


func _recolocar_babor(capitan: Node2D, celda: Vector2i, tipo: TipoMovimiento) -> void:
	capitan.tipo_movimiento = tipo
	colocar(capitan, celda)
	capitan.reinicializar_como_recien_agregado()


## savebgm MUS_EVIL_TEAM. El AdministradorMapa elige la música antes de avisar con mapa_activado,
## así que el tema se pone también a mano. Tras la escena sigue sonando hasta salir del mapa.
func _actualizar_musica(hay_escena: bool) -> void:
	var mapa := obtener_mapa()
	if mapa == null or _musica_mapa.is_empty():
		return
	mapa.musica_mapa = MUSICA_MAGMA if hay_escena else _musica_mapa
	if hay_escena and is_visible_in_tree():
		reproducir_musica(MUSICA_MAGMA)


func _on_disparador(id_evento: StringName) -> void:
	if _en_curso or not CASOS.has(id_evento) or not pendiente():
		return
	if not comenzar(_administrador()):
		return
	await _guion(CASOS[id_evento])


## SlateportCity_Harbor_EventScript_EvilTeamEscapeScene.
func _guion(caso: Array) -> void:
	var capitan := _npc(babor)
	await recorrer_jugador(caso[0])
	mirar(_npc(magno), D)
	girar_jugador(U)
	await mensaje(TEXTO_MAGNO)
	admin.cuadro_dialogo.cerrar()
	await en_paralelo([
		_subir_al_submarino.bind(_npc(soldado)),
		_subir_al_submarino.bind(_npc(magno)),
		_submarino_sale,
	])
	SistemaGuardado.set_contador(CONTADOR_ESTADO, ESTADO_HECHO)
	await recorrer(capitan, caso[1])
	girar_jugador(caso[2])
	await mensaje(TEXTO_BABOR)
	SistemaGuardado.set_flag(HistoriaGuaridaCalagua.BANDERA_BLOQUEO_OCULTO, true)
	# moveobjectoffscreen + setobjectmovementtype: BABOR vuelve a su sitio al recargar el mapa.
	terminar(false, [capitan])


## SlateportCity_Harbor_Movement_EvilTeamBoardSub: dos delay_16, jump_up y set_invisible.
func _subir_al_submarino(npc: Node2D) -> void:
	await esperar_fotogramas(FOTOGRAMAS_DELAY_16 * 2)
	var tween := create_tween()
	tween.tween_property(npc, "position:y", npc.position.y - TAMANO_CASILLA, FOTOGRAMAS_SALTO / FOTOGRAMAS_POR_SEGUNDO)
	await saltar_en_sitio(npc, U, FOTOGRAMA_PASO)
	npc.visible = false
	await _salpicar(npc.global_position + DESFASE_CENTRO_CELDA)


## Agua que salta al caer al mar, centrada en la casilla de la caída (arte propio, no está en Rubí).
func _salpicar(centro: Vector2) -> void:
	var salpicadura: Sprite2D = SALPICADURA.instantiate()
	add_child(salpicadura)
	salpicadura.global_position = centro
	for fotograma in salpicadura.hframes:
		salpicadura.frame = fotograma
		await esperar_fotogramas(FOTOGRAMAS_POR_FRAME_SALPICADURA)
	salpicadura.queue_free()


func _submarino_sale() -> void:
	var sombra := _npc(submarino)
	await esperar_fotogramas(FOTOGRAMAS_DELAY_16 * 4)
	await recorrer(sombra, SUBMARINO_NORMAL)
	await recorrer(sombra, SUBMARINO_RAPIDO, VelocidadPaso.RAPIDO)
	sombra.visible = false

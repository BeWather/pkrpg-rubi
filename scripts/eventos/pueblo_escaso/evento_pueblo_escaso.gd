## evento_pueblo_escaso.gd
## Guiones del exterior de PUEBLO ESCASO (pokeruby data/maps/OldaleTown/scripts.inc).
## Las coordenadas de la escena coinciden 1:1 con las de Rubí.
##
## 1. Dependiente de la TIENDA (objeto 2, OldaleTown_EventScript_MartEmployee):
##    sin FLAG_RECEIVED_POTION_OLDALE espera en (13,14) mirando abajo; al hablarle
##    acompaña al jugador hasta la puerta de la TIENDA con MUSICA_SIGUEME y le
##    regala una POCIÓN. Después espera en (13,7) y solo explica la POCIÓN.
## 2. Maniaco de las huellas (objeto 3, OldaleTown_EventScript_FootprintsMan):
##    sin FLAG_ADVENTURE_STARTED tapa la salida oeste en (1,11) mirando a la
##    izquierda y el coord_event (0,10) no deja pasar (BlockedPath). Después está
##    en (8,9) mirando a la derecha.
## 3. Rival (objeto 4, OldaleTown_EventScript_Rival / RivalTrigger1..3): tras
##    vencerle en la RUTA 103 (VAR_OLDALE_STATE 1) espera en (11,19); al hablarle
##    o pisar (8..10,19) dice que vuelve al LABORATORIO, se va hacia abajo y
##    desaparece (VAR_OLDALE_STATE 2 / FLAG_HIDE_RIVAL_OLDALE_TOWN).
extends EventoGuionizado
class_name EventoPuebloEscaso

const MOTIVO_PAUSA: StringName = &"pueblo_escaso"
const TipoMovimiento := NpcBase.TipoMovimientoNPC

## FLAG_RECEIVED_POTION_OLDALE.
const BANDERA_POCION: String = "pueblo_escaso_pocion_recibida"
## VAR_OLDALE_STATE 2 / FLAG_HIDE_RIVAL_OLDALE_TOWN: el rival ya se fue (o el
## jugador llegó a VILLA RAÍZ sin cruzarse con él, MoveRivalFromOldale).
const BANDERA_RIVAL_VISTO: String = "pueblo_escaso_rival_visto"

const TEXTO_DEPENDIENTE_HOLA: String = "PUEBLO_ESCASO_DEPENDIENTE_HOLA"
const TEXTO_DEPENDIENTE_TIENDA: String = "PUEBLO_ESCASO_DEPENDIENTE_TIENDA"
const TEXTO_DEPENDIENTE_POCION: String = "PUEBLO_ESCASO_DEPENDIENTE_POCION"
const TEXTO_MOCHILA_LLENA: String = "MOCHILA_LLENA_REGALO"
const TEXTO_MANIACO_NO_PASES: String = "PUEBLO_ESCASO_MANIACO_NO_PASES"
const TEXTO_MANIACO_HUELLAS: String = "PUEBLO_ESCASO_MANIACO_HUELLAS"
const TEXTO_MANIACO_BOSQUEJO: String = "PUEBLO_ESCASO_MANIACO_BOSQUEJO"
## "PUEBLO_ESCASO_RIVAL_<AURA|BRUNO>_VOLVAMOS".
const TEXTO_RIVAL: String = "PUEBLO_ESCASO_RIVAL_%s_VOLVAMOS"

const OBJETO_POCION: String = "POCION"
const MUSICA_SIGUEME: String = "SIGUEME"

const DEPENDIENTE_TIENDA := Vector2i(13, 7)
## OldaleTown_EventScript_MoveMartEmployee.
const DEPENDIENTE_ESPERA := Vector2i(13, 14)
const MANIACO_PASEA := Vector2i(8, 9)
## OldaleTown_EventScript_BlockWestEntrance.
const MANIACO_BLOQUEA := Vector2i(1, 11)
const RIVAL_ESPERA := Vector2i(11, 19)

## RivalTrigger1..3: pasos del rival hasta el jugador (RivalApproachPlayer1..3).
const PASOS_RIVAL := {&"rival_1": 2, &"rival_2": 1, &"rival_3": 0}

@export var dependiente: NodePath
@export var maniaco: NodePath
@export var rival: NodePath

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null
## FLAG_TEMP_1: el dependiente ya acompañó al jugador en esta visita.
var _acompanado: bool = false


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for hijo in get_children():
		if hijo is DisparadorEventoPorTiles:
			hijo.evento_activado.connect(_on_disparador)
	_conectar(dependiente, _on_dependiente_hablado)
	_conectar(maniaco, _on_maniaco_hablado)
	_conectar(rival, _on_rival_hablado)
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(func(_por_warp: bool) -> void: preparar())
	preparar()


func _conectar(ruta: NodePath, metodo: Callable) -> void:
	var npc := _npc(ruta)
	if npc != null and npc.has_signal("hablado"):
		npc.hablado.connect(metodo)


func _npc(ruta: NodePath) -> Node2D:
	return get_node_or_null(ruta) as Node2D


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


static func aventura_iniciada() -> bool:
	return SistemaGuardado.get_flag(HistoriaVillaRaiz.BANDERA_AVENTURA)


static func pocion_recibida() -> bool:
	return SistemaGuardado.get_flag(BANDERA_POCION)


## VAR_OLDALE_STATE == 1.
static func rival_esperando() -> bool:
	return SistemaGuardado.get_flag(HistoriaVillaRaiz.BANDERA_RIVAL_RUTA_103) \
		and not SistemaGuardado.get_flag(BANDERA_RIVAL_VISTO)


## ============================================================================
## ON_TRANSITION
## ============================================================================

## OldaleTown_OnTransition: coloca al dependiente, al maniaco y al rival.
func preparar() -> void:
	if _en_curso:
		return
	_acompanado = false
	var npc_dependiente := _npc(dependiente)
	if npc_dependiente != null:
		npc_dependiente.tipo_movimiento = TipoMovimiento.MIRAR_ABAJO
		colocar(npc_dependiente, DEPENDIENTE_TIENDA if pocion_recibida() else DEPENDIENTE_ESPERA)
	var npc_maniaco := _npc(maniaco)
	if npc_maniaco != null:
		if aventura_iniciada():
			npc_maniaco.tipo_movimiento = TipoMovimiento.MIRAR_DERECHA
			colocar(npc_maniaco, MANIACO_PASEA)
		else:
			npc_maniaco.tipo_movimiento = TipoMovimiento.MIRAR_IZQUIERDA
			colocar(npc_maniaco, MANIACO_BLOQUEA)
	var npc_rival := _npc(rival)
	if npc_rival != null:
		npc_rival.tipo_movimiento = TipoMovimiento.MIRAR_ARRIBA
		colocar(npc_rival, RIVAL_ESPERA)
		npc_rival.visible = rival_esperando()


func _on_disparador(id_evento: StringName) -> void:
	if _en_curso:
		return
	if id_evento == &"bloqueo_oeste":
		if not aventura_iniciada():
			_no_pases()
	elif PASOS_RIVAL.has(id_evento) and rival_esperando():
		_rival_al_paso(PASOS_RIVAL[id_evento])


## lock + faceplayer desde la interacción de un NPC.
func _comenzar_con(npc: Node2D) -> bool:
	if not comenzar(npc.nodo_administrador):
		if npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return false
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()
	return true


## ============================================================================
## DEPENDIENTE DE LA TIENDA
## ============================================================================

## OldaleTown_EventScript_MartEmployee.
func _on_dependiente_hablado(npc: Node2D) -> void:
	if _en_curso or not _comenzar_con(npc):
		return
	if pocion_recibida() or _acompanado:
		await mensaje(TEXTO_DEPENDIENTE_POCION)  # ExplainPotion
		terminar(false, [npc])
		return
	_acompanado = true
	reproducir_musica(MUSICA_SIGUEME)
	await mensaje(TEXTO_DEPENDIENTE_HOLA)
	admin.cuadro_dialogo.cerrar()
	await _ir_a_la_tienda(npc, admin.jugador.facing_direction)
	mirar(npc, Vector2.DOWN)
	await _regalar_pocion(npc)
	restaurar_musica_mapa()  # fadedefaultbgm
	terminar(false, [npc])


## switch VAR_FACING: GoToMartSouth / North / East. El jugador acaba en (13,8),
## debajo del dependiente y junto a la puerta de la TIENDA. Mirando a la
## izquierda (DIR_WEST) no hay caso en Rubí: (14,14) es un bloqueo.
func _ir_a_la_tienda(npc: Node2D, mirada_jugador: Vector2) -> void:
	match mirada_jugador:
		Vector2.DOWN:  # el jugador está encima del dependiente
			await en_paralelo([
				recorrer.bind(npc, [Vector2.LEFT, Vector2.UP, Vector2.UP, Vector2.RIGHT] + _repetir(Vector2.UP, 5)),
				_esperar_y_recorrer_jugador.bind(64, _repetir(Vector2.UP, 5)),
			])
		Vector2.UP:  # el jugador está debajo
			await en_paralelo([
				recorrer.bind(npc, _repetir(Vector2.UP, 7)),
				recorrer_jugador.bind(_repetir(Vector2.UP, 7)),
			])
		Vector2.RIGHT:  # el jugador está a su izquierda
			await en_paralelo([
				recorrer_jugador.bind([Vector2.RIGHT] + _repetir(Vector2.UP, 6)),
				recorrer.bind(npc, _repetir(Vector2.UP, 7)),
			])


func _esperar_y_recorrer_jugador(fotogramas: int, direcciones: Array) -> void:
	await esperar_fotogramas(fotogramas)
	await recorrer_jugador(direcciones)


## OldaleTown_EventScript_ExplainPokemonMart + giveitem ITEM_POTION.
func _regalar_pocion(npc: Node2D) -> void:
	await mensaje(TEXTO_DEPENDIENTE_TIENDA, false)
	if not await dar_objeto(npc, OBJETO_POCION):
		await mensaje(TEXTO_MOCHILA_LLENA)  # OldaleTown_EventScript_BagIsFull
		return
	await mensaje(TEXTO_DEPENDIENTE_POCION)
	SistemaGuardado.set_flag(BANDERA_POCION, true)


## ============================================================================
## MANIACO DE LAS HUELLAS
## ============================================================================

## OldaleTown_EventScript_FootprintsMan.
func _on_maniaco_hablado(npc: Node2D) -> void:
	if _en_curso or not _comenzar_con(npc):
		return
	if aventura_iniciada():
		await mensaje(TEXTO_MANIACO_BOSQUEJO)  # NotBlockingPath
	else:
		await mensaje(TEXTO_MANIACO_HUELLAS)
		admin.cuadro_dialogo.cerrar()
		mirar(npc, npc.direccion_base)  # Common_Movement_FaceOriginalDirection
	terminar(false, [npc])


## OldaleTown_EventScript_BlockedPath: el maniaco sube corriendo a cortar el paso,
## retrocede mirando al jugador (que da un paso atrás) y vuelve a (1,11).
func _no_pases() -> void:
	if not comenzar(_administrador()):
		return
	var npc := _npc(maniaco)
	if npc == null:
		terminar()
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	await en_paralelo([
		_esperar_y_recorrer_jugador.bind(8, [Vector2.RIGHT]),  # PlayerStepBack
		_maniaco_corta_el_paso.bind(npc),
	])
	await mensaje(TEXTO_MANIACO_NO_PASES)
	admin.cuadro_dialogo.cerrar()
	await recorrer(npc, [Vector2.DOWN, Vector2.LEFT])  # ReturnToOriginalPosition
	terminar(false, [npc])


## OldaleTown_Movement_BackUp: walk_fast_up, walk_in_place_fastest_left y un
## paso a la derecha sin dejar de mirar a la izquierda.
func _maniaco_corta_el_paso(npc: Node2D) -> void:
	await caminar(npc, Vector2.UP, VelocidadPaso.RAPIDO)
	mirar(npc, Vector2.LEFT)
	await caminar(npc, Vector2.RIGHT)
	mirar(npc, Vector2.LEFT)


## ============================================================================
## RIVAL
## ============================================================================

## OldaleTown_EventScript_Rival.
func _on_rival_hablado(npc: Node2D) -> void:
	if _en_curso or not rival_esperando() or not _comenzar_con(npc):
		return
	await _rival_se_va(npc)


## OldaleTown_EventScript_RivalTrigger1..3.
func _rival_al_paso(pasos: int) -> void:
	var npc := _npc(rival)
	if npc == null or not npc.visible or not comenzar(_administrador()):
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	if pasos > 0:
		await recorrer(npc, _repetir(Vector2.LEFT, pasos))
	else:
		mirar(npc, Vector2.LEFT)  # face_left
	girar_jugador(Vector2.RIGHT)
	await _rival_se_va(npc)


## OldaleTown_EventScript_ShowRivalMessage + RivalFinish.
func _rival_se_va(npc: Node2D) -> void:
	await mensaje(TEXTO_RIVAL % Rival.clave())
	admin.cuadro_dialogo.cerrar()
	await recorrer(npc, _repetir(Vector2.DOWN, 6))  # RivalExit
	npc.visible = false  # removeobject
	SistemaGuardado.set_flag(BANDERA_RIVAL_VISTO, true)
	terminar(false, [npc])


static func _repetir(direccion: Vector2, veces: int) -> Array:
	var lista: Array = []
	for i in veces:
		lista.append(direccion)
	return lista

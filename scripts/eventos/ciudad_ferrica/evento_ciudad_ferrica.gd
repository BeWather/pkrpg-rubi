## evento_ciudad_ferrica.gd
## Guiones del exterior de CIUDAD FÉRRICA (pokeruby data/maps/RustboroCity/scripts.inc):
## las 13 coord_events de las PIEZAS DEVON. Las celdas de Godot son las de Rubí.
##
## 1. Robo (StolenGoodsTrigger0..4, (23,20..24), VAR_RUSTBORO_STATE 1): «¡Fuera!»,
##    aparecen un soldado MAGMA (objeto 10, en (13,21)) y el empleado de DEVON
##    (objeto 9, en (14,21)); el soldado huye hacia el túnel y el empleado le persigue
##    pidiéndole que no se lleve sus PIEZAS. Activa el robo (HistoriaFerrica.robar_piezas)
##    y el empleado queda en (30,10) para la próxima vez que se cargue el mapa.
## 2. Petición de ayuda (HelpGetGoodsTrigger0..3, VAR_RUSTBORO_STATE 2): al pisar una
##    casilla junto al empleado, se gira, «!» y pide ayuda (estado 3).
## 3. Devolución (ReturnGoodsTrigger0..3 con VAR_RUSTBORO_STATE 4, o hablar con el
##    empleado con FLAG_RECOVERED_DEVON_GOODS): le da una SUPERBALL, le pide que le
##    acompañe y le lleva a DEVON 3F (RUSTBORO_CITY_DEVON_CORP_3F (2,2)).
## Sin las PIEZAS recuperadas, hablar con el empleado solo repite lo del túnel.
extends EventoGuionizado
class_name EventoCiudadFerrica

const MOTIVO_PAUSA: StringName = &"ciudad_ferrica"
const TipoMovimiento := NpcBase.TipoMovimientoNPC

const TEXTO_FUERA: String = "FERRICA_ROBO_FUERA"
const TEXTO_NO_TE_LLEVES: String = "FERRICA_ROBO_NO_TE_LLEVES"
const TEXTO_AYUDAME: String = "FERRICA_ROBO_AYUDAME"
const TEXTO_TUNEL: String = "FERRICA_DEVON_TUNEL"
const TEXTO_GRACIAS: String = "FERRICA_DEVON_GRACIAS"
const TEXTO_ACOMPANAME: String = "FERRICA_DEVON_ACOMPANAME"
const TEXTO_MOCHILA: String = "FERRICA_DEVON_MOCHILA_LLENA"

## GREAT_BALL.
const OBJETO_RECOMPENSA: String = "SUPERBALL"
const SONIDO_EXCLAMACION: String = "SE_PIN"

## map.json: el empleado (objeto 9) en (30,10); el soldado (objeto 10) en (13,21).
const EMPLEADO_ESPERA := Vector2i(30, 10)
const EMPLEADO_ROBO := Vector2i(14, 21)
const SOLDADO_ROBO := Vector2i(13, 21)
## RustboroCity_DevonCorp_3F, warp 255, 2, 2: DEVON 3F está en y − 28 en la escena.
const MAPA_DEVON: String = "ciudad_ferrica_devon"
const LLEGADA_DEVON_3F := Vector2(2, -26)
const FOTOGRAMAS_PIN: int = 48

const L := Vector2.LEFT
const R := Vector2.RIGHT
const U := Vector2.UP
const D := Vector2.DOWN

## Id del disparador → [clase, caso]. Las coord_events de Rubí son los mismos
## cuatro (o cinco) puntos con otra variable.
const ROBO := "robo"
const AYUDA := "ayuda"
const DEVOLUCION := "devolucion"

## RustboroCity_Movement_GruntEscape: dos pasos rapidísimos y cinco rápidos a la
## derecha y nueve rápidos hacia arriba.
static var HUIDA_SOLDADO: Array = _repetir(R, 7) + _repetir(U, 9)
## EmployeeChaseGrunt1 (acaba con walk_in_place_fastest_up) y EmployeeChaseGrunt2.
static var PERSECUCION_1: Array = _repetir(R, 6)
static var PERSECUCION_2: Array = _repetir(U, 7)

@export var empleado: NodePath
@export var soldado: NodePath

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
	var npc := _npc(empleado)
	if npc != null and npc.has_signal("hablado"):
		npc.hablado.connect(_on_empleado_hablado)
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(func(_por_warp: bool) -> void: preparar())
	preparar()


func _npc(ruta: NodePath) -> Node2D:
	return get_node_or_null(ruta) as Node2D


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


## OnTransition: el empleado espera en (30,10) mirando a la derecha y el soldado, que
## solo existe durante el robo, no se ve.
func preparar() -> void:
	if _en_curso:
		return
	var npc := _npc(empleado)
	if npc != null:
		npc.tipo_movimiento = TipoMovimiento.MIRAR_DERECHA
		colocar(npc, EMPLEADO_ESPERA)
	var npc_soldado := _npc(soldado)
	if npc_soldado != null:
		npc_soldado.tipo_movimiento = TipoMovimiento.MIRAR_DERECHA
		colocar(npc_soldado, SOLDADO_ROBO)
		npc_soldado.visible = false


## Los coord_events dependen de VAR_RUSTBORO_STATE; el id es "<clase>_<caso>".
func _on_disparador(id_evento: StringName) -> void:
	if _en_curso:
		return
	var partes := String(id_evento).rsplit("_", true, 1)
	if partes.size() != 2 or not partes[1].is_valid_int():
		return
	var caso := int(partes[1])
	match partes[0]:
		ROBO:
			if HistoriaFerrica.estado() == HistoriaFerrica.Estado.GIMNASIO_VENCIDO:
				_robo()
		AYUDA:
			if HistoriaFerrica.estado() == HistoriaFerrica.Estado.PIEZAS_ROBADAS:
				_pedir_ayuda(caso)
		DEVOLUCION:
			if HistoriaFerrica.estado() == HistoriaFerrica.Estado.PIEZAS_RECUPERADAS:
				_devolver_piezas(caso)


## ============================================================================
## ROBO
## ============================================================================

## RustboroCity_EventScript_StolenGoodsScene.
func _robo() -> void:
	var npc := _npc(empleado)
	var npc_soldado := _npc(soldado)
	if npc == null or npc_soldado == null or not comenzar(_administrador()):
		return
	# setobjectxyperm 9, 14, 21 + setobjectmovementtype 9, MOVEMENT_TYPE_FACE_RIGHT
	npc.tipo_movimiento = TipoMovimiento.MIRAR_DERECHA
	colocar(npc, EMPLEADO_ROBO)
	npc.visible = false
	await mensaje(TEXTO_FUERA, false)
	admin.cuadro_dialogo.cerrar()
	npc_soldado.visible = true  # addobject 10
	npc.visible = true  # addobject 9
	await recorrer(npc_soldado, HUIDA_SOLDADO, VelocidadPaso.RAPIDO)
	npc_soldado.visible = false  # removeobject 10
	await recorrer(npc, PERSECUCION_1)
	mirar(npc, U)
	await mensaje(TEXTO_NO_TE_LLEVES)
	await recorrer(npc, PERSECUCION_2)
	npc.visible = false  # removeobject 9: reaparece en (30,10) al recargar el mapa
	npc.tipo_movimiento = TipoMovimiento.MIRAR_DERECHA
	colocar(npc, EMPLEADO_ESPERA)  # setobjectxyperm 9, 30, 10
	HistoriaFerrica.robar_piezas()
	terminar(false, [npc, npc_soldado])


## ============================================================================
## PETICIÓN DE AYUDA
## ============================================================================

## Hacia dónde se gira el empleado y el jugador según la casilla (HelpGetGoodsTrigger0..3):
## [mirada del empleado, mirada del jugador, el empleado da un paso hacia abajo].
const AYUDA_CASOS := [[U, D, false], [L, R, false], [D, U, false], [D, U, true]]
## ReturnGoodsTrigger0..3: el 1 está a la derecha del empleado.
const DEVOLUCION_CASOS := [[U, D, false], [R, L, false], [D, U, false], [D, U, true]]


## EmployeeAskToGetGoods.
func _pedir_ayuda(caso: int) -> void:
	var npc := _npc(empleado)
	if npc == null or not comenzar(_administrador()):
		return
	npc.visible = true
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	await _avisar(npc, AYUDA_CASOS[caso])
	HistoriaFerrica.pedir_ayuda()  # setflag FLAG_UNKNOWN_9F + VAR_RUSTBORO_STATE 3
	await mensaje(TEXTO_AYUDAME)
	terminar(false, [npc])


## EmployeeFacePlayer*: se gira, «!» y espera; con el caso 3 se acerca un paso.
func _avisar(npc: Node2D, caso: Array) -> void:
	mirar(npc, caso[0])
	Singleton.play_sound.emit(SONIDO_EXCLAMACION)
	await exclamacion(npc)
	await esperar_fotogramas(FOTOGRAMAS_PIN)
	if caso[2]:
		await caminar(npc, D)
	if caso[1] != Vector2.ZERO:
		girar_jugador(caso[1])


## ============================================================================
## DEVOLUCIÓN
## ============================================================================

## RustboroCity_EventScript_DevonEmployee1 (lock + faceplayer).
func _on_empleado_hablado(npc: Node2D) -> void:
	if _en_curso:
		return
	var administrador_npc: Node = npc.nodo_administrador if npc.nodo_administrador != null else _administrador()
	if not comenzar(administrador_npc):
		if npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()
	if HistoriaFervergal.piezas_recuperadas():
		await _entrega(npc, [L, Vector2.ZERO, false])  # EmployeeFacePlayerRight
		return
	await mensaje(TEXTO_TUNEL)
	terminar(false, [npc])


func _devolver_piezas(caso: int) -> void:
	var npc := _npc(empleado)
	if npc == null or not comenzar(_administrador()):
		return
	npc.visible = true
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	await _entrega(npc, DEVOLUCION_CASOS[caso])


## ReturnGoods: SUPERBALL, «¡Acompáñame!» y warp a DEVON 3F.
func _entrega(npc: Node2D, caso: Array) -> void:
	await _avisar(npc, caso)
	await mensaje(TEXTO_GRACIAS, false)
	if not await dar_objeto(npc, OBJETO_RECOMPENSA):
		await mensaje(TEXTO_MOCHILA, false)  # RustboroCity_EventScript_BagFull
	await mensaje(TEXTO_ACOMPANAME)
	# El empleado se oculta solo (bandera_mostrar) al activarse el mapa tras el
	# warp; ocultarlo aquí se vería antes del fundido.
	HistoriaFerrica.devolver_piezas()
	await esperar_fotogramas(30)  # delay 30
	var admin_actual: Node = admin
	terminar(false, [npc])
	admin_actual.conectar_escalera(MAPA_DEVON, LLEGADA_DEVON_3F, R)  # warp, sin puerta


static func _repetir(direccion: Vector2, veces: int) -> Array:
	var lista: Array = []
	for i in veces:
		lista.append(direccion)
	return lista

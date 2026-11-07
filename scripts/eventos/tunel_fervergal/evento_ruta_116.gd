## evento_ruta_116.gd
## Guiones de la RUTA 116 (pokeruby data/maps/Route116/scripts.inc). Las celdas de
## la escena son las de Rubí + (0, 2).
##
## 1. SR. ARENQUE (objeto 11, Route116_EventScript_150B5D / 150B6E): con
##    VAR_ROUTE116_STATE 1 (el robo de las PIEZAS) llora a la entrada del TÚNEL
##    FERVERGAL. Al pisar (47,11) se gira hacia el jugador, que le mira, y cuenta que
##    secuestraron a PEEKO (estado 2). Hablarle repite el texto.
## 2. EMPLEADO DE DEVON (objeto 19, Route116_EventScript_150A7B): regala una
##    ACOPIO BALL (REPEAT BALL) una sola vez y se va caminando hacia la izquierda
##    (si el jugador mira a la derecha, baja primero). Con la mochila llena avisa y
##    no se va.
## 3. EXCAVADOR (objeto 21, Route116_EventScript_150A49): tres textos según
##    FLAG_RECOVERED_DEVON_GOODS / FLAG_DEVON_GOODS_STOLEN (condicional de la
##    escena); con las PIEZAS recuperadas pasa a (41,12) (setobjectxyperm 21, 41, 10).
## 4. HOMBRE de las GAFAS (objeto 22, Route116_EventScript_150B8F): busca sus gafas.
##    Si el jugador lleva las GAFAS DE SOL, o ya recogió las ocultas de (70,15)
##    (FoundBlackGlasses), se rinde y se marcha caminando.
extends EventoGuionizado
class_name EventoRuta116

const MOTIVO_PAUSA: StringName = &"ruta_116"
const TipoMovimiento := NpcBase.TipoMovimientoNPC

const TEXTO_ARENQUE: String = "RUTA116_ARENQUE"
const TEXTO_EMPLEADO_INI: String = "RUTA116_EMPLEADO_DEVON_INI"
const TEXTO_EMPLEADO_REPETIDO: String = "RUTA116_EMPLEADO_DEVON_REPETIDO"
const TEXTO_EMPLEADO_TIENDA: String = "RUTA116_EMPLEADO_DEVON_TIENDA"
const TEXTO_EMPLEADO_MOCHILA: String = "RUTA116_EMPLEADO_DEVON_MOCHILA"
const TEXTO_GAFAS_PIDE: String = "RUTA116_GAFAS_PIDE"
const TEXTO_GAFAS_VER: String = "RUTA116_GAFAS_VER"
const TEXTO_GAFAS_NO_ESTAN: String = "RUTA116_GAFAS_NO_ESTAN"
const TEXTO_GAFAS_SOL: String = "RUTA116_GAFAS_SOL"
const TEXTO_GAFAS_SOL_NO_ESTAN: String = "RUTA116_GAFAS_SOL_NO_ESTAN"

## REPEAT BALL y BLACK_GLASSES en la tabla Objetos.
const OBJETO_ACOPIO_BALL: String = "ACOPIOBALL"
const OBJETO_GAFAS: String = "GAFASDESOL"

## Posición del objeto 21 en map.json: (38,9) de Rubí.
const EXCAVADOR_TRABAJA := Vector2i(38, 11)
## Route116_EventScript_150A41: setobjectxyperm 21, 41, 10.
const EXCAVADOR_RECUPERADO := Vector2i(41, 12)

const L := Vector2.LEFT
const R := Vector2.RIGHT
const U := Vector2.UP
const D := Vector2.DOWN

## Route116_Movement_150B1C: ocho pasos a la izquierda.
static var SALIDA_EMPLEADO: Array = _repetir(L, 8)
## Route116_Movement_150B25: baja y nueve pasos a la izquierda (el jugador mira a la derecha).
static var SALIDA_EMPLEADO_DERECHA: Array = [D] + _repetir(L, 9)
## Route116_Movement_150C4D.
static var SALIDA_GAFAS: Array = _repetir(L, 9)
## Route116_Movement_150C57.
static var SALIDA_GAFAS_DERECHA: Array = [U] + _repetir(L, 9)

@export var arenque: NodePath
@export var empleado_devon: NodePath
@export var excavador: NodePath
@export var hombre_gafas: NodePath

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
	_conectar(arenque, _on_arenque_hablado)
	_conectar(empleado_devon, _on_empleado_hablado)
	_conectar(hombre_gafas, _on_hombre_gafas_hablado)
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


## Route116_MapScript1_150A37 (ON_TRANSITION): con FLAG_RECOVERED_DEVON_GOODS el
## excavador espera en (41,12).
func preparar() -> void:
	if _en_curso:
		return
	var npc := _npc(excavador)
	if npc != null:
		npc.tipo_movimiento = TipoMovimiento.MIRAR_DERECHA
		colocar(npc, EXCAVADOR_RECUPERADO if HistoriaFervergal.piezas_recuperadas() else EXCAVADOR_TRABAJA)


## lock + faceplayer desde la interacción de un NPC.
func _comenzar_con(npc: Node2D) -> bool:
	if not comenzar(npc.nodo_administrador if npc.nodo_administrador != null else _administrador()):
		if npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return false
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()
	return true


## VAR_FACING: hacia dónde miraba el jugador al hablar.
func _mirada_jugador(npc: Node2D) -> Vector2:
	return npc.jugador.facing_direction if npc.jugador != null else D


func _tiene(objeto: String) -> bool:
	var bolsillo := int(SistemaGuardado.obtener_datos_objeto_completos(objeto).get("bolsillo_id", 0))
	return SistemaGuardado.get_cantidad_objeto(objeto, bolsillo) > 0


## ============================================================================
## SR. ARENQUE
## ============================================================================

func _on_disparador(id_evento: StringName) -> void:
	if id_evento == &"arenque_llora":
		_arenque_llora()


## Route116_EventScript_150B5D: lock, faceplayer, msgbox, VAR_ROUTE116_STATE 2.
func _on_arenque_hablado(npc: Node2D) -> void:
	if _en_curso or not _comenzar_con(npc):
		return
	await mensaje(TEXTO_ARENQUE)
	SistemaGuardado.set_contador(HistoriaFervergal.CONTADOR_RUTA_116, HistoriaFervergal.Ruta116.ARENQUE_HABLADO)
	terminar(false, [npc])


## Route116_EventScript_150B6E (coord_event (47,9) con VAR_ROUTE116_STATE 1): el SR.
## ARENQUE se gira a la derecha y el jugador a la izquierda.
func _arenque_llora() -> void:
	var npc := _npc(arenque)
	if _en_curso or npc == null or not npc.visible \
			or HistoriaFervergal.ruta_116() != HistoriaFervergal.Ruta116.ARENQUE_LLORANDO:
		return
	if not comenzar(_administrador()):
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	mirar(npc, R)
	girar_jugador(L)
	await mensaje(TEXTO_ARENQUE)
	SistemaGuardado.set_contador(HistoriaFervergal.CONTADOR_RUTA_116, HistoriaFervergal.Ruta116.ARENQUE_HABLADO)
	terminar(false, [npc])


## ============================================================================
## EMPLEADO DE DEVON
## ============================================================================

## Route116_EventScript_150A7B / 150A94 / 150B04.
func _on_empleado_hablado(npc: Node2D) -> void:
	if _en_curso:
		return
	var mirada := _mirada_jugador(npc)
	if not _comenzar_con(npc):
		return
	if SistemaGuardado.get_flag(HistoriaFervergal.BANDERA_EMPLEADO_CONOCIDO):
		await mensaje(TEXTO_EMPLEADO_REPETIDO, false)
	else:
		await mensaje(TEXTO_EMPLEADO_INI, false)
	SistemaGuardado.set_flag(HistoriaFervergal.BANDERA_EMPLEADO_CONOCIDO, true)
	if not await dar_objeto(npc, OBJETO_ACOPIO_BALL):
		await mensaje(TEXTO_EMPLEADO_MOCHILA)  # Route116_EventScript_150B12
		terminar(false, [npc])
		return
	await mensaje(TEXTO_EMPLEADO_TIENDA)
	await recorrer(npc, SALIDA_EMPLEADO_DERECHA if mirada == R else SALIDA_EMPLEADO)
	npc.visible = false  # removeobject VAR_LAST_TALKED
	# FLAG_RECEIVED_REPEAT_BALL; clearflag FLAG_HIDE_EMPLOYEE_DEVON_CORP_3F es lo mismo:
	# el empleado reaparece en DEVON 3F con esta bandera.
	SistemaGuardado.set_flag(HistoriaFervergal.BANDERA_ACOPIO_BALL, true)
	terminar(false, [npc])


## ============================================================================
## HOMBRE DE LAS GAFAS
## ============================================================================

## Route116_EventScript_150B8F.
func _on_hombre_gafas_hablado(npc: Node2D) -> void:
	if _en_curso:
		return
	var mirada := _mirada_jugador(npc)
	if not _comenzar_con(npc):
		return
	var encontradas := SistemaGuardado.get_flag(HistoriaFervergal.BANDERA_GAFAS_ENCONTRADAS)
	if _tiene(OBJETO_GAFAS):
		await mensaje(TEXTO_GAFAS_PIDE)
		await mensaje(TEXTO_GAFAS_VER)
		if not encontradas:
			await mensaje(TEXTO_GAFAS_SOL)  # Route116_EventScript_150BCA sin FoundBlackGlasses
			terminar(false, [npc])
			return
		await mensaje(TEXTO_GAFAS_SOL_NO_ESTAN)
	elif encontradas:
		await mensaje(TEXTO_GAFAS_NO_ESTAN)  # Route116_EventScript_150BBB
	else:
		await mensaje(TEXTO_GAFAS_PIDE)
		terminar(false, [npc])
		return
	await _gafas_se_va(npc, mirada)


## Route116_EventScript_150C03: delay 20, camina a la izquierda y desaparece.
func _gafas_se_va(npc: Node2D, mirada: Vector2) -> void:
	admin.cuadro_dialogo.cerrar()
	await esperar_fotogramas(20)
	await recorrer(npc, SALIDA_GAFAS_DERECHA if mirada == R else SALIDA_GAFAS)
	npc.visible = false  # removeobject VAR_LAST_TALKED (FLAG_HIDE_LOST_GLASSES_MAN)
	SistemaGuardado.set_flag(HistoriaFervergal.BANDERA_HOMBRE_GAFAS_SE_FUE, true)
	terminar(false, [npc])


static func _repetir(direccion: Vector2, veces: int) -> Array:
	var lista: Array = []
	for i in veces:
		lista.append(direccion)
	return lista

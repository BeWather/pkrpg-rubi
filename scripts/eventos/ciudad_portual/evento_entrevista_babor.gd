## evento_entrevista_babor.gd
## Entrevista al CAP. BABOR en CIUDAD PORTUAL (pokeruby data/maps/SlateportCity; Godot = Rubí + (0,0)).
## Con VAR_SLATEPORT_STATE == 1 (`portual_entrevista_babor`, la activa el robo del MONTE PÍRICO):
## OnTransition: MovePeopleForSternInterview coloca al público alrededor de la cámara y, sin la
##     bandera, cada NPC vuelve a su sitio de la escena.
## CaptStern: el jugador solo le alcanza desde (27,13), pues GABI y TEO ocupan el resto de los
##     lados y (28,12) es la puerta del PUERTO. Termina la entrevista, GABI y TEO se van, el
##     EQUIPO MAGMA habla por megáfono y BABOR y el jugador entran en el PUERTO (warp a (11,14)),
##     donde sigue EventoHuidaSubmarino.
extends EventoGuionizado
class_name EventoEntrevistaBabor

const MOTIVO_PAUSA: StringName = &"entrevista_babor"
const TipoMovimiento := NpcBase.TipoMovimientoNPC

## VAR_SLATEPORT_STATE == 1.
const BANDERA_ENTREVISTA: String = "portual_entrevista_babor"
## clearflag FLAG_HIDE_STERN_SLATEPORT_HARBOR.
const BANDERA_BABOR_PUERTO: String = "portual_puerto_babor_visible"

const MAPA_PUERTO: String = "ciudad_portual_puerto"
const LLEGADA_PUERTO := Vector2(11, 14)
const MUSICA_MAGMA: String = "EQUIPO_MAGMA_APARECE"  # MUS_EVIL_TEAM
const SONIDO_EXCLAMACION: String = "SE_PIN"

const TEXTO_SEGUIR_AVANZANDO: String = "PORTUAL_BABOR_ENTREVISTA_1"
const TEXTO_GABI_GRACIAS: String = "PORTUAL_BABOR_ENTREVISTA_2"
const TEXTO_PRIMERA_VEZ: String = "PORTUAL_BABOR_ENTREVISTA_3"
const TEXTO_DESCUBRIMIENTO: String = "PORTUAL_BABOR_ENTREVISTA_4"
const TEXTO_MEGAFONO: String = "PORTUAL_BABOR_ENTREVISTA_5"
const TEXTO_QUE_FUE: String = "PORTUAL_BABOR_ENTREVISTA_6"
const TEXTO_DEL_PUERTO: String = "PORTUAL_BABOR_ENTREVISTA_7"
const TEXTO_VEN_CONMIGO: String = "PORTUAL_BABOR_ENTREVISTA_8"

const FOTOGRAMAS_DELAY_16: int = 16
const FOTOGRAMAS_GABI_GIRA: int = 10
const FOTOGRAMAS_TEO_GIRA: int = 25
const FOTOGRAMAS_DELAY_48: int = 48

const L := Vector2.LEFT
const R := Vector2.RIGHT
const U := Vector2.UP
const D := Vector2.DOWN

## SlateportCity_Movement_GabbyExit (tras un delay_16) y TyExit.
static var GABI_SALE: Array = [L, L, D, L, L, L, L, L, L, L, L]
static var TEO_SALE: Array = [D, L, L, L, D, L, L, L, L, L, L, L, L]
## SlateportCity_Movement_SternEnterHarbor y PlayerEnterHarbor.
static var BABOR_ENTRA: Array = [R, U, U]
static var JUGADOR_ENTRA: Array = [R, U]

@export var babor: NodePath
@export var gabi: NodePath
@export var teo: NodePath
@export var anciana: NodePath  # objeto 7
@export var chico: NodePath  # objeto 3
@export var cocinero: NodePath  # objeto 6
@export var chica: NodePath  # objeto 8
@export var gordo: NodePath  # objeto 1
@export var hombre: NodePath  # objeto 2

## false omite el warp final (tests).
var con_warp: bool = true
## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null

## NPC del público → [celda, tipo_movimiento, rango] de la escena.
var _sitios_originales: Dictionary = {}
var _publico_colocado: bool = false


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var capitan := _npc(babor)
	if capitan != null and capitan.has_signal("hablado"):
		capitan.hablado.connect(_on_babor_hablado)
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(func(_por_warp: bool) -> void: preparar())
	preparar()


func _npc(ruta: NodePath) -> Node2D:
	return get_node_or_null(ruta) as Node2D


## setobjectxyperm + setobjectmovementtype de MovePeopleForSternInterview.
func _sitios_entrevista() -> Array:
	return [
		[anciana, Vector2i(25, 13), TipoMovimiento.MIRAR_DERECHA_ABAJO],
		[chico, Vector2i(25, 14), TipoMovimiento.MIRAR_ARRIBA_DERECHA],
		[cocinero, Vector2i(27, 16), TipoMovimiento.MIRAR_ARRIBA],
		[chica, Vector2i(28, 16), TipoMovimiento.MIRAR_ARRIBA],
		[gordo, Vector2i(29, 16), TipoMovimiento.MIRAR_ARRIBA],
		[hombre, Vector2i(31, 14), TipoMovimiento.MIRAR_IZQUIERDA],
	]


## OnTransition. Sin entrevista no toca a nadie: los mapas siguen instanciados y un NPC
## conserva su paseo al volver.
func preparar() -> void:
	if _en_curso:
		return
	if SistemaGuardado.get_flag(BANDERA_ENTREVISTA):
		_colocar_publico()
	elif _publico_colocado:
		_devolver_publico()


func _colocar_publico() -> void:
	for sitio: Array in _sitios_entrevista():
		var npc := _npc(sitio[0])
		if npc == null:
			continue
		if not _sitios_originales.has(npc):
			_sitios_originales[npc] = [npc.coord, npc.tipo_movimiento, npc.rango]
		_recolocar(npc, sitio[1], sitio[2], Vector2i.ZERO)
	_publico_colocado = true


func _devolver_publico() -> void:
	for npc: Node2D in _sitios_originales:
		var original: Array = _sitios_originales[npc]
		_recolocar(npc, original[0], original[1], original[2])
	_sitios_originales.clear()
	_publico_colocado = false


func _recolocar(npc: Node2D, celda: Vector2i, tipo: TipoMovimiento, rango: Vector2i) -> void:
	npc.tipo_movimiento = tipo
	npc.rango = rango
	colocar(npc, celda)
	npc.reinicializar_como_recien_agregado()


func _on_babor_hablado(npc: Node2D) -> void:
	var administrador_npc: Node = administrador if is_instance_valid(administrador) else npc.nodo_administrador
	if _en_curso or not comenzar(administrador_npc):
		if not _en_curso and npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	await _guion(npc)


## SlateportCity_EventScript_CaptStern.
func _guion(capitan: Node2D) -> void:
	var reportera := _npc(gabi)
	var camara := _npc(teo)
	await mensaje(TEXTO_SEGUIR_AVANZANDO)
	await mensaje(TEXTO_GABI_GRACIAS)
	admin.cuadro_dialogo.cerrar()
	mirar(reportera, R)
	await esperar_fotogramas(FOTOGRAMAS_GABI_GIRA)
	mirar(camara, D)
	await esperar_fotogramas(FOTOGRAMAS_TEO_GIRA)
	await en_paralelo([
		_babor_mira_salida.bind(capitan),
		_jugador_mira_a_babor,
		_salir.bind(reportera, FOTOGRAMAS_DELAY_16, GABI_SALE),
		_salir.bind(camara, 0, TEO_SALE),
	])
	await mensaje(TEXTO_PRIMERA_VEZ)
	mirar(capitan, U)
	await mensaje(TEXTO_DESCUBRIMIENTO)
	reproducir_musica(MUSICA_MAGMA)
	await mensaje(TEXTO_MEGAFONO)
	await _reaccion_del_publico()
	mirar(capitan, D)
	await mensaje(TEXTO_QUE_FUE)
	Singleton.play_sound.emit(SONIDO_EXCLAMACION)
	await exclamacion(capitan)
	await esperar_fotogramas(FOTOGRAMAS_DELAY_48)
	await mensaje(TEXTO_DEL_PUERTO)
	mirar(capitan, U)  # Common_Movement_FacePlayer: el jugador sigue en (27,13).
	await mensaje(TEXTO_VEN_CONMIGO)
	admin.cuadro_dialogo.cerrar()
	await en_paralelo([_babor_entra.bind(capitan), _jugador_entra])
	SistemaGuardado.set_flag(BANDERA_BABOR_PUERTO, true)
	SistemaGuardado.set_flag(BANDERA_ENTREVISTA, false)  # setvar VAR_SLATEPORT_STATE, 2
	_ir_al_puerto(capitan)


func _babor_mira_salida(capitan: Node2D) -> void:
	await esperar_fotogramas(FOTOGRAMAS_DELAY_16 * 5)
	await recorrer(capitan, [D, L])


func _jugador_mira_a_babor() -> void:
	await esperar_fotogramas(FOTOGRAMAS_DELAY_16 * 7)
	girar_jugador(D)


## removeobject al terminar el recorrido.
func _salir(npc: Node2D, espera: int, pasos: Array) -> void:
	await esperar_fotogramas(espera)
	await recorrer(npc, pasos)
	npc.visible = false


## applymovement del público mientras suena el megáfono.
func _reaccion_del_publico() -> void:
	mirar(_npc(cocinero), L)
	mirar(_npc(gordo), L)
	_npc(chico).mostrar_interrogacion.call()
	await en_paralelo([_anciana_preocupada, _hombre_preocupado])


## SlateportCity_Movement_OldWomanConcern.
func _anciana_preocupada() -> void:
	var npc := _npc(anciana)
	await esperar_fotogramas(FOTOGRAMAS_DELAY_16 * 2)
	npc.mostrar_interrogacion.call()
	mirar(npc, R)
	await esperar_fotogramas(FOTOGRAMAS_DELAY_16 * 2)
	mirar(npc, L)


## SlateportCity_Movement_ManConcern.
func _hombre_preocupado() -> void:
	var npc := _npc(hombre)
	npc.mostrar_interrogacion.call()
	mirar(npc, U)
	await esperar_fotogramas(FOTOGRAMAS_DELAY_16)
	mirar(npc, D)
	await esperar_fotogramas(FOTOGRAMAS_DELAY_16 * 2)
	mirar(npc, L)


## SternEnterHarbor termina con set_invisible; removeobject 11 al llegar.
func _babor_entra(capitan: Node2D) -> void:
	await recorrer(capitan, BABOR_ENTRA)
	capitan.visible = false


func _jugador_entra() -> void:
	girar_jugador(R)
	await esperar_fotogramas(FOTOGRAMAS_DELAY_16 * 2)
	await recorrer_jugador(JUGADOR_ENTRA)


## warp MAP_SLATEPORT_CITY_HARBOR, 255, 11, 14.
func _ir_al_puerto(capitan: Node2D) -> void:
	var admin_actual := admin
	terminar(true, [capitan])
	if not con_warp:
		return
	admin_actual.jugador.end_dialog()
	admin_actual.jugador.no_control = true
	admin_actual.conectar_escalera(MAPA_PUERTO, LLEGADA_PUERTO, U)

## evento_tunel_fervergal.gd
## Guiones del TÚNEL FERVERGAL (pokeruby data/maps/RusturfTunnel/scripts.inc). Las
## celdas de la escena coinciden 1:1 con las de Rubí.
##
## 1. Emboscada (RusturfTunnel_EventScript_15C9AB): con VAR_RUSTURF_TUNNEL_STATE 2 el
##    soldado MAGMA y PEEKO esperan en (13,5) y (13,4). Al pisar (9,4) o (9,5) el
##    soldado reta al jugador, los dos retroceden un paso a la derecha (de cara a él)
##    y quedan en (14,5) y (14,4) (estado 3).
## 2. Rescate de PEEKO (RusturfTunnel_EventScript_15C9EA): hablar con el soldado
##    (MUS_EVIL_TEAM), combate sin presentación, sus PIEZAS DEVON, huye hacia la
##    izquierda y llega el SR. ARENQUE de (5,4): agradece al jugador y se va con PEEKO.
##    Apaga FLAG_DEVON_GOODS_STOLEN y activa FLAG_RECOVERED_DEVON_GOODS.
## 3. MO04 (RusturfTunnel_EventScript_15C7D1): al romper una de las dos rocas con
##    GOLPE ROCA (el túnel sin abrir), el novio de CLARA da al jugador la MO04
##    FUERZA y los dos se van a PUEBLO VERDEGAL. El guion depende de la casilla desde
##    la que se rompió (VAR_TEMP_1 por los coord_events (23,4), (25,4) y (25,5)).
##    En Rubí lo lanza el estado 4/5 de TryUpdateRusturfTunnelState al final de
##    DoRockSmashMovement; aquí, la señal `rota` de la roca, cuando el jugador
##    recupera el control.
## 4. El novio (objeto 1) dice un texto la primera vez en cada visita (FLAG_TEMP_1) y
##    otro después.
extends EventoGuionizado
class_name EventoTunelFervergal

const MOTIVO_PAUSA: StringName = &"tunel_fervergal"
const TipoMovimiento := NpcBase.TipoMovimientoNPC

## TRAINER_RUSTURF_TUNNEL_GRUNT (TRAINER_GRUNT_42 en Rubí).
const ENTRENADOR_MAGMA: int = 581
const MUSICA_MAGMA: String = "EQUIPO_MAGMA_APARECE"  # MUS_EVIL_TEAM
const MUSICA_COMBATE: String = "TEAM_AQUA_MAGMA_BATTLE"
## SPECIES_WINGULL: número nacional del grito de PEEKO.
const GRITO_PEEKO: int = 278
const OBJETO_PIEZAS: String = "PIEZASDEVON"
const OBJETO_MO: String = "MO04"
## Ids de las rocas de la escena (FLAG_HIDE_RUSTURF_TUNNEL_ROCK_2 en (24,4) y
## FLAG_HIDE_RUSTURF_TUNNEL_ROCK_1 en (24,5)).
const IDS_ROCAS: Array[String] = ["roca_r116_1", "roca_r116_2"]
## Motivo de pausa de character.usar_golpe_roca.
const PAUSA_GOLPE_ROCA: StringName = &"golpe_roca"

const TEXTO_VIENES: String = "TUNEL_FERVERGAL_MAGMA_VIENES"
const TEXTO_RETO: String = "TUNEL_FERVERGAL_MAGMA_RETO"
const TEXTO_PIEZAS: String = "TUNEL_FERVERGAL_MAGMA_PIEZAS"
const TEXTO_ARENQUE_PEEKO: String = "TUNEL_FERVERGAL_ARENQUE_PEEKO"
const TEXTO_ARENQUE_GRACIAS: String = "TUNEL_FERVERGAL_ARENQUE_GRACIAS"
const TEXTO_NOVIO: String = "TUNEL_FERVERGAL_NOVIO"
const TEXTO_NOVIO_RUTA: String = "TUNEL_FERVERGAL_NOVIO_RUTA"
const TEXTO_ROCA_ROTA: String = "TUNEL_FERVERGAL_ROCA_ROTA"
const TEXTO_MO_FUERZA: String = "TUNEL_FERVERGAL_MO_FUERZA"
const TEXTO_CLARA: String = "TUNEL_FERVERGAL_CLARA"

## Posiciones de map.json (objetos 6 y 7) y las que fija TryOverrideTemplateCoords.
const MAGMA_ESPERA := Vector2i(13, 5)
const PEEKO_ESPERA := Vector2i(13, 4)
const MAGMA_EMBOSCADA := Vector2i(14, 5)
const PEEKO_EMBOSCADA := Vector2i(14, 4)
## Objeto 5: el SR. ARENQUE aparece aquí (addobject 5).
const ARENQUE_LLEGA := Vector2i(5, 4)
const NOVIO_ESPERA := Vector2i(23, 5)
const NOVIA_ESPERA := Vector2i(25, 4)

const L := Vector2.LEFT
const R := Vector2.RIGHT
const U := Vector2.UP
const D := Vector2.DOWN

## Coord_events de la roca (VAR_TEMP_1): id_evento del disparador → valor.
const CASILLAS_ROCA := {&"roca_oeste": 1, &"roca_este_arriba": 2, &"roca_este_abajo": 3}

@export var novio: NodePath
@export var novia: NodePath
@export var soldado_magma: NodePath
@export var peeko: NodePath
@export var arenque: NodePath
## Rocas del túnel (ControladorRocaRomper), en el orden de IDS_ROCAS.
@export var rocas: Array[NodePath] = []

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null
## VAR_TEMP_1: casilla desde la que se rompió la roca (0 = ninguna de las tres).
var _temp_1: int = 0
## FLAG_TEMP_1 del novio: ya habló en esta visita.
var _novio_hablado: bool = false


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for hijo in get_children():
		if hijo is DisparadorEventoPorTiles:
			hijo.evento_activado.connect(_on_disparador)
	_conectar(novio, _on_novio_hablado)
	_conectar(soldado_magma, _on_soldado_hablado)
	for ruta in rocas:
		var roca := get_node_or_null(ruta) as ControladorRocaRomper
		if roca != null:
			roca.rota.connect(_on_roca_rota)
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)
	preparar()


func _on_mapa_activado(_por_warp: bool) -> void:
	# FLAG_TEMP_*: se borran al entrar en el mapa.
	_temp_1 = 0
	_novio_hablado = false
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


## RusturfTunnel_MapScript1_15C762 (ON_TRANSITION): con VAR_RUSTURF_TUNNEL_STATE 2
## el soldado y PEEKO esperan una casilla antes (setobjectxyperm 7, 13, 4 y 6, 13, 5).
func preparar() -> void:
	if _en_curso:
		return
	var espera := HistoriaFervergal.tunel() == HistoriaFervergal.Tunel.PERSECUCION
	var npc_magma := _npc(soldado_magma)
	if npc_magma != null:
		npc_magma.tipo_movimiento = TipoMovimiento.MIRAR_IZQUIERDA
		colocar(npc_magma, MAGMA_ESPERA if espera else MAGMA_EMBOSCADA)
	var npc_peeko := _npc(peeko)
	if npc_peeko != null:
		npc_peeko.tipo_movimiento = TipoMovimiento.MIRAR_IZQUIERDA
		colocar(npc_peeko, PEEKO_ESPERA if espera else PEEKO_EMBOSCADA)
	var npc_arenque := _npc(arenque)
	if npc_arenque != null:
		colocar(npc_arenque, ARENQUE_LLEGA)


## lock + faceplayer desde la interacción de un NPC.
func _comenzar_con(npc: Node2D) -> bool:
	if not comenzar(npc.nodo_administrador if npc.nodo_administrador != null else _administrador()):
		if npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return false
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()
	return true


func _on_disparador(id_evento: StringName) -> void:
	if CASILLAS_ROCA.has(id_evento):
		_temp_1 = CASILLAS_ROCA[id_evento]  # RusturfTunnel_EventScript_15C999 / 99F / 9A5
	elif id_evento == &"emboscada" and not _en_curso \
			and HistoriaFervergal.tunel() == HistoriaFervergal.Tunel.PERSECUCION:
		_emboscada()


## ============================================================================
## EMBOSCADA
## ============================================================================

## RusturfTunnel_EventScript_15C9AB.
func _emboscada() -> void:
	var npc_magma := _npc(soldado_magma)
	var npc_peeko := _npc(peeko)
	if npc_magma == null or npc_peeko == null or not comenzar(_administrador()):
		return
	await mensaje(TEXTO_VIENES)
	# RusturfTunnel_Movement_15C9D3: walk_right sin dejar de mirar a la izquierda.
	await en_paralelo([_retroceder.bind(npc_magma), _retroceder.bind(npc_peeko)])
	colocar(npc_magma, MAGMA_EMBOSCADA)  # moveobjectoffscreen: la nueva celda es la de origen
	colocar(npc_peeko, PEEKO_EMBOSCADA)
	npc_magma.update_direction(L)
	npc_peeko.update_direction(L)
	SistemaGuardado.set_contador(HistoriaFervergal.CONTADOR_TUNEL, HistoriaFervergal.Tunel.EMBOSCADA_VISTA)
	terminar(false, [npc_magma, npc_peeko])


func _retroceder(npc: Node2D) -> void:
	await caminar(npc, R, NpcBase.VelocidadPaso.NORMAL, L)


## ============================================================================
## RESCATE DE PEEKO
## ============================================================================

## RusturfTunnel_EventScript_15C9EA.
func _on_soldado_hablado(npc: Node2D) -> void:
	if _en_curso or not _comenzar_con(npc):
		return
	reproducir_musica(MUSICA_MAGMA)
	await mensaje(TEXTO_RETO)
	# trainerbattle_no_intro: el texto de derrota sale del combate (frase_derrota).
	var resultado := await combatir(ENTRENADOR_MAGMA, MUSICA_COMBATE)
	if resultado != &"victoria":
		terminar(resultado == &"derrota_transferida", [npc])
		preparar()
		return
	await mensaje(TEXTO_PIEZAS, false)
	await dar_objeto(npc, OBJETO_PIEZAS)  # giveitem ITEM_DEVON_GOODS
	admin.cuadro_dialogo.cerrar()  # closemessage
	# RusturfTunnel_Movement_15CA99 (jugador) y 15CAA2 (soldado, 9 × walk_fast_left).
	await en_paralelo([_jugador_se_aparta, recorrer.bind(npc, _repetir(L, 9), VelocidadPaso.RAPIDO)])
	npc.visible = false  # removeobject 6
	await esperar_fotogramas(50)  # delay 50
	var npc_arenque := _npc(arenque)
	if npc_arenque != null:
		await _llega_arenque(npc_arenque)
	var npc_peeko := _npc(peeko)
	var salidas: Array[Callable] = []
	if npc_arenque != null:
		salidas.append(recorrer.bind(npc_arenque, _repetir(L, 11)))  # 15CAB4
	if npc_peeko != null:
		salidas.append(recorrer.bind(npc_peeko, _repetir(L, 9)))  # 15CAC3
	await en_paralelo(salidas)
	if npc_arenque != null:
		npc_arenque.visible = false  # removeobject 5
	if npc_peeko != null:
		npc_peeko.visible = false  # removeobject 7
	HistoriaFervergal.recuperar_piezas()
	restaurar_musica_mapa()
	terminar(false, [npc, npc_arenque, npc_peeko])


## addobject 5 y el diálogo con el SR. ARENQUE.
func _llega_arenque(npc_arenque: Node2D) -> void:
	colocar(npc_arenque, ARENQUE_LLEGA)
	npc_arenque.update_direction(R)
	npc_arenque.visible = true
	await recorrer(npc_arenque, _repetir(R, 7))  # 15CAAC
	# 15CA9F (jugador baja y mira arriba) y 15CAC0 (delay_16 y un paso a la derecha).
	await en_paralelo([_jugador_baja, _arenque_junto_a_peeko.bind(npc_arenque)])
	await mensaje(TEXTO_ARENQUE_PEEKO)
	npc_arenque.mirar_jugador()  # Common_Movement_FacePlayer
	await _mensaje_con_grito(TEXTO_ARENQUE_GRACIAS)


func _jugador_se_aparta() -> void:
	# face_down, lock_facing_direction, walk_up, unlock, walk_in_place_fastest_left.
	girar_jugador(D)
	await retroceder_jugador(U)
	girar_jugador(L)


func _jugador_baja() -> void:
	await recorrer_jugador([D])
	girar_jugador(U)


func _arenque_junto_a_peeko(npc_arenque: Node2D) -> void:
	await esperar_fotogramas(16)
	await caminar(npc_arenque, R)


## message + waitmessage + waitse + playmoncry + waitbuttonpress + waitmoncry +
## closemessage: el texto se escribe entero, suena el grito de PEEKO y se espera A.
func _mensaje_con_grito(clave: String) -> void:
	var pendiente := [true]
	var al_terminar := func() -> void: pendiente[0] = false
	var cuadro: Node = admin.cuadro_dialogo
	cuadro.mostrar(tr(clave), false, false, al_terminar, false, cuadro.esta_activo)
	while pendiente[0]:
		await get_tree().process_frame
	var reproductor: Variant = grito(GRITO_PEEKO)
	if con_gritos:
		await _esperar_boton()
	await esperar_grito(reproductor)
	cuadro.cerrar()


## waitbuttonpress.
func _esperar_boton() -> void:
	await get_tree().process_frame
	while not (Input.is_action_just_pressed("btn_accion") or Input.is_action_just_pressed("btn_cancelar")):
		await get_tree().process_frame


## ============================================================================
## NOVIO DE CLARA
## ============================================================================

## RusturfTunnel_EventScript_15C799.
func _on_novio_hablado(npc: Node2D) -> void:
	if _en_curso or not _comenzar_con(npc):
		return
	if _novio_hablado:
		await mensaje(TEXTO_NOVIO_RUTA)
	else:
		_novio_hablado = true
		await mensaje(TEXTO_NOVIO)
	mirar(npc, npc.direccion_base)  # Common_Movement_FaceOriginalDirection
	terminar(false, [npc])


## ============================================================================
## MO04 FUERZA
## ============================================================================

## TryUpdateRusturfTunnelState: con el túnel sin abrir, romper cualquiera de las
## dos rocas lanza el guion en cuanto termina el golpe de roca.
func _on_roca_rota() -> void:
	if _en_curso or HistoriaFervergal.tunel_abierto():
		return
	while not _jugador_libre():
		if not is_inside_tree():
			return
		await get_tree().process_frame
	if not _en_curso and not HistoriaFervergal.tunel_abierto():
		entregar_mo_fuerza()


## El jugador está en este mapa, con control y sin el golpe de roca en marcha.
func _jugador_libre() -> bool:
	var mapa := obtener_mapa()
	var adm := _administrador()
	if adm == null or mapa == null or adm.get("mapa_actual") != mapa:
		return false
	var jugador: Node = adm.get("jugador")
	return jugador != null and jugador.get("no_control") != true and jugador.get("paso_en_curso") != true 			and not Singleton.motivos_pausa().has(PAUSA_GOLPE_ROCA)


## FLAG_HIDE_RUSTURF_TUNNEL_ROCK_1 o _2.
static func hay_roca_rota() -> bool:
	for id in IDS_ROCAS:
		if ControladorRocaRomper.esta_rota(id):
			return true
	return false


## RusturfTunnel_EventScript_15C7D1. `_temp_1` es la casilla desde la que se rompió.
func entregar_mo_fuerza() -> void:
	var npc_novio := _npc(novio)
	var npc_novia := _npc(novia)
	if npc_novio == null or npc_novia == null or not comenzar(_administrador()):
		return
	var caso := _temp_1
	for npc in [npc_novio, npc_novia]:
		npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	match caso:
		1:  # 15C8CA: se miran
			mirar(npc_novio, U)
			girar_jugador(D)
		2:  # 15C8DF
			await caminar(npc_novio, U)
			mirar(npc_novio, R)
	# 15C92D: playse SE_PIN, exclamación y Common_Movement_Delay48.
	Singleton.play_sound.emit("SE_PIN")
	await exclamacion(npc_novio)
	await esperar_fotogramas(48)
	await mensaje(TEXTO_ROCA_ROTA)
	if caso == 2 or caso == 3:  # 15C8EB
		await caminar(npc_novio, R)
	if await dar_objeto(npc_novio, OBJETO_MO):  # giveitem ITEM_HM04_STRENGTH
		SistemaGuardado.set_flag(HistoriaFervergal.BANDERA_MO04, true)
	await mensaje(TEXTO_MO_FUERZA)
	match caso:
		1:  # 15C880
			await en_paralelo([_jugador_oeste, _novio_oeste.bind(npc_novio)])
		2, 3:  # 15C892 / 15C8AE
			await en_paralelo([_jugador_este, _novio_este.bind(npc_novio)])
			mirar(npc_novia, D)
	await mensaje(TEXTO_CLARA)
	# 15C8F7 / 15C909 / 15C91B: se van juntos por la salida a PUEBLO VERDEGAL.
	var pasos_novia: Array = _repetir(R, 4) + _repetir(D, 7)
	var pasos_novio: Array = _repetir(R, 5) + _repetir(D, 7) if caso == 1 \
			else [U] + _repetir(R, 4) + _repetir(D, 7)
	if caso != 0:
		await en_paralelo([recorrer.bind(npc_novia, pasos_novia), recorrer.bind(npc_novio, pasos_novio)])
	# RusturfTunnel_EventScript_SetRusturfTunnelOpen: removeobject 1 y 10.
	npc_novio.visible = false
	npc_novia.visible = false
	HistoriaFervergal.abrir_tunel()
	terminar(false, [npc_novio, npc_novia])


## RusturfTunnel_Movement_15C96A.
func _jugador_oeste() -> void:
	await recorrer_jugador([L])
	girar_jugador(R)


## RusturfTunnel_Movement_15C96D.
func _jugador_este() -> void:
	await recorrer_jugador([R])
	girar_jugador(L)


## RusturfTunnel_Movement_15C98F: dos pasos en el sitio, sube y va a la derecha.
func _novio_oeste(npc: Node2D) -> void:
	await trotar_en_sitio(npc, U, 2, 8)
	await caminar(npc, U, VelocidadPaso.RAPIDO)
	await caminar(npc, R, VelocidadPaso.RAPIDO)


## RusturfTunnel_Movement_15C994: dos pasos en el sitio, a la derecha y mira arriba.
func _novio_este(npc: Node2D) -> void:
	await trotar_en_sitio(npc, R, 2, 8)
	await caminar(npc, R, VelocidadPaso.RAPIDO)
	mirar(npc, U)


static func _repetir(direccion: Vector2, veces: int) -> Array:
	var lista: Array = []
	for i in veces:
		lista.append(direccion)
	return lista

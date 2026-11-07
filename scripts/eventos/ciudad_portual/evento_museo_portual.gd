## evento_museo_portual.gd
## Guiones del MUSEO OCEÁNICO de CIUDAD PORTUAL (pokeruby data/maps/
## SlateportCity_OceanicMuseum_1F y _2F). Las dos plantas están en una sola escena, la
## 2F apilada encima de la 1F: Godot (x, y) = Rubí (x, y) en la 1F y (x, y - 14) en la 2F.
##
## 1F: la ENTRADA (coord_events (9,7) y (10,7) con VAR_SLATEPORT_MUSEUM_1F_STATE == 0) cobra
##     50$ con SÍ/NO. Sin dinero: antes de entregar las PIEZAS DEVON (FLAG_DELIVERED_DEVON_GOODS)
##     le dejan pasar «con su grupo»; después, no. La variable de Rubí la reinicia la entrada
##     de CIUDAD PORTUAL (OnTransition): aquí, al llegar por las puertas (9,8) y (10,8).
##     El SOLDADO conocido (objeto 13) te da la MT46 y huye de la sala.
## 2F: CAP. BABOR (objeto 1) recibe las PIEZAS y el EQUIPO MAGMA las reclama: dos soldados
##     (objetos 3 y 4, TRAINER_MUSEUM_2F_GRUNT_1 y _2) combaten, MAGNO (objeto 2, VAR_6) los
##     reprende y te advierte, el equipo se va y BABOR te da las gracias y se marcha.
##     Al terminar: los soldados de la 1F desaparecen, `ruta_110_soldados_ocultos`
##     (FLAG_HIDE_EVIL_TEAM_ROUTE110) y `piezas_devon_entregadas` (FLAG_DELIVERED_DEVON_GOODS).
##     Perder deja la escena sin hacer: los tres actores vuelven a estar ocultos.
extends EventoGuionizado
class_name EventoMuseoPortual

const MOTIVO_PAUSA: StringName = &"museo_portual"
const TipoMovimiento := NpcBase.TipoMovimientoNPC

## VAR_SLATEPORT_MUSEUM_1F_STATE == 1.
const BANDERA_ENTRADA_PAGADA: String = "museo_portual_entrada_pagada"
## FLAG_HIDE_EVIL_TEAM_OCEANIC_MUSEUM (soldados de la 1F), FLAG_HIDE_STERN_OCEANIC_MUSEUM_2F y
## FLAG_HIDE_SCARED_GRUNT_OCEANIC_MUSEUM. Las tres empiezan sin activar (todos visibles).
const BANDERA_EQUIPO_OCULTO: String = "museo_portual_equipo_oculto"
const BANDERA_BABOR_OCULTO: String = "museo_portual_babor_oculto"
const BANDERA_ASUSTADO_OCULTO: String = "museo_portual_asustado_oculto"
## FLAG_RECEIVED_TM46.
const BANDERA_MT46: String = "museo_portual_mt46_recibida"
## FLAG_HIDE_EVIL_TEAM_ROUTE110 (la usa ruta_110.tscn) y FLAG_DELIVERED_DEVON_GOODS.
const BANDERA_RUTA_110: String = "ruta_110_soldados_ocultos"
const BANDERA_PIEZAS_ENTREGADAS: String = "piezas_devon_entregadas"

const PRECIO_ENTRADA: int = 50
const OBJETO_MT46: String = "MT46"
const OBJETO_PIEZAS: String = "PIEZASDEVON"
## TRAINER_MUSEUM_2F_GRUNT_1 y _2 de Rubí (TRAINER_GRUNT_46 y _47).
const ENTRENADOR_SOLDADO_1: int = 585
const ENTRENADOR_SOLDADO_2: int = 586
const MUSICA_MAGMA: String = "EQUIPO_MAGMA_APARECE"  # MUS_EVIL_TEAM
const MUSICA_COMBATE: String = "EQUIPO_AQUA_MAGMA_BATALLA"
const SONIDO_EXCLAMACION: String = "SE_PIN"
const SONIDO_SALIDA: String = "puerta_salida"  # SE_EXIT

const TEXTO_ENTRADA: String = "PORTUAL_MUSEO_ENTRADA"
const TEXTO_DISFRUTA: String = "PORTUAL_MUSEO_DISFRUTA"
const TEXTO_SIN_DINERO: String = "PORTUAL_MUSEO_SIN_DINERO"
const TEXTO_GRUPO: String = "PORTUAL_MUSEO_GRUPO"
const TEXTO_ASUSTADO: String = "PORTUAL_MUSEO_ASUSTADO"
const TEXTO_ASUSTADO_DESPEDIDA: String = "PORTUAL_MUSEO_ASUSTADO_DESPEDIDA"
const TEXTO_ASUSTADO_SIN_ESPACIO: String = "PORTUAL_MUSEO_ASUSTADO_SIN_ESPACIO"
const TEXTO_BABOR_PIEZAS: String = "PORTUAL_MUSEO_2F_BABOR_PIEZAS"
const TEXTO_SOLDADO_ALTO: String = "PORTUAL_MUSEO_2F_SOLDADO_ALTO"
const TEXTO_BABOR_QUIENES: String = "PORTUAL_MUSEO_2F_BABOR_QUIENES"
const TEXTO_SOLDADO_SOMOS: String = "PORTUAL_MUSEO_2F_SOLDADO_SOMOS"
const TEXTO_SOLDADO_FURIOSO: String = "PORTUAL_MUSEO_2F_SOLDADO_FURIOSO"
const TEXTO_SOLDADO_ME_OCUPO: String = "PORTUAL_MUSEO_2F_SOLDADO_ME_OCUPO"
const TEXTO_SOLDADO_ENTROMETIDO: String = "PORTUAL_MUSEO_2F_SOLDADO_ENTROMETIDO"
const TEXTO_MAGNO_VENGO: String = "PORTUAL_MUSEO_2F_MAGNO_VENGO"
const TEXTO_MAGNO_ADVERTENCIA: String = "PORTUAL_MUSEO_2F_MAGNO_ADVERTENCIA"
const TEXTO_BABOR_GRACIAS: String = "PORTUAL_MUSEO_2F_BABOR_GRACIAS"
const TEXTO_BABOR_ENTREGA: String = "PORTUAL_MUSEO_2F_BABOR_ENTREGA"
const TEXTO_BABOR_SE_VA: String = "PORTUAL_MUSEO_2F_BABOR_SE_VA"

## La 2F empieza en la fila -14 (filas -14..-6).
const DESFASE_2F: int = -14
## Rubí (6,1) de la 2F: donde aparecen MAGNO y sus soldados (la escalera).
const CELDA_ESCALERA_2F := Vector2i(6, 1 + DESFASE_2F)
## Filas de las puertas de la 1F: llegar a ellas es entrar en CIUDAD PORTUAL → MUSEO.
const FILA_PUERTAS: int = 8
const FOTOGRAMAS_DELAY_16: int = 16
const FOTOGRAMAS_DELAY_8: int = 8

const L := Vector2.LEFT
const R := Vector2.RIGHT
const U := Vector2.UP
const D := Vector2.DOWN

## SlateportCity_OceanicMuseum_2F_EventScript_SternLeave (Rubí → mismas direcciones).
static var BABOR_SE_VA: Array = [U, L, L, L, L, L, U, U, L, L, U, U]
## ..._Movement_FamiliarGruntExitNorth / ExitSouth (walk_fast_*).
static var ASUSTADO_SALIDA_NORTE: Array = [R, D, D, D, D]
static var ASUSTADO_SALIDA_SUR: Array = [D, D, D, D]

@export var babor: NodePath
@export var magno: NodePath
@export var soldado_a: NodePath  # objeto 3 (FirstGrunt)
@export var soldado_b: NodePath  # objeto 4 (SecondGrunt)
@export var soldado_asustado: NodePath

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
	_conectar(babor, _on_babor_hablado)
	_conectar(soldado_asustado, _on_asustado_hablado)
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)
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


## Celda a la que llega el jugador al activarse el mapa. Con un warp en curso
## (mapa_activado llega con el telón negro, antes de teletransportarle) cuenta la
## celda de destino del warp.
func _celda_llegada() -> Vector2i:
	var adm := _administrador()
	var jugador: Node = adm.get("jugador") if adm != null else null
	if jugador == null:
		return Vector2i(-1000, -1000)
	var celda: Vector2i = jugador.pos_celda_act
	if int(adm.get("coneccion")) != 0 and adm.get("coneccion_posicion") is Vector2:
		var destino: Vector2 = adm.get("coneccion_posicion")
		celda = Vector2i(int(floorf(destino.x)), int(floorf(destino.y)))
	return celda


func _on_mapa_activado(_por_warp: bool) -> void:
	# SlateportCity_OnTransition: VAR_SLATEPORT_MUSEUM_1F_STATE = 0 al volver a la ciudad.
	if _celda_llegada().y == FILA_PUERTAS:
		SistemaGuardado.set_flag(BANDERA_ENTRADA_PAGADA, false)
	preparar()


## OnTransition: MAGNO y los dos soldados de la 2F (FLAG_HIDE_* activas desde el principio)
## y BABOR en su sitio.
func preparar() -> void:
	if _en_curso:
		return
	for ruta in [magno, soldado_a, soldado_b]:
		var actor := _npc(ruta)
		if actor != null:
			actor.visible = false
			colocar(actor, CELDA_ESCALERA_2F)
			actor.tipo_movimiento = TipoMovimiento.MIRAR_ABAJO


func _comenzar_con(npc: Node2D) -> bool:
	var administrador_npc: Node = npc.nodo_administrador if npc.nodo_administrador != null else _administrador()
	if _en_curso or not comenzar(administrador_npc):
		if not _en_curso and npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return false
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	return true


## ============================================================================
## ENTRADA (1F)
## ============================================================================

func _on_disparador(id_evento: StringName) -> void:
	if _en_curso or SistemaGuardado.get_flag(BANDERA_ENTRADA_PAGADA):
		return
	match id_evento:
		&"entrada_izquierda":
			cobrar_entrada(L)  # PayEntranceFeeLeft
		&"entrada_derecha":
			cobrar_entrada(R)  # PayEntranceFeeRight


## PayEntranceFee (lockall; showmoneybox al principio, updatemoneybox tras cobrar y
## hidemoneybox al salir por cualquier rama).
func cobrar_entrada(mirada: Vector2) -> void:
	if not comenzar(_administrador()):
		return
	girar_jugador(mirada)
	mostrar_cuadro_dinero()
	if not await preguntar_si_no(TEXTO_ENTRADA):
		ocultar_cuadro_dinero()
		await _echar_al_jugador()
		terminar()
		return
	if SistemaGuardado.get_dinero_jugador() >= PRECIO_ENTRADA:
		SistemaGuardado.quitar_dinero_jugador(PRECIO_ENTRADA)
		actualizar_cuadro_dinero()
		await mensaje(TEXTO_DISFRUTA)
		SistemaGuardado.set_flag(BANDERA_ENTRADA_PAGADA, true)
		ocultar_cuadro_dinero()
	elif not SistemaGuardado.get_flag(BANDERA_PIEZAS_ENTREGADAS):
		# AllowEntranceAnyway: «¿Vienes con el grupo que entró justo antes?».
		await mensaje(TEXTO_GRUPO)
		SistemaGuardado.set_flag(BANDERA_ENTRADA_PAGADA, true)
		ocultar_cuadro_dinero()
	else:
		await mensaje(TEXTO_SIN_DINERO)
		ocultar_cuadro_dinero()
		await _echar_al_jugador()
	terminar()


## PushPlayerBackFromCounter: walk_down.
func _echar_al_jugador() -> void:
	admin.cuadro_dialogo.cerrar()
	await recorrer_jugador([D])


## ============================================================================
## SOLDADO CONOCIDO (1F, objeto 13)
## ============================================================================

func _on_asustado_hablado(npc: Node2D) -> void:
	if not _comenzar_con(npc):
		return
	var mirada: Vector2 = admin.jugador.facing_direction  # VAR_FACING
	npc.mirar_jugador()  # faceplayer
	await esperar_fotogramas(FOTOGRAMAS_DELAY_8)
	Singleton.play_sound.emit(SONIDO_EXCLAMACION)
	await exclamacion(npc)
	await esperar_fotogramas(48)  # Common_Movement_Delay48
	await mensaje(TEXTO_ASUSTADO, false)
	if not await dar_objeto(npc, OBJETO_MT46):  # giveitem ITEM_TM46_THIEF
		await mensaje(TEXTO_ASUSTADO_SIN_ESPACIO)
		terminar(false, [npc])
		return
	SistemaGuardado.set_flag(BANDERA_MT46, true)
	await mensaje(TEXTO_ASUSTADO_DESPEDIDA)
	admin.cuadro_dialogo.cerrar()
	var rapido := VelocidadPaso.RAPIDO
	if mirada == U:  # VAR_FACING == 2 → ExitNorth
		await recorrer(npc, ASUSTADO_SALIDA_NORTE, rapido)
	else:
		mirar(npc, D)
		await recorrer(npc, ASUSTADO_SALIDA_SUR, rapido)
	await esperar_fotogramas(FOTOGRAMAS_DELAY_8)
	Singleton.play_sound.emit(SONIDO_SALIDA)
	npc.visible = false  # removeobject 13
	SistemaGuardado.set_flag(BANDERA_ASUSTADO_OCULTO, true)
	terminar(false, [npc])


## ============================================================================
## CAP. BABOR y el EQUIPO MAGMA (2F)
## ============================================================================

func _on_babor_hablado(npc: Node2D) -> void:
	if not _comenzar_con(npc):
		return
	await robo_de_piezas(npc)


## SlateportCity_OceanicMuseum_2F_EventScript_CaptStern (lock + faceplayer).
func robo_de_piezas(npc_babor: Node2D) -> void:
	var mirada: Vector2 = admin.jugador.facing_direction  # VAR_FACING
	var primero := _npc(soldado_a)  # objeto 3
	var segundo := _npc(soldado_b)  # objeto 4
	var jefe := _npc(magno)  # objeto 2
	npc_babor.mirar_jugador()
	await mensaje(TEXTO_BABOR_PIEZAS)
	reproducir_musica(MUSICA_MAGMA)
	for actor in [primero, segundo, jefe]:
		actor.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	# addobject 3 + FirstGruntEnter; addobject 4 + SecondGruntEnter.
	_aparecer(primero)
	await recorrer(primero, [D, R])
	mirar(primero, D)
	_aparecer(segundo)
	await caminar(segundo, D)
	# FirstGruntApproach / SecondGruntApproach: los dos a la vez.
	await en_paralelo([
		_tramo.bind(primero, [D, D, D, R, R, R], 0),
		_tramo.bind(segundo, [D, D, D, D, R, R, R, R], 0),
	])
	if mirada == D or mirada == R:
		girar_jugador(L)  # PlayerFaceGrunts
	await mensaje(TEXTO_SOLDADO_ALTO)
	if mirada != R:
		mirar(npc_babor, L)  # SternFaceGrunts
	await mensaje(TEXTO_BABOR_QUIENES)
	await mensaje(TEXTO_SOLDADO_SOMOS)
	admin.cuadro_dialogo.cerrar()
	await caminar(segundo, R)  # GruntApproachToBattle
	if mirada == D:
		await recorrer_jugador([L, D])  # PlayerApproachGruntSouth
		girar_jugador(L)
	elif mirada == L:
		await recorrer_jugador([U, L, L, D])  # PlayerApproachGruntWest
		girar_jugador(L)
	var resultado := await combatir(ENTRENADOR_SOLDADO_1, MUSICA_COMBATE)
	if resultado != &"victoria":
		_perder(resultado, [npc_babor, primero, segundo, jefe])
		return
	# Al cerrar el combate se restaura el tema del mapa; Rubí vuelve al guardado
	# (MUS_EVIL_TEAM) y solo `savebgm 0` antes del segundo combate lo cambia por el
	# del mapa: tras el soldado 1 sigue sonando el equipo MAGMA.
	reproducir_musica(MUSICA_MAGMA)
	await mensaje(TEXTO_SOLDADO_FURIOSO)
	admin.cuadro_dialogo.cerrar()
	await caminar(segundo, L, NpcBase.VelocidadPaso.NORMAL, R)  # GruntDefeated (lock_facing)
	await caminar(primero, R)  # GruntApproachToBattle
	await mensaje(TEXTO_SOLDADO_ME_OCUPO)
	resultado = await combatir(ENTRENADOR_SOLDADO_2, MUSICA_COMBATE)
	if resultado != &"victoria":
		_perder(resultado, [npc_babor, primero, segundo, jefe])
		return
	await caminar(primero, L, NpcBase.VelocidadPaso.NORMAL, R)  # GruntDefeated
	mirar(primero, D)
	mirar(segundo, U)
	await mensaje(TEXTO_SOLDADO_ENTROMETIDO)
	admin.cuadro_dialogo.cerrar()
	await esperar_fotogramas(35)
	# addobject 2: MAGNO baja por la escalera mientras el soldado le deja paso.
	_aparecer(jefe)
	await en_paralelo([
		_tramo.bind(jefe, [D, D, D, D, D, R, R, R, R], 0),
		_dejar_paso.bind(segundo),
	])
	await mensaje(TEXTO_MAGNO_VENGO)
	await caminar(jefe, R)  # EvilLeaderApproachPlayer
	await mensaje(TEXTO_MAGNO_ADVERTENCIA)
	admin.cuadro_dialogo.cerrar()
	await oscurecer_pantalla()
	for actor in [jefe, primero, segundo]:  # removeobject 2, 3 y 4
		actor.visible = false
	await aclarar_pantalla()
	await esperar_fotogramas(30)
	_ocultar_equipo()  # setflag FLAG_HIDE_EVIL_TEAM_OCEANIC_MUSEUM
	girar_jugador(R)
	await mensaje(TEXTO_BABOR_GRACIAS)
	await _entregar_piezas()
	await mensaje(TEXTO_BABOR_SE_VA)
	admin.cuadro_dialogo.cerrar()
	await recorrer(npc_babor, BABOR_SE_VA)  # SternLeave
	await esperar_fotogramas(FOTOGRAMAS_DELAY_8)
	Singleton.play_sound.emit(SONIDO_SALIDA)
	npc_babor.visible = false  # removeobject 1
	SistemaGuardado.set_flag(BANDERA_BABOR_OCULTO, true)
	SistemaGuardado.set_flag(BANDERA_RUTA_110, true)  # FLAG_HIDE_EVIL_TEAM_ROUTE110
	SistemaGuardado.set_flag(BANDERA_PIEZAS_ENTREGADAS, true)  # FLAG_DELIVERED_DEVON_GOODS
	restaurar_musica_mapa()
	terminar(false, [npc_babor, primero, segundo, jefe])


## addobject: el actor aparece en la escalera de la 2F mirando abajo.
func _aparecer(actor: Node2D) -> void:
	colocar(actor, CELDA_ESCALERA_2F)
	mirar(actor, D)
	actor.visible = true
	actor.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)


## Los pasos de `actor` tras una pausa opcional (delay_16 …).
func _tramo(actor: Node2D, direcciones: Array, demora: int) -> void:
	if demora > 0:
		await esperar_fotogramas(demora)
	await recorrer(actor, direcciones)


## SlateportCity_OceanicMuseum_2F_Movement_GruntMoveForEvilLeader: ocho delay_16 y un
## delay_8, un paso rápido hacia abajo y mira arriba.
func _dejar_paso(soldado: Node2D) -> void:
	await esperar_fotogramas(8 * FOTOGRAMAS_DELAY_16 + FOTOGRAMAS_DELAY_8)
	await caminar(soldado, D, VelocidadPaso.RAPIDO)
	mirar(soldado, U)


## Common_EventScript_PlayerHandedOverTheItem: fanfarria de MT/MO, «¡{PN} entregó X!» y
## removeitem (si el jugador no lleva las PIEZAS no pierde nada: Rubí no lo comprueba).
func _entregar_piezas() -> void:
	var datos: Dictionary = SistemaGuardado.obtener_datos_objeto_completos(OBJETO_PIEZAS)
	await mensaje_con_fanfarria(TEXTO_BABOR_ENTREGA, Fanfarria.TEMA_MT_MO,
			{"{objeto}": str(datos.get("nombre", OBJETO_PIEZAS))})
	SistemaGuardado.quitar_objeto_jugador(OBJETO_PIEZAS, 1, int(datos.get("bolsillo_id", 0)))


## setflag FLAG_HIDE_EVIL_TEAM_OCEANIC_MUSEUM: los soldados de la 1F desaparecen.
func _ocultar_equipo() -> void:
	SistemaGuardado.set_flag(BANDERA_EQUIPO_OCULTO, true)
	var mapa := obtener_mapa()
	var npcs: Node = mapa.get_node_or_null("NPCs") if mapa != null else null
	if npcs == null:
		return
	for npc in npcs.get_children():
		if npc.has_method("aplicar_bandera_ocultar") and str(npc.get("bandera_ocultar")) == BANDERA_EQUIPO_OCULTO:
			npc.aplicar_bandera_ocultar()


## Derrota (o combate rechazado): nada cambia y los actores vuelven a estar fuera.
func _perder(resultado: StringName, actores: Array) -> void:
	terminar(resultado == &"derrota_transferida", actores)
	preparar()
	var npc_babor: Node2D = actores[0]
	if is_instance_valid(npc_babor):
		mirar(npc_babor, D)

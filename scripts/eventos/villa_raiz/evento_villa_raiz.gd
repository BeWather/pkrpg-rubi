## evento_villa_raiz.gd
## Guiones del exterior de VILLA RAÍZ (pokeruby data/maps/LittlerootTown/scripts.inc).
## El estado lo da HistoriaVillaRaiz.
##
## Coordenadas de Godot = Rubí + (8, 0), como en la Ruta 101.
##
## 1. Llegada (VAR_LITTLEROOT_INTRO_STATE 1/2, StepOffTruck*): el jugador salta
##    del camión de la mudanza (aparcado ante su casa), MAMÁ sale de casa,
##    "¡Ya hemos llegado!" y entran juntos (intro → 3, warp a la planta baja).
## 2. Niño de la salida norte (LittlerootTown_EventScript_Twin): con el estado 0
##    vigila en (7,2) y no deja salir (NeedPokemonTrigger*); tras conocer al rival
##    espera en (10,1) y avisa de los gritos (GoSaveBirchTrigger, estado → 2).
## 3. MAMÁ y las DEPORTIVAS (estado 3, tras la POKéDEX): espera delante de casa y
##    sale al paso si te vas hacia la RUTA 101 (GiveRunningShoesTrigger0..5).
## 4. Carteles de las casas según el sexo del jugador, GORDO tras la llegada.
extends EventoGuionizado
class_name EventoVillaRaiz

const MOTIVO_PAUSA: StringName = &"villa_raiz"
## Godot = Rubí + DESFASE.
const DESFASE := Vector2i(8, 0)
const TipoMovimiento := NpcBase.TipoMovimientoNPC

const TEXTO_LLEGADA: String = "VILLA_RAIZ_MAMA_LLEGADA"
const TEXTO_ESPERA: String = "VILLA_RAIZ_MAMA_ESPERA"
const TEXTO_DEPORTIVAS: String = "VILLA_RAIZ_MAMA_DEPORTIVAS"
const TEXTO_DEPORTIVAS_PUESTAS: String = "VILLA_RAIZ_DEPORTIVAS_PUESTAS"
const TEXTO_INSTRUCCIONES: String = "VILLA_RAIZ_MAMA_INSTRUCCIONES"
const TEXTO_VUELVE_A_CASA: String = "VILLA_RAIZ_MAMA_VUELVE_A_CASA"
const TEXTO_HIERBA: String = "VILLA_RAIZ_NINO_HIERBA"
const TEXTO_PELIGRO: String = "VILLA_RAIZ_NINO_PELIGRO"
const TEXTO_GRITOS: String = "VILLA_RAIZ_NINO_GRITOS"
const TEXTO_RESCATE: String = "VILLA_RAIZ_NINO_RESCATE"
const TEXTO_SUERTE: String = "VILLA_RAIZ_NINO_SUERTE"
const CARTEL_JUGADOR: String = "VILLA_RAIZ_CARTEL_CASA_JUGADOR"
const CARTEL_ABEDUL: String = "VILLA_RAIZ_CARTEL_CASA_ABEDUL"

## Celdas (Rubí). Casa 1 = la de BRUNO, casa 2 = la de AURA.
const PUERTA_CASA := {1: Vector2i(5, 8), 2: Vector2i(14, 8)}
## Trasera del camión (setdynamicwarp de InsideOfTruck): de aquí salta el jugador.
const TRASERA_CAMION := {1: Vector2i(3, 10), 2: Vector2i(12, 10)}
## SetMomStandingInFrontOfDoorPos.
const MAMA_ANTE_PUERTA := {1: Vector2i(5, 9), 2: Vector2i(14, 9)}
## warpsilent a la planta baja (LittlerootTown_EventScript_StepOffTruck*).
const ENTRADA_CASA := {1: Vector2(8, 8), 2: Vector2(2, 8)}
const NINO_PASEA := Vector2i(16, 10)
const NINO_VIGILA := Vector2i(7, 2)
const NINO_NORTE := Vector2i(10, 1)

## GiveRunningShoesTrigger0..5: celda del disparador (Rubí) → índice VAR_0x8008.
const DISPARADORES_DEPORTIVAS := {
	&"deportivas_0": 0, &"deportivas_1": 1, &"deportivas_2": 2,
	&"deportivas_3": 3, &"deportivas_4": 4, &"deportivas_5": 5,
}
## Triggers 0 y 1 (salida norte): MAMÁ aparece en (10,9) / (11,9) y sube 6.
const MAMA_SALE_AL_NORTE := {0: Vector2i(10, 9), 1: Vector2i(11, 9)}
## Triggers 2..5: pasos de MAMÁ hasta el jugador, por casa (MomApproachPlayer*).
const PASOS_MAMA := {
	1: {2: 4, 3: 5, 4: 2, 5: 3},
	2: {2: 3, 3: 2, 4: 5, 5: 4},
}

@export var mama: NodePath
@export var nino: NodePath
@export var gordo: NodePath
@export var puerta_casa_1: NodePath
@export var puerta_casa_2: NodePath
@export var cartel_casa_1: NodePath
@export var cartel_casa_2: NodePath
## Camiones de la mudanza (objetos 5 y 6, FLAG_HIDE_MOVING_TRUCK_BRENDAN / _MAY).
@export var camion_casa_1: NodePath
@export var camion_casa_2: NodePath

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
	var npc_nino := _npc(nino)
	if npc_nino != null and npc_nino.has_signal("hablado"):
		npc_nino.hablado.connect(_on_nino_hablado)
	var npc_mama := _npc(mama)
	if npc_mama != null and npc_mama.has_signal("hablado"):
		npc_mama.hablado.connect(_on_mama_hablada)
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)
	preparar()


## Celda de Godot de una celda de Rubí.
static func celda_de(celda_rubi: Vector2i) -> Vector2i:
	return celda_rubi + DESFASE


func _npc(ruta: NodePath) -> Node2D:
	return get_node_or_null(ruta) as Node2D


func _puerta(casa: int) -> Node:
	return get_node_or_null(puerta_casa_1 if casa == 1 else puerta_casa_2)


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


## ============================================================================
## ON_TRANSITION / ON_FRAME
## ============================================================================

func _on_mapa_activado(_por_warp: bool) -> void:
	# MoveRivalFromOldale: el rival ya no espera en PUEBLO ESCASO. Aquí y no en
	# preparar(): _ready corre aunque el jugador esté en otro mapa.
	if SistemaGuardado.get_flag(HistoriaVillaRaiz.BANDERA_RIVAL_RUTA_103):
		SistemaGuardado.set_flag(EventoPuebloEscaso.BANDERA_RIVAL_VISTO, true)
	preparar()
	var intro := HistoriaVillaRaiz.intro()
	if intro == HistoriaVillaRaiz.Intro.CAMION_CHICO or intro == HistoriaVillaRaiz.Intro.CAMION_CHICA:
		var admin_actual := _administrador()
		await esperar_fin_warp(admin_actual)
		await llegada()


## LittlerootTown_OnTransition: carteles, niño, GORDO y MAMÁ en su sitio.
func preparar() -> void:
	if _en_curso:
		return
	# SetRivalLeftForRoute103: al salir de su casa, el rival ya va camino de la RUTA 103.
	if SistemaGuardado.get_flag(HistoriaVillaRaiz.BANDERA_RIVAL_CONOCIDO):
		SistemaGuardado.set_flag(HistoriaVillaRaiz.BANDERA_RIVAL_SE_FUE, true)
	var chico := HistoriaVillaRaiz.es_chico()
	_poner_cartel(cartel_casa_1, CARTEL_JUGADOR if chico else CARTEL_ABEDUL)
	_poner_cartel(cartel_casa_2, CARTEL_ABEDUL if chico else CARTEL_JUGADOR)
	_colocar_nino()
	_mostrar_camiones()
	var npc_gordo := _npc(gordo)
	if npc_gordo != null:  # FLAG_HIDE_FAT_MAN_LITTLEROOT hasta entrar en casa
		npc_gordo.visible = HistoriaVillaRaiz.intro() >= HistoriaVillaRaiz.Intro.ENTRAR_EN_CASA
	var npc_mama := _npc(mama)
	if npc_mama != null:
		var esperando := HistoriaVillaRaiz.estado_pueblo() == 3
		if esperando:
			npc_mama.tipo_movimiento = TipoMovimiento.MIRAR_ABAJO
			colocar(npc_mama, celda_de(MAMA_ANTE_PUERTA[HistoriaVillaRaiz.casa_jugador()]))
		npc_mama.visible = esperando


func _poner_cartel(ruta: NodePath, clave: String) -> void:
	var cartel := get_node_or_null(ruta)
	if cartel != null:
		cartel.set("id_texto", clave)


## FLAG_HIDE_MOVING_TRUCK_*: solo se ve el camión de la casa del jugador, y solo
## hasta entrar en casa con MAMÁ.
func _mostrar_camiones() -> void:
	var intro := HistoriaVillaRaiz.intro()
	for casa in [1, 2]:
		var camion := get_node_or_null(camion_casa_1 if casa == 1 else camion_casa_2) as CanvasItem
		if camion != null:
			camion.visible = intro == (HistoriaVillaRaiz.Intro.CAMION_CHICO if casa == 1 else HistoriaVillaRaiz.Intro.CAMION_CHICA)


## LittlerootTown_EventScript_SetTwinPos.
func _colocar_nino() -> void:
	var npc_nino := _npc(nino)
	if npc_nino == null:
		return
	if _tiene_inicial():
		npc_nino.tipo_movimiento = TipoMovimiento.PASEAR_RANGO
		colocar(npc_nino, celda_de(NINO_PASEA))
	elif HistoriaVillaRaiz.estado_pueblo() == 0:
		npc_nino.tipo_movimiento = TipoMovimiento.MIRAR_ABAJO
		colocar(npc_nino, celda_de(NINO_VIGILA))
	else:
		npc_nino.tipo_movimiento = TipoMovimiento.MIRAR_ARRIBA
		colocar(npc_nino, celda_de(NINO_NORTE))


## ============================================================================
## LLEGADA (LittlerootTown_EventScript_StepOffTruck* / GoInsideWithMom)
## ============================================================================

## El camión de Godot deja al jugador en su trasera, (3,10) o (12,10) de Rubí,
## mirando a la derecha; salta al suelo (jump_right) y espera a MAMÁ junto a él.
## Si llega a otra celda (partidas o arranques de depuración), camina hasta allí.
func llegada() -> void:
	var intro := HistoriaVillaRaiz.intro()
	if intro != HistoriaVillaRaiz.Intro.CAMION_CHICO and intro != HistoriaVillaRaiz.Intro.CAMION_CHICA:
		return
	if not comenzar(_administrador()):
		return
	var casa := HistoriaVillaRaiz.casa_jugador()
	var puerta := _puerta(casa)
	var celda_puerta := celda_de(PUERTA_CASA[casa])
	var npc_mama := _npc(mama)
	var junto_al_camion := celda_puerta + Vector2i(-1, 2)
	var jugador: Node = admin.jugador
	var celda_jugador: Vector2i = jugador.pos_celda_act
	await esperar_fotogramas(15)
	if celda_jugador == celda_de(TRASERA_CAMION[casa]):
		await bajar_del_camion()
		celda_jugador.x += 1
	while celda_jugador.x < junto_al_camion.x:
		await recorrer_jugador([Vector2.RIGHT])
		celda_jugador.x += 1
	if npc_mama == null:
		push_warning("[VILLA_RAIZ] Falta MAMÁ en el mapa")
	else:
		await abrir_puerta(puerta)
		npc_mama.tipo_movimiento = TipoMovimiento.SIN_MOVIMIENTO
		colocar(npc_mama, celda_puerta)
		npc_mama.visible = true  # addobject 4
		await caminar(npc_mama, Vector2.DOWN)  # MomExitHouse
		await cerrar_puerta(puerta)
		await esperar_fotogramas(10)
		await caminar(npc_mama, Vector2.DOWN)  # MomApproachPlayerAtTruck
		mirar(npc_mama, Vector2.LEFT)
	await mensaje(TEXTO_LLEGADA)
	admin.cuadro_dialogo.cerrar()
	if npc_mama != null:
		# MomApproachDoor y PlayerApproachDoor: delay_16 delay_8 y a la puerta.
		await en_paralelo([
			_esperar_y_caminar.bind(npc_mama, Vector2.UP),
			_esperar_y_caminar_jugador.bind(Vector2.RIGHT),
		])
		girar_jugador(Vector2.UP)
		await abrir_puerta(puerta)
		# MomEnterHouse (walk_up, set_invisible) y PlayerEnterHouse (walk_up ×2):
		# la puerta sigue abierta hasta que entran los dos.
		await en_paralelo([
			_entrar_por_la_puerta.bind(npc_mama),
			recorrer_jugador.bind([Vector2.UP, Vector2.UP]),
		])
	HistoriaVillaRaiz.set_intro(HistoriaVillaRaiz.Intro.ENTRAR_EN_CASA)
	_mostrar_camiones()  # setflag FLAG_HIDE_MOVING_TRUCK_*
	jugador.visible = false  # hideobjectat LOCALID_PLAYER
	await cerrar_puerta(puerta)
	var npc_gordo := _npc(gordo)
	if npc_gordo != null:
		npc_gordo.visible = true  # clearflag FLAG_HIDE_FAT_MAN_LITTLEROOT
	SistemaGuardado.set_flag(HistoriaVillaRaiz.BANDERA_OCULTAR_CARTEL, false)  # clearflag FLAG_HIDE_MAP_NAME_POPUP
	# warpsilent a la planta baja de casa.
	var admin_actual := admin
	terminar(true)
	jugador.end_dialog()
	jugador.no_control = true
	admin_actual.conectar_escalera(HistoriaVillaRaiz.mapa_casa_jugador(), ENTRADA_CASA[casa], Vector2.UP)


## LittlerootTown_Movement_14D6C0: playse SE_DANSA, jump_right y delay_16 ×3.
func bajar_del_camion() -> void:
	Singleton.play_sound.emit("SE_DANSA")
	await admin.jugador.saltar_guion(Vector2.RIGHT)
	await esperar_fotogramas(48)


## walk_up + set_invisible (FLAG_HIDE_MOM_LITTLEROOT).
func _entrar_por_la_puerta(npc: Node2D) -> void:
	await caminar(npc, Vector2.UP)
	npc.visible = false


func _esperar_y_caminar(npc: Node2D, direccion: Vector2) -> void:
	await esperar_fotogramas(24)
	await caminar(npc, direccion)


func _esperar_y_caminar_jugador(direccion: Vector2) -> void:
	await esperar_fotogramas(24)
	await recorrer_jugador([direccion])


## ============================================================================
## NIÑO DE LA SALIDA NORTE
## ============================================================================

func _on_disparador(id_evento: StringName) -> void:
	match id_evento:
		&"norte_izquierda":
			if HistoriaVillaRaiz.estado_pueblo() == 0:
				_no_salgas_sin_pokemon(false)
		&"norte_derecha":
			match HistoriaVillaRaiz.estado_pueblo():
				0:
					_no_salgas_sin_pokemon(true)
				1:
					_ve_a_ver_los_gritos()
		_:
			if DISPARADORES_DEPORTIVAS.has(id_evento) and HistoriaVillaRaiz.estado_pueblo() == 3:
				_deportivas_al_paso(DISPARADORES_DEPORTIVAS[id_evento])


## LittlerootTown_EventScript_NeedPokemonTriggerLeft / Right: el niño corre hasta
## ponerse delante del jugador, le empuja una casilla hacia el pueblo y vuelve.
func _no_salgas_sin_pokemon(derecha: bool) -> void:
	if _en_curso or not comenzar(_administrador()):
		return
	var npc_nino := _npc(nino)
	if npc_nino == null:
		terminar()
		return
	mirar(npc_nino, Vector2.RIGHT)
	await esperar_fotogramas(8)
	await saltar_en_sitio(npc_nino, Vector2.RIGHT)
	await esperar_fotogramas(8)
	var ida: Array = [Vector2.RIGHT, Vector2.RIGHT, Vector2.RIGHT, Vector2.RIGHT, Vector2.UP, Vector2.UP, Vector2.LEFT]
	if derecha:
		ida = [Vector2.RIGHT, Vector2.RIGHT, Vector2.RIGHT, Vector2.UP, Vector2.UP, Vector2.RIGHT]
	await recorrer(npc_nino, ida, VelocidadPaso.RAPIDO)
	mirar(npc_nino, Vector2.DOWN)
	# LittlerootTown_EventScript_DangerousWithoutPokemon.
	await mensaje(TEXTO_HIERBA)
	admin.cuadro_dialogo.cerrar()
	await en_paralelo([
		caminar.bind(npc_nino, Vector2.DOWN),
		retroceder_jugador.bind(Vector2.DOWN),
	])
	await mensaje(TEXTO_PELIGRO)
	admin.cuadro_dialogo.cerrar()
	var vuelta: Array = [Vector2.RIGHT, Vector2.DOWN, Vector2.DOWN, Vector2.LEFT, Vector2.LEFT, Vector2.LEFT, Vector2.LEFT, Vector2.UP]
	if derecha:
		vuelta = [Vector2.LEFT, Vector2.DOWN, Vector2.LEFT, Vector2.LEFT, Vector2.LEFT]
	await recorrer(npc_nino, vuelta)
	mirar(npc_nino, Vector2.DOWN)
	terminar(false, [npc_nino])


## LittlerootTown_EventScript_GoSaveBirchTrigger.
func _ve_a_ver_los_gritos() -> void:
	if _en_curso or not comenzar(_administrador()):
		return
	var npc_nino := _npc(nino)
	if npc_nino != null:
		mirar(npc_nino, Vector2.RIGHT)
	girar_jugador(Vector2.LEFT)
	await _aviso_de_los_gritos(npc_nino)
	terminar(false, [npc_nino] if npc_nino != null else [])


func _aviso_de_los_gritos(npc_nino: Node2D) -> void:
	await mensaje(TEXTO_GRITOS)
	admin.cuadro_dialogo.cerrar()
	if npc_nino != null:
		mirar(npc_nino, npc_nino.direccion_base)  # Common_Movement_FaceOriginalDirection
	SistemaGuardado.set_flag(HistoriaVillaRaiz.BANDERA_AVISO_SOCORRO, true)  # VAR_LITTLEROOT_STATE = 2


## LittlerootTown_EventScript_Twin.
func _on_nino_hablado(npc: Node2D) -> void:
	if _en_curso:
		return
	if not comenzar(npc.nodo_administrador):
		if npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()
	if SistemaGuardado.get_flag(HistoriaVillaRaiz.BANDERA_AVENTURA):
		await mensaje(TEXTO_SUERTE)
	elif _tiene_inicial():
		await mensaje(TEXTO_RESCATE)
	elif HistoriaVillaRaiz.estado_pueblo() != 0:
		await _aviso_de_los_gritos(npc)
	else:
		await mensaje(TEXTO_HIERBA)
	terminar(false, [npc])


## ============================================================================
## MAMÁ Y LAS DEPORTIVAS (VAR_LITTLEROOT_STATE 3)
## ============================================================================

## LittlerootTown_EventScript_GiveRunningShoesTrigger.
func _deportivas_al_paso(indice: int) -> void:
	if _en_curso or not comenzar(_administrador()):
		return
	var npc_mama := _npc(mama)
	if npc_mama == null:
		terminar()
		return
	var casa := HistoriaVillaRaiz.casa_jugador()
	var hacia_el_jugador := Vector2.RIGHT if casa == 1 else Vector2.LEFT
	npc_mama.tipo_movimiento = TipoMovimiento.SIN_MOVIMIENTO
	if MAMA_SALE_AL_NORTE.has(indice):
		colocar(npc_mama, celda_de(MAMA_SALE_AL_NORTE[indice]))
		npc_mama.visible = true
	mirar(npc_mama, hacia_el_jugador)  # MomNoticePlayer
	await mensaje(TEXTO_ESPERA)
	admin.cuadro_dialogo.cerrar()
	var pasos: Array = []
	if MAMA_SALE_AL_NORTE.has(indice):
		girar_jugador(Vector2.DOWN)
		pasos = _repetir(Vector2.UP, 6)
	else:
		girar_jugador(-hacia_el_jugador)
		pasos = _repetir(hacia_el_jugador, PASOS_MAMA[casa][indice])
	await recorrer(npc_mama, pasos)
	await _dar_deportivas()
	# MomReturnHome*.
	if MAMA_SALE_AL_NORTE.has(indice):
		await recorrer(npc_mama, _repetir(Vector2.DOWN, 5))
		npc_mama.visible = false
	else:
		await recorrer(npc_mama, _repetir(-hacia_el_jugador, pasos.size()))
		await _mama_entra_en_casa(npc_mama, casa)
	terminar(false, [npc_mama])


## LittlerootTown_EventScript_Mom: hablarle delante de la puerta.
func _on_mama_hablada(npc: Node2D) -> void:
	if _en_curso or HistoriaVillaRaiz.estado_pueblo() != 3:
		return
	if not comenzar(npc.nodo_administrador):
		if npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()
	await _dar_deportivas()
	await _mama_entra_en_casa(npc, HistoriaVillaRaiz.casa_jugador())
	terminar(false, [npc])


## LittlerootTown_EventScript_GiveRunningShoes + SetReceivedRunningShoes.
func _dar_deportivas() -> void:
	await mensaje(TEXTO_DEPORTIVAS, false)
	await mensaje_con_fanfarria(TEXTO_DEPORTIVAS_PUESTAS)
	SistemaGuardado.set_flag(HistoriaVillaRaiz.BANDERA_DEPORTIVAS, true)  # VAR_LITTLEROOT_STATE = 4
	SistemaGuardado.set_flag(HistoriaVillaRaiz.BANDERA_SIN_DEPORTIVAS, false)  # FLAG_SYS_B_DASH
	await mensaje(TEXTO_INSTRUCCIONES, false)
	await mensaje(TEXTO_VUELVE_A_CASA)
	admin.cuadro_dialogo.cerrar()
	await esperar_fotogramas(30)


## Mira a la puerta, la abre, entra y desaparece (hideobjectat + removeobject).
func _mama_entra_en_casa(npc_mama: Node2D, casa: int) -> void:
	mirar(npc_mama, Vector2.UP)
	var puerta := _puerta(casa)
	await abrir_puerta(puerta)
	await caminar(npc_mama, Vector2.UP)  # MomExitThroughDoor
	npc_mama.visible = false
	await cerrar_puerta(puerta)


## FLAG_RESCUED_BIRCH; también el inicial de la Bandolera de las partidas anteriores.
static func _tiene_inicial() -> bool:
	return SistemaGuardado.get_flag(HistoriaVillaRaiz.BANDERA_RESCATADO) \
		or SistemaGuardado.get_flag(HistoriaVillaRaiz.BANDERA_INICIAL)


static func _repetir(direccion: Vector2, veces: int) -> Array:
	var lista: Array = []
	for i in veces:
		lista.append(direccion)
	return lista

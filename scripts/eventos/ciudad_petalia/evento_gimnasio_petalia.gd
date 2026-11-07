## evento_gimnasio_petalia.gd
## Guiones del GIMNASIO de CIUDAD PETALIA (pokeruby data/maps/PetalburgCity_Gym).
##
## En Rubí las nueve salas están apiladas en un mapa de 9×112; en la escena están
## en una rejilla de 3×3 salas de 9×8 (ver SALAS). Cada sala tiene:
## - arriba, una o dos PUERTAS CORREDERAS (bg_event + warpdoor): siempre son
##   pared; al leerlas, si el entrenador de la sala no está vencido (o, en la
##   entrada, sin VAR_PETALBURG_GYM_STATE ≥ 6) «Parece que esta puerta está
##   cerrada...»; si no, SÍ/NO y warp al FELPUDO de la sala siguiente. El destino y
##   la animación son del Warp de la misma celda (PUERTA_GIMNASIO_5, siempre con_llave:
##   como en Rubí, no se entra caminando, solo leyéndola).
## - abajo, los FELPUDOS de vuelta (METATILE_PetalburgGym_RoomEntrance): suelo
##   normal hasta que se abren; abiertos son una salida (Warp SALIDAS) a la puerta
##   de la sala anterior.
## Al vencer al entrenador de una sala sus puertas se abren con la animación de 5
## cuadros (PetalburgGymSlideOpenDoors) y aparecen los felpudos de las salas a las
## que llevan. Al entrar en el mapa (ON_LOAD) con VAR_PETALBURG_GYM_STATE 6 se abren
## al instante las de la entrada y las de los entrenadores vencidos; con 7, todas.
##
## NORMAN: espera en la entrada hasta tener las cuatro MEDALLAS (y tras el
## CAMPEONATO); habla según las MEDALLAS, combate con las cuatro y entrega la
## MEDALLA EQUILIBRIO y la MT42.
##
## BLASCO (objeto 10): la primera vez que se habla con NORMAN entra por la puerta,
## NORMAN le presta su ZIGZAGOON y el jugador sale con él a la ciudad
## (BeginWallyTutorial; sigue EventoCiudadPetalia.tutorial_blasco). Al volver de
## la RUTA 102 se despide (ReturnFromWallyTutorial). El estado vive en HistoriaBlasco.
extends EventoGuionizado
class_name EventoGimnasioPetalia

const MOTIVO_PAUSA: StringName = &"gimnasio_petalia"
const TipoMovimiento := NpcBase.TipoMovimientoNPC

const ENTRENADOR_NORMAN: int = 269
const MUSICA_LIDER: String = "GYM_LEADER_BATTLE"
const FANFARRIA_MEDALLA: String = "OBTENIDA_MEDALLA"
## FLAG_BADGE05_GET (MEDALLA EQUILIBRIO); también hace de FLAG_DEFEATED_PETALBURG_GYM.
const INDICE_MEDALLA: int = 4
const OBJETO_MT42: String = "MT42"
## FLAG_RECEIVED_TM42.
const BANDERA_MT42: String = "petalia_mt42_recibida"
## FLAG_SYS_GAME_CLEAR.
const BANDERA_JUEGO_COMPLETADO: String = "SYS_GAME_CLEAR"
## !FLAG_HIDE_WATTSON_MAUVILLE: ERICO sale a CIUDAD MALVALONA al vencer a NORMAN
## (HistoriaMalvalona.BANDERA_ERICO_FUERA; el nodo del exterior la lee por su nombre).
const BANDERA_ERICO_FUERA: String = "malvalona_erico_fuera"

const T := "PETALIA_GIMNASIO_"
const TEXTO_PUERTA_CERRADA: String = T + "PUERTA_CERRADA"
const TEXTO_MOCHILA_LLENA: String = "MOCHILA_LLENA_REGALO"
## switch VAR_PETALBURG_GYM_STATE (0 = antes del tutorial de BLASCO).
const TEXTOS_NORMAN := {0: T + "PAPA_LLEGAS", 2: T + "PAPA_FERRICA", 3: T + "PAPA_AZULIZA",
	4: T + "PAPA_MAS_FUERTE", 5: T + "PAPA_MAS_FUERTE"}
const MUSICA_SIGUEME: String = "SIGUEME"
## warp MAP_PETALBURG_CITY, 255, 15, 8: la puerta del GIMNASIO; se sale con un paso.
const MAPA_CIUDAD: String = "ciudad_petalia"
const PUERTA_CIUDAD := Vector2(15, 10)

## OnTransition: NORMAN en la entrada ((4,107) de Rubí) o en su sala ((4,3)).
const NORMAN_ENTRADA := Vector2i(4, 3)
const NORMAN_SALA := Vector2i(4, -23)
## BLASCO entra por la puerta ((4,111) de Rubí) y vuelve a (5,108) tras el tutorial.
const BLASCO_PUERTA := Vector2i(4, 7)
const BLASCO_VUELTA := Vector2i(5, 4)

const R := Vector2.RIGHT
const L := Vector2.LEFT
const U := Vector2.UP
const D := Vector2.DOWN
## VAR_FACING al hablar con NORMAN → VAR_0x8008 (0 sur, 1 norte, 2 oeste, 3 este).
const CASO_POR_MIRADA := {Vector2.DOWN: 0, Vector2.UP: 1, Vector2.LEFT: 2, Vector2.RIGHT: 3}
## NormanAddressPlayer*: [mirada de NORMAN, giro del jugador (ZERO = no gira)].
const NORMAN_AL_JUGADOR := [[U, Vector2.ZERO], [D, U], [R, L], [L, R]]
## NormanAddressWally*.
const NORMAN_A_BLASCO := [D, R, D, D]

## Salas de Rubí (índice = VAR_0x8004 de PetalburgGymSlideOpenDoors), con la celda
## de la escena de cada puerta corredera (cuadro de arriba; el de abajo es +1) y
## de cada felpudo que abre. Rubí (x, y) → escena (origen.x + x, origen.y + y − y0).
const SALAS := {
	1: {"entrenador": "", "correderas": [Vector2i(1, 0), Vector2i(7, 0)],
		"felpudos": [Vector2i(-10, 7), Vector2i(17, 7)]},  # entrada (y0 104) → (0, 0)
	2: {"entrenador": "Rodrigo", "correderas": [Vector2i(-15, 0), Vector2i(-9, 0)],
		"felpudos": [Vector2i(-10, -6), Vector2i(1, -6)]},  # VELOCIDAD (78) → (-16, 0)
	3: {"entrenador": "Mari", "correderas": [Vector2i(17, 0), Vector2i(23, 0)],
		"felpudos": [Vector2i(6, -6), Vector2i(17, -6)]},  # PRECISIÓN (91) → (16, 0)
	4: {"entrenador": "Pascual", "correderas": [Vector2i(-9, -13)],
		"felpudos": [Vector2i(-15, -19)]},  # REDUCCIÓN CERO (39) → (-16, -13)
	5: {"entrenador": "Lara", "correderas": [Vector2i(1, -13), Vector2i(7, -13)],
		"felpudos": [Vector2i(-10, -19), Vector2i(17, -19)]},  # DEFENSA (52) → (0, -13)
	6: {"entrenador": "Jorge", "correderas": [Vector2i(17, -13)],
		"felpudos": [Vector2i(22, -19)]},  # RECUPERACIÓN (65) → (16, -13)
	7: {"entrenador": "Jimena", "correderas": [Vector2i(-9, -26)],
		"felpudos": [Vector2i(1, -19)]},  # FUERZA (13) → (-16, -26)
	8: {"entrenador": "Blas", "correderas": [Vector2i(17, -26)],
		"felpudos": [Vector2i(6, -19)]},  # KO INSTANTÁNEO (26) → (16, -26)
}
## Requisito de cada cartel de puerta (nodo de Carteles): entrenador que hay que
## haber vencido; "" = VAR_PETALBURG_GYM_STATE ≥ 6.
const PUERTAS := {
	"PuertaVelocidad": "", "PuertaPrecision": "",
	"PuertaReduccionCero": "Rodrigo", "PuertaDefensaIzquierda": "Rodrigo",
	"PuertaDefensaDerecha": "Mari", "PuertaRecuperacion": "Mari",
	"PuertaFuerzaIzquierda": "Pascual", "PuertaFuerzaDerecha": "Lara",
	"PuertaKOIzquierda": "Lara", "PuertaKODerecha": "Jorge",
	"PuertaLiderIzquierda": "Jimena", "PuertaLiderDerecha": "Blas",
}

## Atlas de tileset_edificios: el secundario de Rubí empieza en (8, 9) con 8 de ancho.
const ATLAS_SUELO := Vector2i(9, 9)  # 0x201
const ATLAS_FELPUDO := [Vector2i(8, 11), Vector2i(9, 11)]  # RoomEntrance_Left / _Right
const ATLAS_CORREDERA := Vector2i(8, 12)  # SlidingDoor_Frame0 (+k, cuadro k; +1 en y, abajo)
## gUnknown_083F8370: el primer cuadro sale enseguida y cada uno de los demás
## tras dos fotogramas.
const FOTOGRAMAS_CORREDERA: int = 2

@export var npcs: NodePath = ^"../../NPCs"
@export var carteles: NodePath = ^"../../Carteles"
@export var felpudos: NodePath = ^"../../Felpudos"
@export var suelo: NodePath = ^"../../Suelo"

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var nodo_carteles := get_node_or_null(carteles)
	if nodo_carteles != null:
		for cartel in nodo_carteles.get_children():
			if cartel is CartelEvento and PUERTAS.has(String(cartel.name)):
				cartel.accionado.connect(_on_puerta)
	for n in SALAS:
		var entrenador := _npc(SALAS[n]["entrenador"])
		if entrenador != null and entrenador.has_signal("vencido"):
			entrenador.vencido.connect(_on_entrenador_vencido.bind(n))
	var norman := _npc("Norman")
	if norman != null and norman.has_signal("hablado"):
		norman.hablado.connect(_on_norman)
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)
	preparar()


func _on_mapa_activado(_por_warp: bool) -> void:
	preparar()
	if HistoriaBlasco.de_vuelta_en_el_gimnasio():
		despedida_blasco()  # PetalburgCity_Gym_OnFrame


func _npc(nombre: String) -> Node2D:
	var nodo := get_node_or_null(npcs)
	if nodo == null or nombre.is_empty():
		return null
	return nodo.get_node_or_null(nombre) as Node2D


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


## ============================================================================
## ESTADO
## ============================================================================

## VAR_PETALBURG_GYM_STATE: 0 y 1 durante la historia de BLASCO (HistoriaBlasco);
## después 2 + MEDALLAS 1..4 (6 = reto contra NORMAN); 7 con la MEDALLA EQUILIBRIO.
static func estado() -> int:
	if SistemaGuardado.tiene_medalla(INDICE_MEDALLA):
		return 7
	if HistoriaBlasco.gimnasio() < HistoriaBlasco.Gimnasio.DESPEDIDA:
		return HistoriaBlasco.gimnasio()
	var medallas := 0
	for i in 4:
		if SistemaGuardado.tiene_medalla(i):
			medallas += 1
	return 2 + medallas


func _vencido(nombre: String) -> bool:
	var entrenador := _npc(nombre)
	return entrenador != null and entrenador.has_method("esta_vencido") and entrenador.esta_vencido()


## ¿Está abierta la sala `n`? (OpenUnlockedDoors / UnlockAllDoors).
func sala_abierta(n: int) -> bool:
	var e := estado()
	if e >= 7:
		return true
	if e < 6:
		return false
	return n == 1 or _vencido(SALAS[n]["entrenador"])


## goto_if_not_defeated / compare VAR_PETALBURG_GYM_STATE, 6 de cada puerta.
func puerta_abierta(nombre_cartel: String) -> bool:
	var requisito: String = PUERTAS.get(nombre_cartel, "")
	return estado() >= 6 if requisito.is_empty() else _vencido(requisito)


## ============================================================================
## ON_LOAD / ON_TRANSITION
## ============================================================================

func preparar() -> void:
	if _en_curso:
		return
	for n in SALAS:
		_aplicar_sala(n, sala_abierta(n))
	var norman := _npc("Norman")
	if norman != null:
		var en_entrada := estado() < 6 or SistemaGuardado.get_flag(BANDERA_JUEGO_COMPLETADO)
		norman.tipo_movimiento = TipoMovimiento.MIRAR_ABAJO
		colocar(norman, NORMAN_ENTRADA if en_entrada else NORMAN_SALA)
	var guia := _npc("Guia")
	if guia != null:
		guia.visible = estado() >= 6  # FLAG_HIDE_PETALBURG_GYM_GUIDE
	var blasco := _npc("Blasco")
	if blasco != null:  # OnTransition: setobjectxyperm 10, 5, 108
		blasco.tipo_movimiento = TipoMovimiento.MIRAR_ARRIBA
		colocar(blasco, BLASCO_VUELTA if HistoriaBlasco.de_vuelta_en_el_gimnasio() else BLASCO_PUERTA)
		blasco.visible = HistoriaBlasco.de_vuelta_en_el_gimnasio()  # FLAG_HIDE_WALLY_PETALBURG_GYM


func _aplicar_sala(n: int, abierta: bool) -> void:
	for celda: Vector2i in SALAS[n]["correderas"]:
		_poner_corredera(celda, 4 if abierta else 0)
	for celda: Vector2i in SALAS[n]["felpudos"]:
		_poner_felpudo(celda, abierta)


func _capa_suelo() -> TileMapLayer:
	return get_node_or_null(suelo) as TileMapLayer


func _poner_corredera(celda: Vector2i, cuadro: int) -> void:
	var capa := _capa_suelo()
	if capa == null:
		return
	capa.set_cell(celda, 0, ATLAS_CORREDERA + Vector2i(cuadro, 0))
	capa.set_cell(celda + Vector2i.DOWN, 0, ATLAS_CORREDERA + Vector2i(cuadro, 1))


## Cada felpudo son dos celdas: `celda` (izquierda) y la de su derecha.
func _poner_felpudo(celda: Vector2i, abierto: bool) -> void:
	var capa := _capa_suelo()
	for i in 2:
		var c := celda + Vector2i(i, 0)
		if capa != null:
			capa.set_cell(c, 0, ATLAS_FELPUDO[i] if abierto else ATLAS_SUELO)
		var salida := felpudo_en(c)
		if salida != null:
			_activar_salida(salida, abierto)


func felpudo_en(celda: Vector2i) -> Warp:
	var nodo := get_node_or_null(felpudos)
	if nodo == null:
		return null
	for hijo in nodo.get_children():
		if hijo is Warp and hijo.coord_celda == celda:
			return hijo
	return null


## Un felpudo cerrado es suelo: su Warp SALIDAS no responde ni muestra flecha.
static func _activar_salida(salida: Warp, activa: bool) -> void:
	if activa and not salida.is_in_group("Salidas"):
		salida.add_to_group("Salidas")
	elif not activa and salida.is_in_group("Salidas"):
		salida.remove_from_group("Salidas")
	# Warp._process (flecha) necesita el AdministradorMapa de la raíz.
	salida.set_process(activa and salida.get_tree().root.has_node("AdministradorMapa"))


## Warp de la escena en la celda de una puerta corredera (su destino es el felpudo
## de la sala siguiente).
func warp_de_puerta(celda: Vector2i) -> Warp:
	var mapa := obtener_mapa()
	if mapa == null:
		return null
	for hijo in mapa.get_children():
		if hijo is Warp and hijo.tipo_warp == Warp.TipoWarp.PUERTAS and hijo.coord_celda == celda:
			return hijo
	return null


## ============================================================================
## PUERTAS
## ============================================================================

## PetalburgCity_Gym_EventScript_*RoomDoor.
func _on_puerta(cartel: CartelEvento) -> void:
	if _en_curso or not comenzar(_administrador()):
		return
	if not puerta_abierta(String(cartel.name)):
		await mensaje(TEXTO_PUERTA_CERRADA)  # DoorLocked
		terminar()
		return
	var entrar := await preguntar_si_no(cartel.id_texto)
	admin.cuadro_dialogo.cerrar()
	var warp := warp_de_puerta(cartel.coord_tile)
	terminar()
	if entrar and warp != null:  # EnterRoom: warpdoor
		admin.iniciar_transicion_centro(warp)


## SlideOpen*RoomDoors: continuación del trainerbattle_single de cada entrenador.
func _on_entrenador_vencido(_npc_vencido: Node2D, n: int) -> void:
	await abrir_sala(n)


## PetalburgGymSlideOpenDoors + Set*RoomDoorMetatiles.
func abrir_sala(n: int) -> void:
	Singleton.play_sound.emit("SE_UNLOCK")
	for cuadro in 5:
		if cuadro > 0:
			await esperar_fotogramas(FOTOGRAMAS_CORREDERA)
		for celda: Vector2i in SALAS[n]["correderas"]:
			_poner_corredera(celda, cuadro)
	for celda: Vector2i in SALAS[n]["felpudos"]:
		_poner_felpudo(celda, true)


## ============================================================================
## NORMAN
## ============================================================================

## PetalburgCity_Gym_EventScript_Norman (lock + faceplayer).
func _on_norman(npc: Node2D) -> void:
	var administrador_npc: Node = npc.nodo_administrador if npc.nodo_administrador != null else _administrador()
	if _en_curso or not comenzar(administrador_npc):
		if npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()
	var e := estado()
	if e == 6:
		await _combate_norman(npc)
		return
	if e >= 7:
		await _norman_tras_combate(npc)
		return
	if e == HistoriaBlasco.Gimnasio.INICIAL:
		await mensaje(TEXTOS_NORMAN[0])
		await _tutorial_blasco(npc)
		return
	await mensaje(TEXTOS_NORMAN.get(e, TEXTOS_NORMAN[0]))
	terminar(false, [npc])


## NormanBattle.
func _combate_norman(npc: Node2D) -> void:
	await mensaje(T + "PAPA_RETO")
	var resultado := await combatir(ENTRENADOR_NORMAN, MUSICA_LIDER)
	if resultado != &"victoria":
		terminar(resultado == &"derrota_transferida", [npc])
		return
	await mensaje_con_fanfarria(T + "MEDALLA_RECIBIDA", FANFARRIA_MEDALLA)
	await mensaje(T + "PAPA_MEDALLA", false)
	dar_medalla(INDICE_MEDALLA)  # FLAG_DEFEATED_PETALBURG_GYM, FLAG_BADGE05_GET, VAR = 7
	# setflag FLAG_HIDE_WATTSON_MAUVILLE_GYM + clearflag FLAG_HIDE_WATTSON_MAUVILLE: ERICO deja su
	# GIMNASIO y espera en CIUDAD MALVALONA (LLAVE SÓTANO y MT24).
	SistemaGuardado.set_flag(BANDERA_ERICO_FUERA, true)
	for n in SALAS:
		_aplicar_sala(n, true)  # UnlockAllDoors
	await _dar_mt42(npc)


## NormanPostBattle (sin la BAYA ENIGMA del EVENTO MISTERIOSO).
func _norman_tras_combate(npc: Node2D) -> void:
	if not SistemaGuardado.get_flag(BANDERA_MT42):
		await _dar_mt42(npc)
		return
	if SistemaGuardado.get_flag(BANDERA_JUEGO_COMPLETADO):
		await mensaje(T + "PAPA_NUNCA_SUFICIENTE")
	else:
		await mensaje(T + "PAPA_ENTRENAR")
	terminar(false, [npc])


## GiveFacade2: MT42, la explica, se da la vuelta (VAR_FACING), vuelve a mirar al
## jugador y le habla de los padres de BLASCO.
func _dar_mt42(npc: Node2D) -> void:
	if not await dar_objeto(npc, OBJETO_MT42):
		await mensaje(TEXTO_MOCHILA_LLENA)  # Common_EventScript_ShowBagIsFull
		terminar(false, [npc])
		return
	SistemaGuardado.set_flag(BANDERA_MT42, true)
	await mensaje(T + "PAPA_MT42", false)
	await mensaje(T + "PAPA_ORGULLOSO")
	var mirada: Vector2 = admin.jugador.facing_direction
	mirar(npc, mirada)  # 154ABC..154ADD: le da la espalda
	await esperar_fotogramas(8)
	mirar(npc, -mirada)  # 154AE8..154B09: vuelve a mirarle
	await mensaje(T + "PAPA_PADRES_BLASCO")
	terminar(false, [npc])


## setflag FLAG_BADGE0n_GET.
static func dar_medalla(indice: int) -> void:
	var medallas: Array = SistemaGuardado.datos_vivos.jugador.get("medallas", [])
	while medallas.size() < 8:
		medallas.append(false)
	medallas[indice] = true
	SistemaGuardado.datos_vivos.jugador["medallas"] = medallas


## ============================================================================
## BLASCO
## ============================================================================

## BeginWallyTutorial: BLASCO entra, NORMAN le presta su ZIGZAGOON y el jugador sale
## con él (switch VAR_FACING: el jugador puede hablar con NORMAN desde cualquier lado).
func _tutorial_blasco(norman: Node2D) -> void:
	var blasco := _npc("Blasco")
	if blasco == null:
		terminar(false, [norman])
		return
	var caso: int = CASO_POR_MIRADA.get(admin.jugador.facing_direction, 0)
	blasco.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	colocar(blasco, BLASCO_PUERTA)
	mirar(blasco, U)
	blasco.visible = true  # addobject 10
	Singleton.play_sound.emit("puerta_entrada")  # SE_DOOR
	await _blasco_llega(norman, blasco, caso)
	for clave in ["BLASCO_QUIERO_POKEMON", "PAPA_ERES_BLASCO", "BLASCO_NUNCA_ATRAPE", "PAPA_YA"]:
		await mensaje(T + clave, false)
	mirar(norman, NORMAN_AL_JUGADOR[caso][0])
	if NORMAN_AL_JUGADOR[caso][1] != Vector2.ZERO:
		girar_jugador(NORMAN_AL_JUGADOR[caso][1])
	await mensaje(T + "PAPA_VE_CON_BLASCO", false)
	mirar(norman, NORMAN_A_BLASCO[caso])
	for clave in ["PAPA_PRESTO_ZIGZAGOON", "BLASCO_POKEBALL", "BLASCO_GUAU"]:
		await mensaje(T + clave, false)
	if caso == 1:
		mirar(norman, D)  # NormanFaceDoorNorth
	mirar(blasco, D if caso == 1 else _hacia_el_jugador(blasco))
	await mensaje(T + "BLASCO_VIENES")
	reproducir_musica(MUSICA_SIGUEME)  # setflag FLAG_DONT_TRANSITION_MUSIC + playbgm
	await _salir_con_blasco(norman, blasco, caso)
	blasco.visible = false  # removeobject 10
	HistoriaBlasco.salir_con_blasco()
	SistemaGuardado.set_flag(HistoriaVillaRaiz.BANDERA_OCULTAR_CARTEL, true)  # lo quita la ciudad
	terminar(false, [norman, blasco])
	admin.conectar_escalera(MAPA_CIUDAD, PUERTA_CIUDAD, D, true)


## WallyArriveSouth / North / WestEast.
func _blasco_llega(norman: Node2D, blasco: Node2D, caso: int) -> void:
	if caso == 1:
		await _con_pausas(blasco, [16, U, 24, U, R, U, U])  # WallyArriveNorth
		mirar(blasco, L)
		mirar(norman, R)
		girar_jugador(R)
		return
	mirar(norman, D)
	if caso != 0:
		girar_jugador(D)
	await _con_pausas(blasco, [16, U, 24, U, U])  # WallyArrive


## ExitGymWithWally*: BLASCO baja a la puerta y el jugador le sigue.
func _salir_con_blasco(norman: Node2D, blasco: Node2D, caso: int) -> void:
	var pasos_blasco: Array = [D, D, D]
	var pasos_jugador: Array = []
	var espera_jugador := 32
	match caso:
		0:
			mirar(norman, D)
			pasos_jugador = [R, D, D, D, D, D]
		1:
			pasos_blasco = [D, D, D, D]
			pasos_jugador = [D, D, D]
			espera_jugador = 48
		2:
			pasos_jugador = [D, D, D, D]
		3:
			pasos_blasco = [D, D, R, D]
			pasos_jugador = [D, D, D, R, D]
			girar_jugador(D)
	await en_paralelo([
		_blasco_sale.bind(blasco, pasos_blasco),
		_esperar_y_recorrer_jugador.bind(espera_jugador, pasos_jugador),
	])
	await esperar_fotogramas(8)


## WallyExit*: tras los pasos, mira arriba, delay_16 y walk_in_place_down.
func _blasco_sale(blasco: Node2D, pasos: Array) -> void:
	await recorrer(blasco, pasos)
	mirar(blasco, U)
	await esperar_fotogramas(16)
	mirar(blasco, D)


func _esperar_y_recorrer_jugador(fotogramas: int, direcciones: Array) -> void:
	await esperar_fotogramas(fotogramas)
	await recorrer_jugador(direcciones)


## applymovement con delay_N intercalados (los enteros son fotogramas).
func _con_pausas(npc: Node2D, pasos: Array) -> void:
	for paso in pasos:
		if paso is int:
			await esperar_fotogramas(paso)
		else:
			await caminar(npc, paso)


## Common_Movement_FacePlayer (GetDirectionToFace: primero el eje horizontal).
func _hacia_el_jugador(npc: Node2D) -> Vector2:
	var celda: Vector2i = admin.jugador.pos_celda_act
	if celda.x != npc.coord_celda.x:
		return L if celda.x < npc.coord_celda.x else R
	return U if celda.y < npc.coord_celda.y else D


## ReturnFromWallyTutorial: BLASCO devuelve el ZIGZAGOON, se despide y se va.
func despedida_blasco() -> void:
	var blasco := _npc("Blasco")
	var norman := _npc("Norman")
	if blasco == null or norman == null or not comenzar(_administrador()):
		return
	blasco.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	await esperar_fin_warp(admin)
	girar_jugador(U)  # OnWarp: TurnPlayerNorth
	await mensaje(T + "PAPA_QUE_TAL", false)
	await mensaje(T + "BLASCO_ADIOS")
	girar_jugador(D)
	await recorrer(blasco, [D, D, D])  # WallyExitGym
	await esperar_fotogramas(16)
	Singleton.play_sound.emit("puerta_salida")  # SE_EXIT
	blasco.visible = false  # removeobject 10 + FLAG_HIDE_WALLY_PETALBURG
	await esperar_fotogramas(30)
	girar_jugador(U)
	await mensaje(T + "PAPA_A_POR_MEDALLAS")
	HistoriaBlasco.despedir()
	terminar(false, [blasco, norman])
	colocar(blasco, BLASCO_PUERTA)

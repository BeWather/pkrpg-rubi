## evento_arrecipolis.gd
## Guiones del exterior de ARRECÍPOLIS (pokeruby data/maps/SootopolisCity/scripts.inc). Las celdas de Godot son las de
## Rubí; los NPC, carteles y puertas cerradas los añade herramientas/importar_eventos_arrecipolis.py. El estado vive
## en HistoriaArrecipolis.
##
## - OnLoad + OnTransition (aplicar_estado(), al cargar y en cada mapa_activado):
##   - sin FLAG_LEGEND_ESCAPED_SEAFLOOR_CAVERN el EXPERTO (objeto 3) tapa la CUEVA ANCESTRAL en (31,18) y la puerta del
##     GIMNASIO (31,32) está cerrada;
##   - con ella y sin FLAG_LEGENDARY_BATTLE_COMPLETED se cierran también las ocho casas (setmetatile
##     METATILE_Sootopolis_Door_Closed, con colisión: MB_CLOSED_SOOTOPOLIS_DOOR, «La puerta está cerrada.»);
##   - con FLAG_LEGENDARY_BATTLE_COMPLETED MÁXIMO espera frente al GIMNASIO (31,33) mirando abajo;
##   - con FLAG_SYS_WEATHER_CTRL las mujeres de la cueva suben a (29,19) y (33,19) y, con VAR_SOOTOPOLIS_STATE = 1,
##     MÁXIMO (29,6) y PLUBIO (30,6) esperan arriba. La sequía y su música las pone ClimaLegendario.
## - coord_event (25,6) con el estado en 1 (`cueva`, SootopolisCity_EventScript_LeadPlayerCaveOfOrigin): MÁXIMO se
##   sorprende y se acerca, te lleva hasta PLUBIO, que reconoce la ESFERA ROJA y os guía (con MÁXIMO detrás) hasta la
##   entrada de la cueva; el estado pasa a 2 y se quedan en (30,21) y (32,21).
## - MÁXIMO (`maximo`, SootopolisCity_EventScript_YoullBeOkay): antes del legendario, «No te preocupes...»; después,
##   «te lo debemos todo», mira abajo y se va volando (FLDEFF_NPCFLY_OUT) para siempre.
## El resto de vecinos son npc_dialogo_condicional / npc_regalo_diario (DULCINEA, KIRI en inglés).
extends EventoInteriorMalvalona
class_name EventoArrecipolis

const MOTIVO_PAUSA: StringName = &"arrecipolis"

const T := "ARRECIPOLIS_"
const TEXTOS_CUEVA: Array[String] = [T + "CUEVA_01", T + "CUEVA_02", T + "CUEVA_03", T + "CUEVA_04", T + "CUEVA_05",
	T + "CUEVA_06"]
const TEXTO_MAXIMO: String = T + "MAXIMO"
const TEXTO_MAXIMO_TRAS_LEGENDARIO: String = T + "MAXIMO_TRAS_LEGENDARIO"
const TEXTO_PUERTA_CERRADA: String = T + "PUERTA_CERRADA"

const SONIDO_EXCLAMACION: String = "SE_PIN"

## setobjectxyperm de OnLoad / OnTransition.
const CELDA_EXPERTO_CUEVA := Vector2i(31, 18)
const CELDAS_MUJERES_SEQUIA: Array[Vector2i] = [Vector2i(29, 19), Vector2i(33, 19)]
const CELDA_MAXIMO_ESPERA := Vector2i(29, 6)
const CELDA_PLUBIO_ESPERA := Vector2i(30, 6)
const CELDA_MAXIMO_GIMNASIO := Vector2i(31, 33)
## SootopolisCity_EventScript_LockCityDoors (las ocho casas) y la puerta del GIMNASIO.
const PUERTAS_CASAS: Array[Vector2i] = [Vector2i(9, 6), Vector2i(9, 17), Vector2i(9, 26), Vector2i(44, 17),
	Vector2i(8, 35), Vector2i(53, 28), Vector2i(45, 6), Vector2i(48, 25)]
const PUERTA_GIMNASIO := Vector2i(31, 32)

## Movimientos de LeadPlayerCaveOfOrigin.
const MAXIMO_SE_ACERCA: Array[Vector2] = [L, L, L]
const MAXIMO_HASTA_PLUBIO: Array[Vector2] = [R, R, R, U]
const JUGADOR_HASTA_PLUBIO: Array[Vector2] = [R, R, R, R]
const PLUBIO_GUIA_1: Array[Vector2] = [D, D, D, R, R, R, R, D, D, D, D, L, L, L, L, L, L]
const MAXIMO_SIGUE_1: Array[Vector2] = [D, R, D, D, D, R, R, R, R, D, D, D, D, L, L]
const JUGADOR_SIGUE_1: Array[Vector2] = [R, D, D, D, R, R, R, R, D, D, D, D, L, L, L, L, L]
const PLUBIO_GUIA_2: Array[Vector2] = [L, L, D, D, D, D, D, D, D, D, R, R, R, R, R, R]
const MAXIMO_SIGUE_2: Array[Vector2] = [L, L, L, L, L, L, D, D, D, D, D, D, D, D, R, R, R, R]
const JUGADOR_SIGUE_2: Array[Vector2] = [L, L, L, D, D, D, D, D, D, D, D, R, R, R, R, R]
## delay_16 ×2 al principio de WallaceContinue / PlayerContinue.
const FOTOGRAMAS_ESPERA_SEGUIR: int = 32
const FOTOGRAMAS_DELAY_48: int = 48
const FOTOGRAMAS_DELAY_30: int = 30
const FOTOGRAMAS_DELAY_50: int = 50

@export var mujeres: Array[NodePath] = []
@export var experto: NodePath
@export var plubio: NodePath
@export var maximo: NodePath
## Sprites de las puertas cerradas («Puerta_x_y») y sus carteles (mismo nombre).
@export var puertas_cerradas: NodePath
@export var carteles_puertas: NodePath
@export var datos_tiles: NodePath

## Celda y tipo de movimiento de cada NPC en la escena (las plantillas de Rubí).
var _plantillas: Dictionary = {}


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for ruta: NodePath in mujeres + [experto, plubio, maximo]:
		var npc := nodo(ruta)
		if npc != null:
			_plantillas[npc] = [npc.coord, npc.tipo_movimiento]
	for hijo in get_children():
		if hijo is DisparadorEventoPorTiles:
			hijo.evento_activado.connect(_on_disparador)
	escuchar(maximo, _on_maximo)
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)
	aplicar_estado()


func _on_mapa_activado(_por_warp: bool) -> void:
	if not _en_curso:
		aplicar_estado()


## OnLoad + OnTransition.
func aplicar_estado() -> void:
	var escapo := HistoriaArrecipolis.legendario_escapo()
	var completado := HistoriaArrecipolis.legendario_completado()
	for npc: Node2D in _plantillas:
		_recolocar(npc, _plantillas[npc][0], _plantillas[npc][1])
	if not escapo:
		_recolocar(nodo(experto), CELDA_EXPERTO_CUEVA)
	poner_puertas(escapo and not completado, not completado)
	if completado:
		_recolocar(nodo(maximo), CELDA_MAXIMO_GIMNASIO, NpcBase.TipoMovimientoNPC.MIRAR_ABAJO)
	if SistemaGuardado.get_flag(HistoriaArrecipolis.BANDERA_CLIMA):
		for i in mini(mujeres.size(), CELDAS_MUJERES_SEQUIA.size()):
			_recolocar(nodo(mujeres[i]), CELDAS_MUJERES_SEQUIA[i])
		if HistoriaArrecipolis.estado() == 1:
			_recolocar(nodo(maximo), CELDA_MAXIMO_ESPERA, NpcBase.TipoMovimientoNPC.MIRAR_DERECHA)
			_recolocar(nodo(plubio), CELDA_PLUBIO_ESPERA, NpcBase.TipoMovimientoNPC.MIRAR_IZQUIERDA)


## setobjectxyperm (+ setobjectmovementtype si `tipo` ≥ 0).
func _recolocar(npc: Node2D, celda: Vector2i, tipo: int = -1) -> void:
	if npc == null:
		return
	if tipo >= 0:
		npc.tipo_movimiento = tipo
	colocar(npc, celda)


## Puertas de las casas y del GIMNASIO: el sprite cerrado, el cartel «La puerta está cerrada.», la colisión y el warp.
func poner_puertas(casas_cerradas: bool, gimnasio_cerrado: bool) -> void:
	for celda in PUERTAS_CASAS:
		poner_puerta(celda, casas_cerradas)
	poner_puerta(PUERTA_GIMNASIO, gimnasio_cerrado)


func poner_puerta(celda: Vector2i, cerrada: bool) -> void:
	var nombre := nombre_puerta(celda)
	var contenedor := get_node_or_null(puertas_cerradas)
	var sprite := contenedor.get_node_or_null(nombre) as CanvasItem if contenedor != null else null
	if sprite != null:
		sprite.visible = cerrada
	var carteles := get_node_or_null(carteles_puertas)
	var cartel := carteles.get_node_or_null(nombre) if carteles != null else null
	if cartel != null:
		if cerrada and not cartel.is_in_group("Cartel"):
			cartel.add_to_group("Cartel")
		elif not cerrada and cartel.is_in_group("Cartel"):
			cartel.remove_from_group("Cartel")
	var tp := get_node_or_null(datos_tiles) as TPTileDataMap
	if tp != null:
		if cerrada:
			tp.set_flag(Vector2(celda), TPTileDataMap.Flags.BLOQUEO)
		else:
			tp.clear_flag(Vector2(celda), TPTileDataMap.Flags.BLOQUEO)
	var warp := warp_en(celda)
	if warp != null:
		var grupo: String = Warp.GRUPOS[warp.tipo_warp]
		if cerrada and warp.is_in_group(grupo):
			warp.remove_from_group(grupo)
		elif not cerrada and not warp.is_in_group(grupo):
			warp.add_to_group(grupo)


static func nombre_puerta(celda: Vector2i) -> String:
	return "Puerta_%d_%d" % [celda.x, celda.y]


func puerta_cerrada(celda: Vector2i) -> bool:
	var tp := get_node_or_null(datos_tiles) as TPTileDataMap
	return tp != null and tp.has_flag(Vector2(celda), TPTileDataMap.Flags.BLOQUEO)


## Warp de la escena en `celda` (o null).
func warp_en(celda: Vector2i) -> Warp:
	var mapa := obtener_mapa()
	if mapa == null:
		return null
	for hijo in mapa.get_children():
		var warp := hijo as Warp
		if warp != null and Vector2i(floori(warp.position.x / 16.0), floori(warp.position.y / 16.0)) == celda:
			return warp
	return null


func _on_disparador(id_evento: StringName) -> void:
	if id_evento == &"cueva" and not _en_curso and HistoriaArrecipolis.estado() == 1:
		await guiar_a_la_cueva()


## SootopolisCity_EventScript_LeadPlayerCaveOfOrigin.
func guiar_a_la_cueva() -> void:
	var npc_maximo := nodo(maximo)
	var npc_plubio := nodo(plubio)
	if npc_maximo == null or npc_plubio == null or not comenzar(_administrador()):
		return
	mirar(npc_maximo, L)
	girar_jugador(R)
	Singleton.play_sound.emit(SONIDO_EXCLAMACION)
	await exclamacion(npc_maximo)
	await esperar_fotogramas(FOTOGRAMAS_DELAY_48)
	await recorrer(npc_maximo, MAXIMO_SE_ACERCA)
	await mensaje(TEXTOS_CUEVA[0])
	await en_paralelo([
		recorrer.bind(npc_maximo, MAXIMO_HASTA_PLUBIO),
		recorrer_jugador.bind(JUGADOR_HASTA_PLUBIO),
	])
	mirar(npc_maximo, D)  # walk_in_place_fastest_down de StevenLeadPlayerToWallace
	await mensaje(TEXTOS_CUEVA[1], false)
	Singleton.play_sound.emit(SONIDO_EXCLAMACION)
	await exclamacion(npc_plubio)
	await esperar_fotogramas(FOTOGRAMAS_DELAY_48)
	await mensaje(TEXTOS_CUEVA[2])
	await esperar_fotogramas(FOTOGRAMAS_DELAY_30)
	await en_paralelo([
		recorrer.bind(npc_plubio, PLUBIO_GUIA_1),
		recorrer.bind(npc_maximo, MAXIMO_SIGUE_1),
		recorrer_jugador.bind(JUGADOR_SIGUE_1),
	])
	mirar(npc_plubio, R)
	girar_jugador(R)
	await esperar_fotogramas(FOTOGRAMAS_DELAY_30)
	mirar(npc_maximo, D)
	await mensaje(TEXTOS_CUEVA[3])
	await esperar_fotogramas(FOTOGRAMAS_DELAY_30)
	await en_paralelo([
		_recorrer_tras_espera.bind(npc_plubio, PLUBIO_GUIA_2),
		_recorrer_jugador_tras_espera.bind(JUGADOR_SIGUE_2),
		recorrer.bind(npc_maximo, MAXIMO_SIGUE_2),
	])
	mirar(npc_plubio, L)
	await mensaje(TEXTOS_CUEVA[4], false)
	girar_jugador(L)
	await mensaje(TEXTOS_CUEVA[5])
	# moveobjectoffscreen + setobjectmovementtype: se quedan donde llegaron (las plantillas de Rubí).
	_recolocar(npc_plubio, npc_plubio.coord_celda, NpcBase.TipoMovimientoNPC.MIRAR_IZQUIERDA)
	_recolocar(npc_maximo, npc_maximo.coord_celda, NpcBase.TipoMovimientoNPC.MIRAR_DERECHA)
	SistemaGuardado.set_contador(HistoriaArrecipolis.CONTADOR_ESTADO, 2)
	terminar(false, [npc_plubio, npc_maximo])


## delay_16 ×2 y los pasos (WallaceContinueLeadPlayerToCave / PlayerContinueFollowWallaceToCave).
func _recorrer_tras_espera(npc: Node2D, pasos: Array[Vector2]) -> void:
	await esperar_fotogramas(FOTOGRAMAS_ESPERA_SEGUIR)
	await recorrer(npc, pasos)


func _recorrer_jugador_tras_espera(pasos: Array[Vector2]) -> void:
	await esperar_fotogramas(FOTOGRAMAS_ESPERA_SEGUIR)
	await recorrer_jugador(pasos)


## SootopolisCity_EventScript_YoullBeOkay.
func _on_maximo(npc: Node2D) -> void:
	if not empezar_con(npc):
		return
	if not HistoriaArrecipolis.legendario_completado():
		await mensaje(TEXTO_MAXIMO)
		terminar(false, [npc])
		return
	await mensaje(TEXTO_MAXIMO_TRAS_LEGENDARIO)
	admin.cuadro_dialogo.cerrar()  # closemessage
	mirar(npc, D)
	await esperar_fotogramas(FOTOGRAMAS_DELAY_50)
	await salir_volando(npc)  # removeobject VAR_LAST_TALKED (FLAG_HIDE_STEVEN_SOOTOPOLIS)
	SistemaGuardado.set_flag(HistoriaArrecipolis.BANDERA_MAXIMO_VISIBLE, false)
	terminar(false, [npc])

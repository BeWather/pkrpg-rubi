## evento_malvalanova.gd
## Guiones de MALVALANOVA (pokeruby data/maps/NewMauville_Entrance y NewMauville_Inside/scripts.inc). Las
## escenas las genera herramientas/importar_malvalanova.py; las celdas de Godot son las de Rubí y los
## metatiles se pintan sobre su atlas de dos capas con EventoNaoAbandonada.pintar_metatile.
##
## Entrada (`entrada = true`):
## - OnLoad (NewMauville_Entrance_EventScript_15E4A1): con VAR_NEW_MAUVILLE_STATE = 0 (sin
##   `malvalanova_puerta_abierta`) la puerta lleva los metatiles cerrados, impasables, y su Warp no funciona.
## - `puerta` (coord_event (4,2), NewMauville_Entrance_EventScript_15E4DC): mira arriba, «la puerta está
##   cerrada»; con la LLAVE SÓTANO pregunta si usarla y, con SÍ, abre la puerta (SE_BANG, estado 1). La
##   llave no se gasta (checkitem).
##
## Interior:
## - OnTransition (NewMauville_Inside_MapScript1_15E593): VAR_TEMP_1 = VAR_TEMP_2 = 0, es decir, las
##   barreras azules y verdes levantadas y los botones sin pulsar, como en el layout.
## - `boton_azul` (coord_events con VAR_TEMP_1 = 0, _EventScript_15E5AA): SE_PIN, bajan las barreras
##   azules y suben las verdes (_EventScript_15E5DA). `boton_verde` (VAR_TEMP_2 = 0, _15E5C2): al revés
##   (_EventScript_15E728).
## - `generador` (coord_event (33,6) con VAR_NEW_MAUVILLE_STATE = 1, _EventScript_15E876): pisa el
##   interruptor, se apaga el generador y VAR_NEW_MAUVILLE_STATE = 2 (`nueva_malvalona_completada`, la
##   bandera que ya consulta ERICO en CIUDAD MALVALONA). OnLoad (_15E59E) lo deja apagado al volver.
## - Carteles del generador (`carteles`, _EventScript_15E8E0): «irradia calor» o «está apagado».
##
## Los VOLTORB de las bolas son PokemonEstaticoOverworld de la escena y no pasan por aquí.
extends EventoInteriorMalvalona
class_name EventoMalvalanova

enum Barreras { LEVANTADAS, AZUL_BAJADA, VERDE_BAJADA }

const MOTIVO_PAUSA: StringName = &"malvalanova"
const T := "MALVALANOVA_"
const TEXTO_PUERTA_CERRADA: String = T + "PUERTA_CERRADA"
const TEXTO_USAR_LLAVE: String = T + "PUERTA_USAR_LLAVE"
const TEXTO_PUERTA_ABIERTA: String = T + "PUERTA_ABIERTA"
const TEXTO_GENERADOR: String = T + "GENERADOR"
const TEXTO_GENERADOR_APAGADO: String = T + "GENERADOR_APAGADO"
const TEXTO_INTERRUPTOR: String = T + "GENERADOR_INTERRUPTOR"
const SONIDO_PUERTA: String = "SE_BANG"
const SONIDO_BOTON: String = "SE_PIN"

## VAR_NEW_MAUVILLE_STATE >= 1.
const BANDERA_PUERTA_ABIERTA: String = "malvalanova_puerta_abierta"
## VAR_NEW_MAUVILLE_STATE == 2 (HistoriaMalvalona.BANDERA_NUEVA_MALVALONA).
const BANDERA_GENERADOR_APAGADO: String = "nueva_malvalona_completada"
const OBJETO_LLAVE: String = "LLAVESOTANO"

## Puerta de la entrada: celda -> [metatile cerrado, metatile abierto, impasable abierta]
## (METATILE_Facility_NewMauvilleDoor_Closed/Open_Tile0..5). Cerrada es impasable entera.
const PUERTA: Dictionary = {
	Vector2i(3, 0): [0x314, 0x2C3, false], Vector2i(4, 0): [0x315, 0x2C4, false], Vector2i(5, 0): [0x316, 0x2C5, false],
	Vector2i(3, 1): [0x31C, 0x2CB, true], Vector2i(4, 1): [0x31D, 0x2CC, false], Vector2i(5, 1): [0x31E, 0x2CD, true],
}
const CELDA_WARP_PUERTA := Vector2i(4, 1)

## Celda de arriba de cada barrera (cuatro celdas hacia abajo).
const BARRERAS_AZULES: Array[Vector2i] = [Vector2i(23, 34), Vector2i(10, 16), Vector2i(10, 0)]
const BARRERAS_VERDES: Array[Vector2i] = [Vector2i(37, 33), Vector2i(28, 22), Vector2i(10, 24), Vector2i(21, 2)]
const BOTONES_AZULES: Array[Vector2i] = [Vector2i(6, 11), Vector2i(13, 10), Vector2i(16, 22), Vector2i(4, 26), Vector2i(30, 38)]
const BOTONES_VERDES: Array[Vector2i] = [Vector2i(2, 11), Vector2i(17, 10), Vector2i(25, 18), Vector2i(18, 36)]
## METATILE_BikeShop_Barrier_Blue/Green_Top, _TopMid, _BottomMid, _Bottom (todas impasables).
const BARRERA_AZUL: Array[int] = [0x2B7, 0x2BF, 0x2C7, 0x2CF]
const BARRERA_VERDE: Array[int] = [0x2B6, 0x2BE, 0x2C6, 0x2CE]
## Barrera bajada: Barrier_Hidden_Top y _Bottom (impasables), Floor_Shadow_Top y Wall_Edge_Top (pasables).
const BARRERA_OCULTA: Array[int] = [0x269, 0x271, 0x26D, 0x281]
const BARRERA_OCULTA_IMPASABLE: Array[bool] = [true, true, false, false]
const BOTON_AZUL: int = 0x236
const BOTON_VERDE: int = 0x22E
const BOTON_PULSADO: int = 0x24F

## Generador (NewMauville_Inside_EventScript_15E88B): interruptor pulsado y METATILE_BikeShop_Generator_Off_Tile0..7.
const CELDA_INTERRUPTOR := Vector2i(33, 6)
const CELDA_GENERADOR := Vector2i(32, 2)
const GENERADOR_APAGADO: int = 0x2F0

## NewMauville_Entrance (puerta) o NewMauville_Inside (barreras y generador).
@export var entrada: bool = false
## Carteles del generador (CartelEvento).
@export var carteles: Array[NodePath] = []
@export var suelo: NodePath
@export var superior: NodePath
@export var datos_tiles: NodePath

## VAR_TEMP_1 / VAR_TEMP_2 del interior.
var barreras: Barreras = Barreras.LEVANTADAS


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for hijo in get_children():
		if hijo is DisparadorEventoPorTiles:
			hijo.evento_activado.connect(_on_disparador)
	for ruta in carteles:
		var cartel := get_node_or_null(ruta) as CartelEvento
		if cartel != null:
			cartel.accionado.connect(_on_cartel_generador)
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)
	# Los Warp se apuntan a su grupo en su propio _ready (después de este nodo).
	aplicar_estado.call_deferred()


func _on_mapa_activado(_por_warp: bool) -> void:
	aplicar_estado()


## OnTransition + OnLoad de cada mapa.
func aplicar_estado() -> void:
	if entrada:
		poner_puerta(SistemaGuardado.get_flag(BANDERA_PUERTA_ABIERTA))
		return
	poner_barreras(Barreras.LEVANTADAS)
	if SistemaGuardado.get_flag(BANDERA_GENERADOR_APAGADO):
		apagar_generador()


func _on_disparador(id_evento: StringName) -> void:
	match id_evento:
		&"puerta":
			if not SistemaGuardado.get_flag(BANDERA_PUERTA_ABIERTA):
				await puerta()
		&"boton_azul":
			if barreras != Barreras.AZUL_BAJADA:
				pulsar_boton(Barreras.AZUL_BAJADA)
		&"boton_verde":
			if barreras != Barreras.VERDE_BAJADA:
				pulsar_boton(Barreras.VERDE_BAJADA)
		&"generador":
			if not SistemaGuardado.get_flag(BANDERA_GENERADOR_APAGADO):
				await interruptor_generador()


## ============================================================================
## Entrada: la puerta de la LLAVE SÓTANO
## ============================================================================

## NewMauville_Entrance_EventScript_15E4DC.
func puerta() -> void:
	if not comenzar(_administrador()):
		return
	girar_jugador(U)  # Common_Movement_WalkInPlaceFastestUp
	await mensaje(TEXTO_PUERTA_CERRADA)
	if not HistoriaMalvalona.tiene(OBJETO_LLAVE) or not await preguntar_si_no(TEXTO_USAR_LLAVE):
		terminar()
		return
	await mensaje(TEXTO_PUERTA_ABIERTA)
	poner_puerta(true)
	Singleton.play_sound.emit(SONIDO_PUERTA)
	SistemaGuardado.set_flag(BANDERA_PUERTA_ABIERTA, true)  # setvar VAR_NEW_MAUVILLE_STATE, 1
	terminar()


func poner_puerta(abierta: bool) -> void:
	for celda: Vector2i in PUERTA:
		var datos: Array = PUERTA[celda]
		_pintar(celda, int(datos[1] if abierta else datos[0]), bool(datos[2]) if abierta else true)
	var warp := warp_en(CELDA_WARP_PUERTA)
	if warp == null:
		return
	var grupo: String = Warp.GRUPOS[warp.tipo_warp]
	if abierta and not warp.is_in_group(grupo):
		warp.add_to_group(grupo)
	elif not abierta and warp.is_in_group(grupo):
		warp.remove_from_group(grupo)


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


## ============================================================================
## Interior: barreras y generador
## ============================================================================

## NewMauville_Inside_EventScript_15E5AA / _15E5C2 (lockall, playse SE_PIN, setmetatiles, releaseall).
func pulsar_boton(estado: Barreras) -> void:
	Singleton.play_sound.emit(SONIDO_BOTON)
	poner_barreras(estado)


## LEVANTADAS es el layout; AZUL_BAJADA, _15E5DA; VERDE_BAJADA, _15E728.
func poner_barreras(estado: Barreras) -> void:
	barreras = estado
	for celda in BARRERAS_AZULES:
		_poner_barrera(celda, BARRERA_AZUL, estado == Barreras.AZUL_BAJADA)
	for celda in BARRERAS_VERDES:
		_poner_barrera(celda, BARRERA_VERDE, estado == Barreras.VERDE_BAJADA)
	for celda in BOTONES_AZULES:
		_pintar(celda, BOTON_PULSADO if estado == Barreras.AZUL_BAJADA else BOTON_AZUL, false)
	for celda in BOTONES_VERDES:
		_pintar(celda, BOTON_PULSADO if estado == Barreras.VERDE_BAJADA else BOTON_VERDE, false)


func _poner_barrera(arriba: Vector2i, levantada: Array[int], bajada: bool) -> void:
	for i in 4:
		var celda := arriba + Vector2i(0, i)
		if bajada:
			_pintar(celda, BARRERA_OCULTA[i], BARRERA_OCULTA_IMPASABLE[i])
		else:
			_pintar(celda, levantada[i], true)


## NewMauville_Inside_EventScript_15E876.
func interruptor_generador() -> void:
	if not comenzar(_administrador()):
		return
	await mensaje(TEXTO_INTERRUPTOR)
	apagar_generador()
	SistemaGuardado.set_flag(BANDERA_GENERADOR_APAGADO, true)  # setvar VAR_NEW_MAUVILLE_STATE, 2
	terminar()


## NewMauville_Inside_EventScript_15E88B.
func apagar_generador() -> void:
	_pintar(CELDA_INTERRUPTOR, BOTON_PULSADO, false)
	for i in 8:
		_pintar(CELDA_GENERADOR + Vector2i(i % 4, i / 4), GENERADOR_APAGADO + i, true)


static func texto_generador() -> String:
	return TEXTO_GENERADOR_APAGADO if SistemaGuardado.get_flag(BANDERA_GENERADOR_APAGADO) else TEXTO_GENERADOR


## NewMauville_Inside_EventScript_15E8E0.
func _on_cartel_generador(_cartel: CartelEvento) -> void:
	if not comenzar(_administrador()):
		return
	await mensaje(texto_generador())
	terminar()


func _pintar(celda: Vector2i, metatile: int, impasable: bool) -> void:
	EventoNaoAbandonada.pintar_metatile(get_node_or_null(suelo) as TileMapLayer, get_node_or_null(superior) as TileMapLayer,
			get_node_or_null(datos_tiles) as TPTileDataMap, celda, metatile, impasable)

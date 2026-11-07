## evento_casa_treta_prueba.gd
## Evento común de los acertijos de la CASA TRETA (pokeruby data/maps/
## Route110_TrickHousePuzzle1..8/scripts.inc). Cada escena `ruta_110_casa_treta_pruebaN`
## lleva su propio nodo (esta clase o una subclase) y se controla sola; el contrato de
## entrada/salida está en documentacion/20261014-casa-treta-fase1.md.
##
## Lo que resuelve esta base (igual en las 8 pruebas):
##  - PERGAMINO (bg_event `sign`, `Route110_TrickHousePuzzleN_EventScript_Scroll`):
##    primera lectura «encontró un pergamino» + fanfarria + «memorizó el código»
##    (PUZZLE_N_STATE 0 -> 1); después «Contiene un código secreto.».
##  - PUERTA (13,1) (`Route110_TrickHousePuzzle_EventScript_Door`, comportamiento
##    MB_TRICK_HOUSE_PUZZLE_DOOR): solo se lee mirando al norte desde (13,2). Sin pergamino
##    leído, «escribe el código secreto aquí»; con él, el texto del código (desplazado un
##    acertijo, ver HistoriaCasaTreta), SE_PIN, la puerta pasa a 0x20B (escalera) y deja de
##    bloquear (PUZZLE_N_STATE -> 2). El número de prueba sale de `numero_prueba`, no de
##    ROOMS_COMPLETED como en Rubí (ver el aviso del análisis §2.5).
##  - REAPERTURA: con PUZZLE_N_STATE == 2 la puerta se carga ya abierta en las ocho pruebas
##    (Rubí solo lo hacía en la 1: es el fallo que decidió corregir el usuario).
##  - Disparadores por tiles hijos (coord_events): llegan a `_on_disparador(id)`, que
##    implementan las subclases (botones de la 2 y la 3, MECAÑECOS de la 5).
##
## `setmetatile` + `DrawWholeMapView` = `poner_metatile()`: cambia el atlas de la capa
## Suelo y pone o quita BLOQUEO en el TPTileDataMap (el último argumento de setmetatile de
## Rubí es «impasable»). Sustituye a un TileAlterno por celda: P3 cambia ~100 celdas de
## golpe y no tiene sentido un nodo por cada una; el patrón es el mismo que usan
## EventoCasaTreta (cortina) y el gimnasio de PETALIA (correderas).
extends EventoGuionizado
class_name EventoCasaTretaPrueba

const MOTIVO_PAUSA: StringName = &"ruta_110_casa_treta_prueba"
## Fuente 0 de `tileset_edificios.tres`.
const FUENTE_ATLAS: int = 0
## `gTileset_TrickHousePuzzle` (ids 0x200..0x294): celda de atlas = (24 + id % 8, id / 8).
const METATILE_BASE: int = 0x200
const COLUMNA_BASE: int = 24
## Celda de la puerta del acertijo y su 0x20B abierta (METATILE_TrickHousePuzzle_Stairs_Down).
const CELDA_PUERTA: Vector2i = Vector2i(13, 1)
const METATILE_ESCALERA: int = 0x20B
const METATILE_BOTON_ARRIBA: int = 0x258
const METATILE_BOTON_PULSADO: int = 0x259

## SE_PIN al abrir la puerta o pulsar un botón (`playse SE_PIN`).
const SONIDO_PIN: String = "SE_PIN"

const TEXTO_PERGAMINO_ENCONTRADO: String = "CASA_TRETA_PERGAMINO_ENCONTRADO"
const TEXTO_PERGAMINO_MEMORIZADO: String = "CASA_TRETA_PERGAMINO_MEMORIZADO"
const TEXTO_PERGAMINO_LEIDO: String = "CASA_TRETA_PERGAMINO_LEIDO"
const TEXTO_PUERTA_CERRADA: String = "CASA_TRETA_PUERTA_CERRADA"
const PLANTILLA_TEXTO_CODIGO: String = "CASA_TRETA_PUERTA_CODIGO_%d"

## 1..8: acertijo al que pertenece la escena.
@export_range(1, 8) var numero_prueba: int = 1
## Pergamino (bg_event `sign`, cualquier dirección): CartelEvento.
@export var pergamino: NodePath
## Puerta (13,1): CartelEvento mirando al norte.
@export var puerta: NodePath
## Capa `Suelo` y capa de colisiones de la escena.
@export var capa_suelo: NodePath
@export var datos_tiles: NodePath

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null
## false omite esperas, exclamaciones y movimientos (tests).
var con_esperas: bool = true
## La puerta (13,1) está ya abierta (estado 2 o recién abierta).
var puerta_abierta: bool = false


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	var cartel := get_node_or_null(pergamino)
	if cartel is CartelEvento:
		cartel.accionado.connect(_on_pergamino)
	var cartel_puerta := get_node_or_null(puerta)
	if cartel_puerta is CartelEvento:
		cartel_puerta.accionado.connect(_on_puerta)
	_conectar_disparadores(self)
	_preparar()
	# ON_LOAD de la prueba 1 de Rubí, extendido a las 8: la puerta ya abierta vuelve abierta.
	if HistoriaCasaTreta.puerta_abierta(numero_prueba):
		abrir_puerta_visual()


## Punto de extensión: configuración de la subclase tras conectar las señales.
func _preparar() -> void:
	pass


func _conectar_disparadores(nodo: Node) -> void:
	for hijo in nodo.get_children():
		if hijo is DisparadorEventoPorTiles:
			hijo.evento_activado.connect(_on_disparador)
		else:
			_conectar_disparadores(hijo)


## Punto de extensión: un coord_event de la prueba (id = `id_evento` del disparador).
func _on_disparador(_id_evento: StringName) -> void:
	pass


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


## Se anula en tests (`con_esperas = false`).
func esperar_fotogramas(fotogramas: int) -> void:
	if con_esperas:
		await super.esperar_fotogramas(fotogramas)


func _sonido(clave: String) -> void:
	Singleton.play_sound.emit(clave)


## ============================================================================
## TILES (setmetatile)
## ============================================================================

## Celda del atlas de `gTileset_TrickHousePuzzle` de un metatile de Rubí.
static func atlas_de_metatile(metatile: int) -> Vector2i:
	var indice := metatile - METATILE_BASE
	return Vector2i(COLUMNA_BASE + indice % 8, indice / 8)


## setmetatile(x, y, metatile, impasable). No redibuja nada más: el TileMapLayer ya lo
## hace al cambiar la celda (DrawWholeMapView).
func poner_metatile(celda: Vector2i, metatile: int, impasable: bool) -> void:
	var capa := get_node_or_null(capa_suelo) as TileMapLayer
	if capa != null:
		capa.set_cell(celda, FUENTE_ATLAS, atlas_de_metatile(metatile))
	var datos := get_node_or_null(datos_tiles) as TPTileDataMap
	if datos == null:
		return
	if impasable:
		datos.set_flag(Vector2(celda), TPTileDataMap.Flags.BLOQUEO)
	else:
		datos.clear_flag(Vector2(celda), TPTileDataMap.Flags.BLOQUEO)


## Metatile actual de la celda (atlas) o (-1, -1) si no hay capa o la celda está vacía.
func atlas_en_celda(celda: Vector2i) -> Vector2i:
	var capa := get_node_or_null(capa_suelo) as TileMapLayer
	if capa == null:
		return Vector2i(-1, -1)
	return capa.get_cell_atlas_coords(celda)


## ¿La celda bloquea ahora el paso?
func bloquea_celda(celda: Vector2i) -> bool:
	var datos := get_node_or_null(datos_tiles) as TPTileDataMap
	if datos == null:
		return false
	return datos.has_flag(Vector2(celda), TPTileDataMap.Flags.BLOQUEO)


## `setmetatile 13, 1, METATILE_TrickHousePuzzle_Stairs_Down, 0`.
func abrir_puerta_visual() -> void:
	puerta_abierta = true
	poner_metatile(CELDA_PUERTA, METATILE_ESCALERA, false)


## ============================================================================
## PERGAMINO Y PUERTA
## ============================================================================

func _on_pergamino(_cartel: CartelEvento) -> void:
	await leer_pergamino()


## `Route110_TrickHousePuzzleN_EventScript_Scroll` + `FoundScroll`/`ReadScrollAgain`.
func leer_pergamino() -> void:
	if _en_curso or not comenzar(_administrador()):
		return
	if HistoriaCasaTreta.leer_pergamino(numero_prueba):
		await mensaje_con_fanfarria(TEXTO_PERGAMINO_ENCONTRADO)  # MUS_OBTAIN_ITEM
		await mensaje(TEXTO_PERGAMINO_MEMORIZADO)
	else:
		await mensaje(TEXTO_PERGAMINO_LEIDO)
	terminar()


func _on_puerta(_cartel: CartelEvento) -> void:
	await usar_puerta()


## `Route110_TrickHousePuzzle_EventScript_Door` + `PuzzleN_EventScript_Door`.
func usar_puerta() -> void:
	if puerta_abierta or _en_curso or not comenzar(_administrador()):
		return
	if not HistoriaCasaTreta.abrir_puerta(numero_prueba):
		await mensaje(TEXTO_PUERTA_CERRADA)
		terminar()
		return
	await mensaje(PLANTILLA_TEXTO_CODIGO % numero_prueba)
	_sonido(SONIDO_PIN)
	abrir_puerta_visual()
	terminar()

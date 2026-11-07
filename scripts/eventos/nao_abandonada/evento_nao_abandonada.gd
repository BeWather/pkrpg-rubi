## evento_nao_abandonada.gd
## Guiones de la NAO ABANDONADA (pokeruby AbandonedShip_*/scripts.inc) que no son un msgbox, un
## entrenador ni un objeto. Cada escena (generada por herramientas/importar_nao_abandonada.py) asigna
## solo lo que tiene:
##
## - Puertas con llave (`puertas`, carteles CartelEvento): el ALMACÉN del sótano
##   (AbandonedShip_Corridors_B1F, LLAVE ALMACÉN) y las CABINAS 1, 2, 4 y 6 de la planta oculta
##   (AbandonedShip_HiddenFloorCorridors, LL. CABINA 1/2/4/6). OnLoad: sin su FLAG_USED_*_KEY la puerta
##   lleva el metatile cerrado (METATILE_Facility_IntactDoor_Bottom_Locked / DoorIndent_Locked) y su Warp no
##   funciona; con ella, el abierto. Al leer el cartel: «la puerta está abierta», «está cerrada» (sin la
##   llave) o mete la llave (SE_PIN), la gasta, pone la bandera y abre la puerta.
## - AYUDANTE del CAP. BABOR (AbandonedShip_CaptainsOffice_EventScript_CaptSternAide): con el ESCÁNER ya
##   cambiado (FLAG_EXCHANGED_SCANNER = `portual_escaner_cambiado`) o recogido y sin llevarlo, «este barco
##   se llama S.S. CACTUS»; llevándolo, que se lo lleves al CAP. BABOR; si no, que aún no lo ha encontrado.
## - Destellos de las cabinas ocultas (`destellos_cabinas`, AbandonedShip_HiddenFloorRooms_OnFrame): al
##   entrar en una cabina brillan su chatarra y la llave oculta que aún no se haya recogido (FLDEFF_SPARKLE).
extends EventoInteriorMalvalona
class_name EventoNaoAbandonada

const MOTIVO_PAUSA: StringName = &"nao_abandonada"
const T := "NAO_ABANDONADA_"
const TEXTO_PUERTA_ABIERTA: String = T + "PUERTA_ABIERTA"
const SONIDO_LLAVE: String = "SE_PIN"

## Carteles de puerta (nombre del nodo) -> datos de la puerta. `celda` es la del Warp que abre.
const PUERTAS: Dictionary = {
	"PuertaAlmacen": {"celda": Vector2i(11, 4), "objeto": "LLAVEALMACEN",
		"bandera": "nao_abandonada_llave_almacen_usada", "cerrada": T + "PUERTA_ALMACEN_CERRADA",
		"llave": T + "PUERTA_ALMACEN_LLAVE", "metatile_cerrado": 0x233, "metatile_abierto": 0x22B, "bloqueo": true},
	"PuertaCabina1": {"celda": Vector2i(3, 8), "objeto": "LLAVECAB1",
		"bandera": "nao_abandonada_llave_cabina1_usada", "cerrada": T + "PUERTA_CABINA1_CERRADA",
		"llave": T + "PUERTA_LLAVE", "metatile_cerrado": 0x233, "metatile_abierto": 0x22B, "bloqueo": true},
	"PuertaCabina2": {"celda": Vector2i(6, 8), "objeto": "LLAVECAB2",
		"bandera": "nao_abandonada_llave_cabina2_usada", "cerrada": T + "PUERTA_CABINA2_CERRADA",
		"llave": T + "PUERTA_LLAVE", "metatile_cerrado": 0x233, "metatile_abierto": 0x22B, "bloqueo": true},
	"PuertaCabina4": {"celda": Vector2i(3, 3), "objeto": "LLAVECAB4",
		"bandera": "nao_abandonada_llave_cabina4_usada", "cerrada": T + "PUERTA_CABINA4_CERRADA",
		"llave": T + "PUERTA_LLAVE", "metatile_cerrado": 0x234, "metatile_abierto": 0x21A, "bloqueo": false},
	"PuertaCabina6": {"celda": Vector2i(9, 3), "objeto": "LLAVECAB6",
		"bandera": "nao_abandonada_llave_cabina6_usada", "cerrada": T + "PUERTA_CABINA6_CERRADA",
		"llave": T + "PUERTA_LLAVE", "metatile_cerrado": 0x234, "metatile_abierto": 0x21A, "bloqueo": false},
}

## AYUDANTE del CAP. BABOR.
const BANDERA_ESCANER_CAMBIADO: String = "portual_escaner_cambiado"
## FLAG_ITEM_ABANDONED_SHIP_HIDDEN_FLOOR_ROOM_2_SCANNER: la bandera del ItemOverworld del ESCÁNER.
const BANDERA_ESCANER_RECOGIDO: String = "item_nao_abandonada_cabinas_ocultas_escaner_01"
const OBJETO_ESCANER: String = "ESCANER"
const TEXTO_SIN_ESCANER: String = T + "DESPACHO_AYUDANTE_SIN_ESCANER"
const TEXTO_CON_ESCANER: String = T + "DESPACHO_AYUDANTE_CON_ESCANER"
const TEXTO_SS_CACTUS: String = T + "DESPACHO_AYUDANTE_SS_CACTUS"

## Destellos de las cabinas (AbandonedShip_HiddenFloorRooms_EventScript_EnterRm1..6): cabina -> chatarra que
## brilla siempre y [bandera de la llave oculta, celda] que brilla mientras no se recoja. La cabina 3 no brilla
## nada si su llave ya se recogió.
const PREFIJO_LLAVE: String = "item_nao_abandonada_cabinas_ocultas_llave_cabina%d_oculta_01"
const DESTELLOS: Dictionary = {
	1: {"chatarra": [Vector2i(10, 10)], "llave": 4, "celda_llave": Vector2i(1, 12)},
	3: {"chatarra": [], "llave": 1, "celda_llave": Vector2i(42, 10)},
	4: {"chatarra": [Vector2i(8, 5), Vector2i(11, 3)], "llave": 6, "celda_llave": Vector2i(1, 2)},
	5: {"chatarra": [Vector2i(16, 3), Vector2i(25, 2), Vector2i(24, 6)], "llave": 2, "celda_llave": Vector2i(20, 5)},
}
const FOTOGRAMAS_ANTES_DESTELLO: int = 20
const FOTOGRAMAS_TRAS_DESTELLO: int = 10
## Última fila de llegada de las cabinas de arriba (4..6).
const FILA_MAX_CABINAS_ARRIBA: int = 2

const FUENTE_ATLAS: int = 0
const COLUMNAS_ATLAS: int = 8

@export var ayudante: NodePath
@export var puertas: Array[NodePath] = []
@export var suelo: NodePath
@export var superior: NodePath
@export var datos_tiles: NodePath
@export var destellos_cabinas: bool = false

## Destellos lanzados en la última entrada (tests).
var ultimos_destellos: Array[Vector2i] = []
## false omite las esperas y los efectos de destello (tests).
var con_destellos: bool = true


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	escuchar(ayudante, _on_ayudante)
	for ruta in puertas:
		var cartel := get_node_or_null(ruta) as CartelEvento
		if cartel != null:
			cartel.accionado.connect(_on_cartel_puerta)
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)
	# Los Warp se apuntan a su grupo en su propio _ready (después de este nodo).
	aplicar_estado.call_deferred()


func _on_mapa_activado(por_warp: bool) -> void:
	aplicar_estado()
	if destellos_cabinas and por_warp:
		await esperar_fin_warp(_administrador())
		var admin_actual := _administrador()
		var jugador: Node = admin_actual.get("jugador") if admin_actual != null else null
		# OnFrame corre tras el paso de salida de la puerta: las cabinas de arriba se llegan por la fila 1.
		while is_instance_valid(jugador) and jugador.get("paso_en_curso") == true:
			await get_tree().process_frame
		if is_instance_valid(jugador):
			await entrar_en_cabina(Vector2i(jugador.get("pos_celda_act")))


## ============================================================================
## Puertas con llave
## ============================================================================

## OnLoad: cada puerta con su metatile y su Warp según la bandera de la llave.
func aplicar_estado() -> void:
	for ruta in puertas:
		var nombre := String(ruta.get_name(ruta.get_name_count() - 1))
		if PUERTAS.has(nombre):
			var datos: Dictionary = PUERTAS[nombre]
			_poner_puerta(datos, SistemaGuardado.get_flag(str(datos["bandera"])))


static func puerta_abierta(nombre_cartel: String) -> bool:
	return PUERTAS.has(nombre_cartel) and SistemaGuardado.get_flag(str(PUERTAS[nombre_cartel]["bandera"]))


## AbandonedShip_Corridors_B1F_EventScript_StorageRoomDoor / HiddenFloorCorridors_EventScript_Room*Door.
func _on_cartel_puerta(cartel: CartelEvento) -> void:
	if _en_curso or not comenzar(_administrador()):
		return
	var datos: Dictionary = PUERTAS.get(String(cartel.name), {})
	if datos.is_empty():
		terminar()
		return
	if SistemaGuardado.get_flag(str(datos["bandera"])):
		await mensaje(TEXTO_PUERTA_ABIERTA)
		terminar()
		return
	var objeto := str(datos["objeto"])
	var bolsillo := _bolsillo(objeto)
	if not SistemaGuardado.tiene_objeto(objeto, 1, bolsillo):
		await mensaje(str(datos["cerrada"]))
		terminar()
		return
	await mensaje(str(datos["llave"]))
	Singleton.play_sound.emit(SONIDO_LLAVE)
	SistemaGuardado.quitar_objeto_jugador(objeto, 1, bolsillo)
	SistemaGuardado.set_flag(str(datos["bandera"]), true)
	_poner_puerta(datos, true)
	terminar()


func _poner_puerta(datos: Dictionary, abierta: bool) -> void:
	var celda: Vector2i = datos["celda"]
	var metatile := int(datos["metatile_abierto"] if abierta else datos["metatile_cerrado"])
	pintar_metatile(get_node_or_null(suelo) as TileMapLayer, get_node_or_null(superior) as TileMapLayer,
			get_node_or_null(datos_tiles) as TPTileDataMap, celda, metatile, bool(datos["bloqueo"]))
	var warp := warp_en(celda)
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


## setmetatile x, y, metatile, impassable sobre el atlas de dos capas de importar_nao_abandonada.py
## (metatile secundario 0x200 + n: abajo en (n % 8, n / 8), arriba en (8 + n % 8, n / 8)).
static func pintar_metatile(capa_suelo: TileMapLayer, capa_superior: TileMapLayer, tp: TPTileDataMap,
		celda: Vector2i, metatile: int, bloqueo: bool) -> void:
	var n := metatile - 0x200
	var abajo := Vector2i(n % COLUMNAS_ATLAS, n / COLUMNAS_ATLAS)
	_pintar(capa_suelo, celda, abajo)
	_pintar(capa_superior, celda, abajo + Vector2i(COLUMNAS_ATLAS, 0))
	if tp == null:
		return
	if bloqueo:
		tp.set_flag(Vector2(celda), TPTileDataMap.Flags.BLOQUEO)
	else:
		tp.clear_flag(Vector2(celda), TPTileDataMap.Flags.BLOQUEO)


static func _pintar(capa: TileMapLayer, celda: Vector2i, atlas: Vector2i) -> void:
	if capa == null:
		return
	var fuente := capa.tile_set.get_source(FUENTE_ATLAS) as TileSetAtlasSource if capa.tile_set != null else null
	if fuente != null and fuente.has_tile(atlas):
		capa.set_cell(celda, FUENTE_ATLAS, atlas)
	else:
		capa.erase_cell(celda)


static func _bolsillo(objeto: String) -> int:
	return int(SistemaGuardado.obtener_datos_objeto_completos(objeto).get("bolsillo_id", 0))


## ============================================================================
## AYUDANTE del CAP. BABOR
## ============================================================================

static func texto_ayudante() -> String:
	if SistemaGuardado.get_flag(BANDERA_ESCANER_CAMBIADO):
		return TEXTO_SS_CACTUS
	if SistemaGuardado.tiene_objeto(OBJETO_ESCANER, 1, _bolsillo(OBJETO_ESCANER)):
		return TEXTO_CON_ESCANER
	if SistemaGuardado.get_flag(BANDERA_ESCANER_RECOGIDO):
		return TEXTO_SS_CACTUS
	return TEXTO_SIN_ESCANER


func _on_ayudante(npc: Node2D) -> void:
	if not empezar_con(npc):
		return
	await mensaje(texto_ayudante())
	terminar(false, [npc])


## ============================================================================
## Destellos de las cabinas ocultas
## ============================================================================

## Cabina (1..6) según la celda de llegada: columnas 21 y 36 son la del medio y la derecha; la fila 2, las
## de arriba (EventScript_DoHiddenItemSparkle). Se acepta también la fila 1 (la de la puerta) por si el paso
## de salida no llegó a darse.
static func cabina_de(celda: Vector2i) -> int:
	var cabina := 1
	if celda.x == 21:
		cabina += 1
	elif celda.x == 36:
		cabina += 2
	if celda.y <= FILA_MAX_CABINAS_ARRIBA:
		cabina += 3
	return cabina


## Celdas que brillan al entrar en `cabina` con el estado actual de la partida.
static func destellos_de(cabina: int) -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	if not DESTELLOS.has(cabina):
		return res
	var datos: Dictionary = DESTELLOS[cabina]
	for celda: Vector2i in datos["chatarra"]:
		res.append(celda)
	if not SistemaGuardado.get_flag(PREFIJO_LLAVE % int(datos["llave"])):
		res.append(datos["celda_llave"])
	return res


func entrar_en_cabina(celda_jugador: Vector2i) -> void:
	var celdas := destellos_de(cabina_de(celda_jugador))
	ultimos_destellos = celdas
	if celdas.is_empty() or not comenzar(_administrador()):
		return
	if con_destellos:
		await esperar_fotogramas(FOTOGRAMAS_ANTES_DESTELLO)
		var ultimo: EfectoDestello = null
		for celda in celdas:
			ultimo = EfectoDestello.lanzar(obtener_mapa(), celda)
		if ultimo != null:
			await ultimo.terminado
		await esperar_fotogramas(FOTOGRAMAS_TRAS_DESTELLO)
	terminar()

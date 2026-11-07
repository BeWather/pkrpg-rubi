## evento_ciudad_calagua.gd
## Guion del exterior de CIUDAD CALAGUA (pokeruby data/maps/LilycoveCity/scripts.inc).
## Las celdas de Godot son las de Rubí.
##
## SOLDADO del WAILMER (objeto 10, LilycoveCity_EventScript_WailmerTrainerGrunt): lockall
## sin faceplayer. Grita al WAILMER; la primera vez (FLAG_MET_WAILMER_TRAINER) además se
## gira hacia el jugador, le pide que se pierda y recupera su dirección. Las siguientes
## solo repite el primer texto.
##
## Tiles dinámicos de `LilycoveCity_OnLoad` (`setmetatile x, y, metatile, impasable`):
## - WAILMER que bloquean la salida a la RUTA 124 (`EventScript_SetWailmerMetatiles`, 12 celdas
##   impasables): se ven y bloquean mientras NO se haya activado FLAG_EVIL_TEAM_ESCAPED_IN_SUBMARINE.
## - Entrada a la guarida del EQUIPO (`RemoveEvilTeamBaseEntrance`): con la MEDALLA 7
##   (FLAG_BADGE07_GET) se tapa con roca y deja de poderse pasar.
## Ninguno es un NPC ni un tile del suelo: son una capa (`cierra_entrada`) y unos sprites
## (`bloqueo_wailmer`) cuya visibilidad se decide aquí, y su paso se impide con la bandera
## BLOQUEO del `TPTileDataMap` (como el último argumento de `setmetatile`). Al ocultarlos se
## restaura el valor que tenía cada celda al cargar el mapa, no se limpia a ciegas.
extends EventoGuionizado
class_name EventoCiudadCalagua

const MOTIVO_PAUSA: StringName = &"ciudad_calagua"

## FLAG_MET_WAILMER_TRAINER.
const BANDERA_ENTRENADOR_CONOCIDO: String = "calagua_entrenador_wailmer_conocido"
const TEXTO_WAILMER: String = "CALAGUA_SOLDADO_WAILMER"
const TEXTO_FUERA: String = "CALAGUA_SOLDADO_WAILMER_FUERA"
## FLAG_EVIL_TEAM_ESCAPED_IN_SUBMARINE: el equipo se fue y los WAILMER dejan el paso libre.
const BANDERA_EQUIPO_ESCAPO: String = "calagua_equipo_escapo"
## FLAG_BADGE07_GET: índice de la MEDALLA 7 en `jugador.medallas`.
const MEDALLA_CIERRE_GUARIDA: int = 6
const BLOQUEO: int = TPTileDataMap.Flags.BLOQUEO
const TAMANO_CELDA: int = 16

@export var soldado_wailmer: NodePath
## Capa con las rocas que tapan la entrada de la guarida (`CierraEntradaGuarida`).
@export var cierra_entrada: NodePath
## Nodo con los sprites de los WAILMER que bloquean la salida (`BloqueoWailmer`).
@export var bloqueo_wailmer: NodePath
## `TPTileDataMap` del mapa, donde se pone y quita el BLOQUEO.
@export var datos_tiles: NodePath

## BLOQUEO que tenía cada celda gestionada al cargar el mapa: celda -> bool.
var _bloqueo_original: Dictionary = {}

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var npc := get_node_or_null(soldado_wailmer)
	if npc != null and npc.has_signal("hablado"):
		npc.hablado.connect(_on_soldado_wailmer)
	_recordar_bloqueo_original()
	aplicar_estado()
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(func(_por_warp: bool) -> void: aplicar_estado())


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


func _on_soldado_wailmer(npc: Node2D) -> void:
	var administrador_npc: Node = npc.nodo_administrador if npc.nodo_administrador != null else _administrador()
	if _en_curso or not comenzar(administrador_npc):
		if not _en_curso and npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	await mensaje(TEXTO_WAILMER)
	if not SistemaGuardado.get_flag(BANDERA_ENTRENADOR_CONOCIDO):
		npc.mirar_jugador()  # Common_Movement_FacePlayer
		await mensaje(TEXTO_FUERA)
		mirar(npc, npc.direccion_base)  # Common_Movement_FaceOriginalDirection
		SistemaGuardado.set_flag(BANDERA_ENTRENADOR_CONOCIDO, true)
	terminar(false, [npc])


## ============================================================================
## TILES DINÁMICOS (LilycoveCity_OnLoad)
## ============================================================================

## Celdas que ocupan las rocas que tapan la entrada de la guarida.
func celdas_cierre_guarida() -> Array[Vector2i]:
	var capa := get_node_or_null(cierra_entrada) as TileMapLayer
	return capa.get_used_cells() if capa != null else ([] as Array[Vector2i])


## Celdas que ocupan los sprites de los WAILMER (cada uno de 32x32 centrado en su posición).
func celdas_wailmer() -> Array[Vector2i]:
	var celdas: Array[Vector2i] = []
	var contenedor := get_node_or_null(bloqueo_wailmer)
	if contenedor == null:
		return celdas
	for hijo in contenedor.get_children():
		var sprite := hijo as Sprite2D
		if sprite == null or sprite.texture == null:
			continue
		var origen := sprite.position - sprite.texture.get_size() / 2.0
		var primera := Vector2i((origen / TAMANO_CELDA).floor())
		var cuantas := Vector2i((sprite.texture.get_size() / TAMANO_CELDA).ceil())
		for y in cuantas.y:
			for x in cuantas.x:
				celdas.append(primera + Vector2i(x, y))
	return celdas


## ¿Está tapada ahora la entrada de la guarida? (con la MEDALLA 7)
func guarida_cerrada() -> bool:
	return SistemaGuardado.tiene_medalla(MEDALLA_CIERRE_GUARIDA)


## ¿Bloquean ahora los WAILMER la salida? (hasta que el equipo escapa)
func wailmer_bloquean() -> bool:
	return not SistemaGuardado.get_flag(BANDERA_EQUIPO_ESCAPO)


## Pone la visibilidad y el BLOQUEO de la roca de la guarida y de los WAILMER según las banderas.
## Se llama al cargar y cada vez que el mapa pasa a ser el actual.
func aplicar_estado() -> void:
	var cerrada := guarida_cerrada()
	var capa := get_node_or_null(cierra_entrada) as CanvasItem
	if capa != null:
		capa.visible = cerrada
	_fijar_bloqueo(celdas_cierre_guarida(), cerrada)
	var bloquean := wailmer_bloquean()
	var wailmer := get_node_or_null(bloqueo_wailmer) as CanvasItem
	if wailmer != null:
		wailmer.visible = bloquean
	_fijar_bloqueo(celdas_wailmer(), bloquean)


func _recordar_bloqueo_original() -> void:
	var datos := get_node_or_null(datos_tiles) as TPTileDataMap
	if datos == null:
		return
	# El diccionario de la escena se comparte entre instancias: copia propia para no tocar la original.
	datos.tile_data = datos.tile_data.duplicate(true)
	for celda in celdas_cierre_guarida() + celdas_wailmer():
		_bloqueo_original[celda] = datos.has_flag(Vector2(celda), BLOQUEO)


## `setmetatile(..., impasable)`: con `bloquear` la celda no se puede pisar; sin él recupera
## el BLOQUEO que tenía al cargar.
func _fijar_bloqueo(celdas: Array[Vector2i], bloquear: bool) -> void:
	var datos := get_node_or_null(datos_tiles) as TPTileDataMap
	if datos == null:
		return
	for celda in celdas:
		if bloquear or bool(_bloqueo_original.get(celda, false)):
			datos.set_flag(Vector2(celda), BLOQUEO)
		else:
			datos.clear_flag(Vector2(celda), BLOQUEO)

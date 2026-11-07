@tool
class_name TileAlterno
extends Node2D

## Cambia una celda de una capa entre su tile original y un tile alterno del
## mismo atlas (setmetatile de Rubí): cajas de la mudanza, pantalla encendida de
## la tele o del PC. Opcionalmente pone/quita BLOQUEO en la capa de datos
## (TPTileDataMap) mientras el tile alterno está activo.
##
## Sigue el patrón de EventoPCCasa (coord_tile con ajuste a la cuadrícula en el
## editor) y de PuenteMaderaMapa (set_cell entre dos tiles del atlas).
##
## Estado: `activo` (o activar()/desactivar()). En ejecución, el tile original se
## lee de la capa mientras la celda está apagada, así que una celda vacía se
## vuelve a vaciar con erase_cell al desactivar. En el editor solo dibuja una vista
## previa semitransparente del tile alterno y nunca toca la capa.

const TAMANO_TILE: int = 16
const FOTOGRAMAS_POR_SEGUNDO: float = 60.0
const ALFA_VISTA_PREVIA: float = 0.6

## TileMapLayer donde se cambia la celda.
@export var capa: NodePath:
	set(valor):
		capa = valor
		_capa = null
		_refrescar_editor()
@export var coord_tile: Vector2i = Vector2i.ZERO:
	set(valor):
		coord_tile = valor
		if is_inside_tree():
			position = Vector2(valor.x * TAMANO_TILE + 8, valor.y * TAMANO_TILE + 8)
		_refrescar_editor()
@export var fuente_atlas: int = 0:
	set(valor):
		fuente_atlas = valor
		_refrescar_editor()
## Coordenadas en el atlas del tile que se muestra al activarse.
@export var atlas_alterno: Vector2i = Vector2i.ZERO:
	set(valor):
		atlas_alterno = valor
		_refrescar_editor()
## Si es true, al activarse la celda recibe TPTileDataMap.Flags.BLOQUEO (salvo que
## ya lo tuviera) y al desactivarse se lo quita solo si lo puso este nodo.
@export var bloquea: bool = false
@export var datos_tiles: NodePath:
	set(valor):
		datos_tiles = valor
		_refrescar_editor()
## Estado con el que se abre la escena (si nadie lo ha fijado antes por código).
@export var activo_al_inicio: bool = false

## true mientras se muestra el tile alterno.
var activo: bool:
	get:
		return _encendido
	set(valor):
		if valor:
			activar()
		else:
			desactivar()

var _encendido: bool = false
## Algo (código o parpadeo) ya fijó el estado: _ready no aplica activo_al_inicio.
var _estado_fijado: bool = false
## Cada activar()/desactivar()/parpadear() invalida los parpadeos en curso.
var _generacion: int = 0
var _capa: TileMapLayer = null
var _original_fuente: int = -1
var _original_atlas: Vector2i = Vector2i.ZERO
var _original_alternativo: int = 0
var _bloqueo_puesto: bool = false
var _entrada_datos_creada: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		set_notify_transform(true)
		# La vista previa va por encima de las capas sin guardar un z_index en la escena.
		RenderingServer.canvas_item_set_z_index(get_canvas_item(), 1000)
		queue_redraw()
		return
	position = Vector2(coord_tile.x * TAMANO_TILE + 8, coord_tile.y * TAMANO_TILE + 8)
	var la_capa := _capa_resuelta()
	if la_capa != null:
		_capturar_original(la_capa)
	if activo_al_inicio and not _estado_fijado:
		_aplicar(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		coord_tile = Vector2i(round((position.x - 8) / TAMANO_TILE), round((position.y - 8) / TAMANO_TILE))
		position = Vector2(coord_tile.x * TAMANO_TILE + 8, coord_tile.y * TAMANO_TILE + 8)


func _exit_tree() -> void:
	_generacion += 1  # un parpadeo a medias no sigue tocando la capa


## Muestra el tile alterno (y pone BLOQUEO si `bloquea`).
func activar() -> void:
	_estado_fijado = true
	_generacion += 1
	_aplicar(true)


## Devuelve el tile original (y quita BLOQUEO si lo puso este nodo).
func desactivar() -> void:
	_estado_fijado = true
	_generacion += 1
	_aplicar(false)


## Alterna `veces` cambios empezando por ENCENDIDO, esperando `frames_por_cambio`
## fotogramas (a 60 fps) tras cada uno: con veces = 5 es on/off/on/off/on y queda
## encendido. Un activar()/desactivar() o salir del árbol a medias lo interrumpe.
func parpadear(veces: int, frames_por_cambio: int) -> void:
	if Engine.is_editor_hint():
		return
	_estado_fijado = true
	_generacion += 1
	var mi_generacion := _generacion
	if not is_inside_tree():
		_aplicar(veces % 2 != 0)
		return
	var encender := true
	for _i in maxi(veces, 0):
		_aplicar(encender)
		if frames_por_cambio > 0:
			await get_tree().create_timer(frames_por_cambio / FOTOGRAMAS_POR_SEGUNDO).timeout
		if mi_generacion != _generacion or not is_inside_tree():
			return
		encender = not encender


## Vuelve a dibujar el estado actual: la capa o los datos pueden haberse
## restablecido por fuera (p. ej. MapaDecoracion.recomponer al decorar el cuarto).
func reaplicar() -> void:
	if _encendido:
		_aplicar(true)


func _capa_resuelta() -> TileMapLayer:
	if not is_instance_valid(_capa) and not capa.is_empty():
		_capa = get_node_or_null(capa) as TileMapLayer
	return _capa


func _datos_resueltos() -> TPTileDataMap:
	if datos_tiles.is_empty():
		return null
	return get_node_or_null(datos_tiles) as TPTileDataMap


## Guarda el tile que hay ahora en la celda (solo vale mientras está apagado).
func _capturar_original(la_capa: TileMapLayer) -> void:
	_original_fuente = la_capa.get_cell_source_id(coord_tile)
	_original_atlas = la_capa.get_cell_atlas_coords(coord_tile)
	_original_alternativo = la_capa.get_cell_alternative_tile(coord_tile)


func _aplicar(encender: bool) -> void:
	if Engine.is_editor_hint():
		return
	var la_capa := _capa_resuelta()
	if la_capa != null:
		if not _encendido:
			_capturar_original(la_capa)  # apagado, la capa muestra el original
		if encender:
			la_capa.set_cell(coord_tile, fuente_atlas, atlas_alterno)
		elif _original_fuente == -1:
			la_capa.erase_cell(coord_tile)
		else:
			la_capa.set_cell(coord_tile, _original_fuente, _original_atlas, _original_alternativo)
	_encendido = encender
	_aplicar_bloqueo(encender)


func _aplicar_bloqueo(encender: bool) -> void:
	if not bloquea:
		return
	var datos := _datos_resueltos()
	if datos == null:
		return
	var celda := Vector2(coord_tile)
	var clave := "%d,%d" % [coord_tile.x, coord_tile.y]
	if encender:
		if datos.has_flag(celda, TPTileDataMap.Flags.BLOQUEO):
			return
		_hacer_escribible(datos)
		_entrada_datos_creada = not datos.tile_data.has(clave)
		datos.set_flag(celda, TPTileDataMap.Flags.BLOQUEO)
		_bloqueo_puesto = true
	elif _bloqueo_puesto:
		_hacer_escribible(datos)
		datos.clear_flag(celda, TPTileDataMap.Flags.BLOQUEO)
		if _entrada_datos_creada and datos.get_flags(celda) == 0:
			datos.tile_data.erase(clave)  # la celda no tenía entrada: vuelve a no tenerla
		_bloqueo_puesto = false
		_entrada_datos_creada = false


## tile_data viene de la escena y puede ser de solo lectura: se copia para poder
## cambiarla (set_cell_data la vaciaría).
func _hacer_escribible(datos: TPTileDataMap) -> void:
	if datos.tile_data.is_read_only():
		datos.tile_data = datos.tile_data.duplicate(true)


## ============================================================================
## EDITOR: vista previa y avisos
## ============================================================================

func _refrescar_editor() -> void:
	if not Engine.is_editor_hint():
		return
	queue_redraw()
	if is_inside_tree():
		update_configuration_warnings()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_rect(Rect2(-8, -8, TAMANO_TILE, TAMANO_TILE), Color(0.2, 0.9, 1.0, 0.9), false)
	var fuente := _fuente_atlas()
	if fuente == null or fuente.texture == null or not fuente.has_tile(atlas_alterno):
		return
	var region: Rect2 = Rect2(fuente.get_tile_texture_region(atlas_alterno))
	draw_texture_rect_region(fuente.texture, Rect2(-region.size / 2.0, region.size), region,
		Color(1, 1, 1, ALFA_VISTA_PREVIA))


func _fuente_atlas() -> TileSetAtlasSource:
	var la_capa := _capa_resuelta()
	if la_capa == null or la_capa.tile_set == null or not la_capa.tile_set.has_source(fuente_atlas):
		return null
	return la_capa.tile_set.get_source(fuente_atlas) as TileSetAtlasSource


func _get_configuration_warnings() -> PackedStringArray:
	var avisos := PackedStringArray()
	if capa.is_empty() or _capa_resuelta() == null:
		avisos.append("Asigna en `capa` el TileMapLayer donde se cambia la celda.")
	else:
		var fuente := _fuente_atlas()
		if fuente == null:
			avisos.append("La fuente de atlas %d no existe en el TileSet de la capa." % fuente_atlas)
		elif not fuente.has_tile(atlas_alterno):
			avisos.append("El atlas %d no tiene el tile %s." % [fuente_atlas, atlas_alterno])
	if bloquea and _datos_resueltos() == null:
		avisos.append("`bloquea` necesita en `datos_tiles` un TPTileDataMap.")
	return avisos

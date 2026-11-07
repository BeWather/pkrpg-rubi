@tool
extends EditorContextMenuPlugin
## Entrada del menú básico del lienzo 2D para colocar el marcador del mapa.

signal colocar_spawn_debug(raiz: Node2D, celda: Vector2i)

const RUTA_MAPA: String = "res://escenas/mapas/MapaConfiguracion.gd"
const TAM_TILE: int = 16

var _raiz_clic: Node2D = null
var _celda_clic: Vector2i = Vector2i.ZERO
var _lienzo: Control = null
var _pos_ultimo_clic: Vector2 = Vector2.ZERO
var _hay_clic: bool = false


func establecer_lienzo(lienzo: Control) -> void:
	_lienzo = lienzo


func registrar_clic(pos_lienzo: Vector2) -> void:
	_pos_ultimo_clic = pos_lienzo
	_hay_clic = true


func _popup_menu(_paths: PackedStringArray) -> void:
	_raiz_clic = EditorInterface.get_edited_scene_root() as Node2D
	if not es_mapa(_raiz_clic):
		_raiz_clic = null
		return
	# Guardar la posición ANTES de abrir el menú: al elegir la acción el ratón
	# ya puede estar sobre otra zona del lienzo.
	var pos_lienzo: Vector2
	if is_instance_valid(_lienzo):
		pos_lienzo = _lienzo.get_local_mouse_position()
	elif _hay_clic:
		pos_lienzo = _pos_ultimo_clic
	else:
		_raiz_clic = null
		return
	_hay_clic = false
	_celda_clic = celda_en_lienzo(_raiz_clic, pos_lienzo)
	add_context_menu_item("Spawn Debug", _al_elegir)


static func es_mapa(raiz: Node2D) -> bool:
	if not is_instance_valid(raiz) or not raiz.is_inside_tree():
		return false
	var script := raiz.get_script() as Script
	while script != null:
		if script.resource_path == RUTA_MAPA:
			return true
		script = script.get_base_script()
	return false


static func celda_en_lienzo(raiz: Node2D, pos_viewport: Vector2) -> Vector2i:
	var xf := raiz.get_viewport().global_canvas_transform * raiz.get_global_transform_with_canvas()
	var local: Vector2 = xf.affine_inverse() * pos_viewport
	return Vector2i((local / TAM_TILE).floor())


func _al_elegir(_nodos: Array) -> void:
	if is_instance_valid(_raiz_clic) and EditorInterface.get_edited_scene_root() == _raiz_clic:
		colocar_spawn_debug.emit(_raiz_clic, _celda_clic)

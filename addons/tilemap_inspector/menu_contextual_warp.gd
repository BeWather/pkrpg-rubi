@tool
extends EditorContextMenuPlugin
## Se registra por separado para el árbol de escena y el lienzo 2D.
## Solo ofrece la acción para warps de la escena local actualmente editada.

signal solicitar_editor_warps(warp: Node)

const Datos = preload("res://addons/tilemap_inspector/datos_conexiones_warp.gd")


func _popup_menu(paths: PackedStringArray) -> void:
	var raiz := EditorInterface.get_edited_scene_root()
	if _buscar_warp(paths, raiz) != null:
		add_context_menu_item("Editar conexión…", _al_elegir)


static func _buscar_warp(paths: PackedStringArray, raiz: Node) -> Node:
	if raiz == null or not raiz.is_inside_tree():
		return null
	for ruta in paths:
		# El lienzo entrega rutas absolutas; el árbol, relativas a la raíz
		# editada. Comprobar pertenencia evita aceptar nodos de la vista Remota.
		for base in [raiz.get_tree().root, raiz]:
			var warp := _warp_local(base.get_node_or_null(NodePath(ruta)), raiz)
			if warp != null:
				return warp
	return null


static func _warp_local(nodo: Node, raiz: Node) -> Node:
	if not is_instance_valid(nodo) or not is_instance_valid(raiz):
		return null
	var actual := nodo
	while actual != null and (actual == raiz or raiz.is_ancestor_of(actual)):
		if Datos._hereda_script(actual, Datos.SCRIPT_WARP):
			return actual
		actual = actual.get_parent()
	return null


func _al_elegir(nodos: Array) -> void:
	var raiz := EditorInterface.get_edited_scene_root()
	for nodo in nodos:
		if not (nodo is Node):
			continue
		var warp := _warp_local(nodo, raiz)
		if warp != null:
			solicitar_editor_warps.emit(warp)
			return

## isla_espejismo_ruta.gd
## Route130_OnTransition: con la ISLA ESPEJISMO a la vista (IslaEspejismo.esta_presente) la RUTA 130 usa el layout
## con la isla (setmaplayoutindex 46); si no, el de mar abierto (264) y oculta el árbol de bayas 82 (FLAG_TEMP_11).
##
## Como las mareas de la CUEVA CARDUMEN (MareaCueva): la ruta lleva dos grupos de capas, `RutaNormal` y este nodo
## (la isla), cada uno con sus TileMapLayer y su TPTileDataMap. Se muestra el grupo activo y se oculta el otro;
## MapaConfiguracion.get_capa_por_id salta los grupos ocultos, así que la colisión sigue al grupo visible.
## Los mapas se reutilizan, así que se vuelve a aplicar en cada `mapa_activado`.
extends Node2D
class_name IslaEspejismoRuta

## Grupo de capas (con su TPTileDataMap) de la ruta sin isla.
@export var ruta_normal: NodePath = ^"../RutaNormal"
@export var arbol_baya: NodePath = ^"../NPCs/BayaIslaEspejismo"


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(IslaEspejismo.GRUPO)
	aplicar()
	var mapa := _buscar_mapa()
	if mapa != null and not mapa.mapa_activado.is_connected(_on_mapa_activado):
		mapa.mapa_activado.connect(_on_mapa_activado)


func _on_mapa_activado(_por_warp: bool) -> void:
	aplicar()


func aplicar() -> void:
	_fijar(IslaEspejismo.esta_presente())


func _fijar(presente: bool) -> void:
	var normal := get_node_or_null(ruta_normal) as CanvasItem
	if normal == null:
		push_warning("IslaEspejismoRuta: falta el grupo de capas %s" % ruta_normal)
		return
	visible = presente
	normal.visible = not presente
	var arbol := get_node_or_null(arbol_baya) as CanvasItem
	if arbol != null:
		arbol.visible = presente


func _buscar_mapa() -> Node:
	var nodo: Node = get_parent()
	while nodo != null and not nodo.has_signal("mapa_activado"):
		nodo = nodo.get_parent()
	return nodo

## isla_pilar_celeste.gd
## Isla del PILAR CELESTE en la RUTA 131 (pokeruby Route131_MapScript1_152444: con FLAG_SYS_GAME_CLEAR,
## `setmaplayoutindex 320`).
##
## Como las mareas de la CUEVA CARDUMEN (MareaCueva): la ruta lleva dos grupos de capas, `RutaNormal`
## (LAYOUT_ROUTE131) y este nodo (la ruta completa con la isla, layout 320), cada uno con sus TileMapLayer y su
## TPTileDataMap (las banderas, herramientas/generar_colisiones_rutas_pacifidlog.py). Se muestra el grupo activo y
## se oculta el otro; MapaConfiguracion.get_capa_por_id salta los grupos ocultos, así que la colisión sigue al
## grupo visible.
##
## Al cargar el mapa y cada vez que pasa a ser el actual (OnTransition): con `SYS_GAME_CLEAR` se ve la isla y el
## warp de la puerta (`warp`) funciona; sin ella, se ve RutaNormal y el warp sale de su grupo.
extends Node2D
class_name IslaPilarCeleste

const BANDERA_JUEGO_COMPLETADO: String = "SYS_GAME_CLEAR"

## Grupo de capas (con su TPTileDataMap) de la ruta sin la isla.
@export var ruta_normal: NodePath = ^"../RutaNormal"
@export var warp: NodePath = ^"../WarpPilarCeleste"


func _ready() -> void:
	var mapa := get_parent() as MapaConfiguracion
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)
	aplicar()
	# Los Warp se apuntan a su grupo en su propio _ready (después de este nodo).
	aplicar.call_deferred()


func _on_mapa_activado(_por_warp: bool) -> void:
	aplicar()


static func isla_visible() -> bool:
	return SistemaGuardado.get_flag(BANDERA_JUEGO_COMPLETADO)


func aplicar() -> void:
	var activa := isla_visible()
	var normal := get_node_or_null(ruta_normal) as CanvasItem
	if normal == null:
		push_warning("IslaPilarCeleste: falta el grupo de capas %s" % ruta_normal)
	else:
		visible = activa
		normal.visible = not activa
	var puerta := get_node_or_null(warp) as Warp
	if puerta == null or not puerta.is_inside_tree():
		return
	var grupo: String = Warp.GRUPOS[puerta.tipo_warp]
	if activa and not puerta.is_in_group(grupo):
		puerta.add_to_group(grupo)
	elif not activa and puerta.is_in_group(grupo):
		puerta.remove_from_group(grupo)

## marea_cueva.gd
## Mareas de la CUEVA CARDUMEN (pokeruby UpdateShoalTideFlag / FLAG_SYS_SHOAL_TIDE, time_events.c).
##
## La marea sale solo de la hora local (RelojJuego, el RTC de Rubí) con una tabla de 24 horas, y solo se
## recalcula al entrar a la cueva desde fuera (GetLastUsedWarpMapType es un mapa exterior): mientras el
## jugador pasa de sala en sala la marea no cambia, aunque cambie la hora. El resultado se guarda en la
## bandera `cueva_cardumen_marea_alta`, que es la que leen el resto de salas y los objetos.
##
## En Rubí la sala de entrada y la interior cambian de layout con `setmaplayoutindex`; aquí cada una lleva dos
## grupos de capas, `MareaBaja` y `MareaAlta` (cada uno con su TileMapLayer y su TPTileDataMap). Este nodo
## muestra el grupo de la marea activa y oculta el otro; MapaConfiguracion.get_capa_por_id salta los grupos
## ocultos, así que la colisión sigue al grupo visible.
class_name MareaCueva
extends Node

## FLAG_SYS_SHOAL_TIDE: true = marea alta.
const BANDERA_MAREA_ALTA: String = "cueva_cardumen_marea_alta"

## `tide[]` de UpdateShoalTideFlag: true = marea alta en esa hora (0-23).
const TABLA_MAREA_ALTA: Array[bool] = [
	true, true, true,
	false, false, false, false, false, false,
	true, true, true, true, true, true,
	false, false, false, false, false, false,
	true, true, true,
]

## Las salas de la cueva: si el mapa del que se viene empieza por este prefijo, no se sale al exterior.
@export var prefijo_salas: String = "cueva_cardumen"
@export var grupo_baja: NodePath = ^"../MareaBaja"
@export var grupo_alta: NodePath = ^"../MareaAlta"

## Doble de AdministradorMapa (tests); si no, se busca el de la raíz.
var administrador: Node = null


## ¿Hay marea alta a esa hora (0-23)? Sin hora, la hora local del juego.
static func es_marea_alta(hora: int = -1) -> bool:
	var h: int = RelojJuego.hora_local() if hora < 0 else hora
	return TABLA_MAREA_ALTA[posmod(h, 24)]


## UpdateShoalTideFlag: fija la bandera según la hora local y la devuelve.
static func actualizar_bandera() -> bool:
	var alta: bool = es_marea_alta()
	SistemaGuardado.set_flag(BANDERA_MAREA_ALTA, alta)
	return alta


## Marea guardada; si nunca se calculó (partida nueva o cargada dentro de la cueva), la calcula.
static func marea_actual() -> bool:
	if not SistemaGuardado.has_flag(BANDERA_MAREA_ALTA):
		return actualizar_bandera()
	return SistemaGuardado.get_flag(BANDERA_MAREA_ALTA)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var mapa := _mapa()
	if mapa != null and mapa.has_signal("mapa_activado"):
		mapa.mapa_activado.connect(_on_mapa_activado)
	aplicar(marea_actual())


## ¿Se entra desde fuera de la cueva? `mapa_anterior_key` vacío = partida cargada, no hay warp.
func entra_desde_fuera() -> bool:
	var adm := _administrador()
	var clave: Variant = adm.get("mapa_anterior_key") if adm != null else null
	var anterior: String = str(clave) if clave != null else ""
	return not anterior.is_empty() and not anterior.begins_with(prefijo_salas)


func _on_mapa_activado(por_warp: bool) -> void:
	if por_warp and entra_desde_fuera():
		actualizar_bandera()
	aplicar(marea_actual())


## Muestra el grupo de la marea y oculta el otro.
func aplicar(alta: bool) -> void:
	var activo := get_node_or_null(grupo_alta if alta else grupo_baja) as Node2D
	var inactivo := get_node_or_null(grupo_baja if alta else grupo_alta) as Node2D
	if activo == null or inactivo == null:
		push_warning("MareaCueva: faltan los grupos de capas %s / %s" % [grupo_baja, grupo_alta])
		return
	activo.visible = true
	inactivo.visible = false


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


func _mapa() -> Node:
	var nodo: Node = get_parent()
	while nodo != null and not nodo is MapaConfiguracion:
		nodo = nodo.get_parent()
	return nodo

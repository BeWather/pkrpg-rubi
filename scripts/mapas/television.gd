## television.gd
## Tele de un interior (metatile MB_TELEVISION de pokeruby): va en `Carteles` en la
## celda de la tele y solo responde mirando hacia arriba
## (MetatileBehavior_IsPlayerFacingTVScreen). Al pulsar A lanza Event_TV y al
## cargarse el mapa enciende o apaga `pantalla` (UpdateTVScreensOnMap); la lógica
## está en ProgramacionTV.
@tool
extends Signpost
class_name Television

## TileAlterno con la pantalla encendida (METATILE_Building_TV_On). Opcional: sin
## él la tele funciona igual pero no cambia de aspecto.
@export var pantalla: NodePath

var _mapa: MapaConfiguracion = null


func _init() -> void:
	direccion = Singleton.enum_dir_cartel.ABAJO


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	_mapa = _buscar_mapa()
	if _mapa != null:
		_mapa.mapa_activado.connect(_on_mapa_activado)


func _buscar_mapa() -> MapaConfiguracion:
	var nodo := get_parent()
	while nodo != null and not nodo is MapaConfiguracion:
		nodo = nodo.get_parent()
	return nodo as MapaConfiguracion


## Clave del mapa (nombre base de la escena, como mapa_actual_key).
func clave_mapa() -> String:
	if _mapa == null:
		_mapa = _buscar_mapa()
	return _mapa.scene_file_path.get_file().get_basename() if _mapa != null else ""


func _on_mapa_activado(_por_warp: bool) -> void:
	var encender: Variant = ProgramacionTV.al_cargar_mapa(clave_mapa())
	if encender != null:
		_encender_pantalla(bool(encender))


func accionar_cartel() -> void:
	var resultado := ProgramacionTV.ver(clave_mapa())
	var al_terminar := Callable()
	if resultado["apagar"]:
		al_terminar = _encender_pantalla.bind(false)  # special TurnOffTVScreen
	Singleton.mostrar_texto(resultado["texto"], al_terminar)


func _encender_pantalla(encender: bool) -> void:
	var tile := get_node_or_null(pantalla) as TileAlterno if not pantalla.is_empty() else null
	if tile != null:
		tile.activo = encender

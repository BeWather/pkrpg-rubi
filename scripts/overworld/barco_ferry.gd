## barco_ferry.gd
## S.S. MAREA atracado en el PUERTO de CIUDAD PORTUAL y en el de CIUDAD CALAGUA (pokeruby OBJ_EVENT_GFX_SS_TIDAL, objeto
## (8,9) de SlateportCity_Harbor y LilycoveCity_Harbor). Se ve solo con la bandera `bandera_visible` (SYS_GAME_CLEAR:
## new_game.inc oculta los dos barcos con FLAG_HIDE_SS_TIDAL_*_HARBOR y el SALÓN de la FAMA los muestra), reevaluada
## cada vez que el mapa pasa a ser el actual; ahí también vuelve a su sitio si había zarpado.
##
## zarpar() es Common_EventScript_FerryDepart: delay 60 y Movement_FerryDepart (tres pasos lentos y cuatro normales
## hacia la derecha). Lo usa la azafata (npc_azafata_ferry.gd) al embarcar.
extends Sprite2D
class_name BarcoFerry

const FOTOGRAMAS_ANTES: int = 60
const PASOS_LENTOS: int = 3
const PASOS_NORMALES: int = 4
## walk_slow_* y walk_* (fotogramas por casilla a 60 por segundo).
const FOTOGRAMAS_PASO_LENTO: int = 32
const FOTOGRAMAS_PASO_NORMAL: int = 16
const TAMANO_CASILLA: int = 16

@export var bandera_visible: String = "SYS_GAME_CLEAR"
## Dirección en la que zarpa (Movement_FerryDepart: walk_*_right).
@export var direccion_salida: Vector2 = Vector2.RIGHT

var _posicion_atracado: Vector2


func _ready() -> void:
	_posicion_atracado = position
	var mapa := _mapa()
	if mapa != null:
		mapa.mapa_activado.connect(func(_por_warp: bool) -> void: aplicar())
	aplicar()


func _mapa() -> MapaConfiguracion:
	var nodo: Node = get_parent()
	while nodo != null and not nodo is MapaConfiguracion:
		nodo = nodo.get_parent()
	return nodo as MapaConfiguracion


## OnTransition: atracado en su sitio y visible según la bandera.
func aplicar() -> void:
	position = _posicion_atracado
	visible = bandera_visible.is_empty() or SistemaGuardado.get_flag(bandera_visible)


## Common_EventScript_FerryDepart.
func zarpar() -> void:
	await get_tree().create_timer(FOTOGRAMAS_ANTES / 60.0).timeout
	var tween := create_tween()
	tween.tween_property(self, "position", position + direccion_salida * TAMANO_CASILLA * PASOS_LENTOS,
			PASOS_LENTOS * FOTOGRAMAS_PASO_LENTO / 60.0)
	tween.tween_property(self, "position", position + direccion_salida * TAMANO_CASILLA * (PASOS_LENTOS + PASOS_NORMALES),
			PASOS_NORMALES * FOTOGRAMAS_PASO_NORMAL / 60.0)
	await tween.finished

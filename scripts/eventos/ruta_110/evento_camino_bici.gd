## evento_camino_bici.gd
## Guiones de las dos casetas de entrada al CAMINO de BICIS de la COSTA (pokeruby data/maps/
## Route110_SeasideCyclingRoadSouthEntrance y _NorthEntrance). Las dos tienen la misma sala de
## 15×6: la entrada del lado de tierra (celdas (1,5)/(2,5)) y la del puente (12,5)/(13,5), con
## el GUARDA (objeto 1) detrás del mostrador en (7,2).
##
## Dos coord_events con VAR_TEMP_1 (aquí la bandera temporal `TEMPORAL_CRUZADO`, que se limpia en
## cada warp igual que las VAR_TEMP de Rubí):
##   (7,4), VAR_TEMP_1 == 0: delante del GUARDA. A pie, el GUARDA te echa («no puedes entrar a
##       pie») y un paso a la izquierda te saca del mostrador; en bici activa FLAG_SYS_CYCLING_ROAD
##       y VAR_TEMP_1 = 1. Solo la caseta NORTE: con BICI CARRERA (GetPlayerAvatarBike == 2) deja
##       VAR_CYCLING_CHALLENGE_STATE en 1 (reto preparado).
##   (5,4), VAR_TEMP_1 == 1: al volver hacia el lado de tierra apaga FLAG_SYS_CYCLING_ROAD,
##       VAR_TEMP_1 = 0 y (solo NORTE) VAR_CYCLING_CHALLENGE_STATE = 0.
## OnTransition de la NORTE: VAR_CYCLING_CHALLENGE_STATE 3 o 2 → 1 (se vuelve a la caseta del
## principio del camino: el reto vuelve a estar preparado).
extends EventoGuionizado
class_name EventoCaminoBici

const MOTIVO_PAUSA: StringName = &"camino_bici"
## VAR_TEMP_1 == 1.
const TEMPORAL_CRUZADO: String = "camino_bici_cruzado"
const TEXTO_SIN_BICI: String = "RUTA_110_BICI_SIN_BICI"
const ID_CRUCE: StringName = &"cruce"
const ID_SALIDA: StringName = &"salida"

## true en la caseta NORTE (la que lleva el estado del reto del CAMINO de BICIS).
@export var entrada_norte: bool = false

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for hijo in get_children():
		if hijo is DisparadorEventoPorTiles:
			hijo.evento_activado.connect(_on_disparador)
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


## Route110_SeasideCyclingRoadNorthEntrance_MapScript1 (OnTransition).
func _on_mapa_activado(_por_warp: bool) -> void:
	if not entrada_norte:
		return
	var estado := CaminoBici.estado_reto()
	if estado == CaminoBici.RETO_TERMINADO or estado == CaminoBici.RETO_EN_CURSO:
		CaminoBici.fijar_estado_reto(CaminoBici.RETO_PREPARADO)


func _on_disparador(id_evento: StringName) -> void:
	match id_evento:
		ID_CRUCE:
			await cruzar_mostrador()
		ID_SALIDA:
			salir_del_camino()


## EventScript_16348B (SUR) / _1634F7 (NORTE). Solo actúa con VAR_TEMP_1 == 0.
func cruzar_mostrador() -> void:
	if _en_curso or SistemaGuardado.get_flag_temporal(TEMPORAL_CRUZADO):
		return
	var adm := _administrador()
	if not comenzar(adm):
		return
	var bici := CaminoBici.tipo_bici_jugador(adm.get("jugador"))
	if entrada_norte and bici == CaminoBici.BICI_CARRERA:
		CaminoBici.fijar_estado_reto(CaminoBici.RETO_PREPARADO)  # You're on the Mach Bike!
	if bici == CaminoBici.SIN_BICI:
		# You don't have a bike!: closemessage + walk_left del jugador.
		await mensaje(TEXTO_SIN_BICI)
		await recorrer_jugador([Vector2.LEFT])
		terminar()
		return
	CaminoBici.fijar_activo(true)  # setflag FLAG_SYS_CYCLING_ROAD
	SistemaGuardado.set_flag_temporal(TEMPORAL_CRUZADO, true)  # VAR_TEMP_1 = 1
	terminar()


## EventScript_1634BD (SUR) / _16353A (NORTE). Solo actúa con VAR_TEMP_1 == 1; sin diálogo ni
## movimiento, así que no hace falta bloquear al jugador.
func salir_del_camino() -> void:
	if not SistemaGuardado.get_flag_temporal(TEMPORAL_CRUZADO):
		return
	if entrada_norte:
		CaminoBici.fijar_estado_reto(CaminoBici.RETO_LIBRE)
	CaminoBici.fijar_activo(false)  # clearflag FLAG_SYS_CYCLING_ROAD
	SistemaGuardado.set_flag_temporal(TEMPORAL_CRUZADO, false)  # VAR_TEMP_1 = 0

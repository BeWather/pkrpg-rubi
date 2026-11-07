## evento_desierto_ruta_111.gd
## Bloqueo de la entrada al DESIERTO de la RUTA 111 sin las GAFAS AISLANTES (pokeruby
## data/maps/Route111: coord_events con VAR_TEMP_3 == 0 → Route111_EventScript_150116 / _150122 →
## _15013A). Las celdas de la escena son las de Rubí (1:1).
##
## Con la tormenta de arena ya activa (zonas de TormentaArena), la primera celda del desierto
## dispara el guion: si el jugador no lleva ITEM_GO_GOGGLES, un mensaje le avisa («no se puede
## avanzar») y un paso (walk_down en el lado sur, VAR_SPECIAL_4 = 1; walk_left en el lado noreste,
## VAR_SPECIAL_4 = 2) le devuelve a la celda anterior. Con las gafas no hace nada: Rubí marca
## VAR_TEMP_3 = 1 para no repetir la comprobación hasta salir del desierto, pero comprobar la
## bolsa en cada cruce da el mismo resultado.
extends EventoGuionizado
class_name EventoDesiertoRuta111

const MOTIVO_PAUSA: StringName = &"ruta_111_desierto"
const TEXTO_BLOQUEO: String = "RUTA111_DESIERTO_BLOQUEO"
## ITEM_GO_GOGGLES en la tabla Objetos.
const OBJETO_GAFAS: String = "GAFASAISL"

## Route111_EventScript_150116 (VAR_SPECIAL_4 = 1): empuja hacia abajo.
const ID_BLOQUEO_SUR: StringName = &"bloqueo_sur"
## Route111_EventScript_150122 (VAR_SPECIAL_4 = 2): empuja hacia la izquierda.
const ID_BLOQUEO_NORESTE: StringName = &"bloqueo_noreste"

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


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


func _on_disparador(id_evento: StringName) -> void:
	match id_evento:
		ID_BLOQUEO_SUR:
			await comprobar_gafas(Vector2.DOWN)
		ID_BLOQUEO_NORESTE:
			await comprobar_gafas(Vector2.LEFT)


## Route111_EventScript_15013A: sin gafas, mensaje y un paso hacia `retroceso`.
func comprobar_gafas(retroceso: Vector2) -> void:
	if _en_curso or tiene_gafas():
		return
	if not comenzar(_administrador()):
		return
	await mensaje(TEXTO_BLOQUEO)
	await recorrer_jugador([retroceso])
	terminar()


static func tiene_gafas() -> bool:
	var bolsillo := int(SistemaGuardado.obtener_datos_objeto_completos(OBJETO_GAFAS).get("bolsillo_id", 0))
	return SistemaGuardado.get_cantidad_objeto(OBJETO_GAFAS, bolsillo) > 0

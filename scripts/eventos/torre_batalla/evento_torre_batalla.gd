## evento_torre_batalla.gd
## Base de los guiones de los interiores de la TORRE BATALLA: warps por guion (`warp MAP_..., 255, x, y`) y la vuelta al
## inicio del juego (BattleTower_SoftReset).
class_name EventoTorreBatalla
extends EventoGuionizado

const MAPA_VESTIBULO: String = "torre_batalla_vestibulo"
const MAPA_ASCENSOR: String = "torre_batalla_ascensor"
const MAPA_PASILLO: String = "torre_batalla_pasillo"
const MAPA_SALA: String = "torre_batalla_sala"
const P: String = "TORRE_BATALLA_"

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null
## Sustituye a la vuelta al inicio (tests).
var reinicio: Callable = Callable()
## Generador de los sorteos (tests con semilla).
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	motivo_pausa = &"torre_batalla"


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	rng.randomize()
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)
	preparar()


## Coloca NPC y puertas (OnTransition).
func preparar() -> void:
	pass


## OnFrame del mapa.
func guion_entrada() -> void:
	pass


func _on_mapa_activado(_por_warp: bool) -> void:
	if _en_curso:
		return
	preparar()
	await esperar_fin_warp(_administrador())
	await guion_entrada()


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


func _npc(ruta: NodePath) -> Node2D:
	return get_node_or_null(ruta) as Node2D


func _conectar(ruta: NodePath, senal: StringName, metodo: Callable) -> void:
	var nodo := get_node_or_null(ruta)
	if nodo != null and nodo.has_signal(senal):
		nodo.connect(senal, metodo)


## warp MAP_..., 255, x, y + waitstate.
func _ir_a(mapa: String, celda: Vector2i, mirada: Vector2, npcs: Array = []) -> void:
	var jugador: Node = admin.jugador
	var admin_actual: Node = admin
	terminar(true, npcs)
	jugador.end_dialog()
	jugador.no_control = true
	admin_actual.conectar_escalera(mapa, Vector2(celda), mirada)


## BattleTower_SoftReset: guardado o no, se vuelve a la pantalla de inicio y lo que no se guardó se pierde.
func _reiniciar_juego() -> void:
	terminar(false)
	if reinicio.is_valid():
		reinicio.call()
		return
	Singleton.mantener_pausa(motivo_pausa, false)
	get_tree().reload_current_scene()

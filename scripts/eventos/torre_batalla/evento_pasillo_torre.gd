## evento_pasillo_torre.gd
## Pasillo de la TORRE BATALLA (pokeruby data/maps/BattleTower_Corridor/scripts.inc): la puerta abierta es la (12,0) en
## el nivel 50 y la (15,0) en el nivel 100; la azafata entra primero y el jugador la sigue hasta la sala.
class_name EventoPasilloTorre
extends EventoTorreBatalla

const CELDA_AZAFATA: Vector2i = Vector2i(9, 2)
const CELDA_JUGADOR: Vector2i = Vector2i(8, 2)
const CELDA_SALA: Vector2i = Vector2i(4, 8)

@export var azafata: NodePath
## setmetatile de OnLoad: las puertas abiertas, una por nivel.
@export var puerta_nivel_50: NodePath
@export var puerta_nivel_100: NodePath


func preparar() -> void:
	var npc := _npc(azafata)
	if npc != null:
		colocar(npc, CELDA_AZAFATA)
		npc.visible = true
		mirar(npc, Vector2.LEFT)
	var nivel_100 := RetoTorreBatalla.nivel() == RetoTorreBatalla.NIVEL_100
	var puerta_50 := get_node_or_null(puerta_nivel_50) as CanvasItem
	var puerta_100 := get_node_or_null(puerta_nivel_100) as CanvasItem
	if puerta_50 != null:
		puerta_50.visible = not nivel_100
	if puerta_100 != null:
		puerta_100.visible = nivel_100


## Pasos a la derecha hasta la puerta: BattleTower_Corridor_Movement_1608D1 .. 1608D5.
static func pasos_azafata(tipo: int) -> int:
	return 6 if tipo == RetoTorreBatalla.NIVEL_100 else 3


static func pasos_jugador(tipo: int) -> int:
	return pasos_azafata(tipo) + 1


func guion_entrada() -> void:
	if not comenzar(_administrador()):
		return
	var npc := _npc(azafata)
	admin.jugador.visible = true
	colocar_jugador(CELDA_JUGADOR, Vector2.RIGHT)
	var tipo := RetoTorreBatalla.nivel()
	var ruta_jugador: Array = []
	ruta_jugador.resize(pasos_jugador(tipo))
	ruta_jugador.fill(Vector2.RIGHT)
	ruta_jugador.append(Vector2.UP)
	var tareas: Array[Callable] = [recorrer_jugador.bind(ruta_jugador)]
	if npc != null:
		var ruta_azafata: Array = []
		ruta_azafata.resize(pasos_azafata(tipo))
		ruta_azafata.fill(Vector2.RIGHT)
		ruta_azafata.append(Vector2.UP)
		tareas.append(recorrer.bind(npc, ruta_azafata))
	await en_paralelo(tareas)
	if npc != null:
		npc.visible = false
	admin.jugador.visible = false
	_ir_a(MAPA_SALA, CELDA_SALA, Vector2.UP, [npc] if npc != null else [])

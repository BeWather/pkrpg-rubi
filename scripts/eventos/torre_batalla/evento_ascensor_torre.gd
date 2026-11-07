## evento_ascensor_torre.gd
## Ascensor de la TORRE BATALLA (pokeruby data/maps/BattleTower_Elevator/scripts.inc): suben la azafata y el jugador,
## el ascensor tiembla (ShakeScreenInElevator) y salen al pasillo.
class_name EventoAscensorTorre
extends EventoTorreBatalla

const CELDA_AZAFATA: Vector2i = Vector2i(1, 5)
const CELDA_JUGADOR: Vector2i = Vector2i(1, 6)
const CELDA_PASILLO: Vector2i = Vector2i(8, 2)

@export var azafata: NodePath


func preparar() -> void:
	var npc := _npc(azafata)
	if npc != null:
		colocar(npc, CELDA_AZAFATA)
		npc.visible = true
		mirar(npc, Vector2.UP)


func guion_entrada() -> void:
	if not comenzar(_administrador()):
		return
	var npc := _npc(azafata)
	admin.jugador.visible = true
	colocar_jugador(CELDA_JUGADOR, Vector2.UP)
	var subir: Array[Callable] = [recorrer_jugador.bind([Vector2.UP, Vector2.UP])]
	if npc != null:
		subir.append(recorrer.bind(npc, [Vector2.UP, Vector2.RIGHT]))
	await en_paralelo(subir)
	girar_jugador(Vector2.DOWN)
	if npc != null:
		mirar(npc, Vector2.DOWN)
	await _temblar()
	await esperar_fotogramas(64)
	var salir: Array[Callable] = [recorrer_jugador.bind([Vector2.RIGHT, Vector2.DOWN, Vector2.DOWN])]
	if npc != null:
		salir.append(recorrer.bind(npc, [Vector2.DOWN, Vector2.DOWN]))
	await en_paralelo(salir)
	if npc != null:
		npc.visible = false
	_ir_a(MAPA_PASILLO, CELDA_PASILLO, Vector2.RIGHT, [npc] if npc != null else [])


## ShakeScreenInElevator: ±1 px cada 3 ticks, 23 cambios (69 ticks).
func _temblar() -> void:
	var camara := get_viewport().get_camera_2d()
	var base := camara.offset if camara != null else Vector2.ZERO
	Singleton.play_sound.emit("SE_ELEVATOR")
	for tick in range(1, 70):
		if camara != null and tick % 3 == 0:
			camara.offset = base + Vector2(0, -1 if (tick / 3) % 2 == 1 else 1)
		await esperar_fotogramas(1)
	if camara != null:
		camara.offset = base

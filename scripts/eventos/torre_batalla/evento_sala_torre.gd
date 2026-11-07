## evento_sala_torre.gd
## SALA BATALLA de la TORRE BATALLA (pokeruby data/maps/BattleTower_BattleRoom/scripts.inc): siete entrenadores seguidos,
## con la azafata (objeto 2, (1,7)) entre combates. Tras cada victoria se recupera el equipo como estaba y se cura. Entre
## combates: seguir, guardar y dejar de jugar, o cancelar (sin guardar: al continuar, «se te olvidó guardar»).
class_name EventoSalaTorre
extends EventoTorreBatalla

const CELDA_JUGADOR: Vector2i = Vector2i(4, 8)
const CELDA_RIVAL: Vector2i = Vector2i(5, 1)
const CELDA_AZAFATA: Vector2i = Vector2i(1, 7)
const CELDA_VESTIBULO: Vector2i = Vector2i(6, 6)
const TEMA_CURACION: String = "POKEMON_RECUPERADOS"

@export var rival: NodePath
@export var azafata: NodePath

## Sustituye al combate (tests): call(id_entrenador) -> bool (ganó el jugador).
var combate_simulado: Callable = Callable()
## Sustituye al guardado (tests).
var guardador: Callable = Callable()


func preparar() -> void:
	var npc_rival := _npc(rival)
	if npc_rival != null:
		colocar(npc_rival, CELDA_RIVAL)
		npc_rival.visible = false
	var npc_azafata := _npc(azafata)
	if npc_azafata != null:
		colocar(npc_azafata, CELDA_AZAFATA)
		npc_azafata.visible = true
		mirar(npc_azafata, Vector2.RIGHT)


## BattleTower_BattleRoom_EventScript_1608EB.
func guion_entrada() -> void:
	if not comenzar(_administrador()):
		return
	admin.jugador.visible = true
	colocar_jugador(CELDA_JUGADOR, Vector2.UP)
	await recorrer_jugador([Vector2.UP, Vector2.UP, Vector2.UP])
	girar_jugador(Vector2.RIGHT)
	await _bucle_de_combates()


## BattleTower_BattleRoom_EventScript_1608FA.
func _bucle_de_combates() -> void:
	var npc_rival := _npc(rival)
	var npc_azafata := _npc(azafata)
	while true:
		var id := RetoTorreBatalla.elegir_siguiente_entrenador(rng)
		_vestir_rival(npc_rival, id)
		if npc_rival != null:
			await recorrer(npc_rival, [Vector2.DOWN, Vector2.DOWN, Vector2.DOWN, Vector2.DOWN])
			mirar(npc_rival, Vector2.LEFT)
		await mensaje(RetoTorreBatalla.clave_saludo(id))
		SistemaGuardado.curar_equipo_completo()
		if not await _combatir(id):
			# Derrota: LoadPlayerParty, estado 5, warp al vestíbulo.
			RetoTorreBatalla.cargar_copia_equipo()
			RetoTorreBatalla.anotar_derrota()
			_volver_al_vestibulo()
			return
		# BattleTower_BattleRoom_EventScript_160961.
		if RetoTorreBatalla.anotar_victoria() > RetoTorreBatalla.COMBATES_POR_RETO:
			# BattleTower_BattleRoom_EventScript_160A56.
			RetoTorreBatalla.cargar_copia_equipo()
			RetoTorreBatalla.anotar_reto_ganado()
			_volver_al_vestibulo()
			return
		if npc_rival != null:
			await recorrer(npc_rival, [Vector2.UP, Vector2.UP, Vector2.UP, Vector2.UP])
			npc_rival.visible = false
			colocar(npc_rival, CELDA_RIVAL)
		if npc_azafata != null:
			await recorrer(npc_azafata, [Vector2.RIGHT, Vector2.RIGHT, Vector2.RIGHT, Vector2.UP])
		girar_jugador(Vector2.DOWN)
		await mensaje(P + "CURAR")
		RetoTorreBatalla.cargar_copia_equipo()
		RetoTorreBatalla.guardar_copia_equipo()
		RetoTorreBatalla.reducir_equipo()
		await fanfarria(TEMA_CURACION, true)
		SistemaGuardado.curar_equipo_completo()
		if not await _menu_entre_combates():
			return
		admin.cuadro_dialogo.cerrar()
		girar_jugador(Vector2.RIGHT)
		if npc_azafata != null:
			await recorrer(npc_azafata, [Vector2.DOWN, Vector2.LEFT, Vector2.LEFT, Vector2.LEFT])
			mirar(npc_azafata, Vector2.RIGHT)


## BattleTower_BattleRoom_EventScript_1609B2. Devuelve true para seguir combatiendo.
func _menu_entre_combates() -> bool:
	while true:
		if await preguntar_si_no(P + "OPONENTE", {"{valor}": RetoTorreBatalla.combate()}):
			return true
		if await preguntar_si_no(P + "GUARDAR_Y_DEJAR"):
			await _guardar_y_salir()
			return false
		if await preguntar_si_no(P + "CANCELAR_RETO"):
			await oscurecer_pantalla()
			_reiniciar_juego()
			return false
	return false


## BattleTower_BattleRoom_EventScript_160A94: se guarda el equipo entero y el vestíbulo; al continuar, se retoma ahí.
func _guardar_y_salir() -> void:
	RetoTorreBatalla.fijar_estado(RetoTorreBatalla.Estado.PAUSADO)
	RetoTorreBatalla.fijar_ya_guardado(true)
	await mensaje(P + "GUARDANDO", false)
	await esperar_fotogramas(60)
	RetoTorreBatalla.cargar_copia_equipo()
	_escribir_guardado()
	Singleton.play_sound.emit("SE_SAVE")
	await mensaje(P + "GUARDADA")
	await oscurecer_pantalla()
	_reiniciar_juego()


func _escribir_guardado() -> void:
	if guardador.is_valid():
		guardador.call()
		return
	SistemaGuardado.actualizar_datos_vivos()
	var posicion: Dictionary = SistemaGuardado.datos_vivos.posicion
	posicion["mapa_actual"] = MAPA_VESTIBULO
	posicion["cx"] = CELDA_VESTIBULO.x
	posicion["cy"] = CELDA_VESTIBULO.y
	posicion["direccion"] = [0, -1]
	SistemaGuardado.guardar_partida(true)


## SetBattleTowerTrainerGfxId: VAR_OBJ_GFX_ID_0 según la clase del entrenador.
func _vestir_rival(npc: Node2D, id: int) -> void:
	if npc == null:
		return
	var fila := RetoTorreBatalla.datos_entrenador_torre(id)
	var marcos := load("res://escenas/avatares/%s.tres" % str(fila["sprite"])) as SpriteFrames
	npc.set("tamano_sprite", int(fila["tamano_sprite"]))
	if marcos != null:
		npc.selec_frames = marcos
	colocar(npc, CELDA_RIVAL)
	npc.visible = true
	mirar(npc, Vector2.DOWN)


## StartSpecialBattle 0: BATTLE_TYPE_BATTLE_TOWER | BATTLE_TYPE_TRAINER.
func _combatir(id: int) -> bool:
	if combate_simulado.is_valid():
		return bool(combate_simulado.call(id))
	admin.cuadro_dialogo.cerrar()
	var manager := admin.get("battle_manager") as OverworldBattleManager
	if manager == null:
		push_warning("[%s] Sin OverworldBattleManager" % motivo_pausa)
		return false
	var rivales := RetoTorreBatalla.generar_equipo_rival(id, RetoTorreBatalla.nivel(), rng)
	var ejecucion: ResultadoEjecucionBatalla = await manager.combatir_torre_batalla(RetoTorreBatalla.crear_entrenador(id), rivales)
	if ejecucion.fue_rechazada():
		push_warning("[%s] Combate %d rechazado: %s" % [motivo_pausa, id, ejecucion.codigo_error])
		return false
	return ejecucion.resultado == ResultadoBatalla.Valor.VICTORIA_JUGADOR


## warp MAP_BATTLE_TOWER_LOBBY, 255, 6, 6.
func _volver_al_vestibulo() -> void:
	var npcs: Array = []
	for ruta: NodePath in [rival, azafata]:
		var npc := _npc(ruta)
		if npc != null:
			npcs.append(npc)
	_ir_a(MAPA_VESTIBULO, CELDA_VESTIBULO, Vector2.UP, npcs)

## evento_bosque_petalia.gd
## El soldado del EQUIPO MAGMA y el investigador de DEVON en el BOSQUE PETALIA
## (pokeruby PetalburgWoods_EventScript_15CCA8 / 15CD42). Coordenadas de Godot =
## Rubí + (3,0).
##
## Con VAR_PETALBURG_WOODS_STATE 0 (sin `BANDERA_HECHO`), al pisar (26,23) o (27,23)
## de Rubí:
## 1. El investigador mira a todos lados («Ni uno...»), se acerca al jugador y le pregunta
##    por SHROOMISH. Suena MUS_EVIL_TEAM y el soldado baja desde (26,17).
## 2. El soldado se presenta, va a por los papeles; el investigador se esconde detrás
##    del jugador y pide ayuda; el soldado reta al jugador (trainerbattle_no_intro).
## 3. Tras ganar: el soldado retrocede, se va hacia arriba y desaparece; el investigador
##    regala una SUPERBALL, avisa de CIUDAD FÉRRICA y se va corriendo hacia el norte.
##    VAR_PETALBURG_WOODS_STATE 1: los dos quedan ocultos (removeobject).
## Perder el combate no cambia el estado: al volver, los dos están en su sitio.
extends EventoGuionizado
class_name EventoBosquePetalia

const MOTIVO_PAUSA: StringName = &"bosque_petalia"
## VAR_PETALBURG_WOODS_STATE 1 / FLAG_HIDE_EVIL_TEAM_PETALBURG_WOODS /
## FLAG_HIDE_DEVON_PETALBURG_WOODS (removeobject).
const BANDERA_HECHO: String = "bosque_petalia_devon_rescatado"
## TRAINER_PETALBURG_WOODS_GRUNT de Rubí (TRAINER_GRUNT_36).
const ENTRENADOR_SOLDADO: int = 575
const MUSICA_MAGMA: String = "EQUIPO_MAGMA_APARECE"  # MUS_EVIL_TEAM
const MUSICA_COMBATE: String = "EQUIPO_AQUA_MAGMA_BATALLA"
const OBJETO_REGALO: String = "SUPERBALL"

const TEXTO_NI_UNO: String = "BOSQUE_PETALIA_DEVON_NI_UNO"
const TEXTO_SHROOMISH: String = "BOSQUE_PETALIA_DEVON_SHROOMISH"
const TEXTO_EMBOSCADA: String = "BOSQUE_PETALIA_MAGMA_EMBOSCADA"
const TEXTO_PAPELES: String = "BOSQUE_PETALIA_MAGMA_PAPELES"
const TEXTO_AYUDA: String = "BOSQUE_PETALIA_DEVON_AYUDA"
const TEXTO_RETO: String = "BOSQUE_PETALIA_MAGMA_RETO"
const TEXTO_HUYE: String = "BOSQUE_PETALIA_MAGMA_HUYE"
const TEXTO_GRACIAS: String = "BOSQUE_PETALIA_DEVON_GRACIAS"
const TEXTO_MOCHILA_LLENA: String = "BOSQUE_PETALIA_DEVON_MOCHILA_LLENA"
const TEXTO_FERRICA: String = "BOSQUE_PETALIA_DEVON_FERRICA"
const TEXTO_PRISA: String = "BOSQUE_PETALIA_DEVON_PRISA"

## Celdas de Godot del soldado (objeto 3) y del investigador (objeto 4).
const CELDA_SOLDADO := Vector2i(29, 17)
const CELDA_INVESTIGADOR := Vector2i(29, 20)

@export var soldado: NodePath
@export var investigador: NodePath

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
		mapa.mapa_activado.connect(func(_por_warp: bool) -> void: preparar())
	preparar()


func _npc(ruta: NodePath) -> Node2D:
	return get_node_or_null(ruta) as Node2D


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


static func hecho() -> bool:
	return SistemaGuardado.get_flag(BANDERA_HECHO)


## Los dos en su sitio mientras no se haya resuelto (tras perder vuelven a él).
func preparar() -> void:
	if _en_curso:
		return
	var npc_soldado := _npc(soldado)
	var npc_investigador := _npc(investigador)
	if npc_soldado != null:
		npc_soldado.tipo_movimiento = NpcBase.TipoMovimientoNPC.MIRAR_DERECHA
		colocar(npc_soldado, CELDA_SOLDADO)
		npc_soldado.visible = not hecho()
	if npc_investigador != null:
		npc_investigador.tipo_movimiento = NpcBase.TipoMovimientoNPC.MIRAR_ALREDEDOR
		colocar(npc_investigador, CELDA_INVESTIGADOR)
		npc_investigador.visible = not hecho()


func _on_disparador(id_evento: StringName) -> void:
	if _en_curso or hecho():
		return
	match id_evento:
		&"trigger_0":
			emboscada(false)
		&"trigger_1":
			emboscada(true)


## PetalburgWoods_EventScript_15CCA8 (`derecha` = false) y 15CD42 (true): el jugador
## pisa (26,23) o (27,23) de Rubí.
func emboscada(derecha: bool) -> void:
	var npc_soldado := _npc(soldado)
	var npc_investigador := _npc(investigador)
	if npc_soldado == null or npc_investigador == null or not comenzar(_administrador()):
		return
	for npc in [npc_soldado, npc_investigador]:
		npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	# PetalburgWoods_EventScript_15CDE6: mira a todos lados.
	for direccion in [Vector2.UP, Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.RIGHT, Vector2.UP]:
		mirar(npc_investigador, direccion)
		await esperar_fotogramas(16)
	await mensaje(TEXTO_NI_UNO)
	# delay_16, face_player y baja hasta el jugador.
	await esperar_fotogramas(16)
	if derecha:
		mirar(npc_investigador, Vector2.RIGHT)
		await recorrer(npc_investigador, [Vector2.DOWN, Vector2.DOWN, Vector2.DOWN])
		mirar(npc_investigador, Vector2.RIGHT)
		girar_jugador(Vector2.LEFT)
	else:
		mirar(npc_investigador, Vector2.DOWN)
		await recorrer(npc_investigador, [Vector2.DOWN, Vector2.DOWN])
	await mensaje(TEXTO_SHROOMISH)
	reproducir_musica(MUSICA_MAGMA)
	await recorrer(npc_soldado, [Vector2.DOWN, Vector2.DOWN])  # PetalburgWoods_Movement_15CEC3
	await esperar_fotogramas(32)
	await mensaje(TEXTO_EMBOSCADA)
	if derecha:
		await recorrer(npc_soldado, [Vector2.DOWN, Vector2.DOWN, Vector2.DOWN], VelocidadPaso.RAPIDO)  # 15CEBF
	else:
		await recorrer(npc_soldado, [Vector2.DOWN, Vector2.DOWN], VelocidadPaso.RAPIDO)  # 15CEB0
	mirar(npc_investigador, Vector2.UP)
	await mensaje(TEXTO_PAPELES)
	# El investigador se pone detrás del jugador y mira arriba.
	if derecha:
		await recorrer(npc_investigador, [Vector2.DOWN, Vector2.RIGHT], VelocidadPaso.RAPIDO)  # 15CEA4
	else:
		await recorrer(npc_investigador, [Vector2.RIGHT, Vector2.DOWN, Vector2.DOWN, Vector2.LEFT], VelocidadPaso.RAPIDO)  # 15CE9E
	mirar(npc_investigador, Vector2.UP)
	await mensaje(TEXTO_AYUDA)
	if derecha:
		girar_jugador(Vector2.UP)
	else:
		await caminar(npc_soldado, Vector2.DOWN)  # 15CEC8
	await mensaje(TEXTO_RETO)
	var resultado := await combatir(ENTRENADOR_SOLDADO, MUSICA_COMBATE)
	if resultado != &"victoria":
		terminar(resultado == &"derrota_transferida", [npc_soldado, npc_investigador])
		preparar()
		return
	# PetalburgWoods_Movement_15CEB3: retrocede sin dejar de mirar abajo.
	await caminar(npc_soldado, Vector2.UP)
	mirar(npc_soldado, Vector2.DOWN)
	await _despedidas(npc_soldado, npc_investigador)
	# PetalburgWoods_Movement_15CE80 / 15CE95: el investigador se va corriendo.
	var salida: Array = [Vector2.LEFT] if derecha else [Vector2.RIGHT]
	for i in 7:
		salida.append(Vector2.UP)
	await recorrer(npc_investigador, salida, VelocidadPaso.RAPIDO)
	npc_investigador.visible = false  # removeobject 4
	SistemaGuardado.set_flag(BANDERA_HECHO, true)  # VAR_PETALBURG_WOODS_STATE 1
	restaurar_musica_mapa()
	terminar(false, [npc_soldado, npc_investigador])


## PetalburgWoods_EventScript_15CDFA.
func _despedidas(npc_soldado: Node2D, npc_investigador: Node2D) -> void:
	await mensaje(TEXTO_HUYE)
	await recorrer(npc_soldado, [Vector2.UP, Vector2.UP, Vector2.UP, Vector2.UP, Vector2.UP], VelocidadPaso.RAPIDO)  # 15CEB7
	await esperar_fotogramas(32)
	npc_soldado.visible = false  # removeobject 3
	restaurar_musica_mapa()
	girar_jugador(Vector2.DOWN)
	await mensaje(TEXTO_GRACIAS, false)
	if not await dar_objeto(npc_investigador, OBJETO_REGALO):  # giveitem ITEM_GREAT_BALL
		await mensaje(TEXTO_MOCHILA_LLENA, false)
	await mensaje(TEXTO_FERRICA)
	# PetalburgWoods_Movement_15CEA8: mira abajo, delay_16 ×5 y mira arriba.
	mirar(npc_investigador, Vector2.DOWN)
	await esperar_fotogramas(80)
	mirar(npc_investigador, Vector2.UP)
	await mensaje(TEXTO_PRISA)
	admin.cuadro_dialogo.cerrar()

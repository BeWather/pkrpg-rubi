## evento_ruta_128.gd
## Escena del POKéMON antiguo en la RUTA 128 (pokeruby Route128_EventScript_15213F, OnFrame con VAR_ROUTE128_STATE == 1;
## contador `ruta128_estado`, empieza en 0). MAXIE = MAGNO, ARCHIE = AQUILES, STEVEN = MÁXIMO (nombres de la ROM española).
## Godot = Rubí + (0,0).
##
## Con el estado en 1, al activarse el mapa: MAGNO (objeto 4, (37,22)) y AQUILES (objeto 5, (38,21)) ya están en escena (la historia
## de ARRECÍPOLIS limpia sus FLAG_HIDE_*; aquí `ruta128_magno_visible` / `ruta128_aquiles_visible` y el propio evento los activa si
## nadie lo hizo). Delay 20; MAGNO baja un paso, mira a la izquierda y a la derecha y de frente; dice «¿qué ha pasado?», retrocede
## despacio (lock_facing_direction + walk_slow_up) y «yo sólo quería...»; AQUILES se acerca a la izquierda y mira abajo, MAGNO
## mira arriba; AQUILES le habla («¿ahora lo entiendes?»), da un paso a la derecha, mira abajo, el jugador mira arriba y te
## manda irte; MAGNO retrocede tres casillas a la izquierda (el jugador mira a la izquierda, AQUILES camina dos), «esto desafía toda
## lógica...»; delay 40; los dos se van andando a toda prisa (removeobject 5 y 4); delay 100; aparece MÁXIMO (objeto 3, (40,22);
## addobject 3), da un paso rápido a la izquierda, «¿qué pasa aquí?», sube una casilla, cuenta lo del sol abrasador, mira abajo,
## «voy a ARRECÍPOLIS», espera 50 fotogramas y se va. El estado pasa a 2.
##
## NO migrado:
## - `special sub_807E25C` (efecto visual de pantalla de Rubí, solo en la versión Ruby): no existe en el proyecto.
## - Common_EventScript_SetupEvilTeamGfxIds de OnTransition: los líderes llevan fijos los gráficos de Rubí (MAXIE 042 y
##   ARCHIE 041). La sequía de SetLegendaryWeather (FLAG_SYS_WEATHER_CTRL) la pone ClimaLegendario.
## `ruta128_estado` = 1 y las dos banderas de los líderes (clearflag FLAG_HIDE_EVIL_LEADER_ROUTE128 /
## FLAG_HIDE_OTHER_LEADER_ROUTE128) los pone el final de la CAVERNA ABISAL (EventoCavernaAbisal).
extends EventoInteriorMalvalona
class_name EventoRuta128

const MOTIVO_PAUSA: StringName = &"ruta_128"

## VAR_ROUTE128_STATE.
const CONTADOR_ESTADO: String = "ruta128_estado"
## Inversas de FLAG_HIDE_STEVEN_ROUTE128, FLAG_HIDE_EVIL_LEADER_ROUTE128 y FLAG_HIDE_OTHER_LEADER_ROUTE128 (new_game.inc las
## activa al empezar: los tres empiezan ocultos).
const BANDERA_STEVEN: String = "ruta128_steven_visible"
const BANDERA_MAGNO: String = "ruta128_magno_visible"
const BANDERA_AQUILES: String = "ruta128_aquiles_visible"

## delay 20, 40, 100 y 50; delay_16 de los movimientos.
const FOTOGRAMAS_DELAY_20: int = 20
const FOTOGRAMAS_DELAY_40: int = 40
const FOTOGRAMAS_DELAY_100: int = 100
const FOTOGRAMAS_DELAY_50: int = 50
const FOTOGRAMAS_DELAY_16: int = 16

## Route128_Movement_15227E (MAGNO): 3 pasos rápidos a la izquierda y mira a la derecha.
const PASOS_MAGNO_RETROCEDE: Array[Vector2] = [Vector2.LEFT, Vector2.LEFT, Vector2.LEFT]
## Route128_Movement_152290 (AQUILES): 2 pasos a la izquierda.
const PASOS_AQUILES_SE_ACERCA: Array[Vector2] = [Vector2.LEFT, Vector2.LEFT]
## Route128_Movement_152296 (AQUILES): 3 pasos rápidos a la izquierda y 7 hacia arriba.
const PASOS_AQUILES_SE_VA: Array[Vector2] = [
	Vector2.LEFT, Vector2.LEFT, Vector2.LEFT,
	Vector2.UP, Vector2.UP, Vector2.UP, Vector2.UP, Vector2.UP, Vector2.UP, Vector2.UP,
]
## Route128_Movement_152283 (MAGNO), tras 2 × delay_16: arriba, izquierda y 8 hacia arriba.
const PASOS_MAGNO_SE_VA: Array[Vector2] = [
	Vector2.UP, Vector2.LEFT,
	Vector2.UP, Vector2.UP, Vector2.UP, Vector2.UP, Vector2.UP, Vector2.UP, Vector2.UP, Vector2.UP,
]

const T := "RUTA128_HISTORIA_"
const TEXTO_MAGNO_1: String = T + "MAGNO_1"
const TEXTO_MAGNO_2: String = T + "MAGNO_2"
const TEXTO_AQUILES_1: String = T + "AQUILES_1"
const TEXTO_AQUILES_2: String = T + "AQUILES_2"
const TEXTO_AQUILES_3: String = T + "AQUILES_3"
const TEXTO_MAXIMO_1: String = T + "MAXIMO_1"
const TEXTO_MAXIMO_2: String = T + "MAXIMO_2"
const TEXTO_MAXIMO_3: String = T + "MAXIMO_3"

@export var steven: NodePath
@export var magno: NodePath
@export var aquiles: NodePath


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)


## map_script_2 VAR_ROUTE128_STATE, 1.
func _on_mapa_activado(_por_warp: bool) -> void:
	if SistemaGuardado.get_contador(CONTADOR_ESTADO) == 1 and not en_curso():
		escena_del_pokemon_antiguo()


## Route128_EventScript_15213F.
func escena_del_pokemon_antiguo() -> void:
	var npc_steven := nodo(steven)
	var npc_magno := nodo(magno)
	var npc_aquiles := nodo(aquiles)
	if npc_steven == null or npc_magno == null or npc_aquiles == null or not comenzar(_administrador()):
		return
	var npcs: Array = [npc_steven, npc_magno, npc_aquiles]
	# Los líderes están en el mapa mientras dura el estado 1.
	_mostrar(npc_magno, BANDERA_MAGNO, true)
	_mostrar(npc_aquiles, BANDERA_AQUILES, true)
	await esperar_fin_warp(admin)
	for npc in npcs:
		npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	await esperar_fotogramas(FOTOGRAMAS_DELAY_20)
	# MAGNO: Route128_Movement_152271.
	await caminar(npc_magno, D, VelocidadPaso.RAPIDO)
	mirar(npc_magno, L)
	await esperar_fotogramas(FOTOGRAMAS_DELAY_16)
	mirar(npc_magno, R)
	await esperar_fotogramas(2 * FOTOGRAMAS_DELAY_16)
	mirar(npc_magno, D)
	await mensaje(TEXTO_MAGNO_1)
	# Route128_Movement_152279: lock_facing_direction + walk_slow_up + delay_16.
	await caminar(npc_magno, U, VelocidadPaso.LENTO, D)
	await esperar_fotogramas(FOTOGRAMAS_DELAY_16)
	await mensaje(TEXTO_MAGNO_2)
	admin.cuadro_dialogo.cerrar()  # closemessage
	# AQUILES: Route128_Movement_152293.
	await caminar(npc_aquiles, L)
	mirar(npc_aquiles, D)
	mirar(npc_magno, U)  # Common_Movement_WalkInPlaceFastestUp
	await mensaje(TEXTO_AQUILES_1)
	admin.cuadro_dialogo.cerrar()
	# Route128_Movement_1522A1.
	await caminar(npc_aquiles, R)
	mirar(npc_aquiles, D)
	girar_jugador(U)
	await mensaje(TEXTO_AQUILES_2)
	admin.cuadro_dialogo.cerrar()
	girar_jugador(L)
	var retrocede := func() -> void:
		await recorrer(npc_magno, PASOS_MAGNO_RETROCEDE, VelocidadPaso.RAPIDO)
		mirar(npc_magno, R)
	var se_acerca := func() -> void:
		await recorrer(npc_aquiles, PASOS_AQUILES_SE_ACERCA)
	await en_paralelo([retrocede, se_acerca])
	await mensaje(TEXTO_AQUILES_3)
	admin.cuadro_dialogo.cerrar()
	await esperar_fotogramas(FOTOGRAMAS_DELAY_40)
	var magno_se_va := func() -> void:
		await esperar_fotogramas(2 * FOTOGRAMAS_DELAY_16)
		await recorrer(npc_magno, PASOS_MAGNO_SE_VA, VelocidadPaso.RAPIDO)
	var aquiles_se_va := func() -> void:
		await recorrer(npc_aquiles, PASOS_AQUILES_SE_VA, VelocidadPaso.RAPIDO)
	await en_paralelo([aquiles_se_va, magno_se_va])
	_mostrar(npc_aquiles, BANDERA_AQUILES, false)  # removeobject 5
	_mostrar(npc_magno, BANDERA_MAGNO, false)  # removeobject 4
	await esperar_fotogramas(FOTOGRAMAS_DELAY_100)
	await cruzar_pajaro_vuelo()
	# MÁXIMO: addobject 3 + Route128_Movement_15226F.
	_mostrar(npc_steven, BANDERA_STEVEN, true)
	await caminar(npc_steven, L, VelocidadPaso.RAPIDO)
	girar_jugador(R)
	await mensaje(TEXTO_MAXIMO_1)
	admin.cuadro_dialogo.cerrar()
	var steven_sube := func() -> void:
		await caminar(npc_steven, U)  # Route128_Movement_15226D
	girar_jugador(U)
	await en_paralelo([steven_sube])
	await mensaje(TEXTO_MAXIMO_2)
	mirar(npc_steven, D)
	await mensaje(TEXTO_MAXIMO_3)
	admin.cuadro_dialogo.cerrar()
	mirar(npc_steven, D)
	await esperar_fotogramas(FOTOGRAMAS_DELAY_50)
	await salir_volando(npc_steven)
	_mostrar(npc_steven, BANDERA_STEVEN, false)
	SistemaGuardado.set_contador(CONTADOR_ESTADO, 2)
	terminar(false, npcs)


## addobject / removeobject: la bandera positiva (inversa de FLAG_HIDE_*) y la visibilidad del NPC.
func _mostrar(npc: Node2D, bandera: String, visible_: bool) -> void:
	SistemaGuardado.set_flag(bandera, visible_)
	npc.aplicar_bandera_ocultar()

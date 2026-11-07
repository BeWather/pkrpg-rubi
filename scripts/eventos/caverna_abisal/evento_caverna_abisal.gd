## evento_caverna_abisal.gd
## Despertar de GROUDON en la sala 9 de la CAVERNA ABISAL (pokeruby data/maps/SeafloorCavern_Room9/scripts.inc,
## SeafloorCavern_Room9_EventScript_15DAFA, coord_event (17,42) con VAR_SEAFLOOR_CAVERN_STATE = 0; contador
## `caverna_abisal_estado`). Las celdas de Godot son las de Rubí; MAXIE = MAGNO y ARCHIE = AQUILES (ROM española).
##
## El jugador mira arriba, «¡No te muevas!»; MAGNO aparece en (9,42), se acerca siete pasos y, tras hablar, combate
## (trainerbattle_no_intro TRAINER 601). Con la victoria: se despeja la niebla, la ESFERA AZUL brilla (destello en
## (16,42), SE_M_DETECT), suena MUS_AWAKEN_LEGEND con SE_ORB y la pantalla se tiñe de azul (DestelloEsfera), el GROUDON
## dormido se va y aparece el despierto, que baja dos casillas despacio, se desvanece el azul, tiembla la cámara (1,1),
## sube deslizándose y se va (temblor 2,2). MAGNO recibe el aviso
## de los suyos (SE_PC_LOGIN / SE_PC_OFF); llegan AQUILES y dos soldados AQUA; MAGNO se sorprende (exclamación),
## retrocede un paso y AQUILES te pide que salgas. Al final: estado 1, se ocultan los soldados MAGMA de la caverna
## (`caverna_abisal_soldados_ocultos`), MÁXIMO deja su casa de ALGARIA (`algaria_maximo_oculto`, estado 1 de su casa),
## la escena de la RUTA 128 queda lista (`ruta128_estado` = 1 con MAGNO y AQUILES visibles), ARRECÍPOLIS pasa al estado
## 1 con la sequía (HistoriaArrecipolis.al_escapar_legendario) y warp a la RUTA 128 (38,22).
## Con una derrota ante MAGNO, él vuelve a ocultarse en su sitio y el disparador sigue activo.
##
## El destello azul de la ESFERA (special sub_80818A4 / sub_80818FC) lo hace DestelloEsfera.
extends EventoInteriorMalvalona
class_name EventoCavernaAbisal

const MOTIVO_PAUSA: StringName = &"caverna_abisal"

## VAR_SEAFLOOR_CAVERN_STATE.
const CONTADOR_ESTADO: String = "caverna_abisal_estado"
## FLAG_HIDE_EVIL_TEAM_GRUNTS_SEAFLOOR_CAVERN (`bandera_ocultar` de los soldados MAGMA).
const BANDERA_SOLDADOS_OCULTOS: String = "caverna_abisal_soldados_ocultos"
## TRAINER 601 (MAGNO, ROM española).
const ENTRENADOR_MAGNO: int = 601
const NUMERO_GROUDON: int = 383
const FANFARRIA_DESPERTAR: String = "DESPIERTAN_LEGENDARIOS"  # MUS_AWAKEN_LEGEND
const CLIMA_DESPEJADO := preload("res://recursos/clima/ninguno.tres")

## Celdas de Rubí.
const CELDA_LIDER := Vector2i(9, 42)
const CELDAS_SOLDADOS: Array[Vector2i] = [Vector2i(8, 41), Vector2i(8, 42)]
const CELDA_DESTELLO := Vector2i(16, 42)
const CELDA_GROUDON := Vector2i(17, 38)

## Lo que toca al terminar (EventoRuta128, EventoCasaMaximo).
const CONTADOR_RUTA_128: String = "ruta128_estado"
const BANDERA_MAGNO_RUTA_128: String = "ruta128_magno_visible"
const BANDERA_AQUILES_RUTA_128: String = "ruta128_aquiles_visible"
const BANDERA_MAXIMO_OCULTO: String = "algaria_maximo_oculto"
const CONTADOR_CASA_MAXIMO: String = "algaria_casa_maximo_estado"
const MAPA_RUTA_128: String = "ruta_128"
const LLEGADA_RUTA_128 := Vector2(38, 22)

const T := "CAVERNA_ABISAL_SALA9_%02d"

## Fotogramas (a 60 por segundo) de los delay y movimientos del guion.
const FOTOGRAMAS_DELAY_16: int = 16
const FOTOGRAMAS_DELAY_20: int = 20
const FOTOGRAMAS_DELAY_30: int = 30
const FOTOGRAMAS_DELAY_48: int = 48
const FOTOGRAMAS_DELAY_60: int = 60
const FOTOGRAMAS_DELAY_150: int = 150
## walk_slow_down (32 por casilla) y slide_up (8 por casilla) de GROUDON.
const FOTOGRAMAS_PASO_LENTO: int = 32
const FOTOGRAMAS_DESLIZ: int = 8
## FadeOutMapMusic(4): 16 pasos de volumen cada 4 fotogramas.
const FOTOGRAMAS_FUNDIDO_MUSICA: int = 64

@export var magno: NodePath
@export var aquiles: NodePath
@export var soldados: Array[NodePath] = []
@export var groudon_dormido: NodePath
@export var groudon_despierto: NodePath

## Sustituye al combate real (tests): Callable() -> StringName (&"victoria", &"derrota_transferida", &"fallo").
var combate_simulado: Callable = Callable()
## false omite el destello, la fanfarria, las sacudidas y el warp final (tests).
var con_efectos: bool = true


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
	aplicar_estado()


func _on_mapa_activado(_por_warp: bool) -> void:
	if not _en_curso:
		aplicar_estado()


static func completado() -> bool:
	return SistemaGuardado.get_contador(CONTADOR_ESTADO) >= 1


## Reparto en su sitio y oculto; el GROUDON dormido solo mientras no haya despertado.
func aplicar_estado() -> void:
	_mostrar(magno, false, CELDA_LIDER)
	_mostrar(aquiles, false, CELDA_LIDER)
	for i in soldados.size():
		_mostrar(soldados[i], false, CELDAS_SOLDADOS[mini(i, CELDAS_SOLDADOS.size() - 1)])
	var dormido := get_node_or_null(groudon_dormido) as CanvasItem
	if dormido != null:
		dormido.visible = not completado()
	var despierto := get_node_or_null(groudon_despierto) as Node2D
	if despierto != null:
		despierto.visible = false
		despierto.position = _posicion_groudon(CELDA_GROUDON)


func _mostrar(ruta: NodePath, visible_npc: bool, celda: Vector2i) -> void:
	var npc := nodo(ruta)
	if npc == null:
		return
	colocar(npc, celda)
	npc.visible = visible_npc


static func _posicion_groudon(celda: Vector2i) -> Vector2:
	return Vector2(celda.x * 16 + 8, celda.y * 16 + 16)


func _on_disparador(id_evento: StringName) -> void:
	if _en_curso or id_evento != &"magno" or completado():
		return
	await despertar_groudon()


## SeafloorCavern_Room9_EventScript_15DAFA.
func despertar_groudon() -> void:
	var npc_magno := nodo(magno)
	var npc_aquiles := nodo(aquiles)
	if npc_magno == null or npc_aquiles == null or not comenzar(_administrador()):
		return
	girar_jugador(U)
	await esperar_fotogramas(FOTOGRAMAS_DELAY_16 * 2)  # SeafloorCavern_Room9_Movement_15DD68
	await mensaje(T % 1)
	# addobject VAR_0x8004 (MAGNO) y SeafloorCavern_Room9_Movement_15DD36: siete pasos a la derecha.
	_mostrar(magno, true, CELDA_LIDER)
	npc_magno.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	girar_jugador(L)
	await recorrer(npc_magno, [R, R, R, R, R, R, R])
	await mensaje(T % 2)
	mirar(npc_magno, U)
	await mensaje(T % 3)
	mirar(npc_magno, R)  # Common_Movement_FacePlayer
	await mensaje(T % 4)
	var resultado: StringName = await _combatir_magno()
	if resultado != &"victoria":
		_mostrar(magno, false, CELDA_LIDER)
		terminar(resultado == &"derrota_transferida", [npc_magno])
		return
	await mensaje(T % 5)
	if admin.has_method("cambiar_clima_overworld"):
		admin.cambiar_clima_overworld(CLIMA_DESPEJADO)  # setweather WEATHER_NONE + doweather
	await _apagar_musica()
	await mensaje(T % 6)
	await _despertar()
	await mensaje(T % 7)
	Singleton.play_sound.emit("SE_PC_LOGIN")
	girar_jugador(L)
	await mensaje(T % 8)
	await caminar(npc_magno, L)  # SeafloorCavern_Room9_Movement_15DD41
	await esperar_fotogramas(FOTOGRAMAS_DELAY_16)
	await mensaje(T % 9)
	Singleton.play_sound.emit("SE_PC_OFF")
	await esperar_fotogramas(FOTOGRAMAS_DELAY_20)
	mirar(npc_magno, D)
	await mensaje(T % 10)
	await _llegan_los_aqua(npc_aquiles)
	mirar(npc_magno, L)
	await mensaje(T % 11)
	Singleton.play_sound.emit("SE_PIN")
	await exclamacion(npc_magno)
	await esperar_fotogramas(FOTOGRAMAS_DELAY_48)
	await mensaje(T % 12)
	await mensaje(T % 13)
	# SeafloorCavern_Room9_Movement_15DD60 (AQUILES) y _15DD46 (MAGNO: un paso atrás mirando arriba y gira a la derecha).
	var tareas: Array[Callable] = [recorrer.bind(npc_aquiles, [R, R]), _retroceder_magno.bind(npc_magno)]
	await en_paralelo(tareas)
	await mensaje(T % 14)
	_finalizar()
	var npcs: Array = [npc_magno, npc_aquiles]
	for ruta in soldados:
		npcs.append(nodo(ruta))
	if con_efectos:
		admin.conectar_escalera(MAPA_RUTA_128, LLEGADA_RUTA_128, D)
	terminar(false, npcs)


## special sub_8081924 + waitstate (Overworld_FadeOutMapMusic): la música de la caverna no vuelve; tras la fanfarria
## el resto del guion va en silencio hasta que la RUTA 128 pone la suya con el warp.
func _apagar_musica() -> void:
	var musica := admin.get("musica_player") as NuevoAudioStreamPlayer
	if musica != null:
		await musica.desvanecer_y_detener(FOTOGRAMAS_FUNDIDO_MUSICA / FOTOGRAMAS_POR_SEGUNDO if con_efectos else 0.0)


## SeafloorCavern_Room9_Movement_15DD46: face_up, lock_facing_direction, walk_down, walk_in_place_fastest_right.
func _retroceder_magno(npc_magno: Node2D) -> void:
	await caminar(npc_magno, D, VelocidadPaso.NORMAL, U)
	mirar(npc_magno, R)


func _combatir_magno() -> StringName:
	if combate_simulado.is_valid():
		admin.cuadro_dialogo.cerrar()
		return StringName(combate_simulado.call())
	return await combatir(ENTRENADOR_MAGNO)


## Destello de la ESFERA AZUL, MUS_AWAKEN_LEGEND + SE_ORB y GROUDON (removeobject 7, addobject 1, movimientos
## _15DD4C y _15DD57 con los ShakeCamera).
func _despertar() -> void:
	var npc_magno := nodo(magno)
	Singleton.play_sound.emit("SE_M_DETECT")
	if con_efectos:
		var destello := EfectoDestello.lanzar(obtener_mapa(), CELDA_DESTELLO)
		if destello != null:
			await destello.terminado
		fanfarria(FANFARRIA_DESPERTAR)
	Singleton.play_sound.emit("SE_ORB")
	# special sub_80818A4 con VAR_RESULT = 1 (Rubí): destello azul de la ESFERA AZUL.
	var destello := DestelloEsfera.lanzar(admin, true, admin.get("cam") as Camera2D, con_efectos, centro_en_pantalla(npc_magno))
	mirar(npc_magno, U)
	girar_jugador(U)
	await esperar_fotogramas(FOTOGRAMAS_DELAY_150)
	var dormido := get_node_or_null(groudon_dormido) as CanvasItem
	if dormido != null:
		dormido.visible = false
	var despierto := get_node_or_null(groudon_despierto) as Node2D
	if despierto == null:
		await destello.terminar()
		return
	despierto.position = _posicion_groudon(CELDA_GROUDON)
	despierto.visible = true
	if not destello.esta_expandido():
		await destello.expandido  # waitstate
	await esperar_fotogramas(FOTOGRAMAS_DELAY_60)
	await esperar_fotogramas(FOTOGRAMAS_DELAY_16 * 2)
	await _mover_groudon(despierto, Vector2.DOWN, FOTOGRAMAS_PASO_LENTO)
	await esperar_fotogramas(FOTOGRAMAS_DELAY_16 * 3)
	await _mover_groudon(despierto, Vector2.DOWN, FOTOGRAMAS_PASO_LENTO)
	await esperar_fotogramas(FOTOGRAMAS_DELAY_16 * 3)
	await destello.terminar()  # special sub_80818FC + waitstate
	await _sacudir(1, 1)
	await _mover_groudon(despierto, Vector2.UP, FOTOGRAMAS_DESLIZ)
	await _mover_groudon(despierto, Vector2.UP, FOTOGRAMAS_DESLIZ)
	despierto.visible = false
	await esperar_fotogramas(4)
	await _sacudir(2, 2)
	await esperar_fotogramas(FOTOGRAMAS_DELAY_30)


## Centro de la casilla del NPC en píxeles del viewport: en la ROM, (104,80) cae en la casilla de MAGNO.
static func centro_en_pantalla(npc: Node2D) -> Vector2:
	return npc.get_global_transform_with_canvas() * Vector2(0.0, 8.0 - NpcBase.OFFSET.y)


func _mover_groudon(sprite: Node2D, direccion: Vector2, fotogramas: int) -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "position", sprite.position + direccion * 16, fotogramas / FOTOGRAMAS_POR_SEGUNDO)
	await tween.finished


## special ShakeCamera con VAR_0x8004 / VAR_0x8005.
func _sacudir(horizontal: int, vertical: int) -> void:
	if not con_efectos:
		return
	var camara: Node = admin.get("cam")
	if camara != null and camara.has_method("sacudir_camara"):
		camara.call("sacudir_camara", horizontal, vertical)
		await get_tree().create_timer(camara.call("duracion_temblor")).timeout


## addobject 3, 4 y 5: AQUILES (_15DD5A, cinco pasos rápidos) y los dos soldados AQUA (_15DD63, cuatro pasos rápidos).
func _llegan_los_aqua(npc_aquiles: Node2D) -> void:
	_mostrar(aquiles, true, CELDA_LIDER)
	var tareas: Array[Callable] = [recorrer.bind(npc_aquiles, [R, R, R, R, R], VelocidadPaso.RAPIDO)]
	for i in soldados.size():
		var soldado := nodo(soldados[i])
		if soldado == null:
			continue
		_mostrar(soldados[i], true, CELDAS_SOLDADOS[mini(i, CELDAS_SOLDADOS.size() - 1)])
		soldado.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
		tareas.append(recorrer.bind(soldado, [R, R, R, R], VelocidadPaso.RAPIDO))
	npc_aquiles.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	await en_paralelo(tareas)


## Final de SeafloorCavern_Room9_EventScript_15DAFA (las variables y banderas que existen en el proyecto).
func _finalizar() -> void:
	SistemaGuardado.set_contador(CONTADOR_RUTA_128, 1)
	SistemaGuardado.set_flag(BANDERA_MAGNO_RUTA_128, true)  # clearflag FLAG_HIDE_EVIL_LEADER_ROUTE128
	SistemaGuardado.set_flag(BANDERA_AQUILES_RUTA_128, true)  # clearflag FLAG_HIDE_OTHER_LEADER_ROUTE128
	SistemaGuardado.set_flag(BANDERA_MAXIMO_OCULTO, true)  # setflag FLAG_HIDE_STEVEN_STEVENS_HOUSE
	SistemaGuardado.set_contador(CONTADOR_CASA_MAXIMO, 1)  # setvar VAR_STEVENS_HOUSE_STATE, 1
	SistemaGuardado.set_contador(CONTADOR_ESTADO, 1)
	SistemaGuardado.set_flag(BANDERA_SOLDADOS_OCULTOS, true)
	HistoriaArrecipolis.al_escapar_legendario()

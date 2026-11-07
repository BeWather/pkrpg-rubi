## evento_gimnasio_algaria.gd
## Guion del GIMNASIO de CIUDAD ALGARIA, de los líderes VITO y LETI (TATE y LIZA en inglés) y de sus
## cuatro interruptores (pokeruby data/maps/MossdeepCity_Gym/scripts.inc). Las celdas de Godot son
## las de Rubí.
##
## VITO (8,3) y LETI (9,3), objetos 0 y 8, comparten script (MossdeepCity_Gym_EventScript_TateAndLiza,
## `trainerbattle_double`): si el jugador no tiene dos POKéMON aptos lo dicen y no combaten; si no, se
## presentan y combaten en DOBLE (TRAINER_TATE_AND_LIZA, `tipo_batalla` "DOBLE" en lista_entrenadores.json).
## Al ganar entregan la MEDALLA MENTE (FLAG_BADGE07_GET y FLAG_DEFEATED_MOSSDEEP_GYM), marcan a los seis
## entrenadores como vencidos (Common_EventScript_SetGymTrainers, VAR_0x8008 = 7) y dan la MT04 PAZ MENTAL
## (la mochila llena la deja pendiente: se vuelve a ofrecer al hablarles, FLAG_RECEIVED_TM_CALM_MIND).
##
## INTERRUPTORES (bg_events `sign` PLAYER_FACING_ANY, MossdeepCity_Gym_EventScript_Switch1..4): se
## pulsan hablándoles (CartelEvento). Alternan FLAG_MOSSDEEP_GYM_SWITCH_n, esperan 2 x delay_16, cambian
## a la vez la palanca (0x238 arriba / 0x239 abajo, impasable) y una flecha roja del suelo (0x204 derecha,
## 0x20C izquierda, 0x205 abajo, 0x20D arriba) y suenan SE_CLICK. La flecha cambia de metatile Y de
## comportamiento (MB_WALK_*): aquí, atlas + banderas EMPUJE_* (SueloForzado.fijar_cinta). Como las
## banderas son persistentes, `MossdeepCity_Gym_OnLoad` repinta los cuatro pares en cada carga: aquí al
## entrar el nodo en el árbol y cada vez que el mapa pasa a ser el actual.
##
## Los seis entrenadores son TRAINER_TYPE_NORMAL (`npc_entrenador`), el guía y las estatuas no necesitan
## guion; la plataforma de teletransporte (MB_AQUA_HIDEOUT_WARP (12,3), warpteleport a (14,29)) es un Warp.
extends EventoGuionizado
class_name EventoGimnasioAlgaria

const MOTIVO_PAUSA: StringName = &"gimnasio_algaria"

## TRAINER_TATE_AND_LIZA.
const ENTRENADOR_VITO_LETI: int = 271
const MUSICA_LIDER: String = "GYM_LEADER_BATTLE"
const FANFARRIA_MEDALLA: String = "OBTENIDA_MEDALLA"
## FLAG_BADGE07_GET (MEDALLA MENTE); también hace de FLAG_DEFEATED_MOSSDEEP_GYM.
const INDICE_MEDALLA: int = 6
const OBJETO_MT04: String = "MT04"
## FLAG_RECEIVED_TM_CALM_MIND.
const BANDERA_MT04: String = "algaria_mt04_recibida"
## npc_id de los seis entrenadores (la bandera de victoria es npc_id + "_combate").
const ENTRENADORES: Array[String] = [
	"ciudad_algaria_gimnasio_patricio", "ciudad_algaria_gimnasio_virgilio",
	"ciudad_algaria_gimnasio_fede", "ciudad_algaria_gimnasio_ana",
	"ciudad_algaria_gimnasio_samanta", "ciudad_algaria_gimnasio_magda",
]
const SUFIJO_COMBATE: String = "_combate"

const T := "ALGARIA_GIMNASIO_"
const TEXTO_INTRO: String = T + "VITO_INI"
const TEXTO_SIN_DOS_POKEMON: String = T + "VITO_SIN_DOS_POKEMON"
const TEXTO_MEDALLA: String = T + "MEDALLA_RECIBIDA"
const TEXTO_MEDALLA_INFO: String = T + "MEDALLA_INFO"
const TEXTO_MT04: String = T + "MT04"
const TEXTO_POST: String = T + "VITO_POST"
const TEXTO_MOCHILA_LLENA: String = "MOCHILA_LLENA_REGALO"

## ============================================================================
## INTERRUPTORES
## ============================================================================

const FUENTE_ATLAS: int = 0
## gTileset_MossdeepGym: metatile 0x200 + n -> celda (n % 8, 52 + n / 8) de interior_edificios_2.
const METATILE_BASE: int = 0x200
const FILA_BASE: int = 52
const NUMERO_INTERRUPTORES: int = 4
## FLAG_MOSSDEEP_GYM_SWITCH_n (persistentes).
const PLANTILLA_BANDERA_INTERRUPTOR: String = "algaria_gimnasio_interruptor_%d"
## METATILE_MossdeepGym_Switch_Up / Switch_Down.
const METATILE_PALANCA_ARRIBA: int = 0x238
const METATILE_PALANCA_ABAJO: int = 0x239
## METATILE_MossdeepGym_RedArrow_*.
const FLECHA_DERECHA: int = 0x204
const FLECHA_ABAJO: int = 0x205
const FLECHA_IZQUIERDA: int = 0x20C
const FLECHA_ARRIBA: int = 0x20D
## Palanca n (índice n-1): bg_events Switch1..4.
const PALANCAS: Array[Vector2i] = [Vector2i(2, 7), Vector2i(8, 10), Vector2i(17, 15), Vector2i(5, 24)]
## Flecha que cambia cada palanca y su metatile apagada (el de map.bin) / encendida
## (SetSwitchNMetatiles).
const FLECHAS: Array[Vector2i] = [Vector2i(5, 5), Vector2i(8, 14), Vector2i(15, 17), Vector2i(1, 23)]
## Flechas que se ven en la capa Puente, no en Suelo: la del interruptor 2.
const FLECHAS_EN_PUENTE: Array[Vector2i] = [Vector2i(8, 14)]
const FLECHA_APAGADA: Array[int] = [FLECHA_IZQUIERDA, FLECHA_ABAJO, FLECHA_DERECHA, FLECHA_DERECHA]
const FLECHA_ENCENDIDA: Array[int] = [FLECHA_DERECHA, FLECHA_DERECHA, FLECHA_IZQUIERDA, FLECHA_ARRIBA]
## Dirección que empuja cada metatile de flecha (MB_WALK_EAST/SOUTH/WEST/NORTH).
const DIRECCION_FLECHA: Dictionary = {
	FLECHA_DERECHA: Vector2.RIGHT, FLECHA_ABAJO: Vector2.DOWN,
	FLECHA_IZQUIERDA: Vector2.LEFT, FLECHA_ARRIBA: Vector2.UP,
}
## `MossdeepCity_Gym_Movement_WaitAfterSwitchUse`: delay_16, delay_16.
const ESPERA_INTERRUPTOR: int = 32
## SE_CLICK (`MossdeepCity_Gym_EventScript_DrawMapAfterSwitchUsed`).
const SONIDO_INTERRUPTOR: String = "SE_CLICK"

@export var vito: NodePath = ^"../../NPCs/Vito"
@export var leti: NodePath = ^"../../NPCs/Leti"
@export var suelo: NodePath = ^"../../Suelo"
## Capa sobre el suelo (z_index 10) que dibuja las flechas de FLECHAS_EN_PUENTE.
@export var puente: NodePath = ^"../../Puente"
@export var datos_tiles: NodePath = ^"../../TPTileDataMap"
## Banderas de la capa 1 (Puente): empuje de las flechas de FLECHAS_EN_PUENTE.
@export var datos_puente: NodePath = ^"../../DataPuente"
## Los cuatro interruptores, en orden Switch1..4 (CartelEvento).
@export var interruptores: Array[NodePath] = [
	^"../../Carteles/Interruptor1", ^"../../Carteles/Interruptor2",
	^"../../Carteles/Interruptor3", ^"../../Carteles/Interruptor4",
]

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null
## Se anula en tests (`con_esperas = false`).
var con_esperas: bool = true


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for ruta: NodePath in [vito, leti]:
		var lider := get_node_or_null(ruta)
		if lider != null and lider.has_signal("hablado"):
			lider.hablado.connect(_on_lideres)
	for indice in interruptores.size():
		var cartel := get_node_or_null(interruptores[indice])
		if cartel is CartelEvento:
			cartel.accionado.connect(_on_interruptor.bind(indice + 1))
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(func(_por_warp: bool) -> void: sincronizar_interruptores())
	sincronizar_interruptores()


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


func esperar_fotogramas(fotogramas: int) -> void:
	if con_esperas:
		await super.esperar_fotogramas(fotogramas)


## Common_EventScript_SetGymTrainers (gimnasio 7): settrainerflag de los seis. Los NPC vivos
## dejan de ver al jugador al sincronizarse con la bandera.
static func marcar_entrenadores_vencidos() -> void:
	for id_npc in ENTRENADORES:
		SistemaGuardado.set_flag(id_npc + SUFIJO_COMBATE, true)


## ============================================================================
## VITO Y LETI
## ============================================================================

## MossdeepCity_Gym_EventScript_TateAndLiza (los dos objetos).
func _on_lideres(npc: Node2D) -> void:
	var administrador_npc: Node = npc.nodo_administrador if npc.nodo_administrador != null else _administrador()
	if _en_curso or not comenzar(administrador_npc):
		if not _en_curso and npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return
	var gemelos: Array = []
	for ruta: NodePath in [vito, leti]:
		var gemelo := get_node_or_null(ruta)
		if gemelo != null:
			gemelos.append(gemelo)
	for gemelo in gemelos:
		gemelo.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()
	if SistemaGuardado.tiene_medalla(INDICE_MEDALLA):
		await _tras_combate(gemelos)
		return
	# trainerbattle_double: sin dos POKéMON aptos solo se muestra TateAndLizaNeedTwoMons.
	if not puede_combate_doble():
		await mensaje(TEXTO_SIN_DOS_POKEMON)
		terminar(false, gemelos)
		return
	await mensaje(TEXTO_INTRO)
	var resultado := await combatir(ENTRENADOR_VITO_LETI, MUSICA_LIDER)
	if resultado != &"victoria":
		terminar(resultado == &"derrota_transferida", gemelos)
		return
	# MossdeepCity_Gym_EventScript_TateAndLizaDefeated.
	await mensaje_con_fanfarria(TEXTO_MEDALLA, FANFARRIA_MEDALLA)
	await mensaje(TEXTO_MEDALLA_INFO, false)
	EventoGimnasioPetalia.dar_medalla(INDICE_MEDALLA)  # FLAG_DEFEATED_MOSSDEEP_GYM + FLAG_BADGE07_GET
	marcar_entrenadores_vencidos()
	SistemaGuardado.set_flag(EventoHuidaSubmarino.BANDERA_TRABAJADORES, false)  # clearflag FLAG_HIDE_WORKERS_SLATEPORT_HARBOR
	await _dar_mt04(gemelos)


## HasEnoughMonsForDoubleBattle.
func puede_combate_doble() -> bool:
	return OverworldBattleManager.jugador_puede_combate_doble(SistemaGuardado.get_equipo())


## Después del combate: la MT04 pendiente o el comentario final.
func _tras_combate(gemelos: Array) -> void:
	if not SistemaGuardado.get_flag(BANDERA_MT04):
		await _dar_mt04(gemelos)
		return
	await mensaje(TEXTO_POST)
	terminar(false, gemelos)


## MossdeepCity_Gym_EventScript_GiveCalmMind2: la bandera solo se pone si se entregó.
func _dar_mt04(gemelos: Array) -> void:
	if not await dar_objeto(gemelos[0], OBJETO_MT04):
		await mensaje(TEXTO_MOCHILA_LLENA)  # Common_EventScript_ShowBagIsFull
		terminar(false, gemelos)
		return
	await mensaje(TEXTO_MT04)
	SistemaGuardado.set_flag(BANDERA_MT04, true)
	terminar(false, gemelos)


## ============================================================================
## INTERRUPTORES (setmetatile)
## ============================================================================

## Celda del atlas de `gTileset_MossdeepGym` de un metatile de Rubí.
static func atlas_de_metatile(metatile: int) -> Vector2i:
	var indice := metatile - METATILE_BASE
	return Vector2i(indice % 8, FILA_BASE + indice / 8)


## Metatile de Rubí que hay dibujado en la celda, o -1 si no es del tileset del gimnasio.
func metatile_en_celda(celda: Vector2i) -> int:
	var capa := _capa_de_flecha(celda)
	if capa == null:
		return -1
	var atlas := capa.get_cell_atlas_coords(celda)
	if atlas.x < 0 or atlas.y < FILA_BASE:
		return -1
	return METATILE_BASE + (atlas.y - FILA_BASE) * 8 + atlas.x


## Capa en la que se pinta la flecha de la celda.
func _capa_de_flecha(celda: Vector2i) -> TileMapLayer:
	return get_node_or_null(puente if FLECHAS_EN_PUENTE.has(celda) else suelo) as TileMapLayer


func interruptor_activo(numero: int) -> bool:
	return SistemaGuardado.get_flag(PLANTILLA_BANDERA_INTERRUPTOR % numero)


## MossdeepCity_Gym_OnLoad: repinta los cuatro pares palanca/flecha según FLAG_MOSSDEEP_GYM_SWITCH_n.
func sincronizar_interruptores() -> void:
	for numero in range(1, NUMERO_INTERRUPTORES + 1):
		_aplicar_interruptor(numero, interruptor_activo(numero))


func _on_interruptor(_cartel: CartelEvento, numero: int) -> void:
	await accionar_interruptor(numero)


## MossdeepCity_Gym_EventScript_Switch1..4 (y ClearSwitch1..4).
func accionar_interruptor(numero: int) -> void:
	if numero < 1 or numero > NUMERO_INTERRUPTORES or _en_curso or not comenzar(_administrador()):
		return
	var activo := not interruptor_activo(numero)
	SistemaGuardado.set_flag(PLANTILLA_BANDERA_INTERRUPTOR % numero, activo)
	await esperar_fotogramas(ESPERA_INTERRUPTOR)
	_aplicar_interruptor(numero, activo)
	Singleton.play_sound.emit(SONIDO_INTERRUPTOR)
	terminar()


## setmetatile de la palanca y de la flecha (metatile + banderas de empuje). El TileMapLayer
## redibuja solo (DrawWholeMapView); las celdas conservan su BLOQUEO de map.bin.
func _aplicar_interruptor(numero: int, activo: bool) -> void:
	var indice := numero - 1
	var capa := get_node_or_null(suelo) as TileMapLayer
	var flecha: int = FLECHA_ENCENDIDA[indice] if activo else FLECHA_APAGADA[indice]
	if capa != null:
		capa.set_cell(PALANCAS[indice], FUENTE_ATLAS,
				atlas_de_metatile(METATILE_PALANCA_ABAJO if activo else METATILE_PALANCA_ARRIBA))
	var capa_flecha := _capa_de_flecha(FLECHAS[indice])
	if capa_flecha != null:
		capa_flecha.set_cell(FLECHAS[indice], FUENTE_ATLAS, atlas_de_metatile(flecha))
	var en_puente := FLECHAS_EN_PUENTE.has(FLECHAS[indice])
	var datos := get_node_or_null(datos_puente if en_puente else datos_tiles) as TPTileDataMap
	# La flecha del puente es deslizante: solo cambia de dirección.
	SueloForzado.fijar_cinta(datos, FLECHAS[indice], DIRECCION_FLECHA[flecha], en_puente)

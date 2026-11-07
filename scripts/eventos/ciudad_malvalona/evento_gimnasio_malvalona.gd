## evento_gimnasio_malvalona.gd
## Guiones del GIMNASIO de CIUDAD MALVALONA (pokeruby data/maps/MauvilleCity_Gym).
##
## PUZLE: tres interruptores de suelo ((0,9), (8,11), (4,15)). Pisar uno distinto del
## último alterna entre el estado A (el de map.bin) y el B (barreras alternas); pisar el
## mismo no hace nada. Cada alternancia cambia 22 celdas de `Encima` (corrientes y
## postes) y la colisión de 14 celdas en el mismo fotograma (MauvilleGymSpecial2), y
## dibuja el interruptor pisado (MauvilleGymSpecial1). El estado vive en
## HistoriaGimnasioMalvalona y se guarda con la partida, como en Rubí: cargar dentro
## del GIMNASIO lo conserva y solo se reinicia al entrar por warp desde otro mapa
## (MauvilleCity_OnTransition). Vencido ERICO se desactiva todo (estado D, MauvilleGymSpecial3): sin
## corrientes y con los tres interruptores pisados.
##
## ERICO (Wattson): combate de LÍDER al hablarle; la victoria da la MEDALLA DINAMO, marca
## a los cuatro entrenadores como vencidos, desactiva el puzle y entrega la MT34 (la
## bandera de la MT solo se pone si se entregó). Está en su GIMNASIO salvo entre la
## victoria sobre NORMAN y la MT24 de la ciudad (HistoriaGimnasioMalvalona.erico_en_gimnasio).
extends EventoInteriorMalvalona
class_name EventoGimnasioMalvalona

const MOTIVO_PAUSA: StringName = &"gimnasio_malvalona"

const SIN_TILE := Vector2i(-1, -1)
## Atlas de tileset_edificios (el tile (24,60)/(25,60) lleva z_index 10 en el tileset).
const ATLAS_INTERRUPTOR_LEVANTADO := Vector2i(21, 59)  # RaisedSwitch 0x205
const ATLAS_INTERRUPTOR_PISADO := Vector2i(22, 59)  # PressedSwitch 0x206
const ATLAS_CABEZA_POSTE := Vector2i(16, 61)
## Celdas de los tres interruptores (VAR_0x8004 0, 1, 2 de MauvilleGymSpecial1).
const CELDAS_INTERRUPTOR: Array[Vector2i] = [Vector2i(0, 9), Vector2i(8, 11), Vector2i(4, 15)]
## Postes de base que bloquean en los tres estados (PoleBottom / 0x218).
const POSTES: Array[Vector2i] = [Vector2i(3, 8), Vector2i(3, 11), Vector2i(6, 11)]
## [celda, Encima en A, Encima en B, bloqueo en A, bloqueo en B] de las 25 celdas que
## MauvilleGymSpecial2 puede cambiar (calculadas sobre map.bin; ver el análisis §3.5).
## 22 cambian de dibujo y 14 de colisión; las cabezas de poste (3,10), (3,13) y (6,13)
## solo cambian de colisión.
const CELDAS: Array = [
	[Vector2i(4, 7), Vector2i(24, 60), SIN_TILE, false, false],
	[Vector2i(5, 7), Vector2i(25, 60), SIN_TILE, false, false],
	[Vector2i(3, 8), Vector2i(24, 58), SIN_TILE, true, true],
	[Vector2i(4, 8), Vector2i(24, 61), SIN_TILE, true, false],
	[Vector2i(5, 8), Vector2i(25, 61), SIN_TILE, true, false],
	[Vector2i(3, 9), Vector2i(24, 59), SIN_TILE, true, false],
	[Vector2i(1, 10), SIN_TILE, Vector2i(24, 60), false, false],
	[Vector2i(2, 10), SIN_TILE, Vector2i(25, 60), false, false],
	[Vector2i(3, 10), Vector2i(16, 61), Vector2i(16, 61), true, false],
	[Vector2i(4, 10), SIN_TILE, Vector2i(24, 60), false, false],
	[Vector2i(5, 10), SIN_TILE, Vector2i(25, 60), false, false],
	[Vector2i(1, 11), SIN_TILE, Vector2i(24, 61), false, true],
	[Vector2i(2, 11), SIN_TILE, Vector2i(25, 61), false, true],
	[Vector2i(3, 11), SIN_TILE, Vector2i(24, 58), true, true],
	[Vector2i(4, 11), SIN_TILE, Vector2i(24, 61), false, true],
	[Vector2i(5, 11), SIN_TILE, Vector2i(25, 61), false, true],
	[Vector2i(6, 11), Vector2i(24, 58), SIN_TILE, true, true],
	[Vector2i(3, 12), SIN_TILE, Vector2i(24, 59), false, true],
	[Vector2i(6, 12), Vector2i(24, 59), SIN_TILE, true, false],
	[Vector2i(3, 13), Vector2i(16, 61), Vector2i(16, 61), false, true],
	[Vector2i(4, 13), Vector2i(24, 60), SIN_TILE, false, false],
	[Vector2i(5, 13), Vector2i(25, 60), SIN_TILE, false, false],
	[Vector2i(6, 13), Vector2i(16, 61), Vector2i(16, 61), true, false],
	[Vector2i(4, 14), Vector2i(24, 61), SIN_TILE, true, false],
	[Vector2i(5, 14), Vector2i(25, 61), SIN_TILE, true, false],
]

const BLOQUEO: int = 1  # TPTileDataMap.Flags.BLOQUEO

const MUSICA_LIDER: String = "GYM_LEADER_BATTLE"
const FANFARRIA_MEDALLA: String = "OBTENIDA_MEDALLA"
const SONIDO_INTERRUPTOR: String = "SE_UNLOCK"
## TRAINER_WATTSON.
const ENTRENADOR_ERICO: int = 267
const OBJETO_MT34: String = "MT34"
## npc_id de los cuatro entrenadores (la bandera de victoria es npc_id + "_combate").
const ENTRENADORES: Array[String] = [
	"ciudad_malvalona_gimnasio_angel", "ciudad_malvalona_gimnasio_isma",
	"ciudad_malvalona_gimnasio_ben", "ciudad_malvalona_gimnasio_viviana",
]

const T := "CIUDAD_MALVALONA_GIMNASIO_"
const TEXTO_ERICO_INI: String = T + "ERICO_INI"
const TEXTO_MEDALLA_RECIBIDA: String = T + "MEDALLA_RECIBIDA"
const TEXTO_ERICO_MEDALLA: String = T + "ERICO_MEDALLA"
const TEXTO_ERICO_MT34: String = T + "ERICO_MT34"
const TEXTO_ERICO_POST: String = T + "ERICO_POST"
const TEXTO_ERICO_NUEVA_MALVALONA: String = T + "ERICO_NUEVA_MALVALONA"

@export var erico: NodePath = ^"../../NPCs/Erico"
@export var npcs: NodePath = ^"../../NPCs"
@export var suelo: NodePath = ^"../../Suelo"
@export var encima: NodePath = ^"../../Encima"
@export var datos_tiles: NodePath = ^"../../TPTileDataMap"


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)
	var npc_erico := nodo(erico)
	if npc_erico != null and npc_erico.has_signal("hablado"):
		npc_erico.hablado.connect(_on_erico)
	var contenedor := get_parent()
	if contenedor != null:
		for hijo in contenedor.get_children():
			if hijo is DisparadorEventoPorTiles:
				hijo.evento_activado.connect(_on_disparador)
	preparar()


## Al entrar por warp el puzle vuelve a A (MauvilleCity_OnTransition); al cargar la
## partida o volver de un menú se conserva. En ambos casos se redibuja (OnLoad).
func _on_mapa_activado(por_warp: bool) -> void:
	if por_warp:
		HistoriaGimnasioMalvalona.entrar()
	preparar()


## OnLoad: dibuja el estado del puzle y coloca a ERICO.
func preparar() -> void:
	dibujar_estado()
	var npc_erico := nodo(erico)
	if npc_erico != null:
		npc_erico.visible = HistoriaGimnasioMalvalona.erico_en_gimnasio()


## ============================================================================
## PUZLE
## ============================================================================

## Disparador `interruptor_N` (coord_event de Switch1/2/3).
func _on_disparador(id_evento: StringName) -> void:
	var texto := String(id_evento)
	if not texto.begins_with("interruptor_") or _en_curso:
		return
	pisar_interruptor(int(texto.trim_prefix("interruptor_")))


## PressFloorSwitch. Devuelve true si cambió algo.
func pisar_interruptor(n: int) -> bool:
	if not HistoriaGimnasioMalvalona.pisar(n):
		return false
	dibujar_estado()
	Singleton.play_sound.emit(SONIDO_INTERRUPTOR)
	return true


## Estado que se dibuja: A, B o D (puzle desactivado).
enum Estado { A, B, D }


func estado() -> Estado:
	if HistoriaGimnasioMalvalona.desactivado():
		return Estado.D
	return Estado.B if HistoriaGimnasioMalvalona.barreras() else Estado.A


## Atlas de `Encima` de la celda `fila` (de CELDAS) en el estado dado.
static func atlas_encima(fila: Array, estado_puzle: Estado) -> Vector2i:
	match estado_puzle:
		Estado.A:
			return fila[1]
		Estado.B:
			return fila[2]
	# D: sin corrientes; las cabezas de poste se quedan.
	return ATLAS_CABEZA_POSTE if fila[1] == ATLAS_CABEZA_POSTE else SIN_TILE


## ¿Bloquea la celda `fila` en el estado dado? En D solo los postes de base.
static func bloquea(fila: Array, estado_puzle: Estado) -> bool:
	match estado_puzle:
		Estado.A:
			return fila[3]
		Estado.B:
			return fila[4]
	return POSTES.has(fila[0])


## MauvilleGymSpecial2 / 1 / 3 de una vez: las 25 celdas (Encima y colisión) y los tres
## interruptores en el mismo fotograma.
func dibujar_estado() -> void:
	var capa_encima := get_node_or_null(encima) as TileMapLayer
	var capa_suelo := get_node_or_null(suelo) as TileMapLayer
	var colisiones := get_node_or_null(datos_tiles)
	var actual := estado()
	for fila: Array in CELDAS:
		var celda: Vector2i = fila[0]
		var atlas := atlas_encima(fila, actual)
		if capa_encima != null:
			if atlas == SIN_TILE:
				capa_encima.erase_cell(celda)
			else:
				capa_encima.set_cell(celda, 0, atlas)
		if colisiones != null:
			if bloquea(fila, actual):
				colisiones.set_flag(Vector2(celda), BLOQUEO)
			else:
				colisiones.clear_flag(Vector2(celda), BLOQUEO)
	if capa_suelo == null:
		return
	for i in CELDAS_INTERRUPTOR.size():
		var pisado := actual == Estado.D or HistoriaGimnasioMalvalona.interruptor() == i + 1
		capa_suelo.set_cell(CELDAS_INTERRUPTOR[i], 0, ATLAS_INTERRUPTOR_PISADO if pisado else ATLAS_INTERRUPTOR_LEVANTADO)


## Marca a los cuatro entrenadores como vencidos (settrainerflag; Common_EventScript_SetGymTrainers).
## Los NPC vivos dejan de ver al jugador al sincronizarse con la bandera.
static func marcar_entrenadores_vencidos() -> void:
	for id_npc in ENTRENADORES:
		SistemaGuardado.set_flag(id_npc + "_combate", true)


## ============================================================================
## ERICO
## ============================================================================

## MauvilleCity_Gym_EventScript_Wattson (lock + faceplayer).
func _on_erico(npc: Node2D) -> void:
	if not empezar_con(npc):
		return
	if HistoriaGimnasioMalvalona.desactivado():
		await _tras_combate(npc)
		return
	await mensaje(TEXTO_ERICO_INI)
	var resultado := await combatir(ENTRENADOR_ERICO, MUSICA_LIDER)
	if resultado != &"victoria":
		terminar(resultado == &"derrota_transferida", [npc])
		return
	await mensaje_con_fanfarria(TEXTO_MEDALLA_RECIBIDA, FANFARRIA_MEDALLA)  # WattsonDefeated
	await mensaje(TEXTO_ERICO_MEDALLA, false)
	EventoGimnasioPetalia.dar_medalla(HistoriaGimnasioMalvalona.INDICE_MEDALLA)  # FLAG_BADGE03_GET
	marcar_entrenadores_vencidos()
	dibujar_estado()  # MauvilleGymSpecial3
	Singleton.play_sound.emit(SONIDO_INTERRUPTOR)
	await _dar_mt34(npc)


## Tras vencerle: la MT34 pendiente, la despedida de MALVALANOVA o el comentario normal.
func _tras_combate(npc: Node2D) -> void:
	if not SistemaGuardado.get_flag(HistoriaMalvalona.BANDERA_MT34):
		await _dar_mt34(npc)
		return
	if SistemaGuardado.get_flag(HistoriaMalvalona.BANDERA_NUEVA_MALVALONA):
		await mensaje(TEXTO_ERICO_NUEVA_MALVALONA)  # CompletedNewMauville
	else:
		await mensaje(TEXTO_ERICO_POST)
	terminar(false, [npc])


## GiveShockWave: la bandera solo se pone si la MT se entregó.
func _dar_mt34(npc: Node2D) -> void:
	if not await dar_objeto(npc, OBJETO_MT34):
		await mensaje_mochila_llena()
		terminar(false, [npc])
		return
	await mensaje(TEXTO_ERICO_MT34)
	SistemaGuardado.set_flag(HistoriaMalvalona.BANDERA_MT34, true)
	terminar(false, [npc])

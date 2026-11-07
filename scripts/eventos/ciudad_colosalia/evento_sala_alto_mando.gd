## evento_sala_alto_mando.gd
## Salas del ALTO MANDO de la LIGA POKéMON de CIUDAD COLOSALIA (pokeruby EverGrandeCity_SidneysRoom,
## _PhoebesRoom, _GlaciasRoom y _DrakesRoom + data/scripts/elite_four.inc). Un mismo guion para las
## cuatro: cada sala exporta su miembro, su entrenador, su bandera FLAG_DEFEATED_ELITE_4_* y el valor de
## VAR_ELITE_4_STATE (`colosalia_alto_mando_estado`) con el que se entra (SIXTO 0 … DRACÓN 3).
##
## - OnFrame con el estado en `estado_entrada` (PokemonLeague_EliteFour_EventScript_WalkInCloseDoor): el
##   jugador mira al norte (OnWarp), sube seis casillas, suena SE_TRUCK_DOOR y la puerta de entrada se
##   cierra (setmetatile 0x206/0x20E con colisión en (5..7, 12..13)); el estado avanza.
## - OnLoad: con el estado ya superado la puerta está cerrada; vencido el miembro, abierta la del norte.
## - Al hablarle (sin vencer): playbgm MUS_ENCOUNTER_ELITE_FOUR, presentación y trainerbattle_no_intro.
##   Al ganar: FLAG_DEFEATED_ELITE_4_*, delay 32, SE_DOOR, la puerta norte se abre (0x344/0x345, el
##   Warp a su celda queda libre) y los focos se apagan (0x2DD/0x2DE); después, su discurso.
## - Perder (derrota con traslado al punto de curación) llama a EventScript_WhiteOut: se reinicia el
##   ALTO MANDO (EverGrandeCity_HallOfFame_EventScript_ResetEliteFour) y hay que empezar desde SIXTO.
##
## Si la sala tiene la capa `SigCerrado` (`siguiente_cerrado`), abrir la puerta y apagar los focos es solo
## ocultarla; el BLOQUEO de las celdas lo sigue llevando el TPTileDataMap.
##
## Los tiles van en dos capas (Suelo y Superior) con el atlas de herramientas/importar_interiores_colosalia.py:
## el metatile secundario 0x200 + n está en (n % 8, n / 8) abajo y en (8 + n % 8, n / 8) arriba. Las
## animaciones de gTileset_EliteFour no se migran.
extends EventoInteriorMalvalona
class_name EventoSalaAltoMando

const MOTIVO_PAUSA: StringName = &"sala_alto_mando"

## VAR_ELITE_4_STATE.
const CONTADOR_ESTADO: String = "colosalia_alto_mando_estado"
## FLAG_DEFEATED_ELITE_4_SYDNEY, _PHOEBE, _GLACIA y _DRAKE.
const BANDERAS_VENCIDOS: Array[String] = [
	"colosalia_sixto_vencido", "colosalia_fatima_vencida", "colosalia_nivea_vencida", "colosalia_dracon_vencido",
]
const MUSICA_ENCUENTRO: String = "ENCUENTRO_ALTO_MANDO"
const SONIDO_CIERRE: String = "SE_TRUCK_DOOR"
const SONIDO_PUERTA: String = "puerta_entrada"  # SE_DOOR
## Common_Movement_WalkUp6.
const PASOS_ENTRADA: int = 6
## Common_Movement_Delay32 de PokemonLeague_EliteFour_SetAdvanceToNextRoomMetatiles.
const FOTOGRAMAS_ANTES_DE_ABRIR: int = 32

## include/constants/metatile_labels.h (gTileset_EliteFour).
const METATILE_PUERTA_ENTRADA_ABAJO: int = 0x20E
const METATILE_PUERTA_ENTRADA_ARRIBA: int = 0x206
const METATILE_FOCO_IZQUIERDO_APAGADO: int = 0x2DD
const METATILE_FOCO_DERECHO_APAGADO: int = 0x2DE
const METATILE_PUERTA_MARCO: int = 0x344
const METATILE_PUERTA_ABIERTA: int = 0x345
const FUENTE_ATLAS: int = 0
const COLUMNAS_ATLAS: int = 8

## Puerta de entrada (5..7, 12..13) y puerta norte (6,1)/(6,2).
const PUERTA_ENTRADA_ARRIBA: Array[Vector2i] = [Vector2i(5, 12), Vector2i(6, 12), Vector2i(7, 12)]
const PUERTA_ENTRADA_ABAJO: Array[Vector2i] = [Vector2i(5, 13), Vector2i(6, 13), Vector2i(7, 13)]
const CELDA_MARCO: Vector2i = Vector2i(6, 1)
const CELDA_PUERTA_NORTE: Vector2i = Vector2i(6, 2)
## Focos de la fila 2: RightSpotlightOff en 0, 2, 4, 9, 11; LeftSpotlightOff en 1, 3, 8, 10, 12.
const FOCOS_DERECHOS: Array[int] = [0, 2, 4, 9, 11]
const FOCOS_IZQUIERDOS: Array[int] = [1, 3, 8, 10, 12]
const FILA_FOCOS: int = 2
## Autotile animado (capa `Superior`) de los focos encendidos.
const ATLAS_FOCO_ENCENDIDO: Vector2i = Vector2i(1, 42)

@export var miembro: NodePath
## TRAINER_SIDNEY (261), _PHOEBE (262), _GLACIA (263), _DRAKE (264).
@export var entrenador_id: int = 0
@export var bandera_vencido: String = ""
## VAR_ELITE_4_STATE al entrar en esta sala.
@export var estado_entrada: int = 0
@export var texto_intro: String = ""
@export var texto_post: String = ""
@export var suelo: NodePath
@export var superior: NodePath
@export var datos_tiles: NodePath
## Capa opcional con la puerta norte cerrada y los focos encendidos (autotile) por encima de `Suelo`, que ya
## los trae abiertos y apagados. Al vencer al miembro se oculta; sin ella se pintan los metatiles de la ROM.
@export var siguiente_cerrado: NodePath

## Celdas tocadas por setmetatile con su estado original: celda -> [abajo, arriba, banderas].
var _originales: Dictionary = {}


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_guardar_originales()
	escuchar(miembro, _on_miembro)
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)
	aplicar_estado()


## EverGrandeCity_HallOfFame_EventScript_ResetEliteFour (también al perder: EventScript_WhiteOut).
static func reiniciar_alto_mando() -> void:
	for bandera in BANDERAS_VENCIDOS:
		SistemaGuardado.set_flag(bandera, false)
	SistemaGuardado.set_contador(CONTADOR_ESTADO, 0)


func vencido() -> bool:
	return SistemaGuardado.get_flag(bandera_vencido)


func _on_mapa_activado(_por_warp: bool) -> void:
	aplicar_estado()
	if SistemaGuardado.get_contador(CONTADOR_ESTADO) == estado_entrada and not vencido():
		await entrar()


## OnLoad: las salas se reutilizan, así que también se deshacen los setmetatile de una visita anterior.
func aplicar_estado() -> void:
	_restaurar_originales()
	var capa_cerrada := get_node_or_null(siguiente_cerrado) as TileMapLayer
	if capa_cerrada != null:
		capa_cerrada.visible = true
	if SistemaGuardado.get_contador(CONTADOR_ESTADO) > estado_entrada or vencido():
		cerrar_puerta_entrada()
	if vencido():
		abrir_paso()


## OnFrame: PokemonLeague_EliteFour_EventScript_WalkInCloseDoor.
func entrar() -> void:
	if not comenzar(_administrador()):
		return
	await esperar_fin_warp(admin)
	girar_jugador(U)  # OnWarp: turnobject LOCALID_PLAYER, DIR_NORTH
	var pasos: Array = []
	for i in PASOS_ENTRADA:
		pasos.append(U)
	await recorrer_jugador(pasos)
	Singleton.play_sound.emit(SONIDO_CIERRE)
	cerrar_puerta_entrada()
	SistemaGuardado.set_contador(CONTADOR_ESTADO, estado_entrada + 1)
	terminar()


## EverGrandeCity_*Room_EventScript_<miembro>.
func _on_miembro(npc: Node2D) -> void:
	if not empezar_con(npc):
		return
	if vencido():
		await mensaje(texto_post)
		terminar(false, [npc])
		return
	reproducir_musica(MUSICA_ENCUENTRO)
	await mensaje(texto_intro)
	var resultado := await combatir(entrenador_id)
	if resultado != &"victoria":
		if resultado == &"derrota_transferida":
			reiniciar_alto_mando()
		terminar(resultado == &"derrota_transferida", [npc])
		return
	SistemaGuardado.set_flag(bandera_vencido, true)
	await esperar_fotogramas(FOTOGRAMAS_ANTES_DE_ABRIR)
	Singleton.play_sound.emit(SONIDO_PUERTA)
	abrir_paso()
	await mensaje(texto_post)
	terminar(false, [npc])


## PokemonLeague_EliteFour_EventScript_CloseDoor.
func cerrar_puerta_entrada() -> void:
	for celda in PUERTA_ENTRADA_ARRIBA:
		poner_metatile(celda, METATILE_PUERTA_ENTRADA_ARRIBA, true)
	for celda in PUERTA_ENTRADA_ABAJO:
		poner_metatile(celda, METATILE_PUERTA_ENTRADA_ABAJO, true)


## PokemonLeague_EliteFour_SetAdvanceToNextRoomMetatiles (sin el delay ni el sonido).
func abrir_paso() -> void:
	var capa_cerrada := get_node_or_null(siguiente_cerrado) as TileMapLayer
	if capa_cerrada != null:
		# `Suelo` ya trae la puerta abierta y los focos apagados: basta con descubrirlos.
		capa_cerrada.visible = false
		var tp := get_node_or_null(datos_tiles) as TPTileDataMap
		if tp != null:
			tp.clear_flag(Vector2(CELDA_MARCO), TPTileDataMap.Flags.BLOQUEO)
			tp.clear_flag(Vector2(CELDA_PUERTA_NORTE), TPTileDataMap.Flags.BLOQUEO)
			for x in FOCOS_DERECHOS + FOCOS_IZQUIERDOS:
				tp.set_flag(Vector2(x, FILA_FOCOS), TPTileDataMap.Flags.BLOQUEO)
		return
	poner_metatile(CELDA_MARCO, METATILE_PUERTA_MARCO, false)
	poner_metatile(CELDA_PUERTA_NORTE, METATILE_PUERTA_ABIERTA, false)
	for x in FOCOS_DERECHOS:
		apagar_foco(Vector2i(x, FILA_FOCOS), METATILE_FOCO_DERECHO_APAGADO)
	for x in FOCOS_IZQUIERDOS:
		apagar_foco(Vector2i(x, FILA_FOCOS), METATILE_FOCO_IZQUIERDO_APAGADO)


## Los focos encendidos son un autotile animado en `Superior`: apagarlos es quitarlo y dejar la celda
## bloqueada. Si la sala aún tiene el metatile estático, se aplica el setmetatile original.
func apagar_foco(celda: Vector2i, metatile_apagado: int) -> void:
	var capa_superior := get_node_or_null(superior) as TileMapLayer
	if capa_superior == null or capa_superior.get_cell_atlas_coords(celda) != ATLAS_FOCO_ENCENDIDO:
		poner_metatile(celda, metatile_apagado, true)
		return
	capa_superior.erase_cell(celda)
	var tp := get_node_or_null(datos_tiles) as TPTileDataMap
	if tp != null:
		tp.set_flag(Vector2(celda), TPTileDataMap.Flags.BLOQUEO)


## setmetatile x, y, metatile, impassable: las dos capas y el BLOQUEO de la celda.
func poner_metatile(celda: Vector2i, metatile: int, bloqueo: bool) -> void:
	EventoSalaAltoMando.pintar_metatile(get_node_or_null(suelo) as TileMapLayer, get_node_or_null(superior) as TileMapLayer,
			get_node_or_null(datos_tiles) as TPTileDataMap, celda, metatile, bloqueo)


## setmetatile sobre las capas de un atlas de importar_interiores_colosalia.py (metatile secundario).
static func pintar_metatile(capa_suelo: TileMapLayer, capa_superior: TileMapLayer, tp: TPTileDataMap,
		celda: Vector2i, metatile: int, bloqueo: bool) -> void:
	var n := metatile - 0x200
	var abajo := Vector2i(n % COLUMNAS_ATLAS, n / COLUMNAS_ATLAS)
	_pintar(capa_suelo, celda, abajo)
	_pintar(capa_superior, celda, abajo + Vector2i(COLUMNAS_ATLAS, 0))
	if tp == null:
		return
	if bloqueo:
		tp.set_flag(Vector2(celda), TPTileDataMap.Flags.BLOQUEO)
	else:
		tp.clear_flag(Vector2(celda), TPTileDataMap.Flags.BLOQUEO)


static func _pintar(capa: TileMapLayer, celda: Vector2i, atlas: Vector2i) -> void:
	if capa == null:
		return
	var fuente := capa.tile_set.get_source(FUENTE_ATLAS) as TileSetAtlasSource if capa.tile_set != null else null
	if fuente != null and fuente.has_tile(atlas):
		capa.set_cell(celda, FUENTE_ATLAS, atlas)
	else:
		capa.erase_cell(celda)


func _celdas_modificables() -> Array[Vector2i]:
	var celdas: Array[Vector2i] = [CELDA_MARCO, CELDA_PUERTA_NORTE]
	celdas.append_array(PUERTA_ENTRADA_ARRIBA)
	celdas.append_array(PUERTA_ENTRADA_ABAJO)
	for x in FOCOS_DERECHOS + FOCOS_IZQUIERDOS:
		celdas.append(Vector2i(x, FILA_FOCOS))
	return celdas


func _guardar_originales() -> void:
	var capa_suelo := get_node_or_null(suelo) as TileMapLayer
	var capa_superior := get_node_or_null(superior) as TileMapLayer
	var tp := get_node_or_null(datos_tiles) as TPTileDataMap
	for celda in _celdas_modificables():
		_originales[celda] = [
			capa_suelo.get_cell_atlas_coords(celda) if capa_suelo != null else Vector2i(-1, -1),
			capa_superior.get_cell_atlas_coords(celda) if capa_superior != null else Vector2i(-1, -1),
			tp.get_flags(Vector2(celda)) if tp != null else 0,
		]


func _restaurar_originales() -> void:
	var capa_suelo := get_node_or_null(suelo) as TileMapLayer
	var capa_superior := get_node_or_null(superior) as TileMapLayer
	var tp := get_node_or_null(datos_tiles) as TPTileDataMap
	for celda: Vector2i in _originales:
		var original: Array = _originales[celda]
		_restaurar_celda(capa_suelo, celda, original[0])
		_restaurar_celda(capa_superior, celda, original[1])
		if tp != null:
			if int(original[2]) & TPTileDataMap.Flags.BLOQUEO:
				tp.set_flag(Vector2(celda), TPTileDataMap.Flags.BLOQUEO)
			else:
				tp.clear_flag(Vector2(celda), TPTileDataMap.Flags.BLOQUEO)


static func _restaurar_celda(capa: TileMapLayer, celda: Vector2i, atlas: Vector2i) -> void:
	if capa == null:
		return
	if atlas == Vector2i(-1, -1):
		capa.erase_cell(celda)
	else:
		capa.set_cell(celda, FUENTE_ATLAS, atlas)

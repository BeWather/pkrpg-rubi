class_name HieloFinoMapa
extends SueloAgrietadoMapa

## Hielo fino del GIMNASIO de ARRECÍPOLIS 1F (pokeruby PerStepCallback_8069DD4 de
## src/field_tasks.c y SootopolisCity_Gym_1F_OnFrame). Las celdas de hielo llevan la
## bandera SUELO_AGRIETADO:
##   - pisar hielo intacto (MB_THIN_ICE): VAR_ICE_STEP_COUNT + 1 y, 4 frames después,
##     SE_ICE_CRACK y el tile pasa a agrietado (METATILE_SootopolisGym_Ice_Cracked);
##   - pisar hielo agrietado (MB_CRACKED_ICE): VAR_ICE_STEP_COUNT = 0, 4 frames después
##     SE_ICE_BREAK y el tile pasa a roto (Ice_Broken); al terminar el paso el jugador
##     cae a `mapa_inferior` en la misma celda (FallThroughIce, warphole);
##   - cuando el contador llega a 8, 28 y 69 (un umbral por sala) suma 1, espera 40
##     frames, suena SE_ICE_STAIRS y se abre un tramo de escalera: las rampas que
##     devolvían al jugador al sur (MB_SLIDE_SOUTH) pasan a METATILE_SootopolisGym_Stairs.
## El contador empieza en 1 (OnTransition) y todo vuelve al estado inicial cada vez que
## el mapa deja de ser el actual, como en Rubí (las grietas son VAR_TEMP).

signal tramo_abierto(indice: int)

const SONIDO_GRIETA := "SE_ICE_CRACK"
const SONIDO_ROTURA := "SE_ICE_BREAK"
const SONIDO_ESCALERA := "SE_ICE_STAIRS"
## VAR_ICE_STEP_COUNT tras SootopolisCity_Gym_1F_OnTransition.
const CONTADOR_INICIAL: int = 1
const MASCARA_RAMPA: int = TPTileDataMap.Flags.EMPUJE_ABAJO | TPTileDataMap.Flags.EMPUJE_DESLIZANTE

## Valores del contador que abren cada tramo (map_script_2 de OnFrame).
@export var umbrales: Array[int] = [8, 28, 69]
## Celdas de cada tramo, de dos en dos y en el orden de `umbrales`
## (CheckSetStairMetatiles: (8,15)-(8,16), (8,10)-(8,11), (8,4)-(8,5)).
@export var celdas_escalera: Array[Vector2i] = [
	Vector2i(8, 15), Vector2i(8, 16), Vector2i(8, 10), Vector2i(8, 11), Vector2i(8, 4), Vector2i(8, 5),
]
@export var atlas_escalera: Vector2i = Vector2i(7, 0)
## Frames entre el paso y el cambio de tile (data[6] = 4).
@export var frames_grieta: int = 4
## `delay 40` de SootopolisCity_Gym_1F_EventScript_Unlock*Stairs.
@export var frames_escalera: int = 40

var contador: int = CONTADOR_INICIAL
## Celda -> atlas del hielo intacto, para las celdas ya agrietadas o rotas.
var _originales: Dictionary = {}
## Celda -> atlas de la rampa, para los tramos abiertos.
var _rampas: Dictionary = {}
var _tramos_abiertos: int = 0
var _tweens: Array[Tween] = []


func procesar_paso(tp: TPTileDataMap, destino: Vector2i) -> bool:
	if tp == null or _rotas.has(destino):
		return false
	if _originales.has(destino):
		# MetatileBehavior_IsCrackedIce: se rompe y el jugador cae al acabar el paso.
		contador = 0
		_rotas[destino] = true
		_programar(frames_grieta, _cambiar_tile.bind(destino, atlas_agujero, SONIDO_ROTURA))
		return true
	if not tp.has_flag(Vector2(destino), TPTileDataMap.Flags.SUELO_AGRIETADO):
		return false
	var capa := _capa()
	if capa == null:
		return false
	_originales[destino] = capa.get_cell_atlas_coords(destino)
	contador += 1
	_programar(frames_grieta, _cambiar_tile.bind(destino, atlas_agrietado, SONIDO_GRIETA))
	var tramo := umbrales.find(contador)
	if tramo != -1:
		contador += 1  # addvar VAR_ICE_STEP_COUNT, 1
		_programar(frames_grieta + frames_escalera, abrir_tramo.bind(tramo, true))
	return false


func esta_agrietada(celda: Vector2i) -> bool:
	return _originales.has(celda) and not _rotas.has(celda)


func tramos_abiertos() -> int:
	return _tramos_abiertos


## Abre el tramo `indice` de escalera (y los anteriores, como CheckSetStairMetatiles).
func abrir_tramo(indice: int, con_sonido: bool = false) -> void:
	if indice < _tramos_abiertos:
		return
	if con_sonido and is_inside_tree():
		Singleton.play_sound.emit(SONIDO_ESCALERA)
	var capa := _capa()
	var tp := _tp()
	for i in range(_tramos_abiertos, indice + 1):
		for j in range(i * 2, mini(i * 2 + 2, celdas_escalera.size())):
			var celda := celdas_escalera[j]
			if capa != null:
				_rampas[celda] = capa.get_cell_atlas_coords(celda)
				capa.set_cell(celda, fuente_atlas, atlas_escalera)
			if tp != null:
				tp.clear_flag(Vector2(celda), MASCARA_RAMPA)
		tramo_abierto.emit(i)
	_tramos_abiertos = indice + 1


func restaurar_todo() -> void:
	for tween: Tween in _tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_tweens.clear()
	_roturas.clear()
	var capa := _capa()
	var tp := _tp()
	if capa != null:
		for celda: Vector2i in _originales:
			capa.set_cell(celda, fuente_atlas, _originales[celda])
	for celda: Vector2i in _rampas:
		if capa != null:
			capa.set_cell(celda, fuente_atlas, _rampas[celda])
		if tp != null:
			tp.set_flag(Vector2(celda), MASCARA_RAMPA)
	_originales.clear()
	_rampas.clear()
	_rotas.clear()
	_tramos_abiertos = 0
	contador = CONTADOR_INICIAL


func _programar(frames: int, llamada: Callable) -> void:
	if not is_inside_tree():
		llamada.call()
		return
	var tween := create_tween()
	tween.tween_interval(frames * SEGUNDOS_POR_FRAME)
	tween.tween_callback(llamada)
	_tweens.append(tween)


func _cambiar_tile(celda: Vector2i, atlas: Vector2i, sonido: String) -> void:
	if is_inside_tree():
		Singleton.play_sound.emit(sonido)
	var capa := _capa()
	if capa != null and _originales.has(celda):
		capa.set_cell(celda, fuente_atlas, atlas)


func _capa() -> TileMapLayer:
	var padre := get_parent()
	return padre.get_node_or_null(NodePath(nombre_capa)) as TileMapLayer if padre != null else null


func _tp() -> TPTileDataMap:
	var padre := get_parent()
	return padre.get_node_or_null(^"TPTileDataMap") as TPTileDataMap if padre != null else null

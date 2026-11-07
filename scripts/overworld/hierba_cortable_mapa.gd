class_name HierbaCortableMapa
extends Node

## CORTE sobre la hierba alta: rama de hierba de SetUpFieldMove_Cut,
## FldEff_UseCutOnGrass y FldEff_CutGrass de pokeruby (src/fldeff_cut.c).
##
## Reglas de Rubí que copia:
## - Cuadrado 3x3 CENTRADO EN LA CELDA DEL JUGADOR (PlayerGetDestCoords pisa la
##   celda frontal que dejó CheckObjectGraphicsInFrontOfPlayer), solo con celdas de
##   la misma elevación que el jugador: aquí, los datos de la capa activa.
## - Habilita CORTE (SetUpFieldMove_Cut) si alguna celda del cuadrado es hierba
##   alta o muy alta (MetatileBehavior_IsPokeGrass: TALL_GRASS y LONG_GRASS) o
##   ceniza (IsAshGrass); un árbol delante tiene prioridad. Aquí esas conductas son
##   las banderas HIERBA_ALTA, HIERBA_MAS_ALTA y HIERBA_CENIZA de TPTileDataMap.
## - FldEff_CutGrass corta toda celda cortable del cuadrado
##   (MetatileBehavior_IsCuttableGrass: las tres anteriores y LONG_GRASS_SOUTH_EDGE,
##   la raíz de la hierba muy alta, que aquí se reconoce por su tile) y sustituye
##   su metatile (SetCutGrassMetatile): hierba alta/muy alta -> General Grass,
##   ceniza -> campo de ceniza. SetCutGrassMetatiles recoloca las raíces: si la
##   fila de encima del cuadrado sigue siendo hierba muy alta, la celda cortada
##   bajo ella recibe la raíz; y si bajo la fila inferior había una raíz, se borra.
## - No hace falta ningún encuentro ni pregunta: solo se usa desde el menú del
##   Pokémon (el botón A frente a la hierba no hace nada).
##
## Los cambios son volátiles como los de MapGridSetMetatileIdAt: duran hasta que
## el mapa se vuelve a cargar, es decir, hasta `SistemaGuardado.limpiar_temporales()`
## (warps y cruce de bordes, ClearTempFieldEventData). Cada celda cortada se anota
## en el almacén de banderas temporales por mapa (`hierba_cortada:<mapa>:<x>,<y>`),
## que viaja en la partida como las FLAG_TEMP_* de Rubí; al cargarla, el componente
## vuelve a aplicar esas celdas (Rubí guarda el área visible con SaveMapView).
##
## Sustitución de tiles: cada TileSet declara en `TILESETS` su hierba corta, los
## tiles cortables y la raíz. Un tile con otro tile debajo en una capa inferior
## se borra (hierba como superposición sobre `Suelo`); si no hay nada debajo se
## cambia por la hierba corta del mismo tileset. Los tiles que no estén en la
## tabla no se tocan: una celda con bandera pero sin tile conocido no es cortable
## y avisa una vez para que se añada.
##
## Lo crea a demanda `MapaConfiguracion.obtener_hierba_cortable()`: no hay que
## añadir nodos a las escenas de los mapas.

const GRUPO := &"hierba_cortable"
const NOMBRE_NODO := "HierbaCortable"
const PREFIJO_CELDA := "hierba_cortada:"
const PREFIJO_RAIZ := "hierba_raiz:"
## IsPokeGrass (TALL_GRASS, LONG_GRASS) o IsAshGrass.
const MASCARA_HIERBA: int = TPTileDataMap.Flags.HIERBA_ALTA \
	| TPTileDataMap.Flags.HIERBA_MAS_ALTA \
	| TPTileDataMap.Flags.HIERBA_CENIZA
## Sonido de FldEff_CutGrass (SE_M_CUT), el mismo del árbol.
const RUTA_SONIDO: String = ControladorArbolCortable.RUTA_SONIDO

const RUTA_TILESET_INICIAL := "res://graficos/tilesets/tileset_inicial.tres"
const RUTA_TILESET_RUTA_01 := "res://escenas/ruta_01.tres"

## Por TileSet (ruta del recurso): Vector3i(fuente, atlas.x, atlas.y).
## - corta: General Grass, hierba sin altura.
## - cortables: TallGrass, LongGrass (cuerpo) y ceniza (con o sin limpiar).
## - larga: cuerpo de la hierba muy alta (LongGrass), el que necesita raíz.
## - raiz: LongGrass_Root (MB_LONG_GRASS_SOUTH_EDGE), sin bandera propia.
const TILESETS: Dictionary = {
	RUTA_TILESET_INICIAL: {
		"corta": Vector3i(0, 6, 7),
		"cortables": [
			Vector3i(0, 2, 16),	# hierba alta con fondo propio (Suelo)
			Vector3i(1, 0, 7),	# hierba alta, tile de naturaleza
			Vector3i(1, 1, 6),	# hierba muy alta
			Vector3i(1, 0, 5),	# hierba con ceniza (Ruta 113)
			Vector3i(0, 5, 26),	# hierba con ceniza, variante
			Vector3i(0, 2, 27),	# hierba con ceniza ya limpiada por el jugador
		],
		"larga": [Vector3i(1, 1, 6)],
		"raiz": [Vector3i(1, 1, 7)],
	},
	RUTA_TILESET_RUTA_01: {
		"corta": Vector3i(0, 19, 6),
		"cortables": [Vector3i(0, 12, 12)],
		"larga": [],
		"raiz": [],
	},
}

## Celda -> {"tiles": Array[Dictionary], "flags": int, "capa_datos": int}: lo
## necesario para que la hierba vuelva a crecer exactamente como estaba.
var cortadas: Dictionary = {}
## "x,y,capa" -> {"capa": String, "celda": Vector2i, "previo": Dictionary}: raíces
## colocadas por SetCutGrassMetatiles.
var raices: Dictionary = {}

var _mapa: MapaConfiguracion = null
var _avisadas: Dictionary = {}


func _enter_tree() -> void:
	add_to_group(GRUPO)
	_mapa = _buscar_mapa_padre()
	if not SistemaGuardado.temporales_limpiados.is_connected(regenerar):
		SistemaGuardado.temporales_limpiados.connect(regenerar)


func _ready() -> void:
	_aplicar_guardado()


# ──────────────────────────────────────────────────────────────────────────────
# REGLAS (puras)
# ──────────────────────────────────────────────────────────────────────────────

## Las 9 celdas de SetUpFieldMove_Cut, fila a fila (y de arriba abajo, x de
## izquierda a derecha), centradas en `centro`.
static func cuadrado(centro: Vector2i) -> Array[Vector2i]:
	var celdas: Array[Vector2i] = []
	for i in 3:
		for j in 3:
			celdas.append(centro + Vector2i(j - 1, i - 1))
	return celdas


## MetatileBehavior_IsPokeGrass || MetatileBehavior_IsAshGrass sobre las banderas
## de la celda: lo que hace que CORTE se pueda elegir.
static func habilita_corte(flags: int) -> bool:
	return (flags & MASCARA_HIERBA) != 0


static func clave_tile(fuente: int, atlas: Vector2i) -> Vector3i:
	return Vector3i(fuente, atlas.x, atlas.y)


## Tabla de sustitución del TileSet, o {} si no se conoce.
static func tabla_de(tile_set: TileSet) -> Dictionary:
	if tile_set == null:
		return {}
	return TILESETS.get(tile_set.resource_path, {})


## Componente del mapa actual (lo crea si hace falta) o null sin mapa.
static func del_mapa_actual() -> HierbaCortableMapa:
	var arbol_escena := Engine.get_main_loop() as SceneTree
	if arbol_escena == null:
		return null
	var admin: Node = arbol_escena.root.get_node_or_null("AdministradorMapa")
	if admin == null:
		return null
	var mapa := admin.get("mapa_actual") as MapaConfiguracion
	if mapa == null or not mapa.is_inside_tree():
		return null
	return mapa.obtener_hierba_cortable()


## Celda del mapa actual en la que está el jugador (el centro del cuadrado).
static func celda_del_jugador() -> Vector2i:
	var arbol_escena := Engine.get_main_loop() as SceneTree
	var admin: Node = arbol_escena.root.get_node_or_null("AdministradorMapa") if arbol_escena != null else null
	if admin == null:
		return Vector2i.ZERO
	var jugador := admin.get("jugador") as Node2D
	var mapa := admin.get("mapa_actual") as Node2D
	if jugador == null or mapa == null:
		return Vector2i.ZERO
	var desplazamiento: Vector2 = admin.get("jugador_offset") if admin.get("jugador_offset") is Vector2 else Vector2(8, 14)
	return Vector2i(((jugador.global_position - desplazamiento - mapa.global_position) / float(Singleton.TILE_SIZE)).floor())


## SetUpFieldMove_Cut, rama de hierba: ¿hay hierba cortable en el cuadrado
## centrado en el jugador? Lo usa el menú del Pokémon para habilitar CORTE.
static func hierba_cortable_junto_al_jugador() -> bool:
	var hierba := del_mapa_actual()
	return hierba != null and hierba.hay_hierba_cortable(celda_del_jugador(), Singleton.capa_activa)


## Al cargar la partida: crea el componente de los mapas que tengan celdas
## cortadas en el almacén temporal, y este las vuelve a aplicar.
static func restaurar_guardado(mapas: Array) -> void:
	if SistemaGuardado.claves_temporales(PREFIJO_CELDA).is_empty() \
			and SistemaGuardado.claves_temporales(PREFIJO_RAIZ).is_empty():
		return
	for mapa in mapas:
		if not (mapa is MapaConfiguracion) or not (mapa as MapaConfiguracion).is_inside_tree():
			continue
		var clave := clave_de_mapa(mapa as MapaConfiguracion)
		if not SistemaGuardado.claves_temporales(PREFIJO_CELDA + clave + ":").is_empty() \
				or not SistemaGuardado.claves_temporales(PREFIJO_RAIZ + clave + ":").is_empty():
			(mapa as MapaConfiguracion).obtener_hierba_cortable()


## Clave del mapa en el almacén temporal: su nombre interno o, si no lo tiene, el
## de su escena.
static func clave_de_mapa(mapa: MapaConfiguracion) -> String:
	if mapa == null:
		return ""
	if not mapa.nombre_interno.is_empty():
		return mapa.nombre_interno
	var base := mapa.scene_file_path.get_file().get_basename()
	return base if not base.is_empty() else str(mapa.name)


# ──────────────────────────────────────────────────────────────────────────────
# CONSULTA
# ──────────────────────────────────────────────────────────────────────────────

## SetUpFieldMove_Cut: alguna celda del cuadrado habilita CORTE (bandera de
## hierba) y se puede sustituir (tile conocido).
func hay_hierba_cortable(centro: Vector2i, capa_datos: int) -> bool:
	var tp := _datos(capa_datos)
	if tp == null:
		return false
	var capas := _capas()
	for celda in cuadrado(centro):
		if _es_hierba_cortable(celda, tp, capas):
			return true
	return false


## Celdas del cuadrado que cortaría FldEff_CutGrass ahora mismo: las de hierba y
## las raíces (que no habilitan CORTE por sí solas).
func celdas_cortables(centro: Vector2i, capa_datos: int) -> Array[Vector2i]:
	var resultado: Array[Vector2i] = []
	var tp := _datos(capa_datos)
	if tp == null:
		return resultado
	var capas := _capas()
	for celda in cuadrado(centro):
		if _es_hierba_cortable(celda, tp, capas) or _tiene_raiz(celda, capas):
			resultado.append(celda)
	return resultado


func esta_cortada(celda: Vector2i) -> bool:
	return cortadas.has(celda)


# ──────────────────────────────────────────────────────────────────────────────
# CORTAR
# ──────────────────────────────────────────────────────────────────────────────

## FldEff_CutGrass completo: suena SE_M_CUT, cambia los metatiles y lanza las hojas
## desde `origen_global` (la altura de la cintura del jugador). Termina cuando
## acaban de girar. Devuelve cuántas celdas se cortaron.
func cortar_alrededor(centro: Vector2i, capa_datos: int, origen_global: Vector2) -> int:
	ControladorArbolCortable.reproducir_sonido_corte()
	var celdas := cortar_cuadrado(centro, capa_datos)
	var hojas := HojasCorteHierba.new()
	var padre: Node = _mapa if _mapa != null and _mapa.is_inside_tree() else self
	padre.add_child(hojas)
	hojas.global_position = origen_global
	await hojas.terminado
	return celdas.size()


## SetCutGrassMetatile para cada celda cortable del cuadrado más
## SetCutGrassMetatiles (raíces). Sin sonido ni hojas. Devuelve las celdas
## cortadas.
func cortar_cuadrado(centro: Vector2i, capa_datos: int) -> Array[Vector2i]:
	var cortadas_ahora: Array[Vector2i] = []
	var tp := _datos(capa_datos)
	if tp == null:
		return cortadas_ahora
	var capas := _capas()
	for celda in cuadrado(centro):
		if _cortar_celda(celda, tp, capas, capa_datos):
			cortadas_ahora.append(celda)
	_recolocar_raices(centro, capas)
	_liberar_pisadas(cortadas_ahora)
	return cortadas_ahora


## Vuelve a dejar el mapa como recién cargado (la hierba crece de nuevo).
func regenerar() -> void:
	var capas := _capas()
	# Primero las raíces: guardan el tile que había tras cortar, y el corte
	# restaura después el original de esa misma celda.
	for clave: String in raices:
		var raiz: Dictionary = raices[clave]
		_poner_tile(capas, str(raiz.capa), raiz.celda, raiz.previo)
	for celda: Vector2i in cortadas:
		var registro: Dictionary = cortadas[celda]
		for tile: Dictionary in registro.tiles:
			_poner_tile(capas, str(tile.capa), celda, tile)
		if int(registro.flags) >= 0:
			var tp := _datos(int(registro.capa_datos))
			if tp != null:
				_escribir_flags(tp, celda, int(registro.flags))
	cortadas.clear()
	raices.clear()


# ──────────────────────────────────────────────────────────────────────────────
# INTERNO
# ──────────────────────────────────────────────────────────────────────────────

func _cortar_celda(celda: Vector2i, tp: TPTileDataMap, capas: Array[TileMapLayer], capa_datos: int) -> bool:
	if cortadas.has(celda):
		return false
	var con_bandera := _es_hierba_cortable(celda, tp, capas)
	if not con_bandera and not _tiene_raiz(celda, capas):
		return false
	# La ceniza que el jugador ya limpió se corta desde su tile original.
	var ceniza := _mapa.obtener_hierba_ceniza() if _mapa != null else null
	if ceniza != null and ceniza.esta_limpia(celda):
		ceniza.restaurar_celda(celda)
	var tiles: Array[Dictionary] = []
	for indice in capas.size():
		var capa := capas[indice]
		var tabla := tabla_de(capa.tile_set)
		if tabla.is_empty() or capa.get_cell_source_id(celda) < 0:
			continue
		var tile := clave_tile(capa.get_cell_source_id(celda), capa.get_cell_atlas_coords(celda))
		var es_hierba: bool = con_bandera and tile in tabla.cortables
		var es_raiz: bool = tile in tabla.raiz
		if not es_hierba and not es_raiz:
			continue
		tiles.append({
			"capa": str(capa.name),
			"fuente": capa.get_cell_source_id(celda),
			"atlas": capa.get_cell_atlas_coords(celda),
			"alt": capa.get_cell_alternative_tile(celda),
		})
		if _hay_tile_debajo(capas, indice, celda):
			capa.erase_cell(celda)
		else:
			var corta: Vector3i = tabla.corta
			capa.set_cell(celda, corta.x, Vector2i(corta.y, corta.z))
	var flags_previos := -1
	if con_bandera:
		flags_previos = tp.get_flags(Vector2(celda))
		_escribir_flags(tp, celda, flags_previos & ~MASCARA_HIERBA)
	cortadas[celda] = {"tiles": tiles, "flags": flags_previos, "capa_datos": capa_datos}
	_anotar(PREFIJO_CELDA + _clave_mapa() + ":%d,%d" % [celda.x, celda.y])
	return true


## SetCutGrassMetatiles(x - 1, y - 2): desde la fila de encima del cuadrado y la
## de debajo, recoloca las raíces de la hierba muy alta que sigue en pie.
func _recolocar_raices(centro: Vector2i, capas: Array[TileMapLayer]) -> void:
	for i in 3:
		var x := centro.x - 1 + i
		# Hierba muy alta justo encima del cuadrado: la celda cortada bajo ella
		# (fila superior del cuadrado) necesita la raíz.
		var arriba := Vector2i(x, centro.y - 2)
		var capa_larga := _capa_con_tile(capas, arriba, "larga")
		if capa_larga != null:
			var tabla := tabla_de(capa_larga.tile_set)
			var debajo := Vector2i(x, centro.y - 1)
			if not tabla.raiz.is_empty() and _es_hierba_corta(debajo, capas) and not _tiene_raiz(debajo, capas):
				var raiz: Vector3i = tabla.raiz[0]
				_poner_raiz(capa_larga, debajo, raiz)
		# Fila inferior ya cortada y una raíz debajo: sin hierba encima, la raíz sobra.
		var inferior := Vector2i(x, centro.y + 1)
		if _es_hierba_corta(inferior, capas):
			var bajo := Vector2i(x, centro.y + 2)
			if _tiene_raiz(bajo, capas):
				_quitar_raiz(bajo, capas)


func _poner_raiz(capa: TileMapLayer, celda: Vector2i, raiz: Vector3i) -> void:
	var clave := "%d,%d,%s" % [celda.x, celda.y, capa.name]
	if not raices.has(clave):
		raices[clave] = {"capa": str(capa.name), "celda": celda, "previo": _tile_actual(capa, celda)}
	capa.set_cell(celda, raiz.x, Vector2i(raiz.y, raiz.z))
	_anotar(PREFIJO_RAIZ + _clave_mapa() + ":" + clave)


## Quita las raíces de `celda` (General Grass en su lugar).
func _quitar_raiz(celda: Vector2i, capas: Array[TileMapLayer]) -> void:
	for indice in capas.size():
		var capa := capas[indice]
		var tabla := tabla_de(capa.tile_set)
		if tabla.is_empty() or capa.get_cell_source_id(celda) < 0:
			continue
		var tile := clave_tile(capa.get_cell_source_id(celda), capa.get_cell_atlas_coords(celda))
		if not (tile in tabla.raiz):
			continue
		var clave := "%d,%d,%s" % [celda.x, celda.y, capa.name]
		if not raices.has(clave):
			raices[clave] = {"capa": str(capa.name), "celda": celda, "previo": _tile_actual(capa, celda)}
		if _hay_tile_debajo(capas, indice, celda):
			capa.erase_cell(celda)
		else:
			var corta: Vector3i = tabla.corta
			capa.set_cell(celda, corta.x, Vector2i(corta.y, corta.z))
		_anotar(PREFIJO_RAIZ + _clave_mapa() + ":" + clave + ":quitar")


func _es_hierba_cortable(celda: Vector2i, tp: TPTileDataMap, capas: Array[TileMapLayer]) -> bool:
	if cortadas.has(celda) or not habilita_corte(tp.get_flags(Vector2(celda))):
		return false
	if _capa_con_tile(capas, celda, "cortables") != null:
		return true
	_avisar_sin_tile(celda)
	return false


func _tiene_raiz(celda: Vector2i, capas: Array[TileMapLayer]) -> bool:
	return _capa_con_tile(capas, celda, "raiz") != null


## General Grass: algún tile de la celda es la hierba corta de su tileset.
func _es_hierba_corta(celda: Vector2i, capas: Array[TileMapLayer]) -> bool:
	for capa in capas:
		var tabla := tabla_de(capa.tile_set)
		if tabla.is_empty() or capa.get_cell_source_id(celda) < 0:
			continue
		if clave_tile(capa.get_cell_source_id(celda), capa.get_cell_atlas_coords(celda)) == tabla.corta:
			return true
	return false


## Primera capa cuyo tile en `celda` está en la lista `lista` de su tileset.
func _capa_con_tile(capas: Array[TileMapLayer], celda: Vector2i, lista: String) -> TileMapLayer:
	for capa in capas:
		var tabla := tabla_de(capa.tile_set)
		if tabla.is_empty() or capa.get_cell_source_id(celda) < 0:
			continue
		var tile := clave_tile(capa.get_cell_source_id(celda), capa.get_cell_atlas_coords(celda))
		if tile in tabla[lista]:
			return capa
	return null


## ¿Hay algo dibujado en `celda` en una capa anterior (por debajo) a la `indice`?
func _hay_tile_debajo(capas: Array[TileMapLayer], indice: int, celda: Vector2i) -> bool:
	for i in indice:
		if capas[i].get_cell_source_id(celda) >= 0:
			return true
	return false


func _tile_actual(capa: TileMapLayer, celda: Vector2i) -> Dictionary:
	return {
		"fuente": capa.get_cell_source_id(celda),
		"atlas": capa.get_cell_atlas_coords(celda),
		"alt": capa.get_cell_alternative_tile(celda),
	}


func _poner_tile(capas: Array[TileMapLayer], nombre_capa: String, celda: Vector2i, tile: Dictionary) -> void:
	for capa in capas:
		if str(capa.name) != nombre_capa:
			continue
		if int(tile.fuente) < 0:
			capa.erase_cell(celda)
		else:
			capa.set_cell(celda, int(tile.fuente), tile.atlas, int(tile.alt))
		return


## Capas de tiles del mapa de abajo arriba (orden de los hijos).
func _capas() -> Array[TileMapLayer]:
	var capas: Array[TileMapLayer] = []
	if _mapa == null:
		_mapa = _buscar_mapa_padre()
	if _mapa == null:
		return capas
	for hijo: Node in _mapa.get_children():
		if hijo is TileMapLayer:
			capas.append(hijo as TileMapLayer)
	return capas


func _datos(capa_datos: int) -> TPTileDataMap:
	if _mapa == null:
		_mapa = _buscar_mapa_padre()
	return _mapa.get_capa_resuelta(capa_datos) if _mapa != null else null


## tile_data viene de la escena y puede ser de solo lectura: se copia para poder
## cambiarla (set_cell_data la vaciaría).
func _escribir_flags(tp: TPTileDataMap, celda: Vector2i, flags: int) -> void:
	if tp.tile_data.is_read_only():
		tp.tile_data = tp.tile_data.duplicate(true)
	var clave := "%d,%d" % [celda.x, celda.y]
	var datos: Dictionary = tp.tile_data.get(clave, {})
	if datos.is_read_only():
		datos = datos.duplicate(true)
	datos["flags"] = flags
	tp.tile_data[clave] = datos


## Las animaciones de hierba pisada ("PastoAlto1") de las celdas cortadas
## desaparecen: UpdateTallGrassFieldEffect las detiene al dejar de ser TALL_GRASS.
func _liberar_pisadas(celdas: Array[Vector2i]) -> void:
	if celdas.is_empty() or _mapa == null or not is_inside_tree():
		return
	for nodo: Node in get_tree().get_nodes_in_group("PastoAlto1"):
		var pasto := nodo as Node2D
		if pasto != null and _mapa.is_ancestor_of(pasto) \
				and _mapa.global_to_map_cell(pasto.global_position) in celdas:
			pasto.queue_free()


func _avisar_sin_tile(celda: Vector2i) -> void:
	if _avisadas.has(celda):
		return
	_avisadas[celda] = true
	push_warning("[HIERBA_CORTABLE] %s %s: celda con hierba pero sin tile conocido; añade su tile a HierbaCortableMapa.TILESETS" % [
		_clave_mapa(), celda,
	])


func _clave_mapa() -> String:
	return clave_de_mapa(_mapa)


func _anotar(clave: String) -> void:
	SistemaGuardado.set_flag_temporal(clave, true)


## Vuelve a aplicar las celdas y raíces que la partida guardada trae de este mapa.
func _aplicar_guardado() -> void:
	var clave_mapa := _clave_mapa()
	if clave_mapa.is_empty():
		return
	var prefijo_celda := PREFIJO_CELDA + clave_mapa + ":"
	var capas := _capas()
	var tp_por_capa: Dictionary = {}
	for clave in SistemaGuardado.claves_temporales(prefijo_celda):
		var coords := clave.trim_prefix(prefijo_celda).split(",")
		if coords.size() != 2 or not coords[0].is_valid_int() or not coords[1].is_valid_int():
			continue
		var capa_datos: int = Singleton.capa_activa
		if not tp_por_capa.has(capa_datos):
			tp_por_capa[capa_datos] = _datos(capa_datos)
		var tp: TPTileDataMap = tp_por_capa[capa_datos]
		if tp != null:
			_cortar_celda(Vector2i(coords[0].to_int(), coords[1].to_int()), tp, capas, capa_datos)
	var prefijo_raiz := PREFIJO_RAIZ + clave_mapa + ":"
	for clave in SistemaGuardado.claves_temporales(prefijo_raiz):
		var partes := clave.trim_prefix(prefijo_raiz).split(":")
		var datos := partes[0].split(",")
		if datos.size() < 3 or not datos[0].is_valid_int() or not datos[1].is_valid_int():
			continue
		var celda := Vector2i(datos[0].to_int(), datos[1].to_int())
		var nombre_capa := ",".join(datos.slice(2))
		for capa in capas:
			if str(capa.name) != nombre_capa:
				continue
			var tabla := tabla_de(capa.tile_set)
			if tabla.is_empty():
				break
			var raiz_clave := "%d,%d,%s" % [celda.x, celda.y, nombre_capa]
			if not raices.has(raiz_clave):
				raices[raiz_clave] = {"capa": nombre_capa, "celda": celda, "previo": _tile_actual(capa, celda)}
			if partes.size() > 1 and partes[1] == "quitar":
				_quitar_raiz(celda, capas)
			elif not tabla.raiz.is_empty():
				var raiz: Vector3i = tabla.raiz[0]
				capa.set_cell(celda, raiz.x, Vector2i(raiz.y, raiz.z))
			break


func _buscar_mapa_padre() -> MapaConfiguracion:
	var nodo: Node = get_parent()
	while nodo != null:
		if nodo is MapaConfiguracion:
			return nodo as MapaConfiguracion
		nodo = nodo.get_parent()
	return null

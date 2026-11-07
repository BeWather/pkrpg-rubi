class_name DatosConcurso
extends RefCounted
## Datos estáticos de los concursos de Rubí, leídos una vez de poke.db (DatabaseManager):
## - gContestMoves por numero_movimiento: categoría, efecto, iniciador de combo y combos;
## - gContestEffects (ConcursoEfectos): tipo de icono, appeal y jam;
## - gContestOpponents (ConcursoRivales): los 60 rivales.
## Los importa herramientas/importar_concurso_datos.py.
##
## MOVE_NONE (0) no está en la tabla Movimientos: en gContestMoves es
## HIGHLY_APPEALING / COOL sin combos, y así lo devuelve este objeto (lo usan los
## concursantes nerviosos, que actúan con MOVE_NONE).

const MOVIMIENTO_NINGUNO: int = 0
const NUM_EFECTOS: int = 48
const NUM_NIVELES: int = 4
const POOLS: Array[String] = ["pool_carisma", "pool_belleza", "pool_dulzura", "pool_ingenio", "pool_dureza"]

## numero_movimiento -> {nombre_interno, nombre, categoria, efecto, combo_inicio, combos: Array[int]}.
var _movimientos: Dictionary = {}
## nombre_interno -> numero_movimiento.
var _por_nombre: Dictionary = {}
## id -> {nombre, tipo, atractivo, interferencia}.
var _efectos: Array[Dictionary] = []
## Filas de ConcursoRivales por id.
var _rivales: Array[Dictionary] = []

static var _compartido: DatosConcurso = null


## Instancia cargada de la BD, compartida (los datos no cambian en partida).
static func compartido() -> DatosConcurso:
	if _compartido == null:
		var datos := DatosConcurso.new()
		if datos.cargar_desde_bd():
			_compartido = datos
		else:
			return datos
	return _compartido


func cargar_desde_bd() -> bool:
	if DatabaseManager == null or not DatabaseManager.esta_conectado():
		return false
	cargar(DatabaseManager.obtener_movimientos_concurso(), DatabaseManager.obtener_efectos_concurso(),
		DatabaseManager.obtener_rivales_concurso())
	return not _efectos.is_empty()


## Carga desde filas ya leídas (la BD o datos de prueba).
func cargar(movimientos: Array, efectos: Array, rivales: Array) -> void:
	_movimientos.clear()
	_por_nombre.clear()
	for fila in movimientos:
		var numero: int = int(fila.get("numero_movimiento", 0))
		var combos: Array[int] = []
		var lista: Variant = fila.get("concurso_combos_json", "[]")
		if lista is String:
			lista = JSON.parse_string(lista)
		if lista is Array:
			for valor in lista:
				combos.append(int(valor))
		_movimientos[numero] = {
			"nombre_interno": str(fila.get("nombre_interno", "")),
			"nombre": str(fila.get("nombre", "")),
			"categoria": int(fila.get("concurso_categoria", 0)),
			"efecto": int(fila.get("concurso_efecto", 0)),
			"combo_inicio": int(fila.get("concurso_combo_inicio", 0)) if fila.get("concurso_combo_inicio") != null else 0,
			"combos": combos,
			"descripcion": str(fila.get("concurso_descripcion", "")) if fila.get("concurso_descripcion") != null else "",
		}
		_por_nombre[str(fila.get("nombre_interno", ""))] = numero
	_efectos.clear()
	for fila in efectos:
		_efectos.append({
			"nombre": str(fila.get("nombre", "")),
			"tipo": int(fila.get("tipo", 0)),
			"atractivo": int(fila.get("atractivo", 0)),
			"interferencia": int(fila.get("interferencia", 0)),
		})
	_rivales.clear()
	for fila in rivales:
		_rivales.append(fila)


func _movimiento(numero: int) -> Dictionary:
	return _movimientos.get(numero, {})


## gContestMoves[m].contestCategory (Movimiento.CategoriaConcurso).
func categoria(movimiento: int) -> int:
	return int(_movimiento(movimiento).get("categoria", Movimiento.CategoriaConcurso.CARISMA))


## gContestMoves[m].effect (EfectosConcurso.Efecto).
func efecto(movimiento: int) -> int:
	return int(_movimiento(movimiento).get("efecto", 0))


## gContestMoves[m].comboStarterId.
func combo_inicio(movimiento: int) -> int:
	return int(_movimiento(movimiento).get("combo_inicio", 0))


## gContestMoves[m].comboMoves (sin ceros).
func combos(movimiento: int) -> Array[int]:
	var lista: Array[int] = []
	lista.assign(_movimiento(movimiento).get("combos", []))
	return lista


func nombre_movimiento(movimiento: int) -> String:
	return str(_movimiento(movimiento).get("nombre", ""))


## Descripción del efecto en la pantalla de elección (gContestEffectStrings).
func descripcion_movimiento(movimiento: int) -> String:
	return str(_movimiento(movimiento).get("descripcion", ""))


func nombre_interno_movimiento(movimiento: int) -> String:
	return str(_movimiento(movimiento).get("nombre_interno", ""))


## numero_movimiento a partir del nombre interno (0 si no existe).
func numero_movimiento(nombre_interno: String) -> int:
	return int(_por_nombre.get(nombre_interno, MOVIMIENTO_NINGUNO))


## gContestEffects[e].appeal.
func atractivo_efecto(id_efecto: int) -> int:
	return int(_efectos[id_efecto].get("atractivo", 0)) if id_efecto >= 0 and id_efecto < _efectos.size() else 0


## gContestEffects[e].jam.
func interferencia_efecto(id_efecto: int) -> int:
	return int(_efectos[id_efecto].get("interferencia", 0)) if id_efecto >= 0 and id_efecto < _efectos.size() else 0


## gContestEffects[e].effectType (solo para el icono de la descripción).
func tipo_efecto(id_efecto: int) -> int:
	return int(_efectos[id_efecto].get("tipo", 0)) if id_efecto >= 0 and id_efecto < _efectos.size() else 0


## AreMovesContestCombo: `actual` completa el combo que abre `previo`. La tabla de
## multiplicadores de Rubí es booleana, así que el resultado es 0 o 1.
func son_combo(previo: int, actual: int) -> int:
	var inicio: int = combo_inicio(previo)
	if inicio == 0:
		return 0
	return 1 if combos(actual).has(inicio) else 0


func num_rivales() -> int:
	return _rivales.size()


func rival(id: int) -> Dictionary:
	return _rivales[id] if id >= 0 and id < _rivales.size() else {}


## Ids de los rivales de un nivel y una categoría, en el orden de gContestOpponents
## (Contest_InitAllPokemon).
func rivales_para(nivel: int, categoria_concurso: int) -> Array[int]:
	var ids: Array[int] = []
	var pool: String = POOLS[categoria_concurso]
	for fila in _rivales:
		if int(fila.get("nivel", -1)) == nivel and int(fila.get(pool, 0)) != 0:
			ids.append(int(fila.get("id", 0)))
	return ids

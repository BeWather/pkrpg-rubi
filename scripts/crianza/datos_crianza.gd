extends RefCounted
class_name DatosCrianza

## Datos de especie y movimientos que necesita la Guardería (`src/daycare.c`).
##
## Envuelve `DatabaseManager` (consultas parametrizadas, grupo de versión
## `ruby-sapphire`) y el JSON de preevoluciones importado del decomp
## (`herramientas/importar_especie_base_huevo.py`). Todas las especies se
## identifican por `Pokemon.nombre_interno` y los movimientos por
## `Movimientos.nombre_interno` canónico.
##
## `Guarderia` lo usa por duck-typing: los tests pueden pasar un doble con los
## mismos métodos.

const RUTA_ESPECIE_BASE: String = "res://BaseDatos/crianza/especie_base_huevo.json"
const VERSION_GRUPO: String = "ruby-sapphire"
const METODO_NIVEL: int = 1
const METODO_MAQUINA: int = 2
const METODO_HUEVO: int = 3
## Learnset por nivel (parámetros: especie, METODO_NIVEL, VERSION_GRUPO). Lo reutiliza
## el editor de entrenadores, que consulta SQLite sin DatabaseManager.
const SQL_MOVIMIENTOS_NIVEL: String = """
	SELECT pm.nivel_aprendizaje AS nivel, m.nombre_interno FROM PokemonMovimientos pm
	JOIN Pokemon p ON p.numero_nacional = pm.pokemon_numero
	JOIN Movimientos m ON m.id = pm.movimiento_id
	WHERE p.nombre_interno = ? AND pm.metodo_aprendizaje_id = ? AND pm.version_grupo = ?
	ORDER BY pm.orden_aprendizaje"""

## Mapa hijo -> preevolución directa, compartido entre instancias.
static var _preevoluciones: Dictionary = {}
static var _preevoluciones_cargadas: bool = false

var _cache_especie: Dictionary = {}
var _cache_niveles: Dictionary = {}
var _cache_huevo: Dictionary = {}


# ==============================================
# ESPECIE
# ==============================================

## Grupos huevo de la especie ("Monster", "No Eggs", "Ditto"...). Vacío si no existe.
func grupos_huevo(especie: String) -> Array[String]:
	var fila := _fila_especie(especie)
	var grupos: Array[String] = []
	for clave in ["grupo_huevo_1", "grupo_huevo_2"]:
		var valor: Variant = fila.get(clave)
		if valor != null and str(valor) != "":
			grupos.append(str(valor))
	return grupos


## Ciclos de huevo (`gBaseStats.eggCycles`): `pasos_eclosion / 255`.
func ciclos_huevo(especie: String) -> int:
	var fila := _fila_especie(especie)
	return int(fila.get("pasos_eclosion", 0)) / 255


## Probabilidad (0-100) de que la especie sea hembra; -1 si no tiene sexo.
func prob_sexo(especie: String) -> int:
	var fila := _fila_especie(especie)
	var valor: Variant = fila.get("prob_sexo")
	return -1 if valor == null else int(valor)


## Especie del huevo (`GetEggSpecies`): la preevolución más básica.
func especie_base(especie: String) -> String:
	_cargar_preevoluciones()
	var actual := especie
	# Como GetEggSpecies: como mucho 5 pasos hacia atrás.
	for i in range(5):
		if not _preevoluciones.has(actual):
			break
		actual = str(_preevoluciones[actual])
	return actual


## Experiencia necesaria para alcanzar `nivel` según la curva de la especie
## (`CalculadoraStatsPokemon`, curvas de Gen 3).
func experiencia_nivel(especie: String, nivel: int) -> int:
	var fila := _fila_especie(especie)
	return CalculadoraStatsPokemon.experiencia_nivel(nivel, str(fila.get("ratio_crecimiento", "")))


# ==============================================
# MOVIMIENTOS
# ==============================================

## Movimientos huevo de la especie (método egg, `ruby-sapphire`).
func movimientos_huevo(especie: String) -> Array[String]:
	if _cache_huevo.has(especie):
		return _cache_huevo[especie]
	var resultado: Array[String] = []
	var filas := _consultar("""
		SELECT m.nombre_interno FROM PokemonMovimientos pm
		JOIN Pokemon p ON p.numero_nacional = pm.pokemon_numero
		JOIN Movimientos m ON m.id = pm.movimiento_id
		WHERE p.nombre_interno = ? AND pm.metodo_aprendizaje_id = ? AND pm.version_grupo = ?
		ORDER BY pm.id""", [especie, METODO_HUEVO, VERSION_GRUPO])
	for fila in filas:
		resultado.append(str(fila["nombre_interno"]))
	_cache_huevo[especie] = resultado
	return resultado


## true si `mov` es una MT/MO (`MaquinasMovimientos`) que la especie puede
## aprender en `ruby-sapphire` (`CanMonLearnTMHM`).
func puede_aprender_mt(especie: String, mov: String) -> bool:
	var filas := _consultar("""
		SELECT 1 FROM PokemonMovimientos pm
		JOIN Pokemon p ON p.numero_nacional = pm.pokemon_numero
		JOIN Movimientos m ON m.id = pm.movimiento_id
		JOIN MaquinasMovimientos mm ON mm.movimiento_id = m.id
		WHERE p.nombre_interno = ? AND m.nombre_interno = ?
		AND pm.metodo_aprendizaje_id = ? AND pm.version_grupo = ?
		LIMIT 1""", [especie, mov, METODO_MAQUINA, VERSION_GRUPO])
	return not filas.is_empty()


## Movimientos por nivel de la especie en `ruby-sapphire`, en el orden de la
## tabla (`gLevelUpLearnsets`): [{"nivel": int, "mov": String}, ...].
func movimientos_nivel(especie: String) -> Array[Dictionary]:
	if _cache_niveles.has(especie):
		return _cache_niveles[especie]
	var resultado: Array[Dictionary] = []
	var filas := _consultar(SQL_MOVIMIENTOS_NIVEL, [especie, METODO_NIVEL, VERSION_GRUPO])
	for fila in filas:
		var nivel: Variant = fila.get("nivel")
		resultado.append({"nivel": 0 if nivel == null else int(nivel), "mov": str(fila["nombre_interno"])})
	_cache_niveles[especie] = resultado
	return resultado


## Movimientos que la especie aprende exactamente en `nivel` (`MonTryLearningNewMove`).
func movimientos_en_nivel(especie: String, nivel: int) -> Array[String]:
	var resultado: Array[String] = []
	for entrada in movimientos_nivel(especie):
		if int(entrada["nivel"]) == nivel and not resultado.has(str(entrada["mov"])):
			resultado.append(str(entrada["mov"]))
	return resultado


## `nombre_interno` canónico de un movimiento. Los movimientos de partida se
## construyen siempre desde la BD (`Movimiento.desde_guardado`), así que
## `get_nombre_interno()` ya es la clave de `Movimientos.nombre_interno`.
func id_movimiento(mov: Movimiento) -> String:
	if mov == null:
		return ""
	return mov.get_nombre_interno()


## Crea un `Movimiento` con PP completos, con los mismos datos que
## `BasePokemon.get_movs_nivel` (`Movimiento.desde_fila_bd`). null si el
## movimiento no existe.
func crear_movimiento(nombre_interno: String) -> Movimiento:
	var filas := _consultar("""
		SELECT mc.*, t.nombre AS tipo_nombre FROM Movimientos mc
		LEFT JOIN Tipos t ON mc.tipo_id = t.id
		WHERE mc.nombre_interno = ?""", [nombre_interno])
	if filas.is_empty():
		push_warning("[DatosCrianza] Movimiento '%s' no encontrado" % nombre_interno)
		return null
	return Movimiento.desde_fila_bd(filas[0])


# ==============================================
# INTERNOS
# ==============================================

func _fila_especie(especie: String) -> Dictionary:
	if _cache_especie.has(especie):
		return _cache_especie[especie]
	var filas := _consultar("""
		SELECT grupo_huevo_1, grupo_huevo_2, pasos_eclosion, prob_sexo, ratio_crecimiento
		FROM Pokemon WHERE nombre_interno = ?""", [especie])
	var fila: Dictionary = filas[0] if not filas.is_empty() else {}
	_cache_especie[especie] = fila
	return fila


static func _cargar_preevoluciones() -> void:
	if _preevoluciones_cargadas:
		return
	_preevoluciones_cargadas = true
	var archivo := FileAccess.open(RUTA_ESPECIE_BASE, FileAccess.READ)
	if archivo == null:
		push_error("[DatosCrianza] No se pudo abrir %s" % RUTA_ESPECIE_BASE)
		return
	var datos: Variant = JSON.parse_string(archivo.get_as_text())
	archivo.close()
	if datos is Dictionary:
		_preevoluciones = datos
	else:
		push_error("[DatosCrianza] JSON inválido en %s" % RUTA_ESPECIE_BASE)


func _consultar(consulta: String, parametros: Array) -> Array:
	if not DatabaseManager.esta_conectado():
		return []
	if not DatabaseManager.db.query_with_bindings(consulta, parametros):
		push_warning("[DatosCrianza] Error en consulta: %s" % consulta)
		return []
	return DatabaseManager.db.get_query_result().duplicate()

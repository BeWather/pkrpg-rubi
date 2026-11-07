@tool
extends RefCounted
## Autogenerador de datos completos de Pokemon desde lo minimo (especie+nivel).
## Abre poke.db con godot-sqlite sin depender de autoloads, asi que funciona
## identico en el editor y en el juego. Pensado para reutilizarse
## desde la ventana de prueba de batalla, la lista de pokemon generados y
## cualquier UI futura.

const RUTA_DB := "res://BaseDatos/poke.db"

var _db = null


func _init(ruta_db: String = RUTA_DB) -> void:
	_db = SQLite.new()
	_db.path = ruta_db
	# OJO: NUNCA read_only = true. godot-sqlite lo implementa con immutable=1 y
	# en Windows ese handle deja en SOLO LECTURA cualquier otra conexion al
	# mismo archivo (el editor de instancias no podia guardar mientras esta
	# clase estuviera viva). Esta clase solo ejecuta SELECTs igualmente.
	if not _db.open_db():
		_db = null


func esta_conectado() -> bool:
	return _db != null


func cerrar() -> void:
	if _db != null:
		_db.close_db()
		_db = null


## Catalogo de especies para selectores: [{nombre_interno, nombre, numero_nacional}]
func lista_especies() -> Array:
	if _db == null:
		return []
	_db.query("SELECT nombre_interno, nombre, numero_nacional FROM Pokemon ORDER BY numero_nacional")
	return _db.query_result.duplicate(true) if _db.query_result != null else []


func datos_especie(nombre_interno: String) -> Dictionary:
	if _db == null or nombre_interno.strip_edges().is_empty():
		return {}
	_db.query_with_bindings("SELECT * FROM Pokemon WHERE nombre_interno = ? COLLATE NOCASE", [nombre_interno.strip_edges()])
	var resultados: Array = _db.query_result if _db.query_result != null else []
	return resultados[0] if resultados.size() > 0 else {}


## Ultimos movimientos aprendidos por nivel (max 4), mismos criterios que la
## lista de pokemon generados: [{nombre_interno, nombre, pp}]
func movimientos_por_nivel(pokemon_numero: int, nivel: int, limite: int = 4) -> Array:
	if _db == null or pokemon_numero <= 0:
		return []
	_db.query_with_bindings("""
		SELECT mc.nombre_interno, mc.nombre, mc.pp
		FROM PokemonMovimientos pm
		JOIN Movimientos mc ON mc.id = pm.movimiento_id
		JOIN MetodosAprendizaje ma ON ma.id = pm.metodo_aprendizaje_id
		WHERE pm.pokemon_numero = ?
			AND ma.nombre = 'level-up'
	""" + MovimientosIniciales.SQL_ORDEN_RUBI % nivel, [pokemon_numero])
	var resultados: Array = _db.query_result if _db.query_result != null else []
	var movimientos: Array = []
	for fila in MovimientosIniciales.seleccionar(resultados, limite):
		movimientos.append({
			"nombre_interno": str(fila.get("nombre_interno", "")).to_upper(),
			"nombre": str(fila.get("nombre", "")),
			"pp": int(fila.get("pp", 0)),
		})
	return movimientos


func naturaleza_aleatoria() -> String:
	if _db == null:
		return ""
	_db.query("SELECT nombre FROM Naturalezas ORDER BY RANDOM() LIMIT 1")
	var resultados: Array = _db.query_result if _db.query_result != null else []
	return str(resultados[0].get("nombre", "")) if resultados.size() > 0 else ""


## Sexo aleatorio respetando prob_sexo de la especie (0=siempre M, 100=siempre F,
## null=SIN_SEXO), mismo criterio que BasePokemon.
func sexo_aleatorio(prob_sexo) -> String:
	if prob_sexo == null:
		return "SIN_SEXO"
	var prob := int(prob_sexo)
	if prob <= 0:
		return "M"
	if prob >= 100:
		return "F"
	return "F" if randi() % 100 < prob else "M"


## AUTOGLPRINCIPAL: especie+nivel -> entrada completa de datos.
## Los IVs salen aleatorios (0-31) como hace BasePokemon; las estadisticas
## finales las calcula la batalla al crear la instancia real.
func autogenerar(especie: String, nivel: int, entrenador: String = "") -> Dictionary:
	var fila := datos_especie(especie)
	if fila.is_empty():
		return {}
	var nivel_final := maxi(nivel, 1)
	var habilidad := str(fila.get("habilidad_1", ""))
	if habilidad.is_empty():
		habilidad = str(fila.get("habilidad_2", ""))
	if habilidad.is_empty():
		habilidad = "SIN_HABILIDAD"
	return {
		"nombre_interno": str(fila.get("nombre_interno", "")).to_upper(),
		"nombre": str(fila.get("nombre", "")),
		"numero_nacional": int(fila.get("numero_nacional", 0)),
		"nivel": nivel_final,
		"sexo": sexo_aleatorio(fila.get("prob_sexo")),
		"naturaleza": naturaleza_aleatoria(),
		"habilidad": habilidad,
		"objeto": "",
		"iv_ps": randi() % 32,
		"iv_ataque": randi() % 32,
		"iv_defensa": randi() % 32,
		"iv_ataque_especial": randi() % 32,
		"iv_defensa_especial": randi() % 32,
		"iv_velocidad": randi() % 32,
		"movimientos": movimientos_por_nivel(int(fila.get("numero_nacional", 0)), nivel_final),
		"encuentro_lugar": "PRUEBA",
		"encuentro_bola": "POKEBALL",
		"encuentro_nivel": nivel_final,
		"entrenador_original": entrenador,
	}

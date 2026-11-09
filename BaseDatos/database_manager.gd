extends Node

const TiposEntrenadorData := preload("res://BaseDatos/tipos_entrenador.gd")

# DatabaseManager - Singleton para acceso global a la base de datos
# Uso: DatabaseManager.obtener_naturaleza_aleatoria()

signal database_ready
signal database_error(message: String)

var db: SQLite = null
var db_path: String = "res://BaseDatos/poke.db"
var db_connected: bool = false

# ==============================================
# TABLA DE ENCUENTROS SALVAJES
# ==============================================

## Pesos de los 12 slots de hierba/cueva (Gen 3). Suma = 100.
const PESOS_SLOTS_ENCUENTRO: Array = [20, 20, 10, 10, 10, 10, 5, 5, 4, 4, 1, 1]  # alias para retrocompatibilidad
const PESOS_SLOTS_HIERBA:  Array = [20, 20, 10, 10, 10, 10, 5, 5, 4, 4, 1, 1]  # 12 slots
## Pesos de los 5 slots de agua/roca (surf / golpe roca). Suma = 100.
const PESOS_SLOTS_AGUA:    Array = [60, 30, 5, 4, 1]   # 5 slots
const PESOS_SLOTS_ROCA:    Array = [60, 30, 5, 4, 1]   # 5 slots
## Pesos de pesca por tipo de caña. En el JSON los 10 slots de "pesca" están
## concatenados: slots 0-1 = caña vieja, 2-4 = caña buena, 5-9 = supercaña.
const PESOS_SLOTS_PESCA_VIEJA: Array = [70, 30]            # 2 slots, suma = 100
const PESOS_SLOTS_PESCA_BUENA: Array = [60, 20, 20]        # 3 slots, suma = 100
const PESOS_SLOTS_PESCA_SUPER: Array = [40, 40, 15, 4, 1]  # 5 slots, suma = 100

var _tabla_encuentros: Dictionary = {}
var _tabla_encuentros_cargada: bool = false
const RUTA_ENCUENTROS: String = "res://BaseDatos/config_encuentros.json"
const RUTA_ENCUENTROS_ALTERNATIVO: String = "res://BaseDatos/config_encuentros_alternativo.json"
## Usa config_encuentros_alternativo.json (3 generaciones, sin slots repetidos) en lugar
## de la tabla original. Los mapas que la alternativa no define (ZONA SAFARI) conservan
## la original. Lo fija AdministradorMapa desde su bandera `tabla_encuentros_alternativa`.
var usar_tabla_alternativa: bool = false:
	set(valor):
		if valor == usar_tabla_alternativa:
			return
		usar_tabla_alternativa = valor
		_tabla_encuentros_cargada = false

# Caché en memoria de la matriz de efectividad (tabla TiposEficacia).
# La batalla y la IA la consultan varias veces por turno: se carga una vez.
var _matriz_eficacia: Dictionary = {}
var _matriz_eficacia_cargada: bool = false

## Caché de Pokemon.ratio_captura por nombre interno (obtener_ratio_captura).
var _cache_ratio_captura: Dictionary = {}

## Caché de la tabla Bayas por Objetos.id (obtener_datos_baya).
var _cache_bayas: Dictionary = {}

## Caché de la tabla Habilidades por clave de búsqueda (obtener_datos_habilidad).
var _cache_habilidades: Dictionary = {}

const RUTA_ENTRENADORES: String = "res://BaseDatos/lista_entrenadores.json"
var _entrenadores_por_id: Dictionary = {}
var _entrenadores_cargados: bool = false

func _ready():
	# La BBDD es dato de DESARROLLO (se edita con las herramientas del editor y
	# el maestro vive en el repo). En desarrollo se abre DIRECTAMENTE desde
	# res://; la copia en user:// solo se usa en builds exportados, donde res://
	# va empaquetado (PCK/APK) y SQLite no puede abrirlo como fichero real.
	if _res_es_abrible_directo():
		conectar_base_datos("res://BaseDatos/poke.db")
	else:
		var source_db := "res://BaseDatos/poke.db"
		var user_db := "user://poke.db"
		if not FileAccess.file_exists(user_db):
			print("📦 [DATABASE_MANAGER] Copiando DB de %s a %s (primer arranque)" % [source_db, user_db])
			_copiar_db(source_db, user_db)
		elif FileAccess.file_exists(source_db) and FileAccess.get_modified_time(source_db) > FileAccess.get_modified_time(user_db):
			# La DB no se escribe en tiempo de ejecución; si res:// es más
			# reciente que la copia local (p. ej. tras actualizar la app) se
			# refresca para recoger los datos nuevos del paquete.
			print("🔄 [DATABASE_MANAGER] %s más reciente que %s — refrescando copia local" % [source_db, user_db])
			_borrar_db_local(user_db)
			_copiar_db(source_db, user_db)
		conectar_base_datos(user_db)

	# La matriz de efectividad de tipos vive en la BBDD (tabla TiposEficacia).
	# Se sincroniza aquí con Singleton.tabla_tipos, la caché en memoria que
	# consumen la batalla y la IA; el diccionario hardcodeado de singleton.gd
	# queda como fallback si la tabla no existe o está vacía.
	_sincronizar_tabla_tipos_singleton()

## True si SQLite puede abrir la DB de res:// como fichero real del disco
## (desarrollo: editor o ejecución desde el proyecto). En builds exportados
## res:// está empaquetado (PCK/APK) y solo es legible vía FileAccess, así que
## se devuelve false y se trabaja sobre la copia local en user://.
func _res_es_abrible_directo() -> bool:
	var f := FileAccess.open("res://BaseDatos/poke.db", FileAccess.READ_WRITE)
	if f != null:
		f.close()
		return true
	return false

## Copia la DB de origen a destino (usado para la copia local en user://).
func _copiar_db(source_db: String, user_db: String) -> void:
	if not FileAccess.file_exists(source_db):
		# En Android, los .db dentro del APK no son accesibles directamente via res://.
		# Pero la DB ya copiada en install anterior (en user://poke.db) sigue siendo valida.
		print("⚠️ [DATABASE_MANAGER] %s no accesible por res://. Usando DB existente en user:// si existe." % source_db)
		return
	var src := FileAccess.open(source_db, FileAccess.READ)
	if src == null:
		push_error("[DATABASE_MANAGER] No se pudo leer %s" % source_db)
		return
	var bytes := src.get_buffer(src.get_length())
	src.close()
	var dst := FileAccess.open(user_db, FileAccess.WRITE)
	if dst == null:
		push_error("[DATABASE_MANAGER] No se pudo escribir %s" % user_db)
		return
	dst.store_buffer(bytes)
	dst.close()
	print("✅ [DATABASE_MANAGER] DB copiada OK (%d bytes)" % bytes.size())

## Elimina la copia local de la DB (y los sidecars WAL/SHM de SQLite).
func _borrar_db_local(user_db: String) -> void:
	var base_absoluta := ProjectSettings.globalize_path(user_db)
	for sufijo in ["", "-wal", "-shm"]:
		var ruta: String = base_absoluta + sufijo
		if FileAccess.file_exists(ruta):
			DirAccess.remove_absolute(ruta)
func conectar_base_datos(path: String = "") -> bool:
	if path != "":
		db_path = path

	if db != null:
		db.close_db()

	db = SQLite.new()
	db.path = db_path

	if db.open_db():
		db_connected = true
		print("✅ [DATABASE_MANAGER] Conectado a la base de datos: %s" % db_path)
		database_ready.emit()
		return true
	else:
		db_connected = false
		var error_msg = "❌ [DATABASE_MANAGER] Error al conectar a la base de datos: %s" % db_path
		print(error_msg)
		database_error.emit(error_msg)
		return false

## Cierra la conexión a la base de datos.
func desconectar_base_datos():
	if db != null:
		db.close_db()
		db_connected = false
		print("🔌 [DATABASE_MANAGER] Base de datos desconectada")

## Verifica si hay conexión activa a la base de datos.
func esta_conectado() -> bool:
	return db_connected and db != null

## Ejecuta una consulta SQL y devuelve true si fue exitosa.
func ejecutar_consulta(consulta: String) -> bool:
	if not esta_conectado():
		print("❌ [DATABASE_MANAGER] No hay conexión a la base de datos")
		return false

	var resultado = db.query(consulta)
	if not resultado:
		print("❌ [DATABASE_MANAGER] Error en consulta: %s" % consulta)

	return resultado

## Obtiene los resultados de la última consulta.
func obtener_resultados() -> Array:
	if not esta_conectado():
		return []

	return db.get_query_result()

# ==============================================
# CONSULTAS DE POKÉMON
# ==============================================

## Obtiene todos los datos de un Pokémon por su nombre interno.
func obtener_datos_pokemon(nombre_interno: String) -> Dictionary:
	var consulta = "SELECT * FROM Pokemon WHERE nombre_interno = '%s'" % nombre_interno

	if ejecutar_consulta(consulta):
		var resultados = obtener_resultados()
		if resultados.size() > 0:
			return resultados[0]

	print("⚠️ [DATABASE_MANAGER] Pokémon '%s' no encontrado" % nombre_interno)
	return {}

## Ratio de captura de la especie (`Pokemon.ratio_captura`, 3-255), con caché
## por nombre interno. Devuelve 0 si la especie no existe o no hay BD.
func obtener_ratio_captura(nombre_interno: String) -> int:
	var clave := nombre_interno.strip_edges().to_upper()
	if _cache_ratio_captura.has(clave):
		return _cache_ratio_captura[clave]
	if not esta_conectado():
		return 0
	var ratio := 0
	if db.query_with_bindings("SELECT ratio_captura FROM Pokemon WHERE nombre_interno = ?", [clave]):
		var resultados: Array = db.get_query_result()
		if not resultados.is_empty() and resultados[0].get("ratio_captura") != null:
			ratio = int(resultados[0]["ratio_captura"])
	if ratio <= 0:
		print("⚠️ [DATABASE_MANAGER] Ratio de captura de '%s' no encontrado" % clave)
		return 0
	_cache_ratio_captura[clave] = ratio
	return ratio

## Obtiene datos de un Pokémon por su número nacional.
func obtener_pokemon_por_numero(numero_nacional: int) -> Dictionary:
	var consulta = "SELECT * FROM Pokemon WHERE numero_nacional = %d" % numero_nacional

	if ejecutar_consulta(consulta):
		var resultados = obtener_resultados()
		if resultados.size() > 0:
			return resultados[0]

	print("⚠️ [DATABASE_MANAGER] Pokémon con número %d no encontrado" % numero_nacional)
	return {}

## Obtiene la lista completa de Pokémon ordenada por número nacional.
func obtener_lista_pokemon() -> Array:
	var consulta = "SELECT numero_nacional, nombre_interno, nombre FROM Pokemon ORDER BY numero_nacional"

	if ejecutar_consulta(consulta):
		return obtener_resultados()

	return []

## Verifica si un Pokémon existe en la base de datos por su nombre interno.
## Usado por batalla.gd (proveedor_datos seam) para validar equipos antes de crearlos.
func existe_pokemon(nombre_interno: String) -> bool:
	var consulta = "SELECT COUNT(*) as count FROM Pokemon WHERE nombre_interno = '%s'" % nombre_interno

	if ejecutar_consulta(consulta):
		var resultados = obtener_resultados()
		if resultados.size() > 0:
			return resultados[0]["count"] > 0

	return false

## Obtiene la lista de Pokémon ordenada por nombre (no por número nacional).
## Distinta de `obtener_lista_pokemon()` a propósito: batalla.gd usa este orden
## para el fallback de equipos de prueba; reusar la otra query cambiaría qué
## Pokémon se elige primero cuando faltan los preferidos.
func obtener_lista_pokemon_por_nombre() -> Array:
	var consulta = "SELECT nombre_interno, nombre FROM Pokemon ORDER BY nombre"

	if ejecutar_consulta(consulta):
		return obtener_resultados()

	return []

# ==============================================
# CONSULTAS DE TIPOS
# ==============================================

## Obtiene el nombre de un tipo por su ID.
func obtener_nombre_tipo_por_id(tipo_id: int) -> String:
	if tipo_id <= 0:
		return ""

	var consulta = "SELECT nombre FROM Tipos WHERE id = %d" % tipo_id

	if ejecutar_consulta(consulta):
		var resultados = obtener_resultados()
		if resultados.size() > 0:
			return resultados[0]["nombre"]

	print("⚠️ [DATABASE_MANAGER] Tipo con ID %d no encontrado" % tipo_id)
	return "DESCONOCIDO"

## Obtiene el ID de un tipo por su nombre.
func obtener_id_tipo_por_nombre(nombre_tipo: String) -> int:
	var consulta = "SELECT id FROM Tipos WHERE nombre = '%s'" % nombre_tipo.to_upper()

	if ejecutar_consulta(consulta):
		var resultados = obtener_resultados()
		if resultados.size() > 0:
			return resultados[0]["id"]

	print("⚠️ [DATABASE_MANAGER] Tipo '%s' no encontrado" % nombre_tipo)
	return 0

## Obtiene todos los tipos disponibles.
func obtener_todos_los_tipos() -> Array:
	var consulta = "SELECT id, nombre, color_hex FROM Tipos ORDER BY id"

	if ejecutar_consulta(consulta):
		return obtener_resultados()

	return []

## Devuelve la matriz completa de efectividad de tipos como
## { "ATACANTE": { "DEFENSOR": factor } } con factor float (2.0 = súper eficaz,
## 0.5 = poco eficaz, 0.0 = sin efecto). Carga perezosa con caché en memoria:
## la batalla y la IA consultan esta matriz varias veces por turno y no
## conviene ir a SQLite en cada cálculo.
func obtener_matriz_eficacia() -> Dictionary:
	if _matriz_eficacia_cargada:
		return _matriz_eficacia

	_matriz_eficacia = {}
	if esta_conectado():
		var consulta := "SELECT ta.nombre AS atacante, td.nombre AS defensor, e.damage_factor AS factor "
		consulta += "FROM TiposEficacia e "
		consulta += "JOIN Tipos ta ON e.damage_type_id = ta.id "
		consulta += "JOIN Tipos td ON e.target_type_id = td.id"
		if ejecutar_consulta(consulta):
			for fila in obtener_resultados():
				var atacante: String = fila["atacante"]
				if not _matriz_eficacia.has(atacante):
					_matriz_eficacia[atacante] = {}
				_matriz_eficacia[atacante][fila["defensor"]] = float(fila["factor"]) / 100.0
			print("✅ [DATABASE_MANAGER] Matriz de eficacia cargada desde TiposEficacia (%d tipos atacantes)" % _matriz_eficacia.size())
		else:
			push_warning("[DATABASE_MANAGER] No se pudo leer TiposEficacia (¿falta la tabla? Se usará el fallback hardcodeado)")
	else:
		push_warning("[DATABASE_MANAGER] Sin conexión: matriz de eficacia vacía")
	_matriz_eficacia_cargada = true
	return _matriz_eficacia

## Fuerza una recarga de la matriz de eficacia desde la BBDD.
func recargar_matriz_eficacia() -> Dictionary:
	_matriz_eficacia_cargada = false
	return obtener_matriz_eficacia()

## Sincroniza Singleton.tabla_tipos (caché que consumen batalla.gd,
## CombatAnalyzer y tests) con los datos de TiposEficacia de la BBDD.
## Si la tabla está vacía o falla la consulta, se conserva el fallback hardcodeado.
func _sincronizar_tabla_tipos_singleton() -> void:
	var matriz := obtener_matriz_eficacia()
	if matriz.is_empty():
		print("⚠️ [DATABASE_MANAGER] TiposEficacia sin datos: Singleton.tabla_tipos conserva el fallback hardcodeado")
		return
	Singleton.tabla_tipos = matriz
	print("✅ [DATABASE_MANAGER] Singleton.tabla_tipos sincronizada desde la BBDD (%d tipos atacantes)" % matriz.size())

# ==============================================
# CONSULTAS DE NATURALEZAS
# ==============================================

## Obtiene una naturaleza aleatoria de la base de datos.
func obtener_naturaleza_aleatoria() -> String:
	var consulta = "SELECT nombre FROM Naturalezas ORDER BY RANDOM() LIMIT 1"

	if ejecutar_consulta(consulta):
		var resultados = obtener_resultados()
		if resultados.size() > 0:
			return resultados[0]["nombre"]

	# Fallback si no se puede obtener de la BD
	print("⚠️ [DATABASE_MANAGER] Error al obtener naturaleza, usando fallback")
	var naturalezas_fallback = ["SERIA", "DOCIL", "TIMIDA", "ALEGRE", "AUDAZ"]
	return naturalezas_fallback[randi() % naturalezas_fallback.size()]

## Obtiene los datos completos de una naturaleza.
func obtener_datos_naturaleza(nombre_naturaleza: String) -> Dictionary:
	var consulta = "SELECT * FROM Naturalezas WHERE nombre = '%s'" % nombre_naturaleza.to_upper()

	if ejecutar_consulta(consulta):
		var resultados = obtener_resultados()
		if resultados.size() > 0:
			return resultados[0]

	print("⚠️ [DATABASE_MANAGER] Naturaleza '%s' no encontrada" % nombre_naturaleza)
	return {}

## Obtiene todas las naturalezas disponibles.
func obtener_todas_las_naturalezas() -> Array:
	var consulta = "SELECT * FROM Naturalezas ORDER BY nombre"

	if ejecutar_consulta(consulta):
		return obtener_resultados()

	return []

# ==============================================
# CONSULTAS DE MOVIMIENTOS
# ==============================================

## Obtiene los movimientos que un Pokémon puede aprender hasta cierto nivel.
func obtener_movimientos_pokemon_nivel(numero_nacional: int, nivel: int, limite: int = 4) -> Array:
	var consulta = """
	SELECT mc.nombre_interno, mc.nombre, mc.tipo_id, mc.poder, mc.precision, mc.pp, mc.prioridad, mc.descripcion,
		   pm.nivel_aprendizaje, t.nombre as tipo_nombre
	FROM PokemonMovimientos pm
	JOIN Movimientos mc ON pm.movimiento_id = mc.id
	JOIN MetodosAprendizaje ma ON pm.metodo_aprendizaje_id = ma.id
	LEFT JOIN Tipos t ON mc.tipo_id = t.id
	WHERE pm.pokemon_numero = %d
	AND ma.nombre = 'level-up'
	""" % numero_nacional + MovimientosIniciales.SQL_ORDEN_RUBI % nivel

	if ejecutar_consulta(consulta):
		return MovimientosIniciales.seleccionar(obtener_resultados(), limite)

	return []

## Obtiene los datos completos de un movimiento.
func obtener_datos_movimiento(nombre_interno: String) -> Dictionary:
	var consulta = """
	SELECT mc.*, t.nombre as tipo_nombre
	FROM Movimientos mc
	LEFT JOIN Tipos t ON mc.tipo_id = t.id
	WHERE mc.nombre_interno = '%s'
	""" % nombre_interno

	if ejecutar_consulta(consulta):
		var resultados = obtener_resultados()
		if resultados.size() > 0:
			return resultados[0]

	print("⚠️ [DATABASE_MANAGER] Movimiento '%s' no encontrado" % nombre_interno)
	return {}

## Datos de concurso de todos los movimientos (gContestMoves), por numero_movimiento:
## nombre_interno, nombre, concurso_categoria, concurso_efecto, concurso_combo_inicio y
## concurso_combos_json. Lo carga una vez DatosConcurso.
func obtener_movimientos_concurso() -> Array:
	if not esta_conectado():
		return []
	if db.query_with_bindings("SELECT numero_movimiento, nombre_interno, nombre, concurso_categoria, "
			+ "concurso_efecto, concurso_combo_inicio, concurso_combos_json, concurso_descripcion FROM Movimientos "
			+ "WHERE numero_movimiento > ? ORDER BY numero_movimiento", [0]):
		return db.get_query_result()
	return []

## numero_nacional de una especie por nombre interno (0 si no existe).
func obtener_numero_nacional(nombre_interno: String) -> int:
	if not esta_conectado() or nombre_interno.is_empty():
		return 0
	if db.query_with_bindings("SELECT numero_nacional FROM Pokemon WHERE nombre_interno = ? LIMIT 1",
			[nombre_interno.to_upper()]):
		var filas: Array = db.get_query_result()
		if not filas.is_empty() and filas[0].get("numero_nacional") != null:
			return int(filas[0]["numero_nacional"])
	return 0

## Tabla ConcursoEfectos (gContestEffects): id, nombre, tipo, atractivo, interferencia.
func obtener_efectos_concurso() -> Array:
	if not esta_conectado():
		return []
	if db.query_with_bindings("SELECT * FROM ConcursoEfectos WHERE id >= ? ORDER BY id", [0]):
		return db.get_query_result()
	return []

## Tabla ConcursoRivales (gContestOpponents) completa, por id.
func obtener_rivales_concurso() -> Array:
	if not esta_conectado():
		return []
	if db.query_with_bindings("SELECT * FROM ConcursoRivales WHERE id >= ? ORDER BY id", [0]):
		return db.get_query_result()
	return []

## Tabla PalabrasFacilesGrupos (EC_GROUP_* de pokeruby): id, referencia, nombre, tipo.
func obtener_grupos_palabras_faciles() -> Array:
	if not esta_conectado():
		return []
	if db.query_with_bindings("SELECT * FROM PalabrasFacilesGrupos WHERE id >= ? ORDER BY id", [0]):
		return db.get_query_result()
	return []

## Todas las PALABRAS FÁCILES (orden de la ROM: grupo e índice): id, grupo_id,
## indice, texto, numero_nacional, numero_movimiento y, en los grupos de
## POKéMON, el nombre_interno de la especie. Lo carga una vez PalabrasFaciles.
func obtener_palabras_faciles() -> Array:
	if not esta_conectado():
		return []
	if db.query_with_bindings("SELECT p.id, p.grupo_id, p.indice, p.texto, p.numero_nacional, "
			+ "p.numero_movimiento, e.nombre_interno AS especie FROM PalabrasFaciles p "
			+ "LEFT JOIN Pokemon e ON e.numero_nacional = p.numero_nacional "
			+ "WHERE p.id >= ? ORDER BY p.grupo_id, p.indice", [0]):
		return db.get_query_result()
	return []

## Obtiene movimientos básicos de un tipo específico.
func obtener_movimientos_basicos_por_tipo(tipo_nombre: String) -> Array:
	var movimientos_por_tipo = {
		"FUEGO": ["TACKLE", "EMBER", "GROWL", "SCRATCH"],
		"AGUA": ["TACKLE", "WATER-GUN", "GROWL", "POUND"],
		"PLANTA": ["TACKLE", "VINE-WHIP", "GROWL", "ABSORB"],
		"ELECTRICO": ["TACKLE", "THUNDER-SHOCK", "GROWL", "QUICK-ATTACK"],
		"NORMAL": ["TACKLE", "SCRATCH", "GROWL", "POUND"],
		"TIERRA": ["TACKLE", "SAND-ATTACK", "GROWL", "DIG"],
		"ROCA": ["TACKLE", "ROCK-THROW", "HARDEN", "ROLLOUT"],
		"PSIQUICO": ["TACKLE", "CONFUSION", "GROWL", "TELEPORT"],
		"DRAGON": ["TACKLE", "DRAGON-RAGE", "LEER", "TWISTER"]
	}

	if movimientos_por_tipo.has(tipo_nombre):
		return movimientos_por_tipo[tipo_nombre]
	else:
		return movimientos_por_tipo["NORMAL"]

# ==============================================
# CONSULTAS DE OBJETOS (para la mochila)
# ==============================================

## Obtiene todos los objetos de un bolsillo específico.
func obtener_objetos_por_bolsillo(bolsillo_id: int) -> Array:
	var consulta = "SELECT * FROM Objetos WHERE bolsillo_id = %d ORDER BY nombre" % bolsillo_id

	if ejecutar_consulta(consulta):
		return obtener_resultados()

	return []

## Obtiene los datos de un objeto por su nombre interno.
func obtener_datos_objeto(nombre_interno: String) -> Dictionary:
	var consulta = "SELECT * FROM Objetos WHERE upper(nombre_interno) = upper('%s')" % nombre_interno

	if ejecutar_consulta(consulta):
		var resultados = obtener_resultados()
		if resultados.size() > 0:
			return resultados[0]

	print("⚠️ [DATABASE_MANAGER] Objeto '%s' no encontrado" % nombre_interno)
	return {}

## Obtiene el nombre_interno de un objeto por su ID en la tabla Objetos.
## Usado por ControladorBaya para entregar la baya correcta al cosechar.
func obtener_nombre_interno_objeto_por_id(id: int) -> String:
	var consulta: String = "SELECT nombre_interno FROM Objetos WHERE id = %d" % id
	if ejecutar_consulta(consulta):
		var resultados: Array = obtener_resultados()
		if not resultados.is_empty():
			return resultados[0].get("nombre_interno", "")
	print("⚠️ [DATABASE_MANAGER] Objeto con id %d no encontrado" % id)
	return ""

## Fila de la tabla Habilidades para `clave`, con caché. `clave` es el
## nombre_interno (lo que guarda BasePokemon.habilidad); como respaldo acepta el
## nombre inglés (nombre_en, "OVERGROW" / "Overgrow" / "Compound Eyes"), que es
## lo que guardaban las partidas antiguas. {} si no existe.
func obtener_datos_habilidad(clave: String) -> Dictionary:
	var normalizada := clave.to_upper().replace(" ", "").strip_edges()
	if normalizada.is_empty():
		return {}
	if _cache_habilidades.has(normalizada):
		return _cache_habilidades[normalizada]
	if not esta_conectado():
		return {}
	var datos: Dictionary = {}
	var consulta := """
		SELECT * FROM Habilidades
		WHERE nombre_interno = ? OR REPLACE(UPPER(nombre_en), ' ', '') = ?
		ORDER BY nombre_interno = ? DESC LIMIT 1"""
	if db.query_with_bindings(consulta, [normalizada, normalizada, normalizada]):
		var resultados: Array = db.get_query_result()
		if not resultados.is_empty():
			datos = resultados[0]
	_cache_habilidades[normalizada] = datos
	return datos

## Fila de la tabla Bayas (datos de gBerries de pokeruby) para el objeto
## `objeto_id` (Objetos.id), con caché. {} si no es una baya de 3ª generación
## (p. ej. las de 4ª gen que están en Objetos pero no se pueden plantar).
func obtener_datos_baya(objeto_id: int) -> Dictionary:
	if _cache_bayas.has(objeto_id):
		return _cache_bayas[objeto_id]
	if not esta_conectado():
		return {}
	var datos: Dictionary = {}
	if db.query_with_bindings("SELECT * FROM Bayas WHERE objeto_id = ?", [objeto_id]):
		var resultados: Array = db.get_query_result()
		if not resultados.is_empty():
			datos = resultados[0]
	_cache_bayas[objeto_id] = datos
	return datos

## Fila de la tabla Bayas por `numero` (índice de gBerries + 1: CHERI = 1 …
## ENIGMA = 43), con la misma caché que `obtener_datos_baya`. {} si no existe.
## La usan los rivales de la LICUABAYAS (ReglasLicuadora.bayas_rivales_desde_bd).
func obtener_datos_baya_por_numero(numero: int) -> Dictionary:
	if not esta_conectado():
		return {}
	if db.query_with_bindings("SELECT objeto_id FROM Bayas WHERE numero = ?", [numero]):
		var resultados: Array = db.get_query_result()
		if not resultados.is_empty():
			return obtener_datos_baya(int(resultados[0]["objeto_id"]))
	return {}

## Obtiene la información de una MT/MO para mostrar en la mochila.
func obtener_info_maquina(nombre_interno_objeto: String) -> String:
	var consulta = """
	SELECT
		m.nombre AS nombre_movimiento
	FROM Objetos o
	JOIN MaquinasMovimientos mm ON o.id = mm.objeto_id
	JOIN Movimientos m ON mm.movimiento_id = m.id
	WHERE o.nombre_interno = '%s'
	""" % nombre_interno_objeto

	if ejecutar_consulta(consulta):
		var resultados = obtener_resultados()
		if resultados.size() > 0:
			var nombre_movimiento = resultados[0]["nombre_movimiento"]

			if nombre_interno_objeto.begins_with("MO"):
				var numero_mo = "%02d" % nombre_interno_objeto.substr(2).to_int()  # dos dígitos: "MO01"
				return "[img]res://UI/mochila/txt_mo.png[/img]%s %s" % [numero_mo, nombre_movimiento]
			elif nombre_interno_objeto.begins_with("MT"):
				var numero_mt = "%02d" % nombre_interno_objeto.substr(2).to_int()  # dos dígitos: "MT09"
				return "MT%s %s" % [numero_mt, nombre_movimiento]

	print("⚠️ [DATABASE_MANAGER] No se pudo obtener información para la máquina '%s'" % nombre_interno_objeto)
	return ""

## Obtiene la descripción del movimiento de una MT/MO para mostrar en la mochila.
func obtener_descripcion_maquina(nombre_interno_objeto: String) -> String:
	var consulta = """
	SELECT
		m.descripcion AS descripcion_movimiento
	FROM Objetos o
	JOIN MaquinasMovimientos mm ON o.id = mm.objeto_id
	JOIN Movimientos m ON mm.movimiento_id = m.id
	WHERE o.nombre_interno = '%s'
	""" % nombre_interno_objeto

	if ejecutar_consulta(consulta):
		var resultados = obtener_resultados()
		if resultados.size() > 0:
			var descripcion_movimiento = resultados[0]["descripcion_movimiento"]
			return descripcion_movimiento if descripcion_movimiento != null else ""

	print("⚠️ [DATABASE_MANAGER] No se pudo obtener descripción para la máquina '%s'" % nombre_interno_objeto)
	return ""

## Obtiene todos los bolsillos activos de la mochila.
func obtener_bolsillos_activos() -> Array:
	var consulta = "SELECT * FROM Bolsillos WHERE activo = 1 ORDER BY id"

	if ejecutar_consulta(consulta):
		return obtener_resultados()

	return []

# ==============================================
# CONSULTAS DE ENTRENADORES
# ==============================================

## Obtiene los datos de un entrenador por su ID.
func obtener_datos_entrenador(entrenador_id: int) -> Dictionary:
	var consulta = "SELECT * FROM Entrenadores WHERE id = %d" % entrenador_id

	if ejecutar_consulta(consulta):
		var resultados = obtener_resultados()
		if resultados.size() > 0:
			return resultados[0]

	print("⚠️ [DATABASE_MANAGER] Entrenador con ID %d no encontrado" % entrenador_id)
	return {}

## Crea un nuevo entrenador y devuelve su ID.
func crear_entrenador(nombre: String, sexo: String = "M", es_jugador: bool = false) -> int:
	var consulta = """
	INSERT INTO Entrenadores (nombre, sexo, es_jugador, dinero)
	VALUES ('%s', '%s', %s, 3000)
	""" % [nombre, sexo, es_jugador]

	if ejecutar_consulta(consulta):
		# Obtener el ID del entrenador recién creado
		var consulta_id = "SELECT last_insert_rowid() as id"
		if ejecutar_consulta(consulta_id):
			var resultado = obtener_resultados()
			if resultado.size() > 0:
				var nuevo_id = resultado[0]["id"]
				print("✅ [DATABASE_MANAGER] Entrenador '%s' creado con ID %d" % [nombre, nuevo_id])
				return nuevo_id

	print("❌ [DATABASE_MANAGER] Error al crear entrenador '%s'" % nombre)
	return -1

## Lee lista_entrenadores.json una sola vez y lo indexa por id. Antes se
## parseaba el JSON entero (~388 KB) en cada llamada y cada entrenador del
## Overworld llama dos veces en su _ready: ~6,7 s al continuar la partida.
func _get_entrenadores_por_id() -> Dictionary:
	if _entrenadores_cargados:
		return _entrenadores_por_id
	_entrenadores_cargados = true
	_entrenadores_por_id.clear()

	if not FileAccess.file_exists(RUTA_ENTRENADORES):
		print("❌ [DATABASE_MANAGER] Archivo de entrenadores no encontrado: %s" % RUTA_ENTRENADORES)
		return _entrenadores_por_id

	var archivo := FileAccess.open(RUTA_ENTRENADORES, FileAccess.READ)
	if archivo == null:
		print("❌ [DATABASE_MANAGER] Error al abrir archivo de entrenadores: %s" % RUTA_ENTRENADORES)
		return _entrenadores_por_id
	var json_string := archivo.get_as_text()
	archivo.close()

	var json := JSON.new()
	if json.parse(json_string) != OK:
		print("❌ [DATABASE_MANAGER] Error al parsear JSON de entrenadores: %s" % json.get_error_message())
		return _entrenadores_por_id
	if not json.data is Array:
		print("❌ [DATABASE_MANAGER] El archivo JSON no contiene un array de entrenadores")
		return _entrenadores_por_id

	for entrenador_data: Variant in json.data:
		if entrenador_data is Dictionary and (entrenador_data as Dictionary).has("id"):
			var id_entrenador := int((entrenador_data as Dictionary)["id"])
			# Como el bucle original: ante ids duplicados gana el primero.
			if not _entrenadores_por_id.has(id_entrenador):
				_entrenadores_por_id[id_entrenador] = entrenador_data
	print("✅ [DATABASE_MANAGER] Lista de entrenadores cargada: %d entrenadores" % _entrenadores_por_id.size())
	return _entrenadores_por_id

## Fuerza a releer lista_entrenadores.json en la próxima consulta.
func invalidar_cache_entrenadores() -> void:
	_entrenadores_cargados = false
	_entrenadores_por_id.clear()

## Obtiene datos de un entrenador desde el archivo JSON lista_entrenadores.json
## (cacheado en memoria). Cada llamada devuelve una instancia nueva.
func get_entrenador(entrenador_id: int) -> DatosEntrenador:
	var entrada: Variant = _get_entrenadores_por_id().get(entrenador_id, null)
	if entrada is Dictionary:
		# Copia profunda: el consumidor nunca puede alterar la caché.
		var entrenador_data: Dictionary = (entrada as Dictionary).duplicate(true)
		# Crear instancia de DatosEntrenador
		var entrenador = DatosEntrenador.new()

		# Asignar propiedades básicas
		entrenador.clase_entrenador = entrenador_data.get("clase_entrenador", "ENTRENADOR")
		entrenador.ratio_dinero = int(entrenador_data.get(
			"ratio_dinero",
			TiposEntrenadorData.obtener_ratio_dinero(str(entrenador_data.get("clase_entrenador", "ENTRENADOR")))
		))
		entrenador.num_sprite = int(entrenador_data.get("num_sprite", 1))
		entrenador.nombre = entrenador_data.get("nombre", "DESCONOCIDO")
		entrenador.frase_derrota = str(entrenador_data.get("frase_derrota", "..."))
		entrenador.sexo = entrenador_data.get("sexo", "M")
		entrenador.tipo_batalla = str(entrenador_data.get("tipo_batalla", "SIMPLE")).to_upper()
		if entrenador.tipo_batalla != "DOBLE":
			entrenador.tipo_batalla = "SIMPLE"
		entrenador.musica_id = entrenador_data.get("musica_id", "batalla_entrenador")
		entrenador.jingle_id = int(entrenador_data.get("jingle_id", 0))

		# Asignar objetos
		if entrenador_data.has("objetos") and entrenador_data["objetos"] is Array:
			entrenador.objetos.clear()
			for objeto in entrenador_data["objetos"]:
				if typeof(objeto) == TYPE_STRING:
					entrenador.objetos.append(str(objeto))

		# Cargar pokémon del entrenador
		if entrenador_data.has("pokemon") and entrenador_data["pokemon"] is Array:
			entrenador.set_pokemon_desde_diccionarios(entrenador_data["pokemon"])

		print("✅ [DATABASE_MANAGER] Entrenador '%s' (ID: %d) cargado desde JSON" % [entrenador.nombre, entrenador_id])
		return entrenador

	print("⚠️ [DATABASE_MANAGER] Entrenador con ID %d no encontrado en JSON" % entrenador_id)
	return null

# ==============================================
# FUNCIONES DE UTILIDAD Y DEBUG
# ==============================================

## Obtiene estadísticas generales de la base de datos.
func obtener_estadisticas_bd() -> Dictionary:
	var stats = {}

	var consultas_stats = {
		"pokemon": "SELECT COUNT(*) as total FROM Pokemon",
		"movimientos": "SELECT COUNT(*) as total FROM Movimientos",
		"tipos": "SELECT COUNT(*) as total FROM Tipos",
		"naturalezas": "SELECT COUNT(*) as total FROM Naturalezas",
		"objetos": "SELECT COUNT(*) as total FROM Objetos",
		"entrenadores": "SELECT COUNT(*) as total FROM Entrenadores"
	}

	for tabla in consultas_stats:
		if ejecutar_consulta(consultas_stats[tabla]):
			var resultado = obtener_resultados()
			if resultado.size() > 0:
				stats[tabla] = resultado[0]["total"]
			else:
				stats[tabla] = 0
		else:
			stats[tabla] = -1

	return stats

## Imprime estadísticas de la base de datos.
func debug_estadisticas():
	print("=== ESTADÍSTICAS DE LA BASE DE DATOS ===")
	var stats = obtener_estadisticas_bd()

	for tabla in stats:
		var total = stats[tabla]
		var estado = "✅" if total > 0 else ("❌" if total == -1 else "⚠️")
		print("  %s %s: %d registros" % [estado, tabla.capitalize(), total])

	print("=========================================")

## Lista todas las tablas disponibles en la base de datos.
func debug_tablas_disponibles():
	var consulta = "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"

	if ejecutar_consulta(consulta):
		var resultados = obtener_resultados()
		print("=== TABLAS DISPONIBLES ===")
		for tabla in resultados:
			print("  📋 %s" % tabla["name"])
		print("===========================")
	else:
		print("❌ [DATABASE_MANAGER] Error al obtener lista de tablas")

## Cierra la conexión al salir.
func _exit_tree():
	desconectar_base_datos()

# ==============================================
# ENCUENTROS SALVAJES
# ==============================================

## Lee un JSON de encuentros indexando las claves en minúsculas (nombre de archivo de la
## escena, sin distinguir mayúsculas). Devuelve {} si falta o no se puede parsear.
func _leer_json_encuentros(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		print("❌ [DATABASE_MANAGER] %s no encontrado" % path.get_file())
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		print("❌ [DATABASE_MANAGER] Error al parsear %s: %s" % [path.get_file(), json.get_error_message()])
		return {}
	var tabla: Dictionary = {}
	for clave: String in json.data:
		tabla[clave.to_lower()] = json.data[clave]
	return tabla

## Devuelve (y cachea) la tabla de encuentros activa: la original o, con
## `usar_tabla_alternativa`, la alternativa superpuesta mapa a mapa sobre la original.
func _get_tabla_encuentros() -> Dictionary:
	if _tabla_encuentros_cargada:
		return _tabla_encuentros

	_tabla_encuentros = _leer_json_encuentros(RUTA_ENCUENTROS)
	if usar_tabla_alternativa:
		var alternativa := _leer_json_encuentros(RUTA_ENCUENTROS_ALTERNATIVO)
		for mapa: String in alternativa:
			_tabla_encuentros[mapa] = alternativa[mapa]
	_tabla_encuentros_cargada = true
	print("✅ [DATABASE_MANAGER] Tabla de encuentros cargada (%s): %d mapas" % [
		"alternativa" if usar_tabla_alternativa else "original", _tabla_encuentros.size()])
	return _tabla_encuentros

## Tabla usada por los encuentros y la pantalla ÁREA de la Pokédex.
## Vista de solo lectura: los consumidores no deben modificar este diccionario.
func obtener_tabla_encuentros_activa() -> Dictionary:
	return _get_tabla_encuentros()


## Selecciona un Pokémon salvaje aleatorio según la tabla de encuentros del mapa.
## tipo : "hierba" | "agua" | "roca" | "pesca"
## rod  : "vieja" | "buena" | "super"  — solo relevante cuando tipo == "pesca"
## Devuelve {nombre_interno, nivel} o {} si no hay datos para ese mapa/tipo.
func seleccionar_pokemon_salvaje(mapa_id: String, tipo: String = "hierba", rod: String = "vieja") -> Dictionary:
	var tabla := _get_tabla_encuentros()
	mapa_id = mapa_id.to_lower()

	if not tabla.has(mapa_id):
		return {}

	var zona: Dictionary = tabla[mapa_id].get(tipo, {})
	var slots_todos: Array = zona.get("encuentros", [])
	if slots_todos.is_empty():
		return {}

	# Seleccionar pesos y segmento de slots según tipo
	var pesos: Array
	var slots: Array
	match tipo:
		"hierba":
			pesos = PESOS_SLOTS_HIERBA
			slots = slots_todos
		"agua":
			pesos = PESOS_SLOTS_AGUA
			slots = slots_todos
		"roca":
			pesos = PESOS_SLOTS_ROCA
			slots = slots_todos
		"pesca":
			# Los 10 slots del JSON están concatenados: 0-1 vieja, 2-4 buena, 5-9 super
			match rod:
				"vieja":
					pesos = PESOS_SLOTS_PESCA_VIEJA
					slots = slots_todos.slice(0, 2)
				"buena":
					pesos = PESOS_SLOTS_PESCA_BUENA
					slots = slots_todos.slice(2, 5)
				_:  # super
					pesos = PESOS_SLOTS_PESCA_SUPER
					slots = slots_todos.slice(5, 10)
		_:
			pesos = PESOS_SLOTS_HIERBA
			slots = slots_todos

	var limite: int = min(slots.size(), pesos.size())
	if limite == 0:
		return {}

	var total_peso: int = 0
	for i in range(limite):
		total_peso += pesos[i]

	var roll: int = randi() % total_peso
	var acumulado: int = 0
	var slot: Dictionary = slots[0]
	for i in range(limite):
		acumulado += pesos[i]
		if roll < acumulado:
			slot = slots[i]
			break

	var nivel_min: int = slot.get("nivel_min", 5)
	var nivel_max: int = slot.get("nivel_max", nivel_min)
	var nivel: int = nivel_min + randi() % (nivel_max - nivel_min + 1)

	return {
		"nombre_interno": slot.get("nombre_interno", ""),
		"nivel": nivel
	}

## Devuelve la probabilidad de encuentro para un mapa y tipo dado, según config_encuentros.json.
## Rango esperado: 0.0 a 1.0 (ej. 0.1 para 10% de probabilidad).
## Devuelve 0.1 por defecto si no hay datos.
func obtener_probabilidad_encuentro(mapa_id: String, tipo: String = "hierba") -> float:
	var tabla := _get_tabla_encuentros()
	mapa_id = mapa_id.to_lower()
	if tabla.has(mapa_id) and tabla[mapa_id].has(tipo) and tabla[mapa_id][tipo].has("ratio"):
		print("📊 [DATABASE_MANAGER] Probabilidad de encuentro para mapa '%s', tipo '%s': %f%%" % [mapa_id, tipo, float(tabla[mapa_id][tipo]["ratio"])])
		return float(tabla[mapa_id][tipo].get("ratio", 10.0)) / 100.0
	return 0.1  # Valor por defecto si no se encuentra el mapa/tipo

## Obtiene los nombres de los bolsillos de la mochila.
## [nombre, cifras]
func obtener_nombres_bolsillos() -> Array:
	# Traer también la columna `cifras` (0,2,3) para que la UI sepa cuántos dígitos reservar
	var consulta = "SELECT nombre, cifras FROM Bolsillos WHERE activo = 1 ORDER BY id"

	if ejecutar_consulta(consulta):
		return obtener_resultados()

	return []

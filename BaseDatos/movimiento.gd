extends RefCounted
class_name Movimiento

# Propiedades principales del movimiento
var nombre: String  # Nombre mostrable del movimiento
var pp_act: int     # PP actuales
var pp_mas: int     # Cantidad de usos de Más PP aplicados (0..3)
var pp_tot: int     # PP totales tras aplicar el bonus de Más PP
var datos: Dictionary  # Datos completos del movimiento

# Constructor de la clase
func _init(p_nombre: String = "", p_pp_act: int = 0, p_pp_mas: int = 0, p_pp_tot: int = 0, p_datos: Dictionary = {}):
	nombre = p_nombre
	pp_act = p_pp_act
	pp_mas = p_pp_mas
	pp_tot = p_pp_tot
	datos = p_datos

# === GETTERS PARA FACILITAR EL ACCESO A LOS DATOS ===

## Obtiene el nombre del movimiento.
func get_nombre_interno() -> String:
	return datos.get("nombre_interno", "")

## Obtiene el nombre del movimiento en mayúsculas.
func get_tipo() -> String:
	return datos.get("tipo", "")

## Obtiene la potencia del movimiento.
func get_potencia() -> int:
	var valor = datos.get("potencia", -1)
	return valor if typeof(valor) == TYPE_INT else -1

## Obtiene la precisión del movimiento.
func get_precision() -> int:
	var valor = datos.get("precision", -1)
	return valor if typeof(valor) == TYPE_INT else -1

## Obtiene los PP máximos del movimiento.
func get_max_pp() -> int:
	return datos.get("max_pp", 0)

## Obtiene la prioridad del movimiento.
func get_prioridad() -> int:
	return datos.get("prioridad", 0)

## Obtiene el ID de la categoría de daño del movimiento.
## REGLA (decomp, IS_TYPE_PHYSICAL): en Gen 3 físico o especial depende del tipo;
## la BD trae la categoría moderna y solo se usa para distinguir los de estado.
func get_categoria_dano_id() -> int:
	return categoria_por_tipo(get_tipo(), int(datos.get("categoria_dano_id", 0)))

static func categoria_por_tipo(tipo: String, categoria: int) -> int:
	if categoria not in [1, 2] or tipo in ["", "???"]:
		return categoria
	return 1 if tipo in ["NORMAL", "LUCHA", "VOLADOR", "VENENO", "TIERRA", "ROCA", "BICHO", "FANTASMA", "ACERO"] else 2

## true si el movimiento es de contacto (F_MAKES_CONTACT; PIEL TOSCA, ELEC.
## ESTÁT. y similares solo reaccionan a estos).
func hace_contacto() -> bool:
	return int(_dato_combate("contacto", 0)) == 1

## true si es un movimiento sonoro (gSoundMovesTable; INSONORIZAR lo bloquea).
func es_sonoro() -> bool:
	return int(_dato_combate("sonido", 0)) == 1

## `.effect` del decomp (EFFECT_BURN_HIT...), "" si no se conoce.
func get_efecto() -> String:
	return str(_dato_combate("efecto", ""))

## `.secondaryEffectChance` del decomp (0-100).
func get_prob_secundario() -> int:
	return int(_dato_combate("prob_secundario", 0))

# === DATOS DE CONCURSO (gContestMoves / gContestEffects) ===

## Categorías de concurso en el orden del enum CONTEST_CATEGORY_* de pokeruby
## (nombres de los iconos de la ROM española).
enum CategoriaConcurso { CARISMA, BELLEZA, DULZURA, INGENIO, DUREZA }
const NOMBRES_CATEGORIA_CONCURSO: Array[String] = ["CARISMA", "BELLEZA", "DULZURA", "INGENIO", "DUREZA"]

## `gContestMoves[m].contestCategory` (CategoriaConcurso).
func get_categoria_concurso() -> int:
	return int(_dato_combate("concurso_categoria", CategoriaConcurso.CARISMA))

## Nombre de la categoría de concurso ("DUREZA"...).
func get_nombre_categoria_concurso() -> String:
	return NOMBRES_CATEGORIA_CONCURSO[clampi(get_categoria_concurso(), 0, NOMBRES_CATEGORIA_CONCURSO.size() - 1)]

## `gContestMoves[m].effect` (enum CONTEST_EFFECT_*).
func get_efecto_concurso() -> int:
	return int(_dato_combate("concurso_efecto", 0))

## `gContestEffects[efecto].appeal`: la ficha muestra appeal / 10 corazones.
func get_atractivo() -> int:
	return int(_dato_combate("concurso_atractivo", 0))

## `gContestEffects[efecto].jam`: la ficha muestra jam / 10 corazones negros.
func get_interferencia() -> int:
	return int(_dato_combate("concurso_interferencia", 0))

## `gContestEffectStrings[efecto]` (texto oficial ES, con el salto de línea de la ROM).
func get_descripcion_concurso() -> String:
	return str(_dato_combate("concurso_descripcion", ""))

## `gContestMoves[m].comboStarterId`: id de iniciador de combo (0 = no inicia ninguno).
func get_combo_inicio() -> int:
	return int(_dato_combate("concurso_combo_inicio", 0))

## `gContestMoves[m].comboMoves` sin ceros: iniciadores que este movimiento completa.
func get_combos() -> Array[int]:
	var combos: Array[int] = []
	var lista: Variant = JSON.parse_string(str(_dato_combate("concurso_combos_json", "[]")))
	if lista is Array:
		for valor in lista:
			combos.append(int(valor))
	return combos

## Datos de combate que no viajan en `datos` cuando el movimiento se construyó
## a mano (partidas guardadas, generador de movimientos...): se leen de la tabla
## Movimientos por nombre interno y se cachean.
static var _cache_combate: Dictionary = {}

func _dato_combate(clave: String, defecto: Variant) -> Variant:
	if datos.has(clave):
		return datos[clave]
	var nombre_interno := get_nombre_interno()
	if nombre_interno.is_empty():
		return defecto
	if not _cache_combate.has(nombre_interno):
		var fila: Dictionary = {}
		if DatabaseManager != null and DatabaseManager.esta_conectado():
			fila = DatabaseManager.obtener_datos_movimiento(nombre_interno)
		_cache_combate[nombre_interno] = fila
	var fila_cache: Dictionary = _cache_combate[nombre_interno]
	return fila_cache.get(clave, defecto) if fila_cache.get(clave) != null else defecto

func get_objetivo_id() -> int:
	return int(datos.get("objetivo_id", 10)) if datos.get("objetivo_id") != null else 10

## Obtiene el ID del efecto secundario del movimiento.
func get_descripcion() -> String:
	return datos.get("descripcion", "")

# === MÉTODOS DE UTILIDAD ===

func get_info() -> String:
	"""Obtiene la información completa del movimiento como string para debugging."""
	return "Movimiento(nombre=%s, pp=%d/%d, tipo=%s, potencia=%d)" % [nombre, pp_act, pp_tot, get_tipo(), get_potencia()]

func es_valido() -> bool:
	"""Verifica si el movimiento tiene datos válidos."""
	return nombre != "" and pp_tot > 0

## Restaura los PP actuales a los PP totales.
func restaurar_pp() -> void:
	pp_act = pp_tot


## Usa una cantidad específica de PP.
## Retorna true si se pudieron usar, false si no hay suficientes PP.
func usar_pp(cantidad: int = 1) -> bool:
	if pp_act >= cantidad:
		pp_act -= cantidad
		return true
	return false

## Verifica si el movimiento tiene PP disponibles.
func tiene_pp() -> bool:
	return pp_act > 0

## Recalcula los PP totales basándose en los PP base más los adicionales.
func calcular_pp_totales() -> void:
	var pp_base = get_max_pp()
	var pp_up_usados = clamp(pp_mas, 0, 3)
	pp_tot = pp_base + int(floor(float(pp_base) * float(pp_up_usados) / 5.0))
	pp_act = clamp(pp_act, 0, pp_tot)

# === MÉTODOS ESTÁTICOS PARA CREAR MOVIMIENTOS ===

## Crea un movimiento por defecto (Placaje).
static func crear_por_defecto() -> Movimiento:
	var datos_defecto = {
		"nombre_interno": "PLACAJE",
		"nombre": "PLACAJE",
		"tipo": "NORMAL",
		"potencia": 40,
		"precision": 100,
		"max_pp": 35,
		"prioridad": 0,
		"descripcion": "Un ataque de tipo Normal."
	}
	
	return Movimiento.new(
		"PLACAJE",     # Nombre en español y mayúsculas
		35,            # PP actuales
		0,             # PP adicionales
		35,            # PP totales
		datos_defecto  # Datos completos
	)

## Crea un movimiento vacío (sin datos).
static func crear_vacio() -> Movimiento:
	return Movimiento.new("", 0, 0, 0, {})

## Crea un movimiento con PP completos desde una fila de la tabla Movimientos
## (`DatabaseManager.obtener_datos_movimiento`: `mc.*` + `tipo_nombre`). Es la ÚNICA
## construcción de `datos` desde la BD: la comparten el aprendizaje por nivel
## (`BasePokemon.get_movs_nivel`), la crianza (`DatosCrianza.crear_movimiento`) y
## la carga de partidas (`desde_guardado`).
static func desde_fila_bd(fila: Dictionary) -> Movimiento:
	var pp: int = int(fila["pp"]) if fila.get("pp") != null else 0
	var datos_movimiento: Dictionary = {
		"nombre_interno": str(fila["nombre_interno"]),
		"nombre": str(fila["nombre"]),
		"tipo": str(fila["tipo_nombre"]) if fila.get("tipo_nombre") != null else "NORMAL",
		"potencia": int(fila["poder"]) if fila.get("poder") != null else 0,
		"precision": int(fila["precision"]) if fila.get("precision") != null else 0,
		"max_pp": pp,
		"prioridad": int(fila["prioridad"]) if fila.get("prioridad") != null else 0,
		"categoria_dano_id": int(fila["categoria_dano_id"]) if fila.get("categoria_dano_id") != null else 0,
		"objetivo_id": fila.get("objetivo_id", null),
		"descripcion": str(fila["descripcion"]) if fila.get("descripcion") != null else "",
	}
	var completos: Dictionary = fila.duplicate(true)
	completos.merge(datos_movimiento, true)
	return Movimiento.new(str(fila["nombre"]), pp, 0, pp, completos)

# === GUARDADO (ver MovimientoGuardado) ===

## Catálogo de nombres (`MovimientoGuardado.construir_catalogo`) de la tabla
## Movimientos; se carga una vez, al primer uso con la BD conectada.
static var _catalogo: Dictionary = {}

## Catálogo de resolución nombre interno / mostrable. {} si no hay BD conectada.
static func catalogo() -> Dictionary:
	if not _catalogo.is_empty():
		return _catalogo
	if DatabaseManager == null or not DatabaseManager.esta_conectado():
		return {}
	var filas: Array = []
	if DatabaseManager.ejecutar_consulta("SELECT nombre_interno, nombre, pp FROM Movimientos"):
		filas = DatabaseManager.obtener_resultados().duplicate()
	_catalogo = MovimientoGuardado.construir_catalogo(filas)
	return _catalogo

## Crea un movimiento desde su entrada de guardado: el diccionario actual
## (`a_guardado`) o cualquier formato que acepte `MovimientoGuardado.normalizar`
## (cadena legada "Movimiento(nombre=GRUÑIDO, ...)", nombre suelto...). Los datos
## salen de la BD por `nombre_interno`; se conservan `pp_act` y `pp_mas` guardados.
## Si el nombre no existe en la BD se conserva el movimiento con lo poco que se
## sabe de él (y un aviso). null solo si la entrada no es reconocible.
static func desde_guardado(entrada: Variant) -> Movimiento:
	const Record = preload("res://BaseDatos/move_save_record.gd")
	if entrada is Dictionary and entrada.has("move_record_version"):
		if not Record.valid(entrada): return null
		var fields: Dictionary = Record.decode_fields(entrada)
		return Movimiento.new(str(fields.name), int(fields.pp_act), int(fields.pp_mas), int(fields.pp_tot), fields.data)
	var norm: Dictionary = MovimientoGuardado.normalizar(entrada, catalogo())
	if norm.is_empty():
		push_warning("[Movimiento] Entrada de guardado no reconocida, se descarta: %s" % str(entrada))
		return null
	var interno: String = str(norm["nombre_interno"])
	if bool(norm["resuelto"]):
		var fila: Dictionary = DatabaseManager.obtener_datos_movimiento(interno)
		if not fila.is_empty():
			var movimiento: Movimiento = desde_fila_bd(fila)
			movimiento.pp_mas = int(norm["pp_mas"])
			movimiento.pp_tot = int(norm["pp_tot"])
			movimiento.pp_act = int(norm["pp_act"])
			return movimiento
	push_warning("[Movimiento] Movimiento '%s' no existe en la BD; se conserva sin datos de combate" % interno)
	return Movimiento.new(str(norm.get("nombre", interno)), int(norm["pp_act"]), int(norm["pp_mas"]), int(norm["pp_tot"]), {
		"nombre_interno": interno,
		"nombre": str(norm.get("nombre", interno)),
		"tipo": str(norm.get("tipo", "")),
		"potencia": int(norm.get("potencia", 0)),
		"max_pp": int(norm["pp_tot"]),
	})

## Entrada de guardado de este movimiento: {nombre_interno, pp_act, pp_mas, pp_tot}.
## Escribe siempre la clave canónica (si `datos` no la trae, la busca por nombre).
func a_guardado() -> Dictionary:
	var interno: String = get_nombre_interno().strip_edges()
	var fila: Dictionary = MovimientoGuardado.resolver(catalogo(), interno if not interno.is_empty() else nombre)
	if not fila.is_empty():
		interno = str(fila["nombre_interno"])
	elif interno.is_empty():
		interno = nombre
	return MovimientoGuardado.crear(interno, pp_act, pp_mas, pp_tot)

## Entradas de guardado de una lista de movimientos (ignora lo que no es Movimiento).
static func lista_a_guardado(movimientos: Array) -> Array:
	var resultado: Array = []
	for movimiento: Variant in movimientos:
		if movimiento is Movimiento:
			resultado.append(movimiento.a_guardado())
	return resultado

# === MÉTODOS DE COMPARACIÓN ===

## Compara si dos movimientos son iguales basándose en su nombre interno.
func equals(otro_movimiento: Movimiento) -> bool:
	if not otro_movimiento:
		return false
	return get_nombre_interno() == otro_movimiento.get_nombre_interno()

## Override del método to_string para debugging. NO es un formato de guardado
## (solo lleva el nombre mostrable): usar `a_guardado()`.
func _to_string() -> String:
	return get_info()

## Crea una copia del movimiento actual.
func duplicate() -> Movimiento:
	return Movimiento.new(nombre, pp_act, pp_mas, pp_tot, datos.duplicate(true))

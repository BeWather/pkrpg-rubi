@tool
extends RefCounted
## Conversor entre el formato de Pokémon del guardado local
## (partida/partida_guardada.json, ver EstructuraGuardado._pokemon_a_diccionario)
## y el formato de formulario del Editor de Instancia de Pokémon
## (editor_instancia_pokemon.gd: cargar_datos_formulario / datos_pokemon_solicitados).
##
## Corre dentro del editor (herramientas @tool), por eso NO usa BasePokemon ni
## los autoloads (DatabaseManager, Singleton): lee sus propios catálogos de
## poke.db y calcula los datos derivados con CalculadoraStatsPokemon, la misma
## fuente de fórmulas que usa el juego.
##
## Equivalencias entre ambos mundos:
##   - estado (guardado, Singleton.ProblemaEstado: NORMAL=-1, DEBILITADO=0, ...)
##     <-> estado_primario (formulario, 0 = sano): estado_primario = estado + 1.
##   - sexo "SIN_SEXO" (guardado) <-> "N" (formulario).
##   - movimientos: existing v1 dictionaries (or legacy Movimiento text)
##     <-> movimientos_json (JSON de [{movimiento_id, nombre_interno, pp_act, pp_mas, ...}]).
##   - naturaleza/habilidad/objeto por nombre <-> por id de la BBDD.
##   - condiciones carisma/belleza/dulzura/ingenio/dureza/brillo (guardado)
##     <-> concurso_carisma ... concurso_brillo (formulario).
## Las claves shiny, marcas, cintas y pokerus_* también se escriben: el
## from_dict del juego las carga (son propiedades de BasePokemon).

const FormatoMovimiento = preload("res://BaseDatos/movimiento_guardado.gd")
const MoveRecord = preload("res://BaseDatos/move_save_record.gd")
const CalculadoraStats := preload("res://BaseDatos/calculadora_stats.gd")
const RUTA_DB := "res://BaseDatos/poke.db"
const RUTA_ICONO := "res://graficos/Icons/icon%03d.png"
const RUTA_ICONO_HUEVO := "res://graficos/Icons/iconEgg.png"
const ESTADO_NORMAL := -1
const ESTADO_MAXIMO := 6 # Singleton.ProblemaEstado.POKERUS
const MAX_MOVIMIENTOS := 4
## Condición de concurso en la partida -> columna del formulario (PokemonInstancias).
const CONDICIONES_CONCURSO := {
	"carisma": "concurso_carisma",
	"belleza": "concurso_belleza",
	"dulzura": "concurso_dulzura",
	"ingenio": "concurso_ingenio",
	"dureza": "concurso_dureza",
	"brillo": "concurso_brillo",
}
const STATS := ["ps", "ataque", "defensa", "ataque_especial", "defensa_especial", "velocidad"]
const COLUMNA_BASE := {
	"ps": "base_ps",
	"ataque": "base_atq",
	"defensa": "base_def",
	"ataque_especial": "base_atq_esp",
	"defensa_especial": "base_def_esp",
	"velocidad": "base_vel",
}
const MARCAS_POR_DEFECTO := {
	"circulo": false,
	"cuadrado": false,
	"triangulo": false,
	"corazon": false,
}
## Campos con el mismo nombre en ambos formatos.
const CAMPOS_ENTEROS := [
	"nivel", "experiencia", "felicidad", "encuentro_nivel", "entrenador_id",
	"iv_ps", "iv_ataque", "iv_defensa", "iv_ataque_especial", "iv_defensa_especial", "iv_velocidad",
	"ev_ps", "ev_ataque", "ev_defensa", "ev_ataque_especial", "ev_defensa_especial", "ev_velocidad",
	"pokerus_dias_restantes", "pokerus_fecha_ultimo_conteo",
]
const CAMPOS_BOOL := ["huevo", "infectado", "curado", "encuentro_fatidico"]
const CAMPOS_TEXTO := ["nombre_interno", "mote", "encuentro_lugar", "encuentro_bola", "entrenador_sexo"]

## Último mensaje de error (vacío si la última operación fue bien).
var error := ""

var _especies_por_id: Dictionary = {}
var _especies_por_interno: Dictionary = {}
var _naturalezas_por_id: Dictionary = {}
var _naturalezas_por_nombre: Dictionary = {}
var _habilidades_por_id: Dictionary = {}
var _habilidades_por_nombre: Dictionary = {}
var _objetos_por_id: Dictionary = {}
var _objetos_por_interno: Dictionary = {}
var _movimientos_por_id: Dictionary = {}
var _movimientos_por_nombre: Dictionary = {}
var _tipos_por_id: Dictionary = {}
var _iconos: Dictionary = {}
var _cargado := false


# =====================================================================
# Catálogos
# =====================================================================

## Carga los catálogos de poke.db. Devuelve false (y rellena `error`) si falla.
func cargar(ruta_db: String = RUTA_DB) -> bool:
	error = ""
	_cargado = false
	var db := SQLite.new()
	db.path = ruta_db
	# Sin read_only: ver el comentario de _cargar_catalogo en debug_partida_guardada.gd.
	if not db.open_db():
		error = "No se pudo abrir la base de datos %s." % ruta_db
		return false
	var consultas := {
		"especies": "SELECT id, numero_nacional, nombre_interno, nombre, tipo_1_id, tipo_2_id, base_ps, base_atq, base_def, base_vel, base_atq_esp, base_def_esp, prob_sexo, ratio_crecimiento, base_felicidad, habilidad_1, habilidad_1_id FROM Pokemon",
		"naturalezas": "SELECT id, nombre FROM Naturalezas",
		"habilidades": "SELECT id, nombre_interno, nombre, nombre_en FROM Habilidades",
		"objetos": "SELECT id, nombre_interno, nombre FROM Objetos",
		"movimientos": "SELECT * FROM Movimientos",
		"tipos": "SELECT id, nombre FROM Tipos",
	}
	var filas := {}
	for clave: String in consultas:
		if not db.query(consultas[clave]):
			error = "No se pudo leer la tabla de %s: %s" % [clave, db.error_message]
			db.close_db()
			return false
		filas[clave] = db.query_result.duplicate(true)
	db.close_db()

	_especies_por_id.clear()
	_especies_por_interno.clear()
	for fila: Dictionary in filas["especies"]:
		_especies_por_id[int(fila["id"])] = fila
		_especies_por_interno[str(fila["nombre_interno"]).to_upper()] = fila
	_naturalezas_por_id.clear()
	_naturalezas_por_nombre.clear()
	for fila: Dictionary in filas["naturalezas"]:
		_naturalezas_por_id[int(fila["id"])] = fila
		_naturalezas_por_nombre[str(fila["nombre"]).to_upper()] = fila
	_habilidades_por_id.clear()
	_habilidades_por_nombre.clear()
	for fila: Dictionary in filas["habilidades"]:
		_habilidades_por_id[int(fila["id"])] = fila
		# El nombre interno manda: se registra el último para que no lo pisen.
		for columna in ["nombre_en", "nombre", "nombre_interno"]:
			if fila.get(columna) != null and str(fila[columna]) != "":
				_habilidades_por_nombre[str(fila[columna]).to_upper()] = fila
	_objetos_por_id.clear()
	_objetos_por_interno.clear()
	for fila: Dictionary in filas["objetos"]:
		_objetos_por_id[int(fila["id"])] = fila
		_objetos_por_interno[str(fila["nombre_interno"]).to_upper()] = fila
	_movimientos_por_id.clear()
	_movimientos_por_nombre.clear()
	for fila: Dictionary in filas["movimientos"]:
		_movimientos_por_id[int(fila["id"])] = fila
		# El guardado usa el nombre mostrable ("ATAQUE ARENA"): tiene prioridad.
		_movimientos_por_nombre[str(fila["nombre_interno"]).to_upper()] = fila
	for fila: Dictionary in filas["movimientos"]:
		_movimientos_por_nombre[str(fila["nombre"]).to_upper()] = fila
	_tipos_por_id.clear()
	for fila: Dictionary in filas["tipos"]:
		_tipos_por_id[int(fila["id"])] = str(fila["nombre"])
	_cargado = true
	return true


func esta_cargado() -> bool:
	return _cargado


## Fila de la tabla Pokemon de la especie ({} si no existe).
func especie(nombre_interno: String) -> Dictionary:
	return _especies_por_interno.get(nombre_interno.strip_edges().to_upper(), {})


## Especie de un Pokémon del guardado (por nombre_interno o, si no, por pid).
func especie_de(poke: Dictionary) -> Dictionary:
	var fila := especie(str(poke.get("nombre_interno", "")))
	if fila.is_empty() and poke.get("pid") != null:
		fila = _especies_por_id.get(int(poke["pid"]), {})
	return fila


## Nombre mostrable de la especie (o el nombre_interno si no está en la BBDD).
func nombre_especie(poke: Dictionary) -> String:
	var fila := especie_de(poke)
	if fila.is_empty():
		return str(poke.get("nombre_interno", "?"))
	return str(fila["nombre"])


func nombre_habilidad(interno: String) -> String:
	var fila: Dictionary = _habilidades_por_nombre.get(interno.to_upper(), {})
	return str(fila.get("nombre", interno)) if not fila.is_empty() else interno


func nombre_objeto(interno: String) -> String:
	var fila: Dictionary = _objetos_por_interno.get(interno.to_upper(), {})
	return str(fila.get("nombre", interno)) if not fila.is_empty() else interno


## PS máximos que corresponden a la especie/nivel/IV/EV del Pokémon
## (-1 si la especie no está en la BBDD).
func ps_maximos(poke: Dictionary) -> int:
	var fila := especie_de(poke)
	if fila.is_empty():
		return -1
	return CalculadoraStats.stat_ps(int(fila["base_ps"]), int(poke.get("iv_ps", 0)), int(poke.get("ev_ps", 0)), int(poke.get("nivel", 1)))


# =====================================================================
# Guardado -> formulario
# =====================================================================

## Convierte un Pokémon del guardado al formato que acepta
## editor_instancia_pokemon.cargar_datos_formulario().
func a_formulario(poke: Dictionary) -> Dictionary:
	error = ""
	if poke.has("movimientos") and not MoveRecord.valid_slots(poke.movimientos):
		error = "Invalid move list."; return {}
	var datos := {"id": -1}
	for clave in CAMPOS_ENTEROS:
		if poke.get(clave) != null:
			datos[clave] = int(poke[clave])
	for clave in CAMPOS_BOOL:
		if poke.has(clave):
			datos[clave] = a_bool(poke[clave])
	for clave in CAMPOS_TEXTO:
		if poke.get(clave) != null:
			datos[clave] = str(poke[clave])
	var fila_especie := especie_de(poke)
	if fila_especie.is_empty():
		error = "Especie desconocida: %s" % str(poke.get("nombre_interno", "?"))
	else:
		datos["especie_id"] = int(fila_especie["id"])
		datos["nombre_interno"] = str(fila_especie["nombre_interno"])
		datos["numero_nacional"] = int(fila_especie["numero_nacional"])
	var naturaleza: Dictionary = _naturalezas_por_nombre.get(str(poke.get("naturaleza", "")).to_upper(), {})
	if not naturaleza.is_empty():
		datos["naturaleza_id"] = int(naturaleza["id"])
	var habilidad: Dictionary = _habilidades_por_nombre.get(str(poke.get("habilidad", "")).strip_edges().to_upper(), {})
	datos["habilidad_id"] = null
	if not habilidad.is_empty():
		datos["habilidad_id"] = int(habilidad["id"])
	var objeto: Dictionary = _objetos_por_interno.get(str(poke.get("objeto", "")).strip_edges().to_upper(), {})
	datos["objeto_id"] = null
	if not objeto.is_empty():
		datos["objeto_id"] = int(objeto["id"])
	# Sin sexo guardado, el editor elige el de la especie.
	if str(poke.get("sexo", "")).strip_edges() != "":
		datos["sexo"] = _sexo_a_formulario(str(poke["sexo"]))
	datos["es_shiny"] = a_bool(poke.get("shiny", false))
	datos["entrenador_nombre"] = str(poke.get("entrenador_original", ""))
	# Formulario: 0 = sano; guardado: ProblemaEstado.NORMAL = -1.
	var estado := int(poke["estado"]) if poke.get("estado") != null else ESTADO_NORMAL
	datos["estado_primario"] = maxi(estado + 1, 0)
	if poke.get("estad_ps_actual") != null:
		datos["ps_actuales"] = int(poke["estad_ps_actual"])
	var marcas := MARCAS_POR_DEFECTO.duplicate()
	if poke.get("marcas") is Dictionary:
		for clave in marcas:
			marcas[clave] = a_bool(poke["marcas"].get(clave, false))
	datos["marcas_json"] = JSON.stringify(marcas)
	datos["cintas_json"] = JSON.stringify(poke["cintas"] if poke.get("cintas") is Array else [])
	for condicion in CONDICIONES_CONCURSO:
		datos[CONDICIONES_CONCURSO[condicion]] = int(poke.get(condicion, 0)) if poke.get(condicion) != null else 0
	var movimientos: Array = []
	if poke.get("movimientos") is Array:
		for record: Variant in poke["movimientos"]:
			if record == null:
				movimientos.append(null); continue
			var mov := info_movimiento(record)
			if mov.is_empty():
				error = "Invalid move record."; return {}
			var form_move: Dictionary = _movimiento_a_formulario(mov)
			if not form_move.has("movimiento_id"):
				error = "Unknown move identity."; return {}
			movimientos.append(form_move)
	datos["movimientos_json"] = JSON.stringify(movimientos)
	return datos


func _movimiento_a_formulario(mov: Dictionary) -> Dictionary:
	var fila: Dictionary = _movimientos_por_nombre.get(str(mov.get("nombre_interno", mov["nombre"])).to_upper(), {})
	var pp_tot := int(mov["pp_tot"])
	# Sin movimiento_id si no se resuelve: el editor lo busca por nombre_interno.
	var resultado := {
		"nombre_interno": str(mov["nombre"]),
		"nombre": str(mov["nombre"]),
		"pp_act": int(mov["pp_act"]),
		"pp_mas": 0,
		"pp_tot": pp_tot,
	}
	if fila.is_empty():
		return resultado
	resultado["movimiento_id"] = int(fila["id"])
	resultado["nombre_interno"] = str(fila["nombre_interno"])
	resultado["nombre"] = str(fila["nombre"])
	if mov.has("move_record"):
		resultado["pp_mas"] = int(mov.pp_mas)
		resultado["move_record"] = mov.move_record.duplicate(true)
		return resultado
	# Los PP extra no se guardan: se deducen del total (0 si no encaja ninguno).
	var pp_base := int(fila["pp"]) if fila.get("pp") != null else 0
	for pp_mas in range(4):
		if pp_total(pp_base, pp_mas) == pp_tot:
			resultado["pp_mas"] = pp_mas
			break
	return resultado


# =====================================================================
# Formulario -> guardado
# =====================================================================

## Convierte los datos del formulario del editor (señal
## datos_pokemon_solicitados) al formato del guardado. Parte de una copia de
## [param base] (el Pokémon que se sobrescribe) para conservar claves que el
## formulario no conoce (p. ej. entrenador_ids). Devuelve {} y rellena
## `error` si no se puede resolver la especie.
func a_partida(datos: Dictionary, base: Dictionary = {}) -> Dictionary:
	error = ""
	var fila_especie: Dictionary = {}
	if datos.get("especie_id") != null and int(datos["especie_id"]) > 0:
		fila_especie = _especies_por_id.get(int(datos["especie_id"]), {})
	if fila_especie.is_empty():
		fila_especie = especie(str(datos.get("nombre_interno", "")))
	if fila_especie.is_empty():
		error = "No se pudo resolver la especie (especie_id=%s, nombre_interno=%s)." % [str(datos.get("especie_id", "")), str(datos.get("nombre_interno", ""))]
		return {}

	var poke := base.duplicate(true)
	poke["pid"] = int(fila_especie["id"])
	poke["nombre_interno"] = str(fila_especie["nombre_interno"])
	poke["numero_nacional"] = int(fila_especie["numero_nacional"])

	for clave in CAMPOS_ENTEROS:
		poke[clave] = int(_valor(datos, base, clave, 0))
	for clave in CAMPOS_BOOL:
		poke[clave] = a_bool(_valor(datos, base, clave, false))
	for clave in ["mote", "encuentro_lugar", "encuentro_bola"]:
		poke[clave] = str(_valor(datos, base, clave, ""))
	var nivel := clampi(int(_valor(datos, base, "nivel", 5)), 1, 100)
	poke["nivel"] = nivel
	var ratio := str(fila_especie.get("ratio_crecimiento", ""))
	poke["exp_sig_nivel"] = CalculadoraStats.experiencia_nivel(nivel + 1, ratio)
	# Filas creadas con la curva antigua (n^3 para todas las especies): la
	# experiencia se ajusta al rango del nivel, igual que al cargar la partida.
	poke["experiencia"] = CalculadoraStats.ajustar_experiencia_a_nivel(int(poke["experiencia"]), nivel, ratio)

	poke["sexo"] = _sexo_a_partida(str(_valor(datos, base, "sexo", "M")))
	poke["entrenador_sexo"] = "F" if str(_valor(datos, base, "entrenador_sexo", "M")).to_upper() == "F" else "M"
	poke["entrenador_original"] = str(datos["entrenador_nombre"]) if datos.get("entrenador_nombre") != null else str(base.get("entrenador_original", ""))
	if not poke.has("entrenador_ids"):
		poke["entrenador_ids"] = null

	poke["naturaleza"] = _resolver_naturaleza(datos, base)
	poke["habilidad"] = _resolver_habilidad(datos, base, fila_especie)
	var objeto: Dictionary = {}
	if datos.has("objeto_id"):
		if datos["objeto_id"] != null:
			objeto = _objetos_por_id.get(int(datos["objeto_id"]), {})
		poke["objeto"] = str(objeto.get("nombre_interno", ""))
	else:
		poke["objeto"] = str(base.get("objeto", ""))

	# Estadísticas como el juego (BasePokemon._recalcular_stats_con_ivs_actuales):
	# sin multiplicador de naturaleza.
	for stat in STATS:
		var base_stat := int(fila_especie[COLUMNA_BASE[stat]])
		var iv := int(poke["iv_" + stat])
		var ev := int(poke["ev_" + stat])
		if stat == "ps":
			poke["estad_ps"] = CalculadoraStats.stat_ps(base_stat, iv, ev, nivel)
		else:
			poke["estad_" + stat] = CalculadoraStats.stat_general(base_stat, iv, ev, nivel)
	poke["tipo_poder_oculto"] = CalculadoraStats.tipo_poder_oculto(
		int(poke["iv_ps"]), int(poke["iv_ataque"]), int(poke["iv_defensa"]),
		int(poke["iv_velocidad"]), int(poke["iv_ataque_especial"]), int(poke["iv_defensa_especial"]))
	poke["tipo_1"] = str(_tipos_por_id.get(int(fila_especie["tipo_1_id"]), ""))
	var tipo_2_id := int(fila_especie["tipo_2_id"]) if fila_especie.get("tipo_2_id") != null else 0
	poke["tipo_2"] = str(_tipos_por_id.get(tipo_2_id, "")) if tipo_2_id > 0 else ""

	# estado_primario del formulario (0 = sano) -> ProblemaEstado (-1 = NORMAL).
	if datos.get("estado_primario") != null:
		poke["estado"] = clampi(int(datos["estado_primario"]) - 1, ESTADO_NORMAL, ESTADO_MAXIMO)
	else:
		poke["estado"] = int(base.get("estado", ESTADO_NORMAL))
	var ps_actual: int = int(datos["ps_actuales"]) if datos.get("ps_actuales") != null else int(base.get("estad_ps_actual", poke["estad_ps"]))
	poke["estad_ps_actual"] = clampi(ps_actual, 0, int(poke["estad_ps"]))

	if datos.has("movimientos_json") or datos.get("movimientos") is Array:
		poke["movimientos"] = _movimientos_a_partida(datos, base.get("movimientos", []))
		if error != "": return {}
	elif not poke.get("movimientos") is Array:
		poke["movimientos"] = []

	poke["shiny"] = a_bool(datos["es_shiny"]) if datos.has("es_shiny") else a_bool(base.get("shiny", false))
	var marcas := MARCAS_POR_DEFECTO.duplicate()
	var marcas_origen: Variant = _json(datos["marcas_json"]) if datos.has("marcas_json") else base.get("marcas")
	if marcas_origen is Dictionary:
		for clave in marcas:
			marcas[clave] = a_bool(marcas_origen.get(clave, false))
	poke["marcas"] = marcas
	var cintas_origen: Variant = _json(datos["cintas_json"]) if datos.has("cintas_json") else base.get("cintas")
	poke["cintas"] = cintas_origen if cintas_origen is Array else []
	for condicion in CONDICIONES_CONCURSO:
		var columna: String = CONDICIONES_CONCURSO[condicion]
		var valor: Variant = datos[columna] if datos.get(columna) != null else base.get(condicion, 0)
		poke[condicion] = clampi(int(valor) if valor != null else 0, 0, 255)
	return poke


func _movimientos_a_partida(datos: Dictionary, originals: Array = []) -> Array:
	var lista: Variant = _json(datos["movimientos_json"]) if datos.has("movimientos_json") else datos.get("movimientos")
	if not MoveRecord.valid_form_moves(lista) or not MoveRecord.valid_slots(originals):
		error = "Invalid move fields."; return []
	for original: Variant in originals:
		if original != null and info_movimiento(original).is_empty():
			error = "Invalid original move record."; return []
	var result: Array = []
	for index: int in lista.size():
		var mov: Variant = lista[index]
		if mov == null:
			result.append(null); continue
		var row: Dictionary = _movimientos_por_nombre.get(str(mov.nombre_interno).to_upper(), {})
		if row.is_empty():
			error = "Unknown move identity."; return []
		if mov.has("movimiento_id") and int(mov.movimiento_id) != int(row.id):
			error = "Conflicting move identity."; return []
		var original: Variant = originals[index] if index < originals.size() else null
		var preserved: Dictionary = original.duplicate(true) if not mov.get("reset_move_origin", false) and MoveRecord.valid(original) and str(original.data.nombre_interno).to_upper() == str(mov.nombre_interno).to_upper() else {}
		var data: Dictionary = MoveRecord.decode_fields(preserved).data if not preserved.is_empty() else {
			"nombre_interno":str(row.nombre_interno),"nombre":str(row.nombre),"tipo":str(_tipos_por_id.get(int(row.tipo_id), "")),
			"potencia":0 if row.poder == null else int(row.poder),"precision":0 if row.precision == null else int(row.precision),
			"max_pp":int(row.pp),"prioridad":int(row.prioridad),"categoria_dano_id":int(row.categoria_dano_id),
			"objetivo_id":row.objetivo_id,"descripcion":str(row.descripcion)}
		if preserved.is_empty():
			var completos: Dictionary = row.duplicate(true)
			completos.merge(data, true)
			data = completos
		var bonus: int = clampi(int(mov.get("pp_mas", 0)), 0, 3)
		var maximum: int = MoveRecord.total(int(data.max_pp), bonus)
		var current: int = clampi(int(mov.get("pp_act", maximum)), 0, maximum)
		if not preserved.is_empty():
			# An untouched valid historical record keeps its original semantics.
			if bonus != int(preserved.pp_mas) or current != int(preserved.pp_act):
				preserved.pp_act = current; preserved.pp_mas = bonus; preserved.pp_tot = maximum
			result.append(preserved)
		else:
			if MoveRecord.valid(original) or mov.has("move_record"):
				result.append(MoveRecord.encode_fields(str(row.nombre), current, bonus, maximum, data))
			else:
				result.append(FormatoMovimiento.crear(str(row.nombre_interno), current, bonus, maximum))
	return result


static func leer_movimiento(record: Variant) -> Dictionary:
	if record is String: return parsear_movimiento(record)
	if not MoveRecord.valid(record): return {}
	var fields: Dictionary = MoveRecord.decode_fields(record)
	return {"nombre":fields.name,"nombre_interno":fields.data.nombre_interno,"pp_act":int(fields.pp_act),"pp_mas":int(fields.pp_mas),"pp_tot":int(fields.pp_tot),"tipo":str(fields.data.get("tipo", "")),"potencia":fields.data.get("potencia", 0),"move_record":record.duplicate(true)}


func _resolver_naturaleza(datos: Dictionary, base: Dictionary) -> String:
	if datos.get("naturaleza_id") != null:
		var fila: Dictionary = _naturalezas_por_id.get(int(datos["naturaleza_id"]), {})
		if not fila.is_empty():
			return str(fila["nombre"])
	if datos.get("naturaleza") != null:
		return str(datos["naturaleza"]).to_upper()
	return str(base.get("naturaleza", ""))


func _resolver_habilidad(datos: Dictionary, base: Dictionary, fila_especie: Dictionary) -> String:
	if datos.get("habilidad_id") != null:
		var fila: Dictionary = _habilidades_por_id.get(int(datos["habilidad_id"]), {})
		if not fila.is_empty():
			return str(fila["nombre_interno"])
	if datos.get("habilidad") != null:
		var por_nombre: Dictionary = _habilidades_por_nombre.get(str(datos["habilidad"]).to_upper(), {})
		if not por_nombre.is_empty():
			return str(por_nombre["nombre_interno"])
	if str(base.get("habilidad", "")) != "":
		return str(base["habilidad"])
	# Por defecto, la primera habilidad de la especie.
	if fila_especie.get("habilidad_1_id") != null:
		var fila_1: Dictionary = _habilidades_por_id.get(int(fila_especie["habilidad_1_id"]), {})
		if not fila_1.is_empty():
			return str(fila_1["nombre_interno"])
	return str(fila_especie.get("habilidad_1", "")).to_upper() if fila_especie.get("habilidad_1") != null else ""


# =====================================================================
# Movimientos, curación e iconos
# =====================================================================

## PP totales con [param pp_mas] Más PP usados (0..3), igual que el editor.
static func pp_total(pp_base: int, pp_mas: int) -> int:
	var usos := clampi(pp_mas, 0, 3)
	return pp_base + int(floor(float(pp_base) * float(usos) / 5.0))


## Parsea "Movimiento(nombre=X, pp=a/t, tipo=T, potencia=P)" como hace
## EstructuraGuardado._string_a_movimiento. Devuelve {} si no es válido.
static func parsear_movimiento(texto: String) -> Dictionary:
	if not texto.begins_with("Movimiento(") or not texto.ends_with(")"):
		return {}
	var contenido := texto.substr(11, texto.length() - 12)
	var resultado := {"nombre": "", "pp_act": 0, "pp_tot": 0, "tipo": "", "potencia": 0}
	for parte in contenido.split(", "):
		var kv := parte.split("=")
		if kv.size() != 2:
			continue
		var valor := kv[1].strip_edges()
		match kv[0].strip_edges():
			"nombre":
				resultado["nombre"] = valor
			"pp":
				var pp := valor.split("/")
				if pp.size() != 2 or not pp[0].is_valid_int() or not pp[1].is_valid_int(): return {}
				resultado["pp_act"] = int(pp[0])
				resultado["pp_tot"] = int(pp[1])
			"tipo":
				resultado["tipo"] = valor
			"potencia":
				if not valor.is_valid_int(): return {}
				resultado["potencia"] = int(valor)
	if str(resultado["nombre"]) == "" or resultado.pp_tot <= 0 or resultado.pp_act < 0 or resultado.pp_act > resultado.pp_tot:
		return {}
	return resultado


## Legacy Movimiento.get_info() format, retained for old saves only.
static func formatear_movimiento(mov: Dictionary) -> String:
	return "Movimiento(nombre=%s, pp=%d/%d, tipo=%s, potencia=%d)" % [
		str(mov.get("nombre", "")),
		int(mov.get("pp_act", 0)),
		int(mov.get("pp_tot", 0)),
		str(mov.get("tipo", "")),
		int(mov.get("potencia", 0)),
	]


## Cura en el sitio: PS al máximo, sin problema de estado y PP completos.
func info_movimiento(entrada: Variant) -> Dictionary:
	if entrada is Dictionary and entrada.has("move_record_version"):
		return leer_movimiento(entrada)
	if entrada is String and FormatoMovimiento.es_legado(entrada) and parsear_movimiento(entrada).is_empty(): return {}
	var catalogo := FormatoMovimiento.construir_catalogo(_movimientos_por_id.values())
	var mov := FormatoMovimiento.normalizar(entrada, catalogo)
	if mov.is_empty(): return {}
	var fila := FormatoMovimiento.resolver(catalogo, str(mov.nombre_interno))
	if not fila.is_empty():
		mov.nombre = str(fila.nombre)
		mov.tipo = str(_tipos_por_id.get(int(fila.tipo_id), ""))
		mov.potencia = int(fila.poder) if fila.get("poder") != null else 0
	mov.erase("legado")
	mov.erase("resuelto")
	return mov


static func curar(poke: Dictionary) -> bool:
	var conversor := new()
	if not conversor.cargar(): return false
	return conversor._curar_con_catalogo(poke)


func _curar_con_catalogo(poke: Dictionary) -> bool:
	var moves: Variant = poke.get("movimientos", [])
	if not MoveRecord.valid_slots(moves): return false
	var staged: Array = []
	for record: Variant in moves:
		if record == null:
			staged.append(null); continue
		var move := info_movimiento(record)
		if move.is_empty(): return false
		if MoveRecord.valid(record):
			var maximum: int = MoveRecord.total(int(record.data.max_pp), int(record.pp_mas))
			if maximum != int(record.pp_tot): return false
			var copy: Dictionary = record.duplicate(true)
			copy.pp_act = maximum
			staged.append(copy)
		else:
			staged.append(FormatoMovimiento.crear(str(move.nombre_interno), int(move.pp_tot), int(move.pp_mas), int(move.pp_tot)))
	poke["estad_ps_actual"] = int(poke.get("estad_ps", 0))
	poke["estado"] = ESTADO_NORMAL
	poke["movimientos"] = staged
	return true


## Icono de caja (primer fotograma de 32x32). Huevo si el Pokémon es un huevo.
func icono(poke: Dictionary) -> Texture2D:
	var ruta := RUTA_ICONO_HUEVO if a_bool(poke.get("huevo", false)) else RUTA_ICONO % int(poke.get("numero_nacional", 0))
	if _iconos.has(ruta):
		return _iconos[ruta]
	var textura: Texture2D = null
	if ResourceLoader.exists(ruta):
		var hoja := load(ruta) as Texture2D
		if hoja != null:
			var atlas := AtlasTexture.new()
			atlas.atlas = hoja
			atlas.region = Rect2(0, 0, 32, 32)
			textura = atlas
	_iconos[ruta] = textura
	return textura


# =====================================================================
# Utilidades
# =====================================================================

static func a_bool(valor: Variant) -> bool:
	if valor is bool:
		return valor
	if valor is int or valor is float:
		return valor != 0
	if valor is String:
		return valor.strip_edges().to_lower() in ["true", "1", "si", "sí"]
	return false


static func _json(valor: Variant) -> Variant:
	if valor is String:
		return JSON.parse_string(valor)
	return valor


static func _valor(datos: Dictionary, base: Dictionary, clave: String, defecto: Variant) -> Variant:
	if datos.get(clave) != null:
		return datos[clave]
	if base.get(clave) != null:
		return base[clave]
	return defecto


static func _sexo_a_formulario(sexo: String) -> String:
	match sexo.strip_edges().to_upper():
		"F", "HEMBRA", "FEMENINO":
			return "F"
		"SIN_SEXO", "N", "NONE":
			return "N"
	return "M"


static func _sexo_a_partida(sexo: String) -> String:
	match sexo.strip_edges().to_upper():
		"F", "HEMBRA", "FEMENINO":
			return "F"
		"N", "SIN_SEXO", "NONE":
			return "SIN_SEXO"
	return "M"

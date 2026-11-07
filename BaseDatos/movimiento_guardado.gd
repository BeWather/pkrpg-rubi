extends RefCounted
class_name MovimientoGuardado

## Formato de guardado de un movimiento de Pokémon (equipo, cajas del PC,
## guardería) y su migración desde los formatos antiguos.
##
## FORMATO ACTUAL (`crear`; versión 1.1 de EstructuraGuardado). Es el mismo
## subconjunto de claves que `PokemonInstancias.movimientos_json`:
##   {"nombre_interno": "GRUNIDO", "pp_act": 40, "pp_mas": 0, "pp_tot": 40}
## `nombre_interno` es la clave canónica de `Movimientos.nombre_interno`. El nombre
## mostrable ("GRUÑIDO") y el resto de datos salen de la BD al cargar: nunca se guardan.
##
## FORMATO LEGADO (versión 1.0): la cadena de `Movimiento._to_string()`,
##   "Movimiento(nombre=GRUÑIDO, pp=40/40, tipo=NORMAL, potencia=0)"
## que solo llevaba el nombre mostrable. `normalizar` la resuelve contra el
## catálogo y la migra; esta es la ÚNICA resolución nombre mostrable -> interno.
##
## Sin dependencias de autoloads ni de `Movimiento`: lo usan también las herramientas
## del editor (conversor_pokemon_partida.gd), que leen poke.db por su cuenta. El
## catálogo se construye con filas de la tabla Movimientos (nombre_interno, nombre, pp).

const PREFIJO_LEGADO: String = "Movimiento("
## Usos máximos de Más PP (pokeruby: 3 PP Ups por movimiento).
const MAX_PP_MAS: int = 3


## Diccionario de guardado de un movimiento.
static func crear(nombre_interno: String, pp_act: int, pp_mas: int, pp_tot: int) -> Dictionary:
	return {"nombre_interno": nombre_interno, "pp_act": pp_act, "pp_mas": pp_mas, "pp_tot": pp_tot}


## PP totales con `pp_mas` usos de Más PP (0..3): base + base * usos / 5.
static func pp_total(pp_base: int, pp_mas: int) -> int:
	var usos: int = clampi(pp_mas, 0, MAX_PP_MAS)
	return pp_base + int(floor(float(pp_base) * float(usos) / 5.0))


# ==============================================
# CATÁLOGO
# ==============================================

## Catálogo de resolución a partir de filas de `Movimientos` (claves `nombre_interno`,
## `nombre` y, para los PP, `pp`; las demás se conservan tal cual en la fila).
## Resultado: {"interno": {NOMBRE_INTERNO: fila}, "nombre": {NOMBRE_MOSTRABLE: fila}}.
static func construir_catalogo(filas: Array) -> Dictionary:
	var por_interno: Dictionary = {}
	var por_nombre: Dictionary = {}
	for fila: Variant in filas:
		if not fila is Dictionary:
			continue
		var interno: String = str(fila.get("nombre_interno", "")).strip_edges().to_upper()
		if interno.is_empty():
			continue
		por_interno[interno] = fila
		var nombre: String = str(fila.get("nombre", "")).strip_edges().to_upper()
		if not nombre.is_empty() and not por_nombre.has(nombre):
			por_nombre[nombre] = fila
	return {"interno": por_interno, "nombre": por_nombre}


## Fila del catálogo para un nombre interno o, si no existe, mostrable (sin
## distinguir mayúsculas ni espacios sobrantes). {} si no se resuelve.
static func resolver(catalogo: Dictionary, texto: String) -> Dictionary:
	var clave: String = texto.strip_edges().to_upper()
	if clave.is_empty():
		return {}
	var por_interno: Dictionary = catalogo.get("interno", {})
	if por_interno.has(clave):
		return por_interno[clave]
	var por_nombre: Dictionary = catalogo.get("nombre", {})
	if por_nombre.has(clave):
		return por_nombre[clave]
	return {}


# ==============================================
# FORMATO LEGADO
# ==============================================

## true si `valor` es la cadena legada "Movimiento(nombre=..., pp=a/t, ...)".
static func es_legado(valor: Variant) -> bool:
	return valor is String and (valor as String).begins_with(PREFIJO_LEGADO)


## Parsea la cadena legada. {"nombre", "pp_act", "pp_tot", "tipo", "potencia"} o {}
## si no es válida (sin prefijo, sin ")" final o sin nombre).
static func parsear_legado(texto: String) -> Dictionary:
	if not es_legado(texto) or not texto.ends_with(")"):
		return {}
	var contenido: String = texto.substr(PREFIJO_LEGADO.length(), texto.length() - PREFIJO_LEGADO.length() - 1)
	var resultado: Dictionary = {"nombre": "", "pp_act": 0, "pp_tot": 0, "tipo": "", "potencia": 0}
	for parte: String in contenido.split(", "):
		var kv: PackedStringArray = parte.split("=")
		if kv.size() != 2:
			continue
		var valor: String = kv[1].strip_edges()
		match kv[0].strip_edges():
			"nombre":
				resultado["nombre"] = valor
			"pp":
				var pp: PackedStringArray = valor.split("/")
				if pp.size() == 2:
					resultado["pp_act"] = int(pp[0])
					resultado["pp_tot"] = int(pp[1])
			"tipo":
				resultado["tipo"] = valor
			"potencia":
				resultado["potencia"] = int(valor)
	if str(resultado["nombre"]).is_empty():
		return {}
	return resultado


# ==============================================
# NORMALIZACIÓN
# ==============================================

## Lleva `entrada` al formato actual. Acepta:
##   - la cadena legada (migra y deduce `pp_mas` de los PP totales);
##   - un nombre suelto ("GRUNIDO" o "GRUÑIDO"), con PP completos;
##   - un diccionario con `nombre_interno` (o `nombre`) y, opcionales, `pp_act`,
##     `pp_mas` y `pp_tot` (formato actual, `movimientos_json` o snapshot ligero).
## Si el nombre está en el catálogo, `pp_mas` se acota a 0..3, los PP totales se
## recalculan desde los PP base de la BD y `pp_act` se acota a ellos.
##
## Devuelve {} si no se reconoce la entrada. Claves del resultado: `nombre_interno`,
## `pp_act`, `pp_mas`, `pp_tot` (formato actual), `resuelto` (existe en el catálogo),
## `legado` (venía en cadena legada) y, solo con la cadena legada, `nombre`, `tipo` y
## `potencia` (para conservar el movimiento si no se resuelve).
static func normalizar(entrada: Variant, catalogo: Dictionary) -> Dictionary:
	var texto: String = ""
	var pp_act: int = -1
	var pp_mas: int = 0
	var pp_tot: int = -1
	var legado: Dictionary = {}
	var es_cadena_legada: bool = false

	if entrada is String:
		if es_legado(entrada):
			legado = parsear_legado(entrada)
			if legado.is_empty():
				return {}
			es_cadena_legada = true
			texto = str(legado["nombre"])
			pp_act = int(legado["pp_act"])
			pp_tot = int(legado["pp_tot"])
		else:
			texto = entrada
	elif entrada is Dictionary:
		texto = str(entrada.get("nombre_interno", ""))
		if texto.strip_edges().is_empty():
			texto = str(entrada.get("nombre", ""))
		pp_act = _entero(entrada.get("pp_act"), -1)
		pp_mas = _entero(entrada.get("pp_mas"), 0)
		pp_tot = _entero(entrada.get("pp_tot"), -1)
	else:
		return {}

	texto = texto.strip_edges()
	if texto.is_empty():
		return {}

	var resultado: Dictionary = {"legado": es_cadena_legada}
	if es_cadena_legada:
		resultado["nombre"] = texto
		resultado["tipo"] = str(legado["tipo"])
		resultado["potencia"] = int(legado["potencia"])

	var fila: Dictionary = resolver(catalogo, texto)
	var pp_base: int = _entero(fila.get("pp"), 0) if not fila.is_empty() else 0
	if not fila.is_empty() and pp_base > 0:
		if es_cadena_legada:
			# La cadena no guardaba `pp_mas`: se deduce del total (0 si no encaja ninguno).
			pp_mas = 0
			for usos in range(MAX_PP_MAS + 1):
				if pp_total(pp_base, usos) == pp_tot:
					pp_mas = usos
					break
		pp_mas = clampi(pp_mas, 0, MAX_PP_MAS)
		pp_tot = pp_total(pp_base, pp_mas)
		pp_act = pp_tot if pp_act < 0 else clampi(pp_act, 0, pp_tot)
		resultado["nombre_interno"] = str(fila["nombre_interno"]).strip_edges().to_upper()
		resultado["resuelto"] = true
	else:
		# Sin catálogo (o PP base desconocidos): se conservan los valores guardados.
		pp_mas = clampi(pp_mas, 0, MAX_PP_MAS)
		if pp_tot < 0:
			pp_tot = maxi(pp_act, 0)
		if pp_act < 0:
			pp_act = pp_tot
		resultado["nombre_interno"] = str(fila["nombre_interno"]).strip_edges().to_upper() if not fila.is_empty() else texto
		resultado["resuelto"] = not fila.is_empty()
	resultado["pp_act"] = pp_act
	resultado["pp_mas"] = pp_mas
	resultado["pp_tot"] = pp_tot
	return resultado


## Entero de un valor de JSON (float o int); `defecto` si no es numérico.
static func _entero(valor: Variant, defecto: int) -> int:
	if valor is int or valor is float:
		return int(valor)
	return defecto

class_name Lugares
extends RefCounted

## Claves de lugar (patrón MAPSEC de pokeruby).
##
## Todo lo que guarda un "lugar" (el cartel de nombre de lugar, la posición de
## la partida `posicion.nombre_lugar` y el lugar de encuentro de un Pokémon
## `BasePokemon.encuentro_lugar`) guarda SIEMPRE una clave de zona en
## MAYÚSCULAS_CON_GUIONES_BAJOS (p. ej. `RUTA_113`, `VILLA_RAIZ`). El texto
## legible se resuelve solo al mostrarlo con `nombre_lugar(clave)`, que traduce
## `LUGAR_<clave>` desde `BaseDatos/dialogos.csv`.
##
## Las zonas del mapa las declara `MapaConfiguracion.seccion` (los interiores sin
## sección propia heredan la de su `mapa_exterior_asociado`). Además hay claves
## especiales que no son zonas (intercambio, regalo, guardería...).

## Prefijo de las claves de traducción de lugares en dialogos.csv.
const PREFIJO_TRADUCCION: String = "LUGAR_"

## Carpeta raíz de las escenas de mapas (búsqueda de secciones por clave de escena).
const RUTA_ESCENAS_MAPAS: String = "res://escenas/mapas/"

## ===== CLAVES ESPECIALES (no son zonas del mapa) =====
const DESCONOCIDO: String = "RUTA_DESCONOCIDA"
const EQUIPO_ENTRENADOR: String = "EQUIPO_ENTRENADOR"
const GUARDERIA_POKEMON: String = "GUARDERIA_POKEMON"
const REGALO: String = "REGALO"
const INTERCAMBIO: String = "INTERCAMBIO"
const LABORATORIO_PROF: String = "LABORATORIO_PROF"
const EVENTO_ESPECIAL: String = "EVENTO_ESPECIAL"
const LABORATORIO_FOSSIL: String = "LABORATORIO_FOSSIL"
const CAPTURA_ESPECIAL: String = "CAPTURA_ESPECIAL"

## Valores antiguos con clave válida pero obsoleta → clave actual.
const ALIAS_LEGADOS: Dictionary = {
	"LUGAR_ESPECIAL": CAPTURA_ESPECIAL,
	"DESCONOCIDO": DESCONOCIDO,
}

## Letras acentuadas → sin acento, para convertir nombres legibles en claves.
const _SIN_ACENTOS: Dictionary = {
	"Á": "A", "À": "A", "Ä": "A", "Â": "A",
	"É": "E", "È": "E", "Ë": "E", "Ê": "E",
	"Í": "I", "Ì": "I", "Ï": "I", "Î": "I",
	"Ó": "O", "Ò": "O", "Ö": "O", "Ô": "O",
	"Ú": "U", "Ù": "U", "Ü": "U", "Û": "U",
	"Ñ": "N", "Ç": "C",
}

## Límite de saltos interior → exterior al resolver secciones (evita ciclos).
const _MAX_SALTOS_EXTERIOR: int = 4

## Cache clave de escena (en minúsculas) → sección resuelta ("" si no hay).
static var _cache_seccion_escena: Dictionary = {}


## Texto legible de una clave de lugar: traduce `LUGAR_<clave>`; si no hay
## traducción, la propia clave con espacios (`RUTA_106` → `RUTA 106`).
## "" si la clave está vacía.
static func nombre_lugar(clave: String) -> String:
	var limpia := clave.strip_edges()
	if limpia.is_empty():
		return ""
	var clave_traduccion := PREFIJO_TRADUCCION + limpia
	var traducido := String(TranslationServer.translate(StringName(clave_traduccion)))
	if not traducido.is_empty() and traducido != clave_traduccion:
		return traducido
	return limpia.replace("_", " ")


## true si `valor` ya tiene formato de clave (solo A-Z, 0-9 y "_").
static func es_clave_valida(valor: String) -> bool:
	if valor.is_empty():
		return false
	for caracter: String in valor:
		var es_letra := caracter >= "A" and caracter <= "Z"
		var es_digito := caracter >= "0" and caracter <= "9"
		if not (es_letra or es_digito or caracter == "_"):
			return false
	return true


## Convierte cualquier valor de lugar (actual o de partidas antiguas) en clave:
## - clave válida → se conserva (con alias legados aplicados);
## - clave de escena (`ruta_113`, `nodo_laboratorio`) → la `seccion` de ese mapa;
## - nombre legible (`RUTA 101`, `VILLA RAÍZ`) → `RUTA_101`, `VILLA_RAIZ`.
## "" si el valor está vacío.
static func normalizar_clave(valor: String) -> String:
	var limpio := valor.strip_edges()
	if limpio.is_empty():
		return ""
	if es_clave_valida(limpio):
		return str(ALIAS_LEGADOS.get(limpio, limpio))
	var de_escena := seccion_de_escena(limpio)
	if not de_escena.is_empty():
		return de_escena
	var textual := clave_desde_texto(limpio)
	return str(ALIAS_LEGADOS.get(textual, textual))


## Clave a partir de un texto libre: mayúsculas, sin acentos y con "_" en lugar
## de cualquier otro carácter (sin "_" repetidos ni en los extremos).
static func clave_desde_texto(texto: String) -> String:
	var resultado := ""
	var ultimo_guion := true
	for caracter: String in texto.strip_edges().to_upper():
		var c: String = str(_SIN_ACENTOS.get(caracter, caracter))
		var valido := (c >= "A" and c <= "Z") or (c >= "0" and c <= "9")
		if valido:
			resultado += c
			ultimo_guion = false
		elif not ultimo_guion:
			resultado += "_"
			ultimo_guion = true
	return resultado.trim_suffix("_")


## Sección efectiva de la escena de mapa `clave_escena` (nombre del .tscn sin
## extensión, sin distinguir mayúsculas), leída sin instanciar la escena. Un
## interior sin sección propia toma la de su `mapa_exterior_asociado`.
## "" si no existe la escena o no declara sección.
static func seccion_de_escena(clave_escena: String) -> String:
	return _seccion_de_escena(clave_escena, 0)


## POI declarado por el mapa, sin instanciarlo. Los mapas submarinos apuntan
## aquí a su ruta de superficie, aunque su sección de encuentro sea BAJO_AGUA_*.
static func poi_mapa_region_de_escena(clave_escena: String) -> String:
	var propiedades: Dictionary = _leer_propiedades_raiz(clave_escena.strip_edges().to_lower())
	var poi: Variant = propiedades.get("poi_mapa_region", "")
	return str(poi).strip_edges() if poi != null else ""


## Vacía la cache de secciones por escena (tests / herramientas de editor).
static func limpiar_cache() -> void:
	_cache_seccion_escena.clear()


static func _seccion_de_escena(clave_escena: String, saltos: int) -> String:
	var clave := clave_escena.strip_edges().to_lower()
	if clave.is_empty() or saltos > _MAX_SALTOS_EXTERIOR:
		return ""
	if _cache_seccion_escena.has(clave):
		return str(_cache_seccion_escena[clave])
	var resultado := ""
	var propiedades := _leer_propiedades_raiz(clave)
	if not propiedades.is_empty():
		resultado = str(propiedades.get("seccion", "")).strip_edges()
		var exterior := str(propiedades.get("mapa_exterior_asociado", "")).strip_edges()
		if resultado.is_empty() and bool(propiedades.get("esInterior", false)) and not exterior.is_empty():
			resultado = _seccion_de_escena(exterior, saltos + 1)
	_cache_seccion_escena[clave] = resultado
	return resultado


## Propiedades guardadas en el nodo raíz de la escena de mapa (SceneState: no
## instancia la escena ni dispara _ready). {} si no se encuentra.
static func _leer_propiedades_raiz(clave_escena: String) -> Dictionary:
	var ruta := _buscar_ruta_escena(RUTA_ESCENAS_MAPAS, clave_escena)
	if ruta.is_empty():
		return {}
	var packed := load(ruta) as PackedScene
	if packed == null:
		return {}
	var estado := packed.get_state()
	if estado.get_node_count() == 0:
		return {}
	var propiedades := {}
	for indice in estado.get_node_property_count(0):
		propiedades[String(estado.get_node_property_name(0, indice))] = estado.get_node_property_value(0, indice)
	return propiedades


## Búsqueda recursiva de `<nombre>.tscn` (sin distinguir mayúsculas) bajo
## `base_path`. Admite los `.tscn.remap` de una exportación.
static func _buscar_ruta_escena(base_path: String, nombre: String) -> String:
	var dir := DirAccess.open(base_path)
	if dir == null:
		return ""
	var encontrado := ""
	dir.list_dir_begin()
	var nombre_archivo := dir.get_next()
	while not nombre_archivo.is_empty() and encontrado.is_empty():
		if dir.current_is_dir():
			if not nombre_archivo.begins_with("."):
				encontrado = _buscar_ruta_escena(base_path + nombre_archivo + "/", nombre)
		else:
			var archivo := nombre_archivo.trim_suffix(".remap")
			if archivo.ends_with(".tscn") and archivo.get_basename().to_lower() == nombre:
				encontrado = base_path + archivo
		nombre_archivo = dir.get_next()
	dir.list_dir_end()
	return encontrado
